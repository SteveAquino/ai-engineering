---
name: schedule-self
description: Install or update the system cron entry that automatically runs the scheduling-assistant on a recurring schedule to process its inbox. Run once to bootstrap the scheduler.
---

# Skill: Schedule Self

Bootstrap the scheduler by installing a system cron entry that periodically invokes the `scheduling-assistant` persona to run `process-inbox`. This is what makes the scheduler autonomous — it wakes itself up on a schedule.

---

## What Gets Installed

A cron entry in the user's system crontab (inside the `scheduling-assistant` block) that runs:

```bash
<SCHEDULE>  ~/.nvm/versions/node/v24.12.0/bin/copilot \
  -p "Assume role scheduling-assistant and immediately invoke the process-inbox skill" \
  --yolo >> ~/work/personal/ai-engineering/agents/scheduling-assistant/logs/self-check.log 2>&1
```

---

## Phase 0 — Check Existing Entry

```python
import subprocess, re
result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
crontab = result.stdout if result.returncode == 0 else ""
has_entry = "process-inbox" in crontab and "scheduling-assistant" in crontab
print("Self-scheduling entry found." if has_entry else "No self-scheduling entry found.")
print()
# Show current scheduler block if it exists
in_block = False
for line in crontab.splitlines():
    if "# BEGIN scheduling-assistant" in line:
        in_block = True
    if in_block:
        print(line)
    if "# END scheduling-assistant" in line:
        in_block = False
```

If an entry already exists, tell the user and ask:

**Use `ask_user`:**
> "A self-scheduling entry already exists. What would you like to do?"
Choices: `["Update the schedule", "Remove self-scheduling", "Leave it as-is"]`

If "Leave it as-is": stop.

---

## Phase 1 — Choose Frequency

**Use `ask_user`:**
> "How often should the scheduler check its inbox?"

Choices:
- `"Every 15 minutes (*/15 * * * *)"`
- `"Every hour (0 * * * *)"`
- `"Every 6 hours (0 */6 * * *)"`
- `"Daily at midnight (0 0 * * *)"`
- `"Custom — I'll enter a cron expression"`

If custom, ask freeform:

**Use `ask_user`:**
> "Enter your cron schedule expression (e.g., `*/30 * * * *` for every 30 minutes):"

Store as `SELF_SCHEDULE`.

---

## Phase 2 — Preview and Confirm

Show the exact cron line that will be written:

```
<SELF_SCHEDULE>  ~/work/personal/ai-engineering/agents/scheduling-assistant/run-job.sh \
  scheduling-assistant process-inbox \
  ~/work/personal/ai-engineering/agents/scheduling-assistant/logs/self-check.log
```

**Use `ask_user`:**
> "Install this entry in the system crontab?"
Choices: `["Yes — install it", "Cancel"]`

---

## Phase 3 — Install

If "Remove self-scheduling" was chosen in Phase 0: remove the self-check entry from the `manage-schedule` block and re-sync (using the same block-replacement logic as `manage-schedule`). Then stop.

Otherwise, add the self-check entry to `crontab.json` as a special job:

```python
import json, os, datetime
path = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json")
data = json.load(open(path)) if os.path.exists(path) else {"jobs": []}
jobs = data.get("jobs", [])

# Remove any existing self-check entry
jobs = [j for j in jobs if j.get("id") != "self-check"]

# Add updated entry
jobs.append({
    "id": "self-check",
    "description": "Scheduler self-check: process inbox on a recurring schedule",
    "schedule": SELF_SCHEDULE,
    "role": "scheduling-assistant",
    "skill": "process-inbox",
    "enabled": True,
    "created_at": datetime.date.today().isoformat(),
    "created_by": "scheduling-assistant"
})

os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump({"jobs": jobs}, f, indent=2)
```

Then regenerate the full system crontab block (same logic as `manage-schedule` Phase 5):

```python
import subprocess

COPILOT_BIN = os.path.expanduser("~/.nvm/versions/node/v24.12.0/bin/copilot")
LOG_DIR = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/logs")
os.makedirs(LOG_DIR, exist_ok=True)

block_start = "# BEGIN scheduling-assistant"
block_end   = "# END scheduling-assistant"

result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
existing = result.stdout if result.returncode == 0 else ""

lines = existing.splitlines()
new_lines, inside = [], False
for line in lines:
    if line.strip() == block_start:
        inside = True
    elif line.strip() == block_end:
        inside = False
    elif not inside:
        new_lines.append(line)

# Use run-job.sh wrapper to handle auth + PATH reliably
WRAPPER = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/run-job.sh")
GH_BIN = "/opt/homebrew/bin/gh"
block = [block_start]
for j in jobs:
    if j.get("enabled", True):
        log = f"{LOG_DIR}/{j['id']}.log"
        cmd = f"{WRAPPER} {j['role']} {j['skill']} {log}"
        block.append(f'{j["schedule"]}  {cmd}')
block.append(block_end)

new_crontab = "\n".join(new_lines).rstrip() + "\n" + "\n".join(block) + "\n"
subprocess.run(["crontab", "-"], input=new_crontab, text=True, check=True)
```

Confirm by running `crontab -l` and showing the scheduler block.

Tell the user:
- The schedule installed
- Log file location: `~/work/personal/ai-engineering/agents/scheduling-assistant/logs/self-check.log`
- How to stop: invoke `schedule-self` again and choose "Remove self-scheduling"

---

## Notes

- Always use Python scripts at `/tmp/` for file writes.
- The `self-check` entry is stored in `crontab.json` like any other job — `manage-schedule` will show it in the job table.
- To temporarily pause without removing: use `manage-schedule` to disable the `self-check` job.
- The Copilot CLI binary path `~/.nvm/versions/node/v24.12.0/bin/copilot` may vary. Verify with `which copilot` or `nvm which current` if the cron doesn't fire.
- **Auth token:** `run-job.sh` reads from `~/.config/scheduling-assistant/token`. Refresh it when expired: `gh auth token > ~/.config/scheduling-assistant/token`
- **First-time setup:** After installing, run `gh auth token > ~/.config/scheduling-assistant/token && chmod 600 ~/.config/scheduling-assistant/token`
