# Blast Radius Analysis

Inline procedure for Phase 2 of the review workflow. The PR diff and working directory are already available from Phase 1 — do not re-fetch or re-checkout.

**Never save the report or any findings to a file.** All output is in-memory, used only to drive the repairer and to populate the final review report.

---

## Step A: Parse and Categorize the Diff

Obtain the diff for the PR:

```bash
# Mode A (own PR): diff against base branch
git diff origin/<baseRefName>...HEAD

# Mode B (others' PR): diff is already available in the review worktree
git diff origin/<headRefName>...review/<pr-number>-<slug>
```

For each changed file:

- Classify the change type: schema/migration, model/entity, controller/handler, service/business logic, API contract, view/template/component, config, test, build/tooling
- List every function, method, class, interface, type, constant, and public contract that was touched
- Note any changes to method signatures, return types, or exported interfaces

---

## Step B: Identify Research Areas

Map each changed element to its potential impact zones. Prioritize:

1. Public API / exported contract changes
2. Schema / data model changes
3. Business logic / service changes
4. Controller / handler changes
5. View / template changes
6. Config / environment changes

Create a research plan covering these standard areas:

- **Direct consumers** — every file that imports, calls, or extends the changed code
- **Data layer impact** — ORM relationships, queries, migrations, factories, seeders
- **Route & endpoint impact** — which routes, middleware, and handlers are affected
- **Event & async impact** — events dispatched, listeners, jobs, queues touched by the change
- **View & frontend impact** — templates, components, and client-side code consuming changed data
- **API contract impact** — external API responses, webhooks, SDK contracts, serialization
- **Config & environment impact** — config values consumed elsewhere, env var additions/removals
- **Test coverage gaps** — existing tests for changed code, and untested impact paths
- **Security impact** — see checklist below

---

## Step C: Spawn Parallel Sub-Agents to Trace Impact

Spawn sub-agents (max 3 in parallel per preference) to investigate each research area concurrently. Each sub-agent:

- Works read-only in the working directory
- Is scoped to a single research area
- Returns concrete file paths and line numbers

Each sub-agent prompt must include:
- The specific research area to investigate
- The list of changed classes, functions, files, and method signatures to trace
- The working directory path
- Instruction to return concrete references (`file:line`), not summaries

Wait for **all** sub-agents to complete before proceeding to Step D.

---

## Step D: Synthesize the Impact Map

Compile all sub-agent findings. Classify each impact:

- **Direct** — code that directly calls or is called by the changed code
- **Indirect** — code affected through chains, events, or shared state
- **Potential** — code that *might* be affected depending on runtime conditions or data

Identify breaking changes, behavioral shifts, and areas with no test coverage.

---

## Step E: Security Checklist

Check the changed code for each of the following. Flag every hit regardless of severity:

| Category | What to look for |
|---|---|
| Mass assignment | New fields accepted from user input without explicit allow-listing |
| Auth/authz bypass | Removed or weakened middleware, missing authorization checks |
| SQL injection | Raw query construction with user-controlled values |
| XSS | Unescaped output in templates or responses |
| IDOR | New endpoints/routes without ownership or permission checks |
| Data exposure | New fields in API responses, logs, or error messages exposing sensitive data |
| CSRF | New mutation endpoints missing CSRF protection |
| File handling | Upload/download paths without type, size, or path traversal validation |
| Rate limiting | Removed or weakened rate limiting on public-facing endpoints |
| Secrets/env | Hardcoded credentials, secrets in source, new env vars without example entry |

> **Any CRITICAL or HIGH finding must be resolved before this PR is approved.** Evaluate against production behaviour, not local dev defaults.

---

## Step F: Generate the Report

Structure findings as follows. All sections are required. Never use placeholder values — every cell must be populated from actual findings or marked "None identified."

```markdown
# Blast Radius: [Brief description of changes]

**Branch**: [branch name] | **Files Changed**: [count]

## QA Readiness

| Area | Status | Summary |
|------|--------|---------|
| Security | RED / AMBER / GREEN | [one line] |
| Test coverage | RED / AMBER / GREEN | [one line] |
| Deployment risk | RED / AMBER / GREEN | [one line] |
| API contract | RED / AMBER / GREEN | [one line] |
| **Overall** | **RED / AMBER / GREEN** | **[Ready / Blocked — reason]** |

Status key: RED = blocked, must fix before merge. AMBER = proceed with caution. GREEN = clear.
Rules: any RED → overall RED. Any AMBER with no RED → overall AMBER. All GREEN → overall GREEN.

---

## 1. Changes Summary

[Concise description of what changed and why, based on the diff.]

### Changed elements

| File | Type | What changed |
|------|------|-------------|
| `path/to/file` | [model/service/controller/view/etc] | [Methods, signatures, exports changed] |

---

## 2. Impact Map

### By severity

**Critical** — Breaking or behavioral changes:
- [Impact] (`file:line`) — [Why this breaks or changes behavior]

**High** — Direct consumers:
- [Impact] (`file:line`) — [How it connects to the change]

**Medium** — Indirect chain effects:
- [changed element] → [intermediate] → [affected code] (`file:line`)

**Low** — Potential / conditional:
- [Impact] (`file:line`) — Condition: [when this would be affected]

### By domain

| Domain | Element | Impact | Reference |
|--------|---------|--------|-----------|
| [Model/Service/Route/View/Job/etc] | [name] | [what's affected] | `file:line` |

### Security findings

| Finding | Severity | Category | Reference | Production impact |
|---------|----------|----------|-----------|-------------------|
| [Description] | CRITICAL/HIGH/MEDIUM/LOW | [Category] | `file:line` | [What could happen] |

_If none: "No security issues identified in the changed code."_

---

## 3. Manual QA Paths

Ordered by risk. Each path gives a human tester everything they need to execute it immediately.

### Critical Paths (must test before merge)

#### [Path name]
- **Steps**:
  1. [Navigate to / perform action]
  2. [Interact with changed feature]
  3. [Verify expected outcome]
- **Verify**: [What should be true]
- **Regression check**: [What should NOT have changed]

### High Priority Paths

#### [Path name]
- **Steps**: ...
- **Verify**: ...
- **Regression check**: ...

### Edge Cases
- [Boundary condition or specific data scenario worth testing manually]

---

## 4. Test Coverage

### Automated tests included in this PR
- `path/to/test` — [What it covers]

### Existing tests covering changed code
- `path/to/test` — [What it covers]

### Missing automated tests — PUSHBACK REQUIRED

> If any items appear here, the PR should not proceed to merge without them.
> This section identifies the gap only — it does not prescribe implementation.

| Gap | What's untested | Risk if not covered | Effort |
|-----|----------------|---------------------|--------|
| [Behavior/endpoint/path] | [What could break silently] | [Consequence] | Low/Medium |

Only Low and Medium effort gaps are listed here. High-effort gaps (complex setup, external service mocking, extensive test data) are non-blocking:

### Non-blocking coverage gaps
- [High-effort gap] — [Why it's high effort]

---

## 5. Deployment & Risk

| Risk area | Level | Mitigation |
|-----------|-------|------------|
| [area] | Critical/High/Medium/Low | [What to verify, monitor, or roll back] |

### Deployment steps
- [Migration ordering, cache clearing, queue restart, reindex, feature flag requirements, rollback steps]
```

---

## Notes

- Sub-agents are read-only. Never write files from a blast radius sub-agent.
- Trace impact through relationship chains — don't stop at the first level.
- Consider runtime behaviour, not just static references (polymorphism, dynamic dispatch, lazy loading).
- Public API and schema changes have the widest blast radius — prioritize them.
- Evaluate security against production behaviour, not local dev defaults.
- **Test pushback is non-negotiable**: if a critical code path has no test and closing the gap is low-to-medium effort, it must appear in the PUSHBACK REQUIRED section. Do not soften it into a suggestion.
- The report feeds directly into the repairer sub-agent (Step 4 of the review skill) and the final report comment. Keep findings concrete and actionable.
