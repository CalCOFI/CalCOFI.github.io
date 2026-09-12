#!/usr/bin/env python3
"""fetch_measurement_faces.py — the face of every measurement page, fetched from four public services.

    scripts/fetch_measurement_faces.py [--release v2026.09.11] [--only KEYS|FILE] [--limit N]
                                       [--refresh] [--dry-run] [--upload] [--out DIR]

Walks `_data/measurements.json` (the release's measurements catalog record, fetched by
scripts/fetch_release.sh) and writes, for every measurement KEY, the sidecar
`measurements_media.json` in the shape of the plan's Appendix A (plan
`2026-09-11 Measurement faces …`, § D1, § D2, § D8) plus one standalone SVG per structure, under
`.cache/measurement-media/`.  `--upload` rsyncs `keys/` to
`gs://calcofi-files-public/measurement-media/keys/` and copies the sidecar beside it.

THE MEDIA ARE STORED ONCE, NEVER PER RELEASE.  The structures live at
`measurement-media/keys/{key}/structure.svg` and the sidecar once at
`measurement-media/measurements_media.json`; the sidecar's `release` field records which catalog it
was built against and is THE ONLY PLACE a version appears in the layout.  The species faces shipped
`species-media/{release}/…` and promoting v2026.09.11 on 2026-09-11 silently blanked every species
page, because the site fetches the sidecar at the *promoted* version and the media existed only for
the previous one (fixed in CalCOFI.github.io `6904faa`).  A molecule, a NERC concept and an EOV
outlive a release exactly as a taxon does.  Do not reintroduce a `{release}/` path segment here.

The sources, in the order they are asked:

    NERC NVS   the key ring.  The key's P01 (or, for a stand-in, the P01 of the key whose face it
               borrows) as JSON-LD (`?_profile=nvs&_mediatype=application/ld+json`), then ONE hop
               into each of S27 (the chemical substance), S25 (the biological entity), S06 (the
               measured property), A05 (the EOV), P06 (the unit), P07 (the CF standard name) and
               P02 (the parameter group), keeping each one's preferred label, definition and
               `owl:sameAs` — which is where ChEBI, CAS, WoRMS and QUDT come from.  CC BY 4.0.
    ChEBI      for each ChEBI id: the compound record (name stripped of markup, formula, charge,
               mass, definition, SMILES) and the curated 2D molfile.  CC BY 4.0.
               ChEBI ROLES ARE NEVER STORED: the probe found dioxygen classified an
               "anti-inflammatory drug" and the carbon atom an "antidepressant" (plan Appendix B).
               Nothing in this file reads `roles_classification`, and check_measurement_faces.py
               refuses a sidecar that carries a `roles` key anywhere.
    RDKit      the molfile drawn at fetch time: black-and-white palette mapped to `currentColor`,
               atom labels as paths (never `<text>`), a tight `viewBox` computed from every
               coordinate the paths draw, so a three-atom ion fills its slot like a 65-atom
               molecule.  A molecule ChEBI lays out vertically and that is linear (CO₂) is redrawn
               from its SMILES so it reads horizontally.
    Wikipedia  the lead of each title the record's `why[kind = wikipedia]` rows name (1.1) or the
               probe's curated titles (1.0): two sentences, the revision id, CC BY-SA 4.0.  Plus
               ONE table the world publishes and we only read: the Beaufort force scale, parsed
               from the article's wikitext at a named revision into `tables.beaufort`, in both the
               units the article gives (m/s and knots), for the wind page's strip.
    PyCO2SYS   not a source but a computation, and not a release dependency: for every key whose
               composition rows are the carbonate pool, how that pool splits between CO₂(aq),
               HCO₃⁻ and CO₃²⁻ across pH — at the record's own DIC, alkalinity, temperature and
               salinity medians, with the inputs, the package version and the constants named in
               the `bjerrum` block the page credits (plan § D2, § D8).
    NOAA CPC   the Oceanic Niño Index table → `strong_el_nino` (every year with any 3-month ONI
               ≥ +1.5) and `latest`, for the El Niño shading on the anomaly figures (§ D6).

Accepts `measurements.json` schema 1.0 AND 1.1.  1.1 is the primary path: `face{kind, face_of}`,
`chem[]` and `why[]` come from the record, which is the registries' projection (WS-MF1/MF2/MF3).
Under 1.0 the same three things fall back to the probe's own maps (`FACE_OF`, `COMPOSITION`,
`WIKI_TITLE` below, transcribed from `measurement-faces-probe/build.py`), so the fetcher runs today
against the promoted v2026.09.11 record and switches over with no code change when 1.1 lands.

Resumable: every URI's answer is cached as one small file under
`.cache/measurement-media/_cache/{source}/…`, so a killed run continues where it stopped;
`--refresh` ignores the cache.  A source that fails for one key leaves that slot null, logs one
line and the run continues — but a source that REFUSES the run (403, or 429/503 persisting past the
back-off) stops it, because a sidecar built from a half-answered vocabulary is worse than no
sidecar (plan § Gates).

Python >= 3.11, standard library + RDKit (`requirements-media.txt`).  Never install RDKit into a
system Python: `uv venv --python 3.12 .venv-media && uv pip install --python .venv-media/bin/python
-r requirements-media.txt`, then run this script with `.venv-media/bin/python`.
Nothing here is installed; nothing here is committed.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

try:
    from rdkit import Chem, RDLogger
    from rdkit.Chem import AllChem
    from rdkit.Chem.Draw import rdMolDraw2D
except ImportError:                                                     # pragma: no cover
    sys.exit("RDKit is required.  Do not install it into a system Python — make a venv:\n"
             "  uv venv --python 3.12 .venv-media\n"
             "  uv pip install --python .venv-media/bin/python -r requirements-media.txt\n"
             "  .venv-media/bin/python scripts/fetch_measurement_faces.py")

RDLogger.DisableLog("rdApp.*")

ROOT = Path(__file__).resolve().parent.parent
CONTACT = os.environ.get("CALCOFI_MEDIA_CONTACT", "bdbest@gmail.com")
UA = f"calcofi.io measurement-media/1.0 (https://calcofi.io; {CONTACT})"
BUCKET = "gs://calcofi-files-public"
PREFIX = "measurement-media"
# one copy, never one per release: the structures hang off this version-free prefix and the sidecar
# sits at {PREFIX}/measurements_media.json (see the module docstring for the release that proved why)
ASSETS = f"{PREFIX}/keys"

NVS = "http://vocab.nerc.ac.uk/collection"
NVS_PROFILE = "?_profile=nvs&_mediatype=application/ld%2Bjson"
CHEBI_API = "https://www.ebi.ac.uk/chebi/backend/api/public"
WP_SUMMARY = "https://en.wikipedia.org/api/rest_v1/page/summary/"
WP_API = "https://en.wikipedia.org/w/api.php"
ONI_URL = "https://www.cpc.ncep.noaa.gov/data/indices/oni.ascii.txt"
# the Beaufort scale is published, not ours: the wind page reads its own m/s against the table the
# article states, at the revision recorded beside it (plan § D7, § D8 "the fetcher borrows what the
# world publishes").  `metadata/measurement_scale.csv` carries the same bands as marks, authored
# from the same article but with no revision to go back to; the table here is the citable copy.
BEAUFORT_PAGE = "Beaufort_scale"

NVS_LICENSE = "CC BY 4.0"
CHEBI_LICENSE = "CC BY 4.0"
WP_LICENSE = "CC BY-SA 4.0"

# the collections followed ONE hop out of a P01 (plan § D1, the probe's nvs_probe.py)
HOPS = ("S27", "S25", "S06", "A05", "P06", "P07", "P02")

# a ChEBI id the S27 link reaches that is NOT the thing measured.  DIC's P01 (TCO2MSXX) points at
# S27 CS002894, whose only `sameAs` is CHEBI:27594 — the carbon ATOM.  Dissolved inorganic carbon is
# a pool of three species (CO₂, HCO₃⁻, CO₃²⁻), which is what the registry's composition rows carry,
# so the atom is skipped and listed in the sidecar's `skipped` rather than drawn (plan § Gates: "an
# S27 whose ChEBI is not the thing measured … skip it, list it; the registry decides").
SKIP_CHEBI = {
    "CHEBI:27594": "the carbon atom, not the three-species pool DIC measures "
                   "(the composition rows carry CO₂, HCO₃⁻ and CO₃²⁻)",
}

# ── the carbonate system (plan § D2, § D8) ──────────────────────────────────────────────────────
# A key whose composition rows ARE the three carbonate species gets a Bjerrum plot: how the pool
# splits between CO₂, HCO₃⁻ and CO₃²⁻ across pH, with the record's own medians marked.  The split
# is a computation, not a lookup, and PyCO2SYS is not a release dependency — so it is computed
# HERE, from the four medians the record already publishes, with the package version and the
# constants named in the block (§ D8: the release carries what it computes, the fetcher borrows
# and computes what the world publishes).  The keys are reached by IDENTITY, never by name: the
# P01 of total inorganic carbon, of total alkalinity, of temperature and of practical salinity.
CARBONATE_CHEBI = {"CHEBI:16526", "CHEBI:17544", "CHEBI:41609"}   # CO₂(aq), HCO₃⁻, CO₃²⁻
P01_DIC, P01_ALK = "TCO2MSXX", "MDMAP014"
P01_TEMP, P01_SAL = "TEMPPR01", "PSLTZZ01"
# the curve's domain, in pH units: the range over which a carbonate pool is worth drawing
BJERRUM_PH = (4.0, 11.0, 0.1)
# PyCO2SYS's `opt_k_carbonic = 4` is Lueker, Dickson & Keeling (2000), the constants the probe used
K_CARBONIC_OPT = 4
K_CARBONIC_SRC = "Lueker, Dickson & Keeling (2000) carbonic-acid constants (opt_k_carbonic = 4)"

# ── the schema-1.0 fallbacks, transcribed from measurement-faces-probe/build.py ──────────────────
# Under schema 1.1 all three come from the record (`face`, `chem[]`, `why[kind = wikipedia]`), which
# is `metadata/measurement_{face,chem,why}.csv` projected by build_measurements_catalog().  These
# maps exist ONLY so the fetcher runs against the promoted 1.0 record; the registry always wins.

# whose face a key with no P01 borrows (plan § D3, "stands in"; build.py's STANDS)
FACE_OF = {
    "r_temperature": "temperature", "tsg1_temp_c": "temperature", "sst_c": "temperature",
    "air_temp_c": "temperature",
    "tsg1_salinity_psu": "salinity", "sss_psu": "salinity",
    "isus_v": "nitrate", "est_nitrate_cruise_corr": "nitrate", "est_nitrate_sta_corr": "nitrate",
    "fluorescence_v": "chlorophyll_a", "est_chlorophyll_a_sta_corr": "chlorophyll_a",
    "est_chlorophyll_a_cruise_corr": "chlorophyll_a", "chl_fluor": "chlorophyll_a",
    # the ¹⁴C incubations borrow bicarbonate: the form the ¹⁴C is added as
    "c14_mean": "dic", "c14_dark": "dic", "c14_rep1": "dic", "c14_rep2": "dic",
    "oxygen": "oxygen_umol_kg", "sw_ph": "ph",
}
# a key with no concept that shows its scale alone, and the one that shows nothing (build.py)
SCALE_ONLY = ("r_dynamic_height", "r_salinity_sva", "dynamic_height", "specific_volume_anomaly",
              "transmissometer", "par", "spar", "light_pct", "long_wave_rad", "short_wave_rad",
              "par_surf", "atm_pressure_mb", "wind_dir_deg", "wind_speed_ms", "rel_humidity_pct",
              "bottom_depth_m")
NOTHING = ("uws_flow",)

# the composition and equilibrium rows the S27 chain cannot reach (plan § D2; build.py's `chem`
# lists and the TEOS-10 Table D.3 ion bar).  `mass_fraction` is the Reference-Composition mass
# fraction of sea salt (IOC, SCOR & IAPSO 2010, Table D.3; Millero et al. 2008).
COMPOSITION = {
    "salinity": [
        ("CHEBI:17996", "component", 0.5503396), ("CHEBI:29101", "component", 0.3065958),
        ("CHEBI:16189", "component", 0.0771319), ("CHEBI:18420", "component", 0.0365055),
        ("CHEBI:29108", "component", 0.0117186), ("CHEBI:29103", "component", 0.0113495),
        ("CHEBI:17544", "component", 0.0029805), ("CHEBI:15858", "component", 0.0019134),
    ],
    "dic": [
        ("CHEBI:16526", "component", None),      # dissolved CO₂
        ("CHEBI:17544", "component", None),      # bicarbonate
        ("CHEBI:41609", "component", None),      # carbonate
    ],
    # the key says ammonia; NERC's S27 and the Berthelot method say ammonium.  Both are drawn: the
    # pair is the equilibrium the measurement cannot separate.
    "ammonia": [("CHEBI:16134", "conjugate", None)],
    "r_ammonium": [("CHEBI:16134", "conjugate", None)],
    "btl_ammonium": [("CHEBI:16134", "conjugate", None)],
    # acid strips the magnesium and chlorophyll-a becomes pheophytin-a: the method's own product
    "chlorophyll_a": [("CHEBI:44898", "method_product", None)],
    "btl_chlorophyll_a": [("CHEBI:44898", "method_product", None)],
    # pH counts the hydron; it has no picture worth drawing, but the id belongs in the chain
    "ph": [("CHEBI:15378", "the_thing", None)],
    "sw_ph": [("CHEBI:15378", "the_thing", None)],
}
COMPOSITION_SOURCE = {
    "salinity": ("TEOS-10 Manual (IOC, SCOR & IAPSO 2010) Table D.3, mass fractions of "
                 "Reference-Composition sea salt (Millero et al. 2008)"),
}

# a curated Wikipedia title per key (build.py's `wp` slots; the record's why[kind = wikipedia] rows
# replace this wholesale under 1.1).  A key not named here gets no lead — silence, not a guess.
WIKI_TITLE = {
    "salinity": "Salinity",
    "oxygen_umol_kg": "Ocean_deoxygenation",
    "nitrate": "Upwelling",
    "ammonia": "Ammonium",
    "chlorophyll_a": "Phytoplankton",
    "ph": "Ocean_acidification",
    "dic": "Dissolved_inorganic_carbon",
    "synechococcus": "Synechococcus",
}

# per-host rate limits, requests per second.  NVS is the one the brief pins: ≤ 2 rps with a contact
# User-Agent (it answers a P01 with links in ~15 s, so the limit is courtesy, not throughput).
RATE = {"nvs": 2.0, "chebi": 2.0, "wikipedia": 4.0, "noaa": 1.0}
_last: dict[str, float] = {}
_locks: dict[str, threading.Lock] = {}
_locks_guard = threading.Lock()

VERBOSE = True


def log(*a):
    if VERBOSE:
        print(*a, file=sys.stderr, flush=True)


# ── HTTP ────────────────────────────────────────────────────────────────────────────────────────

class SourceRefused(Exception):
    """A source refused the RUN, not one request: a 403, or a 429/503 that outlasted the back-off.
    The plan's gate — stop and report rather than publish a half-answered vocabulary."""


def _throttle(host_key: str):
    with _locks_guard:
        lock = _locks.setdefault(host_key, threading.Lock())
    with lock:
        gap = 1.0 / RATE.get(host_key, 2.0)
        now = time.monotonic()
        prev = _last.get(host_key)
        if prev is not None and now - prev < gap:
            time.sleep(gap - (now - prev))
        _last[host_key] = time.monotonic()


class HttpError(Exception):
    def __init__(self, code, url):
        super().__init__(f"HTTP {code} {url}")
        self.code = code


def _with_deadline(fn, seconds):
    """Run `fn` in a daemon thread and give up after `seconds`.  urllib's `timeout` bounds each
    socket OPERATION, not the whole request, so a server that accepts the connection and then
    dribbles — which is exactly what NERC's S06 S0600045 does — is never timed out by it: the run
    simply stops.  (scripts/fetch_species_media.py learned the same lesson from a media host on
    2026-09-11.)  The abandoned thread dies with the process."""
    box = {}

    def run():
        try:
            box["v"] = fn()
        except BaseException as e:                    # noqa: BLE001 — re-raised in the caller
            box["e"] = e

    th = threading.Thread(target=run, daemon=True)
    th.start()
    th.join(seconds)
    if th.is_alive():
        raise TimeoutError(f"no answer within {seconds:.0f} s")
    if "e" in box:
        raise box["e"]
    return box["v"]


def http(url, host_key, accept="application/json", timeout=60, tries=4) -> bytes:
    """One request with the contact User-Agent, the host's rate limit and exponential back-off.
    404/410 is a real answer and is raised at once; 403 and a persistent 429/503 raise
    SourceRefused, which ends the run."""
    hdr = {"User-Agent": UA, "Accept": accept}
    last = None
    for attempt in range(tries):
        _throttle(host_key)
        req = urllib.request.Request(url, headers=hdr)

        def once():
            with urllib.request.urlopen(req, timeout=timeout) as r:
                return r.read()

        try:
            return _with_deadline(once, timeout + 5)
        except urllib.error.HTTPError as e:
            last = HttpError(e.code, url)
            if e.code == 403:
                raise SourceRefused(f"{host_key} refused with 403: {url}") from e
            if e.code in (400, 401, 404, 410):        # a real answer: do not retry
                raise last
            if e.code in (429, 503):
                wait = 6.0 * 2 ** attempt
                log(f"    ~ {host_key} {e.code}; backing off {wait:.0f}s")
                time.sleep(wait)
                continue
            time.sleep(1.5 * 2 ** attempt)
        except Exception as e:                        # timeout, DNS, reset
            last = e
            time.sleep(1.5 * 2 ** attempt)
    if isinstance(last, HttpError) and last.code in (429, 503):
        raise SourceRefused(f"{host_key} kept answering {last.code} past the back-off: {url}")
    raise last


def get_json(url, host_key, **kw):
    body = http(url, host_key, **kw)
    if not body.strip():
        return None
    return json.loads(body)


def get_text(url, host_key, **kw):
    return http(url, host_key, accept="text/plain,*/*", **kw).decode("utf-8", "replace")


# ── the cache: one small file per URI ────────────────────────────────────────────────────────────

class Cache:
    """Per-URI, on disk, so a killed run continues where it stopped.  A failure caches nothing."""

    def __init__(self, root: Path, refresh: bool):
        self.root = root
        self.refresh = refresh
        # what THIS run has already refetched.  `--refresh` means "ignore what is on disk", once
        # per URI — not once per use.  The 89 keys share 24 P01s and every chain hops into the same
        # handful of S06 and S26 concepts, so without this a refresh asks NVS for the same concept
        # up to a dozen times: a refresh run was still on key 7 after 20 minutes, where the warm
        # run took 26 s (measured 2026-09-12).
        self.fresh: set[tuple[str, str]] = set()

    def path(self, source: str, name: str, ext="json") -> Path:
        safe = re.sub(r"[^A-Za-z0-9._:-]", "_", name)
        return self.root / source / f"{safe}.{ext}"

    def _stale(self, source, name) -> bool:
        return self.refresh and (source, name) not in self.fresh

    def json(self, source, name, fn):
        p = self.path(source, name)
        if not self._stale(source, name) and p.exists():
            try:
                return json.loads(p.read_text()).get("v")
            except Exception:
                pass
        v = fn()                                      # a SourceRefused propagates: the gate
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(json.dumps({"v": v, "at": stamp()}, ensure_ascii=False))
        self.fresh.add((source, name))
        return v

    def text(self, source, name, fn, ext="txt"):
        p = self.path(source, name, ext)
        if not self._stale(source, name) and p.exists():
            return p.read_text()
        v = fn()
        p.parent.mkdir(parents=True, exist_ok=True)
        p.write_text(v)
        self.fresh.add((source, name))
        return v


def stamp():
    return time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime())


def soft(fn, what):
    """Run fn; on anything but the run-ending gate, log one line and return None."""
    try:
        return fn()
    except SourceRefused:
        raise
    except Exception as e:
        log(f"    ! {what}: {type(e).__name__}: {e}")
        return None


# ── NERC NVS ────────────────────────────────────────────────────────────────────────────────────

def _ids(x):
    if x is None:
        return []
    if isinstance(x, dict):
        x = [x]
    return [i["@id"] if isinstance(i, dict) else i for i in x]


def _val(x):
    if isinstance(x, dict):
        return x.get("@value")
    if isinstance(x, list):
        vals = [v for v in (_val(i) for i in x) if v]
        return "; ".join(str(v) for v in vals) or None
    return x


# NVS concepts that did not answer THIS run.  A failure caches nothing on disk (tomorrow's run must
# ask again), but asking a second time inside one run is pure cost: S06 S0600045 ("Concentration")
# has hung for every run since the plan's probe, and it is a broader of most nutrient, oxygen and
# chlorophyll P01s — so without this set, thirty-odd keys each spend the full timeout budget on it
# (measured 2026-09-12: ~5 minutes PER KEY, against 26 s for all 89 warm).
_nvs_dead: set[str] = set()


def nvs_concept(uri: str, cache: Cache) -> dict | None:
    """One NVS concept as JSON-LD, cached by URI on disk and by failure for the run."""
    key = uri.rstrip("/")
    if key in _nvs_dead:
        raise TimeoutError(f"{key} did not answer earlier this run")
    url = key + "/" + NVS_PROFILE
    try:
        # two tries and 30 s: a concept that is up answers in under 2 s, and one that is down stays
        # down for the run
        d = cache.json("nvs", uri, lambda: get_json(url, "nvs", timeout=30, tries=2))
    except SourceRefused:
        raise
    except Exception:
        _nvs_dead.add(key)
        raise
    return d if isinstance(d, dict) else None


def chebi_from_sameas(same: list[str]) -> str | None:
    for s in same:
        m = re.search(r"CHEBI[_:](\d+)", s or "", re.I)
        if m:
            return f"CHEBI:{m.group(1)}"
    return None


def cas_from_sameas(same: list[str]) -> str | None:
    for s in same:
        m = re.search(r"chemidplus/rn/([\d-]+)", s or "")
        if m:
            return m.group(1)
    return None


def worms_from_sameas(same: list[str]) -> int | None:
    for s in same:
        m = re.search(r"taxname[:/](\d+)", s or "")
        if m:
            return int(m.group(1))
    return None


def nvs_chain(p01_uri: str, cache: Cache) -> dict | None:
    """The key ring: the P01 and one hop into each of HOPS."""
    d = nvs_concept(p01_uri, cache)
    if not d:
        return None
    code = p01_uri.rstrip("/").rsplit("/", 1)[-1]
    out = {"p01": code, "uri": p01_uri.rstrip("/") + "/",
           "pref": _val(d.get("skos:prefLabel")), "alt": _val(d.get("skos:altLabel")),
           "definition": _val(d.get("skos:definition")), "license": NVS_LICENSE}
    for link in _ids(d.get("skos:broader")) + _ids(d.get("skos:related")):
        if "/collection/" not in link:
            continue
        coll = link.split("/collection/")[1].split("/")[0]
        if coll not in HOPS or coll.lower() in out:
            continue
        dd = soft(lambda link=link: nvs_concept(link, cache), f"nvs {link}")
        if not dd:
            continue
        same = _ids(dd.get("owl:sameAs"))
        node = {"id": link.rstrip("/").rsplit("/", 1)[-1], "uri": link.rstrip("/") + "/",
                "pref": _val(dd.get("skos:prefLabel")),
                "definition": _val(dd.get("skos:definition")),
                "same_as": same}
        if coll == "S27":
            node["chebi"] = chebi_from_sameas(same)
            node["cas"] = cas_from_sameas(same)
        if coll == "S25":
            node["worms"] = worms_from_sameas(same)
        out[coll.lower()] = node
    return out


# ── ChEBI ───────────────────────────────────────────────────────────────────────────────────────

def chebi_compound(chebi: str, cache: Cache) -> dict | None:
    """The compound record, whitelisted field by field.  `roles_classification` is never read:
    ChEBI's roles are nonsense for a measurement (dioxygen "anti-inflammatory drug")."""
    num = chebi.split(":")[1]
    d = cache.json("chebi", chebi,
                   lambda: get_json(f"{CHEBI_API}/compound/CHEBI:{num}/", "chebi"))
    if not isinstance(d, dict):
        return None
    s = d.get("default_structure") or {}
    c = d.get("chemical_data") or {}
    strip = lambda t: re.sub(r"<[^>]+>", "", t) if isinstance(t, str) else t
    return {"chebi": chebi, "name": strip(d.get("name")), "definition": strip(d.get("definition")),
            "formula": c.get("formula"), "charge": c.get("charge"), "mass": c.get("mass"),
            "smiles": s.get("smiles"), "inchikey": s.get("standard_inchi_key"),
            "license": CHEBI_LICENSE,
            "url": f"https://www.ebi.ac.uk/chebi/searchId.do?chebiId={chebi}"}


def chebi_molfile(chebi: str, cache: Cache) -> str | None:
    num = chebi.split(":")[1]
    txt = cache.text("molfile", chebi,
                     lambda: get_text(f"{CHEBI_API}/molfile/{num}/", "chebi"), ext="mol")
    # the endpoint answers either a bare molfile or a JSON envelope carrying one
    if txt.lstrip().startswith("{"):
        try:
            txt = json.loads(txt).get("molfile") or ""
        except Exception:
            return None
    return txt if "V2000" in txt or "V3000" in txt else None


# ── RDKit: the drawing (plan § D1) ──────────────────────────────────────────────────────────────

DRAWN_BY = f"RDKit {Chem.rdBase.rdkitVersion} from the ChEBI molfile"
DRAWN_BY_SMILES = f"RDKit {Chem.rdBase.rdkitVersion} from the ChEBI SMILES (the molfile is vertical)"


def _draw(mol, big: bool, padding: float) -> str:
    """The probe's own options (measurement-faces-probe/draw2.py): the black-and-white palette so
    every atom is one ink, then #000000 → currentColor so the page's own colour draws it, and
    clearBackground off so nothing paints behind it.  Atom labels come out as <path>, never
    <text>, which is what "text as paths" means here."""
    w, h = (600, 440) if big else (220, 180)
    d = rdMolDraw2D.MolDraw2DSVG(w, h)
    o = d.drawOptions()
    o.useBWAtomPalette()
    o.clearBackground = False
    o.bondLineWidth = 1.5 if big else 2.2
    o.padding = padding
    o.minFontSize = 12 if big else 16
    o.maxFontSize = 26
    o.addStereoAnnotation = False
    d.DrawMolecule(mol)
    d.FinishDrawing()
    t = d.GetDrawingText()
    return (re.sub(r"<\?xml[^>]*\?>\s*", "", t)
            .replace("#000000", "currentColor").replace("#FFFFFF", "none"))


def _tight(rdkit_svg: str) -> tuple[str, str]:
    """The inner markup and a viewBox taken from every coordinate the paths draw, so a small ion
    fills its slot like a big molecule (build.py's svg())."""
    inner = rdkit_svg.split("<!-- END OF HEADER -->", 1)[1].rsplit("</svg>", 1)[0]
    inner = re.sub(r"<rect[^>]*fill:none[^>]*>\s*</rect>", "", inner)
    inner = re.sub(r"\s+", " ", inner).strip()
    xs, ys = [], []
    for d in re.findall(r"d='([^']+)'", inner):
        nums = [float(n) for n in re.findall(r"-?\d+(?:\.\d+)?", d)]
        xs += nums[0::2]
        ys += nums[1::2]
    if not xs:
        raise ValueError("the drawing has no path coordinates")
    pad = 6
    vb = (f"{min(xs) - pad:.1f} {min(ys) - pad:.1f} "
          f"{max(xs) - min(xs) + 2 * pad:.1f} {max(ys) - min(ys) + 2 * pad:.1f}")
    return inner, vb


def draw_structure(molblock: str | None, smiles: str | None) -> dict | None:
    """molfile → RDKit → currentColor → tight viewBox.  A LINEAR molecule ChEBI lays out
    vertically (CO₂, whose molfile stands the O=C=O on end) is redrawn from its SMILES so it reads
    horizontally; the redraw uses padding 0.05, which is what the probe's own CO₂ redraw used and
    what reproduces `measurement-faces-probe/svg/carbon_dioxide.svg` exactly."""
    mol = Chem.MolFromMolBlock(molblock, sanitize=False, removeHs=False) if molblock else None
    if mol is not None:
        try:
            Chem.SanitizeMol(mol)
        except Exception:
            mol.UpdatePropertyCache(strict=False)
    if mol is None and smiles:
        mol = Chem.MolFromSmiles(smiles)
        if mol is None:
            return None
        AllChem.Compute2DCoords(mol)
        inner, vb = _tight(_draw(mol, mol.GetNumHeavyAtoms() > 20, 0.05))
        return {"inner": inner, "viewBox": vb, "drawn_by": DRAWN_BY_SMILES}
    if mol is None:
        return None
    heavy = mol.GetNumHeavyAtoms()
    if mol.GetNumAtoms() <= 1:
        # a MONATOMIC ion (Na⁺, Cl⁻, Mg²⁺, the hydron) has no structure to draw: the drawing would
        # be the formula again, in a worse font.  The chem row still carries its name, formula,
        # charge, mass and mass fraction, which is what salinity's ion bar is made of (§ D2), and
        # it is what the probe drew too — its svg/ holds sulfate and hydrogencarbonate and none of
        # the six monatomic ions of the Reference Composition.  The test is atoms, not HEAVY atoms:
        # ammonium's molfile is one nitrogen and four explicit hydrogens, and NH₄⁺ is a picture.
        return None
    inner, vb = _tight(_draw(mol, heavy > 20, 0.06))
    w, h = (float(x) for x in vb.split()[2:])
    if heavy <= 4 and h > w and smiles:
        # linear and drawn on end: redraw it lying down
        m2 = Chem.MolFromSmiles(smiles)
        if m2 is not None:
            AllChem.Compute2DCoords(m2)
            inner, vb = _tight(_draw(m2, m2.GetNumHeavyAtoms() > 20, 0.05))
            return {"inner": inner, "viewBox": vb, "drawn_by": DRAWN_BY_SMILES}
    return {"inner": inner, "viewBox": vb, "drawn_by": DRAWN_BY}


def standalone_svg(st: dict, label: str) -> str:
    """One file per structure: no width or height, so the page sizes it; `currentColor` throughout,
    so it takes the page's ink in either theme."""
    safe = (str(label).replace("&", "&amp;").replace("<", "&lt;")
            .replace(">", "&gt;").replace("'", "&apos;"))
    return (f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='{st['viewBox']}' "
            f"fill='none' role='img' aria-label='{safe}'>\n{st['inner']}\n</svg>\n")


# ── Wikipedia and the ONI ───────────────────────────────────────────────────────────────────────

def wikipedia_lead(title: str, cache: Cache) -> dict | None:
    d = cache.json("wikipedia", title,
                   lambda: get_json(WP_SUMMARY + urllib.parse.quote(title), "wikipedia"))
    if not isinstance(d, dict) or not d.get("extract"):
        return None
    rev = d.get("revision")
    if not rev:
        return None                                   # a lead without a revision cannot be cited
    sentences = re.split(r"(?<=\.)\s", d["extract"])
    page = (d.get("content_urls") or {}).get("desktop", {}).get("page")
    return {"title": d.get("title") or title, "revision": int(rev), "license": WP_LICENSE,
            "extract": " ".join(sentences[:2]),
            "url": f"{page}?oldid={rev}" if page else None,
            "timestamp": d.get("timestamp")}


def oni(cache: Cache) -> dict | None:
    """NOAA CPC's Oceanic Niño Index: every year with any 3-month ONI ≥ +1.5, and the latest
    season (the El Niño shading on the anomaly figures, plan § D6)."""
    txt = soft(lambda: cache.text("oni", "oni.ascii", lambda: get_text(ONI_URL, "noaa")), "oni")
    if not txt:
        return None
    rows = [l.split() for l in txt.splitlines()[1:] if l.strip()]
    rows = [r for r in rows if len(r) == 4]
    mx: dict[int, float] = {}
    for seas, yr, _total, anom in rows:
        try:
            y, a = int(yr), float(anom)
        except ValueError:
            continue
        mx[y] = max(mx.get(y, -9.0), a)
    last = rows[-1]
    return {"source": ONI_URL, "license": "Public domain (US Government work)",
            "threshold": 1.5, "fetched": stamp(),
            "strong_el_nino": [y for y in sorted(mx) if mx[y] >= 1.5],
            "latest": [last[0], int(last[1]), float(last[3])]}


# ── the Beaufort scale, as Wikipedia states it (plan § D7) ──────────────────────────────────────

_WIKI_LINK = re.compile(r"\[\[(?:[^\]|]*\|)?([^\]|]*)\]\]")
_WIKI_REF = re.compile(r"<ref[^>]*/>|<ref[^>]*>.*?</ref>", re.S)
# "1–3", "0–0.2", "< 1", "≥ 32.7" — a band as the article writes it, either unit
_BAND = re.compile(r"(?:(?P<lo>\d+(?:\.\d+)?)\s*[–—-]\s*(?P<hi>\d+(?:\.\d+)?)"
                   r"|(?P<op><|≥|>|≤)\s*(?P<v>\d+(?:\.\d+)?))")


def _wikitext(s: str) -> str:
    s = _WIKI_LINK.sub(r"\1", _WIKI_REF.sub("", s)).replace("&nbsp;", " ")
    # a description wraps in the article's cell ("Moderate gale,<br />near gale"); on one line of a
    # strip it is one phrase
    return re.sub(r"\s+", " ", re.sub(r"<br\s*/?>", " ", s)).strip(" |")


def _band(cell: str, unit: str) -> tuple[float | None, float | None]:
    """The (lo, hi) of the `unit` segment of a wind-speed cell.  An open band keeps its None: the
    article says "≥ 32.7 m/s", and inventing a top would be inventing a number."""
    for seg in re.split(r"<br\s*/?>", cell):
        if unit not in seg:
            continue
        m = _BAND.search(_wikitext(seg))
        if not m:
            return (None, None)
        if m.group("lo") is not None:
            return (float(m.group("lo")), float(m.group("hi")))
        v, op = float(m.group("v")), m.group("op")
        return (0.0, v) if op in ("<", "≤") else (v, None)
    return (None, None)


def beaufort(cache: Cache) -> dict | None:
    """The Beaufort force table from the English Wikipedia article, at a named revision: force,
    its description, and the band in BOTH the units the article gives — m/s and knots.  The METS
    wind series is declared m/s and reads high for it, which is an open question on the dataset
    (`metadata/calcofi/mets/questions.csv`), so the page shows the force under each reading rather
    than deciding which one the numbers are.  CC BY-SA 4.0."""
    url = (f"{WP_API}?action=parse&page={BEAUFORT_PAGE}&prop=wikitext%7Crevid"
           "&format=json&formatversion=2")
    d = soft(lambda: cache.json("wikipedia", f"parse_{BEAUFORT_PAGE}",
                                lambda: get_json(url, "wikipedia")), "beaufort")
    if not isinstance(d, dict):
        return None
    parse = d.get("parse") or {}
    rev, text = parse.get("revid"), (parse.get("wikitext") or "")
    if not rev or not text:
        return None
    lines = text.splitlines()
    rows, knots = [], []
    for i, line in enumerate(lines):
        m = re.search(r'id="Beaufort_Number_(\d+)"\s*\|\s*(\d+)', line)
        if not m:
            continue
        cells = [l for l in lines[i + 1:i + 4] if l.startswith("|")]
        if len(cells) < 2:
            continue
        force, label, speed = int(m.group(2)), _wikitext(cells[0]), cells[1]
        lo, hi = _band(speed, "m/s")
        klo, khi = _band(speed, "knot")
        if lo is None:
            continue
        rows.append([force, lo, hi, label])
        knots.append([force, klo, khi])
    if len(rows) < 2 or [r[0] for r in rows] != sorted(r[0] for r in rows):
        log(f"    ! beaufort: parsed {len(rows)} rows out of the table — not using them")
        return None
    return {"source": f"Wikipedia: {BEAUFORT_PAGE.replace('_', ' ')}", "revision": int(rev),
            "license": WP_LICENSE,
            "url": f"https://en.wikipedia.org/wiki/{BEAUFORT_PAGE}?oldid={rev}",
            "units": "m s-1", "rows": rows, "knots": knots}


# ── the carbonate system: PyCO2SYS at the record's own medians (plan § D2) ───────────────────────

def bjerrum(key: str, rec: "Record") -> dict | None:
    """How a pool of dissolved inorganic carbon splits between CO₂(aq), HCO₃⁻ and CO₃²⁻ across pH,
    at the temperature and salinity the record itself measures, with the record's own DIC and
    alkalinity medians marked on it.

    Every input is a p50 the record publishes (`series[].observed.p50`) — nothing here is typed —
    and every input, with the package and the constants that turned it into a curve, is named in
    the block the page credits.  Returns None unless all four medians and PyCO2SYS are present."""
    try:
        import PyCO2SYS as pyco2
    except ImportError:
        log("    ! bjerrum: PyCO2SYS is not installed in this venv "
            "(uv pip install --python .venv-media/bin/python -r requirements-media.txt)")
        return None

    ds = rec.dataset_of(key)
    ins = {}
    for name, p01 in (("dic", P01_DIC), ("alkalinity", P01_ALK),
                      ("temperature", P01_TEMP), ("salinity", P01_SAL)):
        got = rec.median(p01, prefer_dataset=ds)
        if got is None:
            log(f"    ! bjerrum: the record carries no median for {name} ({p01})")
            return None
        ins[name] = got

    dic, alk = ins["dic"]["p50"], ins["alkalinity"]["p50"]
    t, sp = ins["temperature"]["p50"], ins["salinity"]["p50"]
    lo, hi, step = BJERRUM_PH
    grid = [round(lo + i * step, 1) for i in range(int(round((hi - lo) / step)) + 1)]

    def sys(**kw):
        return pyco2.sys(salinity=sp, temperature=t, pressure=0,
                         opt_k_carbonic=K_CARBONIC_OPT, **kw)

    # the point: DIC + alkalinity, the two the record measures
    at = sys(par1=dic, par1_type=2, par2=alk, par2_type=1)
    # the curve: the same DIC held against every pH on the grid, so the three shares are the
    # equilibrium's own and not a fit
    cv = sys(par1=[dic] * len(grid), par1_type=2, par2=grid, par2_type=3)

    def f(x):
        return float(x[0] if hasattr(x, "__len__") and not isinstance(x, str) else x)

    curve = []
    for i, ph in enumerate(grid):
        tot = float(cv["CO2"][i]) + float(cv["HCO3"][i]) + float(cv["CO3"][i])
        if tot <= 0:
            return None
        curve.append([ph, round(float(cv["CO2"][i]) / tot, 4),
                      round(float(cv["HCO3"][i]) / tot, 4), round(float(cv["CO3"][i]) / tot, 4)])

    co2, hco3, co3 = f(at["CO2"]), f(at["HCO3"]), f(at["CO3"])
    tot = co2 + hco3 + co3
    src = (f"PyCO2SYS {pyco2.__version__} · {K_CARBONIC_SRC}, at the record's own series medians: "
           f"DIC {dic} and alkalinity {alk} µmol/kg, {t} °C, practical salinity {sp}")
    return {
        "pH": round(f(at["pH"]), 3),
        "co2": round(co2 / tot * 100, 2), "hco3": round(hco3 / tot * 100, 1),
        "co3": round(co3 / tot * 100, 1),
        "omega_arag": round(f(at["saturation_aragonite"]), 2),
        "pco2": round(f(at["pCO2"]), 1),
        "curve": curve,
        "inputs": {k: {"key": v["key"], "dataset_key": v["dataset_key"],
                       "measurement_type": v["measurement_type"], "p50": v["p50"],
                       "units": v["units"], "n_values": v["n_values"]} for k, v in ins.items()},
        "inputs_note": "every value is the record's own observed p50 over the whole series, "
                       "at surface pressure",
        "versions": {"PyCO2SYS": pyco2.__version__, "constants": K_CARBONIC_SRC},
        # the record's own PyCO2SYS marks were typed from the plan's probe (`computed_at_build`
        # false).  These are the same quantities recomputed from the medians above, and the page
        # shows THESE in their place (plan § D7, "computed marks … are recomputed at build").
        "marks": [
            {"value": round(f(at["saturation_aragonite"]), 2),
             "label": "aragonite saturation Ω at the record's medians", "kind": "computed"},
            {"value": round(co2 / tot * 100, 2), "label": "CO₂(aq) share of the pool, %",
             "kind": "computed"},
            {"value": round(hco3 / tot * 100, 1), "label": "HCO₃⁻ share of the pool, %",
             "kind": "computed"},
            {"value": round(co3 / tot * 100, 1), "label": "CO₃²⁻ share of the pool, %",
             "kind": "computed"},
        ],
        "src": src,
    }


# ── the record: 1.1 first, 1.0's fallbacks second ───────────────────────────────────────────────

class Record:
    def __init__(self, path: Path):
        self.doc = json.loads(path.read_text())
        self.schema = str(self.doc.get("schema_version"))
        self.release = (self.doc.get("release") or {}).get("version")
        self.measurements = self.doc.get("measurements") or []
        self.by_key = {m["key"]: m for m in self.measurements}

    @property
    def is_11(self) -> bool:
        return self.schema.split(".")[:2] >= ["1", "1"]

    def p01_uri(self, key: str) -> str | None:
        m = self.by_key.get(key) or {}
        u = m.get("nerc_p01")
        return u or None

    @staticmethod
    def _p01_id(uri: str | None) -> str | None:
        return uri.rstrip("/").rsplit("/", 1)[-1] if uri else None

    def dataset_of(self, key: str) -> str | None:
        """The dataset the key's canonical series comes from."""
        ser = (self.by_key.get(key) or {}).get("series") or []
        canon = next((s for s in ser if s.get("is_canonical")), ser[0] if ser else None)
        return (canon or {}).get("dataset_key")

    def median(self, p01_id: str, prefer_dataset: str | None = None) -> dict | None:
        """The record's own median (`observed.p50`) of the quantity a P01 identifies — the same
        dataset as the asking key where that dataset measures it, else the canonical series.
        Reached by IDENTITY: a key's name never decides which median it gets."""
        cands = []
        for m in self.measurements:
            if self._p01_id(m.get("nerc_p01")) != p01_id:
                continue
            for s in (m.get("series") or []):
                p50 = ((s.get("observed") or {}).get("p50"))
                if p50 is None:
                    continue
                cands.append({"key": m["key"], "dataset_key": s.get("dataset_key"),
                              "measurement_type": s.get("measurement_type"), "p50": p50,
                              "units": m.get("units"), "n_values": s.get("n_values"),
                              "canonical": bool(s.get("is_canonical"))})
        if not cands:
            return None
        same = [c for c in cands if c["dataset_key"] == prefer_dataset]
        pool = same or cands
        return (next((c for c in pool if c["canonical"]), None)
                or max(pool, key=lambda c: c["n_values"] or 0))

    def is_carbonate(self, key: str) -> bool:
        """A key whose composition rows ARE the carbonate pool (plan § D2)."""
        rows = {r.get("chebi") for r in ((self.by_key.get(key) or {}).get("chem") or [])}
        return CARBONATE_CHEBI <= rows

    def face(self, key: str) -> dict:
        """{kind, face_of, source}.  The record's own `face` block under 1.1; under 1.0 the probe's
        FACE_OF map plus what the chain can reach."""
        m = self.by_key.get(key) or {}
        f = m.get("face")
        if isinstance(f, dict) and f.get("kind"):
            return {"kind": f.get("kind"), "face_of": f.get("face_of"), "source": "record"}
        if key in FACE_OF:
            return {"kind": "standsin", "face_of": FACE_OF[key], "source": "probe_map"}
        if key in NOTHING:
            return {"kind": "none", "face_of": None, "source": "probe_map"}
        if key in ("salinity", "dic"):
            return {"kind": "composition", "face_of": None, "source": "probe_map"}
        if key in SCALE_ONLY:
            return {"kind": "scale", "face_of": None, "source": "probe_map"}
        return {"kind": None, "face_of": None, "source": "chain"}     # decided by the chain below

    def chem(self, key: str) -> list[dict] | None:
        """The record's `chem[]` under 1.1; under 1.0 the probe's COMPOSITION rows, which the S27
        chain cannot reach.  Returns None when neither has anything to say."""
        m = self.by_key.get(key) or {}
        rows = m.get("chem")
        if isinstance(rows, list) and rows:
            return [{"chebi": r.get("chebi"), "role": r.get("role") or "component",
                     "via": r.get("via") or "registry", "mass_fraction": r.get("mass_fraction"),
                     "source": r.get("source") or "record"} for r in rows if r.get("chebi")]
        rows = COMPOSITION.get(key)
        if rows:
            return [{"chebi": c, "role": role, "via": "registry", "mass_fraction": mf,
                     "source": COMPOSITION_SOURCE.get(key, "measurement-faces-probe/build.py")}
                    for c, role, mf in rows]
        return None

    def wiki_titles(self, key: str) -> list[str]:
        """The titles named by why[kind = wikipedia] under 1.1; the probe's curated title under
        1.0.  A key named by neither gets no lead."""
        m = self.by_key.get(key) or {}
        out = []
        for w in (m.get("why") or []):
            if (w.get("kind") or "") != "wikipedia":
                continue
            t = w.get("title")
            if not t and w.get("source_url"):
                t = urllib.parse.unquote(w["source_url"].rstrip("/").rsplit("/", 1)[-1])
                t = t.split("?")[0]
            if t:
                out.append(t)
        if out:
            return out
        t = WIKI_TITLE.get(key)
        return [t] if t else []


# ── one key ─────────────────────────────────────────────────────────────────────────────────────

def do_key(key: str, rec: Record, cache: Cache, out_dir: Path, dry_run: bool,
           skipped: list) -> dict:
    entry: dict = {}
    face = rec.face(key)

    # the chain hangs off the key's own P01, or — for a stand-in — off the P01 of the key whose
    # face it borrows.  A stand-in shows NO borrowed ids on its page (plan § D3): they are recorded
    # here under `borrowed_from` so the page can say whose face it is, never as the key's own.
    own = rec.p01_uri(key)
    lent_by = None if own else (face.get("face_of") or None)
    uri = own or (rec.p01_uri(lent_by) if lent_by else None)
    chain = soft(lambda: nvs_chain(uri, cache), f"nvs chain {key}") if uri else None
    if chain:
        if lent_by:
            # a BORROWED chain never lands under `nerc`.  The ids belong to the key whose face this
            # one stands in for, and the page must not print them in this key's ids row (§ D3) — so
            # they sit under their own name, which a template cannot reach by accident.
            entry["nerc_borrowed"] = dict(chain, borrowed_from=lent_by)
        else:
            entry["nerc"] = chain

    if not face.get("kind"):
        if chain and chain.get("s27", {}).get("chebi"):
            face["kind"] = "structure"
        elif chain and chain.get("s25", {}).get("worms"):
            face["kind"] = "organism"
        elif chain and chain.get("s06"):
            face["kind"] = "scale"
        else:
            face["kind"] = "none"
    entry["face"] = face

    # what to draw: the S27's ChEBI (the thing measured) then the registry's composition rows.
    # A stand-in draws the face it borrows, which is that key's chain and composition.
    rows: list[dict] = []
    s27 = (chain or {}).get("s27") or {}
    if s27.get("chebi"):
        rows.append({"chebi": s27["chebi"], "role": "the_thing", "via": "nerc_s27",
                     "mass_fraction": None, "source": f"NVS S27 {s27.get('id')} owl:sameAs"})
    chem_rows = rec.chem(key) or (rec.chem(lent_by) if lent_by else None) or []
    for r in chem_rows:
        if r["chebi"] not in {x["chebi"] for x in rows}:
            rows.append(r)

    # this key's folder is rebuilt from scratch, so a structure a previous run drew and this one no
    # longer claims cannot linger under a name the sidecar has stopped pointing at.  (The bucket is
    # rsynced without deletes, on purpose — see rsync_cmd — so only the local copy is pruned.)
    if not dry_run and (out_dir / "keys" / key).exists():
        for old in (out_dir / "keys" / key).glob("*.svg"):
            old.unlink()

    structures = []
    if face["kind"] not in ("organism",):
        for r in rows:
            if r["chebi"] in SKIP_CHEBI:
                skipped.append({"key": key, "chebi": r["chebi"], "via": r["via"],
                                "why": SKIP_CHEBI[r["chebi"]]})
                continue
            cmp_ = soft(lambda r=r: chebi_compound(r["chebi"], cache), f"chebi {r['chebi']}")
            if not cmp_:
                continue
            st = None
            if face["kind"] != "scale":
                mb = soft(lambda r=r: chebi_molfile(r["chebi"], cache), f"molfile {r['chebi']}")
                st = soft(lambda: draw_structure(mb, cmp_.get("smiles")),
                          f"draw {key} {r['chebi']}")
            item = {k: cmp_[k] for k in ("chebi", "name", "formula", "charge", "mass",
                                         "definition", "license", "url")}
            item.update(role=r["role"], via=r["via"], mass_fraction=r.get("mass_fraction"),
                        source=r.get("source"))
            if st:
                # `structure.svg` is the first DRAWN structure, not the first row: a composition
                # whose leading rows are monatomic ions (salinity: chloride, then sodium) would
                # otherwise leave the key with no structure.svg at all
                first = not any(s.get("svg_inner") for s in structures)
                fname = "structure.svg" if first else f"{r['chebi'].replace(':', '_')}.svg"
                rel = f"keys/{key}/{fname}"
                item.update(viewBox=st["viewBox"], svg_inner=st["inner"],
                            drawn_by=st["drawn_by"], path=rel)
                if not dry_run:
                    p = out_dir / rel
                    p.parent.mkdir(parents=True, exist_ok=True)
                    p.write_text(standalone_svg(st, item["name"] or r["chebi"]))
            structures.append(item)
    if structures:
        entry["structures"] = structures

    leads = []
    for t in (rec.wiki_titles(key) or (rec.wiki_titles(lent_by) if lent_by else [])):
        w = soft(lambda t=t: wikipedia_lead(t, cache), f"wikipedia {t}")
        if w:
            leads.append(w)
    if leads:
        entry["wikipedia"] = leads

    # the carbonate pool's split by pH, computed here because PyCO2SYS is not a release dependency
    if rec.is_carbonate(key):
        b = soft(lambda: bjerrum(key, rec), f"bjerrum {key}")
        if b:
            entry["bjerrum"] = b
    return entry


# ── the run ─────────────────────────────────────────────────────────────────────────────────────

def rsync_cmd(out_dir: Path, dry_run=False):
    """The upload.  rsync never deletes (no --delete-unmatched-destination-objects): a structure an
    earlier sidecar still references stays where the pages that reference it expect it.  Only
    `keys/` is rsynced — the working cache lives beside it and never reaches the bucket — and the
    sidecar is copied separately, because it belongs BESIDE this prefix, not inside it."""
    return (["gcloud", "storage", "rsync", "--recursive"]
            + (["--dry-run"] if dry_run else [])
            + ["--exclude", r"(^|/)_cache/.*",
               str(out_dir / "keys"), f"{BUCKET}/{ASSETS}"])


def upload(out_dir: Path, dry_run=False):
    cmd = rsync_cmd(out_dir, dry_run)
    log("  " + " ".join(cmd))
    subprocess.run(cmd, check=True)


def main(argv=None):
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--record", default=str(ROOT / "_data" / "measurements.json"),
                    help="the measurements catalog record (schema 1.0 or 1.1)")
    ap.add_argument("--release", help="release version (default: the record's)")
    ap.add_argument("--only", help="measurement keys: a comma-separated list, or a file of keys")
    ap.add_argument("--limit", type=int, help="only the first N keys")
    ap.add_argument("--refresh", action="store_true", help="ignore the cache and refetch")
    ap.add_argument("--dry-run", action="store_true", help="write nothing, upload nothing")
    ap.add_argument("--upload", action="store_true",
                    help=f"rsync keys/ to {BUCKET}/{ASSETS}/ and copy the sidecar beside it")
    ap.add_argument("--out", help="output root (default: .cache/measurement-media)")
    ap.add_argument("--data", help="where to drop a local copy of the sidecar "
                                   "(default: _data/measurements_media.json; '' to skip)")
    ap.add_argument("--quiet", action="store_true")
    args = ap.parse_args(argv)

    global VERBOSE
    VERBOSE = not args.quiet

    record_path = Path(args.record)
    if not record_path.exists():
        sys.exit(f"no {record_path} — run scripts/fetch_release.sh first")
    rec = Record(record_path)
    release = args.release or rec.release
    if not rec.schema.startswith(("1.0", "1.1")):
        sys.exit(f"measurements.json schema {rec.schema} is neither 1.0 nor 1.1 — stopping "
                 f"rather than guessing at its shape")

    out_dir = Path(args.out) if args.out else (ROOT / ".cache" / PREFIX)
    cache = Cache(out_dir / "_cache", args.refresh)

    keys = [m["key"] for m in rec.measurements]
    if args.only:
        p = Path(args.only)
        want = ([l.strip() for l in p.read_text().splitlines() if l.strip()] if p.exists()
                else [k.strip() for k in args.only.split(",") if k.strip()])
        order = {k: i for i, k in enumerate(want)}
        keys = sorted((k for k in keys if k in order), key=lambda k: order[k])
        missing = set(want) - set(keys)
        if missing:
            log(f"NOTE: not in the record: {sorted(missing)}")
    if args.limit:
        keys = keys[:args.limit]

    log(f"record schema {rec.schema} · release {release} · {len(keys)} keys · out {out_dir}")
    if not rec.is_11:
        log("NOTE: schema 1.0 — face_of, the composition rows and the Wikipedia titles come from "
            "the probe's maps; schema 1.1 replaces all three with the registries")

    t0 = time.time()
    entries: dict[str, dict] = {}
    skipped: list[dict] = []
    try:
        for i, key in enumerate(keys, 1):
            log(f"[{i}/{len(keys)}] {key}")
            entries[key] = do_key(key, rec, cache, out_dir, args.dry_run, skipped)
            e = entries[key]
            log("    " + (e.get("face", {}).get("kind") or "?")
                + f" · nerc {'y' if e.get('nerc') else '-'}"
                + f" · structures {len(e.get('structures') or [])}"
                + f" · leads {len(e.get('wikipedia') or [])}"
                + (" · bjerrum" if e.get("bjerrum") else ""))
    except SourceRefused as e:
        print(f"\nSTOP — {e}\n"
              f"Nothing was written.  {len(entries)} of {len(keys)} keys had been walked; the "
              f"cache under {cache.root} keeps them, so a rerun resumes.", file=sys.stderr)
        return 2
    elapsed = time.time() - t0

    index = oni(cache)
    tables = {k: v for k, v in (("beaufort", beaufort(cache)),) if v}

    def n(pred):
        return sum(1 for e in entries.values() if pred(e))

    doc = {
        "schema_version": "1.0",
        "release": release,
        "source_record_schema": rec.schema,
        "fetched": stamp(),
        "sources": {
            "nerc": {"base": f"{NVS}/P01/current/", "license": NVS_LICENSE},
            "chebi": {"base": f"{CHEBI_API}/compound/", "license": CHEBI_LICENSE,
                      "note": "structures and captions only; ChEBI roles are never stored"},
            "rdkit": {"version": Chem.rdBase.rdkitVersion},
            "wikipedia": {"base": WP_SUMMARY, "license": WP_LICENSE},
        },
        "oni": index,
        # the tables a page reads that belong to no single key (plan § D7)
        "tables": tables,
        "coverage": {
            "keys": len(entries),
            "nerc": n(lambda e: e.get("nerc")),
            "nerc_borrowed": n(lambda e: e.get("nerc_borrowed")),
            "chebi": n(lambda e: e.get("structures")),
            "structures": sum(len([s for s in (e.get("structures") or []) if s.get("svg_inner")])
                              for e in entries.values()),
            "keys_with_structure": n(lambda e: any(s.get("svg_inner")
                                                   for s in (e.get("structures") or []))),
            "leads": n(lambda e: e.get("wikipedia")),
            "standsin": n(lambda e: (e.get("face") or {}).get("face_of")),
            "bjerrum": n(lambda e: e.get("bjerrum")),
            "tables": sorted(tables),
        },
        "skipped": skipped,
        "measurements": entries,
    }

    dest = out_dir / "measurements_media.json"
    if args.dry_run:
        log(f"[dry-run] would write {dest}")
        if args.upload:
            upload(out_dir, dry_run=True)             # gcloud's own "Would copy …" listing
    else:
        dest.parent.mkdir(parents=True, exist_ok=True)
        dest.write_text(json.dumps(doc, ensure_ascii=False, indent=1))
        data_dest = ROOT / "_data" / "measurements_media.json" if args.data is None else (
            Path(args.data) if args.data else None)
        if data_dest:
            data_dest.parent.mkdir(parents=True, exist_ok=True)
            data_dest.write_text(dest.read_text())
        if args.upload:
            upload(out_dir)
            log("  copying the sidecar")
            subprocess.run(["gcloud", "storage", "cp", str(dest),
                            f"{BUCKET}/{PREFIX}/measurements_media.json"], check=True)

    print(json.dumps(doc["coverage"]))
    if skipped:
        print(f"skipped {len(skipped)} ChEBI id(s) that are not the thing measured: "
              + ", ".join(sorted({s['chebi'] for s in skipped})))
    print(f"{len(keys)} keys in {elapsed:.0f}s ({elapsed / max(1, len(keys)):.2f} s/key) → {dest}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
