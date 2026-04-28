---
name: dream
description: Consolidate and prune a role's memories by reviewing recent session checkpoints. Classifies each memory as durable or transient, elevates new insights from sessions, and produces a refined memories.md for human review before writing.
---

# Skill: dream

Memory consolidation for a role persona. Like REM sleep: replay recent experiences, strengthen durable patterns, prune transient specifics, wake up with higher-quality memory.

Memories naturally accumulate two kinds of content:
- **Durable patterns** — behavioral rules, conventions, architectural principles. These age well.
- **Transient specifics** — version details, library syntax, tool workarounds. These rot as tools evolve.

The existing `manage-role` → `Consolidate memories` compresses by age. This skill consolidates by **quality** — discriminating what should survive long-term from what was useful in the moment.

---

## Phase 0 — Intake

### 0a — Select role

```bash
ls -d ~/work/personal/ai-engineering/agents/*/ 2>/dev/null | xargs -I{} basename {}
```

**Use `ask_user`:**
> "Which role should we dream for?"
Choices: list of discovered role names.

Store as `ROLE_NAME`. Verify `~/work/personal/ai-engineering/agents/<ROLE_NAME>/memories.md` exists; abort if not.

### 0b — Set scope

**Use `ask_user`:**
> "How far back should we look for session context?"
Choices:
- `All sessions tracked in sessions.md`
- `Sessions since last dream`
- `Last 5 sessions`
- `Last 10 sessions`

Store as `SCOPE`.

Read `~/work/personal/ai-engineering/agents/<ROLE_NAME>/sessions.md` to get the list of session IDs. Apply the scope filter:
- "All sessions" → use all rows
- "Since last dream" → look for a `[dream]` marker in sessions.md; use rows after it. If no marker, fall back to all.
- "Last N sessions" → use the N most recent rows (by date, newest-first in the table)

Store the resulting list as `SESSION_IDS`.

---

## Phase 1 — Gather

Read the raw material for the synthesis subagent.

### 1a — Role context

```bash
cat ~/work/personal/ai-engineering/agents/<ROLE_NAME>/instructions.md
cat ~/work/personal/ai-engineering/agents/<ROLE_NAME>/memories.md
```

### 1b — Session checkpoints

For each session ID in `SESSION_IDS`:

```bash
SESSION_DIR="$HOME/.copilot/session-state/<SESSION_ID>"

# Check if the session exists and has checkpoints
if [ -d "$SESSION_DIR/checkpoints" ]; then
  cat "$SESSION_DIR/checkpoints/index.md" 2>/dev/null
  # Read each checkpoint file listed in the index
  for f in "$SESSION_DIR/checkpoints/"*.md; do
    [ "$f" != "$SESSION_DIR/checkpoints/index.md" ] && cat "$f"
  done
fi
```

If a session ID doesn't exist on disk, skip it silently.

Compile all gathered content into a structured brief:

```
=== ROLE: <ROLE_NAME> ===

--- instructions.md ---
<content>

--- memories.md (current) ---
<content>

--- Session Checkpoints ---
[Session <ID> — <date from sessions.md>]
<checkpoint index>
<checkpoint content>

[Session <ID> — ...]
...
```

---

## Phase 2 — Dream (Synthesis Subagent)

Spawn a `general-purpose` subagent with the compiled brief and the following instructions:

---

**Subagent prompt:**

You are performing memory consolidation for a Copilot CLI role persona. You have been given:
1. The role's `instructions.md` — what this role cares about, its goals and communication style
2. The role's current `memories.md` — accumulated memories from past sessions
3. Checkpoint summaries from recent sessions — what was worked on and learned

Your job is to produce a refined, pruned, consolidated version of `memories.md`. Apply these principles:

**Prune aggressively:**
- Implementation-specific details that will rot: library syntax, version-specific workarounds, tool flags (`git worktree`, `Marp --allow-local-files`, etc.)
- One-off fixes for bugs that are now resolved
- Project-specific state that is no longer active (e.g., "we're currently on PROJ-1234")
- Entries that simply document how to use a tool — these belong in docs, not memories

**Keep and elevate:**
- Behavioral rules that tell the role HOW to act (not what tool to use)
- Conventions the team has agreed on (process, code review norms, branching strategy)
- Earned insights about problem patterns (e.g., "closed-loop tests prove self-consistency, not spec conformance")
- Meta-lessons about working with the user (e.g., "stop after 3 failed attempts, ask")

**Consolidate:**
- Multiple overlapping entries about the same pattern → one clean principle
- Specific examples that together illustrate a general rule → one generalized rule, keep the best example

**Elevate from sessions:**
- Look for insights in the session checkpoints that are NOT yet in memories but are durable enough to keep

**Output format:**

Produce a new `memories.md` using this structure:

```markdown
## Behavioral Patterns

- <durable rule about HOW the role should act>
- ...

## Conventions & Policies

- <agreed-upon team or process conventions>
- ...

## Domain Insights

- <earned knowledge about problem patterns, architecture, or design — abstracts above specific tools>
- ...

## Active Context

- <things that are useful right now but should be reviewed at the next dream — flag with [expires: <reason>]>
- ...
```

Then produce a **change summary** in this format:

```
=== DREAM SUMMARY ===

KEPT (<N>):
- "<entry excerpt>" — reason kept

REFINED (<N>):
- ORIGINAL: "<entry excerpt>"
  REFINED:  "<new entry>"
  REASON:   <why abstracted>

PRUNED (<N>):
- "<entry excerpt>" — reason pruned

NEW (<N>):
- "<new entry>" — sourced from session <ID>
```

---

Wait for the subagent to complete. Store its output as `DREAM_OUTPUT` (the new `memories.md` content) and `DREAM_SUMMARY` (the change summary block).

---

## Phase 3 — Review

Show the user the change summary first:

```
Here's what the dream found:

<DREAM_SUMMARY>
```

Then show the full proposed `memories.md`:

```
Here's the proposed new memories.md:

<DREAM_OUTPUT>
```

**Use `ask_user`:**
> "Ready to write this to `~/work/personal/ai-engineering/agents/<ROLE_NAME>/memories.md`?"
Choices:
- `Write it — looks good`
- `Make changes first`
- `Discard — don't write`

If "Make changes first": ask for freeform feedback, revise the output accordingly (either manually or by re-prompting the synthesis subagent with the feedback), then return to this step.

If "Discard": confirm and stop. The current `memories.md` is unchanged.

---

## Phase 4 — Write

1. Back up the current file:

```bash
cp ~/work/personal/ai-engineering/agents/<ROLE_NAME>/memories.md \
   ~/work/personal/ai-engineering/agents/<ROLE_NAME>/memories.md.pre-dream-$(date +%Y%m%d)
```

2. Write the new content:

```bash
cat > ~/work/personal/ai-engineering/agents/<ROLE_NAME>/memories.md << 'DREAM_EOF'
<DREAM_OUTPUT>
DREAM_EOF
```

3. Mark the dream in `sessions.md` by appending a marker row:

```bash
echo "| $(date +%Y-%m-%d) | — | [dream completed] |" >> ~/work/personal/ai-engineering/agents/<ROLE_NAME>/sessions.md
```

4. Confirm:

```bash
cat ~/work/personal/ai-engineering/agents/<ROLE_NAME>/memories.md
```

Show the user the final state and the backup file path.

---

## Notes

- The backup (`.pre-dream-YYYYMMDD`) allows instant rollback: `cp memories.md.pre-dream-YYYYMMDD memories.md`
- If `sessions.md` is empty or the role has no tracked sessions, Phase 1b will produce no checkpoint content — the dream will consolidate existing memories only, with no new session insights
- The `[dream completed]` marker in `sessions.md` is how "Since last dream" scoping works in future runs
- The synthesis subagent is separate from the main agent intentionally — asking the main agent to synthesize its own generated content has consolidation bias (this lesson from the brainstorm skill applies here too)

---

## Reference

- `assume-role` — load a role's instructions and memories into a session
- `remember` — append a new memory entry to a role
- `manage-role` → "Consolidate memories" — lighter, date-based consolidation
- Roles directory: `~/work/personal/ai-engineering/agents/`
