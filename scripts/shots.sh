#!/usr/bin/env bash
# Reproducibly (re)capture product-card screenshots for calcofi.io.
#
# Recipes live in ../_data/shots.yml (shot-scraper "multi" format). Each writes
# images/<key>.png at 1200x750, dismissing any welcome modal / guided tour
# first. Captured PNGs are then compressed in place with pngquant.
#
# Uses your installed Google Chrome by default (`-b chrome`): the map apps
# render H3/WebGL hexagon layers that Playwright's bundled Chromium leaves
# blank. Override with e.g. SHOT_BROWSER=chromium for non-WebGL pages.
#
# One-time setup:
#   pipx install shot-scraper && shot-scraper install   # Playwright driver
#   brew install pngquant                                # macOS (or apt, etc.)
#
# Usage:
#   scripts/shots.sh                 # capture every recipe in _data/shots.yml
#   scripts/shots.sh db-viz-hex      # only cards whose image name contains this
#   scripts/shots.sh db-viz-hex offshore-wind-monitoring
set -euo pipefail
cd "$(dirname "$0")/.."

browser=${SHOT_BROWSER:-chrome}

for cmd in shot-scraper pngquant; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "error: '$cmd' not found — see the setup notes at the top of $0" >&2
    exit 1
  }
done

# all output paths declared in the config (handles the "- output:" list dash)
all_outputs=$(awk '/^[[:space:]]*-?[[:space:]]*output:/ {sub(/.*output:[[:space:]]*/, ""); print}' _data/shots.yml)

# build the subset to (re)capture: everything, or only paths matching an arg
filters=""
targets="$all_outputs"
if [ "$#" -gt 0 ]; then
  targets=""
  for key in "$@"; do
    for out in $all_outputs; do
      case "$out" in
        *"$key"*) filters="$filters -o $out"; targets="$targets $out" ;;
      esac
    done
  done
  [ -n "$targets" ] || { echo "error: no recipe in _data/shots.yml matches: $*" >&2; exit 1; }
fi

# shellcheck disable=SC2086
shot-scraper multi _data/shots.yml --browser "$browser" $filters

for png in $targets; do
  [ -f "$png" ] && pngquant --quality=65-90 --strip --force --ext .png "$png" \
    && echo "compressed $png"
done
