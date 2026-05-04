---
name: manage-role
description: Maintain an existing role persona. View or edit instructions, view or consolidate memories, rename, or delete a role.
---

# Skill: Manage Role

Use this skill to inspect or maintain an existing role persona. Useful for refining instructions over time, reviewing accumulated memories, or cleaning up old roles.

## Path Resolution

Read `ROLES_DIR` from `.agents/references/local.md` in this repository before executing any path-dependent commands.

---

## Phase 0 — Select Role

List available roles:

```bash
ls -d .agents/roles/*/ 2>/dev/null | xargs -I{} basename {}
```

If no roles exist:
> "No roles found in `.agents/roles/`. Use the `create-role` skill to define your first role."
Stop here.

**Use `ask_user`:**
> "Which role do you want to manage?"
Choices: list of discovered role names.

Store as `ROLE_NAME`.

---

## Phase 1 — Select Action

**Use `ask_user`:**
> "What do you want to do with the `<ROLE_NAME>` role?"

Choices:
- `View instructions`
- `Edit instructions`
- `View memories`
- `Consolidate memories`
- `Rename role`
- `Delete role`

---

## Action: View Instructions

```bash
cat .agents/roles/<ROLE_NAME>/ROLE.md
```

Display the full contents. Offer to edit afterward:

**Use `ask_user`:** "Want to edit any section?"
Choices: `["Yes — edit", "No, looks good"]`

---

## Action: Edit Instructions

Show the current `ROLE.md` section by section. For each section, ask:

**Use `ask_user`:** "Current value for **<Section Name>**: `<current content>`. Update it?"
Choices: `["Keep as-is", "Update"]`

If "Update", ask for new content (freeform), then rewrite that section in the file.

After all sections, write the updated file and display the result.

---

## Action: View Memories

```bash
cat .agents/roles/<ROLE_NAME>/memories.md
```

Display the full contents. Then ask:

**Use `ask_user`:** "Anything else?"
Choices: `["Consolidate memories", "Done"]`

---

## Action: Consolidate Memories

Count entries:
```bash
grep -c "^### " .agents/roles/<ROLE_NAME>/memories.md
```

Display the count. Then:

1. Read all entries under `## Recent`
2. Identify entries older than 30 days
3. Summarize the older entries into 5–10 concise bullet points capturing key facts, decisions, and patterns — discard redundant or trivial entries
4. Rewrite `memories.md` as:

```markdown
## Historical Context

- <summarized bullet 1>
- <summarized bullet 2>
- ...

## Recent

### <date of most recent kept entry>
- <memory>

### <etc.>
```

Show the consolidated result. Ask for confirmation before writing:

**Use `ask_user`:** "Does this consolidation look right?"
Choices: `["Write it", "Make changes"]`

---

## Action: Rename Role

**Use `ask_user`:** "What should the new name be? (kebab-case)"
Allow freeform.

Check if the new name already exists. If so, warn and abort.

```bash
mv .agents/roles/<ROLE_NAME> .agents/roles/<NEW_NAME>
```

Confirm:
```bash
ls .agents/roles/
```

---

## Action: Delete Role

**Use `ask_user`:**
> "Are you sure you want to delete the `<ROLE_NAME>` role? This will permanently remove its instructions, memories, and session ID."
Choices: `["Yes — delete it", "Cancel"]`

If confirmed:
```bash
rm -rf .agents/roles/<ROLE_NAME>
echo "Role '$ROLE_NAME' deleted."
```

Confirm the deletion:
```bash
ls .agents/roles/
```

---

## Reference

- Roles directory: `.agents/roles/`
- To create a new role: invoke `create-role`
- To assume a role: invoke `assume-role`
- To append a new memory: invoke `remember`
- For deep memory curation (quality-based pruning + session replay): invoke `dream`
