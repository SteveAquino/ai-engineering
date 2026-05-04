---
name: process-inbox
description: Process pending messages in the current role's inbox. Reads each plain-English message, uses the role's AGENTS.md to interpret intent, applies the appropriate action, and asks before deleting. Works for any role — role-specific behavior is defined in each role's AGENTS.md.
---

# Skill: Process Inbox

Read and process all pending messages in the current role's inbox. Messages are plain-English `.md` files with minimal frontmatter. The active role's `AGENTS.md` defines how messages are interpreted and acted upon — this skill contains no role-specific logic itself.

---

## Phase 0 — Identify Current Role

The current role is known from the active `assume-role` briefing in this session. Use it as `CURRENT_ROLE`.

---

## Phase 1 — Scan Inbox

```python
import os, glob
CURRENT_ROLE = "<CURRENT_ROLE>"
inbox = os.path.expanduser(f"~/work/personal/ai-engineering/agents/{CURRENT_ROLE}/inbox")
files = sorted(glob.glob(os.path.join(inbox, "*.md"))) if os.path.exists(inbox) else []
print(f"Found {len(files)} pending message(s) in {CURRENT_ROLE} inbox:")
for f in files:
    print(f"  {os.path.basename(f)}")
```

If no files:
> "Inbox is empty — nothing to process."
Stop here.

---

## Phase 2 — Load Role Instructions

```bash
cat ~/work/personal/ai-engineering/agents/<CURRENT_ROLE>/AGENTS.md
```

Read the full instructions, paying close attention to the **Inbox Handling** section — it defines how to interpret and act on messages for this role.

---

## Phase 3 — Interpret and Act on Each Message

For each inbox file:

**Read the full file:**
```python
content = open(filepath).read()
print(content)
```

**Interpret** the message using LLM reasoning, guided by the role's **Inbox Handling** instructions. Messages may have any frontmatter or none at all — the body may be entirely plain English. Use the role's instructions to map the message intent to a concrete action.

**Show the proposed action** before executing:
```
Message: <filename>
From:    <from field or "unknown">
Intent:  <your interpretation in one sentence>
Action:  <what you will do>
```

If the interpretation is unambiguous: execute immediately (do not ask for confirmation — this skill is invoked in cron context where no user is present).

If the message is genuinely ambiguous and a user is available:

**Use `ask_user`:**
> "Message `<filename>`: `<body summary>`. I interpret this as: `<proposed action>`. Is that right?"
Choices: `["Yes — apply it", "Skip this message", "Let me clarify"]`

If running autonomously (cron / `--yolo`): apply the most reasonable interpretation without asking. Log your reasoning.

**Execute** the action per the role's instructions.

**Ask before deleting** (unless running autonomously):

**Use `ask_user`:**
> "Message `<filename>` processed. Delete it from the inbox?"

Choices: `["Yes — delete it", "No — keep it"]`

If running autonomously (cron / `--yolo`): delete without asking.

If kept: leave the file in place and note it in the Phase 4 summary as "processed but retained."

**Delete** the file if confirmed:
```python
import os
os.remove(filepath)
print(f"Deleted: {os.path.basename(filepath)}")
```

---

## Phase 4 — Summary

Report:
- N message(s) processed
- N message(s) skipped (with reasons, if any)
- Actions taken (brief list)

---

## Notes

- The inbox lives at `~/work/personal/ai-engineering/agents/<ROLE>/inbox/`
- Messages are written by the `send-message` skill or any agent that drops `.md` files there
- Processed files are deleted only after user confirmation (or automatically in cron/autonomous mode)
- Kept files remain in the inbox and are noted in the summary as "processed but retained"
- Role-specific behavior is **entirely defined in `AGENTS.md`** — this skill is role-agnostic
- If `yaml` is not available: `pip3 install pyyaml --quiet`
- Always use Python scripts at `/tmp/` for file writes

## Local References

If a `references/` directory exists next to this `SKILL.md`, load all `.md` files there
before executing. Reference files may override defaults, add team-specific patterns,
or provide additional links and context.

```bash
ls "$(dirname "$0")/references/"*.md 2>/dev/null
```
