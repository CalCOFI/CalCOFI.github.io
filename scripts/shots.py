#!/usr/bin/env python3
"""(Re)capture the calcofi.io product-card screenshots, one per theme.

    scripts/shots.py                      # every `shots: themed` product (both themes)
    scripts/shots.py db-viz-hex erddap    # just these keys
    scripts/shots.py --all                # themed products twice + everything else once
    scripts/shots.py --theme light …      # one theme only
    scripts/shots.py --dry-run            # print the shot-scraper config, capture nothing
    scripts/shots.py check                # luminance-check every images/*_{dark,light}.png

The capture list is _data/products.yml (`shots: themed` => images/<key>_dark.png +
_light.png at live_url?theme=<t>&tour=off; otherwise images/<key>.png, no param);
per-card overrides (url, wait, javascript, themed) are _data/shots.yml. Each PNG is
1200x750, compressed in place with pngquant, then luminance-checked: a "dark" shot
whose mean luminance says it is white means the product ignored ?theme= — that is
a bug in the product, and the image is NOT what the card should show.

Uses your installed Google Chrome (`--browser chrome`): the map apps render
H3/WebGL layers that Playwright's bundled Chromium leaves blank. Override with
SHOT_BROWSER=chromium. One-time setup:

    pipx install shot-scraper && shot-scraper install
    brew install pngquant
"""
import argparse, os, subprocess, sys, tempfile
from pathlib import Path

import yaml
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
WIDTH, HEIGHT = 1200, 750
DEFAULT_WAIT, SHINY_WAIT = 5000, 15000
# mean luminance (0-255) thresholds — see `check`
DARK_MAX, LIGHT_MIN = 110, 140


def load():
    products = yaml.safe_load((ROOT / "_data/products.yml").read_text())["products"]
    overrides = yaml.safe_load((ROOT / "_data/shots.yml").read_text()) or {}
    return {p["key"]: p for p in products}, overrides


def with_params(url, theme):
    sep = "&" if "?" in url else "?"
    return f"{url}{sep}theme={theme}&tour=off"


def recipes(products, overrides, keys, themes, everything):
    """One shot-scraper `multi` entry per (product, theme)."""
    out = []
    for key, p in products.items():
        ov = overrides.get(key, {})
        themed = p.get("shots") == "themed" and ov.get("themed", True)
        if keys and key not in keys:
            continue
        if not keys and not everything and not themed and key not in overrides:
            continue
        base = ov.get("url", p["live_url"])
        wait = ov.get("wait", SHINY_WAIT if "app.calcofi.io" in base else DEFAULT_WAIT)
        variants = [(t, with_params(base, t), f"images/{key}_{t}.png") for t in themes] if themed \
            else [(None, base, f"images/{key}.png")]
        for theme, url, output in variants:
            r = {"output": output, "url": url, "width": WIDTH, "height": HEIGHT, "wait": wait}
            if ov.get("javascript"):
                r["javascript"] = ov["javascript"]
            out.append(r)
    return out


def luminance(path):
    im = Image.open(path).convert("L").resize((60, 40))
    px = list(im.getdata())
    return sum(px) / len(px)


def check(paths):
    """Fail on a themed shot whose brightness contradicts its theme."""
    bad = 0
    for path in sorted(paths):
        name = Path(path).name
        lum = luminance(path)
        verdict = "ok"
        if name.endswith("_dark.png") and lum > DARK_MAX:
            verdict, bad = f"NOT DARK (mean {lum:.0f} > {DARK_MAX}) — product ignored ?theme=dark", bad + 1
        elif name.endswith("_light.png") and lum < LIGHT_MIN:
            verdict, bad = f"NOT LIGHT (mean {lum:.0f} < {LIGHT_MIN}) — product ignored ?theme=light", bad + 1
        print(f"{name:42s} {lum:5.0f}  {verdict}")
    return bad


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("keys", nargs="*", help="product keys (or `check`)")
    ap.add_argument("--all", action="store_true", help="also capture non-themed products once")
    ap.add_argument("--theme", choices=["dark", "light"], help="only this theme")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()

    os.chdir(ROOT)
    if a.keys and a.keys[0] == "check":
        sys.exit(1 if check(list(Path("images").glob("*_dark.png")) + list(Path("images").glob("*_light.png"))) else 0)

    products, overrides = load()
    unknown = [k for k in a.keys if k not in products]
    if unknown:
        sys.exit(f"error: not in _data/products.yml: {', '.join(unknown)}")
    themes = [a.theme] if a.theme else ["dark", "light"]
    rs = recipes(products, overrides, set(a.keys), themes, a.all)
    if not rs:
        sys.exit("error: nothing to capture (no `shots: themed` product or override matched)")
    cfg = yaml.safe_dump(rs, sort_keys=False, width=1000)
    if a.dry_run:
        print(cfg); return

    for tool in ("shot-scraper", "pngquant"):
        if subprocess.run(["which", tool], capture_output=True).returncode:
            sys.exit(f"error: '{tool}' not found — see the setup notes in {__file__}")
    with tempfile.NamedTemporaryFile("w", suffix=".yml", delete=False) as f:
        f.write(cfg)
    subprocess.run(["shot-scraper", "multi", f.name, "--browser", os.environ.get("SHOT_BROWSER", "chrome")], check=True)
    outputs = [r["output"] for r in rs]
    for png in outputs:
        if Path(png).exists():
            subprocess.run(["pngquant", "--quality=65-90", "--strip", "--force", "--ext", ".png", png], check=True)
            print(f"compressed {png}")
    themed = [o for o in outputs if o.endswith(("_dark.png", "_light.png")) and Path(o).exists()]
    if themed and check(themed):
        sys.exit("\nsome captures contradict their theme — do not commit those; fix the product first")


if __name__ == "__main__":
    main()
