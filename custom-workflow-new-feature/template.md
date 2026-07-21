# {{FEATURE_TITLE}}

- Branch: `{{BRANCH_NAME}}`

## Overview
{{1-3 paragraphs describing:}}
- What the system/product currently does
- What pain/problem exists today (include where it manifests: UI, logs, API behavior, etc.)
- Why it matters (admin experience, reliability, performance, revenue, compliance, etc.)
- Any key context (architectural constraints, integrations, stakeholders)

### Background / Current Behavior
- **Current behavior**: {{WHAT_HAPPENS_TODAY}}
- **Problem**: {{WHAT_BREAKS_OR_IS_MISSING}}
- **Where it happens**: {{FILES / MODULES / FLOWS / UI PAGES}}
- **Impact**: {{WHO_IS_AFFECTED_AND_HOW}}

### Target Outcome
This feature will {{WHAT_YOU_ARE_BUILDING}} so that {{USERS / ADMINS / SYSTEM}} can:
- {{USER_CAPABILITY_1}}
- {{USER_CAPABILITY_2}}
- {{USER_CAPABILITY_3}}

## Requirements
> Keep this checklist crisp and testable. Prefer “behavioral” requirements over implementation details.

### Functional
- [ ] {{REQ_FUNCTIONAL_1}}
- [ ] {{REQ_FUNCTIONAL_2}}
- [ ] {{REQ_FUNCTIONAL_3}}

### Non-Functional
- [ ] Observability: {{LOGS_METRICS_TRACES_REQUIRED}}
- [ ] Performance: {{LATENCY / THROUGHPUT / QUERY_CONSTRAINTS}}
- [ ] Security/Permissions: {{ROLES_ACCESS_RULES}}
- [ ] Data retention / lifecycle: {{RETENTION_POLICY}}
- [ ] Backwards compatibility: {{BC_REQUIREMENTS}}

### UX / Admin (if applicable)
- [ ] {{REQ_UX_1}}
- [ ] {{REQ_UX_2}}

### Out of Scope
- {{OUT_OF_SCOPE_1}}
- {{OUT_OF_SCOPE_2}}

## Implementation Plan
> Break into ordered steps. Each step should be independently reviewable.
> **Code style**: No useless comments. Only add comments that explain tricky/non-obvious code.
> **Before committing**: Run `npm run format` and `npm test` before every commit.
> **No auto-committing**: Only commit when explicitly asked. `git status`/`git diff`/`git log` are read-only — never follow them with `git add` or `git commit` unless Chris said "commit."
> **One step at a time**: When the implementation plan has numbered steps, complete only the current step before asking to proceed. Do not work ahead into future steps.
> **No verbose paths**: Do not specify the working directory in commands when it matches the current directory (e.g. no `git -C /path/to/project`).
> **Playground embeds**: Use `@playground(uuid, caption text)` — parentheses, NOT square brackets.

1. **Discovery / Audit**
- Locate current behavior in: {{FILES / SERVICES / ENDPOINTS}}
- Identify failure points / edge cases: {{EDGE_CASES}}
- Confirm data sources & contracts: {{EXTERNAL_APIS / SCHEMAS}}

2. **Data Model / Storage (if needed)**
- Create/modify table(s): {{TABLES}}
- Fields:
- {{FIELD_1}} — {{PURPOSE}}
- {{FIELD_2}} — {{PURPOSE}}
- Indexing strategy: {{INDEXES_FOR_LOOKUP/DEDUP}}
- Migration notes: {{SAFE_MIGRATION_PLAN}}

3. **Core Logic / Services**
- Add service/module: `{{SERVICE_PATH}}`
- Responsibilities:
- {{RESP_1}}
- {{RESP_2}}
- Key methods:
- `{{METHOD_1}}()` — {{WHAT_IT_DOES}}
- `{{METHOD_2}}()` — {{WHAT_IT_DOES}}
- Error handling strategy:
- Capture: {{WHAT}}
- Deduplicate/grouping (if relevant): {{HOW}}
- Fallback behavior: {{WHAT_HAPPENS_ON_FAILURE}}

4. **Integration Points**
- Update caller(s) to pass context: {{CALLERS}}
- Hook into flow(s): {{REQUEST_LIFECYCLE / JOBS / UI_ACTIONS}}
- Ensure no hard crashes: {{SAFE_DEFAULTS}}

5. **UI / Admin Surface (if needed)**
- Add admin page/resource: `{{ADMIN_RESOURCE_PATH}}`
- List view:
- Columns: {{COLS}}
- Filters: {{FILTERS}}
- Search: {{SEARCH_KEYS}}
- Detail view:
- Sections: {{SECTIONS}}
- Actions:
- {{ACTION_1}}
- {{ACTION_2}}
- Polling/refresh policy (if relevant): {{POLLING}}

6. **Cleanup / Lifecycle (if needed)**
- Command/job: `{{COMMAND_PATH}}` (`{{SIGNATURE}}`)
- Behavior:
- Delete/archive records older than {{DAYS}} days when {{CONDITION}}
- Options: {{FLAGS}}
- Scheduling: {{CRON / KERNEL_SCHEDULE}}

7. **Testing**
- Unit tests:
- `{{TEST_FILE_1}}` — {{WHAT_IT_COVERS}}
- Feature/integration tests:
- `{{TEST_FILE_2}}` — {{WHAT_IT_COVERS}}
- Scenarios to simulate:
- {{SCENARIO_1}}
- {{SCENARIO_2}}
- Acceptance checks:
- {{ACCEPTANCE_CRITERIA}}

## Progress

### Completed
- {{COMPLETED_ITEM_1}}
- {{COMPLETED_ITEM_2}}

### In Progress
- {{IN_PROGRESS_ITEM_1}}
- {{IN_PROGRESS_ITEM_2}}

### Blocked
- {{BLOCKER_1}} (Owner: {{OWNER}} / ETA: {{DATE_OR_UNKNOWN}})
- {{BLOCKER_2}}

### To Do
- {{TODO_1}}
- {{TODO_2}}

## Technical Notes
> Use this section for the “why” and tricky implementation details.

## Files Modified/Created
> Keep this list updated as you work (it doubles as a PR checklist).

### Database
- `{{PATH}}` — {{WHAT_CHANGED}}

### Models
- `{{PATH}}` — {{WHAT_CHANGED}}

### Services / Core
- `{{PATH}}` — {{WHAT_CHANGED}}

### API / Controllers / Responders
- `{{PATH}}` — {{WHAT_CHANGED}}

### Views / Frontend
- `{{PATH}}` — {{WHAT_CHANGED}}

### Admin / CMS
- `{{PATH}}` — {{WHAT_CHANGED}}

### Console / Jobs
- `{{PATH}}` — {{WHAT_CHANGED}}

### Factories / Seeders
- `{{PATH}}` — {{WHAT_CHANGED}}

### Tests
- `{{PATH}}` — {{WHAT_CHANGED}}

## Testing
{{STATUS_ICON}} **{{TEST_STATUS}}**: {{SUMMARY}}
- Total tests: {{N_TESTS}}
- Assertions: {{N_ASSERTIONS}}
- Key coverage:
- {{COVERAGE_ITEM_1}}
- {{COVERAGE_ITEM_2}}

## Questions/Decisions Needed
- [ ] {{QUESTION_1}}
- [ ] {{QUESTION_2}}

## Decisions Made
- **{{DECISION_TITLE_1}}**: {{DECISION}}
- **{{DECISION_TITLE_2}}**: {{DECISION}}

## Session History

### Session 1
- {{SESSION_NOTE_1}}
- {{SESSION_NOTE_2}}

### Session 2
- {{SESSION_NOTE_1}}
- {{SESSION_NOTE_2}}
