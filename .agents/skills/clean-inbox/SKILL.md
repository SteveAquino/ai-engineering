---
name: clean-inbox
description: Apple Mail inbox triage for the engineering-manager-assistant. Categorizes messages, bulk-archives noise, updates the Gemini meeting notes index, documents what was archived in Obsidian, and surfaces a clean actionable summary.
---

# Skill: Clean Inbox

Use this skill to triage the Apple Mail inbox. It archives noise, updates persistent indexes, documents what was removed, and leaves a clean actionable list. Designed for a Gmail-backed Apple Mail account on macOS.

---

## ⛔ Hard Rules

- Never archive messages that require a decision or response without explicit confirmation
- Never delete — only archive (move from `mailbox "INBOX" of account "Google"` to `All Mail` — see Phase 2)
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

Expo, TestFlight, and App Store Connect emails are noise individually, but the **collective activity is worth surfacing** in the archive log as a one-line deployment summary. Before archiving, note:
- Platform (iOS / Android)
- Stage reached (build → submission → review → ready for distribution)
- Any failures (if a build or submission *failed*, that is actionable — do NOT archive, keep it)

Include a `## 🚀 Deployment Activity` section in the archive log (see Phase 4 template). Example:
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

## Phase 2 — Archive Noise

> **🔑 KEY INSIGHT — Gmail IMAP + Apple Mail archiving (CORRECTED 2026-05-05):**
>
> Gmail stores all messages in `All Mail`. INBOX is just a label. To archive (remove the INBOX label), move from the **account-specific INBOX mailbox** to the **account-specific All Mail mailbox**.
>
> **⛔ `mailbox "Archive"` (global AppleScript object) = local On My Mac folder.** It has NOTHING to do with Gmail. Messages moved there appear archived locally, but Gmail never receives an EXPUNGE. On the next full IMAP resync, Gmail pushes all messages back. This was the root cause of all sync-back events in prior sessions.
>
> **Things that do NOT work:**
> - `move ... to mailbox "Archive"` (global) → local On My Mac folder; Gmail never sees it; messages come back on resync
> - `move ... to mailbox "[Gmail]/All Mail" of acct` — key string lookup fails with -1728
> - `synchronize gmailInbox` / `synchronize googleAcct` → throws -1701 (missing parameter); this verb is not usable
> - `check for new mail` immediately after a move → fetches Gmail server state before IMAP operations commit; restores messages
> - Bulk list moves (`move listOfMessages to box`) → throws -1700 type error; always move one message at a time

> **✅ CONFIRMED WORKING PATTERN (verified 2026-05-05):**
>
> 1. Find the `All Mail` mailbox by **iterating** `mailboxes of account "Google"` (direct string key lookup fails)
> 2. Move messages from `mailbox "INBOX" of account "Google"` to that box, **one at a time**
> 3. Wait 2 seconds between senders
> 4. Do **NOT** call `check for new mail` after archiving — let Apple Mail sync naturally

**The correct archiving function — use this for every sender/subject pass:**

```bash
archive_sender() {
  local sender="$1"
  osascript << OSASCRIPT
tell application "Mail"
    set googleAcct to account "Google"
    set gmailInbox to mailbox "INBOX" of googleAcct
    set allMailBox to missing value
    repeat with box in mailboxes of googleAcct
        if name of box is "All Mail" then set allMailBox to box
    end repeat
    set toMove to (messages of gmailInbox whose sender contains "$sender")
    set n to count of toMove
    repeat with msg in toMove
        move msg to allMailBox
    end repeat
    delay 1
    return "[$sender] moved " & n & " — inbox now " & (count of messages of gmailInbox)
end tell
OSASCRIPT
  sleep 2
}

# Call once per sender:
archive_sender "gemini-notes@google.com"
archive_sender "no-reply@dtdg.co"
archive_sender "automation@carrumhealth.atlassian.net"
```

For subject-based archiving, use the same function pattern but filter on `subject contains`:

```bash
archive_subject() {
  local subj="$1"
  osascript << OSASCRIPT
tell application "Mail"
    set googleAcct to account "Google"
    set gmailInbox to mailbox "INBOX" of googleAcct
    set allMailBox to missing value
    repeat with box in mailboxes of googleAcct
        if name of box is "All Mail" then set allMailBox to box
    end repeat
    set toMove to (messages of gmailInbox whose subject contains "$subj")
    set n to count of toMove
    repeat with msg in toMove
        move msg to allMailBox
    end repeat
    delay 1
    return "[$subj] moved " & n & " — inbox now " & (count of messages of gmailInbox)
end tell
OSASCRIPT
  sleep 2
}
```

For deduplication (keep first, archive rest):

```applescript
osascript << 'EOF'
tell application "Mail"
    set googleAcct to account "Google"
    set gmailInbox to mailbox "INBOX" of googleAcct
    set allMailBox to missing value
    repeat with box in mailboxes of googleAcct
        if name of box is "All Mail" then set allMailBox to box
    end repeat
    set dupes to (messages of gmailInbox whose subject contains "overdue Carrum Health Inc task")
    if (count of dupes) > 1 then move item 2 of dupes to allMailBox
    return "Done. Count: " & (count of messages of gmailInbox)
end tell
EOF
```

After the final pass, **wait 5+ minutes** without triggering a mail check, then recheck the count to confirm messages haven't returned.

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

## 🚀 Deployment Activity
| Platform | Version | Pipeline | Status |
|---|---|---|---|
| iOS | 1.x.x | build → submitted → In Review → Ready | ✅ |
| Android | 1.x.x | build → submitted | ✅ |
*(Omit if no build/submission emails were present. Any failures should NOT be archived — surface them as actionable.)*

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
*Archived using: `move (messages of gmailInbox whose ...) to allMailBox` where `allMailBox` is found by iterating `mailboxes of account "Google"` for name "All Mail".*
*Key: Use account-specific INBOX → All Mail. `mailbox "Archive"` (global) = local On My Mac folder and does NOT archive on Gmail.*
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
- **Gmail archiving (CORRECT pattern, confirmed 2026-05-05):** Move from `mailbox "INBOX" of account "Google"` to `All Mail` found by iterating `mailboxes of googleAcct` where `name is "All Mail"`. One sender at a time, `sleep 2` between senders. Do NOT call `check for new mail` after archiving.
- **`mailbox "Archive"` (global) = local On My Mac ONLY.** Gmail never receives these moves. Messages come back on full IMAP resync. Do not use this pattern.
- **`synchronize` verb is broken** in Apple Mail AppleScript — throws -1701 on both mailbox and account references. Omit it entirely; moves propagate to Gmail naturally.
- **`check for new mail` after a move restores messages** — it fetches Gmail server state before IMAP operations finish committing. Never call it immediately after an archive pass.
