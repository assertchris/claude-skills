---
name: usage-statusline
description: Set up a Claude Code statusline that shows session (5h) and weekly (7d) usage limit percentages. Use when user asks to set up usage statusline, show usage limits, or configure usage display.
user_invocable: true
---

# Usage Statusline Setup

This skill configures Claude Code's statusline to display your usage limits (session 5h / weekly 7d) alongside the context window bar.

## What It Does

1. **Reads your OAuth token** from the system keychain (no separate login needed)
   - **macOS**: Reads from the macOS Keychain via `security find-generic-password`
   - **Linux**: Reads from GNOME Keyring via `secret-tool`, with fallback to `~/.claude/.credentials.json`
2. **Calls the usage API** (`GET https://api.anthropic.com/api/oauth/usage`) with a 3-second timeout
3. **Caches the response** at `/tmp/claude-statusline-usage.json` for 60 seconds to avoid hammering the API
4. **Displays** context, session, and week percentages in the statusline, each color-coded green/yellow/red based on usage level
5. **Fails gracefully** — if the token is missing, the API is unreachable, or anything errors, the usage section is simply omitted

## Requirements

- `jq` must be installed
- `curl` must be installed
- A valid Claude AI OAuth session (you must be logged into Claude Code)

## Instructions

When the user invokes this skill, do the following:

### Step 1: Copy the statusline script

Copy the companion script from this skill's directory to `~/.claude/statusline-command.sh`:

1. Read the file `statusline-command.sh` from this skill's base directory (shown at the top of the skill prompt)
2. Write its contents to `~/.claude/statusline-command.sh`

### Step 2: Configure settings.json

Ensure `~/.claude/settings.json` contains the statusline configuration. If the file already exists, merge in the statusline key without overwriting other settings:

```json
{
  "statusLine": {
    "type": "command",
    "command": "sh ~/.claude/statusline-command.sh"
  }
}
```

Use the absolute path with `$HOME` expanded (e.g. `sh /Users/username/.claude/statusline-command.sh`).

### Step 3: Verify

Run the script with test input to confirm it works:

```sh
echo '{"model":{"display_name":"Opus 4.6"},"context_window":{"used_percentage":42}}' | sh ~/.claude/statusline-command.sh
```

The output should show the model name, context bar, and (if authenticated) usage percentages.

## Sharing

To share this with colleagues:
1. Copy the `~/.claude/skills/custom-usage-statusline/` directory to their `~/.claude/skills/` folder
2. They can then run `/usage-statusline` in Claude Code to set it up
