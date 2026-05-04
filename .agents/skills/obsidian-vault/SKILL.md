---
name: obsidian-vault
description: Read and write notes in a local Obsidian vault. Supports write-note, append-note, read-note, and list-notes operations. Vault path is configured per-machine via a gitignored local references file. Used by read-apple-mail and other skills that treat the Obsidian vault as a durable output target.
platform: macOS/Linux/Windows
---

# Skill: Obsidian Vault

Read and write notes in a local Obsidian vault. This skill is a lightweight I/O layer — it does not open the Obsidian app or use the Obsidian API. It reads and writes `.md` files directly in the vault directory.

---

## Local References

Before executing, load local configuration:

```bash
cat "$(dirname "$0")/references/local.md" 2>/dev/null || echo "(no local references)"
```

`VAULT_PATH` is **required**. If not set, this skill cannot proceed.  
See `docs/local.example.md` for all supported keys.

---

## Phase 0 — Locate Vault

Read `VAULT_PATH` from `references/local.md`.

If not set:
- **If a user is present**: ask the user for the vault path. Offer to write it to `references/local.md` for future runs.
- **If running autonomously**: return `error-no-vault-path` and stop.

Validate the path:
```bash
[ -d "$VAULT_PATH" ] && echo "Vault found" || echo "ERROR: Vault directory not found"
```

If the directory does not exist, return `error-vault-not-found` and stop.

---

## Phase 1 — Determine Operation

The caller must specify one of:

| Operation | Description |
|-----------|-------------|
| `write-note` | Create or overwrite a note at a given path within the vault |
| `append-note` | Append content to an existing note (create if absent) |
| `read-note` | Read and return the content of a note |
| `list-notes` | List note filenames in a given vault subdirectory |

If no operation is specified, ask the user which operation to perform.

---

## Phase 2 — Resolve and Validate Target Path

All paths are **relative to `VAULT_PATH`**.

Resolve the full target path:
```python
import os
vault = os.path.expanduser(VAULT_PATH)
target = os.path.realpath(os.path.join(vault, NOTE_PATH))
assert target.startswith(os.path.realpath(vault) + os.sep), "Path escapes vault root"
```

Reject any path that:
- Is absolute
- Contains `..` traversal components
- Resolves outside `VAULT_PATH` (symlink traversal)

Return `error-invalid-path` if validation fails.

For `write-note` and `append-note`: create any missing parent directories within the vault.

Date token substitution: replace `<YYYY>`, `<MM>`, `<DD>` in the path with the current date.

---

## Phase 3 — Execute Operation

### write-note

Show the user a preview before writing:
```
Target: <vault_path>/<note_path>
Content preview (first 5 lines):
  <preview>
```

**If a user is present**: ask:
> "Write this note to your Obsidian vault?"
Choices: `["Yes — write it", "No — cancel"]`

**If running autonomously**: write without prompting, but log the target path and byte count.

```python
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, 'w', encoding='utf-8') as f:
    f.write(content)
print(f"Written: {target} ({len(content)} bytes)")
```

Return `ok`.

---

### append-note

Append a `\n\n` separator followed by the new content:

```python
os.makedirs(os.path.dirname(target), exist_ok=True)
with open(target, 'a', encoding='utf-8') as f:
    f.write('\n\n' + content)
print(f"Appended to: {target}")
```

Return `ok`.

---

### read-note

```python
with open(target, 'r', encoding='utf-8') as f:
    print(f.read())
```

Return the full content to the caller.

Return `error-not-found` if the file does not exist.

---

### list-notes

```python
import glob
pattern = os.path.join(target, '**', '*.md')
notes = sorted(glob.glob(pattern, recursive=True))
for n in notes:
    print(os.path.relpath(n, vault))
```

Returns relative paths from vault root.

---

## Phase 4 — Return Result

Exit codes for callers:
- `ok` — operation completed
- `error-no-vault-path` — `VAULT_PATH` not configured
- `error-vault-not-found` — configured path does not exist on disk
- `error-invalid-path` — note path fails safety validation
- `error-not-found` — note does not exist (read-note only)

---

## Notes

- This skill never opens the Obsidian app — it reads/writes `.md` files directly
- Obsidian syncs in the background; writes from this skill will appear after Obsidian rescans
- Do not write to vault paths that Obsidian marks as excluded (e.g., `.obsidian/`, `_templates/`) — those are internal and this skill should not modify them
- For daily notes: use `VAULT_PATH/<daily-note-folder>/<YYYY>-<MM>-<DD>.md` as the path
- See `docs/local.example.md` for vault path and default note path configuration
