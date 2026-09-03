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

### 3b — Address unresolved review feedback

Invoke the `custom-workflow-address-feedback` skill now. It will find the PR URL, fetch all unresolved review threads, and address them one by one.

After the skill completes, note the result for this PR.

### 3c — Check if the base branch is outdated

Fetch the base branch and check whether the PR branch has been rebased on top of it:

```bash
git fetch origin {baseRefName}
git merge-base --is-ancestor origin/{baseRefName} HEAD
```

If the command exits **0** (the base is already an ancestor of HEAD), the branch is up to date. Skip to Step 3f.

If the command exits **1** (the base has moved ahead of the PR branch), the branch is outdated. Continue to Step 3d.

### 3d — Attempt rebase, without touching authorship

This workflow's job is to keep branches current, never to change who a commit is attributed to — that's what `custom-workflow-reauthor-pr` is for, on explicit request only. A plain `git rebase` preserves the **author** of each commit automatically, but it always re-stamps the **committer** field with whatever identity the running process resolves to (`GIT_COMMITTER_NAME`/`EMAIL` env, else `user.name`/`user.email` from git config). If this maintenance workflow runs as `friday`, that silently swaps the committer to the bot on every commit it touches — which is exactly the "third avatar" bug that `custom-workflow-reauthor-pr` exists to fix, reintroduced by routine maintenance.

Record the author, committer, and any Co-Authored-By trailers for every commit in range before doing anything, so the rebase's effect can be verified:

```bash
PRE_HEAD=$(git rev-parse HEAD)
git log --format="%an <%ae> | %cn <%ce> | %(trailers:key=Co-Authored-By,valueonly)" origin/{baseRefName}..HEAD > /tmp/pre-rebase-identities.txt
```

Force the committer identity to match the author so the rebase can't drift it to the bot's identity:

```bash
export GIT_COMMITTER_NAME="Christopher Pitt"
export GIT_COMMITTER_EMAIL="cgpitt@gmail.com"
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

If this diff is **not empty** — any commit's author, committer, or Co-Authored-By trailers changed — the rebase must not be pushed:

```bash
git reset --hard "$PRE_HEAD"
```

Log this PR as `"rebase skipped — authorship guard failed, needs manual reauthor"` and move to Step 3f without pushing. Do not attempt to fix it automatically; that's a job for `custom-workflow-reauthor-pr` run deliberately, not something this maintenance pass should do as a side effect.

If the diff is empty, continue to Step 3e.

### 3e — Push the updated branch

After a successful rebase that passed the authorship guard above (whether clean or after conflict resolution), force-push:

```bash
git push --force-with-lease origin {headRefName}
```

If the push fails, log `"push failed"` for this PR and move on — do not abort the rest of the PRs.

### 3f — Record result

Append to `prResults`:
- PR URL
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
  Feedback   : {addressed N threads | no unresolved threads}
  Rebase     : {rebased cleanly | conflicts resolved | already up to date | skipped}
  Authorship : {preserved | guard blocked push — needs manual reauthor}
  Push       : {pushed | failed | not needed}

{prUrl2}
  ...
```

If any PR's authorship guard blocked a push, call that out clearly in the summary — it needs Chris to run `custom-workflow-reauthor-pr` deliberately, not a silent rebase.

If any PRs were skipped because their repo isn't in the review project list, list them separately:

```
Skipped (not in review project list):
  - {nameWithOwner} — {prUrl}
```

## Don'ts

1. **DON'T** let a routine rebase silently change any commit's author, committer, or Co-Authored-By trailers — verify with the identity diff in Step 3d before every push
2. **DON'T** try to fix an authorship-guard failure automatically — log it and move on; reauthoring is `custom-workflow-reauthor-pr`'s job, run deliberately, not a side effect of maintenance
