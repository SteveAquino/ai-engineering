---
name: sprint-retro
description: Generates a quantitative sprint retrospective for the engineering team. Pulls velocity, ticket completion rates, carry-over, bug delta, PR throughput, and time allocation by epic/PI/stakeholder group from Jira and GitHub. Blameless — no per-engineer breakdown. Saves to Obsidian and publishes a Confluence page. Supports interactive and autopilot modes. Requires gh and acli.
---

# Skill: Sprint Retro

Generate a quantitative engineering sprint retrospective. This skill is **blameless** — it reports on project/epic allocation and team-level throughput, never on individual engineer output. It supports both interactive and autopilot modes and writes to two destinations: Obsidian and Confluence.

**How this differs from `weekly-team-retro`:**
- Window: sprint (Jira-defined, ~2 weeks) not a calendar week
- Audience: team-facing and stakeholder-shareable, not EM-private
- Qualitative: optional team-level themes only, no per-engineer notes
- Breakdown: by epic, PI idea, and stakeholder group — not by person

**Autopilot mode:** When no user is available, skip all `ask_user` calls and generate the full report from Jira + GitHub data alone.

**Prerequisites:**
- [`gh`](https://cli.github.com/) — GitHub CLI, authenticated
- [`acli`](https://developer.atlassian.com/cloud/acli/) — Atlassian CLI, authenticated

---

## Storage

```
Obsidian: People/Sprint Retros/YYYY-MM-DD.md   (date = sprint start Monday)
Confluence: Engineering > Sprint Retros > Sprint <N> Retro
```

---

## Phase 0 — Load Team Context

Read `GITHUB_ORG`, `JIRA_PROJECT`, `JIRA_PI_PROJECT`, `JIRA_DOMAIN`, `CONFLUENCE_DOMAIN`, and `OBSIDIAN_VAULT` from `references/carrum.md`.
Read the engineer→GitHub login map and query helpers from `references/data-sources.md`.
Read pod membership, assignee→pod map, and pod assignment logic from `references/team.md`.

Pod assignment flows: **Ticket → Epic → PI Idea → Sub-team field**. Fallback: assignee → pod from `team.md`. Bugs and sub-tasks always land in **Shared** regardless of epic.

If any required value is missing, prompt for it with `ask_user`.

---

## Phase 1 — Identify Sprint

### 1a — Discover active sprint

```bash
acli jira sprint list --project TEC --state active
```

Parse the sprint name (format: `Sprint <N>`) and sprint start/end dates.

If no active sprint is found, fall back to the most recently closed sprint:

```bash
acli jira sprint list --project TEC --state closed --limit 1
```

### 1b — Confirm sprint (interactive only)

> **Use `ask_user`:**
> "Running retro for **Sprint <N>** (<start_date> – <end_date>). Is this correct?"
> Choices: `["Yes, proceed", "Use a different sprint"]`

If "Use a different sprint", prompt for the sprint name freeform.

In autopilot, proceed with the discovered sprint without confirmation.

### 1c — Check for existing retro

```python
import os
OBSIDIAN_RETRO = os.path.join(OBSIDIAN_VAULT, "People", "Sprint Retros", f"{sprint_start_date}.md")
exists = os.path.exists(OBSIDIAN_RETRO)
```

If it exists, ask (interactive):

> **Use `ask_user`:**
> "A retro for Sprint <N> already exists. What would you like to do?"
> Choices: `["Update / regenerate", "Open existing (read-only)"]`

In autopilot, regenerate.

---

## Phase 2 — Fetch Sprint Tickets

```bash
acli jira workitem list \
  --project TEC \
  --jql "project = TEC AND sprint = 'Sprint <N>'" \
  --csv --limit 300 \
  > /tmp/sprint_all.csv
```

Parse with `csv.DictReader`. For each ticket collect:
- `key`, `summary`, `issuetype`, `status`, `story_points` (or `estimate`), `epic_link`, `assignee`

### Ticket classification

| Category | Status values |
|----------|--------------|
| Completed | Done, Released, Deployed, Closed |
| Carried over | In Progress, In Review, Code Review, Acceptance Testing |
| Not started | To Do, Backlog, Open |

### Bug tickets

Separately query bugs:
```bash
acli jira workitem list \
  --project TEC \
  --jql "project = TEC AND issuetype = Bug AND sprint = 'Sprint <N>'" \
  --csv --limit 200 > /tmp/sprint_bugs.csv

acli jira workitem list \
  --project TEC \
  --jql "project = TEC AND issuetype = Bug AND status changed to Done DURING ('<sprint_start>', '<sprint_end>')" \
  --csv --limit 200 > /tmp/bugs_resolved.csv

acli jira workitem list \
  --project TEC \
  --jql "project = TEC AND issuetype = Bug AND created >= '<sprint_start>' AND created <= '<sprint_end>'" \
  --csv --limit 200 > /tmp/bugs_opened.csv
```

Compute: `bug_delta = bugs_resolved - bugs_opened` (positive = net reduction ✅, negative = net growth ⚠️)

---

## Phase 3 — Fetch PR Throughput

For each repo in the tracked list (from `carrum-applications.md`), fetch PRs merged during the sprint window using the standard query from `data-sources.md`.

Compute:
- `total_prs_merged`
- `median_review_lag_hours` — time from PR opened to first review comment
- `median_merge_lag_hours` — time from PR opened to merged

> **Note:** Review lag requires `gh pr view <N> --json reviews` per PR — only compute this for repos with <50 PRs merged in the sprint to avoid rate limits.

---

## Phase 4 — Assign Tickets to Pods

### 4a — Classify by type

> **Workflow rule:** Bugs do NOT require an epic per the team's Jira workflow. Only Stories, Tasks, and Technical Debt tickets are expected to have an epic. Bugs always land in **Shared**.

```python
EPIC_REQUIRED_TYPES = {'Story', 'Task', 'Technical Debt'}
BUG_TYPES = {'Bug'}
SUBTASK_TYPES = {'Sub-task'}

dev_tickets   = [t for t in all_tickets if t['Type'] in EPIC_REQUIRED_TYPES]
bug_tickets   = [t for t in all_tickets if t['Type'] in BUG_TYPES]
# Sub-tasks excluded from all breakdowns — counted via parent only
```

### 4b — Look up epic → PI idea → Sub-team

For each dev ticket get its epic key (via `customfield_10014` from `acli jira workitem view`).
For each unique epic, find its PI idea and read the Sub-team field:

```bash
acli jira workitem search \
  --jql "project = PI AND issue in linkedIssues('<EPIC_KEY>')" \
  --fields "key,summary,status" --csv --limit 5
```

Map PI Sub-team value → `"Pod 1"`, `"Pod 2"`, or `"Shared"`.

**Fallback chain (in order):**
1. PI Sub-team field → pod
2. Assignee account ID → pod (from `references/team.md` assignee map)
3. No match → `"Shared"`

**Bugs and sub-tasks:** Always `"Shared"` — never attempt PI lookup.

### 4c — Build per-pod ticket lists

```python
pods = {"Pod 1": [], "Pod 2": [], "Shared": []}
for ticket in dev_tickets:
    pod = ticket_pod_map.get(ticket['Key'], 'Shared')
    pods[pod].append(ticket)
for ticket in bug_tickets:
    pods['Shared'].append(ticket)
```

### 4d — Per-pod velocity

```python
COMPLETED   = {'Released', 'DONE', 'Closed', 'Deployed', 'Done'}
CARRIED     = {'In Progress', 'Code Review', 'In Review', 'Acceptance Testing', 'Ready'}

for pod_name, tickets in pods.items():
    done        = [t for t in tickets if t['Status'] in COMPLETED]
    in_flight   = [t for t in tickets if t['Status'] in CARRIED]
    not_started = [t for t in tickets if t['Status'] not in COMPLETED | CARRIED]
    velocity_pct = len(done) / len(tickets) * 100 if tickets else 0
```

---

## Phase 4.5 — Cycle Time

Measured from ticket creation date (or sprint start date, whichever is **later**) to resolution date.
Only tickets with a resolution date are included. Report excluded count.

For each completed dev ticket, fetch `resolutiondate` and `created` via `acli jira workitem view <KEY> --fields resolutiondate,created --json`. Compute per-pod P50 and P95. Include a per-ticket breakdown table truncating summaries to 55 chars.

---

## Phase 5 — Historical Trend (Sprint-Wide)

Fetch prior 2 sprints via `acli jira workitem search` with sprint JQL. Compute sprint-wide velocity % and carry-over count only (no pod breakdown for trend). Store as `trend_data: list[dict]`.

---

## Phase 6 — PR Health (Per Pod)

Fetch PRs for each repo using the standard query from `data-sources.md`, adding `additions`, `deletions`, `reviews`, and `body` fields.

**PR → Ticket linking:** Extract ticket key from PR title or body via regex `TEC-\d+`. Assign PR to pod via `ticket_pod_map`. If no ticket link → Shared.

**Per-PR metrics:**
- `size` = additions + deletions
- `first_review_lag_hours` = time from `createdAt` to first non-author, non-bot review
- `has_human_review` = any review from a non-bot, non-author login

**Per-pod summary:** total PRs, median size, median first-review lag, PRs without human review.

---

## Phase 7 — Collect Qualitative Themes (Optional)

**Interactive:** ask_user for team-level themes (blockers, wins, incidents). Choices: `["Skip — quantitative only", "Add themes..."]`

**Autopilot:** Skip. Auto-generate Highlights & Risks from data signals only.

---

## Phase 8 — Write the Retro

Write **one file per pod** using Python at `/tmp/write_sprint_retro.py`.

**Obsidian paths:**
```
People/Sprint Retros/<sprint_start_date>-pod1.md
People/Sprint Retros/<sprint_start_date>-pod2.md
```

**Document structure (one file per pod):**

```markdown
# <Pod Name> — TEC Sprint <N> Sprint Report
**Sprint dates: <start> – <end> · Generated: <date>**

---

## Sprint Overview — TEC Sprint <N>

Total sprint items (excluding sub-tasks): <N> · Sprint-wide completion: <done>/<total> (<pct>%)

| Pod | Total | Done | In Flight | Not Started | Completion |
|-----|-------|------|-----------|-------------|------------|
| Pod 1 | N | N | N | N | X% |
| Pod 2 | N | N | N | N | X% |
| Shared | N | N | N | N | X% |
| Sprint Total | N | N | | | X% |

> Note: Bugs (no epic required per workflow) and sub-tasks are included in Shared.

---

## TL;DR

<Pod Name> completed <done>/<total> tickets (<pct>%) this sprint. Cycle time P50 was <X> days
(P95: <X>d, n=<N>). The pod merged <N> PRs with a median size of <N> lines and median
first-review lag of <X>h. <N> PRs received at least one human review.

---

## 1. Velocity

| Metric | Count |
|--------|-------|
| Tickets in sprint | N |
| Done | N (X%) |
| In flight (carry forward) | N |
| Not started (carry forward) | N |

### Completed Tickets

| Ticket | Summary |
|--------|---------|
| [TEC-XXXX](...) | Summary |

### Carry Forward

| Ticket | Status | Summary |
|--------|--------|---------|
| [TEC-XXXX](...) | Status | Summary |

---

## 2. Cycle Time

_Measured from ticket creation (or sprint start, whichever is later) to resolution date.
Tickets without a resolution date excluded (n=<N>)._

| Metric | Value |
|--------|-------|
| P50 (median) | X.X days |
| P95 | X.X days |
| Sample size | N tickets |
| Excluded (no resolution) | N tickets |

### Per-Ticket Breakdown

| Ticket | Summary | Cycle Time |
|--------|---------|------------|
| [TEC-XXXX](...) | Summary (55 char max) | X.Xd or — |

---

## 3. PR Health

| Metric | Value |
|--------|-------|
| PRs merged (sprint window) | N |
| Median PR size (lines changed) | N |
| Median first-review lag | X.Xh |
| PRs without human review | N |

### PR Details

| PR | Ticket | Size | Review Lag | Reviewed |
|----|--------|------|------------|----------|
| [repo #N](...) | [TEC-XXXX](...) or — | N | X.Xh | Yes/No |

---

## Shared Work This Sprint

_Work not owned by a specific pod — bugs, process, EM tasks, and tooling._

### Done (<N>)

| Ticket | Type | Summary |
|--------|------|---------|

### In Flight (<N>)

| Ticket | Type | Status | Summary |
|--------|------|--------|---------|

### Not Started (<N>)

| Ticket | Type | Summary |
|--------|------|---------|

---

## 4. Action Items

_Proposed by Copilot based on sprint data — confirm, adjust, or add at retro._

| # | Item | Ticket | Owner | Status |
|---|------|--------|-------|--------|
| 1 | <auto-generated> | TEC-XXXX or — | TL / EM | Proposed |

---

## 5. Highlights & Risks

### Highlights

- <positive signal from data: fast PRs, completed epics, strong review cadence>

### Risks / Concerns

- <risk from data: stalled high-priority epic, long carry-over, review lag>
```

**Linking rules:**
- Jira: `[TEC-XXXX](https://carrumhealth.atlassian.net/browse/TEC-XXXX)`
- GitHub PR: `[repo #N](https://github.com/carrumhealth/<repo>/pull/<N>)`

**Auto-generate Action Items from:**
- Any carry-forward ticket in Code Review >3 days → "unblock and merge before next sprint"
- Epic with 0 completions despite being in sprint → "review commitment vs capacity"
- PRs without human review → "add review SLA"
- Cycle time P95 > 10 days → "investigate longest-running tickets"
- Velocity < 70% → "review sprint sizing"

**Auto-generate Highlights from:** fully completed epics, median first-review lag < 1h, positive bug delta.

**Auto-generate Risks from:** velocity < 80%, multi-sprint stalled carry-overs, P90 merge lag > 72h, top-priority epic with 0 completions.

**Visual enhancements added to the Confluence output (not the Obsidian markdown):**

| Location | Visual element | Notes |
|----------|---------------|-------|
| After title block, before Sprint Overview | **Table of Contents** (`toc` macro) | minLevel=2, maxLevel=2 |
| After Sprint Overview table | **Stacked bar chart** — Done/In Flight/Not Started per pod | Sprint-wide; same on both pod pages |
| After TL;DR paragraph | **Pie chart** — Done vs Not Done for this pod | Pod-specific completion gauge |
| After Per-Ticket Breakdown table | **Bar chart** — cycle time per ticket (days) | Only if ≥3 data points |
| After PR Details table | **Bar chart** — review lag per PR (hours) | For Pod 2 with many PRs, filter to lag >1h |

> **Note on `expand` macro:** The Confluence `expand` macro hides headings from the `toc` macro. Do **not** wrap sections in expand macros when using the TOC — the TOC will show a blank or partial outline.

---

## Phase 9 — Publish to Confluence

**Note:** `acli confluence page create` does not exist. Use the Confluence REST API with the stored API token. Convert markdown to Confluence **storage format** (XHTML) — do NOT use the `markdown` structured macro (not installed).

**Space:** `TEC2` (Software Engineering)
**Parent page:** Find the `TEC Sprint <N>` page in TEC2 using the search API.

```python
import urllib.request, base64 as b64mod, json, subprocess, re, urllib.parse

# Retrieve token from keychain
result = subprocess.run(['security', 'find-generic-password', '-s', 'acli', '-w'], capture_output=True, text=True)
raw = result.stdout.strip()
if raw.startswith('go-keyring-base64:'):
    import base64; raw = base64.b64decode(raw[len('go-keyring-base64:'):]).decode()
TOKEN = raw.strip()
EMAIL = 'saquino@carrumhealth.com'
DOMAIN = 'https://carrumhealth.atlassian.net'
auth = b64mod.b64encode(f"{EMAIL}:{TOKEN}".encode()).decode()
headers = {'Authorization': f'Basic {auth}', 'Content-Type': 'application/json', 'Accept': 'application/json'}

# ── Confluence macros ─────────────────────────────────────────────────────────

def chart_macro(chart_type, title, rows):
    """Build a Confluence Chart macro. rows[0] = header row, rest = data rows."""
    rows_xml = ''
    for idx, row in enumerate(rows):
        tag = 'th' if idx == 0 else 'td'
        cells = ''.join(f'<{tag}>{c}</{tag}>' for c in row)
        rows_xml += f'<tr>{cells}</tr>'
    return (
        f'<ac:structured-macro ac:name="chart">'
        f'<ac:parameter ac:name="type">{chart_type}</ac:parameter>'
        f'<ac:parameter ac:name="title">{title}</ac:parameter>'
        f'<ac:rich-text-body><table><tbody>{rows_xml}</tbody></table></ac:rich-text-body>'
        f'</ac:structured-macro>'
    )

TOC_MACRO = (
    '<ac:structured-macro ac:name="toc">'
    '<ac:parameter ac:name="minLevel">2</ac:parameter>'
    '<ac:parameter ac:name="maxLevel">2</ac:parameter>'
    '<ac:parameter ac:name="style">disc</ac:parameter>'
    '</ac:structured-macro>'
)

# ── Inline formatter ──────────────────────────────────────────────────────────

def inline(text):
    text = text.replace('&','&amp;').replace('<','&lt;').replace('>','&gt;')
    text = re.sub(r'\*\*(.+?)\*\*', r'<strong>\1</strong>', text)
    text = re.sub(r'(?<!\*)\*(?!\*)(.+?)(?<!\*)\*(?!\*)', r'<em>\1</em>', text)
    text = re.sub(r'`(.+?)`', r'<code>\1</code>', text)
    text = re.sub(r'\[([^\]]+)\]\(([^)]+)\)', r'<a href="\2">\1</a>', text)
    return text

# ── Markdown → Confluence storage format ─────────────────────────────────────

def md_to_confluence(md):
    lines = md.split('\n'); out = []; in_table = in_code = False; i = 0
    while i < len(lines):
        line = lines[i]
        if line.strip().startswith('```'):
            if not in_code:
                in_code = True; lang = line.strip()[3:].strip() or 'none'
                out.append(f'<ac:structured-macro ac:name="code"><ac:parameter ac:name="language">{lang}</ac:parameter><ac:plain-text-body><![CDATA[')
            else: in_code = False; out.append(']]></ac:plain-text-body></ac:structured-macro>')
            i += 1; continue
        if in_code: out.append(line); i += 1; continue
        if line.startswith('|'):
            if not in_table: in_table = True; out.append('<table><tbody>')
            if re.match(r'^\|[\s\-\|:]+\|$', line.strip()): i += 1; continue
            cells = [c.strip() for c in line.strip('|').split('|')]
            next_line = lines[i+1] if i+1 < len(lines) else ''
            tag = 'th' if re.match(r'^\|[\s\-\|:]+\|$', next_line.strip()) else 'td'
            out.append('<tr>' + ''.join(f'<{tag}>{inline(c)}</{tag}>' for c in cells) + '</tr>')
            i += 1; continue
        elif in_table: out.append('</tbody></table>'); in_table = False
        m = re.match(r'^(#{1,4})\s+(.*)', line)
        if m: out.append(f'<h{len(m.group(1))}>{inline(m.group(2))}</h{len(m.group(1))}>'); i += 1; continue
        if re.match(r'^---+$', line.strip()): out.append('<hr/>'); i += 1; continue
        if line.startswith('> '): out.append(f'<ac:structured-macro ac:name="info"><ac:rich-text-body><p>{inline(line[2:])}</p></ac:rich-text-body></ac:structured-macro>'); i += 1; continue
        if line.startswith('- ') or line.startswith('* '):
            items = []
            while i < len(lines) and (lines[i].startswith('- ') or lines[i].startswith('* ')):
                items.append(f'<li>{inline(lines[i][2:])}</li>'); i += 1
            out.append('<ul>' + ''.join(items) + '</ul>'); continue
        if not line.strip(): out.append(''); i += 1; continue
        out.append(f'<p>{inline(line)}</p>'); i += 1
    if in_table: out.append('</tbody></table>')
    return '\n'.join(out)

# ── Visual enhancement injector ───────────────────────────────────────────────

def inject_after(html, anchor, close_tag, content):
    """Find anchor in html, then the first close_tag after it, inject content there."""
    a_pos = html.find(anchor)
    if a_pos == -1: return html
    c_pos = html.find(close_tag, a_pos)
    if c_pos == -1: return html
    ins = c_pos + len(close_tag)
    return html[:ins] + '\n' + content + '\n' + html[ins:]

def add_visual_enhancements(html, charts):
    """
    Inject TOC and chart macros into Confluence HTML after md_to_confluence().

    charts dict keys (all optional):
      sprint_overview_chart  – stacked bar after Sprint Overview table
      velocity_pie           – pie chart after TL;DR paragraph
      cycle_time_chart       – bar chart after Per-Ticket Breakdown table (only if ≥3 data points)
      pr_review_lag_chart    – bar chart after PR Details table

    Build charts with chart_macro(). For pods with many PRs (>20), filter pr rows to lag >1h.
    """
    # TOC after the first <hr/> (separator between title block and body sections)
    hr_pos = html.find('<hr/>')
    if hr_pos != -1:
        ins = hr_pos + len('<hr/>')
        html = html[:ins] + '\n' + TOC_MACRO + '\n' + html[ins:]

    if charts.get('sprint_overview_chart'):
        html = inject_after(html, '<h2>Sprint Overview', '</tbody></table>', charts['sprint_overview_chart'])
    if charts.get('velocity_pie'):
        html = inject_after(html, '<h2>TL;DR</h2>', '</p>', charts['velocity_pie'])
    if charts.get('cycle_time_chart'):
        html = inject_after(html, '<h3>Per-Ticket Breakdown</h3>', '</tbody></table>', charts['cycle_time_chart'])
    if charts.get('pr_review_lag_chart'):
        html = inject_after(html, '<h3>PR Details</h3>', '</tbody></table>', charts['pr_review_lag_chart'])
    return html

# ── Confluence publishing ─────────────────────────────────────────────────────

# Find TEC Sprint <N> parent page
resp = urllib.request.urlopen(urllib.request.Request(
    f"{DOMAIN}/wiki/rest/api/content/search?cql=space=TEC2+AND+title=%22TEC+Sprint+{SPRINT_N}%22&limit=1", headers=headers))
parent_id = json.loads(resp.read())['results'][0]['id']

def find_child(title):
    url = f"{DOMAIN}/wiki/rest/api/content/search?cql=space=TEC2+AND+title=%22{urllib.parse.quote(title)}%22+AND+ancestor={parent_id}"
    d = json.loads(urllib.request.urlopen(urllib.request.Request(url, headers=headers)).read())
    return d['results'][0]['id'] if d.get('results') else None

def publish_page(title, md_path, charts=None):
    with open(md_path) as f: content = f.read()
    body_val = md_to_confluence(content)
    if charts:
        body_val = add_visual_enhancements(body_val, charts)
    existing_id = find_child(title)
    if existing_id:
        curr = json.loads(urllib.request.urlopen(urllib.request.Request(f"{DOMAIN}/wiki/rest/api/content/{existing_id}?expand=version", headers=headers)).read())
        payload = json.dumps({"type":"page","title":title,"version":{"number":curr['version']['number']+1},"body":{"storage":{"value":body_val,"representation":"storage"}}}).encode()
        req = urllib.request.Request(f"{DOMAIN}/wiki/rest/api/content/{existing_id}", data=payload, headers=headers, method='PUT')
    else:
        payload = json.dumps({"type":"page","title":title,"ancestors":[{"id":parent_id}],"space":{"key":"TEC2"},"body":{"storage":{"value":body_val,"representation":"storage"}}}).encode()
        req = urllib.request.Request(f"{DOMAIN}/wiki/rest/api/content", data=payload, headers=headers, method='POST')
    resp = urllib.request.urlopen(req)
    d = json.loads(resp.read())
    return f"{DOMAIN}/wiki{d['_links']['webui']}"

# Build per-pod chart_data dicts from sprint data collected in Phase 2–6, then publish:
# pod1_charts = {
#   'sprint_overview_chart': chart_macro('bar', 'Sprint N — Velocity by Pod', [...]),
#   'velocity_pie':          chart_macro('pie', 'Pod 1 — Completion (X%)', [...]),
#   'cycle_time_chart':      chart_macro('bar', 'Pod 1 — Cycle Time per Ticket (days)', [...]),
#   'pr_review_lag_chart':   chart_macro('bar', 'Pod 1 — PR Review Lag (hours)', [...]),
# }
pod1_url = publish_page(f"Pod 1 — TEC Sprint {SPRINT_N} Sprint Report", '/tmp/sprint_retro_pod1.md', pod1_charts)
pod2_url = publish_page(f"Pod 2 — TEC Sprint {SPRINT_N} Sprint Report", '/tmp/sprint_retro_pod2.md', pod2_charts)
print(f"Pod 1: {pod1_url}")
print(f"Pod 2: {pod2_url}")
```

---

## Phase 10 — Open and Confirm

Open both pod files in Obsidian. Tell the user:
- Obsidian paths (both pods)
- Confluence page URLs (both pods)
- Per-pod: velocity %, carry-over count, cycle time P50
- Action items proposed

---

## Notes

- Always use Python scripts at `/tmp/` for file writing — bash heredocs with `${}` are blocked.
- Use `--csv` for all acli workitem search calls. `--json` is unreliable at >20 results. Parse with `csv.DictReader`.
- Strip `GraphQL:` prefix lines from acli JSON output before parsing (see `data-sources.md`).
- Bot logins to exclude from PR counts are listed in `data-sources.md`.
- Pod membership, assignee→pod map, and PI Sub-team lookup logic are in `references/team.md` (gitignored — create locally after cloning).
- **Epic requirement by type:** Only Stories, Tasks, and Technical Debt tickets require an epic. Bugs do NOT require an epic per the team's Jira workflow. Never flag a bug as a tracking gap. Bugs always go in Shared.
- **Blameless principle:** Never break down metrics by individual engineer name. Report by pod and epic only.
- Sprint name format at Carrum: `TEC Sprint <N>` (e.g., `TEC Sprint 146`).
- Story points are rarely populated — fall back to ticket count for velocity and note this.
- PI Sub-team lookup may fail if the field isn't populated on the PI idea. Fall back to assignee→pod from `team.md` and flag as a follow-up action item.
- **Kept DRY with `weekly-team-retro`:** Common query patterns and the engineer login map live in `references/data-sources.md` (duplicated in both skills — keep in sync).

---

## Fleet Mode

This skill is designed for background agent execution from the EM role. The following phases are parallelizable — launch them as concurrent background agents rather than running sequentially:

| Phase | Can parallelize? | How |
|-------|-----------------|-----|
| Phase 2 — Fetch Sprint Tickets | ✅ | Run alongside Phase 3 |
| Phase 3 — Fetch PR Throughput | ✅ | Run alongside Phase 2 |
| Phase 4 — Assignee lookup (per ticket) | ✅ | Batch with `time.sleep(0.06)` within one agent |
| Phase 4.5 — Cycle time fetch | ✅ | Run alongside PR health fetch |
| Phase 6 — PR Health (per pod) | ✅ | Run alongside cycle time |
| Phase 8 — Write + Phase 9 — Publish | ⚠️ Sequential | Publish depends on write output |

### Recommended invocation from EM role

```
Launch one general-purpose background agent with the full skill context.
Provide: SKILL.md path, references/ paths, sprint number (or "latest").
Agent handles all phases end-to-end and reports Obsidian paths + Confluence URLs on completion.
```

Within the agent, use `concurrent.futures.ThreadPoolExecutor` for the per-ticket Jira API calls in Phase 4 and 4.5 to reduce wall time from ~5min to ~1min.
