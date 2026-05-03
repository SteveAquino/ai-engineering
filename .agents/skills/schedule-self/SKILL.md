---
name: schedule-self
description: Install or update the launchd entry that automatically runs the scheduling-assistant on a recurring schedule to process its inbox. Run once to bootstrap the scheduler.
---

# Skill: Schedule Self

Bootstrap the scheduler by installing a launchd job that periodically invokes the `scheduling-assistant` persona to run `process-inbox`. This is what makes the scheduler autonomous — it wakes itself up on a schedule.

Unlike cron, launchd fires missed jobs on wake, so the scheduler catches up after the machine has been asleep.

---

## What Gets Installed

A launchd plist at `~/Library/LaunchAgents/com.scheduling-assistant.self-check.plist` (via `manage-schedule` Phase 5 sync) that runs `run-job.sh scheduling-assistant process-inbox self-check` on the chosen schedule.

---

## Phase 0 — Check Existing Entry

```python
import subprocess, os
plist = os.path.expanduser("~/Library/LaunchAgents/com.scheduling-assistant.self-check.plist")
exists = os.path.exists(plist)
print("Self-scheduling entry found." if exists else "No self-scheduling entry found.")
if exists:
    result = subprocess.run(["launchctl", "list", "com.scheduling-assistant.self-check"], capture_output=True, text=True)
    print(result.stdout)
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

Show what will be installed:

```
Job ID:   self-check
Schedule: <SELF_SCHEDULE>
Role:     scheduling-assistant
Skill:    process-inbox
Fires on: launchd (catches up on wake)
```

**Use `ask_user`:**
> "Install this entry via launchd?"
Choices: `["Yes — install it", "Cancel"]`

---

## Phase 3 — Install

If "Remove self-scheduling" was chosen in Phase 0: remove the self-check entry from `crontab.json`, then run the `manage-schedule` Phase 5 sync to unload the plist. Then stop.

Otherwise, add the self-check entry to `crontab.json` as a special job:

```python
import json, os, datetime
path = os.path.expanduser("~/.agents/roles/scheduling-assistant/crontab.json")
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

Then run the full launchd sync from `manage-schedule` Phase 5 to write and load the plist.

Confirm with:
```bash
launchctl list | grep com.scheduling-assistant
```

Tell the user:
- The schedule installed
- Log file location: `/tmp/scheduling-assistant/self-check.log`
- How to stop: invoke `schedule-self` again and choose "Remove self-scheduling"

---

## Notes

- Always use Python scripts at `/tmp/` for file writes.
- The `self-check` entry is stored in `crontab.json` like any other job — `manage-schedule` will show it in the job table.
- To temporarily pause without removing: use `manage-schedule` to disable the `self-check` job.
- **Auth token:** `run-job.sh` reads from `~/.config/scheduling-assistant/token`. Refresh it when expired: `gh auth token > ~/.config/scheduling-assistant/token`
- **First-time setup:** After installing, run `gh auth token > ~/.config/scheduling-assistant/token && chmod 600 ~/.config/scheduling-assistant/token`
