---
name: playwright-setup
description: Install and configure Playwright in any project for ad-hoc browser testing. Installs the package, selects browsers, scaffolds a test output directory, and verifies the installation with a smoke test.
---

# Skill: Playwright Setup

Use this skill to prepare any project (or a standalone directory) for ad-hoc Playwright browser testing. Run this once before using `playwright-browser-test`.

---

## Phase 0 — Check Existing Installation

```bash
npx playwright --version 2>/dev/null || echo "NOT_INSTALLED"
```

If already installed, confirm the version and ask:

**Use `ask_user`:**
> "Playwright is already installed (`<version>`). Do you want to reinstall/update, or is this setup for a different directory?"
Choices: `["Use existing installation", "Reinstall / update", "Set up in a different directory"]`

If "Use existing installation", skip to Phase 3 (verify).

---

## Phase 1 — Determine Install Context

**Use `ask_user`:**
> "Where should Playwright be installed?"
Choices: `["In the current project (adds to package.json)", "In a standalone test directory (separate from the project)"]`

If standalone:
```bash
mkdir -p ~/playwright-tests && cd ~/playwright-tests && npm init -y
```

---

## Phase 2 — Install

```bash
npm init playwright@latest
```

This interactive installer will ask about:
- Test directory name (suggest `tests/` or `e2e/`)
- Whether to add a GitHub Actions workflow (suggest no for ad-hoc use)
- Which browsers to install

**Recommended browser selection for ad-hoc testing:**
- Chromium — fast, reliable, good for headed visual testing
- Firefox — cross-browser validation
- WebKit — optional (slower, useful if testing Safari behavior)

After installation, install the browsers:
```bash
npx playwright install
```

---

## Phase 3 — Scaffold Output Directory

Create a consistent location for screenshots and test artifacts:

```bash
mkdir -p ./playwright-results/screenshots
mkdir -p ./playwright-results/reports
```

Add to `.gitignore` if in a project repo:
```
playwright-results/
test-results/
playwright-report/
```

---

## Phase 4 — Verify Installation

Confirm the version and config:
```bash
npx playwright --version
cat playwright.config.ts 2>/dev/null || cat playwright.config.js 2>/dev/null || echo "No config yet — created on first test run"
```

---

## Phase 5 — Summary

Report:
- Playwright version installed
- Browsers available
- Test output directory: `./playwright-results/`
- Next step: invoke `playwright-browser-test` to write and run a test

---

## Reference

- Playwright docs: https://playwright.dev/docs/intro
- To write and run a test: invoke `playwright-browser-test`
- To evaluate screenshots: invoke `playwright-evaluate-screenshots`
