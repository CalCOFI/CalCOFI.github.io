#!/usr/bin/env bash
# dev_all.sh — the homepage and the Explorer on this machine, from ONE terminal:
#   http://localhost:4000         this site (Jekyll), its Explorer / Table builder buttons pointing at ↓
#   http://localhost:5178         the Explorer (Vite, from the explore repo), /builder.html = the Table builder
# Ctrl+C stops both. The explore repo is found beside this one (../explore), around it (..), or at $EXPLORE_DIR.
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
  (cd "$EXPLORE" && npm run dev -- --strictPort > "$ROOT/.explore-dev.log" 2>&1) &
  EXPLORE_PID=$!
  trap 'kill $EXPLORE_PID 2>/dev/null || true' EXIT INT TERM
else
  echo "NOTE: no explore repo found (set EXPLORE_DIR=/path/to/explore) — the homepage's Explorer buttons will 404" >&2
fi

echo "Homepage: http://localhost:4000  (Ctrl+C stops both)"
bash scripts/build.sh serve --config _config.yml,_config.local.yml
