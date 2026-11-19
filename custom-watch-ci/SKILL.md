---
name: custom-watch-ci
user-invocable: true
description: Watch CI for a PR and loop until green — polls checks, skips label-related failures, attempts to fix real failures (lint, tests, build), commits and pushes, then re-polls. Stops after max fix attempts.
allowed-tools: Bash, Read, Edit, Glob
---

# Watch CI Until Green

Polls a PR's CI checks in a loop. Skips failures caused by label-enforcement checks. For real failures (lint, tests, build), reads the failure logs, fixes the code locally, verifies locally, commits, pushes, then re-polls. Stops when all checks pass or max fix attempts are reached.

## Parameters (from ARGUMENTS)

| Key | Purpose | Default |
|---|---|---|
| `pr-url:` | Full GitHub PR URL to watch | auto-discovered via `gh pr view` |
| `max-attempts:` | Max fix attempts before giving up | `3` |

---

## Step 1 — Discover PR context

If `pr-url:` is in ARGUMENTS, use it. Otherwise run:

```bash
gh pr view --json url,headRefName,baseRefName,number 2>/dev/null
```

If this fails or returns nothing, stop: "Could not find a PR for the current branch. Pass pr-url: explicitly."

Store `prUrl`, `headRefName`, `baseRefName`, `prNumber`.

Extract `owner` and `repo` from `prUrl` — the form is `https://github.com/{owner}/{repo}/pull/{number}`.

Store `repoRoot`:

```bash
git rev-parse --show-toplevel
```

## Step 2 — Discover local check command

Look for a check command in this order:

1. `{repoRoot}/package.json` — if a `check` script exists, use `npm run check`. If only `test` exists, use `npm test`.
2. `{repoRoot}/composer.json` — if present and no package.json check found, use `composer run test`.
3. If none found, `checkCommand = null`.

## Step 3 — Identify label-related check names

Fetch the PR's current labels:

```bash
gh pr view {prNumber} --repo {owner}/{repo} --json labels --jq '[.labels[].name]'
```

A label is **blocking** (intentionally preventing merge) if it matches any of these (case-insensitive): `do not merge`, `do-not-merge`, `dnm`, `wip`, `hold`, `blocked`, `on hold`, `not ready`.

Store `hasBlockingLabel = true/false`.

A CI check is **label-related** (and should be skipped/ignored) if its name matches any of these patterns (case-insensitive): `label`, `do-not-merge`, `dnm`, `do not merge`, `wip`, `size/`, `pr-title`, `conventional-commit`, `semantic-pr`.

Store this pattern list as `labelCheckPatterns`.

## Step 4 — Poll loop

Initialise `fixAttempts = 0`, `maxAttempts` from ARGUMENTS or default `3`, `noCheckAttempts = 0`.

**Enter the poll loop.** On each iteration:

```bash
STATUS=$(gh pr checks {prUrl} 2>&1)
```

Classify the output:

### No checks yet

If output matches `no checks` or `could not find any checks`:
- Increment `noCheckAttempts`.
- If `noCheckAttempts >= 3`: report "No CI checks found after 3 attempts — skipping CI watch." and exit.
- Otherwise: echo "No checks yet (attempt {noCheckAttempts}/3), waiting 30s..." → sleep 30 → loop.

### All passing

If output contains no `fail` or `error` words, and contains no `pending` or `in_progress` or `queued` words:
- Report success (see Step 6) and exit.

### Pending / in progress

If output contains `pending`, `in_progress`, or `queued`:
- Reset `noCheckAttempts = 0`.
- Echo "Checks still running, waiting 30s..." → sleep 30 → loop.

### Failures present

If output contains `fail` or `error`:
- Reset `noCheckAttempts = 0`.
- Get the structured check list to identify which checks are failing:

```bash
gh pr checks {prUrl} --json name,state,conclusion 2>/dev/null
```

- Collect the names of all failing checks (those with `state == "FAILURE"` or `conclusion == "failure"`).
- **Filter out label-related failures**: remove any failing check whose name matches any pattern in `labelCheckPatterns`.
- If **all** failing checks were filtered out:
  - Echo "Only label-related checks are failing ({filteredCheckNames}){hasBlockingLabel ? ' — expected while blocking label is present' : ''}. Waiting 30s..." → sleep 30 → loop.
- Otherwise there are **real failures** — proceed to Step 5.

---

## Step 5 — Fix attempt

If `fixAttempts >= maxAttempts`:
- Report "Max fix attempts ({maxAttempts}) reached. CI is still failing." and exit with failure.

Increment `fixAttempts`. Echo "CI failed (fix attempt {fixAttempts}/{maxAttempts}). Diagnosing..."

### 5a — Fetch failure logs from GitHub

Get the most recent failed run for the branch:

```bash
gh run list --branch {headRefName} --repo {owner}/{repo} --limit 1 --json databaseId --jq '.[0].databaseId'
```

Store as `runId`. Fetch failure logs (errors are always at the bottom):

```bash
gh run view {runId} --repo {owner}/{repo} --log-failed 2>&1 | tail -100
```

Store as `failureLogs`.

### 5b — Run checks locally

If `checkCommand` is not null:

```bash
cd {repoRoot} && {checkCommand}
```

Capture output as `localCheckOutput`. Note whether it passed or failed.

### 5c — Diagnose and fix

Read `failureLogs` and `localCheckOutput`. Identify what is failing and why. Fix it by editing source files.

Common patterns:
- **Format/lint errors**: run the formatter (`composer run format`, `npm run format`, etc.) — do not manually edit whitespace.
- **Test failures**: fix the failing assertion or the code under test. Do not delete tests.
- **Type errors**: fix the type mismatch in source.
- **Missing import or undefined symbol**: add the missing import or fix the reference.
- **Build errors**: fix the compilation error indicated in the logs.

Do not guess — base every change on what the logs actually say. If the failure is ambiguous or requires a design decision, stop and report what you found rather than guessing.

### 5d — Verify the fix locally

Run `checkCommand` again (if not null):

```bash
cd {repoRoot} && {checkCommand}
```

If it still fails, do NOT push. Report the local failure output and stop: "Local checks still failing after fix attempt {fixAttempts}. Manual intervention required."

### 5e — Commit and push

Stage only the files you changed (never `git add -A` or `git add .`):

```bash
git add {changedFile1} {changedFile2} ...
```

Commit:

```bash
git commit -m "Fix CI: {brief description of what was fixed (attempt {fixAttempts})}
Co-Authored-By: Claude Sonnet 4.6 <noreply@anthropic.com>"
```

Push:

```bash
git push origin HEAD:{headRefName}
```

If push fails, undo the commit:

```bash
git reset HEAD~1
```

Report: "Push failed after fix attempt {fixAttempts}. Stopping." and exit with failure.

### 5f — Re-enter poll loop

Echo "Fix pushed. Waiting 60s for CI to register the new commit..." → sleep 60 → return to Step 4.

---

## Step 6 — Exit report

On **success**:

```
CI is green.
  PR            : {prUrl}
  Fix attempts  : {fixAttempts}
```

On **failure** (max attempts, local check failure, push failure, or unrecoverable error):

```
CI watch stopped.
  PR            : {prUrl}
  Reason        : {reason}
  Fix attempts  : {fixAttempts}
```
