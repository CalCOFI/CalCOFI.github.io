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
  front door (/, plan 2026-09-07 § D-8) the hero's SVG is drawn <= 62 vh at 1470 and the copy's
             text does not overlap the ship's bounding box; no .tile is drawn > 1.25 x its natural
             height; the numbers on the band equal the inline #reach record's; the years strip has
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

  // one ERDDAP listing: count each tabledap page link
  const tabledap = {};
  [...d.querySelectorAll('a[href*="tabledap/"]')].forEach(a => {
    const m = /tabledap\/([^.?#\/]+)\.html(?:$|[?#])/.exec(a.getAttribute("href") || "");
    if (m) tabledap[m[1]] = (tabledap[m[1]] || 0) + 1;
  });
  out.tabledap = tabledap;
  return out;
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
        want = {"years": n.get("years"), "cruises": n.get("cruises"), "ships": n.get("ships"), "stations": n.get("stations"),
                "taxa": n.get("taxa"), "rows": n.get("rows_m")}
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
        if fr["datasets"] is not None and fr["stripRows"] != fr["datasets"]:
            fails.append(f"{where}: the years strip has {fr['stripRows']} rows for {fr['datasets']} datasets")
        if fr["stations"] is not None and fr["mapMarks"] != fr["stations"]:
            fails.append(f"{where}: the map has {fr['mapMarks']} marks for {fr['stations']} grid cells")
        if fr["warnEls"]:
            fails.append(f"{where}: --warn on the first screen: {', '.join(sorted(set(fr['warnEls']))[:4])}")
        if len(fr["ctaEls"]) != 1:
            fails.append(f"{where}: {len(fr['ctaEls'])} yellow (--cta-bg) elements on the first screen, expected exactly one")
        if width >= 1400 and theme == "light":      # once per run
            for href in fr["pins"]:
                ok = url_ok(href)
                if ok is None:
                    notes.append(f"{where}: pin {href} unreachable (warning only)")
                elif not ok:
                    fails.append(f"{where}: pin {href} does not answer 200/206")


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
