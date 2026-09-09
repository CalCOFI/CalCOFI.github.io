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
#   _data/release_catalog.json    the release's own catalog.json (what a row is on the front door:
#                                 organism observations, measurements, the taxon table's size)
#   _data/release_coverage.json   the release's own coverage.json (~660 KB) — `taxa[]`, one row per
#                                 taxon OBSERVED, with its rank and the datasets it was seen in: the
#                                 front door's species count and each dataset page's (plan
#                                 2026-09-09 § D4). Read at BUILD time, never shipped to the browser
#   _data/release_anchors.json    the version ids the rendered RELEASES.html really carries, so the
#                                 ship's log anchors a release entry only where the page has a
#                                 heading for it (plan 2026-09-09 § N2)
#   _data/taxa.json               the species catalog record (calcofi4db::build_taxa_catalog(),
#                                 schema 1.0, ~2.4 MB) — every taxon with an observation at or below
#                                 it, its lineage, its per-dataset observations and the names each
#                                 dataset uses. _plugins/species.rb draws /species/ from it and
#                                 NOTHING else; without it the site builds with no species pages
#                                 (plan 2026-09-09 § D7)
#   _data/erddap_taxon_key.json   which of the record's current ERDDAP datasets carry a `taxon_key`
#                                 variable, probed once here from erddap.calcofi.io/erddap/info —
#                                 a species page constrains its ERDDAP link only where the server
#                                 says the column exists
#
# All of them are git-ignored: the site is a rendering of the promoted release, never a copy of it.
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
#
# `taxa.json` is resolved exactly the same way, one release behind: the promoted release's
# {record_dir}/taxa.json first, then $TAXA_RELEASE_URL with a loud NOTE, and otherwise NOTHING is
# written — the build then draws no species pages at all rather than inventing one (plan § D-2).
# TAXA_RELEASE_URL takes a full http(s) URL *or* a local path (or a file:// URL) so a staging
# record can be rendered from disk; the bridge goes away when a promoted release carries taxa.json.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DATA="$ROOT/_data"

RELEASE_BASE="${CALCOFI_RELEASE_BASE:-https://storage.googleapis.com/calcofi-db/ducklake/releases}"
RELEASES_HTML="${CALCOFI_RELEASES_HTML:-https://storage.calcofi.io/calcofi-db/ducklake/releases/RELEASES.html}"
FALLBACK_URL="${DATASETS_RELEASE_URL:-}"
TAXA_FALLBACK="${TAXA_RELEASE_URL:-}"

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
  echo "NOTE: no catalog.json beside the record — the front door draws no row counts" >&2

# the release's measured coverage: taxa[] is every taxon actually observed, with its rank — the
# honest species count the band shows (the taxon TABLE's 2,614 rows include ancestors and vocabulary
# entries never observed). Optional, exactly like catalog.json: without it the species tile collapses
# and the dataset pages keep saying "taxa" (plan 2026-09-07 § D-2: never a typed number).
get "$record_dir/coverage.json" "$DATA/release_coverage.json" ||
  echo "NOTE: no coverage.json beside the record — the front door draws no species count" >&2

# the species catalog record: every taxon of the release's taxon table with an observation at or
# below it, with its lineage, its per-dataset counts and the name each dataset uses. Resolved
# exactly as datasets.json is (plan 2026-09-09 § D7): the promoted release's own taxa.json first,
# then the TAXA_RELEASE_URL bridge, and otherwise nothing at all — _plugins/species.rb then draws
# no /species/ pages and says so once, rather than typing a taxon anywhere.
rm -f "$DATA/taxa.json"
if get "$record_dir/taxa.json" "$DATA/taxa.json"; then
  taxa_kind="promoted"; taxa_url="$record_dir/taxa.json"
elif [ -n "$TAXA_FALLBACK" ]; then
  taxa_kind="fallback"; taxa_url="$TAXA_FALLBACK"
  echo
  echo "NOTE: taxa.json from a non-promoted release ---------------------------------------"
  echo "NOTE: the promoted release $version carries no taxa.json (it predates the species catalog)."
  echo "NOTE: building the species pages from  $taxa_url"
  echo "NOTE: TAXA_RELEASE_URL is set; unset it to render the promoted release."
  echo "NOTE: ------------------------------------------------------------------------------"
  echo
  case "$taxa_url" in
    http://*|https://*) get "$taxa_url" "$DATA/taxa.json" ;;
    # a local record: file:// or a plain path, so a staging build can render from disk
    file://*)           cp "${taxa_url#file://}" "$DATA/taxa.json" ;;
    *)                  cp "$taxa_url" "$DATA/taxa.json" ;;
  esac
else
  taxa_kind="none"; taxa_url=""
  echo "NOTE: no taxa.json beside the record and no TAXA_RELEASE_URL — the site builds with no species pages"
fi

if [ -s "$DATA/taxa.json" ]; then
  python3 - "$DATA/taxa.json" "$taxa_kind" "$taxa_url" <<'PYT'
import json, sys
path, kind, url = sys.argv[1:4]
d = json.load(open(path))
c = d.get("counts", {})
print(f"taxa {kind}: schema {d.get('schema_version')} · release {d['release']['version']} · "
      f"{c.get('pages')} pages · {c.get('taxa_observed')} taxa observed · "
      f"{c.get('species_observed')} species · {c.get('datasets')} datasets")
print(f"       {url}")
PYT

  # which of THOSE datasets' ERDDAP tables carry a taxon_key column. A species page links the
  # tabledap page of the dataset that observed it most, constrained to its taxon_key — but only
  # where the server says the column exists; otherwise the plain tabledap page. Probed once here
  # (one small GET per dataset) and cached, so Jekyll never touches the network.
  python3 - "$DATA/datasets.json" "$DATA/taxa.json" "$DATA/erddap_taxon_key.json" <<'PYE' || echo "NOTE: ERDDAP variables not probed — species pages will link the plain tabledap page" >&2
import json, sys, urllib.request
drec, trec, out = sys.argv[1:4]
rec = json.load(open(drec))
keys = {d["dataset_key"] for d in json.load(open(trec)).get("datasets", [])}
ids = []
for d in rec.get("datasets", []):
    if d.get("dataset_key") not in keys:
        continue
    for x in d.get("distributions") or []:
        # the dataset's OWN tabledap table, current, not the _sample / _attribute companions
        if (x.get("format") == "erddap" and x.get("status") != "superseded"
                and str(x.get("url", "")).endswith(".html") and x.get("id") == d["dataset_key"]):
            ids.append(x["id"])
has = {}
for i in sorted(set(ids)):
    try:
        with urllib.request.urlopen(f"https://erddap.calcofi.io/erddap/info/{i}/index.csv", timeout=20) as r:
            body = r.read().decode("utf-8", "replace")
        has[i] = any(line.startswith("variable,taxon_key,") for line in body.splitlines())
    except Exception:
        pass                      # unreachable is not a fact: the id simply gets no entry
json.dump(has, open(out, "w"), indent=1, sort_keys=True)
print(f"erddap taxon_key: {sum(has.values())} of {len(has)} probed datasets carry the column")
PYE
fi

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

# which version headings the RENDERED changelog actually carries. workflows'
# scripts/render_md_on_storage.R stamps id="v2026.09.06" — the version string itself — on a version
# heading, but a release collapsed into a range section ("# v2026.08.04 – v2026.08.06") has an id
# only for the versions the heading names. _plugins/news.rb anchors a release entry only where the
# id is in this list and links the unanchored page otherwise, so the set is READ here rather than
# assumed. Optional: on a failure the list is empty and every release entry links the page's top.
python3 - "$RELEASES_HTML" "$DATA/release_anchors.json" <<'PY3'
import json, re, sys, urllib.request
url, out = sys.argv[1:3]
ids = []
try:
    with urllib.request.urlopen(url, timeout=20) as r:
        html = r.read().decode("utf-8", "replace")
    # the dotted form only: id="v2026.09.06", never the slug id="v2026-09-06-2026-09-06"
    ids = sorted({m for m in re.findall(r'id="(v\d[\d.]*)"', html)}, reverse=True)
except Exception as e:
    print(f"NOTE: could not read {url} ({e}) — release entries will link the changelog unanchored")
json.dump(ids, open(out, "w"), indent=1)
print(f"changelog anchors: {len(ids)} version headings on RELEASES.html")
PY3

python3 - "$DATA/datasets.json" "$source_kind" "$record_url" <<'PY'
import json, sys
path, kind, url = sys.argv[1], sys.argv[2], sys.argv[3]
d = json.load(open(path))
c = d.get("counts", {})
print(f"record {kind}: schema {d.get('schema_version')} · release {d['release']['version']} · "
      f"{c.get('datasets')} datasets · {c.get('holdings')} holdings · {c.get('reference')} reference rows")
print(f"       {url}")
PY
