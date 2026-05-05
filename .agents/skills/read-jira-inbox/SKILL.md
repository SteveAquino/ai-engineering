---
name: read-jira-inbox
description: Query Jira for today's actionable items — assigned tickets, blocked work, mentions, and sprint status — and write a structured daily summary to Obsidian. Designed to be invoked by prepare-daily-plan or run standalone.
---

# Skill: Read Jira Inbox

Fetch today's Jira signals and write a structured summary to Obsidian. Idempotent — safe to run multiple times; overwrites today's file.

---

## Local References

Load vault path from the `obsidian-vault` skill's references, or from `clean-inbox` references:

```bash
VAULT_PATH="/Users/stevenaquino/Documents/Obsidian Vault: Work"
JIRA_SUMMARY_DIR="$VAULT_PATH/Inbox Summaries/Jira"
TODAY=$(date +%Y-%m-%d)
OUTPUT="$JIRA_SUMMARY_DIR/$TODAY Jira Summary.md"
mkdir -p "$JIRA_SUMMARY_DIR"
```

---

## Phase 1 — Fetch Assigned & In-Progress Tickets

Use `acli` to query tickets assigned to the current user:

```bash
# In-progress tickets (what am I actively working on?)
acli jira issue list \
  --project TEC \
  --assignee currentUser() \
  --status "In Progress" \
  --output-format json 2>/dev/null

# To-Do in active sprint
acli jira sprint list --project TEC --active 2>/dev/null | head -5
acli jira issue list \
  --project TEC \
  --assignee currentUser() \
  --status "To Do" \
  --sprint "active" \
  --output-format json 2>/dev/null

# Blocked tickets
acli jira issue list \
  --project TEC \
  --assignee currentUser() \
  --status "Blocked" \
  --output-format json 2>/dev/null
```

If `acli` is unavailable, note it and write a stub summary.

---

## Phase 2 — Fetch PRs Linked to My Tickets

For each in-progress ticket, check for linked GitHub PRs that may be awaiting review or CI:

```bash
# PRs I authored that need attention
gh pr list --author @me --state open \
  --json number,title,reviewDecision,url,headRefName \
  | python3 -c "
import json, sys
prs = json.load(sys.stdin)
for p in prs:
    status = p.get('reviewDecision') or 'awaiting review'
    print(f'#{p[\"number\"]} {p[\"title\"]} — {status} {p[\"url\"]}')
" 2>/dev/null || echo "(gh unavailable)"

# PRs I'm requested to review
gh pr list --state open \
  --json number,title,author,reviewDecision,url \
  --search "review-requested:@me" \
  | python3 -c "
import json, sys
prs = json.load(sys.stdin)
for p in prs:
    print(f'#{p[\"number\"]} {p[\"title\"]} — by {p[\"author\"][\"login\"]} {p[\"url\"]}')
" 2>/dev/null || echo "(gh unavailable)"
```

---

## Phase 3 — Fetch Recent Mentions & Comments

Find Jira tickets where I was recently mentioned or have unread notifications:

```bash
# Tickets with recent activity mentioning me (last 2 days)
acli jira issue list \
  --jql "project = TEC AND comment ~ currentUser() AND updated >= -2d ORDER BY updated DESC" \
  --output-format json 2>/dev/null | head -20
```

---

## Phase 4 — Write Jira Summary to Obsidian

Write the structured summary. Categorize items into:

| Priority | Criteria |
|----------|----------|
| 🔴 Blocked | Status = Blocked, or PR failing CI, or comment thread awaiting my response |
| 🟡 In Progress | Actively assigned, in current sprint |
| 🟢 To Do / Queued | In sprint but not started |
| 📋 Mentioned | Recent comments mentioning me — need to read/respond |
| 🔗 PRs Linked | My open PRs and PRs awaiting my review |

**Template:**

```markdown
# Jira Summary — YYYY-MM-DD

> Generated: HH:MM — Covers TEC project, active sprint, currentUser assignments

---

## 🔴 Blocked
- [TEC-XXXX](https://carrumhealth.atlassian.net/browse/TEC-XXXX) — Title *(blocker: ...)*

## 🟡 In Progress
- [TEC-XXXX](https://carrumhealth.atlassian.net/browse/TEC-XXXX) — Title *(sprint: Sprint N)*

## 🟢 To Do (This Sprint)
- [TEC-XXXX](https://carrumhealth.atlassian.net/browse/TEC-XXXX) — Title

## 📋 Mentioned / Needs Response
- [TEC-XXXX](https://carrumhealth.atlassian.net/browse/TEC-XXXX) — Title *(comment from X, N days ago)*

## 🔗 PRs
### My Open PRs
- [#NNN Title](url) — status

### PRs Awaiting My Review
- [#NNN Title](url) — by @author
```

Write to `$OUTPUT`. If no items in a section, omit that section header.

---

## Phase 5 — Return Summary Path

Print the output path so calling skills (e.g. `prepare-daily-plan`) can read the file:

```bash
echo "JIRA_SUMMARY=$OUTPUT"
```

---

## Notes

- This skill is **read-only** — it does not update tickets, post comments, or close issues.
- If `acli` is not authenticated, write a stub file noting the auth gap and suggesting `acli login`.
- If no items are found in any category, write a summary noting the clean state: "No blocked or in-progress tickets found."
- The output path follows the pattern: `Inbox Summaries/Jira/YYYY-MM-DD Jira Summary.md`
