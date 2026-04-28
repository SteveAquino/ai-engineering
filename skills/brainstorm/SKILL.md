---
name: brainstorm
description: Spawns parallel subagents to explore a problem from multiple perspectives, iterates through 3 rounds of debate (including a cross-debate and adversary pass), and saves a structured summary with falsifiable predictions and irreconcilable tensions to the session-state folder.
---

# Skill: Brainstorm

Use this skill when you want to think deeply about a problem, decision, or design challenge from multiple angles. Domain-adapted roles debate in parallel, an adversary challenges every synthesis, agents directly rebut each other in Round 2, and the process converges over 3 rounds to a concrete, implementable consensus. The result is saved as a structured markdown file in the current session state.

> **What changed (2026-04-24):** Overhauled based on parallel experiments across 4 structural variants. Key improvements: domain-adapted roles instead of generic archetypes, stricter agent prompts (concrete examples + falsifiable predictions required), adversary subagent after Round 1, paired cross-debate in Round 2, 3 rounds default, dedicated synthesizer subagent, new output sections (Falsifiable Predictions table, Irreconcilable Tensions).

---

## Phase 0 — Intake

**Use `ask_user`:**
> "What problem or topic do you want to brainstorm? Describe it in as much detail as you'd like."

Allow freeform. Capture the full problem description — more context produces better role selection.

Then ask:

**Use `ask_user`:**
> "How many perspectives should explore the problem?"
Choices: `["4 (Recommended)", "3", "5", "6"]`

Then ask:

**Use `ask_user`:**
> "How many rounds of iteration?"
Choices: `["3 (Recommended)", "2", "4"]`

Set variables:
- `PROBLEM`: the problem description
- `N_PERSPECTIVES`: integer
- `N_ROUNDS`: integer
- `SLUG`: lowercase hyphenated slug of the topic, max 40 chars

Classify the problem type:
- **Organizational/operational** (team processes, decisions, priorities, workflows) → use **domain-adapted stakeholder roles**
- **Technical architecture** (system design, technology choices, infrastructure) → use **domain-adapted technical roles**
- **Abstract/philosophical** (ethics, strategy, first-principles thinking) → use **archetype pool** (fallback only)

---

## Phase 1 — Select Roles

### If organizational or technical problem (default):

Select `N_PERSPECTIVES` roles from the **actual stakeholder map** for this problem. Do not use generic archetypes unless no real roles apply.

For each selected role, explain **why this specific role is critical for this specific problem** — not just what the role does generically.

Present the role table before proceeding:

| Role | Why This Role Matters Here |
|---|---|
| `<Role Name>` | `<Why their specific failure modes, constraints, or knowledge are load-bearing for this problem>` |

**Example domain roles by problem type:**

*Engineering process/team:* Engineering Manager, Staff Engineer, Product Manager, Senior Engineer (IC)

*Rails/backend architecture:* Tech Lead, DevOps/Platform Engineer, Product Manager, Senior Backend IC

*Product strategy:* CEO/Founder, Head of Product, Lead Engineer, Customer Success Lead

*Security/compliance:* Security Engineer, Product Manager, Engineering Manager, Legal/Compliance

### If abstract/philosophical problem (fallback):

Choose `N_PERSPECTIVES` from:

| Archetype | Lens |
|---|---|
| **Skeptic** | Challenges assumptions, identifies risks, "what could go wrong?" |
| **Optimist** | Upside potential, opportunities, best-case paths |
| **Technical Architect** | Implementation feasibility, system design, technical trade-offs |
| **End-User Advocate** | Human experience, usability, user needs |
| **Systems Thinker** | Second-order effects, feedback loops, emergent behavior |
| **Pragmatist** | Practical, deliverable, incrementally valuable |
| **Contrarian** | Argues the opposite of apparent consensus |
| **Domain Expert** | Deep subject-matter knowledge for this field |

---

## Phase 2 — Round 1: Diverge

Spawn `N_PERSPECTIVES` parallel `general-purpose` subagents — one per role. Launch **all in a single response** using `mode: "background"`. Wait for all to complete, then read with `read_agent`.

**Agent prompt template:**

```
You are analyzing the following problem through a specific role.

## Problem

<PROBLEM>

## Your Role: <ROLE NAME>

<ROLE DESCRIPTION AND WHY THIS ROLE MATTERS FOR THIS PROBLEM>

Analyze from your assigned role. You must be concrete and specific — no abstract principles.

Your response MUST include each of these 5 sections:

1. **Core Thesis** — Your central claim in 1–2 sentences. Make it falsifiable.

2. **Concrete Example** — Commit to a specific, realistic scenario with named details (technology, team size, cost, timeline). Do NOT write "imagine a team that..." — write "A team of N engineers with X system doing Y. Here is how I would handle Z..." Ground your entire argument in this example.

3. **The Steelman** — State the STRONGEST version of the argument against your position — the best case a smart opponent would make. Then explain why you still hold your position despite it.

4. **Falsifiable Prediction** — A specific, testable claim: "If this team does X, within Y timeframe they will observe Z. If they do NOT observe Z, my position is wrong." Be specific about the timeframe and the observable outcome.

5. **The Most Dangerous Assumption** — What is the single most dangerous unexamined assumption embedded in how most people approach this problem? Name it. Explain why it's dangerous. Your position should account for it.
```

---

## Phase 3 — Round 1 Synthesis (Dedicated Synthesizer Subagent)

Do NOT synthesize the Round 1 outputs yourself. Spawn a dedicated `general-purpose` synthesizer subagent. Give it all `N_PERSPECTIVES` raw Round 1 responses. Wait for it to complete.

**Synthesizer prompt:**

```
You are a synthesis agent. You have received responses from <N> different roles on the following problem.

## Problem

<PROBLEM>

## The <N> Role Responses

<PASTE ALL RAW AGENT RESPONSES>

Your job is NOT to resolve tensions — it is to PRESERVE them accurately.

Write a synthesis structured as:

### Settled Points
(What do 2+ roles genuinely agree on? Only include real convergence, not polite overlap. Be specific.)

### Live Disputes
(Where do roles fundamentally disagree? Name the underlying value conflict or empirical disagreement — not just the surface claim. Do not soften these.)

### Strongest Individual Insights
(One standout insight per role that would be LOST if everything were merged. Name the role.)

### What's Being Avoided
(What question or implication are all roles dancing around but not directly addressing?)

### Dangerous Assumptions Flagged
(Compile the "Most Dangerous Assumption" from each role. Which ones are unique? Which ones overlap?)

Do not try to make everyone happy. Do not paper over disagreements. The tensions ARE the value.
```

Write the synthesis to `$WORKING_FILE`.

---

## Phase 3b — Adversary Pass

After the synthesizer completes, spawn ONE dedicated adversary `general-purpose` subagent. Give it the synthesis. Wait for it to complete.

**Adversary prompt:**

```
You are an adversary agent. Your job is to challenge a synthesis document — not because you disagree with everything, but because premature consensus is dangerous and synthesis agents have systematic biases toward agreement.

## The Synthesis to Challenge

<SYNTHESIZER OUTPUT>

## Original Problem

<PROBLEM>

## The Raw Role Responses

<ALL ROUND 1 RAW RESPONSES>

Your response must include:

1. **What This Synthesis Gets Wrong** — The 1–2 most important things the synthesis misstated, overstated, or glossed over. Quote the synthesis and explain the flaw specifically.

2. **What Was Papered Over** — Which tension from the raw responses was softened or eliminated in the synthesis? What was the original sharp disagreement that got flattened?

3. **The Fabricated Consensus** — Did the synthesis attribute a position to a role that the role didn't actually hold? If so, what was actually said vs. what the synthesis claimed?

4. **The Underrepresented Role** — Which role's argument was most weakened by the synthesis process? What did they actually say that's now missing or distorted?

5. **The Harder Question** — What question should Round 2 force the roles to confront that this synthesis avoided entirely?
```

Append the adversary critique to `$WORKING_FILE`.

---

## Phase 4 — Round 2: Cross-Debate (Direct Rebuttal)

Pair roles for direct rebuttal. Pairing heuristic: **pair the most divergent roles** — the ones whose Round 1 positions conflict most directly. With 4 roles, create 2 pairs.

State the pairings and rationale before spawning agents.

Spawn `N_PERSPECTIVES` parallel `general-purpose` subagents — one per role. Each agent gets:
- Their own Round 1 response
- ONE specific other role's Round 1 response (their debate partner)
- The Round 1 synthesis
- The adversary's critique

Launch **all in a single response** using `mode: "background"`. Wait for all to complete.

**Cross-debate prompt template:**

```
You are continuing a brainstorm. You have read a specific other role's argument AND seen an adversary critique of the Round 1 synthesis.

## Problem

<PROBLEM>

## Your Role: <YOUR ROLE NAME>
<YOUR ROLE DESCRIPTION>

## Your Round 1 Position
<YOUR ROUND 1 RESPONSE>

## The Role You Are Directly Rebutting
**Role: <THEIR ROLE NAME>**
<THEIR FULL ROUND 1 RESPONSE>

## Round 1 Synthesis (for context)
<SYNTHESIS>

## Adversary's Critique of Round 1 Synthesis
<ADVERSARY OUTPUT>

Respond directly to your debate partner AND account for what the adversary flagged:

1. **Where They're Right** — Name 1–2 specific points in their argument you accept. Be honest — find the strongest parts of their case.

2. **Where They're Wrong** — Name 1–2 places their argument fails. Quote their words. Explain the specific flaw.

3. **The Core Disagreement** — In one sentence: what is the deepest value or empirical disagreement between your two roles?

4. **Your Revised Position** — Has anything changed from Round 1? If yes, say specifically what and why. If no, explain why their best points don't move you.

5. **The Question That Would Resolve This** — One piece of data or one experiment that would settle the disagreement between your two roles.

6. **Response to the Adversary** — Did the adversary's critique of the synthesis correctly or incorrectly represent your Round 1 position? If incorrectly, what was actually said?
```

---

## Phase 4b — Cross-Debate Synthesis

After all cross-debate agents complete, synthesize the pair debates:

```markdown
## Cross-Debate Synthesis

### Pair 1: <Role A> vs. <Role B>
- What <A> accepted from <B>
- What <B> accepted from <A>
- The unresolved core disagreement (one sentence)
- The question that would settle it

### Pair 2: <Role C> vs. <Role D>
- What <C> accepted from <D>
- What <D> accepted from <C>
- The unresolved core disagreement
- The question that would settle it

### Cross-Pair Convergence
(Points that emerged from BOTH debates pointing toward consensus — what all 4 would grudgingly accept)
```

Append to `$WORKING_FILE`.

---

## Phase 5 — Round 3: Commit (if `N_ROUNDS >= 3`)

Spawn `N_PERSPECTIVES` parallel `general-purpose` subagents — one per role. Each gets: original problem + role description + Round 1 synthesis + adversary critique + cross-debate synthesis.

Launch **all in a single response** using `mode: "background"`. Wait for all to complete.

**Commit prompt template:**

```
Final round. Commit to a concrete position.

## Problem

<PROBLEM>

## Your Role: <ROLE NAME>
<ROLE DESCRIPTION>

## Round 1 Synthesis
<SYNTHESIS>

## Adversary's Critique
<ADVERSARY>

## Cross-Debate Synthesis
<CROSS-DEBATE SYNTHESIS>

1. **Your Final Position** — Concrete enough that an engineer or PM could act on it next week. Write 2–3 specific steps.

2. **What You're Letting Go** — What from Round 1 are you dropping? Why?

3. **The One Non-Negotiable** — One element that MUST be in the final decision or you consider it a failure from your role's perspective. Be specific.

4. **Acceptance Conditions** — If your Non-Negotiable isn't met, under what specific conditions could you accept it anyway?

5. **What Will Go Wrong Without This** — If the consensus doesn't account for your key concern, what specifically breaks, by when, and how will the team know?
```

Synthesize Round 3 outputs and append to `$WORKING_FILE`.

---

## Phase 6 — Final Document

Write the completed brainstorm document to `$WORKING_FILE`.

```bash
SESSION_DIR="~/.copilot/session-state/<SESSION_ID>/"  # Copilot CLI
WORKING_FILE="${SESSION_DIR}brainstorm-${SLUG}.md"
```

**Document structure:**

```markdown
# Brainstorm: <Topic>

_<Date> · <N> roles · <R> rounds_

## Problem Statement

<Full problem description>

## Roles Selected

| Role | Why This Role Matters |
|---|---|
| <Role> | <Rationale> |

## Round 1 Synthesis

### Settled Points
### Live Disputes
### Strongest Individual Insights
### What's Being Avoided
### Dangerous Assumptions Flagged

## Adversary's Critique of Round 1

(Full adversary output — what the synthesis got wrong, what was papered over, what was fabricated)

## Cross-Debate Synthesis (Round 2)

(Pair-by-pair: what each accepted, what hardened, the core disagreement, the resolving question)

## Round 3 Synthesis (if applicable)

## Consensus

<The concrete, durable conclusions that survived scrutiny. Specific enough to implement. Not a direction — an answer.>

## Falsifiable Predictions

| Prediction | Timeframe | Role | What Falsification Looks Like |
|---|---|---|---|
| <If X is done, Y will happen> | <When> | <Who predicted it> | <Observable outcome that would disprove it> |

## Irreconcilable Tensions

<Disagreements that the process clarified but did not resolve. For each: name the tension, explain why it's genuinely unresolvable with available information, and describe what evidence or context would settle it.>

## Minority Views

<Strong positions that didn't make it into consensus but deserve consideration if the consensus breaks down.>

## Recommended Next Steps

<Concrete, sequenced actions suggested by the consensus.>
```

Display the file path and one-line consensus summary to the user.

---

## Phase 7 — Wrap-up

Summarize:
- Output file path
- Roles used and rounds completed
- One-line consensus
- Top 2–3 items from the Falsifiable Predictions table (so the user can track them)

**Use `ask_user`:**
> "What would you like to do next?"
Choices: `["Run another convergence round", "Start a new brainstorm on a different topic", "Nothing — I'm done"]`

- **"Run another convergence round"**: repeat Phase 5 with current synthesis, rewrite final document.
- **"Start a new brainstorm"**: return to Phase 0.
- **"Nothing"**: close out and remind the user of the file path.

---

## Reference

- Session state folder (Copilot CLI): `~/.copilot/session-state/<SESSION_ID>/` — use the active session folder
- Subagent spawning: `task` tool with `agent_type: "general-purpose"` and `mode: "background"` for parallel execution
- Retrieving results: `read_agent` with each agent's ID after completion
- Output file naming: `brainstorm-<slug>.md` where slug is lowercased, hyphenated, max 40 chars
- **Synthesizer and adversary are separate subagents** — never have the main agent synthesize its own generated debate
- **Pairing heuristic for Round 2**: pair the most divergent roles, not the most complementary ones
