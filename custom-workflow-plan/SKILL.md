---
name: custom-workflow-plan
user-invocable: true
description: Plan phased work for the current feature branch. Asks for a brief, researches the codebase via sub-agents, and writes the plan to the feature doc.
allowed-tools: Bash, Agent, AskUserQuestion
---

# Plan

## Parameters (from ARGUMENTS)

| Key | Purpose | Default |
|---|---|---|
| `brief:` | Skip the question and use this as the brief | — |
| `doc-path:` | Explicit path to the plan doc (skips feature doc discovery) | — |
| `research-context:` | Extra context prepended to each sub-agent research prompt | — |
| `post-write:` | Shell command to run after the plan doc is written (e.g. to update a README) | — |

## Step 1: Get the brief

Check `$ARGUMENTS` for a `brief:` key.

- If `brief:` is present: use everything after `brief:` as the brief. **Skip `AskUserQuestion` entirely.**
- If `brief:` is absent: call `AskUserQuestion` **directly and immediately** — do NOT write the question as text first. Ask:

  > "Give a brief description of what to plan."

  Provide 3 example options:
  - `"add Telegram command for snoozing reminders"` — describes a new command
  - `"refactor the prompt queue to support priorities"` — describes internal work
  - `"fix the usage log rotation bug"` — describes a bug fix

  The user will type their own answer via the **Other** field.

If the brief is empty, ask again.

## Step 2: Resolve the plan doc path

Check `$ARGUMENTS` for a `doc-path:` key.

- If `doc-path:` is present: use it directly as the plan doc path. Skip feature doc discovery entirely.
- If `doc-path:` is absent:
  1. Run `git branch --show-current` to get the current branch name.
  2. Strip the type prefix (everything up to and including the first `/`) to get the stem (e.g. `feature/2026-07-20-add-auth` → `2026-07-20-add-auth`). The feature doc is `features/<stem>.md`.

If on `main` and no `doc-path:` was given, warn the user — plan docs should be written on a feature branch. Stop.

## Step 3: Identify phases

Based on the brief alone, draft a list of phases with:
- phase number and title
- one-sentence scope summary
- key areas of the codebase likely involved (directories, modules, or file patterns — rough guesses are fine)

## Step 4: Deep research per phase

Check `$ARGUMENTS` for a `research-context:` key. If present, prepend its value to the sub-agent prompt below.

For each phase, launch a sub-agent (using the Agent tool) with the following prompt:

  "[research-context, if any]

  You are researching one phase of a planned feature to inform the planning agent.

  Phase: [phase number and title]
  Scope: [one-sentence scope summary]
  Likely areas: [directories / modules / file patterns]

  Your task:
  - Explore the relevant areas of the codebase
  - Read files needed to understand current structure, patterns, and constraints
  - Note: if you need to read large files mainly to summarise them, prefer using the haiku model for those reads
  - Return a structured research summary: what exists, what needs to change, any gotchas or dependencies

  Do NOT implement anything. Return only findings."

Collect all sub-agent findings before proceeding.

## Step 5: Write the plan

Using the sub-agent findings, produce a detailed phased implementation plan. Every phase must have concrete steps. Tests go in the same phase as the code they target.

Writing the plan to the doc is NOT optional — it is the final required step. Do not stop until it is done:

1. If the plan doc already exists and has frontmatter (`---` … `---`): preserve the frontmatter block and replace the content below it with the full plan.
2. Otherwise: write the full plan to the doc path resolved in Step 2.
3. Do NOT commit — leave the file uncommitted for review.

## Step 6: Post-write hook (optional)

Check `$ARGUMENTS` for a `post-write:` key. If present, run the shell command it contains. Warn the user if it fails but do not abort.
