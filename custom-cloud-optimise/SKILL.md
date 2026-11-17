# Custom Cloud Optimise

Loops through all Laravel Cloud applications, analyses the slowest and busiest routes over the last 24 hours, checks open/recently merged PRs to avoid duplicating in-flight work, maps each app to its local codebase, reads the relevant controller code, and surfaces one improvement suggestion per application for Chris to approve before any PRs are created.

---

## Prerequisites

- `friday_projects_list` must be seeded with the app repos (see `github.reviewableProjects` in `packages/core/src/config.ts`)
- All target apps must be deployed on Laravel Cloud under the authenticated account

---

## Process

### Step 1: Discover applications

Call `friday_laravel_cloud_list_applications`. For each application, call `friday_laravel_cloud_list_environments` and select the production environment (the one that is not a preview/staging environment — typically named `production` or the one with the primary domain). Store a list of:

```
{ appName, appId, environmentId, environmentName }
```

### Step 2: For each app — fetch access logs and route table

For every entry from Step 1, run two operations **in series** (complete one app fully before moving to the next — per the looping preference):

#### 2a. Access logs

Call `friday_laravel_cloud_get_environment_logs` with:
- `environmentId` from Step 1
- `from`: 24 hours ago (ISO 8601)
- `to`: now (ISO 8601)

Filter the returned log entries to access log lines only (entries that have `duration_ms`, `path`, `method`, and `status` fields).

If fewer than 50 access log entries are returned, note "low traffic — results may be sparse" but continue.

#### 2b. Route table

Call `friday_laravel_cloud_run_command` with:
- `environmentId` from Step 1
- `command`: `php artisan route:list --json`

Parse the JSON output. Each route entry has `uri` and `action` fields. Build a list of normaliser patterns:
- Take each `uri`, replace `{param}` segments (anything matching `\{[^}]+\}`) with a regex group `([^/]+)`
- Store `{ pattern: RegExp, uri: string, action: string }` for each route

### Step 3: Normalise paths and compute p50/p95 per route

For each access log entry from Step 2a:

1. Try to match `path` against each normaliser pattern from Step 2b. Use the first match. If no route matches, use the raw path as the route key.
2. Group entries by normalised route key.
3. For each group, compute:
   - `count`: number of requests
   - `p50`: median `duration_ms` (sort values, take middle element)
   - `p95`: 95th percentile `duration_ms` (sort values, take element at index `Math.floor(count * 0.95)`)

### Step 4: Identify outlier routes

Rank all routes by `count` descending. Take the top 10 by request volume.

From those top 10, flag routes where `p95 > 2 × p50`. These are the candidates — high traffic with an outsized tail latency.

Pick the **top 3 candidates** (highest count among those flagged). If fewer than 3 routes are flagged, include the top routes by p95 regardless.

For each candidate, also record the `action` field from the matched route (e.g. `App\Http\Controllers\TopicsController@index`).

### Step 5: Check for open and recently merged PRs

Use `friday_projects_list` to get the full `{ nameWithOwner → localPath }` map.

Identify the GitHub repo for the current app. The app name in Laravel Cloud usually corresponds to a repo — match by comparing the app name or domain against the keys in the projects map. If no match is found, skip the PR deduplication step for this app and note it in the output.

Call `friday_github_list_prs` with `state: "open"` for the matched repo. Also call with `state: "closed"` and check the first page (most recent) for PRs merged within the last 7 days (check `merged_at` field).

For each of the top-3 candidate routes, check whether any open or recently merged PR title or body mentions:
- The controller name (extracted from `action`, e.g. `TopicsController`)
- The route URI (e.g. `topics/{id}/messages`)

If a match is found, mark that route as **already addressed** and skip it. Note which PR is handling it.

### Step 6: Resolve local codebase path

For each app, look up the `localPath` from `friday_projects_list` using the matched `nameWithOwner`.

If no local path is found (app not in the config), skip code reading for this app and include a note: "⚠️ No local path configured — add `owner/repo` to `github.reviewableProjects` in config.ts".

### Step 7: Read controller code

For each non-skipped top candidate route, extract the controller class and method from the `action` field:

- Format: `App\Http\Controllers\SubNamespace\FooController@bar`
- Class: `FooController` (last segment before `@`)
- Method: `bar` (after `@`)

Locate the controller file under `{localPath}/app/Http/Controllers/`. Search recursively:

```bash
find {localPath}/app/Http/Controllers -name "FooController.php"
```

Read the file. Extract only the target method (from the `public function bar(` line to its matching closing brace). If the file is not found or the method cannot be extracted cleanly, read the first 100 lines of the controller file and note the limitation.

Also read any related files the method clearly depends on (e.g. a service class it calls by name in the first 3 lines of the method body). Limit to 1 additional file.

### Step 8: Generate one improvement suggestion per app

For each app, synthesise what you have:

- The top outlier route (URI, p50, p95, count)
- The controller method code
- Whether related PRs are already in flight

Produce **one concrete, actionable suggestion** per app. Format:

```
**[App Name]** — `METHOD /route/uri` (p50: Xms, p95: Yms, N req/24h)

> [1–3 sentence diagnosis of why this route is slow, referencing the actual code]

Suggested fix: [specific change — e.g. "Add a database index on `topics.user_id`", "Cache the result of `resolveSlug()` for 60s using the request path as the key", "Eager-load the `author` relationship to eliminate N+1 queries"]
```

If a route was skipped because a PR is already in flight, note it briefly:

```
**[App Name]** — already in flight: [PR title] ([PR URL])
```

If no local path is configured:

```
**[App Name]** — ⚠️ local path not configured. Top route: `METHOD /route/uri` (p95: Yms). Add repo to `github.reviewableProjects` to enable code analysis.
```

### Step 9: Present for approval

Output all suggestions as a numbered list. End with:

---

**Ready to create PRs?** Reply with the number(s) you'd like to act on (e.g. "1, 3") or "all". Each approved suggestion will be turned into a branch and PR in the relevant repo.

---

## Parameters (from ARGUMENTS)

| Key | Purpose | Default |
|---|---|---|
| `app:` | Restrict analysis to a single app name (substring match) | all apps |
| `hours:` | Log window in hours | `24` |
| `threshold:` | p95/p50 multiplier to flag a route as an outlier | `2` |

## Notes

- Always work in series through the app list (Step 2 onwards). Do not parallelise across apps.
- The route table command (`artisan route:list`) may time out on large apps. If it fails, skip path normalisation and use raw paths.
- Hibernation is intentional on all apps. Do not filter out apps or routes because they appear to be waking from cold start. Slowest is slowest.
- Never create any branch, commit, or PR without Chris's explicit approval at Step 9.
