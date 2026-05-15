---
name: game-world-update
description: Refreshes the Game World section of the EM's Obsidian Welcome.md from live Jira/PI data. Updates sagas, boss fights, dungeons, and side quests with current status and progress bars. Designed to run autonomously (daily or on-demand). Preserves manually-entered notes.
---

# Skill: Game World Update

Refresh the 🎮 Game World section of `Welcome.md` in the Obsidian vault with live data from Jira and PI projects. Maps Jira items to game objects using the canonical rubric, computes progress bars from Jira status, and rewrites the section in place. Everything below the Game World section is preserved exactly as-is.

---

## Prerequisites

- `acli` must be authenticated (same config used by other Carrum skills)
- Obsidian vault path must be set in `references/local.md` as `VAULT_PATH`
- `WELCOME_NOTE` defaults to `Welcome.md` at vault root

---

## Canonical Game Taxonomy

Use this rubric throughout the skill to classify any item:

| Signal | Classification |
|---|---|
| Multi-epic project (2+ epics, months of work) | 📜 Main Quest |
| Major deliverable with external deadline or blocks other teams | 🐉 Boss Fight |
| First boss within a saga (single-client, scoped delivery) | ⚡ Mini-Boss (tag Boss Fight with ⚡) |
| Research/discovery that must complete before a boss can be fought | 🏰 Dungeon |
| Valuable improvement, no hard deadline, easy to defer | 🗺️ Side Quest |
| Recurring low-effort task, daily/weekly | ⚔️ Daily Grind |
| Urgent single task this sprint | ✅ Action Item |

---

## Progress Bar Scale

Map Jira status → progress bar using this table. When in doubt, use the lower tier.

| Jira Status(es) | Progress Bar | Label |
|---|---|---|
| To Do, Backlog, Icebox, Not Started | `░░░░░` | Not Started |
| In Progress (early), Prioritized | `██░░░` | Started |
| In Progress (mid), Design Review | `███░░` | Halfway |
| Code Review, Technical Review, Product Review | `████░` | Almost Done |
| Done, Closed, Released | `█████` | Cleared |

For **Sagas**: compute progress as the average of their active Boss Fights' progress bars. Use the same 5-tier scale.

For **Dungeons**: pull from the Jira ticket status. If the dungeon has no ticket (it's a freeform item), preserve the existing progress bar from the current Welcome.md.

---

## Phase 0 — Load Config

```bash
# Read vault path
cat "$(dirname "$0")/references/local.md" 2>/dev/null || echo "(no local references)"

VAULT_PATH="<from local.md>"
WELCOME_NOTE="$VAULT_PATH/Welcome.md"
TODAY=$(date "+%Y-%m-%d")
```

Validate:
- `VAULT_PATH` must be set and directory must exist
- `$WELCOME_NOTE` must exist — this skill updates in place, it does not create from scratch

---

## Phase 1 — Fetch Live Jira Data

Run all queries in parallel using background bash processes. Capture CSV output for each.

### 1a — Active Main Quests (PI Projects)

> **PI structure note:** PI items are Platform Ideas in Jira Polaris. They are NOT epics.
> A PI item with multiple child PI items = 📜 Main Quest. A PI item linked to a single TEC epic = just a Boss Fight (no saga wrapper).
> The PI→TEC link is embedded in the TEC epic's description text (e.g. `Platform Idea: PI-661`), not a structured Jira field — `acli` cannot query it directly.
> Query active PI items and cross-reference with known saga mappings below.

```bash
acli jira workitem search \
  --jql "project = PI AND status not in (Done, Released, Closed) ORDER BY priority DESC" \
  --csv
```

For each PI item: capture key, summary, status, priority. Cross-reference with the saga seed table in Phase 2a.

### 1b — Active Boss Fights (TEC Epics, non-EM-tasks)

```bash
acli jira workitem search \
  --jql "project = TEC AND issuetype = Epic AND status not in (Done, Released) AND key != TEC-7995 ORDER BY priority DESC" \
  --csv
```

> **Status note:** Jira uses `Released` as a distinct status from `Done`. Always exclude both.

For each TEC epic: capture key, summary, status, assignee.

Also query the Engineering Manager Tasks epic (TEC-7995) children separately — these feed Side Quests, not Boss Fights:

```bash
acli jira workitem search \
  --jql "'Epic Link' = TEC-7995 AND status != Done ORDER BY priority DESC" \
  --csv
```

### 1c — Dungeon Tickets

Dungeons are research/discovery tickets that are designated as prerequisites for a boss. Identify them by:
- Issue type contains "Spike", "Research", or "Discovery"
- OR summary contains "research", "discovery", "analysis", "evaluation", "eval", "strategy"
- AND status != Done

```bash
acli jira workitem search \
  --jql "project = TEC AND status != Done AND (issuetype in (Spike) OR summary ~ \"research\" OR summary ~ \"analysis\" OR summary ~ \"evaluation\" OR summary ~ \"strategy\") ORDER BY priority DESC" \
  --csv
```

---

## Phase 2 — Build the Game World Model

Parse the CSV results into an in-memory model. For each item, apply the classification rubric.

### 2a — Sagas

Map PI project keys to saga names using this seed table (update if new sagas emerge):

| PI Key | Saga Name |
|---|---|
| PI-882 | Eligibility API |
| PI-900 | Aetna CCOE |
| PI-896 | Pentest Remediation |
| Any new PI epic not in table | Use summary as saga name |

For each saga, compute:
- `active_boss`: the highest-priority Boss Fight linked to this saga (by matching saga name in Boss Fight table or by epic link)
- `urgency_color`: 🔴 if any linked boss has an external deadline within 14 days; 🟠 if incoming/not started; 🟡 if active; 🟢 if in review

### 2b — Boss Fights

For each TEC epic (excluding TEC-7995):
- Map to a saga if PI key is known (look for PI epic link field or naming convention)
- Mark as **⚡ mini-boss** if it is the first/smallest deliverable within a saga
- Compute progress bar from Jira status
- Set status color: 🔴 = deadline within 14 days or overdue; 🟠 = incoming; 🟡 = active/icebox; 🟢 = in review

**Preserve existing boss fights not returned by the query** (they may be in Jira as Stories or Tasks rather than Epics). If a boss fight is in the current Welcome.md but not found by the query, keep it with a `⚠️ not found in Jira` note.

### 2c — Dungeons

For each research/discovery ticket:
- `unlocks`: infer from ticket title or epic link — "Unlocks <boss name>" if discernible, otherwise leave blank for manual fill
- `progress`: compute from Jira status using progress bar table
- `notes`: **preserve existing notes from current Welcome.md if present** — never overwrite manually-entered notes

**For freeform dungeons** (no Jira ticket, in current Welcome.md manually):
- Keep them as-is
- Do not delete them

### 2d — Side Quests

Side quests render as a **single flat table** with a Category column (`Engineering`, `EM / Process`, `Research`). Do not split into sub-tables.

Apply the rubric to classify each item:
- No external deadline + no client blocker + valuable improvement → Side Quest
- If the epic description mentions Q1/Q2/1H but is purely internal with no external SLA → Side Quest (not Boss Fight)

Pull from EM Tasks epic children (TEC-7995) and the existing Welcome.md side quests section. Merge:
- Items from TEC-7995 that are In Progress or Prioritized → include
- Items from TEC-7995 that are Icebox → include if summary matches the current list
- Research items: any ticket whose summary matches "research", "analysis", "pricing", "audit" → Category: Research
- Existing Obsidian `[[wiki-links]]` in the Research rows → preserve as-is
- Sort order: In Progress → Code Review → Queued/Ongoing → Icebox

---

## Phase 3 — Preserve Existing Manual Content

Before rewriting, read the current `Welcome.md` and extract:

1. **Dungeon Notes column** — capture any manually-entered notes per dungeon row
2. **Freeform dungeons** — dungeons with no Jira ticket key
3. **Side quest manual items** — items without a Jira key (e.g., "Accessibility → 100%", coaching items)
4. **Research wiki-links** — Obsidian `[[...]]` links in the Research subcategory
5. **Everything below the `---` after Daily Grind** — the remainder of the file (Action Items, Sprint Status, Team, etc.) is untouched

Store extracted content in memory. Restore it verbatim in Phase 4.

---

## Phase 4 — Render Game World Section

Render the complete Game World section as markdown. Use the following template as the canonical structure:

```markdown
## 🎮 Game World

> **Rubric:** What is this task?
> - Blocks other teams or has an external deadline → 🐉 **Boss Fight**
> - Research/discovery that must happen before a boss → 🏰 **Dungeon**
> - Multi-epic campaign spanning months → 🗺️ **Main Quest**
> - Valuable but no hard deadline, can defer → 🗺️ **Side Quest**
> - Recurring, low-effort, daily/weekly → ⚔️ **Grind**
> - Urgent single task this sprint → ✅ **Action Item**

---

### 🌍 Active Main Quests

| Main Quest | Status | Active Boss |
|---|---|---|
{{SAGAS}}

---

### 🐉 Boss Fights

| Boss | Main Quest | Progress | Status |
|---|---|---|---|
{{BOSS_FIGHTS}}

---

### 🏰 Active Dungeons
*One per saga. Clear before the boss can be fought.*
*Progress: `░░░░░` Not Started · `██░░░` Started · `███░░` Halfway · `████░` Almost Done · `█████` Cleared*

| Dungeon | Unlocks | Progress | Notes |
|---|---|---|---|
{{DUNGEONS}}

---

### 🗺️ Side Quests
*Queue these. Don't let them crowd the dungeons.*

**Engineering**

| Quest | Key | Status |
|---|---|---|
{{SIDE_QUESTS_ENGINEERING}}

**EM / Process**

| Quest | Key | Status |
|---|---|---|
{{SIDE_QUESTS_EM}}

**Research (📚 Read before deciding)**

| Quest | Verdict | Key |
|---|---|---|
{{SIDE_QUESTS_RESEARCH}}

---

### ⚔️ Daily Grind Goals
*Hit these for grind XP. Missing slows the meter — it doesn't break the streak.*

| Task | Goal | Today |
|---|---|---|
| Slack / Messages | 80% cleared | ⬜ |
| Inbox triage | Zero | ⬜ |
| Active sprint Jira touches | Every ticket | ⬜ |
| 1:1 notes filed | Same day | ⬜ |
{{GRIND_OVERDUE}}
```

`{{GRIND_OVERDUE}}`: inject any tickets from TEC-7995 children with `duedate < today` and status != Done as overdue grind items.

---

## Phase 5 — Write to Obsidian

Reconstruct the full `Welcome.md`:

1. Preserve everything **above** `## 🎮 Game World` exactly as-is (Level/XP section, header)
2. Replace from `## 🎮 Game World` through the `---` after `### ⚔️ Daily Grind Goals` with the newly rendered section
3. Preserve everything **below** that `---` exactly as-is

Write using Python to avoid heredoc issues:

```python
with open(WELCOME_NOTE, 'r', encoding='utf-8') as f:
    original = f.read()

# Find insertion boundaries
game_world_start = original.index('## 🎮 Game World')
# Find the --- that follows the Daily Grind section
grind_end_marker = original.index('\n---\n', original.index('### ⚔️ Daily Grind Goals'))
grind_end = grind_end_marker + len('\n---\n')

header = original[:game_world_start]
footer = original[grind_end:]

new_content = header + RENDERED_GAME_WORLD + '\n---\n' + footer

with open(WELCOME_NOTE, 'w', encoding='utf-8') as f:
    f.write(new_content)

print(f"Welcome.md updated — {len(new_content)} bytes")
```

---

## Phase 6 — Summary Report

Print a summary:

```
✅ Game World Updated — {TODAY}

🌍 Main Quests:      {N} active
🐉 Boss Fights: {N} active ({N} overdue/hot)
🏰 Dungeons:   {N} active ({N} not started)
🗺️ Side Quests: {N} engineering / {N} EM / {N} research
⚠️  Preserved {N} manual dungeon notes
⚠️  Kept {N} freeform items (no Jira ticket)
```

If running autonomously (no user present), send a brief completion message to the `engineering-manager-assistant` inbox via the `send-message` skill.

---

## Notes

- This skill updates Welcome.md **in place** — it never recreates the file from scratch
- The Level/XP row is **never touched** — XP tracking is a separate concern
- The Daily Grind checkboxes reset to `⬜` on every run — they're today's goals, not persistent state
- Saga membership for Boss Fights is inferred from naming + epic links. If a boss can't be matched to a saga, it appears under "Standalone"
- This skill should be invoked by `prepare-daily-plan` after pulling Jira/GitHub context, or run manually with `/game-world-update`
- For first-run calibration: after the skill runs, review the output and correct any mis-classifications. Those corrections should be fed back into the saga membership table in Phase 2a

---

## Future Enhancements (not yet built)

- **XP rollup**: award XP when a Boss Fight or Dungeon transitions to Done since the last run; append to Level/XP row
- **Boss kill notifications**: play a sound (via `osx-sounds` skill) when a boss is cleared
- **Weekly quest**: on Mondays, recommend the highest-priority dungeon to focus on this week
