---
name: custom-sync-skills
user-invocable: true
description: Syncs global Claude skills to/from the remote git repo. Commits local changes with descriptive messages, pushes, and pulls remote changes. Use when user asks to sync skills, save skills, push skills, or pull skills.
allowed-tools: Bash(git -C *), Read, Glob, AskUserQuestion
---

# Sync Skills

This skill syncs the global skills directory (`~/.claude/skills/`) with its remote git repo so skills are shared across machines.

## Process

### Step 1: Check Status

```bash
git -C ~/.claude/skills status
```

Show Chris what's changed locally.

### Step 2: Pull Remote Changes

Pull any remote changes first to avoid conflicts:

```bash
git -C ~/.claude/skills pull --rebase origin main
```

If the remote doesn't exist yet (first push), skip this step.

### Step 3: Scan for Sensitive Content

Before committing, review every changed/new file for sensitive content. Read each file that would be committed and look for:

- API keys, tokens, secrets, passwords (e.g. patterns like `sk-`, `ghp_`, `Bearer`, `password`, `secret`, `token` followed by actual values)
- Hardcoded URLs to internal/private services
- Usernames or credentials embedded in commands
- Absolute paths that reveal private directory structures (e.g. `/home/user/private-project/`)
- Any content that looks like it shouldn't be in a public repo

If anything questionable is found, use AskUserQuestion to show Chris exactly what was found and which file it's in. List each finding and ask for confirmation before proceeding. If Chris says no, skip that file.

If nothing sensitive is found, proceed silently.

### Step 4: Commit Local Changes

For each changed or new skill, create a separate commit with a descriptive message. Use `git diff` and `git status` to understand what changed.

**Commit message patterns:**
- New skill: `Add <skill-name> skill`
- Modified skill: `Update <skill-name>: <brief description of what changed>`
- Deleted skill: `Remove <skill-name> skill`

If multiple files changed within one skill, group them in a single commit. If multiple skills changed, make separate commits per skill.

```bash
git -C ~/.claude/skills add custom-<name>/
git -C ~/.claude/skills commit -m "<message>"
```

### Step 5: Push

```bash
git -C ~/.claude/skills push -u origin main
```

### Step 6: Report

Summarize what was synced: how many skills committed, pushed, and/or pulled.

## Edge Cases

### No Remote Branch Yet (First Push)

If `git pull` fails because there's no remote branch, skip the pull and just push after committing.

### No Changes

If there are no local changes and pull brings nothing new, inform Chris everything is already in sync.

### Merge Conflicts

If pull --rebase encounters conflicts, abort the rebase and inform Chris. Do not resolve conflicts automatically.

```bash
git -C ~/.claude/skills rebase --abort
```

## Don'ts

1. **DON'T** force push
2. **DON'T** resolve merge conflicts automatically — inform Chris and abort
3. **DON'T** commit unrelated files outside of skill directories
4. **DON'T** modify any skill content during sync — only commit what's already there
