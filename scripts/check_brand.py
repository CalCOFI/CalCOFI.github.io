#!/usr/bin/env python3
"""Check every live calcofi.io product against the brand contract it wears: brand/v3/README.md for a
product on v3 (2026-11-17: the header's words, sentence case, the wave), brand/v2/README.md for one still
on v2 (frozen, not wrong; v1 superseded 2026-09-04).

    scripts/check_brand.py                 # every product in _data/products.yml
    scripts/check_brand.py db-schema erddap
    scripts/check_brand.py --required-only # only products that must pass (shots: themed)
    scripts/check_brand.py --url http://localhost:4000/v2/   # one URL, held to the required level (a preview)
    scripts/check_brand.py --url … --force-version 3         # hold a page to v3 whatever it says it wears

For each product's live_url, a headless browser opens  ?theme=light  and  ?theme=dark
(appending to any existing query string) and reports:
  theme     <html data-theme> equals the requested theme both times  — the page runs theme.js
  favicon   a <link rel="icon"> whose href returns 200                — and it is the CalCOFI set
            (or the product's own designed mark for the two exceptions)
  home      an <a href="https://calcofi.io"> in the page chrome       — the far-left back-link
  toggle    a .cc-theme-toggle / bslib dark-mode switch / framework light-switch exists
  ver       window.ccTheme.version — "3" and "2" are contracts in force; "1" is reported as a WARNING
  dflt      a third probe with NO ?theme= in a fresh context: a v2 or v3 product must open LIGHT with
            the fonts loaded (document.fonts.check('16px "Source Sans 3"')) and the lockup <img> present

and, for a product on v3 only (a v2 product shows "-": its header is v2's, uppercase, its own words):
  nav       the bar's words are the brand's ONE list, in order: nav.json beside the header.js the page
            loads (so a preview is held to its own copy, the live site to calcofi.io's)
            ("-" too where a framework owns the bar — Quarto, pkgdown, mkdocs, bslib: brand v3 § 6 holds
            that one to the wave and the case, not to the markup; so nav and menu are not asked of it)
  case      sentence case: computed text-transform none on every word of the bar and on .cc-title
  wave      exactly one .cc-wave band is drawn and it starts where the bar ends
  menu      in a 1099 px window (one under NAV_BREAK) the menu button is shown and the nav is not

A product declared `shots: themed` in products.yml MUST pass all of them (exit 1 otherwise), each failure
printed with what was measured; everything else is reported for information (student work, third-party
hosts, not yet migrated). Consistency is checked here weekly (.github/workflows/check-brand.yml), not assumed.

Needs shot-scraper (`pipx install shot-scraper && shot-scraper install`).
"""
import argparse, json, re, subprocess, sys, urllib.error, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OWN_MARK = {"calcofi4r", "calcofi4py"}   # designed exceptions: their own favicon
# shot-scraper awaits a returned promise, which is how the Shiny apps get their settle time
JS = r"""
new Promise(done => setTimeout(() => done((() => {
  const d = document.documentElement;
  const icons = [...document.querySelectorAll('link[rel~="icon"]')].map(l => l.href);
  const home  = !!document.querySelector('a[href="https://calcofi.io"], a[href="https://calcofi.io/"]');
  const toggle = !!document.querySelector('.cc-theme-toggle, [data-cc-theme-toggle], #theme-toggle, bslib-input-dark-mode, .quarto-color-scheme-toggle, [data-md-color-scheme] .md-header__option, .dropdown-item[data-bs-theme-value], button[aria-label*="Switch to"]');
  const fonts = !!(document.fonts && document.fonts.check('16px "Source Sans 3"'));
  const lockup = !!document.querySelector('img[src*="logo_calcofi_h"]');
  const version = (window.ccTheme && window.ccTheme.version) || null;
  // brand v3: the header's words and their case, the script that drew them, the wave under the bar
  const cs = el => getComputedStyle(el), drawn = el => cs(el).display !== "none" && cs(el).visibility !== "hidden" && el.getBoundingClientRect().height > 0;
  // the bar is the brand's own (.cc-header) or, where a framework owns it (Quarto, pkgdown, mkdocs, bslib:
  // brand v3 § 6), the framework's navbar: that one is held to the wave and the case, not to the markup
  const hdr = document.querySelector(".cc-header"), nav = hdr && hdr.querySelector(".cc-links:not(.cc-viewnav)");  // not the catalog menu beside the logo (Datasets ▾, Species ▾, Measurements ▾)
  const fw = hdr ? null : document.querySelector("#quarto-header, header.md-header, nav.navbar, .navbar, body > header");
  const words = nav ? [...nav.children].filter(el => el.matches("a, .cc-m2, .cc-m")).map(el => el.matches("a") ? el : el.querySelector(":scope > .cc-m2-t, :scope > a")).filter(Boolean)
    : fw ? [...fw.querySelectorAll("a.nav-link, .navbar-nav a, .md-tabs__link, a.dropdown-toggle")].filter(drawn) : [];
  const bar = hdr || fw, title = bar && bar.querySelector(".cc-title, .navbar-title, .navbar-brand");
  const hjs = [...document.scripts].map(x => x.src).find(x => /\/brand\/v3\/header\.js(\?|$)/.test(x)) || null;
  const v3 = {
    header: !!hdr, framework: !hdr && !!fw, headerJs: hjs, headerVersion: (window.ccHeader && window.ccHeader.version) || null,
    navState: nav ? nav.getAttribute("data-cc-nav-state") : null, navClass: nav ? String(nav.className) : null,
    words: words.map(el => el.textContent.replace(/\s+/g, " ").trim()),
    cased: words.map(el => cs(el).textTransform).concat(title ? [cs(title).textTransform] : []),
    headerBottom: bar ? Math.round(bar.getBoundingClientRect().bottom + scrollY) : null,
    waves: [...document.querySelectorAll(".cc-wave")].filter(drawn).map(el => ({cls: String(el.className), top: Math.round(el.getBoundingClientRect().top + scrollY), h: Math.round(el.getBoundingClientRect().height)}))
  };
  return {theme: d.dataset.theme || null, bs: d.getAttribute("data-bs-theme"), icons, home, toggle, version, fonts, lockup, title: document.title, href: location.href, v3};
})()), WAIT_MS))
"""

# brand v3 § 4.3: under NAV_BREAK (1100 px) the menu button carries the words. `shot-scraper javascript` has
# no --width, so the page is loaded again in a same-origin iframe one pixel under the breakpoint and read there.
NAV_BREAK = 1100
JS_NARROW = r"""
new Promise(done => {
  const f = document.createElement("iframe");
  f.style.cssText = "position:fixed;left:0;top:0;border:0;width:NARROW_Wpx;height:800px";
  f.src = location.href;
  f.onload = () => setTimeout(() => {
    try {
      const d = f.contentDocument, w = f.contentWindow;
      const shown = el => !!el && w.getComputedStyle(el).display !== "none" && el.getBoundingClientRect().width > 0;
      const hdr = d.querySelector(".cc-header");
      done({width: w.innerWidth, header: !!hdr, button: shown(hdr && hdr.querySelector(".cc-menu-button")), nav: shown(hdr && hdr.querySelector(".cc-links:not(.cc-viewnav)"))});
    } catch (e) { done({error: String(e)}); }
  }, WAIT_MS);
  document.body.appendChild(f);
})
"""


def nav_json_url(header_js):
    """the nav.json a page's header is drawn from: the file beside the brand/v3/header.js it loads"""
    if not header_js:
        return None
    return re.sub(r"[^/]*$", "", header_js.split("?")[0].split("#")[0]) + "nav.json"


def nav_titles(obj):
    """the words' titles of a nav.json, in order"""
    return [w.get("title") for w in (obj or {}).get("words") or []]


def nav_yml_titles(text):
    """the words' titles of a _data/nav.yml text, in order (the top-level `words:` entries; a block
    `  - id: data` / `    title: Data`, or one line `  - { id: cite, title: Cite, … }`). The repo's own
    list: what a page that loads no brand/v3/header.js at all is held to under --force-version 3."""
    out, m = [], re.search(r"^words:\s*$", text or "", re.M)
    for blk in re.split(r"^(?=  - )", (text or "")[m.end():], flags=re.M) if m else []:
        if not blk.startswith("  - "):
            continue
        first = blk.splitlines()[0]
        tt = (re.search(r"\btitle:\s*(\"[^\"]*\"|'[^']*'|[^,}]+)", first) if "{" in first
              else re.search(r"^(?:  - |    )title:\s*(.+?)\s*$", blk, re.M))
        if tt:
            out.append(tt.group(1).strip().strip("\"'"))
    return out


def brand_words(header_js, origin=None):
    """(the brand's words a page is held to, where they were read): nav.json beside the header.js the
    page loads; a page that loads none (--force-version 3 on a v2 page) is held to its own origin's
    /brand/v3/nav.json if it serves one, else to this repo's _data/nav.yml"""
    tried = [nav_json_url(header_js)] if header_js else []
    if origin:
        tried.append(origin + "/brand/v3/nav.json")
    for u in tried:
        t = nav_titles(fetch_json(u))
        if t:
            return t, u
    if not header_js:
        try:
            t = nav_yml_titles((ROOT / "_data/nav.yml").read_text(encoding="utf-8"))
        except OSError:
            t = []
        if t:
            return t, "_data/nav.yml"
    return None, (tried[0] if tried else None)


def judge_v3(v3, narrow, titles):
    """brand v3's own four assertions on one page: ({nav, case, wave, menu: bool or None}, [what was
    measured, for each that failed]). `v3` is the page's probe (JS above), `narrow` the 1099 px probe,
    `titles` the brand's words (nav.json), None when the list could not be read. A bar a framework owns
    (v3.framework: no .cc-header, brand v3 § 6) is held to the wave and the case only: nav and menu are None."""
    v3, narrow, why = v3 or {}, narrow or {}, []
    words, fw = v3.get("words") or [], bool(v3.get("framework"))
    nav = None if fw else (bool(titles) and words == titles)
    if nav is False and not titles:
        why.append(f"nav: no nav.json to hold the words to (the page loads header.js from {v3.get('headerJs')!r})")
    elif nav is False:
        why.append(f"nav: the bar reads {words}, the brand's words are {titles}")
    cased = v3.get("cased") or []
    case = bool(cased) and all(c == "none" for c in cased)
    if not case:
        why.append(f"case: text-transform on the bar's words and title is {sorted(set(cased)) or 'unread (no words)'}, expected none (sentence case)")
    waves, hb = v3.get("waves") or [], v3.get("headerBottom")
    wave = len(waves) == 1 and hb is not None and abs(waves[0]["top"] - hb) <= 1
    if not wave:
        why.append(f"wave: {len(waves)} .cc-wave band(s) drawn"
                   + (f", starting {[x['top'] for x in waves]}px under a bar that ends {hb}px" if waves else ", none under the bar"))
    menu = None if fw else (bool(narrow.get("button")) and not narrow.get("nav") and "error" not in narrow)
    if menu is False:
        why.append(f"menu: at {narrow.get('width', NAV_BREAK - 1)}px the menu button is {'shown' if narrow.get('button') else 'not shown'} "
                   f"and the nav is {'shown' if narrow.get('nav') else 'not shown'}"
                   + (f" ({narrow['error']})" if narrow.get("error") else ""))
    return {"nav": nav, "case": case, "wave": wave, "menu": menu}, why


def fetch_json(url):
    try:
        with urllib.request.urlopen(urllib.request.Request(url, headers={"User-Agent": "calcofi-check-brand"}), timeout=20) as resp:
            return json.loads(resp.read().decode("utf-8")) if resp.status == 200 else None
    except Exception:  # noqa: BLE001
        return None


def with_param(url, kv):
    return f"{url}{'&' if '?' in url else '?'}{kv}"


def probe(url, wait, browser, js=JS):
    cmd = ["shot-scraper", "javascript", url, js.replace("WAIT_MS", str(wait)).replace("NARROW_W", str(NAV_BREAK - 1)), "--browser", browser]
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=180)
    if r.returncode:
        return {"error": (r.stderr or r.stdout).strip().splitlines()[-1:][0] if (r.stderr or r.stdout).strip() else "shot-scraper failed"}
    try:
        return json.loads(r.stdout)
    except json.JSONDecodeError:
        return {"error": f"unparseable: {r.stdout[:80]!r}"}


def status(url):
    try:
        req = urllib.request.Request(url, headers={"Range": "bytes=0-0", "User-Agent": "calcofi-check-brand"})
        with urllib.request.urlopen(req, timeout=20) as resp:
            return resp.status
    except urllib.error.HTTPError as e:
        return e.code
    except Exception:
        return None


def probe_theme(url, theme, wait, browser):
    """Probe url?theme=…; if a redirect dropped the query string (erddap.calcofi.io/ →
    /erddap/index.html), probe the landing URL again with the parameter re-applied."""
    r = probe(with_param(url, f"theme={theme}&tour=off"), wait, browser)
    if "error" not in r and "theme=" not in (r.get("href") or "") and r.get("href"):
        r = probe(with_param(r["href"].split("#")[0], f"theme={theme}&tour=off"), wait, browser)
    return r


def check(p, browser, force=None):
    url = p["live_url"]
    wait = 12000 if "app.calcofi.io" in url else 4000
    light = probe_theme(url, "light", wait, browser)
    if "error" in light:
        return {"error": light["error"]}
    dark = probe_theme(url, "dark", wait, browser)
    # the default: no ?theme=, fresh context (shot-scraper's is) — v2 and v3 must open light with fonts + lockup
    dflt = probe(with_param(url, "tour=off"), wait, browser)
    version = str(light.get("version") or dflt.get("version") or "")
    held = force or version
    icons = light.get("icons") or []
    icon_ok = any((status(i) or 0) in (200, 206) for i in icons)
    if p["key"] not in OWN_MARK:
        icon_ok = icon_ok and any("calcofi.io/brand/" in i or "favicon" in i for i in icons)
    r = {
        "theme":   light.get("theme") == "light" and dark.get("theme") == "dark",
        "favicon": icon_ok,
        "home":    bool(light.get("home")),
        "toggle":  bool(light.get("toggle")),
        "version": version,
        "dflt":    held not in ("2", "3") or (dflt.get("theme") == "light" and bool(dflt.get("fonts")) and bool(dflt.get("lockup"))),
        "title":   light.get("title"),
        "nav": None, "case": None, "wave": None, "menu": None, "why": [],
    }
    if held == "3":
        # the words are held to the nav.json beside the header.js the page itself loads; the wave and
        # the case in both themes; the menu button one pixel under the breakpoint
        v3 = light.get("v3") or {}
        om = re.match(r"https?://[^/]+", light.get("href") or url)
        titles, src = brand_words(v3.get("headerJs"), om.group(0) if om else None)
        narrow = None if v3.get("framework") else probe((light.get("href") or with_param(url, "theme=light&tour=off")).split("#")[0], wait, browser, js=JS_NARROW)
        got, why = judge_v3(v3, narrow, titles)
        got_dark, why_dark = judge_v3(dark.get("v3"), narrow, titles)
        for k in ("nav", "case", "wave"):
            if got[k] and got_dark[k] is False:
                got[k] = False
                why += [f"(dark) {x}" for x in why_dark if x.startswith(k + ":")]
        why = [x + (f" ({src})" if x.startswith("nav:") and titles else "") for x in why]
        if version != "3":
            why.insert(0, f"ver: the page says ccTheme.version {version or None!r}; it is held to v3 (--force-version)")
        r.update(got, why=why)
    return r


V3_KEYS = ("nav", "case", "wave", "menu")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("keys", nargs="*")
    ap.add_argument("--required-only", action="store_true")
    ap.add_argument("--browser", default="chromium", help="shot-scraper browser (chromium is enough: no WebGL needed)")
    ap.add_argument("--url", help="check this one URL instead of products.yml, at the required level (a preview page, a local build)")
    ap.add_argument("--force-version", choices=("2", "3"),
                    help="hold every page checked to this contract whatever ccTheme.version it reports (to show what a v2 page lacks of v3)")
    a = ap.parse_args()

    if a.url:
        products = [{"key": "url", "live_url": a.url, "shots": "themed"}]
    else:
        import yaml   # only products.yml needs it: the pure rules above run (and are tested) as a bare python3
        products = yaml.safe_load((ROOT / "_data/products.yml").read_text())["products"]
    if a.keys:
        products = [p for p in products if p["key"] in a.keys]
    if a.required_only:
        products = [p for p in products if p.get("shots") == "themed"]
    if not products:
        sys.exit("nothing to check")

    fails, warns, whys = [], [], []
    print(f"{'product':28s} {'req':3s} {'theme':5s} {'icon':4s} {'home':4s} {'tog':3s} {'ver':3s} {'dflt':4s} {'nav':4s} {'case':4s} {'wave':4s} {'menu':4s}  title")
    for p in products:
        req = p.get("shots") == "themed"
        r = check(p, a.browser, a.force_version)
        if "error" in r:
            print(f"{p['key']:28s} {'*' if req else ' ':3s} ERROR {r['error'][:70]}")
            if req: fails.append(p["key"])
            continue
        ok = all(r[k] for k in ("theme", "favicon", "home", "toggle", "dflt")) and all(r[k] is not False for k in V3_KEYS)
        mark = lambda k: "-  " if r[k] is None else ("ok " if r[k] else "NO ")
        ver = r["version"] or "-"
        print(f"{p['key']:28s} {'*' if req else ' ':3s} {mark('theme'):5s} {mark('favicon'):4s} {mark('home'):4s} {mark('toggle'):3s} {ver:3s} {mark('dflt'):4s} "
              f"{mark('nav'):4s} {mark('case'):4s} {mark('wave'):4s} {mark('menu'):4s}  {(r['title'] or '')[:40]}")
        if r["why"]:
            whys.append((p["key"], r["why"]))
        if req and not ok: fails.append(p["key"])
        if req and ver not in ("2", "3"): warns.append(p["key"])
    for key, why in whys:
        print(f"\n{key}:")
        for x in why:
            print(f"  {x}")
    if warns:
        print(f"\nWARNING — required products not on brand v2 or v3 (v1 superseded 2026-09-04): {', '.join(warns)}")
    if fails:
        sys.exit(f"\nFAIL — required products off the brand contract: {', '.join(fails)}")
    print("\nall required products pass")


if __name__ == "__main__":
    main()
