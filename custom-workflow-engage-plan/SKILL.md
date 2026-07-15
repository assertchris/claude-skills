---
name: custom-workflow-engage-plan
user-invocable: true
description: Plan phased work for the current Edgar feature branch. Asks for a brief, researches the codebase via sub-agents, and writes the plan to docs/thoughts/plans/.
allowed-tools: Bash, Skill
---

# Edgar Engage Plan

This is a thin wrapper around `custom-workflow-plan` with Edgar-specific defaults.

## Step 1: Derive the plan doc path

1. Run `git branch --show-current` to get the current branch (e.g. `feat/2026-06-13-rate-limit-api-keys`).
2. Strip everything up to and including the first `/` to get the plan stem (e.g. `2026-06-13-rate-limit-api-keys`).
3. The plan doc path is `docs/thoughts/plans/<plan-stem>.md`.

If the branch is `main`, warn the user — plan docs should be written on a feature branch. Suggest running `custom-workflow-new-engage-feature` first and stop.

## Step 2: Delegate to custom-workflow-plan

Invoke the `custom-workflow-plan` skill with these arguments:

- `doc-path: docs/thoughts/plans/<plan-stem>.md`
- `research-context:` Edgar is a multi-tenant Fastify API in `packages/api`, with a React 19 admin panel in `packages/admin` and shared types in `packages/shared`. Note existing conventions: service modules in `packages/api/src/services/`, routes in `packages/api/src/routes/`, tests in `packages/api/test/integration/`. For large files you need only to summarise, prefer using the haiku model.
- `post-write:` a shell snippet that ensures `docs/thoughts/README.md` has a row for this plan file in the plans table. Find the plans table, check whether a row for `<plan-stem>.md` already exists; if not, append `| <plan-stem>.md | active |` as a new row at the end of the table.
- Pass through any `brief:` from ARGUMENTS unchanged.
