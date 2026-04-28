---
name: create-skill
description: Meta-skill for creating a new Copilot CLI skill. Gathers the skill's purpose, classifies it as Carrum Health-specific or personal/portable, then scaffolds the SKILL.md in the right place — a git worktree + draft PR in the developer repo for Carrum skills, or the personal skills library for portable ones.
---

# Skill: Create Skill

Use this skill when you want to create a new Copilot CLI skill from scratch.
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

### Carrum Health skill → `$CARRUM_HOME/developer/.github/skills/` (worktree + draft PR)

**Signals (any one of these → Carrum skill):**
- Uses `acli` (Atlassian CLI) for Jira operations
- References Carrum Jira projects: `TEC`, `PI`, or `INFRA`
- References Carrum services: `core-service-api`, `care-app-web`, `patient-app-mobile`, `care-service-api`, `message-service-api`, `upload-service`, `price-service`
- References `$CARRUM_HOME` or paths under the Carrum work directory
- Uses the `coding_agent` Jira label
- References Carrum documentation under `$CARRUM_HOME/developer/docs/`
- Specific to Carrum's ticket lifecycle, sprint workflow, or team conventions

---

### Personal/portable skill → `~/work/personal/copilot-skills/.github/skills/`

**Signals (all of these → personal skill):**
- Uses only general OS/CLI tools (`git`, `gh`, `bash`, `afplay`, `brew`, etc.)
- Would be useful at any company or on any project
- No references to Carrum-specific services, Jira projects, or internal docs

---

### When ambiguous

If signals are mixed or unclear, **always ask**:

**Use `ask_user`:**
> "I'm leaning toward classifying this as a [Carrum / Personal] skill because [specific reason]. Does that sound right?"

Choices: `["Yes — that's right", "No — make it Personal", "No — make it Carrum"]`

**Default lean:** personal if genuinely unsure — a personal skill is easier to migrate to Carrum later than vice versa.

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
PERSONAL_SKILLS="$HOME/work/personal/copilot-skills/.github/skills"
mkdir -p "$PERSONAL_SKILLS/$SKILL_NAME"
```

Write `$PERSONAL_SKILLS/$SKILL_NAME/SKILL.md` with:
- Frontmatter (`name`, `description`)
- Content based on the approved design from Phase 2
- Follow the conventions in existing skills: phase-driven structure, `ask_user` before destructive actions, code blocks for all commands

**3b. Update the personal skills index**

Add a new row to the `## Available Skills` table in:
`$HOME/work/personal/copilot-skills/.github/skills/personal-skills-index/SKILL.md`

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

### If Carrum Health Skill:

**3a. Create a git worktree**

Use a descriptive branch name (no Jira key needed for pure skill work):

```bash
cd $CARRUM_HOME/developer
BRANCH="add-<skill-name>-skill"
git worktree add $CARRUM_HOME/developer-$BRANCH -b $BRANCH
```

**3b. Scaffold the skill file**

```bash
SKILL_NAME="<skill-name>"
SKILL_DIR="$CARRUM_HOME/developer-$BRANCH/.github/skills/$SKILL_NAME"
mkdir -p "$SKILL_DIR"
```

Write `$SKILL_DIR/SKILL.md` with:
- Frontmatter (`name`, `description`)
- Content based on the approved design from Phase 2
- Phase-driven structure with `ask_user` confirmation gates
- Reference `$CARRUM_HOME/developer/.github/skills/` for any tool references

**3c. Update the skills-reference index**

Add a new row to the `## Available Skills` table in:
`$CARRUM_HOME/developer-$BRANCH/.github/skills/skills-reference/SKILL.md`

Row format:
```markdown
| [`<skill-name>/SKILL.md`](../<skill-name>/SKILL.md) | <One-sentence description> |
```

Keep rows in logical grouping order (reference skills first, then workflow/action skills).

**3d. Commit**

```bash
cd $CARRUM_HOME/developer-$BRANCH
git add .github/skills/$SKILL_NAME/ .github/skills/skills-reference/SKILL.md
git commit -m "Add $SKILL_NAME skill

<brief description of what the skill does and when to use it>

Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
```

**3e. Push and open a draft PR**

```bash
git push -u origin $BRANCH
```

Fill in the PR body using the template at `.github/PULL_REQUEST_TEMPLATE.md`. For skills PRs:
- **Summary**: What the skill does and why it was added
- **Jira Ticket**: Link if one exists, otherwise note "No ticket — skill addition"
- **Risk Level**: Low (new skill, no existing behavior changed)
- **AI Usage**: Check "Used AI to generate content or skills" + "I verified the accuracy and completeness"
- **Documentation Checklist**: Confirm frontmatter description is accurate, links resolve, markdown renders correctly, skills-reference index updated
- **Demo**: Paste example output or a short description of an invocation

```bash
gh pr create \
  --title "Add $SKILL_NAME skill" \
  --body "<filled-in PR body>" \
  --draft \
  --base main \
  --repo carrumhealth/developer
```

---

## Phase 4 — Wrap-up

Summarize what was created:
- Skill name and location
- What it does (one sentence)
- For Carrum skills: worktree path + draft PR link
- For personal skills: confirm it's live in `~/work/personal/copilot-skills/` and discoverable

Remind the user:
- **Personal skills** are immediately available — Copilot discovers them on next session launch via `skillDirectories`
- **Carrum skills** need the PR reviewed and merged before they're available to the team

---

## Reference

- Personal skills library: `$HOME/work/personal/copilot-skills/.github/skills/`
- Personal skills index: `$HOME/work/personal/copilot-skills/.github/skills/personal-skills-index/SKILL.md`
- Carrum skills: `$CARRUM_HOME/developer/.github/skills/`
- Carrum skills index: `$CARRUM_HOME/developer/.github/skills/skills-reference/SKILL.md`
- Carrum PR template: `$CARRUM_HOME/developer/.github/PULL_REQUEST_TEMPLATE.md`
- Carrum services: `$CARRUM_HOME/developer/docs/architecture/carrum-applications.md`
- Skill conventions: study `implement-ticket`, `create-story`, and `create-platform-idea` as exemplars
