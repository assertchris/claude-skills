---
name: custom-workflow-maintain-prs
user-invocable: true
description: Maintain all open PRs — address unresolved review feedback, rebase outdated branches, and resolve merge conflicts. Run this to keep all open PRs clean and up to date.
allowed-tools: Bash, Agent, Read, Edit, Glob, mcp__friday__friday_github_search_prs, mcp__friday__friday_pr_review_list_projects
---

# Maintain Open PRs

Keeps all open pull requests in a healthy state by addressing review feedback, rebasing outdated branches, and resolving merge conflicts.

## Step 1 — Discover all open PRs

Search for all open PRs authored by the authenticated user across all repos:

```bash
gh search prs --author @me --state open --json url,headRefName,baseRefName,number,repository --limit 50
```

Parse the JSON array. Each item has:
- `url` — full GitHub PR URL
- `headRefName` — the PR's feature branch name
- `baseRefName` — the base branch (e.g. `main`)
- `number` — PR number
- `repository.nameWithOwner` — e.g. `RingierIMU/ritdu-sports`

If the list is empty, print "No open PRs found." and stop.

Store the list as `prs`. Initialise a results log `prResults = []`.

## Step 2 — Discover local repo paths

Call `friday_pr_review_list_projects`. This returns a map of `nameWithOwner → localPath` for all repos configured for PR review (e.g. `{ "RingierIMU/ritdu-sports": "/home/friday/Code/ritdu-sports" }`).

Store this as `repoPaths`.

For each PR in `prs`, look up `repository.nameWithOwner` in `repoPaths` to get its `localPath`. If a repo is not in `repoPaths`, skip all its PRs and log them as `"skipped (not in review project list)"`.

## Step 3 — Process each PR

For each PR in `prs` (process sequentially, never in parallel):

### 3a — Navigate and set up

```bash
cd {localPath}
git fetch origin
```

Check if the branch exists locally:

```bash
git branch --list {headRefName}
```

If not, create a local tracking branch:

```bash
git checkout -b {headRefName} origin/{headRefName}
```

Otherwise check out the branch:

```bash
git checkout {headRefName}
git reset --hard origin/{headRefName}
```

### 3b — Check CI status and blocking labels

**⚠️ IMPORTANT: This check determines whether the PR is silently unmergeable and must alert Chris.**

Check the PR's current CI status:

```bash
gh pr checks {number} --repo {nameWithOwner} --json name,state,conclusion 2>&1
```

Determine the overall CI result:
- If all checks pass (all `conclusion == "success"` or `state == "SUCCESS"`) → `CI_STATUS = "green"`
- If any check is still pending/in progress → `CI_STATUS = "pending"`
- If any check has failed → `CI_STATUS = "failing"`
- If no checks exist → `CI_STATUS = "none"`

Also check for blocking labels:

```bash
gh pr view {number} --repo {nameWithOwner} --json labels --jq '.labels[].name'
```

A label is considered **blocking** (intentionally preventing merge) if it matches any of these (case-insensitive): `do not merge`, `do-not-merge`, `dnm`, `wip`, `hold`, `blocked`, `on hold`, `not ready`.

- If any blocking label is present → `HAS_BLOCKING_LABEL = true`
- Otherwise → `HAS_BLOCKING_LABEL = false`

**Flag logic:**
- If `CI_STATUS == "failing"` AND `HAS_BLOCKING_LABEL == false` → mark this PR as `NEEDS_ATTENTION = true` (CI is broken and there's no label explaining why it shouldn't merge — this PR is unexpectedly unmergeable)
- All other combinations → `NEEDS_ATTENTION = false`

### 3c — Address unresolved review feedback

Invoke the `custom-workflow-address-feedback` skill now. It will find the PR URL, fetch all unresolved review threads, and address them one by one.

After the skill completes, note the result for this PR.

### 3d — Check if the base branch is outdated

Fetch the base branch and check whether the PR branch has been rebased on top of it:

```bash
git fetch origin {baseRefName}
git merge-base --is-ancestor origin/{baseRefName} HEAD
```

If the command exits **0** (the base is already an ancestor of HEAD), the branch is up to date. Skip to Step 3f.

If the command exits **1** (the base has moved ahead of the PR branch), the branch is outdated. Continue to Step 3d.

### 3e — Attempt rebase, without touching authorship

**The authorship guard exists for one reason:** sometimes commits on a branch have been deliberately reauthored — e.g. the committer was changed from `friday <friday@assertchris.dev>` to `Christopher Pitt <cgpitt@gmail.com>` — and a rebase must never silently erase that intentional identity change. The guard detects this by comparing identities before and after the rebase. If the rebase changed any identity that was *already non-friday* before the rebase, the push is blocked.

Critically: **do NOT set `GIT_COMMITTER_NAME` or `GIT_COMMITTER_EMAIL` env vars.** Let git use whatever identity is configured. If the pre-rebase commits are all `friday`, the post-rebase commits will also be all `friday`, and the diff will be empty. If a commit was deliberately reauthored to something else before this workflow ran, a plain rebase would reset it back to `friday` — that diff will be non-empty, and the guard correctly blocks the push.

Record the author, committer, and any Co-Authored-By trailers for every commit in range before doing anything:

```bash
PRE_HEAD=$(git rev-parse HEAD)
git log --format="%an <%ae> | %cn <%ce> | %(trailers:key=Co-Authored-By,valueonly)" origin/{baseRefName}..HEAD > /tmp/pre-rebase-identities.txt
```

Rebase without overriding any identity env vars:

```bash
git rebase origin/{baseRefName}
```

If the rebase **fails with conflicts**:

```bash
git rebase --abort
```

Then invoke the `custom-conflict-resolution` skill. That skill will re-attempt the rebase, resolve conflicts file by file, and complete the rebase. After it completes, continue below.

**After any rebase that completes (clean or via conflict resolution), verify authorship was preserved before pushing:**

```bash
git log --format="%an <%ae> | %cn <%ce> | %(trailers:key=Co-Authored-By,valueonly)" origin/{baseRefName}..HEAD > /tmp/post-rebase-identities.txt
diff /tmp/pre-rebase-identities.txt /tmp/post-rebase-identities.txt
```

If this diff is **not empty** — any commit's author, committer, or Co-Authored-By trailers changed — the rebase silently erased a deliberate identity and must not be pushed:

```bash
git reset --hard "$PRE_HEAD"
```

Log this PR as `"rebase skipped — authorship guard tripped"` and move to Step 3f without pushing.

If the diff is empty, continue to Step 3e.

### 3f — Push the updated branch

After a successful rebase that passed the authorship guard above (whether clean or after conflict resolution), force-push:

```bash
git push --force-with-lease origin {headRefName}
```

If the push fails, log `"push failed"` for this PR and move on — do not abort the rest of the PRs.

### 3g — Record result

Append to `prResults`:
- PR URL
- CI status (`green` / `pending` / `failing` / `none`)
- Whether a blocking label is present (and which labels)
- Whether this PR needs attention (`NEEDS_ATTENTION`)
- Whether feedback was addressed (and how many threads)
- Whether a rebase was performed
- Whether conflicts were resolved
- Whether the authorship guard passed (or blocked the push)
- Whether the push succeeded

## Step 4 — Print summary

After all PRs have been processed, print a summary table:

```
PR Maintenance Complete

{prUrl}
  CI         : {green | pending | failing | none}
  Labels     : {blocking: do-not-merge | none}
  Feedback   : {addressed N threads | no unresolved threads}
  Rebase     : {rebased cleanly | conflicts resolved | already up to date | skipped}
  Authorship : {preserved | guard tripped — push blocked}
  Push       : {pushed | failed | not needed}

{prUrl2}
  ...
```

**⚠️ NEEDS ATTENTION — print this section prominently if any PRs have `NEEDS_ATTENTION = true`:**

```
⚠️  The following PRs have failing CI and no blocking label — they are currently unmergeable:

  - {prUrl}  [{failingCheckNames}]
  - {prUrl2} [{failingCheckNames}]

These need your attention before they can merge.
```

Call out any tripped authorship guards clearly in the summary.

If any PRs were skipped because their repo isn't in the review project list, list them separately:

```
Skipped (not in review project list):
  - {nameWithOwner} — {prUrl}
```

## Don'ts

1. **DON'T** set `GIT_COMMITTER_NAME` or `GIT_COMMITTER_EMAIL` env vars during the rebase — doing so guarantees the identity diff will be non-empty for any non-friday commit and defeats the guard entirely
2. **DON'T** push after a rebase if the identity diff is non-empty — that means the rebase silently erased a deliberate identity change; reset to `PRE_HEAD` and skip
3. **DO** understand why the guard exists: if someone deliberately reauthored a commit to `Christopher Pitt <cgpitt@gmail.com>`, a plain rebase would reset it back to `friday <friday@assertchris.dev>` — the guard catches that and blocks the push
