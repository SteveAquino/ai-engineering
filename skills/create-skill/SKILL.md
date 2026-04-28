---
name: create-skill
description: Meta-skill for creating a new agent skill. Gathers the skill's purpose, classifies it as employer-specific or personal/portable, then scaffolds the SKILL.md in the right place — a git worktree + draft PR for employer skills, or the personal skills library for portable ones.
---

# Skill: Create Skill

Use this skill when you want to create a new agent skill from scratch.
It will ask you what you want to build, classify the skill, scaffold the file, and land it in the right place.

---

## Phase 0 — Intake

Ask the user what they want to build:

**Use `ask_user`:**
> "What skill do you want to create? Describe what it should do, what inputs it takes, and what it produces. A sentence or two is fine."

Allow freeform. Capture: purpose, likely inputs, likely outputs, and any tools or services it uses.

---

## Phase 1 — Classify: Where Does This Skill Live?

Evaluate the skill description and determine its destination. There are three possibilities.

### Is this actually a role, not a skill?

If the description sounds like a **persistent persona** — a "mode of operation", an assistant with standing goals and communication style — it's a role, not a skill.

**Signals:** the user says "role", "assistant", "persona", or describes ongoing behavior rather than a discrete task.

**If so:** don't create a skill. Tell the user:
> "This sounds more like a role than a skill — a persistent persona loaded by `assume-role`. Want me to invoke `create-role` instead?"
Choices: `["Yes — create a role", "No — it's still a skill"]`

---

### Personal/portable skill → `~/work/personal/ai-engineering/skills/`

**Signals (all of these → personal skill):**
- Uses only general OS/CLI tools (`git`, `gh`, `bash`, `afplay`, `brew`, etc.)
- Would be useful at any company or on any project
- No references to internal services, proprietary tooling, or org-specific workflows

---

### Employer/project skill → ask for destination

If the skill references internal tools, services, or org-specific workflows, it doesn't belong in the personal library.

**Use `ask_user`:**
> "Where should this skill live? Provide the path to the skills directory (e.g. `/path/to/repo/skills/` or `/path/to/repo/.github/skills/`)."

Allow freeform. Store as `$SKILLS_DEST`.

Also ask:
**Use `ask_user`:**
> "What GitHub repo should the PR be opened against? (e.g. `org/repo`)"

Allow freeform. Store as `$GITHUB_REPO`.

---

### When ambiguous

If it's unclear whether the skill is personal or employer-specific, **always ask**:

**Use `ask_user`:**
> "Should this skill go in your personal skills library (portable, any project) or somewhere else?"

Choices: `["Personal library", "Somewhere else — I'll provide the path"]`

**Default lean:** personal if genuinely unsure — easier to move later.

---

## Phase 2 — Design the Skill

Based on the user's description, draft the key design decisions:

1. **Skill name** — kebab-case, descriptive (e.g., `setup-local-env`, `summarize-pr`, `osx-sounds`)
2. **One-sentence description** — for the frontmatter `description` field and the skills index
3. **Phases or sections** — outline what the skill will do step by step
4. **Key tools** — what commands, APIs, or CLIs the skill uses
5. **Inputs/outputs** — what the user provides, what the skill produces

Present the design as a brief outline.

**Use `ask_user`:**
> "Here's my proposed design for the skill. Does this look good, or do you want to adjust anything?"

Include choices: `["Looks good — write it", "I want to adjust something"]`.
Do not proceed until approved.

---

## Phase 3 — Scaffold the Skill

### If Personal Skill:

**3a. Create the skill directory and file**

```bash
SKILL_NAME="<skill-name>"
PERSONAL_SKILLS="$HOME/work/personal/ai-engineering/skills"
mkdir -p "$PERSONAL_SKILLS/$SKILL_NAME"
```

Write `$PERSONAL_SKILLS/$SKILL_NAME/SKILL.md` with:
- Frontmatter (`name`, `description`)
- Content based on the approved design from Phase 2
- Follow the conventions in existing skills: phase-driven structure, `ask_user` before destructive actions, code blocks for all commands

**3b. Update the personal skills index**

Add a new row to the `## Available Skills` table in:
`$HOME/work/personal/ai-engineering/skills/personal-skills-index/SKILL.md`

Row format:
```markdown
| [`<skill-name>/SKILL.md`](../<skill-name>/SKILL.md) | <One-sentence description> |
```

**3c. Confirm**

```bash
cat "$PERSONAL_SKILLS/$SKILL_NAME/SKILL.md"
```

Present the created file to the user and confirm it looks right.

---

### If Employer/Project Skill:

**3a. Create a git worktree**

Determine the repo root from `$SKILLS_DEST`. Use a descriptive branch name:

```bash
BRANCH="add-<skill-name>-skill"
git -C "<repo-root>" worktree add "<repo-root>-$BRANCH" -b $BRANCH
```

**3b. Scaffold the skill file**

```bash
SKILL_NAME="<skill-name>"
SKILL_DIR="<worktree-path>/<skills-subdir>/$SKILL_NAME"
mkdir -p "$SKILL_DIR"
```

Write `$SKILL_DIR/SKILL.md` with:
- Frontmatter (`name`, `description`)
- Content based on the approved design from Phase 2
- Phase-driven structure with `ask_user` confirmation gates

**3c. Update the skills index**

If a `skills-reference` or `personal-skills-index` equivalent exists in the destination, add a new row:

```markdown
| [`<skill-name>/SKILL.md`](../<skill-name>/SKILL.md) | <One-sentence description> |
```

**3d. Commit**

```bash
cd "<worktree-path>"
git add "<skills-subdir>/$SKILL_NAME/"
git commit -m "Add $SKILL_NAME skill

<brief description of what the skill does and when to use it>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**3e. Push and open a draft PR**

```bash
git push -u origin $BRANCH
gh pr create \
  --title "Add $SKILL_NAME skill" \
  --body "<summary of what the skill does, why it was added, and any notes for reviewers>" \
  --draft \
  --base main \
  --repo "$GITHUB_REPO"
```

---

## Phase 4 — Wrap-up

Summarize what was created:
- Skill name and location
- What it does (one sentence)
- For employer skills: worktree path + draft PR link
- For personal skills: confirm it's live in `~/work/personal/ai-engineering/` and discoverable

Remind the user:
- **Personal skills** are immediately available — the agent discovers them on next session launch via `skillDirectories` (Copilot CLI)
- **Employer skills** need the PR reviewed and merged before they're available to the team

---

## Reference

- Personal skills library: `$HOME/work/personal/ai-engineering/skills/`
- Personal skills index: `$HOME/work/personal/ai-engineering/skills/personal-skills-index/SKILL.md`
- Skill conventions: study `assume-role`, `create-role`, and `session-reflect` as exemplars
