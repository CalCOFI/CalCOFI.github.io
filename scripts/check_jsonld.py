#!/usr/bin/env python3
"""Validate the generated catalog: every page's JSON-LD, the sitemap, and data.json.

    scripts/check_jsonld.py                 # checks ./_site (build it first)
    scripts/check_jsonld.py path/to/_site

What it asserts, and why each rule is here:

  JSON-LD (schema.org/Dataset · Google's Dataset structured-data guide · ODIS's checklist)
    · every /datasets/*/ page carries exactly one <script type="application/ld+json">, and it parses
    · @type Dataset (the release page too), with `name` and `description` — Google's two required
      properties; a Dataset without them is not indexed
    · @id · identifier · includedInDataCatalog · provider — ODIS's checklist (book.odis.org)
    · spatialCoverage, when present, is a GeoShape `box` of four numbers "lat lon lat lon"
    · temporalCoverage, when present, is an ISO 8601 interval
    · every distribution is a DataDownload with an absolute contentUrl
    · the sidecar /datasets/{key}.jsonld is byte-identical in meaning to the in-page block
    · /datasets/ itself is a DataCatalog whose `dataset` list matches the pages that exist

  sitemap.xml — well-formed, every <loc> absolute, one entry per public page, none for an
    `internal` record

  data.json — DCAT-US 1.1, the NON-FEDERAL profile (CalCOFI is a partnership, not a federal bureau,
    so `bureauCode` / `programCode` do not apply; $DCAT_SCHEMA_URL overrides). Validated against the
    published schema when `jsonschema` is importable (CI installs it) and the schema is reachable;
    otherwise the required-field subset below still runs, so an offline machine still catches a
    broken catalog.

Exit 1 on any failure, with every failure printed — never the first one only.
"""
import json
import os
import re
import sys
import urllib.request
import warnings
import xml.etree.ElementTree as ET
from pathlib import Path

# DCAT-US 1.1, the NON-FEDERAL profile. CalCOFI is a NOAA + CDFW + SIO partnership, not a federal
# bureau publishing to data.gov's federal inventory, so `bureauCode` / `programCode` do not apply —
# and inventing them would be exactly the kind of asserted fact this catalog exists to avoid. The
# federal profile is one env var away when a partner asks for it.
DCAT_SCHEMA = os.environ.get(
    "DCAT_SCHEMA_URL",
    "https://raw.githubusercontent.com/GSA/ckanext-datajson/main/ckanext/datajson/"
    "pod_schema/non-federal-v1.1/catalog.json")
LD = re.compile(r'<script type="application/ld\+json">(.*?)</script>', re.S)

fails, notes = [], []


def fail(where, msg):
    fails.append(f"{where}: {msg}")


def blocks(html_path):
    return LD.findall(html_path.read_text(encoding="utf-8"))


def check_dataset_node(node, where, page_url):
    t = node.get("@type")
    if t != "Dataset":
        return fail(where, f'@type is {t!r}, expected "Dataset"')
    for req in ("name", "description"):                     # Google's required properties
        if not node.get(req):
            fail(where, f"missing {req} (required by Google's Dataset guide)")
    for req in ("@id", "identifier", "includedInDataCatalog", "provider", "url"):
        if not node.get(req):
            fail(where, f"missing {req} (ODIS checklist)")
    if node.get("@id") and page_url and node["@id"] != page_url:
        fail(where, f'@id {node["@id"]} is not the page URL {page_url}')
    for k in ("@id", "url"):
        if node.get(k) and not str(node[k]).startswith("http"):
            fail(where, f"{k} is not absolute: {node[k]!r}")

    sc = node.get("spatialCoverage")
    if sc:
        box = (sc.get("geo") or {}).get("box")
        if not box:
            fail(where, "spatialCoverage without geo.box")
        else:
            parts = str(box).split()
            if len(parts) != 4 or any(not re.fullmatch(r"-?\d+(\.\d+)?", p) for p in parts):
                fail(where, f"spatialCoverage box is not four numbers: {box!r}")
    tc = node.get("temporalCoverage")
    if tc and "/" not in str(tc):
        fail(where, f"temporalCoverage is not an ISO 8601 interval: {tc!r}")

    for d in node.get("distribution") or []:
        if d.get("@type") != "DataDownload":
            fail(where, f'distribution @type {d.get("@type")!r}, expected "DataDownload"')
        if not str(d.get("contentUrl", "")).startswith("http"):
            fail(where, f"distribution without an absolute contentUrl: {d.get('name')!r}")
    for c in node.get("creator") if isinstance(node.get("creator"), list) else []:
        if c.get("@type") not in ("Person", "Organization"):
            fail(where, f'creator @type {c.get("@type")!r}')


def check_pages(site, base):
    pages = sorted(p for p in (site / "datasets").glob("*/index.html"))
    if not pages:
        fail("datasets/", "no dataset pages were generated")
    keys = []
    for p in pages:
        key = p.parent.name
        where = f"datasets/{key}/"
        bs = blocks(p)
        if len(bs) != 1:
            fail(where, f"{len(bs)} JSON-LD blocks, expected exactly 1")
            continue
        try:
            node = json.loads(bs[0])
        except json.JSONDecodeError as e:
            fail(where, f"JSON-LD does not parse: {e}")
            continue
        check_dataset_node(node, where, f"{base}/datasets/{key}/")
        if key == "release":
            continue
        keys.append(key)
        side = site / "datasets" / f"{key}.jsonld"
        if not side.exists():
            fail(where, f"no sidecar datasets/{key}.jsonld")
        else:
            try:
                if json.loads(side.read_text(encoding="utf-8")) != node:
                    fail(where, "the sidecar .jsonld differs from the in-page block")
            except json.JSONDecodeError as e:
                fail(where, f"sidecar .jsonld does not parse: {e}")
        rec = site / "datasets" / f"{key}.json"
        if not rec.exists():
            fail(where, f"no record datasets/{key}.json")
    return keys


def check_catalog_page(site, base, keys):
    p = site / "datasets" / "index.html"
    if not p.exists():
        return fail("datasets/", "no /datasets/ page")
    bs = blocks(p)
    if len(bs) != 1:
        return fail("datasets/", f"{len(bs)} JSON-LD blocks, expected 1")
    node = json.loads(bs[0])
    if node.get("@type") != "DataCatalog":
        fail("datasets/", f'@type {node.get("@type")!r}, expected "DataCatalog"')
    listed = {d["@id"].rstrip("/").rsplit("/", 1)[-1] for d in node.get("dataset", [])}
    missing = set(keys) - listed
    extra = listed - set(keys)
    if missing:
        fail("datasets/", f"pages not listed in the DataCatalog: {sorted(missing)}")
    if extra:
        fail("datasets/", f"listed in the DataCatalog with no page: {sorted(extra)}")


def check_sitemap(site, base, keys):
    p = site / "datasets" / "sitemap.xml"
    if not p.exists():
        return fail("datasets/sitemap.xml", "missing")
    try:
        root = ET.fromstring(p.read_text(encoding="utf-8"))
    except ET.ParseError as e:
        return fail("datasets/sitemap.xml", f"not well-formed: {e}")
    ns = "{http://www.sitemaps.org/schemas/sitemap/0.9}"
    locs = [u.findtext(ns + "loc") for u in root.findall(ns + "url")]
    for loc in locs:
        if not str(loc).startswith("http"):
            fail("datasets/sitemap.xml", f"relative <loc>: {loc!r}")
    want = {f"{base}/datasets/{k}/" for k in keys} | {f"{base}/datasets/", f"{base}/datasets/release/"}
    if set(locs) != want:
        fail("datasets/sitemap.xml",
             f"listed {len(locs)} URLs, the pages are {len(want)}; "
             f"only in sitemap: {sorted(set(locs) - want)}; only as pages: {sorted(want - set(locs))}")
    notes.append(f"sitemap.xml: {len(locs)} URLs")


DCAT_REQ_CATALOG = ["@context", "@type", "conformsTo", "dataset"]
DCAT_REQ_DATASET = ["title", "description", "keyword", "modified", "publisher",
                    "contactPoint", "identifier", "accessLevel"]


def refs_in(node):
    """every $ref string anywhere under a JSON schema node"""
    if isinstance(node, dict):
        for k, v in node.items():
            if k == "$ref" and isinstance(v, str):
                yield v
            else:
                yield from refs_in(v)
    elif isinstance(node, list):
        for v in node:
            yield from refs_in(v)


def check_data_json(site):
    p = site / "data.json"
    if not p.exists():
        return fail("data.json", "missing")
    cat = json.loads(p.read_text(encoding="utf-8"))
    for k in DCAT_REQ_CATALOG:
        if k not in cat:
            fail("data.json", f"catalog is missing {k}")
    for i, d in enumerate(cat.get("dataset", [])):
        w = f"data.json[{i}] {d.get('title', '?')!r}"
        for k in DCAT_REQ_DATASET:
            if not d.get(k):
                fail(w, f"missing required DCAT-US field {k}")
        cp = d.get("contactPoint") or {}
        if not str(cp.get("hasEmail", "")).startswith("mailto:"):
            fail(w, "contactPoint.hasEmail must be a mailto: URI")
        if d.get("accessLevel") not in ("public", "restricted public", "non-public"):
            fail(w, f"accessLevel {d.get('accessLevel')!r}")
        for j, dist in enumerate(d.get("distribution") or []):
            if not (dist.get("downloadURL") or dist.get("accessURL")):
                fail(w, f"distribution[{j}] has neither downloadURL nor accessURL")
        if d.get("spatial") and len(str(d["spatial"]).split(",")) != 4:
            fail(w, f"spatial is not a four-number bbox: {d['spatial']!r}")
    notes.append(f"data.json: {len(cat.get('dataset', []))} DCAT-US datasets")
    try:
        import jsonschema  # noqa
    except ImportError:
        notes.append("data.json: jsonschema not installed — checked the required-field subset only")
        return
    try:
        with urllib.request.urlopen(DCAT_SCHEMA, timeout=20) as r:
            schema = json.load(r)
    except Exception as e:  # offline is not a failure; the field checks above already ran
        notes.append(f"data.json: could not fetch the DCAT-US schema ({e}) — field subset only")
        return
    import jsonschema
    # The profile splits into sibling files (dataset-non-federal.json, distribution.json, …)
    # referenced RELATIVELY, and every one of them declares `id: project-open-data.cio.gov/…` — a
    # host that now serves HTML, so left alone each $ref resets the resolution scope onto a dead
    # URL. Walk the refs ourselves, fetch each sibling from the same directory, drop its `id`, and
    # hand the resolver a complete store.
    base_dir = DCAT_SCHEMA.rsplit("/", 1)[0] + "/"
    store, queue = {}, [schema]
    schema.pop("id", None)
    store[DCAT_SCHEMA] = schema
    while queue:
        node = queue.pop()
        for ref in refs_in(node):
            if ref.startswith("#") or "://" in ref:
                continue
            url = base_dir + ref.split("#", 1)[0]
            if url in store:
                continue
            try:
                with urllib.request.urlopen(url, timeout=20) as r:
                    sub = json.load(r)
            except Exception as e:
                notes.append(f"data.json: could not fetch {ref} ({e}) — field subset only")
                return
            sub.pop("id", None)
            store[url] = sub
            queue.append(sub)
    with warnings.catch_warnings():   # RefResolver is deprecated but is the only API that takes a store
        warnings.simplefilter("ignore", DeprecationWarning)
        resolver = jsonschema.RefResolver(base_uri=DCAT_SCHEMA, referrer=schema, store=store)
    v = jsonschema.Draft4Validator(schema, resolver=resolver)
    errs = sorted(v.iter_errors(cat), key=lambda e: list(e.path))
    for e in errs[:20]:
        fail("data.json", f"{'/'.join(str(x) for x in e.path)}: {e.message}")
    if not errs:
        notes.append("data.json: valid against the DCAT-US 1.1 schema")


def main():
    site = Path(sys.argv[1] if len(sys.argv) > 1 else "_site").resolve()
    if not site.is_dir():
        sys.exit(f"no such build directory: {site} — run `bundle exec jekyll build` first")
    base = "https://calcofi.io"
    keys = check_pages(site, base)
    check_catalog_page(site, base, keys)
    check_sitemap(site, base, keys)
    check_data_json(site)
    print(f"checked {len(keys)} dataset pages + the release page in {site}")
    for n in notes:
        print(f"  {n}")
    if fails:
        print(f"\nFAIL — {len(fails)} problem(s):")
        for f in fails:
            print(f"  {f}")
        sys.exit(1)
    print("\nall JSON-LD, the sitemap and data.json pass")


if __name__ == "__main__":
    main()
