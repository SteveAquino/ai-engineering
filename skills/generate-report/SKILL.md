---
name: generate-report
description: Generates a structured report file in the user's preferred format (default: Markdown). Documents the correct file-writing technique for Copilot CLI sessions — including what fails and the reliable /tmp Python script pattern.
---

# Skill: Generate Report

Use this skill to write a structured report to disk at the end of any research or analysis workflow. It asks the user for their preferred output format, then applies the correct file-writing technique for that format.

This skill is also a **reference** for any skill that needs to write files. Several obvious file-writing approaches fail silently — this skill documents all known failure modes and the one pattern that reliably works.

**Invoked by:** `deep-research` or any skill that produces a document.

---

## Phase 0 — Output Format

Ask the user for their preferred format before writing:

**Use `ask_user`:**
> "What format should the report be in?"

Choices: `["Markdown (Recommended)", "HTML", "PDF"]`

Store as `OUTPUT_FORMAT`. Default to Markdown if the user skips.

| Format | Output | Tooling |
|---|---|---|
| **Markdown** | `.md` file in session state folder | Python write — no deps |
| **HTML** | `.html` file, self-contained with inline styles | Python `markdown` lib or manual render |
| **PDF** | `.pdf` via Markdown → HTML → PDF | Requires `pandoc` or `wkhtmltopdf` |

> For HTML and PDF, first generate the Markdown file, then convert. If conversion tooling is unavailable, fall back to Markdown and note the fallback to the user.

---

## Phase 1 — Write the File

Use the correct technique for the format.

### Markdown (default)

See the [Correct Pattern](#the-correct-pattern) section below. Always use the `/tmp` Python script approach — not heredocs or inline `python3 -c`.

### HTML

After writing the Markdown file:

```bash
# Check if markdown module is available
python3 -c "import markdown; print('ok')" 2>/dev/null || pip3 install markdown -q

python3 /tmp/convert_to_html.py
```

The conversion script:

```python
import os, markdown

md_path = "<path>.md"
html_path = "<path>.html"

with open(md_path) as f:
    body = markdown.markdown(f.read(), extensions=["tables", "fenced_code"])

html = f"""<!DOCTYPE html>
<html><head><meta charset="utf-8">
<style>
  body {{ font-family: -apple-system, sans-serif; max-width: 900px; margin: 40px auto; padding: 0 20px; line-height: 1.6; }}
  table {{ border-collapse: collapse; width: 100%; }}
  th, td {{ border: 1px solid #ddd; padding: 8px; text-align: left; }}
  th {{ background: #f5f5f5; }}
  code {{ background: #f5f5f5; padding: 2px 4px; border-radius: 3px; }}
  pre {{ background: #f5f5f5; padding: 16px; border-radius: 6px; overflow-x: auto; }}
</style>
</head><body>
{body}
</body></html>"""

with open(html_path, "w") as f:
    f.write(html)
print(f"Written: {html_path}")
```

### PDF

After generating the HTML file:

```bash
# Try pandoc first, fall back to wkhtmltopdf
if command -v pandoc &>/dev/null; then
  pandoc "<path>.md" -o "<path>.pdf" --pdf-engine=wkhtmltopdf
elif command -v wkhtmltopdf &>/dev/null; then
  wkhtmltopdf "<path>.html" "<path>.pdf"
else
  echo "No PDF tool available — delivering Markdown instead"
fi
```

If neither tool is available, deliver the Markdown file and tell the user:
> "PDF conversion requires `pandoc` or `wkhtmltopdf`. I've saved the report as Markdown instead: `<path>.md`. You can convert it using an online tool like [markdowntopdf.com](https://www.markdowntopdf.com/)."

---

## The Correct Pattern (Markdown File Writing)

**Write Python scripts to `/tmp/` via the `create` tool, then execute with `python3`.**

This is the only approach that reliably handles markdown with code fences, Mermaid diagrams, and backtick content.

---

## Failure Modes (Do Not Use These)

### 1. Heredoc with Python

```bash
python3 - << 'EOF'
content = "..."
EOF
```

**Why it fails:** The Copilot CLI shell security filter blocks heredoc patterns as a potential injection vector.

---

### 2. Inline `python3 -c` with backtick content

**Why it fails:** Backtick characters (used for code fences and Mermaid diagrams) inside a bash command string are interpreted as command substitution. The security filter blocks the command. This is the most common failure mode for markdown with code blocks.

---

### 3. `create` tool with large `file_text`

**Why it fails:** The `create` tool's JSON parameter encoding fails above approximately 15KB. The error message is cryptic: `"The arguments for the tool call 'create' were not valid JSON"`. The tool call is silently dropped.

---

### 4. Large `echo` / `printf` pipelines

**Why it fails:** Shell escaping breaks unpredictably on dollar signs, backslashes, and quotes. Unmanageable for any structured markdown.

---

## Script Template

Use the `create` tool to write one or more scripts to `/tmp/` (keep each under ~8KB), then run them:

```python
import os

OUT = os.path.expanduser("~/.copilot/session-state/<SESSION_ID>/<filename>.md")
TICK = chr(96)        # single backtick
TICKS = chr(96) * 3   # triple backtick — for code fences and Mermaid

section_1 = f"""# Report Title

_Generated: <date>_

## Section with Code

{TICKS}javascript
const x = 1;
{TICKS}

## Section with Mermaid

{TICKS}mermaid
flowchart TD
    A --> B
{TICKS}
"""

# First section: write mode (overwrites)
with open(OUT, "w") as f:
    f.write(section_1)

section_2 = f"""## Another Section

Content here.
"""

# Subsequent sections: append mode
with open(OUT, "a") as f:
    f.write(section_2)

print(f"Written: {OUT}")
```

**Key rules:**
- `TICKS = chr(96) * 3` — never write literal triple-backticks in a script created via the shell
- Keep each `create` call under ~8KB; split large reports across multiple scripts
- First section uses `"w"` mode; subsequent sections use `"a"` mode (append)
- Curly braces in f-strings must be doubled: `{{}}` renders as `{}`

---

## Sizing Guidelines

| Content size | Approach |
|---|---|
| < 8KB | Single Python script |
| 8–40KB | Split into 2–5 scripts; first writes, rest append |
| > 40KB | Consider splitting into multiple output files |

---

## Quick Reference

| Situation | Solution |
|---|---|
| Code fences or Mermaid in content | `TICKS = chr(96) * 3` + f-string with `{TICKS}` |
| Single backticks in content | `TICK = chr(96)` + f-string with `{TICK}` |
| Curly braces in content | Escape as `{{}}` in f-strings |
| File > 8KB | Multiple `create` calls; append with `"a"` mode |
| Idempotent output | Always use `"w"` for the first section |
| HTML output needed | Generate Markdown first, then convert with Python `markdown` lib |
| PDF output needed | Generate HTML, then `pandoc` or `wkhtmltopdf`; fall back gracefully |
