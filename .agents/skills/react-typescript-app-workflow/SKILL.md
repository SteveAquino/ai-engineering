---
name: react-typescript-app-workflow
description: Create or improve production-quality React and strict TypeScript web apps, tools, and game companion apps with clear architecture, accessible UX, linting, Jest-based unit tests, browser end-to-end coverage, builds, and useful documentation.
---

# React + TypeScript App Workflow

Use this skill when creating a React web application or making substantial changes to an existing React + TypeScript app, including internal tools, editors, dashboards, prototypes intended to grow, and game companion applications.

The goal is a maintainable, idiomatic app whose structure, behavior, quality gates, and local workflow are clear to both users and future contributors. Adapt to the repository instead of imposing a duplicate framework or unnecessary abstractions.

## Phase 1 — Inspect the repository and define the task

1. Read applicable `AGENTS.md`, contribution guides, and project documentation before changing files.
2. Identify the app root, package manager, lockfile, framework/build tool, TypeScript settings, lint/test/e2e scripts, CI workflow, current architecture, and any existing UI or design system.
3. Inspect representative components, tests, and documentation. Prefer the established patterns when they are sound. Do not migrate a working test runner, package manager, or build system just to match this skill.
4. For an existing app, record its current baseline and relevant failures before making changes. Do not repair unrelated workspace problems silently.
5. Translate the request into user-visible behavior and acceptance criteria. Ask a concise question only when a missing product decision materially affects implementation. For a requested UI mockup or shell, establish the navigable, responsive user flow first and defer unnecessary backend integration.

## Phase 2 — Choose a proportionate architecture

### New app default

Unless the repository or user specifies otherwise, use:

- React with strict TypeScript and Vite.
- Jest, React Testing Library, `user-event`, and jsdom for unit and component behavior.
- ESLint with TypeScript and React hooks rules.
- Playwright for a small number of high-value browser journeys.
- npm and a committed lockfile when no package manager is already established.

Pin compatible dependency ranges and use the repository's supported Node versions. Prefer stable, widely used tooling over adding libraries for simple behavior.

### Existing app

Extend the stack already in use. Keep or add scripts that make the normal quality gates obvious, such as `lint`, `typecheck`, `test:unit`, `test:e2e`, `build`, and an aggregate `test` or `test:all`. Do not rename or remove existing scripts that another workflow depends on.

### Boundaries

- Keep UI rendering, domain rules, and external I/O distinct when the app has meaningful domain behavior. Use a smaller structure for a genuinely small app.
- Keep state local until shared ownership or persistence needs justify a broader state layer. Avoid generic frameworks and speculative abstractions.
- Treat API, browser storage, imported files, and URL data as untrusted inputs; validate at the boundary and represent loading, empty, error, and success states explicitly.
- Centralize repeated semantic behavior and shared tokens/components. Avoid both duplicated screen-specific implementations and premature design systems.
- Make data flow, ownership, and side effects easy to trace. Keep modules cohesive and public interfaces narrow.

## Phase 3 — Build a usable, accessible experience

1. Implement the user workflow in meaningful increments, keeping the app runnable as it evolves.
2. Use semantic HTML, labeled controls, keyboard operation, visible focus, sensible heading order, and accessible names and status announcements. Use ARIA only where native semantics are insufficient.
3. Support the viewport sizes and input modes relevant to the task. Prevent accidental page overflow; retain intentional scrolling within well-defined regions.
4. Provide complete interaction states: disabled and pending actions, validation feedback, empty states, recoverable errors, and success confirmation.
5. Prefer the existing design system. If one does not exist and the task warrants it, define a small set of reusable tokens and components instead of styling every screen independently.
6. Avoid shipping placeholder controls that appear functional but do nothing. Label prototype data honestly and keep mock adapters replaceable without hiding product behavior.

## Phase 4 — Test behavior at the right levels

### Unit and component tests

- Use Jest and React Testing Library for new apps unless the project already has a supported runner. Test observable behavior through roles, labels, text, and user actions rather than implementation details.
- Cover important domain rules, boundary validation, state transitions, and error cases. Keep tests focused, deterministic, and readable; avoid broad snapshots as a substitute for assertions.
- Use shared test setup and fixtures only where they remove real duplication. Do not mock the feature so completely that the test no longer exercises its behavior.

### Browser end-to-end tests

- Use Playwright for a small set of critical journeys that cross meaningful app boundaries: launch, primary workflow, navigation, persistence or API integration, and a representative failure/recovery path as applicable.
- Prefer accessible locators and stable user-visible outcomes. Avoid timing sleeps, brittle CSS selectors, and tests that duplicate every component-level assertion.
- Ensure the test command starts and stops the app predictably, uses a known local port, and fails clearly when prerequisites are missing.

### Quality gates

Run the repository's documented commands. For a new app, provide and run equivalent gates for:

```text
lint → typecheck → unit/component tests → production build → browser e2e
```

Run the narrowest useful checks during iteration, then the full requested gate before handoff. Do not claim a gate passed unless its command completed successfully. Report skipped or blocked checks with the reason and any related pre-existing failure.
For existing apps, start with affected unit/component tests and the minimum
browser screenshot or selected journey needed to assess the change. Reuse the
dev server and unchanged passes. A feature handoff or screenshot request does
not itself require a production build or full suite. Expand only for a named
unresolved integration risk, relevant dependency change, agreed deliverable or
explicit release/audit request; state the reason before the expensive run.
If optional packaging/full validation exposes unrelated failures, record them
and return to focused evidence instead of repairing unrelated product areas.

## Phase 5 — Document the app and its architecture

Create or update documentation alongside the implementation:

- `README.md`: purpose, prerequisites, install, local start, quality commands, and concise project structure.
- Architecture notes when boundaries, data flow, persistence, integrations, or extension points are not obvious from the code. Keep them focused and current.
- User-facing guidance for non-obvious workflows, keyboard use, import/export formats, or configuration.
- Comments for non-obvious reasons and constraints, not line-by-line narration.
- Examples or environment templates for required configuration; never commit credentials or machine-specific paths.

Document actual commands and current behavior. Do not create duplicate, stale plans or broad documents that restate the source code.

## Phase 6 — Review and hand off

Before finishing:

1. Inspect the diff for accidental generated files, secrets, unrelated changes, dead code, misleading controls, accessibility gaps, and stale documentation.
2. Check formatting/lint, types, unit/component tests, build output, and relevant browser journeys as requested and available.
3. Give a concise report with what changed, key architectural choices, exact verification commands and results, and remaining limitations. Link changed files when possible.
4. Leave commit, publication, deployment, or other externally visible actions to the user's explicit request unless already authorized.

## Definition of done

- The requested primary user flow works end to end in the app.
- Strict TypeScript and lint checks pass, or any blocker is explicitly identified.
- Meaningful unit/component tests cover core behavior, with browser e2e for high-value journeys.
- A production build succeeds when initial app bootstrap or standalone delivery
  is in scope; routine local iteration reports its focused evidence separately.
- A contributor can install, run, test, and understand the app from its documentation.
- The code follows existing project conventions and adds no abstraction without a concrete need.
