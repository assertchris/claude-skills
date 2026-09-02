---
name: custom-workflow-refine
user-invocable: true
description: Refine a Friday note or plan doc over 25 iterations, finding and resolving gaps, assumptions, and ambiguities. Invoked when Chris says "refine this note/plan".
allowed-tools: Bash, mcp__friday__friday_notes_get, mcp__friday__friday_notes_update, Read, Edit, Write
---

## Step 1 — Identify what to refine

Scan the current conversation context for either:

**A) A Friday note** — any mention of a note ID (e.g. "note #42", "note 42", `friday_notes_get` result in context, or a note title that was fetched earlier in this session). Extract the note ID as `<note_id>`. Set `<mode>` to `note`.

**B) A plan doc** — any mention of a file path ending in `.md` inside `docs/`, or a plan/feature doc path explicitly stated in the conversation. Extract the absolute path as `<doc_path>`. Set `<mode>` to `plan`.

If both are present, prefer whichever was mentioned most recently.

If neither can be determined from context, call `AskUserQuestion` with:

> What should I refine? Please provide either a Friday note ID (e.g. "note #42") or the path to a plan doc.

Collect the answer and resolve `<note_id>` or `<doc_path>` accordingly. If still unresolvable, stop with: "Cannot start refinement without a clear target. Provide a note ID or plan doc path."

---

## Step 2 — Set up the working file

**If `<mode>` is `note`:**

1. Fetch the note: call `mcp__friday__friday_notes_get` with `{ id: <note_id> }`. Store the returned `title` as `<note_title>` and `body` as `<original_body>`.
2. Get a timestamp: run `date +%s` via Bash. Store as `<ts>`.
3. Write the note body to a scratch file: `/home/friday/scratch/refine-<note_id>-<ts>.md`. Store this path as `<working_file>`.
4. Write `<original_body>` verbatim to `<working_file>`.

**If `<mode>` is `plan`:**

1. Read the file at `<doc_path>` via the Read tool. Confirm it exists and is non-empty. If missing, stop with: "Plan doc not found at `<doc_path>`."
2. Set `<working_file>` to `<doc_path>`. No copy needed — work directly on the file.

---

## Step 3 — Run 25 refinement iterations

Set `<iteration>` to 1.

Repeat until `<iteration>` reaches 25:

### Each iteration must do all of the following:

**A) Read the current state**

Read `<working_file>` in full. This is your ground truth for this iteration. Do not rely on memory from previous iterations — always re-read.

**B) Identify weaknesses**

Actively search the content for any of the following:

- **Gaps** — facts, decisions, or constraints that are referenced or implied but never stated
- **Unvalidated assumptions** — things the document takes for granted without evidence or justification
- **Ambiguity** — terms, conditions, or steps with more than one plausible interpretation
- **Weak reasoning** — conclusions that don't follow clearly from the stated premises
- **Missing edge cases** — scenarios that the plan/note should handle but doesn't address

**Scope discipline** — only flag true weaknesses in what is already in scope. Do not add scope, new features, or requirements that aren't implied by the existing content. If you are unsure whether something is a weakness or scope creep, add it as an explicit question in the file rather than acting on it.

**C) Attempt to resolve each weakness**

For each weakness found:

1. Check whether the answer is already inferable from:
   - Other parts of the same document
   - The conversation context (tool outputs, facts stated by Chris, prior discussion)
2. If the answer is inferable: write the resolution directly into the file. Expand the relevant section, add the missing constraint, clarify the ambiguous term — whatever fixes the weakness.
3. If the answer genuinely cannot be resolved from available context: add an explicit open question to the file in a dedicated `## Open Questions` section (create it if absent). Format each question as a `- [ ] Question: ...` checklist item.

**Never leave a weakness as "flagged but not addressed."** Either resolve it or convert it to an open question. Flagging without acting is not acceptable.

**D) Make at least one edit**

Even if no major weaknesses are found, look harder. A 25-iteration refinement should be producing meaningful improvements each round. If the file is genuinely tight, consider:

- Tightening wording that is loose but not technically wrong
- Consolidating redundant statements
- Verifying that previously raised open questions have been answered and marking them `- [x]` if so

Write at least one concrete change to `<working_file>` per iteration using the Edit tool.

**E) Report progress**

After the edit, output:

```
Iteration <iteration>/25 complete — <one-line summary of the most significant change made>
```

Increment `<iteration>` by 1 and continue.

---

## Step 4 — Finalise

**If `<mode>` is `note`:**

1. Read the final state of `<working_file>` in full.
2. Call `mcp__friday__friday_notes_update` with:
   - `id`: `<note_id>`
   - `title`: `<note_title>` (unchanged)
   - `body`: the complete, full contents of `<working_file>` — never a partial fragment
3. Confirm the update succeeded (check the tool response for errors).
4. Delete the scratch file: run `rm <working_file>` via Bash.
5. Report: "Note #<note_id> has been refined over 25 iterations and updated. Scratch file cleaned up."

**If `<mode>` is `plan`:**

1. The file is already updated in place — no extra write step needed.
2. Report: "Plan doc refined over 25 iterations. All changes written directly to `<doc_path>`."
