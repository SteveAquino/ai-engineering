---
name: prepare-daily-plan
description: Gathers context from available tools and services to synthesize a prioritized daily work plan, then writes it to the target role's inbox. Works for any role. Designed to run autonomously (no user input required after role selection).
---

# Skill: Prepare Daily Plan

Gather context, synthesize a prioritized plan for the day, and deliver it to a role's inbox. Works for any role. Designed to run headlessly after the target role is known — make judgment calls and move forward.

---

## Phase 0 — Orient

### 0a — Identify target role

If a role was passed from a calling context (e.g., a cron job or `process-inbox`), use it directly as `TARGET_ROLE`.

Otherwise, list available roles and ask:

```bash
ls -d .agents/roles/*/ | xargs -I{} basename {}
```

**Use `ask_user`:**
> "Which role should receive today's daily plan?"

Choices: the discovered role names.

Store as `TARGET_ROLE`.

### 0b — Load role context

Determine today's date:

```bash
date "+%A, %B %-d %Y"   # e.g. "Tuesday, April 28 2026"
DATE=$(date +%Y%m%d)
```

Read the role's `ROLE.md` to understand its priorities and goals:

```bash
cat .agents/roles/$TARGET_ROLE/ROLE.md
```

If `memories.md` exists and is non-empty, read it for recent context:

```bash
cat .agents/roles/$TARGET_ROLE/state/memories.md
```

Use the role's purpose and goals to guide what "important" means when prioritizing the plan.

---

## Phase 1 — Gather Context

This phase is read-only. Use every available tool or CLI to collect signals. Do not edit, close, merge, or modify anything.

### 1a. Pull Requests Needing Attention

Use `gh` to find open PRs that need review or are stalled:

```bash
# PRs awaiting review (assigned to you or your team)
gh pr list --state open --json number,title,author,reviewDecision,createdAt,url \
  | python3 -c "import json,sys; prs=json.load(sys.stdin); [print(f'#{p[\"number\"]} {p[\"title\"]} — by {p[\"author\"][\"login\"]} ({p[\"reviewDecision\"] or \"awaiting review\"}) {p[\"url\"]}') for p in prs]"
```

Look for:
- PRs with no reviews yet (oldest first = most stalled)
- PRs with change requests that haven't been updated
- PRs close to merging (approved, waiting for CI or final push)

If `gh` is not available (`which gh` fails), note it as unavailable and skip.

### 1b. Issues / Action Items

Use `gh` to find open issues:

```bash
gh issue list --state open --assignee @me --json number,title,labels,createdAt,url \
  | python3 -c "import json,sys; issues=json.load(sys.stdin); [print(f'#{i[\"number\"]} {i[\"title\"]} {i[\"url\"]}') for i in issues]"
```

### 1c. Ticket Queue

Check for available skills that can read tickets. Scan the loaded skill directories for anything relevant:

```bash
ls ~/.agents/skills/
# Also check any employer skill directories registered in ~/.copilot/settings.json
```

Look for skills with names like `read-jira-ticket`, `atlassian-acli`, `list-tickets`, or similar. If found, invoke them to retrieve in-progress and queued tickets for the current user. Use the skill's own instructions to determine the right query — typically: tickets assigned to you, in an active sprint, with status In Progress / To Do / Blocked.

Look for:
- Blocked tickets (what's the blocker? can you unblock today?)
- In-progress tickets (any that are stalled or need a nudge?)
- High-priority To Do items that haven't been started

If no ticket-reading skill is available, note it and skip.

### 1e. Email Digest (optional signal)

If the `read-apple-mail` skill is available, invoke it for an unread mail summary:

```bash
ls .agents/skills/read-apple-mail/SKILL.md 2>/dev/null && echo "available" || echo "unavailable"
```

If available, invoke it as a sub-skill. Its output is an email digest (subject lines, senders, suggested todos) — incorporate flagged action items into the plan's **Top Priority** or **Needs Review** sections.

If `read-apple-mail` returns `skipped-no-consent` or `skipped-sensitive`, include a note in the plan:
> "Email digest skipped (consent or sensitivity check). Review Apple Mail directly."

If unavailable or if the skill returns `error-*`, skip silently.

---

### 1d. Recent Activity (optional signal)

Scan for anything that happened since yesterday that may need follow-up:

```bash
# PRs merged in the last 24h
gh pr list --state merged --json number,title,mergedAt,url \
  --search "merged:>$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d 'yesterday' +%Y-%m-%d)" \
  | python3 -c "import json,sys; [print(f'#{p[\"number\"]} {p[\"title\"]} (merged) {p[\"url\"]}') for p in json.load(sys.stdin)]" 2>/dev/null || true
```

---

## Phase 2 — Classify and Synthesize the Plan

### Classification rubric

Before writing the plan, evaluate every gathered item through this rubric:

| Category | Criteria | Signal words |
|----------|----------|--------------|
| 🔴 **Do** | Only you can do it AND it needs to happen today (urgent, blocking others, time-sensitive) | blocked, CI failing, awaiting my review, deadline today, escalated |
| 👥 **Delegate** | Someone else can or should handle it — or you're the wrong person for it right now | assign to, ping X, ask Y, needs design/QA/PM input |
| 📅 **Schedule** | Important but not today — needs to happen but has no hard deadline today | backlog, low urgency, no blocker, on deck, future sprint |
| 🗑 **Drop / Note** | Low-signal, stale, or purely informational — no action required | FYI, merged, closed, no changes needed |

Apply this classification to every item from Phase 1. When in doubt between Do and Delegate, ask: "Is there anyone else who could unblock this?" If yes → Delegate.

---

### Output format

Every actionable item is a checkbox. Items in **Drop / Note** are plain bullets (not checkboxes — no action to complete).

```markdown
# Daily Plan — <Day, Month Date Year>

## 🔴 Do Today
> These require your direct attention today.

- [ ] <specific action> — <context: PR#, ticket key, or reason it's urgent> [<link>]
- [ ] ...

## 👥 Delegate
> Route these to the right person. Check the box once handed off.

- [ ] Ask <person> to <action> — <why / context>
- [ ] ...

## 📅 Schedule
> Important but not today. Check the box once it's on the calendar or backlog.

- [ ] <action> — <why it matters, rough timeframe if known>
- [ ] ...

## 📎 Context & Notes
> Informational — no action item, just useful awareness.

- <observation, e.g. sprint ends Friday, PR #99 merged, team member OOO>
- Email digest skipped — review Apple Mail directly.  ← include only if applicable
```

### Synthesis guidelines

- Every **Do Today** item must have a clear, single action. If an item is vague, break it into subtasks or move it to Schedule until it's scoped.
- **Delegate** items should name a person or team if known. If unknown, name the function (e.g., "ask QA to verify").
- **Schedule** items should include rough timing if inferable (e.g., "before end of sprint", "next week").
- Keep each section to ≤6 items. If there's more, pick the highest-signal ones and fold the rest into a "and N more…" note.
- Omit any section that has zero items — don't render empty headers.
- Never invent items — only include things supported by data gathered in Phase 1.

---

## Phase 3 — Write to Inbox

Write the plan to the target role's inbox:

```python
import os, datetime

TARGET_ROLE = "<TARGET_ROLE>"
INBOX = os.path.expanduser(f".agents/roles/{TARGET_ROLE}/state/inbox")
os.makedirs(INBOX, exist_ok=True)

date_str = datetime.date.today().strftime("%Y%m%d")
filename = f"{date_str}-daily-plan.md"
filepath = os.path.join(INBOX, filename)

# Write the synthesized plan (PLAN_CONTENT = the markdown from Phase 2)
with open(filepath, "w") as f:
    f.write(PLAN_CONTENT)

print(f"✅ Daily plan written to inbox: {filename}")
```

If a daily plan file for today already exists, overwrite it — this skill may run multiple times in a day.

### Phase 3b — Obsidian Sync (optional)

If the `obsidian-vault` skill is available and `DAILY_PLAN_NOTE_PATH` is configured in that skill's `references/local.md`, invoke `obsidian-vault` to write the plan there too:

- **operation:** `write-note`
- **path:** `DAILY_PLAN_NOTE_PATH` (e.g. `Daily Notes/<YYYY>-<MM>-<DD>.md`)
- **content:** the plan markdown from Phase 2

This makes the Obsidian vault the durable source of truth while the inbox copy drives `process-inbox` actions. If the vault skill is unavailable or not configured, skip silently.

---

## Phase 4 — Confirm

Report a brief summary:
- Date
- How many PRs / tickets / issues were found
- Which tools were available vs. unavailable
- Path the plan was written to

Example:
```
✅ Daily plan ready — Tuesday, April 28 2026
   Role: engineering-manager-assistant
   PRs: 4 open (2 awaiting review, 1 approved, 1 stalled)
   Tickets: 6 found via read-jira-ticket skill (1 blocked, 3 in progress)
   Issues: gh not available in this context
   Written to: .agents/roles/engineering-manager-assistant/state/inbox/20260428-daily-plan.md
```

---

## Notes

- This skill is **read-only** except for writing the plan file to inbox. Do not close issues, merge PRs, update tickets, or post comments.
- Adapt queries to whatever tools are available — the goal is to gather the richest context possible with what's accessible.
- If running in cron context, all tool checks and data gathering should be non-interactive (no prompts, no auth flows).
- The plan is intended to be read by the target role via `process-inbox`, which will then act on it interactively with the user.
- If no tools are available at all, write a minimal plan noting the unavailability and suggesting the user run the skill interactively.
