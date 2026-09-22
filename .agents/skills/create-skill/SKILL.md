---
name: create-skill
description: Meta-skill for creating a new agent skill. Gathers the skill's purpose, classifies it as employer-specific or personal/portable, then scaffolds the SKILL.md in the right place — a git worktree + draft PR for employer skills, or the personal skills library for portable ones. Treats business-specific logic, internal identifiers, source paths, workflow details, and credentials as local-only by default, routed to a gitignored references/local.md overlay instead of the committed file.
---

# Skill: Create Skill

Use this skill when you want to create a new agent skill from scratch.
It will ask you what you want to build, classify the skill, scaffold the file, and land it in the right place.

**Quality gate:** Before scaffolding, check `session-reflect/docs/skill-proposal-rubric.md`. A skill should pass at least 4 of the 5 rubric gates. If it doesn't, suggest logging it as a `[skill-candidate]` memory entry instead and waiting for recurrence.

---

## Phase 0 — Intake

Ask the user what they want to build:

**Use `ask_user`:**
> "What skill do you want to create? Describe what it should do, what inputs it takes, and what it produces. A sentence or two is fine."

Allow freeform. Capture: purpose, likely inputs, likely outputs, and any tools or services it uses.

---

## Phase 1 — Classify: Where Does This Skill Live?

Evaluate the skill description and determine its destination. There are four possibilities.

### Is this actually a role, not a skill?

If the description sounds like a **persistent persona** — a "mode of operation", an assistant with standing goals and communication style — it's a role, not a skill.

**Signals:** the user says "role", "assistant", "persona", or describes ongoing behavior rather than a discrete task.

**If so:** don't create a skill. Tell the user:
> "This sounds more like a role than a skill — a persistent persona loaded by `assume-role`. Want me to invoke `create-role` instead?"
Choices: `["Yes — create a role", "No — it's still a skill"]`

---

### Personal/portable skill → this repo's `.agents/skills/`

**Signals (all of these → personal skill):**
- Uses only general OS/CLI tools (`git`, `gh`, `bash`, `afplay`, `brew`, etc.)
- Would be useful at any company or on any project
- No references to internal services, proprietary tooling, or org-specific workflows

---

### Role-specific skill → `.agents/roles/<role-name>/skills/`

Skills that are specific to one role's workflow and make most sense loaded alongside that role's instructions. These are committed alongside the role and automatically surfaced when `assume-role` loads that role.

**Signals:**
- Designed to be invoked primarily when operating as a specific role
- Encodes a workflow that's meaningful in the context of that role's goals
- Not necessarily useful outside that role's operating context

**If so:** ask which role it belongs to:
> "Which role should this skill live under?"
Choices: list of role names from `.agents/roles/`

Store as `$ROLE_NAME`. Skill will be created at `.agents/roles/$ROLE_NAME/skills/<skill-name>/SKILL.md`.

---

### Employer/project skill → ask for destination

If the skill references internal tools, services, or org-specific workflows, it doesn't belong in the personal library.

**Use `ask_user`:**
> "Where should this skill live? Provide the path to the skills directory (e.g. `/path/to/repo/.agents/skills/`, `/path/to/repo/.github/skills/`, or another tool-specific skills directory)."

Allow freeform. Store as `$SKILLS_DEST`.

Also ask:
**Use `ask_user`:**
> "What GitHub repo should the PR be opened against? (e.g. `org/repo`)"

Allow freeform. Store as `$GITHUB_REPO`.

---

### When ambiguous

If it's unclear which destination applies, **always ask**:

**Use `ask_user`:**
> "Where should this skill live?"

Choices: `["Personal library (portable)", "Under a specific role", "Employer/project repo — I'll provide the path"]`

**Default lean:** personal if genuinely unsure — easier to move later.

---

## Phase 2 — Design the Skill

Based on the user's description, draft the key design decisions:

1. **Skill name** — kebab-case, descriptive (e.g., `setup-local-env`, `summarize-pr`, `osx-sounds`)
2. **One-sentence description** — for the frontmatter `description` field and the skills index
3. **Phases or sections** — outline what the skill will do step by step
4. **Key tools** — what commands, APIs, or CLIs the skill uses
5. **Inputs/outputs** — what the user provides, what the skill produces
6. **Local-only content** — scan the description and outline for anything covered by "Local-only by default" (Phase 3): proprietary business logic, internal identifiers, source paths, workflow details, or credentials. List each item found and note that it will live in `references/local.md` (gitignored) rather than the committed `SKILL.md`. If nothing applies, note that explicitly.

Present the design as a brief outline.

**Use `ask_user`:**
> "Here's my proposed design for the skill. Does this look good, or do you want to adjust anything?"

Include choices: `["Looks good — write it", "I want to adjust something"]`.
Do not proceed until approved.

---

## Phase 3 — Scaffold the Skill

### Skill directory layout

Every skill gets exactly one `SKILL.md` at the directory root. Use semantic subdirectories for everything else — never place additional files directly beside `SKILL.md`:

| Path | Purpose | Committed? |
|------|---------|------------|
| `SKILL.md` | Skill definition | ✅ Yes |
| `docs/` | Rubrics, templates, examples, supporting reference docs — including `docs/local.example.md`, a committed **template** showing the shape of `references/local.md` with placeholder values only | ✅ Yes |
| `references/` | Business/team/machine-specific overlay: real org names, internal identifiers, source paths, workflow details, credentials, and any other non-portable configuration | ❌ No (git-ignored) |

Create `docs/` only if the skill has supporting documents to commit. Create `references/` (with a matching `docs/local.example.md` template) and add the `## Local References` boilerplate below to `SKILL.md` whenever the skill's design touches anything business-specific — see "Local-only by default" next.

---

### Local-only by default

Business-specific details are **local-only by default**, not just "when obviously needed." Before writing `SKILL.md`, review the approved design from Phase 2 and route anything in the following categories out of the committed file and into a gitignored `references/local.md` overlay instead:

- **Proprietary or business-specific logic** — org-specific rules, decision criteria, or workflow steps that only make sense for one employer/team
- **Internal identifiers** — project/board keys (e.g. Jira project codes), pod/team names, ticket prefixes, environment or service names
- **Source paths** — absolute filesystem paths, internal repo names, internal URLs/domains, vault or notes locations specific to one machine or org
- **Workflow details** — internal Slack/Jira/CI conventions, escalation paths, approval chains, or any process specific to one organization
- **Credentials or secrets** — API keys, tokens, account names, auth details of any kind (these never belong in *either* the committed file or `references/local.md` in plaintext beyond a placeholder — treat `references/local.md` as gitignored config, not a secrets store)

Committed `SKILL.md` content should describe generic, portable behavior and read optional values from the overlay, falling back to asking the user or to safe generic defaults when the overlay is absent. This applies to every destination — personal, role-specific, and employer/project skills alike.

**When the skill needs a local overlay, add this boilerplate to `SKILL.md`** (adjust the description to the skill's actual keys):

````markdown
## Local References (optional)

Before running, check for local configuration:

```bash
cat "$(dirname "$0")/references/local.md" 2>/dev/null || echo "(no local overlay — using defaults/prompts)"
```

`references/local.md` is git-ignored and never committed. See `docs/local.example.md` for the
supported keys and their format. Treat any value not set there as unknown — fall back to asking
the user or to generic, org-agnostic behavior.
````

Pair it with a committed `docs/local.example.md` containing only placeholder values (`YOURPROJECT`, `/Users/yourname/...`, `your-org`, etc.) and comments explaining each key — never real values.

**Verify the ignore rule before writing any local content:**

```bash
git check-ignore -v "<skill-dir>/references/local.md"
```

If nothing matches, the destination repo's `.gitignore` is missing coverage. Add the narrowest rule that fits its existing conventions (e.g. `.agents/skills/*/references/` if that pattern already exists for other skills, or a skill-specific `<skill-dir>/references/` line otherwise) **before** any real local values are written to disk, and confirm again with `git check-ignore -v`.

---

### If Personal Skill:

**3a. Create the skill directory and file**

```bash
SKILL_NAME="<skill-name>"
PERSONAL_SKILLS="<repo-root>/.agents/skills"
mkdir -p "$PERSONAL_SKILLS/$SKILL_NAME"
# Only create docs/ if this skill has supporting documents to commit:
# mkdir -p "$PERSONAL_SKILLS/$SKILL_NAME/docs"
```

Write `$PERSONAL_SKILLS/$SKILL_NAME/SKILL.md` with:
- Frontmatter (`name`, `description`)
- Content based on the approved design from Phase 2 — generic and portable, with any local-only items identified in Phase 2 step 6 read from `references/local.md` instead of hardcoded
- Follow the conventions in existing skills: phase-driven structure, `ask_user` before destructive actions, code blocks for all commands

If Phase 2 step 6 identified any local-only content, also:

```bash
mkdir -p "$PERSONAL_SKILLS/$SKILL_NAME/docs" "$PERSONAL_SKILLS/$SKILL_NAME/references"
```

- Write `docs/local.example.md` with placeholder values only (never real org names, paths, or identifiers) and add the `## Local References` boilerplate to `SKILL.md` (see "Local-only by default" above).
- Do **not** create `references/local.md` with real values as part of this scaffolding step — that is filled in locally by whoever uses the skill, never by `create-skill` itself, and must never be committed.
- Verify coverage: `git check-ignore -v "$PERSONAL_SKILLS/$SKILL_NAME/references/local.md"`. This repo's `.gitignore` already excludes `.agents/skills/*/references/`, so this should already match; if it doesn't, stop and fix the gitignore before proceeding.

**3b. Update the personal skills index**

Add a new row to the `## Available Skills` table in:
`<repo-root>/.agents/skills/personal-skills-index/SKILL.md`

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

### If Role-Specific Skill:

**3a. Create the skill directory under the role**

```bash
SKILL_NAME="<skill-name>"
ROLE_SKILLS="<repo-root>/.agents/roles/$ROLE_NAME/skills"
mkdir -p "$ROLE_SKILLS/$SKILL_NAME"
```

Write `$ROLE_SKILLS/$SKILL_NAME/SKILL.md` with:
- Frontmatter (`name`, `description`)
- Content based on the approved design from Phase 2 — generic within the role's own operating scope, with any local-only items identified in Phase 2 step 6 read from `references/local.md` instead of hardcoded
- Phase-driven structure with `ask_user` before destructive actions

If Phase 2 step 6 identified any local-only content, also create `docs/local.example.md` (placeholder values only) and add the `## Local References` boilerplate to `SKILL.md` (see "Local-only by default" above). Verify with `git check-ignore -v "$ROLE_SKILLS/$SKILL_NAME/references/local.md"` — this repo's `.gitignore` already excludes `.agents/roles/*/skills/*/references/`. Never create `references/local.md` itself with real values as part of scaffolding.

The skill will be automatically surfaced when `assume-role` loads `$ROLE_NAME`.

**3b. Confirm**

```bash
cat "$ROLE_SKILLS/$SKILL_NAME/SKILL.md"
ls "$ROLE_SKILLS/"
```

No skills index update needed — role skills are discovered from the `skills/` directory at briefing time.

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

**Credentials are never committed, in any destination.** Even in an employer repo where business logic and internal identifiers legitimately belong in the committed `SKILL.md`, machine-specific or secret values (API keys, tokens, personal account names, local file paths that vary per developer) still belong in a gitignored `references/local.md`, never in the committed file.

If Phase 2 step 6 identified any local-only content (credentials, or machine-specific paths/identifiers that shouldn't be shared even within the org), also:

```bash
mkdir -p "$SKILL_DIR/docs" "$SKILL_DIR/references"
git -C "<worktree-path>" check-ignore -v "<skills-subdir>/$SKILL_NAME/references/local.md"
```

If `check-ignore` reports no match, the destination repo's `.gitignore` doesn't yet exclude skill-local overlays. Add the narrowest rule that fits its existing conventions (mirror an existing pattern if one covers other skills' `references/` dirs, otherwise add a skill-specific `<skills-subdir>/$SKILL_NAME/references/` line) as part of this same change, then confirm again with `check-ignore` before writing any real local values. Write `docs/local.example.md` with placeholder values only, and add the `## Local References` boilerplate to `SKILL.md` (see "Local-only by default" above).

**3c. Update the skills index**

If a `skills-reference` or `personal-skills-index` equivalent exists in the destination, add a new row:

```markdown
| [`<skill-name>/SKILL.md`](../<skill-name>/SKILL.md) | <One-sentence description> |
```

**3d. Commit**

```bash
cd "<worktree-path>"
git add "<skills-subdir>/$SKILL_NAME/"
git status  # confirm no references/local.md, credentials, or secrets are staged
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
- Whether any local-only overlay was scaffolded (`references/` + `docs/local.example.md`), and confirm it's gitignored — never report a local overlay as "committed"
- For employer skills: worktree path + draft PR link
- For personal skills: confirm it's live in this repo's `.agents/skills/` and will be discoverable through any configured global skill link

Remind the user:
- **Personal skills** are available after the relevant agent restarts or reloads its configured skill directory
- **Employer skills** need the PR reviewed and merged before they're available to the team
- If a local overlay was scaffolded, the user (or whoever adopts the skill) still needs to copy `docs/local.example.md` to `references/local.md` and fill in real values locally — `create-skill` never does this on their behalf

---

## Reference

- Personal skills library: this repo's `.agents/skills/`
- Personal skills index: `<repo-root>/.agents/skills/personal-skills-index/SKILL.md`
- Skill conventions: study `assume-role`, `create-role`, and `session-reflect` as exemplars
- Local-overlay convention: study `obsidian-vault`, `read-apple-mail`, `clean-inbox`, or `weekly-impact-recap` for worked examples of `references/local.md` + `docs/local.example.md`
