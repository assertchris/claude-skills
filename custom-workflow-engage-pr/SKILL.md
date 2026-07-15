---
name: custom-workflow-engage-pr
user-invocable: true
description: Push the current Edgar feature branch, open a PR using the plan doc for the description, then watch CI until it passes or fails. Use instead of custom-workflow-pr when working in the Edgar (ritdu-sports-user-engagement-platform) project.
allowed-tools: Bash, Skill
---

# Edgar Engage PR

This is a thin wrapper around `custom-workflow-pr` that derives the plan doc path from the current branch and passes it through so the PR description is generated from the plan doc rather than a `features/` doc.

## Step 1: Derive the plan doc path

1. Run `git branch --show-current` to get the current branch (e.g. `feat/2026-06-13-rate-limit-api-keys`).
2. Strip everything up to and including the first `/` to get the plan stem (e.g. `2026-06-13-rate-limit-api-keys`).
3. The plan doc path is `docs/thoughts/plans/<plan-stem>.md`.

If the branch is `main`, warn the user and stop.

If the plan doc doesn't exist at that path, warn the user and suggest running `custom-workflow-engage-plan` first.

## Step 2: Delegate to custom-workflow-pr

Invoke the `custom-workflow-pr` skill with:

- `doc-path: docs/thoughts/plans/<plan-stem>.md`
- Pass through `draft` from ARGUMENTS if present.
