---
name: assume-role
description: Brief the current agent session with a role persona. Reads the role's ROLE.md and memories.md from the roles directory and injects them as a structured briefing into the conversation. No restart required — works mid-session.
---

# Skill: Assume Role

Use this skill to steer the current session to operate under a specific role persona. The role's instructions and accumulated memories are injected directly into the conversation. No environment variables or restarts required.

## Path Resolution

Read `ROLES_DIR` from `.agents/references/local.md` in this repository before executing any path-dependent commands. If that file does not exist, tell the user to create it using `.agents/references/local.md` as a template (it defines `ROLES_DIR`, `SKILLS_DIR`, and `AGENTS_DIR` as absolute paths for this machine).

---

## Phase 0 — Discover Available Roles

List all role directories:

```bash
ls -d .agents/roles/*/  2>/dev/null | xargs -I{} basename {}
```

If no roles exist:
> "No roles found in `.agents/roles/`. Use the `create-role` skill to define your first role."
Stop here.

---

## Phase 1 — Select Role

If a role name was passed from another skill (e.g., `create-role`), skip selection and use it directly.

Otherwise:

**Use `ask_user`:**
> "Which role do you want to assume?"

Choices: the list of discovered role names from Phase 0.

Store selection as `ROLE_NAME`.

---

## Phase 1b — Select Session (if multiple exist)

Check how many session entries exist for the chosen role:

```bash
# Count data rows (exclude header lines starting with | Date or |---|)
grep -c "^| 20" .agents/roles/<ROLE_NAME>/state/sessions.md 2>/dev/null || echo 0
```

If **0 entries** — skip to Phase 2 (fresh session, no prior context to resume).

If **1 entry** — offer to resume it or start fresh:

**Use `ask_user`:**
> "Found 1 previous session for `<ROLE_NAME>` (`<date>` — `<label>`). What would you like to do?"

Choices: `["Resume previous session", "Start a fresh session"]`

If **2+ entries** — show the full sessions table and let the user pick:

```bash
cat .agents/roles/<ROLE_NAME>/state/sessions.md
```

**Use `ask_user`:**
> "Found multiple sessions for `<ROLE_NAME>`. Which would you like to resume, or start a new one?"

Choices: one entry per row formatted as `"<date> — <label>"`, plus `"Start a fresh session"`.

If the user selects a prior session, note the session ID — surface it at the end of the briefing:
> *To resume: run `/resume <SESSION_ID>` in a new session (Copilot CLI)*

If starting fresh, proceed — a new entry will be logged in Phase 3.

---

## Phase 2 — Load Role Files

```bash
ROLE_DIR=".agents/roles/<ROLE_NAME>"

# Verify the role exists
if [[ ! -d "$ROLE_DIR" ]]; then
  echo "Role '$ROLE_NAME' not found."
  exit 1
fi

cat "$ROLE_DIR/ROLE.md"
echo "---MEMORIES---"
cat "$ROLE_DIR/state/memories.md"
echo "---SKILLS---"
ls "$ROLE_DIR/skills/" 2>/dev/null | grep -v "^$" || echo "(none)"
```

Read both files. If `memories.md` is empty or only contains the `## Recent` header, note that there are no memories yet — omit the memories section from the briefing rather than showing an empty block.

If `skills/` exists, read each `SKILL.md` inside it to understand what role-specific skills are available — they will be listed in the briefing and are active for this session.

---

## Phase 3 — Log Session Entry

Append a new entry to the role's `sessions.md`. Ask for an optional label first:

**Use `ask_user`:**
> "Add a short label for this session? (e.g., 'PROJ-1234 auth refactor', 'weekly planning'). Helps identify it later."

Allow freeform. If the user skips or provides nothing, default to the current date in `YYYY-MM-DD` format (i.e., `$(date +%Y-%m-%d)`).

Append a new row to `.agents/roles/<ROLE_NAME>/state/sessions.md`:

```bash
DATE=$(date +%Y-%m-%d)
# Append row: | date | session-id | label |
echo "| $DATE | <CURRENT_SESSION_ID> | <LABEL> |" >> .agents/roles/<ROLE_NAME>/state/sessions.md
```

The session ID is available from the current session context.

---

## Phase 4 — Check Inbox

Before delivering the briefing, check for pending inbox messages:

```python
import os, glob
ROLE_NAME = "<ROLE_NAME>"
inbox = os.path.expanduser(f".agents/roles/{ROLE_NAME}/state/inbox")
files = sorted(glob.glob(os.path.join(inbox, "*.md"))) if os.path.exists(inbox) else []
print(f"Pending inbox messages: {len(files)}")
for f in files:
    print(f"  {os.path.basename(f)}")
```

If messages are found, include the **📬 Pending Inbox** section in the briefing. If empty, omit it.

---

## Phase 5 — Deliver the Briefing

Output the full role briefing as a structured message:

---

**🎭 Role Briefing: `<ROLE_NAME>`**

I am now operating as the **`<ROLE_NAME>`** persona.

### Instructions

<full contents of ROLE.md>

### Active Memories

<full contents of memories.md — omit this section if memories.md is empty>

### 🛠 Role Skills

<list of role-specific skills found in `.agents/roles/<ROLE_NAME>/skills/`, each with its one-line description from frontmatter — omit this section if no skills directory exists>

These skills are active for this session and can be invoked by name.

### 📬 Pending Inbox (`<N> message(s)`)

<list of pending inbox filenames — omit this entire section if inbox is empty>

> Run `process-inbox` to handle these.

---

*Role context loaded. I'll operate under these instructions for this session.*
*To record a new memory: invoke `remember`*
*To switch roles: invoke `assume-role` again*
*To update role instructions: invoke `manage-role`*

---

After delivering the briefing, begin responding in character as the role — applying the persona's communication style, priorities, and goals from this point forward in the session.

---

## Reference

- Roles directory: `.agents/roles/`
- To create a new role: invoke `create-role`
- To view all roles and session history: invoke `list-roles`
- To re-brief after `/compact`: invoke `assume-role` again
