---
name: custom-zsh-aliases
user-invocable: true
description: Adds custom zsh aliases and functions (change, branches, gs, gd, nah) to ~/.zshrc. Use when user asks to set up zsh aliases, install shell aliases, or configure a new machine with standard shell shortcuts.
allowed-tools: Bash(grep, cat, source), Read, Edit, AskUserQuestion
---

# Zsh Aliases & Functions Setup

This skill adds standard zsh aliases and the `branches` function to `~/.zshrc` on a new machine.

## Aliases & Functions to Install

```zsh
alias change='vim ~/.zshrc && source ~/.zshrc'
alias gs="git status"
alias gd="git diff"
alias nah="git reset --hard HEAD"

branches() {
  git checkout main &&
  git fetch --prune &&
  git pull &&

  gone=$(
    git for-each-ref --format='%(refname:short) %(upstream:track)' refs/heads \
    | awk '$2=="[gone]"{print $1}'
  )

  if [[ -n "$gone" ]]; then
    echo "Deleting gone branches:"
    for b in ${(f)gone}; do
      echo "  - $b"
      git branch -D "$b"
    done
  else
    echo "No gone branches to delete."
  fi

  git branch -v
}
```

## Process

### Step 1: Read ~/.zshrc

Read the user's `~/.zshrc` file to understand its current contents.

### Step 2: Replace or Add Entries

For each alias and function:
- If it already exists in `~/.zshrc`, **overwrite it** with the version from this skill using the Edit tool.
- If it does not exist, append it.

Group any newly appended entries in a clearly marked block:

```zsh
# Custom aliases and functions
<new entries here>
```

### Step 3: Source

Run `source ~/.zshrc` using the Bash tool to activate the changes immediately.

## Notes

- The `branches` function checks out `main`, prunes remote tracking branches, and deletes local branches whose upstream is gone
- The `change` alias opens `~/.zshrc` in vim and re-sources it after editing
