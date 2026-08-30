#!/usr/bin/env python3
"""Draw the brand v2 horizontal lockup: the CalCOFI mark + a "CalCOFI" wordmark, as outlined SVG.

    scripts/build_lockup.py            # writes brand/v2/logo_calcofi_h.svg + logo_calcofi_h_light.svg
    scripts/build_lockup.py --long     # + the long name in small caps beneath the wordmark (a check, not shipped)

The mark is the yellow rosette of brand/v1/logo_calcofi.svg (its `calcofi_x5F_logo` group, verbatim
paths). The wordmark is Source Sans 3 at wght 800, shaped by HarfBuzz (so the GPOS kerning applies) from
the very woff2 the brand serves (brand/v2/fonts/), and outlined with fontTools so the SVG needs no font.
Two grounds, as v1: `logo_calcofi_h.svg` (white wordmark, for a dark ground) and `_light.svg` (navy
#182B49). The lockup is 240 units tall; the mark fills 200 of them and the capitals 150, so at the header's
36 px the caps are 22.5 px and at the app header's 28 px they are 17.5 px.

Needs fontTools + brotli + uharfbuzz (pip install fonttools brotli uharfbuzz).
"""
import argparse, io, re
from pathlib import Path

import uharfbuzz as hb
from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont
from fontTools.varLib.instancer import instantiateVariableFont

ROOT = Path(__file__).resolve().parent.parent
V1 = ROOT / "brand/v1/logo_calcofi.svg"
OUT = ROOT / "brand/v2"
FONT = OUT / "fonts/SourceSans3-VF.woff2"

H = 240                   # lockup height (viewBox units)
MARK_H = 200              # the rosette's height, centred vertically
CAP_H = 150               # capital height of the wordmark
GAP = 30                  # mark → wordmark
WGHT = 800
MARK_YELLOW = "#F4D530"   # the logo's own yellow (v1)
NAVY = "#182B49"          # UC San Diego Navy — the wordmark on a light ground
LONG_NAME = "CALIFORNIA COOPERATIVE OCEANIC FISHERIES INVESTIGATIONS"


def mark_paths():
    """The rosette's <path d> strings and its bounding box in v1's viewBox (measured: 56.6,91.1 → 381.3,415.0)."""
    s = V1.read_text()
    g = re.search(r'<g id="calcofi_x5F_logo">(.*?)</g>', s, re.S).group(1)
    ds = re.findall(r'd="([^"]+)"', g)
    ds = [re.sub(r"\s+", " ", d).strip() for d in ds]
    return ds, (56.6, 91.1, 381.3, 415.0)


def shaped(font_path, text, wght, size):
    """Glyph ids + pen-space positions (font units → `size` px per em) for `text` at weight `wght`.
    HarfBuzz reads sfnt, not WOFF2, so the woff2 is decompressed through fontTools first."""
    raw = io.BytesIO(); t = TTFont(font_path); t.flavor = None; t.save(raw)
    blob = hb.Blob(raw.getvalue())
    face = hb.Face(blob)
    font = hb.Font(face)
    font.set_variations({"wght": wght})
    buf = hb.Buffer(); buf.add_str(text); buf.guess_segment_properties()
    hb.shape(font, buf, {"kern": True, "liga": True})
    upm = face.upem
    scale = size / upm
    x = 0.0
    out = []
    for info, pos in zip(buf.glyph_infos, buf.glyph_positions):
        out.append((info.codepoint, (x + pos.x_offset) * scale, pos.y_offset * scale))
        x += pos.x_advance
    return out, x * scale, upm


def outline(font_path, text, wght, size, x0, baseline):
    """One SVG path `d` for `text`, baked into lockup space (y down)."""
    ttf = TTFont(font_path); ttf.flavor = None
    static = instantiateVariableFont(ttf, {"wght": wght})
    glyph_order = static.getGlyphOrder()
    glyph_set = static.getGlyphSet()
    glyphs, adv, upm = shaped(font_path, text, wght, size)
    s = size / upm
    pen = SVGPathPen(glyph_set)
    for gid, gx, gy in glyphs:
        name = glyph_order[gid]
        glyph_set[name].draw(TransformPen(pen, (s, 0, 0, -s, x0 + gx, baseline - gy)))
    # the last glyph's right side bearing is air; the viewBox stops at the ink
    last = glyph_order[glyphs[-1][0]]
    ink_right = x0 + adv - max(0, static["hmtx"][last][0] - _ink_xmax(static, last)) * s
    return pen.getCommands(), ink_right


def _ink_xmax(static, name):
    from fontTools.pens.boundsPen import BoundsPen
    bp = BoundsPen(static.getGlyphSet()); static.getGlyphSet()[name].draw(bp)
    return bp.bounds[2] if bp.bounds else static["hmtx"][name][0]


def build(long_name=False):
    ds, (x0, y0, x1, y1) = mark_paths()
    mw, mh = x1 - x0, y1 - y0
    ms = MARK_H / mh
    mark_w = mw * ms
    # the rosette: scale so its height is MARK_H, sit it at the left edge, centred vertically
    mark_tf = f"translate({-x0 * ms:.3f},{(H - MARK_H) / 2 - y0 * ms:.3f}) scale({ms:.5f})"
    cap = 660 / 1000   # Source Sans 3 sCapHeight / unitsPerEm (OS/2)
    size = CAP_H / cap
    tx = mark_w + GAP
    baseline = (H + CAP_H) / 2 if not long_name else (H + CAP_H) / 2 - 22
    word_d, right = outline(FONT, "CalCOFI", WGHT, size, tx, baseline)
    extra = ""
    if long_name:
        # the long name in 600 caps, tracked, on the wordmark's left edge, under the baseline
        ln_size = 30
        ln_d, ln_right = outline(FONT, LONG_NAME, 600, ln_size, tx + 4, baseline + 46)
        right = max(right, ln_right)
        extra = f'\n  <path class="w" d="{ln_d}"/>'
    w = round(right + 2)
    def svg(word_fill, ground):
        head = (f'<?xml version="1.0" encoding="utf-8"?>\n'
                f'<!-- calcofi.io brand v2 — the horizontal lockup, for a {ground} ground. GENERATED by scripts/build_lockup.py:\n'
                f'     the v1 mark (its rosette paths, verbatim) + "CalCOFI" in Source Sans 3 wght {WGHT}, shaped by HarfBuzz and outlined,\n'
                f'     so no font is needed to draw it. {w}×{H}; use at height 36 (pages) or 28 (apps). Do not hand-edit. -->\n')
        return (head +
                f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {H}" width="{w}" height="{H}" role="img" aria-label="CalCOFI">\n'
                f'  <style>.m{{fill:{MARK_YELLOW}}}.w{{fill:{word_fill}}}</style>\n'
                f'  <g class="m" transform="{mark_tf}">\n' +
                "".join(f'    <path d="{d}"/>\n' for d in ds) +
                f'  </g>\n  <path class="w" d="{word_d}"/>{extra}\n</svg>\n')
    suffix = "_long" if long_name else ""
    (OUT / f"logo_calcofi_h{suffix}.svg").write_text(svg("#FFFFFF", "dark"))
    (OUT / f"logo_calcofi_h{suffix}_light.svg").write_text(svg(NAVY, "light"))
    print(f"wrote brand/v2/logo_calcofi_h{suffix}.svg + _light.svg  viewBox 0 0 {w} {H}  (mark {mark_w:.0f} wide, caps {CAP_H}, font size {size:.1f})")


if __name__ == "__main__":
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--long", action="store_true", help="also draw the long-name variant (for the eye; not part of the contract)")
    a = ap.parse_args()
    build(False)
    if a.long:
        build(True)
