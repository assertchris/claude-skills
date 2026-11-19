---
name: custom-workflow-pr
user-invocable: true
description: Open a PR assigned to assertchris, then watch CI until it passes or fails. Only use when Chris explicitly asks to open or create a PR — never invoke just because commits need pushing.
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

Once the PR URL is returned, invoke the `custom-watch-ci` skill, passing `pr-url: <pr-url>`. This skill polls CI, skips label-related failures, attempts to fix real failures, and loops until green or max attempts reached.

When `custom-watch-ci` exits (green or stopped), store the QA checklist in topic meta:

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
