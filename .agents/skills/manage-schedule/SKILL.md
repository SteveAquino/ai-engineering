---
name: manage-schedule
description: Review and edit the scheduling-assistant's cron job registry (crontab.json), then sync changes to the system crontab. Only invoke as the scheduling-assistant persona.
---

# Skill: Manage Schedule

View and edit the scheduled agent job registry. This skill is the **only** sanctioned way to modify `crontab.json` — direct edits bypass the sync to the system crontab and should never be done.

⛔ **Only invoke this skill as the `scheduling-assistant` persona.**

---

## Storage

```
~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json
```

---

## Phase 0 — Display Current State

Read and display `crontab.json`:

```python
import json, os
path = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json")
if not os.path.exists(path):
    print("(empty — no jobs scheduled yet)")
else:
    data = json.load(open(path))
    jobs = data.get("jobs", [])
    print(f"{'ID':<25} {'Enabled':<8} {'Schedule':<15} {'Role':<35} {'Skill'}")
    print("-" * 105)
    for j in jobs:
        print(f"{j['id']:<25} {str(j['enabled']):<8} {j['schedule']:<15} {j['role']:<35} {j['skill']}")
```

If the file doesn't exist, note that it will be created on first write.

---

## Phase 1 — Choose Action

**Use `ask_user`:**
> "What would you like to do?"

Choices: `["Add a new job", "Edit an existing job", "Enable a job", "Disable a job", "Delete a job", "Done — no changes"]`

If "Done — no changes": exit.

---

## Phase 2 — Collect Details

### Add a new job

Ask in sequence:

**Use `ask_user`:** "Job ID — short kebab-case identifier (e.g., `weekly-retro`)" *(freeform)*
**Use `ask_user`:** "Cron schedule (e.g., `0 9 * * 1` for Monday 9am)" *(freeform)*
**Use `ask_user`:** "Which role should run this job?" *(freeform — role name, e.g., `engineering-manager-assistant`)*
**Use `ask_user`:** "Which skill should that role invoke?" *(freeform — skill name, e.g., `weekly-team-retro`)*
**Use `ask_user`:** "One-line description of what this job does" *(freeform)*

Check that the job ID doesn't already exist. If it does:

**Use `ask_user`:**
> "A job with ID `<ID>` already exists. What would you like to do?"
Choices: `["Overwrite it", "Pick a different ID", "Cancel"]`

Build the new job entry:
```json
{
  "id": "<ID>",
  "description": "<DESCRIPTION>",
  "schedule": "<SCHEDULE>",
  "role": "<ROLE>",
  "skill": "<SKILL>",
  "enabled": true,
  "created_at": "<TODAY>",
  "created_by": "scheduling-assistant"
}
```

### Edit an existing job

**Use `ask_user`:** "Which job ID do you want to edit?" Choices: list of existing IDs.

**Use `ask_user`:** "Which field?" Choices: `["schedule", "role", "skill", "description"]`

**Use `ask_user`:** "New value for `<field>`:" *(freeform, show current value)*

### Enable / Disable

**Use `ask_user`:** "Which job?" Choices: list of job IDs (filter by current state for enable/disable).

Set `enabled: true` or `enabled: false`.

### Delete

**Use `ask_user`:** "Which job do you want to delete?" Choices: list of job IDs.

**Use `ask_user`:**
> "⚠️ This will permanently remove `<ID>` from the registry and system crontab. Are you sure?"
Choices: `["Yes — delete it", "Cancel"]`

---

## Phase 3 — Show Diff and Confirm

Show the proposed change clearly:

```
BEFORE:  <original entry or "(none)">
AFTER:   <new entry or "(removed)">
```

**Use `ask_user`:**
> "Apply this change to `crontab.json` and sync to system crontab?"
Choices: `["Apply it", "Cancel"]`

---

## Phase 4 — Write `crontab.json`

Write the updated file using a Python script at `/tmp/write_crontab.py`:

```python
import json, os
path = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
data = {"jobs": UPDATED_JOBS}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print(f"Written {len(UPDATED_JOBS)} job(s) to {path}")
```

---

## Phase 5 — Sync to System Crontab

The scheduler owns a clearly-marked block in the system crontab. Regenerate it from all enabled jobs:

```python
import subprocess, os, json

COPILOT_BIN = os.path.expanduser("~/.nvm/versions/node/v24.12.0/bin/copilot")
LOG_DIR = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/logs")
os.makedirs(LOG_DIR, exist_ok=True)

path = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json")
jobs = json.load(open(path)).get("jobs", []) if os.path.exists(path) else []

block_start = "# BEGIN scheduling-assistant"
block_end   = "# END scheduling-assistant"

result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
existing = result.stdout if result.returncode == 0 else ""

# Strip old scheduler block
lines = existing.splitlines()
new_lines, inside = [], False
for line in lines:
    if line.strip() == block_start:
        inside = True
    elif line.strip() == block_end:
        inside = False
    elif not inside:
        new_lines.append(line)

# Build new block — use run-job.sh wrapper to handle auth + PATH reliably
WRAPPER = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/run-job.sh")
LOG_DIR = "/tmp/scheduling-assistant"
os.makedirs(LOG_DIR, exist_ok=True)
block = [block_start]
for j in jobs:
    if j.get("enabled", True):
        if "command" in j:
            # Shell command job — run directly, log to /tmp
            cmd = f'{j["command"]} >> {LOG_DIR}/{j["id"]}.log 2>&1'
        else:
            # Role+skill job — use wrapper (handles auth + PATH)
            cmd = f"{WRAPPER} {j['role']} {j['skill']} {j['id']}"
        block.append(f'{j["schedule"]}  {cmd}')
block.append(block_end)

new_crontab = "\n".join(new_lines).rstrip() + "\n" + "\n".join(block) + "\n"
subprocess.run(["crontab", "-"], input=new_crontab, text=True, check=True)
print(f"Synced {len([j for j in jobs if j.get('enabled')])} enabled job(s) to system crontab.")
```

Run `crontab -l` and show the updated scheduler block to confirm.

---

## Phase 6 — Loop

**Use `ask_user`:**
> "Want to make another change?"
Choices: `["Yes — make another change", "No — done"]`

If yes, return to Phase 1.

---

## Notes

- Always use Python scripts at `/tmp/` for file writes — bash heredocs with `${}` are blocked.
- The `crontab.json` file is gitignored — it's personal operational state.
- The scheduler block in the system crontab is bounded by `# BEGIN scheduling-assistant` / `# END scheduling-assistant` markers. Never edit lines inside this block manually.
- Log files live at `~/work/personal/ai-engineering/agents/scheduling-assistant/logs/<job-id>.log`.
- **Auth token:** `run-job.sh` reads from `~/.config/scheduling-assistant/token`. Refresh when expired: `gh auth token > ~/.config/scheduling-assistant/token`
