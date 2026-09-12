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
                         What's observed (2026-09-10, was Life: two counted rows — the species count linking
                         `/species/`, the measurements count linking `/measurements/` — each with its glyphs and its
                         door). No tile ends in a button: the one CTA is the hero's; every tile ends
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

### Six words, tabs, and one search over the three indexes

Since 2026-09-10 (plan `2026-09-10 Measurements catalog …` § D7, Ben's scheme) the navigation is six
words and an outbound link — **DATA · APPS · ACCESS · BUILD · DOCS · NEWS · calcofi.org ↗**, seven
items, all of them generated from the one `sections:` list in `_data/products.yml`. A section is a
`kind: section` (drawn on this page under its own anchor) or a `kind: page` (a header link to its
`url:` and nothing else — that is what DOCS and NEWS are). The section ids `datasets`, `explore`,
`access` and `build` did not change, so every anchor anyone has bookmarked still lands; only their
titles did. `students` is gone as a section: the nine student projects are a tab of APPS. The
`docs` product keeps its key, its uptime and analytics slugs and its `added:` — the ship's log and
the three-slug contract are untouched — but its card left the Build grid for the header's word.

**The submenus.** DATA, APPS and ACCESS each list their tabs on hover or focus, with a count pill. A tab whose full listing lives on its own page carries `url:` (and the `site.data` key it needs, `data:`) in `products.yml`, and the header links that page instead of the homepage tab — Species → `/species/`, Measurements → `/measurements/`; Datasets stays a homepage tab because the whole grid is there.
It is CSS, not a library: the section link is the trigger, `:hover` / `:focus-within` opens it, and
`assets/tabs.js` blurs the focused link on Escape, which is the whole close. The brand hides
`.cc-links` under 760 px, so on a phone a tap on the word goes to the section. The whole behaviour
hangs off **one class** — `cc-submenus` on the `<nav class="cc-links">` in `_layouts/default.html`:
remove it and the header is flat six words again, with no other edit anywhere (the plan's open
question 8).

**The tabs.** Every crowded section is tabbed, each tab with a count pill: DATA is *Datasets ·
Species · Measurements*, APPS is *Explorer · General · Dataset · Student*, ACCESS is *Services ·
Packages*; BUILD keeps three cards. A tab is declared in `sections[].tabs[]` (`id`, `title`,
`blurb`, and an optional `count:` naming a catalog number rather than a card count) and a card joins
one with `tab:` — tab ids are unique across sections, so a panel selects on `tab:` alone.
`assets/tabs.js` (≤ 110 lines, no dependency) sets `aria-selected`, hides the other panels, moves on
the arrow keys, writes the selected tab of the DATA tabset into `?tab=` and restores it on load. It
is loaded **from the head**, deferred: deferred scripts run in document order and `assets/catalog.js`
rewrites the URL from the dataset filters on load, dropping every parameter it does not own, so
`?tab=` has to be read before that happens. (For the same reason, touching a catalog filter drops
`?tab=` from the address bar — the tab itself does not change.) With JS off the first panel is the
one that shows: the panels are rendered with `hidden` already set by Liquid.

**One search, three indexes.** The box above the DATA tabs searches datasets, species and
measurements at once. `assets/door-search.js` fetches `/datasets/search.json`, `/species/search.json`
and `/measurements/search.json` **once, on the first focus** — never at load, so the first paint is
untouched — and a record that 404s simply contributes no group. Results are grouped, four per group,
with an "all *n* in …" row to that group's catalog; Enter opens the first hit, Escape closes, arrow
keys walk the list. `species/search.json` is built by Liquid straight from the release's own
`taxa.json`, so it is the same record `/species/` is drawn from. `measurements/search.json` is a
**bridge stub** built from the release's own `coverage.json` (`variables[realm == "env"]`) until a
release carries `measurements.json`; when `_plugins/measurements.rb` ships it writes that URL and
the stub file must be deleted — a generated page and a source page of one permalink collide.

**The two catalogs' counts, and where each comes from.** Nothing on the door is typed:

```
16 datasets          site.data.catalog.counts.datasets            the release record
1,008 species        numbers.species_fmt                          coverage.json taxa[] at rank Species
79 measurements      numbers.measurements_keys_fmt                coverage.json variables[realm == env],
                                                                  counted as DISTINCT (variable ∥ measurement_type)
84 series            numbers.measurements_series_fmt              the same rows, counted
5 datasets           numbers.measurements_datasets                their distinct dataset_key
25.0 M · 316 M       numbers.measurements_env_m · measurements_m  catalog.json obs_env · + the two full-res tables
1949 → 2026          numbers.measurements_year_{min,max}          the same rows' year_min / year_max
17 · 1 4 3 9 · 3 2   how many products carry that `tab:`          products.yml
```

`variable` is the crosswalk column: where the registry assigns one (the five unified pairs the
Explorer carries — temperature, salinity, oxygen ml/L, oxygen µmol/kg, sigma-theta) its two series
are one measurement, which is why v2026.09.06 reads **79 measurements in 84 series**. A count the
build cannot read collapses its pill, its tile row and its door rather than being invented.

**Where a door leads when the catalog does not exist.** `/species/` exists only where the release
carries `taxa.json`; `/measurements/` only where it carries `measurements.json`. Without the record
the band tile, the Observed row, the realm door and the tab all fall back to the Explorer —
`…/explore/` for organisms, `…/explore/?var=temperature` for measurements — so a door always leads
somewhere true.

**Also checked** by `check_layout.py`, in both themes at 1470 and 375: the header reads exactly those
seven words; each submenu is closed until focused, opens on focus, closes on Escape, and every item
carries a count; the section bar reads DATA · APPS · ACCESS · BUILD, each counted; every tabset has
exactly one selected tab and one drawn panel, and a card tabset's pill equals the cards in its panel;
the band's species and measurements numbers are links; the Observed tile draws both rows and spills
nothing; the search returns a Species group for "sardine", a Measurements group for "nitrate" and a
Datasets group for "CUFES"; and the DATA section is no more than 120 px taller than it was before the
tabs (`DATA_SECTION_BASE`, measured on main, is re-stated in the script whenever the furniture
changes).

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

## The species catalog (`/species/`, `/species/{slug}/`)

The dataset catalog's pattern with the release's `taxon` table in the place of `dataset`: one
record, one generator, one page per key, and **not one taxon fact written in this repo**. The
source is `taxa.json` — the record `calcofi4db::build_taxa_catalog()` writes into each release
beside `datasets.json` (schema 1.0, `calcofi4db/inst/schema/taxa.schema.json`; 2.44 MB on
v2026.09.06).

```
scripts/fetch_release.sh   {record_dir}/taxa.json → _data/taxa.json (git-ignored), and beside it
                           _data/erddap_taxon_key.json — which ERDDAP tables carry a taxon_key column
_plugins/species.rb        the record → /species/, /species/{slug}/, /species/{slug}.json,
                           /species/sitemap.xml — and site.data.species for the index and the
                           dataset pages' taxon links
assets/species.js          the tree + search, the class × dataset matrix, the icicle, the years strip
scripts/check_jsonld.py    one schema.org/Taxon node per page, and the species sitemap
scripts/check_layout.py    /species/ and /species/worms-217452/ at 1470 and 375 px, both themes
```

**The record.** `counts` (taxa observed · species observed · the taxon table's rows · datasets ·
pages · the `obs_bio` rows that carry a taxon key), `datasets[]` (each with its colour, category,
counts and `vocabulary_only[]`), and `taxa[]` — one entry per taxon **with an observation at or
below it**: 2,410 on v2026.09.06, the 1,506 observed plus the 904 ancestors that roll them up. The
204 `taxon` rows nothing observes get no page; the 175 of them a dataset declares are the folded
*In the vocabulary, not yet observed* list on that **dataset**'s page instead (174 for ichthyo, 2
each for Farallon and mesopelagic). Each entry carries its `slug`, `lineage{}`,
`ids{}`, `local{}` (a dataset-local class only), `groups[]`, `direct{}`, `rollup{}` and
`datasets[]` — per dataset the counts, the years, and `sources[]`: **the name that dataset uses**.

**The slug rule.** `slug` is the `taxon_key` with its `:` written `-`, so `worms:217452` is
`/species/worms-217452/`. The reverse is the split on the **last dash before the trailing digits**
(`/^(.*)-(\d+)$/` → `$1:$2`), so a dataset key's own hyphens survive: `cce-lter_zooscan-13` is
`cce-lter_zooscan:13`. `assets/species.js` derives the slug from the key rather than carrying it
2,403 times.

**What a page carries.** The lineage breadcrumb (every ancestor a link, behind its rank's
abbreviation), the accepted name **once** as the title — italic for a genus, species or subspecies;
a dataset-local class is headed by its dataset's own name for it and says so — the common name, a
status eyebrow (`Species · accepted · checked 2026-08-05`) with a quiet pill where the authority
does not say `accepted` (87 of the 2,410 pages), the ids linked out (WoRMS · ITIS · GBIF · NCBI · iNat)
with the key in mono, the stat row, one row per dataset it was observed in, the years strip, the
taxa under it (folded past 30), its `taxon_group`s, and the **ways in**: the Explorer prefilled
`?taxon={key}`, db-query prefilled with `SELECT * FROM __TBL:obs_bio__ WHERE taxon_key = …`, ERDDAP,
and R and Python snippets. Each URL is a full-width single mono line, elided from the **middle** by
`species.js` so the tail — the taxon the tool opens on — survives a phone; one row per endpoint.

**The flags.** Each `sources[]` row is the vocabulary a dataset declares, and carries a quiet pill
where the crosswalk had to move: `synonym` (the name is not the accepted one, 70 rows),
`sp_to_genus` (*"Cyclothone sp."* → the genus, 11), `rekeyed` (the id the dataset supplied was
deprecated by its authority and re-keyed to the successor, 27 Farallon rows), `id_conflict` (a
*secondary* authority's id disagrees with the key authority's cross-reference, 23 ichthyo rows) and
`no_name` (the dataset carries only a code, 120). The labels are a map with a **plain-text
fallback**, so a flag the next release adds still renders as itself.

**The forest, and the display merge.** The `taxon` table is a forest, not a tree: `worms:1` Biota,
`worms:3` Plantae, `worms:6` Bacteria, `worms:7` Chromista, `itis:202423` Animalia — the ITIS bird
lineage, because WoRMS lags on Aves — and the 14 dataset-local classes are all roots. **The pages
follow the record exactly.** Only the index's tree merges: display nodes of the same **rank AND
`scientific_name`** across the two authorities become one node (Animalia, Chordata, Vertebrata,
Gnathostomata), linked to the `worms:` page, showing the summed rollup; a root above kingdom rank
(Biota) is lifted so the tree opens on the kingdoms; a node the merge leaves with neither
observations nor children is not drawn (ITIS's Bilateria and Deuterostomia, whose only chain merges
away — both keep their pages); and the 14 local classes hang under one *Dataset-local classes*
node. 2,403 nodes drawn, and their direct observations still sum to the record's `obs_bio_rows`.

**Two switches on the tree** (Ben, 2026-09-09: a species sat twelve indents deep and could not be
clicked). By default the tree shows the **major ranks** — kingdom → phylum → class → order →
family → genus → species — and any taxon observed at another rank (a suborder or subfamily
identification is a real taxon with data); the unobserved minor ranks of the WoRMS lineage
(subphylum, infraphylum, parvphylum, gigaclass, superclass, subclass, superorder, subfamily …) are
folded out of the display and their shown descendants attach to the nearest shown ancestor.
Counts never change — every rollup is over the full tree. **all ranks** (`?ranks=all`) shows
everything. And either pane — the tree or the matrix — can be **expanded to the full width**
with the ⤢ button in its header (`?panes=tree|matrix` in the URL — not remembered across visits since 2026-09-10, when a remembered matrix followed Ben around with the tree gone). The collapsed pane folds into a 28 px vertical pill beside the expanded one — the Explorer's collapsed-panel idiom — and the pill, like ⤡, shows both again; a search with matches shows the tree again if it was folded. The
⤡ button restores both. With both shown the tree pane is still exactly the matrix pane's height.

**The inline JSON.** `/species/` inlines **one** payload (284 KB, 56 KB gzipped): every node with
its key, name, common name, rank, parent, direct observations and per-dataset observations
(datasets referenced by their index in `ds[]`), plus the class × dataset matrix and the icicle
hierarchy — **both counted in Ruby, once, from the record**, so `species.js` only paints them and no
count can be computed two ways. It doubles as the search index, so the page loads one payload and
not two; per-taxon detail is `/species/{slug}.json`.

**The checks.** `check_jsonld.py`: exactly one `Taxon` node per page with `name`, `identifier` (the
WoRMS LSID `urn:lsid:marinespecies.org:taxname:{id}`, or ITIS's TSN page) and the page's own `url`;
`taxonRank` exactly where the record ranks it and nowhere else (the 14 dataset-local classes have
none, and none is invented); `parentTaxon` exactly where the record has a parent, read back from the
sidecar so a page cannot claim a lineage the record lacks; `/species/` one `CollectionPage`; and the
species sitemap equal to the pages that exist. `check_layout.py`: the index's five counts equal the
inline record's, the matrix has exactly rows × datasets cells, the tree pane is exactly the matrix
pane's height (the tree scrolls **inside** it, so no unbounded text sits beside a fixed-height
figure), every `.sp-url` is one line and actually elided, and on a taxon page the *Observed in* rows
are the record's `datasets[]` with its counts, the lineage is a chain of species links, and the
Explorer link opens prefilled.

**The `TAXA_RELEASE_URL` bridge.** `fetch_release.sh` takes the promoted release's own `taxa.json`
first. Until a promoted release carries one, `TAXA_RELEASE_URL` names a staging record — a full
`http(s)` URL, a `file://` URL **or a plain local path**, so a record on disk renders:

```bash
TAXA_RELEASE_URL=/path/to/taxa.json scripts/fetch_release.sh && bundle exec jekyll build
```

It is set as a repository variable and passed in `pages.yml`, `refresh.yml`, `pr.yml` and
`check-brand.yml`'s layout job, beside `DATASETS_RELEASE_URL`. **With neither, nothing is
generated**: no `_data/taxa.json`, one NOTE, no species pages, and the front door's Life tile links
the Explorer instead — the same D-2 rule the numbers band follows (a fact the build cannot read is
not rendered, never typed). Unset the variable when the promoted release carries the record.

**Faces · the fetcher.** A species page that says nothing about the organism is a page nobody
reads twice, so every taxon gets a picture. The pictures are **not release content** — they come
from eight public services that change on their own cadence, and the release has to stay
reproducible (plan `2026-09-11 Species faces …` § D6) — so they are fetched here, into
`gs://calcofi-files-public/species-media/{release}/`, and read back at build time like any other
sidecar.

```
scripts/fetch_species_media.py   _data/taxa.json → taxa_media.json + 800 px WebP thumbnails
                                 under .cache/species-media/{release}/; --upload rsyncs them to
                                 the public bucket and stamps each asset's `cached` object path
scripts/check_species_media.py   the gate: an allow-listed licence, a credit, a live link and a
                                 named taxon on every asset; silhouettes on >= 95 % of the taxa
scripts/fetch_release.sh         {bucket}/species-media/{release}/taxa_media.json →
                                 _data/taxa_media.json (git-ignored, silently absent)
.github/workflows/species-media.yml   weekly, Sundays 09:00 UTC — DISABLED (`if: false`) until a
                                 GCP_SA_KEY secret exists; run it by hand until then
```

**The sources, in the order they are asked.** **PhyloPic** for the silhouette — by WoRMS id, else
by name at each rank up the lineage until a node has a primary image; it is the one picture every
page can have, it is 2–12 KB of vector, and inked `fill="currentColor"` it is navy on white and
bone on navy without a second file. **Wikidata**, one SPARQL per batch of 100 taxa (never one per
taxon), for the item, its image, its English article and its iNat / eBird / FishBase / GBIF ids.
**Wikipedia**'s REST summary for the lead sentence. **Commons** for the photo and the drawing —
Wikidata's P18 and the files of `Category:{scientific name}`, whose `extmetadata` carries the
licence, the artist and the categories. **iNaturalist**'s curated `taxon_photos`. **GBIF**
occurrence media as the raw fallback. **WoRMS** attributes for the maximum body length. **NOAA
AFSC**'s Ichthyoplankton Information System for the fishes' developmental plate — the picture of
what the ichthyoplankton and CUFES surveys actually collect.

**The policy, in five lines** (plan § D7, Ben 2026-09-11). *Take* CC0, public domain, the Public
Domain Mark, CC BY and CC BY-SA. *Take, rank last, label* CC BY-NC and CC BY-NC-SA. *Leave* every
ND — the crop and the fade are derivatives — and everything with no licence field, `null`, or "all
rights reserved"; a licence is never inferred and a credit is never typed. *Never fetch at all*
Macaulay, FishBase and WoRMS photographs and NOAA's Hornady drawings, until a written yes. *Rank*
the page's own taxon first, then a species under it, then an ancestor within two ranks flagged
"stands in"; curated before raw; then CC0 › PD › CC BY › CC BY-SA › NC; then landscape and ≥ 800 px.
Every asset carries what the source said: `{source, id, url, page, license, license_url, credit,
taxon_shown, steps_up}`. **`taxon_shown` is read, never assumed** — PhyloPic's `specificNode`, the
Commons file's category, the iNaturalist taxon — because the silhouette on the Pacific sardine's
page is drawn from the Japanese sardine and the caption has to say so.

**The cache, and the clock.** Every source's answer for every taxon is one small JSON under
`.cache/species-media/{release}/_cache/{source}/{slug}.json`, and PhyloPic's name lookups are
memoised across taxa, so a run that is killed continues where it stopped and a source that fails
for one taxon leaves that slot `null` and does not stop the run. Each per-taxon record is stamped
with the accepted name and ids it was fetched **under**: a new `taxon_key` in the next release's
`taxa.json` is simply fetched, and a taxon whose name or ids change under the same key is
refetched on the next run without anyone asking (`~ … fetched under …, now … — refetching` in the
log). Every request carries a
User-Agent with a contact and obeys a per-host rate limit — and because those hosts are
independent, a taxon's sources are asked **at once** (`--workers`, default 6, each host still
behind its own lock), which is 1.76 s/taxon instead of 5.61 s cold, with byte-identical output:
about **1.2 h for the record's 2,410 taxa** rather than 3.8. To redo one taxon, or the ten cast
taxa of the plan's probe:

```bash
scripts/fetch_release.sh                                      # _data/taxa.json first
printf 'worms:217452\n' > /tmp/one.txt
scripts/fetch_species_media.py --only /tmp/one.txt --refresh  # --refresh ignores the cache
scripts/check_species_media.py .cache/species-media/v2026.09.10/taxa_media.json
```

### Faces · the page

A taxon page used to say nothing about the organism. It now opens with a **face row**, a **sentence**
and — where the lengths exist — a **How big is it** section (plan 2026-09-11). None of it comes from
the release: the media depend on eight external services and change on their own cadence, so they
live in a second sidecar.

```
_data/taxa_media.json     scripts/fetch_species_media.py → the silhouette, the photo, the plate,
                          the lengths and the Wikipedia lead, per taxon_key (git-ignored, weekly)
_data/size_reference.csv  key,label,m,note,source — the ladder's six reference objects
_plugins/species.rb       composes page.face / page.glance / page.sentence / page.credits /
                          page.size_data, all nil-safe; and the JSON-LD `image`
_includes/species_face.html   the face row, the sentence, the credit line (server-side: content)
_includes/species_size.html   the How big section's hosts and its one inline payload
_includes/species_credit.html the ONE credit format: kind · who · licence · where · what it shows
assets/species.js         the ladder, the beside figure and the plate (figures: drawn in the browser)
```

**The row.** The **silhouette** is the constant: a 2–12 KB PhyloPic vector, inlined and filled with
`currentColor`, so one file is navy on white and bone on navy. When the sidecar's `taxon_shown` is
not the page's taxon the caption says so — *drawn from Ardenna creatopus, 1 rank up*. The **photo**
is the enrichment: a 3 : 2 frame with the stored focal point and a radial mask **on the frame**, so
the picture dissolves into whatever ground the page has; a non-commercial licence is accepted, ranked
last, and labelled `NC`. The **glance** is two bars — the taxon's max length and the nearest familiar
reference, the one whose |log₁₀(taxon ÷ reference)| is smallest among the quarter, the bongo ring, a
person and the ship (the hair and the 505 µm mesh join only for something under 2 mm) — or one line
saying *not on record*. **Every slot is independently absent, and an absent slot leaves no gap**: a
taxon the sidecar has no entry for renders as it did before, bar the sentence and the stat word below.

**The sentence** has three parts, each marked and each underlined in its source's colour with a
legend: `s-wp` Wikipedia's lead under CC BY-SA 4.0 with its revision, `s-rec` this release's own
numbers, `s-au` the naming authority. **`s-au` is not drawn today**: `taxa.json` carries no
`taxonomic_authority`, and a page never fetches one — the clause is simply omitted.

**The word.** A row of `obs_bio` is not an organism: 75.5 % of the CUFES rows and 85.0 % of the
phytoplankton rows are `value = 0`. So the stat and the sentence say **records** until
`build_taxa_catalog()` carries `n_present` (rows with `value > 0`); the moment the record has it,
the stat reads `n_present` *observations* with `n_obs` *records* beside it and the sentence follows.
The word is chosen from the field the record actually has — never typed.

**How big is it** draws the log ladder (10 µm → 100 m, the six references above the axis, the taxon's
egg, hatching, flexion, transformation and adult-max marks below), the silhouette to scale beside the
nearest reference, and the AFSC developmental plate with the early-life lengths and their sources.
The three are figures, so `species.js` draws them from one inline payload; on a phone the ladder's
own container scrolls sideways and the page does not.

**Credits and licences are never written here.** Every one is read from the sidecar, in one format,
with the licence linked to its own deed; the JSON-LD gains an `ImageObject` with `contentUrl`,
`license`, `creditText` and `acquireLicensePage` on exactly the pages that show a photo.

**The checks.** `check_jsonld.py` asserts that `image` block against `_data/taxa_media.json` — present
on every page with a photo, absent everywhere else, and complete when present. `check_layout.py` adds
a `faces` block at 1470 and 375 px in both themes over four pages — the sardine (silhouette, photo,
glance, five ladder marks, a plate), *Chaetoceros* (no length, no plate, no gap), the sooty shearwater
(a stand-in silhouette, flagged) and jack mackerel (no sidecar entry at all): the silhouette is a
labelled `role="img"` with real pixels, the photo has alt text, `loading="lazy"` and the mask, the
glance draws two bars or says *not on record*, the sentence's marked parts and its legend agree, every
asset shown has a credit line, the ladder draws exactly the payload's marks and the csv's references
with **no two labels from different groups overlapping** (bounding boxes read from the DOM), the plate
is drawn exactly where the payload has one, and the stat says *records*.
## The measurements catalog (`/measurements/`, `/measurements/{key}/`)

The species catalog's pattern with `obs_env.measurement_type` in the place of `obs_bio.taxon_key`:
one record, one generator, one page per key, and **not one measurement fact written in this repo**.
The source is `measurements.json` — the record `calcofi4db::build_measurements_catalog()` writes
into each release beside `taxa.json` (schema 1.0,
`calcofi4db/inst/schema/measurements.schema.json`; 167 KB on v2026.09.06).

```
scripts/fetch_release.sh   {record_dir}/measurements.json → _data/measurements.json (git-ignored),
                           and beside it _data/erddap_measurement_type.json — which ERDDAP tables
                           carry a measurement_type column (5 of 5 today)
_plugins/measurements.rb   the record → /measurements/, /measurements/{key}/, /measurements/{key}.json,
                           /measurements/sitemap.xml, /measurements/search.json — and
                           site.data.measurements for the index, the front door and the dataset pages
assets/measurements.js     the URL elision (WS-M3), then the timeline table, the matrix, the years
                           strip, the depth bars and the month strip (WS-M4)
scripts/check_jsonld.py    one schema.org/DefinedTerm node per page, and the measurements sitemap
```

**The key.** A page is one measurement **key** — the registry's `variable` where the crosswalk
unifies two series (bottle `temperature` + CTD `temperature_ave`), else the canonical
`measurement_type` itself: `/measurements/temperature/`, `/measurements/nitrate/`,
`/measurements/btl_temperature/`. **79 keys in 84 series across 5 datasets** on v2026.09.06. A
**series** is one `measurement_type` × dataset under that key, listed with the dataset's own source
column and flag column — *what the source called it*, the `dataset_taxon` of this catalog. The
record decides both; nothing is re-derived here, and the slug is the key.

**What a page carries**, in the mock's order: the crumb (Measurements › category › key), the eyebrow
(`Measurement · category · units`), the label as the title — the record's authored `variable.csv`
label on the five unified keys, else the canonical series' registry description with a line saying
so (74 keys carry the `no_label` flag) — the ids linked out (NERC P01, P06 units) with the key and
the series in mono, the stat row (values · sampling roots · years · datasets · depth · seasons),
**Measured in** (one row per series: the dataset dot with its **name** beside it, its values,
sampling roots, years, depths, grid cells and cruises, then the series, its source column, its flag
column and the record's quiet pills), the three figures, **Range & quality**, **Related
measurements**, the **ways in**, *This page as data* and *Cite*. Each URL is a full-width single
mono line, elided from the **middle** by `measurements.js` so the tail — the measurement the tool
opens on — survives a phone; one row per endpoint.

**Range & quality, and what a bound means** (plan 2026-09-10 § D9, as Ben revised it). The block
states the registry's declared bound, then the observed min · median · max and 5th–95th percentile
**within** it, then — for a series with values outside a declared bound — one line: *n values
outside the declared −2 … 40 degC (56.87 and 99) … are excluded from this range and from the
Explorer, and leave the database at the next release*. A value outside a **declared** bound is a
certain bug being removed at the ingest, never an open question; a series with **no** bound says so
(`no_bound`), and the `sentinel_suspected` heuristic on such a series reads *range suspect · no
bound*. Then the flag counts by code — each dataset's own vocabulary, uninterpreted — with what
`qual_ok` keeps, and whether a `climatology` baseline exists.

**Related measurements** are the record's `related[]`: the same quantity from another platform or
another kind of sample, each its own page, never merged — `same_bottles` (the CTD files' own bottle
samples, which would count the bottle dataset twice), `underway_vs_cast`, `replicate_vs_mean`,
`pre_qc_twin`, `sensor_vs_mean`, `paired_sensors`, `same_casts`. The reason is written as a sentence
from a map with a plain-text fallback, so a reason the next release adds still renders.

**The ways in.** The Explorer prefilled `?var={key}` — **only** where the release's own
`coverage.json` lists the key, otherwise the plain app, saying so — the anomaly section
(`?lens=section&var={key}&anom=1`) where a climatology exists, db-query prefilled with
`SELECT * FROM __TBL:obs_env__ WHERE measurement_type IN (…) LIMIT 100;`, **one ERDDAP row per
series** constrained to `measurement_type` where the probe says the table carries the column
(`_data/erddap_measurement_type.json`, the way `erddap_taxon_key.json` gates the species link), the
Parquet note through the release catalog (`obs_env` is partitioned by `measurement_type`; never a
path built by hand), and R and Python snippets.

**On a dataset page.** Each variable in *Coverage → Variables* links its measurement page where the
record has one (`site.data.measurements.type_slugs`, `measurement_type` → slug) and keeps its
Explorer link where it does not; underneath, a folded **Full resolution only · n** list names the
series that are not canonical for any key and ride the supplemental table instead (21 on the CTD
page, 37 on METS).

The index opens with the overview — the category × dataset matrix and the datasets list — then the search, the category chips and the timeline they summarise (Ben, 2026-09-10). Its head states the count the way it works: a measurement is one quantity under one name, two datasets' series are one measurement only where they share a NERC P01 concept for the same kind of sample (the unified keys are listed and linked), and how many measurements carry a NERC concept at all — every number from the record. The machine-readable sentence on each catalog index (`/datasets/`, `/species/`, `/measurements/`) is a `.cc-aside`: small print in the muted colour behind a hairline.

**The index's figures, and its two switches** (`assets/measurements.js`, no library). The
**timeline** is one row per measurement, grouped under its category, with one bar per series laid on
a 1949 → release-year axis (decade ticks in the header row, two series stacked thin), then units ·
datasets (dot **and name**) · values · depth range; hovering a bar gives the dataset, the series and
its description, years, values, sampling events, samples, depths, source column, flag column and
P01 — the same text is the bar's `title` and `aria-label`, so it is there without a mouse. It is
`role="table"` with `role="row"` wrappers that are `display: contents`, so the CSS grid lays out one
grid while the accessibility tree gets a real table. Being 78 years wide it is **wider than a
phone on purpose**: its own container scrolls sideways and the page never does. Beside it the
**category × dataset matrix** (the cell is how many measurements that dataset carries in that
category, one sequential ramp of `--accent` into `--bg`, capped at 45 % so the count stays in a text
token at ≥ 4.5:1) and **the datasets** list (dot · name · category · realm note · series · years ·
values · how many series are full-resolution only).

Two switches, both written to the URL with `history.replaceState` and read back on load:

| parameter | what it does |
|---|---|
| `?q=` | filters the timeline over the label, the key, the category, the units (either spelling), the P01 id, and every series' `measurement_type`, source column, flag column, description and dataset name. The live count beside the box reads *n of 79*. |
| `?cat=` | the pressed category chip (the exact category name, e.g. `?cat=Nutrients+%26+Chemistry`); the chips are buttons with `aria-pressed`, each carrying its count. A measurement page's crumb links back with it. |

**A measurement page's three figures** read the inline JSON beside them, one row per SERIES: the
**years strip** (`#mm-strip-data` → `#mm-strip`, an `<svg>` on the mock's geometry — a 150 px label
gutter, an 8 px year cell, a 22 px row — that scrolls inside its own box below ~620 px rather than
shrinking its labels away; opacity is √(n / that row's maximum)), the **depth bars**
(`#mm-depth-data` → `#mm-depth`, the record's own bands, one thin bar per series, the end label kept
inside the column) and the **month strip** (`#mm-months-data` → `#mm-months`, twelve cells per
series with the letters below). Each adds `.mm-drawn` when it has drawn — the CSS hides an undrawn
`<svg>`, because an undrawn one is 300 × 150 by the CSS default and `:not([viewBox])` never matches
in an HTML document.

**The inline JSON.** `/measurements/` inlines **one** payload (31 KB): every key with its label,
category, units, P01 and totals, and every series with its dataset index, spans, depths, columns and
flags — the timeline, the matrix, the datasets list and the search all read it, so no count can be
computed two ways. Per-key detail (the per-year, per-month, per-depth and per-flag maps) is on the
page, in `#mm-strip-data`, `#mm-depth-data` and `#mm-months-data`, and in `/measurements/{key}.json`.

### Faces · what it is, how it is taken, why it matters

A measurement page that only counts values says nothing about the thing counted. The **face** (plan
`2026-09-11 Measurement faces …` § D1–D7) answers three questions under the stats band and again at
length below *Measured in*, and **not one of its facts is written in this repo**. Two sources:

| | |
|---|---|
| `_data/measurements.json` **1.1** | the RELEASE's, additive to 1.0: `face` (`kind` ∈ structure · composition · scale · organism · standsin · none, and `face_of`), `chem`, `method`, `scale`, `why` and `anomaly` per key — authored in `metadata/measurement_{chem,method,scale,why,face}.csv` and measured at release |
| `_data/measurements_media.json` | the FETCHER's: the NERC concept and its definition, the structures RDKit draws from ChEBI's molfiles, the Wikipedia leads, the GOOS EOV sheet and NOAA's ONI table. Written by `scripts/fetch_measurement_faces.py` into **one version-free copy** at `gs://calcofi-files-public/measurement-media/` — `measurements_media.json` beside `keys/{key}/structure.svg` — and pulled into `_data/` by `scripts/fetch_release.sh` |

**A key with neither renders exactly as it did before the face existed** — the row is not emitted,
the three headings are not written, and the built page is byte-for-byte what `main` builds.

**What.** The structure is **ours**: NERC's P01 → its S27 → `owl:sameAs` ChEBI → ChEBI's own
molfile → RDKit with `currentColor`, so one file is navy on white and bone on navy and there is no
second asset to fall out of step. ChEBI's *definition* may be quoted (CC BY 4.0); its **roles never
are** — dioxygen's include "anti-inflammatory drug" and the S27 behind DIC is the carbon *atom*,
whose roles include "antidepressant". A **pool** (DIC) or a **mixture** (salinity) therefore takes
composition rows and their mass fractions, never that S27: it draws its components, and its ids row
and its JSON-LD `sameAs` stay empty of ChEBI and CAS, because carbon's entry must never stand for
DIC. A **property** (temperature, pH) has no molecule, so its face is the scale it is read on; an
**organism** count reaches the species face through S25 → WoRMS.

**Stands in.** A key with no P01 borrows the face of the quantity it estimates or repeats, wearing a
chip that says whose face it is (`est_nitrate_sta_corr` → nitrate's, "estimated from the ISUS
sensor") and **none of the borrowed ids**: not in the ids row, not in `sameAs`, and no `image` in
its JSON-LD. A stand-in borrows a picture, not an identity.

**How.** One card per series from the method registry — the platform glyph, the instrument, the
principle, the reaction steps, the wavelength on a spectrum strip, the precision, the series' own
flag column (or *no flag at this grain*), and a pin link to `calcofi.org` styled as the front door
hero's, landing on its section through a text fragment because those pages have no stable anchors.
Beside them, *Where in the water column* from the record's own depth bands.

**Why.** One sentence, three sources, each underlined in its own colour with a legend that names
exactly the parts drawn: NERC's definition · what the record holds and how it has moved · the
authored pick with its citations. The **other readings are one click away** in a
`<details class="ds-details">` — the datasets catalog's *not yet in the database* idiom — **closed
on load**, its summary count the list's own; an authored alternative with no citation says *needs a
citation before it can be the pick* rather than reading as a fact. Then the **familiar scale**
(the record's 5th–95th per series, the declared bounds dashed, the marks sourced below the axis,
and a red flag for a value the scale makes implausible), the **anomaly in every depth band the
record measures in** on one shared scale with the strong El Niño years shaded from NOAA's ONI, and
the **EOV card** — the GOOS question **quoted and linked, never paraphrased**, because
goosocean.org reserves all rights.

**Drawn, not fetched.** The structures are inline SVG, so the picture is on the page with
JavaScript off. Everything else — the spark, the ion bar, the hair, the pH strip, the Beaufort row,
the spectrum, the water column, the familiar scale, the anomaly and the Bjerrum plot — is drawn by
the `// ── faces (WS-MF5)` section of `assets/measurements.js` from **one** inline payload,
`#mm-face`, **at its host's own measured width**, one SVG unit per CSS pixel, so an 11 px label is
11 px in a 560 px column and in an 1,100 px one. Each host adds `.mmf-drawn` when it has drawn.

**`n_flagged`.** Schema 1.1 carries the flagged count per series and per key. The record is the
source and `n_values − qual_ok_n` the fallback; where both exist and disagree the build warns once
and the record wins — the two must never reach a reader as different numbers.

**The checks.** `check_jsonld.py` asserts an `ImageObject` with `contentUrl`, `license`,
`creditText` and `acquireLicensePage` exactly where the record's face is a `structure` **and** the
sidecar drew one, and nowhere else — with no release version in the URL, because keying media by
release blanked every species page on 2026-09-11 — and that no stand-in, pool, mixture, property or
organism claims a chemical id in `sameAs`. `check_layout.py`'s `faces` block, at 1470 and 375 px in
both themes over the seven pages that show all seven states (`nitrate`, `salinity`, `dic`,
`synechococcus`, `wind_speed_ms`, `est_nitrate_sta_corr`, `ammonia`), asserts the row's three
columns and a non-empty *What*, a labelled `role="img"` per structure, the stand-in's chip and
empty ids, the sentence's parts against its legend, the details closed with a matching count, the
familiar scale with **no two mark labels overlapping** (boxes read back from the DOM), the anomaly's
rows against the record's own bands, and that nothing in the face is wider than its column.

**The checks.** `check_jsonld.py`: exactly one `DefinedTerm` node per page with `name`, `identifier`
(the key), the page's own `url` and the NERC P01 collection as its `inDefinedTermSet`; `termCode`
exactly where the record's entry carries a `nerc_p01` and nowhere else (23 series carry none, and an
empty id means *no concept says exactly this*, never *not looked at*); one `PropertyValue` per
series, named by its `measurement_type`; `/measurements/` one `DefinedTermSet` listing every page
that exists; and the measurements sitemap equal to those pages (80 URLs today).

**The `MEASUREMENTS_RELEASE_URL` bridge**, exactly as `TAXA_RELEASE_URL`: the promoted release's own
`measurements.json` first, then the variable (a full `http(s)` URL, a `file://` URL or a plain local
path), and **with neither, nothing is generated** — no `_data/measurements.json`, one NOTE, no
measurement pages, no `/measurements/search.json`, and the front door's measurements tile, Observed
row, realm door and tab fall back to the Explorer on `?var=temperature` with counts read from the
release's own `coverage.json`. It is set as a repository variable and passed in `pages.yml`,
`refresh.yml`, `pr.yml` and `check-brand.yml`. Unset it when the promoted release carries the record.

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
when you change the page's structure — headings, landmarks, labels, a colour — and expect **99**
on a catalog page: the one audit still open is the shared footer's `<h4>` heading order
(`_layouts/default.html`), which follows an `<h2>` on every catalog page and so skips a level.
`/measurements/` scores 99 and `/measurements/temperature/` 98 in both themes (measured
2026-09-10), against `/species/` 99 and `/species/{slug}/` 95 — the measurement page underlines
the links inside its muted notes, which is the difference:

```bash
for u in / /datasets/ /datasets/calcofi_ctd-cast/ /species/ /measurements/ /measurements/temperature/; do
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

**calcofi.io's own pages** are captured too — the front door, the dataset catalog, two dataset
pages, the species catalog and one species page — from the `pages:` section of
[`_data/shots.yml`](_data/shots.yml). They are not products and have no card,
so they are a separate list rather than an invented `products.yml` entry; they land in
`images/<key>_{dark,light}.png` like everything else, so the luminance check covers them.

The script drives your installed Google Chrome (`--browser chrome`) because the
map apps render H3/WebGL hexagon layers that Playwright's bundled Chromium
leaves blank (override with `SHOT_BROWSER=chromium`). After capture it checks
that a `_dark` image is actually dark and a `_light` one light: a failure means
the product ignored `?theme=` — fix the product, do not commit the image.
