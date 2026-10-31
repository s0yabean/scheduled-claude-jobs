#!/usr/bin/env bash
# Run as the first step of every cloud routine. Idempotent.
#
# Skills are NOT stored in this repo. They live in a separate skills repo (the source of truth)
# and are checked out fresh at the start of every run, so an edit to a skill is picked up by the
# next scheduled run with no redeploy.
#
# Env:
#   SKILLS_REPO_URL     https URL of the skills repo (placeholder in .env.example)
#   SKILLS_REPO_TOKEN   optional token for a private skills repo
#   SKILLS_DIR_OVERRIDE optional path to an existing checkout (e.g. a second repo the routine attached)
#   SKILLS              space-separated skill paths inside <repo>/skills/ to install
#   CLAUDE_SKILLS_DIR   where Claude Code looks for skills (default ~/.claude/skills)
set -euo pipefail

SKILLS="${SKILLS:-dependency-digest}"
CLAUDE_SKILLS_DIR="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}"
mkdir -p "$CLAUDE_SKILLS_DIR"

# 1. Find or clone the skills repo.
REPO_DIR=""
for c in "${SKILLS_DIR_OVERRIDE:-}" "$PWD/../skills-repo" "$PWD/skills-repo"; do
  if [ -n "$c" ] && [ -d "$c/skills" ]; then REPO_DIR="$c"; break; fi
done
if [ -z "$REPO_DIR" ]; then
  : "${SKILLS_REPO_URL:?no skills checkout found and SKILLS_REPO_URL not set}"
  REPO_DIR="$(mktemp -d)/skills-repo"
  url="$SKILLS_REPO_URL"
  if [ -n "${SKILLS_REPO_TOKEN:-}" ]; then
    url="${url/https:\/\//https://x-access-token:${SKILLS_REPO_TOKEN}@}"
  fi
  git clone -q --depth 1 "$url" "$REPO_DIR"
fi
echo "using skills repo at $REPO_DIR"

# 2. Link each skill where Claude Code will find it.
for s in $SKILLS; do
  [ -f "$REPO_DIR/skills/$s/SKILL.md" ] || { echo "missing skill: $s" >&2; exit 1; }
  ln -sfn "$REPO_DIR/skills/$s" "$CLAUDE_SKILLS_DIR/$(basename "$s")"
done

# 3. Tools the skills need. Pin versions: the cloud image's defaults are not yours.
#    Example (uncomment and adapt):
#    command -v uv >/dev/null || curl -LsSf https://astral.sh/uv/install.sh | sh
#    uv tool install --python 3.12 some-cli-tool
for s in $SKILLS; do
  d="$REPO_DIR/skills/$s/scripts"
  if [ -f "$d/package.json" ]; then (cd "$d" && npm install --silent --no-audit --no-fund); fi
done

count="$(find "$CLAUDE_SKILLS_DIR" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')"
echo "bootstrap ok: $count skill(s) linked into $CLAUDE_SKILLS_DIR"
