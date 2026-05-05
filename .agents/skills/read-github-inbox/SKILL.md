---
name: read-github-inbox
description: Query GitHub for today's actionable items — PRs needing review, assigned issues, unread notifications, and CI failures — and write a structured daily summary to Obsidian. Designed to be invoked by prepare-daily-plan or run standalone.
---

# Skill: Read GitHub Inbox

Fetch today's GitHub signals and write a structured summary to Obsidian. Idempotent — safe to run multiple times; overwrites today's file.

---

## Local References

```bash
VAULT_PATH="/Users/stevenaquino/Documents/Obsidian Vault: Work"
GH_SUMMARY_DIR="$VAULT_PATH/Inbox Summaries/GitHub"
TODAY=$(date +%Y-%m-%d)
OUTPUT="$GH_SUMMARY_DIR/$TODAY GitHub Summary.md"
mkdir -p "$GH_SUMMARY_DIR"
```

If `gh` is not available or not authenticated, write a stub summary noting the gap.

---

## Phase 1 — PRs Requiring My Review

```bash
gh pr list --state open \
  --json number,title,author,reviewDecision,createdAt,url,repository \
  --search "review-requested:@me" \
  | python3 -c "
import json, sys
from datetime import datetime, timezone

prs = json.load(sys.stdin)
for p in sorted(prs, key=lambda x: x['createdAt']):
    age = (datetime.now(timezone.utc) - datetime.fromisoformat(p['createdAt'].replace('Z','+00:00'))).days
    repo = p.get('repository', {}).get('name', '')
    print(f'#{p[\"number\"]} [{repo}] {p[\"title\"]} — by {p[\"author\"][\"login\"]} ({age}d old) {p[\"url\"]}')
" 2>/dev/null || echo "(gh unavailable or no results)"
```

---

## Phase 2 — My Open PRs (authored)

```bash
gh pr list --author @me --state open \
  --json number,title,reviewDecision,isDraft,createdAt,url,repository \
  | python3 -c "
import json, sys
from datetime import datetime, timezone

prs = json.load(sys.stdin)
for p in prs:
    status = p.get('reviewDecision') or 'awaiting review'
    draft = ' [DRAFT]' if p.get('isDraft') else ''
    repo = p.get('repository', {}).get('name', '')
    age = (datetime.now(timezone.utc) - datetime.fromisoformat(p['createdAt'].replace('Z','+00:00'))).days
    print(f'#{p[\"number\"]} [{repo}] {p[\"title\"]}{draft} — {status} ({age}d old) {p[\"url\"]}')
" 2>/dev/null || echo "(gh unavailable or no results)"
```

---

## Phase 3 — Assigned Issues

```bash
gh issue list \
  --assignee @me \
  --state open \
  --json number,title,labels,createdAt,url,repository \
  | python3 -c "
import json, sys
issues = json.load(sys.stdin)
for i in issues:
    labels = ', '.join(l['name'] for l in i.get('labels', []))
    repo = i.get('repository', {}).get('name', '')
    print(f'#{i[\"number\"]} [{repo}] {i[\"title\"]} [{labels}] {i[\"url\"]}')
" 2>/dev/null || echo "(gh unavailable or no results)"
```

---

## Phase 4 — Unread Notifications

```bash
gh api notifications \
  | python3 -c "
import json, sys
notifications = json.load(sys.stdin)
for n in notifications[:20]:
    repo = n.get('repository', {}).get('full_name', '')
    subject = n.get('subject', {})
    print(f'[{n[\"reason\"]}] [{repo}] {subject.get(\"title\",\"\")} — {subject.get(\"url\",\"\")}')
" 2>/dev/null || echo "(gh unavailable or no notifications)"
```

---

## Phase 5 — CI Failures on My PRs

For each open PR from Phase 2, check for failing check runs:

```bash
# Get the head SHA for each open PR and check CI status
gh pr list --author @me --state open --json number,headRefOid,url \
  | python3 -c "
import json, sys, subprocess
prs = json.load(sys.stdin)
for p in prs:
    result = subprocess.run(
        ['gh', 'api', f'repos/carrumhealth/{{REPO}}/commits/{p[\"headRefOid\"]}/check-runs'],
        capture_output=True, text=True
    )
    try:
        checks = json.loads(result.stdout).get('check_runs', [])
        failed = [c['name'] for c in checks if c['conclusion'] == 'failure']
        if failed:
            print(f'PR #{p[\"number\"]}: FAILING — {failed}')
    except:
        pass
" 2>/dev/null || true
```

---

## Phase 6 — Write GitHub Summary to Obsidian

Categorize and write:

| Priority | Criteria |
|----------|----------|
| 🔴 Needs Review | PRs assigned to me for review, oldest first |
| 🔴 CI Failing | My PRs with failing checks |
| 🟡 My Open PRs | PRs I authored — awaiting review or change requested |
| 🟡 Draft PRs | My draft PRs (in flight) |
| 🟢 Assigned Issues | Open issues assigned to me |
| 📬 Notifications | Unread GitHub notifications (mentions, CI, etc.) |

**Template:**

```markdown
# GitHub Summary — YYYY-MM-DD

> Generated: HH:MM

---

## 🔴 Review Requested
- [#NNN repo — Title](url) — by @author (N days old)

## 🔴 CI Failing
- [#NNN repo — Title](url) — failing: check-name

## 🟡 My Open PRs
- [#NNN repo — Title](url) — awaiting review (N days old)

## 🟡 My Draft PRs
- [#NNN repo — Title](url) [DRAFT]

## 🟢 Assigned Issues
- [#NNN repo — Title](url) [label]

## 📬 Notifications (top 10)
- [reason] repo — Title
```

Write to `$OUTPUT`. Omit sections with no items.

---

## Phase 7 — Return Summary Path

```bash
echo "GITHUB_SUMMARY=$OUTPUT"
```

---

## Notes

- This skill is **read-only** — it does not merge PRs, close issues, or post comments.
- Scope: defaults to `carrumhealth` org. If working across multiple orgs, adjust `gh` queries with `--repo` or org-scoped flags.
- If `gh` is not authenticated, write a stub file: "GitHub summary unavailable — run `gh auth login`."
- Output path: `Inbox Summaries/GitHub/YYYY-MM-DD GitHub Summary.md`
