---
name: custom-reauthor-pr
user-invocable: true
description: Re-authors all commits on a GitHub PR branch from fridaytherobot to assertchris (Christopher Pitt), preserving commit messages and Co-Authored-By lines. Use when user asks to re-author a PR, claim a PR, take ownership of PR commits, or sign commits on a bot PR.
allowed-tools: Bash(git *, gh *)
---

# Re-Author PR Commits

This skill takes a GitHub PR URL, checks out the branch, and re-authors all commits on it from `fridaytherobot` to `assertchris` (Christopher Pitt <cgpitt@gmail.com>). The commit messages, including any Co-Authored-By lines, are preserved exactly.

## Process

### Step 1: Parse the PR URL

The PR URL is passed as `$ARGUMENTS`. Extract the repo and PR number from it.

```bash
gh pr view <url> --json headRefName,baseRefName,commits
```

Note the head branch name and base branch name.

### Step 2: Clone and checkout

If not already in the repo, clone it and check out the head branch:

```bash
gh repo clone <owner>/<repo> /tmp/reauthor-<repo>-<pr>
cd /tmp/reauthor-<repo>-<pr>
git checkout <head-branch>
```

If already in the correct repo, just fetch and checkout:

```bash
git fetch origin
git checkout <head-branch>
git pull origin <head-branch>
```

### Step 3: Identify commits to rewrite

Find commits on the branch that are not on the base branch:

```bash
git log --format="%H %an" <base-branch>..<head-branch>
```

Only rewrite commits where the author is `fridaytherobot`. Leave any other commits untouched.

### Step 4: Rebase with author rewrite

Use `git rebase` with `--exec` to rewrite the author on each fridaytherobot commit:

```bash
git rebase <base-branch> --exec 'if [ "$(git log -1 --format=%an)" = "fridaytherobot" ]; then git commit --amend --no-edit --author="Christopher Pitt <cgpitt@gmail.com>"; fi'
```

If the rebase encounters conflicts, stop and inform Chris. Do not resolve conflicts automatically.

### Step 5: Verify

```bash
git log --format="%H %an <%ae> %s" <base-branch>..<head-branch>
```

Confirm all previously-fridaytherobot commits now show `Christopher Pitt <cgpitt@gmail.com>` as the author, and that commit messages (including Co-Authored-By trailers) are unchanged.

### Step 6: Force push

```bash
git push --force-with-lease origin <head-branch>
```

### Step 7: Report

Show Chris the updated commit list and the PR URL.

## Don'ts

1. **DON'T** modify commit messages — only change the author field
2. **DON'T** rewrite commits that aren't authored by `fridaytherobot`
3. **DON'T** resolve rebase conflicts — stop and inform Chris
4. **DON'T** use `--force` — always use `--force-with-lease`
5. **DON'T** modify the base branch or any commits outside the PR

## Success Criteria

- All fridaytherobot commits on the PR branch are now authored by Christopher Pitt <cgpitt@gmail.com>
- Commit messages and Co-Authored-By trailers are preserved
- Branch is force-pushed with lease
- Chris sees the updated commit log
