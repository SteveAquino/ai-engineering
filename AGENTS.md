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

## Conventions

- Keep committed skills portable and employer-neutral.
- Keep machine-specific paths, team context, and private operational state in ignored role files.
- Do not use `AGENTS.md` for role personas; use `ROLE.md` so it is not confused with ambient repo instructions.
