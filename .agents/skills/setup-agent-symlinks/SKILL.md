---
name: setup-agent-symlinks
description: Bootstrap global agent/skill symlinks on a new machine. Creates individual symlinks in ~/.agents/skills/ pointing at this personal repo, then wires Claude Code and VS Code Copilot agent entries. Run once after cloning.
---

# Skill: setup-agent-symlinks

Wire this personal repo's skills and roles into every agent tool on this machine.
Run once after cloning, or to repair a broken setup.

Covers: OpenCode, Claude Code, GitHub Copilot CLI / VS Code.

---

## Phase 0 — Detect Repo Location

```bash
REPO=$(git rev-parse --show-toplevel 2>/dev/null)
echo "Repo: $REPO"
```

Confirm with the user if the detected path looks wrong.

---

## Phase 1 — Skill Symlinks (`~/.agents/skills/`)

Each skill gets its own symlink so personal skills and employer repo skills coexist
without collision. `~/.agents/skills/` must be a real directory — not a whole-dir symlink.

First, convert if needed:

```bash
if [ -L "$HOME/.agents/skills" ]; then
  OLD_TARGET=$(readlink "$HOME/.agents/skills")
  echo "~/.agents/skills is a whole-dir symlink → $OLD_TARGET"
  echo "Converting to a real directory and re-linking existing skills individually..."
  rm "$HOME/.agents/skills"
  mkdir -p "$HOME/.agents/skills"

  for skill_dir in "$OLD_TARGET"/*/; do
    name=$(basename "$skill_dir")
    [ -d "$skill_dir" ] && [ ! -L "$skill_dir" ] && ln -sfn "$skill_dir" "$HOME/.agents/skills/$name"
  done
else
  mkdir -p "$HOME/.agents/skills"
fi
```

Then symlink each skill from this repo:

```bash
for skill_dir in "$REPO/.agents/skills"/*/; do
  name=$(basename "$skill_dir")
  link="$HOME/.agents/skills/$name"

  # If a real directory exists at the target, ln -sfn will nest the symlink
  # inside it instead of replacing it. Remove the directory first.
  if [ -d "$link" ] && [ ! -L "$link" ]; then
    echo "removing existing real directory: $name"
    rm -rf "$link"
  fi

  [ -L "$link" ] && echo "updating: $name" || echo "creating: $name"
  ln -sfn "$skill_dir" "$link"
done

echo ""
echo "Personal skill symlinks in ~/.agents/skills/:"
ls -la "$HOME/.agents/skills/" | grep "$REPO"
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

## Phase 4 — local.md

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

## Phase 5 — Verify

```bash
echo "=== ~/.agents/skills (personal symlinks) ==="
ls -la "$HOME/.agents/skills/" | grep "$REPO" | wc -l | xargs echo "personal skill symlinks:"

echo ""
echo "=== ~/.claude/skills ==="
ls -la "$HOME/.claude/skills" 2>/dev/null | head -3 || echo "(not set)"

echo ""
echo "=== ~/.copilot/agents/ ==="
ls "$HOME/.copilot/agents/"*.agent.md 2>/dev/null | head -5 || echo "(not set)"

echo ""
echo "=== local.md ==="
cat "$REPO/.agents/references/local.md"
```

---

## Reference

- Skills: `~/.agents/skills/` — individual symlinks per skill (personal + carrum coexist)
- Claude Code skills: `~/.claude/skills/` → this repo's skills dir
- Role agents: `~/.copilot/agents/*.agent.md`
- Machine paths: `.agents/references/local.md` (gitignored)
