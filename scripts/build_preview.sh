#!/usr/bin/env bash
# build_preview.sh — calcofi.io as it would look with a dataset its provider has not yet agreed to
# publish, built from a candidate release in the private preview bucket, for the sign-in-only
# calcofi-preview service (CalCOFI/workflows preview/, plan 2026-11-02).
#
#   scripts/build_preview.sh <dataset_key> <release_base> [out_dir]
#   scripts/build_preview.sh sio_cetacean-sightings \
#     https://storage.googleapis.com/calcofi-preview/ducklake-preview/releases _site_preview
#
# The site is served under /d/<key>/f/site/ and the Explorer build beside it under
# /d/<key>/f/explore/, so: --baseurl, Explorer links rewritten to the private Explorer, and the
# few script defaults that assume the domain root made relative to it. Not a production build
# (JEKYLL_ENV unset), so no analytics tag; `preview: true` drops the feedback button, which would
# otherwise file a public GitHub issue. The release is read with the caller's gcloud token.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

KEY="${1:?dataset key, e.g. sio_cetacean-sightings}"
# where the preview service shows the build: /d/<key> (iap mode) or, in link mode, the
# /<key>/<token> workflows' scripts/build_preview.sh mints (PREVIEW_URLBASE)
URLBASE="${PREVIEW_URLBASE:-/d/$KEY}"
BASE="${2:?release base, e.g. https://storage.googleapis.com/calcofi-preview/ducklake-preview/releases}"
OUT="${3:-_site_preview}"
SITE="$URLBASE/f/site"
EXPLORE="$URLBASE/f/explore/"
# the candidate's object URLs name the PUBLIC bucket under the preview root (calcofi4db builds
# them on CC_STORAGE_HTTPS); the service streams those objects at /d/<key>/data/<root>/ behind the
# same sign-in, and serves the held notebook's render as /d/<key>/f/ingest.html
BUCKET="${BASE#https://storage.googleapis.com/}"; BUCKET="${BUCKET%%/*}"
ROOT="$(basename "$(dirname "$BASE")")"
DATA="$URLBASE/data/$ROOT/"
NOTEBOOK="$URLBASE/f/ingest.html"

export CALCOFI_RELEASE_BASE="$BASE"
export CALCOFI_RELEASE_TOKEN="${CALCOFI_RELEASE_TOKEN:-$(gcloud auth print-access-token)}"
export CALCOFI_SKIP_LINK_CHECK=1
# the per-cast measurements are measured from the candidate's own objects (fetch_dataset_measurements.py)
export CALCOFI_OBJECT_BASE="https://storage.googleapis.com/${BASE#https://storage.googleapis.com/}"
CALCOFI_OBJECT_BASE="${CALCOFI_OBJECT_BASE%%/ducklake*}"
unset JEKYLL_ENV

scripts/fetch_release.sh

printf 'preview: true\nfeedback_url: ""\n' > _config.preview.yml
trap 'rm -f _config.preview.yml' EXIT
bundle exec jekyll build --config _config.yml,_config.preview.yml --baseurl "$SITE" -d "$OUT"

# the absolute links and root-relative defaults a sub-path build cannot reach by itself
find "$OUT" -type f \( -name '*.html' -o -name '*.js' -o -name '*.json' -o -name '*.xml' \) -print0 |
  xargs -0 perl -pi -e "
    s{https://calcofi\.io/explore/}{$EXPLORE}g;
    s{https://storage\.googleapis\.com/(?:calcofi-db|$BUCKET)/$ROOT/}{$DATA}g;
    s{https://calcofi\.io/workflows/ingest_$KEY\.html}{$NOTEBOOK}g;
    s{((?:href|src)=\")/(?!/|\Q${URLBASE#/}\E/)}{\$1$SITE/}g;
    s{(['\"])/brand/v2/}{\$1$SITE/brand/v2/}g;
    s{(['\"])/datasets/search\.json}{\$1$SITE/datasets/search.json}g;
    s{(all: ['\"])/(datasets|species|measurements)/}{\$1$SITE/\$2/}g;
    s{\|\| ['\"]/(species|measurements)/['\"]}{|| '$SITE/\$1/'}g;"

echo "built $OUT for $KEY (baseurl $SITE, Explorer $EXPLORE)"
