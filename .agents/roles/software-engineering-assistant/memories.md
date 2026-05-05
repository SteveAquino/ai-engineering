
[2026-05-04] Never use `gh pr edit` in repos with GitHub Projects (classic) — use `gh api repos/<owner>/<repo>/pulls/<number> --method PATCH` instead. `gh pr edit` silently fails due to deprecated GraphQL fields.

[2026-05-04] AI-generated bugs cluster into 3 categories requiring different interventions: A (temporal ordering violations) → TDD forcing function (failing test specifying WHEN enforcement fires, written before implementation); B (description-vs-enforcement divergence) → adversarial self-review with enforcement-as-code verification; C (missing security defaults: mass-assignment, XSS, missing auth stubs) → classification + per-class checklist. Applying one fix to all three is the primary failure mode — B/C improvement masks A until a production incident.

[2026-05-04] `implement-ticket` needs a 3-sprint upgrade: Sprint 1 — classification gate (security_class, temporal_contract) + TDD forcing for temporal contracts + agent halts on security_class (no gh pr create); Sprint 2 — human-authored adversarial brief in repo + separate adversarial verification agent (no shared context, blocking CI check); Sprint 3 — human-in-the-loop gate for generated tooling (new skills, agent prompts, tool definitions).

[2026-05-04] The adversarial verification agent for security-class tickets must have NO shared context with the implementing agent. "Adversarial" is a structural property (fixed narrow checklist, separate process, no access to implementing agent's scratchpad), not a prompt posture. A second call to the same agent with adversarial framing inherits the same blind spots.

[2026-05-04] Brainstorm working file hygiene: establish the canonical $WORKING_FILE path before launching any subagents and pass it explicitly in each agent's prompt. Never let subagents choose their own output filenames — this fragments output across multiple files requiring a cleanup pass.

[2026-05-04] For parallel brainstorm rounds: read completed agents immediately on notification, then use `wait: true` on the last remaining one to block cleanly before synthesis. Don't poll.

[skill-candidate] `parallel-pr-fix` (placement: employer:carrum): Takes a PR review summary, locates worktrees for each branch, launches one general-purpose background fix agent per PR with full diff + findings + worktree context, waits for all, then verifies CI and reports results. First seen: 2026-05-04, session a05d9286.

[skill-candidate] `multi-agent-inbox-dispatch` (placement: personal): Given a session output (brainstorm, review, report), composes role-specific inbox messages for 2+ target agents with genuinely different framings tailored to each role's concerns, and writes them in one operation. First seen: 2026-05-04, session a05d9286.

## 2026-05-05 — Dependabot batch session (TEC-8389)

[2026-05-05] For Carrum Rails repos, `gems.carrumhealth.com` (private gem server) is not accessible from agent machines. Use the Dependabot PR's Gemfile.lock diff as ground truth for Rails gem versions, or use the Dependabot branch as a base. Do not attempt `bundle update` for private-source gems without a valid credential or local cache.

[2026-05-05] When manually editing a Gemfile.lock to bump a gem with `< N` upper-bound constraints (e.g. activesupport requiring `minitest < 6`), all transitive deps must also be updated. Use `bundle update <gem> <dep>` rather than editing by hand — manual edits silently break CI.

[2026-05-05] `bundle update` can resolve gems to a higher minor version than the Dependabot target (e.g. rack 3.2.6 vs 3.1.21 target). When this happens, flag it explicitly in the PR description. Add a temporary Gemfile pin (e.g. `gem 'rack', '~> 3.1.0'`) if the reviewer wants patch-only behavior.

[2026-05-05] patient-app-mobile CircleCI E2E tests (`e2e_tests_iphone`, `e2e_tests_web`) are infrastructure-sensitive and frequently flaky. Always check recent master CI runs before attributing E2E failures to a branch change.

[2026-05-05] Use `gh api repos/<owner>/<repo>/pulls/<number> --method PATCH --field title="..."` to rename PR titles. Avoid `gh pr edit --title` — it has GraphQL deprecation issues with Projects classic.

[2026-05-05] [skill-candidate] `dependabot-batch` (placement: employer:carrum): End-to-end skill that inventories open Dependabot PRs, runs parallel package research agents, compiles a review doc, opens per-repo batch draft PRs via a fleet, creates Jira Task + subtasks, and sends an EM handoff message. First seen: TEC-6093 (prior sprint); second occurrence: TEC-8389 (2026-05-05). Passes 5/5 rubric gates — ready to formalize.
