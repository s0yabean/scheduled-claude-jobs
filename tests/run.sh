#!/usr/bin/env bash
# Offline tests. No Claude calls, no network, no launchctl. Uses a temp dir for all state.
#   bash tests/run.sh
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT
pass=0; fail=0
ok()  { echo "ok   $*"; pass=$((pass + 1)); }
bad() { echo "FAIL $*"; fail=$((fail + 1)); }
check() { local d="$1"; shift; if "$@"; then ok "$d"; else bad "$d"; fi; }

# --- syntax / lint ---
for f in "$ROOT"/scripts/*.sh "$ROOT"/local/*.sh "$ROOT"/tests/*.sh; do
  check "bash -n $(basename "$f")" bash -n "$f"
done
if command -v shellcheck >/dev/null; then
  check "shellcheck" shellcheck "$ROOT"/scripts/*.sh "$ROOT"/local/*.sh "$ROOT"/tests/*.sh
else
  echo "skip shellcheck (not installed)"
fi
check "plist template is well-formed XML" xmllint --noout "$ROOT/local/com.example.folder-summary.plist"

# --- bootstrap: fresh skill checkout from the (synthetic) skills repo ---
SKDIR="$TMP/claude-skills"
SKILLS="dependency-digest folder-summary" SKILLS_DIR_OVERRIDE="$ROOT/examples/skills-repo" \
  CLAUDE_SKILLS_DIR="$SKDIR" bash "$ROOT/scripts/bootstrap.sh" >/dev/null
check "bootstrap links dependency-digest" test -f "$SKDIR/dependency-digest/SKILL.md"
check "bootstrap links folder-summary" test -f "$SKDIR/folder-summary/SKILL.md"
check "bootstrap fails on a missing skill" \
  bash -c "! SKILLS=nope SKILLS_DIR_OVERRIDE='$ROOT/examples/skills-repo' CLAUDE_SKILLS_DIR='$SKDIR' bash '$ROOT/scripts/bootstrap.sh' 2>/dev/null"

# Clone path: a throwaway git repo stands in for the remote skills repo.
REMOTE="$TMP/remote-skills"; cp -R "$ROOT/examples/skills-repo" "$REMOTE"
git -C "$REMOTE" init -q && git -C "$REMOTE" add -A \
  && git -C "$REMOTE" -c user.name=test -c user.email=test@example.com commit -qm init
SK2="$TMP/claude-skills-2"
(cd "$TMP" && SKILLS="dependency-digest" SKILLS_REPO_URL="file://$REMOTE" \
  CLAUDE_SKILLS_DIR="$SK2" bash "$ROOT/scripts/bootstrap.sh" >/dev/null)
check "bootstrap clones the skills repo when no checkout exists" test -f "$SK2/dependency-digest/SKILL.md"

# --- install.sh --print renders the plist without touching launchd ---
PL="$TMP/rendered.plist"
WATCH_DIR="$TMP/watch" INTERVAL=3600 bash "$ROOT/local/install.sh" --print > "$PL"
check "rendered plist is valid" plutil -lint -s "$PL"
check "rendered plist has no placeholders" bash -c "! grep -q '__' '$PL'"
check "rendered plist runs the installed copy" grep -q "$HOME/.local/bin/folder-summary.sh" "$PL"

# --- folder-summary.sh: since-time state ---
W="$TMP/watch"; S="$TMP/state"; mkdir -p "$W"
echo "draft: pricing page, TODO add FAQ" > "$W/pricing.md"   # synthetic file
echo "meeting notes, synthetic"          > "$W/notes.txt"
touch -t 202001010000 "$W/old.md"                             # older than any since-time
run() { WATCH_DIR="$W" STATE_DIR="$S" bash "$ROOT/local/folder-summary.sh" 2>/dev/null; }
latest() { find "$S/digests" -name '*.md' | sort | tail -1; }

DRY_RUN=1 run
D="$(latest)"
check "dry run writes a digest" test -f "$D"
check "dry run lists changed files" grep -q "pricing.md" "$D"
check "dry run skips files older than since-time" bash -c "! grep -q 'old.md' '$D'"
check "dry run does not move last_success" test ! -f "$S/last_success"

# Fake claude that succeeds: proves the real path writes output and moves last_success.
FAKE="$TMP/bin"; mkdir -p "$FAKE"
printf '#!/bin/sh\necho "# Summary (fake claude)"\n' > "$FAKE/claude-ok"
printf '#!/bin/sh\necho partial; exit 1\n' > "$FAKE/claude-fail"
chmod +x "$FAKE"/claude-*

sleep 1
CLAUDE_BIN="$FAKE/claude-ok" run
check "real run writes claude output" grep -q "fake claude" "$(latest)"
check "real run records last_success" test -s "$S/last_success"
FIRST="$(cat "$S/last_success")"

sleep 2
echo "new file" > "$W/new.md"
before="$(cat "$S/last_success")"
if CLAUDE_BIN="$FAKE/claude-fail" run; then bad "failed claude run exits non-zero"; else ok "failed claude run exits non-zero"; fi
check "failed run leaves last_success unchanged" test "$(cat "$S/last_success")" = "$before"
check "failed run leaves no partial file" bash -c "! ls '$S'/digests/*.tmp >/dev/null 2>&1"

DRY_RUN=1 run
D="$(latest)"
check "next run covers only files since last success" grep -q "new.md" "$D"
check "next run excludes files from before last success" bash -c "! grep -q 'pricing.md' '$D'"
check "since-time in prompt equals last_success" grep -q "Since: $FIRST" "$D"

echo
echo "$pass passed, $fail failed"
[ "$fail" -eq 0 ]
