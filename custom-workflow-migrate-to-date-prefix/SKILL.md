---
name: custom-workflow-migrate-to-date-prefix
user-invocable: true
description: Migrate a project's feature docs and branches from NNN numeric prefixes to YYYY-MM-DD date prefixes. Defaults to dry-run mode — pass dry-run:false to apply changes.
allowed-tools: Bash, AskUserQuestion
---

# Migrate to Date Prefix

Migrates feature docs and local branches from `NNN-slug` numeric prefixes to `YYYY-MM-DD-slug` date prefixes.

## Parameters (from ARGUMENTS)

| Key | Purpose | Default |
|---|---|---|
| `project:` | Project directory to migrate | cwd |
| `dry-run:` | Print what would change without touching anything | `true` |
| `only:` | Comma-separated NNN values to process (e.g. `only:003,007,042`) | all |

## Step 1: Resolve project directory

Check `$ARGUMENTS` for a `project:` key. If present, use that path. Otherwise use the current working directory.

Confirm `features/` exists in the project directory. If not, stop with an error.

## Step 2: Resolve parameters

- **`dry-run:`** — extract from ARGUMENTS. If absent or anything other than `false`, treat as `true`.
- **`only:`** — if present, parse as comma-separated list of NNN strings (e.g. `["003", "007", "042"]`). If absent, process all files.

If `dry-run` is true, print a prominent header:

```
DRY RUN — no files will be changed. Pass dry-run:false to apply.
```

## Step 3: Collect feature docs to migrate

Run:
```bash
ls <project>/features/ | grep -E '^[0-9]{3}-'
```

This lists only files with the old NNN prefix. Filter by `only:` if provided. Sort by NNN ascending.

## Step 4: Resolve a date for each file

For each `features/NNN-slug.md`, determine the date using this priority order:

**1. Git history of the file (primary — works even when branch is deleted):**
```bash
git -C <project> log --follow --reverse --format="%ai" -- features/NNN-slug.md | head -1
```
Take only the date portion (first 10 characters, `YYYY-MM-DD`). This succeeds for virtually all merged features since the doc was committed as part of the feature.

**2. Local branch still exists:**
```bash
git -C <project> log feature/NNN-slug --reverse --format="%ai" 2>/dev/null | head -1
```
Only used if (1) returns empty.

**3. Reflog (branch deleted recently, reflog not yet expired):**
```bash
git -C <project> reflog show --format="%ai %gs" 2>/dev/null | grep "feature/NNN-slug" | head -1
```
Only used if (1) and (2) return empty.

**4. Prompt the user:**
If none of the above yield a date, call `AskUserQuestion` asking for the date for this specific file. Accept `YYYY-MM-DD` format.

## Step 5: Derive new names

For each file with a resolved date:

- Strip the NNN prefix: `NNN-slug` → `slug`
- New doc filename: `<date>-<slug>.md`
- New branch name (if branch still exists locally): `feature/<date>-<slug>`

Check for conflicts: if `features/<date>-<slug>.md` already exists, warn and skip that file.

## Step 6: Print the migration plan

For each file, print one line regardless of dry-run mode:

```
[NNN] features/NNN-slug.md  →  features/YYYY-MM-DD-slug.md  (date from: git-history)
      branch feature/NNN-slug  →  feature/YYYY-MM-DD-slug    (if branch exists)
      SKIP: worktree has uncommitted changes                  (if worktree blocked)
```

If dry-run is true, stop here after printing the full plan.

## Step 7: Apply changes (only if dry-run:false)

For each file in the plan, in order:

**a. Rename the feature doc.**
```bash
git -C <project> mv features/NNN-slug.md features/YYYY-MM-DD-slug.md
```
If the file is not tracked by git (uncommitted), use `mv` instead.

**b. Rename the local branch (only if it still exists).**
```bash
git -C <project> branch -m feature/NNN-slug feature/YYYY-MM-DD-slug
```

**c. Handle the worktree (only if branch exists and worktree exists).**

Check for uncommitted changes first:
```bash
git -C <project>/.worktrees/feature/NNN-slug status --porcelain 2>/dev/null
```
- If output is non-empty: skip worktree rename, warn the user, continue to next file.
- If clean: remove and recreate.
  ```bash
  git -C <project> worktree remove .worktrees/feature/NNN-slug --force
  ```
  Then use the `friday_worktree_create` MCP tool to recreate the worktree under the new branch name.

**d. Update any README or index file** in `features/` that contains the old filename as a literal string. Use `sed -i` to replace `NNN-slug.md` with `YYYY-MM-DD-slug.md` in that file.

**e. Remove `features/template.md`** if it exists in the project (once, after all renames are done):
```bash
git -C <project> rm features/template.md 2>/dev/null || rm -f <project>/features/template.md
```
Print: `Removed features/template.md (template now lives alongside the skill)`

## Step 8: Summary

After applying all changes, print:

```
Migration complete.
  Renamed: N docs
  Branches renamed: N
  Worktrees skipped (uncommitted changes): N
  Files skipped (conflict): N

Remote branches are NOT updated. To clean up the remote for each renamed branch:
  git push origin :feature/NNN-slug feature/YYYY-MM-DD-slug

Don't forget to stage and commit the renamed docs:
  git -C <project> add features/ && git commit -m "Migrate feature docs to date-based prefixes"
```
