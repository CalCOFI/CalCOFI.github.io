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
  url        (dataset pages) no .ds-url is taller than one line at 375 px. A URL in a right-hand
             table column wrapped to five lines on a phone.
  erddap     (dataset pages) each ERDDAP dataset id's tabledap page appears exactly once. It was
             listed twice: once under Download for its formats, once under Services for its page.

Lighthouse is NOT run here (it needs its own Chrome and ~30 s a page); README says how, and
.github/workflows/check-brand.yml runs this script weekly and on a pull request.

Needs shot-scraper (`pipx install shot-scraper && shot-scraper install`).
"""
import argparse, json, subprocess, sys

DEFAULT_PATHS = [
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
