#!/usr/bin/env bash
# fetch_release.sh — put the release's catalog sidecars in _data/ so Jekyll can build the
# dataset pages from the record and nothing else. Run before `bundle exec jekyll build`
# (scripts/build.sh does both; .github/workflows/{pages,refresh}.yml run it too).
#
#   _data/datasets.json   the record (calcofi4db::build_dataset_catalog(), schema 1.0)
#   _data/versions.json   the release history (the release strip's "all releases")
#   _data/grid.geojson    the 218 station-grid cells (the bbox map's backdrop)
#
# All three are git-ignored: the site is a rendering of the promoted release, never a copy of it.
#
# Resolution order — the production prefix's own `latest.txt`, and nothing else from that prefix:
#   1. GET {RELEASE_BASE}/latest.txt  → the promoted version
#   2. if {RELEASE_BASE}/{version}/datasets.json exists, that is the record
#   3. otherwise fall back to $DATASETS_RELEASE_URL (a full URL to a datasets.json), print a
#      loud NOTE, and never guess another version under the production prefix
#
# The fallback is the bridge until the next data release: v2026.09.04 was promoted before
# build_dataset_catalog() existed, and Ben decided not to cut a release for the sidecars alone
# (plan § Measured, 2026-09-05), so the record lives on the staging prefix until then.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="$ROOT/_data"

RELEASE_BASE="${CALCOFI_RELEASE_BASE:-https://storage.googleapis.com/calcofi-db/ducklake/releases}"
FALLBACK_URL="${DATASETS_RELEASE_URL:-https://storage.googleapis.com/calcofi-db/ducklake-staging/releases/v2026.09.05/datasets.json}"

mkdir -p "$DATA"

get() {  # get <url> <dest>; quiet, fails on any non-2xx
  curl -fsSL --retry 3 --retry-delay 2 -o "$2" "$1"
}

version="$(curl -fsSL --retry 3 "$RELEASE_BASE/latest.txt" | tr -d '[:space:]' || true)"
if [ -z "$version" ]; then
  echo "ERROR: could not resolve $RELEASE_BASE/latest.txt" >&2
  exit 1
fi
echo "promoted release: $version"

record_url="$RELEASE_BASE/$version/datasets.json"
if get "$record_url" "$DATA/datasets.json"; then
  source_kind="promoted"
else
  record_url="$FALLBACK_URL"
  source_kind="fallback"
  echo
  echo "NOTE: datasets.json from a non-promoted release ------------------------------------"
  echo "NOTE: the promoted release $version carries no datasets.json (it predates the catalog)."
  echo "NOTE: building from  $record_url"
  echo "NOTE: set DATASETS_RELEASE_URL (env / repo variable) to change it; this whole fallback"
  echo "NOTE: goes away with the next data release, which writes datasets.json to the"
  echo "NOTE: production prefix and makes step 2 above succeed."
  echo "NOTE: ------------------------------------------------------------------------------"
  echo
  get "$record_url" "$DATA/datasets.json"
fi

# the sidecars that travel with the record: grid.geojson from the SAME release folder, so the
# station grid and the bboxes drawn over it always come from one release
record_dir="${record_url%/*}"
get "$record_dir/grid.geojson" "$DATA/grid.geojson" ||
  echo "WARN: no grid.geojson beside the record — the bbox maps will draw without the station grid" >&2

# versions.json is release-history, kept at the prefix root, never inside a version folder
get "$RELEASE_BASE/versions.json" "$DATA/versions.json" ||
  echo "WARN: no versions.json at $RELEASE_BASE — the release strip will show this release only" >&2

python3 - "$DATA/datasets.json" "$source_kind" "$record_url" <<'PY'
import json, sys
path, kind, url = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path))
c = d.get("counts", {})
print(f"record {kind}: schema {d.get('schema_version')} · release {d['release']['version']} · "
      f"{c.get('datasets')} datasets · {c.get('holdings')} holdings · {c.get('reference')} reference rows")
print(f"       {url}")
PY
