---
name: setup-agent-integration
description: Wire this repo's skills into OpenCode, VS Code Copilot, and Copilot CLI on a new machine using symlinks. The repo can live anywhere — tools always look in stable home-directory locations. Run once after cloning.
---

# Skill: Setup Agent Integration

Wire this repo's skills into your agent tools so they are available in every session, regardless of where the repo is cloned. Covers OpenCode, VS Code Copilot, and Copilot CLI.

**Core strategy:** instead of pointing each tool's config at this repo's actual path, we create symlinks in stable `~/` locations that tools already discover automatically. The repo can be cloned anywhere and the tool configs never need to change.

Run once after cloning, or to repair a broken setup.

---

## Phase 0 — Detect Repo Location

```bash
REPO=$(git rev-parse --show-toplevel 2>/dev/null)
echo "Repo root: $REPO"
```

Confirm with the user if the detected path looks wrong before proceeding.

---

## Phase 1 — Skill Symlinks (`~/.agents/skills/`)

`~/.agents/skills/` is the shared discovery location for all three tools. Rather than symlinking the entire directory (which would conflict if you also have personal skills there), we symlink each skill individually so personal and repo skills coexist cleanly.

```bash
mkdir -p "$HOME/.agents/skills"

for skill_dir in "$REPO/.agents/skills"/*/; do
  name=$(basename "$skill_dir")
  link="$HOME/.agents/skills/$name"

  if [ -L "$link" ]; then
    echo "updating: $link → $skill_dir"
  else
    echo "creating: $link → $skill_dir"
  fi

  ln -sfn "$skill_dir" "$link"
done

echo ""
echo "Skills now available in ~/.agents/skills/:"
ls "$HOME/.agents/skills/"
```

After this, every skill in this repo is discoverable by all three tools without any path-specific config. Personal skills you maintain in a separate repo can coexist in the same `~/.agents/skills/` directory as individual symlinks alongside these.

---

## Phase 2 — OpenCode: Global AGENTS.md

OpenCode loads `~/.config/opencode/AGENTS.md` as global instructions at the start of every session. This repo does not ship a template for it — you'll need to create or maintain your own. At minimum it should list the skills now available in `~/.agents/skills/` so OpenCode can discover and invoke them.

If you already have a global AGENTS.md, add a section pointing at the symlinked skills:

```markdown
## Carrum Developer Skills

Skills available via `~/.agents/skills/`. Invoke any skill by name.
See `skills-reference` for the full index.
```

---

## Phase 3 — OpenCode: Directory Access

OpenCode's `external_directory` permission defaults to `ask` for any path outside the current working directory. Configure it once in `~/.config/opencode/opencode.jsonc` so you're never prompted for your regular project directories:

```jsonc
// ~/.config/opencode/opencode.jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "external_directory": {
      // Add each directory tree you work in regularly:
      "~/work/<your-org>/**":         "allow",
      "~/work/<personal>/**":         "allow",
      "~/Documents/<notes-vault>/**": "allow"
    }
  }
}
```

Replace the placeholders with your actual directory names. `**` allows all subdirectories at any depth. This is the only persistent directory allowlist among the three tools — VS Code and Copilot CLI both handle access via interactive trust prompts instead.

> **How it works:** `external_directory` is a gate checked before any individual tool permission (read, edit, bash). Once allowed here, OpenCode's default `allow` rules for those tools apply automatically — no further config needed.

---

## Phase 4 — VS Code Copilot: One-time Settings

The skill symlinks from Phase 1 make skills available at `~/.agents/skills/`, but VS Code needs to know to look there. Add this to your VS Code User settings (`settings.json`):

```json
{
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,
    "~/.agents/skills": true
  },
  "chat.useCustomizationsInParentRepositories": true
}
```

These are stable paths that never need to change. `chat.useCustomizationsInParentRepositories` tells VS Code to walk up from open workspace folders and pick up `AGENTS.md` and `.github/copilot-instructions.md` from parent directories automatically.

---

## Phase 5 — Copilot CLI: Shell Profile

Add `~/.agents` to `COPILOT_CUSTOM_INSTRUCTIONS_DIRS` in your shell profile. This is a stable path — the symlinks do the work of routing to the right repo:

```bash
# ~/.zshrc or ~/.bashrc
export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="$HOME/.agents"
```

Copilot CLI will look for `AGENTS.md` and `.github/instructions/**/*.instructions.md` inside `~/.agents` on every session start. Skills in `~/.agents/skills/` are also auto-discovered without this variable.

---

## Phase 6 — Verify

```bash
echo "=== ~/.agents/skills (symlinks) ==="
ls -la "$HOME/.agents/skills/" | grep "^l"

echo ""
echo "=== OpenCode AGENTS.md ==="
[ -f "$HOME/.config/opencode/AGENTS.md" ] && echo "present" || echo "(not installed)"

echo ""
echo "=== OpenCode external_directory config ==="
cat "$HOME/.config/opencode/opencode.jsonc" 2>/dev/null || echo "(no config found)"

echo ""
echo "=== COPILOT_CUSTOM_INSTRUCTIONS_DIRS ==="
echo "${COPILOT_CUSTOM_INSTRUCTIONS_DIRS:-(not set — add to shell profile)}"
```

---

## Reference

| What | OpenCode | VS Code Copilot | Copilot CLI |
|---|---|---|---|
| **Skill discovery** | `~/.agents/skills/` (via AGENTS.md) | `~/.agents/skills/` (via `chat.instructionsFilesLocations`) | `~/.agents/skills/` (auto) |
| **Directory access** | `permission.external_directory` in `opencode.jsonc` | Workspace Trust (interactive) | Session trust at launch |
| **Always-on personal instructions** | `~/.config/opencode/AGENTS.md` | `~/.agents/skills/*.instructions.md` | `~/.copilot/copilot-instructions.md` |
| **Config file** | `~/.config/opencode/opencode.jsonc` | VS Code `settings.json` (User) | `~/.zshrc` / shell profile |

### Why symlinks instead of direct paths

Hardcoding the repo path in each tool's config means every engineer's config differs by machine, and breaks silently when the repo moves. Symlinks in stable `~/` locations decouple tool config from repo location:

- Tool configs point at `~/.agents/skills/` — a path that never changes
- Symlinks inside that directory point at the actual repo — set once after cloning, trivially updated
- Personal skills coexist in the same `~/.agents/skills/` directory as individual symlinks alongside repo skills, with no collision

### Key files in this repo

- `.agents/skills/` — reusable skills invoked by name in any tool; see `skills-reference` for the index

See [`docs/workflow/coding-agent-guidelines.md`](../../../docs/workflow/coding-agent-guidelines.md) for guidance on what belongs in `AGENTS.md` vs `.github/copilot-instructions.md` when you add those files.

### Notes

- `$CARRUM_HOME` should be set in your shell profile to the root where all Carrum repos are cloned.
- OpenCode's `external_directory` is the only persistent config-file-based directory allowlist among these tools. VS Code and Copilot CLI use interactive trust prompts instead.
- `github.copilot.chat.codeGeneration.instructions` in VS Code settings is **deprecated** as of VS Code 1.102. Use `.instructions.md` files via `chat.instructionsFilesLocations` instead.
