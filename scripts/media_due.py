#!/usr/bin/env python3
"""media_due.py — which species and measurement keys of the promoted release have no face yet.

    scripts/media_due.py [--release-base URL] [--media-base URL]
                         [--taxa FILE|URL] [--measurements FILE|URL]
                         [--taxa-media FILE|URL] [--measurements-media FILE|URL] [--json]

The faces are NOT release content: `taxa_media.json` and `measurements_media.json` live once at
`gs://calcofi-files-public/{species,measurement}-media/` and are rebuilt by
scripts/fetch_species_media.py and scripts/fetch_measurement_faces.py.  A release that adds a taxon
or a measurement key needs them rebuilt; one that adds none does not.  This compares the promoted
release's own records (`{release}/taxa.json`, `{release}/measurements.json`, resolved through
`latest.txt`) with the two published sidecars and prints, per kind, how many keys the record has,
how many the sidecar has, and the ones missing.

Exit status, which the release's deploy script (workflows/scripts/deploy_consumers.sh, step 7)
branches on:
    0   nothing due: every key of the record has an entry in its sidecar
    3   due: at least one key is missing (or a sidecar is absent altogether)
    2   could not tell (a record could not be read)

A key the sidecar has and the record lacks is not a reason to fetch: the sidecars are one copy for
every release, and a key a release dropped keeps its entry.  Standard library only.
"""

from __future__ import annotations

import argparse
import json
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path

RELEASE_BASE = "https://storage.googleapis.com/calcofi-db/ducklake/releases"
MEDIA_BASE = "https://storage.googleapis.com/calcofi-files-public"
UA = "calcofi.io media-due/1.0 (https://calcofi.io; bdbest@gmail.com)"

EXIT_NONE, EXIT_UNKNOWN, EXIT_DUE = 0, 2, 3


def fresh(url: str) -> str:
    """A cache-busting query: the public bucket's edge cache served a pre-DOI versions.json for
    minutes after the object changed (2026-10-06), and the post-upload check must see the new bytes."""
    return f"{url}{'&' if '?' in url else '?'}cb={time.time_ns()}"


def read_json(src: str):
    """A local path, a file:// URL or an http(s) URL; None when an http(s) object is absent (404)."""
    if src.startswith(("http://", "https://")):
        req = urllib.request.Request(fresh(src), headers={"User-Agent": UA, "Cache-Control": "no-cache"})
        try:
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.load(r)
        except urllib.error.HTTPError as e:
            if e.code == 404:
                return None
            raise
    if src.startswith("file://"):
        src = src[len("file://"):]
    p = Path(src)
    return json.loads(p.read_text()) if p.exists() else None


def read_text(src: str) -> str:
    req = urllib.request.Request(fresh(src), headers={"User-Agent": UA, "Cache-Control": "no-cache"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return r.read().decode().strip()


def record_taxon_keys(rec: dict) -> set[str]:
    """taxa.json (calcofi4db::build_taxa_catalog()): `taxa` is a list of {taxon_key, …}."""
    return {t["taxon_key"] for t in rec.get("taxa") or []}


def record_measurement_keys(rec: dict) -> set[str]:
    """measurements.json (calcofi4db::build_measurements_catalog()): `measurements` is a list of {key, …}."""
    return {m["key"] for m in rec.get("measurements") or []}


def sidecar_keys(doc: dict | None, field: str) -> set[str]:
    """taxa_media.json `taxa` and measurements_media.json `measurements` are dicts keyed by key.
    A key the fetcher deliberately left without a structure still has an entry (its reason is
    in `skipped`), so an entry is what "has a face" means here."""
    if not doc:
        return set()
    v = doc.get(field) or {}
    return set(v) if isinstance(v, dict) else {x.get("key") for x in v if isinstance(x, dict)}


def due(record: set[str], sidecar: set[str]) -> list[str]:
    """The record's keys with no sidecar entry, sorted."""
    return sorted(record - sidecar)


def main(argv=None) -> int:
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--release-base", default=RELEASE_BASE)
    ap.add_argument("--media-base", default=MEDIA_BASE)
    ap.add_argument("--taxa", help="the record (default: the promoted release's taxa.json)")
    ap.add_argument("--measurements", help="the record (default: the promoted release's)")
    ap.add_argument("--taxa-media", help="default: {media-base}/species-media/taxa_media.json")
    ap.add_argument("--measurements-media",
                    help="default: {media-base}/measurement-media/measurements_media.json")
    ap.add_argument("--json", action="store_true", help="print the result as one JSON object")
    args = ap.parse_args(argv)

    version = None
    if not (args.taxa and args.measurements):
        try:
            version = read_text(f"{args.release_base}/latest.txt")
        except Exception as e:                                          # pragma: no cover
            print(f"could not read {args.release_base}/latest.txt: {e}", file=sys.stderr)
            return EXIT_UNKNOWN
    taxa_src = args.taxa or f"{args.release_base}/{version}/taxa.json"
    meas_src = args.measurements or f"{args.release_base}/{version}/measurements.json"
    tm_src = args.taxa_media or f"{args.media_base}/species-media/taxa_media.json"
    mm_src = args.measurements_media or f"{args.media_base}/measurement-media/measurements_media.json"

    try:
        taxa, meas = read_json(taxa_src), read_json(meas_src)
        tm, mm = read_json(tm_src), read_json(mm_src)
    except Exception as e:
        print(f"could not read a record or a sidecar: {type(e).__name__}: {e}", file=sys.stderr)
        return EXIT_UNKNOWN
    if taxa is None or meas is None:
        print(f"a record is missing: {taxa_src if taxa is None else meas_src}", file=sys.stderr)
        return EXIT_UNKNOWN

    out = {"release": version or (taxa.get("release") if isinstance(taxa, dict) else None)}
    for kind, rec_keys, doc, field, src in (
            ("species", record_taxon_keys(taxa), tm, "taxa", tm_src),
            ("measurements", record_measurement_keys(meas), mm, "measurements", mm_src)):
        side = sidecar_keys(doc, field)
        miss = due(rec_keys, side)
        out[kind] = {"record": len(rec_keys), "sidecar": len(side), "missing": miss,
                     "sidecar_present": doc is not None,
                     "sidecar_release": (doc or {}).get("release"), "sidecar_src": src}

    n_due = sum(len(out[k]["missing"]) for k in ("species", "measurements"))
    if args.json:
        print(json.dumps(out, indent=1))
    else:
        print(f"release {out['release']}")
        for k in ("species", "measurements"):
            o = out[k]
            head = ", ".join(o["missing"][:8]) + (" …" if len(o["missing"]) > 8 else "")
            print(f"  {k:<13} record {o['record']:>5} · sidecar {o['sidecar']:>5} "
                  f"(built for {o['sidecar_release'] or 'absent'}) · missing {len(o['missing'])}"
                  + (f": {head}" if o["missing"] else ""))
    return EXIT_DUE if n_due else EXIT_NONE


if __name__ == "__main__":
    sys.exit(main())
