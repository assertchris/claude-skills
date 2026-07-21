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

## Step 3: Determine branch name

Run:
```bash
date +%Y-%m-%d
```

The branch name is `feature/<today>-<slug>` (e.g. `feature/2026-07-20-add-auth`).

The feature doc filename is `<today>-<slug>.md`.

## Step 4: Resolve feature doc template

Use this priority order to find the template source:

1. **Project override**: check if `<feature-dir>/.claude/feature-doc-template.md` exists. If so, use it.
2. **Skill default**: use `~/.claude/skills/custom-workflow-new-feature/template.md`.

Never ask the user. Never look for `features/template.md` in the repo.

Remember the resolved template path — it will be copied into the worktree in step 6.

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

Copy the resolved template (step 4) to `<feature-dir>/.worktrees/<branch>/features/template.md`, creating the `features/` directory if needed.

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
