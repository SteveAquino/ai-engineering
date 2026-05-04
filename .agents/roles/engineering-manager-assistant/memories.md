
[2026-05-04] Gmail archive in Apple Mail: use `move ... to mailbox "Archive"` — never `mailbox "[Gmail]/All Mail"` (raises -1728, messages are already there). This correctly removes the Gmail INBOX label via IMAP.
[2026-05-04] AppleScript `whose` clause must be inline in `move` statements — `move (messages of inbox whose sender contains "x") to mailbox "Archive"`. Storing the filtered list in a variable changes the object reference type and causes -1700.
[2026-05-04] Gmail IMAP sync lag after archiving is ~30–60 seconds — archived messages remain visible in Mail.app count briefly. This is normal; not a failure.
[2026-05-04] `evaluate-research` must always run as an isolated subagent (rubber-duck, separate context window). Context isolation = structural impartiality. Never evaluate research inline in the same session that produced it.
[2026-05-04] Obsidian vault top-level research folder is `Research/` (not `Reference/`). Subdirs: `Research/AI Engineering/`, `Research/Ruby Research/`, `Research/People & Process/`. Research Digest at `Research/Research Digest.md`.
[2026-05-04] Machine-specific skill paths (vault path, mail account name) go in `references/local.md` (gitignored, never committed). Template lives in `docs/local.example.md`. Pattern applies to all skills needing absolute machine paths.
[skill-candidate] `end-of-day-wrap` (placement: role:engineering-manager-assistant): Generates/updates end-of-day note from daily plan + session history — marks completed items, surfaces carryovers, pre-read for tomorrow. First seen: 2026-05-04.
