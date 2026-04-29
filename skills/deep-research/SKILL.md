---
name: deep-research
description: Conducts deep, multi-source research on any question using parallel background agents (fleet mode). Produces a structured markdown report with TL;DR, comparison tables, Mermaid diagrams, and cited sources.
---

# Skill: Research

Use this skill when you need comprehensive research on a technical, regulatory, process, or strategy question. Parallel background agents cover different research dimensions simultaneously — official docs, technical implementation, community evidence, and recent changes — then synthesize into a single markdown report.

**Invocation examples:**
- `/research` — then describe the question
- "Research whether X is compliant with Y guidelines"
- "Investigate our current approach to Z and whether it matches best practices"

---

## Phase 0 — Intake

### Research Question

**Use `ask_user`:**
> "What do you want to research? Describe the question, and include any relevant context (e.g., the technology, system, or codebase involved)."

Allow freeform. Capture:
- The core question being investigated
- Any relevant context: technology stack, codebase, current behavior
- Whether there is a specific "verdict" needed (e.g., "is our approach correct?", "what should we change?")

Store as `RESEARCH_QUESTION` and `CONTEXT`.

### Report Style

**Use `ask_user`:**
> "Any specific requirements for the report?"

Choices: `["Standard (TL;DR + tables + Mermaid + citations)", "Lightweight (TL;DR + summary only, no diagrams)", "Deep (add community case studies and counterexamples)"]`

The standard format is appropriate for most questions. Use "Lightweight" for quick directional research. Use "Deep" when you need community validation or want to surface real-world edge cases.

### Optional Context

**Use `ask_user`:**
> "Should I analyze your current codebase implementation as part of this research? (Recommended when the question relates to how something is currently built)"

Choices: `["Yes — analyze the codebase (Recommended)", "No — skip codebase analysis"]`

Store as `INCLUDE_CODEBASE`.

---

## Phase 1 — Design the Research Plan

Based on the question, identify **5–6 parallel research dimensions**. Select from the standard set below, customizing or adding domain-specific agents as needed.

### Standard Research Dimensions

| Agent Role | Focus | When to Include |
|---|---|---|
| `authoritative-sources` | Official documentation, policy documents, legal agreements, standards bodies | Always |
| `technical-docs` | SDK / framework / tool official docs and implementation guides | When a specific technology is involved |
| `codebase-analysis` | Current implementation in the repo — **discovery-first, no assumed file paths** | When `INCLUDE_CODEBASE = true` |
| `community-evidence` | Reddit, Stack Overflow, Hacker News — real-world experiences and edge cases | Almost always; slowest agent |
| `recent-changes` | What changed in the last 12–18 months; breaking changes, new requirements, deprecations | Always |
| `domain-specific` | Domain expert dimension (e.g., "regulatory" for healthcare, "security" for auth) | Add when the domain has specialized considerations |

Present the planned dimensions to the user before launching:
> "I'll research this using N parallel agents: [list dimensions]. Starting now..."

---

## Phase 2 — Launch the Fleet

Spawn all research agents in a **single response** using `mode: "background"`. Do not wait between launches.

### Agent Prompt Template

Each agent receives a self-contained prompt:

```
You are conducting focused research as part of a larger parallel research effort.

## Research Question

<RESEARCH_QUESTION>

## Context

<CONTEXT>

## Your Research Dimension: <AGENT_ROLE>

<AGENT_FOCUS_DESCRIPTION>

## Instructions

Research this dimension thoroughly. Be specific and concrete. Prioritize authoritative sources.

For every claim, include a citation: source name, URL (if available), and date verified.

Consider the current date: <TODAY'S DATE>. Flag anything that may have changed recently.

Your response must include:
1. **Key Findings** — the most important discoveries from your research dimension
2. **Tables or comparisons** where data lends itself to structured comparison
3. **Edge cases or exceptions** — anything that complicates the simple answer
4. **Citations** — every factual claim should have a source
5. **Confidence level** — High (authoritative + community), Medium (authoritative only), Low (community only)

Do not hedge excessively. Give a clear, well-supported answer from your research dimension.
```

### Agent-Specific Guidance

| Agent | Additional Instructions |
|---|---|
| `authoritative-sources` | Fetch the actual policy documents; note exact section numbers. Flag if any appear to conflict with each other. |
| `technical-docs` | Include version numbers. Note if behavior differs across versions. |
| `codebase-analysis` | **README first, then discovery, then read.** Start by reading the repo's `README.md` (and any docs/ index) — it often documents the CI platform, project structure, key scripts, and conventions that would otherwise take many greps to discover. Then do a broad repo exploration before deciding which files to read. Specifically: check for ALL CI systems (`.github/workflows/`, `.circleci/`, `Jenkinsfile`, `fastlane/`, `bitrise.yml`, `scripts/`) before concluding anything about automation. Do not assume GitHub Actions. |
| `community-evidence` | Search Reddit (use JSON API: reddit.com/r/subreddit/search.json), Stack Overflow API, Hacker News Algolia API. Note date of each post. |
| `recent-changes` | Use web search for the last 12–18 months. Include changelogs, blog announcements, and policy update pages. |

> ⚠️ **Orchestrator note for codebase-analysis prompts:** Do NOT hardcode a list of specific files to read in the agent prompt. Instead, describe what you're looking for and let the agent discover the relevant files. Always instruct the agent to read `README.md` first. Prescriptive file lists cause agents to miss critical implementation details that live in unexpected locations.

Collect all agent IDs after launching. You will be auto-notified when each completes.

---

## Phase 3 — Await and Read Results

Wait for completion notifications. As each agent completes, read its output with `read_agent`.

If an agent takes more than 10 minutes, you may begin synthesizing completed agents and note the pending one. Do not block the entire synthesis on one slow agent — community research is typically the slowest.

If an agent fails, retry once with `mode: "background"`. If it fails again, note the gap in the report and proceed.

---

## Phase 4 — Synthesize

After all (or most) agents complete, synthesize findings across dimensions into a coherent narrative.

**Synthesis checklist:**
- [ ] Have I identified where sources agree?
- [ ] Have I identified where sources conflict, and explained why?
- [ ] Have I formed a clear verdict on the research question?
- [ ] Have I identified any open questions or areas of genuine uncertainty?
- [ ] Have I noted any actionable follow-up items (beyond the research question)?

---

## Phase 5 — Write the Report

Use the `generate-report` technique to write the report to the session state folder.

> **Reference:** See [`generate-report/SKILL.md`](../generate-report/SKILL.md) for the correct file-writing pattern (Python scripts via `create` tool + `python3` execution). Never use heredocs or inline `python3 -c` with backtick content.

### Output File

```python
import os
SESSION_DIR = os.path.expanduser("~/.copilot/session-state/<SESSION_ID>")
SLUG = RESEARCH_QUESTION.lower()[:40].replace(" ", "-").replace("/", "-")
OUTPUT_FILE = os.path.join(SESSION_DIR, f"{SLUG}-research.md")
```

### Required Report Structure

```markdown
# <Research Topic>: Research Report

_Researched <DATE> · Sources: <list key source types>_

---

## TL;DR

> **<One-sentence verdict on the research question>**

| Question | Answer |
|---|---|
| <Sub-question 1> | **<Answer>** |
| <Sub-question 2> | **<Answer>** |
| Confidence | High / Medium / Low |

---

## Table of Contents
[auto-generated]

---

## 1. <Authoritative Sources Section>
[What the official docs say; exact citations]

## 2. <Technical Section>
[How the technology works; relevant implementation details]

## 3. <Current Implementation>
[If codebase was analyzed: what we're doing today and how it maps to findings]

## 4. <Verdict>
[Structured answer to the research question: what's correct, what's overcorrect, what's wrong]

## 5. <Community Evidence>
[Real-world experience; known incidents; what practitioners actually do]

## 6. <Recent Changes>
[What changed in the last 12-18 months; anything requiring action]

## 7. Recommendations
[Concrete next steps based on the research]

## Citations

| # | Source | Type | URL | Verified |
|---|---|---|---|---|
| 1 | ... | Authoritative | ... | <date> |
```

### Format Requirements

- **TL;DR table** at the top: question/answer rows with bolded answers
- **Tables** for all comparisons, feature matrices, policy differences, timelines
- **Mermaid diagrams** for flows, decision trees, architectures (use `flowchart TD` or `sequenceDiagram`)
- **Inline citations** throughout: link every factual claim to its source
- **Citations index** at the bottom with source type, URL, and verification date
- **Confidence indicator**: in the TL;DR table, note High/Medium/Low confidence with explanation

---

## Phase 6 — Open and Confirm

```bash
open -a "Visual Studio Code" "$OUTPUT_FILE"
```

Tell the user:
- File path
- One-sentence verdict (from TL;DR)
- Top 1–2 actionable recommendations
- Any follow-up items that surfaced during research

---

## Notes

- The community research agent (Reddit/SO/HN) is typically the slowest — allow up to 10–15 minutes. If it's still running when all other agents complete, begin writing the report and note it as pending.
- For policy/compliance questions: always fetch the actual policy document, not just summaries. Policy numbering changes over time.
- The `generate-report` pattern is essential for reports > 8KB — do not skip it.
- This skill complements `brainstorm`: use `deep-research` for factual questions requiring external sources, use `brainstorm` for deliberative questions requiring multiple perspectives on a known body of knowledge.

---

## Reference

- File-writing technique: [`generate-report/SKILL.md`](../generate-report/SKILL.md)
- Session state folder: `~/.copilot/session-state/<SESSION_ID>/`
- Subagent launching: `task` tool with `agent_type: "general-purpose"`, `mode: "background"`
- Reading results: `read_agent` with each agent's ID after notification
