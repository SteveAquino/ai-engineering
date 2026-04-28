---
name: personal-skills-index
description: Index of personal Copilot CLI skills not tied to any specific employer. Use this when asked what personal skills are available.
---

# Personal Copilot CLI Skills

Personal, portable skills that follow me across projects and employers.
These live in `~/work/personal/ai-engineering/` and are registered globally via `skillDirectories` in `~/.copilot/settings.json`.

## Available Skills

| Skill | Description |
|---|---|
| [`brainstorm/SKILL.md`](../brainstorm/SKILL.md) | Spawns parallel subagents to explore a problem from multiple perspectives, iterates through configurable rounds toward consensus, and saves a structured summary to the session-state folder. |
| [`dream/SKILL.md`](../dream/SKILL.md) | Consolidate and prune a role's memories by reviewing recent session checkpoints. Classifies each memory as durable or transient, elevates new insights from sessions, and produces a refined `memories.md` for human review before writing. |
| [`assume-role/SKILL.md`](../assume-role/SKILL.md) | Brief the current session with a role persona. Reads `instructions.md` and `memories.md` from `~/work/personal/ai-engineering/agents/<name>/` and injects them as a structured briefing. No restart required — works mid-session. |
| [`create-role/SKILL.md`](../create-role/SKILL.md) | Interactively define a new role persona. Gathers name, purpose, goals, and communication preferences, then scaffolds the role directory with `instructions.md` and `memories.md`. |
| [`create-skill/SKILL.md`](../create-skill/SKILL.md) | Meta-skill for creating a new Copilot CLI skill. Classifies the skill as Carrum Health-specific or personal/portable, then scaffolds it in the right place — a git worktree + draft PR for Carrum skills, or the personal skills library for portable ones. |
| [`list-roles/SKILL.md`](../list-roles/SKILL.md) | Show all available role personas in `~/work/personal/ai-engineering/agents/`, their purpose, memory entry count, and saved session IDs for `/resume`. |
| [`manage-role/SKILL.md`](../manage-role/SKILL.md) | Maintain an existing role persona — view or edit instructions, view or consolidate memories, rename, or delete a role. |
| [`osx-sounds/SKILL.md`](../osx-sounds/SKILL.md) | Play audio notifications from the macOS command line. Covers built-in system sounds, `afplay`, `say`, and `osascript` — including how to find sound files and success/failure cue patterns. |
| [`playwright-browser-test/SKILL.md`](../playwright-browser-test/SKILL.md) | Write and run an ad-hoc Playwright test against any URL — headed or headless. Captures screenshots at key steps and saves them to a results folder. |
| [`protocol-compliance-review/SKILL.md`](../protocol-compliance-review/SKILL.md) | Given a library/gem and a protocol spec URL, produce a structured compliance gap report covering wire format, required operations, field shapes, error codes, and test suite blind spots — with a prioritized fix list. |
| [`playwright-evaluate-screenshots/SKILL.md`](../playwright-evaluate-screenshots/SKILL.md) | Evaluate a folder of Playwright screenshots using vision to determine whether each step succeeded or failed. Produces a structured pass/fail report with observations per screenshot. |
| [`playwright-setup/SKILL.md`](../playwright-setup/SKILL.md) | Set up Playwright in any project directory — installs the npm package, scaffolds a scripts directory, and installs browser binaries. Run once before using playwright-browser-test. |
| [`remember/SKILL.md`](../remember/SKILL.md) | Append a timestamped memory entry to a role's `memories.md`. Keeps role context durable across sessions and `/compact` operations. Offers consolidation when entries get long. |
| [`session-reflect/SKILL.md`](../session-reflect/SKILL.md) | At the end of a work session, generate a structured reflection document covering what was built, friction points, novel patterns, memories to persist, and skills worth codifying. Routes findings to role memories or skill proposal files. |
| [`weekly-team-retro/SKILL.md`](../weekly-team-retro/SKILL.md) | Generates a weekly engineering team retrospective. Fetches PR activity and resolved tickets for the week, collects qualitative EM notes per engineer via `ask_user`, and saves a persistent markdown file to `~/work/personal/ai-engineering/agents/engineering-manager-assistant/weekly-retros/`. |

---

## Adding a New Personal Skill

```bash
mkdir -p ~/work/personal/ai-engineering/.agents/skills/<skill-name>
# Create SKILL.md with frontmatter (name, description) + content
# Copilot will discover it automatically — no config change needed
```

Frontmatter template:
```markdown
---
name: skill-name
description: One sentence describing when to invoke this skill.
---
```
