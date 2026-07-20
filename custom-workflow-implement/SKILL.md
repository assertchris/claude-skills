---
name: custom-workflow-implement
user-invocable: true
description: Run phased implementation from the current branch's feature doc. Works through each phase in a sub-agent, verifying completion between phases.
allowed-tools: Bash, Agent
---

# Implement

## Parameters (from ARGUMENTS)

| Key | Purpose | Default |
|---|---|---|
| `doc-path:` | Explicit path to the plan doc (skips feature doc discovery) | — |
| `impl-context:` | Extra context prepended to each sub-agent implementation prompt | — |
| `pre-commit:` | Shell commands to run before committing (newline or semicolon separated) | `npm run check` |
| `completion-via:` | How to check phase completion: `progress` (Progress section in doc) or `git-log` (commit message starts with `Phase N:`) | `progress` |

## Step 1: Resolve the plan doc path

Check `$ARGUMENTS` for a `doc-path:` key.

- If `doc-path:` is present: use it directly. Skip feature doc discovery.
- If `doc-path:` is absent:
  1. Run `git branch --show-current` to get the branch name.
  2. Strip the type prefix (everything up to and including the first `/`) to get the stem (e.g. `feature/2026-07-20-add-auth` → `2026-07-20-add-auth`). The feature doc is `features/<stem>.md`.

If on `main` and no `doc-path:` was given, warn the user and stop — implementation should run on a feature branch.

## Step 2: Resolve parameters

- **`impl-context:`** — extract from ARGUMENTS, or use empty string.
- **`pre-commit:`** — extract from ARGUMENTS, or default to `npm run check`.
- **`completion-via:`** — extract from ARGUMENTS, or default to `progress`.

## Step 3: Find incomplete phases

Read the plan doc. It contains phases as headings (e.g. `### Phase 1 — Title` or `### Phase 1: Title`).

Determine which phases are already complete based on `completion-via:`:

- **`progress`**: The Progress section at the bottom of the doc tracks Completed / In Progress / To Do. Any phase listed under "Completed" is done — skip it.
- **`git-log`**: Run `git log --oneline`. Any commit whose message starts with `Phase N:` means that phase is complete — skip it.

## Step 4: Implement each incomplete phase

For each incomplete phase, in order:

1. Launch a sub-agent (using the Agent tool) with the following prompt:

   "[impl-context, if any]

   You are implementing a single phase of a feature. Here is what to do:

   Phase: [phase number and title from the plan doc]

   Instructions:
   - Read CLAUDE.md for pre-commit checks, code style rules, and testing conventions
   - Read the plan doc at [path] for full context on this phase
   - Implement ONLY this phase
   - Run the following pre-commit checks and fix any issues: [pre-commit commands]
   - [If completion-via is 'progress':] Update the plan doc's Progress section: move this phase from To Do/In Progress to Completed
   - Commit all changes with a message starting with 'Phase N: ' (e.g. 'Phase 1: Add Question types and extend PlanState')

   Do NOT work on any other phase. Stop after committing."

2. After the sub-agent finishes, verify completion based on `completion-via:`:
   - **`progress`**: Re-read the plan doc's Progress section. Confirm this phase now appears under "Completed".
   - **`git-log`**: Run `git log --oneline -5`. Confirm the most recent commit starts with `Phase N:` for this phase.
   - If verification fails, tell the user which phase failed and stop — do not continue.

3. Move to the next incomplete phase.

When all phases are done, tell the user: "All phases complete."

If every phase is already complete, report "All phases already complete."
