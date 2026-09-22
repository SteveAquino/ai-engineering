---
name: setup-agent-integration
description: Wire agent skills and role personas from this repo and any additional repos into OpenCode, VS Code Copilot, and Copilot CLI on a new machine using individual symlinks. Run once after cloning.
---

# Skill: Setup Agent Integration

Wire agent skills and role personas into your tools so they are available in every
session, regardless of where repos are cloned. Run from any repo that contains
`.agents/skills/` or `.agents/roles/`. Additional repos (personal, employer, etc.)
can be added when prompted.

**Strategy:** `~/.agents/skills/` and `~/.agents/roles/` are real directories containing
one symlink per skill or role. Skills and roles from multiple repos coexist — if the
same name exists in two repos, the last one processed wins. Tool configs point at the
stable `~/` path; symlinks route to the actual repos.

Run once after cloning, or to repair a broken setup.

---

## Phase 0 — Detect Current Repo

```bash
REPO=$(git rev-parse --show-toplevel 2>/dev/null)
echo "Current repo: $REPO"
```

Confirm with the user before proceeding if the path looks wrong.

---

## Phase 1 — Collect Repos

Ask the user:

> "Are there any other repos with agent skills or role personas you'd like to include?
> List their paths, one per line — or press enter to skip.
> Example: `~/work/personal/ai-engineering`"

Build a list: `REPOS = [REPO, ...any additional repos provided]`.

For each additional repo, verify it contains `.agents/skills/`, `.agents/roles/`, or both
before including it. If a path has neither, warn and skip it.

---

## Phase 2 — Skill Symlinks (`~/.agents/skills/`)

First, ensure `~/.agents/skills/` is a real directory. If it's currently a whole-dir
symlink (from an older setup), convert it:

```bash
if [ -L "$HOME/.agents/skills" ]; then
  OLD_TARGET=$(readlink "$HOME/.agents/skills")
  echo "Converting whole-dir symlink → $OLD_TARGET to a real directory..."
  rm "$HOME/.agents/skills"
  mkdir -p "$HOME/.agents/skills"
  # Re-link skills that were in the old target as real dirs
  for skill_dir in "$OLD_TARGET"/*/; do
    name=$(basename "$skill_dir")
    [ -d "$skill_dir" ] && [ ! -L "$skill_dir" ] && ln -sfn "$skill_dir" "$HOME/.agents/skills/$name"
  done
else
  mkdir -p "$HOME/.agents/skills"
fi
```

Then, for each repo in `REPOS`, symlink its skills:

```bash
for REPO in "${REPOS[@]}"; do
  echo "--- Linking skills from $REPO ---"
  for skill_dir in "$REPO/.agents/skills"/*/; do
    name=$(basename "$skill_dir")
    link="$HOME/.agents/skills/$name"

    # Remove real directory at target — ln -sfn won't replace it
    if [ -d "$link" ] && [ ! -L "$link" ]; then
      rm -rf "$link"
    fi

    [ -L "$link" ] && echo "updating: $name" || echo "creating: $name"
    ln -sfn "$skill_dir" "$link"
  done
done

echo ""
echo "All symlinks in ~/.agents/skills/:"
ls -la "$HOME/.agents/skills/" | grep "^l"
```

---

## Phase 2b — Role Symlinks (`~/.agents/roles/`)

First, ensure `~/.agents/roles/` is a real directory. If it's currently a whole-dir
symlink (from an older setup), convert it:

```bash
if [ -L "$HOME/.agents/roles" ]; then
  OLD_TARGET=$(readlink "$HOME/.agents/roles")
  echo "Converting whole-dir symlink → $OLD_TARGET to a real directory..."
  rm "$HOME/.agents/roles"
  mkdir -p "$HOME/.agents/roles"
  shopt -s nullglob
  for role_dir in "$OLD_TARGET"/*/; do
    name=$(basename "$role_dir")
    [ -d "$role_dir" ] && [ ! -L "$role_dir" ] && ln -sfn "$role_dir" "$HOME/.agents/roles/$name"
  done
  shopt -u nullglob
else
  mkdir -p "$HOME/.agents/roles"
fi
```

Then, for each repo in `REPOS`, symlink its roles:

```bash
for REPO in "${REPOS[@]}"; do
  echo "--- Linking roles from $REPO ---"
  shopt -s nullglob
  for repo_role_dir in "$REPO/.agents/roles"/*/; do
    name=$(basename "$repo_role_dir")
    link="$HOME/.agents/roles/$name"

    if [ -d "$link" ] && [ ! -L "$link" ]; then
      if [ -d "$link/state" ]; then
        mkdir -p "$repo_role_dir/state"
        source_count=$(find "$link/state" -type f | wc -l | tr -d ' ')
        dest_before=$(find "$repo_role_dir/state" -type f 2>/dev/null | wc -l | tr -d ' ')
        echo "migrating state: $link/state → $repo_role_dir/state"
        echo "source files: $source_count"
        echo "destination files before merge: $dest_before"
        rsync -ai --update "$link/state/" "$repo_role_dir/state/"
        dest_after=$(find "$repo_role_dir/state" -type f | wc -l | tr -d ' ')
        echo "destination files after merge: $dest_after"
      fi

      backup="${link}.premigrate.$(date +%s)"
      echo "warning: real directory found at $link — backing up to $backup"
      mv "$link" "$backup"
    fi

    [ -L "$link" ] && echo "updating: $name" || echo "creating: $name"
    ln -sfn "$repo_role_dir" "$link"
  done
  shopt -u nullglob
done

echo ""
echo "All symlinks in ~/.agents/roles/:"
ls -la "$HOME/.agents/roles/" | grep "^l"
```

---

## Phase 3 — OpenCode: Directory Access

Ask the user:

> "What directory paths should OpenCode always have access to? These are typically your
> work repo roots, notes vault, and any personal agent repos.
> Example: `~/work/carrum`, `~/work/personal`, `~/Documents/Notes`"

Accept a list in any format. Then:

1. Check if `~/.config/opencode/opencode.jsonc` exists and read it if so.
2. Merge the `permission.external_directory` block into the existing config, preserving
   all other keys. Each path becomes an `"allow"` entry with `/**` appended.
3. Write the result back.

Example output shape:

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "permission": {
    "external_directory": {
      "~/work/carrum/**":             "allow",
      "~/work/personal/**":           "allow",
      "~/Documents/Notes/**":         "allow"
    }
  }
}
```

If the file already has an `external_directory` block, merge entries — do not overwrite
existing ones.

---

## Phase 4 — VS Code Copilot: User Settings

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

Merge these two keys into the existing JSON, preserving all other settings:

```json
{
  "chat.instructionsFilesLocations": {
    ".github/instructions": true,
    "~/.agents/skills": true
  },
  "chat.useCustomizationsInParentRepositories": true
}
```

For `chat.instructionsFilesLocations`: if the key already exists, add the entries
without removing any existing ones. Write the file back with consistent indentation.

---

## Phase 5 — Copilot CLI: Shell Profile

Ask the user:

> "What shell are you using? (zsh / bash / other)"

Determine the default profile file:

| Shell | Default profile file |
|---|---|
| zsh | `~/.zshrc` |
| bash | `~/.bash_profile` (macOS) or `~/.bashrc` (Linux) |
| other | Ask the user to specify |

Check whether the file exists:

```bash
[ -f "$PROFILE" ] && echo "exists" || echo "not found"
```

If it does not exist, confirm with the user before creating it:

> "`$PROFILE` does not exist. Create it now?"

If they confirm: `touch "$PROFILE"`

Then check if already set and append if not:

```bash
grep -q "COPILOT_CUSTOM_INSTRUCTIONS_DIRS" "$PROFILE" && echo "already set" || \
cat >> "$PROFILE" << 'EOF'

# Copilot CLI — agent skill discovery
export COPILOT_CUSTOM_INSTRUCTIONS_DIRS="$HOME/.agents"
EOF
```

> Remind the user to `source` the profile or open a new terminal for the export to
> take effect in the current session.

---

## Phase 6 — OpenCode: Global AGENTS.md (manual)

`~/.config/opencode/AGENTS.md` is loaded as global instructions at the start of every
OpenCode session. Its content is personal — this skill does not write it.

If the file doesn't exist, note it:

> "`~/.config/opencode/AGENTS.md` not found. This file gives OpenCode always-on context
> about your roles, skills, and working style. You'll want to create it — its content
> is yours to define. Skipping."

---

## Phase 7 — Verify

```bash
echo "=== Phase 2: Skill symlinks ==="
count=$(ls -la "$HOME/.agents/skills/" 2>/dev/null | grep "^l" | wc -l | tr -d ' ')
echo "$count symlink(s) in ~/.agents/skills/"
ls -la "$HOME/.agents/skills/" | grep "^l"

echo ""
echo "=== Phase 2b: Role symlinks ==="
role_count=$(ls -la "$HOME/.agents/roles/" 2>/dev/null | grep "^l" | wc -l | tr -d ' ')
echo "$role_count symlink(s) in ~/.agents/roles/"
ls -la "$HOME/.agents/roles/" | grep "^l"
shopt -s nullglob
for link in "$HOME/.agents/roles"/*; do
  [ -L "$link" ] || continue
  name=$(basename "$link")
  role_md="$link/ROLE.md"
  state_dir="$link/state"
  if [ -f "$role_md" ] && [ -d "$state_dir" ] && { [ -f "$state_dir/memories.md" ] || [ -f "$state_dir/sessions.md" ]; }; then
    echo "PASS — $name"
  else
    echo "FAIL — $name"
    [ -f "$role_md" ] || echo "  missing ROLE.md"
    [ -d "$state_dir" ] || echo "  missing state/"
    if [ -d "$state_dir" ] && [ ! -f "$state_dir/memories.md" ] && [ ! -f "$state_dir/sessions.md" ]; then
      echo "  missing memories.md and sessions.md"
    fi
  fi
done
shopt -u nullglob

echo ""
echo "=== Phase 3: OpenCode external_directory ==="
if grep -q "external_directory" "$HOME/.config/opencode/opencode.jsonc" 2>/dev/null; then
  echo "PASS — entries found:"
  grep -A10 "external_directory" "$HOME/.config/opencode/opencode.jsonc"
else
  echo "FAIL — not configured"
fi

echo ""
echo "=== Phase 4: VS Code chat.instructionsFilesLocations ==="
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
echo "=== Phase 5: COPILOT_CUSTOM_INSTRUCTIONS_DIRS ==="
if [ -n "$COPILOT_CUSTOM_INSTRUCTIONS_DIRS" ]; then
  echo "PASS (current session) — $COPILOT_CUSTOM_INSTRUCTIONS_DIRS"
else
  echo "NOT SET in current session (may be written to profile — open a new terminal to confirm)"
fi

echo ""
echo "=== Phase 6: OpenCode AGENTS.md ==="
[ -f "$HOME/.config/opencode/AGENTS.md" ] && echo "present" || echo "not found (manual step)"
```

---

## Reference

| What | OpenCode | VS Code Copilot | Copilot CLI |
|---|---|---|---|
| **Skill discovery** | `~/.agents/skills/` | `~/.agents/skills/` via `chat.instructionsFilesLocations` | `~/.agents/skills/` (auto) |
| **Role discovery** | `~/.agents/roles/` via role-aware skills | `~/.agents/roles/` via role-aware skills | `~/.agents/roles/` via role-aware skills |
| **Directory access** | `permission.external_directory` in `opencode.jsonc` | Workspace Trust (interactive) | Session trust at launch |
| **Always-on instructions** | `~/.config/opencode/AGENTS.md` | `~/.agents/skills/*.instructions.md` | `~/.copilot/copilot-instructions.md` |
| **Written by this skill** | `opencode.jsonc` | `settings.json` | Shell profile |

### Notes

- Skills from multiple repos coexist as individual symlinks. If the same skill name
  appears in two repos, the last repo processed wins — carrum skills conventionally
  run last and take precedence over personal skills of the same name.
- If `~/.agents/roles/<name>` already exists as a real directory, treat it as possible
  pre-symlink local state: merge any `state/` files into the repo role with
  `rsync --update`, print the merge summary, then back up the original directory to
  `.premigrate.<timestamp>` before replacing it with the symlink.
- `github.copilot.chat.codeGeneration.instructions` is **deprecated** as of VS Code 1.102.
  Use `.instructions.md` files via `chat.instructionsFilesLocations` instead.
- OpenCode's `external_directory` is the only config-file-based directory allowlist
  among these tools. VS Code and Copilot CLI use interactive trust prompts instead.
