#!/usr/bin/env bash
# fetch_tutorial_apngs.sh -- POSIX twin of fetch_tutorial_apngs.ps1.
#
# Pulls tutorial APNGs from origin/assets into doc/source/_static/tutorials/.
# Used by the CI docs build (Ubuntu runner) before sphinx-build runs.
#
# Usage:
#   bash modules/dasImgui/tests/integration/fetch_tutorial_apngs.sh [remote]
#
# Default remote = origin. Override with the first positional arg if your
# checkout uses a different remote name (e.g. `upstream`).

set -euo pipefail

REMOTE="${1:-origin}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
TUTORIAL_DIR="$REPO_ROOT/doc/source/_static/tutorials"

echo "[fetch_tutorial_apngs] remote: $REMOTE"
echo "[fetch_tutorial_apngs] target: $TUTORIAL_DIR"

cd "$REPO_ROOT"

# --depth 1 keeps the local fetch small (we only ever want the tip).
git fetch --depth 1 "$REMOTE" assets

mkdir -p "$TUTORIAL_DIR"

# Restrict to *.apng so the orphan branch's README.md doesn't bleed in.
git checkout FETCH_HEAD -- doc/source/_static/tutorials/*.apng

# Unstage -- they're .gitignored but checkout-from-ref stages them anyway.
git reset HEAD -- doc/source/_static/tutorials/*.apng >/dev/null

count=$(find "$TUTORIAL_DIR" -maxdepth 1 -name '*.apng' | wc -l | tr -d ' ')
total_kb=$(du -ck "$TUTORIAL_DIR"/*.apng | tail -1 | awk '{print $1}')
total_mb=$((total_kb / 1024))
echo "[fetch_tutorial_apngs] $count APNGs (${total_mb} MB) ready in $TUTORIAL_DIR"
