---
name: weekly-team-retro
description: Generates a weekly engineering team retrospective. Fetches PR activity and Jira ticket completions for the current week, collects qualitative EM notes on each engineer via ask_user, and saves a persistent markdown report to the EM assistant role's weekly-retros directory. Requires GitHub CLI (gh) and Atlassian CLI (acli).
---

# Skill: Weekly Team Retro

Generate a weekly engineering team retrospective. This skill pulls quantitative data (PRs merged, tickets resolved, post-mortems) from the current week, prompts the EM for qualitative engineer notes one by one, then writes a structured markdown report to the EM role's persistent store.

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

## Phase 3 — Collect Qualitative Notes

For each engineer on the roster (sorted alphabetically by first name), ask:

> **Use `ask_user`:**
> "**[Engineer Name]** — [N tickets assigned, M PRs merged this week]. Any qualitative notes? (contributions, concerns, 1:1 topics, shoutouts)"
> Choices: `["Skip — nothing to add", "Add a note..."]`

If "Add a note...", follow up with a freeform question:

> **Use `ask_user`:**
> "What would you like to note about [Engineer Name]?"

After iterating through all engineers, ask:

> **Use `ask_user`:**
> "Any additional team-wide observations, cross-cutting themes, or incidents to note?"
> Allow freeform or skip.

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

**File path:**
```python
RETRO_DIR = os.path.expanduser("~/work/personal/ai-engineering/agents/engineering-manager-assistant/weekly-retros")
OUTPUT = f"{RETRO_DIR}/{file_date}-team-retro.md"
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
- File path
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

## Local References

If a `references/` directory exists next to this `SKILL.md`, load all `.md` files there
before executing. Reference files may override defaults, add team-specific patterns,
or provide additional links and context.

```bash
ls "$(dirname "$0")/references/"*.md 2>/dev/null
```
