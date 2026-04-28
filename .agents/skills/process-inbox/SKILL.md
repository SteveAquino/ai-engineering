---
name: process-inbox
description: Process pending scheduling requests from the scheduling-assistant inbox. Parses markdown+frontmatter .md files, applies schedule/cancel changes to crontab.json, syncs to system crontab, then deletes each processed file.
---

# Skill: Process Inbox

Read and apply all pending agent scheduling requests from the inbox directory. Each request is a markdown file with YAML frontmatter. After applying, the file is deleted.

---

## Inbox Location

```
~/work/personal/ai-engineering/agents/scheduling-assistant/inbox/
```

### Message format

```markdown
---
id: req-abc123
action: schedule
job_id: weekly-retro
schedule: "0 9 * * 1"
role: engineering-manager-assistant
skill: weekly-team-retro
requested_by: engineering-manager-assistant
requested_at: 2026-04-28T17:00:00Z
---

Optional human-readable description.
```

`action` must be `schedule` or `cancel`.

---

## Phase 0 — Scan Inbox

```python
import os, glob
inbox = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/inbox")
files = sorted(glob.glob(os.path.join(inbox, "*.md")))
print(f"Found {len(files)} pending request(s):")
for f in files:
    print(f"  {os.path.basename(f)}")
```

If no files found:
> "Inbox is empty — nothing to process."
Stop here.

---

## Phase 1 — Parse Requests

For each `.md` file, parse the YAML frontmatter using Python:

```python
import re

def parse_frontmatter(content):
    match = re.match(r'^---\s*\n(.*?)\n---\s*\n?(.*)', content, re.DOTALL)
    if not match:
        return {}, content
    import yaml
    meta = yaml.safe_load(match.group(1))
    body = match.group(2).strip()
    return meta, body

requests = []
errors = []
for path in files:
    content = open(path).read()
    meta, body = parse_frontmatter(content)
    required = ["action", "job_id", "role", "skill"]
    missing = [f for f in required if f not in meta]
    if missing:
        errors.append(f"{os.path.basename(path)}: missing fields {missing}")
        continue
    if meta["action"] not in ("schedule", "cancel"):
        errors.append(f"{os.path.basename(path)}: unknown action '{meta['action']}'")
        continue
    meta["_file"] = path
    meta["_description"] = body or meta.get("description", "")
    requests.append(meta)
```

If any files fail to parse, surface the errors and ask:

**Use `ask_user`:**
> "⚠️ Some inbox files could not be parsed: `<list>`. Skip them and continue with the rest?"
Choices: `["Skip invalid files and continue", "Abort — fix files first"]`

---

## Phase 2 — Show Proposed Changes

Load current `crontab.json` and display what each request would do:

```python
import json, os
crontab_path = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json")
data = json.load(open(crontab_path)) if os.path.exists(crontab_path) else {"jobs": []}
jobs = {j["id"]: j for j in data.get("jobs", [])}

print(f"{'File':<35} {'Action':<10} {'Job ID':<25} {'Effect'}")
print("-" * 90)
for req in requests:
    existing = jobs.get(req["job_id"])
    if req["action"] == "schedule":
        effect = "UPDATE" if existing else "ADD"
    else:
        effect = "REMOVE" if existing else "⚠️ NOT FOUND"
    print(f"{os.path.basename(req['_file']):<35} {req['action']:<10} {req['job_id']:<25} {effect}")
```

**Use `ask_user`:**
> "Apply all N change(s) to `crontab.json` and sync to system crontab?"
Choices: `["Apply all", "Cancel — don't change anything"]`

---

## Phase 3 — Apply Changes

Apply each request to the jobs dict:

```python
import datetime

for req in requests:
    if req["action"] == "schedule":
        jobs[req["job_id"]] = {
            "id": req["job_id"],
            "description": req["_description"] or req.get("description", ""),
            "schedule": req.get("schedule", ""),
            "role": req["role"],
            "skill": req["skill"],
            "enabled": True,
            "created_at": datetime.date.today().isoformat(),
            "created_by": req.get("requested_by", "unknown")
        }
    elif req["action"] == "cancel":
        if req["job_id"] in jobs:
            jobs.pop(req["job_id"])
```

Write updated `crontab.json` via `/tmp/apply_inbox.py`:

```python
import json, os
path = os.path.expanduser("~/work/personal/ai-engineering/agents/scheduling-assistant/crontab.json")
os.makedirs(os.path.dirname(path), exist_ok=True)
with open(path, "w") as f:
    json.dump({"jobs": list(jobs.values())}, f, indent=2)
```

Regenerate the system crontab scheduler block (same logic as `manage-crons` Phase 5):

```python
import subprocess, os

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

block = [block_start]
for j in jobs.values():
    if j.get("enabled", True):
        cmd = (f'{COPILOT_BIN} -p "Assume role {j["role"]} and immediately invoke the {j["skill"]} skill"'
               f' --yolo >> {LOG_DIR}/{j["id"]}.log 2>&1')
        block.append(f'{j["schedule"]}  {cmd}')
block.append(block_end)

new_crontab = "\n".join(new_lines).rstrip() + "\n" + "\n".join(block) + "\n"
subprocess.run(["crontab", "-"], input=new_crontab, text=True, check=True)
```

---

## Phase 4 — Delete Processed Files

Delete each successfully processed inbox file:

```python
for req in requests:
    os.remove(req["_file"])
    print(f"Deleted: {os.path.basename(req['_file'])}")
```

Report a summary:
- N request(s) applied
- N file(s) deleted
- N error(s) skipped (if any)

---

## Notes

- Always use Python scripts at `/tmp/` for file writes.
- Processed inbox files are deleted — not archived. The crontab.json and system crontab are the record of what was applied.
- If `yaml` is not available in the Python environment, install it first: `pip install pyyaml --quiet`.
- The inbox directory itself is gitignored. Other agents write `.md` files here; the scheduler reads and deletes them.
- Run `crontab -l` at the end and show the scheduler block to confirm the sync.
