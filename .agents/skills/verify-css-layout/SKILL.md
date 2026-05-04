---
name: verify-css-layout
description: Write and run a headless Playwright test against a URL to visually verify CSS layout. Captures screenshots at key interaction steps and renders them for review. Use whenever CSS changes might affect rendered layout — especially for chat panels, message bubbles, or complex flex/grid layouts.
status: proposed
proposed: 2026-05-01
context: care-app-web chat panel layout debugging session
---

# Skill: Verify CSS Layout

Use this skill to confirm that a CSS or JSX change actually renders correctly in a browser — not just looks correct in code. Especially useful for:
- Chat message bubble alignment (flex-end, right-align)
- Grommet layout edge cases
- Responsive width/height behavior under dynamic content

---

## Inputs

Ask the user for:
1. **URL** — the page to test (e.g., `http://localhost:8081/episodes/123`)
2. **Steps** — a plain-English list of interaction steps (click X, fill Y, send message, etc.)
3. **Assertions** — what to look for in the screenshots (e.g., "user bubble right-aligned", "no overflow on long messages")

---

## Phase 1 — Confirm Playwright is available

```bash
ls <app-dir>/node_modules/.bin/playwright 2>/dev/null && echo "found" || echo "not found"
```

If not found, install it:
```bash
cd <app-dir> && npx playwright install chromium --with-deps
```

---

## Phase 2 — Write the test script

Write a file `/tmp/layout-test.mjs` using ESM syntax (`import`):

```js
import { chromium } from '<app-dir>/node_modules/playwright/index.mjs';
import { writeFileSync, mkdirSync } from 'fs';

const OUT = '/tmp/layout-screenshots';
mkdirSync(OUT, { recursive: true });

const browser = await chromium.launch({ headless: true });
const page = await browser.newPage();
await page.setViewportSize({ width: 1440, height: 900 });

// ── Login / setup ──
await page.goto('<URL>');
// ... add auth steps if needed ...

// ── Interaction steps ──
// step 1
await page.writeFileSync = null; // placeholder

// ── Screenshots ──
await page.screenshot({ path: `${OUT}/01-initial.png`, fullPage: false });

await browser.close();
console.log('Screenshots saved to', OUT);
```

Fill in the interaction steps based on user input. Capture a screenshot after each meaningful state change.

---

## Phase 3 — Run the test

```bash
node /tmp/layout-test.mjs
```

---

## Phase 4 — View screenshots

Read each screenshot using the `view` tool. For each one, describe:
- What is visible
- Whether it matches the expected layout
- Any alignment, overflow, or wrapping issues

---

## Phase 5 — Report

Output a pass/fail summary:

```
✅ 01-initial.png — panel rendered correctly
✅ 02-after-message.png — user bubble right-aligned, no overflow
❌ 03-long-message.png — bubble stretches full width (justify-end not working)
```

If any screenshot fails, describe the root cause and suggest a fix.

---

## Notes

- Always resolve Playwright from the app's `node_modules`, not globally.
- Use `import` (ESM), not `require()` — `playwright/index.mjs` is ESM-only in newer versions.
- Run scripts with `node --experimental-vm-modules` if import syntax causes issues with older Node.
- For Grommet flex layout bugs: look for `<Box>` shrinking to content width — the most common cause of `justify-end` doing nothing.
