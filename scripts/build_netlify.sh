#!/usr/bin/env bash
# build_netlify.sh — one folder to drag onto Netlify: this site AND the Explorer / Query Builder, together.
#
#   bash scripts/build_netlify.sh        then upload the _site folder (Netlify → Deploy manually)
#
# The Explorer is built from the explore repo (beside this one, around it, or $EXPLORE_DIR — as dev_all.sh
# finds it) into _site/explore/, and every link to the LIVE Explorer (https://calcofi.io/explore/…) in the
# built pages is pointed at that copy, so the whole preview is the new version. Docs, ERDDAP and the other
# apps still open their live sites. Reuses the release record already in _data/ (run dev_all.sh --refresh first
# for a newer one).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
export PYTHONUTF8=1 RUBYOPT=-Eutf-8

EXPLORE="${EXPLORE_DIR:-}"
for d in "$ROOT/../explore" "$ROOT/.."; do
  [ -z "$EXPLORE" ] && [ -f "$d/package.json" ] && grep -q '"name": "explore"' "$d/package.json" && EXPLORE="$(cd "$d" && pwd)"
done
[ -n "$EXPLORE" ] || { echo "no explore repo found (set EXPLORE_DIR=/path/to/explore)" >&2; exit 1; }

echo "1/3  the site"
bundle exec jekyll build --config _config.yml,_config.netlify.yml

echo "2/3  the Explorer and the Query Builder ($EXPLORE)"
[ -d "$EXPLORE/node_modules" ] || (cd "$EXPLORE" && npm install --no-audit --no-fund)
(cd "$EXPLORE" && npm run build)
rm -rf _site/explore && mkdir -p _site/explore && cp -R "$EXPLORE/dist/." _site/explore/

echo "3/3  links to the live Explorer → this preview's copy"
find _site -path _site/explore -prune -o \( -name '*.html' -o -name '*.json' \) -type f -print0 \
  | xargs -0 sed -i 's#https://calcofi\.io/explore/#/explore/#g'

echo "done: upload $ROOT/_site to Netlify (Deploy manually)"
