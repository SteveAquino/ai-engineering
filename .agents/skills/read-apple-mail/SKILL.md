---
name: read-apple-mail
description: Reads unread Apple Mail messages via the local SQLite Envelope Index and produces a structured digest. Optionally syncs the summary to an Obsidian vault. Mac-only. Privacy-first — consent required before any message metadata enters context. Suitable as a Phase 1 signal source for prepare-daily-plan or morning-briefing.
platform: macOS
---

# Skill: Read Apple Mail

Surface unread mail from Apple Mail as a structured digest, with privacy checkpoints at every stage.

**Scope of v1:** subject lines, senders, dates, and mailbox labels only.  
Full message body is out of scope — never read or summarize body content.

---

## Local References

Before executing, check for a local references file:

```bash
cat "$(dirname "$0")/references/local.md" 2>/dev/null || echo "(no local references)"
```

If the file exists, treat its values as overrides for the defaults listed in each phase.  
See `docs/local.example.md` for all supported keys.

---

## Phase 0 — Pre-Flight Consent

⚠️ **Privacy notice for the user:**
> This skill will read subject lines, sender names, and mailbox labels from your Apple Mail
> database. That metadata will enter this LLM session's context. It will not be sent to any
> external service, but it will be visible to the model.
>
> **Before proceeding, confirm there is nothing in your recent email subjects or sender names
> that you would not want an AI model to see** (e.g., medical, legal, HR, financial subjects).

**If a user is present**, ask:

> "I'm about to read your Apple Mail inbox — subject lines and senders only, no message bodies.
> Are you comfortable proceeding?"

Choices: `["Yes — proceed", "No — skip this skill"]`

If the user says no: return `skipped-no-consent` and stop.

**If running autonomously (cron / no user present):**

Check `references/local.md` for `STANDING_CONSENT=true`. If not set:

> Skip: no interactive user and no standing consent configured.
> Result: `skipped-no-consent`
> Add this to any summary produced by the calling skill.

Stop here and return the result to the caller.

---

## Phase 1 — Setup / Doctor

Locate the Mail database. Try paths in order:

```bash
for v in 10 9 8 7; do
  path="$HOME/Library/Mail/V${v}/MailData/Envelope Index"
  [ -f "$path" ] && echo "Found: $path" && break
done
```

If a `MAIL_DB_PATH` is defined in `references/local.md`, use that path instead.

Verify read access:

```bash
sqlite3 "$MAIL_DB_PATH" "SELECT count(*) FROM messages LIMIT 1;" 2>&1
```

Common failure modes:
- **Permission denied / TCC error**: Mail must be granted Full Disk Access in System Settings → Privacy & Security. Return `error-permissions`.
- **File not found**: Apple Mail may not be installed or the path changed. Return `error-db-not-found`.
- **Database locked**: Mail is likely open and writing. Open in read-only mode with `-readonly` flag or wait and retry once.
- **Schema mismatch**: Log a warning and continue with best-effort queries.

If setup fails, stop here with the appropriate error code.

---

## Phase 2 — Count Unread

Get a summary count before reading any metadata:

```sql
SELECT count(*)
FROM messages m
JOIN mailboxes mb ON m.mailbox = mb.ROWID
WHERE m.read = 0
  AND m.deleted = 0
  AND mb.source_name NOT IN ('Deleted Messages', 'Drafts', 'Sent Messages',
                              'Junk', 'Spam', '[Gmail]/Trash', '[Gmail]/Sent Mail',
                              '[Gmail]/Drafts', '[Gmail]/Spam')
  AND mb.source_name NOT LIKE '%Trash%'
  AND mb.source_name NOT LIKE '%Sent%'
  AND mb.source_name NOT LIKE '%Draft%'
  AND mb.source_name NOT LIKE '%Junk%'
  AND mb.source_name NOT LIKE '%Spam%';
```

Report:
> "Found N unread message(s) in Apple Mail."

If `N = 0`: return `ok-no-unread` and stop.

---

## Phase 3 — Read Metadata

Query subject, sender, date, and mailbox for unread messages, with limits:

```sql
SELECT
  m.ROWID,
  m.subject,
  a.address AS sender,
  datetime(m.date_sent + 978307200, 'unixepoch', 'localtime') AS sent_at,
  mb.source_name AS mailbox
FROM messages m
LEFT JOIN addresses a ON m.sender = a.ROWID
JOIN mailboxes mb ON m.mailbox = mb.ROWID
WHERE m.read = 0
  AND m.deleted = 0
  AND mb.source_name NOT IN ('Deleted Messages', 'Drafts', 'Sent Messages',
                              'Junk', 'Spam', '[Gmail]/Trash', '[Gmail]/Sent Mail',
                              '[Gmail]/Drafts', '[Gmail]/Spam')
  AND mb.source_name NOT LIKE '%Trash%'
  AND mb.source_name NOT LIKE '%Sent%'
  AND mb.source_name NOT LIKE '%Draft%'
  AND mb.source_name NOT LIKE '%Junk%'
  AND mb.source_name NOT LIKE '%Spam%'
ORDER BY m.date_sent DESC
LIMIT 50;
```

Defaults:
- `MAX_MESSAGES=50` — override via `references/local.md`
- `SINCE_HOURS` — if set, add `AND m.date_sent > (strftime('%s', 'now') - 978307200 - SINCE_HOURS * 3600)`
- `ALLOWED_MAILBOXES` — if set, restrict `mb.source_name IN (...)` instead of the exclusion list

Note: Apple Mail stores dates as seconds since 2001-01-01 (Mac epoch). The offset `978307200` converts to Unix epoch.

---

## Phase 4 — Privacy Scan

For each message retrieved, check the subject line against sensitive keywords before including it in the output:

Sensitive signal words (case-insensitive):
`medical`, `doctor`, `prescription`, `diagnosis`, `health`, `HIPAA`,
`legal`, `attorney`, `lawsuit`, `settlement`, `court`,
`HR`, `performance`, `termination`, `disciplinary`,
`salary`, `payroll`, `compensation`, `bank`, `account`, `wire`, `invoice`,
`password`, `credentials`, `2FA`, `verification code`, `SSN`, `social security`

For each **flagged message**:

**If a user is present**, show the subject line (only) and ask:

> "Subject: `<subject>` (from `<sender>`) — this looks potentially sensitive. Include it in the summary?"

Choices: `["Yes — include it", "No — skip this message"]`

**If running autonomously**: skip the message, note it as `skipped-sensitive` with its ROWID (not subject) in the output.

Unflagged messages proceed without interruption.

---

## Phase 5 — Summarize

Produce a structured markdown summary from the approved messages:

```markdown
# Email Digest — <date>

**Unread:** N  |  **Included:** M  |  **Skipped (sensitive):** K

## By Sender / Topic

### <sender or topic group>
- [<mailbox>] <subject> — <sent_at>
- ...

## Suggested Action Items
- Reply needed: ...
- Review: ...
- FYI / no action: ...

## Skipped Messages
<K messages skipped — possible sensitive content. Review Apple Mail directly.>
```

Group related messages by sender or topic. Infer action items from subject lines — do not fabricate; only suggest what the subjects imply.

---

## Phase 6 — Return Digest

Return the summary produced in Phase 5 (condensed if called from another skill).

Exit codes for callers:
- `ok` — completed normally
- `ok-no-unread` — no unread messages found
- `skipped-no-consent` — user declined or no standing consent in autonomous mode
- `skipped-sensitive` — completed but N messages excluded
- `error-permissions` — Full Disk Access not granted
- `error-db-not-found` — Envelope Index not found at expected paths

---

## Notes

- Never read, summarize, or log full message bodies — subjects and senders only
- This skill is macOS-only; skip gracefully on other platforms
- Good signal source for `prepare-daily-plan` and any morning-briefing skill
- See `docs/local.example.md` for all configurable local references
