---
name: create-role
description: Interactively define a new role persona. Gathers name, purpose, goals, and communication preferences, then scaffolds the role directory with ROLE.md and an empty memories.md. Optionally assumes the role immediately.
---

# Skill: Create Role

Use this skill to define a new persistent role persona. Roles are used by `assume-role` to brief an agent session with specific instructions and accumulated memories.

## Path Resolution

Read `ROLES_DIR` from `.agents/references/local.md` in this repository before executing any path-dependent commands. If that file does not exist, tell the user to create it — it defines `ROLES_DIR` as an absolute path for this machine.

---

## Phase 0 — Gather Role Identity

**Use `ask_user`:**
> "What should this role be called? Use kebab-case (e.g., `architect`, `eng-lead`, `staff-engineer`)."

Allow freeform. Validate it's kebab-case (lowercase, hyphens only). Store as `ROLE_NAME`.

Check if the role already exists:
```bash
ls .agents/roles/<ROLE_NAME>/ 2>/dev/null
```

If it exists, warn the user and ask:
> "A role named `<ROLE_NAME>` already exists. Do you want to overwrite it or pick a different name?"
Choices: `["Overwrite it", "Pick a different name"]`

---

## Phase 1 — Define the Role

Ask each question in sequence. Allow freeform for all.

**1a.** `ask_user`: "In one sentence, what is this role for? (e.g., 'Technical architecture advisor focused on system design and trade-offs')"

**1b.** `ask_user`: "What are this role's standing goals? List anything it should always prioritize, watch out for, or advocate for."

**1c.** `ask_user`: "How should this role communicate? (e.g., lead with recommendation, use tables for trade-offs, be terse, use bullet points, etc.)"

**1d.** `ask_user`: "Are there any reference docs, skills, or sources this role should always consult? (Leave blank to skip)"

---

## Phase 2 — Preview & Confirm

Assemble and display the full `ROLE.md` that will be written:

```markdown
# Role: <ROLE_NAME>

## Purpose
<Phase 1a answer>

## Standing Goals
<Phase 1b answer, formatted as bullets>

## Communication Style
<Phase 1c answer>

## Always Consult
<Phase 1d answer, or omit section if blank>
```

**Use `ask_user`:**
> "Does this look right? Confirm to create the role."
Choices: `["Create it", "Make changes"]`

If "Make changes", loop back to Phase 1 for the section the user wants to revise.

---

## Phase 3 — Scaffold the Role

```bash
ROLE_DIR=".agents/roles/<ROLE_NAME>"
mkdir -p "$ROLE_DIR"
```

Write `$ROLE_DIR/ROLE.md` with the following structure. The `## On Session Start` block must appear between the frontmatter closing `---` and the `# Role:` heading — this ensures memories are loaded automatically when the agent starts:

```markdown
---
name: "<display name>"
description: "<one-sentence description>"
...
---

## On Session Start

**Before responding to your first message in any session**, read your memories to restore context from previous sessions. Do not reply until you have read this file:

```bash
cat .agents/roles/<ROLE_NAME>/state/memories.md
```

This path is relative to the ai-engineering repository root. If the file is not found, your workspace root is not the ai-engineering repo — memories will not be available this session.

---

# Role: <ROLE_NAME>

## Purpose
...
```

Append the confirmed content from Phase 2 (Purpose, Standing Goals, Communication Style, Always Consult) after the `# Role:` heading.

```bash
# Initialize state/ subdirectory with empty memories and sessions files
ROLE_NAME="<ROLE_NAME>"
mkdir -p ".agents/roles/$ROLE_NAME/state"
printf '## Recent\n\n' > ".agents/roles/$ROLE_NAME/state/memories.md"
printf '# Sessions: %s\n\n| Date | Session ID | Label |\n|---|---|---|\n' "$ROLE_NAME" > ".agents/roles/$ROLE_NAME/state/sessions.md"
```

Confirm:
```bash
ls -la .agents/roles/<ROLE_NAME>/
ls -la .agents/roles/<ROLE_NAME>/state/
```

---

## Phase 4 — Assume Now?

**Use `ask_user`:**
> "Role `<ROLE_NAME>` created. Do you want to assume it now and brief this session?"
Choices: `["Yes — assume role now", "Not yet"]`

If "Yes", invoke the `assume-role` skill, passing `<ROLE_NAME>` as the target role (skip the role selection step).

---

## Reference

- Roles directory: `.agents/roles/`
- To switch roles later: invoke `assume-role`
- To view all roles: invoke `list-roles`
- To update role instructions later: invoke `manage-role`
