---
name: send-message
description: Send a plain-English message to any agent's inbox. Any persona can use this to request work from another agent — no schema required. The receiving agent interprets the message using its own instructions.
---

# Skill: Send Message

Drop a plain-English message into any agent's inbox. You don't need to know the receiving agent's schema — just describe what you want in natural language. The receiving agent will interpret and act on it the next time it runs `process-inbox`.

---

## Phase 0 — Choose Target Agent

List available agents:

```bash
ls -d ~/.agents/roles/*/  2>/dev/null | xargs -I{} basename {}
```

**Use `ask_user`:**
> "Which agent should receive this message?"

Choices: the list of discovered agent names.

Store as `TARGET_AGENT`.

---

## Phase 1 — Compose Message

**Use `ask_user`:**
> "What would you like to tell the `<TARGET_AGENT>`? Write your message in plain English."

Allow freeform. Store as `MESSAGE_BODY`.

---

## Phase 2 — Preview & Confirm

Show a preview:

```
To:      <TARGET_AGENT>
From:    <CURRENT_ROLE or "unknown">
Message: <MESSAGE_BODY>
```

**Use `ask_user`:**
> "Send this message to `<TARGET_AGENT>`'s inbox?"
Choices: `["Yes — send it", "Cancel"]`

---

## Phase 3 — Write Inbox File

```python
import os, datetime

CURRENT_ROLE = "<CURRENT_ROLE>"  # from active assume-role session, or "unknown"
TARGET_AGENT = "<TARGET_AGENT>"
MESSAGE_BODY = "<MESSAGE_BODY>"

inbox = os.path.expanduser(f"~/.agents/roles/{TARGET_AGENT}/inbox")
os.makedirs(inbox, exist_ok=True)

ts = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
slug = MESSAGE_BODY.strip().lower().split()[:4]
slug = "-".join(c for c in "-".join(slug) if c.isalnum() or c == "-")[:40]
filename = f"{ts}-{slug}.md"
filepath = os.path.join(inbox, filename)

content = f"""---
id: msg-{ts}
from: {CURRENT_ROLE}
to: {TARGET_AGENT}
sent_at: {datetime.datetime.utcnow().isoformat()}Z
---

{MESSAGE_BODY}
""".lstrip()

with open(filepath, "w") as f:
    f.write(content)

print(f"✅ Message written to {TARGET_AGENT} inbox: {filename}")
```

---

## Phase 4 — Confirm

Report:
> "✅ Message sent to `<TARGET_AGENT>`. It will be processed the next time `<TARGET_AGENT>` runs `process-inbox`."

If the target agent has a self-check cron (e.g., scheduling-assistant), note when it will next run.

---

## Notes

- Any persona can invoke this skill — it only writes a file
- The message body is plain English — no schema required
- The receiving agent interprets the message using its `ROLE.md`
- The inbox directory is created automatically if it doesn't exist
- To process immediately: assume the target role and invoke `process-inbox`
