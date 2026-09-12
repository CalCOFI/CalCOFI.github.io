#!/usr/bin/env python3
"""Split the measurement-faces probe into the two files the page reads, so WS-MF5 can be built and
checked before WS-MF3 (the record, schema 1.1) and WS-MF4 (the media sidecar) land.

    python3 _test/build_measurement_face_fixture.py \
        --probe "$HOME/Github/CalCOFI/workflows/.claude/plans/2026-09-11 measurement-faces-probe/data.json" \
        --record _data/measurements.json \
        --out-record  _test/fixtures/measurements_11.json \
        --out-media   _test/fixtures/measurements_media.json

WHAT IT DOES, and what it deliberately does not do.

The probe's `data.json` carries BOTH halves for eleven cast keys — the release's numbers and the
fetched vocabularies — in one object, because the mockup was one page. The site reads two files:

  measurements.json 1.1     the RELEASE's: the 1.0 record plus `face`, `chem`, `method`, `scale`,
                            `why`, `anomaly` and `n_flagged` per key (plan Appendix A)
  measurements_media.json   the FETCHER's: ONI, the NERC concept, the drawn structures, the
                            Wikipedia leads, the GOOS EOV sheet and the scale tables (plan § D8)

so this script splits it, grafting the eleven keys' face halves onto a REAL 1.0 record (pass the
promoted `measurements.json` with --record) rather than re-deriving one. Every number it writes is
copied from the probe or from that record; nothing is computed here but `n_flagged`, which is the
plugin's own arithmetic (`n_values - qual_ok_n`, landing PR #22) written into the record so the two
sources can be compared — the reconciliation the handoff's delta 4 asks for.

`--disagree KEY` writes a deliberately wrong `n_flagged` on one key, so the plugin's "the record and
the arithmetic disagree" warning can be seen firing.
"""
import argparse, json, sys
from pathlib import Path

# the mockup's per-key face object → the record's 1.1 fields and the media sidecar's entry.
# Everything under `MEDIA_*` is fetched from a third party on its own cadence (NERC, ChEBI,
# Wikipedia, GOOS, NOAA CPC): it is the fetcher's, never the release's.
MEDIA_KEYS = ("nerc", "structures", "wikipedia", "eov", "taxon", "calcofi_quote")


def sub_formula(c):
    return c


def chem_row(x, svg_name=None):
    """measurement_chem.csv's shape (Appendix A) plus the display fields ChEBI itself supplies."""
    return {k: v for k, v in {
        "chebi": x.get("chebi"), "name": x.get("name"), "formula": x.get("formula"),
        "charge": x.get("charge"), "mass": x.get("mass"), "role": x.get("role"),
        "via": "nerc_s27", "definition": x.get("definition"), "svg": svg_name,
    }.items() if v is not None}


def method_rows(c):
    out = []
    for h in c.get("how") or []:
        s = next((s for s in c["rec"]["series"] if s["dataset_key"] == h["dataset"]), None)
        out.append({k: v for k, v in {
            "dataset_key": h.get("dataset"),
            "measurement_type": s and s.get("measurement_type"),
            "platform": h.get("platform"), "instrument": h.get("instrument"),
            "principle": h.get("principle"), "steps": h.get("steps"),
            "wavelength_nm": h.get("nm"), "wavelength_note": h.get("nm_label"),
            "precision": h.get("precision"), "calcofi_org": h.get("url"),
            "page": h.get("page"), "source": h.get("src_note"),
            "acid_figure": h.get("acid"),
        }.items() if v is not None})
    return out


def scale_payload(c):
    """measurement_scale.csv's marks, plus the axis and the flags the figure needs.

    Appendix A defines only the MARKS (`key,value,lo,hi,label,kind,how,source,source_url`). The
    axis a mark sits on (linear · log · Beaufort, and its domain) and the quality flags the
    familiar scale surfaced (§ D7, § F8) are carried here as `scale_axis` and `scale_flags` — an
    addendum WS-MF3/WS-MF1 must emit, reported with this branch. The page is nil-safe without
    either: no axis → a linear one derived from the bounds, the observed range and the marks.
    """
    sc = c.get("scale")
    if not sc:
        return None, None, None
    marks = [{k2: v2 for k2, v2 in {
        "value": r.get("v"), "lo": r.get("lo"), "hi": r.get("hi"), "label": r.get("label"),
        "kind": r.get("kind"), "source": r.get("src"), "off": r.get("off"),
    }.items() if v2 is not None} for r in sc.get("refs") or []]
    axis = {k: v for k, v in {
        "type": sc.get("type"), "domain": sc.get("domain"), "source": sc.get("src"),
        "zero_pct": sc.get("zero_pct"),
    }.items() if v is not None}
    flags = [{k2: v2 for k2, v2 in {
        "text": f.get("text"), "value": f.get("v"), "off": f.get("off"),
    }.items() if v2 is not None} for f in sc.get("flags") or []]
    return marks, axis, flags


def why_rows(c):
    """measurement_why.csv's rows: rank 1 is the pick, ranks 2… the alternatives (§ D5)."""
    w = c.get("why") or {}
    rows = []
    eov = c.get("eov") or {}

    def cites(cs):
        return [{"key": x[0], "label": x[1], "url": x[2]} for x in cs or []]

    rows.append({k: v for k, v in {
        "rank": 1, "kind": "authored", "text": w.get("text"), "cites": cites(w.get("cites")),
        "bibkeys": [x[0] for x in w.get("cites") or []],
        "eov": eov.get("name"), "goos_doc": eov.get("doc"),
    }.items() if v not in (None, [])})
    for i, a in enumerate(w.get("alts") or []):
        rows.append({k: v for k, v in {
            "rank": i + 2, "kind": a.get("kind"), "text": a.get("text"),
            "cites": cites(a.get("cites")), "bibkeys": [x[0] for x in a.get("cites") or []],
        }.items() if v not in (None, [])})
    return rows


def face_block(c):
    kind = c.get("kind")
    out = {"kind": kind}
    if c.get("kind_note"):
        out["note"] = c["kind_note"]
    si = c.get("stands_in")
    if si:
        out["face_of"] = si.get("face_of")
        out["stands_in_note"] = si.get("why")
    if c.get("a05_only"):
        out["a05_only"] = c["a05_only"]
    if c.get("p01_borrowed_from"):
        out["p01_borrowed_from"] = c["p01_borrowed_from"]
    return out


def media_block(c, svg):
    out = {}
    p01 = c.get("p01")
    if p01:
        nerc = {"p01": p01.get("code"), "url": p01.get("url"), "pref": p01.get("pref"),
                "definition": p01.get("def"), "license": "CC BY 4.0",
                "links": p01.get("links") or {}}
        if c.get("s27"):
            nerc["s27"] = {"id": c["s27"], "chebi": (c.get("chem") or [{}])[0].get("chebi"),
                           "cas": c.get("cas")}
        tx = c.get("taxon")
        if tx:
            nerc["s25"] = {"id": tx.get("s25"), "worms": tx.get("worms")}
        out["nerc"] = nerc
    # the structures, drawn by RDKit from ChEBI's molfiles, in the page's ink
    st = []
    for i, name in enumerate(c.get("svg") or []):
        s = svg.get(name)
        if not s:
            continue
        x = (c.get("chem") or [])[i] if i < len(c.get("chem") or []) else {}
        st.append({k: v for k, v in {
            "chebi": x.get("chebi"), "name": x.get("name") or name.replace("_", " "),
            "formula": x.get("formula"), "charge": x.get("charge"), "mass": x.get("mass"),
            "definition": x.get("definition"), "role": x.get("role"),
            "viewBox": s.get("viewBox"), "svg_inner": s.get("inner"),
            "drawn_by": "RDKit 2026.03 from the ChEBI molfile", "license": "CC BY 4.0 (ChEBI)",
            "key": name,
        }.items() if v is not None})
    if st:
        out["structures"] = st
    wp = c.get("wp")
    if wp:
        out["wikipedia"] = [wp]
    if c.get("eov"):
        out["eov"] = c["eov"]
    if c.get("taxon"):
        out["taxon"] = c["taxon"]
    if c.get("calcofi_quote"):
        out["calcofi_quote"] = c["calcofi_quote"]
    if c.get("composition"):
        out["composition"] = c["composition"]
    if c.get("bjerrum"):
        out["bjerrum"] = c["bjerrum"]
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--probe", required=True)
    ap.add_argument("--record", required=True, help="a real measurements.json 1.0 to graft onto")
    ap.add_argument("--out-record", required=True)
    ap.add_argument("--out-media", required=True)
    ap.add_argument("--disagree", default=None,
                    help="write a deliberately wrong n_flagged on this key")
    a = ap.parse_args()

    probe = json.loads(Path(a.probe).read_text(encoding="utf-8"))
    rec = json.loads(Path(a.record).read_text(encoding="utf-8"))
    cast = {c["key"]: c for c in probe["cast"]}
    svg = probe.get("svg") or {}

    rec["schema_version"] = "1.1"
    n_faces = 0
    for m in rec["measurements"]:
        # n_flagged, per series and per key: the record becomes the source and the plugin's
        # `n_values - qual_ok_n` the fallback (handoff delta 4). Written from the record's OWN
        # counts so the two agree, which is the point of the reconciliation.
        tot = 0
        for s in m.get("series") or []:
            if s.get("qual_ok_n") is None:
                continue
            s["n_flagged"] = max(int(s["n_values"] or 0) - int(s["qual_ok_n"] or 0), 0)
            tot += s["n_flagged"]
        m["n_flagged"] = tot
        c = cast.get(m["key"])
        if not c:
            continue
        n_faces += 1
        m["face"] = face_block(c)
        chem = [chem_row(x, (c.get("svg") or [None] * 9)[i] if i < len(c.get("svg") or []) else None)
                for i, x in enumerate(c.get("chem") or [])]
        if chem:
            m["chem"] = chem
        meth = method_rows(c)
        if meth:
            m["method"] = meth
        marks, axis, flags = scale_payload(c)
        if marks is not None:
            m["scale"] = marks
            if axis:
                m["scale_axis"] = axis
            if flags:
                m["scale_flags"] = flags
        why = why_rows(c)
        if why:
            m["why"] = why
        if c.get("anomaly"):
            an = dict(c["anomaly"])
            an.setdefault("baseline", [1993, 2013])
            m["anomaly"] = an
        elif c.get("anomaly_none"):
            m["anomaly_note"] = c["anomaly_none"]

    if a.disagree:
        for m in rec["measurements"]:
            if m["key"] == a.disagree:
                m["n_flagged"] = int(m.get("n_flagged") or 0) + 1
                print(f"n_flagged on {a.disagree} bumped by 1 on purpose", file=sys.stderr)

    media = {
        "schema_version": "1.0",
        "release": probe["release"]["version"],
        "fetched": probe["built"],
        "base": "https://storage.googleapis.com/calcofi-files-public/measurement-media/",
        "oni": probe["oni"],
        # the two tables the scales are read against, fetched with the leads (§ D8, Appendix B)
        "tables": {},
        "measurements": {},
    }
    bf = (cast.get("wind_speed_ms") or {}).get("scale", {}).get("beaufort")
    if bf:
        media["tables"]["beaufort"] = {
            "source": (cast["wind_speed_ms"]["scale"] or {}).get("src"),
            "rows": bf,
        }
    for k, c in cast.items():
        b = media_block(c, svg)
        if b:
            media["measurements"][k] = b

    Path(a.out_record).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out_record).write_text(json.dumps(rec, indent=1, ensure_ascii=False), encoding="utf-8")
    Path(a.out_media).write_text(json.dumps(media, indent=1, ensure_ascii=False), encoding="utf-8")
    print(f"record  {a.out_record}: schema {rec['schema_version']}, "
          f"{len(rec['measurements'])} keys, {n_faces} with a face")
    print(f"media   {a.out_media}: {len(media['measurements'])} keys, "
          f"{sum(len(v.get('structures') or []) for v in media['measurements'].values())} structures")


if __name__ == "__main__":
    main()
