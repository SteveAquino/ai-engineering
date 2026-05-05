---
name: report
description: Send a task completion summary to the engineering-manager-assistant inbox for async review. Thin wrapper around send-message with a structured, scannable format.
---

# Skill: Report

After completing a task, use this skill to drop a structured summary into the engineering-manager-assistant's inbox for async review.

---

## Phase 0 — Load Local References

```bash
ls "$(dirname "$0")/references/"*.md 2>/dev/null && echo "Loading references..." || true
```

Load any `.md` files found. They may add team-specific report fields or formatting preferences.

---

## Phase 1 — Gather Report Details

Collect the following. If the current session has obvious context (ticket key, task name, outcomes), pre-fill and confirm rather than asking from scratch.

**Use `ask_user`:**
> "What task or ticket are you reporting on?"

Allow freeform. Store as `TASK`.

**Use `ask_user`:**
> "What was completed? (1–3 sentences)"

Allow freeform. Store as `OUTCOME`.

**Use `ask_user`:**
> "Any follow-up items or decisions needed? (leave blank if none)"

Allow freeform. Store as `FOLLOWUPS`. Default to "None."

---

## Phase 2 — Preview Report

Compose the message body:

```
## Task Completed: <TASK>

**What was done:**
<OUTCOME>

**Follow-ups / decisions needed:**
<FOLLOWUPS>
```

Display it and confirm:

**Use `ask_user`:**
> "Send this report to the engineering-manager-assistant inbox?"

Choices: `["Yes — send it", "Edit first", "Cancel"]`

- **Edit first** → ask what to change, update and re-display.
- **Cancel** → abort.

---

## Phase 3 — Send

Invoke `send-message` with:
- `TARGET_AGENT = engineering-manager-assistant`
- `CURRENT_ROLE` = current assumed role (or "unknown")
- `MESSAGE_BODY` = the composed message above

Follow the `send-message` skill instructions:

```
~/work/personal/ai-engineering/skills/send-message/SKILL.md
```

---

## Phase 4 — Confirm

Report:
> "✅ Report sent to engineering-manager-assistant. It will be reviewed the next time that role runs `process-inbox`."

---

## Local References

If a `references/` directory exists next to this `SKILL.md`, load all `.md` files there
before executing. Reference files may add required report fields, formatting preferences,
or team-specific routing (e.g., send to a different role).

```bash
ls "$(dirname "$0")/references/"*.md 2>/dev/null
```
