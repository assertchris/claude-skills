---
name: custom-feature-doc
user-invocable: true
description: Creates a new feature documentation file for the current feature branch based on features/template.md. Use when user asks to create feature documentation, start a feature doc, or initialize documentation for a new feature.
allowed-tools: Bash(git *), Read, Write, Glob
---

# Feature Documentation Creator

This skill creates a new feature documentation file for tracking planning and implementation across multiple Claude sessions.

## Purpose

Feature documentation files:
- Document the planning and implementation of each feature
- Persist across multiple Claude sessions
- Live in the `features/` directory
- Are named after the branch they're created in
- Follow a consistent template structure

## Process

### Step 1: Detect Current Branch

```bash
git branch --show-current
```

Extract the branch name and handle common patterns:
- `feature/sports-2345-add-something` → `sports-2345-add-something`
- `sports-2345-add-something` → `sports-2345-add-something`
- `bugfix/fix-thing` → `fix-thing`

### Step 2: Check if Feature Doc Already Exists

```bash
ls features/ | grep "<branch-name-without-prefix>"
```

If a feature document already exists, inform the user and ask if they want to:
- Open the existing document
- Create a new one with a different name
- Overwrite the existing one (not recommended)

### Step 3: Read Template

Read `features/template.md` from the project root.

### Step 4: Create Feature Document

Create a new file at `features/<branch-name-without-prefix>.md` with the template content.

Replace the following placeholders with actual values:
- `{{BRANCH_NAME}}` → The full branch name (e.g., `feature/sports-2345-add-something`)
- `{{STATUS_ICON}}` → `🟡` (default to "In Progress")
- `{{STATUS_TEXT}}` → `In Progress`

Leave all other placeholders (like `{{FEATURE_TITLE}}`, `{{ISSUE_KEY}}`, etc.) as-is for the user to fill in.

### Step 5: Inform User

Tell the user:
1. That the feature document has been created
2. The file path
3. That they should fill in the placeholders to document their feature
4. Remind them to update it as they work across sessions
5. Remind them that session history should not include dates/times and should not contain system-specific information

## Example Usage

**User**: "Create a feature doc for this branch"

**Process**:
1. Run `git branch --show-current` → `feature/sports-2456-improve-caching`
2. Extract branch name → `sports-2456-improve-caching`
3. Check if `features/sports-2456-improve-caching.md` exists → No
4. Read `features/template.md`
5. Create `features/sports-2456-improve-caching.md` with:
   - `{{BRANCH_NAME}}` replaced with `feature/sports-2456-improve-caching`
   - `{{STATUS_ICON}}` replaced with `🟡`
   - `{{STATUS_TEXT}}` replaced with `In Progress`
6. Inform user the document is ready

## Edge Cases

### No Git Branch
If not in a git repository or can't detect branch:
- Ask user for the feature name
- Use that to create the file

### Already Exists
If feature document already exists:
- Show the user the file path
- Ask what they'd like to do

### Template Missing
If `features/template.md` doesn't exist:
- Inform user that template is missing
- Ask if they want to continue without template (blank file)

### Special Branch Names
Handle edge cases:
- `main` or `master` → Don't create feature doc (inform user)
- Very long branch names → Use full name, warn if > 100 chars
- Branch names with special chars → Keep as-is (git allows them)

## Don'ts

1. **DON'T** automatically fill in feature-specific content beyond the basic placeholders
2. **DON'T** overwrite existing feature docs without explicit user permission
3. **DON'T** modify the template file itself
4. **DON'T** create feature docs for non-feature branches without asking
5. **DON'T** include dates/times in session history sections
6. **DON'T** include system-specific information (like private file paths, e.g., `~/.claude/plans/xyz.md`) in the documentation

## Success Criteria

A successful feature document creation means:
- File exists at `features/<branch-name>.md`
- Basic placeholders (branch, status) are filled in
- All other placeholders remain for user to complete
- User is informed of the file location
- User knows to update it as they work
