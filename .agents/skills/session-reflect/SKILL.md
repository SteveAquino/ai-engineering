---
name: session-reflect
description: At the end of a work session, generate a structured reflection document covering what was built, where the agent got stuck, novel patterns, memories to persist, and skills worth codifying. Optionally routes memories to a role and creates skill proposal files.
---

# Skill: Session Reflect

Use this skill at the end of a work session to capture learnings before they're lost to context summarization. It produces a reflection document, then routes findings to the right places — role memories, skill proposals, or both.

---

## Phase 0 — Locate Session Context

Read `SESSION_DIR` from `.agents/references/local.md`:

```bash
SESSION_DIR=$(grep "^SESSION_DIR=" .agents/references/local.md | cut -d= -f2-)
echo "Session: $SESSION_DIR"
ls "$SESSION_DIR" 2>/dev/null || echo "(session dir not yet created)"
ls "$SESSION_DIR/files/" 2>/dev/null || echo "(no files yet)"
ls "$SESSION_DIR/checkpoints/" 2>/dev/null | head -10
```

If an existing `session-reflection.md` is found in `files/`, read it:

```bash
cat "$SESSION_DIR/files/session-reflection.md" 2>/dev/null
```

Decide whether to regenerate from scratch or extend the existing file. If one exists, ask:

**Use `ask_user`:**
> "I found an existing `session-reflection.md` for this session. Do you want to update it or start fresh?"
Choices: `["Update the existing file", "Start fresh"]`

---

## Phase 1 — Read Source Material

Gather context from session artifacts before writing:

```bash
# Read plan.md if it exists
cat "$SESSION_DIR/plan.md" 2>/dev/null

# Read the most recent checkpoint
LATEST_CHECKPOINT=$(ls "$SESSION_DIR/checkpoints/"*.md 2>/dev/null | sort -r | head -1)
[ -n "$LATEST_CHECKPOINT" ] && cat "$LATEST_CHECKPOINT"
```

Also draw from the current conversation history visible in context — including summaries, tool calls, outcomes, errors encountered, and pivots made.

---

## Phase 2 — Generate Reflection Document

Write the reflection to `$SESSION_DIR/files/session-reflection.md`.

**Template:**

```markdown
# Session Reflection — [TICKET or TOPIC]
_[DATE]_

## What We Built
[Brief description of the deliverable — what exists now that didn't before]

## Where I Got Stuck (and How I Got Unstuck)
[One section per friction point]

### [Friction point title]
- **Problem:** [What went wrong or was unclear]
- **Pivot/fix:** [What resolved it]
- **Learning:** [Durable takeaway]

## What Was New and Novel
- [Pattern, tool, or approach used for the first time]
- [...]

## Potential Memories to Record
| Memory | Why It Matters |
|---|---|
| [Durable fact phrased as a rule] | [Why future sessions would benefit] |

## Potential Skills to Codify
### [Skill name]
**What it does:** [One sentence]
**Why codify it:** [What problem it solves]
**Key steps:** [Rough recipe — enough to implement from this brief]

## Meta-Observations
[Anything worth noting about how the session went — agent behavior, tool limitations, workflow gaps]
```

**Writing guidelines:**
- Write in the agent's voice — capture what *the agent* learned, not just what the user did
- Memories must be phrased as durable facts: "Always X" / "Use Y for Z" — not "In this session, X happened"
- Skill proposals should be concrete enough that a future `create-skill` invocation could use them directly as the brief
- Be honest about friction — where things broke, where tools were missing, where the agent had to guess

After writing, open the file in VS Code for immediate review:

```bash
code "$SESSION_DIR/files/session-reflection.md"
```

Then display the reflection in the conversation and confirm it captures the session accurately.

---

## Phase 3 — Route Memories

**Use `ask_user`:**
> "Would you like me to append the key memories to a role now?"
Choices: `["Yes — choose a role", "No — I'll review the file first"]`

If yes: follow the `remember` skill flow.

```bash
# List available roles
ls .agents/roles/
```

For each memory in the "Potential Memories to Record" table, append it to the chosen role's `memories.md` with a timestamp. Follow the same format as the `remember` skill:

```
[YYYY-MM-DD] <Memory text>
```

---

## Phase 4 — Route Skill Proposals

**Apply the quality rubric before proposing any skill.** Read `docs/skill-proposal-rubric.md` (in the `docs/` subdirectory next to this SKILL.md) and score each candidate against the five gates. A candidate that passes 4+ gates is ready to propose. A candidate that passes fewer than 4 should be logged as a `[skill-candidate]` memory entry instead — not a proposal file.

**`[skill-candidate]` memory format** (for borderline/first-occurrence patterns):
```
[skill-candidate] `<proposed-name>`: <one-sentence description>. First seen: <date or session ID>.
```
Route these to the active role's `memories.md` via the `remember` skill rather than creating a proposal file.

**Use `ask_user`:**
> "Would you like me to create proposal markdown files for the skills identified?"
Choices: `["Yes — create proposal files", "No — skip"]`

If yes: for each skill that **passed the rubric** (4+ gates), write a proposal file to `$SESSION_DIR/files/skill-proposal-<skill-name>.md`.

**Proposal file template:**

```markdown
# Skill Proposal: `<skill-name>`

**Category:** [Personal / Employer-specific]
**Suggested location:** `~/.agents/skills/<skill-name>/`

---

## Purpose
[One paragraph description]

## Problem It Solves
[What goes wrong without this skill]

## Proposed Behavior
[Phase-by-phase outline]

## Key Notes
[Important constraints, conventions, or edge cases]
```

After creating proposal files, list them:

```bash
ls "$SESSION_DIR/files/"skill-proposal-*.md 2>/dev/null
```

Remind the user: invoke `create-skill` with any of these proposals as the brief to build them out.

---

## Phase 5 — Wrap-up

Summarize what was produced:
- Path to `session-reflection.md`
- Number of memories routed (if any)
- Skill proposal files created (if any)

Suggest next steps:
- Review `session-reflection.md` and refine before the session closes
- Invoke `create-skill` for any skill proposals worth building now
- Invoke `remember` for any memories not yet routed

---

## Reference

- Session dir: read from `.agents/references/local.md` as `SESSION_DIR`
- Roles: `.agents/roles/`
- Memory routing: invoke `remember` skill
- Skill creation: invoke `create-skill` skill with a proposal file as the brief
