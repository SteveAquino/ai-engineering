---
name: playwright-browser-test
description: Write and run an ad-hoc Playwright test against any URL — headed or headless. Captures screenshots at key steps and saves them to a results folder for manual review or evaluation by playwright-evaluate-screenshots.
---

# Skill: Playwright Browser Test

Use this skill to write and run an ad-hoc Playwright test for any feature or workflow. No existing test suite required — this creates a self-contained test script, runs it, and captures screenshots at key steps.

Prerequisite: Playwright must be installed. If not, invoke `playwright-setup` first.

---

## Phase 0 — Gather Test Intent

**Use `ask_user`:**
> "What URL and workflow do you want to test? Describe the feature or user journey you want to validate."

Allow freeform. Capture:
- Target URL
- Steps to perform (e.g., "log in, navigate to the dashboard, click New Appointment")
- What success looks like (e.g., "the appointment form appears", "no error messages")
- Any credentials or data needed

**Use `ask_user`:**
> "Run headed (visible browser window) or headless?"
Choices: `["Headed — show the browser", "Headless — run silently in background"]`

**Use `ask_user`:**
> "Which browser?"
Choices: `["Chromium (recommended)", "Firefox", "WebKit (Safari-like)"]`

---

## Phase 1 — Design the Test

Based on the workflow description, outline the test steps:

1. Navigate to `<URL>`
2. `<action 1>` — screenshot after
3. `<action 2>` — screenshot after
4. `<final assertion step>` — screenshot after
5. Save all screenshots to `./playwright-results/screenshots/<test-name>/`

Present the step outline to the user.

**Use `ask_user`:**
> "Does this test plan look right?"
Choices: `["Yes — write and run it", "I want to adjust the steps"]`

---

## Phase 2 — Write the Test Script

Create a self-contained test file:

```bash
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
TEST_NAME="adhoc-$TIMESTAMP"
TEST_FILE="./playwright-results/$TEST_NAME.spec.ts"
SCREENSHOT_DIR="./playwright-results/screenshots/$TEST_NAME"
mkdir -p "$SCREENSHOT_DIR"
```

Write `$TEST_FILE` with a Playwright test matching the approved plan. Use this structure:

```typescript
import { test, expect } from '@playwright/test';
import path from 'path';

const screenshotDir = '<SCREENSHOT_DIR>';

test('<test description>', async ({ page }) => {
  // Step 1: Navigate
  await page.goto('<URL>');
  await page.screenshot({ path: path.join(screenshotDir, '01-initial-load.png') });

  // Step 2: <action>
  await page.click('<selector>');
  await page.screenshot({ path: path.join(screenshotDir, '02-after-action.png') });

  // Step N: Final state
  await page.screenshot({ path: path.join(screenshotDir, '0N-final-state.png') });
});
```

**Screenshot naming convention:** `NN-description.png` (zero-padded step number + what was just done).

**Selector strategy (in order of preference):**
1. `getByRole()` / `getByText()` / `getByLabel()` — semantic, resilient
2. `getByTestId()` — if data-testid attributes exist
3. CSS selectors — last resort

---

## Phase 3 — Run the Test

```bash
HEADED_FLAG="<--headed if headed, empty if headless>"
BROWSER="<chromium|firefox|webkit>"

npx playwright test "$TEST_FILE" \
  $HEADED_FLAG \
  --project="$BROWSER" \
  --reporter=list \
  --output="./playwright-results/artifacts"
```

Capture exit code. Show the test output.

---

## Phase 4 — Report Results

After the run:

```bash
ls ./playwright-results/screenshots/$TEST_NAME/
```

Report:
- ✅ / ❌ Pass or fail
- Number of screenshots captured and their paths
- Any errors or unexpected behavior from the test output
- If the test failed: show the error message and which step it failed at

**Use `ask_user`:**
> "Test complete. What would you like to do next?"
Choices: `["Evaluate the screenshots with playwright-evaluate-screenshots", "Re-run with adjustments", "Done"]`

---

## Reference

- Screenshot output: `./playwright-results/screenshots/<test-name>/`
- To set up Playwright: invoke `playwright-setup`
- To evaluate screenshots: invoke `playwright-evaluate-screenshots`
- Playwright locator docs: https://playwright.dev/docs/locators
