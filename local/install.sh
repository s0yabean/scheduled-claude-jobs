#!/usr/bin/env bash
# Installs the folder-summary launchd job. Re-run to update.
#
#   WATCH_DIR=~/notes bash local/install.sh            # install and load
#   WATCH_DIR=~/notes bash local/install.sh --print    # render the plist to stdout, change nothing
#
# INTERVAL (seconds, default 7200 = every 2 hours) sets how often launchd starts the job.
# launchd only fires while the Mac is awake; missed runs are covered by the since-time.
set -euo pipefail
HERE="$(cd "$(dirname "$0")" && pwd)"
LABEL="com.example.folder-summary"
: "${WATCH_DIR:?set WATCH_DIR to the folder to summarise}"
INTERVAL="${INTERVAL:-7200}"
BIN_DIR="$HOME/.local/bin"
SCRIPT="$BIN_DIR/folder-summary.sh"

render() {
  sed -e "s#__SCRIPT__#$SCRIPT#" -e "s#__HOME__#$HOME#g" \
      -e "s#__WATCH_DIR__#$WATCH_DIR#" -e "s#__INTERVAL__#$INTERVAL#" \
      "$HERE/$LABEL.plist"
}

if [ "${1:-}" = "--print" ]; then render; exit 0; fi

case "$WATCH_DIR" in
  "$HOME/Desktop"*|"$HOME/Documents"*|"$HOME/Downloads"*)
    echo "warning: launchd jobs cannot read $WATCH_DIR without Full Disk Access (macOS privacy)." >&2 ;;
esac

mkdir -p "$HOME/.local/state/scheduled-claude-jobs/folder-summary" "$HOME/Library/LaunchAgents" "$BIN_DIR"
# launchd cannot read ~/Desktop (macOS privacy), and this repo may well be cloned there,
# so run an installed copy of the script from ~/.local/bin instead of the repo checkout.
cp "$HERE/folder-summary.sh" "$SCRIPT" && chmod +x "$SCRIPT"
DEST="$HOME/Library/LaunchAgents/$LABEL.plist"
render > "$DEST"
launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null || true
launchctl bootstrap "gui/$(id -u)" "$DEST"
echo "installed: every ${INTERVAL}s. Test now: launchctl kickstart -k gui/$(id -u)/$LABEL"
echo "uninstall: launchctl bootout gui/$(id -u)/$LABEL && rm $DEST"
