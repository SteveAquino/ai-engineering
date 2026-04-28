# ai-engineering

Personal AI agent skills and role personas.

## Skills

Skills live at `.agents/skills/*/SKILL.md`. Add the directory to `skillDirectories`
in `~/.copilot/settings.json`:

```json
"skillDirectories": [
  "/Users/<you>/work/personal/ai-engineering/.agents/skills"
]
```

## Agent Personas

Role instruction files live at `agents/<name>/instructions.md`. Memories and sessions
are private, gitignored, and managed locally via the `assume-role`, `remember`, and
`dream` skills.

To use: invoke the `assume-role` Copilot CLI skill.
