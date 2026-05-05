---
name: clean-inbox
description: Apple Mail inbox triage for the engineering-manager-assistant. Categorizes messages, bulk-archives noise, updates the Gemini meeting notes index, documents what was archived in Obsidian, and surfaces a clean actionable summary.
---

# Skill: Clean Inbox

Use this skill to triage the Apple Mail inbox. It archives noise, updates persistent indexes, documents what was removed, and leaves a clean actionable list. Designed for a Gmail-backed Apple Mail account on macOS.

---

## ⛔ Hard Rules

- Never archive messages that require a decision or response without explicit confirmation
- Never delete — only archive (use `mailbox "Archive"` with global `inbox` as source — see Phase 2)
- Always write the archive log before ending — the log is the audit trail
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
- `ARCHIVE_LOG_PATH` — path template for archive log, relative to `VAULT_PATH` (tokens: `<YYYY>`, `<MM>`, `<DD>`)
- `EMAIL_SUMMARY_PATH` — path template for email summary, relative to `VAULT_PATH` (default: `Inbox Summaries/Email/YYYY-MM-DD Email Summary.md`)
- `GEMINI_INDEX_PATH` — path to Gemini meeting notes index, relative to `VAULT_PATH`

If `VAULT_PATH` is missing, ask the user and offer to write `references/local.md`. See `docs/local.example.md` for the full format.

---

## Phase 0 — Check Current State

Get a count and quick preview of the inbox:

```applescript
osascript -e 'tell application "Mail" to count messages of inbox'
```

Then list all messages with sender + subject:

```applescript
osascript << 'EOF'
tell application "Mail"
    set msgs to messages of inbox
    set outLines to {}
    repeat with i from 1 to (count of msgs)
        set msg to item i of msgs
        set end of outLines to (i as string) & ". [" & sender of msg & "] " & subject of msg
    end repeat
    return (count of msgs) & " messages" & return & (outLines as string)
end tell
EOF
```

Review the list before proceeding.

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
```

### Deduplication rules

When multiple copies of the same notification type exist, keep the **most recent** and archive the rest:
- Rippling HIPAA reminders (e.g. "due soon" vs. "due tomorrow" — keep the urgent one)
- Huntress training reminders — keep 1
- Kula RSVP reminders for the same candidate — keep 1
- Past Kula RSVPs for already-decided candidates — archive all

---

## Phase 2 — Archive Noise

> **🔑 KEY INSIGHT — Gmail IMAP + Apple Mail archiving:**
>
> Gmail stores **all messages in `[Gmail]/All Mail`**. INBOX is just a label — not a storage folder. Moving a message to `All Mail` is a no-op because it's already there.
>
> To "archive" (remove the Inbox label), you must operate from the **global `inbox` object** (Apple Mail's virtual combined inbox) and move to `mailbox "Archive"`. Despite `mailbox "Archive"` sounding local, operating from `inbox` causes Mail to issue the correct IMAP EXPUNGE from the Gmail INBOX context, which removes the Inbox label server-side. Verified to persist through multiple Gmail sync cycles.
>
> **Things that do NOT work (all researched and confirmed broken):**
> - Moving from iterated `gmailInbox` mailbox object → messages are already in All Mail; no-op
> - `move ... to mailbox "[Gmail]/All Mail" of acct` — technically succeeds but no IMAP label removal; messages come back
> - `move listOfMessages to archiveBox` — bulk list moves throw `-1700` type error; use one-at-a-time

**The correct archiving template:**

```applescript
osascript << 'EOF'
tell application "Mail"
    -- Archive by sender — uses global inbox (critical!) and mailbox "Archive" (correct for Gmail)
    move (messages of inbox whose sender contains "gemini-notes@google.com") to mailbox "Archive"
    move (messages of inbox whose sender contains "no-reply@dtdg.co") to mailbox "Archive"
    
    -- Archive by subject fragment
    move (messages of inbox whose subject contains "Your Weekly Digest from Datadog") to mailbox "Archive"
    
    -- For large batches or when whose-syntax fails, use one-at-a-time:
    set toMove to (messages of inbox whose sender contains "automation@carrumhealth.atlassian.net")
    repeat with msg in toMove
        move msg to mailbox "Archive"
    end repeat
    
    return "Done. Inbox now: " & (count of messages of inbox)
end tell
EOF
```

Run as many blocks as needed. Verify the count drops after each batch. Gmail sync delay is ~30–60 seconds; wait a few minutes then check the count hasn't rebounded before declaring success.

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

## Phase 4 — Write Archive Log

Create `Inbox Summaries/Archive Logs/YYYY-MM-DD Mail Archive Log.md` in the Obsidian vault.

**Template:**

```markdown
# Mail Archive Log — [DATE]

**Inbox before:** N messages
**Inbox after:** N messages
**Total archived:** N messages

---

## 🗓️ Gemini Meeting Notes (N emails)
[List meeting titles, link to Gemini Index]
📄 See: [[Meeting Notes/Gemini Index]]

## 🔔 App Notifications & Marketing
| Sender | Description |
|---|---|
| ... | ... |

## 💳 Billing & Receipts
| Sender | Description |
|---|---|

## ⚙️ Automation & System Noise
| Source | Description |
|---|---|

## 📅 Past / Stale Items
| Item | Reason Archived |
|---|---|

## 📬 Remaining Inbox (N messages)
[Categorized summary of what was left — see Phase 5]

---
*Archived using: `move (messages of inbox whose ...) to mailbox "Archive"`*
*Key: `mailbox "Archive"` removes Gmail INBOX label. `[Gmail]/All Mail` does not.*
```

---

## Phase 4b — Write Email Summary to Obsidian

After writing the archive log, write a **human-readable email summary** to the vault. This is the daily at-a-glance reference for what's in the inbox — separate from the archive log (which is the audit trail).

**Location:** `Inbox Summaries/Email/YYYY-MM-DD Email Summary.md`

**Template:**

```markdown
# Email Summary — YYYY-MM-DD

**Inbox before:** N messages
**Inbox after:** N messages
**Archived:** N messages
**Archive log:** [[Inbox Summaries/Archive Logs/YYYY-MM-DD Mail Archive Log]]

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

Report final state:

```applescript
osascript -e 'tell application "Mail" to count messages of inbox'
```

Summarize:
- Messages archived (total and by category)
- Archive log location in Obsidian
- Email summary location in Obsidian
- Gemini index updated (Y/N, how many new entries)
- Top 3 actions remaining

---

## Reference

- **Obsidian vault:** set in `references/local.md` as `VAULT_PATH` (see `docs/local.example.md`)
- **Archive log location:** `$VAULT_PATH/$ARCHIVE_LOG_PATH` (default: `Inbox Summaries/Archive Logs/YYYY-MM-DD Mail Archive Log.md`)
- **Email summary location:** `$VAULT_PATH/$EMAIL_SUMMARY_PATH` (default: `Inbox Summaries/Email/YYYY-MM-DD Email Summary.md`)
- **Gmail archiving (the working pattern):** `move (messages of inbox whose ...) to mailbox "Archive"` — using global `inbox` (not an iterated mailbox) as the source causes Mail to issue IMAP EXPUNGE from the INBOX context, which removes Gmail's Inbox label server-side. Verified to persist through multiple sync cycles. All other patterns (moving from iterated gmailInbox, moving to `[Gmail]/All Mail` directly, etc.) do not remove the server-side label and messages come back.
- **Gmail IMAP behavior:** All messages stored once in `[Gmail]/All Mail`. INBOX is a label, not a storage folder. The only way to archive via AppleScript is to use `messages of inbox` + `mailbox "Archive"` — this combination correctly removes the Gmail Inbox label.
