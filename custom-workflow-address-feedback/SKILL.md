---
name: custom-workflow-address-feedback
user-invocable: true
description: Find, address, and resolve GitHub PR review threads for the current branch. Handles code fixes (commit + push per thread) and discussion replies.
allowed-tools: Bash, Agent
---

# Address Feedback

Process all unresolved GitHub PR review threads for the current branch. Code-change threads get their own commit and push; discussion-only threads get a reply and are resolved.

## Build constraints — follow these without exception

- Address threads one at a time, never in parallel.
- Each code-fix thread gets its own commit — never batch multiple threads into one commit.
- Stage only the files changed for that thread — never use `git add -A` or `git add .`.
- Use `git push origin HEAD:{headRefName}` — not bare `git push`.
- On push failure: undo with `git reset HEAD~1` (mixed mode). If the reset itself fails, stop immediately and report.
- On check failure before commit: unstage with `git restore --staged .`; skip the thread.
- Use `jq -n --arg body "..."` for all reply JSON — never interpolate shell variables directly into JSON strings.
- File paths from `thread.path` are relative to repo root; resolve as `{repoRoot}/{thread.path}`.
- Run all check commands with `cwd=repoRoot`.
- Run the pre-flight check before any edits.

---

## Step 1 — Find the PR URL

Try to discover the PR URL for the current branch:

```bash
gh pr view --json url --jq '.url' 2>/dev/null
```

If that returns a non-empty URL, use it. If it fails or returns nothing, search the session context for a GitHub PR URL. If still not found, call `friday_telegram_search` with the current branch name as the query and look for a PR URL in recent messages.

If no PR URL can be found after all three attempts, stop and report: "Could not find a PR URL for the current branch."

Store the URL as `prUrl`.

## Step 2 — Parse owner, repo, and PR number

Extract the three components from `prUrl`. A GitHub PR URL has the form `https://github.com/{owner}/{repo}/pull/{number}`.

Store as `owner`, `repo`, and `prNumber`.

## Step 3 — Verify the PR is open

```bash
gh pr view {prNumber} --repo {owner}/{repo} --json state --jq '.state'
```

If the output is not `"OPEN"`, stop and report: "PR #{prNumber} is not open (state: {state})."

## Step 4 — Verify working branch matches PR head ref

Fetch the PR head ref:

```bash
gh pr view {prNumber} --repo {owner}/{repo} --json headRefName --jq '.headRefName'
```

Store as `headRefName`.

Check the current branch:

```bash
git rev-parse --abbrev-ref HEAD
```

If the current branch does not match `headRefName`, check whether the working tree is clean:

```bash
git status --porcelain
```

If the working tree is clean, checkout the correct branch:

```bash
git checkout {headRefName}
```

If the working tree is not clean, stop and report: "Working tree has uncommitted changes; cannot switch to {headRefName}."

## Step 5 — Verify git repo and store root

```bash
git rev-parse --show-toplevel
```

Store the output as `repoRoot`. If this command fails, stop and report that the current directory is not inside a git repository.

## Step 6 — Discover check command

Read `{repoRoot}/package.json` and inspect the `scripts` object. If a `check` script exists, set `checkCommand` to `npm run check`. If there is no `check` script but a `test` script exists, set `checkCommand` to `npm test`. If neither exists, set `checkCommand` to `null`.

## Step 7 — Pre-flight check

If `checkCommand` is not null, run it now with `cwd` set to `repoRoot`:

```bash
cd {repoRoot} && {checkCommand}
```

If it exits non-zero, stop and report the failure output. Do not proceed to fetching threads until the repo is in a passing state.

## Step 8 — Check for prior runs

Call `friday_event_list` with:
- `type`: `"pr.feedback.addressed"`
- `source_id`: `{prUrl}`
- `direction`: `"desc"`
- `limit`: `1`

If the response contains at least one event, extract its `occurred_at` timestamp and store as `cutoff`. Otherwise set `cutoff` to `null`.

## Step 9 — Fetch GitHub review threads and initialise counters

Fetch all review threads via GraphQL:

```bash
gh api graphql -f query='
  query($owner: String!, $repo: String!, $number: Int!) {
    repository(owner: $owner, name: $repo) {
      pullRequest(number: $number) {
        reviewThreads(first: 100) {
          nodes {
            id
            isResolved
            isOutdated
            path
            line
            comments(first: 50) {
              nodes {
                databaseId
                body
                createdAt
                author { login }
              }
            }
          }
        }
      }
    }
  }
' -F owner={owner} -F repo={repo} -F number={prNumber}
```

From the response, filter to threads where:
- `isResolved` is `false`
- `isOutdated` is `false`
- The `createdAt` of the last comment in `comments.nodes` is after `cutoff` (skip this filter if `cutoff` is null)

Initialise counters:
- `code_fixes = 0`
- `discussion_only = 0`
- `commits_pushed = 0`
- `skipped = 0`
- `skipped_list = []`

If there are no matching threads, skip to Step 11.

## Step 10 — Address each thread in series

For each thread in the filtered list, work through it completely before moving to the next.

### Classify the thread

Read all comment bodies in `thread.comments.nodes`. Also read the source file at `{repoRoot}/{thread.path}` around `thread.line` for context. Determine whether the thread requires a code change or is discussion-only.

A thread requires a code change when a reviewer explicitly asks for a modification to source code — a wording fix, a logic change, an added guard, a renamed variable, etc. A thread is discussion-only when it is a question, a clarification, praise (LGTM), or a comment that has already been addressed by other means.

### Code change required

1. Edit the relevant files to address the reviewer's request.
2. Stage only the files you changed for this thread:
   ```bash
   git add {file1} {file2} ...
   ```
   Never use `git add -A` or `git add .`.
3. Run `checkCommand` (if not null) with `cwd=repoRoot`. If it exits non-zero:
   - Unstage: `git restore --staged .`
   - Post a reply to the thread (see reply format below) explaining the check failed and the thread is being skipped.
   - Append a description of the thread to `skipped_list`.
   - Increment `skipped`.
   - Move on to the next thread.
4. Commit with a concise message describing what was changed for this thread:
   ```bash
   git commit -m "Address review: {brief description}"
   ```
5. Push:
   ```bash
   git push origin HEAD:{headRefName}
   ```
   If the push exits non-zero:
   - Undo the commit: `git reset HEAD~1`
   - If the reset itself fails, stop immediately and report: "Push failed and reset failed — repo may be in an inconsistent state."
   - If reset succeeded, append a description of the thread to `skipped_list`, increment `skipped`, move on to the next thread.
6. Record the commit SHA:
   ```bash
   git rev-parse HEAD
   ```
7. Reply to the thread with the commit SHA (see reply format below).
8. Resolve the thread (see resolve format below).
9. Increment `code_fixes` and `commits_pushed`.

### Discussion only

If the thread is pure praise or LGTM with no question or request, resolve without replying.

Otherwise reply acknowledging the comment or answering the question, then resolve. Increment `discussion_only`.

### Reply format

Post a reply to a thread using the PR review comment API. The `databaseId` for the in-reply-to parameter is `thread.comments.nodes[0].databaseId`.

```bash
jq -n --arg body "{reply body here}" '{body: $body}' \
  | gh api -X POST \
      repos/{owner}/{repo}/pulls/{prNumber}/comments/{databaseId}/replies \
      --input -
```

### Resolve format

Resolve a thread using the GraphQL `resolveReviewThread` mutation:

```bash
gh api graphql -f query='
  mutation($threadId: ID!) {
    resolveReviewThread(input: { threadId: $threadId }) {
      thread { isResolved }
    }
  }
' -F threadId="{thread.id}"
```

## Step 11 — Record a completion event

Call `friday_event_create` with:
- `type`: `"pr.feedback.addressed"`
- `user`: `"chris"`
- `source_id`: `{prUrl}`
- `payload`: `{ "code_fixes": {code_fixes}, "discussion_only": {discussion_only}, "commits_pushed": {commits_pushed}, "skipped": {skipped} }`
- `summary`: `"Addressed {code_fixes + discussion_only} thread(s) on {prUrl}"`

If this call fails, log the failure but continue — it is non-fatal.

## Step 12 — Print summary

Report the results:

```
Address feedback complete for {prUrl}

  Code fixes committed and pushed : {commits_pushed}
  Discussion threads resolved     : {discussion_only}
  Threads skipped                 : {skipped}
```

If `skipped_list` is non-empty, list each skipped thread with a short reason:

```
Skipped threads:
  - {description 1}
  - {description 2}
```
