---
name: personal-skills-index
description: Index of personal agent skills not tied to any specific employer. Use this when asked what personal skills are available.
---

# Personal Agent Skills

Personal, portable skills that follow me across projects and employers.
These live in `~/work/personal/ai-engineering/` and are registered globally via `skillDirectories` in the agent config (Copilot CLI: `~/.copilot/settings.json`).

## Available Skills

| Skill | Description |
|---|---|
| [`brainstorm/SKILL.md`](../brainstorm/SKILL.md) | Spawns parallel subagents to explore a problem from multiple perspectives, iterates through configurable rounds toward consensus, and saves a structured summary to the session-state folder. |
| [`dream/SKILL.md`](../dream/SKILL.md) | Consolidate and prune a role's memories by reviewing recent session checkpoints. Classifies each memory as durable or transient, elevates new insights from sessions, and produces a refined `memories.md` for human review before writing. |
| [`assume-role/SKILL.md`](../assume-role/SKILL.md) | Brief the current session with a role persona. Reads `AGENTS.md` and `memories.md` from `~/work/personal/ai-engineering/agents/<name>/` and injects them as a structured briefing. No restart required — works mid-session. |
| [`create-role/SKILL.md`](../create-role/SKILL.md) | Interactively define a new role persona. Gathers name, purpose, goals, and communication preferences, then scaffolds the role directory with `AGENTS.md` and `memories.md`. |
| [`create-skill/SKILL.md`](../create-skill/SKILL.md) | Meta-skill for creating a new agent skill. Classifies the skill as employer-specific or personal/portable, then scaffolds it in the right place — a git worktree + draft PR for employer skills, or the personal skills library for portable ones. |
| [`list-roles/SKILL.md`](../list-roles/SKILL.md) | Show all available role personas in `~/work/personal/ai-engineering/agents/`, their purpose, memory entry count, and saved session IDs for `/resume`. |
| [`manage-schedule/SKILL.md`](../manage-schedule/SKILL.md) | Review and edit the scheduling-assistant's cron job registry (`crontab.json`), then sync to system crontab. Only invoke as the `scheduling-assistant` persona. |
| [`manage-role/SKILL.md`](../manage-role/SKILL.md) | Maintain an existing role persona — view or edit instructions, view or consolidate memories, rename, or delete a role. |
| [`osx-sounds/SKILL.md`](../osx-sounds/SKILL.md) | Play audio notifications from the macOS command line. Covers built-in system sounds, `afplay`, `say`, and `osascript` — including how to find sound files and success/failure cue patterns. |
| [`prepare-daily-plan/SKILL.md`](../prepare-daily-plan/SKILL.md) | Gathers context from available tools (gh, acli, etc.) to synthesize a prioritized daily work plan for the engineering manager, then writes it to the EM assistant's inbox. Runs autonomously — no user input required. |
| [`process-inbox/SKILL.md`](../process-inbox/SKILL.md) | Process pending messages in the current role's inbox. Reads each plain-English `.md` file, uses the role's `AGENTS.md` to interpret intent, applies the appropriate action, and deletes the file. Works for any role. |
| [`remember/SKILL.md`](../remember/SKILL.md) | Append a timestamped memory entry to a role's `memories.md`. Keeps role context durable across sessions and `/compact` operations. Offers consolidation when entries get long. |
| [`send-message/SKILL.md`](../send-message/SKILL.md) | Send a plain-English message to any agent's inbox. No schema required — the receiving agent interprets the message using its own `AGENTS.md`. |
| [`schedule-self/SKILL.md`](../schedule-self/SKILL.md) | Install or update the system cron entry that automatically runs the scheduling-assistant on a recurring schedule to process its inbox. Run once to bootstrap the scheduler. |
| [`session-reflect/SKILL.md`](../session-reflect/SKILL.md) | At the end of a work session, generate a structured reflection document covering what was built, friction points, novel patterns, memories to persist, and skills worth codifying. Routes findings to role memories or skill proposal files. |
| [`weekly-team-retro/SKILL.md`](../weekly-team-retro/SKILL.md) | Generates a weekly engineering team retrospective. Fetches PR activity and resolved tickets for the week, collects qualitative EM notes per engineer via `ask_user`, and saves a persistent markdown file to `~/work/personal/ai-engineering/agents/engineering-manager-assistant/weekly-retros/`. |

---

## Adding a New Personal Skill

```bash
mkdir -p ~/work/personal/ai-engineering/skills/<skill-name>
# Create SKILL.md with frontmatter (name, description) + content
# The agent will discover it automatically — no config change needed
```

Frontmatter template:
```markdown
---
name: skill-name
description: One sentence describing when to invoke this skill.
---
```
