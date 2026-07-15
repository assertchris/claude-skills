---
name: custom-workflow-pr
user-invocable: true
description: Push the current branch and open a PR assigned to assertchris, then watch CI until it passes or fails.
allowed-tools: Bash, Skill
---

# PR

## Parameters (from ARGUMENTS)

| Key | Purpose | Default |
|---|---|---|
| `doc-path:` | Explicit path to the plan/feature doc — passed through to `custom-pr-summary` | — |
| `draft` | Create the PR as a draft | false |

Use the /custom-submit-pr skill to push and open a PR. Pass through any `doc-path:` and `draft` from ARGUMENTS unchanged.

Once the PR URL is returned, watch it for CI completion using a bash poll loop — stay in this session and run:

  ATTEMPTS=0
  while true; do
    STATUS=$(gh pr checks <pr-url> 2>&1)
    if echo "$STATUS" | grep -qiE "no checks|could not find any checks"; then
      ATTEMPTS=$((ATTEMPTS + 1))
      if [ "$ATTEMPTS" -ge 3 ]; then
        echo "No CI checks found after 3 attempts — skipping CI watch." && break
      fi
      echo "No checks found yet (attempt $ATTEMPTS/3), waiting 30s..."
    elif echo "$STATUS" | grep -qE "fail|error"; then
      echo "Checks failed:" && echo "$STATUS" && break
    elif echo "$STATUS" | grep -qE "pending|in_progress|queued"; then
      echo "Checks still running, waiting 30s..." && ATTEMPTS=0
    else
      echo "All checks passed." && break
    fi
    sleep 30
  done

When all checks pass, or if there are no checks after 3 attempts, report the PR URL and that it is ready to merge.
