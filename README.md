# CalCOFI.github.io

Source for the [calcofi.io](https://calcofi.io) landing page — a Jekyll site
styled as a sibling of [schema](https://github.com/CalCOFI/db-schema),
[query](https://github.com/CalCOFI/db-query) and
[workflows](https://github.com/CalCOFI/workflows).

## Editing products

All cards are driven by [`_data/products.yml`](_data/products.yml) — one entry
per product with `key`, `title`, `section` (`apps` | `services` | `developer` |
`documentation` | `students`), `live_url`, `source_url`, `img`, `description`,
and optionally `status` (`interim` | `superseded` | `archived`),
`superseded_by`, `extra_links` (`[{label, url}]`, extra deep links in the card's
link row), `tech` chips and `credits` (for student contributions).

Cards are named for the thing itself — the repo or app name used everywhere
else (`db-viz-hex`, not "Integrated App") — so a card, its source, its status
page and its usage report are recognizably the same product. Student
contributions keep human-friendly titles.

Edit the YAML, push to main, and GitHub Actions
([`.github/workflows/pages.yml`](.github/workflows/pages.yml)) rebuilds and
deploys the site. The old Google Sheet + `index.Rmd` + `bs4cards` pipeline is
retired.

## Local preview

```bash
bundle install
bundle exec jekyll serve
# open http://localhost:4000
```

## Brand: theme, header, favicon (`brand/v1/`)

[`brand/v1/`](brand/v1/) is the contract every CalCOFI product wears — colour
tokens, the `.cc-header` chrome (logo far-left linking to calcofi.io, 🌓 toggle),
`theme.js` (`?theme=dark|light` → `cc_theme` cookie on `.calcofi.io` →
`localStorage.theme` → dark) and the logo/favicon set — served at
`https://calcofi.io/brand/v1/`. This site is its first consumer. Read
[`brand/v1/README.md`](brand/v1/README.md) before touching a product's chrome;
v1 is frozen once adopted, breaking changes go to `v2/`.

[`brand/v2/`](brand/v2/) is the **proposed** SIO look (2026-08-30; light by default,
Source Sans 3 + Teko, the horizontal lockup, two scales) — previewed at
`calcofi.io/brand/v2/` (the specimen) and `calcofi.io/v2/` (this page on v2:
`_layouts/v2.html`, `v2/index.html`, `style-v2.css`, `_includes/product_card_v2.html`)
until the 9/8 decision; nothing live changes until the flip. See
[`brand/v2/README.md`](brand/v2/README.md).

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
