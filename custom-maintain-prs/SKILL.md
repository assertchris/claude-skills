---
name: custom-maintain-prs
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

### 3d — Attempt rebase

```bash
git rebase origin/{baseRefName}
```

If the rebase **succeeds** (exit 0 and no conflict markers), skip to Step 3e.

If the rebase **fails with conflicts**:

```bash
git rebase --abort
```

Then invoke the `custom-conflict-resolution` skill. That skill will re-attempt the rebase, resolve conflicts file by file, and complete the rebase.

After the skill completes, continue to Step 3e.

### 3e — Push the updated branch

After a successful rebase (whether clean or after conflict resolution), force-push:

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
- Whether the push succeeded

## Step 4 — Print summary

After all PRs have been processed, print a summary table:

```
PR Maintenance Complete

{prUrl}
  Feedback : {addressed N threads | no unresolved threads}
  Rebase   : {rebased cleanly | conflicts resolved | already up to date | skipped}
  Push     : {pushed | failed | not needed}

{prUrl2}
  ...
```

If any PRs were skipped because their repo isn't in the review project list, list them separately:

```
Skipped (not in review project list):
  - {nameWithOwner} — {prUrl}
```
