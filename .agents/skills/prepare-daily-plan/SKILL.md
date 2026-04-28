---
name: prepare-daily-plan
description: Gathers context from available tools and services to synthesize a prioritized daily work plan for the engineering manager, then writes it to the EM assistant's inbox. Designed to run autonomously (no user input required).
---

# Skill: Prepare Daily Plan

Gather context, synthesize a prioritized plan for the day, and deliver it to the `engineering-manager-assistant` inbox. Designed to run headlessly — no `ask_user` calls. Make judgment calls and move forward.

---

## Phase 0 — Orient

Determine today's date:

```bash
date "+%A, %B %-d %Y"   # e.g. "Tuesday, April 28 2026"
DATE=$(date +%Y%m%d)
```

Read the EM role's `AGENTS.md` to understand current priorities and goals:

```bash
cat ~/work/personal/ai-engineering/agents/engineering-manager-assistant/AGENTS.md
```

If `memories.md` exists and is non-empty, read it for recent context:

```bash
cat ~/work/personal/ai-engineering/agents/engineering-manager-assistant/memories.md
```

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

### 1c. Ticket Queue (if Jira/acli available)

Check for `acli`:

```bash
which acli 2>/dev/null && echo "acli available" || echo "acli not available"
```

If available, retrieve in-progress and ready tickets. The exact project key and JQL will depend on your setup — use the most relevant query you can infer from role memories or the `AGENTS.md`:

```bash
# Example — adapt project key and assignee from context
acli jira issue list \
  --jql "assignee = currentUser() AND sprint in openSprints() AND status in ('In Progress', 'To Do', 'Blocked') ORDER BY priority DESC" \
  --columns "key,summary,status,priority" \
  --limit 20
```

Look for:
- Blocked tickets (what's the blocker? can you unblock today?)
- In-progress tickets (any that are stalled or need a nudge?)
- High-priority To Do items that haven't been started

If `acli` is not available, note it and skip.

### 1d. Recent Activity (optional signal)

Scan for anything that happened since yesterday that may need follow-up:

```bash
# PRs merged in the last 24h
gh pr list --state merged --json number,title,mergedAt,url \
  --search "merged:>$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d 'yesterday' +%Y-%m-%d)" \
  | python3 -c "import json,sys; [print(f'#{p[\"number\"]} {p[\"title\"]} (merged) {p[\"url\"]}') for p in json.load(sys.stdin)]" 2>/dev/null || true
```

---

## Phase 2 — Synthesize the Plan

Review all gathered context and produce a prioritized daily plan. Structure it as follows:

```markdown
# Daily Plan — <Day, Month Date Year>

## 🔍 Top Priority
<1–3 items that are highest urgency or highest leverage today. Be specific: include PR/ticket numbers and links.>

## 👀 Needs Review
<PRs or deliverables waiting on your attention. Include PR number, author, and link.>

## 🚧 Unblock / Follow Up
<Blocked tickets, stalled work, or items where a quick message/decision from you unblocks someone else.>

## 📋 In Progress
<Active work items to continue or check in on today.>

## 📌 On Deck
<Lower-priority items to tackle if the above are clear, or to keep front of mind.>

## 📎 Context Notes
<Anything notable from memories, recent merges, or patterns worth noting — e.g. sprint end approaching, team member OOO, etc. Omit if nothing notable.>
```

Guidelines:
- Be specific and actionable — every item should have a clear "what to do"
- Include links/keys wherever available
- Keep each section to ≤5 items; if there's more, pick the highest-signal ones
- If a section has no items, omit it entirely
- Sections with no data from any tool: note "no data available" rather than leaving blank

---

## Phase 3 — Write to Inbox

Write the plan to the EM assistant's inbox:

```python
import os, datetime

INBOX = os.path.expanduser("~/work/personal/ai-engineering/agents/engineering-manager-assistant/inbox")
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
   PRs: 4 open (2 awaiting review, 1 approved, 1 stalled)
   Tickets: 6 found via acli (1 blocked, 3 in progress)
   Issues: gh not available in this context
   Written to: ~/work/personal/ai-engineering/agents/engineering-manager-assistant/inbox/20260428-daily-plan.md
```

---

## Notes

- This skill is **read-only** except for writing the plan file to inbox. Do not close issues, merge PRs, update tickets, or post comments.
- Adapt queries to whatever tools are available — the goal is to gather the richest context possible with what's accessible.
- If running in cron context, all tool checks and data gathering should be non-interactive (no prompts, no auth flows).
- The plan is intended to be read by the `engineering-manager-assistant` role via `process-inbox`, which will then act on it interactively with the user.
- If no tools are available at all, write a minimal plan noting the unavailability and suggesting the user run the skill interactively.
