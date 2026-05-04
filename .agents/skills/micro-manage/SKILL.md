---
name: micro-manage
description: Read-only inbox triage across all agent roles. Summarizes pending messages by role — count, topics, age — without removing anything. Use this to spot blocked or stale items before deciding which role to assume.
---

# Skill: Micro-Manage (Inbox Triage)

Read every role's inbox and produce a quick-scan triage summary. Nothing is deleted or processed — this is purely observational.

---

## Phase 0 — Load Local References

```bash
ls "$(dirname "$0")/references/"*.md 2>/dev/null && echo "Loading references..." || true
```

Load any `.md` files found. They may override defaults or add team-specific triage rules.

---

## Phase 1 — Discover Roles

```bash
ls -d ~/work/personal/ai-engineering/agents/*/
```

Collect the list of role names. Store as `ROLES`.

---

## Phase 2 — Read All Inboxes

For each role in `ROLES`:

```bash
ROLE="<role-name>"
INBOX=~/work/personal/ai-engineering/.agents/roles/$ROLE/state/inbox
ls -t "$INBOX/"*.md 2>/dev/null || echo "(empty)"
```

For each inbox file found, read it and extract:
- **Sender** (`from:` frontmatter field, or "unknown")
- **Topic** (first non-frontmatter line, truncated to ~60 chars)
- **Age** (file mtime or `sent_at` frontmatter field — compute hours/days since now)

---

## Phase 3 — Build Triage Summary

Print a consolidated summary:

```
📬 Inbox Triage — <DATE>
════════════════════════════════════════

engineering-manager-assistant  (2 messages)
  🟢  2h ago  "Weekly retro report for April 28"          [from: software-engineering-assistant]
  🟡  31h ago "Implement TEC-8330 status update"          [from: software-engineering-assistant]

scheduling-assistant  (0 messages)
  ✓  inbox empty

skill-builder  (1 message)
  🔴  3d ago  "Review spec-driven-development proposal"   [from: engineering-manager-assistant]

software-engineering-assistant  (0 messages)
  ✓  inbox empty

════════════════════════════════════════
Total: 3 messages across 2 roles
Stale (>48h): 1  ⚠️
```

**Age color coding:**
- 🟢 < 24 hours
- 🟡 24–48 hours
- 🔴 > 48 hours (stale)

---

## Phase 4 — Triage Prompt (Optional)

If any stale (🔴) messages are found, note:

> "There are stale messages. To process them: assume the relevant role and invoke `process-inbox`."

Do not process, move, or delete any messages. This skill is read-only.

---

## Local References

If a `references/` directory exists next to this `SKILL.md`, load all `.md` files there
before executing. Reference files may override defaults, add team-specific triage rules,
or specify additional inbox locations to check.

```bash
ls "$(dirname "$0")/references/"*.md 2>/dev/null
```
