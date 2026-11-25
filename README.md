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

### Front door v2 (2026-11-17): Betty's first screen over the seven tasks' panels

PR #45 (Betty Huang, 2026-11-13 to 11-16, after the 12 November database tour) redrew the first screen,
the header, the three catalog pages and the dataset page. It was reconciled with `main` on 2026-11-17 on
one rule: **her design leads the presentation, and everything `main` does still works.** What follows in
this section (the seven doors, the eight header words) is the record of what the panels and anchors are;
where v2 changed how they are reached, this subsection is the current state.

- **The first screen** is `_includes/front_door_hero.html` (`assets/hero.css`, `assets/hero.js`): the
  eyebrow, "California's ocean, measured since {since}", two sentences, four numbers, and "Where do you
  want to start?" with three start cards over Line 90's sea floor (`_data/line90_floor.json`), then a
  strip of two quiet links. There are no door buttons. Every one of the seven tasks is one visible link, or
  one word of the header, away:

  ```
  task (main, 2026-11-16)             on the first screen                          goes to
  1 See what CalCOFI collects         header Learn ▾ › How CalCOFI samples ·       #learn
                                      the label by the ship (hidden under 900 px)
  2 Explore and download on a map     card 1 "Explorer" (the one yellow button)    the Explorer
                                      header Map ▾ › All apps                      #explore (Maps and apps)
  3 Find and download a dataset       card 2 "Browse datasets" · header Data ▾     /datasets/
  4 Work with the data in code        card 3 "Code" · header Data ▾ › Get it       #program
  5 Cite the data                     header Learn ▾ › Cite the data               docs/cite.html
  6 Contribute data                   strip "Contribute"                           docs/provide.html
  7 Inform ocean and fisheries        strip "Statewide monitoring"                 #monitor
    management
  new: one table across datasets      card 3 "Query Builder" · Data ▾ › Get it     calcofi.io/query/
  ```

  **The strip had five links until 2026-11-17** (Share your data · Cite the data · What CalCOFI collects ·
  Statewide monitoring · More visualizations). The owner cut it to the two nothing else on the screen says:
  "Cite the data" repeated the header's Cite, "What CalCOFI collects" its Learn, "More visualizations" its
  Map menu, and "Share your data" became "Contribute". It stays a row under the cards, where it was: two
  links are too few for a card of their own, and beside "Line 90 sea floor, GEBCO 2025" they close the screen.

  Three things differ from the PR as opened, each because `main` had decided it: card 1 has one button,
  not Explorer beside Data Finder (one app on the first screen: the reply to Ed Weber of 2026-11-10, and
  `main` stopped calling to the station app from the front door on 2026-11-16; the Dataset Finder keeps its
  card in Maps and apps and its line in the header's Map menu); "Code" opens `#program` (R, Python, SQL and
  ERDDAP side by side) where it had opened the SQL shell alone; "Share your data" goes to the docs
  chapter on contributing where it had gone to the workflows site.
- **The panels are `main`'s**, in `main`'s order, with two redrawn: `#learn` opens on Betty's slim navy
  bar over the annotated drawing alone, with `main`'s links (every dataset, measurement and species, the
  docs, the FAQ), the kinds of data, the docs card and the ship's log below it for whoever scrolls;
  `#explore` is her **Maps and apps** (the Explorer large, the Dataset Finder beside the apps for one
  dataset, then the student projects, each card ending Open · Source · Status · Usage), which keeps
  `main`'s line to Find. An app whose `status:` is `superseded` or `archived` is not drawn there
  (`scripts/check_layout.py` `_product_keys` expects exactly that). `#find`, `#program` and `#monitor`
  are unchanged; `#find` is reached from Maps and apps, from the old anchors and from `?q=` / `?tab=`.
- **Anchors.** The routing script is `main`'s. `#viz` (a door until 2026-11-16, then a group of Explore)
  lands on Maps and apps at the apps for one dataset (`#dataset`); `#students` on the student projects
  (`#student`). Close puts focus back on the link that opened the panel, or on the start heading.
- **The header is the brand's** since 2026-11-17 (brand v3, [`brand/v3/README.md`](brand/v3/README.md) § 4):
  **Data ▾ · Map ▾ · Learn ▾ · calcofi.org ↗**, sentence case, from the one list
  `_data/nav.yml`, which `_plugins/nav.rb` resolves for this site's `_includes/site_nav.html` and for
  `/brand/v3/nav.json`, drawn by `brand/v3/header.js` into the Explorer and the Query Builder. A word with a
  menu is a button: it opens on hover and on a press, and Escape closes it. The owner settled the words in
  three steps on 2026-11-17: Docs, FAQ and News back as words of the bar, as on `main` (nine words with Query
  and Cite); then, to simplify, all of them folded under **Learn**, which holds Guides (How CalCOFI samples,
  Frequently asked questions, Cite the data, Documentation) and News (Tutorials, Stories, All news: the
  ship's log filtered by type). Each destination is linked once. Where `main`'s eight uppercase words went:
  DATA is Data ▾; APPS is Map ▾; ACCESS and BUILD are Data ▾ › Get it; DOCS, FAQ and NEWS are lines of Learn ▾;
  calcofi.org ↗ is itself. `main`'s rule that the header never wraps holds: the menu button takes over under
  1100 px (`NAV_BREAK` in `brand/v3/header.css`, `brand/v3/header.js` and `scripts/check_layout.py`), and
  the open column lists every line and scrolls inside itself.
- **The Query Builder has its own address, `https://calcofi.io/query/`** (the owner, 2026-11-17: "move the
  Query Builder to its own dedicated query, and then cross-link"). Its code stays in `CalCOFI/explore`
  (`src/builder`, which shares the Explorer's engine); a thin repo `CalCOFI/query` builds and serves it.
  Here the address is written once, as `CalCOFI::Nav::QUERY_URL`, and read by the header's Query Builder line, the first under Data ▾ › Get it
  (`query: ""` in `_data/nav.yml`; it was a word of the bar, Query, until the owner moved it there that evening), the third start card and each dataset page's one-species and
  one-measurement CSV links (`…/query/?pick=…`). A preview or a local build names its own copy with
  `local_query` (`_config.netlify.yml`: `/query/`, placed there by `scripts/build_netlify.sh` from
  `QUERY_DIST` or `npm run build:query`; `_config.local.yml`: the Vite dev server's `builder.html`).
  `/explore/builder.html` redirects to it, query string and all, once `VITE_QUERY_URL` is set on the
  Explorer's build. **The address is not new:** from 2026-08-10 (20f82df) to 2026-11-17 this repo's
  `query/index.html` redirected `calcofi.io/query/` to `calcofi.io/db-query/`, the SQL console, which had that
  name first. The project site CalCOFI/query took the path over when it first deployed (2026-11-17), so a link
  to `/query/` written for the SQL console now opens the Query Builder, which links db-query for that reader;
  the file is deleted here, since it was shadowed and would have come back to life had that repository ever
  been removed.
- **The wave** (brand v3 § 4.5) is under the bar on every page: the catalogs' search band and a dataset
  page's title band are the wave with a head in it; every other page, the front door included, has a slim
  one (34 px), drawn by `_layouts/default.html`. On the front door it cuts into the hero's sky.
- **Phone.** Stacked, the hero is scaled by its height, so under 900 px the start heading takes the
  hero's ink (it was white on the sky), the label by the ship is not drawn and the strip sits under the
  cards; under 480 px the four numbers close up to fit 375 px.
- **The layout contract was re-anchored, not loosened** (`scripts/check_layout.py`, 2f7c4dc). The PR's markup had
  moved out from under its selectors, so the front-door block, the header menus and the redesigned dataset page
  were passing without being measured. It now reads `section.hero`, the header's words and their menus,
  the finders and `main.dp-page`, at the old thresholds: every task link on the first screen of a 1280 × 645
  window and 32 px tall, nothing open on load, every old anchor opened from a shut page, one Download button per
  dataset page, a dataset page under 2,200 px. Three rules follow the new design and say so in the script's
  docstring: one yellow button on the first screen (the Explorer's; D6 A had none), four numbers (five before), and
  the first screen one window tall. When front door v2 merged (2026-11-17) it failed on three things, all on
  the catalog pages, left for the owner to decide; he decided them the same evening ("fix with mix … add species
  hierarchy view back as another tab") and the check is green:
  - `/measurements/` opens with its five categories closed (1,145 px at 1470 against the 1,625 ceiling, which did
    not move; it was 8,643 px with all 104 rows open). A press opens a category in place, a search opens the
    ones that hold a match, `?q=` and `?cat=` land the same way. Without JavaScript the full list is in
    `<noscript>`.
  - `/species/` finds higher taxa again: `_plugins/finder.rb` (`CalCOFI::Finder.higher_taxa`) writes
    `/species/finder-taxa.json`, the taxa with a page that are not species rows, and a search lists the matches
    under the species rows as "Groups and other taxa" (`?q=sardin`: the sardine, then *Sardinops*). The
    hierarchy (the icicle) is a view tab again, drawn when shown; `?tab=hierarchy` lands on it. The hidden
    legacy block that still fed the old class list is gone.
  - `/datasets/` is unchanged at 2,575 px and **its ceiling is restated, 2,300 → 2,725**: a finder with every
    dataset as a row is the page's point. The arithmetic is beside the constant in `scripts/check_layout.py`
    (the fixed parts plus 22 rows), so a 23rd dataset fails. This is the one threshold that moved.
- **Preview.** `scripts/build_netlify.sh` builds this site and the Explorer into one folder (`OUT`,
  default `_site`) and points every link to the live Explorer at the copy, so the Query Builder links
  stay inside the preview. `EXPLORE_DIST=` reuses a built Explorer. `scripts/dev_all.sh` runs both on one
  machine for development.

**One screen, seven doors** (issue #30, "calcofi.io, calmer"; decisions D2 A, D3 A, D4 B, D5 A, D6 A; the
doors re-cut to seven *tasks* on 2026-11-16 from the program's users and coordinator).
At 1280 × 645, the screen in Dan Rudnick's report, the whole first screen is visible: on the left, what
CalCOFI is (the eyebrow, "From ship to screen", one lede, five numbers and the Line 90 section drawn
**quiet**); on the right, "What do you want to do?" and seven doors, each a thing a person came to do, in
plain words (no "integrated", "harmonized", "parquet" or "STAC" on the first screen). The last three doors
are drawn smaller. The first screen has no yellow (D6 A). Five doors each open one full-width panel on
the Sand band beneath the first screen, and opening another door closes it (D2 A); Cite and Contribute
are plain links, one click to their chapter of the docs book. Every panel has one yellow button to its
real destination, except Work with the data in code, where Get the data is the destination. With no door
open the page is about 900 px tall at 1470 px.

```
door                                    opens        what is behind it
1 See what CalCOFI collects             #learn       the annotated Line 90 section (#sec-full: the 14 pins, the axes);
  "What is measured, where and how                   the kinds of data (#kinds), read from the record's categories —
   deep, since 1949."                                the three long series first (fish eggs and larvae, hydrography,
                                                     zooplankton), then the rest in category.order, each with its
                                                     datasets, their years and its holdings; links to /datasets/,
                                                     /measurements/, /species/, the docs, calcofi.org's sampling
                                                     methods (the yellow); the docs card; the four newest log entries
2 Explore and download on a map         #explore     the Explorer (the yellow), the lens key, its card (#explorer), the
  "Pick species or measurements, a                   General apps (#general), then Other data visualizations (#viz:
   time and a place. See them                        the Dataset · Student tabs). "Want one dataset as its provider
   together and download the table."                 published it? Find the dataset →" opens door 3 in place
3 Find and download a dataset           #find        the head beside a short grid map (context; "Explore by station →"
  "Know which dataset you want? Each                 opens the Explorer's station view), then, as one step, the one
   has its own page with its source                  search over the list of datasets (each name an underlined link
   files and citation."                              to its page, its years drawn beside it), the three catalog tabs
                                                     (#datasets holds all three), the release line. "Want several
                                                     kinds of data together, or just one area and period? Use the
                                                     Explorer →" goes straight to the Explorer. No Data Finder
                                                     button: the Explorer replaces it (2026-11-16)
4 Work with the data in code            #program     Get the data (five snippets), Services · Packages (#access), then
  "R, Python, SQL and ERDDAP."                       Build on the pipeline (#build: calcofi4db, db-schema, workflows,
                                                     GitHub as a quiet primary button) — no yellow
5 Cite the data                         a link       https://calcofi.io/docs/cite.html
6 Contribute data                       a link       https://calcofi.io/docs/provide.html
7 Inform ocean and fisheries            #monitor     the products whose products.yml entry has `doors: [monitor]` (the
  management · the statewide                         UCLA map, Offshore Wind Monitoring). Only what exists is drawn;
  monitoring inventory, more to come                 a fact the build cannot read is omitted, so nothing is promised
```

The split the coordinator asked to be visible: **one dataset in its original, authoritative form** is that
dataset's page (door 3); **several kinds of observation together, or a subset by time and place**, is the
Explorer (door 2). Each of the two panels carries one line saying when to use the other. Before
2026-11-16 the doors were Dan's seven pathways (Find and download data · Visualize and explore · Download
programmatically · Build something · Learn how CalCOFI sampling and data work · Ocean monitoring · Other
data visualizations); Build and Other data visualizations are now the second groups of doors 4 and 2, so
nothing a developer or a student project had was removed.

**The URL carries the open door.** Opening a door writes `#learn` (or `#explore`, `#find`, `#program`,
`#monitor`). On load, `?door=find` also opens it, and so do `?q=` (the search) and
`?tab=<one of the Find tabs>`. The old anchors still land: an id inside a panel (`#datasets`, `#access`,
`#general`, `#explorer`, `#kinds`, and the two former doors `#build` and `#viz`) opens that panel and
scrolls to the element, and `?door=build` / `?door=viz` do the same. A tab id (`#species`, `#student`)
opens the panel and selects the tab. Either way the URL keeps that hash (not the door's), so the
browser's own scroll to the fragment on load lands on the element, below the sticky header. The retired words `#data`, `#apps`, `#docs`, `#monitoring` and
`#students` map to where they live now. The header's words are the same links (D3 A), so DATA · APPS ·
ACCESS · BUILD open their doors in place (Find, Explore, Code, Code at its Build group), and the open
door's word is marked `aria-current` (both ACCESS and BUILD while Code is open). Each submenu item links
`/#<tab id>`, so General lands in Explore and Student in Explore's second group. DOCS, FAQ and NEWS stay
pages. The logic is one inline script at the foot of `index.html`. It runs before the deferred scripts,
so a door named in the URL is open before the first paint. Each open fires `cc:door` on the document.
With JavaScript off, every panel shows (a `<noscript>` rule), in door order.

**Every product is still drawn.** The cards are `_includes/product_card.html`, unchanged except for a
`data-key`. `check_layout.py` asserts that every key in `products.yml` is drawn behind some door.

Where the facts come from is unchanged:

```
assets/section.js        Line 90 as an oceanographic section. buildSection(host, reach, {quiet}) draws the
                         quiet version (viewBox 1400 × 600, cropped at the floor line, role=img) or the
                         annotated one (1400 × 660, the 14 pins as links to calcofi.org method pages).
                         Gear depths are protocol constants, each with a `source:` comment. Gradient
                         ids carry a per-drawing suffix, so the two drawings never share a <defs>.
_data/line90_floor.json  the sea floor (GEBCO 2025 every 500 m), committed cartography; without it the
                         floor is drawn and the captions say so.
assets/reach.js          the static grid map (framed on the survey's core, its key in the caption) into
                         #map-host, and each dataset row's years into Find's list (#strip-host). The rows
                         and their linked names are HTML from site.data.reach.datasets, so they read
                         without JS; the drawing only adds the cells, the decade rules and the bars.
#reach                   ONE inline JSON the drawings read (_plugins/datasets.rb, site.data.reach).
the five numbers         site.data.catalog.numbers. A value the build cannot read is not rendered.
```

**Motion**: the rosette casts down the CTD wire and the CUFES dots flow. Both stop under
`prefers-reduced-motion`, and so do the panel's 220 ms entrance and the chevron turn.

**Checked** by `scripts/check_layout.py` on `/`, `/?door=viz`, `/?q=sardine&tab=species` and `/?q=krill`,
at 1470 and 375 px, in both themes. These assertions hold:

- The seven doors are in order (`FRONT_DOORS`), each at least 32 px tall. A panel door controls its own
  panel; Cite and Contribute are links to their docs chapters (`FRONT_LINKS`).
- At 1280 px and wider, every door ends above the 645 px fold.
- On a phone, the head, the drawing and the doors stack in that order.
- No door is open on load unless the URL names one, and then exactly one is — the one `?door=` names.
- A click on a link to every old anchor (`FRONT_ANCHORS`: the doors, the ids and tabs inside panels, the
  retired words) opens the door it now lives behind.
- The page is at most 950 px tall at 1470 with no door open.
- Opening Find and then Explore leaves only Explore open, and a second click closes it.
- The first screen has no `--warn` and no yellow, and each panel has exactly one yellow button (Code none).
- The quiet drawing has no pins. The See-what-CalCOFI-collects drawing has them, and each answers a ranged GET.
- The five numbers equal the record's.
- Find's list has one row per dataset, each name an `<a>` to `/datasets/{key}/` with its years drawn,
  at body-text size (≥ 16 px) in `--accent`, underlined, ≥ 28 px tall (32 on a phone). At ≥ 1280 px,
  with Find open at its top, the search and the first eight names fit an 800 px window, and the map card
  is no taller than the head beside it. Find links the Data Finder nowhere. The map has one mark per cell.
- Every product is drawn.
- There is no horizontal scroll.

The front door's footer puts the partner strip and the three columns on one row, scoped by
`#layout:has(.fd-screen)`. The layout's footer is unchanged on every other page.

### The start cards and the monitoring panel: one job per slot (2026-11-23)

PR 57 (Betty, 2026-11-18 to 21) rewrote the three start cards and the Statewide monitoring panel; its review
(Ben, 2026-11-23) kept the redesign and cut the words. The rule, so a card can be checked against it:

| slot | its one job |
|---|---|
| button | names where you go, by the product's own name: "Explorer", never "Explorer App" |
| heading | says what you will do there, in other words than the button's; it answers "Where do you want to start?" |
| line | one fact neither has said (scope, a format, a number read from the release); optional; never a second sentence |
| everything else | not drawn: no eyebrow, no question, no caption except where two buttons need telling apart |

- **Cards** (`_includes/front_door_hero.html`): See it on a map → Explorer · Download the files → Datasets ·
  Pull only what you need → Query Builder (Point and click), Code (R, Python, SQL). The dataset count is the
  record's and the formats are the zip manifest's (`Downloads.format_labels`, `site.data.catalog.zip_formats`,
  `_test/downloads_test.rb`): a format the release stops writing stops being promised.
- **Strip**: Contribute · Cite the data · Statewide monitoring. "Cite the data" stays although Learn ▾ holds it:
  a reader reported she could not find it there.
- **Monitoring panel** (`index.html` § 7, `.fd-mon` in `style.css`): the question, the map's screenshot uncropped,
  one line, one button ("Monitoring map"). The panel typed three numbers counted by hand from the map's files;
  the site draws no number the build cannot read, so they are gone. The distance is "about 13 miles" (statute).
- **No CSS zoom.** The hero's words and cards, `/datasets/` and this panel were drawn at 90% with `zoom`. The
  sizes that view arrived at are now written as values: in `assets/hero.css` every length of the text layer is
  its size times `--hs` (.9 at desktop widths, 1 under 901 px, stepping up on big screens; `assets/hero.js`
  lowers it where the cards would pass the window's bottom edge), and `assets/browse-tiles.css` and `.fd-mon`
  carry the scaled numbers themselves. What a zoomed page shared with the rest of the site (the catalogs row,
  the preview, the folds, `.ap-feat`) is at the site's size again.
- Under 900 px the hero is as tall as its words, so where the ship falls behind "Where do you want to start?"
  depends on how much the cards say; the heading has a pale plate behind it there (a dark one in the dark theme).

### Seven words, tabs, and one search over the three indexes

Since 2026-09-10 (plan `2026-09-10 Measurements catalog …` § D7, Ben's scheme) the navigation is words
and an outbound link — since 2026-11-16 **DATA · APPS · ACCESS · BUILD · DOCS · FAQ · NEWS ·
calcofi.org ↗**, eight items (FAQ, the docs book's FAQ chapter, joined right after DOCS at the owner's
request), all of them generated from the one `sections:` list in `_data/products.yml`. A section is a
`kind: section` (drawn on this page under its own anchor) or a `kind: page` (a header link to its
`url:` and nothing else — that is what DOCS, FAQ and NEWS are; FAQ has no product, so no card, tab
or door draws it). The section ids `datasets`, `explore`,
`access` and `build` did not change, so every anchor anyone has bookmarked still lands; only their
titles did. `students` is gone as a section: the nine student projects are a tab of APPS. The
`docs` product keeps its key, its uptime and analytics slugs and its `added:` — the ship's log and
the three-slug contract are untouched — but its card left the Build grid for the header's word.

**The submenus.** DATA, APPS and ACCESS each list their tabs on hover or focus, with a count pill. A tab whose full listing lives on its own page carries `url:` (and the `site.data` key it needs, `data:`) in `products.yml`, and the header links that page instead of the homepage tab — Species → `/species/`, Measurements → `/measurements/`; Datasets stays a homepage tab because the whole grid is there.
It is CSS, not a library: the section link is the trigger, `:hover` / `:focus-within` opens it, and
`assets/tabs.js` blurs the focused link on Escape, which is the whole close. The whole behaviour
hangs off **one class** — `cc-submenus` on the `<nav class="cc-links">` in `_layouts/default.html`:
remove it and the header is flat seven words again, with no other edit anywhere (the plan's open
question 8).

**The menu button, and a header that never wraps** (2026-11-16, with FAQ the eighth item). The row —
lockup, tagline, the eight items, the feedback and theme buttons — fits one line from 1,089 px
(measured on seven pages in both themes), so below **1,100 px** the nav hides and a hamburger in the
icon cluster opens the same nav as a column, each word with its tab items inline (`style.css`
`@media (max-width: 1099px)`; `NAV_BREAK` in `assets/tabs.js`, which closes the menu when the window
grows past it, and in `check_layout.py` — change all three together). Before, 480–1,040 px drew the
nav on two to five lines (a 187 px header at 640). Under 600 px the empty spacer and the brand's gap
no longer push the theme toggle onto a second line (a 101 px header at 375 px, 109 px at 480–552),
and from 480 px the tagline sets on two short lines in its own box; the row is one line from 360 px
(at 320 px it still wraps). brand/v2 is untouched — every rule is this site's own `style.css`, which
no other product (docs, the Explorer, db-query …) loads. `check_layout.py --nav` (in `pr.yml`)
asserts one line of nav at 1,100, 1,280 and 1,470 px, the menu button at 1,024, 800, 640 and 375 px
with all eight items when opened, no header wrap and no overlap, on four pages, both themes.

**The tabs.** Every crowded section is tabbed, each tab with a count pill: DATA is *Datasets ·
Species · Measurements*, ACCESS is *Services · Packages* and Other data visualizations is *Dataset ·
Student* (issue #30 took APPS' Explorer and General out of tabs, into the Explore door, whose second
group carries these two tabs); BUILD keeps three cards, the second group of Work with the data in code. A tab is declared in `sections[].tabs[]` (`id`, `title`,
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
and `/measurements/search.json` **once, on the first focus** (or on load, if `?q=` is already on the
URL) — never at load otherwise, so the first paint is untouched — and a record that 404s simply
contributes no group. The dropdown listbox (`#door-res`) stays for keyboard users: results grouped,
four per group, with an "all *n* in …" row to that group's catalog; Enter opens the first hit, Escape
closes, arrow keys walk the list. `species/search.json` is built by Liquid straight from the release's
own `taxa.json`, so it is the same record `/species/` is drawn from. `measurements/search.json` is a
**bridge stub** built from the release's own `coverage.json` (`variables[realm == "env"]`) until a
release carries `measurements.json`; when `_plugins/measurements.rb` ships it writes that URL and
the stub file must be deleted — a generated page and a source page of one permalink collide.

**Round 2 (D4/D5/D9, WS-R4, 2026-09-15): one box, not two.** The catalog's own `#ds-q` field is gone
from `catalog_filters.html` — the six facet selects share the width it used to take (`flex: 1 1 0`
each) — and `assets/catalog.js` now reads its query from `#door-q` (and from `?q=` on the URL on
load) wherever that element exists; the standalone `/datasets/` page, which has no door search, keeps
only the facet selects and a `?q=` still filters once on load. The query also writes into the OPEN
tab's own panel: on Datasets it filters the grid exactly as before; on Species and Measurements,
`door-search.js` renders up to 50 hits sorted by observations into `#door-species-results` /
`#door-measurements-results` (R1's `result_row.html` shape, built here in JS), hiding that tab's own
headline/counts/link (`#door-<key>-body`) while the box is non-empty and restoring it when cleared —
so typing on the Species tab is never a dead end. Both result panels stay in sync on every keystroke
regardless of which tab is showing, so switching tabs needs no re-render of its own. A shared link —
`/?q=sardine&tab=species` — lands with the box filled, the right tab selected (`tabs.js`'s own
`?tab=` restore) and the results already drawn.

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
the first screen's number, the realm door and the tab all fall back to the Explorer —
`…/explore/` for organisms, `…/explore/?var=temperature` for measurements — so a door always leads
somewhere true.

**Also checked** by `check_layout.py`, in both themes at 1470 and 375: the header reads exactly those
seven words and calcofi.org ↗; each submenu is closed until focused, opens on focus, closes on Escape, and every item
carries a count; every tabset has
exactly one selected tab and one drawn panel, and a card tabset's pill equals the cards in its panel;
the first screen's species and measurements numbers are links; the search returns a Species group for "sardine", a Measurements group for "nitrate" and a
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
| story | [`_data/news.yml`](_data/news.yml) | whoever made it: something the data show — a cruise's finding, a film made from the release | on push to `main` | its page under `/stories/` |
| tutorial | [`_data/news.yml`](_data/news.yml) | whoever gave it: a recorded walk-through, dated the day it was given, with its recording, slides, notes and scripts | on push to `main` | its page under `/tutorials/` |

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
                           + _data/{release_headings,release_anchors}.json + _data/zip_manifest.json
                           (the Download zips; ALL git-ignored: the site renders the release, never
                           copies it; an optional one that is missing collapses the thing it feeds
                           rather than being typed)
_plugins/datasets.rb       the record → /datasets/, /datasets/{key}/, {key}.json, {key}.jsonld,
                           /datasets/release/, /datasets/sitemap.xml, /datasets/search.json,
                           /data.json — and site.data.catalog for index.html
_plugins/downloads.rb      the record's `bundle` rows, else the zip manifest → what each Download
                           button and dialog offers (Downloads.offer; _test/downloads_test.rb)
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

### Calmer (issue #30): one list, the dense views one click away

Re-cut to the review's decisions (D1–D17, all as recommended); nothing was removed, it moved:

- **`/datasets/`** (`_layouts/datasets.html`) is `calm.css`'s catalog: the three catalogs as
  siblings, *Datasets*, one sentence, one line of counts, the ONE search over the three indexes
  (`_includes/one_search.html`, D10 B) — `assets/catalog.js` also filters this page's rows from
  `#door-q` — and a **Filter** button (`ui-filter`) that opens the six facets (opened on load when
  the URL carries one; `?cat=` from a dataset page's crumb lands filtered). Then **one list**, Biology
  then Environment (`realm-*`), one row per dataset: category glyph · name (category · provider) ·
  years · obs · licence. A row opens to its first sentence, what is in it (`el-taxa`/`el-variables`,
  `ui-years`, `el-contributes`, `el-release`) and its ways in (`way-*`). The category's description
  is the name's hover in the row and the ⓘ (`_includes/info.html`) in the opened row (D9 B). A row
  with zips has a **Download** control beside it (see *Download* below) — beside the `<details>`,
  in a `.dl-rowwrap`, never inside its `<summary>`.
- **The tiles are a view tab**: *List* (`view-list`, default) · *By category* (`view-grid`) is
  `_includes/catalog_grid.html` unchanged (`filters="off"`: the page draws the filter row itself);
  `?tab=grid` links to it. The holdings (`el-holding`), the reference frame and the release
  (`el-release`) are folds titled with their answers (D14), their bodies today's includes.
- **A dataset page** (`_layouts/dataset.html`) is one column under a head of four things: the
  category glyph as the mark and the short name, the full name, one facts line (key, provider,
  licence chip, DOI, release, stage), ONE sentence (the record's first sentence, then what CalCOFI
  holds — `Catalog#first_sentence` / `#holds_sentence`, cut and counted, never typed), the map
  beside it at its own aspect (`assets/coverage.js`), one line of numbers, and — where the dataset
  has zips — the yellow **Download** button under the numbers (see *Download* below). *What this is* folds the
  whole description and the people. **What is in it** stays open (`el-contents`): the years strip on
  the release's own axis under the map (D15, `Catalog#years_strip`), then one line each for the
  variables, taxa, life stages and contributes-to, each opening in place to all of them (the old
  Coverage band's lists). **Ways in** is one line (`Catalog#ways`, D12/D16). Then folds, each
  wearing its `el-*` glyph and titled with its answer: *Every endpoint · N* (the Access tabset,
  unchanged), *Cite* (`Catalog#cite_answer`), *Provenance* (a holding: *Status*; the source files
  moved in here), *Related*, *Open questions*, *Keywords*. No sub-nav (D17). A holding keeps *Where
  it lives today* open; a dataset with sampling events only says the Explorer has nothing to draw.
- `check_layout.py` asserts, on both: a height ceiling at 1470 with nothing open (`MAX_DS_H`),
  every fold and row closed on load, the list equal to the record's datasets, and no multi-column
  block under a dataset page's head. The filter, variables, ERDDAP-once (inside *Every endpoint*)
  and URL assertions keep their intent; the hero's "two columns end together" is gone with the hero.
  Heights at 1280 with nothing open: `/datasets/` 3,523 → ~2,220 px; `calcofi_bottle` 4,165 →
  ~2,020; `swfsc_ichthyo` 5,096 → ~2,080; `calcofi_prodo` 3,029 → ~1,580.

The sections below are the record of the rules the grid and the Access model were built on.

**Browse datasets, a finder with a preview (PR #45, 2026-11-14; reconciled 2026-11-17).** `/datasets/`
is now `assets/browse.{js,css}` over `site.data.browse` (`_plugins/browse.rb`): a navy band with one
search (names, providers, categories and the species and measurements inside each dataset), a type
filter and a sort; the three catalogs as folder tabs (`_includes/catalog_crumb.html`); Years covered as a
fold; then List and By category, each row a link to the dataset's page, and beside the list a sticky
preview of the chosen row (its station map from `/datasets/browse.json`, what is in it, its years, View
on map, Download, Full details). The preview's Download is the dataset page's dialog (`#download`),
named by the default zip. `/species/` and `/measurements/` are the same finder (`assets/finder.{js,css}`,
`_plugins/finder.rb` writing `/species/finder.json` and `/measurements/finder.json`); their previews
link each dataset's page and download nothing themselves. The folds under the list (holdings, reference
rows, the release) are unchanged.

### Tiles by category, and words that come from the record (PR 57, 2026-11-23)

`/datasets/` opens on **category tiles** (Betty 2026-11-18): Environment then Biology, a tile per group of the
record's `browse` block (`_plugins/dataset_extras.rb` `tiles`; a dataset no group claims gets a tile of its own
record category, so a new dataset is never lost). A tile opens its category in place (`?cat=<slug>`, a step in
the history, so Back returns to the tiles; main's `#cat-…` anchors and `?cat=<record category>` still open the
right tile). List is the second view; typing a query, a "Try" word or a type switches to it, because only the
List is filtered.

- **Where the words live.** The plain name, collection, analysis, method picture, status and the tiles were typed
  in `_data/dataset_extras.yml` for six days. They are now the release record's (`datasets.json` schema 1.2: each
  dataset's `display`, top-level `browse`, `attribution.associated_parties`), authored in the workflows repo.
  `_test/dataset_extras_test.rb` fails the build if the file, or a read of `site.data["dataset_extras"]`, returns.
- **A dataset in an open category is four slots** (`_includes/browse_cat_row.html`): the method picture and its
  label · name and provider · the plain name · years and ongoing/ended. Collection, analysis and the description
  are the dataset page's. "Open dataset" is said once, in the preview, which keeps "and 38 more".
- **One column, one head.** The body is `.calm-page`, the column the search band and the other two catalogs use.
  The Datasets · Species · Measurements row (`_includes/catalog_crumb.html`) is on all three catalogs, with this
  page's By category / List switch on its line; the header keeps the tagline on every page. "The release" fold is
  closed on load like every other fold.
- **The search is a combobox** whose listbox (`#bd-dd-list`) holds only options, each with an id; the input's
  `aria-activedescendant` names the one the arrow keys are on.

### The grid: an emphasis ladder, packed, with the reference frame in its own band

The catalog's layout follows four rules, and `scripts/check_layout.py` is what keeps them true
(plan `2026-09-05 CalCOFI.io UI refresh …` § D-1 to D-3, D-10):

1. **Emphasis is a ladder.** A dataset in the release (rung 1) is a 4-column grid — name · provider
   · (years · sparkline · n obs · a variables/taxa expander) · licence — `--accent` at 700 with its
   own colour as a 9 px dot; the format phrase that used to sit in the meta is gone (round 2 D1,
   WS-R4: the Format filter and the dataset page keep it). The expander (`.ds-vars`, D3) is a closed
   `<details>` reading "*n* variables" (env) or "*n* taxa" (bio, `<i>`talic scientific names,
   commonest-observed first) — the names stay in the DOM either way, so the door search still
   matches them, and a hit inside one opens it (`assets/catalog.js`, the same one-way rule as the
   holdings block below). The licence is `_includes/licence_chip.html` (D5) — one glyph, one colour,
   only the shade and text vary; the dataset head wears the same chip. A dataset homed elsewhere that
   *contributes* variables here (rung 2) is `--fg` at 400 with a hollow dot and its variables
   collapsed behind "n variables ▸". A **holding** — something CalCOFI has that is not in the
   database — is `--muted` at 400 on one line with quiet chips. A reference row is `--fg` at 400 with
   its count in mono.
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

### A dataset page: the map, and nothing below the head is two columns

`/datasets/{key}/` followed D-4 to D-7 of the same plan; issue #30 (above) re-cut its layout:

1. **The head is the only two-column region**, and its second column is a map of where the
   dataset was actually sampled — since issue #30 at the drawing's own aspect, as `calm.css`'s head
   picture, rather than stretched to the title block. The first cut put a 418 px column beside a
   1,346 px one and left **928 px of blank page** under the abstract; two columns whose contents
   differ that much cannot be made to end together, so everything below the head is one column.
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
3. **Access is a tabset, one tab per group (round 2 S2, WS-R4)**, inside the *Every endpoint* fold since issue #30. Each row is two lines: label ·
   chips · meta · copy, and no URL line (2026-09-06): the label is the link, the chips and
   identifier say which endpoint it is, and the copy button beside every row copies the address.
   *Download as a zip* (the Download button's zips, where the dataset has them) leads *Get the
   data*; *Tables from the release* is a table (table · holds · rows · size · since · sha256); *Code*
   follows it, so "DuckDB, anywhere" reads one of the objects just listed and explains the
   content-hashed path; ERDDAP is listed **once**, as a matrix of id × (subset form · info · graph —
   no netCDF, the CF file is the netCDF) with the grain glossary under it. The matrix's whole-table
   CSV and JSON links were dropped on 2026-11-16: ERDDAP answers a request with no constraint 403,
   so they promised a file that never came; ERDDAP's own CSV and JSON are taken from its subset form. The tab row IS
   the group's name (`_plugins/datasets.rb Catalog#access_groups` / `#holding_access`, each group's
   `g["n"]` its pill — the same sum `page.n_endpoints` totals for the sub-nav's "Access *n*"), so a
   group's own heading is not repeated inside its panel (D3, "say it once"); the pair left/right
   wrapper that used to sit *Metadata records* beside *Archives & portals* is gone — a tab panel is
   one group, `assets/tabs.js`'s ordinary contract (its own `id="ts-ds-access"`, distinct from the
   front door's product tabsets). Explore rows and product cards carry each app's **lenses**
   (products.yml `lenses:`) as suffix icons, with a key under the landing page's Explore heading.
4. **The generator checks its own output.** `Catalog#unlisted_endpoints` compares every URL in the
   record's `distributions[]` and `registrations[]` against the rows actually rendered and warns at
   build on any that reach no Access row. It caught two legacy ERDDAP ids that carry no `format`
   key and had silently vanished from the CTD casts' page.
5. **`_test/derive_id_test.rb`** (`ruby _test/derive_id_test.rb`, also run by `scripts/build.sh`)
   pins `_plugins/derive_id.rb` — the rule that reads a portal's own identifier off its URL — to
   every URL shape in the record. calcofi4db 4.5.0 derives the same ids, so the two have one list
   to agree on.

**The dataset page, redesigned (PR #45, 2026-11-15; reconciled 2026-11-17).** A dataset (not a holding,
which keeps the page above) is drawn by `_includes/dataset_page.html` from `page.dp`
(`_plugins/dataset_page.rb`): a navy band with the name and five or six numbers; on the left About (the
record's first sentence, the rest one click away), When it was sampled (records per year on the release's
axis, and by month) and What's in it (every taxon, most recorded first, with a search, or every
measurement by category), each row with a CSV button for just that one; on the right, sticky, the map
with View on map and See stations, **Get the data** and **Cite this dataset**; then About the data
(creators, credit, where else it is archived). Reconciled with `main`: the big button in Get the data
is the Download link and dialog (`#dl-btn`, `#dl-dialog`, `/datasets/{key}/#download`,
`_includes/download_dialog.html`), and the folds the redesign had dropped are back, closed, under About
the data (`_includes/dataset_folds.html`, shared with the holding page): Every endpoint (`#access`),
Provenance, Related, Open questions for the provider, Keywords. Cite is the card, so the Cite fold is
skipped there.

### The dataset page after PR 57 (2026-11-23)

Betty's "Full details page" (2026-11-18), as built after its review. `_includes/dataset_page.html`,
`assets/dataset-page.{css,js}`, `_plugins/dataset_page.rb`.

- **Hero.** The brand's wave band (`cc-wave cc-wave-own`, its own svg edge), about 315 px at 1470: a back link that
  names its category, the name with ongoing/ended beside it, the plain name, the record's first sentence, the
  station map with "View on map" on it, and every number along the foot (a biology dataset shows its taxa and its
  measurement types). Neither checker exempts the page from the wave.
- **Under it**: Collection and Analysis as two lines; When it was sampled; then ONE tabset, **Species ·
  Measurements · Fields** (`#ts-dp-lists`, the tabs idiom of `assets/tabs.js`; it is the page's one
  `data-url-tab` tabset, so `?tab=fields` is a link, and `#taxa`, `#variables`, `#fields` select their tab). Each
  list shows eight rows and "Show all N" / "Show fewer". Without JavaScript the three lists follow one another, whole.
- **Height.** `MAX_DS_H["dataset"]` is 2,650 px (was 2,200): the page holds three lists where the old one held one.
  The 20 pages measure 2,075 to 2,627 px at 1470 with nothing opened (2026-11-23). The reason is written beside the number in
  `scripts/check_layout.py`; it is not room for a second open list.
- **Measurements** lists only the types the release holds a value for (`DatasetPage.table_rows`,
  `counted_types`); the registry gives the words. **Fields** leaves out the species columns for a dataset with no
  taxa (`DatasetExtras.fields`, `bio: false`) and takes a column's words from the record's `display.column_notes`.
- **One Download** (the side card's `#dl-btn`) and **one link to the original**. `#download` is the no-JavaScript
  download options and nothing else. "Combined from N source tables" is said only where the record marks two or
  more NOAA ERDDAP tables `kind: source` (`DatasetExtras.combined?`); `mirror` tables are in a closed fold,
  "Also on NOAA ERDDAP". Under "Just part of it?": Query Builder, Dataset Finder (by station), ERDDAP, In code.
- **Month tiles**: each tile's words take the ink that reads on its shade, per theme (`DatasetPage.tile_ink`;
  `_test/dataset_page_test.rb` holds every shade to 4.5:1 against `brand/v2/theme.css`).
- **Phone** (640 px and under): a table row stacks, the name and its button first, then units, description, years.

### Download: one button, plain formats, the citation in the file

Measured on 2026-11-16: no route gave a newcomer a file Excel opens with its citation and licence.
The dataset page's only downloads were three folds down (Every endpoint › Get the data: Parquet, CF
netCDF, ERDDAP "CSV" links that answered 403), and /datasets/ had none. Now:

```
_data/zip_manifest.json    scripts/fetch_release.sh, from {calcofi-db}/publish/zip/manifest.json
                           (workflows publish_to-zip.qmd, schema 1.0): per dataset, one zip per format
                           — csv (every dataset) · xlsx (only where every table fits an Excel sheet)
                           · parquet — each with README.md, CITATION.md/.bib, LICENSE.txt, columns.csv;
                           a format not written carries its reason in plain words
_plugins/downloads.rb      Downloads.offer: the record's own `bundle` distributions first, else the
                           manifest; nil for a holding or a dataset with nothing written. Every word
                           about a FORMAT is written there once; every number and reason is read
_includes/download_options.html   the options, drawn in the dialog and again in a <noscript> section
assets/download.js         the dialog (the button, #download on the URL, Esc, Close, the backdrop),
                           and one GA4 `dataset_download` event per zip link
assets/download.css        the button, the dialog and the rows' control (loaded from default.html)
```

- **The dataset page**: a yellow **DOWNLOAD CSV · 425 KB** (the default zip's own size) under the head's numbers — the space the
  map beside it leaves empty, so the head is no taller — above the 1280 × 800 fold. It opens a native
  `<dialog>`: **CSV** first (one click downloads it, and it has the focus), **Excel**, or the
  manifest's own reason it is not offered; each with one plain line on what the format is for, its
  zipped size and what is inside; *Only want part of it?* → the Explorer opened on the dataset;
  *Other formats* — the Parquet zip, ERDDAP's subset form, the CF netCDF, *Every endpoint* (which
  opens that fold); the **licence** from the record by the licence chip's rule (unstated: "No
  licence has been established…", never open terms; custom: a link to the provider's terms); and
  *register your use*, encouraged, never required (`_config.yml register_use_url`). Without
  JavaScript the button is a plain link to the CSV zip and the dialog's options are a `<noscript>`
  section (`#download`).
- **/datasets/** and the front door's Find panel: a compact **Download** control per dataset row
  (an icon in Find's list of names, `_includes/dl_rowlink.html` in a third column of its subgrid,
  and in the `catalog_grid.html` rows of the Datasets tab and *By category*), linking
  `/datasets/{key}/#download`, which opens the dialog on arrival. A holding has none. Front door →
  a CSV zip is three clicks (Find · the row's Download · CSV). Before, no route reached a CSV: the
  nearest file was one table's Parquet object, three clicks in and below the fold (Find · the row ·
  *Parquet* in Ways in), and the ERDDAP "CSV", five clicks in, answered 403.
- **Analytics**: `dataset_download` {dataset_key, format, file_name, link_url} through the layout's
  gtag, skipped under `navigator.webdriver` as the layout's config is. Not `file_download`: GA4's
  enhanced measurement already sends that for a `.zip` link, and the same name twice would double
  every count.
- **Before the first upload** there is no manifest: `fetch_release.sh` says so in one NOTE, and no
  button, row control or *Download as a zip* block renders anywhere. To build against zips on disk,
  `ZIP_MANIFEST_URL` takes a URL, a `file://` URL or a plain path:

  ```bash
  ZIP_MANIFEST_URL=~/_big/calcofi/publish/zip/manifest.json scripts/build.sh
  ```

- **The zips are content-addressed (manifest schema 1.1).** A URL carries a hash directory
  (`…/zip/swfsc_ichthyo/3872789ed24411383f47ae8a/calcofi_swfsc_ichthyo_v2026.11.14_csv.zip`); the
  version in a file name is `since`, the release where that content first appeared; each dataset
  carries `since`, `checked_version`, `content_hash` and `data_hash`, and the history is the chain
  of per-release manifests. So nothing here parses or builds a file name or URL: each bundle's
  `url` is used exactly as given, the suggested download name is its last path segment, unknown
  fields are ignored, and any `schema_version` of 1 or higher is read. The dialog says "Verified
  against release `checked_version`" and, only when `since` is earlier, "; the data are unchanged
  since `since`" — true however many releases pass. `_test/fixtures/zip_manifest_1_1.json` is that
  shape, beside the 1.0 `zip_manifest.json`.
- **Checked** by `_test/downloads_test.rb` (all three formats; Excel not written, with its reason;
  the licence kinds; a holding; the manifest absent; the record's bundles winning; the
  1.1 content-addressed shape) and
  `check_layout.py`'s `download` block: exactly one button in a dataset page's head, ending above
  the 1280 × 800 fold at 1280 and wider and linking the CSV zip; its dialog closed on load and CSV
  first; none on a holding or without zips; one row control per dataset with zips on /datasets/,
  none in a `<summary>` (`download_offers`, pinned by `_test/check_layout_downloads_test.py`).

**Fallbacks awaiting the record.** Each is marked `# until the record carries …` in
`_plugins/datasets.rb` and is deleted when the release that carries the field renders (plan D-9):
`GRAIN_FALLBACK` (an ERDDAP grain's meaning), `PORTAL_NAMES` + `PORTAL_ABOUT` (a portal's name and
one-liner), the EML probe (`url_ok?` on the release's `eml/{key}.xml` — until the record carries a
`format: eml` distribution), the DwC-A and EDI package probes (until the record carries them as
`bundle` distributions — v2026.11.14 carries none), the zip manifest (until the record carries the
csv/xlsx/parquet zips as `bundle` distributions; `Downloads.offer` already prefers them),
`_plugins/derive_id.rb` (a registration's
identifier), and `STAGE_MEANING`, which is site-side text by nature — the stage vocabulary is
`dataset_status.csv`'s, not any one dataset's.

**Two download files, two jobs (2026-11-17).** PR #45 and `main` each added `assets/download.js` and
`download.css` on the same days, for different features. `main`'s keep the names (the dialog above).
Betty's form is `assets/download-form.js` / `download-form.css` (global `CCDownload`): it opens from
the **CSV** button beside one species or one measurement on a dataset page and offers *Just that one*,
which opens the Query Builder with it picked and starts the CSV
(`calcofi.io/query/?pick=bio:<dataset>:<taxon>` or `env:<dataset>:<measurement>`, `&download=1`), or
*The whole dataset*, which is the release zip, with a link to the dialog for the other formats. The form
first built a whole-dataset CSV in the browser from the release Parquet (a vendored reader, files up to
30 MB) or sent the reader to ERDDAP; the zip replaced both, so nothing whole-dataset is assembled in the
browser. A measurement the record marks `grain: "sample"` (one value per cast) has no CSV button, since
the Query Builder does not read `sample_measurement` (`DatasetPage.pickable?`,
`_test/dataset_page_test.rb`).

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
everything. (The tree and the matrix used to share one row, with ⤢ / ⤡ to widen either and
`?panes=` in the URL; since issue #30 each is its own view tab at the full width, so the panes and
their pills are gone.)

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
inline record's and its h1 carries no digit, the class list is the record's classes by observations,
the matrix has exactly rows × datasets cells, a search's hits fill the flat Matches list, every
`.sp-url` is one line and actually elided, and on a taxon page the *Observed in* rows are the
record's `datasets[]` with its counts and one drawn strip each, the lineage is a chain of species
links, and the Explorer link opens prefilled. Since issue #30 it also asserts nothing is open on load
(no class row, one view panel, every fold closed), every fold's title carries an answer, no sub-nav,
and a height ceiling at 1470 with nothing open (the content, header to last fold: index ≤ 2,220 px,
a taxon page ≤ 1,500 px — the mockups' 1,775 and ~1,200 plus a quarter).

### Issue #30 · calmer (what moved where)

Both pages are built from `assets/calm.css`; nothing was removed, it moved (D1–D17, all A unless noted).

- **`/species/`** — the catalog head (the three siblings, *Species*, one sentence with the old lede in
  its ⓘ, the five counts as one quiet line, and the ONE search, `one_search.html`, D10 B). Then ONE
  list (D7 A): the 22 classes with their PhyloPic silhouettes, most observed first, each a
  `calm-item` that opens to its six most-observed taxa as R1 result rows, plus *Open*, *Explorer* and
  *In the tree*. The tree (with its rank folds and *all ranks*), the matrix and the icicle are view
  tabs (`?tab=tree|matrix|hierarchy`), each today's panel unchanged; the icicle is drawn the first
  time its tab is chosen. `species.js` listens to `#door-q`: the hits fill `#sp-matches` above the
  views, the class list keeps the classes holding one, and the tree folds to them (`?q=`).
- **A taxon page** — one column, no sub-nav (D17). The head is the silhouette as the mark, the name
  (italic for genus and below), the common name, a facts line (rank · status · ids · key · groups),
  the sentence, ONE picture (D11: the photo; the silhouette where there is none) with its credit as the
  caption, and one line of numbers that now carries the max length (`el-size`). *Observed in* stays
  open, each dataset a row with its own years strip. The ways are one line (Explorer · db-query ·
  ERDDAP | R · Python · JSON, D12); the code and URLs are the first fold, with `ways_tabs.html`
  inside. Everything else is a fold titled with its answer (D14, `page.fold` from
  `Taxa#folds`): *Code and endpoints*, *How big is it · 39.5 cm max · egg 1.34–2.05 mm* (the glance,
  ladder, beside figure, plate), *Under it · 38 taxa · … most observed*, *Life stages*, *Lineage ·
  12 ranks · Biota to Sardinops* (the crumb shows the last three; its "N ranks" opens this fold),
  *Credits*, *Elsewhere* (Wikidata, iNaturalist, FishBase … from the sidecar's links) and *Cite*.

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
scripts/media_due.py             which keys of the promoted release neither sidecar has (exit 3
                                 = due); the release's deploy (workflows/scripts/
                                 deploy_consumers.sh, step 7) runs it and, only when due, the
                                 fetch → check → --upload → refresh.yml above
.github/workflows/species-media.yml   weekly, Sundays 09:00 UTC — DISABLED (`if: false`) until a
                                 GCP_SA_KEY secret exists; the release deploy runs it instead
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
_includes/species_face.html   the mark, the picture, the sentence, the glance (server-side: content)
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

**Round 2 (plan "faces round 2" § P1–P3, I1, I2, D6, D9; WS-R5).** The sentence's underline + legend
retired in favour of R1's source badges (`.cc-src.cc-src-{wp,rec,nerc}`) — one small badge after each
part, its `title` the article + licence + revision (and "Wikipedia has only the genus" where the
sidecar's `about` says so), the release version, or the authority + id, so nothing is said twice. Each
picture gets exactly one `.sp-credit` line — `Photo · {by} · {licence, linked} · {via}` and
`Silhouette · {by} · {licence} · PhyloPic, drawn from {shown}`, the stand-in caption folded into it —
with a photo source's long "(c) … uploaded by …" string moved to the line's `title` rather than printed
(`_plugins/species.rb`'s `short_by()`). The strip's and the ladder's caption paragraphs are now an ⓘ on
their heading; *Note from the crosswalk* is gone as a section and its text is an ⓘ after the `key` id
instead. *Ways in* takes R1's `ways_tabs.html` include — *This page as data* is now the `json` tab
rather than a section of its own, and its own paragraph is the heading's ⓘ. Both index pages (`/species/`,
`/measurements/`) trade a numbers-sentence h1 for a name ("Every organism CalCOFI has counted" /
"Everything measured in the water and the air above it"); the counts stay in the stat band, the only
place they are typed, and the definitions + machine-readable line move into an ⓘ at the lede's end. On
`/species/`, a search also renders a flat **Matches** list (`#sp-matches`, R1's `.cc-result` row shape,
built client-side in `assets/species.js`) above the tree — up to 50 of the same `hits` the tree
highlighting already computes, sorted by observations — so which taxa matched is never buried among
their folded-open ancestors; the tree keeps its own fold and highlight below it.

## The measurements catalog (`/measurements/`, `/measurements/{key}/`)

### Calmer (issue #30, 2026-10)

Re-cut on `assets/calm.css` by the review's decisions; **nothing was removed, it moved**:

- **`/measurements/`** — one column: the catalog head (Datasets · Species · Measurements, the name,
  one sentence with the counting ⓘ, one line of numbers, the ONE search over the three indexes,
  D10 B). The default view is a **list** (D8 A), rendered by Liquid from `site.data.measurements.list`
  (`catalog_groups` in `_plugins/measurements.rb`): the keys unified across datasets on top, then the
  five categories as rows that open in place, **collapsed**, each to its keys (`?cat=` opens one). The
  old stats band went into the numbers line and the ⓘ; the chips into the categories. The timeline
  table and the category × dataset matrix (with the datasets list) are view tabs, unchanged, and
  `#door-q` filters both the list and the timeline (`row_hay` = the timeline's haystack).
- **Short label** (D13 A): `short_label` where the record has one, else the heading cut at its first
  comma or colon outside parentheses (`MeasurementsRecord.cut_label`, tested in
  `_test/measurements_short_label_test.rb`). It is the catalog row's name, the h1, the crumb and the
  one search's name; the full label is the sub line under it.
- **A measurement page** — one column. The head: category glyph + short label, the full label, the
  ids, the face's ONE sentence, one line of numbers, and ONE picture: the face's What column (the
  molecule, the ion bar, the scale ramp, the Beaufort strip or the organism) with NERC's definition
  as its caption. **Measured in** stays open, each series row with its own years strip. The ways in
  are one line of links; every endpoint and the code are the *Every way in* fold (D12 A,
  `ways_tabs.html` inside). Everything else is a fold, closed on load and titled with its answer
  (D14 A): The structure · How it is measured (the How column + the methods tabset) · Why it matters
  (the spark, the EOV card, CalCOFI's words, the other ways to say why) · The record's own history
  (the anomaly) · Units and range (range & quality + the familiar scale) · By depth · by month ·
  Related measurements · Cite. A figure in a fold is drawn when the fold opens, at its width.
- `check_layout.py` reads the folds closed on load, then opens them and checks every face rule as
  before; heights at 1470 px with nothing open are capped at 1,625 px (catalog) and 1,850 px (a page).

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

**Round 2, the body (plan 2026-09-15 § D1–D3, D8, WS-R3).** The "Heads-up" warning paragraph is
gone: the stats band's own `flagged` stat carries the count (0 with no ⓘ where nothing is flagged;
otherwise the same words behind an ⓘ, `_includes/info.html`). *What it is* and *Where in the water
column* are retired — the NERC definition and the vocabulary chain moved to the face's own What
column (round 2's face, a sibling workstream), and *By depth* already carried the same bands as
counts; only the big structure cards survive, retitled *The structure*. *How it is measured* is one
`.tabset` tab per series (`ways_rows()`'s sibling in spirit, `f.how`), so a two-dataset measurement
reads as two acts rather than one card repeating chips *Measured in* already shows; a single-series
page draws no tab row. **Range & quality** leads with a four-chip line — bounds, observed, flagged,
baseline, each hovering to the number(s) behind it (`quality_rows()`'s own `chips`, ` _plugins/
measurements.rb`) — with the full definition list still there under a collapsed *details*. **Ways
in** folds *This page as data* into the shared code-route tabset as its `json` panel
(`_includes/ways_tabs.html`, `ways_rows()`'s `group` per way: app buttons for Explorer/db-query,
then one tabset over erddap · parquet · r · python · json); every remaining figure caption
(the years strip, *By depth*, *By month*, *Related measurements*) moved from a trailing `.mm-note`
paragraph into an ⓘ on the heading it captions, text unchanged. Measured on temperature: 4,968 →
3,729 px at 1280 px light (round-2-after-R1 baseline, before any face-row changes land).

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

**Round 2 — drawn to a scale (WS-R2).** The plan `2026-09-15 faces round 2 …` § D4 gave every face
figure a scale, labels on it and a hover. The What column of a **scale** kind is now the variable's
own cmocean ramp over its **declared bounds** (the observed minimum to maximum, said so in a
`title`, where the record declares none), with the record's 5th–95th as an open frame in the page's
ink and `metadata/measurement_scale.csv`'s marks labelled short on it and in full on hover — the
ramp is never the only encoding of either. `RAMP_OF` in `assets/measurements.js` is the Explorer's
`defaultRamp()` **copied verbatim** from `../explore/src/ramps.ts` (cited with its commit); pH keeps
its acid→base strip, wind its Beaufort cells (shaded on its own ramp, the median and the 95th
outlined), a composition its ion bar in the row and its molecules under *What*, and an unmatched
variable the plain strip. The **spark** is 100 px on its own band's maximum with `+x / 0 / −x` on a
left axis, four year ticks, the trend and a per-year hover, and its line ends *drawn to ±x*; the
**history** defaults to **own scale per band** with the ± written beside each band and its count,
a radio pair for one shared scale (not in the URL), a per-bar hover and a one-line `.cc-legend1` —
its four-line mono legend, its computation and the climatology-depth note now live in the
heading's ⓘ. Every figure reads on ONE `.mmf-tip` div on the body, and every hover is also the
mark's `<title>`. The **sentence** dropped its NERC clause (the What column has it) and its
underline legend for a `.cc-src` badge per part; the Wikipedia lead left *Borrowed context* to
become one of the *other ways to say why*. Two bugs went with it: `how_rows()` read
`calcofi_org`/`page` for the record's `calcofi_org_url`/`source`, so **no page linked calcofi.org**
(81 of 89 now do), and the anomaly credit read `oni.latest[3]`, printing *"JJA 2026 is undefined"*
on every page with an anomaly.

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
ruby _test/downloads_test.rb                     # what the Download button and dialog offer
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

## Brand: theme, header, favicon (`brand/v2/`, `brand/v3/`)

[`brand/v2/`](brand/v2/) is the contract every CalCOFI product wears — the SIO look (UCSD palette,
**light by default**, Source Sans 3 + Teko, the horizontal lockup, two scales via `data-cc-scale`),
the `.cc-header` chrome (lockup far-left linking to calcofi.io, sun/moon toggle), `theme.js`
(`?theme=dark|light` → `cc_theme` cookie on `.calcofi.io`, persisted only on an explicit choice →
light) and the favicon set — served at `https://calcofi.io/brand/v2/`. In force since the flip on
2026-09-04 (`_layouts/default.html`, `index.html`, `style.css`, `_includes/product_card.html`). Read
[`brand/v2/README.md`](brand/v2/README.md) before touching a product's chrome. It is frozen.

[`brand/v3/`](brand/v3/) (2026-11-17) is v2 with **one header for every product**: the same words in
sentence case from `_data/nav.yml`, a word that may open a menu, the menu button under 1100 px, and the
wave under the bar. It adds `header.css`, `header.js`, `nav.json` and a `theme.js` that reports version 3;
the tokens, fonts, icons and logos are still v2's files. This site, the Explorer and the Query Builder
wear it; every other product keeps v2 until it changes its head block.
[`brand/v3/README.md`](brand/v3/README.md) has the contract, who wears what, the order of deployment
(`brand/v3/` has to be live before a product that loads it) and the alternative that was not built.
**To change a word of the header, edit `_data/nav.yml`**, nowhere else; `_test/nav_test.rb` pins the list.
Where a menu's panel sits is the brand's business too (`header.css`, and `header.js` keeps every panel inside the
window): the specimen page `/brand/v3/` draws the header as a product does and is one of the pages
`scripts/check_layout.py --nav` opens.

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

## Round 2 idioms

Six shared components (plan "faces round 2", § Decisions D1, D2, D5, D6) that a species, a
measurement or a dataset page all reuse rather than each spelling out its own version:

- **`_includes/info.html` + `assets/info.js`** — the pill + ⓘ idiom (D1): `<details class="cc-info">`
  holding a popover (`.cc-pop`, a bottom sheet under 640 px); `info.js` keeps one open at a time,
  closes on an outside click or Escape. `defer`-loaded on every page from `_layouts/default.html`.
- **`assets/tabs.js`'s `data-url-tab` gate (D2)** — the `?tab=` URL memory belongs to ONE tabset per
  page, the one carrying `data-url-tab` (today: the front door's). Every other tabset (the ways-in
  tabset, a future methods tabset) switches locally and never touches the URL, on write **or**
  restore.
- **`_includes/ways_tabs.html` (D2)** — the ways-in tabset: app ways (Explorer, db-query) as
  buttons, then one shared tabset over the code routes (erddap · parquet · r · python · json, one
  panel per group present, no tab row for a single group). Reads `page.ways[].group` where a
  plugin sets it, else derives it from the way's `name`.
- **`_includes/licence_chip.html` (D5, Ben's 2026-09-15 revision)** — one glyph (`#i-licence`), one
  colour, on every chip; only the text and the shade vary (`unstated` dimmed, dashed). Never prints
  a raw license id. Its size param is `chip_size`, not `size` — found while WS-R4 placed it on 16
  rows + the dataset head: Liquid's dot lookup special-cases the literal key `size` on anything
  Hash-like, so `include.size` always returned the include tag's own param COUNT (every chip grew a
  bogus `cc-chip-lic-3` class), never a param actually named `size`.
- **`_includes/icons_round2.html`** — the round 2 sprite (`#i-licence`, `#i-copy`), included once at
  the top of `<body>`; `brand/v2/icons.css` stays frozen.
- **`_includes/result_row.html` (D9)** — the one search-result row shape a Species/Measurements
  search panel and `/species/`'s Matches list both render (`{n, c, it, m, u}`, the same shape
  `assets/door-search.js`'s `rowsFrom()` already normalises a hit to).
- **The source badges + legend (D6)** — `.cc-src.cc-src-{nerc,rec,why,wp}` (a superscript letter
  after a sentence part, `title` the source) and `.cc-legend1` (one line of swatches), replacing a
  page's own underline-and-legend idiom.

All six render once on `_test/round2_idioms.html` (`sitemap: false`, `robots: noindex`; whitelisted
in `_config.yml`'s `include:` since `_test/` is otherwise dropped like every `_`-prefixed path) —
`scripts/check_layout.py --url http://localhost:4000/_test/round2_idioms.html` and
`scripts/check_brand.py --url` the same run against it.
