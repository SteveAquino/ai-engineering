# Global OpenCode Instructions

## Personal AI Engineering Repo

Personal agent skills and role personas live at:

```
REPO_PATH_PLACEHOLDER/.agents/
  skills/   — available globally via ~/.agents/skills symlink
  roles/    — role personas with committed ROLE.md and gitignored state/
  references/local.md  — machine-specific paths (gitignored), including SESSION_DIR
```

## Session Initialization

At the start of every session, write the current session directory to `local.md` in the ai-engineering repo before doing any other work:

```bash
REPO="REPO_PATH_PLACEHOLDER"
if [ -n "$OPENCODE" ]; then
  SESSION_DIR="$HOME/.local/share/opencode/sessions/$OPENCODE_RUN_ID"
  mkdir -p "$SESSION_DIR/checkpoints" "$SESSION_DIR/files"
else
  SESSION_DIR="<path from system context>"
fi
sed -i '' "s|SESSION_DIR=.*|SESSION_DIR=$SESSION_DIR|" "$REPO/.agents/references/local.md"
```

This makes `SESSION_DIR` available to all skills without any provider-specific logic.

## Role Personas

To assume a role persona, invoke the `assume-role` skill. Available roles:

| Role | Purpose |
|---|---|
| `engineering-manager-assistant` | EM assistant: surfaces insights, drafts communications, tracks team health |
| `scheduling-assistant` | Owns the scheduled agent task registry and recurring role inbox processing |
| `skill-builder` | Expert in designing and building agent skills |
| `software-engineering-assistant` | Software engineer assistant: implements tickets, writes tests, opens PRs |

The `engineering-manager-assistant` role is the default EM context. When asked to assume it, read:
- `REPO_PATH_PLACEHOLDER/.agents/roles/engineering-manager-assistant/ROLE.md`
- `REPO_PATH_PLACEHOLDER/.agents/roles/engineering-manager-assistant/state/memories.md`

## Skills

All personal skills are available globally via the `~/.agents/skills` symlink. Invoke any skill by name. For a full index, invoke `personal-skills-index`.

Key skills:
- `assume-role` — load a role persona into the current session
- `dream` — consolidate and prune a role's memories (run periodically)
- `session-reflect` — end-of-session reflection and memory routing
- `remember` — append a durable memory to the active role
- `process-inbox` — process pending role inbox messages
- `prepare-daily-plan` — generate a grounded daily plan from live signals
