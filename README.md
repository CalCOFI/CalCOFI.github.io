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

## The dataset catalog (`/datasets/`, `/data.json`)

calcofi.io opens on the **dataset grid**, and every dataset has a page at
`calcofi.io/datasets/{dataset_key}/`. **Not one dataset fact is written in this repo.** The single
source is `datasets.json` — the record `calcofi4db::build_dataset_catalog()` writes into each release
(schema 1.0; the schema is `calcofi4db/inst/schema/datasets.schema.json`) — fetched at build time and
turned into pages by a Jekyll generator.

```
scripts/fetch_release.sh   latest.txt → _data/{datasets,versions}.json + _data/grid.geojson
                           (all three git-ignored: the site renders the release, never copies it)
_plugins/datasets.rb       the record → /datasets/, /datasets/{key}/, {key}.json, {key}.jsonld,
                           /datasets/release/, /datasets/sitemap.xml, /datasets/search.json,
                           /data.json — and site.data.catalog for index.html
scripts/check_jsonld.py    every page's JSON-LD, the sitemap, and data.json against DCAT-US 1.1
```

**Which release.** `fetch_release.sh` resolves `latest.txt` on the production prefix and uses that
release's `datasets.json`. It never picks an unpromoted release from that prefix. The promoted
release `v2026.09.04` predates the catalog, and Ben chose not to cut a release for the sidecars
alone, so until the next data release the script falls back to the **staging** record and prints a
loud `NOTE: datasets.json from a non-promoted release …`. Override with `DATASETS_RELEASE_URL` (an
env var locally, a repo variable in Actions) — a full URL to a `datasets.json`. When the next release
writes `datasets.json` to the production prefix, the fallback stops firing on its own and the
default can be deleted.

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
3. **Access is full-width rows, not a table.** Each row is two lines: label · chips · meta · copy,
   then the URL on its own line, middle-elided (`Catalog#split_url` — a head that shrinks 999×
   faster than the tail, so the informative end survives to the last pixel). ERDDAP is listed
   **once**, as a matrix of id × (CSV · netCDF · JSON · page · info · graph) with the grain glossary
   under it; *Metadata records* holds the records about the data; *Archives & portals* lists each
   portal's own identifier.
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
one-liner), `stac_collection_url` (the STAC collection), `_plugins/derive_id.rb` (a registration's
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
scripts/check_brand.py --url http://localhost:4000/datasets/
scripts/check_brand.py --url http://localhost:4000/datasets/swfsc_ichthyo/

scripts/check_layout.py                          # the four catalog pages at 1470 and 375 px,
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
| `pages.yml` | push to main | fetch → build → `check_jsonld.py` → deploy |
| `pr.yml` | pull request | `_test/derive_id_test.rb` → fetch → build → `check_jsonld.py` → **`check_layout.py`** → `check_brand.py --url` on two built pages. No deploy. |
| `check-brand.yml` | Mondays 06:17 UTC | `check_brand.py --required-only` against every live product, and a second job that builds the site and runs **`check_layout.py`** against it |
| `refresh.yml` | release dispatch · weekly · by hand | the same three steps as `pages.yml` |

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
scripts/shots.py --pages         # only calcofi.io's own pages
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
