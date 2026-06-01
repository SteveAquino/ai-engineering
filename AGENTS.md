# AGENTS.md

This repository is a personal library of portable **agent skills** and **role personas**. It is not tied to any specific employer.

## Directory Structure

```text
ai-engineering/
  AGENTS.md
  .agents/
    skills/
      <skill-name>/
        SKILL.md
    roles/
      <role-name>/
        ROLE.md
        memories.md
        sessions.md
        inbox/
        logs/
```

## Concepts

- `AGENTS.md` is ambient repository guidance for Codex and other coding agents.
- `SKILL.md` defines an invocable workflow under `.agents/skills/<skill-name>/`.
- `ROLE.md` defines a persistent persona under `.agents/roles/<role-name>/`.
- `memories.md`, `sessions.md`, `inbox/`, `logs/`, and generated reports are local role state and are gitignored.

## Roles

Roles are persistent personas. Use `assume-role` to brief an agent session with a role's `ROLE.md` and local `memories.md`.

| Role | Purpose |
|---|---|
| `engineering-manager-assistant` | EM assistant: surfaces insights, drafts communications, tracks team health |
| `scheduling-assistant` | Owns the scheduled agent task registry and recurring role inbox processing |
| `skill-builder` | Expert in designing and building agent skills |
| `software-engineering-assistant` | Software engineer assistant: implements tickets, writes tests, opens PRs |

## Skills

Skills are composable, phased workflows. For the full index with descriptions, invoke `personal-skills-index`.

Core role skills:

- `assume-role` - load a role persona into the current session
- `create-role`, `manage-role`, `list-roles` - manage role personas
- `remember` - append a memory to the active role
- `dream` - consolidate and prune a role's memories

Scheduling skills:

- `manage-schedule` - CRUD on the scheduling assistant registry
- `process-inbox` - process pending role inbox messages
- `schedule-self` - bootstrap scheduler self-checking
- `send-message` - drop a plain-English message into any role inbox

Workflow skills:

- `brainstorm` - parallel multi-perspective exploration
- `session-reflect` - end-of-session reflection and memory routing
- `create-skill` - scaffold a new skill
- `weekly-team-retro` - generate a weekly team retrospective

## Tool Setup

Run `setup-agent-symlinks` once after cloning on a new machine. It creates:

- `~/.agents/skills` → `.agents/skills` (OpenCode, Codex)
- `~/.claude/skills` → `.agents/skills` (Claude Code)
- `~/.copilot/agents/*.agent.md` → `.agents/roles/*/ROLE.md` (VS Code)
- `~/.config/opencode/AGENTS.md` from the repo template (OpenCode session bootstrap)

See `README.md` → Tool Setup for full details and manual instructions.

## VS Code Agent Integration

Each `ROLE.md` doubles as a VS Code agent definition. It includes a YAML frontmatter block (tools, model, handoffs) that VS Code reads to surface the role as a named agent in the chat UI.

VS Code looks for agent definitions in `~/.copilot/agents/*.agent.md`. Rather than maintaining a separate copy, each entry is a symlink back to the canonical `ROLE.md` in this repo:

```
~/.copilot/agents/<role>.agent.md  →  <repo>/.agents/roles/<role>/ROLE.md
```

### Setting up symlinks on a new machine

Run once after cloning the repo:

```bash
REPO="/path/to/ai-engineering"
AGENTS_DIR="$HOME/.copilot/agents"
mkdir -p "$AGENTS_DIR"

for role in engineering-manager-assistant scheduling-assistant skill-builder software-engineering-assistant; do
  ln -sf "$REPO/.agents/roles/$role/ROLE.md" "$AGENTS_DIR/$role.agent.md"
done
```

### Adding a new role

1. Scaffold the role with `create-role` (or manually under `.agents/roles/<name>/`)
2. Add VS Code frontmatter to `ROLE.md` — name, description, tools, model
3. Add the symlink: `ln -sf "$REPO/.agents/roles/<name>/ROLE.md" "$HOME/.copilot/agents/<name>.agent.md"`
4. Add a row to the Roles table above

## Conventions

- Keep committed skills portable and employer-neutral.
- Keep machine-specific paths, team context, and private operational state in ignored role files.
- Do not use `AGENTS.md` for role personas; use `ROLE.md` so it is not confused with ambient repo instructions.
- `ROLE.md` is the single source of truth — the VS Code agent entry is always a symlink, never a copy.
