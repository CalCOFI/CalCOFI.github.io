# CalCOFI.github.io

Source for the [calcofi.io](https://calcofi.io) landing page — a Jekyll site
styled as a sibling of [schema](https://github.com/CalCOFI/db-schema),
[query](https://github.com/CalCOFI/db-query) and
[workflows](https://github.com/CalCOFI/workflows).

## Editing products

All cards are driven by [`_data/products.yml`](_data/products.yml) — one entry
per product with `key`, `title`, `section` (`featured` | `explore` | `data` |
`build` | `students`), `live_url`, `source_url`, `img`, `description`, and
optionally `status` (`interim` | `superseded` | `archived`), `superseded_by`,
`tech` chips and `credits` (for student contributions).

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

## Screenshots

Card images live in `images/<key>.png` (1200×750, top-cropped to 16:10 by
CSS). Cards whose app shows a welcome modal or guided tour on load — or needs
a long cold-start wait — have a recipe in [`_data/shots.yml`](_data/shots.yml); regenerate
them reproducibly with [`scripts/shots.sh`](scripts/shots.sh):

```bash
# one-time setup
pipx install shot-scraper && shot-scraper install   # Playwright driver
brew install pngquant                                # or apt, etc.

scripts/shots.sh               # (re)capture every card in _data/shots.yml
scripts/shots.sh db-viz-hex    # just one (arg matches the image name)
```

Each recipe captures at 1200×750, dismisses the modal/tour via a `javascript:`
block, then compresses with [pngquant](https://pngquant.org). The script drives
your installed Google Chrome (`-b chrome`) because the map apps render H3/WebGL
hexagon layers that Playwright's bundled Chromium leaves blank (override with
`SHOT_BROWSER=chromium`).

For a simple static page not worth a recipe, the [shot-scraper](https://shot-scraper.datasette.io)
one-liner still works:

```bash
shot-scraper https://calcofi.io/db-query/ -o images/db-query.png \
  --width 1200 --height 750 --wait 5000
pngquant --force --ext .png images/db-query.png
```

Shiny apps cold-start in ~10–20 s; bump the recipe's `wait:` (or `--wait`) for
`app.calcofi.io/<app>/` URLs.
