---
name: custom-review
description: Comprehensive PR review that loops code review and blast radius analysis, repairing issues between each pass until both phases come back clean.
user-invocable: true
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr list:*), Bash(gh pr comment:*), Bash(git *)
---

# Custom Review

Run a two-phase, self-healing review loop on a pull request:

1. **Phase 1 — Code Review Loop**: Run the full code-review skill, fix everything it finds, repeat until clean (max 5 rounds).
2. **Phase 2 — Blast Radius Loop**: Run the full blast-radius skill, fix everything it finds, repeat until clean (max 5 rounds).

---

## Step 1: Get PR Reference

Parse the user's input for a PR number or GitHub PR link.

- PR number → use directly.
- PR link → extract the number.
- Nothing provided → stop and ask: "Which PR should I review? Provide a PR number or GitHub link."

Confirm the PR is open (not merged, not draft, not closed). If not open, stop and tell the user.

---

## Step 2: Phase 1 — Code Review Loop

Run the following loop up to **5 times**. Stop early if the reviewer returns clean.

### Each iteration

**Sub-agent A — Code Reviewer**

Spawn a sub-agent. Give it the PR number and this instruction:

> Run the full `/code-review` skill on PR #N. Return every issue it surfaces with confidence ≥ 80, including file path, line number, description, and confidence score. If it finds nothing significant, return `CLEAN`.

Wait for Sub-agent A to complete.

- If it returns `CLEAN`: Phase 1 is done. Move to Phase 2.
- If it returns issues: spawn Sub-agent B.

**Sub-agent B — Code Repairer**

Spawn a sub-agent. Give it the full list of issues from Sub-agent A and this instruction:

> Fix every issue in the list. Apply the minimal correct change for each one. Do not touch anything unrelated. Once all fixes are applied, stage the changed files, commit with message `fix(review): [brief description] (code-review round N)`, and push.

Wait for Sub-agent B to complete. Then start the next iteration.

If 5 rounds complete without `CLEAN`, stop and report the outstanding issues to the user.

---

## Step 3: Phase 2 — Blast Radius Loop

Run the following loop up to **5 times**. Stop early if the analyzer returns clean.

### Each iteration

**Sub-agent A — Blast Radius Analyzer**

Spawn a sub-agent. Give it the PR number and this instruction:

> Run the full `change-blast-radius` skill on PR #N. Return every RED or AMBER finding, every CRITICAL or HIGH security issue, and every Low or Medium effort test gap it surfaces. If there is nothing significant, return `CLEAN`.

Wait for Sub-agent A to complete.

- If it returns `CLEAN`: Phase 2 is done. Move to Step 4.
- If it returns findings: spawn Sub-agent B.

**Sub-agent B — Blast Radius Repairer**

Spawn a sub-agent. Give it the full findings from Sub-agent A and this instruction:

> Fix every actionable finding in the list:
> - CRITICAL/HIGH security findings: apply the minimal code fix.
> - Low/Medium effort test gaps: write the missing test.
> - RED/AMBER deployment risks that can be addressed in code: apply the fix.
> - Tenant divergences and High-effort test gaps: do NOT fix — note them for the final report instead.
>
> Once all fixes are applied, stage the changed files, commit with message `fix(review): [brief description] (blast-radius round N)`, and push.

Wait for Sub-agent B to complete. Then start the next iteration.

If 5 rounds complete without `CLEAN`, stop and report the outstanding findings to the user.

---

## Step 4: Final Report

Post a comment on the PR:

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

## Notes

- Phases run sequentially. Complete Phase 1 before starting Phase 2.
- Sub-agents run the skills whole — do not break the skills into micro-tasks.
- If a fix is ambiguous or risky, the repairer sub-agent must stop and surface it to the user before committing.
- Max 5 rounds per phase. If not clean by round 5, report and wait for instruction.
