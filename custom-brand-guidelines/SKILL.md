---
name: custom-brand-guidelines
description: Fetch the live assertchris.dev brand guidelines and audit or suggest how to implement them in the current project.
allowed-tools: Read, Write, Edit, Glob, Bash, WebFetch
user-invocable: true
---

# Brand Guidelines

Fetch the live brand guidelines from https://branding.assertchris.dev, then either audit the current project for compliance or suggest how to implement the guidelines here.

## Credentials

The site is protected by HTTP Basic Auth. The URL is always `https://branding.assertchris.dev`.

Credentials are NOT stored in this skill. Before fetching, ask the user:

> The brand site requires HTTP Basic Auth. What are the username and password?

Wait for the response. If the user says the credentials are already set as environment variables or provides them directly, use those. Store them only in memory for this session — never write them to any file.

## Process

### 1. Fetch the guidelines

Use Bash to fetch the page with curl and the provided credentials:

```bash
curl -s -u "<user>:<pass>" https://branding.assertchris.dev
```

Parse the HTML response to extract the text content of each section. The page is structured as `<h2>` section headings followed by content. Extract the meaningful text, code snippets, and rules from each section — ignore Tailwind class attributes on wrapper divs.

The sections currently on the site are:

- **Logo** — SVG component usage, sizing rules, wrapping requirements, don'ts
- **Dark / Light Mode** — scheme switcher implementation (FOUC prevention script, JS, HTML)
- **Color Palette** — 6 tokens: `bg-background`, `bg-background-secondary`, `bg-foreground`, `bg-foreground-secondary`, `bg-accent`, `bg-on-accent`, each with light/dark values and usage notes
- **Type Palette** — 6 classes: `.type-heading`, `.type-heading-secondary`, `.type-heading-tertiary`, `.type-content`, `.type-content-secondary`, `.type-label`, each with Tailwind composition and use case
- **Spacing** — `flex flex-col gap-4` layout, `[&_h1]:mt-4 [&_h2]:mt-4` heading separation, `space-y-4` for sub-containers, `self-start` for shrink-to-fit elements
- **Voice & Tone** — writing style rules (may include a fragment with inline prose)
- **Imagery & Style** — minimal aesthetic, allowed/disallowed image types, color philosophy (stone scale), centered container `max-w-4xl mx-auto`, reading column `max-w-4xl p-8`, dark mode implementation, accent usage, interactive element conventions, image treatment, SVG diagram support

If the fetch returns 401, tell the user the credentials were rejected and stop.

If the fetch returns anything other than 200, report the status code and stop.

### 2. Determine the mode

ARGUMENTS may be:

- **`audit`** — scan the current project for compliance and report findings
- **`suggest`** — suggest how to implement the brand guidelines in this project, given its tech stack
- **nothing** — default to `suggest`

### 3. Audit mode

Scan the project files for brand-relevant patterns. Focus on:

**Colors:** Look for hardcoded hex values, `#ffffff`, `#000000`, named colors (`red-`, `blue-` other than `blue-600`/`blue-400` for accent), or color classes that bypass the token system.

**Typography:** Look for inline font sizes (`text-base`, `text-lg` etc.) applied directly to content elements instead of the type utility classes. Check whether `.type-heading`, `.type-content` etc. are defined and used.

**Spacing:** Check for `mt-N`/`mb-N`/`pt-N`/`pb-N` on content elements that should be handled by a `gap-4` flex container. Flag `margin-top` and `margin-bottom` in CSS.

**Dark mode:** Check whether dark mode is implemented via CSS custom properties + a `.dark` class on `<html>`, or via Tailwind's `dark:` prefix variant. The brand approach uses the former.

**Logo:** Check for direct SVG copies vs. a component reference.

**Images:** Check for `rounded-xl`, `shadow-`, `grayscale`, `hover:` on `<img>` elements.

Report findings as a structured list grouped by section. For each finding include:
- The file and line number
- What was found
- What the guideline expects

### 4. Suggest mode

Determine the project's tech stack from the files in the working directory (Laravel/Blade, Next.js/React, plain HTML, etc.). Then produce concrete, copy-pasteable implementation suggestions for each brand section:

**Always include:**
- The CSS custom property token definitions (or equivalent for the stack)
- The type utility class definitions
- The dark mode FOUC prevention script
- The scheme switcher JS and HTML
- The spacing container pattern
- Logo component usage example

**Token implementation rules — do not deviate:**
- The brand defines exactly 6 semantic tokens. Their names and the Tailwind palette shades they map to are documented on the brand site — read them from there, do not assume.
- **NEVER hardcode hex values for token definitions.** Tailwind 4 exposes all palette colors as CSS custom properties (e.g. `--color-stone-50`, `--color-blue-600`). Always reference those variables using `var()` so values stay in sync with Tailwind's palette and never drift. The pattern for a Laravel/Tailwind 4 project is:
  ```css
  @theme {
      --color-background: var(--color-<shade-from-brand-site>);
      /* ... one entry per token, values read from the brand site */
  }

  :root.dark {
      --color-background: var(--color-<dark-shade-from-brand-site>);
      /* ... dark overrides, values read from the brand site */
  }
  ```
- Read the exact shade names (e.g. `stone-50`, `stone-950`, `blue-600`) from the brand site's Color Palette section — they are listed there. Map each to its `var(--color-<shade>)` reference. Never substitute your own values.
- For opacity modifiers (e.g. borders, hover states not covered by the 6 tokens), use Tailwind's opacity modifier syntax on existing tokens: `border-foreground/15`, `hover:bg-foreground/10`, `bg-background/50` etc.
- Do NOT invent additional tokens beyond the 6 the brand defines.

**Adapt to the stack:**
- For Laravel/Blade with Tailwind 4: add `@theme` block and `:root.dark` overrides in `resources/css/app.css` — no `tailwind.config.js` needed
- For Next.js/React with Tailwind 4: same approach in `globals.css`
- For plain HTML/CSS: define tokens in a `tokens.css` file; note Tailwind palette vars may not be available without Tailwind

For each suggestion, explain briefly why it matches the guideline — one sentence max. Keep code blocks minimal and runnable.

## Don'ts

1. **DON'T** hardcode the credentials anywhere — not in files, not in commands left in shell history, not in comments
2. **DON'T** commit any file touched during this skill run unless Chris explicitly asks
3. **DON'T** modify the brand site itself — this skill is read-only against that site
4. **DON'T** make assumptions about what the brand guidelines say — always fetch fresh from the site
5. **DON'T** flag issues that are intentional overrides (e.g. a utility page that deliberately uses raw colors for demonstration)
6. **DON'T** rewrite or refactor code during audit mode — report findings only
