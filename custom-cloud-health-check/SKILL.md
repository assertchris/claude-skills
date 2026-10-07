---
name: custom-cloud-health-check
user-invocable: true
description: Inspect a cloud-hosted app (Laravel Cloud + Cloudflare) for caching, security, and performance gaps. Recommends fixes and optionally drafts a Friday research note for implementation.
allowed-tools: Bash, Read, mcp__friday__friday_notes_create, mcp__friday__friday_notes_search, AskUserQuestion
---

# Cloud Health Check

Inspect a Laravel app hosted on Laravel Cloud behind Cloudflare. Surface caching, security, and crawler hygiene problems. Recommend fixes. Optionally draft a research note.

This skill **does not implement anything** — it inspects, recommends, and documents.

---

## Step 1: Gather inputs

Check `$ARGUMENTS` for:
- `domain:` — the live domain (e.g. `sensoryseekers.co.za`)
- `project:` — absolute path to the project repo

If either is missing, ask for them via `AskUserQuestion`.

---

## Step 2: Inspect the live site

Run the following checks against `https://<domain>` using `curl`. Never call any URL you are not confident is the user's own site.

### 2a. Homepage headers
```bash
curl -sI "https://<domain>"
```
Extract and record:
- `cache-control` value
- `cf-cache-status` (MISS / HIT / EXPIRED / BYPASS / DYNAMIC / etc.)
- `age`
- `last-modified`
- `cf-ray`
- `laravel-cloud-cache` — if present and set to `DYNAMIC`, Laravel Cloud is signalling Cloudflare to bypass cache. **This overrides any `cache-control` header you set.** Laravel Cloud has a dashboard toggle to suppress it, but it does not reliably work. The correct fix is a Cloudflare Transform Rule → "Remove Response Header" targeting `laravel-cloud-cache`.
- `set-cookie` — any `Set-Cookie` header on a cacheable response also causes Cloudflare to mark it `DYNAMIC` and skip caching. Check whether Laravel is setting session or XSRF cookies on the homepage. If so, the session/cookie middleware must be removed from the cacheable route.

### 2b. Bypass Cloudflare cache to see origin headers
```bash
curl -sI -H "Cache-Control: no-cache" "https://<domain>"
```
Record the origin `cache-control` value separately so you can distinguish what Laravel sends vs what Cloudflare serves. Also check whether `laravel-cloud-cache` and `set-cookie` appear in the origin response — if they do, the fix is in the app; if they don't, the fix is a Cloudflare Transform Rule.

### 2c. Static asset headers
Pick one `/build/` path from the HTML source or `public/build/manifest.json` if accessible. Run:
```bash
curl -sI "https://<domain>/build/<any-asset>"
```
Check for `cache-control: public, max-age=31536000, immutable`.

### 2d. Known crawler files
For each path below, run `curl -so /dev/null -w "%{http_code}" "https://<domain><path>"` and record the status code:
- `/robots.txt`
- `/sitemap.xml`
- `/favicon.ico`
- `/apple-touch-icon.png`
- `/ads.txt`
- `/.well-known/security.txt`

Note any 404s — each one means crawlers are repeatedly hammering the origin.

### 2e. Security headers
```bash
curl -sI "https://<domain>" | grep -i "x-frame-options\|x-content-type\|content-security-policy\|strict-transport\|referrer-policy\|permissions-policy"
```

---

## Step 3: Inspect the codebase

From the project directory, check:

### 3a. Cache middleware
- Does `app/Http/Middleware/SetCacheHeaders.php` exist and is it registered in `bootstrap/app.php`?
- Does any route use `cache.headers:` middleware with `s_maxage` set?
- Are there any dead/unregistered middleware files (e.g. `CacheBuildAssets.php`)?

### 3b. Cloudflare security rule sync
- Is `assertchris/cloudflare-security-rule-sync` in `composer.json`?
- Has the config been published (`config/cloudflare-security-rule-sync.php` exists)?
- Are `CF_API_TOKEN` and `CF_ZONE_ID` in `.env.example`?
- Is the sync wired into a deploy step or Artisan command?

### 3c. Layout / view bloat

Read the main public layout file (typically `resources/views/components/layout.blade.php` or `resources/views/layouts/app.blade.php`). Look for:

**Framework directives loaded unnecessarily**
- `@filamentStyles`, `@filamentScripts` — Filament is an admin panel; these should never appear in a public-facing layout
- `@livewireStyles`, `@livewireScripts` — only needed if Livewire components are actually used on that page; check whether any Livewire components exist in public views before flagging

**Fonts**
- Any `<link>` loading Google Fonts, Typekit, or other external font services — note the font family names
- Grep the view files and CSS/JS for actual usage of those font families: `grep -r "font-family\|font-face\|fontFamily" resources/`
- Any font declared but not referenced anywhere in styles or Tailwind config is dead weight and an extra render-blocking request

**Commented-out HTML**
- Large blocks of `{{-- ... --}}` or `<!-- ... -->` commented-out markup — these bloat the response payload and often contain stale or sensitive structure

**Inline scripts / styles**
- Large `<style>` or `<script>` blocks that belong in compiled assets
- `<script src="...">` tags pointing to CDN-hosted libraries that are also bundled via Vite (duplicate loading)

**Meta / link tag hygiene**
- Unused `<meta>` tags (e.g. generator tags, deprecated keywords meta)
- Multiple `<link rel="canonical">` or conflicting open graph tags

For each finding: note the file, the approximate line, what it is, and why it costs (extra request, render-blocking, payload bloat, etc.).

### 3d. Public directory hygiene
Check for the presence of:
- `public/robots.txt` (non-empty)
- `public/sitemap.xml`
- `public/favicon.ico` (non-zero bytes: `wc -c public/favicon.ico`)
- `public/apple-touch-icon.png`
- `public/ads.txt`
- `public/.well-known/security.txt`

---

## Step 4: Score and report

Present findings grouped by severity:

### 🔴 Critical (serving 404s or no caching at all)
- Missing crawler files (robots.txt, sitemap, favicon, etc.)
- No `Cache-Control` header on homepage
- `cf-cache-status: BYPASS` or `DYNAMIC` on homepage
- `laravel-cloud-cache: DYNAMIC` present in response — Laravel Cloud injects this header and Cloudflare respects it, bypassing cache entirely regardless of your `cache-control` value. The dashboard toggle to suppress it does not reliably work. Fix: add a Cloudflare Transform Rule → **Modify Response Header** → **Remove** → `laravel-cloud-cache`. This must be done per-zone in the Cloudflare dashboard.
- `set-cookie` on a cacheable route — Cloudflare will not cache any response that sets a cookie. Remove session/cookie middleware from routes you want cached (use `withoutMiddleware` or a dedicated route group).

### 🟡 Suboptimal (caching present but wrong TTLs or missing coverage)
- `s-maxage` is absent or less than 604800 on homepage
- `/build/` assets missing `immutable` directive
- `last-modified` absent on responses

### 🟢 Quick wins (security, hygiene, dead code)
- Missing security headers (X-Frame-Options, HSTS, Referrer-Policy, etc.)
- `assertchris/cloudflare-security-rule-sync` not installed — blocks everything not on your route allowlist at the Cloudflare edge before it touches PHP
- Dead middleware files sitting unregistered
- Layout bloat: unused framework directives (Filament/Livewire), unneeded external font loads, commented-out HTML, CDN scripts duplicated by Vite, stale meta tags
- Empty `favicon.ico` (0 bytes) causing repeated browser fetches

For each finding include:
- What it is
- Why it matters
- What to do (high-level — no implementation code)

---

## Step 5: Offer a research note

After the report, ask:

> "Want me to draft a research note for these findings? It will follow the same format as the implementation notes you use for feature work."

If yes, create a note via `friday_notes_create` with:
- **Title**: `<App name>: Cloud Health Improvements`
- **User**: `chris`
- **Body**: structured as:
  - **Goal** — one paragraph summarising what needs fixing and why
  - **Platform** — hosting stack (Laravel Cloud → Cloudflare, etc.)
  - **Findings** — same grouped list from Step 4
  - **Recommended Packages** — always include `assertchris/cloudflare-security-rule-sync` if not already installed, with install instructions and what it does
  - **Cloudflare Rules Required** — if `laravel-cloud-cache` was found in responses, document the required Transform Rule (Modify Response Header → Remove → `laravel-cloud-cache`) and note that the Laravel Cloud dashboard toggle for this is unreliable
  - **Implementation Checklist** — numbered list of concrete tasks (no code, just what to do)
  - **Decisions / Open Questions** — anything that needs a choice before implementation (TTL values, security contact email, sitemap URLs, etc.)

Check `friday_notes_search` first with the app name to avoid creating a duplicate note.

---

## Principles

- **Never implement.** This skill inspects and recommends only.
- **Never guess URLs.** Only check paths that are standard web conventions or that you can read from the codebase.
- **Read-only on production.** Never run any command that mutates production state.
- **cloudflare-security-rule-sync is always on the checklist** for any Laravel + Cloudflare app that doesn't already have it. It blocks non-allowlisted paths at the edge — significant bot/crawler traffic reduction with zero PHP overhead.
