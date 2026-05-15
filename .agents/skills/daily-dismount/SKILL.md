---
name: daily-dismount
description: End-of-day reflection and closing ritual for any role. Collects qualitative feedback, a Slack activity summary, checks for unreflected sessions, and writes a Daily Notes end-of-day entry celebrating accomplishments and surfacing workflow improvements.
---

# Skill: Daily Dismount

Use this skill at the end of the work day to close out cleanly. It gathers context from multiple sources — your words, your Slack activity, today's sessions — and produces an end-of-day note in Obsidian that helps you celebrate what got done and spot patterns worth improving.

---

## Path Resolution

Read `ROLES_DIR` and `VAULT_PATH` from `.agents/references/local.md` before executing any path-dependent steps.

```bash
cat .agents/references/local.md 2>/dev/null
```

Required values:
- `ROLES_DIR` — absolute path to `.agents/roles/`
- `VAULT_PATH` — absolute path to the Obsidian vault root

---

## Phase 1 — Qualitative Check-In

**Use `ask_user`:**
> "How would you describe today?"

Allow freeform. Store the response as `TODAY_VIBE`. This sets the emotional tone for the entire end-of-day note — use it as the opening framing.

---

## Phase 2 — Slack Summary

**Use `ask_user`:**
> "Paste your Slack daily summary below (from your automation), or skip if you don't have one today."

Allow freeform. If the user pastes a summary, store it as `SLACK_SUMMARY` and extract:
- Key threads or conversations participated in
- Decisions made or unblocked
- Items raised that may have become inbox/action items
- Any blockers surfaced by the team

If the user skips, note that the Slack summary was not included and continue.

---

## Phase 3 — Session Reflection Check

Find all role sessions from **today** that don't yet have a `session-reflection.md`. Check every role in `ROLES_DIR`:

```bash
TODAY=$(date +%Y-%m-%d)
ROLES_DIR="<from local.md>"
SESSION_STATE="$HOME/.copilot/session-state"

# For each role, find today's sessions from sessions.md
for role_dir in "$ROLES_DIR"/*/; do
    role=$(basename "$role_dir")
    sessions_file="$role_dir/state/sessions.md"
    [ -f "$sessions_file" ] || continue

    # Extract session IDs from today
    grep "^| $TODAY" "$sessions_file" | while IFS='|' read _ date session_id label _; do
        session_id=$(echo "$session_id" | tr -d ' ')
        label=$(echo "$label" | tr -d ' ')
        [ -z "$session_id" ] && continue
        [ "$session_id" = "—" ] && continue

        # Check if session-reflection.md exists
        reflection="$SESSION_STATE/$session_id/files/session-reflection.md"
        if [ ! -f "$reflection" ]; then
            echo "NO_REFLECTION|$role|$session_id|$label"
        else
            echo "REFLECTED|$role|$session_id|$label"
        fi
    done
done
```

Build a list of unreflected sessions. If none, skip to Phase 4.

If unreflected sessions exist, **automatically invoke the `session-reflect` skill for each one** — do not ask the user. Session reflection is always required before closing out; it feeds the memories and context that make future sessions better.

Invoke `session-reflect` for each unreflected session in sequence. After all reflections are complete, continue to Phase 4.

---

## Phase 4 — Gather Context

Pull from available sources to inform the end-of-day summary. Do all reads in parallel:

```bash
VAULT="<from local.md>"
TODAY=$(date +%Y-%m-%d)

# Today's daily plan (if it exists)
cat "$VAULT/Daily Plans/$TODAY Daily Plan.md" 2>/dev/null

# Today's inbox/email summary (if clean-inbox was run)
cat "$VAULT/Inbox Summaries/Email/$TODAY Email Summary.md" 2>/dev/null

# Today's session checkpoints (most recent role session)
SESSION_STATE="$HOME/.copilot/session-state"
# Read the most recent checkpoint from the current session
LATEST_SESSION=$(ls -td "$SESSION_STATE"/*/ 2>/dev/null | head -1)
LATEST_CHECKPOINT=$(ls "$LATEST_SESSION/checkpoints/"*.md 2>/dev/null | sort -r | head -1)
[ -n "$LATEST_CHECKPOINT" ] && cat "$LATEST_CHECKPOINT"

# Any 1:1 notes created today (check for today's date in People/One on Ones/)
find "$VAULT/People/One on Ones" -name "$TODAY.md" 2>/dev/null | while read f; do
    echo "=== $(dirname $f | xargs basename) 1:1 ==="
    cat "$f"
done

# Gemini meeting notes from today (titles only — from index)
grep "$TODAY" "$VAULT/Meeting Notes/Gemini Index.md" 2>/dev/null
```

Also draw from the current conversation history — all work done this session is in context.

---

## Phase 5 — Write End of Day Note

Write to `$VAULT/Daily Notes/$TODAY End of Day.md`.

If the file already exists, ask:

**Use `ask_user`:**
> "An End of Day note already exists for today. What would you like to do?"

Choices: `["Overwrite it", "Append to it"]`

**Template:**

```markdown
# End of Day — YYYY-MM-DD

> _"<TODAY_VIBE — the user's own words>"_

---

## 🎉 Accomplishments

What actually got done today — stated as wins, not tasks. Be specific and generous.

- [Win 1]
- [Win 2]
- ...

---

## 📅 Meetings & Conversations

| Meeting | Key Outcome |
|---|---|
| [Meeting name] | [Decision, action, or insight] |

---

## 💬 Slack Highlights

_[Extracted from Slack summary — key threads, decisions, or team moments worth remembering. Omit if no summary was provided.]_

- [Highlight 1]
- [Highlight 2]

---

## 🔁 Carry-Over Work

Items that didn't close today — and why. The goal is to understand the pattern, not judge it.

| Item | Why It Carried Over | Priority Tomorrow |
|---|---|---|
| [Item] | [Reason: meeting-heavy day / blocked / deprioritized] | 🔴 / 🟡 / 🟢 |

---

## 🧠 Workflow Observations

Honest reflection on how the day flowed. Look for patterns:
- Was today too parallel? (Too many things in flight at once?)
- Were there context-switching costs that slowed things down?
- What would have made today smoother?
- What can be delegated or automated?

_[2–4 honest sentences]_

---

## 🚀 Top 3 for Tomorrow

The three things that matter most tomorrow morning, in priority order.

1. [Most important]
2. [Second]
3. [Third]

---

_Closed: [TIME] — [brief weather/energy note if user mentioned it]_
```

**Writing guidelines:**
- Lead with accomplishments — even on hard days, something got done. Name it specifically.
- Carry-over items should be explained, not just listed. The pattern matters.
- Workflow Observations is the highest-value section for long-term improvement. Don't skip it even if brief.
- Top 3 for tomorrow should come from the inbox summary + carry-over list, not invented.
- Keep the tone honest and warm — this is a personal document, not a status report.

---

## Phase 6 — Confirm and Close

Display the full end-of-day note in the conversation (or a summary if it's long).

Report:
- Path to the note in Obsidian
- Whether session reflections are pending
- Top 3 for tomorrow (repeat for easy recall)

Then sign off:

> _"You're done for today. 🎉 Go be a human."_

---

## Reference

- **Daily Notes location:** `$VAULT_PATH/Daily Notes/YYYY-MM-DD End of Day.md`
- **Daily Plans location:** `$VAULT_PATH/Daily Plans/YYYY-MM-DD Daily Plan.md`
- **Inbox summary location:** `$VAULT_PATH/Inbox Summaries/Email/YYYY-MM-DD Email Summary.md`
- **Session state:** `~/.copilot/session-state/<SESSION_ID>/`
- **Session reflections:** `~/.copilot/session-state/<SESSION_ID>/files/session-reflection.md`
- **Roles directory:** set in `.agents/references/local.md` as `ROLES_DIR`
- **Related skills:** `session-reflect`, `clean-inbox`, `prepare-daily-plan`
