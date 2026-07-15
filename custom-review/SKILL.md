---
name: custom-review
description: Comprehensive PR review that loops code review and blast radius analysis, repairing issues between each pass until both phases come back clean.
user-invocable: true
allowed-tools: Bash(gh pr view:*), Bash(gh pr diff:*), Bash(gh pr list:*), Bash(gh pr comment:*), Bash(git *)
---

# Custom Review

Run a two-phase, self-healing review loop on a pull request:

1. **Phase 1 — Code Review Loop**: Repeatedly review the PR for bugs and compliance issues, repairing each round's findings, until a review pass returns nothing significant.
2. **Phase 2 — Blast Radius Loop**: Repeatedly analyze the PR's impact across tenants and system components, repairing each round's findings, until an analysis pass returns nothing significant.

---

## Step 1: Get PR Reference

Parse the user's input for a PR number or GitHub PR link.

- If a PR number is provided (e.g. `123`), use it directly.
- If a PR link is provided (e.g. `https://github.com/.../pull/123`), extract the PR number.
- If **no PR reference is provided**, stop and ask:
  > "Which PR should I review? Provide a PR number or GitHub link."

Fetch PR details:

```bash
gh pr view <number> --json headRefName,title,number,url,state,mergeCommit,mergedAt,baseRefName
```

Confirm the PR is open (not merged, not draft, not closed). If it is not open, stop and tell the user.

---

## Step 2: Phase 1 — Code Review Loop

Repeat the following loop until the review sub-agent returns no significant findings (i.e. no issues with a confidence score ≥ 80):

### Loop body

**Sub-agent A — Code Reviewer**

Spawn a sub-agent to review the PR. The sub-agent must:

1. Use a Haiku agent to get a list of relevant CLAUDE.md file paths (root + any directories touched by the PR).
2. Use a Haiku agent to summarise the PR changes.
3. Launch 5 parallel Sonnet agents to independently review the changes:
   - **Agent 1**: Audit compliance with CLAUDE.md files found above.
   - **Agent 2**: Shallow scan for obvious bugs in the diff (no extra context; large bugs only; no nitpicks).
   - **Agent 3**: Read git blame and history of changed files; identify bugs in light of that historical context.
   - **Agent 4**: Read previous PRs that touched these files; surface any comments that also apply here.
   - **Agent 5**: Read code comments in modified files; check changes comply with any guidance in them.
4. For each issue found, spawn a parallel Haiku confidence-scoring agent. Score each issue 0–100:
   - **0**: False positive, doesn't survive light scrutiny, or is pre-existing.
   - **25**: Might be real but unverified. Stylistic issue not explicitly in CLAUDE.md.
   - **50**: Verified real but minor. Unlikely to be hit in practice.
   - **75**: Highly confident. Directly verifiable, significant, or explicitly in CLAUDE.md.
   - **100**: Certain. Will be hit frequently. Evidence directly confirms it.
5. Filter to issues scoring ≥ 80.
6. Return the filtered issue list. If empty, return `CLEAN`.

**If the sub-agent returns `CLEAN`**: Phase 1 is complete. Proceed to Phase 2.

**If the sub-agent returns issues**:

Spawn **Sub-agent B — Code Repairer**. The sub-agent must:

1. Read the full context of each issue (file, line, reason).
2. Apply the minimal code change that resolves each issue.
3. Do not change anything not directly related to the flagged issues.
4. Stage only the modified files (do not `git add .` blindly), commit with:
   `fix(review): [brief description of issues resolved] (code-review round N)`
5. Push to the PR branch: `git push`.
6. Return a summary of every change made and the commit SHA.

After the repairer completes, start the next Code Review Loop iteration from Sub-agent A.

### False positive guidance for Sub-agent A

Do not flag:

- Pre-existing issues (not introduced by this PR).
- Things that look like bugs but aren't.
- Pedantic nitpicks a senior engineer would ignore.
- Issues a linter, typechecker, or CI pipeline would catch.
- General code quality issues (test coverage, security hygiene) unless CLAUDE.md requires them.
- Issues silenced by an explicit lint-ignore comment.
- Intentional behavioral changes directly related to the PR's purpose.
- Real issues on lines the PR did not modify.

---

## Step 3: Phase 2 — Blast Radius Loop

Repeat the following loop until the blast radius sub-agent returns no significant findings (i.e. no RED or AMBER items, no unaddressed critical/high security findings, no test pushback items):

### Environment context

This codebase runs across multiple environments with different configuration sources:

| Environment | Config sources | Secrets |
|-------------|---------------|---------|
| **Production** | `config/overrides/env/production/*.php`, `config/overrides/tenant/{tenant}/*.php`, `config/overrides/tenant-env/{tenant}-production/*.php` | Vapor Parameter Store (encrypted) |
| **Staging** | `config/overrides/env/staging/*.php`, `config/overrides/tenant/{tenant}/*.php`, `config/overrides/tenant-env/{tenant}-staging/*.php` | Vapor Parameter Store (encrypted) |
| **QA** | Cloned from staging, dynamically created per PR | Cloned from staging Parameter Store |
| **Local** | `.env`, `.env.{env}-{tenant}` (gitignored), `config/overrides/` | Plaintext in `.env` files |
| **Testing** | `.env.testing` | Test values only |

Config layering: base `config/` → `env/{env}/` → `tenant/{tenant}/` → `tenant-env/{tenant}-{env}/` (most specific wins).

**All blast radius analysis is for production** unless the user states otherwise.

### Tenant dispatch mode

Determine tenant scope from user input:

| Mode | Trigger | Tenants analyzed |
|------|---------|-----------------|
| **All** (default) | No tenant instruction | All production tenants in `config/overrides/tenant/` (excluding `global` and `xx`) |
| **Representative** | User says "representative", "rep", "quick", or "sample" | 3–4 selected tenants |
| **Explicit** | User names specific tenant(s) | Only those tenants |

### Loop body

**Sub-agent A — Blast Radius Analyzer**

Spawn a sub-agent to analyze impact. The sub-agent must run two phases:

**Phase 1 — Locate (broad sweep)**

Dispatch one `qa-tenant-locator` per tenant in scope, all in parallel. Each locator's prompt must include:
- The tenant it is scoped to (e.g. "You are the **pt** tenant locator").
- ALL research areas listed below, bundled into a single prompt per tenant.
- The list of changed classes, methods, and files to trace.

Research areas to investigate:
- **Direct consumers**: Every file that imports, uses, or references the changed classes/methods/traits.
- **Route & responder impact**: Routes, middleware, and responders affected. Trace: route → responder → service/proxy → Blade view.
- **Proxy & service chain**: service → HTTP client → proxy DTO → responder → view.
- **Model & observer chains**: Eloquent relationships from changed models; observers in `app/Observers/`.
- **View & theme cascade**: Blade templates affected; trace through `resources/theme/paths.json`.
- **Content block impact**: Changes to `ContentBlocksResolverService` and block Blade templates.
- **Event & listener chains**: Events dispatched by changed code and their listeners.
- **Queue & job impact**: Jobs using changed models or services (SQS async in production).
- **Migration & schema impact**: Every model, factory, seeder, and query referencing affected columns/tables.
- **Config & feature flag impact**: Config values consumed elsewhere; tenant overrides; feature flag gates.
- **Cache impact**: Response caching (60s TTL), SWR cache macro, Redis cache.
- **Test coverage gaps**: Existing tests for changed code; untested impact paths.
- **API contract impact**: Mobile API v1/v2 or Sportal365 API consumption.
- **Security impact**: Mass assignment, auth/authz bypass, SQL injection, XSS, IDOR, data exposure, CSRF, file handling, rate limiting, secrets/env.

**Phase 2 — Analyze (deep dive, mandatory for ALL tenants)**

After all locators complete, spawn one `qa-tenant-analyzer` per tenant in scope, all in parallel. Each analyzer's prompt must include:
- The tenant it is scoped to.
- The specific files and locations to analyze (from locator results, or the changed files if no overrides found).
- The specific question to answer (e.g. "Does the PT theme cascade override this base view, and if so, does the override consume the changed proxy field?").

> **HARD RULE**: Phase 2 is mandatory for ALL tenants. Do not skip any tenant because "the locator found no impact." Locators find WHERE; analyzers trace HOW.

The sub-agent returns a structured findings object:

```
{
  security_findings: [ { severity, category, file, line, description } ],  // CRITICAL/HIGH/MEDIUM/LOW
  test_gaps: [ { gap, risk, effort } ],                                     // effort: Low/Medium/High
  tenant_divergences: [ { tenant, area, description } ],
  deployment_risks: [ { area, level, mitigation } ],
  overall_status: "RED" | "AMBER" | "GREEN"
}
```

Return `CLEAN` if `overall_status` is GREEN and:
- No CRITICAL or HIGH security findings remain.
- No test gaps with Low or Medium effort remain.

**If the sub-agent returns `CLEAN`**: Phase 2 is complete. Proceed to Step 4.

**If the sub-agent returns findings**:

Spawn **Sub-agent B — Blast Radius Repairer**. The sub-agent must:

1. For each CRITICAL or HIGH **security finding**: apply the minimal code change that resolves it. Do not over-engineer.
2. For each **test gap** with Low or Medium effort: write the missing test.
3. For each **deployment risk** that can be mitigated in code (e.g. a missing cache clear, a missing feature flag check): apply the fix.
4. Tenant divergences and High-effort test gaps are noted but not acted on automatically — surface them to the user instead.
5. Stage only the modified files (do not `git add .` blindly), commit with:
   `fix(review): [brief description of issues resolved] (blast-radius round N)`
6. Push to the PR branch: `git push`.
7. Return a summary of every change made and the commit SHA.

After the repairer completes, start the next Blast Radius Loop iteration from Sub-agent A.

---

## Step 4: Final Report

Once both phases are clean, produce a final report:

```markdown
# Review Complete: [PR title] (#[number])

**Rounds — Code Review**: [N] | **Rounds — Blast Radius**: [N]

## Code Review
[Summary of issues found and fixed across all rounds. "None" if first pass was clean.]

## Blast Radius
[Summary of security findings, test gaps, and deployment risks found and fixed across all rounds.]

## Still Requires Human Attention
[List any tenant divergences, High-effort test gaps, or findings that could not be automatically repaired.]

## QA Readiness
| Area | Status | Summary |
|------|--------|---------|
| Security | [RED / AMBER / GREEN] | [One-line reason] |
| Test coverage | [RED / AMBER / GREEN] | [One-line reason] |
| Tenant safety | [RED / AMBER / GREEN] | [One-line reason] |
| Manual QA paths | [RED / AMBER / GREEN] | [One-line reason] |
| Deployment risk | [RED / AMBER / GREEN] | [One-line reason] |
| **Overall** | **[RED / AMBER / GREEN]** | **[Ready / Blocked — reason]** |
```

Post this report as a comment on the PR using:

```bash
gh pr comment <number> --body "<report>"
```

Present the report to the user and highlight anything still requiring human attention.

---

## Notes

- Always run phases sequentially: complete Phase 1 before starting Phase 2.
- Repair sub-agents commit and push automatically after each round.
- If a repair sub-agent encounters a change that is ambiguous or risky (e.g. a security fix with unclear intent), it must stop, surface the issue to the user, and wait for instruction before committing.
- The loop has an implicit safety limit: if either phase has not converged after 5 rounds, stop, report the outstanding findings, and ask the user how to proceed.
- All tenant analysis uses the two-agent model: `qa-tenant-locator` for broad sweep, `qa-tenant-analyzer` for deep read. Never use a single agent to "check all tenants."
