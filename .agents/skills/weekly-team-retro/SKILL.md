---
name: weekly-team-retro
description: Generates a weekly engineering team retrospective. Fetches PR activity and Jira ticket completions for the current week, mines qualitative signals from Obsidian (Slack/email summaries, EOD notes, 1:1s) in autopilot mode or prompts the EM interactively, and saves a persistent markdown report to the EM assistant role's weekly-retros directory. Requires GitHub CLI (gh) and Atlassian CLI (acli).
---

# Skill: Weekly Team Retro

Generate a weekly engineering team retrospective. This skill pulls quantitative data (PRs merged, tickets resolved, post-mortems) from the current week, collects qualitative engineer notes — either mined automatically from Obsidian sources or gathered interactively via `ask_user` — then writes a structured markdown report to the EM role's persistent store.

**Autopilot mode:** When no user is available (cron, async session, user not responding), skip all `ask_user` calls and mine qualitative signals from Obsidian instead. See Phase 2.5.

**Prerequisites:**
- [`gh`](https://cli.github.com/) — GitHub CLI, authenticated
- [`acli`](https://developer.atlassian.com/cloud/acli/) — Atlassian CLI, authenticated

---

## Storage

Weekly retros are stored persistently in the EM assistant role directory:

```
~/work/personal/ai-engineering/agents/engineering-manager-assistant/weekly-retros/YYYY-MM-DD-team-retro.md
```

The date in the filename is always the **Monday** of the week being covered.

---

## Phase 0 — Load Team Context

Load team config from the `references/` directory (if present — see Local References below).
The reference file provides `GITHUB_ORG`, `JIRA_PROJECT`, `JIRA_DOMAIN`, `TEAM_NAME`, and a pointer to the repo list.

If any value is absent after loading references, prompt for it:

> **Use `ask_user`:**
> "What is your GitHub org?" *(freeform)*

> "Which repos should I track? Provide a comma-separated list." *(freeform)*

> "What is your Jira project key? (e.g. ENG, PLAT, TEC)" *(freeform)*

> "What is your Jira domain? (e.g. your-org.atlassian.net)" *(freeform)*

> "What should I call your team in the report? (e.g. Engineering Team, Platform Team)" *(freeform)*

Store `GITHUB_ORG`, `REPOS`, `JIRA_PROJECT`, `JIRA_DOMAIN`, and `TEAM_NAME` as variables for the rest of this skill.

---

## Phase 1 — Determine Week Window

Compute the Monday–Friday window for the current week:

```python
from datetime import datetime, timedelta, timezone
today = datetime.now(timezone.utc)
monday = today - timedelta(days=today.weekday())
week_start = monday.replace(hour=0, minute=0, second=0, microsecond=0)
week_end = week_start + timedelta(days=4, hours=23, minutes=59, seconds=59)
week_label = week_start.strftime("%B %-d–") + (week_start + timedelta(days=4)).strftime("%-d, %Y")
file_date = week_start.strftime("%Y-%m-%d")
```

Check if a retro for this week already exists:

```bash
RETRO_DIR="$HOME/work/personal/ai-engineering/agents/engineering-manager-assistant/weekly-retros"
ls "$RETRO_DIR/${file_date}-team-retro.md" 2>/dev/null
```

If it exists, ask:

> **Use `ask_user`:**
> "A retro for this week already exists. What would you like to do?"
> Choices: `["Update it with new notes", "Start fresh", "Open existing (read-only)"]`

---

## Phase 2 — Fetch Quantitative Data

Run all fetches in parallel.

### 2a. PRs merged this week

Query all configured repos for PRs merged within the week window:

```bash
for repo in "${REPOS[@]}"; do
  gh pr list --repo "$GITHUB_ORG/$repo" --state merged \
    --json number,title,url,mergedAt,additions,deletions,reviews \
    --limit 100
done
```

Filter to `mergedAt` within the week window. For each PR record:
- `title`, `number`, `url`, `repo`
- `size` = additions + deletions
- `human_reviews` = reviews where author.login is not a bot (`dependabot[bot]`, `github-actions[bot]`, `copilot-pull-request-reviewer[bot]`, `copilot-swe-agent[bot]`)
- `review_lag_hours` = time from `createdAt` to first human review `submittedAt`
- Match `<JIRA_PROJECT>-` ticket keys in title for Jira linkage

### 2b. Tickets resolved this week (Jira)

```bash
acli jira workitem search \
  --jql "project = <JIRA_PROJECT> AND sprint in openSprints() AND status changed to (Released, Done, Closed, Deployed) AFTER '<WEEK_START_DATE>'" \
  --fields "key,summary,status,assignee,issuetype" \
  --json --limit 200
```

If `sprint in openSprints()` returns empty (sprint may be closed), fall back to:
```bash
--jql "project = <JIRA_PROJECT> AND sprint = '<SPRINT_NAME>' AND resolutiondate >= '<WEEK_START_DATE>'"
```

Record: key, summary, status, assignee displayName, issue type.

### 2c. Post-mortems in sprint

```bash
acli jira workitem search \
  --jql "project = <JIRA_PROJECT> AND sprint = '<SPRINT_NAME>' AND (summary ~ 'post-mortem' OR summary ~ 'postmortem')" \
  --fields "key,summary,status,assignee" \
  --json --limit 20
```

### 2d. Build the engineer roster

From the tickets resolved and PRs merged, collect unique assignee displayNames and PR authors. This is the roster to iterate through for qualitative notes.

To get PR authors (gh doesn't always return `author` in list output), use assignees from Jira tickets as the primary source. Supplement with PR reviewer lists if needed.

---

## Phase 2.5 — Mine Qualitative Sources

Run this phase regardless of interactive/autopilot mode. In interactive mode the mined data pre-populates the `ask_user` prompts. In autopilot mode it replaces them entirely.

### 2.5a — Locate Obsidian Vault

Read `OBSIDIAN_VAULT` from the `references/` file (e.g., `carrum.md`). If not present, fall back to the EM role's `memories.md` (grep for "Obsidian vault").

### 2.5b — Collect weekly source files

```python
import os, glob
from datetime import timedelta

VAULT = "<OBSIDIAN_VAULT>"
days = [week_start + timedelta(days=i) for i in range(5)]  # Mon–Fri

slack_files, email_files, eod_files = [], [], []
for d in days:
    ds = d.strftime("%Y-%m-%d")
    # Slack — two naming conventions
    for pattern in [f"{ds} Slack Summary.md", f"{ds} Slack Digest.md"]:
        p = os.path.join(VAULT, "Inbox Summaries", "Slack", pattern)
        if os.path.exists(p): slack_files.append(p)
    # Email
    p = os.path.join(VAULT, "Inbox Summaries", "Email", f"{ds} Email Summary.md")
    if os.path.exists(p): email_files.append(p)
    # EOD notes
    p = os.path.join(VAULT, "Daily Notes", f"{ds} End of Day.md")
    if os.path.exists(p): eod_files.append(p)
```

Read all found files into a single `weekly_context` string.

### 2.5c — Scan 1:1 notes for the week

For each engineer on the roster, check if a 1:1 note exists for any day in the week window:

```python
one_on_one_notes = {}
ONE_ON_ONE_BASE = os.path.join(VAULT, "People", "One on Ones")
for engineer in roster:
    first_name = engineer.split()[0]  # match folder by first name
    for d in days:
        note_path = os.path.join(ONE_ON_ONE_BASE, first_name,
                                 d.strftime("%Y-%m-%d") + ".md")
        if os.path.exists(note_path):
            one_on_one_notes[engineer] = open(note_path).read()
```

### 2.5d — Extract per-engineer signals

For each engineer, scan the combined `weekly_context` (Slack + Email + EOD) plus any 1:1 note for signals:

```python
import re

def extract_signals(name, context, one_on_one_text=""):
    """Return a list of signal strings for this engineer from the context."""
    signals = []
    first = name.split()[0]
    # Find sentences/bullets mentioning the engineer
    for line in context.splitlines():
        if first.lower() in line.lower() or name.lower() in line.lower():
            line = line.strip().lstrip("-•*|").strip()
            if len(line) > 20:  # skip very short matches
                signals.append(line)
    # Include full 1:1 note if available
    if one_on_one_text:
        signals.append(f"[1:1 this week] {one_on_one_text.strip()}")
    return signals
```

Build `mined_notes: dict[engineer_name -> list[signal_str]]`.

### 2.5e — Synthesize per-engineer qualitative notes

For each engineer, synthesize their signals into a 2–5 sentence qualitative note using LLM reasoning:

- Lead with the most meaningful signal (1:1 content > EOD mentions > Slack/email signals)
- Distinguish positive signals (shoutouts, deliveries, team reception) from concerns (blockers, friction, missed items)
- If no signals found for an engineer, note: `"No qualitative signals found in Slack, email, or EOD notes this week."`
- Do NOT fabricate details — only use signals explicitly found in the source text

Store result as `synthesized_notes: dict[engineer_name -> str]`.

---

## Phase 3 — Collect Qualitative Notes

**Check autopilot mode** before running this phase:
- Autopilot = user is unavailable (cron, async, no `ask_user` response possible)
- Interactive = user is present in the session

### Autopilot path

Use `synthesized_notes` from Phase 2.5 directly. No `ask_user` calls. Add a note to the retro header:

```
_Qualitative notes mined automatically from Obsidian (Slack summaries, email summaries, EOD notes, 1:1s)._
```

### Interactive path

For each engineer on the roster (sorted alphabetically by first name), present the mined context as a starting point:

> **Use `ask_user`:**
> "**[Engineer Name]** — [N tickets, M PRs]. Mined context: _[first 120 chars of synthesized note]_. Accept, edit, or skip?"
> Choices: `["Accept mined note", "Edit / add more", "Skip — nothing to add"]`

If "Edit / add more", follow up:

> **Use `ask_user`:**
> "What would you like to add or change for [Engineer Name]?"

Merge the freeform response with the mined note.

After iterating, ask:

> **Use `ask_user`:**
> "Any additional team-wide observations, cross-cutting themes, or incidents to note?"
> Allow freeform or skip.

### Both paths

Record the final note for each engineer (mined, merged, or skipped) as `final_notes: dict[engineer -> str]`. These flow into Phase 5.

---

## Phase 4 — Identify Watch Items

From the data, automatically surface:

1. **Reverts** — any PR titled starting with "Revert" merged this week
2. **Large auto-generated PRs** — PRs > 2,000 lines with "swagger", "schema", or "regen" in title (flag for CI automation)
3. **Long review lags** — PRs where `review_lag_hours > 24` (flag for review culture discussion)
4. **OOO gaps** — if an engineer had no tickets closed and no PRs merged but is on the roster (they may have been OOO without handoff)
5. **Not-started follow-ups** — any post-mortem follow-up tickets still in Ready status

---

## Phase 5 — Write the Retro

Write the markdown file using a Python script at `/tmp/write_weekly_retro.py` (never use bash heredocs with `${}`).

**File path — write to Obsidian only:**
```python
OBSIDIAN_VAULT = "<OBSIDIAN_VAULT>"  # from references/carrum.md
OBSIDIAN_OUT = os.path.join(OBSIDIAN_VAULT, "People", "Weekly Retros", f"{file_date}.md")
os.makedirs(os.path.dirname(OBSIDIAN_OUT), exist_ok=True)
OUTPUT = OBSIDIAN_OUT
```

**Document structure:**

```markdown
# <TEAM_NAME> — Weekly Retro
**Week of <WEEK_LABEL>**  
_Generated <DATE>_

---

## What Shipped This Week

**N PRs merged · M tickets released · D working days**

| Highlight | Ticket |
|-----------|--------|
| <key delivery> | [<JIRA_PROJECT>-XXXX](...) |

---

## Post-Mortems

| Ticket | Incident | Owner | Status |
|--------|----------|-------|--------|

---

## Watch Items

- **<item>** — <description and recommendation>

---

## Team Observations

### <Engineer Name>
<qualitative note, or "No notes this week.">

---

## Follow-Ups for Next Week

| Item | Owner |
|------|-------|
| <action item derived from observations> | <name> |
```

**Linking rules:**
- Every Jira key → `[<JIRA_PROJECT>-XXXX](https://<JIRA_DOMAIN>/browse/<JIRA_PROJECT>-XXXX)`
- Every GitHub PR → `[repo-name #N](https://github.com/<GITHUB_ORG>/<repo>/pull/<N>)`

**Follow-ups** are auto-generated from:
- Engineers with a concerning note → suggest 1:1 topic
- Watch items that require action → suggest owner
- Post-mortem follow-ups not started → flag for EM

---

## Phase 6 — Open and Confirm

```bash
python3 /tmp/write_weekly_retro.py
open -a "Visual Studio Code" "<OUTPUT>"
```

Tell the user:
- Obsidian file path (`People/Weekly Retros/YYYY-MM-DD.md`)
- Engineers covered
- Any watch items flagged
- Follow-ups added

---

## Past Retros

To read a prior week's retro:

```bash
ls ~/work/personal/ai-engineering/agents/engineering-manager-assistant/weekly-retros/
```

Files are named `YYYY-MM-DD-team-retro.md` (Monday date of each week). Read with `view` tool.

---

## Notes

- Always use Python scripts at `/tmp/` for file writing — bash heredocs with `${}` are blocked.
- Strip `GraphQL:` prefix lines from all acli JSON output before parsing.
- Bot logins to exclude from review counts: `dependabot[bot]`, `github-actions[bot]`, `copilot-pull-request-reviewer[bot]`, `copilot-swe-agent[bot]`.
- The EM assistant role (`~/work/personal/ai-engineering/agents/engineering-manager-assistant/`) is the source of truth for team context. Read `memories.md` at the start of each session for standing team knowledge.
- Team context (GitHub org, repos, Jira project/domain) is read from the EM assistant role's `memories.md` and `AGENTS.md`. Update those files if the team roster or repos change.
- If running mid-week, note the retro is a partial view and label it accordingly.
- **Autopilot mode** is active whenever `ask_user` is unavailable or the user is not present. In autopilot, Phase 2.5 mined notes replace all Phase 3 `ask_user` prompts entirely — never block on user input.
- **Signal quality hierarchy:** 1:1 notes this week > EOD notes > Slack summaries > email summaries. Always lead with the highest-signal source.
- **Do not fabricate.** If no qualitative signals exist for an engineer, write exactly: `"No qualitative signals found in Slack, email, or EOD notes this week."` Do not invent observations.
- **Retros are saved to Obsidian only** at `People/Weekly Retros/YYYY-MM-DD.md`. There is no separate role-store copy.

## Local References

If a `references/` directory exists next to this `SKILL.md`, load all `.md` files there
before executing. Reference files may override defaults, add team-specific patterns,
or provide additional links and context.

```bash
ls "$(dirname "$0")/references/"*.md 2>/dev/null
```

---

## Fleet Mode

This skill is a candidate for background agent execution from the EM role.

| Phase | Can parallelize? | How |
|-------|-----------------|-----|
| Phase 1 — PR fetch (per repo) | ✅ | Each repo is independent — fetch all 7 repos concurrently |
| Phase 2 — Jira ticket fetch | ✅ | Run alongside PR fetching |
| Phase 2.5 — Obsidian source mining | ✅ | Read-only, safe to run concurrently with data fetches |
| Phase 3 — Write retro | ⚠️ Sequential | Depends on Phase 1+2+2.5 output |

### Recommended invocation from EM role

```
Launch one general-purpose background agent with the full skill context.
Provide: SKILL.md path, references/ paths, week date (or "current week").
Agent runs all phases and reports the Obsidian file path on completion.
```

Within the agent, use `concurrent.futures.ThreadPoolExecutor` for per-repo `gh pr list` calls (Phase 1) — reduces fetch time from ~2min to ~20s.
