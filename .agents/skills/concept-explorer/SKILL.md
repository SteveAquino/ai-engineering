---
name: concept-explorer
description: Turn any concept, codebase, document, or artifact into a navigable dark-themed HTML exploration page with perspective toggle (standard/supportive/adversarial), isolated Aristotelian four-cause analysis, and context-aware sections. Supports autopilot mode with sane defaults.
---

# Skill: Concept Explorer

Use this skill to turn any subject into a navigable, interactive HTML report. Works for: code repositories, take-home submissions, system designs, documents, proposals, technical concepts, interview candidates, or any artifact you want to understand deeply.

The output is a self-contained HTML file saved to the session files directory and opened in the browser. It includes:
- A sticky sidebar with section navigation
- A **perspective toggle** (Standard / Supportive / Adversarial) that switches the interpretive sections
- An **Aristotelian four-cause analysis** run by an isolated subagent with no pre-conditioning context
- Factual sections (structure, components, data flow, decisions) that are perspective-independent
- Domain-appropriate section selection based on detected content type

**Invocation examples:**
- "Turn this repo into an explorable HTML page"
- "Make me a concept explorer for this architecture proposal"
- "Build an exploration doc for this interview submission"
- "Run concept-explorer on this in autopilot"

---

## Phase 0 — Intake

### Determine the subject

If the subject was passed directly (a file path, URL, pasted content, or description), capture it as `SUBJECT`. If not, ask:

**Ask the user:**
> "What do you want to explore? Provide a path, URL, pasted content, or describe the concept. The more context you give, the better the output."

Allow freeform. Store as `SUBJECT` and `SUBJECT_LABEL` (a short human-readable name for the page title, e.g. "Taylor — AI Triage Harness" or "Rails ActiveRecord Architecture").

---

### Autopilot check

**Ask the user:**
> "Run in autopilot mode (use all defaults, no more questions) or configure manually?"

Choices: `["Autopilot — just build it (Recommended)", "Configure — I'll answer a few questions"]`

If **Autopilot**: set all defaults listed below and skip to Phase 1.
If **Configure**: proceed through the configuration questions below.

---

### Configuration questions (skip in autopilot)

**1. Content type** (used to select section templates)

**Ask the user:**
> "What type of content is this?"

Choices:
- `Codebase / take-home submission` → sections: Architecture, Components, Data Model, Design Decisions, Test Coverage, Team Legibility
- `System design / proposal` → sections: Overview, Architecture, Data Flow, Design Decisions, Operational Concerns, Gaps
- `Document / paper / RFC` → sections: Summary, Structure, Arguments, Evidence, Gaps, Implications
- `Interview candidate / work output` → sections: Overview, Strengths, Concerns, Against Role Bar, Team Legibility, Follow-up Questions
- `Technical concept / technology` → sections: Overview, Use Cases, Trade-offs, Ecosystem, Maturity, Adoption Risks
- `Auto-detect` → main analysis agent infers the best section structure

**Default (autopilot):** Auto-detect.

---

**2. Perspectives**

**Ask the user:**
> "Include adversarial and supportive perspectives in addition to the standard read?"

Choices: `["Yes — all three perspectives (Recommended)", "Standard only — skip adversarial/supportive"]`

**Default (autopilot):** Yes — all three.

---

**3. Aristotelian analysis**

**Ask the user:**
> "Include an isolated Aristotelian four-cause analysis (Material / Formal / Efficient / Final cause + gap analysis)?"

Choices: `["Yes — isolated subagent, no pre-conditioning (Recommended)", "No — skip"]`

**Default (autopilot):** Yes.

---

**4. Specific angles to probe**

**Ask the user:**
> "Any specific concerns, angles, or questions you want the analysis to investigate? (Leave blank to let the agents surface findings autonomously)"

Allow freeform or blank. Store as `FOCUS_ANGLES`. **Default (autopilot):** None — agents surface findings autonomously.

---

**5. Audience / framing**

**Ask the user:**
> "Who is this for, and what decision or understanding does it support?"

Allow freeform. Store as `AUDIENCE_CONTEXT`. **Default (autopilot):** Personal reference and decision-making.

---

### Role context

Capture the current active role/session context (if any) to pass to the context-aware main analysis agent. The isolated agents (Aristotelian, adversarial, supportive) must NOT receive this context — they read only the source material.

```bash
# Read current role context if available
ROLE_CONTEXT_FILE=".agents/roles/$(cat .agents/references/local.md 2>/dev/null | grep ACTIVE_ROLE | cut -d= -f2 2>/dev/null)/ROLE.md"
```

If no active role, `ROLE_CONTEXT` = "General purpose — no specific role active."

---

## Phase 1 — Plan the Sections

Based on content type (detected or configured), select the section set. Use this routing table:

| Content Type | Factual Sections | Interpretive Sections |
|---|---|---|
| Codebase / take-home | Architecture & Pipeline, Components, Data Model, Design Decisions, Eval/Test Coverage | Overview verdict, Concerns, Signals, Gaps, Follow-up |
| System design / proposal | Architecture, Data Flow, Design Decisions, Operational Concerns | Overview verdict, Concerns, Strengths/Gaps, Follow-up |
| Document / RFC | Structure, Arguments, Evidence | Summary verdict, Concerns, Strengths, Implications, Follow-up |
| Interview candidate | Work Output, Methodology, Communication Signals | Overall verdict, Concerns, Against Role Bar, Follow-up Questions |
| Technical concept | Overview, Use Cases, Trade-offs, Ecosystem | Verdict (adopt/avoid/wait), Risks, Recommendations |
| Auto-detect | Agent decides | Agent decides |

**Factual sections** are perspective-independent — they contain what the artifact *is*, not what you think of it.

**Interpretive sections** get three perspective-panel variants (Standard / Supportive / Adversarial).

---

## Phase 2 — Launch Parallel Agents

Launch all agents in a **single response**. Do not wait between launches. Agents run concurrently.

Announce to the user: "Launching [N] parallel agents. This takes 2–4 minutes. I'll assemble the page when they finish."

---

### Agent 1: Main Analysis Agent (context-aware)

This agent receives full session/role context and produces the factual sections + the **Standard** interpretive content.

**Prompt template:**

```
You are producing a structured analysis of the following subject for inclusion in a navigable HTML exploration page.

## Subject
<SUBJECT>

## Subject label
<SUBJECT_LABEL>

## Role / session context
<ROLE_CONTEXT>

## Audience and framing
<AUDIENCE_CONTEXT>

## Specific angles to probe
<FOCUS_ANGLES — or "None. Surface findings autonomously.">

## Section structure to produce
<SELECTED_SECTIONS based on content type>

## What to produce

Return structured HTML content only — no <html>, <head>, <body> wrappers. Just the inner content blocks.

Produce two parts:

### Part A: Factual Sections
One <div> per factual section. These are perspective-independent — what the artifact IS, not what you think of it.
Use <h2> for section titles, <h3> for subsections, <h4> for detail headings.
Use <pre> for code blocks, <code> for inline code.
Use <table> with class="comparison-table" for comparison tables.
Use <ul class="signal-list"> for dot-prefixed evidence lists.
Use <div class="card"> and <div class="cards-grid"> for card layouts.
Use <div class="callout [green|yellow|red|blue]"> for highlighted findings.
Use <div class="timeline"> / <div class="timeline-item"> for chronological sequences.
Be specific and evidence-based. Cite file names, function names, line numbers where relevant.

### Part B: Standard Interpretive Content
Wrapped in: <div class="perspective-panel active" data-perspective="standard">...</div>

Produce perspective-specific versions of: overall verdict, concerns/findings cards, signals (strong/weak), gap analysis, follow-up framing.

Use <div class="concern-card"> for finding cards.
Use <div class="verdict [refuted|confirmed|mixed]"> for verdict labels.
Use <ul class="signal-list"> with colored dots for signal lists.
Use <div class="callout [green|yellow|red|blue]"> for verdict and summary callouts.
Use <div class="question-card"> with <div class="q-text"> and <div class="q-why"> for follow-up questions.

CSS variables available: --bg, --surface, --surface2, --border, --text, --muted, --accent, --accent2, --green, --yellow, --red, --blue, --purple, --mono, and *-bg variants for each color.
```

---

### Agent 2: Aristotelian Analysis Agent (ISOLATED — no context)

This agent receives **only the source material** — no session context, no role framing, no prior evaluation. Clean cold read.

**Prompt template:**

```
You are a senior analyst applying Aristotle's four-cause framework to understand a subject from first principles. You have no prior context about this subject, its author, or any evaluation process. Approach this purely as a philosophical and technical analysis.

## The Four Causes

- **Material Cause** — What is it made of? Raw constituents: language, frameworks, components, data structures, file types, dependencies.
- **Formal Cause** — What is its form/structure? The arrangement of parts: patterns, component boundaries, data flow, how pieces relate.
- **Efficient Cause** — What brought it into being? Forces that shaped it: design decisions, constraints, trade-offs chosen and rejected.
- **Final Cause (Telos)** — What is it for? Purpose: the problem it solves, the need it serves, the end state it aims at.

Then produce:
- **Actuality vs. Ideal Form** — What does this actually do/say vs. what its telos implies it should fully do/say?
- **Gap Analysis** — Ordered list of gaps between actuality and ideal form, from highest to lowest consequence. Rate each: Critical / Significant / Minor.

## Subject to analyze
<SUBJECT — source material paths or content only. No evaluation context.>

## Output format

Return structured HTML content only. No <html>/<head>/<body> wrappers.

Structure:
- <h3> for each cause heading
- <p> tags with color: var(--muted) for body text
- <strong> for key terms and judgments
- <code> for file names, class names, identifiers
- <blockquote style="border-left: 3px solid var(--border); padding-left: 16px; margin: 12px 0; color: var(--muted); font-style: italic;"> for direct quotes from source material
- Two-column actuality vs. ideal: <div style="display:grid; grid-template-columns:1fr 1fr; gap:16px; margin:16px 0;">
- Gap analysis: styled list items with severity spans:
  - Critical: <span style="color:var(--red); font-weight:700; font-size:11px; text-transform:uppercase;">Critical</span>
  - Significant: <span style="color:var(--yellow); font-weight:700; font-size:11px; text-transform:uppercase;">Significant</span>
  - Minor: <span style="color:var(--muted); font-weight:700; font-size:11px; text-transform:uppercase;">Minor</span>

Be rigorous and specific. Every observation must cite actual evidence from the source material. This analysis should only be possible for someone who has read this specific subject.
```

---

### Agent 3: Adversarial Perspective Agent (ISOLATED — no context)

This agent receives **only the source material** and its assigned perspective role. No session context.

**Prompt template:**

```
You are making the strongest defensible case AGAINST this subject — whether that means: against hiring this candidate, against adopting this technology, against approving this proposal, against this architecture. Apply to what makes sense given the subject.

You are not being unfair. You are applying a high bar rigorously and focusing on evidence. Do not manufacture concerns — only raise things genuinely supported by the source material.

## Subject
<SUBJECT — source material paths or content only. No evaluation context.>

## What to produce

Return structured HTML content only. Wrap everything in:
<div class="perspective-panel" data-perspective="adversarial">...</div>

Produce:
1. A verdict: <div class="callout red"> with bold verdict and 2–3 sentences of evidence-based reasoning
2. Key concerns: how the main findings look from an adversarial lens (use .concern-card with .verdict.confirmed / .verdict.mixed classes as appropriate)
3. Damaging evidence: <ul class="signal-list"> with red dots, citing specific files/classes/passages
4. A gap severity reframe: 1–2 sentences characterizing the overall gap from your perspective
5. Recommendation: <div class="callout red"> with your specific verdict and conditions to reconsider
6. Follow-up probes: <div class="question-card"> items with .q-text and .q-why

Keep everything evidence-based. Specificity is what makes critique credible. No generic concerns.

CSS variables available: --bg, --surface, --surface2, --border, --text, --muted, --accent, --accent2, --green, --yellow, --red, --blue, --purple, --mono.
```

---

### Agent 4: Supportive Perspective Agent (ISOLATED — no context)

This agent receives **only the source material** and its assigned perspective role. No session context.

**Prompt template:**

```
You are making the strongest defensible case FOR this subject — whether that means: for hiring this candidate, for adopting this technology, for approving this proposal, for this architecture. Apply to what makes sense given the subject.

You are not ignoring real problems. You are contextualizing them fairly, weighing them against scope/constraints, and highlighting genuine strengths. Do not spin weaknesses into strengths dishonestly.

## Subject
<SUBJECT — source material paths or content only. No evaluation context.>

## What to produce

Return structured HTML content only. Wrap everything in:
<div class="perspective-panel" data-perspective="supportive">...</div>

Produce:
1. A verdict: <div class="callout green"> with bold verdict and 2–3 sentences of evidence-based reasoning
2. How the main findings look from a supportive lens (use .concern-card with .verdict.refuted / .verdict.mixed classes as appropriate)
3. Strongest signals: <ul class="signal-list"> with green dots, citing specific files/classes/passages — things you would not expect from a junior contributor
4. Contextualized weaknesses: <div class="callout yellow"> acknowledging real gaps but contextualizing them against scope/format/constraints
5. Recommendation: <div class="callout green"> with your specific verdict and what to validate next
6. Follow-up validators: <div class="question-card"> items with .q-text and .q-why

Keep everything evidence-based. Specificity is what makes advocacy credible. No generic praise.

CSS variables available: --bg, --surface, --surface2, --border, --text, --muted, --accent, --accent2, --green, --yellow, --red, --blue, --purple, --mono.
```

---

## Phase 3 — Assemble the HTML

After all agents complete (or after 10 minutes, proceed with completed agents and note any pending), assemble the final HTML page.

Use one assembly agent or assemble directly. The assembly agent receives all four agent outputs and the section plan.

### HTML page structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><SUBJECT_LABEL> — Concept Explorer</title>
  <style>
    /* Full design system — paste from reference below */
  </style>
</head>
<body>
  <!-- Sidebar nav -->
  <nav>
    <!-- Brand block with subject label and content type -->
    <!-- Verdict badge (updates with perspective) -->
    <!-- Nav sections: Overview, [Content-type sections], Analysis, Interview/Follow-up -->
    <!-- Perspective descriptions -->
  </nav>

  <main>
    <!-- Sticky perspective bar -->
    <div class="perspective-bar" id="perspective-bar">
      <span class="pb-label">Reading as:</span>
      <div class="pb-options">
        <button class="pb-btn active" data-p="standard" onclick="setPerspective('standard')">⚖ Standard</button>
        <button class="pb-btn" data-p="supportive" onclick="setPerspective('supportive')">✅ Supportive</button>
        <button class="pb-btn" data-p="adversarial" onclick="setPerspective('adversarial')">⚠ Adversarial</button>
      </div>
      <span class="pb-desc" id="pb-desc">Balanced assessment weighted for context and scope</span>
    </div>

    <!-- Overview section (perspective-toggled verdict + factual intro) -->
    <section id="overview">...</section>

    <!-- Aristotelian analysis section -->
    <section id="aristotle">
      <h2>🏛 Aristotelian Analysis</h2>
      <p class="section-intro">Cold read — no session context. Four-cause analysis of what this subject actually is, what it is for, and where it falls short of its own telos.</p>
      <!-- Agent 2 output here -->
    </section>

    <!-- Factual sections (perspective-independent) -->
    <!-- Agent 1 Part A output here -->

    <!-- Interpretive sections (perspective-toggled) -->
    <!-- All three perspective panels side by side for: concerns, signals, gaps, follow-up -->

    <hr class="section-divider">
  </main>

  <script>
    /* setPerspective(), nav scroll highlighting, node toggles */
  </script>
</body>
</html>
```

---

### HTML Design System Reference

The assembly agent must use this exact CSS variable palette and component set for visual consistency across all generated pages.

#### CSS Variables

```css
:root {
  --bg: #0f1117;
  --surface: #1a1d27;
  --surface2: #22263a;
  --border: #2e3352;
  --text: #e2e8f0;
  --muted: #8892a4;
  --accent: #6366f1;
  --accent2: #818cf8;
  --green: #34d399;      --green-bg: rgba(52,211,153,0.08);
  --yellow: #fbbf24;     --yellow-bg: rgba(251,191,36,0.08);
  --red: #f87171;        --red-bg: rgba(248,113,113,0.08);
  --blue: #60a5fa;       --blue-bg: rgba(96,165,250,0.08);
  --purple: #a78bfa;     --purple-bg: rgba(167,139,250,0.08);
  --font: -apple-system, BlinkMacSystemFont, 'Segoe UI', system-ui, sans-serif;
  --mono: 'SF Mono', 'Fira Code', 'Cascadia Code', monospace;
}
```

#### Core Layout
- `body`: flex row, `--bg` background
- `nav`: 220px sticky sidebar, `--surface` background, `border-right: 1px solid var(--border)`
- `main`: flex-1, `padding: 40px 48px`, `max-width: 1100px`
- `section`: `margin-bottom: 64px`, `scroll-margin-top: 24px`

#### Component Classes

| Class | Usage |
|---|---|
| `.badge .green/.yellow/.red/.blue/.purple` | Pill badges — status, tags |
| `.callout .green/.yellow/.red/.blue` | Left-bordered callout box — verdicts, warnings, findings |
| `.card` | Surface card with border and padding |
| `.cards-grid` | 2-column card grid |
| `.signal-list` | Dot-prefixed evidence list — use `.dot.green/.red/.yellow` |
| `.concern-card` | Finding card with `.verdict .refuted/.confirmed/.mixed` label |
| `.question-card` | Interview question with `.q-text` and `.q-why` children |
| `.comparison-table` | Full-width table with `.win`/`.lose` cell coloring |
| `.timeline` / `.timeline-item` | Vertical timeline with accent dots |
| `.erd-table` / `.erd-header` / `.erd-col` | Database table display |
| `.decision-card` | Decision card with `.dc-label.decision/.tradeoff/.rationale` sections |
| `.pipeline-node` | Clickable node in a pipeline diagram — toggles a `.node-detail` panel |
| `.eval-loop` / `.eval-row` / `.eval-arrow` | Numbered feedback loop steps |

#### Perspective Toggle System

```css
.perspective-bar { position: sticky; top: 0; z-index: 100; background: var(--surface); border-bottom: 1px solid var(--border); padding: 12px 0; display: flex; align-items: center; gap: 16px; margin-bottom: 40px; }
.pb-btn { padding: 6px 14px; border-radius: 20px; border: 1px solid var(--border); background: var(--surface2); color: var(--muted); font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.15s; }
.pb-btn.active[data-p="standard"] { background: rgba(99,102,241,0.15); border-color: var(--accent); color: var(--accent2); }
.pb-btn.active[data-p="supportive"] { background: var(--green-bg); border-color: var(--green); color: var(--green); }
.pb-btn.active[data-p="adversarial"] { background: var(--red-bg); border-color: var(--red); color: var(--red); }
.perspective-panel { display: none; }
.perspective-panel.active { display: block; }
```

```javascript
const PERSPECTIVE_DESCS = {
  standard: 'Balanced assessment weighted for context and scope',
  supportive: 'Strongest defensible case for — evidence-based advocacy',
  adversarial: 'Strongest defensible case against — high-bar rigorous critique'
};
function setPerspective(p) {
  document.querySelectorAll('.perspective-panel').forEach(el => {
    el.classList.toggle('active', el.dataset.perspective === p);
  });
  document.querySelectorAll('.pb-btn').forEach(btn => {
    btn.classList.toggle('active', btn.dataset.p === p);
  });
  const desc = document.getElementById('pb-desc');
  if (desc) desc.textContent = PERSPECTIVE_DESCS[p] || '';
  // Optional: update sidebar verdict badge
  const badge = document.querySelector('.verdict-badge');
  if (badge) {
    const labels = { standard: 'Balanced', supportive: '✅ Advocate', adversarial: '⚠ Critique' };
    const colors = { standard: 'var(--green)', supportive: 'var(--green)', adversarial: 'var(--red)' };
    badge.textContent = labels[p];
    badge.style.color = colors[p];
  }
}
// Scroll-based nav highlighting
const sections = document.querySelectorAll('section[id]');
const navLinks = document.querySelectorAll('nav a');
const observer = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      navLinks.forEach(l => l.classList.remove('active'));
      const a = document.querySelector(`nav a[href="#${entry.target.id}"]`);
      if (a) a.classList.add('active');
    }
  });
}, { threshold: 0.3 });
sections.forEach(s => observer.observe(s));
// Initialize
setPerspective('standard');
```

---

### Assembly rules

1. **Do not truncate agent output.** Embed all content from all four agents in full.
2. **Perspective panels must wrap all interpretive content** — overview verdict, concerns, signals, gaps, recommendations, follow-up. Factual sections are NOT wrapped.
3. **Aristotelian section gets a clear intro note** that it was produced by an isolated subagent with no pre-conditioning context.
4. **Sidebar nav** must link to every section present in the page. Group under nav-section labels matching the content type.
5. **If an agent didn't finish**, note it visually with a `<div class="callout yellow">Agent result pending — refresh or re-run</div>` placeholder.

---

## Phase 4 — Save and Deliver

### Save the file

```python
import os, re, pathlib

local_md = pathlib.Path(".agents/references/local.md").read_text()
SESSION_DIR = re.search(r"^SESSION_DIR=(.+)$", local_md, re.MULTILINE).group(1)
SLUG = "<SUBJECT_LABEL>".lower()[:40].replace(" ", "-").replace("/", "-")
OUTPUT_FILE = os.path.join(SESSION_DIR, "files", f"{SLUG}-explorer.html")
os.makedirs(os.path.dirname(OUTPUT_FILE), exist_ok=True)
# write HTML content to OUTPUT_FILE
```

### Open in browser

```bash
open "$OUTPUT_FILE"
```

### Confirm to user

Tell the user:
- File path
- Page title and sections included
- Perspectives available (if configured)
- Whether Aristotelian analysis was included
- Top 1–2 findings surfaced (from the Standard read)
- Any agents that didn't complete

---

## Notes

- **Isolated agents are critical.** The adversarial and supportive agents must not receive any evaluation framing, prior opinions, or session context. Their value comes from a genuinely cold read. Pass only source material paths/content.
- **Aristotelian analysis surprises.** The isolated four-cause agent consistently surfaces things that context-aware analysis misses or underweights — especially in the Final Cause (telos) and gap analysis. Don't skip it.
- **Content type detection.** When in autopilot, the main analysis agent should infer the content type from the subject and select sections accordingly. Common signals: `Gemfile`/`schema.rb` → codebase; `.md` doc with headers → document/RFC; repo with `app/` → Rails codebase; bullet notes with attendees → meeting/1:1.
- **Perspective balance.** The adversarial agent often finds things the supportive agent rationalizes away — and vice versa. The most valuable output is usually found in what only one of them says. Highlight this in your delivery summary.
- **Assembly agent size.** The full HTML for a complex subject can exceed 2000 lines. Use the Write tool directly rather than echoing to shell. If the assembly agent hits context limits, split factual sections and interpretive sections into two passes and combine.
- **Reuse for different lenses.** The same skill can be invoked multiple times on the same subject with different `FOCUS_ANGLES` to get progressively deeper on a specific dimension (e.g., first pass: overall; second pass: "focus on team collaboration signals only").

---

## Reference

- Design system: see HTML Design System Reference section above
- Session dir: read from `.agents/references/local.md` as `SESSION_DIR`
- Subagent launching: Task tool with `subagent_type: "general"` — launch all 4 in a single response
- File writing: Write tool directly for HTML files > 8KB
- Inspired by: interview take-home review session (2026-05-29, session `b9dc20af`)
