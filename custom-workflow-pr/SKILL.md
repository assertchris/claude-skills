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
| `base:` | Override the PR base branch (passed through to `custom-submit-pr`) | repo default |
| `body:` | Pre-composed PR body — skips summary generation and style guide in `custom-submit-pr` | — |

Use the /custom-submit-pr skill to push and open a PR. Pass through `doc-path:`, `draft`, `base:`, and `body:` from ARGUMENTS unchanged.

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

When all checks pass, or if there are no checks after 3 attempts, store the QA checklist in topic meta:

1. Extract the topic ID from the current session scope — the numeric portion of `user::chris::<N>`. If the scope is not in this format (e.g. general session), skip meta storage and proceed to reporting.
2. Run the `custom-qa-checklist` skill unconditionally to generate the checklist markdown.
3. Run `git rev-parse HEAD` to capture the current commit SHA.
4. Capture the absolute path of the repository (`git rev-parse --show-toplevel`).
5. Call `friday_topic_set_meta` three times:
   - `{ id: <topic_id>, key: "qa_checklist", value: "<checklist text, or empty string if generation failed or returned nothing>" }`
   - `{ id: <topic_id>, key: "qa_checklist_commit", value: "<SHA>" }`
   - `{ id: <topic_id>, key: "qa_checklist_repo", value: "<absolute repo path>" }`

If checklist generation fails for any reason, store an empty string for `qa_checklist` (do not skip the step). Note the failure in the final response.

After meta storage (or if skipped), report the PR URL and that it is ready to merge.
