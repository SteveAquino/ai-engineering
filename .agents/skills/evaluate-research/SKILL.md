---
name: evaluate-research
description: Impartial quality evaluation of a research document. Invoked as a structurally isolated subagent by process-inbox — receives only the document content, no session context. Returns a verdict (TRUST / REVIEW / DISCARD), confidence score, TL;DR, and falsifiable claim for the Research Digest.
---

# Skill: Evaluate Research

**Structural isolation is the entire point of this skill.** It is always invoked as a subagent with no shared context from the session that produced the research. The evaluator must not know who requested the research, what they hoped to find, or what decisions depend on it.

Invoke this skill by passing only:
1. The full text of the research document
2. The topic/title

Nothing else. No prior conversation. No outcome expectations.

---

## ⛔ Hard Rules

- Never soften a DISCARD verdict because the research "seems well-intentioned"
- Never upgrade confidence because the conclusions match what you'd expect
- Always cite specific lines or claims when scoring — no vague praise or criticism
- If sources are not cited in the document, score sources as WEAK regardless of how confident the prose sounds

---

## Phase 1 — Apply the Rubric

Score each dimension independently before forming an overall verdict.

### 1. Sources
- **STRONG**: 3+ verifiable external sources cited with specifics (URLs, docs, version numbers)
- **MEDIUM**: 1–2 sources, or sources cited but not linkable
- **WEAK**: No sources cited, or "model knowledge only", or single unverifiable claim

### 2. Internal Consistency
- **STRONG**: Conclusions follow directly from evidence presented; no logical gaps
- **MEDIUM**: Mostly follows but has one unsupported leap
- **WEAK**: Conclusions go beyond what evidence supports, or contradict earlier claims

### 3. Falsifiability
- **STRONG**: Document states a specific "if wrong, check X" — a concrete counter-check exists
- **MEDIUM**: Implicitly falsifiable but not stated
- **WEAK**: Conclusions are unfalsifiable or so hedged they can't be wrong

### 4. Recency / Staleness Risk
- **LOW RISK**: Evergreen topic, or explicitly time-stamped with recency check
- **MEDIUM RISK**: Could be outdated within 6 months; no recency check mentioned
- **HIGH RISK**: Fast-moving topic (APIs, pricing, tooling) with no date anchoring

### 5. Scope Discipline
- **TIGHT**: Answers the question asked; doesn't wander
- **LOOSE**: Contains useful content but also unasked tangents that dilute the signal

---

## Phase 2 — Form Overall Verdict

| Verdict | Condition |
|---------|-----------|
| ✅ **TRUST** | Sources STRONG or MEDIUM + Consistency STRONG + at least one other dimension strong |
| 🔍 **REVIEW** | Mixed scores — has real signal but reader should verify key claims before acting |
| ❌ **DISCARD** | Sources WEAK + Consistency WEAK, or HIGH staleness risk on a time-sensitive topic |

---

## Phase 3 — Write the Assessment

Output a structured block:

```markdown
## Research Evaluation

**Verdict:** ✅ TRUST / 🔍 REVIEW / ❌ DISCARD
**Confidence:** HIGH / MEDIUM / LOW

### Scores
| Dimension | Score | Note |
|-----------|-------|------|
| Sources | STRONG/MEDIUM/WEAK | [specific observation] |
| Consistency | STRONG/MEDIUM/WEAK | [specific observation] |
| Falsifiability | STRONG/MEDIUM/WEAK | [specific observation] |
| Staleness Risk | LOW/MEDIUM/HIGH | [specific observation] |
| Scope | TIGHT/LOOSE | [specific observation] |

### TL;DR (2–3 sentences for the Research Digest)
[What the research actually says, neutrally stated. Not the verdict — the content.]

### Falsifiable Claim
[One sentence: "If this is wrong, you'd find X by checking Y."]

### Reviewer Guidance
[One sentence: what the human reviewer should focus on if they choose to read it.]
```

---

## Phase 4 — Return to Caller

Return the full assessment block. The calling skill (process-inbox) will:
1. Append the TL;DR + verdict to the Research Digest
2. Save the full assessment alongside the research note in Obsidian
3. Archive the inbox message
