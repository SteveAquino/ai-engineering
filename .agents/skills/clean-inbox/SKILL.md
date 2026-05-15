---
name: clean-inbox
description: Apple Mail inbox triage for the engineering-manager-assistant. Categorizes messages, updates the Gemini meeting notes index, documents the inbox state in Obsidian, and surfaces a clean actionable summary.
---

# Skill: Clean Inbox

Use this skill to triage the Apple Mail inbox. It categorizes messages, extracts Gemini meeting notes, writes an inbox summary to Obsidian, and surfaces actionable items. Designed for a Gmail-backed Apple Mail account on macOS.

> **Current mode: Summarize-and-clear** — Phase 2 reads each non-human message, extracts the substance into the Obsidian email digest, then marks it as read. Only emails from real humans remain unread. Archiving/moving is still suspended until the Gmail MCP agent is built.

---

## ⛔ Hard Rules

- Never archive messages that require a decision or response without explicit confirmation
- **Do not attempt to move, archive, or label messages** — all AppleScript-based archiving is broken on Mail 16 / macOS 15 Sequoia. Phase 2 only marks noise as read (safe); it does not move anything.
- Never merge, push, or take irreversible action on flagged sensitive emails (e.g. credential emails) — surface them to the user instead

---

## Local References

Before executing, load local configuration:

```bash
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cat "$SKILL_DIR/references/local.md" 2>/dev/null || echo "(no local references — copy docs/local.example.md to references/local.md)"
```

Required keys:
- `VAULT_PATH` — absolute path to the Obsidian vault root
- `MAIL_ACCOUNT_NAME` — Gmail account name as it appears in Apple Mail (default: `Google`)

Optional keys (fall back to defaults if absent):
- `EMAIL_SUMMARY_PATH` — path template for email summary, relative to `VAULT_PATH` (default: `Inbox Summaries/Email/YYYY-MM-DD Email Summary.md`)
- `GEMINI_INDEX_PATH` — path to Gemini meeting notes index, relative to `VAULT_PATH`
- `GMAIL_APP_PASSWORD` — App password for Gmail IMAP access (required for Phase 2 archiving)

If `VAULT_PATH` is missing, ask the user and offer to write `references/local.md`. See `docs/local.example.md` for the full format.

---

## Phase 0 — Check Current State

Get a count and quick preview of the inbox. Use Python IMAP for the count (reliable), AppleScript for the message list:

```python
import imaplib
# Load APP_PASSWORD from references/local.md
imap = imaplib.IMAP4_SSL("imap.gmail.com")
imap.login("saquino@carrumhealth.com", APP_PASSWORD)
imap.select("INBOX")
_, data = imap.search(None, "ALL")
print(f"Inbox: {len(data[0].split())} messages")
imap.logout()
```

Then list all messages with sender + subject (AppleScript still works for reading):

---

## Phase 1 — Categorize

Mentally (or in a scratch table) sort each message into one of four buckets:

| Bucket | Description |
|--------|-------------|
| **Archive — noise** | Marketing, receipts, app notifications, past RSVPs, stale digests, duplicate reminders |
| **Archive — Gemini notes** | Emails from `gemini-notes@google.com` — archive after indexing |
| **Keep — actionable** | Anything requiring a response, decision, approval, or attendance |
| **Keep — FYI** | Calendar invites already accepted, informational threads to glance at |

### Known noise senders (safe to bulk-archive)

```
gemini-notes@google.com
payments-noreply@google.com
team.notifications@herokumanager.com
noreply@email.openai.com          # policy/marketing emails only
no-reply@updates.braze.com
info@peeklogic.com
webinars@e.lucid.co
no_reply@email.apple.com          # App Store Connect notifications
testflight_no_reply@email.apple.com  # TestFlight build notifications
secure-support@expo.dev           # Expo build/submission notifications — see "Deployment Activity" below
firebase-noreply@google.com       # Firebase notifications
hello@carrumhealth.com            # patient-facing notifications
support@omadahealth.com
no-reply@dtdg.co                  # Datadog alerts and digests
automation@carrumhealth.atlassian.net
noreply@sentry.io
```

### Known noise subject patterns (safe to bulk-archive)

```
"You have new messages"
"Account Activation"
"Your Weekly Digest from Datadog"
"here is your weekly update for"    # Jira weekly digest
"moved to trash"                    # Jira project trash notifications
"Estimation Status Automation"      # Jira automation failures
"Rovo AI"                           # Atlassian marketing
"HRIS Integrations"                 # vendor pitches
"Update to our privacy policy"
"Kaitlin Pham is ready to work"     # Notion onboarding noise
"New in April:"                     # Braze/vendor newsletters
"build succeeded"                   # Expo build noise
"submission succeeded"              # Expo submission noise
"is now available to test"          # TestFlight noise
"has completed processing"          # App Store Connect processing noise
```

### Deployment activity — archive but summarize

Expo, TestFlight, and App Store Connect emails are noise individually, but the **collective activity is worth surfacing** in the email summary as a one-line deployment summary. Before archiving, note:
- Platform (iOS / Android)
- Stage reached (build → submission → review → ready for distribution)
- Any failures (if a build or submission *failed*, that is actionable — do NOT archive, keep it)

Include a `## 🚀 Deployment Activity` section in the email summary. Example:
```
iOS 1.5.7: build → submitted → In Review → Ready for Distribution ✅
Android 1.5.7: build → submitted ✅
```

### To/CC context awareness

Before keeping a message as actionable, check whether you are the **primary recipient (To:)** or only **CC'd**. These have different weights:

| Your position | Default treatment |
|---|---|
| **To:** (primary) | Treat as directed at you — apply full prioritization |
| **CC:** only | Lower priority — treat as FYI unless the thread explicitly asks for your input |
| **BCC / list** | Background awareness — archive unless clearly actionable |

**Example:** An email from a Carrum engineer addressed **To: Anthem contacts**, with Steve CC'd, is an external communication you're copied on for awareness — not a personal action item. Archive it or downgrade to 📋 Other Items rather than flagging as 🔴 High Priority.

When in doubt, read the first line of the body to check if it addresses "Steve" or "Hi team" vs. "Dear [external party]".

### Deduplication rules

When multiple copies of the same notification type exist, keep the **most recent** and archive the rest:
- Rippling HIPAA reminders (e.g. "due soon" vs. "due tomorrow" — keep the urgent one)
- Huntress training reminders — keep 1
- Kula RSVP reminders for the same candidate — keep 1
- Past Kula RSVPs for already-decided candidates — archive all

---

## Phase 2 — Read, Summarize, and Mark Non-Human Mail as Read ✅ (active)

> **Archiving is suspended** (AppleScript `archive`, `move`, `set deleted status` all fail on Mail 16 / macOS 15). However, **marking as read and reading message content** works reliably. The goal here is to *be the inbox* — read every non-human message, extract the substance, and mark it read so the user only sees mail from real humans.

**The model:** You are Steve's inbox assistant. You read the mail, summarize what matters, and clear the noise. Nothing is lost — it's all captured in the Obsidian email summary. Steve only needs to open emails from real humans.

### Step 1 — Extract all unread messages with content via Python

Use `imaplib` with the Gmail app password (from `references/local.md`) to fetch full message content. AppleScript can read subjects/senders but not body text reliably for all formats.

```python
import imaplib, email, email.header, re
from datetime import datetime

# Load from references/local.md
APP_PASSWORD = "<GMAIL_APP_PASSWORD>"
EMAIL = "saquino@carrumhealth.com"

imap = imaplib.IMAP4_SSL("imap.gmail.com")
imap.login(EMAIL, APP_PASSWORD)
imap.select("INBOX")

_, data = imap.search(None, "UNSEEN")
uids = data[0].split()

messages = []
for uid in uids:
    _, msg_data = imap.fetch(uid, "(RFC822)")
    msg = email.message_from_bytes(msg_data[0][1])
    sender = email.header.decode_header(msg.get("From", ""))[0]
    sender = sender[0].decode(sender[1] or "utf-8") if isinstance(sender[0], bytes) else sender[0]
    subject = email.header.decode_header(msg.get("Subject", ""))[0]
    subject = subject[0].decode(subject[1] or "utf-8") if isinstance(subject[0], bytes) else subject[0]
    
    # Extract body
    body = ""
    for part in msg.walk():
        if part.get_content_type() == "text/plain":
            body = part.get_payload(decode=True).decode("utf-8", errors="ignore")[:500]
            break
    
    messages.append({"uid": uid.decode(), "sender": sender, "subject": subject, "body": body.strip()})

imap.logout()
```

### Step 2 — Classify each message

For each message, determine if sender is **human** or **non-human**:

A sender is **non-human** if their address contains any of:
`noreply, no-reply, no_reply, donotreply, notifications, notification, alerts, alert, automated, automation, comments-noreply, drive-shares, atlassian.net, jsm-notifications, kula.ai, rippling.com, alerts.mycurricula.com, mail.notion.so, notify@, updates.braze.com, email.apple.com, expo.dev, news2date.news, e.zoom.us, employeebenefits`

Calendar invites are also non-human even from real senders — mark as read if subject starts with:
`Invitation:, Updated invitation:, Canceled event:, Updated invitation with note:, Canceled:`

All others are **human** — leave unread.

### Step 3 — Summarize non-human messages by category

Before marking anything as read, build a structured summary of what was read. Group into sections:

**🔔 Alerts & Notifications** — Jira, PagerDuty, Datadog, Sentry, GitHub CI
> Include: what triggered, severity, resolution status if visible in body

**📅 Calendar** — invites, updates, cancellations
> Include: meeting name, date/time, who sent it, any notes in the body

**✅ Compliance & HR (Rippling)** — training due, task reminders, approvals
> Include: what's due, deadline, whether it's overdue

**👥 Recruiting (Kula)** — RSVP reminders, interview scheduling
> Include: candidate name, role, interview type, date, RSVP status

**📄 Docs & Sheets** — Google Docs/Sheets comment notifications
> Include: doc name, commenter, what they said (from body preview)

**🔧 Vendor / Tool** — Okta, Huntress, Firebase, marketing
> Include: what action (if any) is requested and deadline

Write this summary into the `## 📬 Inbox Digest` section of the day's email summary file in Obsidian (append, don't overwrite).

### Step 4 — Mark non-human messages as read

After summarizing, mark them all read via AppleScript:

```applescript
osascript << 'ASCRIPT'
tell application "Mail"
    set nonHumanPatterns to {"noreply", "no-reply", "no_reply", "donotreply", "notifications", "notification", "alert", "automated", "automation", "comments-noreply", "drive-shares", "atlassian.net", "jsm-notifications", "kula.ai", "rippling.com", "alerts.mycurricula.com", "mail.notion.so", "updates.braze.com", "email.apple.com", "expo.dev", "news2date.news", "e.zoom.us", "employeebenefits"}
    set calPrefixes to {"Invitation:", "Updated invitation:", "Canceled event:", "Updated invitation with note:", "Canceled:"}
    set markedCount to 0
    repeat with m in (messages of inbox whose read status is false)
        set mSender to sender of m
        set mSubject to subject of m
        set shouldMark to false
        repeat with p in nonHumanPatterns
            if mSender contains p then set shouldMark to true
        end repeat
        if not shouldMark then
            repeat with cp in calPrefixes
                if mSubject starts with cp then set shouldMark to true
            end repeat
        end if
        if shouldMark then
            set read status of m to true
            set markedCount to markedCount + 1
        end if
    end repeat
    return "Marked " & markedCount & " as read. Remaining unread: " & (count (messages of inbox whose read status is false))
end tell
ASCRIPT
```

Report the count and confirm remaining unread are all from humans.

> **When archiving is restored**, the correct pattern is `duplicate msg to mailbox "Tagged for archival" of account "Google"` via AppleScript, combined with a Google Apps Script that archives labeled messages every 15 minutes.

---

## Phase 2.5 — Jira Triage: Timestamp Check + Ticket Proposals

For every actionable email surfaced in Phase 1 (🔴 High Priority or 🟡 Medium Priority), determine whether it already has a Jira ticket — and whether that ticket was created *after* the email, meaning the work is already in flight or done.

### Step 1 — Classify each actionable email

For each actionable item, classify it as one of:

| Class | Description | Action |
|---|---|---|
| **engineering-story** | Technical work: SSO cert rotation, certificate expiry, API change, system alert, migration, integration request | Propose a Jira story stub |
| **em-task** | EM operational work: hiring decision, team process, vendor sync, compliance, people management | Log as task under TEC-7995 |
| **human-reply** | A real person needs a response | Flag for reply, no ticket needed |
| **already-handled** | Ticket exists AND was created after email sent | Suppress — nothing to do |

**Engineering story signals:** words like "certificate", "expir", "action required", "migrate", "API", "integration", "failure", "alert", "P1", "incident", "security", "CocoaPods", "credential", "rotation", "BigQuery", "SQL deprecation"

**EM task signals:** words like "RSVP", "interview", "training", "HIPAA", "compliance", "overdue", "approval", "time off", "hiring", "onboarding", "vendor", "reconnect", "sync", "retro", "process"

### Step 2 — Jira timestamp check

For each engineering-story or em-task candidate, search Jira for a matching ticket and compare timestamps:

```python
import subprocess, csv, io
from datetime import datetime, timezone

def search_jira(query_text):
    """Search Jira for tickets matching the query. Returns list of dicts with key, summary, created, status."""
    result = subprocess.run(
        ["acli", "jira", "workitem", "search",
         "--jql", f'project = TEC AND text ~ "{query_text}" ORDER BY created DESC',
         "--fields", "summary,status,created", "--csv", "--max-results", "5"],
        input="y\n", capture_output=True, text=True, timeout=20
    )
    rows = []
    for row in csv.DictReader(io.StringIO(result.stdout)):
        rows.append(row)
    return rows

def ticket_created_after(ticket_created_str, email_date):
    """Returns True if the Jira ticket was created after the email was sent."""
    # ticket_created_str is ISO format from Jira
    try:
        ticket_dt = datetime.fromisoformat(ticket_created_str.replace("Z", "+00:00"))
        return ticket_dt > email_date
    except:
        return False
```

For each candidate:
1. Extract 2-3 keywords from the subject/body
2. Call `search_jira(keywords)`
3. If a matching ticket exists AND `ticket_created_after(ticket.created, email.date)` → mark as **already-handled**, note the ticket key
4. If no matching ticket or ticket predates email → flag as **needs action**

### Step 3 — Output

Add a `## 🎫 Jira Triage` section to the Obsidian email summary with three subsections:

```markdown
## 🎫 Jira Triage

### ✅ Already Handled (ticket created after email)
| Email | Ticket | Status |
|---|---|---|
| [Subject] | [TEC-XXXX](link) — [summary] | Released / In Progress |

### 📋 Proposed Engineering Stories
For each unmatched engineering-story item, include a ready-to-use stub:
- **Subject:** [email subject]
- **Proposed summary:** [one-line ticket summary]
- **Type:** Story
- **Epic:** [best guess based on topic — e.g. TEC-7060 for SSO certs]
- **Notes:** [key details from email body]

### 🗂️ EM Tasks to Log (→ TEC-7995)
For each unmatched em-task item:
- **[Task title]** — [brief description]. Source: [email subject, sender, date]
  → `acli jira workitem create --project TEC --type Task --summary "..." --parent TEC-7995`
```

**Do not create tickets automatically.** Surface the proposals and let the user confirm. The `acli` command stub makes it a one-click action.

---

## Phase 3 — Update Gemini Meeting Notes Index

If any Gemini notes were in the inbox, extract their Google Doc links and append to the living index.

**Index location:** `Meeting Notes/Gemini Index.md` in the Obsidian vault

**What this is:** A permanent, growing index of all AI-generated meeting notes from Google Gemini. Each entry links to the original Google Doc. New entries are appended here as meetings accumulate — this is not an inbox summary, it's a long-term reference.

### Extract links from .emlx files

Gemini note emails contain a Google Docs link in the body. Extract it:

```python
import glob, email, re, os

mail_base = os.path.expanduser("~/Library/Mail/V10")
# Find emlx files modified today (or in a recent date range)
pattern = os.path.join(mail_base, "**", "*.emlx")
for path in glob.glob(pattern, recursive=True):
    try:
        with open(path, "rb") as f:
            raw = f.read()
        lines = raw.split(b"\n", 1)
        msg = email.message_from_bytes(lines[1])
        if "gemini-notes@google.com" not in msg.get("From", ""):
            continue
        subject = msg.get("Subject", "")
        # Extract Google Doc link
        body = ""
        for part in msg.walk():
            if part.get_content_type() == "text/plain":
                body = part.get_payload(decode=True).decode("utf-8", errors="ignore")
        links = re.findall(r"https://docs\.google\.com/document/d/[^\s\]>\"]+", body)
        if links:
            print(f"{subject} -> {links[0]}")
    except Exception as e:
        pass
```

Append new rows to the index table:

```markdown
| YYYY-MM-DD | "Meeting Name" | [Open](https://docs.google.com/...) |
```

---

## Phase 4 — Write Email Summary to Obsidian

Write a **human-readable email summary** to the vault.

**Location:** `Inbox Summaries/Email/YYYY-MM-DD Email Summary.md`

**Template:**

```markdown
# Email Summary — YYYY-MM-DD

**Inbox count:** N messages

---

## 🔴 High Priority — Action Required

- ⚠️ [Sender] — "[Subject]" (what action is needed)
- ...

---

## 🟡 Medium Priority — Needs Input Soon

- [Sender] — [Description] (context)
- ...

---

## 🟢 FYI / Upcoming Calendar

| Date | Event |
|---|---|
| **Day Month Time** | Description |

---

## 📋 Other Items
- [Anything else worth noting]
```

Write this file **before** presenting the summary to the user — it ensures the summary is persisted in Obsidian even if the session ends.

---

## Phase 5 — Summarize Actionable Items

Present the remaining inbox as a prioritized list grouped by urgency:

```
🔴 High Priority — Action Needed
🟡 Medium Priority — Needs Input Soon
🟢 Low Priority / FYI
```

Common high-priority patterns for this role:
- Rippling: HIPAA/compliance training deadlines, time-off approvals, overdue tasks
- Kula: RSVP deadlines for active candidates
- Huntress: required training
- Google Docs/Sheets share requests from internal colleagues
- HR/sensitive threads (surface immediately, never archive without reading)

**Ask the user** if they want to take any immediate action on flagged items, or if the summary is sufficient.

---

## Phase 6 — Confirm and Close

Report final state via AppleScript:

```applescript
osascript -e 'tell application "Mail" to count messages of inbox'
```

Summarize:
- Inbox count
- Email summary location in Obsidian
- Gemini index updated (Y/N, how many new entries)
- Top 3 actions remaining

---

## Reference

- **Obsidian vault:** set in `references/local.md` as `VAULT_PATH` (see `docs/local.example.md`)
- **Email summary location:** `$VAULT_PATH/Inbox Summaries/Email/YYYY-MM-DD Email Summary.md`
- **Current mode: read-only triage** — Phase 2 skipped. No archiving until Gmail MCP agent is ready (plan in software-engineering-assistant inbox).
- **When archiving is restored:** use `duplicate msg to mailbox "Tagged for archival" of account "Google"` via AppleScript (confirmed working on Mail 16, 2026-05-07). Pair with Google Apps Script trigger at script.google.com to auto-archive labeled messages every 15 min.
- **Apple Mail 16 regressions:** `archive` (-2741), `set deleted status` (-609), `move` (bounces back on IMAP resync). Only `duplicate` and read operations work reliably.
