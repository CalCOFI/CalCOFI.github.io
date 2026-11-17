#!/usr/bin/env bash
# build_netlify.sh — one folder to drag onto Netlify: this site AND the Explorer / Query Builder, together.
#
#   bash scripts/build_netlify.sh        then upload the _site folder (Netlify → Deploy manually)
#
# The Explorer is built from the explore repo (beside this one, around it, or $EXPLORE_DIR — as dev_all.sh
# finds it) into _site/explore/, and every link to the LIVE Explorer (https://calcofi.io/explore/…) in the
# built pages is pointed at that copy, so the whole preview is the new version. Docs, ERDDAP and the other
# apps still open their live sites. Reuses the release record already in _data/ (run dev_all.sh --refresh first
# for a newer one). Runs on macOS, Linux and Git Bash (bash, bundle, npm, perl).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONUTF8=1 RUBYOPT=-Eutf-8

EXPLORE="${EXPLORE_DIR:-}"
for d in "$ROOT/../explore" "$ROOT/.."; do
  [ -z "$EXPLORE" ] && [ -f "$d/package.json" ] && grep -q '"name": "explore"' "$d/package.json" && EXPLORE="$(cd "$d" && pwd)"
done
# EXPLORE_DIST=/path/to/an/already/built/dist skips the Explorer build (it must hold index.html, built with the
# Explorer's own base "./"); QUERY_DIST=/path/to/a/built/dist-query does the same for the Query Builder, which has
# its own address (/query/; `npm run build:query` in the explore repo, where its code lives);
# OUT=/some/folder writes the preview there instead of _site
DIST="${EXPLORE_DIST:-}"
QDIST="${QUERY_DIST:-}"
OUT="${OUT:-_site}"
[ -n "$EXPLORE" ] || { [ -n "$DIST" ] && [ -n "$QDIST" ]; } || { echo "no explore repo found (set EXPLORE_DIR=/path/to/explore, or EXPLORE_DIST and QUERY_DIST to built folders)" >&2; exit 1; }

echo "1/3  the site"
bundle exec jekyll build --config _config.yml,_config.netlify.yml -d "$OUT"

if [ -n "$DIST" ]; then
  echo "2/3  the Explorer (already built: $DIST)"
else
  echo "2/3  the Explorer ($EXPLORE)"
  [ -d "$EXPLORE/node_modules" ] || (cd "$EXPLORE" && npm install --no-audit --no-fund)
  (cd "$EXPLORE" && VITE_QUERY_URL=/query/ npm run build)
  DIST="$EXPLORE/dist"
fi
[ -f "$DIST/index.html" ] || { echo "no index.html in $DIST" >&2; exit 1; }
rm -rf "$OUT/explore" && mkdir -p "$OUT/explore" && cp -R "$DIST/." "$OUT/explore/"
if [ -n "$QDIST" ]; then
  echo "     the Query Builder (already built: $QDIST)"
else
  echo "     the Query Builder ($EXPLORE, build:query)"
  [ -d "$EXPLORE/node_modules" ] || (cd "$EXPLORE" && npm install --no-audit --no-fund)
  (cd "$EXPLORE" && VITE_BASE=/query/ npm run build:query)
  QDIST="$EXPLORE/dist-query"
fi
[ -f "$QDIST/index.html" ] || { echo "no index.html in $QDIST" >&2; exit 1; }
rm -rf "$OUT/query" && mkdir -p "$OUT/query" && cp -R "$QDIST/." "$OUT/query/"

echo "3/3  links to the live Explorer and the live Query Builder → this preview's copies"
# perl, not `sed -i`: GNU sed takes -i alone and BSD sed (macOS) takes the next word as a backup suffix, so
# `sed -i 's#…#g'` stopped here on a Mac with "invalid command code" and left every link on the live site.
# perl -pi is the same on macOS, Linux and Git Bash. The .js files too: assets/species.js builds Explorer links.
find "$OUT" \( -path "$OUT/explore" -o -path "$OUT/query" \) -prune -o \( -name '*.html' -o -name '*.json' -o -name '*.js' \) -type f -print0 \
  | xargs -0 perl -pi -e 's#https://calcofi\.io/(explore|query)/#/$1/#g'
# (grep exits 1 when it finds nothing, which is the good case: `|| true` keeps pipefail from ending the script on it)
left=$( (grep -rl --include='*.html' --include='*.js' --include='*.json' --exclude-dir=explore --exclude-dir=query -E 'https://calcofi\.io/(explore|query)/' "$OUT" || true) | wc -l | tr -d ' ')
[ "$left" = "0" ] || { echo "$left file(s) under $OUT still link the live Explorer or Query Builder" >&2; exit 1; }

echo "done: upload $OUT to Netlify (Deploy manually), or serve it: python3 -m http.server --directory $OUT"
