# read-apple-mail — Local Configuration Reference
#
# Copy this file to references/local.md and customize for this machine.
# references/local.md is gitignored — it never leaves this machine.
#
# All keys are optional unless noted.

# ─── Consent ─────────────────────────────────────────────────────────────────

# Set to true to allow autonomous/cron runs without interactive consent prompt.
# Only set this if you have reviewed and accept the privacy implications.
# Default: false (always prompt when no user is present)
STANDING_CONSENT=false

# ─── Database ────────────────────────────────────────────────────────────────

# Override the auto-detected Envelope Index path.
# Only needed if Apple Mail stores data in a non-standard location.
# Default: auto-detect ~/Library/Mail/V*/MailData/Envelope Index
# MAIL_DB_PATH=/Users/yourname/Library/Mail/V10/MailData/Envelope Index

# ─── Query Scope ─────────────────────────────────────────────────────────────

# Maximum number of messages to retrieve per run.
# Default: 50
MAX_MESSAGES=50

# Only retrieve messages received in the last N hours.
# Useful for recurring runs. Omit for all unread.
# SINCE_HOURS=24

# Restrict to specific mailbox names only (comma-separated).
# If set, the exclusion list is ignored and only these mailboxes are scanned.
# ALLOWED_MAILBOXES=INBOX,Work
