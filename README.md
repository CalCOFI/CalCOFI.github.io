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
scripts/shots.py --all           # plus the single-image cards
scripts/shots.py check           # luminance-check every themed image
```

The script drives your installed Google Chrome (`--browser chrome`) because the
map apps render H3/WebGL hexagon layers that Playwright's bundled Chromium
leaves blank (override with `SHOT_BROWSER=chromium`). After capture it checks
that a `_dark` image is actually dark and a `_light` one light: a failure means
the product ignored `?theme=` — fix the product, do not commit the image.
