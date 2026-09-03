---
name: custom-writing-style-guide
description: Apply a personal writing style guide to rewrite prose in markdown files or inline text.
allowed-tools: Read, Write, Edit, Glob, Bash
user-invocable: true
---

# Writing Style Guide (Generic)

Rewrite prose to match Chris's voice, preserving all structural elements exactly.

## Process

### 1. Resolve the Input

ARGUMENTS may contain one of:

- **A file path or glob pattern** (e.g. `docs/intro.md` or `docs/**/*.md`) — process the file(s) and write results back in place
- **Raw text** (anything that is not a valid file path or glob) — rewrite the text in memory and return the result as output; do not write to any file
- **Nothing** — stop and tell the caller to provide either a file path or raw text

To distinguish: check whether ARGUMENTS looks like a file path or glob (contains `/`, `~`, or ends in `.md`, `**`, `*`). If it matches an existing file or glob, treat it as file mode. Otherwise treat it as raw text mode.

In **file mode**: expand globs with `Glob`. If the resolved file list is empty, inform the caller and stop. Only process markdown files (`.md`).

In **text mode**: the entire ARGUMENTS string is the text to rewrite. Return the rewritten text as plain output when done.

### 2. Load the Style Guide

Read `~/.claude/skills/custom-writing-style-guide/style-guide.md`.

If the file is missing, stop and report the error.

### 3. Parse the Content

For each file (file mode) or the raw text (text mode), classify each line using the following state machine:

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

### 4. Unslop Pass

Before applying the style guide, scan each prose block for artificial language patterns and rewrite to eliminate them. This pass runs silently. The goal is to strip AI-sounding noise so the style pass works on clean human prose.

**Pattern categories to eliminate:**

*Content issues:* Puffery ("pivotal moment", "game-changer", "paradigm shift"), hollow "-ing phrases" that open sentences ("Leveraging our expertise…"), name-dropping without explanation, promotional adjectives ("nestled", "vibrant", "thriving"), vague attributions ("experts say", "studies show"), generic obstacles ("challenges", "hurdles").

*Language problems:* AI vocabulary — "delve", "interplay", "testament", "nuanced", "tapestry", "underscore", "embark", "navigate", "landscape", "ecosystem" (when used metaphorically); inflated copulas ("serves as", "acts as", "functions as" when "is" works); "not just X, but Y" constructions; forced lists of three where two or four would be natural; synonym cycling (using five words for the same thing to avoid repetition).

*Style concerns:* Excessive em dashes used as a tic rather than for genuine parenthetical emphasis; scattered boldfacing for emphasis (bold is structural, not decorative); headers that restate the list content beneath them; decorative emojis in prose; Title Case headings (convert to sentence case).

*Communication artifacts:* Chatbot phrases ("I hope this helps!", "Feel free to…", "Don't hesitate to…"); false praise ("Great question!", "Absolutely!"); cutoff disclaimers ("As of my knowledge cutoff…").

*Filler:* Verbose phrases ("In order to" → "To", "Due to the fact that" → "Because", "At this point in time" → "Now"); over-hedging ("it's worth noting that", "it's important to mention"); generic conclusions that restate the intro.

*Jargon:* Abstract metaphor nouns used as filler — "substrate", "vector", "flywheel", "north star", "unlock", "leverage" (as a verb).

**Rewrite rules:**
- Replace passive voice with active where natural
- Break dense compound sentences into two shorter ones
- Prefer mechanisms over metaphors — say what a thing actually does, not what it resembles
- Remove sentences that restate what the previous sentence already said
- Replace weak verbs ("utilize" → "use", "facilitate" → "help", "implement" → "build" or "add")

**What stays:** Data tables, enumerable lists, the author's own terminology, structural bolding (e.g. term definitions), short punchy sentences, and any passage that reads as direct and specific already.

### 5. Rewrite Prose

Process all prose blocks, applying the style guide. No pausing, no section-by-section approval — rewrite everything at once.

Within prose blocks, preserve exactly:
- Inline code references (`` `velocityY` ``, `` `btn()` ``)
- Link URLs (link text can be rewritten)
- Technical accuracy and information density

### 6. Output the Result

**File mode:** Write the rewritten content back to the same file(s) using `Edit` or `Write`. Then verify structural integrity:
- Heading count and text matches the original
- Fenced code block count matches the original
- Empty line count is within reasonable range of the original
- No `@directive` lines were modified

Report any discrepancies.

**Text mode:** Output the rewritten text directly. Do not write to any file.

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
13. **DON'T** ask the user anything — no `AskUserQuestion`, no mode selection, no confirmation prompts
