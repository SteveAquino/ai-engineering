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

### 0b — Gather calendar and schedule context

Before fetching any data sources, ask for today's schedule. This is the most important constraint — it determines what can realistically be accomplished and how async time should be allocated.

**Ask the user:**
> "What does your calendar look like today? Share any meetings, blocks, or constraints — including a hard end time if you have one. You can paste a list, describe it, or share a screenshot."

Accept any format (list, prose, screenshot). Extract and store:
- `MEETINGS` — list of meetings with times (name, start, end)
- `ASYNC_WINDOWS` — contiguous blocks with no meetings (these are where work actually happens)
- `HARD_END` — latest time the user can work today (default: assume no constraint if not given)
- `ENERGY_NOTES` — any physical, fatigue, or focus notes the user mentions (e.g. "ending at 6pm due to health", "slow morning")

If the user skips or says "no calendar today", set `MEETINGS = []`, `ASYNC_WINDOWS = ["all day"]`, `HARD_END = "EOD"`.

This context shapes the entire plan:
- **Do Today** items must fit in `ASYNC_WINDOWS` — if there's only 60 min of async time, the section should have at most 2–3 items
- Meetings become the **Schedule** section header entries
- `HARD_END` is displayed prominently at the top of the plan
- Anything that can't fit today moves to **Carry Forward**, not **Do Today**

### 0c — Load role context

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

## Phase 1 — Gather Context via Inbox Sub-Skills

This phase is **read-only and DRY** — it delegates to specialized inbox skills that each own their data source. Each sub-skill writes a dated summary file to Obsidian; this skill reads those files to synthesize the plan. Never re-fetch data that a sub-skill already collected today.

```bash
TODAY=$(date +%Y-%m-%d)
VAULT_PATH="/Users/stevenaquino/Documents/Obsidian Vault: Work"
```

### 1a. Jira Inbox

Check if today's Jira summary already exists:

```bash
JIRA_SUMMARY="$VAULT_PATH/Inbox Summaries/Jira/$TODAY Jira Summary.md"
if [ -f "$JIRA_SUMMARY" ]; then
    echo "✅ Jira summary found — reading existing file"
    cat "$JIRA_SUMMARY"
else
    echo "⬇️  Jira summary not found — invoking read-jira-inbox skill"
    # Invoke the read-jira-inbox skill (it will write the file)
fi
```

If the file doesn't exist, invoke the `read-jira-inbox` skill as a sub-step. After it completes, read `$JIRA_SUMMARY`.

Extract action signals:
- 🔴 Blocked tickets → **Do Today**
- 🟡 In Progress → **Do Today** or **Schedule**
- PRs awaiting review from Jira context → **Do Today**

### 1b. GitHub Inbox

Check if today's GitHub summary already exists:

```bash
GITHUB_SUMMARY="$VAULT_PATH/Inbox Summaries/GitHub/$TODAY GitHub Summary.md"
if [ -f "$GITHUB_SUMMARY" ]; then
    echo "✅ GitHub summary found — reading existing file"
    cat "$GITHUB_SUMMARY"
else
    echo "⬇️  GitHub summary not found — invoking read-github-inbox skill"
    # Invoke the read-github-inbox skill (it will write the file)
fi
```

If the file doesn't exist, invoke the `read-github-inbox` skill as a sub-step.

Extract action signals:
- 🔴 Review requested on me → **Do Today**
- 🔴 CI failing on my PRs → **Do Today**
- 🟡 My stalled PRs (no review > 2 days) → **Delegate** or nudge
- 🟢 Assigned issues → **Schedule** unless time-sensitive

### 1c. Email Inbox

Check if today's email summary already exists:

```bash
EMAIL_SUMMARY="$VAULT_PATH/Inbox Summaries/Email/$TODAY Email Summary.md"
if [ -f "$EMAIL_SUMMARY" ]; then
    echo "✅ Email summary found — reading existing file"
    cat "$EMAIL_SUMMARY"
else
    echo "⬇️  Email summary not found — invoking clean-inbox skill"
    # Invoke the clean-inbox skill (it will write the file)
    # Note: clean-inbox is interactive — if running headlessly, skip and note the gap
fi
```

Extract action signals:
- 🔴 Compliance deadlines, approval requests, sensitive items → **Do Today**
- 🟡 Security/certificate threads, RSVP deadlines → **Do Today** or **Schedule**
- 🟢 FYI calendar items → **Context & Notes**

### 1d. Slack Digest (optional)

Check if today's Slack summary exists:

```bash
SLACK_SUMMARY="$VAULT_PATH/Inbox Summaries/Slack/$TODAY Slack Summary.md"
[ -f "$SLACK_SUMMARY" ] && cat "$SLACK_SUMMARY" || echo "No Slack summary for today — was it archived separately?"
```

If a Slack summary exists, read it for additional context. Do not invoke any tool to create it — Slack digests are manually shared or created via `clean-inbox`-style processing.

**Critical Slack-source rule:** only promote a Slack-derived item into the daily plan if the digest preserves a **specific, checkable source** for that item — preferably a Slack permalink, or at minimum a directly checkable Jira/GitHub/Confluence link captured alongside the Slack note. A generic label like "Slack digest", "#preng", "Aditi asked", or "pasted Slack notes" is **not sufficient**.

If a pasted/manual Slack digest surfaces a plausible action but does **not** include a specific permalink or equivalent checkable source:
- Prefer to **omit** the item rather than fabricate confidence
- Or include it only as `⚠️ needs source verification — ...`
- If a user is present and the interruption is reasonable, ask them for the specific permalink/thread before treating it as a normal action item

### 1e. Recent Merged PRs (optional enrichment)

Pull lightweight recent activity that doesn't require a sub-skill:

```bash
# PRs merged in the last 24h — useful for Context & Notes section
gh pr list --state merged --json number,title,mergedAt,url \
  --search "merged:>$(date -v-1d +%Y-%m-%d 2>/dev/null || date -d 'yesterday' +%Y-%m-%d)" \
  | python3 -c "import json,sys; [print(f'#{p[\"number\"]} {p[\"title\"]} (merged) {p[\"url\"]}') for p in json.load(sys.stdin)]" 2>/dev/null || true
```

---

## Phase 2 — Classify and Synthesize the Plan

### Source-verification gate (run before classification)

Before an item can appear as a normal actionable checkbox, verify that you can point to a **specific, checkable source** for that exact item.

Allowed source forms:
- Jira ticket key or URL (for example `TEC-8164` or `https://.../browse/TEC-8164`)
- GitHub PR / issue URL
- Slack permalink (`.../archives/.../p1234567890123456`)
- Confluence URL
- Obsidian wikilink **only if** the referenced note itself contains one of the checkable sources above

Not sufficient on their own:
- "Slack digest"
- "Email summary"
- "Task List"
- channel names without permalinks (for example `#preng`)
- person-only references (for example "Priya asked", "Justin DM")
- copied carry-forward rows that no longer preserve the original source

If the item has a valid source, keep it eligible for normal classification.

If the item is useful but lacks a valid source, you have exactly three acceptable options:
1. **Omit it entirely**
2. Include it as `⚠️ needs source verification — ...` with the best-available provenance note
3. If interactive and not disruptive, ask the user for the missing source link before including it

Never silently upgrade a weakly sourced or unsourced item into a normal action item.

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

> Sources: [[Inbox Summaries/Jira/YYYY-MM-DD Jira Summary|Jira]] · [[Inbox Summaries/GitHub/YYYY-MM-DD GitHub Summary|GitHub]] · [[Inbox Summaries/Email/YYYY-MM-DD Email Summary|Email]] · [[Inbox Summaries/Slack/YYYY-MM-DD Slack Summary|Slack]]
> **Hard stop: <HARD_END>**   ← omit this line if no hard end was given

## 🗓 Today's Schedule
> Omit this section entirely if no calendar was provided.

| Time | Event | Type |
|---|---|---|
| <time> | <meeting name> | Meeting |
| <time>–<time> | **<async block name>** | Async window |

**Async windows: <list of available blocks with durations>**

## ⚡ <First async window label, e.g. "Right Now (10:00–11:00am)">
> Only include if there is async time before the first meeting. Quick, low-friction actions only.

## 🔴 Do Today
> These require your direct attention today.

- [ ] <specific action> — <context: PR#, ticket key, or reason it's urgent> [<link>]
- [ ] <specific action> — <context> _(source: <specific checkable source>)_
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
- **Calendar-aware sizing:** Count the total async minutes available (sum of `ASYNC_WINDOWS`). If async time is < 90 min, **Do Today** should have at most 2–3 items. If < 3 hours, at most 4–5 items. A day packed with meetings is not a day to stack a 10-item do-list — be ruthless.
- Keep each section to ≤6 items. If there's more, pick the highest-signal ones and fold the rest into a "and N more…" note.
- Omit any section that has zero items — don't render empty headers.
- Never invent items — only include things supported by data gathered in Phase 1.
- **Every external reference must be a hyperlink — no exceptions.** Jira tickets, GitHub PRs, issues, and any other external resource must be linked inline where they first appear. Plain-text keys like `TEC-1234` or `#99` with no link are not acceptable in the output.
- **Never fabricate links.** If a real URL is not available from the gathered data, write the item as plain text with a note like "(check email for invite link)" or "(find in Slack)". Do not construct placeholder URLs like `TEC-0000` or guess at ticket numbers.
- **Every generated action item must carry its own inline source citation.** Add `_(source: ...)_` or equivalent directly on the item line. Do not rely on the plan-level `> Sources:` header as evidence for individual items.
- **Generic provenance is not enough.** `Slack digest`, `email summary`, `Task List`, `#preng`, `GitHub bot`, or a person's name without a direct link/key are insufficient for a normal action item.
- **Carry-forward requires re-validation.** Before carrying an item into a new daily plan, re-open the prior plan / task list row / source note and confirm the item still retains a specific, checkable source. Preserve that source in the newly generated line.
- **Do not silently carry forward source-less items.** If a carried item no longer has a valid source, either drop it, or render it as `⚠️ needs source verification — ...` for one-time human confirmation. Do not increment `carried N×` on an unverified item.
- **Task List / legacy action lists are secondary indexes, not primary evidence.** Only carry an item from them when the row itself contains a live Jira/GitHub/Slack/Confluence citation (or a resolvable note that does). Otherwise treat the row as unverified memory and do not promote it blindly.
- **Slack-derived items need a permalink.** If the underlying Slack material is a pasted digest or summary without message URLs, omit the item or mark it `⚠️ needs source verification` instead of presenting it as trusted fact.

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

### Phase 3b — Obsidian Sync

Write the daily plan to Obsidian:

```python
import os, datetime

VAULT_PATH = "/Users/stevenaquino/Documents/Obsidian Vault: Work"
TODAY = datetime.date.today()
date_label = TODAY.strftime("%Y-%m-%d")

plan_path = f"{VAULT_PATH}/Daily Plans/{date_label} Daily Plan.md"
os.makedirs(os.path.dirname(plan_path), exist_ok=True)
with open(plan_path, "w") as f:
    f.write(PLAN_CONTENT)
print(f"✅ Daily plan written to Obsidian: {plan_path}")
```

### Phase 3c — Update Welcome.md

Update **two sections** of `Welcome.md`:

#### 1. Start of Day table

Replace the Start of Day table to point to today's dated summaries:

```python
import re, os, datetime

VAULT_PATH = "/Users/stevenaquino/Documents/Obsidian Vault: Work"
TODAY = datetime.date.today().strftime("%Y-%m-%d")
welcome_path = f"{VAULT_PATH}/Welcome.md"

content = open(welcome_path).read()

new_start_of_day = f"""## 🌅 Start of Day

| | |
|---|---|
| 📅 [[Daily Plans/{TODAY} Daily Plan\\|Today's Plan]] | 📬 [[Inbox Summaries/Email/{TODAY} Email Summary\\|Email Summary]] |
| 💬 [[Inbox Summaries/Slack/{TODAY} Slack Summary\\|Slack Summary]] | 📋 [[Inbox Summaries/Jira/{TODAY} Jira Summary\\|Jira Summary]] |
| 🐙 [[Inbox Summaries/GitHub/{TODAY} GitHub Summary\\|GitHub Summary]] | 🌙 [[Daily Notes/{TODAY} End of Day\\|End of Day Notes]] |"""

updated = re.sub(
    r"## 🌅 Start of Day.*?(?=\n---|\n## )",
    new_start_of_day + "\n\n",
    content,
    flags=re.DOTALL
)
```

#### 2. Workload Meter

Count open action items from today's plan and update the meter:

```python
tasks = re.findall(r"- \[ \] (.+)", PLAN_CONTENT)
high   = sum(1 for t in tasks if "🔴" in t)
medium = sum(1 for t in tasks if "🟡" in t)
low    = sum(1 for t in tasks if "🟢" in t)
total  = len(tasks)

filled = min(round(total / 15 * 15), 15)
bar = "█" * filled + "░" * (15 - filled)

if total <= 3:    label = "Light"
elif total <= 7:  label = "Moderate"
elif total <= 11: label = "Heavy"
else:             label = "Critical"

new_workload = f"""## 🌡️ Workload

| 🔴 **{high}** | 🟡 **{medium}** | 🟢 **{low}** | **{total} open** — `{bar}` {label} |
|---|---|---|---|"""

updated = re.sub(
    r"## 🌡️ Workload.*?(?=\n---|\n## )",
    new_workload + "\n\n",
    updated,
    flags=re.DOTALL
)

open(welcome_path, "w").write(updated)
print(f"✅ Welcome.md updated — Start of Day links + Workload: {total} open ({high}🔴 {medium}🟡 {low}🟢) — {label}")
```

If `Welcome.md` doesn't exist or either section is missing, skip that section silently and log a warning.

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
