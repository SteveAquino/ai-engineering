---
name: weekly-impact-recap
description: Produces an evidence-based weekly impact recap from Jira, GitHub, Slack, a notes vault, and related local artifacts, with a concise visual dashboard and explicit attribution. Org-specific configuration (vault path, org/repo, Jira project and pod conventions, internal workflows) lives in an optional gitignored local overlay — see "Local overlay" below.
---

# Skill: Weekly Impact Recap

Create a concise but evidence-rich recap of the previous Monday–Sunday work week. The goal is to
show leadership leverage and team delivery outcomes, not merely personal task completion.

## Local overlay (optional)

Before running, check for a local overlay:

```bash
cat "$(dirname "$0")/references/local.md" 2>/dev/null || echo "(no local overlay — using defaults/prompts)"
```

`references/local.md` is gitignored (see `.gitignore`'s `.agents/skills/*/references/` rule) and
never committed. If present, it may define: the vault/notes path, GitHub org and repos, Jira
project key(s) and pod/team names, status-category conventions (e.g. which statuses count as
"released"), and any other org-specific source locations or internal workflows. See
`docs/local.example.md` for the full set of supported keys and their format. Treat any value not
set there as unknown — fall back to asking the user or to the generic behavior described below.

## When to run

Run from `prepare-daily-plan` on Mondays for whichever role is configured to receive a weekly
impact recap (see that skill's Monday integration step). May also be invoked directly when a
weekly impact recap is requested for any role.

## Inputs

- Current date and target role.
- Vault/notes path: read `VAULT_PATH` from `references/local.md` if present; otherwise ask the
  user, or use the `obsidian-vault` skill if one is configured for this environment.
- Live Jira and GitHub access when available, scoped to whatever org/project the local overlay
  (or the user) specifies.
- Local daily plans, daily notes, Slack digests/activity summaries, Jira/GitHub/email summaries,
  meeting notes, and role inbox/session artifacts.

## Output

Write the recap to:

```text
<VAULT_PATH>/Weekly Recaps/<YYYY-MM-DD> to <YYYY-MM-DD> Accomplishments.md
```

Use the previous Monday and Sunday as the date range. Verify the file exists and is readable
before reporting success.

## Evidence and attribution rules

1. Timebox the work to approximately 8 minutes. Prefer a broad, defensible synthesis over
   exhaustive searching.
2. Use live `gh` and Jira CLI queries when available to substantiate:
   - PRs reviewed, approved, commented on, and merged.
   - Jira/tracker items that moved through review, testing, released, or deployed states.
   - Blockers, escalations, production/support issues, and ownership changes.
3. Distinguish clearly between:
   - **You individually** — directly evidenced personal work.
   - **Team-delivered outcomes** — work owned by teammates or the broader organization.
   - **Leadership leverage** — review, unblock, triage, escalation, coordination, and coverage
     that helped the team move.
4. Never infer causation from proximity. Say "leadership-enabled" or "contributing
   review/unblock" when the evidence does not establish sole ownership.
5. Preserve direct links for Jira tickets, GitHub PRs, Slack permalinks, and relevant vault notes.
6. If the user supplies an accomplishment that local artifacts do not independently verify,
   include it with an explicit `user-supplied` or `not independently verified` label.
7. Treat missing weekend or holiday artifacts as unknown coverage, not proof that no work
   occurred.
8. Keep personal operating hygiene (for example, inbox cleanup) out of headline impact. If
   retained, place it in a clearly labeled "Personal Operating Hygiene (not an impact item)"
   section.

## Required report structure

```markdown
# Weekly Accomplishments Recap — <start>–<end>

> Coverage and freshness note.

---

## ⚡ At a Glance

> **Theme:** one-sentence leadership/delivery theme.

| Signal | Result | Status |
|---|---:|---|
| <measured activity> | **N** | <percentage bar only when a denominator exists> |
| <counted outcome> | **N** | `● Verified activity` |
| <open work> | **N** | `⚠ Carryover` |

### 🏅 Notable Outcomes

- <three to five outcome-focused bullets>

> **Reading key:** Use progress bars only for ratios with meaningful denominators. Use status
> labels for raw counts; never render every count as a 100% bar.

## 🎯 Executive Impact Summary
<short synthesis of leadership leverage and team value>

## 🧭 Your Leadership & Delivery Leverage
<reviews, unblockers, triage, escalations, operating coverage, decisions>

## 🏢 Team Outcomes (team-delivered, leadership-enabled)
<team-owned Jira and delivery outcomes with attribution — use the pod/team name from the local
overlay if one is configured, otherwise a generic "Team"/"Pod" label>

## 🏗️ Broader Organization Outcomes
<cross-team delivery, standards, incidents, documentation, and enablement>

## 🧹 Personal Operating Hygiene (not an impact item)
<optional; only if useful for completeness>

## 📊 Concrete Evidence Table
<PR/Jira/support/leadership rows with status, role, and source>

## 🟡 Open Risks / Carryover into next week
<specific unresolved items and owners>

## 📚 Sources / Coverage Note
<reviewed sources, live queries, and explicit gaps>
```

## Collection workflow

### 1. Establish the range

```bash
date "+%Y-%m-%d %A"
```

Set `WEEK_START` to the previous Monday and `WEEK_END` to the previous Sunday. Do not use the
current Monday as part of the recap.

### 2. Review local artifacts

Read `VAULT_PATH` from `references/local.md` (or however it was resolved in Inputs above), then
inspect only files relevant to `WEEK_START..WEEK_END`:

```bash
find "$VAULT_PATH" \
  \( -path "*/Daily Plans/*" -o -path "*/Daily Notes/*" \
  -o -path "*/Daily Slack Digests/*" -o -path "*/Inbox Summaries/*" \
  -o -path "*/Meetings/*" \) \
  -type f | sort
```

Prioritize daily plans, end-of-day notes, Slack activity summaries, Jira/GitHub summaries, and
meeting/OOO coverage notes.

### 3. Run bounded live evidence queries

If authenticated tools are available, query the date range once. Read `GH_ORG` from
`references/local.md`; if not set, ask the user or omit `--owner` and search across accessible
repos:

```bash
gh search prs --owner "$GH_ORG" \
  --reviewed-by @me \
  --updated "$WEEK_START..$WEEK_END" \
  --json repository,number,title,url,state,updatedAt
```

Use whatever Jira CLI conventions, project key(s), and pod/team fields are documented in
`references/local.md` (or ask the user) to find tracker items that changed status during the
range. Record exact command failures rather than silently substituting stale summaries.

### 4. Synthesize and write

Prefer concrete outcomes over activity volume:

- "26 PRs reviewed; 22 merged" is stronger than "participated in reviews."
- "24 tracker items moved through review/release states, mostly teammate-owned" preserves team
  attribution.
- "Production issue escalated to the owning team" captures leadership value without claiming a
  fix you did not author.

Write the report with UTF-8 encoding. Do not mutate Jira, GitHub, Slack, or email.

### 5. Verify

```bash
test -r "$RECAP_PATH"
wc -c "$RECAP_PATH"
```

Report the path, evidence counts, key gaps, and whether live queries were available.
