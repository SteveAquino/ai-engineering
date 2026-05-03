---
name: manage-schedule
description: Review and edit the scheduling-assistant's cron job registry (crontab.json), then sync changes to launchd. Only invoke as the scheduling-assistant persona.
---

# Skill: Manage Schedule

View and edit the scheduled agent job registry. This skill is the **only** sanctioned way to modify `crontab.json` — direct edits bypass the sync to launchd and should never be done.

⛔ **Only invoke this skill as the `scheduling-assistant` persona.**

---

## Storage

```
~/.agents/roles/scheduling-assistant/crontab.json
```

---

## Phase 0 — Display Current State

Read and display `crontab.json`:

```python
import json, os
path = os.path.expanduser("~/.agents/roles/scheduling-assistant/crontab.json")
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
> "Apply this change to `crontab.json` and sync to launchd?"
Choices: `["Apply it", "Cancel"]`

---

## Phase 4 — Write `crontab.json`

Write the updated file using a Python script at `/tmp/write_crontab.py`:

```python
import json, os
path = os.path.expanduser("~/.agents/roles/scheduling-assistant/crontab.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
data = {"jobs": UPDATED_JOBS}
with open(path, "w") as f:
    json.dump(data, f, indent=2)
print(f"Written {len(UPDATED_JOBS)} job(s) to {path}")
```

---

## Phase 5 — Sync to launchd

Jobs are managed as individual `.plist` files under `~/Library/LaunchAgents/`. Unlike cron, launchd fires missed jobs on wake — this is the key advantage.

**Plist label convention:** `com.scheduling-assistant.<job-id>`

```python
import subprocess, os, json
from itertools import product

WRAPPER = os.path.expanduser("~/.agents/roles/scheduling-assistant/run-job.sh")
LOG_DIR = "/tmp/scheduling-assistant"
AGENTS_DIR = os.path.expanduser("~/Library/LaunchAgents")
os.makedirs(LOG_DIR, exist_ok=True)

path = os.path.expanduser("~/.agents/roles/scheduling-assistant/crontab.json")
jobs = json.load(open(path)).get("jobs", []) if os.path.exists(path) else []

def expand_field(s, min_val, max_val):
    """Expand cron field to list of ints, or None for '*'."""
    if s == '*':
        return None
    values = set()
    for part in s.split(','):
        if '-' in part:
            a, b = part.split('-')
            values.update(range(int(a), int(b) + 1))
        elif '/' in part:
            base, step = part.split('/')
            start = min_val if base == '*' else int(base)
            values.update(range(start, max_val + 1, int(step)))
        else:
            values.add(int(part))
    return sorted(values)

def cron_to_intervals(cron_expr):
    """Convert cron expression to list of StartCalendarInterval dicts."""
    minute_f, hour_f, dom_f, month_f, dow_f = cron_expr.strip().split()
    axes = []
    for vals, key in [
        (expand_field(minute_f, 0, 59), 'Minute'),
        (expand_field(hour_f,   0, 23), 'Hour'),
        (expand_field(dom_f,    1, 31), 'Day'),
        (expand_field(month_f,  1, 12), 'Month'),
        (expand_field(dow_f,    0,  7), 'Weekday'),
    ]:
        axes.append([(key, v) for v in vals] if vals is not None else [None])
    intervals = []
    for combo in product(*axes):
        d = {k: v for k, v in combo if k is not None}
        if d not in intervals:
            intervals.append(d)
    return intervals

def build_plist(job):
    label = f"com.scheduling-assistant.{job['id']}"
    log = f"{LOG_DIR}/{job['id']}.log"
    if "command" in job:
        prog_args = ["/bin/bash", "-c", f"{job['command']} >> {log} 2>&1"]
    else:
        prog_args = [WRAPPER, job['role'], job['skill'], job['id']]
    intervals = cron_to_intervals(job['schedule'])
    interval_xml = "\n".join(
        "<dict>" + "".join(f"<key>{k}</key><integer>{v}</integer>" for k, v in d.items()) + "</dict>"
        for d in intervals
    )
    return f"""<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key><string>{label}</string>
    <key>ProgramArguments</key>
    <array>{"".join(f"<string>{a}</string>" for a in prog_args)}</array>
    <key>StartCalendarInterval</key>
    <array>{interval_xml}</array>
    <key>StandardOutPath</key><string>{log}</string>
    <key>StandardErrorPath</key><string>{log}</string>
    <key>RunAtLoad</key><false/>
</dict>
</plist>"""

# Remove all existing scheduling-assistant plists
existing = [f for f in os.listdir(AGENTS_DIR) if f.startswith("com.scheduling-assistant.")]
for f in existing:
    label = f.replace(".plist", "")
    plist_path = os.path.join(AGENTS_DIR, f)
    subprocess.run(["launchctl", "unload", plist_path], capture_output=True)
    os.remove(plist_path)
    print(f"Removed: {f}")

# Write and load new plists for enabled jobs
for j in jobs:
    if j.get("enabled", True):
        label = f"com.scheduling-assistant.{j['id']}"
        plist_path = os.path.join(AGENTS_DIR, f"{label}.plist")
        with open(plist_path, "w") as f:
            f.write(build_plist(j))
        result = subprocess.run(["launchctl", "load", plist_path], capture_output=True, text=True)
        status = "loaded ✅" if result.returncode == 0 else f"ERROR: {result.stderr.strip()}"
        print(f"{label}: {status}")

print(f"\nSynced {len([j for j in jobs if j.get('enabled')])} enabled job(s) to launchd.")
```

Show loaded agents to confirm:
```bash
launchctl list | grep com.scheduling-assistant
```

### Migration: clean up old crontab block (run once if migrating from cron)

```python
import subprocess
result = subprocess.run(["crontab", "-l"], capture_output=True, text=True)
lines = result.stdout.splitlines()
new_lines, inside = [], False
for line in lines:
    if line.strip() == "# BEGIN scheduling-assistant": inside = True
    elif line.strip() == "# END scheduling-assistant": inside = False
    elif not inside: new_lines.append(line)
new_crontab = "\n".join(new_lines).rstrip() + "\n"
subprocess.run(["crontab", "-"], input=new_crontab, text=True, check=True)
print("Removed scheduling-assistant block from crontab.")
```

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
- Plists live at `~/Library/LaunchAgents/com.scheduling-assistant.<job-id>.plist`. Never edit them manually — always re-sync via this skill.
- launchd fires missed jobs on wake — that's why we use it instead of cron.
- Log files live at `/tmp/scheduling-assistant/<job-id>.log`.
- **Auth token:** `run-job.sh` reads from `~/.config/scheduling-assistant/token`. Refresh when expired: `gh auth token > ~/.config/scheduling-assistant/token`
