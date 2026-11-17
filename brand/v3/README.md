# calcofi.io brand — v3 (v2 with one header for every product)

Served from `https://calcofi.io/brand/v3/` (this directory in `CalCOFI/CalCOFI.github.io`). **Proposed
2026-11-17**, after the review of front door v2: the site's new header (sentence case, menus under its words, a navy band
ending in a wave on the catalog pages) looked unlike the header the Explorer, the Query Builder and the other
products wear, and the owner asked for one look, with leave to revise the brand to get it.

v3 changes **one thing: the header**. Everything else is v2, unchanged, and still loaded from `/brand/v2/`:
the tokens, the type, the buttons, cards, chips and bands, the icons, the lockup and the favicons. v2's own
README says "v2 is frozen once adopted … anything that changes how an existing page looks or behaves is `v3/`",
and a sentence-case header with shared words is such a change. So v2 stays frozen and served, as v1 did, and
**a product moves to v3 by changing its head block**. A product that does nothing keeps the v2 header it has.

| file | what |
|---|---|
| `head.html` | the `<head>` block to paste: v2's block (favicons, fonts, the pre-paint snippet, `v2/theme.css`) plus `v3/header.css`, `v3/theme.js` and `v3/header.js` |
| `header.css` | the header: the words in sentence case, a word that opens a menu, the menu button and its column, the bar's edge, and **the wave** |
| `header.js` | draws the brand's words into `<nav data-cc-nav>` from `nav.json`, and runs the menus and the menu button for any v3 header |
| `nav.json` | **the words**, generated at build from `_data/nav.yml` by `_plugins/nav.rb`; never edited by hand |
| `theme.js` | v2's script, reporting `ccTheme.version === "3"` and `brand === "v3"`; a v2 page and a v3 page share one stored theme |
| `index.html` | the specimen: the header at the page scale and the app scale, the wave with a head and slim, in both themes |

Not here on purpose: `theme.css`, `fonts.css`, `fonts/`, `icons.css`, `icons/`, the logos and the favicons. They
are v2's, and v3's head block loads them from `/brand/v2/`. Nothing in `/brand/v2/` was edited for v3.

## The contract, where it differs from v2

v2's contract (`../v2/README.md` § The contract) stands, point for point, except **4 (Header)**, which becomes:

**4. Header.** One bar, then the wave.

1. **The bar.** The lockup far left → `https://calcofi.io` (36 px on pages, 28 px in apps). A product other than
   calcofi.io puts its own title beside it → its own root, **in sentence case** ("Explorer", "Query Builder"),
   with an optional `<small>` subtitle; calcofi.io has the tagline there instead. The release chip, where a
   product has one. Then the words, the product's own icon buttons, and the toggle at the right.
2. **The words are the brand's, the same on every product, in sentence case:**

   **Data ▾ · Map ▾ · Query · Learn ▾ · calcofi.org ↗**

   A product does not type them. It writes an empty
   `<nav class="cc-links cc-nav" id="cc-nav" data-cc-nav aria-label="Sections"></nav>` and `header.js` draws them
   from `nav.json`. calcofi.io draws the same markup at build time from the same list, so its nav is in the page
   with JavaScript off. The list is `_data/nav.yml` in this repo: a word, a menu line or a link changes there,
   once, for everyone. A product's own links (the Explorer's lens picker, a Help menu) are controls of its bar,
   not words of the nav.
3. **A word may open a menu.** It is then a `<button aria-expanded aria-controls>` and a panel. The menu opens on
   hover and stays a moment after the pointer leaves; it also opens on a press (click, tap, Enter, Space), which
   is what a touch screen and a keyboard have. Escape closes it, even under the pointer, and returns focus to its
   button; so do a press outside and focus leaving. Focus alone does not open a menu, so tabbing through the bar
   is five stops, not every line of every menu. The first line of a menu is the page the word would otherwise
   have linked (Data → Datasets, Map → the Explorer, Learn → How CalCOFI samples). A destination is said once:
   Learn holds the guides (How CalCOFI samples, Frequently asked questions, Cite the data, Documentation) and the
   news (Tutorials, Stories, All news), and none of them is also a word of the bar.
4. **The bar never wraps.** From 1100 px the words are inline. Below that the menu button
   (`<button class="cc-icon-button cc-menu-button" aria-controls="cc-nav" aria-expanded="false">`) carries them
   in one column, every line of every menu shown, scrolling inside itself. The number 1100 is `NAV_BREAK` in
   `header.css` and `header.js` (and in this site's `scripts/check_layout.py`); change them together. An app whose
   bar is full of its own controls puts `class="cc-header cc-nav-menu"` and gets the menu button at every width.
5. **The wave.** Directly under the bar, on every page, a navy band that ends in a wave: `.cc-wave`. It is navy
   in both themes. A page puts its own head in it (a search and filters, a title and its numbers), or nothing:

   ```html
   <div class="cc-wave"><div class="cc-wave-in"> … the page's head, white on navy … </div></div>
   <div class="cc-wave cc-wave-slim"></div>      <!-- 34 px on a page, 15 px in an app -->
   ```

   The edge is drawn by `header.css` (a mask on `::after`), so the markup is one element. `--cc-wave-below` is
   the colour the wave cuts into: the page ground by default; a page whose first band is another colour sets it.
   A band that draws its own edge with an inline `<svg>` adds `.cc-wave-own`.
6. Where a framework owns the bar (Quarto, pkgdown, mkdocs, bslib `page_navbar`), v2's rule stands: the lockup
   goes in its brand slot and its native toggle is bridged. Such a product adopts v3's words by linking the
   same destinations in its own navbar config, in sentence case, and puts a `.cc-wave.cc-wave-slim` under its
   navbar. `scripts/check_brand.py` holds a framework-owned bar to the wave and the case, not to the markup.

And **10 (Version)** becomes: `window.ccTheme.version === "3"`, `window.ccHeader.version === "3"`.

## Using it

A page (plain HTML, Jekyll, Hugo):

```html
<head>
  …
  {{ contents of head.html }}
  <link rel="stylesheet" href="style.css">   <!-- your own, after the brand -->
</head>
<body>
<header class="cc-header">
  <a class="cc-home" href="https://calcofi.io" aria-label="CalCOFI.io home">
    <img class="cc-logo-dark"  src="https://calcofi.io/brand/v2/logo_calcofi_h.svg"       alt="CalCOFI.io">
    <img class="cc-logo-light" src="https://calcofi.io/brand/v2/logo_calcofi_h_light.svg" alt="CalCOFI.io">
  </a>
  <a class="cc-title" href="/db-schema/">Schema</a>
  <a class="cc-release" href="https://calcofi.io/db-schema/#erd?v=v2026.11.14">release <b>v2026.11.14</b></a>
  <span class="cc-spacer"></span>
  <nav class="cc-links cc-nav" id="cc-nav" data-cc-nav aria-label="Sections"></nav>
  <button class="cc-icon-button cc-menu-button" type="button" aria-label="Open the menu" aria-controls="cc-nav" aria-expanded="false">
    <svg class="cc-menu-icon-open" viewBox="0 0 24 24" aria-hidden="true"><path d="M3 6h18v2H3zm0 5h18v2H3zm0 5h18v2H3z"/></svg>
    <svg class="cc-menu-icon-close" viewBox="0 0 24 24" aria-hidden="true"><path d="M19 6.41 17.59 5 12 10.59 6.41 5 5 6.41 10.59 12 5 17.59 6.41 19 12 13.41 17.59 19 19 17.59 13.41 12z"/></svg>
  </button>
  <button class="cc-theme-toggle" type="button" aria-label="Toggle dark / light theme">🌓</button>
</header>
<div class="cc-wave"><div class="cc-wave-in"><h1>Schema</h1></div></div>
```

An app adds `<meta name="cc-scale" content="app">` above the head block, as in v2, and, if its bar is full,
`class="cc-header cc-nav-menu"` and `<div class="cc-wave cc-wave-slim"></div>` under it.

A preview that is not on calcofi.io (a Netlify build, a local folder) serves its own copy of `/brand/` and points
its head block there; `header.js` reads `nav.json` from beside itself, and `nav.json`'s links follow the build's
own `url` (a build with `url: ""` keeps every link inside the preview). A product may also name another list:
`data-cc-nav="https://…/nav.json"`.

The menu lines show a glyph where the page also loads `/brand/v2/icons.css`; without it they are text.

## Who wears what

Nothing changes for a product until it changes its head block. As of 2026-11-17 (nothing below is deployed; the
three v3 rows are local branches under review; how each v2 product loads the brand is v2's README's account,
not re-checked on the live products for this change):

| product | brand today | after the branches merge | to move to v3 later |
|---|---|---|---|
| calcofi.io (this site: front door, catalogs, dataset, species and measurement pages, news, stories, tutorials) | v2, uppercase words typed in the layout | **v3** | — |
| Explorer (`/explore/`) | v2, its own bar, no site words | **v3**: the words behind the menu button, a slim wave | — |
| Query Builder (`/explore/builder.html`) | new | **v3**: the words inline, its title in the wave | — |
| docs, workflows (Quarto) | v2 through `libs/brand/quarto_head.html` | v2, unchanged | the head include and the navbar's words; § 4.6 |
| db-schema, db-query, ctd-transects (plain pages) | v2 | v2, unchanged | the head block and the empty nav, as above |
| calcofi4r, calcofi4db (pkgdown), calcofi4py (mkdocs) | v2 | v2, unchanged | `_pkgdown.yml` / `mkdocs.yml` includes; § 4.6 |
| Shiny apps on app.calcofi.io (station, ctd, pollutants, and the archived ones) | v2 through `calcofi4r::cc_brand_head()` | v2, unchanged | a `brand = "v3"` in calcofi4r, then each app's next deploy |
| ERDDAP, storage | not looked at for this change | unchanged | not planned |
| student and partner projects (UCLA map, UCSB portals, the timeline, the archived apps) | not looked at for this change | unchanged | not planned |

So after the merge two header looks exist across calcofi.io's products, not three: v3 (the site, the Explorer,
the Query Builder) and v2 (everything not yet moved). The weekly `check-brand.yml` run reports each product's
version; a required product still on v2 is listed, not failed.

## Order of deployment

`/brand/v3/` has to be live before a product that loads it is. The files here and `_data/nav.yml` +
`_plugins/nav.rb` (which writes `nav.json`) are one commit that no page uses, so it can go to `main` on its own
first, with no visible change anywhere; then the Explorer and the Query Builder; then the site.

## Checked, not assumed

`scripts/check_brand.py`, for a product reporting version 3: the nav's words equal `nav.json`'s, in order; the
words and the title compute to `text-transform: none`; a `.cc-wave` directly follows the bar; at 1099 px the menu
button is shown and the nav is not. `_test/nav_test.rb` pins the list: the five words, what Learn holds, no
destination linked twice, and every destination `main`'s eight uppercase words reached still linked.
`scripts/check_layout.py` holds this site's header to one line from 1100 px, the menus to their behaviour and the
open column to reaching every line on a 375 × 667 phone.

## The alternative that was not built

**Revise v2 in place.** Editing `brand/v2/theme.css` so that every product's header becomes sentence case with
the wave the day the site merges. It is one version to maintain and no product is left behind. It was not chosen
because v2 is loaded live by every product, including Shiny apps and student projects nobody has opened this
month: their uppercase titles would change case and their pages would gain a band under the bar without anyone
looking at them, and v2's own contract promises that will not happen. If the two looks living side by side
bother more than that risk, the change is small: move `header.css`'s rules into `v2/theme.css` and delete v3.

## Changes within v3

- **2026-11-17 — proposed.** Everything above.
