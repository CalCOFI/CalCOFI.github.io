#!/usr/bin/env python3
"""Check every live calcofi.io product against the brand contract (brand/v2/README.md; v1 superseded 2026-09-04).

    scripts/check_brand.py                 # every product in _data/products.yml
    scripts/check_brand.py db-schema erddap
    scripts/check_brand.py --required-only # only products that must pass (shots: themed)
    scripts/check_brand.py --url http://localhost:4000/v2/   # one URL, held to the required level (a preview)

For each product's live_url, a headless browser opens  ?theme=light  and  ?theme=dark
(appending to any existing query string) and reports:
  theme     <html data-theme> equals the requested theme both times  — the page runs theme.js
  favicon   a <link rel="icon"> whose href returns 200                — and it is the CalCOFI set
            (or the product's own designed mark for the two exceptions)
  home      an <a href="https://calcofi.io"> in the page chrome       — the far-left back-link
  toggle    a .cc-theme-toggle / bslib dark-mode switch / framework light-switch exists
  ver       window.ccTheme.version — "2" is the contract in force; "1" is reported as a WARNING
  dflt      a third probe with NO ?theme= in a fresh context: a v2 product must open LIGHT with the
            fonts loaded (document.fonts.check('16px "Source Sans 3"')) and the lockup <img> present

A product declared `shots: themed` in products.yml MUST pass all four (exit 1 otherwise), and a
v2 product must also pass `dflt`;
everything else is reported for information (student work, third-party hosts, not yet
migrated). Consistency is checked here weekly (.github/workflows/check-brand.yml), not assumed.

Needs shot-scraper (`pipx install shot-scraper && shot-scraper install`).
"""
import argparse, json, subprocess, sys, urllib.request
from pathlib import Path

import yaml

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
  return {theme: d.dataset.theme || null, bs: d.getAttribute("data-bs-theme"), icons, home, toggle, version, fonts, lockup, title: document.title, href: location.href};
})()), WAIT_MS))
"""


def with_param(url, kv):
    return f"{url}{'&' if '?' in url else '?'}{kv}"


def probe(url, wait, browser):
    cmd = ["shot-scraper", "javascript", url, JS.replace("WAIT_MS", str(wait)), "--browser", browser]
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


def check(p, browser):
    url = p["live_url"]
    wait = 12000 if "app.calcofi.io" in url else 4000
    light = probe_theme(url, "light", wait, browser)
    if "error" in light:
        return {"error": light["error"]}
    dark = probe_theme(url, "dark", wait, browser)
    # the default: no ?theme=, fresh context (shot-scraper's is) — v2 must open light with fonts + lockup
    dflt = probe(with_param(url, "tour=off"), wait, browser)
    version = str(light.get("version") or dflt.get("version") or "")
    icons = light.get("icons") or []
    icon_ok = any((status(i) or 0) in (200, 206) for i in icons)
    if p["key"] not in OWN_MARK:
        icon_ok = icon_ok and any("calcofi.io/brand/" in i or "favicon" in i for i in icons)
    return {
        "theme":   light.get("theme") == "light" and dark.get("theme") == "dark",
        "favicon": icon_ok,
        "home":    bool(light.get("home")),
        "toggle":  bool(light.get("toggle")),
        "version": version,
        "dflt":    version != "2" or (dflt.get("theme") == "light" and bool(dflt.get("fonts")) and bool(dflt.get("lockup"))),
        "title":   light.get("title"),
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("keys", nargs="*")
    ap.add_argument("--required-only", action="store_true")
    ap.add_argument("--browser", default="chromium", help="shot-scraper browser (chromium is enough: no WebGL needed)")
    ap.add_argument("--url", help="check this one URL instead of products.yml, at the required level (a preview page, a local build)")
    a = ap.parse_args()

    products = yaml.safe_load((ROOT / "_data/products.yml").read_text())["products"]
    if a.url:
        products = [{"key": "url", "live_url": a.url, "shots": "themed"}]
    if a.keys:
        products = [p for p in products if p["key"] in a.keys]
    if a.required_only:
        products = [p for p in products if p.get("shots") == "themed"]
    if not products:
        sys.exit("nothing to check")

    fails, warns = [], []
    print(f"{'product':28s} {'req':3s} {'theme':5s} {'icon':4s} {'home':4s} {'tog':3s} {'ver':3s} {'dflt':4s}  title")
    for p in products:
        req = p.get("shots") == "themed"
        r = check(p, a.browser)
        if "error" in r:
            print(f"{p['key']:28s} {'*' if req else ' ':3s} ERROR {r['error'][:70]}")
            if req: fails.append(p["key"])
            continue
        ok = all(r[k] for k in ("theme", "favicon", "home", "toggle", "dflt"))
        mark = lambda k: "ok " if r[k] else "NO "
        ver = r["version"] or "-"
        print(f"{p['key']:28s} {'*' if req else ' ':3s} {mark('theme'):5s} {mark('favicon'):4s} {mark('home'):4s} {mark('toggle'):3s} {ver:3s} {mark('dflt'):4s}  {(r['title'] or '')[:40]}")
        if req and not ok: fails.append(p["key"])
        if req and ver != "2": warns.append(p["key"])
    if warns:
        print(f"\nWARNING — required products still on brand v1 (superseded 2026-09-04): {', '.join(warns)}")
    if fails:
        sys.exit(f"\nFAIL — required products off the brand contract: {', '.join(fails)}")
    print("\nall required products pass")


if __name__ == "__main__":
    main()
