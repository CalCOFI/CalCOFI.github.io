#!/usr/bin/env python3
"""fetch_species_media.py — the face of every species page, fetched from eight public services.

    scripts/fetch_species_media.py [--release v2026.09.10] [--only FILE] [--limit N]
                                   [--refresh] [--dry-run] [--upload] [--sizes sizes.json]

Walks `_data/taxa.json` (the release's species catalog record, fetched by scripts/fetch_release.sh)
and writes, for every taxon, the sidecar `taxa_media.json` in the shape of the plan's Appendix A
(plan `2026-09-11 Species faces …`, § D1 and § D5–D8) plus 800 px WebP thumbnails, under
`.cache/species-media/{release}/`.  `--upload` rsyncs that folder to
`gs://calcofi-files-public/species-media/{release}/` and stamps each asset's `cached` object path.

The sources, in the order they are asked:

    PhyloPic     the silhouette — the one picture EVERY page can have.  By WoRMS id
                 (/resolve/marinespecies.org/taxname/{id}), else by name at each rank up the
                 lineage until a node has a primary image.  `taxon_shown` is the image's
                 `specificNode`, never the page's taxon: the caption has to name what is drawn.
    Wikidata     one SPARQL per batch of 100 taxa (never one query per taxon) on P850 (WoRMS)
                 and P815 (ITIS) → the item, P18, the enwiki sitelink, P3151 iNat, P3444 eBird,
                 P938 FishBase, P846 GBIF, P2043 length.
    Wikipedia    REST page/summary from the sitelink → the lead sentence(s), the revision.
    Commons      P18 and the files of Category:{scientific name} → extmetadata (the licence per
                 FILE, which is the only field the photo sources agree on).
    iNaturalist  taxon_photos (curated) then default_photo; `license_code` null = all rights
                 reserved, which the policy drops.
    GBIF         occurrence/search media — the raw fallback.  The `license=` query parameter
                 filters the DATASET, not the image, so the licence is read per media item.
    WoRMS        AphiaAttributesByAphiaID → a checked maximum body length.
    NOAA AFSC    the Ichthyoplankton Information System's developmental plate, for fishes.

The licence policy and the ranking are the plan's D7 — see `POLICY_ALLOW` and `rank_key()`.

Resumable: every source's answer for every taxon is cached as one small JSON under
`.cache/species-media/{release}/_cache/{source}/{slug}.json`, so a killed run continues where it
stopped; `--refresh` ignores the cache.  A source that fails for a taxon leaves that slot null,
logs one line, and the run continues.

Python >= 3.11, standard library + Pillow.  Nothing here is installed; nothing here is committed.
"""

from __future__ import annotations

import argparse
import base64
import io
import json
import os
import re
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    from PIL import Image
except ImportError:                                                     # pragma: no cover
    sys.exit("Pillow is required (python3 -c 'import PIL').  Do not install it here — ask.")

ROOT = Path(__file__).resolve().parent.parent
CONTACT = os.environ.get("CALCOFI_MEDIA_CONTACT", "bdbest@gmail.com")
UA = f"calcofi.io species-media/1.0 (https://calcofi.io; {CONTACT})"
BUCKET = "gs://calcofi-files-public"
PREFIX = "species-media"

# ── the licence policy (plan § D7) ──────────────────────────────────────────────────────────────
# Take: CC0, public domain (incl. the Public Domain Mark), CC BY, CC BY-SA.  Take, rank last and
# label: CC BY-NC, CC BY-NC-SA.  Leave: any ND (the crop and the fade are derivatives), anything
# without a licence field, anything "all rights reserved".  `null` is NEVER mapped to a licence.
POLICY_ALLOW = ["CC0", "PD", "PDM", "CC BY", "CC BY-SA", "CC BY-NC", "CC BY-NC-SA"]
POLICY_DENY = ["ND", "ARR", "unknown"]

LICENSE_RANK = {"CC0": 0, "Public domain": 1, "Public Domain Mark": 1,
                "CC BY": 2, "CC BY-SA": 3, "CC BY-NC": 4, "CC BY-NC-SA": 5}

LICENSE_URL = {
    "CC0 1.0": "https://creativecommons.org/publicdomain/zero/1.0/",
    "Public Domain Mark": "https://creativecommons.org/publicdomain/mark/1.0/",
    "Public domain": None,
}

# the fish classes whose species the AFSC Ichthyoplankton Information System may hold a plate for
FISH_CLASSES = {"actinopteri", "actinopterygii", "teleostei", "elasmobranchii", "holocephali"}

PLATE_CREDIT = ("Matarese, Kendall, Blood & Vinter 1989, NOAA Tech. Rep. NMFS 80, "
                "via the AFSC Ichthyoplankton Information System")
PLATE_LICENSE = "Public domain (US Government work)"

# a Commons file counts as a DRAWING, not a photograph, when one of these words appears in its
# categories, its ObjectName or its ImageDescription: they are the words Commons itself uses for
# the hand-made images (plates, engravings, lithographs) rather than for photographs.
DRAWING_WORDS = ("illustration", "drawing", "drawings", "plate", "plates", "painting",
                 "engraving", "engravings", "lithograph", "lithographs", "sketch", "etching",
                 "woodcut", "artwork", "scientific illustration", "watercolor", "watercolour")
# … unless one of these appears too: a diagram, a chart, a map or a graph is a figure ABOUT the
# organism, not a picture OF it, and Commons files them under the same "illustration" categories.
NOT_DRAWING_WORDS = ("diagram", "chart", "graph", "map", "maps", "logo", "distribution map",
                     "histogram", "plot of", "table", "cladogram", "phylogeny")

# per-host rate limits, requests per second (plan/brief: PhyloPic 2, Wikidata 1, Commons 2,
# Wikipedia 4, iNaturalist 1, GBIF 4, WoRMS 3, NOAA 1)
RATE = {"phylopic": 2.0, "wikidata": 1.0, "commons": 2.0, "wikipedia": 4.0,
        "inat": 1.0, "gbif": 4.0, "worms": 3.0, "noaa": 1.0, "download": 4.0}
_last: dict[str, float] = {}

VERBOSE = True


def log(*a):
    if VERBOSE:
        print(*a, file=sys.stderr, flush=True)


# ── HTTP ────────────────────────────────────────────────────────────────────────────────────────

def _throttle(host_key: str):
    rps = RATE.get(host_key, 2.0)
    gap = 1.0 / rps
    now = time.monotonic()
    prev = _last.get(host_key)
    if prev is not None and now - prev < gap:
        time.sleep(gap - (now - prev))
    _last[host_key] = time.monotonic()


class HttpError(Exception):
    def __init__(self, code, url):
        super().__init__(f"HTTP {code} {url}")
        self.code = code


def http(url, host_key, accept="application/json", timeout=40, data=None, headers=None,
         tries=3) -> bytes:
    """One request with the contact User-Agent, a timeout, and three retries with backoff."""
    hdr = {"User-Agent": UA, "Accept": accept, **(headers or {})}
    last = None
    for attempt in range(tries):
        _throttle(host_key)
        req = urllib.request.Request(url, headers=hdr, data=data)
        try:
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()
        except urllib.error.HTTPError as e:
            last = HttpError(e.code, url)
            if e.code in (400, 401, 403, 404, 410):          # a real answer: do not retry
                raise last
            time.sleep(2 ** attempt * 1.5)
        except Exception as e:                                # timeout, DNS, reset
            last = e
            time.sleep(2 ** attempt * 1.5)
    raise last


def get_json(url, host_key, **kw):
    return json.loads(http(url, host_key, **kw))


# ── the cache: one small JSON per taxon per source ──────────────────────────────────────────────

class Cache:
    def __init__(self, root: Path, refresh: bool):
        self.root = root
        self.refresh = refresh

    def path(self, source: str, slug: str) -> Path:
        return self.root / source / f"{slug}.json"

    def get(self, source, slug):
        if self.refresh:
            return None
        p = self.path(source, slug)
        if p.exists():
            try:
                return json.loads(p.read_text())
            except Exception:
                return None
        return None

    def put(self, source, slug, value):
        p = self.path(source, slug)
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps(value, ensure_ascii=False))
        return value

    def run(self, source, slug, fn):
        """Cached call.  A failure caches nothing and leaves the slot null."""
        hit = self.get(source, slug)
        if hit is not None:
            return hit.get("v")
        try:
            v = fn()
        except Exception as e:
            log(f"    ! {source} {slug}: {type(e).__name__}: {e}")
            return None
        self.put(source, slug, {"v": v, "at": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())})
        return v


# ── licences ────────────────────────────────────────────────────────────────────────────────────

def normalize_license(raw: str | None, url: str | None = None) -> tuple[str, str | None] | None:
    """Normalise a source's licence string to one of the allowed forms, or None to DROP the file.

    Returns (label, license_url).  Anything with ND, anything empty, anything "all rights
    reserved" and anything unrecognised returns None — a licence is never assumed.
    """
    s = (raw or "").strip()
    u = (url or "").strip()
    hay = f"{s} {u}".lower().replace("_", "-").replace("cc-", "cc ")
    if not hay.strip():
        return None
    if "-nd" in hay or " nd " in hay or "noderiv" in hay:
        return None
    if "all rights reserved" in hay or "arr" == s.lower() or "copyright" == s.lower():
        return None

    def ver(default=""):
        m = re.search(r"(\d\.\d)", s) or re.search(r"/(\d\.\d)/", u)
        return m.group(1) if m else default

    if "cc0" in hay or "zero" in hay:
        return "CC0 1.0", "https://creativecommons.org/publicdomain/zero/1.0/"
    if "publicdomain/mark" in hay or "public domain mark" in hay or hay.strip() == "pdm":
        return "Public Domain Mark", "https://creativecommons.org/publicdomain/mark/1.0/"
    if "public domain" in hay or hay.strip() in ("pd", "pd-us", "pd-usgov") or "pd-" in hay:
        return "Public domain", None
    if "by-nc-sa" in hay or "by nc sa" in hay:
        v = ver("4.0")
        return f"CC BY-NC-SA {v}", f"https://creativecommons.org/licenses/by-nc-sa/{v}/"
    if "by-nc" in hay or "by nc" in hay:
        v = ver("4.0")
        return f"CC BY-NC {v}", f"https://creativecommons.org/licenses/by-nc/{v}/"
    if "by-sa" in hay or "by sa" in hay:
        v = ver("4.0")
        return f"CC BY-SA {v}", f"https://creativecommons.org/licenses/by-sa/{v}/"
    if re.search(r"\bcc[ -]?by\b", hay) or "/licenses/by/" in hay:
        v = ver("4.0")
        return f"CC BY {v}", f"https://creativecommons.org/licenses/by/{v}/"
    return None


def license_order(label: str) -> int:
    base = re.sub(r"\s*\d.*$", "", label).strip()
    return LICENSE_RANK.get(base, 9)


# ── the record: names, lineage, ancestry ────────────────────────────────────────────────────────

class Record:
    """`taxa.json` with the lookups the ranking needs: name → key, key → parents."""

    def __init__(self, path: Path):
        d = json.loads(path.read_text())
        self.release = d["release"]["version"]
        self.taxa = d["taxa"]
        self.by_key = {t["taxon_key"]: t for t in self.taxa}
        self.by_name = {}
        for t in self.taxa:
            n = (t.get("scientific_name") or "").strip()
            if n and n.lower() not in self.by_name:
                self.by_name[n.lower()] = t["taxon_key"]

    def ancestors(self, key, limit=99):
        """The chain of parent keys, nearest first."""
        out, cur, seen = [], self.by_key.get(key), {key}
        while cur and len(out) < limit:
            p = cur.get("parent_taxon_key")
            if not p or p in seen:
                break
            out.append(p)
            seen.add(p)
            cur = self.by_key.get(p)
        return out

    def relation(self, key, name: str | None) -> tuple[int, int] | None:
        """How a candidate's `taxon_shown` relates to the page's taxon (plan § D7's ranking).

        Returns (tier, steps_up): tier 0 = the taxon itself, 1 = a species (or any descendant)
        under it, 2 = an ancestor within two ranks ("stands in").  None means the candidate names
        something else entirely and is dropped.
        """
        t = self.by_key.get(key) or {}
        mine = (t.get("scientific_name") or "").strip()
        cand = (name or "").strip()
        if not cand:
            return None
        if mine and cand.lower() == mine.lower():
            return 0, 0
        ckey = self.by_name.get(cand.lower())
        if ckey and key in self.ancestors(ckey):
            return 1, 0                                   # a descendant: shown, and named
        if ckey:
            anc = self.ancestors(key, limit=2)
            if ckey in anc:
                return 2, anc.index(ckey) + 1
            return None
        # the candidate is not in the record: fall back to the name itself
        if mine and cand.lower().startswith(mine.lower() + " "):
            return 1, 0                                   # "Genus species" under "Genus"
        if mine and mine.lower().startswith(cand.lower() + " "):
            return 2, 1                                   # the genus of our species
        lin = [v for v in (t.get("lineage") or {}).values() if v]
        for i, anc_name in enumerate(reversed(lin)):       # family, order, class, phylum, kingdom
            if anc_name and anc_name.lower() == cand.lower():
                return (2, i + 1) if i < 2 else None
        return None


# ── PhyloPic ────────────────────────────────────────────────────────────────────────────────────

_phylopic_build = None


def phylopic_build():
    """The API's current build number, which every /nodes query must carry.

    `/ping` answered with it in the 2026-09-11 probe; it now answers 204 with no body, so the
    number is read where the API actually publishes it: the 307 redirect the root sends to
    `/?build=NNN`.  Both are tried, in that order, before the walk gives up.
    """
    global _phylopic_build
    if _phylopic_build is None:
        for url in ("https://api.phylopic.org/ping", "https://api.phylopic.org/"):
            try:
                _throttle("phylopic")
                req = urllib.request.Request(url, headers={"User-Agent": UA,
                                                           "Accept": "application/json"})
                with urllib.request.urlopen(req, timeout=40) as r:
                    m = re.search(r"[?&]build=(\d+)", r.geturl())
                    if m:
                        _phylopic_build = int(m.group(1))
                        break
                    body = r.read()
                    if body:
                        _phylopic_build = json.loads(body).get("build")
                        if _phylopic_build:
                            break
            except Exception as e:
                log(f"  ! phylopic build from {url}: {type(e).__name__}: {e}")
        if not _phylopic_build:
            raise RuntimeError("PhyloPic did not publish a build number")
        log(f"phylopic build {_phylopic_build}")
    return _phylopic_build


def _phylopic_from_image(img, resolved_by, steps_up):
    L = img["_links"]
    href = L["self"]["href"]
    uuid = href.split("/images/")[1].split("?")[0]
    lic_url = (L.get("license") or {}).get("href")
    lic = normalize_license(None, lic_url)
    if not lic:
        return None                                        # PhyloPic is CC0/PDM/BY/BY-SA only
    return {"source": "phylopic", "uuid": uuid,
            "url": f"https://www.phylopic.org/images/{uuid}",
            "svg_url": (L.get("vectorFile") or {}).get("href"),
            "license": lic[0], "license_url": lic[1],
            "credit": (L.get("contributor") or {}).get("title"),
            "taxon_shown": (L.get("specificNode") or {}).get("title")
                           or (L.get("generalNode") or {}).get("title"),
            "node": (L.get("generalNode") or {}).get("title"),
            "resolved_by": resolved_by, "steps_up": steps_up}


def phylopic_by_worms(worms_id):
    b = phylopic_build()
    d = get_json(f"https://api.phylopic.org/resolve/marinespecies.org/taxname/{worms_id}"
                 f"?build={b}&embed_primaryImage=true", "phylopic")
    img = (d.get("_embedded") or {}).get("primaryImage")
    return _phylopic_from_image(img, "worms_id", 0) if img else None


_name_memo: dict[str, dict | None] = {}


def phylopic_by_name(name, steps_up, memo=None):
    """One /nodes query per NAME, memoised across taxa: 2,410 taxa share a few hundred families,
    orders and classes, and the walk would otherwise ask for "Myctophidae" hundreds of times."""
    low = name.lower()
    hit = _name_memo.get(low, "miss")
    if hit == "miss" and memo is not None:
        cached = memo.get("phylopic_name", re.sub(r"[^a-z0-9]+", "-", low))
        if cached is not None:
            hit = cached.get("v")
            _name_memo[low] = hit
    if hit != "miss":
        return dict(hit, steps_up=steps_up) if hit else None
    b = phylopic_build()
    q = urllib.parse.quote(low)
    d = get_json(f"https://api.phylopic.org/nodes?build={b}&filter_name={q}"
                 f"&embed_items=true&embed_primaryImage=true&page=0", "phylopic")
    found = None
    for n in ((d.get("_embedded") or {}).get("items") or []):
        img = (n.get("_embedded") or {}).get("primaryImage")
        if img:
            found = _phylopic_from_image(img, "name", steps_up)
            break
    _name_memo[low] = found
    if memo is not None:
        memo.put("phylopic_name", re.sub(r"[^a-z0-9]+", "-", low), {"v": found})
    return found


def name_chain(t):
    """The taxon's own name, then each rank up its lineage — the PhyloPic fallback walk."""
    names, seen = [], set()
    def add(n):
        if n and n.lower() not in seen:
            seen.add(n.lower())
            names.append(n)
    name = (t.get("scientific_name") or "").strip()
    add(name)
    if (t.get("rank") or "").lower() in ("species", "subspecies", "variety", "forma") and " " in name:
        add(name.split()[0])                                # the genus
    lin = t.get("lineage") or {}
    for k in ("family", "order", "class", "phylum", "kingdom"):
        add(lin.get(k))
    return names


def fetch_silhouette(t, rec, memo=None):
    wid = (t.get("ids") or {}).get("worms_id")
    if wid:
        try:
            s = phylopic_by_worms(wid)
        except HttpError as e:
            # /resolve 404s for most taxa (the probe: 4 of 12 resolved) — that is the normal
            # answer, not a failure, and the name walk below is the fallback it implies.
            if e.code != 404:
                raise
            s = None
        if s:
            return s
    for i, n in enumerate(name_chain(t)):
        try:
            s = phylopic_by_name(n, i, memo)
        except HttpError:
            continue
        if s:
            return s
    return None


SVG_STRIP = [
    (re.compile(r"<\?xml.*?\?>", re.S), ""),
    (re.compile(r"<!DOCTYPE.*?>", re.S), ""),
    (re.compile(r"<!--.*?-->", re.S), ""),
    (re.compile(r"<metadata\b.*?</metadata>", re.S | re.I), ""),
    (re.compile(r"<title\b.*?</title>", re.S | re.I), ""),
    (re.compile(r"<desc\b.*?</desc>", re.S | re.I), ""),
]


def normalize_svg(svg: str):
    """Strip the prolog, the DOCTYPE and the metadata; ink the paths with `currentColor`.

    Returns (viewBox, aspect, inner markup).  The generator inlines `svg_inner` inside its own
    <svg viewBox=…>, so the page's colour reaches the silhouette without a second file.
    """
    for pat, sub in SVG_STRIP:
        svg = pat.sub(sub, svg)
    m = re.search(r'viewBox\s*=\s*"([^"]+)"', svg)
    vb = m.group(1).strip() if m else None
    if not vb:
        w = re.search(r'\bwidth\s*=\s*"([\d.]+)', svg)
        h = re.search(r'\bheight\s*=\s*"([\d.]+)', svg)
        if w and h:
            vb = f"0 0 {w.group(1)} {h.group(1)}"
    aspect = None
    if vb:
        p = vb.replace(",", " ").split()
        if len(p) == 4:
            try:
                aspect = round(float(p[2]) / float(p[3]), 3)
            except (ValueError, ZeroDivisionError):
                aspect = None
    m = re.search(r"<svg\b[^>]*>(.*)</svg\s*>", svg, re.S | re.I)
    inner = (m.group(1) if m else svg).strip()
    # every explicit fill becomes the page's ink; `fill="none"` (a stroke-only path) is left alone
    inner = re.sub(r'fill\s*=\s*"(?!none")[^"]*"', 'fill="currentColor"', inner)
    inner = re.sub(r"fill\s*:\s*(?!none)[^;\"']+", "fill:currentColor", inner)
    if 'fill="currentColor"' not in inner and "fill:currentColor" not in inner:
        inner = f'<g fill="currentColor">{inner}</g>'
    inner = re.sub(r"\s*\n\s*", " ", inner).strip()
    return vb, aspect, inner


# ── Wikidata (batched) ──────────────────────────────────────────────────────────────────────────

WD_QUERY = """SELECT ?ext ?item ?image ?len ?inat ?ebird ?fishbase ?gbif ?enwiki WHERE {{
  VALUES ?ext {{ {values} }}
  ?item wdt:{prop} ?ext.
  OPTIONAL{{?item wdt:P18 ?image}}
  OPTIONAL{{?item p:P2043/psv:P2043/wikibase:quantityAmount ?len}}
  OPTIONAL{{?item wdt:P3151 ?inat}} OPTIONAL{{?item wdt:P3444 ?ebird}}
  OPTIONAL{{?item wdt:P938 ?fishbase}} OPTIONAL{{?item wdt:P846 ?gbif}}
  OPTIONAL{{?enwiki schema:about ?item; schema:isPartOf <https://en.wikipedia.org/>}}
}}"""


def wikidata_batch(ext_ids: list[str], prop: str) -> dict:
    """One SPARQL for up to 100 external ids.  Never one query per taxon."""
    values = " ".join(f'"{i}"' for i in ext_ids)
    q = WD_QUERY.format(values=values, prop=prop)
    body = urllib.parse.urlencode({"query": q, "format": "json"}).encode()
    d = json.loads(http("https://query.wikidata.org/sparql", "wikidata",
                        accept="application/sparql-results+json", data=body, timeout=90,
                        headers={"Content-Type": "application/x-www-form-urlencoded"}))
    out = {}
    for row in (d.get("results") or {}).get("bindings", []):
        ext = row["ext"]["value"]
        r = out.setdefault(ext, {})
        for k, v in row.items():
            if k != "ext" and k not in r:
                r[k] = v["value"]
    return out


def wikidata_record(raw):
    """The SPARQL row → the `links` block and the P18 file name."""
    if not raw:
        return None
    item = (raw.get("item") or "").rsplit("/", 1)[-1] or None
    gbif = raw.get("gbif")
    inat = raw.get("inat")
    out = {"wikidata": item,
           "inat": int(inat) if (inat or "").isdigit() else None,
           "fishbase": int(raw["fishbase"]) if (raw.get("fishbase") or "").isdigit() else None,
           "gbif": int(gbif) if (gbif or "").isdigit() else None,
           "ebird": raw.get("ebird") or None,
           "enwiki": raw.get("enwiki") or None,
           "p18": None, "length_m": None}
    if raw.get("image"):
        out["p18"] = urllib.parse.unquote(raw["image"].rsplit("/", 1)[-1]).replace("_", " ")
    try:
        if raw.get("len"):
            out["length_m"] = float(raw["len"]) / 100.0      # P2043 on taxa is centimetres
    except ValueError:
        pass
    return out


# ── Wikipedia ───────────────────────────────────────────────────────────────────────────────────

def sentences(text, n=2, max_chars=320):
    """The probe's rule (species-faces-probe/build.py): the first one or two sentences, <= 320 c."""
    parts = re.split(r"(?<=[.!?])\s+(?=[A-Z])", (text or "").strip())
    out = []
    for p in parts:
        if len(" ".join(out + [p])) > max_chars and out:
            break
        out.append(p)
        if len(out) >= n:
            break
    return " ".join(out)


def fetch_text(enwiki_url, t):
    title = urllib.parse.unquote(enwiki_url.split("/wiki/", 1)[1])
    s = get_json("https://en.wikipedia.org/api/rest_v1/page/summary/"
                 + urllib.parse.quote(title.replace(" ", "_"), safe=""), "wikipedia")
    if s.get("type") == "https://mediawiki.org/wiki/HyperSwitch/errors/not_found":
        return None
    art = s.get("titles", {}).get("normalized") or s.get("title") or title
    desc = (s.get("description") or "").lower()
    about = "taxon"
    if (t.get("rank") or "").lower() == "species" and (
            len(art.split()) == 1 or desc.startswith("genus")):
        about = "genus"
    extract = s.get("extract") or ""
    return {"source": "wikipedia", "title": art,
            "url": (s.get("content_urls") or {}).get("desktop", {}).get("page") or enwiki_url,
            "revision": s.get("revision") and int(s["revision"]),
            "timestamp": (s.get("timestamp") or "")[:10] or None,
            "license": "CC BY-SA 4.0", "about": about,
            "extract": extract, "lead": sentences(extract)}


# ── Commons ─────────────────────────────────────────────────────────────────────────────────────

API_COMMONS = "https://commons.wikimedia.org/w/api.php"


def commons_category_files(name, limit=50):
    u = (f"{API_COMMONS}?action=query&format=json&list=categorymembers&cmtype=file"
         f"&cmlimit={limit}&cmtitle=" + urllib.parse.quote("Category:" + name))
    d = get_json(u, "commons")
    return [m["title"] for m in (d.get("query") or {}).get("categorymembers", [])]


def commons_imageinfo(titles):
    """extmetadata + dimensions for up to 50 titles per call (the API's limit)."""
    out = {}
    for i in range(0, len(titles), 50):
        chunk = titles[i:i + 50]
        u = (f"{API_COMMONS}?action=query&format=json&prop=imageinfo"
             f"&iiprop=extmetadata|url|size&iiurlwidth=1200&titles="
             + urllib.parse.quote("|".join(chunk)))
        d = get_json(u, "commons")
        for pg in ((d.get("query") or {}).get("pages") or {}).values():
            ii = (pg.get("imageinfo") or [{}])[0]
            if not ii:
                continue
            out[pg["title"]] = ii
    return out


def _plain(s):
    """Strip a Commons field's HTML.  A credit is used exactly as the source returns it, with one
    exception: a template that renders the SAME text twice ("Unknown authorUnknown author") is
    collapsed to one copy — that is de-duplication, not authorship."""
    t = re.sub(r"\s+", " ", re.sub("<[^>]+>", "", s or "")).strip()
    half = len(t) // 2
    if len(t) > 6 and len(t) % 2 == 0 and t[:half] == t[half:]:
        t = t[:half]
    return t


def commons_candidates(t, rec, p18):
    titles = []
    if p18:
        titles.append("File:" + p18)
    name = (t.get("scientific_name") or "").strip()
    if name:
        try:
            titles += [x for x in commons_category_files(name) if x not in titles]
        except HttpError:
            pass
    if not titles:
        return []
    info = commons_imageinfo(titles)
    out = []
    for rank_i, title in enumerate(titles):
        ii = info.get(title)
        if not ii:
            continue
        em = ii.get("extmetadata") or {}
        def field(k):
            return _plain((em.get(k) or {}).get("value"))
        lic = normalize_license(field("LicenseShortName"), field("LicenseUrl"))
        if not lic:
            continue
        credit = field("Artist") or field("Credit")
        if not credit:
            continue                                       # a credit is never typed in
        cats = field("Categories")
        shown = None
        for c in cats.split("|"):
            c = c.strip()
            if c and c.lower() in rec.by_name:
                shown = c
                break
        if not shown and name and name.lower() in title.lower():
            shown = name
        if not shown:
            continue                                       # unnamed: the caption would have to lie
        desc = field("ImageDescription")
        obj = field("ObjectName")
        hay = f"{cats} {obj} {desc}".lower()
        is_drawing = (any(w in hay for w in DRAWING_WORDS)
                      and not any(w in hay for w in NOT_DRAWING_WORDS))
        out.append({"source": "commons", "id": title,
                    "page": ii.get("descriptionurl"),
                    "url": ii.get("descriptionurl"),
                    "download": ii.get("thumburl") or ii.get("url"),
                    "license": lic[0], "license_url": lic[1], "credit": credit,
                    "taxon_shown": shown, "shows": desc[:200] or None,
                    "curated": True,       # D7: Commons P18 AND category files are curated;
                                           # `order` keeps P18 (rank_i 0) ahead of the category
                    "w": ii.get("width"), "h": ii.get("height"),
                    "is_drawing": is_drawing, "order": rank_i})
    return out


# ── iNaturalist ─────────────────────────────────────────────────────────────────────────────────

def inat_id_for(t, links):
    if links and links.get("inat"):
        return links["inat"]
    iid = (t.get("ids") or {}).get("inat_id")
    if iid:
        return int(iid)
    name = (t.get("scientific_name") or "").strip()
    if not name:
        return None
    d = get_json("https://api.inaturalist.org/v1/taxa?per_page=3&q="
                 + urllib.parse.quote(name), "inat")
    for r in (d.get("results") or []):
        if (r.get("name") or "").lower() == name.lower():
            return r["id"]
    return None


def inat_candidates(t, rec, links):
    iid = inat_id_for(t, links)
    if not iid:
        return []
    d = get_json(f"https://api.inaturalist.org/v1/taxa/{iid}", "inat")
    res = (d.get("results") or [])
    if not res:
        return []
    fr = res[0]
    out = []
    seq = [(tp.get("photo") or {}, (tp.get("taxon") or {}).get("name") or fr.get("name"), True)
           for tp in (fr.get("taxon_photos") or [])]
    dp = fr.get("default_photo")
    if dp:
        seq.append((dp, fr.get("name"), True))
    for i, (p, shown, curated) in enumerate(seq):
        lic = normalize_license(p.get("license_code"))      # null = all rights reserved: dropped
        if not lic:
            continue
        credit = _plain(p.get("attribution"))
        if not credit:
            continue
        dims = p.get("original_dimensions") or {}
        out.append({"source": "inat", "id": str(p.get("id")),
                    "page": f"https://www.inaturalist.org/photos/{p.get('id')}",
                    "url": f"https://www.inaturalist.org/photos/{p.get('id')}",
                    "download": p.get("original_url") or p.get("large_url") or p.get("medium_url"),
                    "license": lic[0], "license_url": lic[1], "credit": credit,
                    "taxon_shown": shown, "shows": None, "curated": curated,
                    "w": dims.get("width"), "h": dims.get("height"),
                    "is_drawing": False, "order": i})
    return out


# ── GBIF ────────────────────────────────────────────────────────────────────────────────────────

def gbif_key_for(t, links):
    gid = (t.get("ids") or {}).get("gbif_id")
    if gid:
        return int(gid)
    if links and links.get("gbif"):
        return links["gbif"]
    name = (t.get("scientific_name") or "").strip()
    if not name:
        return None
    d = get_json("https://api.gbif.org/v1/species/match?name=" + urllib.parse.quote(name), "gbif")
    return d.get("usageKey")


def gbif_candidates(t, rec, links):
    key = gbif_key_for(t, links)
    if not key:
        return []
    d = get_json(f"https://api.gbif.org/v1/occurrence/search?taxonKey={key}"
                 f"&mediaType=StillImage&limit=50", "gbif")
    out = []
    for i, occ in enumerate(d.get("results") or []):
        for m in (occ.get("media") or [])[:1]:
            # GBIF's `license=` parameter filters the DATASET, not the image (plan § F2), so the
            # licence is read here, per media item, and nothing is inferred from the query.
            lic = normalize_license(m.get("license"))
            if not lic:
                continue
            credit = _plain(m.get("rightsHolder") or m.get("creator"))
            if not credit:
                continue
            shown = occ.get("species") or occ.get("scientificName")
            out.append({"source": "gbif", "id": str(occ.get("key")),
                        "page": f"https://www.gbif.org/occurrence/{occ.get('key')}",
                        "url": m.get("references") or m.get("identifier"),
                        "download": m.get("identifier"),
                        "license": lic[0], "license_url": lic[1], "credit": credit,
                        "taxon_shown": shown, "shows": _plain(m.get("title"))[:200] or None,
                        "curated": False, "w": None, "h": None,
                        "is_drawing": False, "order": i})
    return out


# ── the ranking (plan § D7) ─────────────────────────────────────────────────────────────────────

def rank_key(c):
    """The page's taxon first, then a descendant, then an ancestor within two ranks; curated over
    raw; then the licence order CC0 > PD > BY > BY-SA > NC; then landscape and >= 800 px."""
    big = 0 if (c.get("w") and c.get("h") and c["w"] >= c["h"]
                and max(c["w"], c["h"]) >= 800) else 1
    src = {"commons": 0, "inat": 1, "gbif": 2}.get(c["source"], 3)
    return (c["_tier"], 0 if c.get("curated") else 1, license_order(c["license"]), big,
            src, c.get("order", 0))


def annotate(cands, key, rec):
    """Drop what the record cannot place, stamp `_tier` and `steps_up`."""
    keep = []
    for c in cands:
        r = rec.relation(key, c.get("taxon_shown"))
        if r is None:
            continue
        c["_tier"], c["steps_up"] = r
        keep.append(c)
    return sorted(keep, key=rank_key)


# ── NOAA AFSC Ichthyoplankton Information System (plan § D5, § F6) ──────────────────────────────

def is_fish(t):
    lin = t.get("lineage") or {}
    return ((lin.get("phylum") or "").lower() == "chordata"
            and (lin.get("class") or "").lower() in FISH_CLASSES)


def fetch_plate(t):
    name = (t.get("scientific_name") or "").strip()
    if (t.get("rank") or "").lower() != "species" or " " not in name or not is_fish(t):
        return None
    genus, species = name.split()[:2]
    gsid = f"{genus}!{species}"
    # the IIS keys a species "Genus!species"; the "!" is a literal in its URLs, never escaped
    q = urllib.parse.quote(gsid, safe="!")
    gif = f"https://apps-afsc.fisheries.noaa.gov/ichthyo/images/ill/{q}Page.gif"
    try:
        body = http(gif, "noaa", accept="image/gif", timeout=40)
    except HttpError:
        return None
    if len(body) < 1000 or body[:3] != b"GIF":
        return None
    return {"source": "noaa_iis", "id": gsid,
            "page": f"https://apps-afsc.fisheries.noaa.gov/ichthyo/LHDataIll.php?GSID={q}",
            "url": f"https://apps-afsc.fisheries.noaa.gov/ichthyo/LHDataIll.php?GSID={q}",
            "license": PLATE_LICENSE, "license_url": None, "credit": PLATE_CREDIT,
            "taxon_shown": name, "steps_up": 0, "curated": True,
            "_bytes": base64.b64encode(body).decode()}


# ── WoRMS body size ─────────────────────────────────────────────────────────────────────────────

def worms_size(worms_id):
    a = get_json(f"https://www.marinespecies.org/rest/AphiaAttributesByAphiaID/{worms_id}", "worms")
    rows = []

    def walk(lst):
        for x in (lst if isinstance(lst, list) else []):
            if x.get("measurementType") == "Body size":
                d = {"value": x.get("measurementValue"), "quality": x.get("qualitystatus"),
                     "source_id": x.get("source_id")}
                def kids(l):
                    for y in (l or []):
                        d[y.get("measurementType")] = y.get("measurementValue")
                        kids(y.get("children"))
                kids(x.get("children"))
                rows.append(d)
            walk(x.get("children"))

    walk(a)
    # WoRMS carries one Body size row per sex, life stage and locality (the common dolphin has
    # eight).  "Maximum length" is the LARGEST of the maximum-length rows, and a checked row beats
    # an unreviewed one; a row for a non-adult life stage is not the adult maximum.
    cands = []
    for r in rows:
        if r.get("Type") != "maximum" or r.get("Dimension") != "length":
            continue
        unit = (r.get("Unit") or "").lower()
        if unit not in ("cm", "mm"):
            continue
        stage = (r.get("Life stage") or "adult").lower()
        if stage not in ("adult", "", "unspecified"):
            continue
        try:
            v = float(r["value"])
        except (TypeError, ValueError):
            continue
        cands.append((0 if r.get("quality") == "checked" else 1,
                      -(v / 100.0 if unit == "cm" else v / 1000.0), r))
    if not cands:
        return None
    _, neg_m, r = sorted(cands, key=lambda x: x[:2])[0]   # never sort on the dict itself
    return {"m": round(-neg_m, 5),
            # WoRMS does not publish a length type beside the attribute; FishBase's LType arrives
            # through WS-F2b's sizes.json, and the field stays null rather than being guessed.
            "length_type": r.get("Type of length") or None, "kind": "max",
            "source": "worms_attribute", "source_id": r.get("source_id"),
            "url": f"https://www.marinespecies.org/aphia.php?p=taxdetails&id={worms_id}#attributes"}


# ── thumbnails ──────────────────────────────────────────────────────────────────────────────────

def thumbnail(src_bytes, dest: Path, long_side=800, quality=80):
    im = Image.open(io.BytesIO(src_bytes))
    if im.mode in ("P", "LA", "RGBA"):
        im = im.convert("RGBA")
        bg = Image.new("RGBA", im.size, (255, 255, 255, 255))
        im = Image.alpha_composite(bg, im)
    im = im.convert("RGB")
    w, h = im.size
    if max(w, h) > long_side:
        scale = long_side / max(w, h)
        im = im.resize((max(1, round(w * scale)), max(1, round(h * scale))), Image.LANCZOS)
    dest.parent.mkdir(parents=True, exist_ok=True)
    im.save(dest, "WEBP", quality=quality, method=5)
    return im.size


def materialize(cands, dest: Path, slot, dry_run, out_rel):
    """Take the best candidate whose bytes actually arrive and thumbnail it; try the next on
    failure.  Returns the asset dict, or None when no candidate survives."""
    for c in cands[:4]:
        url = c.get("download")
        if not url:
            continue
        try:
            body = http(url, "download", accept="image/*", timeout=60)
            if not dry_run:
                w, h = thumbnail(body, dest / f"{slot}.webp")
            else:
                w, h = Image.open(io.BytesIO(body)).size
        except Exception as e:
            log(f"    ! {slot} {c['source']} {c['id'][:50]}: {type(e).__name__}: {e}")
            continue
        a = {k: c[k] for k in ("source", "id", "page", "url", "license", "license_url",
                              "credit", "taxon_shown", "steps_up", "shows", "curated")
             if k in c}
        a["cached"] = None
        a["local"] = f"{out_rel}/{slot}.webp"
        a["w"], a["h"] = w, h
        a["focal"] = [0.5, 0.5]
        return a
    return None


# ── one taxon ───────────────────────────────────────────────────────────────────────────────────

def do_taxon(t, rec, cache, out_dir, wd_all, sizes, dry_run):
    key = t["taxon_key"]
    slug = t["slug"]
    dest = out_dir / slug
    entry = {}

    # a — the silhouette
    sil = cache.run("phylopic", slug, lambda: fetch_silhouette(t, rec, cache))
    if sil:
        sil = dict(sil)
        svg = cache.run("phylopic_svg", slug,
                        lambda: http(sil["svg_url"], "phylopic",
                                     accept="image/svg+xml").decode("utf-8", "replace"))
        if svg:
            vb, aspect, inner = normalize_svg(svg)
            sil.update({"viewBox": vb, "aspect": aspect, "svg_inner": inner,
                        "length_axis": ("w" if (aspect or 1) >= 1 else "h"),
                        "svg": f"{PREFIX}/{rec.release}/{slug}/silhouette.svg"})
            if not dry_run:
                dest.mkdir(parents=True, exist_ok=True)
                (dest / "silhouette.svg").write_text(
                    f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{vb}" '
                    f'fill="currentColor">{inner}</svg>')
        sil.pop("svg_url", None)
        entry["silhouette"] = sil

    # b — Wikidata (batched in the prepass) → the links
    links = wikidata_record(wd_all.get(key))
    entry["links"] = ({k: links[k] for k in ("wikidata", "inat", "fishbase", "gbif", "ebird")}
                      if links else None)

    # c — the sentence
    if links and links.get("enwiki"):
        entry["text"] = cache.run("wikipedia", slug, lambda: fetch_text(links["enwiki"], t))
    else:
        entry["text"] = None

    # d — the photo and the drawing
    cands = []
    for source, fn in (("commons", lambda: commons_candidates(t, rec, links and links.get("p18"))),
                       ("inat", lambda: inat_candidates(t, rec, links)),
                       ("gbif", lambda: gbif_candidates(t, rec, links))):
        got = cache.run(f"cand_{source}", slug, fn)
        cands += got or []
    ranked = annotate(cands, key, rec)
    out_rel = f"{PREFIX}/{rec.release}/{slug}"
    photos = [c for c in ranked if not c["is_drawing"]] or ranked
    entry["photo"] = materialize(photos, dest, "photo", dry_run, out_rel)
    drawings = [c for c in ranked if c["source"] == "commons" and c["is_drawing"]
                and (not entry["photo"] or c["id"] != entry["photo"]["id"])]
    entry["drawing"] = materialize(drawings, dest, "drawing", dry_run, out_rel) if drawings else None

    # e — the NOAA plate
    plate = cache.run("noaa", slug, lambda: fetch_plate(t))
    if plate:
        plate = dict(plate)
        body = base64.b64decode(plate.pop("_bytes"))
        try:
            if not dry_run:
                w, h = thumbnail(body, dest / "plate.webp")
            else:
                w, h = Image.open(io.BytesIO(body)).size
            plate.update({"cached": None, "local": f"{out_rel}/plate.webp",
                          "w": w, "h": h, "focal": [0.5, 0.5]})
            entry["plate"] = plate
        except Exception as e:
            log(f"    ! plate {slug}: {type(e).__name__}: {e}")
            entry["plate"] = None
    else:
        entry["plate"] = None

    # f — the size, WoRMS first, then WS-F2b's sizes.json, then Wikidata P2043
    wid = (t.get("ids") or {}).get("worms_id")
    size = cache.run("worms_size", slug, lambda: worms_size(wid)) if wid else None
    fb = (sizes or {}).get(key, {}).get("fishbase") if sizes else None
    if not size and fb and fb.get("length_cm"):
        size = {"m": round(fb["length_cm"] / 100.0, 5), "length_type": fb.get("length_type"),
                "kind": "max", "source": fb.get("server") or "fishbase",
                "source_id": fb.get("spec_code"),
                "url": (f"https://www.{fb.get('server') or 'fishbase'}.se/summary/"
                        f"{(t.get('scientific_name') or '').replace(' ', '-')}.html")}
    if not size and links and links.get("length_m"):
        size = {"m": round(links["length_m"], 5), "length_type": None, "kind": "max",
                "source": "wikidata_p2043", "source_id": links.get("wikidata"),
                "url": f"https://www.wikidata.org/wiki/{links.get('wikidata')}"}
    entry["size"] = size

    early = []
    if fb:
        for stage, k in (("egg", "egg_mm"), ("hatching", "hatch_mm"),
                         ("flexion", "flexion_mm"), ("transformation", "transformation_mm")):
            if fb.get(k):
                early.append({"stage": stage, "mm": fb[k],
                              "source": "fishbase_eggs" if stage == "egg" else "fishbase_larvae",
                              "ref": (list(fb.get("refs") or {}) or [None])[0]})
    entry["early"] = early
    return entry


# ── the run ─────────────────────────────────────────────────────────────────────────────────────

def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--release", help="release version (default: _data/taxa.json's)")
    ap.add_argument("--taxa", default=str(ROOT / "_data" / "taxa.json"))
    ap.add_argument("--only", help="a file of taxon_keys, one per line")
    ap.add_argument("--limit", type=int, help="only the first N taxa")
    ap.add_argument("--refresh", action="store_true", help="ignore the cache and refetch")
    ap.add_argument("--dry-run", action="store_true", help="write nothing, upload nothing")
    ap.add_argument("--upload", action="store_true",
                    help=f"rsync the folder to {BUCKET}/{PREFIX}/{{release}}/ and stamp `cached`")
    ap.add_argument("--sizes", help="WS-F2b's sizes.json (default: _data/sizes.json if present)")
    ap.add_argument("--out", help="output root (default: .cache/species-media)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    global VERBOSE
    VERBOSE = not args.quiet

    taxa_path = Path(args.taxa)
    if not taxa_path.exists():
        sys.exit(f"no {taxa_path} — run scripts/fetch_release.sh first")
    rec = Record(taxa_path)
    release = args.release or rec.release

    sizes_path = Path(args.sizes) if args.sizes else (ROOT / "_data" / "sizes.json")
    sizes = json.loads(sizes_path.read_text()) if sizes_path.exists() else None
    if sizes:
        log(f"sizes.json: {len(sizes)} taxa")

    out_root = Path(args.out) if args.out else (ROOT / ".cache" / PREFIX)
    out_dir = out_root / release
    cache = Cache(out_dir / "_cache", args.refresh)

    taxa = rec.taxa
    if args.only:
        want = [l.strip() for l in Path(args.only).read_text().splitlines() if l.strip()]
        order = {k: i for i, k in enumerate(want)}
        taxa = sorted((t for t in taxa if t["taxon_key"] in order),
                      key=lambda t: order[t["taxon_key"]])
        missing = set(want) - {t["taxon_key"] for t in taxa}
        if missing:
            log(f"NOTE: not in the record: {sorted(missing)}")
    if args.limit:
        taxa = taxa[:args.limit]
    log(f"release {release} · {len(taxa)} taxa · out {out_dir}")

    # Wikidata prepass: one SPARQL per 100 taxa, P850 for the WoRMS-keyed and P815 for the rest
    wd_all: dict[str, dict] = {}
    for prop, idkey in (("P850", "worms_id"), ("P815", "itis_id")):
        pending = [t for t in taxa
                   if (t.get("ids") or {}).get(idkey)
                   and t["taxon_key"] not in wd_all]
        for i in range(0, len(pending), 100):
            chunk = pending[i:i + 100]
            slugs = [t["slug"] for t in chunk]
            hit = {t["taxon_key"]: cache.get(f"wd_{prop}", t["slug"]) for t in chunk}
            todo = [t for t in chunk if hit[t["taxon_key"]] is None]
            if todo:
                ids = [str((t["ids"])[idkey]) for t in todo]
                try:
                    got = wikidata_batch(ids, prop)
                except Exception as e:
                    log(f"  ! wikidata {prop} batch {i//100}: {type(e).__name__}: {e}")
                    got = {}
                    todo = []                                # do not cache a failed batch
                for t in todo:
                    v = got.get(str((t["ids"])[idkey]))
                    cache.put(f"wd_{prop}", t["slug"], {"v": v})
                    hit[t["taxon_key"]] = {"v": v}
            for k, v in hit.items():
                if v and v.get("v"):
                    wd_all.setdefault(k, v["v"])
            log(f"  wikidata {prop}: {len(slugs)} taxa, {sum(1 for v in hit.values() if v and v.get('v'))} items")

    t0 = time.time()
    entries = {}
    for i, t in enumerate(taxa, 1):
        log(f"[{i}/{len(taxa)}] {t['taxon_key']} {t.get('scientific_name')}")
        try:
            entries[t["taxon_key"]] = do_taxon(t, rec, cache, out_dir, wd_all, sizes, args.dry_run)
        except Exception as e:
            log(f"  ! {t['taxon_key']}: {type(e).__name__}: {e}")
            entries[t["taxon_key"]] = {}
        e = entries[t["taxon_key"]]
        log("    " + " ".join(k for k in ("silhouette", "photo", "drawing", "plate", "size", "text")
                              if e.get(k)))
    elapsed = time.time() - t0

    refs = {}
    for v in (sizes or {}).values():
        refs.update((v.get("fishbase") or {}).get("refs") or {})

    doc = {"schema_version": "1.0", "release": release,
           "fetched": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "policy": {"allow": POLICY_ALLOW, "deny": POLICY_DENY},
           "coverage": {"taxa": len(entries),
                        **{k: sum(1 for e in entries.values() if e.get(k))
                           for k in ("silhouette", "photo", "drawing", "plate", "size", "text")}},
           "taxa": entries, "refs": refs}

    if args.upload and not args.dry_run:
        upload(out_dir, release)
        for slug_entry in entries.values():
            for slot in ("photo", "drawing", "plate"):
                a = slug_entry.get(slot)
                if a and a.get("local"):
                    a["cached"] = a["local"]
    for slug_entry in entries.values():
        for slot in ("photo", "drawing", "plate"):
            if slug_entry.get(slot):
                slug_entry[slot].pop("local", None)

    dest = out_dir / "taxa_media.json"
    if args.dry_run:
        log(f"[dry-run] would write {dest}")
        if args.upload:
            log(f"[dry-run] would run: {' '.join(rsync_cmd(out_dir, release))}")
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(doc, ensure_ascii=False, indent=1))
    print(json.dumps(doc["coverage"]))
    print(f"{len(taxa)} taxa in {elapsed:.0f}s ({elapsed / max(1, len(taxa)):.2f} s/taxon) "
          f"→ {dest}")
    return 0


def rsync_cmd(out_dir, release):
    return ["gcloud", "storage", "rsync", "--recursive", "--exclude", "^_cache/.*",
            str(out_dir), f"{BUCKET}/{PREFIX}/{release}"]


def upload(out_dir, release):
    cmd = rsync_cmd(out_dir, release)
    log("  " + " ".join(cmd))
    subprocess.run(cmd, check=True)


if __name__ == "__main__":
    sys.exit(main())
