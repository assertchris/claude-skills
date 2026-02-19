---
name: custom-conflict-resolution
description: Resolves git merge conflicts using rebase strategy, analyzing conflicts one file at a time to preserve the best code from both branches. Use when user asks to resolve conflicts, merge conflicts, fix conflicts, handle conflicts, merge branches, rebase, or mentions git conflicts.
allowed-tools: Bash(git *), Read, Edit, Grep, Glob
user-invocable: true
---

# Git Conflict Resolution via Rebase

This skill handles git merge conflicts using a rebase-first strategy, ensuring clean history and thoughtful conflict resolution.

## Core Principles

1. **Always use rebase, never merge** - Unless explicitly told otherwise
2. **One file at a time** - No batch processing unless user explicitly permits it
3. **Preserve best code from both branches** - Analyze and merge thoughtfully
4. **Never take shortcuts** - Each conflict deserves proper analysis

## Process

### Step 1: Understand the Situation

Before touching anything:

1. Check current git status
2. Identify the target branch (usually `main` or `origin/main`)
3. Understand what the current branch contains vs target
4. Check for duplicate commits (common when PRs were merged to main)

```bash
git status
git log --oneline --graph origin/main..HEAD
git log origin/main --oneline | head -20
```

### Step 2: Attempt Rebase

```bash
git fetch origin main
git rebase origin/main
```

**If rebase succeeds**: Great! Skip to Step 5 (verification).

**If conflicts occur**: Continue to Step 3.

### Step 3: Conflict Analysis

When conflicts occur:

1. List all conflicted files:
```bash
git status | grep "both modified"
```

2. For each conflicted file, show the conflict to the user:
```bash
git diff <file>
```

3. **ASK THE USER**: "I found conflicts in X files. Should I resolve them one at a time, or are there specific patterns where I can batch process (like pure syntax changes)?"

### Step 4: Resolve Each Conflict

For each conflicted file, follow this process:

#### A. Analyze the Differences

1. **Show what changed in HEAD (target branch)**:
```bash
git show HEAD:<file>
```

2. **Show what changed in the incoming commit**:
```bash
git show :<stage>:<file>  # or read the conflict markers
```

3. **Explain to the user**:
   - What main/target branch has
   - What feature branch has
   - What the conflict is about
   - Which approach seems better and why

#### B. Resolution Strategy

Choose based on analysis:

**Strategy 1: Accept one side completely**
```bash
git checkout --ours <file>    # Keep current branch
git checkout --theirs <file>  # Accept incoming changes
```

**Strategy 2: Manual merge required**
- Use Edit tool to manually combine the best of both
- Preserve functionality from both branches
- Remove conflict markers (<<<<<<, =======, >>>>>>>)

**Strategy 3: Manual edit after accepting one side**
- Accept one version as base
- Use Edit tool to apply specific changes from the other version

#### C. Verify and Stage

After resolving:

1. **Lint the file** (if applicable):
```bash
php -l <file>  # For PHP files
npm run lint <file>  # For JS files
```

2. **Stage the resolved file**:
```bash
git add <file>
```

3. **Report to user**: "Resolved X by [brief explanation]"

### Step 5: Complete the Rebase

After all conflicts are resolved:

```bash
git rebase --continue
```

If more conflicts arise in subsequent commits, repeat Step 4.

### Step 6: Verification

1. **Check the clean history**:
```bash
git log --oneline --graph HEAD~10..HEAD
```

2. **Verify working directory is clean**:
```bash
git status
```

3. **Force push with lease**:
```bash
git push --force-with-lease
```

## Common Scenarios

### Scenario 1: Duplicate Commits

**Problem**: Feature branch was based on commits that were later merged to main via PR, creating duplicate commits with different hashes.

**Solution**: Use `git rebase --onto` to replay only the unique commits:

```bash
# Find the first unique commit in your branch
git log --oneline origin/main..HEAD

# Rebase only commits after the duplicates
git rebase --onto origin/main <last-duplicate-commit>
```

### Scenario 2: Structural Refactoring Conflicts

**Problem**: Main refactored code structure (e.g., array → closure), feature branch modified the old structure.

**Solution**:
1. Accept main's new structure (`git checkout --ours`)
2. Apply feature branch's logical changes to the new structure using Edit tool
3. Preserve both improvements

## Batch Processing Rules

**NEVER batch process unless the user explicitly says**:
- "If conflicts are only [specific pattern], you can batch accept [branch]"
- "For files with only syntax changes, use our version"

**When permitted**, use:
```bash
git checkout --ours file1 file2 file3
git add file1 file2 file3
```

## Error Recovery

### If you make a mistake:

```bash
git rebase --abort
# Start over from Step 2
```

### If user wants to switch to merge instead:

```bash
git rebase --abort
git merge origin/main
# Apply same careful one-file-at-a-time process
```

## Critical Don'ts

1. **DON'T** use `git checkout --ours` or `--theirs` without understanding what you're accepting
2. **DON'T** batch process multiple files without explicit user permission
3. **DON'T** skip showing the user what conflicts exist
4. **DON'T** assume syntax-only changes - verify first
5. **DON'T** move on to next file until current one is staged
6. **DON'T** combine operations - resolve, then lint, then stage

## Success Criteria

A successful conflict resolution means:
- Clean linear history on top of target branch
- All functionality from both branches preserved
- No duplicate commits
- All tests pass (run if available)
- User understands what was done and why
