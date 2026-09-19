---
name: custom-workflow-reauthor-pr
user-invocable: true
description: Re-authors ALL non-Chris, non-Claude commits on a GitHub PR branch — every bot account (fridaytherobot, friday, pr-signing-bot, or any other bot, not just the ones named here) — to assertchris (Christopher Pitt) as both author AND committer, preserving commit messages and ensuring every commit carries a Claude Co-Authored-By byline (never second-guessing an existing one). The only two names Chris wants visible on the PR when this is done are his and Claude's. Use when user asks to re-author a PR, claim a PR, take ownership of PR commits, or sign commits on a bot PR.
allowed-tools: Bash(git *, gh *)
---

# Re-Author PR Commits

**The only two names Chris wants to see on the PR when this is done are his (Christopher Pitt) and Claude's (via Co-Authored-By trailer). No third identity survives, ever — not `fridaytherobot`/`friday`, not `pr-signing-bot[bot]`, not any other bot or service account that shows up in the commit list. Check the actual list of distinct authors on the PR (Step 3) and treat every one of them that isn't Chris as needing rewriting — do not limit this to the specific bot names mentioned in this doc, they're examples, not an exhaustive list.**

This skill takes a GitHub PR URL, checks out the branch, and re-authors every non-Chris commit on it (author `fridaytherobot`, `friday`, `pr-signing-bot[bot]`, or any other bot/service account, depending on repo) to `assertchris` (Christopher Pitt <cgpitt@gmail.com>). This must rewrite **both** the author and the committer field — a plain `git commit --amend --author=` only changes the author, and `git rebase --exec` stamps the committer field with whatever `GIT_COMMITTER_NAME`/`GIT_COMMITTER_EMAIL`/`user.name`/`user.email` happen to resolve to in the shell doing the rebase. If that resolves to the bot's identity (it has before), GitHub renders a third avatar on every commit — bot as committer, alongside Chris as author and Claude as co-author. Force the committer identity explicitly; don't rely on ambient git config being correct. Commit messages are otherwise preserved, EXCEPT that every rewritten commit must end up with a `Co-Authored-By: Claude <model> <noreply@anthropic.com>` trailer — add it if missing.

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

Rewrite every commit whose author is not Chris — `fridaytherobot`, `friday`, `pr-signing-bot[bot]`, and any other bot/service account are all in scope, whatever name they show up under in this repo's log. Do not stop at the first bot name you recognize; list every distinct author on the branch and rewrite all of them except Chris. Leave only commits authored by human teammates (not bots) untouched.

Compute the actual merge-base rather than using the base branch's current tip — the base branch may have moved on since the PR forked, and rebasing onto its live tip pulls in unrelated upstream history alongside the author rewrite, silently changing the PR's diff:

```bash
BASE_SHA=$(git merge-base <base-branch> <head-branch>)
```

Use `$BASE_SHA` (not `<base-branch>`) as the rebase target in Step 4.

### Step 4: Rebase with author + committer rewrite and byline fix

Export the committer identity before rebasing, so every replayed commit gets it regardless of ambient git config:

```bash
export GIT_COMMITTER_NAME="Christopher Pitt"
export GIT_COMMITTER_EMAIL="cgpitt@gmail.com"
```

Use `git rebase` with `--exec` to, for every non-Chris commit: rewrite the author (the `--exec` script's own `git commit --amend --author=` call handles this; the committer comes from the exported `GIT_COMMITTER_*` vars above, inherited by the rebase's subshells), and add a `Co-Authored-By: Claude <model> <noreply@anthropic.com>` trailer only if one is entirely absent. If a commit already has any `Co-Authored-By: Claude ...` trailer, don't touch it. Match against a list of every distinct bot author email found in Step 3 — not a single hardcoded name — so a bot you haven't seen before in this repo (e.g. a code-style or CI signing bot) still gets caught. Do this with a small script rather than a one-liner, e.g.:

```bash
cat > /tmp/reauthor-fix.sh <<'SCRIPT'
#!/bin/bash
set -e
MODEL_NAME="$1"   # display name to use when a trailer is missing, e.g. "Claude Sonnet 4.5"
shift
BOT_EMAILS=("$@") # every non-Chris author email seen on this branch (Step 3) — not just one bot
CUR_EMAIL=$(git log -1 --format=%ae)
match=0
for e in "${BOT_EMAILS[@]}"; do
  if [ "$CUR_EMAIL" = "$e" ]; then match=1; fi
done
if [ "$match" -eq 0 ]; then exit 0; fi
git commit --amend --no-edit --author="Christopher Pitt <cgpitt@gmail.com>"
msg=$(git log -1 --format=%B)
if ! printf '%s' "$msg" | grep -q '^Co-Authored-By: Claude'; then
  if [ -z "$msg" ]; then
    msg=$(git log -1 --format=%s --skip=0 2>/dev/null || echo "Automated change")
  fi
  fixed=$(printf '%s\n\nCo-Authored-By: %s <noreply@anthropic.com>' "$msg" "$MODEL_NAME")
  git commit --amend -m "$fixed"
fi
SCRIPT
chmod +x /tmp/reauthor-fix.sh
git rebase "$BASE_SHA" --exec '/tmp/reauthor-fix.sh "<model-name>" "<bot-email-1>" "<bot-email-2>" ...'
```

Ask Chris which model name to use for any trailer-less commits before running this — don't guess or default to a specific version, since the right answer depends on what was actually used at the time and Chris is the authority on that, not the assistant's own (possibly stale) model knowledge.

If the rebase encounters conflicts, stop and inform Chris. Do not resolve conflicts automatically.

### Step 5: Verify

```bash
git log --format="%H author=%an<%ae> committer=%cn<%ce> %B" "$BASE_SHA"..<head-branch>
git diff <original-head-sha> <head-branch> --stat
```

Confirm all previously-bot commits now show `Christopher Pitt <cgpitt@gmail.com>` as **both** author and committer — check the API too (`gh api repos/<owner>/<repo>/pulls/<pr>/commits --jq '.[] | .commit.committer'`), since a stray bot-identity committer is exactly the kind of thing that's easy to miss in a local `git log` glance but shows up as a third avatar on the GitHub PR page. Confirm any pre-existing `Co-Authored-By: Claude ...` trailers are byte-for-byte unchanged, and that commits which previously had no trailer now have one with the model name Chris specified. The `git diff --stat` against the original (pre-rebase) head SHA should come back empty — that's proof the rebase only touched authorship/trailers and didn't drag in unrelated content from a moved base branch.

### Step 6: Force push

```bash
git push --force-with-lease origin <head-branch>
```

### Step 7: Report

Show Chris the updated commit list and the PR URL.

## Don'ts

1. **DON'T** modify commit message content beyond adding a missing Co-Authored-By trailer — leave everything else exactly as written
2. **DON'T** rewrite commits authored by human teammates — but DO rewrite every bot/service-account commit, even ones you don't recognize by name; the goal is exactly two names left in the log (Chris, Claude), never a third
3. **DON'T** resolve rebase conflicts — stop and inform Chris
4. **DON'T** use `--force` — always use `--force-with-lease`
5. **DON'T** modify the base branch or any commits outside the PR
6. **DON'T** rebase onto the base branch's current tip — use the actual merge-base (`$BASE_SHA`), so no unrelated upstream commits leak into the diff
7. **DON'T** leave a commit without a Claude Co-Authored-By trailer
8. **DON'T** change, "correct", or second-guess a model name already present in an existing trailer — the assistant's own model knowledge can be stale, Chris's word on what's a real model is authoritative
9. **DON'T** guess which model name to use for a missing trailer — ask Chris
10. **DON'T** rewrite only the author field — the committer field must also become Christopher Pitt, or the bot's identity survives as a third avatar on the PR page

## Success Criteria

- Exactly two names appear anywhere in the PR's commit log: Christopher Pitt and Claude (co-author trailer only). No bot, service account, or other third identity remains as author or committer — check the full distinct-author list, not just the bot name you expected going in.
- All non-Chris commits on the PR branch are now authored by Christopher Pitt <cgpitt@gmail.com>
- All non-Chris commits also show Christopher Pitt <cgpitt@gmail.com> as **committer**, not just author — verified via the GitHub API, not just local `git log`
- Commit message bodies are otherwise unchanged, including any pre-existing Co-Authored-By trailers
- Every commit that previously lacked a trailer now has `Co-Authored-By: Claude <model-name Chris specified> <noreply@anthropic.com>`
- Branch is force-pushed with lease
- Chris sees the updated commit log
