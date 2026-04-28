---
name: list-roles
description: Show all available role personas in ~/work/personal/ai-engineering/agents/, their purpose, and saved session IDs for resuming. Quick overview of the role system.
---

# Skill: List Roles

Use this skill to see all available role personas and their current state.

---

## Phase 0 — Discover Roles

```bash
ls -d ~/work/personal/ai-engineering/agents/*/ 2>/dev/null | xargs -I{} basename {}
```

If no roles exist:
> "No roles found in `~/work/personal/ai-engineering/agents/`. Use the `create-role` skill to define your first role."
Stop here.

---

## Phase 1 — Gather Details

For each discovered role, read:

```bash
ROLE_DIR="$HOME/work/personal/ai-engineering/agents/<ROLE_NAME>"

# Purpose: first non-header, non-empty line after "## Purpose" in AGENTS.md
PURPOSE=$(awk '/^## Purpose/{found=1; next} found && NF{print; exit}' "$ROLE_DIR/AGENTS.md" 2>/dev/null || echo "(no instructions)")

# Most recent session: last data row in sessions.md
LAST_SESSION=$(grep "^| 20" "$ROLE_DIR/sessions.md" 2>/dev/null | tail -1)
SESSION_ID=$(echo "$LAST_SESSION" | awk -F'|' '{print $3}' | tr -d ' ')
SESSION_LABEL=$(echo "$LAST_SESSION" | awk -F'|' '{print $4}' | sed 's/^ *//;s/ *$//')
SESSION_COUNT=$(grep -c "^| 20" "$ROLE_DIR/sessions.md" 2>/dev/null || echo 0)

# Memory entry count
MEMORY_COUNT=$(grep -c "^### " "$ROLE_DIR/memories.md" 2>/dev/null || echo 0)
```

---

## Phase 2 — Display

Present a clean summary table. For each role:

```
─────────────────────────────────────────────────
Role:     architect
Purpose:  Technical architecture advisor focused on system design and trade-offs
Memories: 7 entries
Sessions: 3 total  →  most recent: 2026-04-09 — PROJ-1234 auth refactor
          /resume abc1234
─────────────────────────────────────────────────
Role:     eng-lead
Purpose:  Engineering leadership and team coordination
Memories: 3 entries
Sessions: 1 total  →  2026-04-01 — (no label)
          /resume def456
─────────────────────────────────────────────────
Role:     staff-engineer
Purpose:  Staff engineer context and best practices
Memories: 0 entries
Sessions: none
─────────────────────────────────────────────────
```

After the list, show available actions:

```
To assume a role:      invoke assume-role
To create a new role:  invoke create-role
To manage a role:      invoke manage-role
```

---

## Reference

- Roles directory: `~/work/personal/ai-engineering/agents/`
- Sessions are saved automatically when you invoke `assume-role`
