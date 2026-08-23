---
name: custom-code-audit
description: Audit the entire codebase for materially useful simplifications. Findings are written to a Friday research note when complete.
user-invocable: true
allowed-tools: Read, Glob, Bash(git *), Bash(grep *), Bash(find *), mcp__friday__friday_notes_create, mcp__friday__friday_notes_update, mcp__friday__friday_notes_get, Agent
---

# Custom Code Audit

Audit this entire codebase for materially useful simplifications in its data structures, state representation, control flow, algorithms, and ownership. When the audit is complete, write all findings to a Friday research note.

This is an audit-only exercise. Do not edit files, run tests, implement recommendations, commit, or push. Read-only inspection commands are allowed.

You are the coordinator. Continue until the complete codebase has been reviewed, the final audit is validated, and findings are saved to a note.

---

## Agent Model Policy

Use the right model for the job — this keeps token costs low and context windows free for work that needs reasoning:

- **Haiku** (`model: "haiku"`): file reads, directory listings, grep summaries, single-file inventories, and any task that is purely "read this file and extract facts." These tasks are mechanical and do not require deep reasoning.
- **Sonnet** (default): subsystem reviews that require multi-file reasoning, cross-cutting pattern analysis, validation of findings, and the final synthesis.

When dispatching a sub-agent for a task that is purely mechanical (reading files, summarising a directory, extracting an interface list), explicitly pass `model: "haiku"` in the Agent tool call. Reserve Sonnet for agents that must reason across multiple files or produce recommendations.

---

## Step 1: Establish the Coverage Contract

Inspect the repository and inventory every identifiable subsystem.

Give each subsystem:

- a stable ID and descriptive name
- an exact ownership boundary
- its key implementation files
- relevant public interfaces, major call sites, and tests
- a status: queued, in review, recommend, or skip

Include frontend, backend, shared infrastructure, platform bridges, generated-contract ownership, and test/tooling infrastructure where materially relevant.

**Use Haiku sub-agents** to read and summarise individual files or directories during this inventory step. A Haiku agent should receive a list of files and return: the subsystem name, its key exports/interfaces, and any obvious ownership signals. The coordinator collects these summaries and builds the inventory — it does not read every file itself.

Create one canonical scratchpad containing:

- the subsystem inventory
- confirmed opportunities
- explicit skip decisions
- cross-cutting patterns
- duplicates and superseded findings
- final priorities and dependencies
- an audit log

Treat this inventory as the coverage contract. Do not assume broad catch-all rows prove coverage.

---

## Step 2: Run Bounded Subsystem Reviews

Use fresh, read-only sub-agents for every subsystem. Give every worker one distinct subsystem with an exact, non-overlapping ownership boundary.

**Model selection for workers:**
- If a subsystem contains only 1–3 small files and has no complex cross-file interactions, dispatch a **Haiku** agent (`model: "haiku"`). It can read the files and return a verdict efficiently.
- If a subsystem spans multiple files, has non-trivial call sites, or requires reasoning about interactions between components, dispatch a **Sonnet** agent (default model).

Keep concurrency bounded to the number of lanes you can actively coordinate. Use one consolidated wait mechanism. Do not interrupt productive workers merely because they are slow. Close completed workers after harvesting their results.

Each worker receives this brief:

> Review the assigned subsystem for at most two materially useful simplifications in its data structures, state representation, or organizing model.
>
> Inspect its implementation, public interfaces, major call sites, and existing tests. Stay within the assigned ownership boundary. You may identify cross-subsystem concerns, but do not expand the scope to solve them.
>
> Look for:
>
> - scattered booleans or nullable fields that permit invalid combinations and should become a state machine or discriminated union
> - repeated assumptions about object shape that need a shared typed model
> - duplicated branching that a small map, registry, reducer, or command model would remove
> - unclear state or behavior ownership that a small module boundary would clarify
> - repeated scans, transformations, or lookups where a more appropriate collection or index would materially simplify behavior
> - lifecycle, concurrency, or async states whose representation permits stale or contradictory state
>
> Do not force an abstraction. Prefer boring local code when it is already clear.
>
> Do not recommend changes solely for stylistic consistency, hypothetical extensibility, minor line-count reduction, or moving existing branching behind a new type.
>
> Return at most two opportunities. If nothing clearly meets the threshold, return `skip`.
>
> For every recommendation, provide:
>
> 1. **Verdict**: recommend or skip
> 2. **Evidence**: exact file and line references
> 3. **Current complexity**: invalid states or pain caused today
> 4. **Proposed representation**: what changes and why it is simpler
> 5. **Implementation scope**: smallest credible change, affected files and interfaces
> 6. **Regression risks**: migration concerns
> 7. **Validation**: existing and additional tests required
> 8. **Confidence**: high, medium, or low

---

## Step 3: Validate and Synthesize

Independently verify every finding against the current repository before accepting it.

Reject, narrow, or demote recommendations that are vague, duplicate another finding, misunderstand intentional semantics, or merely relocate complexity.

Record skips as completed coverage. Deduplicate overlapping findings. Assign each accepted recommendation to one authoritative subsystem.

Continue opening bounded review batches until every inventory row is complete.

---

## Step 4: Audit the Audit

Before finishing, run fresh independent passes for:

- repository coverage and missing subsystem boundaries
- duplication and ownership overlap
- materiality and over-abstraction
- schema completeness
- dependency-aware priority ranking

If the coverage pass finds a real omission, add an explicit subsystem row and audit it. Do not hide it by broadening a previously completed boundary.

Rank the final recommendations by concrete impact, confidence, implementation effort, blast radius, and prerequisites. Identify the best first implementation slices.

The audit is complete only when:

- every identifiable subsystem has been reviewed
- every subsystem has a recommendation or explicit skip
- every finding has complete evidence, scope, risk, and validation fields
- duplicates and weak abstractions have been removed
- priorities and dependencies are internally consistent
- the repository remains unchanged

---

## Step 5: Write Findings to a Research Note

Once the audit is fully validated, create a Friday research note using `friday_notes_create` with:

- **user**: chris
- **title**: `Code Audit — <project name> — <today's date>`
- **body**: the full audit report in Markdown, structured as follows:

```
# Code Audit — <project name> — <date>

## Subsystem Inventory

| ID | Subsystem | Status |
|----|-----------|--------|
| ...| ...       | ...    |

## Findings

### <Subsystem Name>

**Verdict**: recommend / skip

**Evidence**: `path/to/file.ts:42`

**Current complexity**: ...

**Proposed representation**: ...

**Implementation scope**: ...

**Regression risks**: ...

**Validation**: ...

**Confidence**: high / medium / low

---

(repeat for each finding)

## Cross-Cutting Patterns

...

## Priority Ranking

1. ...
2. ...

## Explicit Skips

| Subsystem | Reason |
|-----------|--------|
| ...       | ...    |
```

After creating the note, report the note ID and title to Chris so he can find it easily.
