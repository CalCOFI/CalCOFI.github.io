#!/usr/bin/env python3
"""Check the catalog's LAYOUT against the rules the UI refresh set (plan D-10), the way
check_brand.py checks the theme: a real browser, both themes, two widths, exit 1 on any failure.

    scripts/check_layout.py                                  # the four default paths on localhost:4000
    scripts/check_layout.py --url http://localhost:4000/datasets/
    scripts/check_layout.py --base https://calcofi.io        # the live site
    scripts/check_layout.py --widths 1470 --themes light     # narrow a run down

Every assertion below is a problem that was MEASURED on the live site on 2026-09-05, so each one
can only pass by the layout actually being fixed:

  grid       no tile drawn more than 1.25 x its natural height. The grid was 4,910 px of which
             2,838 px was stretch: a CSS grid row is as tall as its tallest tile, so a one-dataset
             tile beside the 25-row reference tile was drawn nine times its own height.
  ladder     every holding row's name computes to --muted, and NOTHING in a holding row computes
             to --warn. Holdings used to be --fg at 700 wearing the page's only yellow chip, so
             the 17 things NOT in the database read louder than the 16 that are.
  scroll     no horizontal scroll at either width, either theme.
  hero       (dataset pages) the head band's two columns end within 120 px of each other, and no
             two-column region sits between the head and Cite. The CTD page's main column was
             418 px beside a 1,346 px sidebar — 928 px of blank page.
  filter     (the catalog) choosing a category actually hides the other tiles and rows. `el.hidden`
             is a UA rule, so `.cc-card { display: flex }` beat it and the filter hid nothing —
             invisible until the grid packed, then the "hidden" tiles overlapped everything.
  url        (dataset pages) no .ds-url is taller than one line at 375 px. A URL in a right-hand
             table column wrapped to five lines on a phone.
  erddap     (dataset pages) each ERDDAP dataset id's tabledap page appears exactly once. It was
             listed twice: once under Download for its formats, once under Services for its page.
  species    (/species/ and one taxon page, plan 2026-09-09 § S3) the index's five counts equal the
             inline record's; the matrix has exactly (rows x datasets) cells and its pane is not
             drawn taller than its own content; the tree pane is EXACTLY the matrix pane's height
             (the tree scrolls inside it, so no unbounded text sits beside a fixed-height figure);
             every .sp-url is one line and elided from the middle rather than wrapped; on a taxon
             page the "Observed in" rows are the record's datasets[] with its counts, the lineage
             is a chain of links ending in the taxon's parent, and the Explorer link opens
             prefilled on the taxon key.
  faces      (a taxon page, plan 2026-09-11 § D1–D5, D9) the silhouette is a labelled role="img"
             with real pixels; the photo has alt text, loading="lazy" and the radial mask on its
             FRAME; the glance draws two bars or says "not on record" — never a blank slot; the
             sentence's marked parts and its legend agree; every asset shown has a credit line; the
             ladder draws exactly the payload's marks and the six references of size_reference.csv
             with NO two labels overlapping (bounding boxes read from the DOM); the plate is drawn
             exactly where the payload has one; and the stat row says "records", not
             "observations", until the record carries n_present (§ D9 — 75.5 % of the CUFES rows
             and 85.0 % of the phytoplankton rows are zeros, so a row is not an organism).
  measurements (/measurements/ and one measurement page, plan 2026-09-10 § D5, D6) the timeline
             draws one row per measurement and one bar per series of the page's OWN inline record
             (79 and 84 on v2026.09.06), grouped into its categories; the matrix is categories ×
             datasets with every cell drawn and the counts summing to the series; every timeline bar
             has its dataset NAMED in the row (identity is never colour alone); the timeline is
             wider than a phone on purpose, so its own container scrolls and the page does not; the
             chips carry the record's counts and one is pressed; the search finds "nitrate",
             "NTRAZZXX", "µmol/kg" and "METS". On a measurement page the years strip is DRAWN
             (`.mm-drawn`, the `[viewBox]` trap again) with one labelled row per series and one cell
             per year the record counts, the depth bars are the record's bands × its series with
             every end label inside its column, the month strip is 12 cells per series, and each
             `.mm-url` is one line elided from the middle.

  front door (/, plan 2026-09-07 § D-8) the hero's SVG is drawn <= 62 vh at 1470 and the copy's
             text does not overlap the ship's bounding box; no .tile is drawn > 1.25 x its natural
             height; the six numbers on the band (years · cruises · stations · species · organism
             obs. · measurements) equal the inline #reach record's, and measurements + organism
             observations never exceed the release's own row count; the years strip has
             exactly datasets.length rows; the map has exactly stations.length marks; nothing on the
             first screen computes to --warn except the one CTA; every pin href answers 200/206 to
             a ranged GET (the way build_workflows_index.R probes; checked once, not per theme).

Lighthouse is NOT run here (it needs its own Chrome and ~30 s a page); README says how, and
.github/workflows/check-brand.yml runs this script weekly and on a pull request.

Needs shot-scraper (`pipx install shot-scraper && shot-scraper install`).
"""
import argparse, json, subprocess, sys

DEFAULT_PATHS = [
    "/",                             # the front door: the section, the numbers, the bento (plan 2026-09-07)
    "/datasets/",
    "/datasets/calcofi_ctd-cast/",   # the big one: 3 ERDDAP ids, 33 variables, a long abstract
    "/datasets/swfsc_ichthyo/",      # 29 distributions, 6 registrations, a bbox beyond the frame
    "/datasets/calcofi_prodo/",      # a holding: no map, no Access-from-the-release, a long name
    "/species/",                     # the species catalog: search + tree, the matrix, the icicle
    "/species/?panes=matrix",        # the matrix expanded: the tree folds into a vertical pill, never gone
    "/species/?panes=matrix&q=sardine",  # …and a search with a hit shows the tree again (Ben, 2026-09-10)
    "/species/worms-217452/",        # the sardine: two datasets, twelve lineage ranks, five ways in
                                     # — and the full face: silhouette, photo, glance, five ladder
                                     #   marks and a NOAA plate (plan 2026-09-11 § Verification F3)
    "/species/worms-148985/",        # Chaetoceros: a silhouette and a photo, "not on record" for
                                     #   size, no plate — and NO gap where they would be
    "/species/itis-1255050/",        # the sooty shearwater: an Ardenna silhouette, flagged as
                                     #   drawn from one rank up
    "/species/worms-273305/",        # jack mackerel — a taxon the media sidecar has no entry for
                                     #   (the fixture's ten are the cast): the page is what
                                     #   it was, plus the sentence's record part and D9's stat word
    "/measurements/",                # the measurements catalog: search + timeline, matrix, datasets
    "/measurements/temperature/",    # the unified key: two series, two datasets, eight ways in
]

# ── the probe ─────────────────────────────────────────────────────────────────
# `shot-scraper javascript` has no --width (only `shot` does), so the page is loaded in a
# same-origin iframe of exactly the width under test and measured inside it: media queries,
# innerWidth and the grid's column count all follow the iframe's viewport. That keeps this
# script's only dependency the same as check_brand.py's — shot-scraper on PATH.
# Everything below returns plain data; every judgement is made in Python, so a failure can print
# what it actually measured.
PROBE = r"""
(w, d) => {
  const px = v => Math.round(v);
  const cs = el => w.getComputedStyle(el);
  const rgb = el => cs(el).color.replace(/\s/g, "");
  const tok = n => {
    const v = cs(d.documentElement).getPropertyValue(n).trim();
    if (!v) return null;
    const p = d.createElement("span");
    p.style.color = v; d.body.appendChild(p);
    const out = cs(p).color.replace(/\s/g, ""); p.remove();
    return out;
  };
  const out = {
    theme: d.documentElement.dataset.theme || null,
    width: w.innerWidth,
    scrollWidth: d.documentElement.scrollWidth,
    muted: tok("--muted"), warn: tok("--warn"),
    docHeight: d.documentElement.scrollHeight
  };

  // ── the grid: drawn vs natural height per tile ──────────────────────────────
  const grid = d.getElementById("ds-grid");
  if (grid) {
    const tiles = [...grid.children].filter(t => !t.hidden);
    const drawn = tiles.map(t => t.getBoundingClientRect().height);
    // natural = the same tiles with the packing off: no spans, no stretching
    const spans = tiles.map(t => t.style.gridRowEnd);
    const was = grid.className;
    tiles.forEach(t => { t.style.gridRowEnd = ""; });
    grid.classList.remove("is-masonry");
    grid.style.alignItems = "start";
    void grid.offsetHeight;
    const natural = tiles.map(t => t.getBoundingClientRect().height);
    grid.style.alignItems = "";
    grid.className = was;
    tiles.forEach((t, i) => { t.style.gridRowEnd = spans[i]; });
    void grid.offsetHeight;
    out.grid = {
      height: px(grid.getBoundingClientRect().height),
      masonry: grid.classList.contains("is-masonry"),
      columns: cs(grid).gridTemplateColumns.split(" ").length,
      tiles: tiles.map((t, i) => ({
        name: ((t.querySelector(".ds-tile-name") || {}).textContent || t.dataset.tile || "").trim(),
        drawn: px(drawn[i]), natural: px(natural[i]),
        ratio: natural[i] > 0 ? +(drawn[i] / natural[i]).toFixed(3) : 1
      }))
    };
  }

  // ── the filter actually hides ───────────────────────────────────────────────
  // `el.hidden` is a UA-stylesheet rule, so ANY author rule that sets `display` beats it — and
  // .cc-card and .ds-row both set `display: flex`. The filter row hid nothing for as long as it
  // existed (12 tiles and 41 rows stayed painted with one category selected), which only became
  // visible when the grid packed: a tile JS thinks is hidden gets no span, is drawn one 8 px row
  // tall, and spills over its neighbours. So: pick a category, apply it, and look.
  const sel = d.getElementById("ds-cat");
  if (sel) {
    const opt = [...sel.options].map(o => o.value).filter(Boolean)[0];
    if (opt) {
      sel.value = opt;
      sel.dispatchEvent(new w.Event("change", { bubbles: true }));
      void d.body.offsetHeight;
      out.filter = {
        category: opt,
        painted: [...d.querySelectorAll("[hidden]")]
          .filter(el => cs(el).display !== "none")
          .map(el => el.tagName + "." + String(el.className).slice(0, 40)),
        tilesShown: [...(grid ? grid.children : [])].filter(t => !t.hidden).length
      };
      sel.value = "";
      sel.dispatchEvent(new w.Event("change", { bubbles: true }));
    }
  }

  // ── the ladder: a holding row is muted, and carries no --warn ───────────────
  out.holdings = [...d.querySelectorAll(".ds-row-holding")].map(row => ({
    key: row.dataset.key,
    name: rgb(row.querySelector(".ds-row-name")),
    warn: [row, ...row.querySelectorAll("*")]
            .filter(el => {
              const s = cs(el);
              return s.color.replace(/\s/g, "") === out.warn ||
                     s.borderTopColor.replace(/\s/g, "") === out.warn ||
                     s.backgroundColor.replace(/\s/g, "") === out.warn;
            })
            .map(el => String(el.className || el.tagName))
  }));

  // ── the dataset page ───────────────────────────────────────────────────────
  const hero = d.querySelector(".ds-hero");
  if (hero) {
    const kids = [...hero.children].filter(c => c.getBoundingClientRect().height > 0);
    out.hero = { columns: kids.length, heights: kids.map(c => px(c.getBoundingClientRect().height)) };
  }
  // any two-column region between the head band and Cite
  const cite = d.getElementById("cite");
  out.twoCol = [...d.querySelectorAll(".ds-page .cc-container")]
    .filter(el => {
      if (!cite || !(cite.compareDocumentPosition(el) & 2 /* PRECEDING */)) return false;
      if (el.closest(".ds-page-head")) return false;
      const st = cs(el);
      return st.display === "grid" && st.gridTemplateColumns.split(" ").filter(Boolean).length > 1;
    })
    .map(el => (el.parentElement.id || String(el.className)));

  // a URL line must never wrap. Measure the TEXT, not the row: the row also holds a copy button,
  // which is taller than a line of 11.5 px mono and would read as a wrap that is not there.
  out.urls = [...d.querySelectorAll(".ds-url")].map(u => {
    const parts = [...u.querySelectorAll(".ds-url-h, .ds-url-t")];
    return {
      h: px(u.getBoundingClientRect().height),
      textH: px(Math.max(0, ...parts.map(s2 => s2.getBoundingClientRect().height))),
      lh: px(parseFloat(cs(u).lineHeight) || 0),
      t: (u.textContent || "").trim().slice(0, 60)
    };
  });

  // ── the front door (plan 2026-09-07 § D-8) ─────────────────────────────────
  const sec = d.querySelector("svg.sec");
  if (sec) {
    const r = sec.getBoundingClientRect(), sc = r.width / 1400;
    const ship = sec.querySelector(".ship") && sec.querySelector(".ship").getBoundingClientRect();
    // the copy's TEXT, not its blocks: a block spans the column even where the words stop
    const texts = [...d.querySelectorAll(".hero-copy .cc-eyebrow, .hero-copy h1, .hero-copy .hero-lede, .hero-copy .hero-actions a")]
      .map(e => { if (e.tagName === "A") return e.getBoundingClientRect(); const rg = d.createRange(); rg.selectNodeContents(e); return rg.getBoundingClientRect(); });
    const copyAbs = cs(d.querySelector(".hero-copy")).position === "absolute";
    let reach = null; try { reach = JSON.parse(d.getElementById("reach").textContent); } catch (e) {}
    const num = s => +String(s || "").replace(/[^0-9.]/g, "");
    const band = [...d.querySelectorAll(".nums > div")].map(el => ({ label: el.querySelector("dt").textContent.trim(), value: el.querySelector("dd").textContent.trim() }));
    // the first screen: everything above the tab row; --warn may appear only on the CTA
    const tabs = d.querySelector(".section-tabs");
    const warnEls = [...d.querySelectorAll("body *")].filter(el => {
      if (tabs && !(tabs.compareDocumentPosition(el) & 2 /* PRECEDING */)) return false;
      if (el.closest(".cc-header") || el.classList.contains("cc-btn-cta")) return false;   // the one CTA: in dark --warn IS the yellow
      const s = cs(el);
      const w = out.warn;
      return s.color.replace(/\s/g, "") === w || s.backgroundColor.replace(/\s/g, "") === w || s.borderTopColor.replace(/\s/g, "") === w;
    }).map(el => String(el.className || el.tagName));
    const cta = tok("--cta-bg");
    const ctaEls = [...d.querySelectorAll("body *")].filter(el => {
      if (tabs && !(tabs.compareDocumentPosition(el) & 2)) return false;
      if (el.closest(".cc-header")) return false;
      return cs(el).backgroundColor.replace(/\s/g, "") === cta;
    }).map(el => String(el.className || el.tagName));
    out.front = {
      svgVh: +(r.height / w.innerHeight * 100).toFixed(1),
      copyAbs,
      copyOverlapsShip: !!ship && copyAbs && texts.some(b => !(b.right < ship.left || b.left > ship.right || b.bottom < ship.top || b.top > ship.bottom)),
      copyBottomUnits: +(Math.max(...texts.map(b => b.bottom)) - r.top).toFixed(0) / sc,
      pins: [...sec.querySelectorAll("a.pin")].map(a => a.getAttribute("href")),
      band, reachNumbers: reach && reach.numbers,
      stripRows: d.querySelectorAll("svg.strip a.rowlink").length, datasets: reach && reach.datasets.length,
      mapMarks: d.querySelectorAll("svg.map .st").length - d.querySelectorAll("svg.map .keyg .st").length, stations: reach && reach.stations.length,
      warnEls, ctaEls,
      // natural = the tile taken out of the grid at its own width, its flexing fill let be its
      // content's height (the map's drawing at the tile's width, the strip at its aspect)
      tiles: [...d.querySelectorAll(".tile")].map(t => {
        const b = t.getBoundingClientRect(), drawn = b.height;
        const was = t.getAttribute("style") || "";
        const fills = [...t.querySelectorAll(".fill")].map(f => [f, f.getAttribute("style") || ""]);
        const svgs = [...t.querySelectorAll(".fill > svg")].map(s => [s, s.getAttribute("style") || ""]);
        t.style.cssText = was + ";position:absolute;left:0;top:0;width:" + b.width + "px;height:auto;grid-row:auto;grid-column:auto";
        fills.forEach(([f]) => { f.style.flex = "none"; f.style.minHeight = "0"; });
        svgs.forEach(([s]) => { s.style.position = "static"; s.style.width = "100%"; s.style.height = "auto"; });
        const natural = t.getBoundingClientRect().height;
        t.setAttribute("style", was); fills.forEach(([f, s]) => f.setAttribute("style", s)); svgs.forEach(([s, st]) => s.setAttribute("style", st));
        return { name: (t.querySelector(".cc-eyebrow") || {}).textContent || t.className, drawn: px(drawn), natural: px(natural), ratio: natural > 0 ? +(drawn / natural).toFixed(3) : 1 };
      })
    };
  }

  // ── the front door's navigation (plan 2026-09-10 § D7, WS-M0) ──────────────
  // The header's six words plus calcofi.org, the submenus, the sticky section bar, the tabsets and
  // the one search over the three indexes. Everything here is measured on the real page: the
  // submenu is opened by FOCUSING its trigger (that is the whole mechanism — :focus-within), and
  // the search is driven by typing into the box and reading what came back.
  const nav = d.querySelector(".cc-header .cc-links");
  if (nav) {
    const items = [...nav.children].filter(el => el.matches("a, .cc-m"));
    const menus = [...nav.querySelectorAll(".cc-m")].map(m => {
      const trig = m.querySelector("a[aria-haspopup]"), ul = m.querySelector("ul");
      const shown = () => ul && cs(ul).display !== "none";
      const before = shown();
      if (trig) trig.focus();
      const onFocus = shown();
      // the hover bridge (Ben, 2026-09-10): the list floats below its trigger, so the gap between the
      // trigger's bottom and the list's top must be spanned by the list's own ::before strip, or the
      // pointer leaves the group on its way down and the menu closes before a click lands
      let gap = null, bridge = null;
      if (trig && ul && onFocus) {
        const tr = trig.getBoundingClientRect(), ur = ul.getBoundingClientRect();
        gap = ur.top - tr.bottom;
        const b = w.getComputedStyle(ul, "::before");
        bridge = b && b.content !== "none" ? parseFloat(b.height) || 0 : 0;
      }
      // Escape closes: assets/tabs.js blurs the focused link, so the :focus-within rule lapses
      d.activeElement && d.activeElement.dispatchEvent(new w.KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      const afterEsc = shown();
      if (trig) trig.blur();
      return {
        word: trig ? trig.textContent.trim() : null,
        tabs: [...m.querySelectorAll("ul a")].map(a => ({
          title: a.textContent.replace(/\s+/g, " ").trim(),
          pill: (a.querySelector(".pill") || {}).textContent || null,
          go: a.getAttribute("data-go"),
          href: a.getAttribute("href")
        })),
        closed: !before, opensOnFocus: !!onFocus, closesOnEscape: !afterEsc, gap, bridge,
        haspopup: trig && trig.getAttribute("aria-haspopup") === "true",
        expanded: trig && trig.getAttribute("aria-expanded")
      };
    });
    out.nav = {
      words: items.map(el => (el.matches(".cc-m") ? el.querySelector("a") : el).textContent.replace(/\s+/g, " ").trim()),
      hrefs: items.map(el => (el.matches(".cc-m") ? el.querySelector("a") : el).getAttribute("href")),
      visible: cs(nav).display !== "none",
      menus
    };
  }

  // the phone menu (Ben, 2026-09-10): under 480 px the brand hides .cc-links and the hamburger in the
  // icon cluster must open the same nav as a column — every word, every submenu inline, no
  // horizontal scroll while open — and Escape must close it. Measured by clicking the button.
  const header = d.querySelector(".cc-header"), burger = header && header.querySelector(".cc-menu-button");
  if (header && burger) {
    const buttonShown = cs(burger).display !== "none" && burger.getBoundingClientRect().width > 0;
    let opened = null, expanded = null, wordsOpen = null, subsOpen = null, scrollW = null, closedOnEsc = null;
    if (buttonShown) {
      burger.click();
      opened = header.classList.contains("cc-nav-open") && !!nav && cs(nav).display !== "none";
      expanded = burger.getAttribute("aria-expanded");
      wordsOpen = nav ? [...nav.children].filter(el => el.matches("a, .cc-m") && el.getBoundingClientRect().height > 0).length : 0;
      subsOpen = nav ? [...nav.querySelectorAll(".cc-m > ul")].filter(ul => cs(ul).display !== "none" && ul.getBoundingClientRect().height > 0).length : 0;
      scrollW = d.documentElement.scrollWidth;
      d.dispatchEvent(new w.KeyboardEvent("keydown", { key: "Escape", bubbles: true }));
      closedOnEsc = !header.classList.contains("cc-nav-open");
    }
    out.phoneMenu = { buttonShown, opened, expanded, wordsOpen, subsOpen, scrollW, closedOnEsc };
  }

  // do the two catalog pages exist on this build? (the DATA submenu must link them when they do)
  out.pageExists = {};
  for (const p of ["/species/", "/measurements/"]) {
    try { const x = new w.XMLHttpRequest(); x.open("HEAD", p, false); x.send(); out.pageExists[p] = x.status >= 200 && x.status < 400; } catch (e) { out.pageExists[p] = false; }
  }

  // the sticky section bar and the tabsets
  const bar = d.querySelector(".section-tabs");
  if (bar) {
    out.sections = [...bar.querySelectorAll("a")].map(a => ({
      title: a.firstChild ? a.firstChild.textContent.trim() : a.textContent.trim(),
      n: (a.querySelector(".n") || {}).textContent.replace(/\s+/g, " ").trim(),
      href: a.getAttribute("href")
    }));
  }
  const sets = [...d.querySelectorAll(".tabset")];
  if (sets.length) {
    out.tabsets = sets.map(ts => ({
      id: ts.id,
      tabs: [...ts.querySelectorAll(".tabrow button")].map(b => {
        const id = b.getAttribute("data-tab");
        const panel = ts.querySelector('.tabpanel[data-panel="' + id + '"]');
        return {
          id, title: b.textContent.replace(/\s+/g, " ").trim(),
          pill: (b.querySelector(".pill") || {}).textContent || null,
          selected: b.getAttribute("aria-selected") === "true",
          hidden: !panel || panel.hidden,
          drawn: !!panel && cs(panel).display !== "none",
          cards: panel ? panel.querySelectorAll(".prod-card").length : 0
        };
      })
    }));
  }

  // the DATA section's height, so the front door cannot quietly grow (plan § Risks)
  const dataSec = d.getElementById("datasets");
  if (dataSec) out.dataSectionH = px(dataSec.getBoundingClientRect().height);

  // the band's two counted things are doors now
  out.bandLinks = [...d.querySelectorAll(".nums > div")]
    .map(el => ({ label: el.querySelector("dt").textContent.trim(),
                  href: (el.querySelector("dd a") || {}).getAttribute ? el.querySelector("dd a").getAttribute("href") : null }));

  // the Observed tile: both rows drawn, nothing spilling out of the cell
  const obs = d.querySelector(".tile.t-obs");
  if (obs) {
    const b = obs.getBoundingClientRect();
    out.observed = {
      rows: [...obs.querySelectorAll(".obsrow")].map(r => r.textContent.replace(/\s+/g, " ").trim()),
      links: [...obs.querySelectorAll(".obsrow a")].map(a => a.getAttribute("href")),
      overflow: Math.max(0, px(obs.scrollHeight - obs.clientHeight)),
      spill: [...obs.querySelectorAll("*")].filter(e2 => {
        const r2 = e2.getBoundingClientRect();
        return r2.height > 0 && (r2.bottom > b.bottom + 1 || r2.right > b.right + 1);
      }).length
    };
  }

  // ── the species catalog (plan 2026-09-09 § S3) ─────────────────────────────
  // The index: the counts, the matrix's shape and the two panes, all read back from the page's own
  // inline record so the check compares the drawing with the data it was drawn from.
  const spData = d.getElementById("sp-data");
  if (spData) {
    let rec = null; try { rec = JSON.parse(spData.textContent); } catch (e) {}
    const num = s2 => +String(s2 || "").replace(/[^0-9]/g, "");
    const counts = [...d.querySelectorAll(".sp-counts > div")].map(el => ({
      label: el.querySelector("dt").textContent.trim(), value: num(el.querySelector("dd").textContent)
    }));
    const tree = d.getElementById("sp-tree"), mwrap = d.getElementById("sp-matrix");
    const pane = el => el && el.closest(".sp-pane");
    // a pane's natural height: the same pane with its scroll box let be its content's height
    const natural = el => {
      if (!el) return 0;
      const p2 = pane(el), was = tree.style.height;
      tree.style.height = "auto";
      void p2.offsetHeight;
      const h = p2.getBoundingClientRect().height;
      tree.style.height = was;
      return h;
    };
    out.species = {
      counts,
      rec: rec && rec.counts,
      rows: rec && rec.mx ? rec.mx.rows.length : null,
      cols: rec && rec.mx ? rec.mx.cols.length : null,
      cells: d.querySelectorAll(".sp-mx .sp-c").length,
      treePane: pane(tree) ? px(pane(tree).getBoundingClientRect().height) : 0,
      matrixPane: pane(mwrap) ? px(pane(mwrap).getBoundingClientRect().height) : 0,
      matrixNatural: pane(mwrap) ? px(pane(mwrap).scrollHeight) : 0,
      iceRects: d.querySelectorAll("#sp-ice rect").length,
      treeRoots: d.querySelectorAll('#sp-tree > ul > li[role="treeitem"]').length,
      // the panes' mode and the collapsed pane's pill (Ben, 2026-09-10): the pill must stand where
      // the folded pane was, as tall as the expanded pane, and a search with hits must show the tree
      panes: (d.querySelector(".sp-two") || {}).getAttribute ? d.querySelector(".sp-two").getAttribute("data-panes") : null,
      pill: (() => { const pl = [...d.querySelectorAll(".sp-pane-pill")].find(el => !el.hidden && cs(el).display !== "none");
        if (!pl) return null; const b = pl.getBoundingClientRect();
        return { pane: pl.dataset.pane, label: pl.getAttribute("aria-label"), w: px(b.width), h: px(b.height), text: pl.textContent.trim() }; })(),
      treeShown: !!tree && tree.offsetParent !== null,
      hits: d.querySelectorAll("#sp-tree .sp-hit").length,
      hitsShown: [...d.querySelectorAll("#sp-tree .sp-hit")].filter(el => el.offsetParent !== null).length,
      warnEls: [...d.querySelectorAll(".sp-body *, .sp-head *")].filter(el => {
        const st = cs(el), w = out.warn;
        return st.color.replace(/\s/g, "") === w || st.backgroundColor.replace(/\s/g, "") === w;
      }).map(el => String(el.className || el.tagName)).slice(0, 6)
    };
    void natural;   // the tree pane is bounded by the matrix pane, which is checked directly
  }

  // one taxon page: the rows, the lineage and the Explorer link against the page's own record
  const spStrip = d.getElementById("sp-strip-data");
  if (spStrip) {
    let S = null; try { S = JSON.parse(spStrip.textContent); } catch (e) {}
    const numc = s2 => +String(s2 || "").replace(/,/g, "").match(/\d+/);
    out.speciesPage = {
      key: S && S.key,
      recRows: S ? S.rows.map(r => ({ name: r.s, n: r.n })) : [],
      rows: [...d.querySelectorAll(".sp-dsrow")].map(li => ({
        name: (li.querySelector(".sp-l1 a") || {}).textContent || "",
        n: numc((li.querySelector(".sp-meta") || {}).textContent)
      })),
      lineage: [...d.querySelectorAll(".sp-lineage a")].map(a => ({ name: a.textContent.trim(), href: a.getAttribute("href") })),
      here: (d.querySelector(".sp-lineage .sp-here") || {}).textContent || null,
      explore: [...d.querySelectorAll('a[href*="/explore/"]')].map(a => a.getAttribute("href")),
      stripRows: d.querySelectorAll("#sp-strip rect").length ? new Set([...d.querySelectorAll("#sp-strip rect")].map(r => r.getAttribute("y"))).size : 0,
      // DRAWN, not merely populated: `.sp-strip:not([viewBox])` lowercases to `[viewbox]` in an
      // HTML document and never matches SVG's camelCase attribute, so the strip was display:none
      // with 93 rects in it and every count still agreed (measured 2026-09-09)
      stripH: d.querySelector("#sp-strip") ? px(d.querySelector("#sp-strip").getBoundingClientRect().height) : 0,
      stats: [...d.querySelectorAll(".sp-stat > div")].map(el => el.querySelector("dt").textContent.trim())
    };
  }

  // ── faces: the face row, the sentence, the glance, the ladder (plan 2026-09-11 § D1–D5, D9)
  // Read back from the page's OWN inline #sp-size-data where there is one, so the check compares
  // the drawing with the payload it was drawn from and never with a number typed here.
  if (d.querySelector(".sp-page-head")) {
    const sil = d.querySelector(".sp-sil"), ph = d.querySelector(".sp-photo img");
    const box = el => { const b = el.getBoundingClientRect(); return { x: px(b.x), y: px(b.y), w: px(b.width), h: px(b.height) }; };
    let size = null;
    const sd = d.getElementById("sp-size-data");
    if (sd) { try { size = JSON.parse(sd.textContent); } catch (e) {} }
    // every label the ladder draws, with its box, so Python can look for an overlapping pair
    const ladder = d.getElementById("sp-ladder");
    // …each tagged with the <g> it belongs to: a reference's name and its length are stacked on
    // purpose, so only labels from DIFFERENT groups may not overlap
    const lgroups = ladder ? [...ladder.querySelectorAll("g")] : [];
    const labels = ladder && ladder.classList.contains("sp-drawn")
      ? [...ladder.querySelectorAll("text")].map(t => Object.assign(box(t), {
          t: t.textContent.trim(),
          g: lgroups.indexOf(t.closest("g"))
        }))
      : [];
    out.faces = {
      sil: sil ? Object.assign(box(sil), { label: sil.getAttribute("aria-label"), role: sil.getAttribute("role"),
                                           fill: cs(sil).fill.replace(/\s/g, "") }) : null,
      stand: (d.querySelector(".sp-stand") || {}).textContent || null,
      photo: ph ? Object.assign(box(ph), { alt: ph.getAttribute("alt"), w0: ph.getAttribute("width"),
                                           h0: ph.getAttribute("height"), loading: ph.getAttribute("loading"),
                                           pos: cs(ph).objectPosition,
                                           masked: cs(ph.parentElement).maskImage !== "none" ||
                                                   cs(ph.parentElement).webkitMaskImage !== "none" }) : null,
      nc: !!d.querySelector(".sp-photo-fig .cc-chip"),
      bars: [...d.querySelectorAll(".sp-glance .sp-bar")].map(b => px(b.getBoundingClientRect().width)),
      glanceNone: !!d.querySelector(".sp-glance-none"),
      sentParts: [...d.querySelectorAll(".sp-sent > span")].map(s => s.className),
      legend: d.querySelectorAll(".sp-legend > span").length,
      credits: [...d.querySelectorAll(".sp-credit")].map(p => p.textContent.replace(/\s+/g, " ").trim().slice(0, 90)),
      statWords: [...d.querySelectorAll(".sp-stat > div")].map(el => el.querySelector("dt").textContent.trim()),
      size,
      ladderDrawn: !!(ladder && ladder.classList.contains("sp-drawn")),
      ladderMarks: ladder ? ladder.querySelectorAll(".sp-mark, .sp-markdot").length : 0,
      ladderRefs: ladder ? ladder.querySelectorAll(".sp-rlab").length : 0,
      labels,
      besideDrawn: !!(d.querySelector(".sp-beside") && d.querySelector(".sp-beside").classList.contains("sp-drawn")),
      plateImg: !!d.querySelector(".sp-plate-img img"),
      early: d.querySelectorAll(".sp-early li").length,
      howBig: !!d.getElementById("how-big")
    };
  }

  // every .sp-url is ONE line, and elided from the middle rather than wrapped or cut
  out.spUrls = [...d.querySelectorAll(".sp-url")].map(a => ({
    h: px(a.getBoundingClientRect().height),
    lh: px(parseFloat(cs(a).lineHeight) || 0),
    full: (a.getAttribute("data-full") || "").length,
    shown: (a.textContent || "").length,
    elided: (a.textContent || "").indexOf("\u2026") >= 0,
    overflow: a.scrollWidth > a.clientWidth + 1,
    t: (a.textContent || "").trim().slice(0, 48)
  }));

  // one ERDDAP listing: count each tabledap page link
  const tabledap = {};
  [...d.querySelectorAll('a[href*="tabledap/"]')].forEach(a => {
    const m = /tabledap\/([^.?#\/]+)\.html(?:$|[?#])/.exec(a.getAttribute("href") || "");
    if (m) tabledap[m[1]] = (tabledap[m[1]] || 0) + 1;
  });
  out.tabledap = tabledap;

  // ── the measurements catalog (plan 2026-09-10 § D5, D6; WS-M4) ────────────
  // The index's figures are read back against the page's OWN inline record, so the check compares
  // the drawing with the data it was drawn from and never against a number typed here.
  const mmData = d.getElementById("mm-data");
  const mmStrip = d.getElementById("mm-strip-data");
  if (mmStrip) {
    let S = null; try { S = JSON.parse(mmStrip.textContent); } catch (e) {}
    let DP = null; try { DP = JSON.parse(d.getElementById("mm-depth-data").textContent); } catch (e) {}
    let MO = null; try { MO = JSON.parse(d.getElementById("mm-months-data").textContent); } catch (e) {}
    const strip = d.getElementById("mm-strip"), dep = d.getElementById("mm-depth"), mon = d.getElementById("mm-months");
    const bars = [...dep.querySelectorAll(".mm-b")];
    out.mmPage = {
      key: S && S.key,
      recRows: S ? S.rows.length : 0,
      // DRAWN, not merely populated — the `[viewBox]` trap the species strip hit on 2026-09-09
      stripDrawn: strip.classList.contains("mm-drawn"),
      stripH: px(strip.getBoundingClientRect().height),
      stripRows: strip.querySelectorAll("text.mm-rl").length,
      stripRects: strip.querySelectorAll("rect").length,
      recRects: S ? S.rows.reduce((a, r) => a + Object.keys(r.y || {}).filter(k => r.y[k] > 0).length, 0) : 0,
      depthBands: dep.querySelectorAll(".mm-lb").length,
      recBands: DP ? (DP.bands || []).length : 0,
      depthBars: bars.length,
      // an end label that hangs outside its own column is the failure this padding exists for
      depthLabelsOut: bars.filter(b => {
        const sp = b.querySelector("span");
        if (!sp) return false;
        return sp.getBoundingClientRect().right > b.closest(".mm-pair").getBoundingClientRect().right + 1;
      }).length,
      depthLegend: d.querySelectorAll("#mm-depth-legend span").length,
      monthCells: mon.querySelectorAll(".mm-c").length,
      monthRows: MO ? MO.rows.length : 0,
      monthLetters: mon.querySelectorAll(".mm-ml").length,
      rows: [...d.querySelectorAll(".mm-dsrow")].map(li => ({
        name: (li.querySelector(".mm-l1 a") || {}).textContent || "",
        dot: !!li.querySelector(".mm-dot")
      })),
      explore: [...d.querySelectorAll('a[href*="/explore/"]')].map(a => a.getAttribute("href"))
    };
  }
  // every .mm-url is ONE line, elided from the middle rather than wrapped or cut
  out.mmUrls = [...d.querySelectorAll(".mm-url")].map(a => ({
    h: px(a.getBoundingClientRect().height),
    lh: px(parseFloat(cs(a).lineHeight) || 0),
    full: (a.getAttribute("data-full") || "").length,
    shown: (a.textContent || "").length,
    elided: (a.textContent || "").indexOf("…") >= 0,
    overflow: a.scrollWidth > a.clientWidth + 1,
    t: (a.textContent || "").trim().slice(0, 48)
  }));

  if (mmData) {
    let rec = null; try { rec = JSON.parse(mmData.textContent); } catch (e) {}
    const tl = d.getElementById("mm-tl"), mx = d.querySelector(".mm-mx");
    const cells = mx ? [...mx.querySelectorAll(".mm-cell")] : [];
    const read = () => ({
      rows: tl.querySelectorAll(".mm-nm").length,
      n: (d.getElementById("mm-qn") || {}).textContent
    });
    out.mm = {
      rec: rec && rec.counts,
      cats: rec ? rec.cats.length : 0,
      ds: rec ? rec.ds.length : 0,
      recSeries: rec ? rec.rows.reduce((a, r) => a + (r.se || []).length, 0) : 0,
      tlRows: tl.querySelectorAll(".mm-nm").length,
      tlBars: tl.querySelectorAll(".mm-bar").length,
      tlCats: tl.querySelectorAll(".mm-cat").length,
      tlWidth: px(tl.getBoundingClientRect().width),
      tlScroller: px(tl.parentElement.clientWidth),
      tlOverflowX: cs(tl.parentElement).overflowX,
      mxCells: cells.length,
      mxFilled: cells.filter(c => !c.classList.contains("mm-z")).length,
      mxSum: cells.reduce((a, c) => a + (parseInt(String(c.textContent).replace(/,/g, ""), 10) || 0), 0),
      mxHeads: mx ? mx.querySelectorAll(".mm-mh").length : 0,
      mxRows: mx ? mx.querySelectorAll(".mm-rl2").length : 0,
      dsRows: d.querySelectorAll("#mm-dslist li").length,
      chips: [...d.querySelectorAll("#mm-chips button")].map(b => ({
        cat: b.getAttribute("data-cat"), pressed: b.getAttribute("aria-pressed"),
        n: +String((b.querySelector(".mm-n") || {}).textContent || "").replace(/[^0-9]/g, "")
      })),
      legend: d.querySelectorAll("#mm-legend span").length,
      tlRole: tl.getAttribute("role"),
      tipRole: (d.getElementById("mm-ttip") || {}).getAttribute ? d.getElementById("mm-ttip").getAttribute("role") : null,
      // a bar with no dataset name in its row would be identity by colour alone
      barsWithoutName: [...tl.querySelectorAll(".mm-bar")].length -
                       [...tl.querySelectorAll(".mm-ds span")].length
    };
    const q = d.getElementById("mm-q");
    const MM_TERMS = ["nitrate", "NTRAZZXX", "µmol/kg", "METS"];
    const mtype = t => new Promise(res => {
      q.value = t;
      q.dispatchEvent(new w.Event("input", { bubbles: true }));
      setTimeout(() => { out.mm.search = out.mm.search || {}; out.mm.search[t] = read(); res(); }, 80);
    });
    return MM_TERMS.reduce((p, t) => p.then(() => mtype(t)), Promise.resolve())
      .then(() => { q.value = ""; q.dispatchEvent(new w.Event("input", { bubbles: true })); return out; });
  }

  // ── the one search over the three indexes (plan 2026-09-10 § D7 (3)) ───────
  // assets/door-search.js fetches the three records on the FIRST focus, so the box has to be
  // driven, not read: focus it, type each term, and count what came back per group. The promise
  // is what the probe returns — the host resolves whatever `done()` is handed.
  const dq = d.getElementById("door-q");
  if (!dq) return out;
  const TERMS = ["sardine", "nitrate", "CUFES", "TEMPPR01"];
  const type = t => new Promise(res => {
    dq.value = t;
    dq.dispatchEvent(new w.Event("input", { bubbles: true }));
    setTimeout(res, 220);
  });
  const readOut = () => {
    const box = d.getElementById("door-res");
    const groups = [...box.querySelectorAll(".dres-g")].map(g2 => g2.textContent.replace(/\s+/g, " ").trim());
    return { open: box.classList.contains("open"), groups,
             hits: box.querySelectorAll("a.dres-r").length,
             none: !!box.querySelector(".dres-none"),
             first: (box.querySelector("a.dres-r") || {}).getAttribute
               ? box.querySelector("a.dres-r").getAttribute("href") : null };
  };
  dq.focus();
  return new Promise(resolve => {
    setTimeout(() => {                       // the three fetches
      const search = {};
      TERMS.reduce((p, t) => p.then(() => type(t)).then(() => { search[t] = readOut(); }),
                   Promise.resolve())
        .then(() => { dq.value = ""; out.search = search; resolve(out); })
        .catch(e => { out.search = { error: String(e) }; resolve(out); });
    }, 1200);
  });
}
"""

HOST = """
new Promise(done => {
  const f = document.createElement("iframe");
  f.style.cssText = "position:fixed;left:0;top:0;border:0;width:__W__px;height:900px";
  f.src = "__URL__";
  f.onload = () => {
    const w = f.contentWindow, d = f.contentDocument;
    const go = () => setTimeout(() => { try { done((__PROBE__)(w, d)); } catch (e) { done({error: String(e)}); } }, __WAIT__);
    if (d.fonts && d.fonts.ready) d.fonts.ready.then(go); else go();
  };
  document.body.appendChild(f);
});
"""


def probe(url, width, theme, browser, wait):
    sep = "&" if "?" in url else "?"
    target = f"{url}{sep}theme={theme}&tour=off"
    js = (HOST.replace("__W__", str(width)).replace("__URL__", target)
              .replace("__PROBE__", PROBE).replace("__WAIT__", str(wait)))
    # the host page must be same-origin with the target, so load the target itself and let the
    # iframe inside it be the one that is measured at the width under test
    cmd = ["shot-scraper", "javascript", target, js, "--browser", browser]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if r.returncode:
        msg = (r.stderr or r.stdout).strip().splitlines()
        return {"error": msg[-1] if msg else "shot-scraper failed"}
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"error": f"unparseable: {r.stdout[:120]!r}"}


# ── the assertions ────────────────────────────────────────────────────────────
MAX_STRETCH = 1.25    # a tile drawn more than a quarter taller than its content is stretch
MAX_HERO_GAP = 120    # px between the head band's two columns
MAX_GRID_H = 4400     # px at 1470 with the staging record (was 4,910)
MAX_HERO_VH = 62      # the front door's drawing at 1470: the catalog must start within reach
MAX_TILE_STRETCH = 1.25

# ── the front door's navigation (plan 2026-09-10 § D7, WS-M0) ─────────────────
# The six words plus calcofi.org ↗ — seven items, as before D7. DOCS and NEWS are pages, so the
# section bar draws four; the header draws all six and the outbound link.
NAV_WORDS = ["Data", "Apps", "Access", "Build", "Docs", "News", "calcofi.org ↗"]
SECTION_WORDS = ["Data", "Apps", "Access", "Build"]
# the sections whose tabs are CARDS, so a pill must equal the number of cards in its panel. DATA's
# three pills count datasets, species and measurements — the release's numbers, checked against the
# page's own inline record instead (the band assertions above already do it).
CARD_TABSETS = ("ts-explore", "ts-access")
# The Data section at 1470 px, measured on main's own build before D7 (2026-09-10, the v2026.09.06
# record, light): 2,974 px. D7 adds one search box (48), one tab row (43) and one door line in each
# realm head (35) and must not add a screen — plan § Risks, WS-M0's gate. Measured after: 3,078 px,
# +104. Re-measure and re-state this number whenever the catalog's own furniture changes.
DATA_SECTION_BASE = 2974
DATA_SECTION_GROWTH = 120

_PROBED = {}          # pin hrefs answered once per run, not per width and theme


def url_ok(url):
    """200/206 to a ranged GET (HEAD is answered 405 by some hosts — build_workflows_index.R's rule)."""
    if url in _PROBED:
        return _PROBED[url]
    import urllib.request
    req = urllib.request.Request(url, headers={"Range": "bytes=0-0", "User-Agent": "Mozilla/5.0 (calcofi.io check_layout)"})
    try:
        with urllib.request.urlopen(req, timeout=20) as r:
            _PROBED[url] = r.status in (200, 206)
    except Exception as e:  # noqa: BLE001
        code = getattr(e, "code", None)
        _PROBED[url] = code in (200, 206) if code else None   # None: unreachable, a warning not a failure
    return _PROBED[url]


def check(path, r, width, theme, fails, notes):
    where = f"{path} @{width}px {theme}"

    if r.get("scrollWidth", 0) > r.get("width", 0) + 1:
        fails.append(f"{where}: horizontal scroll — scrollWidth {r['scrollWidth']} > {r['width']}")

    g = r.get("grid")
    if g:
        worst = max(g["tiles"], key=lambda t: t["ratio"], default=None)
        notes.append(f"{where}: grid {g['height']}px, {g['columns']} col, masonry={g['masonry']}, "
                     f"worst stretch {worst['ratio']}x ({worst['name'].strip()})" if worst else where)
        for t in g["tiles"]:
            if t["ratio"] > MAX_STRETCH:
                fails.append(f"{where}: tile {t['name'].strip()!r} drawn {t['drawn']}px for "
                             f"{t['natural']}px of content ({t['ratio']}x > {MAX_STRETCH})")
        if width >= 1400 and g["height"] > MAX_GRID_H:
            fails.append(f"{where}: grid {g['height']}px > {MAX_GRID_H}px")
        if width <= 400 and g["columns"] != 1:
            fails.append(f"{where}: grid is {g['columns']} columns, expected 1")

    f = r.get("filter")
    if f:
        notes.append(f"{where}: filter {f['category']!r} -> {f['tilesShown']} tile(s) shown")
        if f["painted"]:
            fails.append(f"{where}: filtering by {f['category']!r} left {len(f['painted'])} hidden "
                         f"element(s) still displayed (an author `display` rule beats [hidden]): "
                         f"{', '.join(sorted(set(f['painted']))[:4])}")

    for h in r.get("holdings", []):
        if h["name"] != r["muted"]:
            fails.append(f"{where}: holding {h['key']} name is {h['name']}, expected --muted {r['muted']}")
        if h["warn"]:
            fails.append(f"{where}: holding {h['key']} carries --warn on {h['warn']}")

    hero = r.get("hero")
    if hero and hero["columns"] == 2 and width >= 900:
        gap = abs(hero["heights"][0] - hero["heights"][1])
        notes.append(f"{where}: hero columns {hero['heights']} (gap {gap}px)")
        if gap > MAX_HERO_GAP:
            fails.append(f"{where}: hero columns end {gap}px apart ({hero['heights']}), max {MAX_HERO_GAP}")
    if r.get("twoCol"):
        fails.append(f"{where}: two-column region(s) between the head and Cite: {r['twoCol']}")

    if width <= 400:
        for u in r.get("urls", []):
            if u["lh"] and u.get("textH", u["h"]) > u["lh"] * 1.6:
                fails.append(f"{where}: URL text wraps ({u['textH']}px over a {u['lh']}px line): {u['t']}…")

    for ds_id, n in (r.get("tabledap") or {}).items():
        if n != 1:
            fails.append(f"{where}: ERDDAP id {ds_id} listed {n} times, expected once")

    # ── the species catalog's index (plan 2026-09-09 § S3) ────────────────────
    sp = r.get("species")
    if sp:
        rec = sp.get("rec") or {}
        # the five counts on the page are the record's, read back from the page's own inline JSON
        want = {"species": rec.get("species_observed"), "taxa observed": rec.get("taxa_observed"),
                "datasets": rec.get("datasets"), "observations": rec.get("obs_bio_rows"),
                "pages": rec.get("pages")}
        seen = {c["label"]: c["value"] for c in sp["counts"]}
        for k, v in want.items():
            if v is None:
                continue
            if k not in seen:
                fails.append(f"{where}: the species index has no {k!r} count though the record carries {v}")
            elif seen[k] != v:
                fails.append(f"{where}: the index says {k} = {seen[k]}, the record says {v}")
        # the matrix is exactly (classes + the two rows the record makes necessary) x datasets
        if sp["rows"] and sp["cols"]:
            wantc = sp["rows"] * sp["cols"]
            if sp["cells"] != wantc:
                fails.append(f"{where}: the matrix has {sp['cells']} cells for "
                             f"{sp['rows']} rows x {sp['cols']} datasets ({wantc})")
        if sp["iceRects"] < 10:
            fails.append(f"{where}: the icicle drew {sp['iceRects']} bands")
        if sp["treeRoots"] < 2:
            fails.append(f"{where}: the tree drew {sp['treeRoots']} roots")
        if sp["warnEls"]:
            fails.append(f"{where}: --warn on the species index: {', '.join(sorted(set(sp['warnEls']))[:4])}")
        # No unbounded text beside a fixed-height figure: the tree scrolls INSIDE a pane that is
        # exactly the matrix pane's height, and the matrix pane is bounded by its own content — so
        # neither pane can be drawn taller than something real (the tree's own content is 2,403
        # nodes, taller than any pane).
        mode = sp.get("panes") or "both"
        has_q = "q=" in path
        if width >= 1100 and mode == "both":
            gap = abs(sp["treePane"] - sp["matrixPane"])
            notes.append(f"{where}: panes tree {sp['treePane']}px / matrix {sp['matrixPane']}px, "
                         f"matrix {sp['cells']} cells, icicle {sp['iceRects']} bands")
            if gap > 4:
                fails.append(f"{where}: the tree pane is {sp['treePane']}px and the matrix pane "
                             f"{sp['matrixPane']}px ({gap}px apart) — they must match")
            if sp["matrixNatural"] and sp["matrixPane"] > sp["matrixNatural"] * MAX_STRETCH:
                fails.append(f"{where}: the matrix pane is drawn {sp['matrixPane']}px for "
                             f"{sp['matrixNatural']}px of content")
        # an expanded pane folds the other into a vertical pill, never removes it (Ben, 2026-09-10)
        if width >= 1100 and mode != "both":
            pl = sp.get("pill")
            other = "tree" if mode == "matrix" else "matrix"
            if not pl or pl["pane"] != other:
                fails.append(f"{where}: panes={mode} but no pill stands in for the {other} pane")
            else:
                shown_h = sp["matrixPane"] if mode == "matrix" else sp["treePane"]
                notes.append(f"{where}: panes={mode}; the {other} pill {pl['w']}×{pl['h']}px reads {pl['label']!r}")
                if not (24 <= pl["w"] <= 32):
                    fails.append(f"{where}: the {other} pill is {pl['w']}px wide, expected about 28")
                if abs(pl["h"] - shown_h) > 4:
                    fails.append(f"{where}: the {other} pill is {pl['h']}px tall beside a {shown_h}px pane")
                if not (pl["label"] or "").lower().startswith("show the"):
                    fails.append(f"{where}: the {other} pill's label reads {pl['label']!r}, not 'Show the …'")
        # a search with hits must show the tree they are in, whatever ?panes= asked for
        if has_q and width >= 1100:
            if sp["hits"] and (not sp["treeShown"] or sp["hitsShown"] == 0):
                fails.append(f"{where}: the search found {sp['hits']} hit(s) but the tree is folded — nothing to click")
            elif sp["hits"]:
                notes.append(f"{where}: search hits {sp['hits']}, shown {sp['hitsShown']}, panes={mode}")

    # ── one taxon page ────────────────────────────────────────────────────────
    spp = r.get("speciesPage")
    if spp:
        rec_rows = spp["recRows"]
        rows = spp["rows"]
        if len(rows) != len(rec_rows):
            fails.append(f"{where}: {len(rows)} \"Observed in\" rows for {len(rec_rows)} datasets in the record")
        else:
            for got, wantr in zip(rows, rec_rows):
                if got["name"].strip() != wantr["name"]:
                    fails.append(f"{where}: row {got['name']!r}, the record says {wantr['name']!r}")
                if got["n"] != wantr["n"]:
                    fails.append(f"{where}: {wantr['name']} shows {got['n']} observations, "
                                 f"the record says {wantr['n']}")
        if not spp["lineage"]:
            fails.append(f"{where}: the taxon page has no lineage")
        for a in spp["lineage"]:
            if not str(a["href"]).startswith("/species/"):
                fails.append(f"{where}: lineage link {a['name']!r} does not point at a species page: {a['href']!r}")
        if spp["key"] and str(spp["key"]).startswith(("worms:", "itis:")):
            wanted = f"https://calcofi.io/explore/?taxon={spp['key']}"
            if wanted not in spp["explore"]:
                fails.append(f"{where}: the Explorer link is {spp['explore']!r}, expected {wanted}")
        if spp["stripRows"] and len(rec_rows) and spp["stripRows"] != len(rec_rows):
            fails.append(f"{where}: the years strip has {spp['stripRows']} rows for {len(rec_rows)} datasets")
        if rec_rows and spp["stripH"] < 20:
            fails.append(f"{where}: the years strip is {spp['stripH']}px tall though the record has "
                         f"{len(rec_rows)} dataset(s) — it is drawn but not displayed")
        notes.append(f"{where}: {len(rows)} dataset row(s), {len(spp['lineage'])} lineage links, "
                     f"strip {spp['stripRows']} rows / {spp['stripH']}px, stats {' · '.join(spp['stats'])}")
        # the sardine is the named regression case: its lineage, its two datasets and their counts
        if spp["key"] == "worms:217452":
            chain = [a["name"] for a in spp["lineage"]]
            wantchain = ["Biota", "Animalia", "Chordata", "Vertebrata", "Gnathostomata", "Osteichthyes",
                         "Actinopterygii", "Actinopteri", "Teleostei", "Clupeiformes", "Alosidae", "Sardinops"]
            if chain != wantchain:
                fails.append(f"{where}: the sardine's lineage reads {' › '.join(chain)}")
            if spp["here"] != "Sardinops sagax":
                fails.append(f"{where}: the lineage ends at {spp['here']!r}, expected 'Sardinops sagax'")

    # ── the face row, the sentence, the glance and the ladder (plan 2026-09-11) ─
    fa = r.get("faces")
    if fa:
        sd = fa.get("size") or {}
        # D9: the page's biggest number is "records" until the record carries n_present, and
        # "observations" (with "records" beside it) the moment it does. The word follows the
        # record, so the check reads the same field the generator does.
        words = fa["statWords"]
        if words:
            if "observations" in words and "records" not in words:
                fails.append(f"{where}: the stat says 'observations' alone — a row of obs_bio is not "
                             f"an organism; D9 wants 'records' until n_present is in the record")
            if ("observations" in words and "records" in words
                    and words.index("observations") > words.index("records")):
                fails.append(f"{where}: 'records' is drawn before 'observations' in the stat row")
        # the sentence: its parts are marked, and the legend names exactly the parts that are drawn
        parts = [p for p in fa["sentParts"] if p.startswith("s-")]
        if parts and fa["legend"] != len(parts):
            fails.append(f"{where}: the sentence has {len(parts)} marked part(s) {parts} but "
                         f"{fa['legend']} legend entries")
        if fa["sil"]:
            s = fa["sil"]
            if s["role"] != "img" or not s["label"]:
                fails.append(f"{where}: the silhouette has role={s['role']!r} aria-label={s['label']!r}")
            if s["w"] < 20 or s["h"] < 20:
                fails.append(f"{where}: the silhouette is drawn {s['w']}x{s['h']}px")
            notes.append(f"{where}: silhouette {s['w']}x{s['h']} {s['label']!r}"
                         + (f" · {fa['stand'].strip()}" if fa["stand"] else ""))
        if fa["photo"]:
            p = fa["photo"]
            if not p["alt"]:
                fails.append(f"{where}: the photo has no alt text")
            if not p["masked"]:
                fails.append(f"{where}: the photo frame carries no radial mask (§ D2)")
            if p["loading"] != "lazy":
                fails.append(f"{where}: the photo is not loading=lazy")
            if p["w"] < 40 or p["h"] < 40:
                fails.append(f"{where}: the photo is drawn {p['w']}x{p['h']}px")
            notes.append(f"{where}: photo {p['w']}x{p['h']} pos {p['pos']}"
                         + (" · NC labelled" if fa["nc"] else ""))
        # the glance: two bars, or one honest line — never a blank slot
        if fa["sil"] or fa["photo"]:
            if not fa["glanceNone"] and len(fa["bars"]) != 2:
                fails.append(f"{where}: the glance draws {len(fa['bars'])} bar(s) and does not say "
                             f"'not on record'")
            if fa["bars"] and min(fa["bars"]) < 1:
                fails.append(f"{where}: a glance bar is drawn {min(fa['bars'])}px wide")
        # the How big section: drawn exactly when the payload has something to draw
        if fa["howBig"]:
            want_marks = len(sd.get("early") or []) + (1 if sd.get("size") else 0)
            if want_marks and not fa["ladderDrawn"]:
                fails.append(f"{where}: the ladder is not drawn though the payload has {want_marks} mark(s)")
            if fa["ladderDrawn"]:
                if fa["ladderMarks"] != want_marks:
                    fails.append(f"{where}: the ladder draws {fa['ladderMarks']} mark(s) for "
                                 f"{want_marks} in the payload")
                if fa["ladderRefs"] != len(sd.get("refs") or []):
                    fails.append(f"{where}: the ladder labels {fa['ladderRefs']} reference(s) for "
                                 f"{len(sd.get('refs') or [])} in size_reference.csv")
                # no two labels may overlap: a ladder whose text collides is unreadable, and the
                # greedy row assignment in species.js is the only thing preventing it
                ls = fa["labels"]
                for i in range(len(ls)):
                    for j in range(i + 1, len(ls)):
                        a, b = ls[i], ls[j]
                        if a["g"] == b["g"] and a["g"] >= 0:
                            continue        # a reference's own name and length, stacked on purpose
                        if (a["x"] < b["x"] + b["w"] and b["x"] < a["x"] + a["w"]
                                and a["y"] < b["y"] + b["h"] and b["y"] < a["y"] + a["h"]):
                            fails.append(f"{where}: ladder labels overlap: {a['t']!r} and {b['t']!r}")
                notes.append(f"{where}: ladder {fa['ladderMarks']} marks, {fa['ladderRefs']} references, "
                             f"{len(fa['labels'])} labels, none overlapping")
            if sd.get("size") and sd.get("sil", {}) and (sd.get("sil") or {}).get("axis") and not fa["besideDrawn"]:
                fails.append(f"{where}: the beside figure is not drawn though the taxon has a length "
                             f"and the silhouette a length axis")
            if bool(sd.get("plate")) != fa["plateImg"]:
                fails.append(f"{where}: the plate is {'missing' if sd.get('plate') else 'invented'} "
                             f"(the payload's plate is {sd.get('plate') and sd['plate'].get('src')!r})")
            if fa["early"] < len(sd.get("early") or []):
                fails.append(f"{where}: {fa['early']} early-life row(s) for "
                             f"{len(sd.get('early') or [])} in the payload")
        elif sd:
            fails.append(f"{where}: a How big payload exists but no section is drawn")
        # a credit line for every asset that is shown: a picture without one is not publishable
        if fa["sil"] and not any(c.startswith("Silhouette") for c in fa["credits"]):
            fails.append(f"{where}: the silhouette is drawn with no credit line")
        if fa["photo"] and not any(c.startswith("Photo") for c in fa["credits"]):
            fails.append(f"{where}: the photo is drawn with no credit line")
        if fa["plateImg"] and not any(c.startswith("Plate") for c in fa["credits"]):
            fails.append(f"{where}: the plate is drawn with no credit line")

    # every URL row is one line, and elided from the middle rather than wrapped or simply cut off
    for u in r.get("spUrls", []):
        if u["lh"] and u["h"] > u["lh"] * 1.6:
            fails.append(f"{where}: a species URL wraps ({u['h']}px over a {u['lh']}px line): {u['t']}…")
        if u["overflow"]:
            fails.append(f"{where}: a species URL overflows its line rather than being elided: {u['t']}…")
        if u["full"] and u["shown"] < u["full"] and not u["elided"]:
            fails.append(f"{where}: a species URL is cut short without an ellipsis: {u['t']}…")

    # ── the measurements catalog (plan 2026-09-10 § D5, D6; § Verification M4) ─
    mm = r.get("mm")
    if mm:
        rec = mm["rec"] or {}
        notes.append(f"{where}: timeline {mm['tlRows']} rows / {mm['tlBars']} bars in {mm['tlCats']} categories, "
                     f"matrix {mm['mxRows']}x{mm['ds']} = {mm['mxCells']} cells ({mm['mxFilled']} with a series, "
                     f"summing {mm['mxSum']}), {mm['dsRows']} datasets, {len(mm['chips'])} chips")
        if mm["tlRows"] != rec.get("measurements"):
            fails.append(f"{where}: the timeline draws {mm['tlRows']} rows, the record has "
                         f"{rec.get('measurements')} measurements")
        if mm["tlBars"] != mm["recSeries"] or mm["tlBars"] != rec.get("series"):
            fails.append(f"{where}: the timeline draws {mm['tlBars']} bars, the record has "
                         f"{mm['recSeries']} series in rows[] and {rec.get('series')} in counts")
        if mm["tlCats"] != mm["cats"]:
            fails.append(f"{where}: {mm['tlCats']} category headings for {mm['cats']} categories")
        # the matrix is category x dataset, every cell drawn, the counts summing to the series
        if mm["mxCells"] != mm["cats"] * mm["ds"]:
            fails.append(f"{where}: the matrix has {mm['mxCells']} cells, expected "
                         f"{mm['cats']}x{mm['ds']} = {mm['cats'] * mm['ds']}")
        if mm["mxHeads"] != mm["ds"] + 1 or mm["mxRows"] != mm["cats"]:
            fails.append(f"{where}: the matrix has {mm['mxHeads']} column heads and {mm['mxRows']} row "
                         f"labels, expected {mm['ds'] + 1} and {mm['cats']}")
        if mm["mxSum"] != mm["recSeries"]:
            fails.append(f"{where}: the matrix cells sum to {mm['mxSum']}, the record has "
                         f"{mm['recSeries']} category x dataset series")
        if mm["dsRows"] != mm["ds"] or mm["legend"] != mm["ds"]:
            fails.append(f"{where}: {mm['dsRows']} dataset rows and {mm['legend']} legend entries for "
                         f"{mm['ds']} datasets")
        if mm["barsWithoutName"] > 0:
            fails.append(f"{where}: {mm['barsWithoutName']} timeline bar(s) with no dataset name in the row "
                         "— identity by colour alone")
        # the timeline is wider than a phone ON PURPOSE: its own container must scroll, not the page
        if mm["tlWidth"] > mm["tlScroller"] and mm["tlOverflowX"] not in ("auto", "scroll"):
            fails.append(f"{where}: the timeline is {mm['tlWidth']}px in a {mm['tlScroller']}px container "
                         f"whose overflow-x is {mm['tlOverflowX']}")
        if mm["tlRole"] != "table":
            fails.append(f"{where}: the timeline's role is {mm['tlRole']!r}, expected 'table'")
        if mm["tipRole"] != "tooltip":
            fails.append(f"{where}: the tooltip's role is {mm['tipRole']!r}, expected 'tooltip'")
        chips = mm["chips"]
        if not chips or chips[0]["cat"] != "" or chips[0]["n"] != rec.get("measurements"):
            fails.append(f"{where}: the first chip is not 'all' with the record's {rec.get('measurements')}")
        if sum(c["n"] for c in chips[1:]) != rec.get("measurements"):
            fails.append(f"{where}: the category chips count {sum(c['n'] for c in chips[1:])}, the record "
                         f"has {rec.get('measurements')} measurements")
        if not any(c["pressed"] == "true" for c in chips):
            fails.append(f"{where}: no chip carries aria-pressed=true")
        s = mm.get("search") or {}
        notes.append(f"{where}: search " + " · ".join(f"{t}: {v['rows']}" for t, v in s.items()))
        for term in ("nitrate", "NTRAZZXX", "µmol/kg", "METS"):
            if s.get(term, {}).get("rows", 0) < 1:
                fails.append(f"{where}: the index search finds nothing for {term!r}")

    mp = r.get("mmPage")
    if mp:
        notes.append(f"{where}: strip {mp['stripRows']} rows / {mp['stripRects']} year cells / {mp['stripH']}px, "
                     f"depth {mp['depthBands']} bands x {mp['recRows']} series = {mp['depthBars']} bars, "
                     f"months {mp['monthCells']} cells, {len(mp['rows'])} series rows")
        if not mp["stripDrawn"] or mp["stripH"] < 20:
            fails.append(f"{where}: the years strip is not drawn (.mm-drawn {mp['stripDrawn']}, "
                         f"{mp['stripH']}px tall)")
        if mp["stripRows"] != mp["recRows"]:
            fails.append(f"{where}: the strip labels {mp['stripRows']} rows, the record has {mp['recRows']} series")
        if mp["stripRects"] != mp["recRects"]:
            fails.append(f"{where}: the strip draws {mp['stripRects']} year cells, the record counts "
                         f"{mp['recRects']} years with a value")
        if mp["depthBands"] != mp["recBands"] or mp["depthBars"] != mp["recBands"] * mp["recRows"]:
            fails.append(f"{where}: the depth bars draw {mp['depthBands']} bands x {mp['depthBars']} bars, "
                         f"the record has {mp['recBands']} bands x {mp['recRows']} series")
        if mp["depthLabelsOut"]:
            fails.append(f"{where}: {mp['depthLabelsOut']} depth-bar end label(s) hang outside their column")
        if mp["recRows"] > 1 and mp["depthLegend"] != mp["recRows"]:
            fails.append(f"{where}: {mp['depthLegend']} legend entries for {mp['recRows']} series "
                         "— two series need a legend")
        if mp["monthCells"] != 12 * mp["monthRows"] or mp["monthLetters"] != 12:
            fails.append(f"{where}: the month strip draws {mp['monthCells']} cells and {mp['monthLetters']} "
                         f"letters, expected {12 * mp['monthRows']} and 12")
        if len(mp["rows"]) != mp["recRows"] or not all(x["dot"] and x["name"] for x in mp["rows"]):
            fails.append(f"{where}: the Measured-in rows are {mp['rows']!r}, the record has {mp['recRows']} series")
        if mp["key"] == "temperature" and f"/explore/?var=temperature" not in " ".join(mp["explore"]):
            fails.append(f"{where}: the Explorer link does not open prefilled on the key: {mp['explore']!r}")

    for u in r.get("mmUrls", []):
        if u["lh"] and u["h"] > u["lh"] * 1.6:
            fails.append(f"{where}: a measurement URL wraps ({u['h']}px over a {u['lh']}px line): {u['t']}…")
        if u["overflow"]:
            fails.append(f"{where}: a measurement URL overflows its line rather than being elided: {u['t']}…")
        if u["full"] and u["shown"] < u["full"] and not u["elided"]:
            fails.append(f"{where}: a measurement URL is cut short without an ellipsis: {u['t']}…")

    # ── the front door (plan 2026-09-07 § D-8) ────────────────────────────────
    fr = r.get("front")
    if fr:
        notes.append(f"{where}: hero {fr['svgVh']}vh, copy {'over the sky' if fr['copyAbs'] else 'stacked'} "
                     f"ending at y {fr['copyBottomUnits']:.0f}/200, {len(fr['pins'])} pins, strip {fr['stripRows']} rows, "
                     f"map {fr['mapMarks']} marks, worst tile stretch "
                     f"{max((t['ratio'] for t in fr['tiles']), default=1)}x")
        if width >= 1400 and fr["svgVh"] > MAX_HERO_VH:
            fails.append(f"{where}: the hero's drawing is {fr['svgVh']}vh, max {MAX_HERO_VH}")
        if fr["copyOverlapsShip"]:
            fails.append(f"{where}: the hero copy overlaps the ship's bounding box")
        if fr["copyAbs"] and fr["copyBottomUnits"] > 200:
            fails.append(f"{where}: the hero copy ends at drawing y {fr['copyBottomUnits']:.0f}, below the surface (200)")
        for t in fr["tiles"]:
            if t["ratio"] > MAX_TILE_STRETCH:
                fails.append(f"{where}: tile {t['name'].strip()!r} drawn {t['drawn']}px for {t['natural']}px of content ({t['ratio']}x)")
        n = fr.get("reachNumbers") or {}
        # the band (plan 2026-09-09 § D9): years · cruises · stations · species · organism obs. ·
        # measurements. `ships` left the band for the hero's eyebrow and `rows` for the release strip
        # and the release tile — a "row" is 78 % one full-resolution CTD table and counts the `obs`
        # compatibility copy twice, so it says nothing about what CalCOFI holds. The keys are the
        # dt's leading words; the value is the dd, parsed.
        want = {"years": n.get("years"), "cruises": n.get("cruises"), "stations": n.get("stations"),
                "species": n.get("species"), "organism obs": n.get("organism_obs_m"),
                "measurements": n.get("measurements_m")}
        seen = {}
        for b in fr["band"]:
            key = next((k for k in want if b["label"].startswith(k)), None)
            if key:
                seen[key] = float(b["value"].replace(",", "").replace(" M", ""))
        for k, v in want.items():
            if v is None:
                continue          # the record cannot supply it: the tile must be absent, and is
            if k not in seen:
                fails.append(f"{where}: the numbers band has no {k!r} tile though the record carries {v}")
            elif seen[k] != v:
                fails.append(f"{where}: the band says {k} = {seen[k]:g}, the record says {v}")
        for k in seen:
            if want.get(k) is None:
                fails.append(f"{where}: the band shows {k!r} = {seen[k]:g} but the record carries no value")
        # both are sums over the same catalog tables[] the release's total_rows is summed from, so
        # neither the band nor a future re-cut of `numbers` can claim more rows than the release has
        mm, om, rm = n.get("measurements_m"), n.get("organism_obs_m"), n.get("rows_m")
        if None not in (mm, om, rm) and mm + om > rm:
            fails.append(f"{where}: measurements {mm} M + organism observations {om} M "
                         f"exceed the release's {rm} M rows")
        if fr["datasets"] is not None and fr["stripRows"] != fr["datasets"]:
            fails.append(f"{where}: the years strip has {fr['stripRows']} rows for {fr['datasets']} datasets")
        if fr["stations"] is not None and fr["mapMarks"] != fr["stations"]:
            fails.append(f"{where}: the map has {fr['mapMarks']} marks for {fr['stations']} grid cells")
        if fr["warnEls"]:
            fails.append(f"{where}: --warn on the first screen: {', '.join(sorted(set(fr['warnEls']))[:4])}")
        if len(fr["ctaEls"]) != 1:
            fails.append(f"{where}: {len(fr['ctaEls'])} yellow (--cta-bg) elements on the first screen, expected exactly one")
        # ── D7: the band's two counted things are doors ──────────────────────
        want_link = {"species": True, "measurements": True}
        for b in r.get("bandLinks") or []:
            key = next((k for k in want_link if b["label"].startswith(k)), None)
            if key and not b["href"]:
                fails.append(f"{where}: the band's {key!r} number is not a link")

        # ── D7: the Observed tile shows both counted rows and spills nothing ──
        ob = r.get("observed")
        if ob:
            notes.append(f"{where}: observed tile {len(ob['rows'])} rows, "
                         f"overflow {ob['overflow']}px, {ob['spill']} spilling children")
            if len(ob["rows"]) < 2:
                fails.append(f"{where}: the Observed tile draws {len(ob['rows'])} rows, expected species and measurements")
            if any(not h for h in ob["links"]):
                fails.append(f"{where}: an Observed row has no way in")
            if ob["overflow"] > 2 or ob["spill"]:
                fails.append(f"{where}: the Observed tile overflows its cell "
                             f"({ob['overflow']}px, {ob['spill']} children outside)")

        # ── D7: the Data section must not grow by a screen ────────────────────
        h = r.get("dataSectionH")
        if h is not None and width >= 1400:
            notes.append(f"{where}: the Data section is {h}px (main measured {DATA_SECTION_BASE}px)")
            if h > DATA_SECTION_BASE + DATA_SECTION_GROWTH:
                fails.append(f"{where}: the Data section is {h}px, more than "
                             f"{DATA_SECTION_GROWTH}px taller than main's {DATA_SECTION_BASE}px")

        if width >= 1400 and theme == "light":      # once per run
            for href in fr["pins"]:
                ok = url_ok(href)
                if ok is None:
                    notes.append(f"{where}: pin {href} unreachable (warning only)")
                elif not ok:
                    fails.append(f"{where}: pin {href} does not answer 200/206")

    # ── the header: six words, calcofi.org, and the submenus (plan 2026-09-10 § D7) ────────────
    nav = r.get("nav")
    if nav and nav["visible"]:
        notes.append(f"{where}: header {' · '.join(nav['words'])}; "
                     f"{len(nav['menus'])} submenus ({', '.join(m['word'] + ' ' + str(len(m['tabs'])) for m in nav['menus'])})")
        if nav["words"] != NAV_WORDS:
            fails.append(f"{where}: the header reads {nav['words']}, expected {NAV_WORDS}")
        for m in nav["menus"]:
            if not m["haspopup"]:
                fails.append(f"{where}: the {m['word']!r} submenu's trigger has no aria-haspopup")
            if not m["closed"]:
                fails.append(f"{where}: the {m['word']!r} submenu is open before anything is focused")
            if not m["opensOnFocus"]:
                fails.append(f"{where}: the {m['word']!r} submenu does not open on focus — it is not keyboard-reachable")
            if not m["closesOnEscape"]:
                fails.append(f"{where}: the {m['word']!r} submenu does not close on Escape")
            for t in m["tabs"]:
                # an item either names a homepage tab (data-go) or links the catalog's own page — Species and
                # Measurements go to /species/ and /measurements/ because the homepage only carries their heads
                # (Ben, 2026-09-10); a hash href with no data-go would land on the section and select nothing
                if not t["go"] and (not t.get("href") or "#" in t["href"]):
                    fails.append(f"{where}: the {m['word']!r} submenu's {t['title']!r} neither names a tab (data-go) nor links a page")
                if not t["pill"]:
                    fails.append(f"{where}: the {m['word']!r} submenu's {t['title']!r} carries no count")
            # the hover bridge: the list's ::before must span the gap below the trigger (Ben, 2026-09-10 —
            # the live menu closed as soon as the pointer moved down to pick an item)
            if m.get("gap") is not None and (m.get("bridge") or 0) < m["gap"]:
                fails.append(f"{where}: the {m['word']!r} submenu floats {m['gap']:.0f}px below its trigger but its hover "
                             f"bridge is {(m.get('bridge') or 0):.0f}px — the pointer leaves the menu on its way down")
        for m in nav["menus"]:
            if m["word"].lower() == "data":
                for t in m["tabs"]:
                    want = {"species": "/species/", "measurements": "/measurements/"}.get(t["title"].split()[0].lower())
                    if want and r.get("pageExists", {}).get(want) and (t.get("href") or "").rstrip("/") + "/" != want:
                        fails.append(f"{where}: the DATA submenu's {t['title']!r} links {t.get('href')!r}, not {want} (the page exists)")
    elif nav and width < 900:
        notes.append(f"{where}: the header nav is hidden (the brand hides it under 480px); the phone menu carries it")

    # ── the phone menu: the hamburger under 480 px (Ben, 2026-09-10: "NO menu in the mobile version") ─
    pm = r.get("phoneMenu")
    if width < 480:
        if not pm or not pm["buttonShown"]:
            fails.append(f"{where}: no phone menu button under 480px, where the brand hides the nav")
        else:
            if not pm["opened"]:
                fails.append(f"{where}: the phone menu button does not open the nav")
            if pm["expanded"] != "true":
                fails.append(f"{where}: the phone menu button's aria-expanded does not follow the menu (read {pm['expanded']!r})")
            if pm["wordsOpen"] != len(NAV_WORDS):
                fails.append(f"{where}: the phone menu shows {pm['wordsOpen']} items, expected {len(NAV_WORDS)}")
            if nav and pm["subsOpen"] != len(nav["menus"]):
                fails.append(f"{where}: the phone menu shows {pm['subsOpen']} of {len(nav['menus'])} submenus inline")
            if pm["scrollW"] and pm["scrollW"] > width:
                fails.append(f"{where}: the open phone menu scrolls horizontally — scrollWidth {pm['scrollW']} > {width}")
            if not pm["closedOnEsc"]:
                fails.append(f"{where}: the phone menu does not close on Escape")
            if not fails or not any(where in f and "phone menu" in f for f in fails):
                notes.append(f"{where}: the phone menu opens with {pm['wordsOpen']} items and {pm['subsOpen']} submenus inline, no horizontal scroll, closes on Escape")
    elif pm and pm["buttonShown"]:
        fails.append(f"{where}: the phone menu button is visible at {width}px; it belongs under 480px only")

    # ── the sticky section bar: the four ON-PAGE sections, each counted ────────────────────────
    secs = r.get("sections")
    if secs is not None:
        got = [s["title"] for s in secs]
        notes.append(f"{where}: section bar {' · '.join(s['title'] + ' ' + s['n'] for s in secs)}")
        if got != SECTION_WORDS:
            fails.append(f"{where}: the section bar reads {got}, expected {SECTION_WORDS}")
        for s in secs:
            if not s["n"]:
                fails.append(f"{where}: the section bar's {s['title']!r} carries no count")

    # ── the tabsets: one selected tab, one drawn panel, and a pill that is the panel's own count ─
    for ts in r.get("tabsets") or []:
        sel = [t for t in ts["tabs"] if t["selected"]]
        drawn = [t for t in ts["tabs"] if not t["hidden"]]
        notes.append(f"{where}: {ts['id']} " + " · ".join(f"{t['title']}" + (f" [{t['cards']} cards]" if t["cards"] else "")
                                                          for t in ts["tabs"]))
        if len(sel) != 1:
            fails.append(f"{where}: {ts['id']} has {len(sel)} selected tabs, expected exactly one")
        if len(drawn) != 1:
            fails.append(f"{where}: {ts['id']} draws {len(drawn)} panels, expected exactly one")
        if sel and drawn and sel[0]["id"] != drawn[0]["id"]:
            fails.append(f"{where}: {ts['id']} selects {sel[0]['id']!r} but draws {drawn[0]['id']!r}")
        if ts["id"] in CARD_TABSETS:
            for t in ts["tabs"]:
                pill = int(str(t["pill"] or "0").replace(",", ""))
                if pill != t["cards"]:
                    fails.append(f"{where}: {ts['id']} tab {t['id']!r} says {pill} but its panel holds {t['cards']} cards")

    # ── the one search over the three indexes ──────────────────────────────────────────────────
    # "sardine" is a species, "nitrate" a measurement AND a dataset's variables, "CUFES" a dataset;
    # "TEMPPR01" is a NERC id that only the measurements RECORD carries, so it is expected to find
    # nothing until WS-M3 ships and is reported, not failed.
    se = r.get("search")
    if se and "error" not in se:
        for term, res in se.items():
            groups = [g.split(" ")[0] for g in res["groups"]]
            notes.append(f"{where}: search {term!r} → {res['hits']} rows in {', '.join(groups) or 'nothing'}")
        for term, want in (("sardine", "Species"), ("nitrate", "Measurements"), ("CUFES", "Datasets")):
            res = se.get(term)
            if not res:
                continue
            if not res["open"]:
                fails.append(f"{where}: the door search did not open for {term!r}")
            if not any(g.startswith(want) for g in res["groups"]):
                fails.append(f"{where}: the door search found no {want} for {term!r} "
                             f"(groups: {res['groups']})")
        p01 = se.get("TEMPPR01")
        if p01 and not p01["groups"]:
            notes.append(f"{where}: 'TEMPPR01' finds nothing — the measurements RECORD carries the "
                         f"NERC ids and no release has one yet (WS-M2/M3)")
    elif se:
        fails.append(f"{where}: the door search errored: {se['error']}")


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--base", default="http://localhost:4000", help="site root (default localhost:4000)")
    ap.add_argument("--url", action="append", help="a full URL to check (repeatable); replaces the defaults")
    ap.add_argument("--widths", nargs="+", type=int, default=[1470, 375])
    ap.add_argument("--themes", nargs="+", default=["light", "dark"])
    ap.add_argument("--browser", default="chromium")
    ap.add_argument("--wait", type=int, default=2500, help="ms to settle (fonts, masonry) before measuring")
    a = ap.parse_args()

    urls = a.url or [a.base.rstrip("/") + p for p in DEFAULT_PATHS]
    fails, notes = [], []
    for url in urls:
        for width in a.widths:
            for theme in a.themes:
                r = probe(url, width, theme, a.browser, a.wait)
                if "error" in r:
                    fails.append(f"{url} @{width}px {theme}: {r['error']}")
                    print(f"ERROR {url} @{width} {theme}: {r['error']}")
                    continue
                before = len(fails)
                check(url, r, width, theme, fails, notes)
                print(f"{'FAIL' if len(fails) > before else 'ok  '} {url} @{width}px {theme}")

    if notes:
        print("\nmeasured:")
        for n in notes:
            print(f"  {n}")
    if fails:
        print(f"\n{len(fails)} FAILURE(S):")
        for f in fails:
            print(f"  {f}")
        sys.exit(1)
    print("\nall layout assertions pass")


if __name__ == "__main__":
    main()
