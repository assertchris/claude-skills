---
name: custom-workflow-summary
description: Turn a stream-of-consciousness voice dictation or a third-party transcript into a numbered video script outline saved as a Friday note. Triggered when Chris says "summary of this", "script summary of this", or similar.
user-invocable: true
allowed-tools: Bash, Read, Glob, mcp__friday__friday_notes_create, mcp__friday__friday_notes_search, mcp__friday__friday_facts_search
---

# Summary / Script Summary

Convert a raw dictation or transcript into a structured Friday note: numbered script points, short-form flags, humor/emotion markers, optional context from local projects, and a "Maybe Later" holding area for tangents and cuts.

**The only output of this skill is a Friday note.** No code changes, no file edits, no tasks created, no messages sent. If something in the content looks actionable, it goes into Friday's Take as an observation — not as an action taken. Chris will explicitly ask if he wants anything done with it.

---

## Step 1 — Parse the input

The raw content is in `$ARGUMENTS`. Strip the invocation phrase from the beginning:
- "I want a script summary of this"
- "Script summary of this"
- "Summary of this"
- "Give me a summary of this"
- Any close variant of the above

Everything remaining is the content to process.

**Detect input type:**
- **Dictation** — Chris speaking a stream of consciousness about a topic he plans to record
- **Transcript** — a third-party conversation, meeting, or video transcript being summarised

If the content clearly has multiple named speakers, labelled turns, or interview-style structure, treat it as a transcript. Otherwise treat it as a dictation.

**Detect fuzzy duration cue** (dictation mode only):

| Cue in content | Target duration |
|---|---|
| "longer form", "deep dive", "everything" | No cut — include all points |
| "quick", "short one", "brief" | ~5–8 minutes |
| Explicit time ("30 minute video") | Use that target |
| No cue | ~20 minutes (default) |

Transcript mode always includes everything — no duration-based cuts.

---

## Step 2 — Cheap context scan

Run the following quickly, in parallel:

1. `ls ~/Code/` — check if any directory name matches the topic keywords in the content
2. Search Friday notes for the topic: `friday_notes_search` with 1–2 key terms
3. Search Friday facts for the topic: `friday_facts_search` with 1–2 key terms

If you find **likely matches** (a project directory, a note, or a fact that clearly relates), surface them before proceeding:

> "I found `~/Code/friday.assertchris.dev` and a note titled 'Agent Rewrite Plan' that look relevant. Want me to dig into them before I generate the summary?"

Wait for approval. If Chris says yes, read the relevant files (README, recent git log, key source files) and Friday notes/facts. Keep all findings — they inform Friday's Take only, not the main script.

If nothing matches, skip silently and proceed.

---

## Step 3 — Extract and classify content

Go through the content and classify every piece:

### Main points
A main point is a distinct idea, claim, story beat, or argument that the speaker(s) intended to make — even if it was rambling or poorly articulated. All speakers' points are equally valid. Distill each into a concise, recordable statement. Do **not** add ideas of your own.

### Humor moments 😄
Flag any moment where something genuinely landed as funny — a joke, a dry observation, an unexpected punchline, a self-deprecating comment. These are **never cut**. Add a brief parenthetical capturing *what made it work*:

`5. 😄 The rubber duck story *(dry delivery, no warning — that's what made it work)*`

### Emotional beats 🥺
Flag any moment of genuine emotional weight — a personal story, a moment of vulnerability, a reference to loss, family, struggle, or joy. These are **never cut**. Add a brief parenthetical capturing the resonance:

`8. 🥺 The story about his dad *(quietly devastating — the pause before "he never came home" carried everything)*`

### Tangents and self-corrections 💭
A tangent or self-correction is content the speaker clearly abandoned, contradicted, or never completed. Signals include: "actually no", "wait forget that", "scratch that", "never mind", or a thought that simply trails off and is never resumed.

Send these to "Maybe Later" with `[re: #N]` if they relate to a specific main point.

### Cut for length 💭 (dictation mode only)
After reordering and numbering, if the estimated total runtime exceeds the target duration, move the least-developed or lowest-priority points to "Maybe Later" tagged `[good candidate — cut for length]`. Use proportion of dictation length per point as a rough pacing proxy (~130 words spoken ≈ 1 minute of video).

---

## Step 4 — Reorder and number

Reorder all main points (including humor and emotional beats) into the most logical narrative flow — not necessarily the order they were spoken. Number them sequentially starting at 1.

Flag **2–3 points** as short-form candidates 🎯 — points that are self-contained, punchy, and can stand alone in 15–60 seconds without any build-up from the rest of the video. Apply 🎯 regardless of whether the input was a dictation or a transcript.

A good 🎯 candidate:
- Makes one clear point that needs no context
- Has emotional resonance, a strong opinion, or a surprising angle
- Can be delivered in 15–60 seconds

---

## Step 5 — Generate Friday's Take (if warranted)

If you found relevant context in Step 2, or if there are genuinely interesting observations about the content itself, add a "Friday's Take" section. Each insight must reference the specific point it relates to with `[re: #N]`.

Only include insights that are:
- Non-obvious
- Grounded in actual context found (not general knowledge)
- Relevant to what Chris might want to know before recording

If there is nothing genuinely interesting to say, omit the section entirely.

---

## Step 6 — Compose the note

**Note title format:** `YYYY-MM-DD Inferred Topic Title`
Use today's date. Infer the topic title from the content — Chris never provides one.

**Note body structure:**

```
# [Inferred Topic Title]

## Script

1. First point
2. 🎯 Second point *(short-form candidate)*
3. 😄 Funny moment *(what made it work)*
4. Third point
5. 🥺 Emotional beat *(the resonance)*
...

## Maybe Later

- 💭 A dropped tangent [re: #2]
- 💭 A good point that didn't fit [good candidate — cut for length]
- 💭 A self-correction with no clear home
...

## Friday's Take  ← omit this section if there is nothing genuinely interesting to say

- 💡 An observation worth considering [re: #1]
...

---
🎯 Short-form candidate — keep it brief and punchy when recording
😄 Humor moment — recreate the energy noted in the parenthetical
🥺 Emotional beat — lean into it; the parenthetical captures what landed
💭 Optional — dropped mid-thought, self-corrected, or cut for length
💡 Friday's insight — an observation, not part of your script
[re: #N] — relates to point N in the Script
[good candidate — cut for length] — worth including but would make the video too long
```

---

## Step 7 — Create the note and return

Create the Friday note using `friday_notes_create` with user `chris`.

Return to Chris:
- The note title
- The note ID
- Nothing else — do not summarise the note content in chat
