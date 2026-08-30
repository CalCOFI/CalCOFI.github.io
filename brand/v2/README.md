# calcofi.io brand — v2 (the SIO look; light by default)

One source for the theme, the header chrome, the type, the lockup and the favicon that every CalCOFI
product shares, served from `https://calcofi.io/brand/v2/` (this directory in
`CalCOFI/CalCOFI.github.io`). **Proposed 2026-08-30**, previewed in place — the specimen
[`index.html`](index.html), the landing page at `calcofi.io/v2/`, the explorer at `calcofi.io/explore/v2/` —
for the 9/3 (show) and 9/8 (decide) meetings; the plan is `workflows/.claude/plans/2026-08-30 Rebrand to
the SIO look …`. `v1/` stays served and frozen; a product opts into v2 by changing one URL.
**v2 is frozen once adopted** — additive changes only; anything that changes how an existing page looks
or behaves is `v3/`.

| file | what |
|---|---|
| `theme.css` | the tokens (both themes, both scales), `.cc-header` / `.cc-footer`, `.cc-release`, the toggle and `.cc-icon-button`, `.cc-btn*`, `.cc-text-link`, `.cc-card`, `.cc-band*`, the type helpers, `.cc-dark-only` / `.cc-light-only` |
| `fonts.css` + `fonts/` | `@font-face` for **Source Sans 3** (variable 200–900, roman + italic) and **Teko** (300–700), self-hosted latin subsets (72 KB), OFL 1.1 (`fonts/OFL-*.txt`). The one file to edit if Brix Sans is licensed |
| `theme.js` | resolve → apply → persist (an explicit choice only) → toggle → notify; `ccTheme.version === "2"` |
| `head.html` | the `<head>` block to paste verbatim: favicons, the two font preloads, the pre-paint snippet, `fonts.css`, `theme.css`, `theme.js` |
| `icons.css` + `icons/` | the 48-glyph sprite and masks, regenerated here from `CalCOFI/explore` (`node scripts/build_icons.mjs ../CalCOFI.github.io/brand/v2`) |
| `logo_calcofi_h.svg` / `logo_calcofi_h_light.svg` | **the horizontal lockup** — the mark + "CalCOFI" wordmark, for a dark / light ground; 36 px tall on pages, 28 px in apps |
| `logo_calcofi.svg` / `logo_calcofi_light.svg` | the mark, as v1 (favicons, cards, a phone header under 480 px) |
| `favicon.ico` `favicon-32x32.png` `favicon-16x16.png` `apple-touch-icon.png` | the favicon set, unchanged |
| `index.html` | the specimen: every token with its contrast, both themes, both scales, the header, type, buttons, cards on each band, an explorer rail sample |

## What v2 is

calcofi.org is being rebuilt by the SIO web team on the template behind scripps.ucsd.edu, and the apps
should carry "some connective tissue to the brand" while keeping "creative latitude" (Mark, 2026-08-27).
Measured on the live template (Appendix A of the plan): navy `#182B49` type on white, Brix Sans 18 px /
1.44, Refrigerator Deluxe uppercase display headings, UCSD blue `#00629B` links, one yellow `#FFCD00`
CTA with 8 px corners, cream `#F5F0E6` and navy bands, rounded borderless cards, a horizontal lockup in a
white masthead. v2 is that as tokens:

- **Light is the default; dark is one click away and remembered across `*.calcofi.io`.** The dark theme
  is **navy** — `#182B49` panels on a `#0F1A2E` ground, the SIO template's own band colour — so a dark app
  is still on-brand.
- **Type by role:** `--sans` Source Sans 3 (the typography page's free substitute for Brix; humanist,
  closer than Roboto), `--display` Teko (for Refrigerator Deluxe) on page h1/h2 only. Self-hosted, so
  the feedback screenshot can embed them and no third party sees a request.
- **The header is SIO-shaped and still one bar:** the lockup far left → `https://calcofi.io`, the
  product title as an uppercase nav item → its own root, the release chip, uppercase links, the toggle.
  No utility strip, no search, no second bar.
- **Two scales, one attribute.** `theme.css` carries a *page* scale (18 px / 40 px bands / 1170 px / 72
  px header / 8 + 12 px corners) and an *app* scale (13 px / 4 px gutters / 44 px header / 4 + 6 px
  corners), selected by `<html data-cc-scale="app">`, which `head.html`'s snippet copies from
  `<meta name="cc-scale" content="app">`. Pages get SIO's rhythm; apps get SIO's tokens. The whitespace
  does not transfer between them and is not meant to.

## Tokens

Semantic names are v1's, so a consumer's CSS keeps resolving. Values are the UC San Diego palette
verbatim except the two derived text tones, which exist because the brand's own value fails AA at UI
sizes (the specimen computes every pair; this table is 2026-08-30's run).

| token | light (default) | dark | note |
|---|---|---|---|
| `--bg` | `#ffffff` | `#0f1a2e` | dark sits just below navy so navy panels read as panels |
| `--panel` | `#f5f5f5` | `#182b49` | **UCSD Navy** is the dark panel |
| `--panel-2` | `#ffffff` | `#21375c` | |
| `--border` | `#dddddd` | `#34486b` | |
| `--fg` | `#182b49` | `#e9edf3` | navy on white 14.2:1 · 14.8:1 |
| `--muted` | `#66686a` | `#9fb0c8` | Cool Gray `#747678` darkened: 5.1:1 on the panel, 4.9:1 on Sand (the brand value is 4.2:1 / 4.0:1) · dark 6.4:1 |
| `--accent` | `#00629b` | `#4fb6e6` | **UCSD Blue**, 6.5:1 on white; lifted for the dark ground, 7.6:1 |
| `--accent-d` | `#004663` | `#8ad0f0` | hover |
| `--on-accent` | `#ffffff` | `#0f1a2e` | NEW — text on an accent fill: 6.5:1 · 7.6:1 (white on the dark accent would be 2.3) |
| `--warn` | `#8a6500` | `#ffcd00` | Gold darkened for AA as text 5.3:1 (`#C69214` is 2.8); the yellow itself in dark, 11.6:1 |
| `--band` | `#f5f0e6` | `#182b49` | NEW — the alternating page band (**Sand** / navy) |
| `--header-bg` | `#ffffff` | `#182b49` | NEW — the bar |
| `--cta-bg` / `--cta-fg` | `#ffcd00` / `#182b49` | same | NEW — the yellow button, 9.4:1 in both themes |
| `--cc-green` / `--cc-red` | `#457a1c` / `#b3261e` | `#8fbf4f` / `#ff8080` | NEW — an app's go / no-go text (UCSD Green darkened; red is not a brand colour), ≥ 4.6:1 everywhere |
| `--cc-navy --cc-blue --cc-yellow --cc-gold --cc-cyan --cc-sand --cc-gray --cc-stone` | constants | constants | the palette by name, for a product's own use |
| `--sans` / `--display` / `--mono` | Source Sans 3 stack / Teko stack / as v1 | | |
| scale: `--fs --lh --fs-sm --nav-fs --space --band-pad --header-h --lockup-h --container --radius --radius-card` | 18px 1.44 14px 15px 8px 40px 72px 36px 1170px 8px 12px | | `[data-cc-scale="app"]`: 13px 1.35 11.5px 13px 4px 0 44px 28px 100% 4px 6px |

The brand does not set body type: a framework page owns its root size. A plain page applies the rhythm
with `body { font: var(--fs)/var(--lh) var(--sans); color: var(--fg); background: var(--bg); }`.

## The contract

1. **Theme resolution** — `?theme=dark|light` → cookie `cc_theme` (`Domain=.calcofi.io`), **honoured only
   beside the marker cookie `cc_theme_src=user`** → `localStorage.cc_theme` (v2's own key, same marker) →
   **light**. A `?theme=` link persists (a visitor who follows one stays on it).
2. **Persist only an explicit choice.** `theme.js` writes the cookie and localStorage from the toggle,
   `ccTheme.set()` or `?theme=` — never from the resolved default. v1 wrote its resolved theme on every
   load, so during the weeks v1 and v2 pages coexist a v1 page seen first would otherwise stamp
   `cc_theme=dark` from v1's default and every v2 page would open dark. A v1 *toggle* (which lacks the
   marker) is lost across the boundary; that is the accepted cost and it ends with Phase 3.
3. **What gets set** on `<html>`: `data-theme`, `data-bs-theme`, `data-md-color-scheme`, `color-scheme`,
   and `data-cc-scale` from the meta. Style against the tokens or `[data-theme="dark"]` — never against
   `prefers-color-scheme`, and never against "no attribute means dark" (v1's idiom): in v2 no attribute
   means light.
4. **Header**: the lockup far left → `https://calcofi.io` (36 px on pages, 28 px in apps); the product's
   title beside it → the product's root, uppercase, with an optional `<small>` subtitle in sentence case;
   the release chip; the product's own links, uppercase; the toggle at the right — the sun while dark, the
   moon-in-sun while light. Where a framework owns the bar (Quarto, pkgdown, mkdocs, bslib `page_navbar`)
   the lockup goes in its brand slot and its native toggle is bridged and dressed in the same pair — a
   page never has two bars or two toggles.
5. **Release**: as v1 — `<a class="cc-release" href="https://calcofi.io/db-schema/#erd?v=vYYYY.MM.DD">release <b>vYYYY.MM.DD</b></a>`
   right after the title, the version the page's data was *built from*.
6. **Buttons and links**: `.cc-btn-cta` is the one yellow per view; `.cc-btn-primary` the accent;
   `.cc-btn-ghost` outlined; `.cc-text-link` the uppercase underlined call to action; inline prose links in
   the accent, no underline, underline on hover.
7. **Scale**: an app declares `<meta name="cc-scale" content="app">` above the head block; a page declares
   nothing.
8. **Favicon**: the set above, except `calcofi4r` (hex) and `calcofi4py` (squircle).
9. **`?tour=off`** suppresses any guided tour, so `live_url?theme=<t>&tour=off` is a deterministic
   screenshot; two screenshots per card, `images/<key>_dark.png` and `_light.png`, the **light one the
   default face**.
10. **Version**: `window.ccTheme.version === "2"`; the `cc:theme` event's detail is `{theme, version}`.

## v1 → v2, the deltas

| | v1 | v2 |
|---|---|---|
| default theme | dark | **light** |
| dark palette | neutral gray (`#1b1d20`, `#4dabf7`) | **navy** (`#0f1a2e` / `#182b49`, `#4fb6e6`) |
| light palette | Bootstrap-flavoured (`#2780e3`) | **UC San Diego** (`#182b49` on white, `#00629b`) |
| type | system-ui | Source Sans 3 + Teko, self-hosted |
| header logo | the 32 px mark + the product name | **the horizontal lockup** (36 / 28 px) |
| header type | 1.05 rem title, mono links | uppercase 15 / 13 px nav idiom |
| persistence | resolved theme written on every load | **only an explicit choice**, marked `cc_theme_src=user`; localStorage key `cc_theme` (was `theme`) |
| "no `data-theme` attribute" | dark | **light** — key dark rules on `[data-theme="dark"]` |
| new tokens | — | `--on-accent --band --header-bg --cta-bg --cta-fg --cc-green --cc-red --cc-*` constants, the scale tokens |
| new classes | — | `.cc-btn*` `.cc-text-link` `.cc-card*` `.cc-band*` `.cc-container` `.cc-h1/2/3` `.cc-eyebrow` `.cc-lede` `.cc-chip` `.cc-footer-bar` |
| scale | — | `data-cc-scale="app"` |
| `ccTheme.version` | `"1"` | `"2"` |

## Using it

Plain HTML / Jekyll / Hugo (a page):

```html
<head>
  …
  {{ contents of head.html }}
  <link rel="stylesheet" href="style.css">   <!-- your own, after theme.css -->
</head>
<body>
<header class="cc-header">
  <a class="cc-home" href="https://calcofi.io" aria-label="CalCOFI.io home">
    <img class="cc-logo-dark"  src="https://calcofi.io/brand/v2/logo_calcofi_h.svg"       alt="CalCOFI">
    <img class="cc-logo-light" src="https://calcofi.io/brand/v2/logo_calcofi_h_light.svg" alt="CalCOFI">
  </a>
  <a class="cc-title" href="./">db-schema</a>
  <a class="cc-release" href="https://calcofi.io/db-schema/#erd?v=v2026.08.25">release <b>v2026.08.25</b></a>
  <span class="cc-spacer"></span>
  <nav class="cc-links"><a href="…">query</a><a href="…">docs</a></nav>
  <button class="cc-theme-toggle" type="button" aria-label="Toggle dark / light theme">🌓</button>
</header>
<section class="cc-band cc-band-alt"><div class="cc-container"> … </div></section>
```

An app adds `<meta name="cc-scale" content="app">` **above** the head block and may swap the lockup for
the mark on a narrow phone:

```html
<picture>
  <source media="(max-width: 479px)" srcset="https://calcofi.io/brand/v2/logo_calcofi_light.svg">
  <img class="cc-logo-light" src="https://calcofi.io/brand/v2/logo_calcofi_h_light.svg" alt="CalCOFI">
</picture>
```

React to a change (basemap, Plotly template, Mermaid theme) — unchanged from v1:

```js
function restyle(theme) { map.setStyle(theme === "dark" ? DARK : LIGHT); }
restyle(window.ccTheme ? ccTheme.get() : document.documentElement.dataset.theme);
document.addEventListener("cc:theme", e => restyle(e.detail.theme));
```

Per framework (the recipes are v1's with the URL changed; Phase 3 of the plan carries each product over):

- **Shiny (R)** — `calcofi4r::cc_brand_head(brand = "v2")` in `tags$head` (emits the meta + head block),
  `cc_brand_header(subtitle = , release = )` for the bar with the lockup, `cc_theme_init(session)` in
  `server`, `cc_tour_enabled(session)` for `?tour=off`. bslib's `input_dark_mode(mode = cc_theme(request))`
  now starts light. (calcofi4r 1.15.0 — gates the five Shiny apps.)
- **Quarto** (workflows, docs) — `libs/brand/quarto_head.html` → v2; the *light* Quarto theme becomes the
  default and `brand-light.scss` takes the Source Sans stack + navy; `scripts/brand_inject_html.R` swaps the
  URL in already-rendered notebooks, no re-render.
- **pkgdown / mkdocs** — `_pkgdown.yml` includes → v2 (the `link` + `icon:` + `class:` navbar workaround
  stands: pkgdown 2.2 has no `html:` component); mkdocs' navy header now *is* the brand.
- **Vite / React** (explore) — `VITE_BRAND=v2` selects the head block and the lockup at build time.

## Brix Sans

Brix Sans and Refrigerator Deluxe are licensed to UC San Diego (MyFonts / Adobe Fonts) and self-hosted by
SIO under that licence; we neither hotlink nor copy them. **Ask the SIO web team whether their webfont
licence can cover calcofi.io as a UCSD-hosted program.** If yes: `fonts.css` swaps the sources and
`"Brix Sans"` goes to the front of `--sans` (and `"Refrigerator Deluxe"` of `--display`) — nothing else
names a font. The brand site's rule "never use Brix and Source Sans simultaneously" is why it is a swap,
not an addition.

## Checked, not assumed

`scripts/check_brand.py` opens every product at `?theme=light` and `?theme=dark` (and any URL with
`--url`); Phase 4 of the plan makes it report `ccTheme.version` and, for a v2 product, require the light
default in a fresh context, the fonts loaded (`document.fonts.check('16px "Source Sans 3"')`), the lockup
`<img>` and `data-cc-scale` on `app.calcofi.io/*`. The specimen prints its own contrast table and its
font-load result (`window.__contrast`, `window.__fonts`).

## Changes within v2

- **2026-08-30 — proposed.** Everything above. Values measured from scripps.ucsd.edu and brand.ucsd.edu on
  2026-08-30 (the plan's Appendices A–B); the SIO template will move — re-measure when calcofi.org launches.
