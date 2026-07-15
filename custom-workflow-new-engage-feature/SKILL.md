---
name: custom-workflow-new-engage-feature
user-invocable: true
description: Start a new feature on the Edgar (ritdu-sports-user-engagement-platform) project. Asks for a brief, derives a date-stamped branch name, creates a worktree, stubs a plan doc, and registers it in docs/thoughts/README.md.
allowed-tools: Bash, AskUserQuestion
---

# Edgar New Engage Feature

The Edgar project root is always `/home/friday/Code/ritdu-sports-user-engagement-platform`.

## Step 1: Get purpose

Check `$ARGUMENTS` for a `brief:` key.

- If `brief:` is present in ARGUMENTS: use everything after `brief:` as the raw purpose. **Skip `AskUserQuestion` entirely.**
- If `brief:` is absent: call `AskUserQuestion` **directly and immediately** — do NOT write the question as text first. Ask:

  > "What is this Edgar feature for? (keep it short — a few words)"

  Provide 3 example options:
  - `"rate-limit API keys"` — describes a security hardening feature
  - `"poll embed SSR"` — describes a widget rendering feature
  - `"purge stale webhooks"` — describes a maintenance / sweeper feature

  The user will type their own answer via the **Other** field.

If the purpose is empty after sanitisation (step 2), ask again.

## Step 2: Sanitise into a slug

Transform the raw purpose into a slug:

1. Lowercase all characters
2. Replace spaces with hyphens
3. Strip any character that is not `a-z`, `0-9`, or `-`
4. Collapse multiple consecutive hyphens into one
5. Trim leading and trailing hyphens
6. **Truncate to 40 characters max**, cutting at the last `-` boundary (do not cut mid-word)

## Step 3: Determine branch name

Run:
```bash
date +%Y-%m-%d
```

The branch name is `feat/<today>-<slug>` (e.g. `feat/2026-06-13-rate-limit-api-keys`).

The plan doc filename is `<today>-<slug>.md`.

## Step 4: Pull main before creating the worktree

Before creating the worktree, ensure main is up to date:

```bash
git -C /home/friday/Code/ritdu-sports-user-engagement-platform pull origin $(git -C /home/friday/Code/ritdu-sports-user-engagement-platform rev-parse --abbrev-ref HEAD)
```

If the pull fails (e.g. no remote, offline), warn Chris but continue — do not abort.

## Step 5: Create worktree, plan stub, and README entry

Create a worktree for the branch in `/home/friday/Code/ritdu-sports-user-engagement-platform` using the friday_worktree_create MCP tool. NEVER run git commands manually — the MCP tool handles branch creation inside the worktree so the main project directory always stays on `main`. Do NOT run `git checkout`, `git branch`, or any other git command in the main project directory — it must remain on `main` throughout.

The worktree will be placed at `/home/friday/Code/ritdu-sports-user-engagement-platform/.worktrees/<branch>`.

Once the worktree exists, copy `node_modules` from the main project into the worktree using `cp -r` (not symlinks) so tools like tsc, vitest, etc. are immediately available.

Then create the plan doc stub at `<worktree>/docs/thoughts/plans/<plan-file>` with this exact content:

```
---
topic: <raw-purpose>
branch: <branch>
status: active
last_validated: <today>
---

# <raw-purpose>

## Overview

TODO

## Phases

### Phase 1: …

**Files:** …

**Tests:** …
```

Then add a new row to the table in `<worktree>/docs/thoughts/README.md`. Find the last row in the `## plans/` table and insert a new row immediately after it:
`| <plan-file> | active |`

Do not commit either file.

## Step 6: Done

Report:

> Worktree ready at: `/home/friday/Code/ritdu-sports-user-engagement-platform/.worktrees/<branch>`
>
> To work in this worktree from Claude Code CLI, exit this session and run:
> ```
> cd /home/friday/Code/ritdu-sports-user-engagement-platform/.worktrees/<branch>
> claude
> ```
