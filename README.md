# ai-engineering

Personal AI agent skills and role personas.

---

## Skills

Skills are discrete, invocable instruction sets that tell an agent how to perform a specific task — from start to finish. Each skill lives in its own directory with a single `SKILL.md` file.

```
.agents/skills/
  assume-role/SKILL.md
  create-role/SKILL.md
  weekly-team-retro/SKILL.md
  ...
```

Register the directory with your agent so it can discover skills. For **Copilot CLI**, add to `skillDirectories` in `~/.copilot/settings.json`:

```json
"skillDirectories": [
  "/Users/<you>/work/personal/ai-engineering/.agents/skills"
]
```

See [`personal-skills-index`](.agents/skills/personal-skills-index/SKILL.md) for the full list of available skills.

---

## Agent Personas

A persona is a persistent role that can be loaded into any agent session to give it a specific identity, goals, and communication style. Personas live in `agents/<name>/`.

```
agents/
  engineering-manager-assistant/
    instructions.md   ← versioned: purpose, goals, communication style
    memories.md       ← gitignored: accumulated session learnings
    sessions.md       ← gitignored: session history log
  skill-builder/
    instructions.md
    memories.md
    sessions.md
  ...
```

### `instructions.md` — versioned, portable

Defines the role's **purpose**, **standing goals**, and **communication style**. This is the stable identity of the persona — it changes infrequently and is committed to the repo.

Instructions are written as agent-agnostic principles. Environment-specific details (file paths, org names, tool locations) live in `memories.md` instead.

### `memories.md` — persistent, gitignored

Accumulates **session learnings** over time: patterns discovered, conventions observed, decisions made, gotchas hit. This is what makes a persona feel "experienced" — it carries forward knowledge across sessions.

Memories are **gitignored** because they are personal and may contain employer-specific details. They persist locally between sessions but are never committed.

Add memories via the `remember` skill. Consolidate and prune stale ones via the `dream` skill.

### `sessions.md` — session history, gitignored

An append-only log of every session the persona was loaded for: date, session ID, and label. Used by `assume-role` to offer resuming a prior session. Also gitignored.

---

## Loading a Persona

Invoke the `assume-role` skill at the start of a session. It will:

1. List available personas and let you pick one
2. Offer to resume a prior session or start fresh
3. Read `instructions.md` and `memories.md`
4. Inject both as a structured briefing into the conversation
5. Log the session to `sessions.md`

The agent then operates under that persona for the rest of the session — applying its goals, style, and accumulated knowledge.

To create a new persona: invoke `create-role`.
To update a persona's instructions or memories: invoke `manage-role`.

---

## Adding a Skill

```bash
mkdir -p .agents/skills/<skill-name>
# Write .agents/skills/<skill-name>/SKILL.md
# Add a row to .agents/skills/personal-skills-index/SKILL.md
```

Or invoke the `create-skill` skill to scaffold it interactively.
