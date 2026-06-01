---
name: one-on-one-prep
description: "Prepare for a 1:1 meeting by gathering all interactions with a direct report over the last two weeks — GitHub PRs, Jira tickets, Obsidian notes, and inbox messages — and synthesizing them into a structured prep document."
---

# Skill: One-on-One Prep

Use this skill before a 1:1 to surface everything relevant: work they've shipped, things you owe them, blockers they've raised, nudges you've sent, and open threads. The output is a filled-in prep document in your session `files/` directory — ready to read, edit, and take into the meeting.

> **Core rule:** Gather signals first, categorize second. Don't start writing until all sources have been checked. A finding in Jira might explain a pattern you saw in GitHub.

---

## Phase 0 — Intake

Read `references/` files before proceeding — they define org-specific values like GitHub org, Jira project keys, Obsidian vault path, and team member identifiers.

Ask the user:

```
Who is this 1:1 with?
```

Allow freeform. Store as `PERSON_NAME`. The user may enter a full name, a GitHub handle, or a Jira username — accept any form and resolve it using the team roster in `references/` if available.

Ask the user:

```
How far back should I look? (default: 14 days)
```

Choices: `["14 days (Recommended)", "7 days", "21 days", "30 days"]`

Store as `LOOKBACK_DAYS`. Default to `14` if skipped.

Compute:
```python
from datetime import datetime, timedelta
SINCE_DATE = (datetime.now() - timedelta(days=LOOKBACK_DAYS)).strftime("%Y-%m-%d")
TODAY = datetime.now().strftime("%Y-%m-%d")
```

Store `SINCE_DATE` and `TODAY`.

---

## Phase 1 — GitHub Signals

### 1a. PRs they opened

```bash
gh pr list \
  --repo <GITHUB_ORG>/<REPO> \
  --author <GITHUB_HANDLE> \
  --state all \
  --search "created:>=$SINCE_DATE" \
  --json number,title,state,createdAt,mergedAt,reviewDecision,url \
  --limit 50
```

Run for each repo in scope (see `references/`). Note:
- **Merged PRs:** wins/output
- **Open PRs:** potentially in-flight or blocked
- **Closed/unmerged PRs:** may indicate abandoned work worth discussing

### 1b. PRs you reviewed or they requested your review on

```bash
# PRs where you are a reviewer
gh pr list \
  --repo <GITHUB_ORG>/<REPO> \
  --reviewer <YOUR_GITHUB_HANDLE> \
  --state all \
  --search "created:>=$SINCE_DATE" \
  --json number,title,author,state,url \
  --limit 50

# PRs where they reviewed your PRs
gh pr list \
  --repo <GITHUB_ORG>/<REPO> \
  --reviewer <GITHUB_HANDLE> \
  --state all \
  --search "created:>=$SINCE_DATE" \
  --json number,title,author,state,url \
  --limit 50
```

### 1c. PR comments and review threads

For each PR they opened or you collaborated on, check for unresolved review threads:

```bash
gh pr view <PR_NUMBER> --repo <GITHUB_ORG>/<REPO> \
  --json comments,reviews,reviewRequests,url
```

Flag:
- Review comments from you that are unaddressed → "Things they owe me"
- Review comments from them on your PRs → context on their thinking
- Unresolved threads in either direction → open items

### 1d. Issues assigned to them or mentioned in

```bash
gh issue list \
  --repo <GITHUB_ORG>/<REPO> \
  --assignee <GITHUB_HANDLE> \
  --state open \
  --json number,title,createdAt,updatedAt,labels,url \
  --limit 50
```

---

## Phase 2 — Jira Signals

> Read Jira project keys from `references/` before running these commands.

### 2a. Tickets assigned to them (updated recently)

```bash
acli jira workitem list \
  --jql "assignee = '<JIRA_USERNAME>' AND updated >= '$SINCE_DATE' ORDER BY updated DESC" \
  --limit 50 \
  --columns key,summary,status,priority,updated
```

### 2b. Tickets they commented on

```bash
acli jira workitem list \
  --jql "project in (<JIRA_PROJECTS>) AND comment ~ '<JIRA_USERNAME>' AND updated >= '$SINCE_DATE' ORDER BY updated DESC" \
  --limit 30 \
  --columns key,summary,status,updated
```

### 2c. Tickets where they are reporter (created recently)

```bash
acli jira workitem list \
  --jql "reporter = '<JIRA_USERNAME>' AND created >= '$SINCE_DATE' ORDER BY created DESC" \
  --limit 30 \
  --columns key,summary,status,created
```

### 2d. Blocked tickets or tickets waiting on you

Look for tickets assigned to them with status `Blocked`, `Waiting for Review`, or similar — and check if any are awaiting your action:

```bash
acli jira workitem list \
  --jql "assignee = '<JIRA_USERNAME>' AND status in ('Blocked', 'In Review', 'Waiting for Feedback') AND updated >= '$SINCE_DATE'" \
  --limit 20 \
  --columns key,summary,status,updated
```

For any blocked ticket, read the full description + comments to understand why:

```bash
acli jira workitem get <TICKET_KEY> --comments
```

---

## Phase 3 — Obsidian Signals

> Read vault path from `references/` before running these commands.

### 3a. Past 1:1 notes for this person

```bash
# Search for notes in the 1:1 folder for this person
find "<OBSIDIAN_VAULT>/1:1s/<PERSON_NAME>" -name "*.md" \
  -newer "$(date -v-${LOOKBACK_DAYS}d +%Y-%m-%d)" \
  2>/dev/null | sort -r | head -5
```

Read the most recent 1:1 note in full — it may contain open action items from the last meeting.

Also read any open action items list if one exists:
```bash
cat "<OBSIDIAN_VAULT>/1:1s/<PERSON_NAME>/open-actions.md" 2>/dev/null
```

### 3b. Notes mentioning this person (anywhere in vault)

```bash
grep -rl "<PERSON_NAME>" "<OBSIDIAN_VAULT>" \
  --include="*.md" \
  -l 2>/dev/null | head -20
```

Read any notes from the last `LOOKBACK_DAYS` days that mention their name — look for meeting notes, project updates, decisions involving them.

### 3c. Check for unresolved action items from previous 1:1s

In the most recent previous 1:1 note, look for unchecked markdown checkboxes:

```bash
grep -n "- \[ \]" "<MOST_RECENT_1_ON_1_NOTE>" 2>/dev/null
```

These are carryover action items — include them in the "Open from last time" section.

---

## Phase 4 — Inbox and Session Signals

### 4a. Agent inbox messages involving this person

```bash
# Check your active role's sent/received messages
grep -rl "<PERSON_NAME>\|<GITHUB_HANDLE>" \
  "/Users/$USER/work/personal/ai-engineering/.agents/roles/*/state/inbox" \
  --include="*.md" 2>/dev/null | head -20
```

Read each matching file. Look for:
- Nudges or asks you sent to them (or to other agents about their work)
- Requests they made of you (via inbox or session)
- Status updates or blockers they reported

### 4b. Session store history

Query the session store for recent turns mentioning this person:

```python
# Use the sql tool with database: "session_store"
query = """
SELECT s.id, s.branch, substr(t.user_message, 1, 300) as message,
       substr(t.assistant_response, 1, 300) as response,
       t.timestamp
FROM turns t
JOIN sessions s ON t.session_id = s.id
WHERE (t.user_message LIKE '%<PERSON_NAME>%'
   OR t.user_message LIKE '%<GITHUB_HANDLE>%'
   OR t.assistant_response LIKE '%<PERSON_NAME>%')
  AND t.timestamp >= date('now', '-<LOOKBACK_DAYS> days')
ORDER BY t.timestamp DESC
LIMIT 30
"""
```

Look for: discussions about their work, decisions made about their tickets, feedback given or received.

---

## Phase 5 — Synthesize

After gathering all signals, categorize everything into the prep document structure below. Apply these rules:

- **Wins & highlights:** Merged PRs, closed tickets, positive comments, shipped features. Be specific — note PR/ticket numbers and what was accomplished.
- **In flight / watch list:** Open PRs with activity, in-progress tickets, anything actively being worked.
- **Blockers & asks they've raised:** Any explicit asks, blocked tickets, unanswered review requests from them to you. Note how long each has been waiting.
- **Things I owe them:** Unaddressed review comments, tickets waiting on your input, promised feedback not yet given, carryover action items from previous 1:1 notes.
- **Things they owe me (or owe the team):** Open PRs awaiting their updates, feedback you requested that hasn't come back, commitments from last 1:1 not yet resolved.
- **Patterns worth noting:** Velocity trends, topic clusters (are they stuck on a particular area?), communication cadence (have you been out of touch?).
- **Topics to raise:** Anything from the above that warrants a direct conversation — recognition, concern, career, process, clarity needed.

> **Do not editorialize beyond what the data shows.** State findings concretely. If you notice a pattern, describe the underlying evidence. Leave interpretation to the manager.

---

## Phase 6 — Write Prep Document

Write the prep document to the session `files/` directory.

```python
import os, re, pathlib
from datetime import datetime

local_md = pathlib.Path(".agents/references/local.md").read_text()
SESSION_DIR = re.search(r"^SESSION_DIR=(.+)$", local_md, re.MULTILINE).group(1)
SESSION_FILES = os.path.join(SESSION_DIR, "files")
os.makedirs(SESSION_FILES, exist_ok=True)

PERSON_SLUG = "<PERSON_NAME>".lower().replace(" ", "-")
TODAY = datetime.now().strftime("%Y-%m-%d")
OUTPUT = os.path.join(SESSION_FILES, f"1on1-prep-{PERSON_SLUG}-{TODAY}.md")
```

### Document Template

```markdown
# 1:1 Prep — <PERSON_NAME>
_Prepared <TODAY> · Data range: <SINCE_DATE> → <TODAY>_
_Sources checked: GitHub (<REPOS>), Jira (<PROJECTS>), Obsidian, inbox/sessions_

---

## Open from Last Time

| Item | From | Status |
|---|---|---|
| <carryover action item> | Last 1:1 | ⬜ Open |

_If no previous 1:1 note found: "No previous 1:1 notes found in Obsidian."_

---

## Wins & Highlights

- **<PR/Ticket title>** — <1-sentence summary of what was accomplished> ([#<num>](<url>))

---

## In Flight / Watch List

| Item | Status | Age | Notes |
|---|---|---|---|
| <PR or ticket title> | <status> | <days open> | <any concern> |

---

## Blockers & Asks They've Raised

| Item | Source | Waiting since | What's needed |
|---|---|---|---|
| <blocked ticket or ask> | Jira/GitHub/inbox | <date> | <what action unblocks it> |

_If none found: "No explicit blockers surfaced in the data range."_

---

## Things I Owe Them

- [ ] <specific action item> _(source: <PR/ticket/inbox reference>)_

---

## Things They Owe Me / The Team

- [ ] <specific open commitment> _(source: <PR/ticket/1:1 note>)_

---

## Patterns

- <Observed pattern with supporting evidence>

---

## Topics to Raise

1. <Topic — based on findings above, not invented>

---

## Raw Signal Log

<Collapsed section with the raw list of PRs, tickets, notes, and inbox messages reviewed — for reference if anything needs to be traced back>

### GitHub
<list of PRs/issues reviewed>

### Jira
<list of tickets reviewed>

### Obsidian
<list of notes checked>

### Inbox / Sessions
<list of messages / session excerpts reviewed>
```

Fill in all sections with real findings. Do not leave template placeholders. If a section has no data, say so explicitly ("No blockers found in this period") rather than leaving it blank.

---

## Phase 7 — Deliver Summary

Tell the user:

- File path to the prep document
- Count of signals gathered (N PRs, N tickets, N notes)
- Top 2–3 things that stand out (highest-priority items from "Things I Owe Them" and "Blockers")
- Any carryover action items from the last 1:1 that are still open

Offer:
```
Open the prep document in VS Code?
```
Choices: `["Yes — open it", "No thanks"]`

If yes:
```bash
open -a "Visual Studio Code" "$OUTPUT"
```

---

## Notes

- **Always read `references/` first.** Org-specific values (GitHub org, Jira project keys, Obsidian vault path, team roster) live there. Do not hardcode them in this skill.
- **The `--since` date filter is your guard.** Don't go beyond `LOOKBACK_DAYS` — you'll drown in irrelevant history.
- **Blocked tickets are highest-priority signals.** A ticket blocked for >3 days without resolution is almost always worth discussing.
- **Carryover action items from previous 1:1 notes are mandatory to check.** If you can't find any previous 1:1 notes, note that explicitly in the output and suggest starting a notes file in Obsidian.
- **Don't summarize what you can quote.** Use the actual PR title, ticket key, comment text — not a paraphrase. Specifics make the prep document useful.
- If acli is not installed or Jira is not configured, skip Phase 2 gracefully and note the gap.
- If no Obsidian vault is configured, skip Phase 3 gracefully and note the gap.
