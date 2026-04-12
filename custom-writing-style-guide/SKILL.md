---
name: custom-writing-style-guide
description: Apply a personal writing style guide to rewrite prose in markdown files.
allowed-tools: Read, Write, Edit, Glob, AskUserQuestion, Bash
user-invocable: true
---

# Writing Style Guide (Generic)

Rewrite prose in markdown files to match Chris's voice, preserving all structural elements exactly.

## Process

### 1. Resolve the Input

Accept a file path or glob pattern as the argument (e.g. `docs/intro.md` or `docs/**/*.md`).

- If ARGUMENTS contains a file path or glob pattern: use it directly
- If **no argument** is given: use `AskUserQuestion` to ask for a file path or glob pattern (e.g. `docs/**/*.md`)

Expand globs with `Glob` to get the list of files to process. If the resolved file list is empty, inform the user and stop.

Only process markdown files (`.md`). If a non-markdown file is specified, inform the user and stop.

### 2. Load the Style Guide

Read `~/.claude/skills/custom-writing-style-guide/style-guide.md`.

If the file is missing, inform the user and stop.

### 3. Load and Parse the File

For each resolved file, read it and classify each line using the following state machine:

```
STATE = "prose"

for each line:
  if line matches /^```/:
    if STATE == "prose":
      STATE = "code_block"
    else:
      STATE = "prose"
    classify as STRUCTURAL
    continue

  if STATE == "code_block":
    classify as STRUCTURAL
    continue

  if line matches /^#{1,6}\s/:    → STRUCTURAL (heading)
  if line matches /^@\w+/:        → STRUCTURAL (directive — leave untouched)
  if line is empty:               → STRUCTURAL (whitespace preservation)

  otherwise:                      → PROSE (rewrite this line)
```

Prose blocks are contiguous runs of non-structural lines. Rewrite them as a unit (whole paragraph), not line by line.

### 4. Ask Rewrite Mode

Use `AskUserQuestion`: "Review each section, or rewrite the whole file at once?"

- **Interactive** (recommended for first use): show each rewritten section and ask for approval before continuing
- **Batch**: rewrite the entire file at once without pausing for review

### 5. Rewrite Prose

Process section by section (delimited by heading lines), applying the style guide.

In **interactive mode**: show the rewritten prose for each section and ask for approval via `AskUserQuestion` before moving to the next.

Within prose blocks, preserve exactly:
- Inline code references (`` `velocityY` ``, `` `btn()` ``)
- Link URLs (link text can be rewritten)
- Technical accuracy and information density

### 6. Write the Result

Write the rewritten content back to the same file using `Edit` or `Write`. Git provides the safety net.

### 7. Verify Structural Integrity

Re-read the written file and confirm:
- Heading count and text matches the original
- Fenced code block count matches the original
- Empty line count is within reasonable range of the original
- No `@directive` lines were modified

Report any discrepancies to the user.

## Don'ts

1. **DON'T** rewrite code blocks or anything inside backtick fences
2. **DON'T** change heading text — headings are structural
3. **DON'T** add or remove sections, headings, or structural elements
4. **DON'T** change inline code references (backtick-wrapped text)
5. **DON'T** change link URLs (link text can be rewritten)
6. **DON'T** add content that wasn't in the original — this is a voice/style transformation, not content expansion
7. **DON'T** remove technical information — if the original explains a concept, the rewrite must too
8. **DON'T** commit — only commit when explicitly asked
9. **DON'T** process non-prose files (`.js`, `.php`, `.py`, `.ts`, etc.) — this skill is for human-readable markdown prose only
10. **DON'T** change the meaning of a sentence, only the voice and style
11. **DON'T** add emojis, marketing language, or filler phrases
12. **DON'T** modify `@directive` lines — leave any `@snippet`, `@playground`, `@banner`, `@palette`, or similar directives exactly as found
