
[2026-05-04] Never use `gh pr edit` in repos with GitHub Projects (classic) — use `gh api repos/<owner>/<repo>/pulls/<number> --method PATCH` instead. `gh pr edit` silently fails due to deprecated GraphQL fields.

[2026-05-04] AI-generated bugs cluster into 3 categories requiring different interventions: A (temporal ordering violations) → TDD forcing function (failing test specifying WHEN enforcement fires, written before implementation); B (description-vs-enforcement divergence) → adversarial self-review with enforcement-as-code verification; C (missing security defaults: mass-assignment, XSS, missing auth stubs) → classification + per-class checklist. Applying one fix to all three is the primary failure mode — B/C improvement masks A until a production incident.

[2026-05-04] `implement-ticket` needs a 3-sprint upgrade: Sprint 1 — classification gate (security_class, temporal_contract) + TDD forcing for temporal contracts + agent halts on security_class (no gh pr create); Sprint 2 — human-authored adversarial brief in repo + separate adversarial verification agent (no shared context, blocking CI check); Sprint 3 — human-in-the-loop gate for generated tooling (new skills, agent prompts, tool definitions).

[2026-05-04] The adversarial verification agent for security-class tickets must have NO shared context with the implementing agent. "Adversarial" is a structural property (fixed narrow checklist, separate process, no access to implementing agent's scratchpad), not a prompt posture. A second call to the same agent with adversarial framing inherits the same blind spots.

[2026-05-04] Brainstorm working file hygiene: establish the canonical $WORKING_FILE path before launching any subagents and pass it explicitly in each agent's prompt. Never let subagents choose their own output filenames — this fragments output across multiple files requiring a cleanup pass.

[2026-05-04] For parallel brainstorm rounds: read completed agents immediately on notification, then use `wait: true` on the last remaining one to block cleanly before synthesis. Don't poll.

[skill-candidate] `parallel-pr-fix` (placement: employer:carrum): Takes a PR review summary, locates worktrees for each branch, launches one general-purpose background fix agent per PR with full diff + findings + worktree context, waits for all, then verifies CI and reports results. First seen: 2026-05-04, session a05d9286.

[skill-candidate] `multi-agent-inbox-dispatch` (placement: personal): Given a session output (brainstorm, review, report), composes role-specific inbox messages for 2+ target agents with genuinely different framings tailored to each role's concerns, and writes them in one operation. First seen: 2026-05-04, session a05d9286.
