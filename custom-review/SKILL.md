---
name: custom-review
description: Comprehensive PR review that loops code review and blast radius analysis, repairing issues between each pass until both phases come back clean.
user-invocable: true
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr list:*), Bash(gh pr comment:*), Bash(gh pr create:*), Bash(gh pr merge:*), Bash(git *), Read, Edit, Write, Glob
---

# Custom Review

Run a two-phase, self-healing review loop on a pull request. The review operates in one of two modes depending on whose PR is being reviewed.

---

## Step 1: Determine Mode

### Get the PR reference

Parse the user's input for a PR number or GitHub PR link.

- PR number → use directly.
- PR link → extract the number.
- Nothing provided → stop and ask: "Which PR should I review? Provide a PR number or GitHub link."

Confirm the PR is open (not merged, not draft, not closed). If not open, stop and tell the user.

Fetch PR metadata:

```bash
gh pr view <number> --json number,title,headRefName,baseRefName,author,url
```

### Determine the mode

**Mode A — Own PR**: The PR's author matches Chris's GitHub username (`assertchris`), AND the current working branch already matches the PR's `headRefName`. In this case, fixes go directly onto the PR branch — no separate review branch is needed.

**Mode B — Someone else's PR (automated review)**: The PR belongs to a different author, OR the current branch does not match the PR's head branch. In this case, a new review branch must be created.

---

## Step 2 (Mode B only): Set Up Review Worktree and Branch

Skip this step entirely for Mode A.

### Check out the PR branch into a new worktree

```bash
# Fetch the PR branch
git fetch origin <headRefName>

# Create a worktree for the PR branch (do not disturb the current worktree)
git worktree add /tmp/review-<pr-number> origin/<headRefName>
```

All subsequent git operations in Mode B run inside `/tmp/review-<pr-number>`.

### Create a review branch off the PR branch

```bash
cd /tmp/review-<pr-number>
git checkout -b review/<pr-number>-<slug>
# <slug> is the PR title lowercased, spaces replaced with hyphens, max 40 chars
git push -u origin review/<pr-number>-<slug>
```

Record:
- **Review worktree**: `/tmp/review-<pr-number>`
- **Review branch**: `review/<pr-number>-<slug>`
- **Target branch** (what the review PR will merge into): `<headRefName>` (the original PR's branch — NOT main)

All commits during the review go to the review branch. Never commit directly to `<headRefName>`.

---

## Step 3: Phase 1 — Code Review Loop

Run the following loop up to **5 times**. Stop early if the review comes back clean.

### Working directory

- Mode A: current worktree root.
- Mode B: `/tmp/review-<pr-number>`.

### Each iteration

**Review (main agent)**

Invoke the `/code-review` skill directly on PR #N. Do not spawn a sub-agent for this — run it inline. Collect every issue it surfaces with confidence ≥ 80.

- If no significant issues: Phase 1 is done. Move to Phase 2.
- If issues found: spawn the repairer.

**Sub-agent — Code Repairer**

Spawn a sub-agent. Give it the full issue list, the absolute working directory path, and this instruction:

> You are a code repairer. Your job is to fix code issues and commit the result. You MUST commit and push before returning — do not summarise, do not report, do not stop at "here's what I'd change." Actually change the files, then commit and push.
>
> Working directory: [absolute path — Mode A: project root, Mode B: /tmp/review-<pr-number>]
>
> For each issue in the list:
> 1. Read the file at the given path.
> 2. Apply the minimal correct fix. Do not touch anything unrelated.
> 3. Write the fix back.
>
> Once all files are fixed:
> 4. `git add` each changed file by name (do NOT use `git add .`).
> 5. `git commit -m "fix(review): [brief description] (code-review round N)"`
> 6. `git push`
>
> Return the commit SHA and a one-line summary of what was fixed. If you cannot fix an issue, say why — but still commit and push everything else.

Wait for the repairer to complete. Then start the next iteration.

If 5 rounds complete without a clean pass, stop and report the outstanding issues to the user.

---

## Step 4: Phase 2 — Blast Radius Loop

Run the following loop up to **5 times**. Stop early if the analysis comes back clean.

### Each iteration

**Analysis (main agent)**

Invoke the `change-blast-radius` skill directly on PR #N. Do not spawn a sub-agent for this — run it inline. Collect every RED or AMBER finding, every CRITICAL or HIGH security issue, and every Low or Medium effort test gap.

- If nothing significant: Phase 2 is done. Move to Step 5.
- If findings: spawn the repairer.

**Sub-agent — Blast Radius Repairer**

Spawn a sub-agent. Give it the full findings list and the working directory, and this instruction:

> You are a code repairer. Your job is to fix code issues and push the result. You MUST push before returning.
>
> Working directory: [absolute path — Mode A: project root, Mode B: /tmp/review-<pr-number>]
>
> Fix every actionable finding in the list:
> - CRITICAL/HIGH security findings: apply the minimal code fix.
> - Low/Medium effort test gaps: write the missing test.
> - RED/AMBER deployment risks that can be addressed in code: apply the fix.
> - Tenant divergences and High-effort test gaps: do NOT fix — note them for the final report instead.
>
> Once all files are fixed:
> 1. `git add` each changed file by name (do NOT use `git add .`).
> 2. `git commit -m "fix(review): [brief description] (blast-radius round N)"`
> 3. `git push` — this is MANDATORY. Do not return without running this command and confirming it succeeded.

Wait for the repairer to complete. Then start the next iteration.

If 5 rounds complete without a clean pass, stop and report the outstanding findings to the user.

---

## Step 5: Final Report

Post a comment on the PR being reviewed:

```bash
gh pr comment <number> --body "<report>"
```

Report format:

```markdown
# Review Complete: [PR title] (#[number])

**Code review rounds**: N | **Blast radius rounds**: N

## What was fixed
[Bullet list of every issue fixed across all rounds, grouped by phase.]

## Still requires human attention
[Tenant divergences, High-effort test gaps, or anything that could not be automatically repaired. Empty if none.]

## QA Readiness
| Area | Status | Summary |
|------|--------|---------|
| Security | GREEN/AMBER/RED | [one line] |
| Test coverage | GREEN/AMBER/RED | [one line] |
| Tenant safety | GREEN/AMBER/RED | [one line] |
| Deployment risk | GREEN/AMBER/RED | [one line] |
| **Overall** | **GREEN/AMBER/RED** | **[Ready / Blocked — reason]** |
```

Present the report to the user and call out anything still requiring human attention.

---

## Step 6 (Mode B only): Offer to Open a Review PR

Skip this step entirely for Mode A.

After presenting the report, present a summary to Chris covering:

1. What the review found.
2. What changes were made on the review branch (`review/<pr-number>-<slug>`).
3. What a fix PR would target: **review branch → `<headRefName>`** (the original PR's branch, NOT main).

Then ask:

> "Do you want me to open a PR for these review changes? It would target `<headRefName>` (PR #<pr-number>'s branch), not main."

**Wait for explicit confirmation before doing anything.**

- If Chris says yes: open the PR.
- If Chris says no or does not respond: stop. Do not open a PR automatically under any circumstances.

### Opening the review PR (only on explicit approval)

```bash
gh pr create \
  --title "Review fixes for PR #<pr-number>: <PR title>" \
  --body "$(cat <<'EOF'
## Review fixes for PR #<pr-number>

This PR contains automated review fixes for #<pr-number> ([PR title]).

**What it fixes:**
[Bullet list of fixes from the Step 5 "What was fixed" section — one line per fix.]

**To merge:** merge this PR into `<headRefName>` before landing PR #<pr-number>.
EOF
)" \
  --base <headRefName> \
  --head review/<pr-number>-<slug>
```

### Clean up the worktree

After the PR is opened (or after Chris declines), remove the temporary worktree:

```bash
git worktree remove /tmp/review-<pr-number> --force
```

---

## Notes

- Phases run sequentially. Complete Phase 1 before starting Phase 2.
- Sub-agents run the skills whole — do not break the skills into micro-tasks.
- **Repairer sub-agents MUST run `git push` as their final act.** A repair that is not pushed never happened. Do not return from a repairer sub-agent without confirming `git push` exited 0.
- If a fix is ambiguous or risky, the repairer sub-agent must surface it to the user — but still commit and push everything else first.
- Max 5 rounds per phase. If not clean by round 5, report and wait for instruction.
- **Never commit directly to the original PR's head branch in Mode B.** All commits go to the review branch only.
- **Never open a review PR automatically.** Always ask first and wait for an explicit yes.
