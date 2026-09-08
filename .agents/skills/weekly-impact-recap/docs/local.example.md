# weekly-impact-recap — Local Configuration Reference
#
# Copy this file to references/local.md and customize for this machine/org.
# references/local.md is gitignored — it never leaves this machine.
#
# All keys are optional. Anything left unset falls back to asking the user
# or to generic, org-agnostic behavior described in SKILL.md.

# ─── Vault / Notes Location ──────────────────────────────────────────────────

# Absolute path to the notes vault (e.g. an Obsidian vault) where daily plans,
# summaries, and the weekly recap are written/read.
# VAULT_PATH=/Users/yourname/Documents/YourVault

# ─── Role Opt-In ──────────────────────────────────────────────────────────────

# Comma-separated list of role names (matching .agents/roles/<name>/) that
# should receive a Monday weekly impact recap via prepare-daily-plan.
# If unset, prepare-daily-plan relies solely on each role's ROLE.md to signal
# whether it wants a weekly recap.
# WEEKLY_RECAP_ROLES=your-leadership-role-name

# ─── GitHub ───────────────────────────────────────────────────────────────────

# GitHub org to scope PR searches to. If unset, searches span all repos this
# account can access.
# GH_ORG=your-github-org

# ─── Jira ─────────────────────────────────────────────────────────────────────

# Jira project key(s) whose tickets count toward this recap (comma-separated
# if more than one project is relevant, e.g. an org-wide project plus a
# pod/team-specific project).
# JIRA_PROJECTS=YOURPROJECT

# Human-readable pod/team name to use in the "Team Outcomes" section header
# and attribution language (e.g. "Platform Pod", "Growth Team").
# TEAM_NAME=Your Team

# Status names that count as "released"/"done" for this org's Jira workflow,
# if they differ from the defaults assumed in SKILL.md (Released, Deployed).
# RELEASED_STATUSES=Released,Deployed

# ─── Internal Systems / Notes ────────────────────────────────────────────────

# Free-form notes on any other internal-only sources, workflows, or
# conventions this recap should account for (e.g. an internal Slack digest
# format, a specific dashboard, or an escalation channel). Keep this section
# as plain prose; it's read by the agent, not parsed as key=value.
#
# NOTES:
#   - ...
