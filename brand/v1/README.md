# calcofi.io brand — v1

> **Superseded by [v2](../v2/) on 2026-09-04.** v1 stays served and frozen; a product that never migrates keeps working.

One source for the theme, the header chrome, the logo and the favicon that every
CalCOFI product shares. Served from `https://calcofi.io/brand/v1/` (this
directory in `CalCOFI/CalCOFI.github.io`). **v1 is frozen once adopted** — token
additions are fine, anything that changes how an existing page looks or behaves
is `v2/`, and consumers opt in.

| file | what |
|---|---|
| `theme.css` | colour tokens (`--bg --panel --panel-2 --border --fg --muted --accent --accent-d --warn`), `.cc-header` / `.cc-footer` chrome, `.cc-release` chip, `.cc-dark-only` / `.cc-light-only` image pairing |
| `theme.js` | resolve → apply → persist → toggle → notify (see below); draws the toggle's icon |
| `head.html` | the `<head>` block to paste verbatim: favicon links, the inline pre-paint snippet, the two tags above |
| `logo_calcofi.svg` / `logo_calcofi_light.svg` | the logo on a dark / light ground |
| `favicon.ico` `favicon-32x32.png` `favicon-16x16.png` `apple-touch-icon.png` | the favicon set |

## The contract

1. **Theme resolution** — `?theme=dark|light` in the URL → cookie `cc_theme`
   (`Domain=.calcofi.io`, so the choice carries from calcofi.io to
   `app.` / `erddap.` / `storage.` / `status.`) → `localStorage.theme` → **dark**.
   A URL parameter persists (a visitor who follows a `?theme=light` link stays light).
2. **What gets set** on `<html>`: `data-theme` (ours), `data-bs-theme`
   (Bootstrap 5.3 / bslib / pkgdown / Quarto), `data-md-color-scheme`
   (mkdocs-material), and `color-scheme`. Style against `--bg` etc., or against
   `[data-theme="light"]` — never against `prefers-color-scheme`.
3. **Header**: the CalCOFI logo far left, linking to `https://calcofi.io`; the
   product's title beside it, linking to the product's own root; the product's own
   links; the theme toggle at the right — **a sun while the page is dark, a
   moon-in-sun while it is light**, i.e. the icon shows what a click switches *to*
   (the mkdocs-material pair, Material Design Icons brightness-7 / brightness-4;
   `theme.js` draws it over the snippet's `🌓` fallback, and `theme.css` exports
   the two masks as `--cc-icon-sun` / `--cc-icon-moon`). Where a framework owns
   the top bar (Quarto, pkgdown, mkdocs, bslib `page_navbar`) the logo goes in its
   brand slot and its native toggle is bridged **and dressed in the same pair**
   (docs' `brand-head.html`, the packages' `_pkgdown.yml`) — a page never has two
   bars or two toggles.
4. **Release**: a product built on the integrated database shows which release, as
   `<a class="cc-release" href="https://calcofi.io/db-schema/#erd?v=vYYYY.MM.DD">release <b>vYYYY.MM.DD</b></a>`
   immediately after the title (Shiny: `cc_brand_header(release = …)` /
   `cc_release_chip()`). The version is what the page's data was *built from*, never
   "latest" fetched at load — the two diverge between a release and a redeploy.
5. **Favicon**: the set above, except products with their own designed mark
   (`calcofi4r` hex, `calcofi4py` squircle).
6. **`?tour=off`** suppresses any guided tour / welcome modal, so a screenshot
   shows the interface.
7. **Two screenshots** for the calcofi.io card, `images/<key>_dark.png` and
   `_light.png`, captured at `live_url?theme=<t>&tour=off` (1200×750).

## Using it

Plain HTML / Jekyll / Hugo:

```html
<head>
  …
  {{ contents of head.html }}
  <link rel="stylesheet" href="style.css">   <!-- your own, after theme.css -->
</head>
<body>
<header class="cc-header">
  <a class="cc-home" href="https://calcofi.io" aria-label="CalCOFI.io home">
    <img class="cc-logo-dark"  src="https://calcofi.io/brand/v1/logo_calcofi.svg"       alt="CalCOFI" width="32" height="32">
    <img class="cc-logo-light" src="https://calcofi.io/brand/v1/logo_calcofi_light.svg" alt="CalCOFI" width="32" height="32">
  </a>
  <a class="cc-title" href="./">db-schema</a>
  <span class="cc-spacer"></span>
  <nav class="cc-links"><a href="…">query</a><a href="…">docs</a></nav>
  <button class="cc-theme-toggle" type="button" aria-label="Toggle dark / light theme">🌓</button>
  <!-- 🌓 is the no-JS fallback: theme.js replaces it with the sun / moon-in-sun icons -->
</header>
```

React to a change (basemap, Plotly template, Mermaid theme):

```js
function restyle(theme) { map.setStyle(theme === "dark" ? DARK : LIGHT); }
restyle(window.ccTheme ? ccTheme.get() : document.documentElement.dataset.theme);
document.addEventListener("cc:theme", e => restyle(e.detail.theme));
```

Shiny (R): `calcofi4r::cc_brand_head()` in `tags$head`, `cc_brand_header()` for the
bar, `cc_theme_init(session)` in `server` (reads `?theme=`, drives
`bslib::toggle_dark_mode()`, writes the cookie back), `cc_tour_enabled(session)` for
`?tour=off`. Quarto / pkgdown / mkdocs recipes are in the plan
(`workflows/.claude/plans/2026-08-25 Consistent dark-light theme …`).

Consistency is checked weekly by `scripts/check_brand.py` in this repo, not assumed.

> **v2 is proposed (2026-08-30)** — [`../v2/`](../v2/): the SIO look, light by default, Source Sans 3 +
> Teko, the horizontal lockup, two scales. Previewed at `calcofi.io/brand/v2/`, `calcofi.io/v2/` and
> `calcofi.io/explore/v2/` for the 9/8 decision; the flip date will be recorded here. **v1 remains served
> and frozen** — a product that never migrates keeps working.

## Changes within v1

- **2026-08-29 — an icon set.** `icons/calcofi-icons.svg` (a `<symbol>` sprite, ids
  `cat-*` for the twelve data categories of `metadata/category.csv`, `lens-*` for the
  explorer's five lenses, `realm-*`, `ui-*` for header and panel actions) and
  `icons.css` (every glyph as a `--cc-icon-<id>` mask custom property plus
  `<i class="cc-i cc-i-cat-fish">`, the way `theme.css` exports the toggle's sun /
  moon) — Material Design Icons (Pictogrammers, Apache-2.0) in the toggle's idiom,
  plus bespoke marine glyphs (copepod, krill, diatom, whale, a ship on its track, a
  section curtain) drawn to the same 24-px grid and weight. Generated from
  `CalCOFI/explore` `src/icon-paths.ts` by `scripts/build_icons.mjs`; the contact sheet
  is `icons/index.html`. `theme.css` gains `.cc-icon-button`, the toggle's flat 2 rem
  button generalized. Additive: no existing page changes; db-viz-station swapped its
  category emoji for the masks the same day.

- **2026-08-29 — the toggle's glyph.** The fleet had grown four different pickers
  (Quarto's icon-less switch on docs, the coloured 🌓 emoji on calcofi.io and the
  explorer, pkgdown's sun/moon, mkdocs-material's sun / moon-in-sun on calcofi4py);
  Ben chose the last as the only obvious one. Changed in place rather than as v2 —
  the purpose is that every product changes at once; the markup, classes,
  selectors and behaviour are unchanged, so nothing opts in or out.
