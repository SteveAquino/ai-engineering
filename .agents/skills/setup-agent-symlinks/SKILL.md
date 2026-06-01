---
name: setup-agent-symlinks
description: Bootstrap global agent/skill symlinks on a new machine. Creates ~/.agents/skills, ~/.claude/skills, and ~/.copilot/agents/ entries pointing at this repo, then installs tool-specific config files (e.g. ~/.config/opencode/AGENTS.md). Run once after cloning.
---

# Skill: setup-agent-symlinks

Wire this repo's skills and roles into every agent tool on this machine. Run once after cloning, or to repair a broken setup.

Covers: OpenCode, Codex, Claude Code, GitHub Copilot CLI / VS Code.

---

## Phase 0 — Detect Repo Location

```bash
REPO=$(git rev-parse --show-toplevel 2>/dev/null)
echo "Repo: $REPO"
```

Confirm with the user if the detected path looks wrong.

---

## Phase 1 — Universal Skills Symlink (`~/.agents/skills`)

Used by: OpenCode, Codex, and any tool that respects the `.agents/skills/` convention.

```bash
mkdir -p "$HOME/.agents"

if [ -L "$HOME/.agents/skills" ]; then
  echo "Existing: $(readlink "$HOME/.agents/skills")"
fi

ln -sfn "$REPO/.agents/skills" "$HOME/.agents/skills"
echo "~/.agents/skills → $REPO/.agents/skills"
```

---

## Phase 2 — Claude Code Skills Symlink (`~/.claude/skills`)

Used by: Claude Code.

```bash
mkdir -p "$HOME/.claude"

if [ -L "$HOME/.claude/skills" ]; then
  echo "Existing: $(readlink "$HOME/.claude/skills")"
fi

ln -sfn "$REPO/.agents/skills" "$HOME/.claude/skills"
echo "~/.claude/skills → $REPO/.agents/skills"
```

---

## Phase 3 — VS Code / Copilot Agent Symlinks (`~/.copilot/agents/`)

Used by: VS Code Copilot Chat (surfaces roles as named agents).

```bash
AGENTS_DIR="$HOME/.copilot/agents"
mkdir -p "$AGENTS_DIR"

for role in $(ls "$REPO/.agents/roles/"); do
  target="$REPO/.agents/roles/$role/ROLE.md"
  link="$AGENTS_DIR/$role.agent.md"
  [ -f "$target" ] || continue
  ln -sf "$target" "$link"
  echo "$link → $target"
done
```

---

## Phase 4 — OpenCode Global AGENTS.md

Used by: OpenCode only. Provides session bootstrap instructions and role context.

**Ask the user:**
> "Install `~/.config/opencode/AGENTS.md` from the repo template?"

Choices: `["Yes — install/overwrite", "Skip"]`

If yes:

```bash
TEMPLATE="$REPO/.agents/references/opencode-agents-template.md"
DEST="$HOME/.config/opencode/AGENTS.md"
mkdir -p "$HOME/.config/opencode"
sed "s|REPO_PATH_PLACEHOLDER|$REPO|g" "$TEMPLATE" > "$DEST"
echo "Written: $DEST"
```

---

## Phase 5 — local.md

Ensure `.agents/references/local.md` exists with correct paths for this machine:

```bash
LOCAL="$REPO/.agents/references/local.md"

if [ ! -f "$LOCAL" ]; then
  cat > "$LOCAL" << EOF
# Local Machine Paths

This file is git-ignored. Create it on each machine after cloning.

\`SESSION_DIR\` is overwritten automatically at the start of every session — do not edit it manually.

## Path Configuration

\`\`\`
AGENTS_DIR=$REPO/.agents
ROLES_DIR=$REPO/.agents/roles
SKILLS_DIR=$REPO/.agents/skills
SESSION_DIR=
\`\`\`
EOF
  echo "Created: $LOCAL"
else
  echo "local.md already exists — verify paths are correct for this machine:"
  cat "$LOCAL"
fi
```

---

## Phase 6 — Verify

```bash
echo "=== ~/.agents/skills ==="
ls -la "$HOME/.agents/skills" | head -3

echo ""
echo "=== ~/.claude/skills ==="
ls -la "$HOME/.claude/skills" 2>/dev/null | head -3 || echo "(not set)"

echo ""
echo "=== ~/.copilot/agents/ ==="
ls "$HOME/.copilot/agents/"*.agent.md 2>/dev/null | head -5 || echo "(not set)"

echo ""
echo "=== OpenCode AGENTS.md ==="
[ -f "$HOME/.config/opencode/AGENTS.md" ] && echo "present" || echo "(not installed)"

echo ""
echo "=== local.md ==="
cat "$REPO/.agents/references/local.md"
```

---

## Reference

- Skills discovery: `~/.agents/skills/` (OpenCode, Codex), `~/.claude/skills/` (Claude Code)
- Role agent entries: `~/.copilot/agents/*.agent.md` (VS Code)
- Global OpenCode instructions: `~/.config/opencode/AGENTS.md`
- Machine paths: `.agents/references/local.md` (gitignored)
- Template: `.agents/references/opencode-agents-template.md`
- Full setup docs: `README.md` → Tool Setup
