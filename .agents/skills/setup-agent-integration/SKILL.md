---
name: setup-agent-integration
description: Wire this repo's skills into OpenCode, VS Code Copilot, and Copilot CLI on a new machine using symlinks. Actually writes config files and creates symlinks — run once after cloning.
---

# Skill: Setup Agent Integration

Wire this repo's skills into your agent tools so they are available in every session,
regardless of where the repo is cloned. Covers OpenCode, VS Code Copilot, and Copilot CLI.

**Core strategy:** create symlinks in stable `~/` locations that tools already discover
automatically. Tool configs point at those stable paths — the repo can be cloned anywhere
and configs never need to change.

Run once after cloning, or to repair a broken setup.

---

## Phase 0 — Detect Repo Location

```bash
REPO=$(git rev-parse --show-toplevel 2>/dev/null)
echo "Repo root: $REPO"
```

Confirm with the user before proceeding if the path looks wrong.

---

## Phase 1 — Skill Symlinks (`~/.agents/skills/`)

Symlink each skill individually so personal and repo skills coexist without collision.

```bash
mkdir -p "$HOME/.agents/skills"

for skill_dir in "$REPO/.agents/skills"/*/; do
  name=$(basename "$skill_dir")
  link="$HOME/.agents/skills/$name"
  [ -L "$link" ] && echo "updating: $name" || echo "creating: $name"
  ln -sfn "$skill_dir" "$link"
done

echo ""
echo "Symlinks in ~/.agents/skills/:"
ls -la "$HOME/.agents/skills/" | grep "^l"
```

---

## Phase 2 — OpenCode: Directory Access

OpenCode requires explicit allowance for directories outside the current working directory.
Ask the user:

> "What directory paths should OpenCode always have access to? These are typically your
> work repo root(s), your notes vault, and any personal agent repos.
> Example: `~/work/carrum`, `~/work/personal`, `~/Documents/Notes`"

Accept a list in any format. Then:

1. Check if `~/.config/opencode/opencode.jsonc` exists and read it if so.
2. Merge the `permission.external_directory` block into the existing config, preserving
   all other keys. Each path the user listed becomes an `"allow"` entry with `/**` appended.
3. Write the result back. Use `//` comments to label the block.

Example output shape:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "external_directory": {
      "~/work/carrum/**":    "allow",
      "~/work/personal/**": "allow",
      "~/Documents/Notes/**": "allow"
    }
  }
}
```

If the file already has an `external_directory` block, merge entries — do not overwrite
existing ones.

> **Note:** `external_directory` is a gate checked before any individual tool permission.
> Once allowed here, OpenCode's default `allow` rules for read/edit/bash apply automatically.

---

## Phase 3 — VS Code Copilot: User Settings

Detect the VS Code `settings.json` path. Check for each in order, use the first that exists:

```bash
for candidate in \
  "$HOME/Library/Application Support/Code/User/settings.json" \
  "$HOME/Library/Application Support/Code - Insiders/User/settings.json" \
  "$HOME/Library/Application Support/Cursor/User/settings.json" \
  "$HOME/.config/Code/User/settings.json" \
  "$HOME/.config/Code - Insiders/User/settings.json"; do
  [ -f "$candidate" ] && echo "$candidate" && break
done
```

If none found, ask the user to provide the path.

Then merge these two keys into the existing JSON, preserving all other settings:

```json
{
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,
    "~/.agents/skills": true
  },
  "chat.useCustomizationsInParentRepositories": true
}
```

For `chat.instructionsFilesLocations`: if the key already exists, add the two entries
without removing any existing ones. Write the file back with consistent indentation.

---

## Phase 4 — Copilot CLI: Shell Profile

Ask the user:

> "What shell are you using? (zsh / bash / other)"

Based on their answer, determine the default profile file:

| Shell | Default profile file |
|---|---|
| zsh | `~/.zshrc` |
| bash | `~/.bash_profile` (macOS) or `~/.bashrc` (Linux) |
| other | Ask the user to specify |

Then check whether the file exists:

```bash
[ -f "$PROFILE" ] && echo "exists" || echo "not found"
```

If it does not exist, inform the user and confirm before creating it:

> "`$PROFILE` does not exist. Create it now?"

If they confirm, create it:

```bash
touch "$PROFILE"
```

Then check if `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` is already set in that file:

```bash
grep -q "COPILOT_CUSTOM_INSTRUCTIONS_DIRS" "$PROFILE" && echo "already set" || echo "not found"
```

If not already set, append idempotently:

```bash
cat >> "$PROFILE" << 'EOF'

# Copilot CLI — agent skill discovery
export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="$HOME/.agents"
EOF
```

> After writing, remind the user to `source` the profile or open a new terminal for the
> export to take effect in the current session.

---

## Phase 5 — OpenCode: Global AGENTS.md (manual)

`~/.config/opencode/AGENTS.md` is loaded as global instructions at the start of every
OpenCode session. Its content is personal — this skill does not write it.

If the file doesn't exist, prompt the user:

> "`~/.config/opencode/AGENTS.md` not found. This file gives OpenCode always-on context
> about your roles, skills, and working style. You'll want to create it — but its content
> is yours to define. Skipping for now."

If it does exist, no action needed.

---

## Phase 6 — Verify

Run all checks and report pass/fail for each:

```bash
echo "=== Phase 1: Skill symlinks ==="
count=$(ls -la "$HOME/.agents/skills/" 2>/dev/null | grep "^l" | wc -l | tr -d ' ')
echo "$count symlink(s) in ~/.agents/skills/"
ls -la "$HOME/.agents/skills/" | grep "^l"

echo ""
echo "=== Phase 2: OpenCode external_directory ==="
if grep -q "external_directory" "$HOME/.config/opencode/opencode.jsonc" 2>/dev/null; then
  echo "PASS — entries found:"
  grep -A10 "external_directory" "$HOME/.config/opencode/opencode.jsonc"
else
  echo "FAIL — not configured"
fi

echo ""
echo "=== Phase 3: VS Code chat.instructionsFilesLocations ==="
VSCODE_SETTINGS=$(for f in \
  "$HOME/Library/Application Support/Code/User/settings.json" \
  "$HOME/Library/Application Support/Code - Insiders/User/settings.json" \
  "$HOME/Library/Application Support/Cursor/User/settings.json" \
  "$HOME/.config/Code/User/settings.json"; do
  [ -f "$f" ] && echo "$f" && break
done)

if [ -n "$VSCODE_SETTINGS" ] && grep -q "instructionsFilesLocations" "$VSCODE_SETTINGS" 2>/dev/null; then
  echo "PASS — found in $VSCODE_SETTINGS"
else
  echo "FAIL — not configured (settings: ${VSCODE_SETTINGS:-not found})"
fi

echo ""
echo "=== Phase 4: COPILOT_CUSTOM_INSTRUCTIONS_DIRS ==="
if [ -n "$COPILOT_CUSTOM_INSTRUCTIONS_DIRS" ]; then
  echo "PASS (current session) — $COPILOT_CUSTOM_INSTRUCTIONS_DIRS"
else
  echo "NOT SET in current session (may still be written to profile — open a new terminal to confirm)"
fi

echo ""
echo "=== Phase 5: OpenCode AGENTS.md ==="
[ -f "$HOME/.config/opencode/AGENTS.md" ] && echo "present" || echo "not found (manual step)"
```

---

## Reference

| What | OpenCode | VS Code Copilot | Copilot CLI |
|---|---|---|---|
| **Skill discovery** | `~/.agents/skills/` | `~/.agents/skills/` via `chat.instructionsFilesLocations` | `~/.agents/skills/` (auto) |
| **Directory access** | `permission.external_directory` in `opencode.jsonc` | Workspace Trust (interactive) | Session trust at launch |
| **Always-on instructions** | `~/.config/opencode/AGENTS.md` | `~/.agents/skills/*.instructions.md` | `~/.copilot/copilot-instructions.md` |
| **Written by this skill** | `opencode.jsonc` | `settings.json` | Shell profile |

### Why symlinks instead of direct paths

Hardcoding the repo path in each tool's config means every engineer's config differs by
machine and breaks silently when the repo moves. Symlinks in stable `~/` locations
decouple tool config from repo location — set once after cloning, trivially updated.

### Key files in this repo

- `.agents/skills/` — reusable skills invoked by name; see `skills-reference` for the index

See [`docs/workflow/coding-agent-guidelines.md`](../../../docs/workflow/coding-agent-guidelines.md)
for guidance on `AGENTS.md` vs `.github/copilot-instructions.md`.

### Notes

- `github.copilot.chat.codeGeneration.instructions` is **deprecated** as of VS Code 1.102.
  Use `.instructions.md` files via `chat.instructionsFilesLocations` instead.
- OpenCode's `external_directory` is the only config-file-based directory allowlist among
  these three tools. VS Code and Copilot CLI use interactive trust prompts instead.
