# CalCOFI.github.io

Source for the [calcofi.io](https://calcofi.io) landing page — a Jekyll site
styled as a sibling of [schema](https://github.com/CalCOFI/db-schema),
[query](https://github.com/CalCOFI/db-query) and
[workflows](https://github.com/CalCOFI/workflows).

## Editing products

All cards are driven by [`_data/products.yml`](_data/products.yml) — one entry
per product with `key`, `title`, `section` (`datasets` | `explore` | `access` |
`build` | `students`), `live_url`, `source_url`, `img`, `description`,
and optionally `group` (an eyebrow group inside a section — Explore's `across` /
`one`), `datasets` (the dataset keys it covers, or `all`; see below),
`status` (`interim` | `superseded` | `archived`),
`superseded_by`, `extra_links` (`[{label, url}]`, extra deep links in the card's
link row), `tech` chips and `credits` (for student contributions).

The `sections:` list drives the section nav, the header links and the counts, so
none of the three can drift from the cards.

Cards are named for the thing itself — the repo or app name used everywhere
else (`db-viz-hex`, not "Integrated App") — so a card, its source, its status
page and its usage report are recognizably the same product. Student
contributions keep human-friendly titles.

Edit the YAML, push to main, and GitHub Actions
([`.github/workflows/pages.yml`](.github/workflows/pages.yml)) rebuilds and
deploys the site. The old Google Sheet + `index.Rmd` + `bs4cards` pipeline is
retired.

## The front door (`/`)

The first screen *shows* what CalCOFI does and how far the data reach (plan
`workflows/.claude/plans/2026-09-07 CalCOFI.io landing re-cut …`), before the catalog, which is
unchanged below it. Its parts, and where every fact on them comes from:

```
assets/section.js        the hero: Line 90 as an oceanographic section, one inline <svg viewBox="0 0 1400 660">
                         built at load — sky, surface, a five-stop water ramp, the sea floor, the ship with its gear
                         drawn to the depth the sampling protocol takes it (each depth a constant with a `source:`
                         comment naming the calcofi.org page), 14 pins for the 13 data categories at the depth that
                         kind of measurement lives, each a link to its method page on calcofi.org. The copy and the
                         one yellow CTA are HTML over the sky (≥ 980 px; stacked above it below that).
_data/line90_floor.json  the sea floor under Line 90 — GEBCO 2025 sampled every 500 m by
                         calcofi4r::cc_transect_bathy() (scripts/build_line90_floor.R; the same call ctd-transects
                         draws with). COMMITTED, like land.geojson: cartography, not a dataset fact. Land is 0 m in
                         the raster, so the headland above the surface is drawn, and the caption says the floor is
                         GEBCO. Without the file the drawing falls back to a drawn profile and says so.
assets/reach.js          the reach: the static grid map (218 cells by pattern, the lines) and the years strip (one row per dataset
                         in the release, one cell per year, opacity by √n_roots; a hatched bar where the record
                         carries only an asserted span — region-pooled phytoplankton, samples-only PIC tows). The
                         rows are grouped Biology then Environment by the dataset's HOME category realm, earliest
                         start year first inside each, and every row carries that category's brand glyph right-
                         aligned against the year field — the same icon its catalog tile wears. The glyph ids,
                         names and realms come from the record through _plugins/datasets.rb (`cat`, `cat_name`,
                         `realm` on each reach dataset); nothing about a category is typed in the script.
#reach                   ONE inline JSON (~60 KB) the three drawings read — the cells, the coastline rings, every
                         dataset's measured years, the categories with the release's counts, the floor and the six
                         numbers — built by _plugins/datasets.rb (`site.data.reach`). No request; grid.geojson never
                         reaches the browser.
the numbers band         77 years · 842 cruises · 218 stations · 1,008 species · 1.3 M organism obs. · 316 M
                         measurements, every one read at build (`site.data.catalog.numbers`; plan 2026-09-09 § D9).
                         Where each comes from: years = the release year minus the earliest measured year_min over
                         datasets[]; cruises and stations = reference[].rows for `cruise` and `grid`; species =
                         the release's own coverage.json (fetched by fetch_release.sh as _data/release_coverage.json,
                         ~660 KB, build-time only) counted as taxa[] at rank Species — 1,008 of the 1,506 taxa
                         OBSERVED, which is not the taxon table's 2,614 rows (1,108 of those are lineage ancestors
                         and vocabulary never observed, so "2,614 taxa" said the wrong thing); organism obs. and
                         measurements = the release's own catalog.json (fetched as _data/release_catalog.json — NOT
                         catalog.json, which Jekyll would load over the generator's site.data.catalog), as
                         tables[obs_bio].rows and tables[obs_env] + [obs_ctd_full] + [obs_mets_full] .rows summed
                         over the tables that release actually carries. `ships` (49) is the hero's eyebrow now, and
                         `rows` (release.total_rows, 349 M) stays where it describes the release OBJECT — the release
                         tile and the release strip, whose cell's title says how much of it is the `obs`
                         compatibility copy counted twice (26 M). Fmt.millions() is the one rule for a count in
                         millions: rounded, one decimal under 10 M, so obs_bio reads 1.3 M and not 1 M. A band dt is
                         one 12 px uppercase line in a 177 px tile, so each new tile's qualifier is its `title`,
                         computed from the same tables. A value the build cannot read is not rendered — the tile
                         collapses; nothing is typed.
the bento                a 6-column grid on 25 px rows: Where (the static map), When (the strip), Latest release, the
                         ship's log, Explore, Get the data (five snippets behind radio-input tabs, no script) and
                         Life (the species count, linking `/species/`). No tile ends in a button: the one CTA is the hero's; every tile ends
                         in an uppercase text link. The Explore cell is not tile markup — it is the SAME
                         _includes/product_card.html the Explore section below renders for the `explore` product, so
                         the tile and the card cannot drift; .t-exp-cell only fits it to the tile. The row unit is
                         25 px because check_layout.py holds every tile to 1.25x its own content's height and a
                         150 px unit could not land inside that for more than two of the seven; a tile of n rows is
                         41n − 16 px and all three columns end on row line 22, so the spans in style.css are a sum —
                         never edit one alone.
brand/v2 --cc-sec-*      the 18 tokens the section is painted with (both themes, additive, in the specimen); the map
                         and strip use --cc-map-*, --cc-stone, --cc-cyan and the record's own dataset colours. The
                         toggle repaints everything; nothing listens for cc:theme.
```

**The ship's log** (`/news/`, the tile, `/feed.xml`) is news that mostly writes itself — where each
kind of entry comes from and when it appears is its own section, [News](#news--where-an-entry-comes-from-and-when-it-appears), below.

**Motion** (Decision 9, narrowed 2026-09-07): the rosette casts down the CTD wire and back on a 26 s
loop and the CUFES dots flow — both off under `prefers-reduced-motion`. The map is static: a cruise
sweep with a year odometer read as one station visited a year, so it went. The site's own `home` capture (`_data/shots.yml pages:`) freezes them so
the card is the same frame every time.

**Checked** by `scripts/check_layout.py` on `/` (plan § D-8): the drawing ≤ 62 vh at 1470 with the
copy clear of the ship's bounding box and above the surface; no tile drawn > 1.25 × its content; the
six numbers on the band equal the inline record's; the strip has one row per dataset and the map one
mark per cell; nothing on the first screen computes to `--warn` but the CTA; every pin's calcofi.org
page answers a ranged GET. Lighthouse accessibility is 100 on `/` and `/news/` in both themes.

## News — where an entry comes from and when it appears

The ship's log (`/news/`, the front door's tile, `/feed.xml`) is news that mostly writes itself:
`_plugins/news.rb` merges four sources into `site.data.log`, newest first. Nobody hand-writes a
release or a dataset entry — the release does.

| type | source | who writes it | when it appears | where it links |
|---|---|---|---|---|
| release | `_data/versions.json` + the first `##` heading of that version's `RELEASE_NOTES.md` (fetched by `fetch_release.sh` into the git-ignored `_data/release_headings.json`) | the release runner, in `RELEASES.md` `# Unreleased` before the cut | minutes after `latest.txt` is promoted (`test_release.qmd` dispatches `refresh.yml`), or by the Monday 09:17 UTC cron | `RELEASES.html#v{version}` — the rendered changelog at that version's own heading, **when the page carries that id**; the page unanchored otherwise |
| dataset | `datasets[].since_version` in the record | nobody — the release that first carries the dataset | with that release | the dataset's page |
| app | `products.yml` `added:` (back-filled from each product's first commit) | whoever adds the card | on push to `main` (`pages.yml`) | the product |
| data · site · paper | [`_data/news.yml`](_data/news.yml) | whoever has the story: a feature, a change to the site, a paper | on push to `main` | the row's `url` |

A `news.yml` row carrying `version:` or `dataset_key:` **replaces** the generated entry of that key —
for a wrong `since_version`, or a notes heading that is not the story. The header's **News** link
wears a dot while an entry is under 30 days old. Type chips are the accent tint — **never `--warn`**:
yellow marks a state that needs attention, not a kind of thing. `feed.xml` is Atom written by the
plugin (the entries are neither posts nor a collection).

**The writing rule that matters most**: the first `##` heading under a version in `RELEASES.md`
*is* the entry calcofi.io and the feed show. Write it as the story of the release, not as a label.

**The anchor is read, never assumed.** `scripts/render_md_on_storage.R` (in `workflows`) stamps
`id="v2026.09.06"` — the version string itself — on each version heading of the rendered
`RELEASES.html`, keeping the old slug id beside it; a release the changelog collapsed into a range
section (`# v2026.08.04 – v2026.08.06`) has an id only for the versions the heading names. So
`fetch_release.sh` GETs that page once and writes the ids it finds to the git-ignored
`_data/release_anchors.json`, and `news.rb` anchors an entry only when the id is in that set.

**Checked** by `scripts/check_news.py` after every build (wired into `pr.yml`, `pages.yml` and
`refresh.yml`): one GET of `RELEASES.html`, and every `RELEASES.html#fragment` in
`_site/news/index.html` and `_site/index.html` must be an `id=` on that page — so a renamed section
or a version whose notes were never re-rendered turns the build red instead of quietly landing a
reader at the top of a 150 KB changelog.

## Feedback (the Explorer's dialog, on every page)

The speech-bubble button beside the theme toggle and the footer's **Send feedback** open the Explorer's
feedback dialog, ported to plain JS (`assets/feedback.js` + `assets/feedback.css`, 2026-09-08 — **fleet
assets**: the docs book loads both from calcofi.io and mounts its own button beside Quarto's toggle, with
`app: docs`; any product on brand v2 can do the same): the current view is captured,
shown as a thumbnail with **edit** (the annotator — arrow · circle · rectangle · pen · text, three
colours, undo, clear) and **retake**, and sent with the note, the page's URL, the release, the viewport
and the theme. It posts to the same Apps Script endpoint the Explorer uses (`_config.yml
feedback_url`; `calcofi4r::cc_feedback_script()` — the "CalCOFI app feedback" Sheet, its `recipients`
tab, the Drive folder), with `app: calcofi-io`; **Open as GitHub issue myself** is the zero-backend
path (a prefilled issue in this repo, the screenshot copied to the clipboard). What is sent is spelled
out in the dialog; an email is optional and never public.

- **The capture** is the viewport slice of the page, by [html-to-image](https://github.com/bubkoo/html-to-image)
  (MIT; vendored in `assets/lib/`, loaded on first use — no CDN), set in the page's own fonts
  (`brand/v2/fonts.css` is fetched and its woff2 inlined). Two things a serialized SVG cannot do are
  done first: the brand sprite is inlined so the drawing's `<use>` glyphs resolve locally, and every
  SVG element's computed paint is stamped as inline style for the instant of the capture (the library
  copies computed styles, but the section's class-driven token fills came through black without it).
- **The public issue** is filed by the Apps Script in the repo it maps the payload's `app` to. The
  script deployed for the Explorer maps only `explore`; regenerate it with
  `cc_feedback_script(repos = c(explore = "CalCOFI/explore", "calcofi-io" = "CalCOFI/CalCOFI.github.io"))`
  and re-paste it (its `GITHUB_TOKEN` needs issues on this repo too) — until then a report from this
  site still reaches the Sheet and the mail, and the issue step is skipped with a note in the row.

## The dataset catalog (`/datasets/`, `/data.json`)

calcofi.io opens on the **dataset grid**, and every dataset has a page at
`calcofi.io/datasets/{dataset_key}/`. **Not one dataset fact is written in this repo.** The single
source is `datasets.json` — the record `calcofi4db::build_dataset_catalog()` writes into each release
(schema 1.0; the schema is `calcofi4db/inst/schema/datasets.schema.json`) — fetched at build time and
turned into pages by a Jekyll generator.

```
scripts/fetch_release.sh   latest.txt → _data/{datasets,versions}.json + _data/grid.geojson, and beside
                           the record _data/{coverage_stations,release_catalog,release_coverage}.json
                           + _data/{release_headings,release_anchors}.json (ALL git-ignored: the site
                           renders the release, never copies it; an optional one that is missing
                           collapses the thing it feeds rather than being typed)
_plugins/datasets.rb       the record → /datasets/, /datasets/{key}/, {key}.json, {key}.jsonld,
                           /datasets/release/, /datasets/sitemap.xml, /datasets/search.json,
                           /data.json — and site.data.catalog for index.html
scripts/check_jsonld.py    every page's JSON-LD, the sitemap, and data.json against DCAT-US 1.1
scripts/check_news.py      every RELEASES.html#fragment the ship's log links is an id on that page
```

**Which release.** `fetch_release.sh` resolves `latest.txt` on the production prefix and uses that
release's `datasets.json` (every promoted release from v2026.09.06 writes one). It never picks an
unpromoted release; `DATASETS_RELEASE_URL` (a full URL to a `datasets.json`) is the one override,
for a rehearsal against a staging record.

**Products carry dataset keys, nothing else.** Each card in `_data/products.yml` may declare
`datasets: [key, …]` or `datasets: all`. The build **fails** on a key that is in neither
`datasets[]` nor `holdings[]` of the record — that is what keeps the product list and the dataset
list one list. It is also the reverse index behind each dataset page's *Access → Explore* rows.

**Visibility.** A record marked `visibility: internal` gets no page, no sitemap entry, no `data.json`
row and no search row.

**Refresh.** `.github/workflows/refresh.yml` rebuilds and deploys on `repository_dispatch`
(`test_release.qmd` fires it the moment a release is promoted), on a weekly cron and by hand.
`pages.yml` does the same three steps on a push to main.

### The grid: an emphasis ladder, packed, with the reference frame in its own band

The catalog's layout follows four rules, and `scripts/check_layout.py` is what keeps them true
(plan `2026-09-05 CalCOFI.io UI refresh …` § D-1 to D-3, D-10):

1. **Emphasis is a ladder.** A dataset in the release is `--accent` at 700 with its own colour as a
   9 px dot and one line of meta (provider · years · sparkline · n obs · the formats as ONE mono
   phrase). A dataset homed elsewhere that *contributes* variables here is `--fg` at 400 with a
   hollow dot and its variables collapsed behind "n variables ▸". A **holding** — something CalCOFI
   has that is not in the database — is `--muted` at 400 on one line with quiet chips. A reference
   row is `--fg` at 400 with its count in mono.
2. **Yellow is reserved.** `--warn` marks a state that needs attention, never a kind of thing. A
   pipeline stage (`ingested`, `validated`, `metadata`, `published`; `external`, `archived`) is
   information: a neutral or quiet chip. Before this, the 17 holdings each wore the page's only
   yellow chip and read louder than the 16 datasets above them.
3. **The grid packs.** `align-items: start` is the no-JS state; `assets/masonry.js` (40 lines, no
   dependency) then gives each tile a `grid-row-end: span n` from its measured height, on load,
   after `document.fonts.ready`, on resize and on the `ds:filtered` event `assets/catalog.js`
   dispatches. Where CSS masonry is supported the script sets `grid-template-rows: masonry` and
   stops. Reading order is always the DOM's. The grid went from **4,910 px to 2,096 px**.
4. **The reference frame is a band, not a tile** (`_includes/reference_band.html`): 25 rows of
   cruise/ship/grid tables, 19 spatial layers grouped as the record groups them, and the
   bathymetry — the one tile whose rows are not datasets, and the one that forced its neighbour to
   nine times its natural height. The filter row ignores it, as it always did.

`coverage.variables[]` are bare strings in schema 1.0 and `{name, units, uri, category}` objects
from the next release. `Catalog#normalize_variables` is the one place that knows, so the tiles, the
search index and `page.variables` all read one shape; a build against either renders.

### A dataset page: the map is the hero, and nothing below the head is two columns

`/datasets/{key}/` follows D-4 to D-7 of the same plan:

1. **The head band is the only two-column region**, and its second column is a map of where the
   dataset was actually sampled. It is bounded to the title block's height *by construction* — the
   cell stretches to the grid row and the SVG fits inside it (`preserveAspectRatio="xMaxYMin meet"`,
   `position: absolute; inset: 0`) — so the two columns end together whatever the abstract's
   length. The first cut put a 418 px column beside a 1,346 px one and left **928 px of blank page**
   under the abstract; two columns whose contents differ that much cannot be made to end together,
   so everything below the head is one column.
2. **The map** (`Catalog#map_svg`) is a static inline SVG drawn at build time — no library, no tile
   server, no external asset, every colour a `--cc-map-*` token so the theme toggle repaints it.
   The frame is **the standard + extended grid ∪ the cells this dataset sampled**, padded 6 % —
   never the record's bbox, which for the ichthyoplankton reads 0–54° N × 180–77° W from bad
   upstream coordinates. The bbox is still drawn, clipped to the frame, dashed, with *extent
   continues beyond the frame* in the corner when it is clipped. Sampled cells are filled with a
   radius ∝ √n_obs and carry a `<title>`; unsampled cells are hollow and carry none (the hovers on
   218 unsampled cells were two thirds of the file).
   - `_data/land.geojson` is the coastline and is **committed**, unlike everything else in `_data/`:
     it is cartography, not a dataset fact. `scripts/build_land.py` builds it once from Natural
     Earth 1:50 m (public domain), clipped to 135–105° W × 19–49° N and simplified at 0.012°
     (28 rings, 791 points, 18 KB). Run it only to change the clip or the tolerance.
   - `_data/coverage_stations.json` (~470 KB, from `fetch_release.sh`, git-ignored) says which
     cells each dataset sampled. It is read at build time and **never shipped to the browser**.
   - `_data/release_coverage.json` (the release's own `coverage.json`, ~660 KB, git-ignored) is read
     the same way: its `taxa[]` gives the front door its species count and each dataset page its
     own — the taxa it observed at rank Species, with every taxon it observed in the tooltip
     (plan 2026-09-09 § D3/D4). Without it a page says "taxa" from the record, as it did before.
3. **Access is full-width rows, not a table.** Each row is two lines: label · chips · meta · copy,
   and no URL line (2026-09-06): the label is the link, the chips and identifier say which endpoint
   it is, and the copy button beside every row copies the address. *Tables from the release* is a
   table (table · holds · rows · size · since · sha256); *Code* follows it, so "DuckDB, anywhere"
   reads one of the objects just listed and explains the content-hashed path; ERDDAP is listed
   **once**, as a matrix of id × (CSV · JSON · page · info · graph — no netCDF, the CF file is the
   netCDF) with the grain glossary under it; *Metadata records* and *Archives & portals* sit side
   by side. Explore rows and product cards carry each app's **lenses** (products.yml `lenses:`) as
   suffix icons, with a key under the landing page's Explore heading.
4. **The generator checks its own output.** `Catalog#unlisted_endpoints` compares every URL in the
   record's `distributions[]` and `registrations[]` against the rows actually rendered and warns at
   build on any that reach no Access row. It caught two legacy ERDDAP ids that carry no `format`
   key and had silently vanished from the CTD casts' page.
5. **`_test/derive_id_test.rb`** (`ruby _test/derive_id_test.rb`, also run by `scripts/build.sh`)
   pins `_plugins/derive_id.rb` — the rule that reads a portal's own identifier off its URL — to
   every URL shape in the record. calcofi4db 4.5.0 derives the same ids, so the two have one list
   to agree on.

**Fallbacks awaiting the record.** Each is marked `# until the record carries …` in
`_plugins/datasets.rb` and is deleted when the release that carries the field renders (plan D-9):
`GRAIN_FALLBACK` (an ERDDAP grain's meaning), `PORTAL_NAMES` + `PORTAL_ABOUT` (a portal's name and
one-liner), the EML probe (`url_ok?` on the release's `eml/{key}.xml` — until the record carries a
`format: eml` distribution), `_plugins/derive_id.rb` (a registration's
identifier), and `STAGE_MEANING`, which is site-side text by nature — the stage vocabulary is
`dataset_status.csv`'s, not any one dataset's.

## Local preview

```bash
scripts/build.sh          # bundle install + fetch the release record + jekyll build
scripts/build.sh serve    # …and serve on http://localhost:4000

# or step by step
bundle install
scripts/fetch_release.sh
bundle exec jekyll serve
```

Checks:

```bash
scripts/check_jsonld.py _site                    # JSON-LD + sitemap + data.json (pip install jsonschema
                                                 # for full DCAT-US schema validation)
scripts/check_news.py _site                      # every RELEASES.html#fragment the log links is an id
                                                 # on that page (one GET; stdlib only)
scripts/check_brand.py --url http://localhost:4000/datasets/
scripts/check_brand.py --url http://localhost:4000/datasets/swfsc_ichthyo/

scripts/check_layout.py                          # the front door + four catalog pages at 1470 and 375 px,
                                                 # both themes: tile stretch, the ladder's colours,
                                                 # no horizontal scroll, the dataset page's columns
scripts/check_layout.py --url http://localhost:4000/datasets/ --widths 1470 --themes light
scripts/check_layout.py --base https://calcofi.io          # against the deployed site

ruby _test/derive_id_test.rb                     # the portal-identifier parser
```

`check_layout.py` needs `shot-scraper` (`pipx install shot-scraper && shot-scraper install`), like
`check_brand.py`. `shot-scraper javascript` has no `--width`, so the script loads each page in a
same-origin iframe of exactly the width under test and measures inside it. **To add an assertion**,
return the measurement from `PROBE` (plain data — no judgement in the page) and judge it in
`check()`, so a failure prints what it measured; then prove it bites by reintroducing the problem
before you commit.

### In CI

| workflow | when | what it runs |
|---|---|---|
| `pages.yml` | push to main | fetch → build → `check_jsonld.py` → **`check_news.py`** → deploy |
| `pr.yml` | pull request | `_test/derive_id_test.rb` → fetch → build → `check_jsonld.py` → **`check_news.py`** → **`check_layout.py`** (the front door and the four catalog pages) → `check_brand.py --url` on three built pages. No deploy. |
| `check-brand.yml` | Mondays 06:17 UTC | `check_brand.py --required-only` against every live product, and a second job that builds the site and runs **`check_layout.py`** against it |
| `refresh.yml` | release dispatch · weekly · by hand | the same four steps as `pages.yml` |

Both layout jobs serve `_site` with `python3 -m http.server` and point `check_layout.py` at
`--base http://localhost:4000`, so the checks run against the build in hand rather than against
whatever is deployed.

Accessibility is Lighthouse, not this script, and it is **not in CI**: the five catalog pages in
both themes measured **106 s** locally (10 s a run, its own Chrome), which is longer than the whole
PR job and would double it for a number that has not moved since the refresh landed. Run it by hand
when you change the page's structure — headings, landmarks, labels, a colour — and expect **100**:

```bash
for u in / /datasets/ /datasets/calcofi_ctd-cast/ /datasets/swfsc_ichthyo/ /datasets/calcofi_prodo/; do
  for t in light dark; do
    npx lighthouse "http://localhost:4000$u?theme=$t" --only-categories=accessibility \
      --quiet --output=json --chrome-flags="--headless=new" \
      | python3 -c 'import json,sys; d=json.load(sys.stdin); print(f"{d[\"finalDisplayedUrl\"]}: {d[\"categories\"][\"accessibility\"][\"score\"]*100:.0f}")'
  done
done
```

## Brand: theme, header, favicon (`brand/v2/`)

[`brand/v2/`](brand/v2/) is the contract every CalCOFI product wears — the SIO look (UCSD palette,
**light by default**, Source Sans 3 + Teko, the horizontal lockup, two scales via `data-cc-scale`),
the `.cc-header` chrome (lockup far-left linking to calcofi.io, sun/moon toggle), `theme.js`
(`?theme=dark|light` → `cc_theme` cookie on `.calcofi.io`, persisted only on an explicit choice →
light) and the favicon set — served at `https://calcofi.io/brand/v2/`. In force since the flip on
2026-09-04 (`_layouts/default.html`, `index.html`, `style.css`, `_includes/product_card.html`). Read
[`brand/v2/README.md`](brand/v2/README.md) before touching a product's chrome.

[`brand/v1/`](brand/v1/) (dark default, system font) is superseded but stays served and frozen for
any product that has not migrated.

## Screenshots

Every card that honours `?theme=` is captured **twice** — `images/<key>_dark.png`
and `images/<key>_light.png` (1200×750, top-cropped to 16:10 by CSS) — and the
card swaps between them with the site's theme toggle. Flip a product to
`shots: themed` in `_data/products.yml` once it passes the theme check; until
then it keeps its single `img:`. Overrides (a bookmark URL to open a view, a
longer `wait:`, JS to dismiss a modal that ignores `?tour=off`) live in
[`_data/shots.yml`](_data/shots.yml).

```bash
# one-time setup
pipx install shot-scraper && shot-scraper install   # Playwright driver
brew install pngquant                                # or apt, etc.

scripts/shots.py                 # (re)capture every `shots: themed` card, both themes
scripts/shots.py db-viz-hex      # just one
scripts/shots.py --all           # plus the single-image cards, plus calcofi.io's own pages
scripts/shots.py --pages         # ONLY calcofi.io's own pages
scripts/shots.py datasets        # just one of them
scripts/shots.py check           # luminance-check every themed image
```

**calcofi.io's own pages** are captured too — the dataset catalog and two dataset pages — from the
`pages:` section of [`_data/shots.yml`](_data/shots.yml). They are not products and have no card,
so they are a separate list rather than an invented `products.yml` entry; they land in
`images/<key>_{dark,light}.png` like everything else, so the luminance check covers them.

The script drives your installed Google Chrome (`--browser chrome`) because the
map apps render H3/WebGL hexagon layers that Playwright's bundled Chromium
leaves blank (override with `SHOT_BROWSER=chromium`). After capture it checks
that a `_dark` image is actually dark and a `_light` one light: a failure means
the product ignored `?theme=` — fix the product, do not commit the image.
