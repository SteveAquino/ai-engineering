---
name: remember
description: Append a timestamped memory entry to a role's memories.md file. Keeps role context durable across sessions and context compaction. Offers consolidation when entries get long.
---

# Skill: Remember

Use this skill to record something worth keeping across sessions for a specific role. The memory is appended to the role's `memories.md` file and will be loaded the next time `assume-role` is invoked for that role.

---

## Phase 0 — What to Remember

**Use `ask_user`:**
> "What do you want to remember? (Be specific — this will be loaded as context in future sessions)"

Allow freeform. Store as `MEMORY_CONTENT`.

---

## Phase 1 — Which Role

Determine the target role:

1. Check if a role was assumed in this session (look for a prior `assume-role` briefing in the conversation). If found, default to that role.

2. **Use `ask_user`:**
   > "Which role should this memory belong to?"

   Choices: list of discovered role names from `ls -d ~/.agents/roles/*/`
   
   If a default was identified in step 1, list it first with "(current session role)" appended.

Store as `ROLE_NAME`.

---

## Phase 2 — Write the Memory

Format the entry with today's date and append it under `## Recent` in the role's `memories.md`:

```bash
ROLE_DIR="$HOME/.agents/roles/<ROLE_NAME>"
DATE=$(date +%Y-%m-%d)
ENTRY="### $DATE\n- <MEMORY_CONTENT>\n"

# Append after the ## Recent header
# If ## Recent doesn't exist, create it
if grep -q "## Recent" "$ROLE_DIR/memories.md"; then
  # Insert after the ## Recent line
  sed -i '' "/^## Recent/a\\
\\
$ENTRY
" "$ROLE_DIR/memories.md"
else
  echo -e "\n## Recent\n\n$ENTRY" >> "$ROLE_DIR/memories.md"
fi
```

Confirm the write:
```bash
tail -10 "$ROLE_DIR/memories.md"
```

Show the user what was written.

---

## Phase 3 — Check for Consolidation

Count the number of entries under `## Recent`:

```bash
grep -c "^### " "$ROLE_DIR/memories.md"
```

If the count exceeds **20 entries**, offer consolidation:

**Use `ask_user`:**
> "You have <N> memory entries for `<ROLE_NAME>`. Want me to consolidate older entries into a summary to keep things compact?"
Choices: `["Yes — consolidate now", "Not yet"]`

### Consolidation process (if approved):

1. Read all entries under `## Recent`
2. Identify entries older than 30 days
3. Summarize the older entries into 3–7 concise bullet points capturing the key facts, decisions, and patterns
4. Rewrite `memories.md` with:
   - `## Historical Context` section at the top containing the summary
   - `## Recent` section containing only entries from the last 30 days
5. Show the user the consolidated result

```markdown
## Historical Context

- <summarized bullet 1>
- <summarized bullet 2>
- ...

## Recent

### <recent date>
- <recent memory>
```

---

## Reference

- To view all memories for a role: invoke `manage-role` → "View memories"
- To load memories into the current session: invoke `assume-role`
- Roles directory: `~/.agents/roles/`
