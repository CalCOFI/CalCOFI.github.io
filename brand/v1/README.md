# calcofi.io brand — v1

One source for the theme, the header chrome, the logo and the favicon that every
CalCOFI product shares. Served from `https://calcofi.io/brand/v1/` (this
directory in `CalCOFI/CalCOFI.github.io`). **v1 is frozen once adopted** — token
additions are fine, anything that changes how an existing page looks or behaves
is `v2/`, and consumers opt in.

| file | what |
|---|---|
| `theme.css` | colour tokens (`--bg --panel --panel-2 --border --fg --muted --accent --accent-d --warn`), `.cc-header` / `.cc-footer` chrome, `.cc-dark-only` / `.cc-light-only` image pairing |
| `theme.js` | resolve → apply → persist → toggle → notify (see below) |
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
   links; the 🌓 toggle at the right. Where a framework owns the top bar (Quarto,
   pkgdown, mkdocs, bslib `page_navbar`) the logo goes in its brand slot and its
   native toggle is bridged — a page never has two bars or two toggles.
4. **Favicon**: the set above, except products with their own designed mark
   (`calcofi4r` hex, `calcofi4py` squircle).
5. **`?tour=off`** suppresses any guided tour / welcome modal, so a screenshot
   shows the interface.
6. **Two screenshots** for the calcofi.io card, `images/<key>_dark.png` and
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
