---
name: custom-pr-summary
description: Generates a concise GitHub pull request summary from the feature doc for the current branch. Use when user asks to create a PR summary, PR description, or wants to extract key information from a feature doc for a pull request.
allowed-tools: Read, Glob, Bash(git *)
user-invocable: true
---

# PR Summary Generator

This skill generates a concise, punchy GitHub pull request summary from feature documentation, extracting only the most important information for code reviewers.

## Purpose

Feature docs are comprehensive and perfect for resuming work across sessions, but they create walls of text when copied into PRs. This skill extracts:
1. A brief summary of what changed and why
2. Files changed, grouped by type of change
3. Specific files reviewers should focus on

## Process

### Step 1: Detect Current Branch

```bash
git branch --show-current
```

Extract the branch name and handle common patterns:
- `feature/sports-2345-add-something` → `sports-2345-add-something`
- `sports-2345-add-something` → `sports-2345-add-something`
- `bugfix/fix-thing` → `fix-thing`

### Step 2: Find Feature Doc

```bash
ls features/ | grep "<branch-name-without-prefix>"
```

If no feature doc exists:
- Inform the user that no feature doc was found for this branch
- Suggest they create one with `/feature-doc` or provide a different branch/file name
- Ask if they want to specify a feature doc path manually

### Step 3: Read Feature Doc

Read the feature doc at `features/<branch-name-without-prefix>.md`.

### Step 4: Extract Key Information

Parse the feature doc and extract:

**For Summary Section:**
- Overview section (1-3 paragraphs)
- Target Outcome (what this feature enables)
- Problem statement (from Background / Current Behavior)
- Key requirements (from Requirements section)

**For Files Changed:**
- Use the "Files Modified/Created" section
- Keep the groupings (Database, Models, Services, Controllers, Views, Tests, etc.)
- Remove placeholder entries (anything with `{{}}`)
- Preserve the format: `path` — description

**For Key Review Areas:**
Identify files that reviewers should focus on by looking for:
- Core logic changes (Services / Core section)
- New models or significant model changes
- API endpoints or controller changes
- Database migrations
- Complex business logic

Typically prioritize in this order:
1. Database migrations (schema changes need careful review)
2. Core services/business logic (where the main changes are)
3. API endpoints/controllers (contract changes)
4. Models (data structure changes)

### Step 5: Generate PR Summary

Create a concise summary with this structure:

```markdown
## Summary

[2-5 bullet points OR 1-2 short paragraphs describing:
- What problem this solves
- What changed at a high level
- Key user/system capability changes]

## Files Changed

### [Category 1]
- `path` — description

### [Category 2]
- `path` — description

[... other categories with actual changes ...]

## Key Review Areas

Focus your review on:
- **`path/to/key/file.php`** — [why this is important to review]
- **`path/to/another/file.php`** — [why this is important to review]
- **`path/to/migration.php`** — [why this is important to review]
```

### Step 6: Format and Present

- **CRITICAL: Display raw markdown with all formatting characters visible** — The user needs to copy/paste the summary WITH markdown syntax (##, -, **, `, etc.) directly into GitHub. DO NOT just render the markdown visually - show the actual markdown characters so they can be copied.
- **Output in markdown format** — The entire PR summary should be formatted as markdown
- Use bullet points for summary if there are 3+ distinct changes
- Use paragraphs if it's a cohesive single feature
- Keep descriptions concise (under 200 words for summary)
- Only include file categories that have actual changes (no placeholders)
- Limit "Key Review Areas" to 3-5 most important files
- Use proper markdown syntax: headers (##), lists (-), bold (**), code blocks (`)

## Example Usage

**User**: "Generate a PR summary" or "/pr-summary"

**Process**:
1. Run `git branch --show-current` → `feature/sports-2456-improve-caching`
2. Find feature doc → `features/sports-2456-improve-caching.md`
3. Read and parse the feature doc
4. Extract: overview, target outcome, files changed, identify core changes
5. Generate concise PR summary
6. Present the formatted summary to the user with all markdown characters visible (##, -, **, `, etc.)

## Edge Cases

### No Feature Doc Found
If the feature doc doesn't exist:
- Inform the user clearly
- Suggest creating one with `/feature-doc`
- Offer to try a different file name if they specify it

### Feature Doc Has Only Placeholders
If the feature doc hasn't been filled in (still has `{{PLACEHOLDERS}}`):
- Inform the user the feature doc needs to be completed first
- Suggest they update the feature doc with actual information
- Offer to work with what's available if some sections are filled in

### Main/Master Branch
If on main or master branch:
- Inform the user this doesn't make sense for main branch
- Ask if they meant to run this on a feature branch

### No Files Changed Section
If the "Files Modified/Created" section is empty or only placeholders:
- Fall back to using `git diff --name-only main...HEAD` to list changed files
- Group them by directory/type manually
- Note in output that this was generated from git diff

### Multiple Possible Feature Docs
If multiple feature docs match the branch name:
- List them all
- Ask the user to specify which one

## Don'ts

1. **DON'T** copy the entire feature doc into the PR summary
2. **DON'T** include placeholder entries (those with `{{}}`) in the output
3. **DON'T** include "Session History" or "Progress" sections from feature doc
4. **DON'T** include "Questions/Decisions Needed" unless critical for reviewers
5. **DON'T** include testing details unless specifically relevant to review
6. **DON'T** make the summary longer than 400 words
7. **DON'T** list every single file if there are 20+ files—group them or summarize

## Success Criteria

A successful PR summary:
- **Displays raw markdown syntax characters** — Shows ##, -, **, `, etc. so the user can copy/paste directly into GitHub
- Is formatted in markdown (with proper headers, lists, bold text, code blocks)
- Is concise (under 400 words)
- Clearly explains WHAT changed and WHY
- Lists files grouped logically
- Highlights 3-5 key files for review focus
- Contains no placeholder text
- Is ready to copy-paste into a GitHub PR description with all formatting intact
- Makes reviewers excited (or at least informed) about the changes
