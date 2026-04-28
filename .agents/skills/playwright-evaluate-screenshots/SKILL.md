---
name: playwright-evaluate-screenshots
description: Evaluate a folder of Playwright screenshots using vision to determine whether each step succeeded or failed. Takes a description of expected behavior and produces a structured pass/fail report with observations per screenshot.
---

# Skill: Playwright Evaluate Screenshots

Use this skill after `playwright-browser-test` to evaluate the captured screenshots and determine whether the tested workflow succeeded. Uses vision to analyze each screenshot against the expected behavior.

---

## Phase 0 — Locate Screenshots

**Use `ask_user`:**
> "Which screenshot folder should I evaluate? (e.g., `./playwright-results/screenshots/adhoc-20260409-143022`)"

Allow freeform, or list available folders:

```bash
ls ./playwright-results/screenshots/ 2>/dev/null || echo "No results directory found"
```

If multiple folders exist, present them as choices.

Store as `SCREENSHOT_DIR`.

---

## Phase 1 — Gather Expected Behavior

**Use `ask_user`:**
> "Briefly describe what a successful run looks like. What should each key step show?"

Allow freeform. This becomes the evaluation criteria — e.g.:
- "After login, the dashboard should show the user's name in the header"
- "The appointment form should appear with fields for date, time, and provider"
- "No error banners or 404 pages should be visible at any step"

---

## Phase 2 — List and Order Screenshots

```bash
ls -1 "$SCREENSHOT_DIR" | sort
```

Present the list of screenshots with their filenames. Confirm the ordering makes sense as a step sequence.

---

## Phase 3 — Evaluate Each Screenshot

For each screenshot in order, use vision to analyze the image:

```bash
# Display each screenshot for analysis
for img in "$SCREENSHOT_DIR"/*.png; do
  echo "Evaluating: $img"
done
```

For each image, evaluate:
1. **What is visible** — describe the UI state shown
2. **Expected vs actual** — does it match the expected behavior from Phase 1?
3. **Verdict** — ✅ Looks correct / ⚠️ Unclear / ❌ Looks wrong
4. **Observations** — any errors, unexpected UI, missing elements, or notable details

---

## Phase 4 — Produce Report

Output a structured evaluation report:

```markdown
# Screenshot Evaluation Report
**Test folder:** <SCREENSHOT_DIR>
**Evaluated:** <timestamp>
**Overall verdict:** ✅ PASS / ❌ FAIL / ⚠️ PARTIAL

---

## Step-by-Step Results

### 01-initial-load.png — ✅ Pass
**Observed:** Homepage loaded at example.com, login form visible with email and password fields.
**Expected:** Login page should be visible.
**Notes:** Page title matches, no error banners.

### 02-after-login.png — ✅ Pass
**Observed:** Dashboard visible, user name "Steven" shown in top-right navigation.
**Expected:** User should be logged in and see the dashboard.
**Notes:** –

### 03-appointment-form.png — ❌ Fail
**Observed:** Blank white page with "Something went wrong" error banner.
**Expected:** Appointment creation form should be visible.
**Notes:** This step failed — the form did not load. Possible causes: missing permissions, route error, or session timeout.

---

## Summary

- Steps evaluated: 3
- Passed: 2
- Failed: 1
- Unclear: 0

**Recommendation:** Investigate step 3 — the appointment form failed to load. Check browser console logs or re-run with `--headed` to observe the failure live.
```

---

## Phase 5 — Next Steps

**Use `ask_user`:**
> "Evaluation complete. What would you like to do?"
Choices: `["Re-run the test with playwright-browser-test", "Save this report to a file", "Done"]`

If "Save report":
```bash
REPORT_FILE="./playwright-results/reports/evaluation-$(date +%Y%m%d-%H%M%S).md"
# Write the report markdown to $REPORT_FILE
echo "Report saved to $REPORT_FILE"
```

---

## Reference

- To run a test and capture screenshots: invoke `playwright-browser-test`
- To set up Playwright: invoke `playwright-setup`
- Screenshot folder convention: `./playwright-results/screenshots/<test-name>/NN-description.png`
