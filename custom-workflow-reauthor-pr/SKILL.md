---
name: custom-workflow-reauthor-pr
user-invocable: true
description: Re-authors all commits on a GitHub PR branch from fridaytherobot to assertchris (Christopher Pitt), preserving commit messages and ensuring every commit carries a Claude Co-Authored-By byline (never second-guessing an existing one). Use when user asks to re-author a PR, claim a PR, take ownership of PR commits, or sign commits on a bot PR.
allowed-tools: Bash(git *, gh *)
---

# Re-Author PR Commits

This skill takes a GitHub PR URL, checks out the branch, and re-authors all bot-authored commits on it (author `fridaytherobot` or `friday`, depending on repo) to `assertchris` (Christopher Pitt <cgpitt@gmail.com>). Commit messages are otherwise preserved, EXCEPT that every rewritten commit must end up with a `Co-Authored-By: Claude <model> <noreply@anthropic.com>` trailer — add it if missing.

**Never "correct" an existing model name in a trailer.** Claude's own knowledge of which model names are real is frequently stale (new models ship after any given session's cutoff) — a version number that looks wrong or unfamiliar may simply be a real model released after the assistant's training. Only change an existing trailer's model name if Chris explicitly says to. If a commit already has a `Co-Authored-By: Claude ...` trailer, leave it exactly as-is.

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

Only rewrite commits where the author is the bot (`fridaytherobot` or `friday` — check the actual author name/email in this repo's log, since it varies). Leave any other commits (e.g. human teammates) untouched.

Compute the actual merge-base rather than using the base branch's current tip — the base branch may have moved on since the PR forked, and rebasing onto its live tip pulls in unrelated upstream history alongside the author rewrite, silently changing the PR's diff:

```bash
BASE_SHA=$(git merge-base <base-branch> <head-branch>)
```

Use `$BASE_SHA` (not `<base-branch>`) as the rebase target in Step 4.

### Step 4: Rebase with author rewrite and byline fix

Use `git rebase` with `--exec` to, for each bot commit: rewrite the author, and add a `Co-Authored-By: Claude <model> <noreply@anthropic.com>` trailer only if one is entirely absent. If a commit already has any `Co-Authored-By: Claude ...` trailer, don't touch it. Do this with a small script rather than a one-liner, e.g.:

```bash
cat > /tmp/reauthor-fix.sh <<'SCRIPT'
#!/bin/bash
set -e
BOT_NAME="$1"     # e.g. fridaytherobot or friday
MODEL_NAME="$2"   # display name to use when a trailer is missing, e.g. "Claude Sonnet 4.5"
if [ "$(git log -1 --format=%an)" != "$BOT_NAME" ]; then exit 0; fi
git commit --amend --no-edit --author="Christopher Pitt <cgpitt@gmail.com>"
msg=$(git log -1 --format=%B)
if ! printf '%s' "$msg" | grep -q '^Co-Authored-By: Claude'; then
  fixed=$(printf '%s\n\nCo-Authored-By: %s <noreply@anthropic.com>' "$msg" "$MODEL_NAME")
  git commit --amend -m "$fixed"
fi
SCRIPT
chmod +x /tmp/reauthor-fix.sh
git rebase "$BASE_SHA" --exec '/tmp/reauthor-fix.sh <bot-name> "<model-name>"'
```

Ask Chris which model name to use for any trailer-less commits before running this — don't guess or default to a specific version, since the right answer depends on what was actually used at the time and Chris is the authority on that, not the assistant's own (possibly stale) model knowledge.

If the rebase encounters conflicts, stop and inform Chris. Do not resolve conflicts automatically.

### Step 5: Verify

```bash
git log --format="%H %an <%ae> %B" "$BASE_SHA"..<head-branch>
git diff <original-head-sha> <head-branch> --stat
```

Confirm all previously-bot commits now show `Christopher Pitt <cgpitt@gmail.com>` as the author, that any pre-existing `Co-Authored-By: Claude ...` trailers are byte-for-byte unchanged, and that commits which previously had no trailer now have one with the model name Chris specified. The `git diff --stat` against the original (pre-rebase) head SHA should come back empty — that's proof the rebase only touched authorship/trailers and didn't drag in unrelated content from a moved base branch.

### Step 6: Force push

```bash
git push --force-with-lease origin <head-branch>
```

### Step 7: Report

Show Chris the updated commit list and the PR URL.

## Don'ts

1. **DON'T** modify commit message content beyond adding a missing Co-Authored-By trailer — leave everything else exactly as written
2. **DON'T** rewrite commits that aren't authored by the bot
3. **DON'T** resolve rebase conflicts — stop and inform Chris
4. **DON'T** use `--force` — always use `--force-with-lease`
5. **DON'T** modify the base branch or any commits outside the PR
6. **DON'T** rebase onto the base branch's current tip — use the actual merge-base (`$BASE_SHA`), so no unrelated upstream commits leak into the diff
7. **DON'T** leave a commit without a Claude Co-Authored-By trailer
8. **DON'T** change, "correct", or second-guess a model name already present in an existing trailer — the assistant's own model knowledge can be stale, Chris's word on what's a real model is authoritative
9. **DON'T** guess which model name to use for a missing trailer — ask Chris

## Success Criteria

- All bot commits on the PR branch are now authored by Christopher Pitt <cgpitt@gmail.com>
- Commit message bodies are otherwise unchanged, including any pre-existing Co-Authored-By trailers
- Every commit that previously lacked a trailer now has `Co-Authored-By: Claude <model-name Chris specified> <noreply@anthropic.com>`
- Branch is force-pushed with lease
- Chris sees the updated commit log
