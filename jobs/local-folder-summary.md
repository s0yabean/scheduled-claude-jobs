# local-folder-summary

- **Cadence:** every 2 hours while the Mac is awake, covering everything since the last successful run
- **Runner:** Mac launchd (`local/install.sh`)
- **Script:** `local/folder-summary.sh` (installed to `~/.local/bin/`)
- **Why local:** it reads a folder on your own disk. A cloud routine runs on someone else's machine
  and cannot see it. The same applies to any job that needs a desktop app or its local API.

## What it does

1. Reads `last_success` (an ISO timestamp). No file = first run, so it looks back 24 hours.
2. Lists files in `WATCH_DIR` modified since then. Nothing changed = writes a one-line digest and stops,
   without calling Claude.
3. Calls `claude -p` with read-only tools (`Read,Glob,Grep`) to summarise the changes.
4. On success: writes `digests/<stamp>.md`, moves `last_success` to the start time of this run,
   and shows a macOS notification. On failure: deletes the partial output and leaves `last_success`
   alone, so the next run covers the same window again.

`DRY_RUN=1` does steps 1, 2 and writes the prompt it would send instead of calling Claude.
A dry run never moves `last_success`.

## Install

```bash
WATCH_DIR="$HOME/notes" bash local/install.sh
launchctl kickstart -k gui/$(id -u)/com.example.folder-summary   # run once now
```

launchd cannot read `~/Desktop`, `~/Documents` or `~/Downloads` (macOS privacy) unless you grant
Full Disk Access, which is why the installer copies the script to `~/.local/bin` and why `WATCH_DIR`
should live elsewhere.
