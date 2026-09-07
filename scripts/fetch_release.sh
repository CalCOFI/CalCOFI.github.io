#!/usr/bin/env bash
# fetch_release.sh — put the release's catalog sidecars in _data/ so Jekyll can build the
# dataset pages from the record and nothing else. Run before `bundle exec jekyll build`
# (scripts/build.sh does both; .github/workflows/{pages,refresh}.yml run it too).
#
#   _data/datasets.json           the record (calcofi4db::build_dataset_catalog(), schema 1.x)
#   _data/versions.json           the release history (the release strip's "all releases")
#   _data/grid.geojson            the 218 station-grid cells (the extent map's backdrop)
#   _data/coverage_stations.json  which grid cells each dataset actually sampled, and how much
#                                 (~470 KB; read at BUILD time to draw the map's filled marks —
#                                 never shipped to the browser)
#   _data/release_catalog.json    the release's own catalog.json (the taxa count on the front door)
#
# All five are git-ignored: the site is a rendering of the promoted release, never a copy of it.
# `_data/land.geojson` is NOT here: the coastline is cartography, not a dataset fact, so it is a
# committed asset built once by scripts/build_land.py.
#
# Resolution order — the production prefix's own `latest.txt`, and nothing else from that prefix:
#   1. GET {RELEASE_BASE}/latest.txt  → the promoted version
#   2. if {RELEASE_BASE}/{version}/datasets.json exists, that is the record
#   3. otherwise fall back to $DATASETS_RELEASE_URL (a full URL to a datasets.json), print a
#      loud NOTE, and never guess another version under the production prefix
#
# v2026.09.06 (2026-09-06) was the first promoted release to write datasets.json, so step 2 now
# succeeds and step 3 fires only if DATASETS_RELEASE_URL is set on purpose (a rehearsal).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="$ROOT/_data"

RELEASE_BASE="${CALCOFI_RELEASE_BASE:-https://storage.googleapis.com/calcofi-db/ducklake/releases}"
FALLBACK_URL="${DATASETS_RELEASE_URL:-}"

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
elif [ -z "$FALLBACK_URL" ]; then
  echo "ERROR: $record_url is missing and no DATASETS_RELEASE_URL fallback is set" >&2
  exit 1
else
  record_url="$FALLBACK_URL"
  source_kind="fallback"
  echo
  echo "NOTE: datasets.json from a non-promoted release ------------------------------------"
  echo "NOTE: the promoted release $version carries no datasets.json (it predates the catalog)."
  echo "NOTE: building from  $record_url"
  echo "NOTE: DATASETS_RELEASE_URL is set; unset it to render the promoted release."
  echo "NOTE: ------------------------------------------------------------------------------"
  echo
  get "$record_url" "$DATA/datasets.json"
fi

# the sidecars that travel with the record: grid.geojson from the SAME release folder, so the
# station grid and the bboxes drawn over it always come from one release
record_dir="${record_url%/*}"
get "$record_dir/grid.geojson" "$DATA/grid.geojson" ||
  echo "WARN: no grid.geojson beside the record — the extent maps will draw without the station grid" >&2

# which cells each dataset sampled: the map's filled marks, and the frame rule's second half
get "$record_dir/coverage_stations.json" "$DATA/coverage_stations.json" ||
  echo "WARN: no coverage_stations.json beside the record — the maps will draw the grid but not the sampled stations" >&2

# the release's own catalog (calcofi4db freeze_plan(): every table with its rows, bytes and objects) —
# the landing page's `taxa` number is tables[name == taxon].rows, which the record does not carry.
# Optional: an older promoted release may have none, and the page then draws no taxa tile (plan
# 2026-09-07 § D-2: a number the build cannot read is not rendered, never typed). Named
# release_catalog.json, not catalog.json, because Jekyll would load _data/catalog.json as
# site.data.catalog — the very key _plugins/datasets.rb builds.
get "$record_dir/catalog.json" "$DATA/release_catalog.json" ||
  echo "NOTE: no catalog.json beside the record — the front door draws no taxa count" >&2

# versions.json is release-history, kept at the prefix root, never inside a version folder
get "$RELEASE_BASE/versions.json" "$DATA/versions.json" ||
  echo "WARN: no versions.json at $RELEASE_BASE — the release strip will show this release only" >&2

# each promoted version's RELEASE_NOTES.md first `##` heading, for the ship's log's release entries
# (plan 2026-09-07 § D-5) — optional, one small GET per version, a version with no notes gets none
python3 - "$DATA/versions.json" "$RELEASE_BASE" "$DATA/release_headings.json" <<'PY2' || echo "NOTE: release headings not fetched — the log names releases by version alone" >&2
import json, re, sys, urllib.request
vpath, base, out = sys.argv[1:4]
try:
    versions = [v["version"] for v in json.load(open(vpath)).get("versions", []) if v.get("version")]
except Exception:
    versions = []
heads = {}
for v in versions[:40]:
    try:
        with urllib.request.urlopen(f"{base}/{v}/RELEASE_NOTES.md", timeout=10) as r:
            for line in r.read().decode("utf-8", "replace").splitlines():
                if line.startswith("## "):
                    heads[v] = re.sub(r"[`*]", "", line[3:]).strip(); break
    except Exception:
        pass
json.dump(heads, open(out, "w"), indent=1, ensure_ascii=False)
print(f"release headings: {len(heads)} of {len(versions)} versions")
PY2

python3 - "$DATA/datasets.json" "$source_kind" "$record_url" <<'PY'
import json, sys
path, kind, url = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path))
c = d.get("counts", {})
print(f"record {kind}: schema {d.get('schema_version')} · release {d['release']['version']} · "
      f"{c.get('datasets')} datasets · {c.get('holdings')} holdings · {c.get('reference')} reference rows")
print(f"       {url}")
PY
