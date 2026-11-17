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
# EXPLORE_DIST=/path/to/an/already/built/dist skips the Explorer build (it must hold index.html and builder.html,
# built with the Explorer's own base "./"); OUT=/some/folder writes the preview there instead of _site
DIST="${EXPLORE_DIST:-}"
OUT="${OUT:-_site}"
[ -n "$EXPLORE" ] || [ -n "$DIST" ] || { echo "no explore repo found (set EXPLORE_DIR=/path/to/explore, or EXPLORE_DIST=/path/to/dist)" >&2; exit 1; }

echo "1/3  the site"
bundle exec jekyll build --config _config.yml,_config.netlify.yml -d "$OUT"

if [ -n "$DIST" ]; then
  echo "2/3  the Explorer and the Query Builder (already built: $DIST)"
else
  echo "2/3  the Explorer and the Query Builder ($EXPLORE)"
  [ -d "$EXPLORE/node_modules" ] || (cd "$EXPLORE" && npm install --no-audit --no-fund)
  (cd "$EXPLORE" && npm run build)
  DIST="$EXPLORE/dist"
fi
[ -f "$DIST/index.html" ] && [ -f "$DIST/builder.html" ] || { echo "no index.html and builder.html in $DIST" >&2; exit 1; }
rm -rf "$OUT/explore" && mkdir -p "$OUT/explore" && cp -R "$DIST/." "$OUT/explore/"

echo "3/3  links to the live Explorer → this preview's copy"
# perl, not `sed -i`: GNU sed takes -i alone and BSD sed (macOS) takes the next word as a backup suffix, so
# `sed -i 's#…#g'` stopped here on a Mac with "invalid command code" and left every link on the live site.
# perl -pi is the same on macOS, Linux and Git Bash. The .js files too: assets/species.js builds Explorer links.
find "$OUT" -path "$OUT/explore" -prune -o \( -name '*.html' -o -name '*.json' -o -name '*.js' \) -type f -print0 \
  | xargs -0 perl -pi -e 's#https://calcofi\.io/explore/#/explore/#g'
# (grep exits 1 when it finds nothing, which is the good case: `|| true` keeps pipefail from ending the script on it)
left=$( (grep -rl --include='*.html' --include='*.js' --include='*.json' --exclude-dir=explore 'https://calcofi\.io/explore/' "$OUT" || true) | wc -l | tr -d ' ')
[ "$left" = "0" ] || { echo "$left file(s) under $OUT still link the live Explorer" >&2; exit 1; }

echo "done: upload $OUT to Netlify (Deploy manually), or serve it: python3 -m http.server --directory $OUT"
