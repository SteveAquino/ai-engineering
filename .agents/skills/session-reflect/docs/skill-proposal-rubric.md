# Skill Proposal Quality Rubric

A proposed skill must pass this rubric before being formalized into a `SKILL.md`. Its purpose is to keep the skill library high-signal — 10 excellent skills beat 50 mediocre ones.

---

## The Five Gates

A skill proposal should pass **at least 4 of 5** gates. A proposal that fails 2 or more is a `[skill-candidate]` at best — record it in memories and wait for recurrence.

The gates apply regardless of where the skill will live (personal, employer, or role-specific). Placement is a separate decision made at formalization time.

| # | Gate | Pass condition |
|---|------|---------------|
| 1 | **Value to target audience** | Does this skill provide meaningful value to the roles or contexts it's designed for? A skill for a single role is fine — it just needs to be genuinely useful to that role, not a one-off. |
| 2 | **Knowledge capture value** | Does it encode a non-obvious workflow that's hard to re-derive without the skill? If an experienced agent could reproduce the steps from first principles in under 2 minutes, the skill adds little value. |
| 3 | **Recurrence signal** | Has this pattern appeared in **2 or more independent sessions**? First-occurrence patterns are candidates, not skills. |
| 4 | **Independence** | Is the skill self-contained, or is it just a thin wrapper that re-explains another skill without adding logic? Thin routers (like `implement-ticket`) are valid only when they meaningfully classify or route between options. |
| 5 | **Onboarding value** | Would an agent new to this role or context benefit from this skill? If it requires deep prior context to be useful, it belongs in a role's `memories.md` instead. |

---

## When to Record vs. Formalize

| Signal | Action |
|--------|--------|
| Pattern appeared once in a session | Add `[skill-candidate]` to the relevant role's `memories.md` |
| Pattern appeared in 2+ independent sessions | Propose for formalization; check rubric |
| Passes 4+ gates | Create the skill with `create-skill` |
| Passes fewer than 4 gates | Keep as `[skill-candidate]` in memories; revisit after next occurrence |

---

## Memory Tagging Convention

When something skill-like happens in a session, log it in the role's `memories.md` using this format:

```
[skill-candidate] `<proposed-name>` (placement: <personal|employer:<org>|role:<role-name>>): <one-sentence description of what it does and when it's useful>. First seen: <session date or ID>.
```

**Examples:**
```
[skill-candidate] `summarize-apple-mail` (placement: personal): Reads unread Apple Mail via local SQLite Envelope Index, categorizes messages, produces actionable digest. First seen: 2026-05-04.
[skill-candidate] `bug-coverage-audit` (placement: employer:carrum): Audits regression test coverage on bug fix PRs for a Jira project. First seen: 2026-05-01.
[skill-candidate] `draft-weekly-retro` (placement: role:engineering-manager-assistant): Generates a weekly team retro from PR activity and qualitative notes. First seen: 2026-04-20.
```

Including a placement hint at tagging time speeds up formalization — but it's optional. `create-skill` will classify at formalization time if no hint is provided.

Do NOT write a full `SKILL.md` at this stage. The candidate lives in memory until recurrence triggers formalization.

---

## Dream-Time Consolidation

When the `dream` skill runs for a role, it should:

1. Scan `memories.md` for lines tagged `[skill-candidate]`
2. Group candidates by concept proximity (same tool, same workflow domain, same trigger)
3. If **2 or more independent entries** cluster around the same concept → surface a skill proposal as a finding in the dream output, using the rubric to score it
4. If a candidate hasn't recurred after **3+ dream cycles** → flag it as stale and recommend pruning

The dream output should include a section:

```
## Skill Candidate Review
- `<name>`: N occurrences — [recommend formalizing | keep watching | prune]
```

---

## What Does NOT Belong in the Skill Library

- One-off audit outputs (session artifacts, not reusable workflows)
- Skills that duplicate an existing skill with minor variation
- "Skills" that are really just role memory entries (habits, preferences, context)
- Wrapper scripts around a single CLI command with no added logic

**Note:** Employer-specific and role-specific skills are fully valid — they just need to pass the rubric and land in the right place. A workflow that only makes sense at one company or for one role can still be an excellent skill. The question is always quality and recurrence, not portability.
