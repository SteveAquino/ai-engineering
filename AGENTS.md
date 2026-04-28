# AGENTS.md

This repository is a personal library of portable **agent skills** and **role personas** — not tied to any specific employer. Skills and roles work with any agent runtime that supports skill directories and plain-English skill invocation (e.g., GitHub Copilot CLI).

---

## Directory Structure

```
ai-engineering/
  AGENTS.md                        ← this file
  .agents/
    skills/                        ← personal portable skills
      <skill-name>/
        SKILL.md                   ← skill definition (frontmatter + phased instructions)
  agents/
    <role-name>/
      AGENTS.md                    ← role persona: purpose, goals, communication style
      memories.md                  ← gitignored; persistent accumulated memories
      sessions.md                  ← gitignored; session log with labels
      inbox/                       ← gitignored; messages from other agents
```

---

## Roles

Roles are persistent personas. Assume a role to brief an agent session with specific instructions and accumulated memories.

| Role | Purpose |
|---|---|
| `engineering-manager-assistant` | EM assistant — surfaces insights, drafts communications, tracks team health |
| `scheduling-assistant` | Owns the scheduled agent task registry; manages cron jobs across agents |
| `skill-builder` | Expert in designing and building agent skills |
| `software-engineering-assistant` | Software engineer assistant — implements tickets, writes tests, opens PRs |

**To use:** invoke the `assume-role` skill. The role's `AGENTS.md` and `memories.md` are injected as a structured briefing into the session.

---

## Skills

Skills are composable, phased workflows. Invoke any skill by name.

For a full index with descriptions: invoke the `personal-skills-index` skill.

**Core role skills:**
- `assume-role` — load a role persona into the current session
- `create-role` / `manage-role` / `list-roles` — manage role personas
- `dream` — consolidate and prune a role's memories
- `remember` — append a memory to the active role

**Scheduling skills** (use as `scheduling-assistant`):
- `manage-crons` — CRUD on the cron job registry
- `process-inbox` — process pending messages in any role's inbox
- `schedule-self` — bootstrap the self-scheduling cron entry
- `send-message` — drop a plain-English message into any agent's inbox

**Workflow skills:**
- `brainstorm` — parallel multi-perspective exploration
- `session-reflect` — end-of-session reflection and memory routing
- `create-skill` — scaffold a new skill (personal or employer-specific)
- `weekly-team-retro` — generate a weekly team retrospective
- `osx-sounds` — play audio notifications on macOS

---

## Conventions

- `AGENTS.md` — role instructions (who the agent is, what it cares about, how it communicates)
- `memories.md` — gitignored; durable context accumulated across sessions
- `SKILL.md` — skill definition with YAML frontmatter and phased instructions
- Inbox files are plain-English `.md` files — no schema required; the receiving role interprets them
