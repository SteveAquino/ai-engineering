---
name: concept-explorer
description: Turn any concept, codebase, document, or artifact into a navigable dark-themed HTML exploration page. Features a four-perspective toggle (Advocate / Realist / Skeptic / Adversary — no neutral center), an isolated Aristotelian four-cause analysis, entity relationship diagrams, charts, and a comprehensive sources/citations section. An explicit exploration phase runs first to discover all relevant source material before any analysis begins.
---

# Skill: Concept Explorer

Use this skill to turn any subject into a navigable, interactive HTML report. Works for: code repositories, take-home submissions, system designs, documents, proposals, technical concepts, interview candidates, or any artifact you want to understand deeply.

The output is a self-contained HTML file saved to the session files directory and opened in the browser. It includes:
- A sticky sidebar with section navigation
- A **four-perspective toggle** (Advocate / Realist / Skeptic / Adversary) — no neutral center; every lens takes a position
- An **Aristotelian four-cause analysis** run by an isolated subagent with no pre-conditioning context
- **Entity relationship diagrams** — inline SVG visual graphs and relationship tables
- **Charts and graphs** — bar charts and stat cards for quantitative sections
- A mandatory **Sources & Citations** section listing every source read and all gaps
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

If **Autopilot**: set all defaults listed below and skip to Phase 0.5.
If **Configure**: proceed through the configuration questions below.

---

### Configuration questions (skip in autopilot)

**1. Content type** (used to select section templates)

**Ask the user:**
> "What type of content is this?"

Choices:
- `Codebase / take-home submission` → sections: Architecture, Components, Data Model, Entity Relationships, Design Decisions, Test Coverage, Team Legibility
- `System design / proposal` → sections: Overview, Architecture, Data Flow, Entity Relationships, Design Decisions, Operational Concerns, Gaps
- `Document / paper / RFC` → sections: Summary, Structure, Arguments, Evidence, Gaps, Implications
- `Interview candidate / work output` → sections: Overview, Strengths, Concerns, Against Role Bar, Team Legibility, Follow-up Questions
- `Technical concept / technology` → sections: Overview, Use Cases, Trade-offs, Ecosystem, Maturity, Adoption Risks
- `Auto-detect` → main analysis agent infers the best section structure

**Default (autopilot):** Auto-detect.

---

**2. Specific angles to probe**

**Ask the user:**
> "Any specific concerns, angles, or questions you want the analysis to investigate? (Leave blank to let the agents surface findings autonomously)"

Allow freeform or blank. Store as `FOCUS_ANGLES`. **Default (autopilot):** None — agents surface findings autonomously.

---

**3. Audience / framing**

**Ask the user:**
> "Who is this for, and what decision or understanding does it support?"

Allow freeform. Store as `AUDIENCE_CONTEXT`. **Default (autopilot):** Personal reference and decision-making.

---

### Role context

Capture the current active role/session context (if any) to pass to the context-aware main analysis agent. The isolated agents (Aristotelian, Advocate, Skeptic, Adversary) must NOT receive this context — they read only the source material.

```bash
ROLE_CONTEXT_FILE=".agents/roles/$(cat .agents/references/local.md 2>/dev/null | grep ACTIVE_ROLE | cut -d= -f2 2>/dev/null)/ROLE.md"
```

If no active role, `ROLE_CONTEXT` = "General purpose — no specific role active."

---

## Phase 0.5 — Exploration

**This phase runs before any analysis.** Its purpose is to discover and read all relevant source material so that nothing is missed and every gap is documented.

The exploration agent is the **main context-aware agent** (Agent 1). It runs exploration first, then analysis.

### Exploration instructions for Agent 1

```
BEFORE producing any analysis or HTML, complete the following exploration steps:

1. **Enumerate source candidates.** Based on the subject, identify everything that might be relevant:
   - For a codebase: README, schema.rb, Gemfile, routes.rb, core models, controllers, service objects, specs, OpenAPI/Swagger specs, CI config, docs/ directory
   - For a system/architecture: all referenced docs, per-service docs, OpenAPI specs in each service repo, ADRs, diagrams
   - For a document/RFC: the document itself plus any linked or referenced documents
   - For an interview submission: all source files, tests, README, any referenced libraries or docs
   - For a technical concept: primary documentation, changelog, known limitations docs, comparison guides

2. **Read everything accessible.** Use the file reading and search tools to read each candidate source. Do not skip files because they seem less important — a gap you skip may be the most significant finding.

3. **Record what you found and what you did not find.** For each source you attempted to read, record:
   - Path or URL
   - Type (code, doc, spec, config, diagram, etc.)
   - Status: FOUND (read successfully) or GAP (expected to exist, not found/accessible)
   - Brief note on what it contained or why it matters

4. **Surface immediate structural observations.** Before producing analysis, note any anomalies discovered during exploration (e.g., "Found 3 service repos but only 1 has OpenAPI docs", "README references a schema that doesn't match the actual schema", "No test files found").

5. **Then proceed to analysis** using the complete picture from the exploration phase.

The exploration log feeds directly into the mandatory Sources & Citations section of the final HTML page.
```

---

## Phase 1 — Plan the Sections

Based on content type (detected or configured), select the section set. Use this routing table:

| Content Type | Factual Sections | Interpretive Sections |
|---|---|---|
| Codebase / take-home | Architecture & Pipeline, Entity Relationships, Components, Data Model, Design Decisions, Test Coverage | Verdict, Concerns, Signals, Gaps, Follow-up |
| System design / proposal | Architecture, Entity Relationships, Data Flow, Design Decisions, Operational Concerns | Verdict, Concerns, Strengths/Gaps, Follow-up |
| Document / RFC | Structure, Entity Relationships, Arguments, Evidence | Verdict, Concerns, Strengths, Implications, Follow-up |
| Interview candidate | Work Output, Methodology, Communication Signals | Verdict, Concerns, Against Role Bar, Follow-up Questions |
| Technical concept | Overview, Entity Relationships, Use Cases, Trade-offs, Ecosystem | Verdict (adopt/avoid/wait), Risks, Recommendations |
| Auto-detect | Agent decides | Agent decides |

**Factual sections** are perspective-independent — they contain what the artifact *is*, not what you think of it.

**Interpretive sections** each get exactly **four** perspective-panel variants (Advocate / Realist / Skeptic / Adversary).

**Entity Relationships** is a factual section but must include a **visual SVG diagram** showing how the main entities/services/components relate to each other — not just a prose description or table. See the `relation-map` component in the design system.

---

## Phase 2 — Launch Parallel Agents

Launch all agents in a **single response**. Do not wait between launches. Agents run concurrently.

Announce to the user: "Launching 5 parallel agents. This takes 3–5 minutes. I'll assemble the page when they finish."

The five agents are:
1. **Main Analysis Agent** (context-aware) — exploration + factual sections + Realist perspective
2. **Aristotelian Agent** (ISOLATED) — four-cause analysis
3. **Advocate Agent** (ISOLATED) — strongest case for
4. **Skeptic Agent** (ISOLATED) — substantive concerns and questions
5. **Adversary Agent** (ISOLATED) — strongest case against

---

### Agent 1: Main Analysis Agent (context-aware)

This agent runs exploration first, then produces factual sections + the **Realist** perspective.

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

## Step 1: Exploration (required before any analysis)

Read ALL relevant source material before producing any content. For each source you attempt to read, record it in your sources log:
- Path or URL
- Type (code / doc / spec / config / diagram / other)
- Status: FOUND or GAP

If the subject is a system or architecture, this means: read every referenced service, look for OpenAPI/Swagger specs in each repo (swagger.yaml, openapi.yaml, openapi.json, docs/api/, swagger/), read per-service documentation, and read any ADRs or architecture decision records.

Do not skip sources because they seem secondary. Document every attempt.

## Step 2: Produce HTML content

Return structured HTML content only — no <html>, <head>, <body> wrappers. Just the inner content blocks.

Produce three parts:

### Part A: Factual Sections
One <section> per factual section with an id matching the section name (lowercase, hyphenated).
Use <h2> for section titles, <h3> for subsections, <h4> for detail headings.
Use <pre> for code blocks, <code> for inline code.
Use <table class="comparison-table"> for comparison tables (use class="win" / class="lose" on cells).
Use <ul class="signal-list"> for dot-prefixed evidence lists.
Use <div class="card"> and <div class="cards-grid"> for card layouts.
Use <div class="callout [green|yellow|red|blue]"> for highlighted findings.
Use <div class="timeline"> / <div class="timeline-item"> for chronological sequences.

**Entity Relationship diagram (required if entities/services/components exist):**
Produce an inline SVG relation-map showing how main entities relate. Use this pattern:
```html
<div class="relation-map">
  <svg width="100%" height="320" viewBox="0 0 860 320" style="overflow:visible">
    <defs>
      <marker id="arrow" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto">
        <polygon points="0 0, 8 3, 0 6" class="svg-arrow"/>
      </marker>
      <marker id="arrow-blue" markerWidth="8" markerHeight="6" refX="7" refY="3" orient="auto">
        <polygon points="0 0, 8 3, 0 6" class="svg-arrow-blue"/>
      </marker>
    </defs>
    <!-- Nodes: use svg-node / svg-node-text classes for theme-aware colors -->
    <g>
      <rect x="40" y="130" width="130" height="44" rx="6" class="svg-node"/>
      <text x="105" y="157" text-anchor="middle" class="svg-node-text" font-size="13" font-family="system-ui, sans-serif" font-weight="600">EntityName</text>
    </g>
    <!-- Edges: svg-edge class; label uses svg-edge-label class -->
    <line x1="170" y1="152" x2="230" y2="152" class="svg-edge" marker-end="url(#arrow)"/>
    <text x="200" y="146" text-anchor="middle" class="svg-edge-label" font-size="10" font-family="system-ui, sans-serif">calls</text>
  </svg>
</div>
```

Add these SVG theme-aware CSS rules alongside the `.relation-map` styles:
```css
/* SVG relation-map — theme-aware via CSS classes */
.svg-node      { fill: var(--surface2); stroke: var(--border); stroke-width: 1.5; }
.svg-node-text { fill: var(--text); }
.svg-edge      { stroke: var(--border); stroke-width: 1.5; fill: none; }
.svg-edge-label { fill: var(--muted); }
.svg-arrow     { fill: var(--border); }
.svg-arrow-blue { fill: var(--blue); }
/* Highlighted nodes (add class svg-node-accent for important entities) */
.svg-node-accent { fill: var(--surface2); stroke: var(--accent); stroke-width: 2; }
/* Edge variants */
.svg-edge-blue   { stroke: var(--blue);   stroke-width: 1.5; fill: none; }
.svg-edge-green  { stroke: var(--green);  stroke-width: 1.5; fill: none; stroke-dasharray: 4 3; }
.svg-edge-red    { stroke: var(--red);    stroke-width: 1.5; fill: none; stroke-dasharray: 4 3; }
```

**Charts (use where quantitative data exists):**
For distributions or counts, use a bar chart:
```html
<div class="bar-chart">
  <div class="bar-row">
    <span class="bar-label">Category name</span>
    <div class="bar-track"><div class="bar-fill green" style="width:75%"></div></div>
    <span class="bar-value">75%</span>
  </div>
</div>
```
For key metrics, use stat cards:
```html
<div class="stat-grid">
  <div class="stat-card"><div class="stat-value green">42</div><div class="stat-label">Total things</div></div>
</div>
```

Be specific and evidence-based. Cite file names, function names, line numbers where relevant.

### Part B: Realist Perspective Content
Wrapped in: <div class="perspective-panel active" data-perspective="realist">...</div>

The Realist reads the evidence without a predetermined conclusion. Name real strengths and real costs with equal weight. Frame findings operationally: "if you ship this, here is what you get and what you give up."

Use <div class="concern-card"> for finding cards.
Use <div class="verdict [refuted|confirmed|mixed]"> for verdict labels.
Use <ul class="signal-list"> with colored dots for signal lists (blue dots for realist).
Use <div class="callout blue"> for the overall verdict summary.
Use <div class="question-card"> with <div class="q-text"> and <div class="q-why"> for follow-up questions.

Produce a Realist panel for EACH of the following interpretive sections (wrap each individually):
- Verdict (id="verdict")
- Concerns (id="concerns")
- Signals (id="signals")
- Gaps (id="gaps")
- Follow-up (id="followup")

### Part C: Sources log
Return a JSON block (as an HTML comment) with every source you attempted:
<!-- SOURCES_LOG
[
  { "path": "/path/to/file.rb", "type": "code", "status": "FOUND", "note": "..." },
  { "url": "https://...", "type": "doc", "status": "GAP", "note": "Expected OpenAPI spec, not found" }
]
SOURCES_LOG -->
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
- <p style="color:var(--muted)"> for body text
- <strong> for key terms and judgments
- <code> for file names, class names, identifiers
- <blockquote style="border-left:3px solid var(--border);padding-left:16px;margin:12px 0;color:var(--muted);font-style:italic"> for direct quotes from source material
- Two-column actuality vs. ideal: <div style="display:grid;grid-template-columns:1fr 1fr;gap:16px;margin:16px 0">
- Gap analysis as a styled list:
  - Critical: <span style="color:#f87171;font-weight:700;font-size:11px;text-transform:uppercase">Critical</span>
  - Significant: <span style="color:#fbbf24;font-weight:700;font-size:11px;text-transform:uppercase">Significant</span>
  - Minor: <span style="color:#8892a4;font-weight:700;font-size:11px;text-transform:uppercase">Minor</span>

Be rigorous and specific. Every observation must cite actual evidence from the source material. This analysis should only be possible for someone who has read this specific subject.
```

---

### Agent 3: Advocate Perspective Agent (ISOLATED — no context)

This agent receives **only the source material** and its assigned perspective. No session context.

**Prompt template:**

```
You are making the strongest defensible case FOR this subject — whether that means: for hiring this candidate, for adopting this technology, for approving this proposal, for this architecture. Apply to what makes sense given the subject.

You are not ignoring real problems. You are contextualizing them fairly, weighing them against scope and constraints, and highlighting genuine strengths. Do not spin weaknesses into strengths dishonestly.

## Subject
<SUBJECT — source material paths or content only. No evaluation context.>

## What to produce

Return structured HTML content only. For EACH of the following interpretive sections, produce a separate panel:

Section: Verdict
<div class="perspective-panel" data-perspective="advocate" data-section="verdict">
  <div class="callout green"><strong>Advocate Verdict:</strong> [bold verdict sentence]<br>[2–3 sentences of evidence-based reasoning for why this clears the bar]</div>
</div>

Section: Concerns
<div class="perspective-panel" data-perspective="advocate" data-section="concerns">
  [How the main findings look favorably — use .concern-card with .verdict.refuted / .verdict.mixed as appropriate]
</div>

Section: Signals
<div class="perspective-panel" data-perspective="advocate" data-section="signals">
  [Strongest positive signals — <ul class="signal-list"> with green dots, citing specific files/classes/passages]
  [Contextualized weaknesses — <div class="callout yellow"> acknowledging real gaps but contextualizing them]
</div>

Section: Gaps
<div class="perspective-panel" data-perspective="advocate" data-section="gaps">
  [Gaps reframed: which ones are expected given scope/format/constraints? Which are genuine risks vs. acceptable trade-offs?]
</div>

Section: Follow-up
<div class="perspective-panel" data-perspective="advocate" data-section="followup">
  [Follow-up validators — <div class="question-card"> items with .q-text "What to confirm" and .q-why "Why this would strengthen the case"]
  <div class="callout green"><strong>Recommendation:</strong> [specific verdict and what to validate next]</div>
</div>

CRITICAL HTML CONTRACT — do NOT use class="visible", id="panel-xxx", or any other attribute name.
Use only data-perspective="advocate" and class="perspective-panel". The JavaScript toggle depends on this exact pattern.

CSS variables available: --bg, --surface, --surface2, --border, --text, --muted, --accent, --accent2, --green, --yellow, --red, --blue, --purple, --mono, and *-bg variants.
```

---

### Agent 4: Skeptic Perspective Agent (ISOLATED — no context)

This agent receives **only the source material** and its assigned perspective. No session context.

**Prompt template:**

```
You are a rigorous but fair skeptic. You raise substantive concerns, question assumptions, and probe for gaps — but you are not adversarial. You are the voice that asks "have we really thought this through?" You weigh evidence carefully and acknowledge genuine strengths.

## Subject
<SUBJECT — source material paths or content only. No evaluation context.>

## What to produce

Return structured HTML content only. For EACH of the following interpretive sections, produce a separate panel:

Section: Verdict
<div class="perspective-panel" data-perspective="skeptic" data-section="verdict">
  <div class="callout yellow"><strong>Skeptic Verdict:</strong> [bold verdict sentence — cautious, conditional, or "not yet"]<br>[2–3 sentences naming the specific unresolved questions that would need answers before confidence increases]</div>
</div>

Section: Concerns
<div class="perspective-panel" data-perspective="skeptic" data-section="concerns">
  [Concerns as open questions rather than verdicts — use .concern-card with .verdict.mixed / .verdict.confirmed as appropriate]
  [Focus on assumptions that haven't been validated, edge cases not handled, or signals that could go either way]
</div>

Section: Signals
<div class="perspective-panel" data-perspective="skeptic" data-section="signals">
  [Mixed signals — <ul class="signal-list"> with yellow dots for ambiguous signals, noting what each could mean either way]
  [What evidence is missing that would resolve the ambiguity?]
</div>

Section: Gaps
<div class="perspective-panel" data-perspective="skeptic" data-section="gaps">
  [Gaps rated by how much they affect confidence: <span style="color:#fbbf24;font-weight:700;font-size:11px;text-transform:uppercase">Confidence-Critical</span> vs. <span style="color:#8892a4;font-weight:700;font-size:11px;text-transform:uppercase">Acceptable</span>]
  [Which gaps would you need closed before recommending a "yes"?]
</div>

Section: Follow-up
<div class="perspective-panel" data-perspective="skeptic" data-section="followup">
  [Probing questions — .question-card items with .q-text "What to verify" and .q-why "What this reveals if the answer is wrong"]
  <div class="callout yellow"><strong>Recommendation:</strong> [conditional verdict — "yes if X", "wait until Y", or "needs validation on Z"]</div>
</div>

CRITICAL HTML CONTRACT — do NOT use class="visible", id="panel-xxx", or any other attribute name.
Use only data-perspective="skeptic" and class="perspective-panel". The JavaScript toggle depends on this exact pattern.

CSS variables available: --bg, --surface, --surface2, --border, --text, --muted, --accent, --accent2, --green, --yellow, --red, --blue, --purple, --mono, and *-bg variants.
```

---

### Agent 5: Adversary Perspective Agent (ISOLATED — no context)

This agent receives **only the source material** and its assigned perspective. No session context.

**Prompt template:**

```
You are making the strongest defensible case AGAINST this subject — whether that means: against hiring this candidate, against adopting this technology, against approving this proposal, against this architecture. Apply to what makes sense given the subject.

You are not being unfair. You are applying a high bar rigorously and focusing on evidence. Do not manufacture concerns — only raise things genuinely supported by the source material.

## Subject
<SUBJECT — source material paths or content only. No evaluation context.>

## What to produce

Return structured HTML content only. For EACH of the following interpretive sections, produce a separate panel:

Section: Verdict
<div class="perspective-panel" data-perspective="adversary" data-section="verdict">
  <div class="callout red"><strong>Adversary Verdict:</strong> [bold verdict sentence — clear no, or strong conditional no]<br>[2–3 sentences of evidence-based reasoning citing specific files/classes/passages]</div>
</div>

Section: Concerns
<div class="perspective-panel" data-perspective="adversary" data-section="concerns">
  [Damaging concerns — use .concern-card with .verdict.confirmed for confirmed problems]
  [Be specific: cite file names, function names, line numbers. Generic concerns are not credible.]
</div>

Section: Signals
<div class="perspective-panel" data-perspective="adversary" data-section="signals">
  [Damaging evidence — <ul class="signal-list"> with red dots, each item citing a specific source location]
  [What does a strong candidate / good architecture / correct proposal look like that is absent here?]
</div>

Section: Gaps
<div class="perspective-panel" data-perspective="adversary" data-section="gaps">
  [Gap severity reframe: characterize the overall gap from an adversarial lens]
  [Which gaps are individually disqualifying vs. collectively disqualifying?]
</div>

Section: Follow-up
<div class="perspective-panel" data-perspective="adversary" data-section="followup">
  [Adversarial probes — .question-card items with .q-text "What to challenge" and .q-why "What it reveals if they can't answer"]
  <div class="callout red"><strong>Recommendation:</strong> [specific verdict and minimum conditions to reconsider]</div>
</div>

CRITICAL HTML CONTRACT — do NOT use class="visible", id="panel-xxx", or any other attribute name.
Use only data-perspective="adversary" and class="perspective-panel". The JavaScript toggle depends on this exact pattern.

CSS variables available: --bg, --surface, --surface2, --border, --text, --muted, --accent, --accent2, --green, --yellow, --red, --blue, --purple, --mono, and *-bg variants.
```

---

## Phase 3 — Assemble the HTML

After all agents complete (or after 10 minutes, proceed with completed agents and note any pending), assemble the final HTML page. Parse the `<!-- SOURCES_LOG ... -->` comment from Agent 1's output to build the Sources section.

### HTML page structure

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title><SUBJECT_LABEL> — Concept Explorer</title>
  <style>/* Full design system — see below */</style>
</head>
<body>
  <!-- Sidebar nav -->
  <nav>
    <!-- Brand + subject label + content type badge -->
    <!-- Verdict badge (updates with perspective) -->
    <!-- Nav links: one per section id -->
    <!-- Perspective descriptions block at bottom of sidebar -->
  </nav>

  <main>
    <!-- Sticky perspective bar (4 buttons + theme toggle) -->
    <div class="perspective-bar" id="perspective-bar">
      <span class="pb-label">Reading as:</span>
      <div class="pb-options">
        <button class="pb-btn" data-p="advocate"  onclick="setPerspective('advocate')">▲ Advocate</button>
        <button class="pb-btn active" data-p="realist"   onclick="setPerspective('realist')">◆ Realist</button>
        <button class="pb-btn" data-p="skeptic"   onclick="setPerspective('skeptic')">? Skeptic</button>
        <button class="pb-btn" data-p="adversary" onclick="setPerspective('adversary')">▼ Adversary</button>
      </div>
      <span class="pb-desc" id="pb-desc">Grounded operational view — names real strengths and real costs</span>
      <button class="theme-toggle" id="theme-toggle" onclick="toggleTheme()" title="Toggle light/dark mode">◑</button>
    </div>

    <!-- Verdict section (perspective-toggled) -->
    <section id="verdict">
      <h2>Verdict</h2>
      <!-- All 4 perspective panels for "verdict" -->
      <!-- data-perspective="advocate"  data-section="verdict" -->
      <!-- data-perspective="realist"   data-section="verdict"  class="active" -->
      <!-- data-perspective="skeptic"   data-section="verdict" -->
      <!-- data-perspective="adversary" data-section="verdict" -->
    </section>

    <!-- Aristotelian analysis section (perspective-independent) -->
    <section id="aristotle">
      <h2>Aristotelian Analysis</h2>
      <p class="section-intro">Cold read — no session context. Four-cause analysis of what this subject actually is, what it is for, and where it falls short of its own telos.</p>
      <!-- Agent 2 output here -->
    </section>

    <!-- Factual sections (perspective-independent) -->
    <!-- Agent 1 Part A: one <section> per factual section -->
    <!-- Must include Entity Relationships section with SVG relation-map -->

    <!-- Interpretive sections (perspective-toggled) -->
    <!-- For each: Concerns, Signals, Gaps, Follow-up -->
    <!-- Each section contains 4 perspective panels (advocate/realist/skeptic/adversary) -->
    <section id="concerns"><h2>Concerns</h2><!-- 4 panels --></section>
    <section id="signals"><h2>Signals</h2><!-- 4 panels --></section>
    <section id="gaps"><h2>Gaps</h2><!-- 4 panels --></section>
    <section id="followup"><h2>Follow-up</h2><!-- 4 panels --></section>

    <!-- Sources & Citations (mandatory, perspective-independent) -->
    <section id="sources">
      <h2>Sources & Citations</h2>
      <p class="section-intro">Every source read during the exploration phase, plus sources expected but not found.</p>
      <!-- Table built from Agent 1's SOURCES_LOG -->
      <table class="comparison-table">
        <thead><tr><th>Source</th><th>Type</th><th>Status</th><th>Notes</th></tr></thead>
        <tbody>
          <!-- FOUND rows: class="win" on Status cell -->
          <!-- GAP rows: class="lose" on Status cell -->
        </tbody>
      </table>
    </section>

    <hr class="section-divider">
  </main>

  <script>/* JS — see below */</script>
</body>
</html>
```

---

### HTML Design System Reference

The assembly agent must use this exact CSS variable palette and component set for visual consistency across all generated pages.

#### CSS Variables

```css
/* Dark mode (default) */
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

/* Light mode overrides — applied via [data-theme="light"] on <html>,
   or automatically when the OS prefers light and no manual override is set */
[data-theme="light"],
@media (prefers-color-scheme: light) { :root:not([data-theme="dark"]) {
  --bg: #f6f8fc;
  --surface: #ffffff;
  --surface2: #eef0f7;
  --border: #d1d5e8;
  --text: #1a1d27;
  --muted: #5a6478;
  --accent: #4f52d8;
  --accent2: #6366f1;
  --green-bg: rgba(22,163,74,0.08);
  --yellow-bg: rgba(202,138,4,0.08);
  --red-bg: rgba(220,38,38,0.08);
  --blue-bg: rgba(37,99,235,0.08);
  --purple-bg: rgba(124,58,237,0.08);
}}

/* When [data-theme="light"] is set manually, ensure it wins over media query */
[data-theme="light"] {
  --bg: #f6f8fc;
  --surface: #ffffff;
  --surface2: #eef0f7;
  --border: #d1d5e8;
  --text: #1a1d27;
  --muted: #5a6478;
  --accent: #4f52d8;
  --accent2: #6366f1;
  --green-bg: rgba(22,163,74,0.08);
  --yellow-bg: rgba(202,138,4,0.08);
  --red-bg: rgba(220,38,38,0.08);
  --blue-bg: rgba(37,99,235,0.08);
  --purple-bg: rgba(124,58,237,0.08);
}
```

#### Core Layout

```css
* { box-sizing: border-box; margin: 0; padding: 0; }
body { display: flex; background: var(--bg); color: var(--text); font-family: var(--font); font-size: 15px; line-height: 1.6; min-height: 100vh; }
nav { width: 240px; flex-shrink: 0; background: var(--surface); border-right: 1px solid var(--border); position: sticky; top: 0; height: 100vh; overflow-y: auto; padding: 24px 0; display: flex; flex-direction: column; }
main { flex: 1; padding: 40px 56px; max-width: 1120px; }
section { margin-bottom: 72px; scroll-margin-top: 24px; }
h2 { font-size: 20px; font-weight: 700; margin-bottom: 20px; color: var(--text); }
h3 { font-size: 16px; font-weight: 600; margin: 24px 0 12px; color: var(--text); }
h4 { font-size: 14px; font-weight: 600; margin: 16px 0 8px; color: var(--muted); }
p { color: var(--muted); margin-bottom: 12px; }
.section-intro { font-size: 13px; color: var(--muted); margin-bottom: 24px; font-style: italic; }
pre { background: var(--surface2); border: 1px solid var(--border); border-radius: 8px; padding: 16px; overflow-x: auto; font-family: var(--mono); font-size: 13px; margin: 16px 0; }
code { font-family: var(--mono); font-size: 13px; background: var(--surface2); padding: 2px 6px; border-radius: 4px; color: var(--accent2); }
hr.section-divider { border: none; border-top: 1px solid var(--border); margin: 48px 0; }
```

#### Sidebar Nav

```css
.nav-brand { padding: 0 20px 20px; border-bottom: 1px solid var(--border); margin-bottom: 16px; }
.nav-brand-label { font-size: 13px; font-weight: 700; color: var(--text); line-height: 1.3; }
.nav-brand-type { font-size: 11px; color: var(--muted); margin-top: 2px; }
.verdict-badge { font-size: 11px; font-weight: 700; margin-top: 8px; }
.nav-section-label { font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 1px; color: var(--muted); padding: 12px 20px 6px; }
nav a { display: block; padding: 6px 20px; font-size: 13px; color: var(--muted); text-decoration: none; transition: color 0.15s, background 0.15s; }
nav a:hover, nav a.active { color: var(--text); background: var(--surface2); }
.nav-perspective-desc { padding: 16px 20px; border-top: 1px solid var(--border); margin-top: auto; }
.nav-perspective-desc p { font-size: 11px; color: var(--muted); line-height: 1.5; margin: 0; }
```

#### Component Classes

| Class | Usage |
|---|---|
| `.badge .green/.yellow/.red/.blue/.purple` | Pill badges — status, tags |
| `.callout .green/.yellow/.red/.blue` | Left-bordered callout box — verdicts, warnings, findings |
| `.card` | Surface card with border and padding |
| `.cards-grid` | 2-column card grid |
| `.signal-list` | Dot-prefixed evidence list — use `.dot.green/.red/.yellow/.blue` |
| `.concern-card` | Finding card with `.verdict .refuted/.confirmed/.mixed` label |
| `.question-card` | Interview question with `.q-text` and `.q-why` children |
| `.comparison-table` | Full-width table with `.win`/`.lose` cell coloring |
| `.timeline` / `.timeline-item` | Vertical timeline with accent dots |
| `.erd-table` / `.erd-header` / `.erd-col` | Database table display |
| `.decision-card` | Decision card with `.dc-label.decision/.tradeoff/.rationale` sections |
| `.pipeline-node` | Clickable node in a pipeline diagram — toggles a `.node-detail` panel |
| `.relation-map` | Container for inline SVG entity relationship diagrams |
| `.bar-chart` / `.bar-row` / `.bar-label` / `.bar-track` / `.bar-fill` / `.bar-value` | Horizontal bar chart |
| `.stat-grid` / `.stat-card` / `.stat-value` / `.stat-label` / `.stat-delta` | Metric stat cards |

#### Full Component CSS

```css
/* Badges */
.badge { display: inline-block; padding: 2px 8px; border-radius: 10px; font-size: 11px; font-weight: 600; text-transform: uppercase; letter-spacing: 0.5px; }
.badge.green { background: var(--green-bg); color: var(--green); border: 1px solid var(--green); }
.badge.yellow { background: var(--yellow-bg); color: var(--yellow); border: 1px solid var(--yellow); }
.badge.red { background: var(--red-bg); color: var(--red); border: 1px solid var(--red); }
.badge.blue { background: var(--blue-bg); color: var(--blue); border: 1px solid var(--blue); }
.badge.purple { background: var(--purple-bg); color: var(--purple); border: 1px solid var(--purple); }

/* Callouts */
.callout { border-left: 3px solid; padding: 14px 16px; border-radius: 0 8px 8px 0; margin: 16px 0; font-size: 14px; }
.callout.green { border-color: var(--green); background: var(--green-bg); color: var(--text); }
.callout.yellow { border-color: var(--yellow); background: var(--yellow-bg); color: var(--text); }
.callout.red { border-color: var(--red); background: var(--red-bg); color: var(--text); }
.callout.blue { border-color: var(--blue); background: var(--blue-bg); color: var(--text); }

/* Cards */
.card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 20px; margin-bottom: 12px; }
.cards-grid { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; margin: 16px 0; }

/* Signal list */
.signal-list { list-style: none; padding: 0; margin: 12px 0; }
.signal-list li { display: flex; align-items: flex-start; gap: 10px; padding: 6px 0; font-size: 14px; color: var(--muted); border-bottom: 1px solid var(--surface2); }
.signal-list li:last-child { border-bottom: none; }
.dot { width: 8px; height: 8px; border-radius: 50%; flex-shrink: 0; margin-top: 6px; }
.dot.green { background: var(--green); }
.dot.red { background: var(--red); }
.dot.yellow { background: var(--yellow); }
.dot.blue { background: var(--blue); }
.dot.muted { background: var(--muted); }

/* Concern card */
.concern-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin-bottom: 12px; }
.concern-card h4 { font-size: 14px; font-weight: 600; color: var(--text); margin: 0 0 8px; }
.concern-card p { font-size: 13px; color: var(--muted); margin: 0; }
.verdict { display: inline-block; font-size: 10px; font-weight: 700; text-transform: uppercase; letter-spacing: 0.5px; padding: 2px 8px; border-radius: 4px; margin-bottom: 8px; }
.verdict.confirmed { background: var(--red-bg); color: var(--red); }
.verdict.refuted { background: var(--green-bg); color: var(--green); }
.verdict.mixed { background: var(--yellow-bg); color: var(--yellow); }

/* Question card */
.question-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin-bottom: 12px; }
.q-text { font-size: 14px; font-weight: 600; color: var(--text); margin-bottom: 6px; }
.q-why { font-size: 13px; color: var(--muted); }

/* Comparison table */
.comparison-table { width: 100%; border-collapse: collapse; font-size: 14px; margin: 16px 0; }
.comparison-table th { text-align: left; padding: 10px 12px; border-bottom: 2px solid var(--border); color: var(--muted); font-size: 12px; text-transform: uppercase; letter-spacing: 0.5px; }
.comparison-table td { padding: 10px 12px; border-bottom: 1px solid var(--surface2); color: var(--muted); vertical-align: top; }
.comparison-table td.win { color: var(--green); }
.comparison-table td.lose { color: var(--red); }

/* Timeline */
.timeline { border-left: 2px solid var(--border); margin: 16px 0 16px 8px; padding-left: 20px; }
.timeline-item { position: relative; padding-bottom: 20px; }
.timeline-item::before { content: ''; position: absolute; left: -27px; top: 6px; width: 10px; height: 10px; border-radius: 50%; background: var(--accent); border: 2px solid var(--bg); }
.timeline-item h4 { font-size: 14px; font-weight: 600; color: var(--text); margin: 0 0 4px; }
.timeline-item p { font-size: 13px; color: var(--muted); margin: 0; }

/* ERD table */
.erd-table { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; overflow: hidden; margin-bottom: 12px; }
.erd-header { background: var(--surface2); padding: 8px 14px; font-size: 12px; font-weight: 700; color: var(--accent2); text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid var(--border); }
.erd-col { display: flex; align-items: center; gap: 10px; padding: 7px 14px; border-bottom: 1px solid var(--surface2); font-size: 13px; }
.erd-col:last-child { border-bottom: none; }
.erd-col .col-type { font-size: 11px; color: var(--accent); font-family: var(--mono); }
.erd-col .col-flag { font-size: 10px; color: var(--muted); margin-left: auto; }

/* Relation map */
.relation-map { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 16px; margin: 16px 0; overflow-x: auto; }
.relation-map svg { display: block; }

/* Bar chart */
.bar-chart { margin: 16px 0; }
.bar-row { display: flex; align-items: center; gap: 10px; margin-bottom: 10px; }
.bar-label { width: 180px; font-size: 13px; color: var(--muted); text-align: right; flex-shrink: 0; }
.bar-track { flex: 1; height: 8px; background: var(--surface2); border-radius: 4px; overflow: hidden; }
.bar-fill { height: 100%; border-radius: 4px; transition: width 0.4s; }
.bar-fill.green { background: var(--green); }
.bar-fill.red { background: var(--red); }
.bar-fill.yellow { background: var(--yellow); }
.bar-fill.blue { background: var(--blue); }
.bar-fill.purple { background: var(--purple); }
.bar-value { width: 40px; font-size: 12px; color: var(--muted); text-align: right; }

/* Stat grid */
.stat-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(130px, 1fr)); gap: 12px; margin: 16px 0; }
.stat-card { background: var(--surface); border: 1px solid var(--border); border-radius: 8px; padding: 18px; text-align: center; }
.stat-value { font-size: 34px; font-weight: 700; color: var(--text); line-height: 1; }
.stat-value.green { color: var(--green); }
.stat-value.red { color: var(--red); }
.stat-value.yellow { color: var(--yellow); }
.stat-value.blue { color: var(--blue); }
.stat-label { font-size: 11px; color: var(--muted); margin-top: 6px; text-transform: uppercase; letter-spacing: 0.5px; }
.stat-delta { font-size: 12px; margin-top: 4px; }
```

#### Four-Perspective Toggle System

```css
.perspective-bar { position: sticky; top: 0; z-index: 100; background: var(--surface); border-bottom: 1px solid var(--border); padding: 12px 0; display: flex; align-items: center; gap: 16px; margin-bottom: 40px; }
.pb-label { font-size: 12px; color: var(--muted); font-weight: 600; white-space: nowrap; }
.pb-options { display: flex; gap: 6px; }
.pb-btn { padding: 6px 14px; border-radius: 20px; border: 1px solid var(--border); background: var(--surface2); color: var(--muted); font-size: 12px; font-weight: 600; cursor: pointer; transition: all 0.15s; white-space: nowrap; }
.pb-btn:hover { border-color: var(--muted); color: var(--text); }
.pb-btn.active[data-p="advocate"]  { background: var(--green-bg);  border-color: var(--green);  color: var(--green); }
.pb-btn.active[data-p="realist"]   { background: var(--blue-bg);   border-color: var(--blue);   color: var(--blue); }
.pb-btn.active[data-p="skeptic"]   { background: var(--yellow-bg); border-color: var(--yellow); color: var(--yellow); }
.pb-btn.active[data-p="adversary"] { background: var(--red-bg);    border-color: var(--red);    color: var(--red); }
.pb-desc { font-size: 12px; color: var(--muted); font-style: italic; }
.theme-toggle { margin-left: auto; background: var(--surface2); border: 1px solid var(--border); color: var(--muted); border-radius: 50%; width: 28px; height: 28px; font-size: 14px; cursor: pointer; display: flex; align-items: center; justify-content: center; flex-shrink: 0; transition: all 0.15s; }
.theme-toggle:hover { color: var(--text); border-color: var(--muted); }
.perspective-panel { display: none; }
.perspective-panel.active { display: block; }
```

```javascript
const PERSPECTIVE_DESCS = {
  advocate:  'Strongest defensible case for — evidence-based advocacy',
  realist:   'Grounded operational view — names real strengths and real costs',
  skeptic:   'Substantive concerns and unresolved questions — conditional verdict',
  adversary: 'Strongest defensible case against — high-bar rigorous critique'
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
  const badge = document.querySelector('.verdict-badge');
  if (badge) {
    const labels  = { advocate: '▲ Advocate', realist: '◆ Realist', skeptic: '? Skeptic', adversary: '▼ Adversary' };
    const colors  = { advocate: 'var(--green)', realist: 'var(--blue)', skeptic: 'var(--yellow)', adversary: 'var(--red)' };
    badge.textContent = labels[p];
    badge.style.color = colors[p];
  }
}
// Scroll-based nav highlighting
const sections = document.querySelectorAll('section[id]');
const navLinks  = document.querySelectorAll('nav a');
const observer  = new IntersectionObserver(entries => {
  entries.forEach(entry => {
    if (entry.isIntersecting) {
      navLinks.forEach(l => l.classList.remove('active'));
      const a = document.querySelector(`nav a[href="#${entry.target.id}"]`);
      if (a) a.classList.add('active');
    }
  });
}, { threshold: 0.3 });
sections.forEach(s => observer.observe(s));
// Initialize on Realist
setPerspective('realist');

// Theme toggle — persists to localStorage, respects prefers-color-scheme as default
function toggleTheme() {
  const html = document.documentElement;
  const current = html.getAttribute('data-theme');
  // If no override, detect OS preference as the current state
  const osPrefersDark = window.matchMedia('(prefers-color-scheme: dark)').matches;
  const isDark = current === 'dark' || (!current && osPrefersDark);
  const next = isDark ? 'light' : 'dark';
  html.setAttribute('data-theme', next);
  localStorage.setItem('ce-theme', next);
}
// On load: apply saved preference, fall back to OS preference
(function() {
  const saved = localStorage.getItem('ce-theme');
  if (saved) document.documentElement.setAttribute('data-theme', saved);
})();
```

---

### Assembly rules

1. **Do not truncate agent output.** Embed all content from all five agents in full.

2. **Every interpretive section contains exactly 4 perspective panels.** The interpretive sections are: Verdict, Concerns, Signals, Gaps, Follow-up. For each, embed all four panels in order: advocate → realist → skeptic → adversary. The realist panel should have `class="perspective-panel active"` on initial load; all others get `class="perspective-panel"`.

3. **Use `data-perspective` + optionally `data-section`** to match agents' output. The JS toggle uses only `data-perspective`. Do not use `id`, `class="visible"`, or any other attribute to control visibility.

4. **Entity Relationships section must have an SVG diagram.** If Agent 1 produced one, embed it. If not, produce one during assembly. No plain-text-only relationship section.

5. **Sources & Citations section is mandatory.** Parse Agent 1's `<!-- SOURCES_LOG ... -->` comment to build the table. If no log was produced, list what files you know were read and mark any obvious gaps (e.g., "No OpenAPI spec found in service repos").

6. **Aristotelian section is perspective-independent.** Never wrap it in a perspective panel.

7. **Factual sections are perspective-independent.** Never wrap them in perspective panels.

8. **Sidebar nav must link to every section.** Group under labels: Analysis, [Content-type sections], Evaluation, Sources.

9. **If an agent didn't finish**, note it: `<div class="callout yellow">Agent result pending — refresh or re-run</div>`.

### CRITICAL: Perspective panel HTML contract

**Do not improvise attribute names, class names, or JavaScript.** Use this exact pattern — no variations:

```html
<!-- Realist is active by default (initial load) -->
<div class="perspective-panel active" data-perspective="realist">...</div>
<div class="perspective-panel" data-perspective="advocate">...</div>
<div class="perspective-panel" data-perspective="skeptic">...</div>
<div class="perspective-panel" data-perspective="adversary">...</div>
```

Forbidden alternatives — these break the toggle:
- `class="visible"` instead of `class="active"` ❌
- `id="panel-xxx-realist"` instead of `data-perspective="realist"` ❌
- Custom `setPerspective` implementations that differ from the one in this skill ❌
- Using old perspective names: `standard`, `supportive` ❌

The JavaScript uses `el.dataset.perspective === p` and `.classList.toggle('active', ...)`. Any deviation breaks the toggle. Copy the JS verbatim from the **Four-Perspective Toggle System** section above.

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
# write HTML content to OUTPUT_FILE using the Write tool
```

### Open in browser

```bash
open "$OUTPUT_FILE"
```

### Confirm to user

Tell the user:
- File path
- Sections included (factual + interpretive)
- Perspectives available (Advocate / Realist / Skeptic / Adversary)
- Whether Aristotelian analysis was included
- Number of sources found vs. gaps documented
- Top 1–2 findings surfaced (from the Realist read)
- Any agents that didn't complete

---

## Notes

- **Exploration phase is non-negotiable.** For architecture subjects especially, single-file analysis misses everything. The exploration phase must read all service repos, OpenAPI specs, ADRs, and config files before any analysis begins.
- **Isolated agents are critical.** The Advocate, Skeptic, and Adversary agents must not receive any evaluation framing, prior opinions, or session context. Their value comes from a genuinely cold read. Pass only source material paths/content.
- **Aristotelian analysis surprises.** The isolated four-cause agent consistently surfaces things that context-aware analysis misses — especially in the Final Cause (telos) and gap analysis. Don't skip it.
- **No neutral perspective.** The four perspectives all take a position. The goal is not balance — it is to stress-test the subject from every angle. The reader synthesizes; the agents advocate.
- **Entity relationships must be visual.** A table of names is not sufficient. The SVG relation-map shows structure at a glance; the table provides detail. Both should be present where entities exist.
- **Charts where the data exists.** Don't manufacture metrics. Use bar charts and stat cards only when there is actual quantitative data (test coverage %, file counts, dependency counts, severity distributions).
- **Sources section builds trust.** Listing every source read — including gaps — tells the reader exactly what the analysis is based on and what it might be missing.
- **Assembly agent size.** Full HTML for a complex subject can exceed 2000 lines. Use the Write tool directly. If context limits are hit, split factual and interpretive passes and combine.
- **Reuse for different lenses.** The same skill can be invoked multiple times on the same subject with different `FOCUS_ANGLES` to go deeper on a specific dimension.

---

## Reference

- Design system: see HTML Design System Reference section above
- Session dir: read from `.agents/references/local.md` as `SESSION_DIR`
- Subagent launching: Task tool with `subagent_type: "general"` — launch all 5 in a single response
- File writing: Write tool directly for HTML files > 8KB
- Inspired by: interview take-home review session (2026-05-29, session `b9dc20af`)
