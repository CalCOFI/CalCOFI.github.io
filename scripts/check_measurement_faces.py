#!/usr/bin/env python3
"""check_measurement_faces.py — refuse to publish a measurement-media sidecar that would mislead.

    scripts/check_measurement_faces.py [.cache/measurement-media/measurements_media.json]
                                       [--record _data/measurements.json] [--quiet]

Six assertions, each from the plan `2026-09-11 Measurement faces …` (§ D1, § D2, § D8, § MF4):

  1 every structure TRACES: `via` is either `nerc_s27` — and then its ChEBI id is the one the
    key's own NVS chain reached, never another — or `registry`, and then the row names the source
    that put it there.  A picture on a measurement page is a claim about identity.
  2 every Wikipedia lead carries a revision id, a licence and a link to that revision: a quotable
    lead is one a reader can go back to, and CC BY-SA 4.0 requires the attribution.
  3 no `roles` ANYWHERE in the document.  ChEBI classifies dioxygen an "anti-inflammatory drug"
    and the carbon atom an "antidepressant"; the roles are never stored, so a `roles` key means
    the fetcher started copying the record wholesale.
  4 every SVG parses as XML, draws in `currentColor` and nothing else (no hex, no rgb(), no named
    colour), and carries no `<text>` — the labels are paths, so the page's font never moves an
    atom.  Both the inline `svg_inner` and every file under `keys/` are checked.
  5 the layout carries NO VERSION.  No path or URL in the sidecar may contain a `v2026.09.11`-
    shaped segment: the media are stored once and the sidecar's own `release` field is the only
    place a version appears.  (Shipping `{release}/` blanked every species page on 2026-09-11.)
  6 a ChEBI id the fetcher skips as "not the thing measured" (DIC's carbon atom) appears in
    `skipped` with a reason, and in no key's structures.
  7 a `bjerrum` block NAMES WHAT MADE IT: every input it was computed from (each with the record
    key, series and p50 it is), the package version and the constants.  A curve on a page is a
    claim about chemistry, and a reader must be able to recompute it.

Exits non-zero with the list of offenders.  Standard library only — it must run in CI where RDKit
is not installed.
"""

from __future__ import annotations

import argparse
import json
import re
import sys
import xml.etree.ElementTree as ET
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent

VERSION_SEGMENT = re.compile(r"v\d{4}\.\d{2}\.\d{2}")
COLOUR = re.compile(r"#[0-9A-Fa-f]{3,8}\b|\brgba?\(|\bhsla?\(")
# the only paint words an SVG here may name
COLOUR_WORDS = {"none", "currentcolor", "transparent", "inherit"}
STYLE_COLOUR = re.compile(r"(?:^|[;\s])(?:fill|stroke|stop-color|flood-color|color)\s*:\s*([^;\"']+)")
ALLOWED_VIA = ("nerc_s27", "registry")


def walk(node, path="$"):
    """Every (json-path, key, value) in the document."""
    if isinstance(node, dict):
        for k, v in node.items():
            yield f"{path}.{k}", k, v
            yield from walk(v, f"{path}.{k}")
    elif isinstance(node, list):
        for i, v in enumerate(node):
            yield from walk(v, f"{path}[{i}]")


def svg_problems(text: str, where: str) -> list[str]:
    out = []
    try:
        ET.fromstring(text if text.lstrip().startswith("<svg") else f"<svg>{text}</svg>")
    except ET.ParseError as e:
        return [f"{where}: does not parse as XML ({e})"]
    if "<text" in text:
        out.append(f"{where}: carries a <text> element — the atom labels must be paths")
    for m in COLOUR.finditer(text):
        out.append(f"{where}: draws in {m.group(0)!r}, not currentColor")
    for m in STYLE_COLOUR.finditer(text):
        v = m.group(1).strip().strip("'\"").lower()
        if v not in COLOUR_WORDS and not COLOUR.search(v):
            out.append(f"{where}: paints {v!r}, not currentColor")
    return out


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sidecar", nargs="?",
                    default=str(ROOT / ".cache" / "measurement-media" / "measurements_media.json"))
    ap.add_argument("--record", default=str(ROOT / "_data" / "measurements.json"),
                    help="the measurements catalog record the sidecar was built from")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    path = Path(args.sidecar)
    if not path.exists():
        print(f"no {path} — run scripts/fetch_measurement_faces.py first", file=sys.stderr)
        return 1
    doc = json.loads(path.read_text())
    keys_dir = path.parent / "keys"
    entries = doc.get("measurements") or {}
    problems: list[str] = []

    record_keys = set()
    rp = Path(args.record)
    if rp.exists():
        record_keys = {m["key"] for m in json.loads(rp.read_text()).get("measurements", [])}

    skipped = {(s.get("key"), s.get("chebi")) for s in (doc.get("skipped") or [])}
    skipped_chebi = {c for _, c in skipped}
    for s in (doc.get("skipped") or []):
        if not s.get("why"):
            problems.append(f"skipped {s.get('chebi')} on {s.get('key')}: no reason given")

    n_svg = 0
    for key, e in entries.items():
        if record_keys and key not in record_keys:
            problems.append(f"{key}: not a key in {rp.name}")
        # a stand-in's chain sits under `nerc_borrowed`, never `nerc`: the ids are the lender's and
        # the page must not print them in this key's ids row (§ D3)
        chain = e.get("nerc") or e.get("nerc_borrowed") or {}
        chain_chebi = (chain.get("s27") or {}).get("chebi")
        if e.get("nerc") and e.get("nerc_borrowed"):
            problems.append(f"{key}: carries both its own chain and a borrowed one")
        if e.get("nerc_borrowed") and not e["nerc_borrowed"].get("borrowed_from"):
            problems.append(f"{key}: a borrowed chain that does not name whose it is")
        if (e.get("face") or {}).get("kind") == "standsin" and e.get("nerc"):
            problems.append(f"{key}: stands in for another key's face but claims a chain as its own")

        for i, st in enumerate(e.get("structures") or []):
            where = f"{key}.structures[{i}] {st.get('chebi')}"
            via = st.get("via")
            # 1 — every structure traces to an S27 sameAs or a registry row
            if via not in ALLOWED_VIA:
                problems.append(f"{where}: via {via!r} is neither {' nor '.join(ALLOWED_VIA)}")
            elif via == "nerc_s27" and st.get("chebi") != chain_chebi:
                problems.append(f"{where}: claims the S27 chain, but that chain reached "
                                f"{chain_chebi!r}")
            elif via == "registry" and not (st.get("source") or "").strip():
                problems.append(f"{where}: a registry row with no source")
            # 6 — a skipped id is never drawn
            if st.get("chebi") in skipped_chebi and st.get("svg_inner"):
                problems.append(f"{where}: drawn, though it is listed in `skipped`")
            # 4 — the drawing
            if st.get("svg_inner"):
                n_svg += 1
                if not st.get("viewBox"):
                    problems.append(f"{where}: a drawing with no viewBox")
                problems += svg_problems(st["svg_inner"], where)
                rel = st.get("path")
                if not rel:
                    problems.append(f"{where}: drawn but carries no path")
                elif not rel.startswith("keys/"):
                    problems.append(f"{where}: path {rel!r} does not start with 'keys/'")
                elif keys_dir.exists() and not (path.parent / rel).exists():
                    # the sidecar promising a file the folder does not hold is exactly what a
                    # rebuilt key with fewer structures leaves behind
                    problems.append(f"{where}: path {rel!r} is not on disk beside the sidecar")

        # 7 — a computed curve names its inputs, its package and its constants
        if (b := e.get("bjerrum")):
            where = f"{key}.bjerrum"
            if not isinstance(b.get("curve"), list) or len(b["curve"]) < 2:
                problems.append(f"{where}: no curve")
            ins = b.get("inputs") or {}
            if not ins:
                problems.append(f"{where}: names no inputs — it must say which medians made it")
            for name, v in ins.items():
                if not isinstance(v, dict) or v.get("p50") is None or not v.get("key"):
                    problems.append(f"{where}.inputs.{name}: not a record series with a p50")
            vers = b.get("versions") or {}
            if not (vers.get("PyCO2SYS") or "").strip():
                problems.append(f"{where}: names no PyCO2SYS version")
            if not (vers.get("constants") or "").strip():
                problems.append(f"{where}: names no equilibrium constants")
            if not (b.get("src") or "").strip():
                problems.append(f"{where}: no credit line for the page to show")

        # 2 — every lead has a revision
        for i, w in enumerate(e.get("wikipedia") or []):
            where = f"{key}.wikipedia[{i}] {w.get('title')}"
            if not isinstance(w.get("revision"), int) or w["revision"] <= 0:
                problems.append(f"{where}: no revision id")
            if (w.get("license") or "") != "CC BY-SA 4.0":
                problems.append(f"{where}: licence {w.get('license')!r}, expected CC BY-SA 4.0")
            if not (w.get("extract") or "").strip():
                problems.append(f"{where}: an empty lead")
            if not (w.get("url") or "").strip():
                problems.append(f"{where}: no link to the revision")

    # 2 (continued) — a borrowed table is quotable too: a revision, a licence and a link
    bf = (doc.get("tables") or {}).get("beaufort")
    if bf:
        if not isinstance(bf.get("revision"), int) or bf["revision"] <= 0:
            problems.append("tables.beaufort: no revision id")
        if (bf.get("license") or "") != "CC BY-SA 4.0":
            problems.append(f"tables.beaufort: licence {bf.get('license')!r}, expected CC BY-SA 4.0")
        if not (bf.get("url") or "").strip():
            problems.append("tables.beaufort: no link to the revision")
        rows = bf.get("rows") or []
        if len(rows) < 2 or any(len(r) != 4 or r[1] is None for r in rows):
            problems.append("tables.beaufort: rows are not [force, lo, hi, label] with a lower band")

    # 3 — no roles anywhere
    for jpath, k, _v in walk(doc):
        if "role" == k.lower() or k.lower().startswith("roles"):
            if k.lower() != "role":                   # `role` is the chem row's the_thing/component
                problems.append(f"{jpath}: a {k!r} key — ChEBI roles are never stored")

    # 5 — no version anywhere but the `release` field
    for jpath, k, v in walk(doc):
        if k in ("release",) or not isinstance(v, str):
            continue
        if VERSION_SEGMENT.search(v):
            problems.append(f"{jpath}: names a release version ({v[:80]!r}) — the media are "
                            f"stored once, and only `release` may say which catalog built them")

    # 4 (continued) — every file on disk
    n_files = 0
    if keys_dir.exists():
        for f in sorted(keys_dir.rglob("*.svg")):
            n_files += 1
            problems += svg_problems(f.read_text(), str(f.relative_to(path.parent)))

    if not args.quiet:
        cov = doc.get("coverage") or {}
        print(f"{path}")
        print(f"  release {doc.get('release')} (record schema {doc.get('source_record_schema')}) "
              f"· fetched {doc.get('fetched')}")
        print(f"  {len(entries)} keys · nerc {cov.get('nerc')} "
              f"(+{cov.get('nerc_borrowed')} borrowed) · "
              f"keys with a structure {cov.get('keys_with_structure')} · "
              f"structures {cov.get('structures')} ({n_svg} inline, {n_files} files) · "
              f"leads {cov.get('leads')} · stands-in {cov.get('standsin')} · "
              f"bjerrum {cov.get('bjerrum')} · tables {', '.join(cov.get('tables') or []) or '—'}")
        if doc.get("skipped"):
            for s in doc["skipped"]:
                print(f"  skipped {s['chebi']} on {s['key']}: {s['why']}")

    if problems:
        print(f"\nFAIL — {len(problems)} problem(s):")
        for p in problems[:100]:
            print(f"  - {p}")
        if len(problems) > 100:
            print(f"  … and {len(problems) - 100} more")
        return 1
    print("\nOK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
