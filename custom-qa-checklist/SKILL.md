---
name: custom-qa-checklist
description: Generates a manual QA test checklist from the feature doc for the current branch. Use when user asks to create a QA checklist, test plan, or wants a list of user-facing things to test in the browser.
allowed-tools: Read, Glob, Bash(git *)
user-invocable: true
---

# QA Checklist Generator

This skill generates a manual QA test checklist from feature documentation, extracting only user-facing functionality that a QA engineer can test in a browser.

## Purpose

Feature docs contain comprehensive technical details, but QA engineers need a focused list of what to manually test in the browser. This skill extracts:
1. User-facing functionality and UI elements to verify
2. User flows and interactions to walk through
3. Edge cases and error states to trigger
4. Visual/UX elements to check (responsive, localization, etc.)

**This skill does NOT include:**
- "Run the automated tests"
- "Check the code does X"
- Backend implementation details
- Database queries or API internals
- Things that can't be verified by clicking around in a browser

## Process

### Step 1: Detect Current Branch

```bash
git branch --show-current
```

Extract the branch name and handle common patterns:
- `feature/sports-2345-add-something` → `sports-2345-add-something`
- `sports-2345-add-something` → `sports-2345-add-something`
- `bugfix/fix-thing` → `fix-thing`

### Step 2: Find Feature Doc

```bash
ls features/ | grep "<branch-name-without-prefix>"
```

If no feature doc exists:
- Inform the user that no feature doc was found for this branch
- Suggest they create one with `/feature-doc` or provide a different branch/file name
- Ask if they want to specify a feature doc path manually

### Step 3: Read Feature Doc

Read the feature doc at `features/<branch-name-without-prefix>.md`.

### Step 4: Extract User-Facing Test Scenarios

Parse the feature doc and extract ONLY user-facing things to test. Look at these sections:

**Overview / Target Outcome:**
- What can users now do that they couldn't before?
- What existing flows have changed?

**Functional Requirements:**
- Filter for user-facing capabilities (ignore backend-only requirements)
- Look for: "users can X", "modal opens", "button shows", "form validates", etc.

**UX / Admin Requirements:**
- UI elements to verify
- Visual states (loading, disabled, error, success)
- Responsive behavior
- Accessibility considerations

**Implementation Plan / Phase Descriptions:**
- Look for mentions of UI components, forms, buttons, modals, pages
- Identify user interactions (click, type, submit, etc.)
- Note any conditional display logic (feature flags, permissions, etc.)

**Key things to identify:**
1. **Happy Path Flows**: Primary user journeys to test
2. **UI Elements**: Buttons, forms, modals, dropdowns, messages
3. **Validation**: Form validation, error messages, edge cases
4. **States**: Loading, success, error, disabled, empty states
5. **Localization**: Text translations, date formats, number formats
6. **Responsive**: Desktop vs mobile vs tablet behavior
7. **Integration Points**: Where this feature connects with existing features

**Things to IGNORE:**
- Automated test coverage
- Code implementation details ("uses JWT", "caches for 1 hour", etc.)
- Database schemas or queries
- API endpoints (unless testing their user-facing response)
- Middleware or backend logic
- Config files or environment variables

### Step 5: Generate QA Checklist

Create a checklist with this structure:

```markdown
# QA Checklist: [Feature Name]

Branch: `[branch-name]`

## Prerequisites
- [ ] Branch deployed to QA environment
- [ ] [Any specific setup needed, e.g., "Feature flag enabled for MX tenant"]
- [ ] [Any test accounts or data needed]

## Happy Path Testing

### [Primary Flow Name]
- [ ] [Step 1 - what to do and what should happen]
- [ ] [Step 2]
- [ ] [Step 3]

### [Secondary Flow Name]
- [ ] [Step 1]
- [ ] [Step 2]

## UI Elements

### [Section/Component Name]
- [ ] [Element] displays correctly (text, styling, position)
- [ ] [Element] responds to interaction (hover, click, focus)
- [ ] [Element] shows correct state (enabled/disabled/loading)

## Edge Cases & Validation

### [Form/Feature Name]
- [ ] Empty/missing required fields show validation errors
- [ ] Invalid input (wrong format, too long, etc.) is rejected
- [ ] Error messages are clear and helpful
- [ ] [Specific edge case to test]

## Error Handling
- [ ] [What happens when X fails - network error, invalid data, etc.]
- [ ] User sees appropriate error message
- [ ] User can recover from error state

## Localization (if applicable)
- [ ] All text displays in correct language
- [ ] Dates/numbers formatted correctly for locale
- [ ] No untranslated keys or placeholder text visible

## Responsive / Cross-browser
- [ ] Desktop (1920x1080): [Key things to check]
- [ ] Tablet (768px): [Key things to check]
- [ ] Mobile (375px): [Key things to check]
- [ ] Test in [Chrome, Firefox, Safari if relevant]

## Integration Testing
- [ ] [How this feature works with existing feature A]
- [ ] [How this feature works with existing feature B]
- [ ] [Any side effects to verify in other parts of the app]

## Regression Testing
- [ ] [Existing functionality that shouldn't be affected]
- [ ] [Other tenants/configurations still work correctly]
```

### Step 6: Format and Present

- Display the checklist as raw markdown with all checkbox syntax visible `- [ ]`
- Keep items actionable and specific (not vague like "test the button")
- Group related items together
- Each checkbox should describe both the action AND expected result
- Prioritize common/critical flows over obscure edge cases
- Include realistic test data examples when helpful
- Keep the entire checklist under 50 items if possible (focused)

## Example Usage

**User**: "Generate a QA checklist" or "/qa-checklist"

**Process**:
1. Run `git branch --show-current` → `feature/sports-3214-add-firebase-auth`
2. Find feature doc → `features/sports-3214-add-firebase-auth.md`
3. Read and parse the feature doc
4. Extract user-facing functionality (login modal, form fields, error messages, etc.)
5. Ignore backend details (JWT verification, token refresh logic, middleware, etc.)
6. Generate focused QA checklist organized by test type
7. Present the formatted checklist with all markdown characters visible

## Example of Good vs Bad Checklist Items

**GOOD (User-facing, actionable, specific):**
- [ ] Click "ENTRAR" button in header, login modal appears below button
- [ ] Enter invalid email format, submit button is disabled
- [ ] Enter wrong password, see "Contraseña incorrecta" error message in Spanish
- [ ] Successfully log in, page refreshes and shows logged-in user name in header
- [ ] On mobile (375px), modal is centered and fits on screen without horizontal scroll

**BAD (Too technical, not user-facing):**
- [ ] Verify JWT token is validated server-side
- [ ] Check that RefreshFirebaseToken middleware runs on every request
- [ ] Confirm service_tokens table has correct schema
- [ ] Run the automated tests
- [ ] Verify Firebase public keys are cached for 1 hour

## Edge Cases

### No Feature Doc Found
If the feature doc doesn't exist:
- Inform the user clearly
- Suggest creating one with `/feature-doc`
- Offer to try a different file name if they specify it

### Feature Doc Has No User-Facing Changes
If the feature is purely backend (API changes, refactoring, etc.):
- Inform the user this appears to be a backend-only change
- Suggest testing via API tools (Postman, curl) if applicable
- Or suggest the change may not need manual QA beyond automated tests

### Main/Master Branch
If on main or master branch:
- Inform the user this doesn't make sense for main branch
- Ask if they meant to run this on a feature branch

### Feature Doc Not Yet Complete
If the feature doc hasn't been filled in (still has `{{PLACEHOLDERS}}`):
- Work with whatever information is available
- Note in the checklist that some details are TBD
- Focus on what IS documented

## Don'ts

1. **DON'T** include items like "Run the automated tests" or "Run php artisan test"
2. **DON'T** include code review items ("Check the JWT verification logic")
3. **DON'T** include backend implementation details ("Verify tokens are cached")
4. **DON'T** include database or API internals ("Check service_tokens table")
5. **DON'T** copy the entire feature doc into the checklist
6. **DON'T** include "Session History" or "Progress" sections
7. **DON'T** make the checklist longer than 50 items unless absolutely necessary
8. **DON'T** use vague items ("Test the login" - be specific about what to test)

## Success Criteria

A successful QA checklist:
- **Displays raw markdown syntax** with `- [ ]` checkbox format visible
- Is formatted in markdown (proper headers, checkbox lists)
- Contains 20-50 actionable test items (focused, not exhaustive)
- Every item is something a QA engineer can do in a browser
- Each item describes both the action AND expected result
- Covers happy path, edge cases, errors, and visual/UX concerns
- Is organized logically (by flow, by component, by test type)
- Contains NO items about running automated tests or checking code
- Contains NO backend implementation details
- Includes relevant localization, responsive, and integration testing
- Is ready to copy-paste into a QA ticket or testing tool
- Makes QA engineers confident they know what to test
