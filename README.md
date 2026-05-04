# ai-engineering

Personal AI agent skills and role personas.

This repository is a portable library for agent workflows that should follow me across projects and machines. It is intentionally not tied to a specific employer. Employer or machine-specific context belongs in ignored local state, not committed skill files.

## Structure

The canonical structure is a single `.agents/` namespace:

```text
ai-engineering/
  AGENTS.md
  .agents/
    skills/
      <skill-name>/
        SKILL.md          # skill definition — always at root, always committed
        docs/             # committed supporting docs: rubrics, templates, examples
        references/       # git-ignored team/machine-specific overlays
    roles/
      <role-name>/
        ROLE.md
        memories.md
        sessions.md
        inbox/
        logs/
        skills/           # role-specific skills, auto-loaded by assume-role
          <skill-name>/
            SKILL.md
```

### Skill directory layout

Every skill directory has exactly one `SKILL.md` at its root. Supporting artifacts use semantic subdirectories to prevent clutter:

| Path | Purpose | Committed? |
|------|---------|------------|
| `SKILL.md` | Skill definition and phases | ✅ Yes |
| `docs/` | Rubrics, templates, reference docs, examples | ✅ Yes |
| `references/` | Team- or machine-specific overlays (org names, project keys, local paths) | ❌ No (git-ignored) |

**Rule:** Never place additional `.md` files directly beside `SKILL.md`. If a skill needs a supporting document, it goes in `docs/`. If it needs team context, it goes in `references/`.

## Why This Shape

Codex and the broader agent-skills ecosystem are converging on `.agents/skills/<skill>/SKILL.md` as the low-config, repo-local discovery path for reusable skills. Keeping skills there means Codex can discover repo skills without per-repo configuration, and user-global discovery can be handled with one junction or symlink.

Roles/personas are first-class in this repo, but they are not the same thing as skills:

- A skill is an invocable workflow: "do this task."
- A role is a persistent operating profile: "think and communicate this way."
- `AGENTS.md` is ambient repo guidance for Codex, so role personas use `ROLE.md` instead.

This keeps the semantics clear:

- `.agents/skills` is the standards-based discovery surface.
- `.agents/roles` is this repo's portable persona registry.
- ignored role state remains local to each machine.

## Local Reference Strategy

Committed skills and roles should stay portable. Machine-specific knowledge belongs in gitignored role state beside each role:

```text
.agents/roles/<role-name>/
  ROLE.md        # committed persona
  memories.md    # ignored local references and durable context
  sessions.md    # ignored local session log
  inbox/         # ignored local messages
  logs/          # ignored local runtime logs
```

Use `memories.md` to adapt the same committed role and skills to a specific machine. Good local memories include:

- local workspace roots and adjacent repo maps
- project-specific skill paths that should be treated as references, not copied globally
- work-vs-personal skill variants and naming collision notes
- local validation commands, screenshots locations, or dev-server habits
- private team, employer, or client context that should never be committed

This lets the portable skills stay generic while still giving the agent useful local bearings. For example, the committed `create-skill` workflow can say "classify placement first", while `skill-builder/memories.md` can record that a work machine already has a similar `spec-driven-development` skill and that a personal variant needs a collision review before being added.

When a local reference becomes broadly useful and employer-neutral, promote it into a committed skill or role update. Until then, keep it in ignored role memory.

## First-Time Setup: Local Path Configuration

After cloning, create the git-ignored path config file that role-related skills read to resolve absolute paths on this machine:

```bash
# macOS/Linux
REPO="$HOME/path/to/ai-engineering"
mkdir -p "$REPO/.agents/references"
cat > "$REPO/.agents/references/local.md" << 'EOF'
# Local Machine Paths
AGENTS_DIR=/absolute/path/to/ai-engineering/.agents
ROLES_DIR=/absolute/path/to/ai-engineering/.agents/roles
SKILLS_DIR=/absolute/path/to/ai-engineering/.agents/skills
EOF
```

Replace `/absolute/path/to/ai-engineering` with the actual clone location. This file is gitignored — every machine needs its own copy.

Skills such as `assume-role`, `create-role`, `list-roles`, `manage-role`, `remember`, and `dream` read `ROLES_DIR` from this file before executing path-dependent commands.

---



### Codex

Codex discovers user-global skills from `$HOME/.agents/skills`. Expose this repo's skills through a single link to `.agents/skills`.

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\.agents"
New-Item -ItemType Junction `
  -Path "$HOME\.agents\skills" `
  -Target "C:\Users\aquin\Projects\ai-engineering\.agents\skills"
```

macOS/Linux:

```bash
mkdir -p "$HOME/.agents"
ln -sfn "$HOME/path/to/ai-engineering/.agents/skills" "$HOME/.agents/skills"
```

After creating or updating the junction, restart Codex. Skills should appear in `/skills` and be invokable by name with `$<skill-name>`.

If you use role personas from outside this repo, expose roles the same way:

Windows PowerShell:

```powershell
New-Item -ItemType Junction `
  -Path "$HOME\.agents\roles" `
  -Target "C:\Users\aquin\Projects\ai-engineering\.agents\roles"
```

macOS/Linux:

```bash
ln -sfn "$HOME/path/to/ai-engineering/.agents/roles" "$HOME/.agents/roles"
```

### GitHub Copilot CLI

For tools that support explicit skill directories, point them at the canonical skills directory:

```json
"skillDirectories": [
  "/path/to/ai-engineering/.agents/skills"
]
```

Copilot CLI also supports skill directory configuration through `COPILOT_SKILLS_DIRS`:

```bash
export COPILOT_SKILLS_DIRS="/path/to/ai-engineering/.agents/skills"
```

Use `assume-role` to load role personas from `.agents/roles`.

### Claude Code

Claude Code uses `~/.claude/skills/<skill-name>/SKILL.md` for user-global skills. Link this repo's canonical skills directory there.

macOS/Linux:

```bash
mkdir -p "$HOME/.claude"
ln -sfn "$HOME/path/to/ai-engineering/.agents/skills" "$HOME/.claude/skills"
```

Windows PowerShell:

```powershell
New-Item -ItemType Directory -Force "$HOME\.claude"
New-Item -ItemType Junction `
  -Path "$HOME\.claude\skills" `
  -Target "C:\Users\aquin\Projects\ai-engineering\.agents\skills"
```

Use `assume-role` to load role personas from `.agents/roles`.

## Skills

Skills are discrete, invocable workflows. Each skill lives in its own directory with a `SKILL.md` file containing frontmatter and phased instructions.

Examples:

```text
.agents/skills/
  assume-role/SKILL.md
  create-role/SKILL.md
  session-reflect/SKILL.md
```

For a full index with descriptions, invoke `personal-skills-index`.

To add a skill, invoke `create-skill`. Do not hand-create skill directories unless you are repairing the library or deliberately bypassing the workflow.

## Roles

Roles are persistent personas. A role briefs an agent session with a specific purpose, standing goals, communication style, and accumulated memories.

Examples:

```text
.agents/roles/
  skill-builder/
    ROLE.md
    memories.md
    sessions.md
  software-engineering-assistant/
    ROLE.md
    memories.md
    sessions.md
```

To use a role, invoke `assume-role`.

## Adding A Skill

Invoke `create-skill`. It classifies whether the request is a portable personal skill, a project/employer skill, or actually a role, then scaffolds the correct `SKILL.md` and updates the skills index.

## Adding A Role

Invoke `create-role`. It scaffolds the role's `ROLE.md` and initializes the ignored local state files that `assume-role`, `remember`, and `dream` use.
