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

If that returns a non-empty URL, use it. If it fails or returns nothing, search the session context for a GitHub PR URL. If still not found, call `friday_messages_list` with the current session's topic ID (the numeric suffix of the session scope, e.g. `user::chris::96` → topic ID `96`) and scan the returned messages for a PR URL matching the current branch name.

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
- `deferred_list = []`

If there are no matching threads, skip to Step 11.

## Step 10 — Address each thread in series

For each thread in the filtered list, work through it completely before moving to the next.

### Classify the thread

Read all comment bodies in `thread.comments.nodes`. Also read the source file at `{repoRoot}/{thread.path}` around `thread.line` for context. Determine which of three categories the thread falls into: **revert/drastic change**, **code change**, or **discussion-only**.

A thread is a **revert or drastic change** when the reviewer asks to:
- Remove or undo something Friday wrote (revert, delete, roll back, take it out)
- Completely rewrite or redesign a section (start over, do it differently, wrong approach)
- Replace an implementation with a fundamentally different one

Do not conflate this with minor fixes (rename, add a guard, fix a typo) — those are ordinary code changes.

A thread requires a **code change** when a reviewer explicitly asks for a targeted modification to source code — a wording fix, a logic change, an added guard, a renamed variable, etc.

A thread is **discussion-only** when it is a question, a clarification, praise (LGTM), or a comment that has already been addressed by other means.

### Revert or drastic change requested

Do not act on this thread. Add an entry to `deferred_list` with:
- The thread ID
- The file path and line
- A one-sentence summary of what the reviewer is asking for

Skip to the next thread. These will be presented to Chris before any action is taken on them.

### Code change required

**Before making any edit, assess whether you agree with the feedback.**

This code has already been through Chris's full review cycle: he reviewed the research, the plan, the implementation, and every line in the PR. A reviewer (or automated bot) may raise valid points — but they may also be wrong. Do not treat reviewer feedback as ground truth.

Ask yourself: is the reviewer's suggestion actually correct? Does it improve the code, or does it introduce a different problem, miss context, or conflict with the design intent?

- If you **agree** the feedback is correct: proceed with the fix as normal.
- If you **disagree** or are **uncertain**: add the thread to `deferred_list` with your assessment (what the reviewer said, why you think they may be wrong, and what you'd recommend instead). Do not implement the change. Present it to Chris at Step 10.5.

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

**Get to the point. You are not paid by the word. The more you write, the less people read.**

Replies must be short and direct. The bulk of every reply must resemble one of these two shapes:

- For a fix: "X was wrong. Fixed by doing Y (in commit `{sha}`)."
- For pushback or a question: "X is wrong for these reasons. I recommend Y instead."

**Confidence rule:** Friday is the author of this code and stands behind it. When disagreeing with a reviewer, be direct and give a reason — don't hedge or apologise. If genuinely uncertain whether the reviewer has a point, say so plainly and ask Chris before replying. Never capitulate to a reviewer just to avoid conflict.

Do not pad, hedge, thank the reviewer, or explain the broader context unless it is genuinely load-bearing and non-obvious. One or two sentences is the target. Three is the ceiling.

Before posting any reply, pass the draft body through the writing style guide via a sub-agent so the main session isn't blocked.

Spawn a sub-agent with model `haiku` and the following prompt:

> Read `~/.claude/skills/custom-writing-style-guide/style-guide.md`. Then rewrite the following text to match the style guide exactly. Keep it short and direct — one to three sentences maximum. Return only the rewritten text — no commentary, no explanation.
>
> {draft reply text}

Use the sub-agent's returned text as the final reply body.

Then post the reply using the PR review comment API. The `databaseId` for the in-reply-to parameter is `thread.comments.nodes[0].databaseId`.

```bash
jq -n --arg body "{final reply body after style guide}" '{body: $body}' \
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

## Step 10.5 — Present deferred threads to Chris

If `deferred_list` is non-empty, stop and present the list before doing anything else:

```
The following threads were deferred — either because they ask for a revert/drastic change,
or because I disagree with the reviewer's suggestion. I haven't touched them.

{for each entry in deferred_list}
  [{index}] {file path}:{line}
      Reviewer: {one-sentence summary of what the reviewer is asking}
      My take:  {one-sentence assessment — why I disagree or what I'd recommend instead, or "drastic change — your call"}
{end}

How would you like to handle each one?
```

Wait for Chris's instructions on each deferred thread. Do not proceed to Step 11 until he has responded. If he says to skip one, add it to `skipped_list`. If he says to address one, re-classify it as a code change and handle it immediately (make the edit, run checks, commit, push, reply, resolve) before moving to his next instruction.

## Step 11 — Re-request review from addressed reviewers

Only proceed with re-requesting if there are **zero** remaining unresolved threads on the PR. If any unresolved threads remain (e.g. because some were skipped), set `rerequestedReviewers` to `[]` and skip the rest of this step — do not re-request while feedback is still open.

Collect the unique GitHub logins of every reviewer who left a comment in the threads you addressed (both code-fix and discussion-only threads). Exclude the PR author and the `github-actions` bot.

Before re-requesting, fetch the current review states for the PR:

```bash
gh api repos/{owner}/{repo}/pulls/{prNumber}/reviews --jq '[.[] | {login: .user.login, state: .state}]'
```

From the collected logins, exclude any reviewer whose most recent review state is `"APPROVED"`. They have already accepted the PR — re-requesting would unnecessarily reset their approval. Only re-request reviewers whose most recent state is `"CHANGES_REQUESTED"`, `"COMMENTED"`, `"DISMISSED"`, or who have no review state at all.

For each remaining reviewer login, re-request their review:

```bash
gh api -X POST repos/{owner}/{repo}/pulls/{prNumber}/requested_reviewers \
  --field 'reviewers[]={reviewerLogin}'
```

If the request fails for a reviewer (e.g. they are no longer a collaborator), log the failure but continue with the remaining reviewers. Do not stop the skill.

After sending re-requests, note which logins were successfully re-requested as `rerequestedReviewers`.

## Step 13 — Record a completion event

Call `friday_event_create` with:
- `type`: `"pr.feedback.addressed"`
- `user`: `"chris"`
- `source_id`: `{prUrl}`
- `payload`: `{ "code_fixes": {code_fixes}, "discussion_only": {discussion_only}, "commits_pushed": {commits_pushed}, "skipped": {skipped}, "rerequested_reviewers": {rerequestedReviewers} }`
- `summary`: `"Addressed {code_fixes + discussion_only} thread(s) on {prUrl}"`

If this call fails, log the failure but continue — it is non-fatal.

## Step 14 — Print summary

Report the results:

```
Address feedback complete for {prUrl}

  Code fixes committed and pushed : {commits_pushed}
  Discussion threads resolved     : {discussion_only}
  Threads skipped                 : {skipped}
  Review re-requested from        : {rerequestedReviewers joined by ", " or "none"}
```

If any deferred threads were handled during Step 10.5, include them in the totals above.

If `skipped_list` is non-empty, list each skipped thread with a short reason:

```
Skipped threads:
  - {description 1}
  - {description 2}
```
