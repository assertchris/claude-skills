---
name: custom-workflow-merge
user-invocable: true
description: Merge the open PR, switch to main, pull, and clean up the worktree and symlinks.
allowed-tools: Bash
---

# Merge

Merge the PR using gh CLI, then follow these steps IN ORDER — do not skip any:

1. Get the main project root: run `git worktree list | head -1 | awk '{print $1}'` to find the main worktree path.
2. Merge and delete the worktree using the friday_worktree_delete MCP tool (or equivalent).
3. Run `cd <main-project-root>` in bash to move the shell to the main project directory.
4. Pull main: `git pull`.
5. Verify symlinks in ~/.claude/commands/ still point to valid paths; retarget any that pointed to the deleted worktree.
