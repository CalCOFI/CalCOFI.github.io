#!/usr/bin/env bash
# dev_all.sh — the homepage and the Explorer on this machine, from ONE terminal:
#   http://localhost:4000         this site (Jekyll), its Explorer / Table builder buttons pointing at ↓
#   http://localhost:5178         the Explorer (Vite, from the explore repo), /builder.html = the Table builder
# Ctrl+C stops both. The explore repo is found beside this one (../explore), around it (..), or at $EXPLORE_DIR.
#
#   bash scripts/dev_all.sh            reuse the release record already in _data/ (skips the download, the gem install and
#                                      the tests): the fast restart
#   bash scripts/dev_all.sh --refresh  download the promoted release again first (scripts/build.sh), as a fresh clone does
# The first run on a clone always refreshes. While it runs, Jekyll rebuilds on every saved edit: no restart needed.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
# Windows' Python and Ruby read files in the old Windows code page unless told otherwise; the release record is UTF-8
export PYTHONUTF8=1 RUBYOPT=-Eutf-8

EXPLORE="${EXPLORE_DIR:-}"
for d in "$ROOT/../explore" "$ROOT/.."; do
  [ -z "$EXPLORE" ] && [ -f "$d/package.json" ] && grep -q '"name": "explore"' "$d/package.json" && EXPLORE="$(cd "$d" && pwd)"
done
if [ -n "$EXPLORE" ]; then
  echo "Explorer: $EXPLORE → http://localhost:5178  (Table builder: http://localhost:5178/builder.html)"
  [ -d "$EXPLORE/node_modules" ] || (cd "$EXPLORE" && npm install --no-audit --no-fund)
  # the Explorer's log lives OUTSIDE this site: Jekyll watches every file here and rebuilds the whole site (minutes) on
  # any change, so a log inside it kept the homepage rebuilding forever
  LOG="${TMPDIR:-/tmp}/calcofi-explore-dev.log"
  echo "  its log: $LOG"
  (cd "$EXPLORE" && npm run dev -- --strictPort > "$LOG" 2>&1) &
  EXPLORE_PID=$!
  trap 'kill $EXPLORE_PID 2>/dev/null || true' EXIT INT TERM
else
  echo "NOTE: no explore repo found (set EXPLORE_DIR=/path/to/explore) — the homepage's Explorer buttons will 404" >&2
fi

echo "Homepage: http://localhost:4000  (Ctrl+C stops both)"
if [ "${1:-}" = "--refresh" ] || [ ! -f _data/datasets.json ]; then
  bash scripts/build.sh serve --config _config.yml,_config.local.yml
else
  rel="$(python3 -c "import json;d=json.load(open('_data/datasets.json'));r=d.get('release');print(r if isinstance(r,str) else (r or {}).get('version') or d.get('version') or 'the last download')" 2>/dev/null || echo 'the last download')"
  echo "reusing the release record in _data/ ($rel) — run with --refresh to download the latest"
  bundle exec jekyll serve --config _config.yml,_config.local.yml
fi
