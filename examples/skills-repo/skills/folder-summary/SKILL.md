---
name: folder-summary
description: Summarise files changed in a local folder since a given time. Read-only.
---

# folder-summary (example skill)

Given a list of changed files and a since-time, write a markdown summary: one line per file on
what changed, then a short "Needs attention" list. Read files only; never edit, move or delete.

The launchd job (`local/folder-summary.sh`) passes this as an inline prompt so it runs without a
skills checkout. Keep it here if you would rather load it as a skill.
