---
name: custom-workflow-engage-implement
user-invocable: true
description: Run phased implementation of an Edgar feature. Reads the plan doc from docs/thoughts/plans/ (derived from the current branch), works through each phase in a sub-agent, and verifies completion via git log between phases.
allowed-tools: Bash, Skill
---

# Edgar Engage Implement

This is a thin wrapper around `custom-workflow-implement` with Edgar-specific defaults.

## Step 1: Derive the plan doc path

1. Run `git branch --show-current` to get the current branch (e.g. `feat/2026-06-13-rate-limit-api-keys`).
2. Strip everything up to and including the first `/` to get the plan stem (e.g. `2026-06-13-rate-limit-api-keys`).
3. The plan doc path is `docs/thoughts/plans/<plan-stem>.md`.

If the branch is `main`, warn the user and stop — implementation should run on a feature branch.

If the plan doc doesn't exist, warn the user and suggest running `custom-workflow-new-engage-feature` and `custom-workflow-engage-plan` first.

## Step 2: Delegate to custom-workflow-implement

Invoke the `custom-workflow-implement` skill with these arguments:

- `doc-path: docs/thoughts/plans/<plan-stem>.md`
- `impl-context:` Edgar is a multi-tenant Fastify API (`packages/api`), React 19 admin panel (`packages/admin`), and shared types (`packages/shared`).
- `pre-commit:` `pnpm typecheck && pnpm --filter @edgar/api test:fast` (if the phase touches a `@slow`-tagged test suite, also run that file directly)
- `completion-via: git-log`
