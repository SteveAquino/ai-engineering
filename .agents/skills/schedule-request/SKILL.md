---
name: schedule-request
description: Drop a scheduling request into the scheduling-assistant's inbox. Any persona can invoke this to schedule or cancel a recurring agent task. The scheduling-assistant will pick it up on its next inbox check.
---

# Skill: Schedule Request

Use this skill to submit a scheduling request to the `scheduling-assistant`. You don't need to be the scheduling-assistant to use this — any persona can invoke it to request that a job be added or canceled.

The request is written as a `.md` file to the scheduling-assistant's inbox. The scheduling-assistant will process it the next time it runs `process-inbox`.

---

## Phase 0 — Gather Request Details

**Use `ask_user`:**
> "Do you want to schedule a new job or cancel an existing one?"
Choices: `["Schedule a new job", "Cancel an existing job"]`

Store the answer as `ACTION` (`schedule` or `cancel`).

---

### If ACTION = schedule

**Use `ask_user`:**
> "What should this job be called? Use a short kebab-case ID (e.g., `weekly-retro`, `daily-standup-summary`)."

Store as `JOB_ID`.

**Use `ask_user`:**
> "Which role should be assumed when this job runs? (e.g., `engineering-manager-assistant`)"

Store as `ROLE`.

**Use `ask_user`:**
> "Which skill should be invoked for that role?"

Store as `SKILL`.

**Use `ask_user`:**
> "What cron schedule should this run on? Enter a cron expression (e.g., `0 9 * * 1` for every Monday at 9am) or describe it in plain English and I'll convert it."

If the user provides plain English, convert it to a valid cron expression and confirm:
> "That maps to `<CRON_EXPRESSION>` — does that look right?"
Choices: `["Yes", "Let me adjust it"]`

Store as `SCHEDULE`.

**Use `ask_user`:**
> "Briefly describe what this job does. (This is stored as a note — leave blank to skip.)"

Store as `DESCRIPTION`. Allow blank.

---

### If ACTION = cancel

**Use `ask_user`:**
> "What is the job ID to cancel? (This must match the `id` in `crontab.json`.)"

Store as `JOB_ID`. Set `ROLE`, `SKILL`, `SCHEDULE`, `DESCRIPTION` to empty strings.

Optionally show the current schedule to help the user find the right ID:

```python
import json, os
path = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json")
if os.path.exists(path):
    data = json.load(open(path))
    jobs = data.get("jobs", [])
    if jobs:
        print(f"{'ID':<30} {'Schedule':<15} {'Role':<35} {'Skill'}")
        print("-" * 90)
        for j in jobs:
            print(f"{j['id']:<30} {j['schedule']:<15} {j['role']:<35} {j['skill']}")
    else:
        print("No jobs currently scheduled.")
else:
    print("crontab.json not found — inbox request will still be written.")
```

---

## Phase 1 — Preview & Confirm

Show the request that will be written:

```
action:       <ACTION>
job_id:       <JOB_ID>
schedule:     <SCHEDULE>
role:         <ROLE>
skill:        <SKILL>
description:  <DESCRIPTION>
requested_by: <CURRENT_ROLE>
```

**Use `ask_user`:**
> "Write this request to the scheduling-assistant's inbox?"
Choices: `["Yes — submit it", "Cancel"]`

---

## Phase 2 — Write Inbox File

Generate a timestamped filename and write the `.md` file:

```python
import os, datetime

INBOX = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/inbox")
os.makedirs(INBOX, exist_ok=True)

ts = datetime.datetime.now().strftime("%Y%m%d%H%M%S")
filename = f"{ts}-{JOB_ID}.md"
filepath = os.path.join(INBOX, filename)

content = f"""---
id: req-{ts}
action: {ACTION}
job_id: {JOB_ID}
schedule: "{SCHEDULE}"
role: {ROLE}
skill: {SKILL}
requested_by: {CURRENT_ROLE}
requested_at: {datetime.datetime.utcnow().isoformat()}Z
---

{DESCRIPTION}
""".strip() + "\n"

with open(filepath, "w") as f:
    f.write(content)

print(f"✅ Request written to inbox: {filename}")
```

Replace `CURRENT_ROLE` with the name of the currently assumed role (from `assume-role` context), or `"unknown"` if not in a role session.

---

## Phase 3 — Confirm

Report:
> "✅ Request `<JOB_ID>` (`<ACTION>`) submitted to scheduling-assistant's inbox. It will be applied the next time `process-inbox` is run."

Optionally remind the user:
> "To process it immediately, assume the `scheduling-assistant` role and run the `process-inbox` skill."

---

## Notes

- Any persona can invoke this skill — it only writes a file; it does not modify `crontab.json` directly.
- The inbox directory is gitignored. Files written here are ephemeral.
- If the same `job_id` already exists and `action` is `schedule`, the scheduling-assistant will update it.
- `cancel` requests for non-existent job IDs will be flagged (but not fail) during `process-inbox`.
