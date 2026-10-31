#!/usr/bin/env bash
# Local folder summary. Runs on the Mac under launchd, because it reads local files that a
# cloud routine cannot see.
#
# Covers everything changed since the last SUCCESSFUL run, so a run missed while the laptop
# slept just makes the next summary longer. last_success only moves forward when a run succeeds.
#
# Env:
#   WATCH_DIR   folder to summarise (required; must be readable by launchd, so not ~/Desktop,
#               ~/Documents or ~/Downloads unless you grant Full Disk Access)
#   STATE_DIR   state, logs and digests (default ~/.local/state/scheduled-claude-jobs/folder-summary)
#   DRY_RUN=1   do everything except call Claude: list the changed files and the prompt
#   CLAUDE_BIN  claude executable (default: claude on PATH)
set -euo pipefail
export PATH="$HOME/.local/bin:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin"

: "${WATCH_DIR:?set WATCH_DIR to the folder to summarise}"
STATE_DIR="${STATE_DIR:-$HOME/.local/state/scheduled-claude-jobs/folder-summary}"
CLAUDE_BIN="${CLAUDE_BIN:-claude}"
DRY_RUN="${DRY_RUN:-0}"

mkdir -p "$STATE_DIR/digests" "$STATE_DIR/logs"
LAST_FILE="$STATE_DIR/last_success"
NOW="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
if [ -f "$LAST_FILE" ]; then
  SINCE="$(cat "$LAST_FILE")"
else
  SINCE="$(date -u -v-24H +%Y-%m-%dT%H:%M:%SZ 2>/dev/null || date -u -d '24 hours ago' +%Y-%m-%dT%H:%M:%SZ)"
fi
STAMP="$(date +%Y-%m-%d_%H%M%S)"
OUT="$STATE_DIR/digests/$STAMP.md"
LOG="$STATE_DIR/logs/$STAMP.log"

log() { echo "$(date -u +%H:%M:%SZ) $*" | tee -a "$LOG" >&2; }

[ -d "$WATCH_DIR" ] && [ -r "$WATCH_DIR" ] || { log "WATCH_DIR not readable: $WATCH_DIR (launchd privacy?), skipping"; exit 0; }

# Files changed since the since-time. BSD find cannot parse ISO dates, so convert the
# since-time to a reference file's mtime and use -newer (works on BSD and GNU find).
to_epoch() { TZ=UTC date -j -f "%Y-%m-%dT%H:%M:%SZ" "$1" +%s 2>/dev/null || date -u -d "$1" +%s; }
to_touch() { date -r "$1" +%Y%m%d%H%M.%S 2>/dev/null || date -d "@$1" +%Y%m%d%H%M.%S; }
REF="$(mktemp)"
trap 'rm -f "$REF"' EXIT
touch -t "$(to_touch "$(to_epoch "$SINCE")")" "$REF"
CHANGED="$(find "$WATCH_DIR" -type f -newer "$REF" ! -name '.*' 2>/dev/null | sort || true)"
N="$(printf '%s' "$CHANGED" | grep -c . || true)"
log "since=$SINCE now=$NOW changed=$N dry_run=$DRY_RUN"

if [ "$N" -eq 0 ]; then
  printf '# Folder summary %s\n\nNo changes since %s.\n' "$NOW" "$SINCE" > "$OUT"
  echo "$NOW" > "$LAST_FILE"
  log "nothing changed, wrote $OUT"
  exit 0
fi

PROMPT="Summarise what changed in these files since ${SINCE} (now is ${NOW}). For each file: one line on what it is and what changed. Then a short 'Needs attention' list (open questions, TODOs, anything that looks unfinished). Read the files only; do not edit, move or delete anything. Output markdown only.

Files:
${CHANGED}"

# Read-only tools only. No Write, Edit or Bash.
ALLOWED="Read,Glob,Grep"

if [ "$DRY_RUN" = "1" ]; then
  {
    printf '# Folder summary %s (DRY RUN, Claude not called)\n\n' "$NOW"
    # shellcheck disable=SC2016  # the backticks are a literal markdown fence
    printf 'Since: %s\nChanged files: %s\nAllowed tools: %s\n\n## Prompt that would be sent\n\n```\n%s\n```\n' \
      "$SINCE" "$N" "$ALLOWED" "$PROMPT"
  } > "$OUT"
  # Dry runs do not move last_success, so the next real run still covers the same window.
  log "dry run, wrote $OUT (last_success unchanged)"
  exit 0
fi

if (cd "$WATCH_DIR" && "$CLAUDE_BIN" -p "$PROMPT" --allowedTools "$ALLOWED") > "$OUT.tmp" 2>>"$LOG"; then
  mv "$OUT.tmp" "$OUT"
  echo "$NOW" > "$LAST_FILE"
  log "ok, wrote $OUT"
  osascript -e 'display notification "New folder summary ready" with title "Folder summary"' >/dev/null 2>&1 || true
else
  rm -f "$OUT.tmp"
  log "claude run failed, last_success unchanged"
  exit 1
fi
