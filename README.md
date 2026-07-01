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
CSS). To capture or refresh one, use
[shot-scraper](https://shot-scraper.datasette.io) and compress with
[pngquant](https://pngquant.org):

```bash
pipx install shot-scraper && shot-scraper install
shot-scraper https://calcofi.io/db-query/ -o images/db-query.png \
  --width 1200 --height 750 --wait 5000
pngquant --force --ext .png images/db-query.png
```

Shiny apps cold-start in ~10–20 s; bump `--wait 20000` for
`app.calcofi.io/<app>/` URLs.
