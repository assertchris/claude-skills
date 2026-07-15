---
name: custom-workflow-new-feature
user-invocable: true
description: Start a new feature by asking for a purpose, then creating a branch + worktree + feature doc.
allowed-tools: Bash, AskUserQuestion
---

# New Feature

## Step 1: Get purpose

Check `$ARGUMENTS` for a `brief:` key.

- If `brief:` is present in ARGUMENTS: use everything after `brief:` as the raw purpose. **Skip `AskUserQuestion` entirely.**
- If `brief:` is absent: call `AskUserQuestion` **directly and immediately** — do NOT write the question as text first. Ask:

  > "What is this feature for? (keep it short — a few words)"

  Provide 3 example options:
  - `"add user auth"` — describes an authentication feature
  - `"export to CSV"` — describes a data export feature
  - `"fix sidebar layout"` — describes a UI bug fix

  The user will type their own answer via the **Other** field.

Also check `$ARGUMENTS` for a `project:` key. If present, use its value as the project hint. Otherwise the project hint is empty.

If the purpose is empty after sanitisation (step 2), ask again.

## Step 2: Sanitise into a slug

Transform the raw purpose into a slug:

1. Lowercase all characters
2. Replace spaces with hyphens
3. Strip any character that is not `a-z`, `0-9`, or `-`
4. Collapse multiple consecutive hyphens into one
5. Trim leading and trailing hyphens
6. **Truncate to 40 characters max**, cutting at the last `-` boundary (do not cut mid-word)

## Step 3: Determine next branch number

Resolve the project directory for the feature count:

1. If the project hint is non-empty and `<project-hint>/features/` exists: use that as the feature directory.
2. If the project hint is non-empty but that path doesn't exist: derive the basename and search the projects root:
   ```bash
   PROJECTS_DIR=$(dirname $(git rev-parse --show-toplevel 2>/dev/null || echo "$PWD"))
   find "$PROJECTS_DIR" -maxdepth 1 -type d -name "<basename>" 2>/dev/null | head -1
   ```
3. If the project hint is empty: use the current directory.

Then run:
```bash
ls <feature-dir>/features/ | grep -oE '^[0-9]+' | sort -n | tail -1
```

Increment by 1 and zero-pad to 3 digits (e.g. `77` → `078`). If no output, use `001`.

The branch name is `feature/<NNN>-<slug>`.

## Step 4: Check for feature doc template

Run:
```bash
git -C <feature-dir> show HEAD:features/template.md > /dev/null 2>&1
```

- If it **succeeds**: the template is committed to the repo. No extra copy needed.
- If it **fails**: no committed template exists. Call `AskUserQuestion` **directly and immediately** — do NOT write the question as text first. Ask:

  > "No `features/template.md` found in this project. Which template should I copy into the worktree?"

  Offer these options:
  - `friday.assertchris.dev` — `/home/friday/Code/friday.assertchris.dev/features/template.md`
  - `floaty.dev` — `/home/friday/Code/floaty.dev/features/template.md`
  - `gepetto.assertchris.dev` — `/home/friday/Code/gepetto.assertchris.dev/features/template.md`
  - `shell.assertchris.dev` — `/home/friday/Code/shell.assertchris.dev/features/template.md`

  The user may also type a custom path via **Other**. Remember this path — before creating the feature doc, copy the template file to `{worktree}/features/template.md` (create the features/ directory if needed).

## Step 5: Pull main before creating the worktree

Before creating the worktree, ensure the project's main branch is up to date. Run in the resolved project directory:

```bash
git -C <feature-dir> pull origin $(git -C <feature-dir> rev-parse --abbrev-ref HEAD)
```

If the pull fails (e.g. no remote, offline), warn Chris but continue — do not abort.

## Step 6: Create worktree and feature doc

Create a worktree for the branch in the resolved project using the friday_worktree_create MCP tool. NEVER run git commands manually — the MCP tool handles branch creation inside the worktree so the main project directory always stays on `main`. Do NOT run `git checkout`, `git branch`, or any other git command in the main project directory — it must remain on `main` throughout.

The worktree will be placed at `<feature-dir>/.worktrees/<branch>`.

Once the worktree exists, copy dependency directories from the main project into the worktree so tools like prettier, tsc, etc. are immediately available without a fresh install. Use `cp -r` (not symlinks) so changes inside the worktree never bleed back. For each of the following directories, if it exists in the main project, copy it into the worktree: `node_modules`, `vendor`.

If a template needed to be copied from another project (step 4), do that now.

Using the worktree's absolute path, create the feature doc file inside the worktree (do not commit it).

## Step 7: Done

Report:

> Worktree ready at: `<feature-dir>/.worktrees/<branch>`
>
> To work in this worktree from Claude Code CLI, exit this session and run:
> ```
> cd <feature-dir>/.worktrees/<branch>
> claude
> ```
