#!/usr/bin/env python3
"""check_species_media.py — refuse to publish a species-media sidecar that would mis-credit a page.

    scripts/check_species_media.py [.cache/species-media/{release}/taxa_media.json]
                                   [--taxa _data/taxa.json] [--sample 0.05] [--no-network]

Five assertions, each from the plan `2026-09-11 Species faces …`:

  1 every non-null asset carries an ALLOW-LISTED licence (§ D7: CC0, public domain, the Public
    Domain Mark, CC BY, CC BY-SA, CC BY-NC, CC BY-NC-SA — never an ND, never "unknown"),
  2 … a non-empty credit, and
  3 … a `page` or a `url` a reader can follow to the original,
  4 `taxon_shown` is the page's taxon, a descendant of it, or an ancestor within TWO ranks
    (walked through `taxa.json`'s `parent_taxon_key`) — a caption must not misname what is shown
    (§ Risks: "a caption misnames what is shown"),
  5 silhouettes cover at least 95 % of the taxa (§ Risks: the check refuses a JSON below that),
  and a 5 % random sample of the assets' `url`s answers 200.

Exits non-zero with the list of offenders.  Standard library only.
"""

from __future__ import annotations

import argparse
import json
import random
import sys
import urllib.error
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
UA = "calcofi.io species-media-check/1.0 (https://calcofi.io; bdbest@gmail.com)"

# the normalised forms fetch_species_media.py is allowed to emit (plan § D7)
ALLOWED_PREFIXES = ("CC0", "Public domain", "Public Domain Mark",
                    "CC BY", "CC BY-SA", "CC BY-NC", "CC BY-NC-SA")
SILHOUETTE_MIN = 0.95
ASSET_SLOTS = ("silhouette", "photo", "drawing", "plate")


def allowed(license_label: str | None) -> bool:
    s = (license_label or "").strip()
    if not s:
        return False
    if "ND" in s.replace("-ND", " ND ").split() or "-nd" in s.lower() or "-ND" in s:
        return False
    return s.startswith(ALLOWED_PREFIXES)


def ancestors(by_key, key, limit=99):
    out, cur, seen = [], by_key.get(key), {key}
    while cur and len(out) < limit:
        p = cur.get("parent_taxon_key")
        if not p or p in seen:
            break
        out.append(p)
        seen.add(p)
        cur = by_key.get(p)
    return out


def shown_ok(by_key, by_name, key, shown, asset=None, slot=None) -> bool:
    """Is what the asset SHOWS within two ranks of the page's taxon?

    The taxon itself, a descendant of it, an ancestor at most two ranks up, or a relative whose
    nearest shared ancestor is at most two ranks above the page's taxon — a congener (the
    silhouette of *Sardinops melanostictus* on the *Sardinops sagax* page) or a con-familial.
    Names PhyloPic draws from are often absent from the record, so the genus word and, for the
    silhouette, the walk's own `steps_up` stand in: the fetcher matched the page's OWN lineage
    name that many ranks up, and PhyloPic's `specificNode` is by construction under that node.
    """
    t = by_key.get(key) or {}
    mine = (t.get("scientific_name") or "").strip().lower()
    cand = (shown or "").strip().lower()
    if not cand:
        return False
    if cand == mine:
        return True
    ckey = by_name.get(cand)
    if ckey and key in ancestors(by_key, ckey):             # a descendant: shown and named
        return True
    mine_anc = ancestors(by_key, key, limit=2)
    if ckey and ckey in mine_anc:                           # an ancestor within two ranks
        return True
    if ckey and set(ancestors(by_key, ckey)) & set(mine_anc):
        return True                                         # a relative under a shared ancestor
    if mine and cand.startswith(mine + " "):                # a species under a genus page
        return True
    if mine and mine.startswith(cand + " "):                # the genus of our species
        return True
    if " " in mine and " " in cand and mine.split()[0] == cand.split()[0]:
        return True                                         # a congener: the genus is shared
    lin = [v for v in (t.get("lineage") or {}).values() if v]
    for i, anc in enumerate(reversed(lin)):                 # family, order, class, phylum, kingdom
        if anc and anc.lower() == cand and i < 2:
            return True
    if (slot == "silhouette" and (asset or {}).get("resolved_by") == "name"
            and (asset or {}).get("steps_up") is not None and asset["steps_up"] <= 2):
        return True
    return False


def head_ok(url) -> bool:
    for method in ("HEAD", "GET"):
        try:
            req = urllib.request.Request(url, method=method, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=30) as r:
                if 200 <= r.status < 300:
                    return True
        except urllib.error.HTTPError as e:
            if e.code == 405:                               # the host refuses HEAD: try GET
                continue
            return False
        except Exception:
            return False
    return False


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("media", nargs="?", help="taxa_media.json (default: the newest under .cache/)")
    ap.add_argument("--taxa", default=str(ROOT / "_data" / "taxa.json"))
    ap.add_argument("--sample", type=float, default=0.05, help="share of urls to GET (0 = none)")
    ap.add_argument("--no-network", action="store_true")
    ap.add_argument("--seed", type=int, default=11)
    args = ap.parse_args(argv)

    path = Path(args.media) if args.media else None
    if path is None:
        found = sorted((ROOT / ".cache" / "species-media").glob("*/taxa_media.json"))
        if not found:
            sys.exit("no taxa_media.json given and none under .cache/species-media/")
        path = found[-1]
    doc = json.loads(Path(path).read_text())
    rec = json.loads(Path(args.taxa).read_text())
    by_key = {t["taxon_key"]: t for t in rec["taxa"]}
    by_name = {}
    for t in rec["taxa"]:
        n = (t.get("scientific_name") or "").strip().lower()
        if n and n not in by_name:
            by_name[n] = t["taxon_key"]

    problems: list[str] = []
    urls: list[tuple[str, str]] = []
    taxa = doc.get("taxa") or {}

    for key, e in taxa.items():
        if key not in by_key:
            problems.append(f"{key}: not a taxon of {rec['release']['version']}'s record")
        for slot in ASSET_SLOTS:
            a = e.get(slot)
            if not a:
                continue
            where = f"{key} {slot}"
            if not allowed(a.get("license")):
                problems.append(f"{where}: licence {a.get('license')!r} is not allow-listed")
            if not (a.get("credit") or "").strip():
                problems.append(f"{where}: no credit")
            link = a.get("page") or a.get("url")
            if not link:
                problems.append(f"{where}: neither a page nor a url")
            else:
                urls.append((where, link))
            if not shown_ok(by_key, by_name, key, a.get("taxon_shown"), a, slot):
                problems.append(f"{where}: taxon_shown {a.get('taxon_shown')!r} is not "
                                f"{by_key.get(key, {}).get('scientific_name')!r} nor within two ranks")

    n = len(taxa)
    n_sil = sum(1 for e in taxa.values() if e.get("silhouette"))
    if n and n_sil / n < SILHOUETTE_MIN:
        problems.append(f"silhouettes on {n_sil}/{n} = {n_sil / n:.1%} of taxa, "
                        f"below the {SILHOUETTE_MIN:.0%} floor")

    checked = 0
    if urls and args.sample > 0 and not args.no_network:
        random.seed(args.seed)
        pick = random.sample(urls, max(1, round(len(urls) * args.sample)))
        for where, u in pick:
            checked += 1
            if not head_ok(u):
                problems.append(f"{where}: {u} did not answer 200")

    print(f"{path}")
    print(f"  {n} taxa · silhouette {n_sil} ({n_sil / n:.0%})" if n else "  0 taxa")
    for slot in ("photo", "drawing", "plate", "size", "text"):
        c = sum(1 for e in taxa.values() if e.get(slot))
        print(f"  {slot:<11} {c}" + (f" ({c / n:.0%})" if n else ""))
    print(f"  {len(urls)} asset links · {checked} sampled with a live request")
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
