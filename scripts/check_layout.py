#!/usr/bin/env python3
"""Check the catalog's LAYOUT against the rules the UI refresh set (plan D-10), the way
check_brand.py checks the theme: a real browser, both themes, two widths, exit 1 on any failure.

    scripts/check_layout.py                                  # the four default paths on localhost:4000
    scripts/check_layout.py --url http://localhost:4000/datasets/
    scripts/check_layout.py --base https://calcofi.io        # the live site
    scripts/check_layout.py --widths 1470 --themes light     # narrow a run down

Every assertion below is a problem that was MEASURED on the live site on 2026-09-05, so each one
can only pass by the layout actually being fixed:

  grid       no tile drawn more than 1.25 x its natural height. The grid was 4,910 px of which
             2,838 px was stretch: a CSS grid row is as tall as its tallest tile, so a one-dataset
             tile beside the 25-row reference tile was drawn nine times its own height.
  ladder     every holding row's name computes to --muted, and NOTHING in a holding row computes
             to --warn. Holdings used to be --fg at 700 wearing the page's only yellow chip, so
             the 17 things NOT in the database read louder than the 16 that are.
  scroll     no horizontal scroll at either width, either theme.
  calm       (the dataset catalog and a dataset page, issue #30) the page is at most MAX_DS_H tall
             at 1470 with nothing open (the catalog's ceiling was restated for a finder on
             2026-11-17: its fixed parts plus 22 rows, the arithmetic is beside the constant); every fold, "Years covered", catalog row, "what is in it"
             line and "What this is" is CLOSED on load; the catalog's list has exactly the record's
             datasets; and on the page kept for a holding no block under the head is a grid of more
             than one column (the CTD page's main column was once 418 px beside a 1,346 px sidebar —
             928 px of blank page; the redesigned page's two columns are judged under `dataset`).
  filter     (the catalog) choosing a category actually hides the other tiles and rows. `el.hidden`
             is a UA rule, so `.cc-card { display: flex }` beat it and the filter hid nothing —
             invisible until the grid packed, then the "hidden" tiles overlapped everything.
  url        (dataset pages) no .ds-url is taller than one line at 375 px. A URL in a right-hand
             table column wrapped to five lines on a phone.
  faces      (a measurement page, plan 2026-09-11 § D1–D7, § Verification MF5) the face row is
             What · How · Why in that order and its What column is never empty; every drawn
             structure is a labelled role="img" with real shapes in it; a STAND-IN wears its chip
             and none of the borrowed ids, and a pool, a mixture, a property or an organism never
             claims a ChEBI or a CAS its S27 only nearly means; the sentence's marked parts and its
             legend agree; "other ways to say why" is CLOSED on load and its count is the list's
             own; the familiar scale is drawn wherever the payload has one with NO two mark labels
             overlapping (bounding boxes read from the DOM); the anomaly draws exactly the record's
             depth bands and at least its year-values; and the three sections are written in order.
             Round 2 (plan 2026-09-15 § D3, D4, § Verification R2): the sentence has NO .s-nerc and
             one .cc-src badge per remaining part and no legend paragraph; a scale kind's What
             column draws an svg.mmf-ramp with a <linearGradient> and the record's marks labelled
             on it; every .mmf-pin points at calcofi.org; the spark draws at least three axis ticks
             and is never stretched with preserveAspectRatio=none; the history writes a ± label per
             band (own scale per row), carries the two scale radios and a one-line legend; and
             exactly one .mmf-tip div serves every figure.
  variables  (dataset pages, CalCOFI.github.io#26) Coverage lists every measurement_type a dataset
             ships, one group per grain: each group names its release table (obs_env | obs_bio |
             sample_measurement), its heading's count is the chips drawn under it, and the page's
             total is their sum. calcofi_ctd-derived draws exactly two groups, obs_env then
             sample_measurement. It listed 2 of 9: the per-cast types live in sample_measurement.
  erddap     (dataset pages) each ERDDAP dataset id's tabledap page appears exactly once. It was
             listed twice: once under Download for its formats, once under Services for its page.
  download   (2026-11-16; re-anchored on front door v2, 2026-11-17) a dataset with zips (the record's
             `bundle` rows, else _data/zip_manifest.json) has exactly ONE Download button — in the
             redesigned page's side column, "Get the data" (a holding's layout: its head) — ending
             above the 1280 x 800 fold at 1280 and wider, linking the CSV zip (no-JS: the button IS that
             link); its dialog is closed on load and lists CSV first, linking the manifest's URL, never
             offers an Excel the manifest did not write, and its "Every endpoint" link has an #access
             fold to open. A holding, or any dataset without zips, draws none. /datasets/ is the
             finder: every row is CLICKED and the preview beside the list read — it carries the
             Download control (a link to that dataset page's #download) for each dataset with zips
             and for no other; none is inside a <summary>, none in the holdings.
  finder     (/datasets/, front door v2) the List and By category each hold the record's datasets
             once; a row's click is handled while the preview is drawn and left to follow its link
             where it is not (a phone); with the LAST row chosen and on screen at least 200 px of its
             preview are on screen too, and at >= 1400 the preview is beside the list; the preview's
             actions sit inside its card for every row; choosing a
             type hides rows for real ([hidden] not beaten by an author `display`); its search finds a
             dataset by a species ("sardine"), a measurement ("nitrate") and its own name ("CUFES").
  dataset    (the redesigned dataset page, main.dp-page) one column at 375 and the content column the
             wide one at >= 1000; the side cards (map, Get the data, Cite) overlap neither each other
             nor what follows; the page SAYS its licence, an unstated one too; it lists every
             measurement the record's measurements.json carries for the dataset (#26: the per-cast
             ones too), each once, and the numbers in its band are the counts drawn.
  species    (/species/ and one taxon page, plan 2026-09-09 § S3; round 2 § I1, I2, P1–P3, WS-R5;
             issue #30 D7, D10–D12, D14, D17; the finder of front door v2) the index's counts equal
             the record's and its h1 carries no digit; Groups draws one card per group of
             finder.json; the views are the five tabs (Groups · All species · The tree · the matrix ·
             The hierarchy) and exactly one panel shows; ?tab=hierarchy lands on the hierarchy and
             main's ?tab=classes on Groups; the matrix has exactly (rows x datasets) cells; the
             hierarchy (main's icicle) is drawn when its view shows and only then, zooms on a band
             and climbs back by its breadcrumb (`hierarchy_faults`); nothing is drawn into a block
             that is never shown; a search's matches are the list's rows, species only, and the taxa
             that are not species rows (a genus, a family …) are listed apart under them, each a
             link to its page with its rank and what it holds, never without a search
             (`higher_faults`; "sardin" finds the sardine and the genus Sardinops); every .sp-url is
             one line and elided from the middle; on
             a taxon page the "Observed in" rows are the record's datasets[] with its counts and one
             DRAWN strip each, the lineage is a chain of links ending in the taxon's parent, the
             Explorer link opens prefilled on the taxon key, the ways are one line with the code
             fold taking the ways_tabs include, every fold is closed on load and titled with its
             answer, and there is no sub-nav. At 1470 with nothing open the index's content is at
             most MAX_SPECIES_INDEX_H and a taxon page's MAX_SPECIES_PAGE_H.
  faces      (a taxon page, plan 2026-09-11 § D1–D5, D9; round 2 § P1, P2, D6) the silhouette is a
             labelled role="img" with real pixels; the photo has alt text and is NOT lazy (#30 D11: it is the head's one picture), and
             the head carries ONE picture (#30 D11 A: the photo, else the silhouette); the glance
             draws two bars or says "not on record" — never a blank slot; the sentence's marked
             parts each end in exactly one .cc-src source badge and carry NO .sp-legend (retired in favour of the badges); every asset shown has a
             credit line; the ladder draws exactly the payload's marks and the six references of
             size_reference.csv with NO two labels overlapping (bounding boxes read from the DOM);
             the plate is drawn exactly where the payload has one; and the stat row says "records",
             not "observations", until the record carries n_present (§ D9 — 75.5 % of the CUFES
             rows and 85.0 % of the phytoplankton rows are zeros, so a row is not an organism).
  measurements (/measurements/ and one measurement page, plan 2026-09-10 § D5, D6) the timeline
             draws one row per measurement and one bar per series of the page's OWN inline record
             (79 and 84 on v2026.09.06), grouped into its categories; the matrix is categories ×
             datasets with every cell drawn and the counts summing to the series; every timeline bar
             has its dataset NAMED in the row (identity is never colour alone); the timeline is
             wider than a phone on purpose, so its own container scrolls and the page does not; the
             default view is the LIST (issue #30 D8 A), the finder's By category: every category a
             CLOSED button on load that says what is inside, opened in place by a press and shut by
             a second, the list holding every key once; a search opens the categories that hold a
             match and draws no other, clearing it shuts them, and ?q= on the URL lands the same
             way (`category_faults`); the preview never shows a row hidden in a closed category;
             without JavaScript the page still lists every measurement (<noscript>), and with it
             that list is not also built unseen; the one search finds "nitrate", "NTRAZZXX",
             "µmol/kg" and "METS" in the list and the timeline; the page is at most MAX_MM_INDEX_H
             at 1470 with nothing opened. On a measurement page every fold is
             closed on load and titled with its answer, then opened and measured; the years strip is
             DRAWN (`.mm-drawn`, the `[viewBox]` trap again) in one row per series, with one cell
             per year the record counts, the depth bars are the record's bands × its series with
             every end label inside its column, the month strip is 12 cells per series, and each
             `.mm-url` is one line elided from the middle.

  front door (/, issue #30; the seven tasks of 2026-11-16; front door v2's first screen, 2026-11-17)
             the first screen is the bar, the wave and section.hero: each of the seven tasks (See
             what CalCOFI collects · Explore · Find · Code · Cite · Contribute · Management) and the
             Query Builder is reached from it in ONE step — a visible link under the bar (a start
             card's button or a link of the strip), each >= 32 px tall, Contribute straight to its
             docs chapter; or, for See what CalCOFI collects and Cite, which the strip gave to the
             header on 2026-11-17, and for those two only, a word of the bar (Cite; Learn) — behind
             the menu button under NAV_BREAK; in a 1280 x 645 window
             (its own probe: the first screen is as tall as the window) the three start cards and
             every task's link end above the fold and every word of the bar is drawn; "Where do you
             want to start?" is >= 3:1 against every PIXEL behind a letter of it — photographed with
             and without its text in six windows (1470 x 900, 1280 x 645, 1100 x 800, 901 x 700,
             820 x 900, 375 x 667), both themes: it lies on a picture, under a scrim at desktop
             widths, so no CSS colour is its ground; the numbers stay inside the window; the
             strip of links starts under the last card; under 900 px the ship's label is not drawn;
             no panel is open on load unless the URL names one (#panel, ?door=, ?q=, ?tab=), and then
             exactly one is, the one ?door= names; with none open at >= 1400 the first screen ends at
             the window's bottom and the footer follows it directly; the panels are DRIVEN by the
             first screen's own links — #monitor opens one, #program closes it and opens another,
             Close shuts it and focus is back on the link that opened it; from the header, as a
             keyboard does it — Map ▾ pressed, its line to Maps and apps followed, focus moved on
             into the panel so the menu shuts — Close still lands focus on something DRAWN, never on
             the hidden line; Maps and apps' line to Find opens Find, and closing that lands focus on
             something drawn; every old
             anchor (#datasets #access #build #viz #general #student …, and the retired words) opens
             the panel it now lives in, #viz and #students keeping the hash of where they landed;
             nothing on the first screen is --warn and exactly ONE thing is yellow, the Explorer's
             button (D6 A reversed by front door v2: see PANEL_YELLOW); each panel carries the yellow
             buttons PANEL_YELLOW says, by what is painted; the annotated drawing behind What CalCOFI
             collects has its pins, each answering 200/206 to a ranged GET (checked once, not per
             theme); the four numbers equal the inline #reach record's and the two counted ones link
             their catalogs; Find's list of datasets has datasets.length rows, each name an <a> to
             /datasets/{key}/ with its years drawn, at >= 16 px in --accent and underlined, and at
             >= 1280 the search and the first eight names fit an 800 px window with Find open, beside
             a map card no taller than the head; Find links the Data Finder nowhere; the map has
             stations.length marks; every product of _data/products.yml is a card in some panel
             except a `superseded` one, which is in none; no horizontal scroll.
  header     (every page; brand v3, 2026-11-17) the bar reads exactly the ONE list of words,
             _data/nav.yml, in order — Data ▾ · Map ▾ · Learn ▾ · calcofi.org ↗ (four words
             since the evening of 2026-11-17; Learn holds the guides and the news), pinned by
             this script's unit test — each word marked data-word with its id, in the
             brand's .cc-nav, in sentence case (text-transform none), and the built
             /brand/v3/nav.json (what every other product's header is drawn from) carries the same
             titles; no destination is linked twice (a word of the bar is not also a line of a
             menu); on one line from NAV_BREAK (1100) up, clear of the icon buttons; below it the
             menu button, the nav not drawn, and never a wrap (`--nav`: the widths either side). A
             menu's word is a button naming its panel (aria-controls) and saying its state
             (aria-expanded): shut at rest with none of its lines a tab stop, NOT opened by focus
             alone, opened by a press, still open with focus on one of its lines, shut by Escape
             with focus back on the button, shut when focus leaves; the panel inside the window; the
             hover bridge spans the gap under the word; every line links a page or a place a panel
             of the front door answers; the three catalogs carry their counts; and the header still
             links somewhere everything main's eight words reached (NAV_REACH: the catalogs, the
             Explorer, the Query Builder at its own address /query/, cite, docs, FAQ, News, code
             access, the pipeline, the apps, what CalCOFI collects, calcofi.org), a word or a line of
             a menu: cite, docs, FAQ, News and what CalCOFI collects are lines of Learn, the Query
             Builder a line of Data. Under NAV_BREAK the button opens ONE column: the
             words, the menus inline, every line drawn and none beside another, the menus'
             words saying expanded, every line scrollable into the window (`--nav` adds a 375 x 667
             window for this), no horizontal scroll, Escape closes it.
  wave       (every page, both themes, both widths; brand v3 § 4) exactly ONE .cc-wave band is
             drawn: it starts where the bar ends (no gap, not under the bar, its top line covered by
             nothing), runs edge to edge, is painted the brand's navy and never the page ground (the
             dark theme's ground is itself dark), and its edge is drawn — the brand's ::after mask,
             or for a band that says .cc-wave-own the page's own <svg> along its bottom — filled with
             a colour that is a visible step from the band's own.

  REMOVED on 2026-11-17, each because the page it measured is gone (front door v2), with what took
  its place:
    the seven .fd-door buttons, in order, each controlling its panel → the eight tasks, each one
                                                                  step from the first screen;
    (2026-11-17, Ben) "each task ONE visible link under the bar"   → still so for six tasks; Cite and
                                                                  What CalCOFI collects are the
                                                                  header's (the strip is Contribute
                                                                  and Statewide monitoring);
    NAV_WORDS typed in this file                                → read from _data/nav.yml, the list
                                                                  pinned by the unit test;
    the phone's "head, drawing, doors stack in that order"     → the drawing is the first screen's
                                                                  ground now; the phone rules above;
    FRONT_MAX_H, 950 px at 1470 with no door open               → one window tall, footer directly after;
    "no yellow on the first screen", "one yellow per panel"     → exactly one, the Explorer's; PANEL_YELLOW;
    "the five numbers", stations among them                     → the four the first screen states;
    a header menu "opens on focus"                              → opens on a press, not on focus;
    "each submenu item names a tab (data-go) or a page, and carries a count pill"
                                                                → links a page or an answered anchor;
                                                                  the three catalogs carry their counts;
    ts-viz's pill = its cards                                   → every product a card (product_keys);
    /datasets/: a Download control per row, and again in By category
                                                                → the one preview, driven row by row;
    a dataset page: "no two-column region under the head"       → `dataset` above (a holding's page
                                                                  keeps the old rule);
    a dataset page: the variables by grain (#coverage .ds-vargroup) → every measurement of the record listed;
    /species/: the five counts, the class list in record order, the ?q= Matches list, the icicle
                                                                → the finder's counts against the
                                                                  record, its groups against
                                                                  finder.json, ?q= in its list; the
                                                                  icicle is a view again (2026-11-17);
    /measurements/: unified keys on top                         → the finder's By category sections,
                                                                  every key once (collapsed again on
                                                                  2026-11-17; the ceiling never moved);
    the one search (#door-q → #door-res) on the catalog pages   → it is on the front door's Find panel
                                                                  only; each finder's own search is
                                                                  driven instead.

Lighthouse is NOT run here (it needs its own Chrome and ~30 s a page); README says how, and
.github/workflows/check-brand.yml runs this script weekly and on a pull request.

Needs shot-scraper (`pipx install shot-scraper && shot-scraper install`).
"""
import argparse, json, os, re, subprocess, sys

DEFAULT_PATHS = [
    "/",                             # the front door: one screen, the eight task links, no panel open
    "/?door=viz",                    # an old door's name lands in the panel that now holds it (Maps and apps)
    "/?q=sardine&tab=species",       # D9 (round 2, WS-R4): a shared link lands on the Species tab
                                     #   with the box filled and >= 1 .cc-result already rendered
    "/?q=krill",                     # …and on the Datasets tab, the same box still filters the grid
                                     #   to the euphausiid row (Ben, 2026-09-15, umbrella D9)
    "/datasets/",
    "/datasets/calcofi_ctd-cast/",   # the big one: 3 ERDDAP ids, 33 variables, a long abstract
    "/datasets/swfsc_ichthyo/",      # 29 distributions, 6 registrations, a bbox beyond the frame
    "/datasets/calcofi_prodo/",      # a holding: no map, no Access-from-the-release, a long name
    "/datasets/calcofi_bottle/",     # D2/S1/S2 (round 2, WS-R4): an unstated licence chip, GCMD
                                     #   keyword leaves, the Access tabset (5 groups, 30 endpoints)
    "/datasets/calcofi_ctd-derived/",   # #26: 9 variables in two groups — obs_env (profile) and
                                     #   sample_measurement (per cast), counts from the release
    "/datasets/cce-lter_euphausiids/",  # D3: the bio row's own taxa expander (37 taxa, custom licence)
    "/species/",                     # the species catalog: the finder's groups, the tree and the matrix behind tabs
    "/species/?tab=matrix",          # the matrix view, unchanged, one click away
    "/species/?tab=hierarchy",       # the hierarchy (main's icicle), a tab again: the link lands on it, drawn
    "/species/?tab=classes",         # main's first view's id: an old link lands on Groups
    "/species/?q=sardin",            # I2: a shared search link lands on the list of matches (umbrella D9)
    "/species/worms-217452/",        # the sardine: two datasets, twelve lineage ranks, five ways in
                                     # — and the full face: silhouette, photo, glance, five ladder
                                     #   marks and a NOAA plate (plan 2026-09-11 § Verification F3)
    "/species/worms-148985/",        # Chaetoceros: a silhouette and a photo, "not on record" for
                                     #   size, no plate — and NO gap where they would be
    "/species/itis-1255050/",        # the sooty shearwater: an Ardenna silhouette, flagged as
                                     #   drawn from one rank up
    "/species/worms-273305/",        # jack mackerel — a taxon the media sidecar has no entry for
                                     #   (the fixture's ten are the cast): the page is what
                                     #   it was, plus the sentence's record part and D9's stat word
    "/species/worms-126175/",        # Sebastes: a genus, 38 taxa under it, a synonym pill, no length
    "/species/worms-293496/",        # Teleostei: a class, nothing keyed to it directly
    "/species/itis-176817/",         # Larus occidentalis: a bird keyed through ITIS, a length, no plate
    "/species/worms-104085/",        # Eucalanidae: a silhouette and no photo — the silhouette is the picture
    "/measurements/",                # the measurements catalog: the categories closed, search + timeline, matrix, datasets
    "/measurements/?q=nitrate",      # a shared search link lands with the categories that hold a match open
    "/measurements/temperature/",    # the unified key: two series, two datasets, eight ways in
    # the faces (plan 2026-09-11 § Verification MF5) — the seven states a measurement page can be in
    "/measurements/nitrate/",              # structure: one ion, a bounded scale, six anomaly bands
    "/measurements/salinity/",             # composition: the sea-salt ion bar, two datasets
    "/measurements/dic/",                  # composition: a pool, the Bjerrum plot, no scale
    "/measurements/synechococcus/",        # organism: the species face through S25 → WoRMS — a
                                           #   record-dependent exemplar, see FACE_EXEMPLARS
    "/measurements/wind_speed_ms/",        # no concept: the Beaufort scale and no ids at all
    "/measurements/est_nitrate_sta_corr/", # stands in: nitrate's face, none of nitrate's ids
    "/measurements/ammonia/",              # structure: an equilibrium pair, a left-censored scale
]

# ── record-dependent exemplars ────────────────────────────────────────────────
# A face state can only be exercised on a key the BUILT record carries. The organism state's
# exemplar was /measurements/synechococcus/, a picoplankton key; cce-lter_picoplankton-bacteria left
# the release's measurements record at v2026.10.01, so the page stopped being built and the probe
# measured the server's 404 page — which has no header, so it read as "no phone menu button" (PR #27,
# 2026-10-05). The exemplar is now resolved against the same _data/ files the build read: the
# preferred key if the record carries it, else the first key of that face kind the record does carry,
# else the path is dropped with a note saying the state is not exercised on this record. Without
# _data/measurements.json (a --base pointed at the live site) the default paths stand as written,
# and a page that answers >= 400 fails as missing, never as a layout fault.
FACE_EXEMPLARS = {"organism": "/measurements/synechococcus/"}


def _record_face_kinds(record, media):
    """{measurement key: face kind} from the record's own `face` and the media sidecar's"""
    items = (record or {}).get("measurements") or []
    items = items if isinstance(items, list) else list(items.values())
    mm = (media or {}).get("measurements") or {}
    kinds = {}
    for m in items:
        k = m.get("key") or m.get("slug")
        if not k:
            continue
        kinds[k] = (m.get("face") or {}).get("kind") or ((mm.get(k) or {}).get("face") or {}).get("kind")
    return kinds


def resolve_face_exemplars(paths, record, media, notes=None):
    """swap or drop each FACE_EXEMPLARS path the record cannot build (see the block comment)"""
    if record is None:
        return list(paths)
    kinds = _record_face_kinds(record, media)
    out = []
    for p in paths:
        kind = next((k for k, v in FACE_EXEMPLARS.items() if v == p), None)
        key = p.strip("/").split("/")[-1]
        if kind is None or key in kinds:
            out.append(p)
            continue
        alt = sorted(k for k, v in kinds.items() if v == kind)
        if alt:
            out.append(f"/measurements/{alt[0]}/")
            if notes is not None:
                notes.append(f"{p}: not in this record — the {kind} face is checked on /measurements/{alt[0]}/")
        elif notes is not None:
            notes.append(f"{p}: not in this record and no key of face kind {kind!r} is — "
                         f"the {kind} face is not exercised on this record")
    return out


def product_keys(text):
    """(the keys the front door must draw, the superseded keys it must not), from a products.yml text,
    in file order. An app the Explorer replaced (`status: superseded`) is no longer drawn (Maps and
    apps, front door v2, Betty 2026-11-16). Every other product is a card in some panel — an
    `archived` one too: the archived student projects are still drawn, with their status."""
    drawn, superseded = [], []
    for b in re.split(r"^(?=  - key:)", text or "", flags=re.M):
        m = re.match(r"  - key: *([\w.-]+)", b)
        if not m:
            continue
        (superseded if re.search(r"^    status: *superseded\b", b, re.M) else drawn).append(m.group(1))
    return drawn, superseded


def _products_text():
    try:
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_data", "products.yml")) as f:
            return f.read()
    except OSError:
        return ""


def _data_dir():
    return os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_data")


DL_ORDER = ("csv", "xlsx", "parquet")


def download_offers(data_dir):
    """{dataset_key: {formats, urls, primary, primary_format}} for every dataset the build would draw a
    Download button for — _plugins/downloads.rb's rule: the record's own `bundle` distributions
    first, else the zip manifest (schema 1.x or higher; unknown fields ignored); a holding never;
    nothing written, no entry. URLs are compared exactly as given, never built."""
    rec = _read_json(os.path.join(data_dir, "datasets.json")) or {}
    man = _read_json(os.path.join(data_dir, "zip_manifest.json")) or {}
    by_man = {}
    if re.match(r"\d+", str(man.get("schema_version", ""))) and int(re.match(r"\d+", str(man["schema_version"])).group()) >= 1:
        by_man = {d.get("dataset_key"): d.get("bundles") or [] for d in man.get("datasets") or []}
    out = {}
    for d in rec.get("datasets") or []:
        k = d.get("dataset_key")
        own = [x for x in d.get("distributions") or []
               if x.get("kind") == "bundle" and x.get("format") in DL_ORDER and x.get("status") != "superseded"]
        rows = [dict(x, written=x.get("written", True)) for x in own] if own else by_man.get(k, [])
        urls = {}
        for b in rows:
            f = b.get("format")
            if f in DL_ORDER and b.get("written") and b.get("url") and f not in urls:
                urls[f] = b["url"]
        if urls:
            prim = "csv" if "csv" in urls else next(f for f in DL_ORDER if f in urls)
            out[k] = {"formats": [f for f in DL_ORDER if f in urls], "urls": urls,
                      "primary": urls[prim], "primary_format": prim}
    return out


def _read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def fetch_json(url):
    """the parsed JSON a GET answers, None when it is unreachable, not 200 or not JSON"""
    import urllib.request
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            return json.loads(r.read().decode("utf-8")) if r.status == 200 else None
    except Exception:  # noqa: BLE001
        return None


def page_status(url):
    """the HTTP status of a GET, None when unreachable — a missing page must fail as missing"""
    import urllib.request, urllib.error
    try:
        with urllib.request.urlopen(url, timeout=20) as r:
            return r.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:  # noqa: BLE001
        return None


# ── the front door's first screen (front door v2, _includes/front_door_hero.html) ─────────────
# One function, pasted into PROBE (the page at `width` x PROBE_H) and FOLD_PROBE (FOLD_W x FOLD_H):
# the header's words, every link on the first screen with its box, the three start cards, the strip,
# the numbers and the label drawn by the ship. (What is painted behind "Where do you want to start?"
# is NOT read here: the heading lies on a picture under a scrim, so it is read from PIXELS —
# heading_contrast below.)
HERO_JS = r"""
  const heroMeasure = () => {
    const hero = d.querySelector("section.hero");
    if (!hero) return null;
    const top = el => el.getBoundingClientRect().top + w.scrollY;
    const bot = el => el.getBoundingClientRect().bottom + w.scrollY;
    const vis = el => { const b = el.getBoundingClientRect(), s = w.getComputedStyle(el);
      return b.width > 0 && b.height > 0 && s.display !== "none" && s.visibility !== "hidden"; };
    const box = el => { const b = el.getBoundingClientRect(); return { top: Math.round(b.top + w.scrollY), bottom: Math.round(b.bottom + w.scrollY),
      left: Math.round(b.left), right: Math.round(b.right), h: Math.round(b.height), w: Math.round(b.width) }; };
    const links = [...hero.querySelectorAll("a[href]")].map(a => Object.assign(box(a), {
      href: a.getAttribute("href"),
      text: (a.getAttribute("aria-label") || a.textContent || "").replace(/\s+/g, " ").trim().slice(0, 60),
      where: a.closest("svg") ? "drawing" : a.closest(".hero-foot") ? "strip" : a.closest(".hero-goal") ? "card" : "other",
      visible: vis(a) }));
    const cards = [...hero.querySelectorAll(".hero-goal")].map(c => Object.assign(box(c), {
      title: ((c.querySelector("h3") || {}).textContent || "").trim() }));
    const strip = hero.querySelector(".hero-foot nav"), h2 = d.getElementById("start-h");
    const sea = d.getElementById("hero-sea"), tag = hero.querySelector(".hero-tag");
    const nums = [...hero.querySelectorAll(".hero-nums > div")];
    let floorData = false;
    try { floorData = ((JSON.parse(d.getElementById("hero-floor").textContent) || {}).profile || []).length > 0; } catch (e) {}
    // the header is part of the first screen (brand v3): each word, whether it is drawn, the link it
    // is or the lines its menu holds — a task may be answered by a word instead of a link below it
    const navEl = d.querySelector(".cc-header .cc-links:not(.cc-viewnav)"), burger = d.querySelector(".cc-header .cc-menu-button");
    const navShown = !!navEl && w.getComputedStyle(navEl).display !== "none";
    const header = navEl ? [...navEl.children].filter(el => el.matches("a, .cc-m2, .cc-m")).map(el => {
      const t = el.matches("a") ? el : el.querySelector(":scope > .cc-m2-t, :scope > a");
      return Object.assign(box(t), { id: el.getAttribute("data-word"), title: (t.textContent || "").replace(/\s+/g, " ").trim(),
        href: el.matches("a") ? el.getAttribute("href") : null,
        lines: el.matches("a") ? [] : [...el.querySelectorAll("a[href]")].map(a => a.getAttribute("href")),
        visible: navShown && vis(t) }); }) : [];
    return {
      header, menuButton: !!burger && vis(burger),
      top: Math.round(top(hero)), bottom: Math.round(bot(hero)), innerH: w.innerHeight, innerW: w.innerWidth,
      links, cards,
      strip: strip ? box(strip) : null,
      start: h2 ? Object.assign(box(h2), { color: w.getComputedStyle(h2).color.replace(/\s/g, "") }) : null,
      tag: tag ? { visible: vis(tag), display: w.getComputedStyle(tag).display, w: Math.round(tag.getBoundingClientRect().width) } : null,
      nums: nums.map(n => Object.assign(box(n), { label: ((n.querySelector("dt") || {}).textContent || "").trim() })),
      drawn: sea ? sea.children.length : 0, ridge: !!(sea && sea.querySelector(".ridge")), floorData,
      svgPins: sea ? sea.querySelectorAll("a.pin").length : 0
    };
  };
"""

# the fold: the first screen alone, in a FOLD_W x FOLD_H window, scrolled to the top
FOLD_PROBE = r"""
(w, d) => {
  __HERO__
  w.scrollTo(0, 0);
  return { fold: heroMeasure(), scrollWidth: d.documentElement.scrollWidth, width: w.innerWidth,
           open: [...d.querySelectorAll(".fd-panel")].filter(p => !p.hidden).map(p => p.id) };
}
"""

# ── the probe ─────────────────────────────────────────────────────────────────
# `shot-scraper javascript` has no --width (only `shot` does), so the page is loaded in a
# same-origin iframe of exactly the width under test and measured inside it: media queries,
# innerWidth and the grid's column count all follow the iframe's viewport. That keeps this
# script's only dependency the same as check_brand.py's — shot-scraper on PATH.
# Everything below returns plain data; every judgement is made in Python, so a failure can print
# what it actually measured.
PROBE = r"""
async (w, d) => {
  const px = v => Math.round(v);
  const cs = el => w.getComputedStyle(el);
  const sleep = ms => new Promise(res => setTimeout(res, ms));
  __HERO__
  const rgb = el => cs(el).color.replace(/\s/g, "");
  const tok = n => {
    const v = cs(d.documentElement).getPropertyValue(n).trim();
    if (!v) return null;
    const p = d.createElement("span");
    p.style.color = v; d.body.appendChild(p);
    const out = cs(p).color.replace(/\s/g, ""); p.remove();
    return out;
  };
  const out = {
    theme: d.documentElement.dataset.theme || null,
    width: w.innerWidth,
    scrollWidth: d.documentElement.scrollWidth,
    muted: tok("--muted"), warn: tok("--warn"),
    docHeight: d.documentElement.scrollHeight
  };

  // ── the catalogs' crumb (Datasets · Species · Measurements, each with its count): it must be able to wrap.
  // Its three words are about 368 px at their narrowest, so at 375 px it fitted by a few px on a Mac and ran 2 to
  // 4 px over on Linux, where the counts' mono face is wider: a sideways scroll of all three catalog pages that
  // only the PR workflow saw (2026-11-17). Squeezed to 300 px, a row that can wrap stays inside its box on any
  // platform; one that cannot runs past it.
  const crumbNav = d.querySelector(".cf-crumb");
  if (crumbNav) {
    const keep = crumbNav.style.width; crumbNav.style.width = "300px";
    out.crumb = { squeezed: crumbNav.scrollWidth, box: crumbNav.clientWidth, links: crumbNav.querySelectorAll("a").length };
    crumbNav.style.width = keep;
  }

  // ── the wave (brand v3 § 4, 2026-11-17): a navy band directly under the bar, on every page ──
  // Read first, with the page as it loaded and scrolled to the top. Every .cc-wave that is DRAWN, its
  // box against the header's, what it is painted with (the gradient's colours, or a flat colour),
  // and its edge: the ::after mask the brand draws, or — for a band that says .cc-wave-own — the
  // page's own <svg> along its bottom.
  {
    // a URL that names a panel (?door=, ?q=, #…) has scrolled the page to it, and the site scrolls
    // smoothly: go to the top at once, and measure in document coordinates all the same
    w.scrollTo({ top: 0, left: 0, behavior: "instant" });
    const hdr = d.querySelector(".cc-header"), sy = w.scrollY;
    const cols = v => (String(v || "").match(/rgba?\([^)]*\)/g) || []).map(x => x.replace(/\s/g, ""));
    out.wave = {
      // where the bar ends with the page at the top (should the page not have gone to the top, the bar
      // is stuck there and its height is that place)
      headerBottom: hdr ? px(sy > 0 ? hdr.getBoundingClientRect().height : hdr.getBoundingClientRect().bottom) : null, scrolled: px(sy),
      ground: tok("--bg"),
      all: d.querySelectorAll(".cc-wave").length, dpBand: !!d.querySelector(".dp-band"),
      drawn: [...d.querySelectorAll(".cc-wave")].filter(el => cs(el).display !== "none" && cs(el).visibility !== "hidden" && el.getBoundingClientRect().height > 0).map(el => {
        const b = el.getBoundingClientRect(), st = cs(el), af = w.getComputedStyle(el, "::after");
        const own = el.classList.contains("cc-wave-own");
        const svg = own ? [...el.querySelectorAll("svg")].filter(x => x.querySelector("path") && x.getBoundingClientRect().width >= b.width - 2).pop() : null;
        const sb = svg && svg.getBoundingClientRect();
        const mask = af ? (af.maskImage || af.webkitMaskImage || "none") : "none";
        return {
          cls: String(el.className), own, top: px(b.top + sy), bottom: px(b.bottom + sy), left: px(b.left), right: px(b.right), h: px(b.height),
          paint: cols(st.backgroundImage).concat(st.backgroundImage === "none" ? cols(st.backgroundColor) : []),
          // the brand's edge: a ::after along the bottom, masked to the wave, filled with what lies below
          after: af && af.content !== "none" ? { h: px(parseFloat(af.height) || 0), mask: mask !== "none", fill: cols(af.backgroundColor)[0] || null } : null,
          // a page's own edge: an <svg> with a path, as wide as the band, ending at its bottom
          svg: svg ? { h: px(sb.height), bottomGap: px(Math.abs(sb.bottom - b.bottom)), fill: cols(cs(svg.querySelector("path")).fill)[0] || null } : null,
          // what covers the band's top line, sampled at its middle: nothing but the band itself or something inside it
          hidden: sy > 0 ? null : (() => { const e = d.elementFromPoint(Math.min(w.innerWidth - 2, Math.max(2, b.left + b.width / 2)), b.top + 2);
            return !!e && e !== el && !el.contains(e) && !(hdr && hdr.contains(e)) ? String(e.className || e.tagName).slice(0, 40) : null; })()
        };
      })
    };
  }

  // ── the dataset catalog and a dataset page, calmer (issue #30) ─────────────
  // measured FIRST, before any probe below opens or filters anything: the page's height with
  // nothing open, and every fold, catalog row and "what is in it" line closed on load
  // (front door v2: a dataset's page is main.dp-page, the redesigned one; a holding keeps
  // main.ds-page; /datasets/ is the finder, main.ds-cat.ds-browse, its rows a.bd-r[data-k])
  const calmDs = d.querySelector("main.ds-page, main.ds-cat, main.dp-page");
  if (calmDs) {
    out.calmDs = {
      kind: calmDs.classList.contains("ds-cat") ? "catalog" : "dataset",
      redesigned: calmDs.classList.contains("dp-page"),
      holding: !!d.getElementById("lives"),
      height: d.documentElement.scrollHeight,
      folds: calmDs.querySelectorAll(".calm-fold").length,
      open: [...calmDs.querySelectorAll(".calm-fold[open], .calm-item[open], .ds-line[open], .ds-more[open], .bd-when[open]")]
              .map(el => el.id || String(el.className).slice(0, 30)),
      // the list's rows are the record's datasets, once each — in the List and in By category
      rows: [...calmDs.querySelectorAll("#bd-list .bd-r[data-k]")].map(el => el.dataset.k),
      gridRows: [...calmDs.querySelectorAll("#ds-view-grid .bd-r[data-k]")].map(el => el.dataset.k)
    };
  }

  // ── the Download button (2026-11-16): one on a dataset page, on its first screen, its dialog CSV
  // first; on /datasets/ the preview beside the list carries the control for the row it shows, never
  // inside a <summary> — read before anything below opens or filters, so the button's position is
  // the page as it loads
  if (calmDs) {
    const btns = [...calmDs.querySelectorAll(".dl-btn")];
    const dlg = d.getElementById("dl-dialog");
    const b0 = btns[0] && btns[0].getBoundingClientRect();
    out.download = {
      n: btns.length,
      // where the one button sits: the head of the page kept for a holding's layout, the "Get the
      // data" card of the redesigned page's side column
      inHead: btns.filter(b => b.closest(".calm-head, .dp-side")).length,
      bottom: b0 ? px(b0.bottom + w.scrollY) : null,
      href: btns[0] ? btns[0].getAttribute("href") : null,
      dialog: !!dlg, dialogOpen: !!(dlg && dlg.open),
      // the dialog's plain options in order: the format a link offers, or "off:<label>" for one not offered
      options: dlg ? [...dlg.querySelectorAll(".dl-opts > .dl-opt")].map(li => {
        const a = li.querySelector("a[data-dl-format]");
        return a ? a.dataset.dlFormat : "off:" + ((li.querySelector(".dl-off-t") || {}).textContent || "").trim();
      }) : [],
      firstHref: dlg && dlg.querySelector(".dl-opts a[data-dl-format]") ? dlg.querySelector(".dl-opts a[data-dl-format]").getAttribute("href") : null,
      // the dialog's "Every endpoint" link must have its fold to land on
      endpointsLink: !!(dlg && dlg.querySelector("[data-dl-endpoints]")), accessFold: !!d.getElementById("access"),
      inSummary: calmDs.querySelectorAll("summary .dl-rowlink, summary .dl-btn, summary a[href$='#download']").length,
      inHoldings: calmDs.querySelectorAll("#ds-holdings .dl-rowlink, .ds-row-holding .dl-rowlink, #ds-holdings a[href$='#download']").length
    };
  }

  // ── Browse datasets, the finder (front door v2): a row shows its dataset in the preview beside
  // the list. DRIVEN: every row of the List is clicked and the preview read — its Download control
  // (a link to that dataset page's #download), and whether the click was handled at all. A click the
  // page does not handle would follow the link and take the probe with it, so a last listener on
  // the window records what the page did and then holds the navigation.
  const bdList = d.getElementById("bd-list"), bdPv = d.getElementById("bd-pv");
  if (bdList && bdPv) {
    // the page opens on the category tiles, which draw no preview (Betty 2026-11-20); the List tab shows it
    const lt = d.getElementById("ds-view-tab-list");
    if (lt && lt.getAttribute("aria-selected") !== "true") { lt.click(); await sleep(250); }
    const rowsEl = [...bdList.querySelectorAll(".bd-r[data-k]")];
    const pvShown = () => !bdPv.hidden && cs(bdPv).display !== "none" && bdPv.getBoundingClientRect().height > 0;
    let handled = null;
    const hold = e => { handled = e.defaultPrevented; e.preventDefault(); };
    w.addEventListener("click", hold);
    const sel0 = (bdList.querySelector(".bd-r.on") || rowsEl[0] || { dataset: {} }).dataset.k;
    const pvDl = {}, unhandled = [];
    let actOver = { px: 0, key: null, what: null }, actN = 0;
    for (const row of rowsEl) {
      handled = null; row.click();
      if (!handled) unhandled.push(row.dataset.k);
      const a = bdPv.querySelector('a[href*="#download"]');
      const h2 = bdPv.querySelector("h2, h3");
      // the preview's actions (View on map · Download · Full details) sit inside the card: the widest
      // overhang of any of them past the card's own edges, over every row ("Full details" stuck out
      // 20 px and the page scrolled sideways at 1100 px until 6292d3d)
      if (pvShown()) {
        const pr0 = bdPv.getBoundingClientRect();
        for (const el of bdPv.querySelectorAll(".bd-pv-act a, .bd-pv-act button")) {
          const eb = el.getBoundingClientRect(), over = Math.max(eb.right - pr0.right, pr0.left - eb.left, eb.bottom - pr0.bottom);
          if (eb.width > 0 && over > actOver.px) actOver = { px: Math.round(over), key: row.dataset.k, what: (el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 30) };
        }
        actN = Math.max(actN, [...bdPv.querySelectorAll(".bd-pv-act a, .bd-pv-act button")].filter(el => el.getBoundingClientRect().width > 0).length);
      }
      pvDl[row.dataset.k] = { href: a ? a.getAttribute("href") : null, tag: a ? a.tagName : null,
        title: h2 ? h2.textContent.trim() : null, name: (row.querySelector("b") || {}).textContent || null };
    }
    // the preview stays reachable: with the LAST row of the list chosen and on screen, the preview
    // that answers it is on screen too (it is sticky beside the list), not a scroll away
    let reach = null;
    const last = rowsEl[rowsEl.length - 1];
    if (last) {
      last.scrollIntoView({ block: "center" });
      await sleep(250);
      handled = null; last.click();
      await sleep(120);
      const pr = bdPv.getBoundingClientRect(), lr = last.getBoundingClientRect(), hh = parseFloat(cs(d.documentElement).getPropertyValue("--header-h")) || 72;
      reach = { shown: pvShown(), handled, position: cs(bdPv).position, pvTop: px(pr.top), pvBottom: px(pr.bottom), rowTop: px(lr.top), rowBottom: px(lr.bottom),
        innerH: w.innerHeight, headerH: hh,
        // how much of the preview is inside the window, under the sticky header
        inView: px(Math.max(0, Math.min(pr.bottom, w.innerHeight) - Math.max(pr.top, hh))),
        sideBySide: pr.left >= lr.right - 2 || pr.right <= lr.left + 2 };
    }
    w.removeEventListener("click", hold);
    const first = rowsEl.find(x => x.dataset.k === sel0);
    if (first && pvShown()) { w.addEventListener("click", hold); first.click(); w.removeEventListener("click", hold); }
    // the type filter actually hides: `el.hidden` is a UA rule that any author `display` beats (see
    // "the filter actually hides" below, which read the old page's #ds-cat)
    const typ = d.getElementById("bd-type");
    let bdFilter = null;
    if (typ) {
      const opt = [...typ.options].map(o => o.value).filter(Boolean)[0];
      if (opt) {
        typ.value = opt; typ.dispatchEvent(new w.Event("change", { bubbles: true }));
        void d.body.offsetHeight;
        bdFilter = { type: opt, shown: rowsEl.filter(x => x.getBoundingClientRect().height > 0).length, total: rowsEl.length,
          painted: [...calmDs.querySelectorAll("[hidden]")].filter(el => cs(el).display !== "none").map(el => el.tagName + "." + String(el.className).slice(0, 40)) };
        typ.value = ""; typ.dispatchEvent(new w.Event("change", { bubbles: true }));
      }
    }
    // its search finds a dataset by a species and by a measurement inside it, and by its own name
    const bq = d.getElementById("bd-q");
    let bdSearch = null;
    if (bq) {
      bdSearch = {};
      for (const t of ["sardine", "nitrate", "CUFES"]) {
        bq.value = t; bq.dispatchEvent(new w.Event("input", { bubbles: true }));
        await sleep(60);
        bdSearch[t] = rowsEl.filter(x => x.getBoundingClientRect().height > 0).map(x => x.dataset.k);
      }
      bq.value = ""; bq.dispatchEvent(new w.Event("input", { bubbles: true }));
    }
    w.scrollTo(0, 0);
    out.browse = { pvDl, unhandled, reach, filter: bdFilter, search: bdSearch, pvDisplay: cs(bdPv).display, actOver, actN };
  }

  // ── the redesigned dataset page (front door v2, _includes/dataset_page.html) ───────────────
  // Two columns by design at desktop width — what is in the dataset, beside a narrower column of
  // cards (the map, Get the data, Cite) — and one column on a phone. Read: the columns, each side
  // card's box, the licence line, the measurements and taxa it lists, the numbers in its band.
  const dpMain = d.querySelector("main.dp-page");
  if (dpMain) {
    const row = dpMain.querySelector(".dp-row"), mainCol = dpMain.querySelector(".dp-main"), side = dpMain.querySelector(".dp-side");
    const rect = el => { const b = el.getBoundingClientRect(); return { top: px(b.top + w.scrollY), bottom: px(b.bottom + w.scrollY), left: px(b.left), right: px(b.right), w: px(b.width) }; };
    const lic = dpMain.querySelector(".dp-lic, .cc-chip-lic");
    out.dp = {
      cols: row ? cs(row).gridTemplateColumns.split(" ").filter(Boolean).length : null,
      mainW: mainCol ? px(mainCol.getBoundingClientRect().width) : null, sideW: side ? px(side.getBoundingClientRect().width) : null,
      cards: side ? [...side.querySelectorAll(":scope > .dp-card")].map(c => Object.assign(rect(c), { title: ((c.querySelector("h3") || {}).textContent || "map").trim() })) : [],
      side: side ? rect(side) : null, main: mainCol ? rect(mainCol) : null,
      below: [...dpMain.querySelectorAll(":scope > .dp-about, :scope > .dp-folds")].map(el => Object.assign(rect(el), { cls: el.className })),
      licence: lic ? lic.textContent.replace(/\s+/g, " ").trim() : null,
      citeCard: !!dpMain.querySelector(".dp-cite"),
      // each measurement row links its page: /measurements/{slug}/ (a per-cast row has no CSV button, so
      // the button's data-k is not every row's)
      measKeys: [...dpMain.querySelectorAll(".dp-m .dp-tr:not(.dp-th) .dp-nm a[href]")].map(a => (/\/measurements\/([^\/]+)\/?$/.exec(a.getAttribute("href")) || [])[1] || a.getAttribute("href"))
        // the table of the redesigned page (Erin's feedback, 2026-11-21): a row per measurement_type, each linking its measurement's page; two rows may share one page
        .concat([...new Set([...dpMain.querySelectorAll(".dp-mtbl tbody tr td:first-child a[href*='/measurements/']")].map(a => (/\/measurements\/([^\/]+)\/?$/.exec(a.getAttribute("href")) || [])[1] || a.getAttribute("href")))]),
      measCsv: dpMain.querySelectorAll('.dp-csv[data-one="env"]').length, measNoCsv: dpMain.querySelectorAll(".dp-m .dp-nocsv").length,
      taxaDrawn: dpMain.querySelectorAll('.dp-csv[data-one="bio"]').length,
      taxaMore: (() => { try { return JSON.parse(dpMain.querySelector("[data-more-rows]").textContent).length; } catch (e) { return 0; } })(),
      facts: [...d.querySelectorAll(".dp-nums > div")].map(el => ({ label: el.querySelector("dt").textContent.trim(), value: el.querySelector("dd").textContent.trim() })),
      csvUnnamed: [...dpMain.querySelectorAll(".dp-csv")].filter(b => !(b.getAttribute("title") || b.getAttribute("aria-label") || "").trim()).length
    };
  }

  // ── the grid: drawn vs natural height per tile ──────────────────────────────
  const grid = d.getElementById("ds-grid");
  if (grid) {
    const tiles = [...grid.children].filter(t => !t.hidden);
    const drawn = tiles.map(t => t.getBoundingClientRect().height);
    // natural = the same tiles with the packing off: no spans, no stretching
    const spans = tiles.map(t => t.style.gridRowEnd);
    const was = grid.className;
    tiles.forEach(t => { t.style.gridRowEnd = ""; });
    grid.classList.remove("is-masonry");
    grid.style.alignItems = "start";
    void grid.offsetHeight;
    const natural = tiles.map(t => t.getBoundingClientRect().height);
    grid.style.alignItems = "";
    grid.className = was;
    tiles.forEach((t, i) => { t.style.gridRowEnd = spans[i]; });
    void grid.offsetHeight;
    out.grid = {
      height: px(grid.getBoundingClientRect().height),
      masonry: grid.classList.contains("is-masonry"),
      columns: cs(grid).gridTemplateColumns.split(" ").length,
      tiles: tiles.map((t, i) => ({
        name: ((t.querySelector(".ds-tile-name") || {}).textContent || t.dataset.tile || "").trim(),
        drawn: px(drawn[i]), natural: px(natural[i]),
        ratio: natural[i] > 0 ? +(drawn[i] / natural[i]).toFixed(3) : 1
      }))
    };
  }

  // D4/D5 (round 2, WS-R4): the six facet selects, once #ds-q is gone — measured, never asserted
  // (there is no "right" width), so a future change to the row can see whether they moved
  const filterSelects = [...d.querySelectorAll(".ds-filter select")];
  if (filterSelects.length) {
    out.filterSelectWidths = filterSelects.map(s => ({ id: s.id, w: px(s.getBoundingClientRect().width) }));
  }

  // ── the filter actually hides ───────────────────────────────────────────────
  // `el.hidden` is a UA-stylesheet rule, so ANY author rule that sets `display` beats it — and
  // .cc-card and .ds-row both set `display: flex`. The filter row hid nothing for as long as it
  // existed (12 tiles and 41 rows stayed painted with one category selected), which only became
  // visible when the grid packed: a tile JS thinks is hidden gets no span, is drawn one 8 px row
  // tall, and spills over its neighbours. So: pick a category, apply it, and look.
  const sel = d.getElementById("ds-cat");
  if (sel) {
    const opt = [...sel.options].map(o => o.value).filter(Boolean)[0];
    if (opt) {
      sel.value = opt;
      sel.dispatchEvent(new w.Event("change", { bubbles: true }));
      void d.body.offsetHeight;
      out.filter = {
        category: opt,
        painted: [...d.querySelectorAll("[hidden]")]
          .filter(el => cs(el).display !== "none")
          .map(el => el.tagName + "." + String(el.className).slice(0, 40)),
        tilesShown: [...(grid ? grid.children : [])].filter(t => !t.hidden).length
      };
      sel.value = "";
      sel.dispatchEvent(new w.Event("change", { bubbles: true }));
    }
  }

  // ── the ladder: a holding row is muted, and carries no --warn ───────────────
  out.holdings = [...d.querySelectorAll(".ds-row-holding")].map(row => ({
    key: row.dataset.key,
    name: rgb(row.querySelector(".ds-row-name")),
    warn: [row, ...row.querySelectorAll("*")]
            .filter(el => {
              const s = cs(el);
              return s.color.replace(/\s/g, "") === out.warn ||
                     s.borderTopColor.replace(/\s/g, "") === out.warn ||
                     s.backgroundColor.replace(/\s/g, "") === out.warn;
            })
            .map(el => String(el.className || el.tagName))
  }));

  // ── the dataset page ───────────────────────────────────────────────────────
  // (issue #30: the head is calm.css's head of four things — the map is its picture at its own
  // aspect, never stretched to the text — so the old hero's "two columns end together" is gone)

  // D2 (round 2, WS-R4): the head wears the same licence chip as a homed row
  const headLic = d.querySelector(".ds-facts .cc-chip-lic, .ds-chips .cc-chip-lic");
  if (headLic) {
    out.headLicence = { present: true, text: headLic.textContent.replace(/\s+/g, " ").trim() };
  }

  // S1: a keyword chip's title is the full GCMD path, its text the leaf after the last ">" — scoped
  // to the Keywords row specifically (.ds-kw is reused for the Coverage variables list too, whose
  // chips carry their OWN, unrelated title)
  const kwChips = [...d.querySelectorAll(".ds-kw-keywords .cc-chip[title]")];
  if (kwChips.length) {
    out.keywordChips = kwChips.map(c => ({ text: c.textContent.trim(), title: c.getAttribute("title") }));
  }

  // S2: Access as a tabset — one panel per group, exactly one shown
  const dsAccess = d.getElementById("ts-ds-access");
  if (dsAccess) {
    const tabs = dsAccess.querySelectorAll(".tabrow > button").length;
    const panels = dsAccess.querySelectorAll(".tabpanel").length;
    const shown = [...dsAccess.querySelectorAll(".tabpanel")].filter(p => !p.hidden).length;
    out.dsAccessTabset = { tabs, panels, shown };
  }
  // Coverage's variables, one group per grain (CalCOFI.github.io#26): the table beside each group,
  // the chips it draws, the count its own heading states, and the page's total
  const vgs = [...d.querySelectorAll("#coverage .ds-vargroup")];
  if (vgs.length) {
    const tot = (d.querySelector("#coverage .ds-cov-h") || {}).textContent || "";
    const gl = [...d.querySelectorAll(".ds-head .calm-nums > div")].find(x => (x.querySelector("dt") || {}).textContent === "years");
    out.varGroups = {
      total: parseInt(tot, 10),
      glance: gl ? gl.querySelector("dd").textContent.trim() : null,
      summaries: vgs.map(g => (g.querySelector(".ds-vargroup-h .cc-muted") || {}).textContent || ""),
      groups: vgs.map(g => ({
        grain: g.dataset.grain,
        table: (g.querySelector(".ds-vargroup-t") || {}).textContent || "",
        // every chip of the group, the collapsed "all N" ones too: the parser closes a <p> at the
        // <details> inside it, so those chips are siblings of .ds-varchips, not its children
        chips: g.querySelectorAll(".cc-chip").length,
        said: parseInt(((g.querySelector(".ds-vargroup-h .cc-muted") || {}).textContent || "").match(/(\d+) variables?\s*$/)?.[1], 10)
      }))
    };
  }
  // one column under the head (issue #30): no block of the page body, nor anything directly inside
  // its open sections, is a grid of more than one column (inner tables inside a fold may be)
  out.twoCol = [...d.querySelectorAll("main.ds-page > *:not(.calm-head), main.ds-page > .calm-sec > *")]
    .filter(el => {
      const st = cs(el);
      return st.display === "grid" && st.gridTemplateColumns.split(" ").filter(Boolean).length > 1;
    })
    .map(el => (el.id || String(el.className)));

  // a URL line must never wrap. Measure the TEXT, not the row: the row also holds a copy button,
  // which is taller than a line of 11.5 px mono and would read as a wrap that is not there.
  out.urls = [...d.querySelectorAll(".ds-url")].map(u => {
    const parts = [...u.querySelectorAll(".ds-url-h, .ds-url-t")];
    return {
      h: px(u.getBoundingClientRect().height),
      textH: px(Math.max(0, ...parts.map(s2 => s2.getBoundingClientRect().height))),
      lh: px(parseFloat(cs(u).lineHeight) || 0),
      t: (u.textContent || "").trim().slice(0, 60)
    };
  });

  // ── the front door (issue #30; the seven tasks of 2026-11-16; front door v2's first screen) ──
  // The first screen is section.hero: three start cards, a strip of links, the numbers, over Line
  // 90's sea floor. There are no door buttons: LINKS open the panels (index.html's script), so the
  // panels are DRIVEN through the hero's own links — open one, open another, Close — and through a
  // link to every old anchor; then the page is put back the way it loaded, so everything measured
  // after this (the tabsets, the search) sees the URL's own state. Document coordinates.
  const hero = d.querySelector("section.hero");
  if (hero) {
    w.scrollTo(0, 0);
    const panels = [...d.querySelectorAll(".fd-panel")];
    const openNow = () => panels.filter(p => !p.hidden).map(p => p.id);
    let reach = null; try { reach = JSON.parse(d.getElementById("reach").textContent); } catch (e) {}
    const band = [...hero.querySelectorAll(".hero-nums > div")].map(el => ({ label: el.querySelector("dt").textContent.trim(), value: el.querySelector("dd").textContent.trim(),
      href: el.querySelector("dd a") ? el.querySelector("dd a").getAttribute("href") : null }));
    // the first screen: nothing in --warn; yellow (--cta-bg, the brand's yellow) is counted, with what wears it
    const first = [...hero.querySelectorAll("*")];
    const colOf = el => { const s = cs(el); return [s.color, s.backgroundColor, s.borderTopColor].map(x => x.replace(/\s/g, "")); };
    const yellows = [tok("--cta-bg"), tok("--cc-yellow"), "rgb(255,205,0)"].filter(Boolean);
    const isYellow = el => yellows.indexOf(cs(el).backgroundColor.replace(/\s/g, "")) >= 0;
    const drawnEl = el => { const b = el.getBoundingClientRect(); return b.width > 0 && b.height > 0; };
    const ctaEls = first.filter(el => drawnEl(el) && isYellow(el)).map(el => ({ cls: String(el.className || el.tagName),
      text: (el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 40), href: (el.closest("a") || { getAttribute: () => null }).getAttribute("href") }));
    // a yellow button is not a warning: in the dark theme --warn and --cta-bg are one colour, so what
    // IS a yellow button (or sits inside one) is counted as yellow above and not again as --warn
    const inYellow = el => { for (let n = el; n && n !== hero; n = n.parentElement) if (isYellow(n)) return true; return false; };
    const warnEls = first.filter(el => drawnEl(el) && !inYellow(el) && colOf(el).indexOf(out.warn) >= 0)
      .map(el => String(el.className || el.tagName));
    const full = d.querySelector("#sec-full svg.sec");
    const H = heroMeasure();
    out.front = {
      hero: H,
      openOnLoad: openNow(),
      heightOnLoad: d.documentElement.scrollHeight,
      footerTop: d.querySelector("footer") ? px(d.querySelector("footer").getBoundingClientRect().top + w.scrollY) : null,
      // every yellow button a panel carries, by what is painted (a class is not a colour)
      panelCtas: panels.map(p => ({ id: p.id, yellow: [...p.querySelectorAll("a, button")].filter(isYellow)
        .map(el => (el.textContent || "").replace(/\s+/g, " ").trim().slice(0, 40)) })),
      pins: full ? [...full.querySelectorAll("a.pin")].map(a => a.getAttribute("href")) : [],
      band, reachNumbers: reach && reach.numbers,
      // Find's list of datasets (Ben, 2026-11-16): one HTML row per dataset, the name an <a> to its page
      stripRows: d.querySelectorAll(".fd-yrow a.fd-yname[href]").length, datasets: reach && reach.datasets.length,
      stripDrawn: d.querySelectorAll(".fd-yrow .fd-ycells svg.fd-ysvg").length,
      // the Download control beside each name with zips (2026-11-16): the keys whose rows carry one
      stripDl: [...d.querySelectorAll(".fd-yrow[data-key]")].filter(r => r.querySelector(".dl-rowlink")).map(r => r.dataset.key),
      stripLinks: [...d.querySelectorAll(".fd-yrow")].map(r => ({ key: r.dataset.key,
        href: (r.querySelector("a.fd-yname") || { getAttribute: () => null }).getAttribute("href") })),
      finderLinks: [...d.querySelectorAll("#find a[href]")].map(a => a.getAttribute("href")).filter(h => /app\.calcofi\.io\/station/.test(h)),
      accent: tok("--accent"),
      mapMarks: d.querySelectorAll("svg.map .st").length - d.querySelectorAll("svg.map .keyg .st").length, stations: reach && reach.stations.length,
      cardKeys: [...new Set([...d.querySelectorAll(".prod-card[data-key]")].map(c => c.dataset.key))],
      warnEls, ctaEls
    };
    // drive the panels through the first screen's own links: one opens, a second closes the first,
    // Close closes it and gives focus back to the link that opened it. Since 2026-11-17 the links to
    // a panel under the bar are the strip's "Statewide monitoring" (#monitor) and the Code card
    // (#program); What CalCOFI collects and Maps and apps are opened from the header (Learn ▾, Map ▾).
    const hl = h => hero.querySelector('.hero-foot a[href="' + h + '"], .hero-goal a[href="' + h + '"]');
    const closeBtn = k => d.querySelector("#" + k + " [data-close]");
    const seen = el => !!el && el !== d.body && el.getBoundingClientRect && el.getBoundingClientRect().width > 0 &&
      cs(el).visibility !== "hidden" && cs(el).display !== "none";
    const lA = hl("#monitor"), lB = hl("#program");
    if (lA && lB) {
      const was = openNow();
      was.forEach(k => closeBtn(k) && closeBtn(k).click());     // start from every panel closed
      lA.focus(); lA.click();
      const a = openNow();
      lB.focus(); lB.click();
      const b = openNow();
      if (closeBtn("program")) closeBtn("program").click();
      const c = openNow();
      const act = d.activeElement;
      const focusBack = { same: act === lB, tag: act ? act.tagName : null, href: act && act.getAttribute ? act.getAttribute("href") : null,
        inHero: !!(act && hero.contains(act)) };
      // from the header, as a keyboard does it: Map ▾ is pressed, its line "All apps" (/#explore) is
      // followed, focus moves on into the panel (the menu shuts behind it) and Close is pressed. The
      // line that opened the panel is hidden by then, so focus must land on something that IS drawn
      // — never on a hidden link, which leaves it on <body>. Under NAV_BREAK the same line is in the
      // menu button's column; it is followed the same way.
      const line = d.querySelector('.cc-header .cc-links:not(.cc-viewnav) a[href$="#explore"]');
      const lineMenu = line && line.closest(".cc-m2"), lineBtn = lineMenu && lineMenu.querySelector(".cc-m2-t");
      const navDrawn = !!line && cs(d.querySelector(".cc-header .cc-links:not(.cc-viewnav)")).display !== "none";
      let viaHeader = null;
      if (line) {
        if (navDrawn && lineBtn) { lineBtn.focus(); lineBtn.click(); await sleep(80); line.focus(); }
        line.click();
        await sleep(60);
        const opened = openNow();
        const inPanel = d.querySelector("#explore a[href], #explore button");
        if (inPanel) inPanel.focus();
        await sleep(360);                                         // the menu's close delay
        const lineHidden = !seen(line);
        if (closeBtn("explore")) closeBtn("explore").click();
        await sleep(40);
        const ah = d.activeElement;
        viaHeader = { opened, navDrawn, lineHidden, afterClose: openNow(), seen: seen(ah), tag: ah ? ah.tagName : null,
          what: ah ? (ah.id || ah.getAttribute("href") || (ah.textContent || "").trim().slice(0, 30)) : null };
      }
      // Find is reached from Maps and apps (its line to Find) and from every old link; opened, its
      // list's names read as links (body-text size, the link colour, underlined), and with the panel
      // scrolled to its top the search and the first eight names sit inside an 800 px window under
      // the sticky header — finding a dataset is the obvious thing (Ben, 2026-11-16)
      { const lk = d.createElement("a"); lk.href = "#explore"; d.body.appendChild(lk); lk.click(); lk.remove(); }
      const xref = d.querySelector('#explore a[href="#find"]');
      if (xref) xref.click();
      const f = openNow();
      const fp = d.getElementById("find"), names = [...d.querySelectorAll("#find .fd-yname")];
      if (fp && names.length && f.indexOf("find") >= 0) {
        const ft = fp.getBoundingClientRect().top, q = d.getElementById("door-q");
        const n8 = names[Math.min(7, names.length - 1)], s0 = cs(names[0]);
        out.front.findList = {
          qBottom: q ? px(q.getBoundingClientRect().bottom - ft) : null,
          n8Bottom: px(n8.getBoundingClientRect().bottom - ft),
          headerH: parseFloat(cs(d.documentElement).getPropertyValue("--header-h")) || null,
          fontPx: parseFloat(s0.fontSize), color: s0.color.replace(/\s/g, ""),
          underline: s0.textDecorationLine, minH: px(Math.min(...names.map(x => x.getBoundingClientRect().height))),
          mapH: px((d.querySelector("#find .fd-map") || { getBoundingClientRect: () => ({ height: 0 }) }).getBoundingClientRect().height),
          headH: px((d.querySelector("#find .fd-phead") || { getBoundingClientRect: () => ({ height: 0 }) }).getBoundingClientRect().height)
        };
      }
      // a panel opened by a link INSIDE a panel (which hides with it): Close still lands focus on
      // something drawn, never on <body>
      if (closeBtn("find")) closeBtn("find").click();
      const act2 = d.activeElement;
      const focusBack2 = { tag: act2 ? act2.tagName : null, id: act2 ? act2.id : null, drawn: seen(act2) };
      // the old anchors: a click on a link to each (the header's menus do exactly this) opens the
      // panel it now lives in. A tab anchor selects its tab, so every tabset's selection and the
      // URL are put back afterwards — what is measured next sees the page the URL loaded.
      const href0 = w.location.href;
      const sel0 = [...d.querySelectorAll(".fd-panel .tabset")].map(ts => ts.querySelector('.tabrow [aria-selected="true"]')).filter(Boolean);
      const anchors = {};
      for (const h of __FD_ANCHORS__) {
        // every panel shut first, so an anchor that opens nothing cannot pass on the panel the
        // anchor before it left open (#explorer, #general, #viz, #dataset, #student share one)
        openNow().forEach(k => closeBtn(k) && closeBtn(k).click());
        const lk = d.createElement("a"); lk.href = "#" + h; d.body.appendChild(lk);
        lk.click(); lk.remove();
        anchors[h] = { open: openNow(), hash: w.location.hash.replace(/^#/, "") };
      }
      sel0.forEach(b => b.click());
      openNow().forEach(k => closeBtn(k) && closeBtn(k).click());
      if (was.length) { const lk = d.createElement("a"); lk.href = "#" + was[0]; d.body.appendChild(lk); lk.click(); lk.remove(); }   // put back what the URL opened
      sel0.forEach(b => b.click());
      try { w.history.replaceState(null, "", href0); } catch (e) {}
      out.front.drive = { afterA: a, afterB: b, afterClose: c, focusBack, viaHeader, afterFind: f, hasXref: !!xref, focusBack2, anchors, restored: openNow() };
      if (d.activeElement && d.activeElement.blur) d.activeElement.blur();
      w.scrollTo(0, 0);
    }
  }

  // ── the header (brand v3, _includes/site_nav.html from _data/nav.yml: Data ▾ · Map ▾ · Query ·
  // Cite · Learn · Docs · FAQ · News · calcofi.org ↗; the behaviour is brand/v3/header.js) ──
  // The words, the menus and what they link. A menu's word is a BUTTON (aria-expanded, aria-controls)
  // over its panel: the CSS opens it on hover, brand/v3/header.js on a press — never on focus alone, so
  // tabbing along the header does not throw three panels open. Everything is measured on the real
  // page: the button is focused (the menu must stay shut), pressed (it must open and say so), focus
  // is moved onto a line inside it, Escape is pressed (it must shut and focus must be back on the
  // button), then it is pressed open again and focus is sent away (it must shut). A menu closes on a
  // short delay (the visibility transition that lets a pointer cross the gap), so each state is read
  // after waiting it out.
  const nav = d.querySelector(".cc-header .cc-links:not(.cc-viewnav)");
  const navItems = () => nav ? [...nav.children].filter(el => el.matches("a, .cc-m, .cc-m2")) : [];
  const trigOf = el => el.matches(".cc-m, .cc-m2") ? el.querySelector(":scope > .cc-m2-t, :scope > a") : el;
  const listOf = m => m.querySelector(":scope > ul, :scope > .cc-dd");
  const shownEl = el => !!el && cs(el).display !== "none" && cs(el).visibility !== "hidden" && el.getBoundingClientRect().height > 0;
  if (nav) {
    const menus = [], navVisible = cs(nav).display !== "none";
    const away = d.querySelector(".cc-header .cc-home") || d.body;
    for (const m of nav.querySelectorAll(".cc-m, .cc-m2")) {
      const trig = trigOf(m), list = listOf(m);
      const rec = {
        word: trig ? trig.textContent.replace(/\s+/g, " ").trim() : null,
        tag: trig ? trig.tagName : null,
        controls: trig ? trig.getAttribute("aria-controls") : null, listId: list ? list.id : null,
        tabs: [...(list ? list.querySelectorAll("a") : [])].map(a => ({
          title: ((a.querySelector("b") || a).textContent || "").replace(/\s+/g, " ").trim(),
          pill: ((a.querySelector(".pill, small") || {}).textContent || "").trim() || null,
          go: a.getAttribute("data-go"),
          href: a.getAttribute("href")
        })),
        expandedAtRest: trig ? trig.getAttribute("aria-expanded") : null
      };
      if (navVisible && trig && list) {
        rec.closed = !shownEl(list);
        // a closed menu's lines are not tab stops (visibility: hidden takes them out of the order)
        rec.closedTabStops = [...list.querySelectorAll("a[href]")].filter(a => cs(a).visibility !== "hidden" && cs(a).display !== "none").length;
        trig.focus(); await sleep(80);
        rec.openOnFocus = shownEl(list);
        trig.click(); await sleep(80);
        rec.opensOnPress = shownEl(list);
        rec.expandedOpen = trig.getAttribute("aria-expanded");
        // the hover bridge (Ben, 2026-09-10): the panel floats below its word, so the gap between the
        // word's bottom and the panel's top must be spanned by the panel's own ::before strip, or the
        // pointer leaves the group on its way down and the menu closes before a click lands
        if (rec.opensOnPress) {
          const tr = trig.getBoundingClientRect(), ur = list.getBoundingClientRect();
          rec.gap = ur.top - tr.bottom;
          const bb = w.getComputedStyle(list, "::before");
          rec.bridge = bb && bb.content !== "none" ? parseFloat(bb.height) || 0 : 0;
          rec.offRight = px(ur.right - w.innerWidth); rec.offLeft = px(-ur.left);
        }
        // Escape, with focus on a line INSIDE the open menu: it shuts and focus is back on its button
        const firstLine = list.querySelector("a[href]");
        if (firstLine) firstLine.focus();
        await sleep(40);
        rec.staysOpenInside = shownEl(list);
        (d.activeElement || d.body).dispatchEvent(new w.KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
        await sleep(320);
        rec.closesOnEscape = !shownEl(list);
        rec.expandedAfterEscape = trig.getAttribute("aria-expanded");
        rec.focusBackOnEscape = d.activeElement === trig;
        // pressed open again, then focus leaves the menu: it shuts
        trig.click(); await sleep(80);
        const reopened = shownEl(list);
        away.focus && away.focus(); await sleep(320);
        rec.closesOnBlur = reopened && !shownEl(list);
        if (shownEl(list)) { trig.click(); await sleep(320); }
        rec.expandedClosed = trig.getAttribute("aria-expanded");
      }
      menus.push(rec);
    }
    if (d.activeElement && d.activeElement.blur) d.activeElement.blur();
    out.nav = {
      words: navItems().map(el => trigOf(el).textContent.replace(/\s+/g, " ").trim()),
      ids: navItems().map(el => el.getAttribute("data-word")),
      navClass: String(nav.className), cased: navItems().map(el => cs(trigOf(el)).textTransform),
      // every link the header carries, a word or a line of a menu: what must stay reachable from it
      allHrefs: [...nav.querySelectorAll("a[href]")].map(a => a.getAttribute("href")),
      visible: navVisible,
      // the header's tab stops with every menu shut (a count, reported): the lockup, the words, the buttons
      tabStops: [...d.querySelectorAll(".cc-header a[href], .cc-header button")].filter(el => !el.disabled && el.tabIndex >= 0 &&
        cs(el).visibility !== "hidden" && cs(el).display !== "none" && el.getBoundingClientRect().width > 0).length,
      menus
    };
  }

  // the menu button (Ben, 2026-09-10; under NAV_BREAK px since 2026-11-16): the hamburger in the
  // icon cluster must open the same nav as ONE column — every word, every menu inline, every line of
  // every menu drawn (FAQ and News are lines of Learn), no horizontal scroll while open — and Escape
  // must close it. Measured by clicking the button.
  const header = d.querySelector(".cc-header"), burger = header && header.querySelector(".cc-menu-button");
  if (header && burger) {
    const buttonShown = cs(burger).display !== "none" && burger.getBoundingClientRect().width > 0;
    let opened = null, expanded = null, wordsOpen = null, subsOpen = null, scrollW = null, closedOnEsc = null, lines = null, menuH = null;
    if (buttonShown) {
      burger.click();
      await sleep(60);
      opened = header.classList.contains("cc-nav-open") && !!nav && cs(nav).display !== "none";
      expanded = burger.getAttribute("aria-expanded");
      wordsOpen = navItems().filter(el => el.getBoundingClientRect().height > 0).length;
      subsOpen = nav ? [...nav.querySelectorAll(".cc-m > ul, .cc-m2 > .cc-dd")].filter(shownEl).length : 0;
      lines = nav ? [...nav.querySelectorAll("a[href]")].map(a => { const b = a.getBoundingClientRect(); return {
        text: ((a.querySelector("b") || a).textContent || "").replace(/\s+/g, " ").trim(), href: a.getAttribute("href"),
        top: px(b.top), bottom: px(b.bottom), left: px(b.left), right: px(b.right), drawn: b.width > 0 && b.height > 0 && cs(a).visibility !== "hidden" }; }) : [];
      menuH = px(header.getBoundingClientRect().height);
      scrollW = d.documentElement.scrollWidth;
      // under NAV_BREAK a menu's word is a heading over lines that are all drawn: it says expanded
      var headsSay = nav ? [...nav.querySelectorAll(".cc-m2 > .cc-m2-t")].map(t => t.getAttribute("aria-expanded")) : [];
      // every line can be brought into the window: the column scrolls inside the header when it is
      // taller than what is left under it (a sticky header cannot be scrolled by the page)
      var reachable = [];
      for (const a of (nav ? [...nav.querySelectorAll("a[href]")] : [])) {
        a.scrollIntoView({ block: "nearest" });
        const b = a.getBoundingClientRect();
        if (!(b.height > 0 && b.top >= -1 && b.bottom <= w.innerHeight + 1)) reachable.push(((a.querySelector("b") || a).textContent || "").replace(/\s+/g, " ").trim());
      }
      var unreachable = reachable;
      if (nav) nav.scrollTop = 0;
      w.scrollTo(0, 0);
      d.dispatchEvent(new w.KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      closedOnEsc = !header.classList.contains("cc-nav-open");
      if (!closedOnEsc) burger.click();
    }
    out.phoneMenu = { buttonShown, opened, expanded, wordsOpen, subsOpen, scrollW, closedOnEsc, lines, menuH, innerH: w.innerHeight,
      headsSay: typeof headsSay === "undefined" ? null : headsSay, unreachable: typeof unreachable === "undefined" ? null : unreachable,
      navOverflowY: nav ? cs(nav).overflowY : null };
  }
  // the header never wraps (2026-11-16): its row is one line at every width — the nav's items share
  // one top when the nav shows, and the row's own children (lockup, tagline, nav or menu button,
  // the icon buttons) share one line, measured with the menu closed
  if (header) {
    const row = [...header.children].filter(el => el.getBoundingClientRect().width > 0 && cs(el).position !== "absolute");
    const items = nav && cs(nav).display !== "none" ? navItems() : [];
    const mid = el => { const b = el.getBoundingClientRect(); return (b.top + b.bottom) / 2; };
    out.headerRow = {
      navShown: items.length > 0,
      navSpread: items.length ? Math.round(Math.max(...items.map(el => mid(trigOf(el)))) - Math.min(...items.map(el => mid(trigOf(el))))) : 0,
      rowLines: row.length ? Math.round(Math.max(...row.map(mid)) - Math.min(...row.map(mid))) : 0,
      height: Math.round(header.getBoundingClientRect().height),
      overlap: items.length && burger ? (() => { const last = items[items.length - 1].getBoundingClientRect().right;
        // the icon buttons beside the nav (the menus' own words are buttons too, inside it)
        const btns = [...header.querySelectorAll("button")].filter(b => !nav.contains(b) && !b.closest(".cc-viewnav") && b.getBoundingClientRect().width > 0);
        return btns.length ? Math.round(last - Math.min(...btns.map(b => b.getBoundingClientRect().left))) : null; })() : null
    };
  }

  // do the two catalog pages exist on this build? (the DATA submenu must link them when they do)
  out.pageExists = {};
  for (const p of ["/species/", "/measurements/"]) {
    try { const x = new w.XMLHttpRequest(); x.open("HEAD", p, false); x.send(); out.pageExists[p] = x.status >= 200 && x.status < 400; } catch (e) { out.pageExists[p] = false; }
  }

  // the tabsets (inside the front door's panels too: `hidden` is read, not the drawn box)
  const sets = [...d.querySelectorAll(".tabset")];
  if (sets.length) {
    out.tabsets = sets.map(ts => ({
      id: ts.id,
      tabs: [...ts.querySelectorAll(".tabrow button")].map(b => {
        const id = b.getAttribute("data-tab");
        const panel = ts.querySelector('.tabpanel[data-panel="' + id + '"]');
        return {
          id, title: b.textContent.replace(/\s+/g, " ").trim(),
          pill: (b.querySelector(".pill") || {}).textContent || null,
          selected: b.getAttribute("aria-selected") === "true",
          hidden: !panel || panel.hidden,
          drawn: !!panel && cs(panel).display !== "none",
          cards: panel ? panel.querySelectorAll(".prod-card").length : 0
        };
      }),
      // a tabset with ONE group/row draws no .tabrow at all (D2: "a single group renders no tab
      // row"; M8/M12, WS-R3) — carry the panels themselves so Python can tell that apart from a
      // real zero-selected bug rather than reading an empty `tabs` list either way
      panels: [...ts.querySelectorAll(".tabpanel")].map(p => ({ id: p.getAttribute("data-panel"), hidden: p.hidden }))
    }));
  }

  // the DATA section's height, so the front door cannot quietly grow (plan § Risks)
  // Since 2026-11-16 #datasets also holds Find's list of datasets (it was the years strip above the
  // block): that list is the panel's, one row per dataset, and is measured apart from the catalog
  const dataSec = d.getElementById("datasets");
  if (dataSec) {
    const yl = dataSec.querySelector(".fd-years"), ylR = yl ? yl.getBoundingClientRect().height : 0;
    const ylH = ylR ? ylR + parseFloat(cs(yl).marginBottom || 0) : 0;   // nothing to subtract while Find is shut
    out.dataSectionH = px(Math.max(0, dataSec.getBoundingClientRect().height - ylH));
  }

  // ── D1–D5, D9 (round 2, WS-R4): the homed row, the one search box ──────────
  if (dataSec) {
    const homed = [...dataSec.querySelectorAll(".ds-row-dataset")];
    const licOf = row => { const l = row.lastElementChild;
      return l && l.classList.contains("dl-rowlink") ? l.previousElementSibling : l; };
    out.homedRows = {
      n: homed.length,
      // D1: the format phrase is gone from every homed row (the Format filter and the dataset
      // page keep it — data-fmt stays on the <li> for the select, checked separately below)
      dsFmt: dataSec.querySelectorAll(".ds-row-dataset .ds-fmt").length,
      // D2: the licence chip is the row's LAST data column, and its text is never the raw "custom" id.
      // A row with zips ends in its Download control (2026-11-16), drawn after the licence, so the
      // licence is then the element just before it: still in the same place on every row.
      licMissing: homed.filter(row => { const l = licOf(row); return !l || !l.classList.contains("cc-chip-lic"); }).length,
      licCustomText: homed.filter(row => (licOf(row) || {}).textContent === "custom").length,
      dlNotLast: homed.filter(row => row.querySelector(".dl-rowlink") && row.lastElementChild !== row.querySelector(".dl-rowlink")).length,
      // D3: a drawn expander is never empty (self-consistent with n_var/n_taxa > 0 gating the
      // template; the source record is cross-checked in Python from the SAME datasets.json)
      varsTotal: dataSec.querySelectorAll(".ds-vars").length,
      varsEmpty: [...dataSec.querySelectorAll(".ds-vars")].filter(v => !v.querySelector(".chips .cc-chip")).length
    };
    // D4/D5 (umbrella D9): exactly one input[type=search] in the whole data section, full width
    const searches = [...dataSec.querySelectorAll('input[type="search"]')];
    const doorBox = d.getElementById("door-search");
    out.doorSearch = {
      n: searches.length,
      hasDsQ: !!d.getElementById("ds-q"),
      boxW: doorBox ? px(doorBox.getBoundingClientRect().width) : null,
      containerW: doorBox ? px(doorBox.closest(".cc-container").getBoundingClientRect().width) : null
    };
  }

  // ── the species catalog (plan 2026-09-09 § S3; issue #30 D7 A, D10 B, D17) ─
  // The index: the counts, the class list, the matrix's shape, all read back from the page's own
  // inline record so the check compares the drawing with the data it was drawn from.
  const spData = d.getElementById("sp-data");
  if (spData) {
    let rec = null; try { rec = JSON.parse(spData.textContent); } catch (e) {}
    const page = d.querySelector(".calm-page");
    const view = d.querySelector('#ts-species .tabrow > button[aria-selected="true"]');
    out.species = {
      h1: (d.querySelector(".calm-cathead h1, .bd-head h1") || {}).textContent || null,
      // the finder (front door v2, assets/finder.js): Groups and All species, with a preview beside
      // the list. Its record is /species/finder.json, read here so the drawing is compared with it.
      finder: (() => {
        const cf = d.getElementById("cf"); if (!cf) return null;
        let F = null; try { const x = new w.XMLHttpRequest(); x.open("GET", cf.getAttribute("data-src"), false); x.send(); F = JSON.parse(x.responseText); } catch (e) {}
        // the taxa that are not species rows (a genus, a family …): /species/finder-taxa.json, what a search also lists
        let T = null; try { const x = new w.XMLHttpRequest(); x.open("GET", cf.getAttribute("data-taxa"), false); x.send(); T = JSON.parse(x.responseText); } catch (e) {}
        const hi = [...d.querySelectorAll("#cf-hi .cf-r")];
        const head = u => { try { const x = new w.XMLHttpRequest(); x.open("HEAD", u, false); x.send(); return x.status; } catch (e) { return 0; } };
        const pv = d.getElementById("cf-pv"), isY = el => [tok("--cta-bg"), "rgb(255,205,0)"].indexOf(cs(el).backgroundColor.replace(/\s/g, "")) >= 0;
        return {
          n: ((d.getElementById("cf-n") || {}).textContent || "").trim(), count: ((d.querySelector(".bd-count") || {}).textContent || "").trim(),
          treeHead: ((d.querySelector(".sp-pane-tree h2") || {}).textContent || "").trim(),
          groups: d.querySelectorAll("#cf-list .cf-gc").length,
          // the list's rows are species (each carries its key); the other taxa a search finds are
          // listed apart, in #cf-hi, each a link to its own page
          rows: [...d.querySelectorAll("#cf-list .cf-r[data-k]")].map(a => a.textContent.replace(/\s+/g, " ").trim().slice(0, 90)),
          rowsInHigher: d.querySelectorAll("#cf-hi .cf-r[data-k]").length,
          higher: hi.map(a => { const tx = sel => ((a.querySelector(sel) || {}).textContent || "").replace(/\s+/g, " ").trim();
            const ds = a.querySelector(".cf-ds"), sm = ds && ds.querySelector("small");
            return { name: tx(".cf-nm b"), sub: tx(".cf-nm > span"), holds: ds ? ds.textContent.replace(sm ? sm.textContent : "", "").replace(/\s+/g, " ").trim() : "", href: a.getAttribute("href") }; }),
          higherHead: ((d.querySelector("#cf-hi h2") || {}).textContent || "").replace(/\s+/g, " ").trim(),
          higherAfterList: (() => { const b = d.getElementById("cf-hi"), last = [...d.querySelectorAll("#cf-list .cf-r[data-k]")].pop();
            return !b || !last || !!(last.compareDocumentPosition(b) & 4); })(),
          higherStatus: hi.length ? head(hi[0].href) : null,
          recTaxa: T ? T.length : null,
          recGroups: F && F.groups ? F.groups.length : null, recRows: F && F.rows ? F.rows.length : null,
          recSpecies: F && F.counts ? F.counts.species_observed : null,
          pvShown: !!pv && !pv.hidden && cs(pv).display !== "none", pvTitle: pv && pv.querySelector("h2") ? pv.querySelector("h2").textContent.trim() : null,
          yellow: [...d.querySelectorAll(".sp-cat a, .sp-cat button")].filter(el => isY(el) && el.getBoundingClientRect().width > 0).map(el => el.textContent.trim()),
          q: (d.getElementById("door-q") || {}).value || ""
        };
      })(),
      rec: rec && rec.counts,
      rows: rec && rec.mx ? rec.mx.rows.length : null,
      cols: rec && rec.mx ? rec.mx.cols.length : null,
      cells: d.querySelectorAll(".sp-mx .sp-c").length,
      view: view ? view.getAttribute("data-tab") : null,
      views: [...d.querySelectorAll("#ts-species .tabrow > button")].map(b => b.getAttribute("data-tab")),
      // only the chosen view's panel showing
      panelsShown: [...d.querySelectorAll("#ts-species > .tabpanel")].filter(p => !p.hidden).length,
      // the hierarchy (main's icicle, a tab again since 2026-11-17): what is drawn in it as the page landed
      ice: (() => { const sv = d.getElementById("sp-ice"); return sv ? {
        rects: sv.querySelectorAll("rect").length, labels: sv.querySelectorAll("text").length,
        w: px(sv.getBoundingClientRect().width), crumb: d.querySelectorAll("#sp-crumb button").length,
        seg: d.querySelectorAll(".sp-seg button").length, inPanel: (sv.closest(".tabpanel") || { getAttribute: () => null }).getAttribute("data-panel") } : null; })(),
      // nothing is drawn into a block that is never shown (review S-26: main's class list and icicle
      // were drawn into a hidden .cf-legacy)
      neverShown: d.querySelectorAll(".cf-legacy").length,
      // the page's own content (header to its last row, the site footer excluded), at this width
      contentH: page ? px(page.getBoundingClientRect().bottom + w.scrollY) : 0,
      treeRoots: d.querySelectorAll('#sp-tree > ul > li[role="treeitem"]').length,
      hits: d.querySelectorAll("#sp-tree .sp-hit").length,
      // nothing in --warn. A yellow BUTTON is not a warning: in the dark theme --warn and --cta-bg are
      // one colour, so the preview's one yellow button is counted as yellow (finder.yellow), not here
      warnEls: [...d.querySelectorAll(".sp-cat *")].filter(el => {
        const st = cs(el), w2 = out.warn, bg = st.backgroundColor.replace(/\s/g, "");
        if (el.matches("a, button") && bg === tok("--cta-bg")) return false;
        return st.color.replace(/\s/g, "") === w2 || bg === w2;
      }).map(el => String(el.className || el.tagName)).slice(0, 6)
    };

    // WS-F4: a phylum/class row's silhouette (.sp-tsil, 18 px tall — under the 20 px .sp-tw button,
    // the row's tallest fixed element) must not change the row's height; hidden vs shown on the
    // SAME row proves it rather than a remembered pixel count. The tree is a view: show it while
    // measuring, then put the panels back as they were.
    const silEl = d.querySelector("#sp-tree .sp-tr .sp-tsil");
    if (silEl) {
      const tp = silEl.closest(".tabpanel"), was0 = tp && tp.hidden;
      if (tp) tp.hidden = false;
      const row = silEl.closest(".sp-tr");
      out.species.treeRowH = px(row.getBoundingClientRect().height);
      const was = silEl.style.display;
      silEl.style.display = "none";
      out.species.treeRowHNoSil = px(row.getBoundingClientRect().height);
      silEl.style.display = was;
      if (tp) tp.hidden = was0;
    }
    // the hierarchy is drawn when its tab is pressed (a hidden <svg> has no width to draw to), zooms on
    // a band and climbs back by the breadcrumb; then the view the page landed on is chosen again
    const tabOf = id => d.querySelector('#ts-species .tabrow > button[data-tab="' + id + '"]');
    const hb = tabOf("hierarchy"), sv = d.getElementById("sp-ice");
    if (hb && sv) {
      const was = out.species.view, n = () => sv.querySelectorAll("rect").length;
      hb.click(); await sleep(120);
      const pressed = { view: (d.querySelector('#ts-species .tabrow > button[aria-selected="true"]') || hb).getAttribute("data-tab"),
        rects: n(), w: px(sv.getBoundingClientRect().width), crumb: d.querySelectorAll("#sp-crumb button").length,
        panels: [...d.querySelectorAll("#ts-species > .tabpanel")].filter(p => !p.hidden).length };
      const g = sv.querySelector("g");
      if (g) { g.dispatchEvent(new w.MouseEvent("click", { bubbles: true })); await sleep(60); pressed.zoomCrumb = d.querySelectorAll("#sp-crumb button").length; }
      const c0 = d.querySelector("#sp-crumb button");
      if (c0) { c0.click(); await sleep(60); pressed.backCrumb = d.querySelectorAll("#sp-crumb button").length; pressed.backRects = n(); }
      out.species.icePressed = pressed;
      const back = tabOf(was); if (back && was !== "hierarchy") { back.click(); await sleep(120); }
    }
  }

  // one taxon page: the rows, the lineage and the Explorer link against the page's own record
  const spStrip = d.getElementById("sp-strip-data");
  if (spStrip) {
    let S = null; try { S = JSON.parse(spStrip.textContent); } catch (e) {}
    const numc = s2 => +String(s2 || "").replace(/,/g, "").match(/\d+/);
    const strips = [...d.querySelectorAll("svg.sp-strip")];
    const page = d.querySelector(".calm-page");
    out.speciesPage = {
      key: S && S.key,
      recRows: S ? S.rows.map(r => ({ name: r.s, n: r.n })) : [],
      rows: [...d.querySelectorAll(".sp-dsrow")].map(li => ({
        name: (li.querySelector(".sp-l1 a") || {}).textContent || "",
        n: numc((li.querySelector(".sp-meta") || {}).textContent)
      })),
      lineage: [...d.querySelectorAll(".sp-lineage a")].map(a => ({ name: a.textContent.trim(), href: a.getAttribute("href") })),
      here: (d.querySelector(".sp-lineage .sp-here") || {}).textContent || null,
      explore: [...d.querySelectorAll('a[href*="/explore/"]')].map(a => a.getAttribute("href")),
      // one strip per "Observed in" row, each DRAWN (`.sp-drawn`) — not merely populated:
      // `.sp-strip:not([viewBox])` lowercases to `[viewbox]` in an HTML document and never matches
      // SVG's camelCase attribute, so the strip was display:none with 93 rects in it and every
      // count still agreed (measured 2026-09-09)
      stripRows: strips.filter(s => s.classList.contains("sp-drawn") && s.querySelector("rect")).length,
      stripH: strips.length ? Math.min(...strips.map(s => px(s.getBoundingClientRect().height))) : 0,
      stats: [...d.querySelectorAll(".sp-stat > div")].map(el => el.querySelector("dt").textContent.trim()),
      waysTabset: !!d.querySelector("#ways .tabset"),
      waysLine: d.querySelectorAll(".calm-ways > a").length,
      folds: d.querySelectorAll(".calm-folds > .calm-fold").length,
      foldsOpen: [...d.querySelectorAll(".calm-folds > .calm-fold")].filter(f => f.open).map(f => f.id),
      // every fold is titled with its answer (D14)
      foldsNoAns: [...d.querySelectorAll(".calm-folds > .calm-fold")]
        .filter(f => !((f.querySelector(":scope > summary .calm-ans") || {}).textContent || "").trim()).map(f => f.id),
      subnav: d.querySelectorAll(".calm-page nav:not(.calm-crumb):not(.sp-lineage)").length,
      h1: (d.querySelector(".calm-name h1") || {}).textContent || "",
      h1Italic: d.querySelector(".calm-name h1") ? cs(d.querySelector(".calm-name h1")).fontStyle : "",
      contentH: page ? px(page.getBoundingClientRect().bottom + w.scrollY) : 0
    };
  }

  // ── faces: the mark, the picture, the sentence, the glance, the ladder (plan 2026-09-11 § D1–D5, D9)
  // Read back from the page's OWN inline #sp-size-data where there is one, so the check compares
  // the drawing with the payload it was drawn from and never with a number typed here. The ladder
  // lives in the closed How big fold: it is opened while its labels are measured, then closed.
  if (d.querySelector(".sp-pg")) {
    const sil = d.querySelector(".sp-sil"), ph = d.querySelector(".sp-photo img");
    const box = el => { const b = el.getBoundingClientRect(); return { x: px(b.x), y: px(b.y), w: px(b.width), h: px(b.height) }; };
    let size = null;
    const sd = d.getElementById("sp-size-data");
    if (sd) { try { size = JSON.parse(sd.textContent); } catch (e) {} }
    const hb = d.getElementById("how-big"), hbWas = hb && hb.open;
    if (hb) hb.open = true;
    // every label the ladder draws, with its box, so Python can look for an overlapping pair
    const ladder = d.getElementById("sp-ladder");
    // …each tagged with the <g> it belongs to: a reference's name and its length are stacked on
    // purpose, so only labels from DIFFERENT groups may not overlap
    const lgroups = ladder ? [...ladder.querySelectorAll("g")] : [];
    const labels = ladder && ladder.classList.contains("sp-drawn")
      ? [...ladder.querySelectorAll("text")].map(t => Object.assign(box(t), {
          t: t.textContent.trim(),
          g: lgroups.indexOf(t.closest("g"))
        }))
      : [];
    out.faces = {
      sil: sil ? Object.assign(box(sil), { label: sil.getAttribute("aria-label"), role: sil.getAttribute("role"),
                                           fill: cs(sil).fill.replace(/\s/g, "") }) : null,
      photo: ph ? Object.assign(box(ph), { alt: ph.getAttribute("alt"), w0: ph.getAttribute("width"),
                                           h0: ph.getAttribute("height"), loading: ph.getAttribute("loading"),
                                           pos: cs(ph).objectPosition }) : null,
      // D11 A: the head's ONE picture — the photo, or the silhouette where there is no photo
      pics: d.querySelectorAll(".calm-head .calm-pic").length,
      silPic: !!d.querySelector(".calm-head .sp-sil-pic svg"),
      nc: !!d.querySelector(".sp-photo-fig .cc-chip"),
      bars: [...d.querySelectorAll(".sp-glance .sp-bar")].map(b => px(b.getBoundingClientRect().width)),
      glanceNone: !!d.querySelector(".sp-glance-none"),
      sentParts: [...d.querySelectorAll(".sp-sent > span")].map(s => s.className),
      badges: [...d.querySelectorAll(".sp-sent > .cc-src")].map(s => s.className),
      legendCount: d.querySelectorAll(".sp-legend").length,
      credits: [...d.querySelectorAll(".sp-credit")].map(p => p.textContent.replace(/\s+/g, " ").trim().slice(0, 90)),
      statWords: [...d.querySelectorAll(".sp-stat > div")].map(el => el.querySelector("dt").textContent.trim()),
      size,
      ladderDrawn: !!(ladder && ladder.classList.contains("sp-drawn")),
      ladderMarks: ladder ? ladder.querySelectorAll(".sp-mark, .sp-markdot").length : 0,
      ladderRefs: ladder ? ladder.querySelectorAll(".sp-rlab").length : 0,
      labels,
      besideDrawn: !!(d.querySelector(".sp-beside") && d.querySelector(".sp-beside").classList.contains("sp-drawn")),
      plateImg: !!d.querySelector(".sp-plate-img img"),
      early: d.querySelectorAll(".sp-early li").length,
      howBig: !!hb && !!sd
    };
    if (hb) hb.open = hbWas;
  }

  // every .sp-url is ONE line, and elided from the middle rather than wrapped or cut
  out.spUrls = [...d.querySelectorAll(".sp-url")].map(a => ({
    h: px(a.getBoundingClientRect().height),
    lh: px(parseFloat(cs(a).lineHeight) || 0),
    full: (a.getAttribute("data-full") || "").length,
    shown: (a.textContent || "").length,
    elided: (a.textContent || "").indexOf("\u2026") >= 0,
    overflow: a.scrollWidth > a.clientWidth + 1,
    t: (a.textContent || "").trim().slice(0, 48)
  }));

  // one ERDDAP listing: count each tabledap page link. On a dataset page that listing is the
  // "Every endpoint" fold (#access); the ways line above it names the first id once more ON
  // PURPOSE (issue #30 D12/D16: a shortlist of the ways in), so it is not the listing counted here.
  // The catalog (/datasets/) has no listing: each row's ways line names its dataset's first id.
  const tabledap = {};
  // (the redesigned page's "Get the data" card names the dataset's ERDDAP tables once more, as its
  // shortlist; the listing is still the fold, so the count is scoped to #access on both pages)
  if (!d.querySelector("main.ds-cat")) [...(d.querySelector("main.ds-page #access, main.dp-page #access") || d).querySelectorAll('a[href*="tabledap/"]')].forEach(a => {
    const m = /tabledap\/([^.?#\/]+)\.html(?:$|[?#])/.exec(a.getAttribute("href") || "");
    if (m) tabledap[m[1]] = (tabledap[m[1]] || 0) + 1;
  });
  out.tabledap = tabledap;

  // ── the measurements catalog (plan 2026-09-10 § D5, D6; WS-M4) ────────────
  // The index's figures are read back against the page's OWN inline record, so the check compares
  // the drawing with the data it was drawn from and never against a number typed here.
  const mmData = d.getElementById("mm-data");
  const mmStrip = d.getElementById("mm-strip-data");
  // issue #30 (calm re-cut): a measurement page's folds are read CLOSED on load (docHeight above is
  // the page with nothing open), then every .calm-fold is opened and the figures inside are read
  // once they have drawn at their fold's width. "Other ways to say why" is not a .calm-fold, so it
  // stays as the page left it.
  const mmFoldsProbe = () => {
    const folds = [...d.querySelectorAll("details.calm-fold")];
    out.mmFolds = {
      ids: folds.map(f => f.id || "?"),
      openOnLoad: folds.filter(f => f.open).map(f => f.id || "?"),
      // D14: every fold is titled with its answer
      noAnswer: folds.filter(f => !((f.querySelector(":scope > summary .calm-ans") || {}).textContent || "").trim())
        .map(f => f.id || "?"),
      titles: folds.map(f => {
        const c = f.querySelector(":scope > summary").cloneNode(true);
        [...c.querySelectorAll(".calm-ans, .cc-i")].forEach(x => x.remove());
        return c.textContent.replace(/\s+/g, " ").trim();
      }),
      measuredOpen: !!d.querySelector("section#measured") && !d.querySelector("section#measured").closest("details"),
      waysLine: d.querySelectorAll(".calm-ways > a").length,
      headPic: !!d.querySelector(".calm-head .mmf-what")
    };
    folds.forEach(f => { f.open = true; });
  };
  const mmPageProbe = () => {
  if (mmStrip) {
    let S = null; try { S = JSON.parse(mmStrip.textContent); } catch (e) {}
    let DP = null; try { DP = JSON.parse(d.getElementById("mm-depth-data").textContent); } catch (e) {}
    let MO = null; try { MO = JSON.parse(d.getElementById("mm-months-data").textContent); } catch (e) {}
    // issue #30: one strip per series, in that series' own row of "Measured in"
    const strips = [...d.querySelectorAll("svg.mm-strip[data-i]")], dep = d.getElementById("mm-depth"), mon = d.getElementById("mm-months");
    // a per-cast key (grain "sample") has no depth figure at all, so #mm-depth may be absent
    const bars = dep ? [...dep.querySelectorAll(".mm-b")] : [];
    out.mmPage = {
      key: S && S.key,
      recRows: S ? S.rows.length : 0,
      // DRAWN, not merely populated — the `[viewBox]` trap the species strip hit on 2026-09-09
      stripDrawn: strips.length > 0 && strips.every(x => x.classList.contains("mm-drawn")),
      stripH: strips.length ? Math.min(...strips.map(x => px(x.getBoundingClientRect().height))) : 0,
      stripRows: strips.filter(x => x.classList.contains("mm-drawn")).length,
      stripRects: strips.reduce((a, x) => a + x.querySelectorAll("rect").length, 0),
      recRects: S ? S.rows.reduce((a, r) => a + Object.keys(r.y || {}).filter(k => r.y[k] > 0).length, 0) : 0,
      depthBands: dep ? dep.querySelectorAll(".mm-lb").length : 0,
      recBands: DP ? (DP.bands || []).length : 0,
      depthBars: bars.length,
      // an end label that hangs outside its own column is the failure this padding exists for
      depthLabelsOut: bars.filter(b => {
        const sp = b.querySelector("span");
        if (!sp) return false;
        return sp.getBoundingClientRect().right > b.closest(".mm-pair").getBoundingClientRect().right + 1;
      }).length,
      depthLegend: d.querySelectorAll("#mm-depth-legend span").length,
      monthCells: mon.querySelectorAll(".mm-c").length,
      monthRows: MO ? MO.rows.length : 0,
      monthLetters: mon.querySelectorAll(".mm-ml").length,
      rows: [...d.querySelectorAll(".mm-dsrow")].map(li => ({
        name: (li.querySelector(".mm-l1 a") || {}).textContent || "",
        dot: !!li.querySelector(".mm-dot")
      })),
      explore: [...d.querySelectorAll('a[href*="/explore/"]')].map(a => a.getAttribute("href")),
      // ── WS-R3 (plan 2026-09-15 § M1, M7–M9, M11–M13, § D8) ──────────────────
      noFlagnote: !d.querySelector(".mm-flagnote"),
      statFlag: !!d.querySelector(".mm-stat-flag"),
      noWhat: !d.getElementById("what"),
      noCol: !d.getElementById("mmf-col"),
      howPanels: (() => {
        const ts = d.getElementById("ts-how");
        if (!ts || !ts.classList.contains("tabset")) return null;
        const row = ts.querySelector(".tabrow");
        return { panels: ts.querySelectorAll(".tabpanel").length,
                 buttons: row ? row.querySelectorAll("button").length : 0, tabrow: !!row };
      })(),
      qualChips: d.querySelectorAll(".mm-qual .qline .cc-chip").length,
      waysTabset: !!d.querySelector(".mm-col-ways .tabset"),
      waysAppButtons: d.querySelectorAll(".mm-col-ways .cc-btn").length
    };
  }
  // every .mm-url is ONE line, elided from the middle rather than wrapped or cut
  out.mmUrls = [...d.querySelectorAll(".mm-url")].map(a => ({
    h: px(a.getBoundingClientRect().height),
    lh: px(parseFloat(cs(a).lineHeight) || 0),
    full: (a.getAttribute("data-full") || "").length,
    shown: (a.textContent || "").length,
    elided: (a.textContent || "").indexOf("…") >= 0,
    overflow: a.scrollWidth > a.clientWidth + 1,
    t: (a.textContent || "").trim().slice(0, 48)
  }));
  };

  if (mmData) {
    let rec = null; try { rec = JSON.parse(mmData.textContent); } catch (e) {}
    const tl = d.getElementById("mm-tl"), mx = d.querySelector(".mm-mx");
    const cells = mx ? [...mx.querySelectorAll(".mm-cell")] : [];
    // issue #30 D8 A / D10 B: the list is the default view and the ONE search (#door-q) filters it
    // and the timeline alike; a search reads both
    // (front door v2: the list is the finder's — #cf-list's rows, By category or A–Z — and #door-q is
    // its search box; main's own list is kept in the page unseen so measurements.js runs unchanged)
    // a row is in view unless it is inside a closed category (issue #30 D8: the categories are closed
    // groups, each a button; `hidden` is the state)
    const inView = a => !a.closest("[hidden]") && a.getBoundingClientRect().height > 0;
    const catsNow = () => [...d.querySelectorAll("#cf-list .cf-grp[data-cat]")].map(g => {
      const b = g.querySelector("h3 > button.cf-gb"), body = b && d.getElementById(b.getAttribute("aria-controls"));
      return { cat: g.getAttribute("data-cat"), rows: g.querySelectorAll(".cf-r").length,
        shown: [...g.querySelectorAll(".cf-r")].filter(inView).length,
        n: +((g.querySelector(".cf-gn") || {}).textContent || "").replace(/ of .*$/, "").replace(/[^0-9]/g, ""),
        button: !!b && b.getAttribute("type") === "button", says: b ? b.getAttribute("aria-expanded") : null,
        controls: !!body && g.contains(body), bodyHidden: body ? body.hidden : null,
        hint: ((g.querySelector(".cf-gtop") || {}).textContent || "").trim().length };
    });
    // the row the preview is showing: in view, hidden inside a closed category, or none (the pane says to choose)
    const pvRow = () => { const a = d.querySelector("#cf-list .cf-r.on"); return a ? (inView(a) ? "in view" : "hidden") : null; };
    const read = () => ({
      rows: tl.querySelectorAll(".mm-nm").length,
      list: d.querySelectorAll("#cf-list .cf-r").length,
      shown: [...d.querySelectorAll("#cf-list .cf-r")].filter(inView).length,
      cats: catsNow().map(c => ({ cat: c.cat, rows: c.rows, shown: c.shown, says: c.says })),
      pvRow: pvRow(),
      n: ((d.getElementById("cf-n") || {}).textContent || "").trim()
    });
    out.mm = {
      h1: (d.querySelector(".calm-cathead h1, .bd-head h1") || {}).textContent || null,
      // the finder's By category list: one section per category, its count and its rows
      listCats: catsNow(),
      listRows: d.querySelectorAll("#cf-list .cf-r").length,
      listInView: [...d.querySelectorAll("#cf-list .cf-r")].filter(inView).length,
      pvRow: pvRow(),
      pvTitle: ((d.querySelector("#cf-pv h2") || {}).textContent || "").trim(),
      q: (d.getElementById("door-q") || {}).value || "",
      // main's list rendered in Liquid is what a reader WITHOUT JavaScript gets (<noscript>); with
      // scripting it must not also be built and hidden (it was: 104 rows in a .cf-legacy block)
      neverShown: d.querySelectorAll(".cf-legacy, #mm-cats, #mm-unified").length,
      // (read from the page as served: the finder replaces the list's host, <noscript> and all, when it runs)
      noscriptRows: (() => { try { const x = new w.XMLHttpRequest(); x.open("GET", w.location.pathname, false); x.send();
        return (x.responseText.match(/<noscript>[\s\S]*?<\/noscript>/g) || []).reduce((a, t) => a + (t.match(/<li class="mm-row"/g) || []).length, 0); } catch (e) { return null; } })(),
      listKeys: [...d.querySelectorAll("#cf-list .cf-r[data-k]")].map(a => a.getAttribute("data-k")),
      // every row names the datasets that measure it (identity is never a dot alone)
      listRowsNoName: [...d.querySelectorAll("#cf-list .cf-r")].filter(a => {
        const c = (a.querySelector(".cf-ds") || { cloneNode: () => ({ querySelectorAll: () => [], textContent: "" }) }).cloneNode(true);
        [...c.querySelectorAll("small")].forEach(x => x.remove());
        return !(c.textContent || "").trim(); }).length,
      countSaid: ((d.getElementById("cf-n") || {}).textContent || "").trim(),
      pvShown: (() => { const pv = d.getElementById("cf-pv"); return !!pv && !pv.hidden && cs(pv).display !== "none"; })(),
      viewTabs: [...d.querySelectorAll("#ts-mm > .tabrow > button")].map(b => b.getAttribute("data-tab")),
      view: ((d.querySelector('#ts-mm > .tabrow > button[aria-selected="true"]') || { getAttribute: () => null }).getAttribute("data-tab")),
      listShown: !((d.querySelector('#ts-mm > .tabpanel[data-panel="cat"]') || { hidden: true }).hidden),
      rec: rec && rec.counts,
      cats: rec ? rec.cats.length : 0,
      ds: rec ? rec.ds.length : 0,
      recSeries: rec ? rec.rows.reduce((a, r) => a + (r.se || []).length, 0) : 0,
      tlRows: tl.querySelectorAll(".mm-nm").length,
      tlBars: tl.querySelectorAll(".mm-bar").length,
      tlCats: tl.querySelectorAll(".mm-cat").length,
      tlWidth: px(tl.getBoundingClientRect().width),
      tlScroller: px(tl.parentElement.clientWidth),
      tlOverflowX: cs(tl.parentElement).overflowX,
      mxCells: cells.length,
      mxFilled: cells.filter(c => !c.classList.contains("mm-z")).length,
      mxSum: cells.reduce((a, c) => a + (parseInt(String(c.textContent).replace(/,/g, ""), 10) || 0), 0),
      mxHeads: mx ? mx.querySelectorAll(".mm-mh").length : 0,
      mxRows: mx ? mx.querySelectorAll(".mm-rl2").length : 0,
      dsRows: d.querySelectorAll("#mm-dslist li").length,
      legend: d.querySelectorAll("#mm-legend span").length,
      tlRole: tl.getAttribute("role"),
      tipRole: (d.getElementById("mm-ttip") || {}).getAttribute ? d.getElementById("mm-ttip").getAttribute("role") : null,
      // a bar with no dataset name in its row would be identity by colour alone
      barsWithoutName: [...tl.querySelectorAll(".mm-bar")].length -
                       [...tl.querySelectorAll(".mm-ds span")].length
    };
    const q = d.getElementById("door-q");
    // a press on a category's button opens it IN PLACE (the button does not move and keeps the focus),
    // puts its first row in the preview, and a second press shuts it. Only on the page as it loads By
    // category with no search; the search below then starts from every category closed again.
    const b0 = d.querySelector("#cf-list .cf-grp h3 > button.cf-gb");
    if (b0 && out.mm.view === "cat" && !out.mm.q) {
      const top = () => px(b0.getBoundingClientRect().top + w.scrollY), t0 = top();
      b0.focus(); b0.click(); await sleep(60);
      const c1 = catsNow();
      out.mm.press = { cat: c1[0].cat, says: c1[0].says, shown: c1[0].shown, rows: c1[0].rows, others: c1.slice(1).filter(c => c.shown || c.says === "true").length,
        moved: top() - t0, focusKept: d.activeElement === b0, pvRow: pvRow(), pvTitle: ((d.querySelector("#cf-pv h2") || {}).textContent || "").trim(),
        colHeads: [...d.querySelectorAll("#cf-list .cf-colh")].filter(inView).length };
      b0.click(); await sleep(60);
      out.mm.press.again = { says: catsNow()[0].says, shown: catsNow()[0].shown, pvRow: pvRow() };
    }
    const MM_TERMS = ["nitrate", "NTRAZZXX", "µmol/kg", "METS"];
    const mtype = t => new Promise(res => {
      q.value = t;
      q.dispatchEvent(new w.Event("input", { bubbles: true }));
      setTimeout(() => { out.mm.search = out.mm.search || {}; out.mm.search[t] = read(); res(); }, 80);
    });
    const q0 = q.value;
    return MM_TERMS.reduce((p, t) => p.then(() => mtype(t)), Promise.resolve())
      .then(() => { q.value = ""; q.dispatchEvent(new w.Event("input", { bubbles: true })); return sleep(80); })
      // the box cleared: what the search opened is shut again
      .then(() => { out.mm.cleared = read(); q.value = q0; q.dispatchEvent(new w.Event("input", { bubbles: true })); return out; });
  }

  // ── measurement faces: the row, the sentence, the collapsed why, the two charts ──────────
  // (plan 2026-09-11 "Measurement faces …" § D1–D7, § Verification MF5). Everything is read back
  // against the page's OWN #mm-face payload, so the check compares the drawing with the data it
  // was drawn from and never with a number typed here.
  const mfProbe = () => {
  const mf = d.getElementById("mm-face");
  if (mf) {
    let P = null;
    try { P = JSON.parse(mf.textContent); } catch (e) {}
    const box = el => { const b = el.getBoundingClientRect(); return { x: px(b.x), y: px(b.y), w: px(b.width), h: px(b.height) }; };
    const det = d.querySelector("details.mmf-alts-det");
    const scale = d.getElementById("mmf-scale"), anom = d.getElementById("mmf-anom");
    // every mark label the familiar scale draws, with its box, so Python can look for a pair that
    // overlaps — the greedy row assignment in measurements.js is the only thing preventing it
    const marks = scale && scale.classList.contains("mmf-drawn")
      ? [...scale.querySelectorAll("text.mmf-mark")].map(t => Object.assign(box(t), { t: t.textContent.trim() }))
      : [];
    out.mfaces = {
      payload: P,
      kind: P && P.kind,
      // issue #30: the face row's What column is the head's ONE picture; How and Why are folds
      what: !!d.querySelector(".calm-head .mmf-what"),
      folds: [...d.querySelectorAll("details.calm-fold")].map(f => f.id),
      mols: [...d.querySelectorAll(".mmf-what .mmf-mol")].map(s => Object.assign(box(s), {
        label: s.getAttribute("aria-label"), role: s.getAttribute("role"),
        paths: s.querySelectorAll("path,line,circle,polygon,text").length
      })),
      mini: !!(d.getElementById("mmf-mini") && d.getElementById("mmf-mini").classList.contains("mmf-drawn")),
      stands: (d.querySelector(".mmf-stands") || {}).textContent || null,
      // the ids row of the head: a stand-in must show none of the face it borrows
      ids: (d.querySelector(".mm-ids") || {}).textContent || "",
      plat: d.querySelectorAll(".mmf-how .mmf-pg svg").length,
      pins: d.querySelectorAll(".mmf-pin").length,
      spark: !!(d.getElementById("mmf-spark") && d.getElementById("mmf-spark").classList.contains("mmf-drawn")),
      // round 2 (WS-R2, plan § D4): a figure has a ramp or an axis, labels on it, and a hover
      sparkTicks: d.querySelectorAll("#mmf-spark text.mmf-tick").length,
      sparkStretch: (d.getElementById("mmf-spark") || {}).getAttribute
        ? d.getElementById("mmf-spark").getAttribute("preserveAspectRatio") : null,
      ramp: d.querySelectorAll(".mmf-what svg.mmf-ramp").length,
      rampGrad: d.querySelectorAll(".mmf-what svg.mmf-ramp linearGradient").length,
      rampMarks: d.querySelectorAll(".mmf-what svg.mmf-ramp text.mmf-mklab").length,
      // the pin's href, so the check can see it reaches calcofi.org and not a column that is not there
      pinHrefs: [...d.querySelectorAll("#how a.mmf-pin")].map(a => a.getAttribute("href")),
      tip: d.querySelectorAll("body > .mmf-tip").length,
      // the history's own scale per row: a ± label beside every band, and the toggle above it
      anomPm: anom ? [...anom.querySelectorAll("text.mmf-tick")].filter(t => t.textContent.trim().startsWith("\u00b1")).length : 0,
      anomToggle: d.querySelectorAll('input[name="mmf-hsc"]').length,
      anomLegend: d.querySelectorAll("#mmf-anom-legend > span").length,
      // the sentence: prose with a badge per part, and NO NERC clause (the What column has it)
      sentParts: [...d.querySelectorAll(".mmf-sent > span[class^='s-']")].map(s => s.className),
      sentBadges: d.querySelectorAll(".mmf-sent .cc-src").length,
      legend: d.querySelectorAll(".mmf-legend > span").length,
      det: det ? { open: det.open, summary: det.querySelector("summary").textContent.trim(),
                   items: det.querySelectorAll(".mmf-alts > li").length } : null,
      scaleDrawn: !!(scale && scale.classList.contains("mmf-drawn")),
      marks,
      anomDrawn: !!(anom && anom.classList.contains("mmf-drawn")),
      // one row per band: the band label and the count beside it
      anomRows: anom ? anom.querySelectorAll("text.mmf-lab").length : 0,
      anomBars: anom ? anom.querySelectorAll("rect[fill]:not(.mmf-nino)").length : 0,
      col: !!(d.getElementById("mmf-col") && d.getElementById("mmf-col").classList.contains("mmf-drawn")),
      colRows: d.querySelectorAll("#mmf-col .mmf-dl").length,
      eovQs: d.querySelectorAll(".mmf-eov .mmf-qs li").length,
      // the folds' titles, in order (issue #30: the sections became folds titled with their answer)
      heads: [...d.querySelectorAll("details.calm-fold > summary")].map(sm => {
        const c = sm.cloneNode(true);
        [...c.querySelectorAll(".calm-ans, .cc-i")].forEach(x => x.remove());
        return c.textContent.replace(/\s+/g, " ").trim();
      }),
      // nothing on the page may be wider than the page (each chart scrolls in its OWN wrapper)
      wide: [...d.querySelectorAll(".mmf-what, .mmf-sent, .mmf-alts, .mmf-card, .mmf-eov")]
        .filter(e => e.scrollWidth > e.clientWidth + 1)
        .map(e => String(e.className) + " " + e.scrollWidth + ">" + e.clientWidth)
    };
  }
  };
  if (mmStrip) {
    mmFoldsProbe();
    return new Promise(res => setTimeout(() => {
      try { mmPageProbe(); mfProbe(); } catch (e) { out.mmError = String(e); }
      res(out);
    }, 700));
  }
  mmPageProbe();
  mfProbe();

  // ── the one search over the three indexes (plan 2026-09-10 § D7 (3)) ───────
  // assets/door-search.js fetches the three records on the FIRST focus, so the box has to be
  // driven, not read: focus it, type each term, and count what came back per group. The promise
  // is what the probe returns — the host resolves whatever `done()` is handed.
  // (front door v2 gave the finders' own search box the id #door-q on /species/ and /measurements/,
  // so species.js and measurements.js fold to it; the one search over the three indexes is where
  // its results box #door-res is — the front door's Find panel)
  const dq = d.getElementById("door-q");
  if (!dq || !d.getElementById("door-res")) return out;
  const TERMS = ["sardine", "nitrate", "CUFES", "TEMPPR01"];
  const type = t => new Promise(res => {
    dq.value = t;
    dq.dispatchEvent(new w.Event("input", { bubbles: true }));
    setTimeout(res, 220);
  });
  const readOut = () => {
    const box = d.getElementById("door-res");
    const groups = [...box.querySelectorAll(".dres-g")].map(g2 => g2.textContent.replace(/\s+/g, " ").trim());
    return { open: box.classList.contains("open"), groups,
             hits: box.querySelectorAll("a.dres-r").length,
             none: !!box.querySelector(".dres-none"),
             first: (box.querySelector("a.dres-r") || {}).getAttribute
               ? box.querySelector("a.dres-r").getAttribute("href") : null };
  };
  dq.focus();
  return new Promise(resolve => {
    setTimeout(() => {                       // the three fetches
      const search = {};
      TERMS.reduce((p, t) => p.then(() => type(t)).then(() => { search[t] = readOut(); }),
                   Promise.resolve())
        // D9: "sardine" also renders into the Species tab's own result panel (assets/door-search.js
        // keeps both panels in sync regardless of which tab is currently showing)
        .then(() => type("sardine"))
        .then(() => {
          const sp = d.getElementById("door-species-results");
          out.doorPanels = { sardineSpeciesResults: sp ? sp.querySelectorAll(".cc-result").length : null };
        })
        // D4/D5: "krill" still filters the Datasets grid exactly as #ds-q used to, now driven by
        // the same #door-q
        .then(() => type("krill"))
        .then(() => {
          const grid = d.getElementById("ds-grid");
          out.doorPanels.krillRowsShown = grid
            ? [...grid.querySelectorAll(".ds-row-dataset")].filter(row => !row.hidden).map(row => row.getAttribute("data-key"))
            : null;
        })
        .then(() => { dq.value = ""; dq.dispatchEvent(new w.Event("input", { bubbles: true })); out.search = search; resolve(out); })
        .catch(e => { out.search = { error: String(e) }; resolve(out); });
    }, 1200);
  });
}
"""

HOST = """
new Promise(done => {
  const f = document.createElement("iframe");
  f.style.cssText = "position:fixed;left:0;top:0;border:0;width:__W__px;height:__H__px";
  f.src = "__URL__";
  f.onload = () => {
    const w = f.contentWindow, d = f.contentDocument;
    // the probe is async (it waits out the header menus' close delay and the finder's sticky preview);
    // a throw or a rejection comes back as {error}, never as a hung page
    const go = () => setTimeout(() => { Promise.resolve().then(() => (__PROBE__)(w, d)).then(done, e => done({error: String(e)})); }, __WAIT__);
    if (d.fonts && d.fonts.ready) d.fonts.ready.then(go); else go();
  };
  document.body.appendChild(f);
});
"""

# the window the pages are measured in: `width` x PROBE_H. The front door's first screen is as tall as
# the window (front door v2: min-height 100vh less the header), so its fold is measured in its own
# window, FOLD_W x FOLD_H, by FOLD_PROBE.
PROBE_H = 900


def probe(url, width, theme, browser, wait, height=PROBE_H, js=None):
    sep = "&" if "?" in url else "?"
    target = f"{url}{sep}theme={theme}&tour=off"
    body = (js or PROBE).replace("__HERO__", HERO_JS).replace("__FD_ANCHORS__", json.dumps(list(FRONT_ANCHORS)))
    js = (HOST.replace("__W__", str(width)).replace("__H__", str(height)).replace("__URL__", target)
              .replace("__PROBE__", body)
              .replace("__WAIT__", str(wait)))
    # the host page must be same-origin with the target, so load the target itself and let the
    # iframe inside it be the one that is measured at the width under test
    status = page_status(target)
    if status is not None and status >= 400:
        return {"error": f"HTTP {status} — the page is not on this build"}
    cmd = ["shot-scraper", "javascript", target, js, "--browser", browser]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if r.returncode:
        msg = (r.stderr or r.stdout).strip().splitlines()
        return {"error": msg[-1] if msg else "shot-scraper failed"}
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"error": f"unparseable: {r.stdout[:120]!r}"}


# ── the assertions ────────────────────────────────────────────────────────────
MAX_STRETCH = 1.25    # a tile drawn more than a quarter taller than its content is stretch
# issue #30: a page's height at 1470 with nothing open — the mockup's target + ~25 %, footer included
# (the mockups: the dataset catalog ~1,750 px, a dataset page ~1,750 px). The old pages ran 3,500 /
# 4,200–5,100 px; anything past these means something that should be a fold has come back open.
# the Download button (2026-11-16): above the fold of a 1280 x 800 screen, at 1280 and wider
DL_FOLD_W, DL_FOLD_H = 1280, 800
PV_MIN_VIEW = 200     # px of the finder's preview on screen once a row is chosen (its name and its buttons)
# The height ceilings at 1470 with nothing open (issue #30).
# catalog — RESTATED on 2026-11-17 by the owner's decision (Ben: "fix with mix"; the one threshold that day
#   that moved). It was 2,300, set for main's calm list of 19 one-line rows. /datasets/ is a FINDER now
#   (Browse datasets, front door v2): a row is a name, what the dataset holds and its years, about 74 px,
#   and the rows are the page's point, so the ceiling is the page's fixed parts plus room for its rows:
#       fixed parts  1,096 px = header 72 + search band 134 + crumb 54 + "When was it sampled" fold 68
#                               + tab row 63 + column heads 71 + folds under the list 179
#                               + page foot 56 + site footer 399
#       rows         20 datasets in 1,479 px (v2026.11.14: 70 to 97 px each, a long name wraps) = 74 px a row
#       measured     1,096 + 1,479 = 2,575 px
#       ceiling      1,096 + 22 x 74 = 2,724 → 2,725: the page as it is, and two more datasets.
#   A 23rd dataset (about 2,800 px) fails, and 25 (about 2,950) by more than 200 px: growth is noticed and
#   the number is then restated on purpose, or the list is paged; it is not a licence for taller rows
#   (20 rows over 2,725 px means the rows grew to more than 81 px each).
# dataset — unchanged.
# dataset: 4200 since 2026-11-21 (Erin's feedback put the measurements and the field descriptions on the page; the longest, ichthyo, is 3,991 px)
MAX_DS_H = {"catalog": 2725, "dataset": 4200}
MAX_GRID_H = 4400     # px at 1470 with the staging record (was 4,910)
# front door v2's finder: Groups · All species · The tree · the matrix, and (2026-11-17, Ben: "add species
# hierarchy view back as another tab") The hierarchy, main's icicle
SPECIES_VIEWS = ["groups", "list", "tree", "matrix", "hierarchy"]
# a view's id on main that an old link may still carry, and the view it must land on now
SPECIES_OLD_VIEWS = {"classes": "groups"}
MAX_SPECIES_INDEX_H = 2300   # issue #30: /species/ at 1470, nothing open — the mockup's 1,775 + 25 %
MAX_SPECIES_PAGE_H = 1500    # issue #30: a taxon page at 1470, nothing open — ~1,200 + 25 %
# the front door (issue #30; the seven tasks of 2026-11-16; front door v2's first screen, 2026-11-17)
FOLD_W, FOLD_H = 1280, 645
# The seven tasks (2026-11-16, the users' and Erin's feedback) and an eighth, the Query Builder. Each is
# reached from the first screen in ONE step: (id, the words a failure prints, the href that answers it,
# where it may be answered). "hero" is a visible link under the bar — a start card's button or a link
# of the strip — and is what every task was until 2026-11-17. That day the strip lost "Cite the data",
# "What CalCOFI collects" and "More visualizations" because the header says them (Ben), so for those
# two tasks, and only those, "header" also answers: a word of the bar that IS the link, or a word
# whose menu holds it. The other six must still be links on the first screen itself: a card that went
# missing is not excused by a line of a menu.
# A hash is this page's panel (the header writes it /#learn); the Explorer and the Query Builder are
# matched by their path, since a preview build serves them from its own folder; Cite and Contribute
# are their docs chapters, exactly.
# The Query Builder has its own address since 2026-11-17 (Ben: "move the Query Builder to its own
# dedicated 'query'"): https://calcofi.io/query/, /query/ in a preview, with or without a query string
# (a dataset page's pick links carry one). It was explore/builder.html, which no longer answers the task.
QUERY_PAT = r"(^|/)query/(\?[^#]*)?$"
FRONT_LINKS = {"cite": "https://calcofi.io/docs/cite.html", "contribute": "https://calcofi.io/docs/provide.html"}
FRONT_TASKS = [
    ("learn",      "See what CalCOFI collects",             r"(^|^/)#learn$",                          ("hero", "header")),
    ("explore",    "Explore and download on a map",         r"(^|/)explore/?(\?[^#]*)?$",               ("hero",)),
    ("find",       "Find and download a dataset",           r"(^|/)datasets/$",                        ("hero",)),
    ("program",    "Work with the data in code",            r"^#program$",                             ("hero",)),
    ("cite",       "Cite the data",                         "^" + re.escape(FRONT_LINKS["cite"]) + "$", ("hero", "header")),
    ("contribute", "Contribute data",                       "^" + re.escape(FRONT_LINKS["contribute"]) + "$", ("hero",)),
    ("monitor",    "Inform ocean and fisheries management", r"^#monitor$",                             ("hero",)),
    ("builder",    "the Query Builder",                     QUERY_PAT,                                 ("hero",)),
]
# the numbers the first screen states (front door v2 draws four; stations are on Find's map), each
# equal to the page's own #reach record; the two COUNTED things link their catalogs, as they always did
FRONT_NUMBERS = ("years", "cruises", "species", "measurements")
# Yellow (issue #30 D6). D6 A was "no yellow on the first screen, one in each panel". Front door v2
# (Betty, e6ad285: "Explorer is the yellow button") puts ONE on the first screen, the Explorer's: the
# rule checked now is exactly one, and that one. A decision the reconciliation records for Ben; the
# check follows the page that was built and fails on a second yellow or on any other first.
# Per panel, the yellow buttons painted (a class is not a colour): Learn none (its bar's "Sampling
# methods" is a quiet link by design: the drawing is the point, Betty 2026-11-14), Code none (Get the
# data is its destination, Erin 2026-10-19), the others one each.
PANEL_YELLOW = {"learn": 0, "explore": 1, "find": 1, "program": 0, "monitor": 1}
# "Where do you want to start?" is large text on a picture: WCAG 1.4.3's 3:1 at every sampled point
START_MIN_CONTRAST = 3.0
PHONE_W = 900         # under this the hero stacks (assets/hero.css @media (max-width: 900px))
# every anchor anyone may have bookmarked, and the panel it must open now: the panels themselves, the
# ids inside a panel (#build and #viz were doors until 2026-11-16; #viz is Maps and apps' apps for one
# dataset since front door v2), the tabs inside a panel, and the retired words of the old sections
FRONT_ANCHORS = {
    "learn": "learn", "explore": "explore", "find": "find", "program": "program", "monitor": "monitor",
    "datasets": "find", "species": "find", "measurements": "find",
    "explorer": "explore", "general": "explore", "viz": "explore", "dataset": "explore", "student": "explore",
    "access": "program", "services": "program", "packages": "program", "build": "program",
    "kinds": "learn",
    "data": "find", "apps": "explore", "docs": "learn", "monitoring": "monitor", "students": "explore",
}
# where a retired word lands INSIDE its panel: the URL keeps that hash, so a reload scrolls to it
FRONT_LANDS = {"viz": "dataset", "students": "student"}
# Find (Ben, 2026-11-16: "the find is still not obvious enough"): at 1280 x 800 with the panel open at
# its top, the one search and the first eight dataset names are on screen; each name is a link at
# body-text size (>= 16 px) in --accent, underlined, at least 28 px tall (MIN_TAP on a phone)
FIND_FOLD_H = 800
HEADER_H = 72         # the sticky header, when the page does not say (--header-h)
FIND_NAME_MIN_PX = 16
FIND_ROW_MIN_PX = 28
# FRONT_MAX_H (950 px at 1470 with no door open) is gone: front door v2's first screen is as tall as
# the window by design (min-height: 100vh less the header), so a number of pixels says nothing in a
# 900 px probe window. What it guarded is asserted directly: with no panel open the first screen ends
# at the window's bottom at >= 1400 px, and nothing but the footer follows it.
MIN_TAP = 32
# issue #30 (calm re-cut): full-page heights at 1470 px with nothing open, header and footer included.
# The mockups measured /measurements/ at 1,300 px and their heaviest measurement page (temperature,
# two series) at 1,476 px; the ceilings are those + 25 %.
MAX_MM_INDEX_H = 1625
MAX_MM_PAGE_H = 1850

# ── the header (brand v3, 2026-11-17: brand/v3/README.md § 4; was plan 2026-09-10 § D7's seven words) ──
# The words are ONE list, _data/nav.yml: _includes/site_nav.html draws this site's header from it and
# _plugins/nav.rb writes it to /brand/v3/nav.json for every other product (brand/v3/header.js). The
# check reads the same file rather than typing the words a third time: the bar must read exactly that
# list, in order, with each word's data-word its id — and _test/check_layout_front_test.py pins the
# list itself (Data ▾ · Map ▾ · Learn ▾ · calcofi.org ↗), so a word cannot leave the bar, or join it,
# by editing the list unseen. main's DATA · APPS · ACCESS · BUILD · DOCS · FAQ · NEWS are lines of the
# three menus (Ben, 2026-11-17, evening: Cite, Docs, FAQ and News, words of the bar for a few hours, fold
# under Learn with How CalCOFI samples; Query is the first line of Data ▾ › Get it); NAV_REACH is what the
# header must still link somewhere, a word or a line of a menu, so none of them can drop out unseen.
def nav_words(text):
    """[{id, title, menu}] of a _data/nav.yml text: the entries of its top-level `words:` list, in
    order. An entry is a block (`  - id: data` then `    title: Data`, `    menu:`) or one line
    (`  - { id: cite, title: Cite, href: … }`). No YAML library: this runs as a bare python3."""
    out, m = [], re.search(r"^words:\s*$", text or "", re.M)
    if not m:
        return out
    for blk in re.split(r"^(?=  - )", (text or "")[m.end():], flags=re.M):
        if not blk.startswith("  - "):
            continue
        first = blk.splitlines()[0]
        if "{" in first:
            wid = re.search(r"\bid:\s*([\w-]+)", first)
            tt = re.search(r"\btitle:\s*(\"[^\"]*\"|'[^']*'|[^,}]+)", first)
            menu = False
        else:
            wid = re.search(r"^  - id:\s*([\w-]+)|^    id:\s*([\w-]+)", blk, re.M)
            tt = re.search(r"^(?:  - |    )title:\s*(.+?)\s*$", blk, re.M)
            menu = bool(re.search(r"^    menu:", blk, re.M))
        if not tt:
            continue
        title = tt.group(1).strip().strip("\"'")
        out.append({"id": next((g for g in (wid.groups() if wid else ()) if g), None), "title": title, "menu": menu})
    return out


def nav_json_titles(obj):
    """the words' titles of a built /brand/v3/nav.json, in order"""
    return [w.get("title") for w in (obj or {}).get("words") or []]


def _nav_text():
    try:
        with open(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_data", "nav.yml"), encoding="utf-8") as f:
            return f.read()
    except OSError:
        return ""


NAV = nav_words(_nav_text())
NAV_WORDS = [x["title"] for x in NAV]
NAV_IDS = [x["id"] for x in NAV]
NAV_MENUS = [x["title"] for x in NAV if x["menu"]]
NAV_REACH = [
    ("the datasets catalog (/datasets/)",       r"(^|/)datasets/$"),
    ("the species catalog (/species/)",         r"(^|/)species/$"),
    ("the measurements catalog (/measurements/)", r"(^|/)measurements/$"),
    ("the Explorer",                            r"(^|/)explore/?$"),
    ("the Query Builder",                       QUERY_PAT),
    ("how to cite",                             r"/docs/cite\.html$"),
    ("the docs",                                r"/docs/?$"),
    ("the FAQ",                                 r"/docs/faq\.html$"),
    ("News",                                    r"(^|/)news/$"),
    ("code access (#services or #packages)",    r"#(services|packages|access|program)$"),
    ("the pipeline (#build)",                   r"#build$"),
    ("the apps (#explore)",                     r"#explore$"),
    ("what CalCOFI collects (#learn)",          r"#learn$"),
    ("calcofi.org",                             r"^https://calcofi\.org/?$"),
]
# below this width the menu button carries the nav (= brand/v3/header.css @media (max-width: 1099px)
# and brand/v3/header.js NAV_BREAK; scripts/check_brand.py holds every v3 product to it too): the
# words fit one line from there (four since 9f2b542; nine had 179 px to spare at 1100), so the header never wraps
NAV_BREAK = 1100
# the widths the header's own assertions are run at by --nav (one line from NAV_BREAK, the menu below)
NAV_WIDTHS = [1100, 1280, 1470, 1024, 800, 640, 375]
# (/datasets/ joined on 2026-11-17: its preview pane made the page scroll sideways 4 px at 1100 px, a
# width the full run does not visit)
NAV_PATHS = ["/", "/datasets/", "/datasets/swfsc_ichthyo/", "/species/", "/measurements/"]
PHONE = (375, 667)    # a small phone's window, for the open menu's column (--nav)
# the sections whose tabs are CARDS, so a pill must equal the number of cards in its panel. DATA's
# three pills count datasets, species and measurements — the release's numbers, checked against the
# page's own inline record instead (the band assertions above already do it).
# (ts-viz, "Other data visualizations", is gone with front door v2: Maps and apps draws those cards
# without tabs, and every product's card is asserted by product_keys instead.)
CARD_TABSETS = ("ts-access",)
# The Data section at 1470 px, measured on main's own build before D7 (2026-09-10, the v2026.09.06
# record, light): 2,974 px. D7 adds one search box (48), one tab row (43) and one door line in each
# realm head (35) and must not add a screen — plan § Risks, WS-M0's gate. Measured after: 3,078 px,
# +104. Re-measure and re-state this number whenever the catalog's own furniture changes.
# Re-measured 2026-09-11 on main's build (c3d7ea7) with the v2026.09.10 record: 3,099 px light and
# dark at 1470 (3,100 on unmodified main): D7's accepted +104 plus 21 px from what main and the
# record have gained since, not a screen. Every PR since the release had failed here on main's own
# height, which is the drift this number exists to catch in a PR, not in main.
# Re-measured 2026-09-15 (round 2, WS-R4, D1–D5/D9) on round-2's own tip (ea5e385, v2026.09.11
# record) before this workstream's changes: 3,117 px light at 1470. After (this branch): 2,948 px —
# a 169 px DECREASE, not a growth: D1 drops the format phrase from every homed row, D4/D5 drop the
# catalog's own #ds-q field and both per-tab search boxes on the front door (their own idxtab-form
# input + link row), more than the D3 variables/taxa expander (closed by default) adds back.
# Re-measured 2026-10-05 on main's own build (pr.yml workflow_dispatch, run 37361035371) with the promoted
# v2026.10.05 record: 3,113 px light and dark at 1470 — the same 3,113 px this branch measures
# (run 37361038873), so the +165 px is the record's growth (cce-lter_iron, 96 measurement keys
# against v2026.09.11's 89), not a change to the catalog's furniture.
DATA_SECTION_BASE = 3113
DATA_SECTION_GROWTH = 120

_PROBED = {}          # pin hrefs answered once per run, not per width and theme


def url_ok(url):
    """200/206 to a ranged GET (HEAD is answered 405 by some hosts — build_workflows_index.R's rule)."""
    if url in _PROBED:
        return _PROBED[url]
    import urllib.request
    req = urllib.request.Request(url, headers={"Range": "bytes=0-0", "User-Agent": "Mozilla/5.0 (calcofi.io check_layout)"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            _PROBED[url] = r.status in (200, 206)
    except Exception as e:  # noqa: BLE001
        code = getattr(e, "code", None)
        _PROBED[url] = code in (200, 206) if code else None   # None: unreachable, a warning not a failure
    return _PROBED[url]


def _rgb(text):
    """(r, g, b) of a computed colour — "rgb(24,43,73)" or "rgba(…)" — else None"""
    m = re.findall(r"[\d.]+", text or "")
    return tuple(float(x) for x in m[:3]) if len(m) >= 3 else None


def contrast(a, b):
    """WCAG 2 contrast ratio of two (r, g, b) colours, 1..21"""
    def lum(c):
        ch = [(v / 255.0) for v in c]
        ch = [v / 12.92 if v <= 0.03928 else ((v + 0.055) / 1.055) ** 2.4 for v in ch]
        return 0.2126 * ch[0] + 0.7152 * ch[1] + 0.0722 * ch[2]
    la, lb = sorted((lum(a), lum(b)), reverse=True)
    return (la + 0.05) / (lb + 0.05)


def png_pixels(data):
    """(width, height, [(r, g, b), …] row by row) of a PNG's bytes: 8-bit RGB or RGBA, not interlaced —
    what a browser screenshot is. No imaging library: this script's one dependency is shot-scraper."""
    import struct, zlib
    if data[:8] != b"\x89PNG\r\n\x1a\n":
        raise ValueError("not a PNG")
    pos, idat, w = 8, b"", None
    while pos < len(data):
        n, kind = struct.unpack(">I4s", data[pos:pos + 8])
        body = data[pos + 8:pos + 8 + n]
        if kind == b"IHDR":
            w, h, depth, ctype, _, _, lace = struct.unpack(">IIBBBBB", body)
            if depth != 8 or ctype not in (2, 6) or lace:
                raise ValueError(f"unsupported PNG (depth {depth}, colour type {ctype}, interlace {lace})")
            bpp = 3 if ctype == 2 else 4
        elif kind == b"IDAT":
            idat += body
        pos += 12 + n
    raw, stride, out, prev = zlib.decompress(idat), w * bpp, [], bytearray(w * bpp)
    for y in range(h):
        f, line = raw[y * (stride + 1)], bytearray(raw[y * (stride + 1) + 1:(y + 1) * (stride + 1)])
        for i in range(stride):
            a_ = line[i - bpp] if i >= bpp else 0
            b_ = prev[i]
            c_ = prev[i - bpp] if i >= bpp else 0
            if f == 1:
                line[i] = (line[i] + a_) & 255
            elif f == 2:
                line[i] = (line[i] + b_) & 255
            elif f == 3:
                line[i] = (line[i] + ((a_ + b_) >> 1)) & 255
            elif f == 4:
                pa, pb, pc = abs(b_ - c_), abs(a_ - c_), abs(a_ + b_ - 2 * c_)
                line[i] = (line[i] + (a_ if pa <= pb and pa <= pc else b_ if pb <= pc else c_)) & 255
        out.extend((line[i], line[i + 1], line[i + 2]) for i in range(0, stride, bpp))
        prev = line
    return w, h, out


def heading_contrast(shown, hidden):
    """A heading against the PIXELS behind it. `shown` and `hidden` are (w, h, pixels) of the same box
    of the page, once with the heading drawn and once with its text transparent. Where the two differ
    is where the letters are; the ink is the colour most of those pixels have when drawn (a letter's
    solid inside, not its soft edge); each of those places' colour with the heading hidden is what is
    behind the letters. Returns {ink, n, min, p05, worst}: the lowest contrast of the ink against any
    pixel behind a letter, the 5th percentile, and that worst pixel — or None when nothing differs
    (no heading was drawn there)."""
    if not shown or not hidden or shown[:2] != hidden[:2]:
        return None
    pairs = [(a, b) for a, b in zip(shown[2], hidden[2]) if a != b]
    if not pairs:
        return None
    count = {}
    for a, _ in pairs:
        count[a] = count.get(a, 0) + 1
    ink = max(count, key=count.get)
    ratios = sorted((contrast(ink, b), b) for _, b in pairs)
    return {"ink": ink, "n": len(pairs), "min": ratios[0][0], "p05": ratios[len(ratios) // 20][0], "worst": ratios[0][1]}


def shot(url, width, height, theme, browser, wait, selector, js=None):
    """the PNG bytes of one element of a page in a width x height window (shot-scraper shot), or None"""
    import tempfile
    sep = "&" if "?" in url else "?"
    with tempfile.TemporaryDirectory() as tmp:
        out = os.path.join(tmp, "s.png")
        cmd = ["shot-scraper", "shot", f"{url}{sep}theme={theme}&tour=off", "-o", out, "--selector", selector, "--width", str(width),
               "--height", str(height), "--wait", str(wait), "--browser", browser, "--silent"] + (["--javascript", js] if js else [])
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
        if r.returncode or not os.path.exists(out):
            return None
        with open(out, "rb") as f:
            return f.read()


# "Where do you want to start?" (#start-h) lies on a picture — the sky or the water of Line 90, under a
# scrim at desktop widths — so no CSS colour is its background. It is photographed twice in each of
# these windows, in both themes, drawn and with its text transparent, and the ink is held to
# START_MIN_CONTRAST against every pixel behind a letter. The windows: the two the pages are probed
# in, the fold's, two where the white heading measured 2.6 to 2.9:1 before the scrim (901 x 700,
# 1100 x 800), a tablet, a phone.
HEADING_WINDOWS = [(1470, 900), (1280, 645), (1100, 800), (901, 700), (820, 900), (375, 667)]
HIDE_HEADING = ("(() => { const h = document.getElementById('start-h'); if (h) { h.style.setProperty('transition', 'none', 'important'); "
                "h.style.setProperty('color', 'transparent', 'important'); h.style.setProperty('text-shadow', 'none', 'important'); } })()")


def check_heading(url, theme, browser, wait, fails, notes):
    """the start heading's contrast against the pixels behind it, in every HEADING_WINDOWS window"""
    ok = True
    for w_, h_ in HEADING_WINDOWS:
        where = f"{url} @{w_}x{h_} {theme}"
        a_, b_ = shot(url, w_, h_, theme, browser, wait, "#start-h"), shot(url, w_, h_, theme, browser, wait, "#start-h", HIDE_HEADING)
        try:
            hc = heading_contrast(png_pixels(a_), png_pixels(b_)) if a_ and b_ else None
        except ValueError as e:
            hc = None
            notes.append(f"{where}: {e}")
        if hc is None:
            fails.append(f"{where}: the start heading (#start-h) could not be photographed with and without its text")
            ok = False
            continue
        rgb_ = lambda c: "rgb(%d,%d,%d)" % c   # noqa: E731
        notes.append(f"{where}: start heading {rgb_(hc['ink'])} is {hc['min']:.2f}:1 at worst against the pixels behind it "
                     f"({rgb_(hc['worst'])}; 5th percentile {hc['p05']:.2f}:1, {hc['n']} pixels)")
        if hc["min"] < START_MIN_CONTRAST:
            fails.append(f"{where}: the start heading {rgb_(hc['ink'])} is {hc['min']:.2f}:1 against the pixels behind it "
                         f"(the palest {rgb_(hc['worst'])}), under {START_MIN_CONTRAST:g}:1")
            ok = False
    return ok


WAVE_EDGE_MIN = 1.3   # the edge's fill against the band's bottom colour: a step an eye sees (dark theme: about 1.6)


def is_navy(c):
    """a (r, g, b) that reads as the brand's navy: dark (WCAG luminance under 0.08 — #14284a is 0.022,
    #1d3d66 0.046) and blue the strongest channel, red the weakest"""
    if not c:
        return False
    lum = (contrast(c, (0, 0, 0)) * 0.05) - 0.05
    return lum < 0.08 and c[2] > c[1] >= c[0]


def check_wave(where, wv, width, fails, notes):
    """brand v3 § 4: every page has ONE navy band directly under the bar, ending in a wave"""
    drawn = (wv or {}).get("drawn") or []
    if not drawn and (wv or {}).get("dpBand"):
        notes.append(f"{where}: the dataset page draws its own band (.dp-band) in place of the header's wave")
        return
    if len(drawn) != 1:
        fails.append(f"{where}: {len(drawn)} wave bands (.cc-wave) are drawn under the bar, expected exactly one"
                     + (f": {[x['cls'] for x in drawn]}" if drawn else f" ({(wv or {}).get('all', 0)} in the page, none drawn)"))
        return
    x, hb = drawn[0], wv.get("headerBottom")
    edge = "its own svg" if x["own"] else "the brand's mask"
    notes.append(f"{where}: wave {x['top']}–{x['bottom']}px under a bar ending {hb}px, painted {' → '.join(x['paint']) or 'nothing'}, edge {edge}")
    # directly under the bar: no gap above it, and not slid under the bar or anything else
    if hb is None:
        fails.append(f"{where}: no header (.cc-header) for the wave to follow")
    elif x["top"] > hb + 1:
        fails.append(f"{where}: the wave starts at {x['top']}px, {x['top'] - hb}px below the bar's bottom ({hb}px): a gap")
    elif x["top"] < hb - 1:
        fails.append(f"{where}: the wave starts at {x['top']}px, under the bar (which ends at {hb}px)")
    if x.get("hidden"):
        fails.append(f"{where}: the wave's top is covered by {x['hidden']!r}")
    if x["left"] > 1 or x["right"] < width - 1:
        fails.append(f"{where}: the wave runs {x['left']}–{x['right']}px of a {width}px window, not edge to edge")
    # navy in both themes, never the page's ground (the bar is white in light and navy in dark; the band is navy in both)
    paint = [_rgb(c) for c in x["paint"]]
    if not paint:
        fails.append(f"{where}: the wave band has no background")
    elif not all(is_navy(c) for c in paint):
        fails.append(f"{where}: the wave band is painted {x['paint']}, not the brand's navy")
    if wv.get("ground") in x["paint"]:
        fails.append(f"{where}: the wave band is painted with the page ground {wv['ground']}")
    # its edge is drawn: the brand's ::after mask, or the page's own svg along the band's bottom, filled
    # with what lies below the band — a colour that is NOT the band's own, a visible step from the
    # band's bottom colour (light: the white ground, about 11:1; dark: the dark ground, about 1.6:1)
    def edge_shows(fill, what):
        f = _rgb(fill)
        if f is None or not paint:
            return
        step = contrast(f, paint[-1])
        if fill in x["paint"] or step < WAVE_EDGE_MIN:
            fails.append(f"{where}: {what} is filled {fill}, {step:.2f}:1 against the band's own {x['paint'][-1]}: no edge shows")
        else:
            notes.append(f"{where}: wave edge {fill}, {step:.2f}:1 against the band")
    if x["own"]:
        sv = x.get("svg")
        if not sv or sv["h"] < 4:
            fails.append(f"{where}: the band says it draws its own edge (.cc-wave-own) but has no svg wave as wide as itself")
        elif sv["bottomGap"] > 2:
            fails.append(f"{where}: the band's own wave ends {sv['bottomGap']}px from the band's bottom")
        else:
            edge_shows(sv.get("fill"), "the band's own wave")
    else:
        af = x.get("after")
        if not af or af["h"] < 4 or not af["mask"]:
            fails.append(f"{where}: the wave's edge is not drawn (::after {af})")
        else:
            edge_shows(af.get("fill"), "the wave's edge")


def task_links(links, pattern):
    """the visible first-screen links whose href answers a task's pattern"""
    return [x for x in links if x.get("visible") and re.search(pattern, x.get("href") or "")]


def task_words(header, pattern):
    """the header's words that answer a task's pattern: a word that is the link, or a word whose menu
    holds a line that is — drawn or not (under NAV_BREAK the bar's words are in the menu button's column)"""
    return [x for x in header or []
            if re.search(pattern, x.get("href") or "") or any(re.search(pattern, h or "") for h in x.get("lines") or [])]


def check_first_screen(where, H, width, fails, notes, fold=False):
    """the assertions about the first screen that hold in any window: the tasks, the tap targets, the
    heading's contrast, the numbers, the strip. `fold` adds the FOLD_W x FOLD_H rule (every task link
    above the fold, the header's words drawn)."""
    links = H.get("links") or []
    missing, small, late, found = [], [], [], []
    for tid, words, pat, places in FRONT_TASKS:
        hits = task_links(links, pat) if "hero" in places else []
        if hits:
            best = max(hits, key=lambda x: x["h"])
            found.append(f"{tid}: {best['where']}")
            if best["h"] < MIN_TAP:
                small.append(f"{tid} {best['h']}px ({best['where']}: {best['text']!r})")
            if fold and min(x["bottom"] for x in hits) > FOLD_H:
                late.append(f"{tid} {min(x['bottom'] for x in hits)}px ({hits[0]['where']})")
            continue
        via = task_words(H.get("header"), pat) if "header" in places else []
        drawn = [x for x in via if x.get("visible")]
        if drawn:
            # a word of the bar: on the first screen by construction (the bar is its first line)
            found.append(f"{tid}: header {drawn[0]['title']!r}")
            if fold and drawn[0]["bottom"] > FOLD_H:
                late.append(f"{tid} {drawn[0]['bottom']}px (header)")
        elif via and width < NAV_BREAK and H.get("menuButton"):
            # under NAV_BREAK the bar's words are behind the menu button, which is on the first screen;
            # that the open column draws every line is the phone menu's own assertion
            found.append(f"{tid}: menu button › {via[0]['title']!r}")
        else:
            missing.append(f"{tid} ({words})" + ("" if "header" in places else " — a link on the first screen itself, not a line of a menu"))
    if missing:
        fails.append(f"{where}: no visible link on the first screen for: {', '.join(missing)}")
    if small:
        fails.append(f"{where}: first-screen link(s) under the {MIN_TAP}px tap target: {'; '.join(small)}")
    if late:
        fails.append(f"{where}: task link(s) end below the {FOLD_H}px fold of a {FOLD_W} x {FOLD_H} window: "
                     f"{'; '.join(late)} (the first screen ends at {H.get('bottom')}px)")
    # in the fold's window (1280 wide, over NAV_BREAK) the bar's words are all drawn
    if fold:
        hidden = [x["title"] for x in H.get("header") or [] if not x.get("visible")]
        if hidden or not H.get("header"):
            fails.append(f"{where}: the header's words {hidden or '(none found)'} are not drawn in a {FOLD_W} x {FOLD_H} window")
    cards, strip, start = H.get("cards") or [], H.get("strip"), H.get("start")
    if len(cards) != 3:
        fails.append(f"{where}: the first screen draws {len(cards)} start cards, expected 3")
    if fold:
        lc = [c["title"] for c in cards if c["bottom"] > FOLD_H]
        if lc:
            fails.append(f"{where}: start card(s) {lc} end below the {FOLD_H}px fold (at {max(c['bottom'] for c in cards)}px)")
    for a, b in zip(cards, cards[1:]):
        if b["top"] < a["bottom"] - 1 and b["left"] < a["right"] - 1 and a["left"] < b["right"] - 1:
            fails.append(f"{where}: start cards {a['title']!r} and {b['title']!r} overlap")
    # the strip of links sits under the cards, never over the last one (it is absolutely placed for one
    # line at desktop width; wrapped on a phone it rode up over the third card until c38911f)
    if strip and cards and strip["top"] < max(c["bottom"] for c in cards) - 1:
        fails.append(f"{where}: the strip of links starts at {strip['top']}px, over the start cards "
                     f"(the last ends at {max(c['bottom'] for c in cards)}px)")
    if not strip:
        fails.append(f"{where}: the first screen has no strip of links (.hero-foot nav)")
    # (the start heading's contrast is read from pixels, in its own windows: check_heading)
    if start is None:
        fails.append(f"{where}: the first screen has no start heading (#start-h)")
    # the numbers stay inside the window ("MEASUREMENTS" ran off the right edge at 375 px)
    out_r = [n["label"] for n in H.get("nums") or [] if n["right"] > H["innerW"] + 1 or n["left"] < -1]
    if out_r:
        fails.append(f"{where}: number(s) {out_r} run outside the {H['innerW']}px window")
    # the label drawn by the ship is part of the picture: under PHONE_W the picture is cut by the
    # window's edge, so the label is neither shown nor a link there (the strip carries the same link)
    tag = H.get("tag")
    if tag and width < PHONE_W and tag["visible"]:
        fails.append(f"{where}: the ship's label is still a drawn link under {PHONE_W}px ({tag['w']}px wide), where the picture is cut")
    if tag and width >= PHONE_W and not tag["visible"]:
        fails.append(f"{where}: the ship's label is not drawn at {width}px")
    # the picture: drawn, with Line 90's floor wherever the page carries its profile, and no pins
    if H.get("drawn", 0) < 3:
        fails.append(f"{where}: the first screen's drawing (#hero-sea) was not drawn")
    if H.get("floorData") and not H.get("ridge"):
        fails.append(f"{where}: the page carries Line 90's sea floor but the drawing has no floor")
    if H.get("svgPins"):
        fails.append(f"{where}: the first screen's drawing carries {H['svgPins']} pins; it is drawn quiet")
    notes.append(f"{where}: tasks — {'; '.join(found)}")
    notes.append(f"{where}: first screen's hero {H.get('top')}–{H.get('bottom')}px in a {H.get('innerW')} x {H.get('innerH')} window; cards end "
                 f"{max((c['bottom'] for c in cards), default=0)}px, strip {strip['top'] if strip else None}–{strip['bottom'] if strip else None}px")


def check_fold(where, r, fails, notes):
    """the first screen alone, in a FOLD_W x FOLD_H window (FOLD_PROBE)"""
    H = r.get("fold")
    if not H:
        fails.append(f"{where}: no first screen (section.hero) to measure")
        return
    if r.get("open"):
        fails.append(f"{where}: {r['open']} open on load")
    if r.get("scrollWidth", 0) > r.get("width", 0) + 1:
        fails.append(f"{where}: horizontal scroll — scrollWidth {r['scrollWidth']} > {r['width']}")
    check_first_screen(where, H, FOLD_W, fails, notes, fold=True)


def hierarchy_faults(sp):
    """what is wrong with the species index's hierarchy view (main's icicle, a tab again since
    2026-11-17), from the probe's `species` record: `view` the tab selected as the page landed, `ice`
    what was drawn then, `icePressed` what pressing the tab drew. Drawn only when shown: a hidden
    <svg> has no width, so an icicle drawn behind another view is drawn to nothing."""
    out, ice, pr = [], sp.get("ice"), sp.get("icePressed")
    if not ice or ice.get("inPanel") != "hierarchy":
        return ["the hierarchy tab's panel holds no icicle (#sp-ice)"]
    if ice.get("seg") != 2:
        out.append(f"the hierarchy offers {ice.get('seg')} ways to size it, expected 2 (observations, species)")
    if sp.get("view") == "hierarchy":
        if ice["rects"] < 2 or ice["crumb"] < 1:
            out.append(f"the hierarchy view is showing but drew {ice['rects']} band(s) and {ice['crumb']} breadcrumb(s)")
    elif ice["rects"]:
        out.append(f"the hierarchy drew {ice['rects']} band(s) while the {sp.get('view')!r} view is showing")
    if not pr:
        out.append("the hierarchy tab was not pressed (no tab, or no #sp-ice)")
    elif pr.get("view") != "hierarchy" or pr.get("panels") != 1:
        out.append(f"pressing The hierarchy selects {pr.get('view')!r} with {pr.get('panels')} panel(s) showing")
    elif pr.get("rects", 0) < 2 or pr.get("w", 0) < 200 or pr.get("crumb", 0) < 1:
        out.append(f"pressing The hierarchy drew {pr.get('rects')} band(s) in {pr.get('w')}px with {pr.get('crumb')} breadcrumb(s)")
    elif pr.get("zoomCrumb", 0) != pr["crumb"] + 1:
        out.append(f"a press on a band does not zoom into it (breadcrumb {pr['crumb']} → {pr.get('zoomCrumb')})")
    elif pr.get("backCrumb") != 1 or pr.get("backRects", 0) < 2:
        out.append(f"the breadcrumb does not climb back out ({pr.get('backCrumb')} crumb(s), {pr.get('backRects')} band(s))")
    return out


def higher_faults(fi, has_q, pages=None):
    """what is wrong with the taxa a species search lists apart from the species (a genus, a family, an
    order …: every taxon with a page that is not a row of the list), from the probe's `finder` record.
    `pages` is the record's own count of taxon pages: rows and other taxa together cannot exceed it."""
    out, hi = [], fi.get("higher") or []
    if not fi.get("recTaxa"):
        out.append("/species/finder-taxa.json is missing or empty: a search cannot find a genus or a family")
    elif pages and fi.get("recRows") is not None and fi["recRows"] + fi["recTaxa"] > pages:
        out.append(f"{fi['recRows']} species rows and {fi['recTaxa']} other taxa for {pages} taxon pages: a taxon is listed twice")
    if not has_q:
        if hi or fi.get("higherHead"):
            out.append(f"{len(hi)} other taxa are listed with no search (the block is drawn only on a search)")
        return out
    if fi.get("rowsInHigher"):
        out.append(f"{fi['rowsInHigher']} species row(s) inside the other-taxa block: the list and the count stay species")
    if hi and not fi.get("higherHead"):
        out.append("the other taxa are listed with no heading that says they are not species")
    if hi and not fi.get("higherAfterList"):
        out.append("the other taxa are listed before the species rows, expected under them")
    bad = [x["href"] for x in hi if not re.search(r"(^|/)species/[\w.-]+/$", x.get("href") or "")]
    if bad:
        out.append(f"{len(bad)} other-taxa row(s) do not link a species page: {bad[:3]}")
    norank = [x["name"] for x in hi if not x.get("sub") or not x.get("holds")]
    if norank:
        out.append(f"{len(norank)} other-taxa row(s) say no rank or not what they hold: {norank[:3]}")
    st = fi.get("higherStatus")
    if hi and not (st is not None and 200 <= st < 400):
        out.append(f"the first other-taxa link ({hi[0].get('href')}) answers HTTP {st}")
    return out


def category_faults(mm, width):
    """what is wrong with the measurements index's By category view (issue #30 D8, back on
    2026-11-17: the categories are CLOSED groups), from the probe's `mm` record.
      on load      every category is a button that names its rows (aria-controls) and says it is shut
                   (aria-expanded=false), with no row in view and a line saying what is inside; the
                   preview shows no row that is hidden inside one
      ?q= on load  the categories drawn are the ones that hold a match, each open with every match in view
      a press      opens that category in place (its button does not move and keeps the focus), every
                   one of its rows in view and no other category's; the preview is then on a row in
                   view; a second press shuts it
      a search     (typed) opens every category that holds a match, draws none that holds none, with
                   every match in view; clearing the box shuts what the search opened"""
    out, lc, q = [], mm.get("listCats") or [], mm.get("q")
    if mm.get("view") != "cat":
        return out
    for c in lc:
        if not (c.get("button") and c.get("controls")):
            out.append(f"category {c['cat']!r} is not a button naming its rows (h3 > button[aria-controls])")
        elif q:
            if c["says"] != "true" or c["shown"] != c["rows"] or not c["rows"]:
                out.append(f"?q={q}: category {c['cat']!r} says aria-expanded={c['says']} with {c['shown']} of {c['rows']} match(es) in view")
        else:
            if c["says"] != "false" or c["shown"] or not c["bodyHidden"]:
                out.append(f"category {c['cat']!r} is open on load (aria-expanded={c['says']}, {c['shown']} row(s) in view): "
                           f"the categories are closed until pressed (issue #30 D8)")
            if not c.get("hint"):
                out.append(f"closed category {c['cat']!r} does not say what is inside")
    if mm.get("pvRow") == "hidden":
        out.append("the preview shows a row that is hidden inside a closed category")
    if q and width >= 1000 and lc and mm.get("pvRow") != "in view":
        out.append(f"?q={q}: the preview is not on a row in view")
    if q:
        return out
    pr = mm.get("press")
    if not pr:
        out.append("no category button to press")
    else:
        if pr["says"] != "true" or not pr["rows"] or pr["shown"] != pr["rows"]:
            out.append(f"pressing {pr['cat']!r}: aria-expanded={pr['says']}, {pr['shown']} of {pr['rows']} row(s) in view")
        if pr["others"]:
            out.append(f"pressing {pr['cat']!r} opened {pr['others']} other categor{'y' if pr['others'] == 1 else 'ies'}")
        if abs(pr["moved"]) > 1:
            out.append(f"pressing {pr['cat']!r} moved its own button {pr['moved']}px")
        if not pr["focusKept"]:
            out.append(f"pressing {pr['cat']!r} lost the focus from its button")
        if width >= 1000 and pr["pvRow"] != "in view":
            out.append(f"with {pr['cat']!r} open the preview is not on a row in view ({pr.get('pvTitle')!r})")
        ag = pr.get("again") or {}
        if ag.get("says") != "false" or ag.get("shown"):
            out.append(f"a second press does not shut {pr['cat']!r} (aria-expanded={ag.get('says')}, {ag.get('shown')} row(s) in view)")
        if ag.get("pvRow") == "hidden":
            out.append(f"with {pr['cat']!r} shut again the preview still shows one of its rows")
    for term, v in (mm.get("search") or {}).items():
        cats = v.get("cats") or []
        shut = [c["cat"] for c in cats if c["rows"] and (c["says"] != "true" or c["shown"] != c["rows"])]
        empty = [c["cat"] for c in cats if not c["rows"]]
        if shut:
            out.append(f"search {term!r} leaves {shut} closed though each holds a match")
        if empty:
            out.append(f"search {term!r} draws {empty} though none holds a match")
        if v.get("shown") != v.get("list"):
            out.append(f"search {term!r}: {v.get('shown')} of {v.get('list')} match(es) in view")
    left = [c["cat"] for c in (mm.get("cleared") or {}).get("cats") or [] if c["says"] != "false" or c["shown"]]
    if left:
        out.append(f"with the search cleared {left} stay open: what the search opened is shut again")
    return out


def bands_r2(P):
    """the record's own anomaly bands, as both the M10 assertions read them"""
    return (P.get("anomaly") or {}).get("bands") or []


def crumb_faults(cr):
    """the catalogs' crumb row (Datasets · Species · Measurements with their counts) must be able to wrap.

    `cr` is the row measured while squeezed to 300 px: {squeezed: its scrollWidth, box: its clientWidth, links}.
    A row that wraps stays inside its box; one that cannot runs past it, and on a phone that is a sideways scroll
    of the whole page wherever the fonts are a little wider than on the machine that wrote the CSS (Linux, in the
    PR workflow, 2026-11-17: scrollWidth 377 and 379 at 375 px, with nothing wrong on a Mac). A page with no
    crumb (cr is None) has nothing to judge."""
    if not cr:
        return []
    if cr.get("squeezed", 0) > cr.get("box", 0) + 1:
        return [f"the catalogs' crumb cannot wrap — squeezed to {cr.get('box')} px it is {cr.get('squeezed')} px wide, "
                "so it scrolls the page sideways on a phone whose fonts are a little wider"]
    return []


def check(path, r, width, theme, fails, notes):
    where = f"{path} @{width}px {theme}"

    if r.get("scrollWidth", 0) > r.get("width", 0) + 1:
        fails.append(f"{where}: horizontal scroll — scrollWidth {r['scrollWidth']} > {r['width']}")
    fails.extend(f"{where}: {f}" for f in crumb_faults(r.get("crumb")))

    # the wave (brand v3 § 4): on every page, one navy band directly under the bar
    check_wave(where, r.get("wave"), width, fails, notes)

    g = r.get("grid")
    if g:
        worst = max(g["tiles"], key=lambda t: t["ratio"], default=None)
        notes.append(f"{where}: grid {g['height']}px, {g['columns']} col, masonry={g['masonry']}, "
                     f"worst stretch {worst['ratio']}x ({worst['name'].strip()})" if worst else where)
        for t in g["tiles"]:
            if t["ratio"] > MAX_STRETCH:
                fails.append(f"{where}: tile {t['name'].strip()!r} drawn {t['drawn']}px for "
                             f"{t['natural']}px of content ({t['ratio']}x > {MAX_STRETCH})")
        if width >= 1400 and g["height"] > MAX_GRID_H:
            fails.append(f"{where}: grid {g['height']}px > {MAX_GRID_H}px")
        if width <= 400 and g["columns"] != 1:
            fails.append(f"{where}: grid is {g['columns']} columns, expected 1")

    fsw = r.get("filterSelectWidths")
    if fsw:
        notes.append(f"{where}: filter selects " +
                     " · ".join(f"{s['id']}={s['w']}px" for s in fsw))

    f = r.get("filter")
    if f:
        notes.append(f"{where}: filter {f['category']!r} -> {f['tilesShown']} tile(s) shown")
        if f["painted"]:
            fails.append(f"{where}: filtering by {f['category']!r} left {len(f['painted'])} hidden "
                         f"element(s) still displayed (an author `display` rule beats [hidden]): "
                         f"{', '.join(sorted(set(f['painted']))[:4])}")

    for h in r.get("holdings", []):
        if h["name"] != r["muted"]:
            fails.append(f"{where}: holding {h['key']} name is {h['name']}, expected --muted {r['muted']}")
        if h["warn"]:
            fails.append(f"{where}: holding {h['key']} carries --warn on {h['warn']}")

    # issue #30: the dataset catalog and a dataset page, calmer — a height ceiling with nothing open,
    # every fold closed on load, and the catalog's list is the record's datasets, once each
    cd = r.get("calmDs")
    if cd:
        notes.append(f"{where}: {cd['kind']} {cd['height']}px with nothing open, {cd['folds']} folds")
        if width >= 1400 and cd["height"] > MAX_DS_H[cd["kind"]]:
            fails.append(f"{where}: {cd['kind']} page is {cd['height']}px with nothing open, "
                         f"max {MAX_DS_H[cd['kind']]} (issue #30)")
        # "The release" opens on load by design (Betty 2026-11-21)
        cd_open = [x for x in cd["open"] if x != "release"]
        if cd_open:
            fails.append(f"{where}: open on load, expected closed: {cd_open}")
        if cd["folds"] < (2 if cd["kind"] == "dataset" else 3):
            fails.append(f"{where}: only {cd['folds']} fold(s) — the dense parts are supposed to be folded")
        if cd["kind"] == "catalog":
            rec = _read_json(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_data", "datasets.json")) or {}
            want = sorted(x["dataset_key"] for x in rec.get("datasets", []) if x.get("visibility") != "internal")
            if want and sorted(cd["rows"]) != want:
                fails.append(f"{where}: the list has {len(cd['rows'])} rows for {len(want)} datasets in the record")
            if want and sorted(cd["gridRows"]) != want:
                fails.append(f"{where}: By category has {len(cd['gridRows'])} rows for {len(want)} datasets in the record")
    if r.get("twoCol"):
        fails.append(f"{where}: two-column region(s) under the head: {r['twoCol']}")

    # the Download button (2026-11-16): the offers are read from the same _data/ files the build read
    # (the record's own `bundle` rows first, else the zip manifest), so with no manifest every page
    # must draw none
    dlw = r.get("download")
    if cd and dlw is not None:
        offers = download_offers(_data_dir())
        if cd["kind"] == "dataset":
            key = path.rstrip("/").split("/")[-1].split("?")[0]
            want = offers.get(key)
            notes.append(f"{where}: download button {dlw['n']} · bottom {dlw['bottom']}px · options {dlw['options']}")
            if want is None:
                if dlw["n"] or dlw["dialog"]:
                    fails.append(f"{where}: {key} has no zips (or is a holding) but draws {dlw['n']} Download button(s)")
            else:
                if dlw["n"] != 1 or dlw["inHead"] != 1:
                    fails.append(f"{where}: expected exactly one Download button, in the head (the redesigned page: its "
                                 f"side column); found {dlw['n']} ({dlw['inHead']} there)")
                if width >= 1280 and (dlw["bottom"] or 10**6) > DL_FOLD_H:
                    fails.append(f"{where}: the Download button ends at {dlw['bottom']}px, below the "
                                 f"{DL_FOLD_W} x {DL_FOLD_H} fold")
                if dlw["href"] != want["primary"]:
                    fails.append(f"{where}: the button links {dlw['href']}, expected the {want['primary_format']} zip "
                                 f"{want['primary']}")
                if not dlw["dialog"] or dlw["dialogOpen"]:
                    fails.append(f"{where}: the Download dialog is {'open on load' if dlw['dialogOpen'] else 'missing'}")
                if "csv" in want["formats"] and (not dlw["options"] or dlw["options"][0] != "csv"):
                    fails.append(f"{where}: the dialog's first option is {dlw['options'][:1]}, expected CSV first")
                if "csv" in want["formats"] and dlw["firstHref"] != want["urls"]["csv"]:
                    fails.append(f"{where}: the dialog's CSV links {dlw['firstHref']}, expected {want['urls']['csv']}")
                if "xlsx" not in want["formats"] and "xlsx" in dlw["options"]:
                    fails.append(f"{where}: the dialog offers Excel, which the manifest did not write")
                # the dialog's "Every endpoint" closes it and opens the #access fold: the fold must be there
                if dlw["endpointsLink"] and not dlw["accessFold"]:
                    fails.append(f"{where}: the Download dialog links \"Every endpoint\" but the page has no #access fold to open")
        else:
            # /datasets/ is the finder: ONE preview beside the list carries the Download control of the row
            # it shows (a link to that dataset page's #download), so every row is driven and its preview
            # read. (main drew a control per row in the List and again in By category: the two views
            # share the one preview now, so "By category draws N controls" has nothing left to count;
            # By category's rows are asserted above instead.)
            rec = _read_json(os.path.join(_data_dir(), "datasets.json")) or {}
            keys = [x["dataset_key"] for x in rec.get("datasets", []) if x.get("visibility") != "internal"]
            want_rows = sorted(k for k in keys if k in offers)
            br = r.get("browse")
            if br is None:
                fails.append(f"{where}: no finder (#bd-list beside #bd-pv) to read the Download controls from")
            else:
                got = {}
                for k, v in br["pvDl"].items():
                    m = re.search(r"/datasets/([^/]+)/#download$", v.get("href") or "")
                    if v.get("href"):
                        got[k] = m.group(1) if m else v["href"]
                wrong = sorted(k for k, v in got.items() if v != k)
                have = sorted(k for k, v in got.items() if v == k)
                # (where the preview is not drawn — a phone — a row opens its dataset page, which has the button)
                if br["pvDisplay"] != "none" and (have != want_rows or wrong):
                    fails.append(f"{where}: the preview draws a Download control for {len(have)} of the {len(want_rows)} datasets with "
                                 f"zips: missing {sorted(set(want_rows) - set(have))[:4]}, extra {sorted(set(have) - set(want_rows))[:4]}, "
                                 f"linking another page {wrong[:4]}")
                # a row's click is the page's to handle while the preview is drawn; where it is not drawn
                # (a phone, if the page stacks it away) the click must be left to follow the link
                if br["pvDisplay"] != "none" and br["unhandled"]:
                    fails.append(f"{where}: {len(br['unhandled'])} row click(s) are not handled though the preview is drawn: {br['unhandled'][:3]}")
                if br["pvDisplay"] == "none" and len(br["unhandled"]) != len(br["pvDl"]):
                    fails.append(f"{where}: the preview is not drawn at {width}px but a row's click is still swallowed: "
                                 f"the row goes nowhere")
                # the preview's actions stay inside its card, whatever the row (a long label must wrap or
                # shrink, not hang out of the card and widen the page)
                ao = br.get("actOver") or {}
                if br["pvDisplay"] != "none":
                    if (ao.get("px") or 0) > 1:
                        fails.append(f"{where}: the preview's action {ao.get('what')!r} runs {ao['px']}px outside the preview card "
                                     f"(with {ao.get('key')} chosen)")
                    if not br.get("actN"):
                        fails.append(f"{where}: the preview draws no actions (.bd-pv-act)")
                rc = br.get("reach")
                if rc and not rc["shown"]:
                    notes.append(f"{where}: the finder's preview is not drawn at {width}px; a row opens its dataset page")
                elif rc:
                    notes.append(f"{where}: finder preview {rc['position']}, {rc['inView']}px in view with the last row chosen "
                                 f"(row {rc['rowTop']}–{rc['rowBottom']}px, preview {rc['pvTop']}–{rc['pvBottom']}px of {rc['innerH']}px)")
                    # reachable: with the last row chosen and on screen, at least PV_MIN_VIEW px of its
                    # preview are on screen too. Beside the list (>= 1000 px) that is the sticky pane; where
                    # the page stacks the preview under the list, a chosen row must still bring it into view
                    if rc["shown"] and rc["handled"] and rc["inView"] < PV_MIN_VIEW:
                        fails.append(f"{where}: with the last row chosen and on screen, {rc['inView']}px of its preview are in the "
                                     f"window (preview {rc['pvTop']}–{rc['pvBottom']}px, window {rc['innerH']}px): choosing a row "
                                     f"shows nothing")
                    if width >= 1400 and not rc["sideBySide"]:
                        fails.append(f"{where}: the preview is not beside the list at {width}px")
                f2 = br.get("filter")
                if f2:
                    notes.append(f"{where}: finder type {f2['type']!r} -> {f2['shown']} of {f2['total']} rows")
                    if f2["painted"]:
                        fails.append(f"{where}: choosing type {f2['type']!r} left {len(f2['painted'])} hidden element(s) still displayed "
                                     f"(an author `display` rule beats [hidden]): {', '.join(sorted(set(f2['painted']))[:4])}")
                    if not (0 < f2["shown"] < f2["total"]):
                        fails.append(f"{where}: choosing type {f2['type']!r} shows {f2['shown']} of {f2['total']} rows")
                else:
                    fails.append(f"{where}: the finder has no type filter (#bd-type) to check that it hides")
                # the one search (main: one box over the three indexes on every catalog page): from
                # /datasets/ a species, a measurement and a dataset's own name each find a dataset
                se2 = br.get("search") or {}
                notes.append(f"{where}: finder search " + " · ".join(f"{t}: {len(v)}" for t, v in se2.items()))
                for term in ("sardine", "nitrate", "CUFES"):
                    if not se2.get(term):
                        fails.append(f"{where}: the finder's search finds no dataset for {term!r}")
                    elif len(se2[term]) >= len(br["pvDl"]):
                        fails.append(f"{where}: the finder's search for {term!r} hides nothing ({len(se2[term])} rows)")
        if dlw["inSummary"]:
            fails.append(f"{where}: {dlw['inSummary']} Download control(s) inside a <summary> (nested interactive)")
        if dlw["inHoldings"]:
            fails.append(f"{where}: a holding row carries a Download control")

    # ── the redesigned dataset page (front door v2) ───────────────────────────────────────────────
    dp = r.get("dp")
    if dp:
        key = path.rstrip("/").split("/")[-1].split("?")[0]
        notes.append(f"{where}: redesigned page {dp['cols']} column(s), main {dp['mainW']}px beside {dp['sideW']}px; "
                     f"{len(dp['cards'])} side cards; {len(dp['measKeys'])} measurements, {dp['taxaDrawn'] + dp['taxaMore']} taxa; "
                     f"licence {dp['licence']!r}")
        # the columns (was "no two-column region under the head", which the CTD page's 418 px main column
        # beside a 1,346 px sidebar earned): two columns are this page's design at desktop width, so what
        # is asserted is that the content column is the wide one, and that a phone gets one column
        if width <= 400 and dp["cols"] != 1:
            fails.append(f"{where}: the page is {dp['cols']} columns at {width}px, expected 1")
        if width >= 1000 and dp["cols"] and dp["cols"] > 1 and (dp["mainW"] or 0) < 1.4 * (dp["sideW"] or 0):
            fails.append(f"{where}: the content column is {dp['mainW']}px beside a {dp['sideW']}px side column: the wide column "
                         f"must be the content's")
        # the side cards do not overlap each other, and the side column does not run over what follows
        cards = dp["cards"]
        for a_, b_ in zip(cards, cards[1:]):
            if b_["top"] < a_["bottom"] - 1:
                fails.append(f"{where}: side cards {a_['title']!r} and {b_['title']!r} overlap "
                             f"({a_['bottom']}px over {b_['top']}px)")
        for bl in dp["below"]:
            for col in (dp["side"], dp["main"]):
                if col and bl["top"] < col["bottom"] - 1:
                    fails.append(f"{where}: {bl['cls']!r} starts at {bl['top']}px, under a column that ends at {col['bottom']}px")
        for c in cards:
            if c["right"] > width + 1 or c["left"] < -1:
                fails.append(f"{where}: the side card {c['title']!r} runs outside the {width}px window")
        # D2 (round 2): a dataset page SAYS its licence, and an unstated one is said to be unstated — never
        # silence, which reads as "no conditions" (licence_chip.html's rule; _plugins/downloads.rb `licence`)
        if not dp["licence"]:
            fails.append(f"{where}: the page states no licence (an unstated or pending one must be said, never left out)")
        elif dp["licence"].strip().lower().endswith("custom"):
            fails.append(f"{where}: the page shows the raw 'custom' licence id (D5)")
        # CalCOFI.github.io#26: the page lists EVERY measurement the dataset ships, the per-cast ones
        # too (they live in sample_measurement; the page once listed 2 of calcofi_ctd-derived's 9).
        # The record is the same _data/measurements.json the build read.
        mrec = _read_json(os.path.join(_data_dir(), "measurements.json")) or {}
        items = mrec.get("measurements") or []
        items = items if isinstance(items, list) else list(items.values())
        want_m = sorted({m.get("slug") or m["key"] for m in items if any(sr.get("dataset_key") == key for sr in m.get("series") or [])})
        if want_m and sorted(set(dp["measKeys"])) != want_m:
            fails.append(f"{where}: the page lists {len(set(dp['measKeys']))} measurements, the record carries {len(want_m)} for "
                         f"{key}: missing {sorted(set(want_m) - set(dp['measKeys']))[:5]}, extra "
                         f"{sorted(set(dp['measKeys']) - set(want_m))[:5]}")
        if len(dp["measKeys"]) != len(set(dp["measKeys"])):
            fails.append(f"{where}: a measurement is listed twice")
        for fct in dp["facts"]:
            n_ = int(re.sub(r"[^0-9]", "", fct["value"]) or 0)
            if fct["label"].startswith("Measurement") and n_ != len(dp["measKeys"]):
                fails.append(f"{where}: the band says {fct['value']} {fct['label']} but the page lists {len(dp['measKeys'])}")
            if fct["label"] in ("Taxon", "Taxa") and n_ != dp["taxaDrawn"] + dp["taxaMore"]:
                fails.append(f"{where}: the band says {fct['value']} {fct['label']} but the page holds {dp['taxaDrawn'] + dp['taxaMore']}")
        if dp["csvUnnamed"]:
            fails.append(f"{where}: {dp['csvUnnamed']} CSV button(s) do not say what they download")

    # D2 S1 S2 (round 2, WS-R4): the dataset page's own licence chip, keyword leaves, Access tabset
    hl = r.get("headLicence")
    if hl:
        notes.append(f"{where}: head licence chip {hl['text']!r}")
        if hl["text"] == "custom":
            fails.append(f"{where}: the head licence chip reads the raw 'custom' id (D5)")

    kw = r.get("keywordChips")
    if kw:
        notes.append(f"{where}: {len(kw)} keyword leaf chip(s)")
        for c in kw:
            if not c["title"]:
                fails.append(f"{where}: keyword chip {c['text']!r} has no title (S1)")
            # a holding's own keywords are flat phrases, no ">" — leaf == full path there by
            # construction, never re-cased (kw_leaf); only a real GCMD path must shorten
            elif ">" in c["title"] and c["text"] == c["title"]:
                fails.append(f"{where}: keyword chip {c['text']!r} shows the full GCMD path, not the leaf (S1)")

    at = r.get("dsAccessTabset")
    if at:
        notes.append(f"{where}: Access tabset {at['tabs']} tab(s), {at['panels']} panel(s), {at['shown']} shown")
        if at["tabs"] != at["panels"]:
            fails.append(f"{where}: Access has {at['tabs']} tab(s) but {at['panels']} panel(s) (S2)")
        if at["shown"] != 1:
            fails.append(f"{where}: Access shows {at['shown']} panel(s) at once, expected 1 (S2)")

    # a dataset's variables, by grain (CalCOFI.github.io#26): every group names the release table its
    # values live in, each heading's count is the chips drawn under it, and the page's total is their sum
    vg = r.get("varGroups")
    if vg:
        notes.append(f"{where}: variables {vg['total']} = " +
                     " + ".join(f"{g['table']} {g['chips']}" for g in vg["groups"]))
        for g in vg["groups"]:
            if g["table"] not in ("obs_env", "obs_bio", "sample_measurement"):
                fails.append(f"{where}: variable group {g['grain']!r} names table {g['table']!r}, expected obs_env | obs_bio | sample_measurement")
            if g["said"] != g["chips"]:
                fails.append(f"{where}: {g['table']} says {g['said']} variable(s) but draws {g['chips']}")
        if vg["total"] != sum(g["chips"] for g in vg["groups"]):
            fails.append(f"{where}: Coverage says {vg['total']} variables but its groups draw "
                         f"{sum(g['chips'] for g in vg['groups'])}")
        # the page's years cover BOTH grains: no group may run to a year the glance does not reach
        yr = re.compile(r"(?<![\d,])((?:19|20)\d{2})(?![\d,])")
        gl = [int(y) for y in yr.findall(vg.get("glance") or "")]
        for s in vg.get("summaries") or []:
            ys = [int(y) for y in yr.findall(s)]
            if ys and gl and max(ys) > max(gl):
                fails.append(f"{where}: a variable group runs to {max(ys)} but the years line says {vg['glance']!r}")
        if "calcofi_ctd-derived" in path and [g["table"] for g in vg["groups"]] != ["obs_env", "sample_measurement"]:
            fails.append(f"{where}: calcofi_ctd-derived should list its profile and its per-cast variables "
                         f"(obs_env, sample_measurement), got {[g['table'] for g in vg['groups']]}")

    if width <= 400:
        for u in r.get("urls", []):
            if u["lh"] and u.get("textH", u["h"]) > u["lh"] * 1.6:
                fails.append(f"{where}: URL text wraps ({u['textH']}px over a {u['lh']}px line): {u['t']}…")

    for ds_id, n in (r.get("tabledap") or {}).items():
        if n != 1:
            fails.append(f"{where}: ERDDAP id {ds_id} listed {n} times, expected once")

    # ── the species catalog's index (plan 2026-09-09 § S3; issue #30; the finder of front door v2) ─
    sp = r.get("species")
    if sp:
        rec = sp.get("rec") or {}
        fi = sp.get("finder")
        has_q = "q=" in path
        num = lambda t: int(re.sub(r"[^0-9]", "", (re.search(r"[\d,]+", t or "") or [""])[0]) or 0) if re.search(r"\d", t or "") else None  # noqa: E731
        if not fi:
            fails.append(f"{where}: the species index has no finder (#cf)")
        else:
            # the counts the page states are the record's (main's quiet line of five counts is gone with
            # the finder, which states the species beside the search and in the tab row, and the pages
            # over the tree: each one stated is checked, none is typed here)
            said = {"the search's count": (None if has_q else num(fi["n"]), rec.get("species_observed")),
                    "the tab row's species": (num(fi["count"]), rec.get("species_observed")),
                    "the tree's taxa": (num(fi["treeHead"]), rec.get("pages"))}
            for what, (got, want) in said.items():
                if want is not None and got is not None and got != want:
                    fails.append(f"{where}: {what} says {got}, the record says {want}")
            if not has_q and num(fi["n"]) is None:
                fails.append(f"{where}: the species index states no species count beside its search")
            if fi["recSpecies"] is not None and rec.get("species_observed") is not None and fi["recSpecies"] != rec["species_observed"]:
                fails.append(f"{where}: finder.json counts {fi['recSpecies']} species, the page's record {rec['species_observed']}")
            # Groups: one card per group of the finder's record (was D7 A's class list — the record's
            # classes, most observed first — which the finder regroups under plain names)
            if sp.get("view") == "groups" and not has_q:
                if not fi["recGroups"] or fi["groups"] != fi["recGroups"]:
                    fails.append(f"{where}: Groups draws {fi['groups']} cards, finder.json has {fi['recGroups']} groups")
            # the preview beside the list is drawn wherever there is room for it
            if width >= 1000 and sp.get("view") in ("groups", "list") and not (fi["pvShown"] and fi["pvTitle"]):
                fails.append(f"{where}: the finder's preview is not drawn beside the list at {width}px")
            if len(fi["yellow"]) > 1:
                fails.append(f"{where}: {len(fi['yellow'])} yellow buttons on the species index: {fi['yellow']}")
        # I1: the h1 is a name, not a sentence of numbers
        if not sp.get("h1"):
            fails.append(f"{where}: the species index has no h1")
        elif any(ch.isdigit() for ch in sp["h1"]):
            fails.append(f"{where}: the species index h1 carries a digit: {sp['h1']!r}")
        # the dense views stay, one click away: the tabs, unchanged panels behind them. The hierarchy
        # (main's icicle) is one of them again: ?tab=hierarchy lands on it (review S-29: it fell back to
        # Groups), and main's ?tab=classes lands on Groups, the view that took the class list's place.
        if sp.get("views") != SPECIES_VIEWS:
            fails.append(f"{where}: the view tabs read {sp.get('views')}, expected {' · '.join(SPECIES_VIEWS)}")
        if sp.get("panelsShown") != 1:
            fails.append(f"{where}: {sp.get('panelsShown')} view panels showing, expected exactly one")
        mtab = re.search(r"[?&]tab=([\w-]+)", path)
        want_view = SPECIES_OLD_VIEWS.get(mtab.group(1), mtab.group(1)) if mtab else None
        if want_view in SPECIES_VIEWS and sp.get("view") != want_view:
            fails.append(f"{where}: ?tab={mtab.group(1)} on the URL but the {sp.get('view')!r} view is selected, expected {want_view!r}")
        fails.extend(f"{where}: {x}" for x in hierarchy_faults(sp))
        if sp.get("neverShown"):
            fails.append(f"{where}: {sp['neverShown']} .cf-legacy block(s) on the species index — a view drawn where it is never shown")
        # the matrix is exactly (classes + the two rows the record makes necessary) x datasets
        if sp["rows"] and sp["cols"]:
            wantc = sp["rows"] * sp["cols"]
            if sp["cells"] != wantc:
                fails.append(f"{where}: the matrix has {sp['cells']} cells for "
                             f"{sp['rows']} rows x {sp['cols']} datasets ({wantc})")
        if sp["treeRoots"] < 2:
            fails.append(f"{where}: the tree drew {sp['treeRoots']} roots")
        if sp["warnEls"]:
            fails.append(f"{where}: --warn on the species index: {', '.join(sorted(set(sp['warnEls']))[:4])}")
        # WS-F4: a phylum/class row's silhouette must not change the row's height
        if sp.get("treeRowH") is not None and sp["treeRowH"] != sp["treeRowHNoSil"]:
            fails.append(f"{where}: a tree row with its silhouette is {sp['treeRowH']}px, "
                         f"{sp['treeRowHNoSil']}px without it — the glyph grew the row")
        notes.append(f"{where}: view {sp.get('view')}, {fi['groups'] if fi else '?'} groups / {len(fi['rows']) if fi else '?'} rows drawn, "
                     f"matrix {sp['cells']} cells, hierarchy {(sp.get('ice') or {}).get('rects')} bands as landed / "
                     f"{(sp.get('icePressed') or {}).get('rects')} when its tab is pressed, content {sp['contentH']}px")
        # issue #30: a height ceiling with nothing open — the mockup's 1,775 px + 25 %
        if width >= 1400 and not has_q and sp.get("view") == SPECIES_VIEWS[0] and sp["contentH"] > MAX_SPECIES_INDEX_H:
            fails.append(f"{where}: the species index is {sp['contentH']}px with nothing open, "
                         f"ceiling {MAX_SPECIES_INDEX_H}px")
        # I2 (umbrella D9): a shared ?q= link lands with the search applied — the finder's list holds the
        # matches (was the flat #sp-matches list above the views), most recorded first
        # a search finds the higher taxa too (2026-11-17; main's one search listed the genus Sardinops for
        # "sardin", the finder listed species only): every taxon with a page that is not a species row is
        # in /species/finder-taxa.json and is listed APART from the species, under them, only on a search
        if fi:
            fails.extend(f"{where}: {x}" for x in higher_faults(fi, has_q, rec.get("pages")))
        if has_q and fi:
            rows = fi["rows"]
            if sp.get("view") != "list":
                fails.append(f"{where}: ?q= on the URL but the {sp.get('view')!r} view shows, not the list of matches")
            if re.search(r"[?&]q=sardin\b", path):
                hi = fi.get("higher") or []
                genus = [x for x in hi if x["name"] == "Sardinops"]
                if len(rows) + len(hi) < 2:
                    fails.append(f"{where}: 'sardin' finds {len(rows)} species row(s) and {len(hi)} other taxa, expected >= 2 "
                                 f"(the species and the genus Sardinops, as on main)")
                elif not rows or "Sardinops" not in rows[0]:
                    fails.append(f"{where}: the list's first row for 'sardin' is {rows[0] if rows else None!r}, "
                                 f"expected a Sardinops by observations")
                elif not genus:
                    fails.append(f"{where}: 'sardin' does not list the genus Sardinops among the other taxa ({[x['name'] for x in hi]})")
                elif not genus[0]["sub"].startswith("Genus") or not re.search(r"^[\d,]+ species$", genus[0]["holds"]):
                    fails.append(f"{where}: the genus Sardinops is listed as {genus[0]['sub']!r} holding {genus[0]['holds']!r}, "
                                 f"expected its rank and how many species it holds")
                if fi["recRows"] and not (0 < len(rows) < fi["recRows"]):
                    fails.append(f"{where}: 'sardin' keeps {len(rows)} of {fi['recRows']} rows")
                if num(fi["n"]) != len(rows):
                    fails.append(f"{where}: the search's count says {fi['n']!r} for {len(rows)} rows drawn")
            if rows:
                notes.append(f"{where}: {len(rows)} match(es), first {rows[0][:50]!r}; other taxa: "
                             f"{', '.join(x['name'] + ' (' + x['sub'] + ')' for x in (fi.get('higher') or [])[:4]) or 'none'}")

    # ── one taxon page (issue #30: D11 A, D12 A, D14 A, D17 A) ──────────────────────
    spp = r.get("speciesPage")
    if spp:
        rec_rows = spp["recRows"]
        rows = spp["rows"]
        if len(rows) != len(rec_rows):
            fails.append(f"{where}: {len(rows)} \"Observed in\" rows for {len(rec_rows)} datasets in the record")
        else:
            for got, wantr in zip(rows, rec_rows):
                if got["name"].strip() != wantr["name"]:
                    fails.append(f"{where}: row {got['name']!r}, the record says {wantr['name']!r}")
                if got["n"] != wantr["n"]:
                    fails.append(f"{where}: {wantr['name']} shows {got['n']} observations, "
                                 f"the record says {wantr['n']}")
        if not spp["lineage"]:
            fails.append(f"{where}: the taxon page has no lineage")
        # D12 A: the ways are one line of links, the code behind a fold that takes the ways_tabs include
        if not spp.get("waysTabset"):
            fails.append(f"{where}: the Code fold has no .tabset — the ways_tabs.html include is missing")
        if spp.get("waysLine", 0) < 2:
            fails.append(f"{where}: the ways line draws {spp.get('waysLine')} link(s)")
        # D14 A: every fold titled with its answer, and every fold closed on load
        if spp.get("foldsOpen"):
            fails.append(f"{where}: fold(s) open on load: {', '.join(spp['foldsOpen'])}")
        if spp.get("foldsNoAns"):
            fails.append(f"{where}: fold(s) with no answer in the title: {', '.join(spp['foldsNoAns'])}")
        # D17 A: no sub-nav
        if spp.get("subnav"):
            fails.append(f"{where}: {spp['subnav']} sub-nav(s) on the taxon page")
        for a in spp["lineage"]:
            if not str(a["href"]).startswith("/species/"):
                fails.append(f"{where}: lineage link {a['name']!r} does not point at a species page: {a['href']!r}")
        if spp["key"] and str(spp["key"]).startswith(("worms:", "itis:")):
            wanted = f"https://calcofi.io/explore/?taxon={spp['key']}"
            if wanted not in spp["explore"]:
                fails.append(f"{where}: the Explorer link is {spp['explore']!r}, expected {wanted}")
        if len(rec_rows) and spp["stripRows"] != len(rec_rows):
            fails.append(f"{where}: {spp['stripRows']} years strip(s) drawn for {len(rec_rows)} datasets")
        if rec_rows and spp["stripH"] < 20:
            fails.append(f"{where}: a years strip is {spp['stripH']}px tall though the record has "
                         f"{len(rec_rows)} dataset(s) — it is drawn but not displayed")
        notes.append(f"{where}: {len(rows)} dataset row(s), {len(spp['lineage'])} lineage links, "
                     f"{spp['stripRows']} strips / {spp['stripH']}px, {spp['folds']} folds, "
                     f"content {spp['contentH']}px, stats {' · '.join(spp['stats'])}")
        # issue #30: a height ceiling with nothing open — the mockup's ~1,200 px + 25 %
        if width >= 1400 and spp["contentH"] > MAX_SPECIES_PAGE_H:
            fails.append(f"{where}: the taxon page is {spp['contentH']}px with nothing open, "
                         f"ceiling {MAX_SPECIES_PAGE_H}px")
        # the sardine is the named regression case: its lineage, its two datasets and their counts
        if spp["key"] == "worms:217452":
            chain = [a["name"] for a in spp["lineage"]]
            wantchain = ["Biota", "Animalia", "Chordata", "Vertebrata", "Gnathostomata", "Osteichthyes",
                         "Actinopterygii", "Actinopteri", "Teleostei", "Clupeiformes", "Alosidae", "Sardinops"]
            if chain != wantchain:
                fails.append(f"{where}: the sardine's lineage reads {' › '.join(chain)}")
            if spp["here"] != "Sardinops sagax":
                fails.append(f"{where}: the lineage ends at {spp['here']!r}, expected 'Sardinops sagax'")
            if spp.get("h1Italic") != "italic":
                fails.append(f"{where}: the species name is not italic ({spp.get('h1Italic')!r})")

    # ── the face row, the sentence, the glance and the ladder (plan 2026-09-11) ─
    fa = r.get("faces")
    if fa:
        sd = fa.get("size") or {}
        # D9: the page's biggest number is "records" until the record carries n_present, and
        # "observations" (with "records" beside it) the moment it does. The word follows the
        # record, so the check reads the same field the generator does.
        words = fa["statWords"]
        if words:
            if "observations" in words and "records" not in words:
                fails.append(f"{where}: the stat says 'observations' alone — a row of obs_bio is not "
                             f"an organism; D9 wants 'records' until n_present is in the record")
            if ("observations" in words and "records" in words
                    and words.index("observations") > words.index("records")):
                fails.append(f"{where}: 'records' is drawn before 'observations' in the stat row")
        # the sentence (round 2 § P1, D6): its parts are marked, and each ends in exactly one source
        # badge — the underline + legend idiom is retired, so a stray .sp-legend is a regression
        parts = [p for p in fa["sentParts"] if p.startswith("s-")]
        badges = fa.get("badges", [])
        if parts and len(badges) != len(parts):
            fails.append(f"{where}: the sentence has {len(parts)} marked part(s) {parts} but "
                         f"{len(badges)} source badge(s)")
        if fa.get("legendCount"):
            fails.append(f"{where}: the sentence still carries a .sp-legend "
                         f"({fa['legendCount']}) — retired in favour of the source badges")
        if fa["sil"]:
            s = fa["sil"]
            if s["role"] != "img" or not s["label"]:
                fails.append(f"{where}: the silhouette has role={s['role']!r} aria-label={s['label']!r}")
            if s["w"] < 20 or s["h"] < 20:
                fails.append(f"{where}: the silhouette is drawn {s['w']}x{s['h']}px")
            sil_credit = next((c for c in fa["credits"] if c.startswith("Silhouette")), None)
            notes.append(f"{where}: silhouette {s['w']}x{s['h']} {s['label']!r}"
                         + (f" · {sil_credit}" if sil_credit else ""))
        if fa["photo"]:
            p = fa["photo"]
            if not p["alt"]:
                fails.append(f"{where}: the photo has no alt text")
            if p["loading"] == "lazy":
                fails.append(f"{where}: the head photo is loading=lazy (it is the page's one picture, above the fold)")
            if p["w"] < 40 or p["h"] < 40:
                fails.append(f"{where}: the photo is drawn {p['w']}x{p['h']}px")
            notes.append(f"{where}: photo {p['w']}x{p['h']} pos {p['pos']}"
                         + (" · NC labelled" if fa["nc"] else ""))
        # D11 A: the head carries ONE picture — the photo, or the silhouette where there is none
        if (fa["photo"] or fa.get("silPic")) and fa.get("pics") != 1:
            fails.append(f"{where}: the head draws {fa.get('pics')} pictures, expected one")
        if fa["photo"] and fa.get("silPic"):
            fails.append(f"{where}: the head draws the photo AND the silhouette as its picture")
        # the glance: two bars, or one honest line — never a blank slot
        if fa["sil"] or fa["photo"]:
            if not fa["glanceNone"] and len(fa["bars"]) != 2:
                fails.append(f"{where}: the glance draws {len(fa['bars'])} bar(s) and does not say "
                             f"'not on record'")
            if fa["bars"] and min(fa["bars"]) < 1:
                fails.append(f"{where}: a glance bar is drawn {min(fa['bars'])}px wide")
        # the How big section: drawn exactly when the payload has something to draw
        if fa["howBig"]:
            want_marks = len(sd.get("early") or []) + (1 if sd.get("size") else 0)
            if want_marks and not fa["ladderDrawn"]:
                fails.append(f"{where}: the ladder is not drawn though the payload has {want_marks} mark(s)")
            if fa["ladderDrawn"]:
                if fa["ladderMarks"] != want_marks:
                    fails.append(f"{where}: the ladder draws {fa['ladderMarks']} mark(s) for "
                                 f"{want_marks} in the payload")
                if fa["ladderRefs"] != len(sd.get("refs") or []):
                    fails.append(f"{where}: the ladder labels {fa['ladderRefs']} reference(s) for "
                                 f"{len(sd.get('refs') or [])} in size_reference.csv")
                # no two labels may overlap: a ladder whose text collides is unreadable, and the
                # greedy row assignment in species.js is the only thing preventing it
                ls = fa["labels"]
                for i in range(len(ls)):
                    for j in range(i + 1, len(ls)):
                        a, b = ls[i], ls[j]
                        if a["g"] == b["g"] and a["g"] >= 0:
                            continue        # a reference's own name and length, stacked on purpose
                        if (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"]
                                and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]):
                            fails.append(f"{where}: ladder labels overlap: {a['t']!r} and {b['t']!r}")
                notes.append(f"{where}: ladder {fa['ladderMarks']} marks, {fa['ladderRefs']} references, "
                             f"{len(fa['labels'])} labels, none overlapping")
            if sd.get("size") and sd.get("sil", {}) and (sd.get("sil") or {}).get("axis") and not fa["besideDrawn"]:
                fails.append(f"{where}: the beside figure is not drawn though the taxon has a length "
                             f"and the silhouette a length axis")
            if bool(sd.get("plate")) != fa["plateImg"]:
                fails.append(f"{where}: the plate is {'missing' if sd.get('plate') else 'invented'} "
                             f"(the payload's plate is {sd.get('plate') and sd['plate'].get('src')!r})")
            if fa["early"] < len(sd.get("early") or []):
                fails.append(f"{where}: {fa['early']} early-life row(s) for "
                             f"{len(sd.get('early') or [])} in the payload")
        elif sd:
            fails.append(f"{where}: a How big payload exists but no section is drawn")
        # a credit line for every asset that is shown: a picture without one is not publishable
        if fa["sil"] and not any(c.startswith("Silhouette") for c in fa["credits"]):
            fails.append(f"{where}: the silhouette is drawn with no credit line")
        if fa["photo"] and not any(c.startswith("Photo") for c in fa["credits"]):
            fails.append(f"{where}: the photo is drawn with no credit line")
        if fa["plateImg"] and not any(c.startswith("Plate") for c in fa["credits"]):
            fails.append(f"{where}: the plate is drawn with no credit line")

    # every URL row is one line, and elided from the middle rather than wrapped or simply cut off
    for u in r.get("spUrls", []):
        if u["lh"] and u["h"] > u["lh"] * 1.6:
            fails.append(f"{where}: a species URL wraps ({u['h']}px over a {u['lh']}px line): {u['t']}…")
        if u["overflow"]:
            fails.append(f"{where}: a species URL overflows its line rather than being elided: {u['t']}…")
        if u["full"] and u["shown"] < u["full"] and not u["elided"]:
            fails.append(f"{where}: a species URL is cut short without an ellipsis: {u['t']}…")

    # ── the measurements catalog (plan 2026-09-10 § D5, D6; § Verification M4) ─
    mm = r.get("mm")
    if mm:
        rec = mm["rec"] or {}
        # I1: the h1 is a name, not a sentence of numbers — the band below carries them, once
        if mm.get("h1") and any(ch.isdigit() for ch in mm["h1"]):
            fails.append(f"{where}: the measurements index h1 carries a digit: {mm['h1']!r}")
        notes.append(f"{where}: timeline {mm['tlRows']} rows / {mm['tlBars']} bars in {mm['tlCats']} categories, "
                     f"matrix {mm['mxRows']}x{mm['ds']} = {mm['mxCells']} cells ({mm['mxFilled']} with a series, "
                     f"summing {mm['mxSum']}), {mm['dsRows']} datasets, list {mm['listRows']} rows in "
                     f"{len(mm['listCats'])} categories ({mm.get('listInView')} in view, "
                     f"{sum(1 for c in mm['listCats'] if c.get('says') == 'true')} open), {r.get('docHeight')}px")
        # (a page that lands on a search, ?q=, draws the matches only: the timeline against the record
        # is judged on the page with no search, and there it must still find something)
        has_q = bool(mm.get("q"))
        if has_q:
            if not (0 < mm["tlRows"] < (rec.get("measurements") or 0)):
                fails.append(f"{where}: ?q={mm['q']} leaves the timeline {mm['tlRows']} of {rec.get('measurements')} rows")
        else:
            if mm["tlRows"] != rec.get("measurements"):
                fails.append(f"{where}: the timeline draws {mm['tlRows']} rows, the record has "
                             f"{rec.get('measurements')} measurements")
            if mm["tlBars"] != mm["recSeries"] or mm["tlBars"] != rec.get("series"):
                fails.append(f"{where}: the timeline draws {mm['tlBars']} bars, the record has "
                             f"{mm['recSeries']} series in rows[] and {rec.get('series')} in counts")
            if mm["tlCats"] != mm["cats"]:
                fails.append(f"{where}: {mm['tlCats']} category headings for {mm['cats']} categories")
        # the matrix is category x dataset, every cell drawn, the counts summing to the series
        if mm["mxCells"] != mm["cats"] * mm["ds"]:
            fails.append(f"{where}: the matrix has {mm['mxCells']} cells, expected "
                         f"{mm['cats']}x{mm['ds']} = {mm['cats'] * mm['ds']}")
        if mm["mxHeads"] != mm["ds"] + 1 or mm["mxRows"] != mm["cats"]:
            fails.append(f"{where}: the matrix has {mm['mxHeads']} column heads and {mm['mxRows']} row "
                         f"labels, expected {mm['ds'] + 1} and {mm['cats']}")
        if mm["mxSum"] != mm["recSeries"]:
            fails.append(f"{where}: the matrix cells sum to {mm['mxSum']}, the record has "
                         f"{mm['recSeries']} category x dataset series")
        if mm["dsRows"] != mm["ds"] or mm["legend"] != mm["ds"]:
            fails.append(f"{where}: {mm['dsRows']} dataset rows and {mm['legend']} legend entries for "
                         f"{mm['ds']} datasets")
        if mm["barsWithoutName"] > 0:
            fails.append(f"{where}: {mm['barsWithoutName']} timeline bar(s) with no dataset name in the row "
                         "— identity by colour alone")
        # the timeline is wider than a phone ON PURPOSE: its own container must scroll, not the page
        if mm["tlWidth"] > mm["tlScroller"] and mm["tlOverflowX"] not in ("auto", "scroll"):
            fails.append(f"{where}: the timeline is {mm['tlWidth']}px in a {mm['tlScroller']}px container "
                         f"whose overflow-x is {mm['tlOverflowX']}")
        if mm["tlRole"] != "table":
            fails.append(f"{where}: the timeline's role is {mm['tlRole']!r}, expected 'table'")
        if mm["tipRole"] != "tooltip":
            fails.append(f"{where}: the tooltip's role is {mm['tipRole']!r}, expected 'tooltip'")
        # issue #30 D8 A: the default view is the LIST — since front door v2 the finder's By category
        # (then A–Z), each category a section saying its count over its rows; every key once, the
        # counts the record's. The categories are COLLAPSED on load again (2026-11-17, Ben: the finder
        # listed every category open, 8,643 px): `category_faults` holds the closed default, the press
        # and the search, and MAX_MM_INDEX_H the short page that buys. (D8 A's "unified keys on top"
        # has no counterpart: the finder marks a unified key in its own row.)
        lc = mm["listCats"]
        fails.extend(f"{where}: {x}" for x in category_faults(mm, width))
        if mm.get("neverShown"):
            fails.append(f"{where}: main's list is built and never shown ({mm['neverShown']} of .cf-legacy, #mm-cats, #mm-unified)")
        if mm.get("noscriptRows") != rec.get("measurements"):
            fails.append(f"{where}: without JavaScript the page lists {mm.get('noscriptRows')} measurement(s) (<noscript>), "
                         f"the record has {rec.get('measurements')}")
        if not mm["listShown"] or mm["viewTabs"][:2] != ["cat", "az"] or mm.get("view") not in ("cat", "az"):
            fails.append(f"{where}: the list is not the default view (tabs {mm['viewTabs']!r}, selected {mm.get('view')!r})")
        if "timeline" not in mm["viewTabs"] or "matrix" not in mm["viewTabs"]:
            fails.append(f"{where}: the timeline and the matrix are not view tabs ({mm['viewTabs']!r})")
        if mm.get("view") == "cat":
            if not has_q and len(lc) != mm["cats"]:
                fails.append(f"{where}: the list has {len(lc)} category sections for {mm['cats']} categories")
            for c in lc:
                if c["n"] != c["rows"]:
                    fails.append(f"{where}: category {c['cat']!r} says {c['n']} but lists {c['rows']}")
        said_n = int(re.sub(r"[^0-9]", "", mm.get("countSaid") or "") or 0)
        if has_q:
            # a shared ?q= link lands with the search applied: fewer rows than the record, the count the rows drawn
            if not (0 < mm["listRows"] < (rec.get("measurements") or 0)) or said_n != mm["listRows"]:
                fails.append(f"{where}: ?q={mm['q']} lists {mm['listRows']} of {rec.get('measurements')} measurements and says {mm.get('countSaid')!r}")
        else:
            if mm["listRows"] != rec.get("measurements") or len(set(mm["listKeys"])) != mm["listRows"]:
                fails.append(f"{where}: the list holds {mm['listRows']} rows ({len(set(mm['listKeys']))} distinct keys), the "
                             f"record has {rec.get('measurements')} measurements")
            if said_n != rec.get("measurements"):
                fails.append(f"{where}: the search's count says {mm.get('countSaid')!r}, the record has {rec.get('measurements')} measurements")
        if mm["listRowsNoName"]:
            fails.append(f"{where}: {mm['listRowsNoName']} list row(s) name no dataset")
        if width >= 1000 and not mm.get("pvShown"):
            fails.append(f"{where}: the finder's preview is not drawn beside the list at {width}px")
        if width >= 1400 and not has_q and (r.get("docHeight") or 0) > MAX_MM_INDEX_H:
            fails.append(f"{where}: the catalog is {r.get('docHeight')}px with nothing open, max {MAX_MM_INDEX_H}")
        s = mm.get("search") or {}
        pr = mm.get("press")
        if pr:
            notes.append(f"{where}: pressing {pr['cat']!r} puts {pr['shown']} of {pr['rows']} rows in view, its button moved {pr['moved']}px, "
                         f"preview {pr.get('pvTitle')!r}; pressed again {(pr.get('again') or {}).get('shown')} in view")
        notes.append(f"{where}: search " + " · ".join(f"{t}: {v['list']} listed in {len(v.get('cats') or [])} categor{'y' if len(v.get('cats') or []) == 1 else 'ies'}"
                                                      f" / {v['rows']} timeline" for t, v in s.items()))
        for term in ("nitrate", "NTRAZZXX", "µmol/kg", "METS"):
            if s.get(term, {}).get("rows", 0) < 1:
                fails.append(f"{where}: the index search finds nothing for {term!r} in the timeline")
            if s.get(term, {}).get("list", 0) < 1:
                fails.append(f"{where}: the one search finds nothing for {term!r} in the list")

    if r.get("mmError"):
        fails.append(f"{where}: the measurement-page probe threw: {r['mmError']}")
    mfo = r.get("mmFolds")
    if mfo:
        # issue #30: one column; Measured in open; the ways one line; everything else a fold, closed
        # on load and titled with its answer (D14); the page within its height with nothing open
        notes.append(f"{where}: {len(mfo['ids'])} folds {mfo['titles']!r}, {r.get('docHeight')}px")
        if mfo["openOnLoad"]:
            fails.append(f"{where}: folds open on load: {mfo['openOnLoad']!r}")
        if mfo["noAnswer"]:
            fails.append(f"{where}: folds with no answer in their title: {mfo['noAnswer']!r} (D14)")
        if not mfo["measuredOpen"]:
            fails.append(f"{where}: 'Measured in' is not an open section")
        if mfo["waysLine"] < 3:
            fails.append(f"{where}: the ways line has {mfo['waysLine']} link(s)")
        if "ways" not in mfo["ids"] or "cite" not in mfo["ids"]:
            fails.append(f"{where}: no 'Every way in' or 'Cite' fold ({mfo['ids']!r})")
        if width >= 1400 and (r.get("docHeight") or 0) > MAX_MM_PAGE_H:
            fails.append(f"{where}: the page is {r.get('docHeight')}px with nothing open, max {MAX_MM_PAGE_H}")

    mp = r.get("mmPage")
    if mp:
        notes.append(f"{where}: strip {mp['stripRows']} rows / {mp['stripRects']} year cells / {mp['stripH']}px, "
                     f"depth {mp['depthBands']} bands x {mp['recRows']} series = {mp['depthBars']} bars, "
                     f"months {mp['monthCells']} cells, {len(mp['rows'])} series rows")
        if not mp["stripDrawn"] or mp["stripH"] < 20:
            fails.append(f"{where}: the years strip is not drawn (.mm-drawn {mp['stripDrawn']}, "
                         f"{mp['stripH']}px tall)")
        if mp["stripRows"] != mp["recRows"]:
            fails.append(f"{where}: {mp['stripRows']} row(s) draw a years strip, the record has {mp['recRows']} series")
        if mp["stripRects"] != mp["recRects"]:
            fails.append(f"{where}: the strip draws {mp['stripRects']} year cells, the record counts "
                         f"{mp['recRects']} years with a value")
        if mp["depthBands"] != mp["recBands"] or mp["depthBars"] != mp["recBands"] * mp["recRows"]:
            fails.append(f"{where}: the depth bars draw {mp['depthBands']} bands x {mp['depthBars']} bars, "
                         f"the record has {mp['recBands']} bands x {mp['recRows']} series")
        if mp["depthLabelsOut"]:
            fails.append(f"{where}: {mp['depthLabelsOut']} depth-bar end label(s) hang outside their column")
        if mp["recRows"] > 1 and mp["depthLegend"] != mp["recRows"]:
            fails.append(f"{where}: {mp['depthLegend']} legend entries for {mp['recRows']} series "
                         "— two series need a legend")
        if mp["monthCells"] != 12 * mp["monthRows"] or mp["monthLetters"] != 12:
            fails.append(f"{where}: the month strip draws {mp['monthCells']} cells and {mp['monthLetters']} "
                         f"letters, expected {12 * mp['monthRows']} and 12")
        if len(mp["rows"]) != mp["recRows"] or not all(x["dot"] and x["name"] for x in mp["rows"]):
            fails.append(f"{where}: the Measured-in rows are {mp['rows']!r}, the record has {mp['recRows']} series")
        if mp["key"] == "temperature" and f"/explore/?var=temperature" not in " ".join(mp["explore"]):
            fails.append(f"{where}: the Explorer link does not open prefilled on the key: {mp['explore']!r}")

        # ── WS-R3 (plan 2026-09-15 § M1, M7–M9, M11–M13, § D8) ──────────────────
        if not mp["noFlagnote"]:
            fails.append(f"{where}: .mm-flagnote is still on the page (M1 retired it)")
        if not mp["statFlag"]:
            fails.append(f"{where}: no .mm-stat-flag in the stats band")
        if not mp["noWhat"]:
            fails.append(f"{where}: #what is still on the page (M7 retired 'What it is')")
        if not mp["noCol"]:
            fails.append(f"{where}: #mmf-col is still on the page (M9 retired 'Where in the water column')")
        hp = mp["howPanels"]
        if hp:
            if hp["panels"] < 1:
                fails.append(f"{where}: the methods tabset (#ts-how) has no panels")
            if hp["tabrow"] and hp["buttons"] != hp["panels"]:
                fails.append(f"{where}: the methods tabset has {hp['buttons']} tab(s) for {hp['panels']} panel(s)")
            if hp["panels"] == 1 and hp["tabrow"]:
                fails.append(f"{where}: a single method still draws a tab row")
            notes.append(f"{where}: methods tabset {hp['panels']} panel(s), tabrow={hp['tabrow']}")
        if mp["qualChips"] != 4:
            fails.append(f"{where}: the quality chip line has {mp['qualChips']} chip(s), expected 4")
        if not mp["waysTabset"]:
            fails.append(f"{where}: no ways-in tabset (M12)")
        elif mp["waysAppButtons"] < 1:
            fails.append(f"{where}: the ways-in tabset has no app button (Explorer/db-query)")

    for u in r.get("mmUrls", []):
        if u["lh"] and u["h"] > u["lh"] * 1.6:
            fails.append(f"{where}: a measurement URL wraps ({u['h']}px over a {u['lh']}px line): {u['t']}…")
        if u["overflow"]:
            fails.append(f"{where}: a measurement URL overflows its line rather than being elided: {u['t']}…")
        if u["full"] and u["shown"] < u["full"] and not u["elided"]:
            fails.append(f"{where}: a measurement URL is cut short without an ellipsis: {u['t']}…")

    # ── measurement faces (plan 2026-09-11 § D1–D7, § Verification MF5; round 2 D3/D4) ───
    # Every assertion reads the page's OWN #mm-face payload, so it can only pass by the drawing
    # actually matching the record and the media sidecar it was built from.
    mfa = r.get("mfaces")
    if mfa:
        P = mfa.get("payload") or {}
        kind = mfa.get("kind")
        # issue #30: the face row's What column is the head's ONE picture, and How then Why are folds,
        # always in that order — a reader who has read one page has read all
        if not mfa["what"]:
            fails.append(f"{where}: the head carries no picture (.calm-head .mmf-what) though the page has a face")
        fo = [f for f in mfa["folds"] if f in ("how", "why")]
        if fo != ["how", "why"]:
            fails.append(f"{where}: the face's folds are {fo!r}, expected how · why")
        # the WHAT picture is never empty: a drawn structure, or a small figure in its place
        if not mfa["mols"] and not mfa["mini"]:
            fails.append(f"{where}: the What column draws neither a structure nor a figure "
                         f"(face kind {kind!r})")
        for s in mfa["mols"]:
            if s["role"] != "img" or not s["label"]:
                fails.append(f"{where}: a structure has role={s['role']!r} aria-label={s['label']!r}")
            if s["w"] < 20 or s["h"] < 20:
                fails.append(f"{where}: a structure is drawn {s['w']}x{s['h']}px")
            if s["paths"] < 1:
                fails.append(f"{where}: a structure drew {s['paths']} shapes — the SVG is empty")
        # § D3: a stand-in says so, and NEVER wears the ids of the face it borrows
        if kind == "standsin":
            if not mfa["stands"]:
                fails.append(f"{where}: a stand-in face with no 'stands in' chip")
            for bad in ("ChEBI", "CAS", "WoRMS"):
                if bad in mfa["ids"]:
                    fails.append(f"{where}: a stand-in's ids row shows {bad} — the ids are not its own")
        elif mfa["stands"]:
            fails.append(f"{where}: a 'stands in' chip on a face of kind {kind!r}")
        # a pool or a mixture draws components but is not any one of them (§ D2, § F3)
        if kind in ("composition", "scale", "organism", "none"):
            for bad in ("ChEBI", "CAS"):
                if bad in mfa["ids"]:
                    fails.append(f"{where}: a {kind} face claims {bad} in its ids row — its S27 is "
                                 f"not the thing this page is about")
        # HOW: a platform glyph and a pin per method row the payload's page carries
        if mfa["plat"] < 1 and P.get("kind") != "none":
            notes.append(f"{where}: the How column draws no platform glyph")
        # ── round 2 (plan 2026-09-15 § D3, D4, § Verification R2) ─────────────────
        # M5: the sentence is PROSE — no NERC clause (the What column carries the definition,
        # § D3 say it once), one source badge per remaining part, and no legend paragraph.
        parts = [p for p in mfa["sentParts"] if p.startswith("s-")]
        if "s-nerc" in parts:
            fails.append(f"{where}: the sentence still carries the NERC clause (.s-nerc) — the "
                         f"What column is the one place the definition is written")
        if parts and mfa["sentBadges"] != len(parts):
            fails.append(f"{where}: the sentence has {len(parts)} marked part(s) {parts} but "
                         f"{mfa['sentBadges']} source badge(s)")
        if mfa["legend"]:
            fails.append(f"{where}: the sentence still prints a .mmf-legend ({mfa['legend']} entries) "
                         f"— the badge's hover is the legend now")
        # M2/M6: a SCALE kind's What column is the variable's own ramp over its bounds, with the
        # record's window and the registry's marks on it. A Beaufort key reads on its cells and an
        # organism, a structure, a composition or a stand-in on its own glyph — none of them here.
        ax = ((P.get("scale") or {}).get("axis") or {})
        if kind == "scale" and ax.get("type") not in ("beaufort",) and P.get("key") != "ph" \
                and not mfa["ramp"]:
            notes.append(f"{where}: a scale face draws no ramp (no rule in the Explorer's "
                         f"defaultRamp() matches {P.get('key')!r}) — the plain strip stands")
        if mfa["ramp"]:
            if not mfa["rampGrad"]:
                fails.append(f"{where}: the What column's ramp has no <linearGradient>")
            n_marks = len([r for r in ((P.get("scale") or {}).get("marks") or []) if r.get("v") is not None])
            if n_marks and not mfa["rampMarks"]:
                fails.append(f"{where}: the ramp draws none of the record's {n_marks} mark(s)")
            notes.append(f"{where}: ramp drawn with {mfa['rampMarks']} labelled mark(s)")
        # M3: the pin. The registry column is `calcofi_org_url`; reading a name that does not
        # exist left the pin off all 89 pages, so the two keys the plan names must carry one.
        if P.get("key") in ("temperature", "nitrate") and not mfa["pinHrefs"]:
            fails.append(f"{where}: no .mmf-pin — {P.get('key')}'s method row carries a "
                         f"calcofi.org URL in the record")
        if mfa["pinHrefs"]:
            for href in mfa["pinHrefs"]:
                if "calcofi.org" not in (href or ""):
                    fails.append(f"{where}: the How column's pin points at {href!r}, not calcofi.org")
            notes.append(f"{where}: pin \u2192 {mfa['pinHrefs'][0]}")
        # M4: the spark is drawn to ITS band's scale and says so — +top / 0 / \u2212top and the years
        if mfa["spark"]:
            if mfa["sparkTicks"] < 3:
                fails.append(f"{where}: the spark draws {mfa['sparkTicks']} axis tick(s), expected "
                             f"at least 3 (+top \u00b7 0 \u00b7 \u2212top)")
            if mfa["sparkStretch"] == "none":
                fails.append(f"{where}: the spark is drawn with preserveAspectRatio=none — its "
                             f"labels are stretched with it")
        # M10: the history carries its own scale per row (a \u00b1 beside every band) and the toggle
        if mfa["anomDrawn"]:
            if mfa["anomPm"] != len(bands_r2(P)):
                fails.append(f"{where}: the history writes {mfa['anomPm']} \u00b1 label(s) for "
                             f"{len(bands_r2(P))} band(s) \u2014 own scale per row is the default")
            if mfa["anomToggle"] != 2:
                fails.append(f"{where}: the history has {mfa['anomToggle']} scale radio(s), expected 2")
            if mfa["anomLegend"] < 3:
                fails.append(f"{where}: the history's one-line legend has {mfa['anomLegend']} entries")
        # one tooltip div for every face figure, never one per chart
        if mfa["tip"] > 1:
            fails.append(f"{where}: {mfa['tip']} .mmf-tip divs on the page, expected one")
        # § D5: the alternatives are CLOSED on load and the summary's count is the list's own
        det = mfa["det"]
        if det:
            if det["open"]:
                fails.append(f"{where}: 'other ways to say why' is open on load")
            m = re.search(r"·\s*(\d+)\s*$", det["summary"])
            if not m:
                fails.append(f"{where}: the why summary carries no count: {det['summary']!r}")
            elif int(m.group(1)) != det["items"]:
                fails.append(f"{where}: the why summary says {m.group(1)} but the list has "
                             f"{det['items']} item(s)")
            notes.append(f"{where}: face {kind} · {len(mfa['mols'])} structure(s) · "
                         f"why + {det['items']} alternative(s), closed")
        # the familiar scale: drawn where the payload has one, and no two mark labels overlapping
        want_scale = bool(P.get("scale"))
        if want_scale and not mfa["scaleDrawn"]:
            fails.append(f"{where}: the familiar scale is not drawn though the payload carries one")
        ms = mfa["marks"]
        for i in range(len(ms)):
            for j in range(i + 1, len(ms)):
                a, b = ms[i], ms[j]
                if (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"]
                        and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]):
                    fails.append(f"{where}: scale labels overlap: {a['t']!r} and {b['t']!r}")
        # § D6: one row per depth band the record measured in — the page's rows ARE the record's
        an = P.get("anomaly") or {}
        bands = an.get("bands") or []
        if bands and not mfa["anomDrawn"]:
            fails.append(f"{where}: the anomaly is not drawn though the record has {len(bands)} band(s)")
        if mfa["anomDrawn"]:
            # two labels a row (the band and its count) plus the two axis notes
            if mfa["anomRows"] != len(bands):
                fails.append(f"{where}: the anomaly draws {mfa['anomRows']} band label(s) for "
                             f"{len(bands)} band(s) in the record")
            want_bars = sum(len(b.get("series") or []) for b in bands)
            if mfa["anomBars"] < want_bars:
                fails.append(f"{where}: the anomaly draws {mfa['anomBars']} bar(s) for {want_bars} "
                             f"year-values in the record")
            notes.append(f"{where}: anomaly {len(bands)} bands, {want_bars} year-values, "
                         f"spark band {an.get('spark_band')!r}")
        elif not bands and mfa["scaleDrawn"] is not None:
            notes.append(f"{where}: no anomaly — the page says why instead")
        # § M9 (WS-R3, plan 2026-09-15): "Where in the water column" is retired — #mmf-col no
        # longer exists on the page (its bands are "By depth"'s, unchanged); mfa["col"] is always
        # falsy now, kept only so an older record replayed through this probe stays harmless.
        if mfa["col"] and mfa["colRows"] < 1:
            fails.append(f"{where}: the water-column figure is drawn with no bands")
        # § M7: "What it is" is retired (the definition moved to the head picture's caption, R2 and
        # issue #30); "How it is measured" and "Why it matters" remain as folds, in order
        if "What it is" in mfa["heads"]:
            fails.append(f"{where}: 'What it is' section still present ({mfa['heads']!r})")
        for h in ("How it is measured", "Why it matters"):
            if h not in mfa["heads"]:
                fails.append(f"{where}: no '{h}' section ({mfa['heads']!r})")
        idx = [mfa["heads"].index(h) for h in ("How it is measured", "Why it matters")
               if h in mfa["heads"]]
        if idx != sorted(idx):
            fails.append(f"{where}: the face sections are out of order: {mfa['heads']!r}")
        # nothing in the face may be wider than its own column
        for wtxt in mfa["wide"]:
            fails.append(f"{where}: a face block overflows its column: {wtxt}")

    # ── the front door (issue #30; the seven tasks; front door v2's first screen) ────────────────
    fr = r.get("front")
    if fr:
        H = fr["hero"]
        notes.append(f"{where}: page {fr['heightOnLoad']}px with {fr['openOnLoad'] or 'no'} panel open; strip {fr['stripRows']} rows, "
                     f"map {fr['mapMarks']} marks, {len(fr['pins'])} pins behind What CalCOFI collects; "
                     f"{len((fr.get('drive') or {}).get('anchors') or {})} old anchors driven")
        # the first screen itself: the seven tasks and the Query Builder each one visible link, the tap
        # targets, the start heading's contrast, the numbers inside the window, the strip under the cards
        check_first_screen(where, H, width, fails, notes)
        # no panel open on load unless the URL names one (a hash, ?door=, ?q= or ?tab=)
        names_one = bool(re.search(r"#.|[?&](door|q|tab)=", path))
        if not names_one and fr["openOnLoad"]:
            fails.append(f"{where}: {fr['openOnLoad']} open on load; the front door opens with every panel closed")
        if names_one and len(fr["openOnLoad"]) != 1:
            fails.append(f"{where}: the URL names a panel but {fr['openOnLoad'] or 'none'} opened")
        mdoor = re.search(r"[?&]door=([\w-]+)", path)
        if mdoor and mdoor.group(1) in FRONT_ANCHORS and fr["openOnLoad"] != [FRONT_ANCHORS[mdoor.group(1)]]:
            fails.append(f"{where}: ?door={mdoor.group(1)} opened {fr['openOnLoad']}, expected "
                         f"[{FRONT_ANCHORS[mdoor.group(1)]!r}]")
        # one screen (was FRONT_MAX_H): with nothing open the first screen ends at the window's bottom
        # and only the footer follows it
        if not names_one and width >= 1400:
            if H["bottom"] > H["innerH"] + 1:
                fails.append(f"{where}: the first screen ends at {H['bottom']}px, below the {H['innerH']}px window: it is more than one screen")
            gap = None if fr.get("footerTop") is None else fr["footerTop"] - H["bottom"]
            if gap is None or gap > 2:
                fails.append(f"{where}: {gap}px lie between the first screen and the footer with no panel open; nothing should")
        dv = fr.get("drive")
        if not dv:
            fails.append(f"{where}: the first screen has no link to #monitor and #program to open the panels with")
        else:
            if dv["afterA"] != ["monitor"]:
                fails.append(f"{where}: the first screen's link to #monitor left {dv['afterA']} open")
            if dv["afterB"] != ["program"]:
                fails.append(f"{where}: opening Work with the data in code did not close the monitoring panel ({dv['afterB']} open)")
            if dv["afterClose"]:
                fails.append(f"{where}: Close left {dv['afterClose']} open")
            # Close gives focus back to the link that opened the panel (there are no door buttons)
            fb = dv["focusBack"]
            if not fb["same"]:
                fails.append(f"{where}: after Close, focus is on {fb['tag']} {fb['href']!r}, not on the link that opened the panel")
            # the header's way in: Map ▾ › All apps opens Maps and apps; once focus has moved into the
            # panel and the menu has shut, Close must still put focus on something drawn
            vh = dv.get("viaHeader")
            if not vh:
                fails.append(f"{where}: the header has no line to Maps and apps (#explore)")
            else:
                if vh["opened"] != ["explore"]:
                    fails.append(f"{where}: the header's line to #explore opened {vh['opened']}, expected ['explore']")
                if vh["afterClose"]:
                    fails.append(f"{where}: Close left {vh['afterClose']} open after the header's line opened it")
                if not vh["seen"]:
                    fails.append(f"{where}: a panel opened from the header's menu, then closed: focus is on {vh['tag']} {vh['what']!r}, "
                                 f"which is not drawn (the line that opened it is hidden once its menu shuts) — focus is lost")
            if not dv["hasXref"]:
                fails.append(f"{where}: Maps and apps has no link to Find (#find): the Find panel is reachable from no visible link")
            elif dv["afterFind"] != ["find"]:
                fails.append(f"{where}: Maps and apps' link to Find left {dv['afterFind']} open")
            fb2 = dv["focusBack2"]
            if not fb2["drawn"]:
                fails.append(f"{where}: after closing a panel opened from inside another, focus is on {fb2['tag']}#{fb2['id']}, "
                             f"not on anything drawn")
            for h, want_k in FRONT_ANCHORS.items():
                got = (dv.get("anchors") or {}).get(h) or {}
                if got.get("open") != [want_k]:
                    fails.append(f"{where}: a link to #{h} opened {got.get('open')}, expected [{want_k!r}]")
                elif h in FRONT_LANDS and got.get("hash") != FRONT_LANDS[h]:
                    fails.append(f"{where}: a link to #{h} left the URL at #{got.get('hash')}, expected #{FRONT_LANDS[h]} "
                                 f"(where it now lives inside {want_k!r})")
            if dv["restored"] != fr["openOnLoad"]:
                fails.append(f"{where}: the probe could not put the panels back ({dv['restored']} vs {fr['openOnLoad']})")
        # yellow (see PANEL_YELLOW): nothing --warn on the first screen; exactly one yellow, the Explorer's
        if fr["warnEls"]:
            fails.append(f"{where}: --warn on the first screen: {', '.join(sorted(set(fr['warnEls']))[:4])}")
        ex_pat = next(t[2] for t in FRONT_TASKS if t[0] == "explore")
        ye = fr["ctaEls"]
        if len(ye) != 1 or not re.search(ex_pat, ye[0].get("href") or ""):
            fails.append(f"{where}: the first screen's yellow is {[(y['text'], y['href']) for y in ye]}, expected exactly one, "
                         f"the Explorer's button")
        for p in fr["panelCtas"]:
            want = PANEL_YELLOW.get(p["id"], 1)
            if len(p["yellow"]) != want:
                fails.append(f"{where}: the {p['id']!r} panel carries {len(p['yellow'])} yellow button(s) {p['yellow']}, expected {want}")
        # the annotated drawing behind What CalCOFI collects carries the pins
        if not fr["pins"]:
            fails.append(f"{where}: the What-CalCOFI-collects panel's annotated drawing carries no pins")
        # the numbers the first screen states equal the record's (see FRONT_NUMBERS)
        n = fr.get("reachNumbers") or {}
        want = {"years": n.get("years"), "cruises": n.get("cruises"), "stations": n.get("stations"),
                "species": n.get("species"), "measurements": n.get("measurements_m")}
        seen = {}
        for b in fr["band"]:
            key = next((k for k in want if b["label"].startswith(k)), None)
            if key:
                seen[key] = float(b["value"].replace(",", "").replace(" M", ""))
            else:
                fails.append(f"{where}: the first screen states {b['label']!r} = {b['value']!r}, which the record's numbers do not carry")
        for k in FRONT_NUMBERS:
            v = want.get(k)
            if v is None:
                continue          # the record cannot supply it: the number must be absent, and is
            if k not in seen:
                fails.append(f"{where}: the first screen has no {k!r} number though the record carries {v}")
        for k in seen:
            if want.get(k) is None:
                fails.append(f"{where}: the first screen shows {k!r} = {seen[k]:g} but the record carries no value")
            elif seen[k] != want[k]:
                fails.append(f"{where}: the first screen says {k} = {seen[k]:g}, the record says {want[k]}")
        for b in fr["band"]:
            if b["label"].split()[0] in ("species", "measurements") and not b["href"]:
                fails.append(f"{where}: the {b['label']!r} number is not a link to its catalog")
        mm, om, rm = n.get("measurements_m"), n.get("organism_obs_m"), n.get("rows_m")
        if None not in (mm, om, rm) and mm + om > rm:
            fails.append(f"{where}: measurements {mm} M + organism observations {om} M "
                         f"exceed the release's {rm} M rows")
        if fr["datasets"] is not None and fr["stripRows"] != fr["datasets"]:
            fails.append(f"{where}: Find's list has {fr['stripRows']} linked rows for {fr['datasets']} datasets")
        if fr["datasets"] is not None and fr["stripDrawn"] != fr["datasets"]:
            fails.append(f"{where}: Find's list draws the years of {fr['stripDrawn']} rows for {fr['datasets']} datasets")
        for row in fr.get("stripLinks") or []:
            want_h = f"/datasets/{row['key']}/"
            if row["href"] != want_h:
                fails.append(f"{where}: Find's list links {row['key']!r} to {row['href']!r}, expected {want_h}")
        # the Download control (2026-11-16): beside every name with zips in Find's list, and only there
        if "stripDl" in fr:
            reach_keys = {row["key"] for row in fr.get("stripLinks") or []}
            want_dl = sorted(k for k in download_offers(_data_dir()) if k in reach_keys)
            if sorted(fr["stripDl"]) != want_dl:
                fails.append(f"{where}: Find's list draws a Download control on {len(fr['stripDl'])} rows, expected "
                             f"{len(want_dl)} (the datasets with zips)")
        # the Explorer replaces the Data Finder (Ben, 2026-11-16): Find calls to it nowhere
        if fr.get("finderLinks"):
            fails.append(f"{where}: Find still links the Data Finder: {fr['finderLinks']}")
        fl = fr.get("findList")
        if dv and dv.get("afterFind") == ["find"] and not fl:
            fails.append(f"{where}: Find opened but its list of datasets (.fd-yname) could not be measured")
        if fl:
            notes.append(f"{where}: Find's names {fl['fontPx']}px {fl['color']} {fl['underline']}, rows >= {fl['minH']}px; "
                         f"search ends {fl['qBottom']}px and name 8 {fl['n8Bottom']}px below the panel's top; "
                         f"map card {fl['mapH']}px beside a {fl['headH']}px head")
            if fl["fontPx"] < FIND_NAME_MIN_PX:
                fails.append(f"{where}: Find's dataset names are {fl['fontPx']}px, under {FIND_NAME_MIN_PX}px")
            if fl["color"] != fr.get("accent"):
                fails.append(f"{where}: Find's dataset names are {fl['color']}, not the link colour --accent {fr.get('accent')}")
            if "underline" not in (fl["underline"] or ""):
                fails.append(f"{where}: Find's dataset names are not underlined ({fl['underline']!r})")
            tap = MIN_TAP if width < 900 else FIND_ROW_MIN_PX
            if fl["minH"] < tap:
                fails.append(f"{where}: a Find dataset name is {fl['minH']}px tall, under {tap}px")
            if width >= FOLD_W:
                room = FIND_FOLD_H - (fl.get("headerH") or HEADER_H)
                if fl["qBottom"] is None or fl["qBottom"] > room or fl["n8Bottom"] > room:
                    fails.append(f"{where}: with Find open the search ends {fl['qBottom']}px and the 8th name "
                                 f"{fl['n8Bottom']}px below the panel's top, beyond the {room}px under the header "
                                 f"of a {FOLD_W} x {FIND_FOLD_H} window")
                if fl["mapH"] > fl["headH"] + 40:
                    fails.append(f"{where}: Find's map card is {fl['mapH']}px beside a {fl['headH']}px head: it sets the block's height again")
        if fr["stations"] is not None and fr["mapMarks"] != fr["stations"]:
            fails.append(f"{where}: the map has {fr['mapMarks']} marks for {fr['stations']} grid cells")
        # nothing removed but what the Explorer replaced: every product in products.yml is a card in
        # some panel (an archived student project too), and a superseded app is in none (front door v2)
        cur, retired = product_keys(_products_text())
        if cur:
            drawn = set(fr["cardKeys"])
            missing = [k for k in cur if k not in drawn]
            if missing:
                fails.append(f"{where}: product(s) {missing} are drawn in no panel")
            ghosts = [k for k in retired if k in drawn]
            if ghosts:
                fails.append(f"{where}: superseded product(s) {ghosts} are still drawn as cards")
            if width >= 1400 and theme == "light":
                notes.append(f"{where}: {len(cur)} products drawn as cards; the {len(retired)} superseded "
                             f"({', '.join(retired) or 'none'}) are not drawn (front door v2: Maps and apps)")
        if r.get("scrollWidth") and r["scrollWidth"] > width:
            fails.append(f"{where}: the front door scrolls horizontally — scrollWidth {r['scrollWidth']} > {width}")

        # ── D7: the Data catalog (#datasets, inside Find) must not grow by a screen ──
        h = r.get("dataSectionH")
        if h and width >= 1400:
            notes.append(f"{where}: the Data catalog is {h}px (main measured {DATA_SECTION_BASE}px)")
            if h > DATA_SECTION_BASE + DATA_SECTION_GROWTH:
                fails.append(f"{where}: the Data catalog is {h}px, more than "
                             f"{DATA_SECTION_GROWTH}px taller than main's {DATA_SECTION_BASE}px")

        if width >= 1400 and theme == "light":      # once per run
            for href in fr["pins"]:
                ok = url_ok(href)
                if ok is None:
                    notes.append(f"{where}: pin {href} unreachable (warning only)")
                elif not ok:
                    fails.append(f"{where}: pin {href} does not answer 200/206")

    # ── the header: the words of _data/nav.yml and their menus (_includes/site_nav.html) ─────────
    nav = r.get("nav")
    if nav and nav["visible"]:
        notes.append(f"{where}: header {' · '.join(nav['words'])}; "
                     f"{len(nav['menus'])} menus ({', '.join(str(m['word']) + ' ' + str(len(m['tabs'])) for m in nav['menus'])}); "
                     f"{nav.get('tabStops')} tab stops with the menus shut")
        if not NAV_WORDS:
            fails.append(f"{where}: _data/nav.yml gives no words to hold the header to")
        if nav["words"] != NAV_WORDS:
            fails.append(f"{where}: the header reads {nav['words']}, expected {NAV_WORDS} (_data/nav.yml)")
        if nav.get("ids") != NAV_IDS:
            fails.append(f"{where}: the header's words are marked data-word={nav.get('ids')}, expected {NAV_IDS}")
        if "cc-nav" not in (nav.get("navClass") or "").split():
            fails.append(f"{where}: the header's nav is class={nav.get('navClass')!r}, not the brand's .cc-nav (brand/v3/header.css styles nothing else)")
        # sentence case (brand v3 § 4): the bar's words are not transformed
        if any(c != "none" for c in nav.get("cased") or []):
            fails.append(f"{where}: the header's words are text-transform {sorted(set(nav['cased']))}, expected none (sentence case)")
        # a destination is said once: a word of the bar is not also a line of a menu (FAQ and News are
        # words again since 2026-11-17, and no longer lines of Learn)
        hrefs = nav.get("allHrefs") or []
        twice = [h for i, h in enumerate(hrefs) if h in hrefs[:i]]
        if twice:
            fails.append(f"{where}: the header links {sorted(set(twice))} more than once")
        if [m["word"] for m in nav["menus"]] != NAV_MENUS:
            fails.append(f"{where}: the header's menus are {[m['word'] for m in nav['menus']]}, expected {NAV_MENUS}")
        for m in nav["menus"]:
            wd = m["word"]
            # the word is a button that says its state and names its panel
            if m["tag"] != "BUTTON":
                fails.append(f"{where}: the {wd!r} menu's word is a {m['tag']}, expected a button (it opens a panel, it does not go anywhere)")
            if not m["controls"] or m["controls"] != m["listId"]:
                fails.append(f"{where}: the {wd!r} menu's button controls {m['controls']!r}, its panel's id is {m['listId']!r}")
            if not m.get("closed", True) or m["expandedAtRest"] != "false":
                fails.append(f"{where}: the {wd!r} menu is open before anything is pressed (aria-expanded={m['expandedAtRest']!r})")
            if m.get("closedTabStops"):
                fails.append(f"{where}: {m['closedTabStops']} line(s) of the closed {wd!r} menu are still tab stops")
            # it opens on a press — a click, a tap, Enter or Space on the button — and not by focus alone
            if m.get("openOnFocus"):
                fails.append(f"{where}: the {wd!r} menu opens on focus alone: tabbing along the header throws it open")
            if not m.get("opensOnPress"):
                fails.append(f"{where}: the {wd!r} menu does not open on a press — a keyboard and a touch screen cannot reach it")
                continue
            if m["expandedOpen"] != "true":
                fails.append(f"{where}: the {wd!r} menu is open but its button says aria-expanded={m['expandedOpen']!r}")
            if not m.get("staysOpenInside"):
                fails.append(f"{where}: the {wd!r} menu shuts when focus moves onto one of its own lines")
            if not m.get("closesOnEscape"):
                fails.append(f"{where}: the {wd!r} menu does not close on Escape")
            elif not m.get("focusBackOnEscape"):
                fails.append(f"{where}: Escape closes the {wd!r} menu but focus is not back on its button")
            if m.get("closesOnEscape") and m["expandedAfterEscape"] != "false":
                fails.append(f"{where}: the {wd!r} menu is shut but its button says aria-expanded={m['expandedAfterEscape']!r}")
            if not m.get("closesOnBlur"):
                fails.append(f"{where}: the {wd!r} menu stays open after focus leaves it")
            if (m.get("offRight") or 0) > 0 or (m.get("offLeft") or 0) > 0:
                fails.append(f"{where}: the open {wd!r} menu runs {max(m.get('offRight') or 0, m.get('offLeft') or 0)}px outside the window")
            for t in m["tabs"]:
                # a line of a menu links a page, or a place on the landing page that a panel answers: a
                # hash no panel knows would land on the first screen and open nothing
                frag = (t.get("href") or "").partition("#")[2]
                if not t.get("href"):
                    fails.append(f"{where}: the {wd!r} menu's {t['title']!r} links nothing")
                elif frag and frag not in FRONT_ANCHORS:
                    fails.append(f"{where}: the {wd!r} menu's {t['title']!r} links #{frag}, which no panel of the front door answers")
            # the hover bridge: the panel's ::before must span the gap below the word (Ben, 2026-09-10 —
            # the live menu closed as soon as the pointer moved down to pick an item)
            if m.get("gap") is not None and (m.get("bridge") or 0) < m["gap"]:
                fails.append(f"{where}: the {wd!r} menu floats {m['gap']:.0f}px below its word but its hover "
                             f"bridge is {(m.get('bridge') or 0):.0f}px — the pointer leaves the menu on its way down")
        for m in nav["menus"]:
            if (m["word"] or "").lower() == "data":
                for t in m["tabs"]:
                    name = t["title"].split()[0].lower()
                    want = {"datasets": "/datasets/", "species": "/species/", "measurements": "/measurements/"}.get(name)
                    exists = name == "datasets" or r.get("pageExists", {}).get(want)
                    if want and exists and (t.get("href") or "").rstrip("/") + "/" != want:
                        fails.append(f"{where}: the Data menu's {t['title']!r} links {t.get('href')!r}, not {want} (the page exists)")
                    # the three catalogs carry their count, the catalog's own
                    if want and exists and not re.search(r"\d", t.get("pill") or ""):
                        fails.append(f"{where}: the Data menu's {t['title']!r} carries no count")
        # what main's header reached in one word stays reachable from this one (DOCS · FAQ · NEWS were
        # words until front door v2; they are lines of Learn now), and so do the three catalogs, the
        # Explorer, the Query Builder and how to cite
        for label, pat in NAV_REACH:
            if not any(re.search(pat, h or "") for h in nav.get("allHrefs") or []):
                fails.append(f"{where}: the header links {label} nowhere")
    elif nav and width < NAV_BREAK:
        notes.append(f"{where}: the header nav is hidden under {NAV_BREAK}px; the menu button carries it")

    # ── the header never wraps (2026-11-16): one line of nav from NAV_BREAK up, the menu button below
    hrow = r.get("headerRow")
    if hrow:
        if width >= NAV_BREAK and not hrow["navShown"]:
            fails.append(f"{where}: the header nav is hidden at {width}px; it shows from {NAV_BREAK}px")
        if width < NAV_BREAK and hrow["navShown"]:
            fails.append(f"{where}: the header nav is drawn at {width}px with the menu shut; under {NAV_BREAK}px the menu button carries it")
        if hrow["navShown"] and hrow["navSpread"] > 8:
            fails.append(f"{where}: the header nav wraps at {width}px ({hrow['navSpread']}px between its words' middles)")
        if hrow["rowLines"] > 8:
            fails.append(f"{where}: the header row is not one line ({hrow['rowLines']}px between its items' middles, "
                         f"{hrow['height']}px tall)")
        if hrow["overlap"] is not None and hrow["overlap"] > -8:
            fails.append(f"{where}: the header nav runs into the icon buttons ({hrow['overlap']}px)")

    # ── the menu button under NAV_BREAK px (Ben, 2026-09-10: "NO menu in the mobile version") ─
    pm = r.get("phoneMenu")
    if width < NAV_BREAK:
        if not pm or not pm["buttonShown"]:
            fails.append(f"{where}: no menu button under {NAV_BREAK}px, where the nav would wrap")
        else:
            if not pm["opened"]:
                fails.append(f"{where}: the phone menu button does not open the nav")
            if pm["expanded"] != "true":
                fails.append(f"{where}: the phone menu button's aria-expanded does not follow the menu (read {pm['expanded']!r})")
            if pm["wordsOpen"] != len(NAV_WORDS):
                fails.append(f"{where}: the phone menu shows {pm['wordsOpen']} items, expected {len(NAV_WORDS)}")
            if nav and pm["subsOpen"] != len(nav["menus"]):
                fails.append(f"{where}: the phone menu shows {pm['subsOpen']} of {len(nav['menus'])} menus inline")
            # every line of every menu is drawn, in ONE column: no line hidden, none beside another
            lines = pm.get("lines") or []
            hidden = [x["text"] for x in lines if not x["drawn"]]
            if hidden:
                fails.append(f"{where}: the open phone menu does not draw {len(hidden)} of its {len(lines)} lines: {hidden[:5]}")
            drawn = sorted((x for x in lines if x["drawn"]), key=lambda x: (x["top"], x["left"]))
            # (a menu's lines tuck 4 px under their word — the same -4 px margin main's had — so "beside"
            # is sharing more than half a line's height, not touching)
            beside = [(a_["text"], b_["text"]) for a_, b_ in zip(drawn, drawn[1:])
                      if a_["bottom"] - b_["top"] > 0.5 * min(a_["bottom"] - a_["top"], b_["bottom"] - b_["top"])]
            if beside:
                fails.append(f"{where}: the open phone menu is not one column: {beside[:3]} share a row")
            for label, pat in NAV_REACH:
                if not any(x["drawn"] and re.search(pat, x.get("href") or "") for x in lines):
                    fails.append(f"{where}: the open phone menu shows no line for {label}")
            # in the column a menu's word is a heading over lines that are all drawn: it says expanded
            if any(x != "true" for x in pm.get("headsSay") or []):
                fails.append(f"{where}: in the open column the menus' words say aria-expanded={pm['headsSay']}, but every line is drawn")
            # every line can be scrolled into the window (the header is sticky: the page cannot scroll it)
            if pm.get("unreachable"):
                fails.append(f"{where}: {len(pm['unreachable'])} line(s) of the open menu cannot be brought into the "
                             f"{width} x {pm.get('innerH')} window (the column is {pm.get('menuH')}px, overflow-y {pm.get('navOverflowY')}): "
                             f"{pm['unreachable'][:5]}")
            if pm["scrollW"] and pm["scrollW"] > width:
                fails.append(f"{where}: the open phone menu scrolls horizontally — scrollWidth {pm['scrollW']} > {width}")
            if not pm["closedOnEsc"]:
                fails.append(f"{where}: the phone menu does not close on Escape")
            if not fails or not any(where in f and "phone menu" in f for f in fails):
                notes.append(f"{where}: the phone menu opens with {pm['wordsOpen']} items, {pm['subsOpen']} menus inline and "
                             f"{len(drawn)} lines in one column ({pm.get('menuH')}px tall), no horizontal scroll, closes on Escape")
    elif pm and pm["buttonShown"]:
        fails.append(f"{where}: the menu button is visible at {width}px; it belongs under {NAV_BREAK}px only")

    # ── the tabsets: one selected tab, one drawn panel, and a pill that is the panel's own count ─
    for ts in r.get("tabsets") or []:
        # WS-R3: a tabset with one group/row draws NO .tabrow (D2's own rule — the methods tabset
        # on a single-series page, e.g. ph, and the ways-in tabset would hit this too were it ever
        # down to one code route) — that is not "zero selected", it is "nothing to select"
        if not ts["tabs"]:
            panels = ts.get("panels") or []
            if len(panels) != 1:
                fails.append(f"{where}: {ts['id'] or '(tabset)'} has no tab row but {len(panels)} panel(s), expected exactly one")
            elif panels[0]["hidden"]:
                fails.append(f"{where}: {ts['id'] or '(tabset)'} has no tab row and its one panel is hidden")
            else:
                notes.append(f"{where}: {ts['id'] or '(tabset)'} no tab row, one panel shown")
            continue
        sel = [t for t in ts["tabs"] if t["selected"]]
        drawn = [t for t in ts["tabs"] if not t["hidden"]]
        notes.append(f"{where}: {ts['id']} " + " · ".join(f"{t['title']}" + (f" [{t['cards']} cards]" if t["cards"] else "")
                                                          for t in ts["tabs"]))
        if len(sel) != 1:
            fails.append(f"{where}: {ts['id']} has {len(sel)} selected tabs, expected exactly one")
        if len(drawn) != 1:
            fails.append(f"{where}: {ts['id']} draws {len(drawn)} panels, expected exactly one")
        if sel and drawn and sel[0]["id"] != drawn[0]["id"]:
            fails.append(f"{where}: {ts['id']} selects {sel[0]['id']!r} but draws {drawn[0]['id']!r}")
        if ts["id"] in CARD_TABSETS:
            for t in ts["tabs"]:
                pill = int(str(t["pill"] or "0").replace(",", ""))
                if pill != t["cards"]:
                    fails.append(f"{where}: {ts['id']} tab {t['id']!r} says {pill} but its panel holds {t['cards']} cards")
        # D9: a `?tab=` on the URL lands with THAT tab already selected (tabs.js's data-url-tab
        # restore) — checked wherever a probed path names one
        if ts["id"] == "ts-datasets":
            m = re.search(r"[?&]tab=([^&]+)", path)
            if m and sel and sel[0]["id"] != m.group(1):
                fails.append(f"{where}: ?tab={m.group(1)!r} on the URL but {sel[0]['id']!r} is selected")

    # ── the one search over the three indexes ──────────────────────────────────────────────────
    # "sardine" is a species, "nitrate" a measurement AND a dataset's variables, "CUFES" a dataset;
    # "TEMPPR01" is a NERC id that only the measurements RECORD carries, so it is expected to find
    # nothing until WS-M3 ships and is reported, not failed.
    se = r.get("search")
    if se and "error" not in se:
        for term, res in se.items():
            groups = [g.split(" ")[0] for g in res["groups"]]
            notes.append(f"{where}: search {term!r} → {res['hits']} rows in {', '.join(groups) or 'nothing'}")
        for term, want in (("sardine", "Species"), ("nitrate", "Measurements"), ("CUFES", "Datasets")):
            res = se.get(term)
            if not res:
                continue
            if not res["open"]:
                fails.append(f"{where}: the door search did not open for {term!r}")
            if not any(g.startswith(want) for g in res["groups"]):
                fails.append(f"{where}: the door search found no {want} for {term!r} "
                             f"(groups: {res['groups']})")
        p01 = se.get("TEMPPR01")
        if p01 and not p01["groups"]:
            notes.append(f"{where}: 'TEMPPR01' finds nothing — the measurements RECORD carries the "
                         f"NERC ids and no release has one yet (WS-M2/M3)")
    elif se:
        fails.append(f"{where}: the door search errored: {se['error']}")

    # ── D1–D5 (round 2, WS-R4): the homed row and the one search box ─────────────────────────────
    hr = r.get("homedRows")
    if hr:
        notes.append(f"{where}: {hr['n']} homed row(s), {hr['varsTotal']} with a variables/taxa "
                     f"expander")
        if hr["dsFmt"]:
            fails.append(f"{where}: {hr['dsFmt']} homed row(s) still draw .ds-fmt (D1)")
        if hr["licMissing"]:
            fails.append(f"{where}: {hr['licMissing']} homed row(s) have no .cc-chip-lic as their "
                         f"last column (D2)")
        if hr.get("dlNotLast"):
            fails.append(f"{where}: {hr['dlNotLast']} homed row(s) draw their Download control before the "
                         f"licence (it ends the row, after the licence chip)")
        if hr["licCustomText"]:
            fails.append(f"{where}: {hr['licCustomText']} homed row(s) show the raw 'custom' id — "
                         f"never on a page (D5)")
        if hr["varsEmpty"]:
            fails.append(f"{where}: {hr['varsEmpty']} .ds-vars expander(s) draw no chips (D3)")
        if hr["n"] and not hr["varsTotal"]:
            fails.append(f"{where}: {hr['n']} homed row(s) and none has a variables/taxa expander (D3)")

    ds = r.get("doorSearch")
    if ds:
        notes.append(f"{where}: {ds['n']} input[type=search] in #datasets "
                     f"({ds['boxW']}px of {ds['containerW']}px container)")
        if ds["n"] != 1:
            fails.append(f"{where}: {ds['n']} input[type=search] inside #datasets, expected exactly 1 (D4/D5)")
        if ds["hasDsQ"]:
            fails.append(f"{where}: #ds-q still exists — the catalog's own search box was supposed to go (D4/D5)")

    dp = r.get("doorPanels")
    if dp:
        notes.append(f"{where}: 'sardine'→{dp['sardineSpeciesResults']} .cc-result(s) in the Species "
                     f"panel; 'krill' grid rows shown: {dp['krillRowsShown']}")
        if dp["sardineSpeciesResults"] == 0:    # None: no Species panel here (a catalog page's one_search)
            fails.append(f"{where}: '?q=sardine' on the Species tab rendered no .cc-result (D9)")
        if dp["krillRowsShown"] is not None:
            if not dp["krillRowsShown"]:
                fails.append(f"{where}: 'krill' filtered the grid to zero rows (D4/D5)")
            elif not any("euphausi" in k for k in dp["krillRowsShown"]):
                fails.append(f"{where}: 'krill' did not filter the grid to the euphausiid row(s) "
                             f"(shown: {dp['krillRowsShown']})")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default="http://localhost:4000", help="site root (default localhost:4000)")
    ap.add_argument("--url", action="append", help="a full URL to check (repeatable); replaces the defaults")
    ap.add_argument("--widths", nargs="+", type=int, default=[1470, 375])
    ap.add_argument("--themes", nargs="+", default=["light", "dark"])
    ap.add_argument("--browser", default="chromium")
    ap.add_argument("--wait", type=int, default=2500, help="ms to settle (fonts, masonry) before measuring")
    ap.add_argument("--nav", action="store_true",
                    help="the header's breakpoint only: NAV_PATHS at NAV_WIDTHS (pr.yml runs it after the full check)")
    a = ap.parse_args()

    fails, notes = [], []
    data = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "_data")
    paths = resolve_face_exemplars(DEFAULT_PATHS, _read_json(os.path.join(data, "measurements.json")),
                                   _read_json(os.path.join(data, "measurements_media.json")), notes)
    urls = a.url or [a.base.rstrip("/") + p for p in paths]
    widths = a.widths
    if a.nav:
        # the header alone, at the widths either side of NAV_BREAK: one line from it, the menu below
        urls = a.url or [a.base.rstrip("/") + p for p in NAV_PATHS]
        widths = NAV_WIDTHS
    # the ONE list of words, as built: /brand/v3/nav.json (what every other product's header is drawn
    # from) must carry the same titles, in order, as _data/nav.yml (what this site's header is drawn
    # from and what the bar is held to above). Once per site.
    for origin in sorted({re.match(r"https?://[^/]+", u).group(0) for u in urls if re.match(r"https?://[^/]+", u)}):
        built = fetch_json(origin + "/brand/v3/nav.json")
        got = nav_json_titles(built)
        if built is None:
            fails.append(f"{origin}/brand/v3/nav.json: not served — the other products' headers have no words to draw")
        elif got != NAV_WORDS:
            fails.append(f"{origin}/brand/v3/nav.json: its words are {got}, _data/nav.yml's are {NAV_WORDS}")
        else:
            notes.append(f"{origin}/brand/v3/nav.json: {' · '.join(got)} (as _data/nav.yml)")
        print(f"{'ok  ' if built is not None and got == NAV_WORDS else 'FAIL'} {origin}/brand/v3/nav.json")

    for url in urls:
        # --nav: the open menu on a small phone (PHONE x PHONE_H): every line of the column must be
        # reachable there, which a 900 px window cannot show
        if a.nav:
            for theme in a.themes:
                where = f"{url} @{PHONE[0]}x{PHONE[1]} {theme}"
                r = probe(url, PHONE[0], theme, a.browser, a.wait, height=PHONE[1])
                before = len(fails)
                if "error" in r:
                    fails.append(f"{where}: {r['error']}")
                else:
                    check(url, r, PHONE[0], f"{theme} ({PHONE[0]}x{PHONE[1]})", fails, notes)
                print(f"{'FAIL' if len(fails) > before else 'ok  '} {where}")
        # the front door's first screen in a FOLD_W x FOLD_H window, once per theme (the bare front door
        # only: a URL that names a panel opens it, and the fold is then the panel's business)
        bare = re.sub(r"^https?://[^/]+", "", url)
        if bare in ("/", "") and not a.nav:
            for theme in a.themes:
                where = f"{url} @{FOLD_W}x{FOLD_H} {theme}"
                r = probe(url, FOLD_W, theme, a.browser, a.wait, height=FOLD_H, js=FOLD_PROBE)
                before = len(fails)
                if "error" in r:
                    fails.append(f"{where}: {r['error']}")
                else:
                    check_fold(where, r, fails, notes)
                print(f"{'FAIL' if len(fails) > before else 'ok  '} {where}")
                good = check_heading(url, theme, a.browser, a.wait, fails, notes)
                print(f"{'ok  ' if good else 'FAIL'} {url} start heading, {len(HEADING_WINDOWS)} windows, {theme}")
        for width in widths:
            for theme in a.themes:
                r = probe(url, width, theme, a.browser, a.wait)
                if "error" in r:
                    fails.append(f"{url} @{width}px {theme}: {r['error']}")
                    print(f"ERROR {url} @{width} {theme}: {r['error']}")
                    continue
                before = len(fails)
                check(url, r, width, theme, fails, notes)
                print(f"{'FAIL' if len(fails) > before else 'ok  '} {url} @{width}px {theme}")

    if notes:
        print("\nmeasured:")
        for n in notes:
            print(f"  {n}")
    if fails:
        print(f"\n{len(fails)} FAILURE(S):")
        for f in fails:
            print(f"  {f}")
        sys.exit(1)
    print("\nall layout assertions pass")


if __name__ == "__main__":
    main()
