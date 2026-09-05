#!/usr/bin/env python3
"""build_land.py — the coastline behind every static map on this site, built ONCE.

    scripts/build_land.py            # fetch Natural Earth, clip, simplify, write _data/land.geojson
    scripts/build_land.py --stats    # …and print what came out

`_data/land.geojson` is **committed**, unlike every other file in `_data/`: it is cartography, not a
dataset fact, so it does not belong in a data release (plan Decision 5). It changes only if this
script's clip or tolerance changes, which is why running it is a deliberate act and not part of
`build.sh`.

Source: Natural Earth 1:50 m land — public domain, `nvkelso/natural-earth-vector`. Clipped to
135–105° W × 19–49° N (the CalCOFI station grid plus a wide margin: every grid line, standard,
extended and historical, is inside it) with Sutherland–Hodgman, then simplified with
Douglas–Peucker at 0.012° ≈ 1 km — invisible at the 360 px the maps are drawn at, and the whole
California and Baja coast plus the Channel Islands comes to ~21 KB.

Pure Python: no shapely, no GDAL, nothing to install. The only network call is the fetch.
"""
import argparse, json, math, os, sys, urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "_data" / "land.geojson"
SRC = ("https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/"
       "geojson/ne_50m_land.geojson")

LON0, LON1, LAT0, LAT1 = -135.0, -105.0, 19.0, 49.0   # the frame: the station grid + margin
TOL = 0.012                                           # degrees, ~1 km — invisible at 360 px


def dp(pts, tol):
    """Douglas–Peucker. A closed ring is split at its farthest point first, or the first and last
    points (which are the same point) would define a zero-length segment and keep nothing."""
    if len(pts) < 3:
        return pts
    if pts[0] == pts[-1]:
        k = max(range(1, len(pts) - 1),
                key=lambda i: (pts[i][0] - pts[0][0]) ** 2 + (pts[i][1] - pts[0][1]) ** 2)
        return dp(pts[:k + 1], tol)[:-1] + dp(pts[k:], tol)
    (x0, y0), (x1, y1) = pts[0], pts[-1]
    dx, dy = x1 - x0, y1 - y0
    L = math.hypot(dx, dy) or 1e-12
    imax, dmax = 0, 0.0
    for i in range(1, len(pts) - 1):
        x, y = pts[i]
        d = abs(dy * x - dx * y + x1 * y0 - y1 * x0) / L
        if d > dmax:
            imax, dmax = i, d
    if dmax > tol:
        return dp(pts[:imax + 1], tol)[:-1] + dp(pts[imax:], tol)
    return [pts[0], pts[-1]]


def clip_ring(ring, lon0=LON0, lon1=LON1, lat0=LAT0, lat1=LAT1):
    """Sutherland–Hodgman against the frame rectangle."""
    def clip(poly, inside, intersect):
        out = []
        for i, p in enumerate(poly):
            q = poly[i - 1]
            if inside(p):
                if not inside(q):
                    out.append(intersect(q, p))
                out.append(p)
            elif inside(q):
                out.append(intersect(q, p))
        return out

    def ix(a, b, axis, val):
        (x0, y0), (x1, y1) = a, b
        if axis == 0:
            t = (val - x0) / (x1 - x0)
            return (val, y0 + t * (y1 - y0))
        t = (val - y0) / (y1 - y0)
        return (x0 + t * (x1 - x0), val)

    poly = ring
    for axis, val, keep in ((0, lon0, lambda p: p[0] >= lon0), (0, lon1, lambda p: p[0] <= lon1),
                            (1, lat0, lambda p: p[1] >= lat0), (1, lat1, lambda p: p[1] <= lat1)):
        if not poly:
            return []
        poly = clip(poly, keep, lambda a, b, axis=axis, val=val: ix(a, b, axis, val))
    return poly


def main():
    ap = argparse.ArgumentParser(description=__doc__,
                                 formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--src", default=SRC, help="ne_50m_land.geojson (a URL or a local path)")
    ap.add_argument("--out", default=str(OUT))
    ap.add_argument("--stats", action="store_true")
    a = ap.parse_args()

    if a.src.startswith("http"):
        print(f"fetching {a.src}")
        with urllib.request.urlopen(a.src, timeout=120) as r:
            land = json.load(r)
    else:
        land = json.load(open(a.src))

    rings, seen = [], 0
    for f in land["features"]:
        g = f["geometry"]
        polys = g["coordinates"] if g["type"] == "MultiPolygon" else [g["coordinates"]]
        for poly in polys:
            for ring in poly:
                seen += 1
                pts = [tuple(p[:2]) for p in ring]
                # a cheap bbox reject before the clip: most of the world is not California
                if (max(p[0] for p in pts) < LON0 or min(p[0] for p in pts) > LON1 or
                        max(p[1] for p in pts) < LAT0 or min(p[1] for p in pts) > LAT1):
                    continue
                c = clip_ring(pts)
                if len(c) >= 3:
                    s = dp(c + [c[0]], TOL)
                    if len(s) >= 4:
                        rings.append(s)

    gj = {
        "type": "FeatureCollection",
        "name": "land_calcofi",
        "source": SRC,
        "attribution": "Natural Earth 1:50m land (public domain)",
        "processing": (f"clipped to {LON0}..{LON1} lon x {LAT0}..{LAT1} lat, "
                       f"Douglas-Peucker {TOL} deg, scripts/build_land.py"),
        "features": [{"type": "Feature", "properties": {},
                      "geometry": {"type": "Polygon",
                                   "coordinates": [[[round(x, 4), round(y, 4)] for x, y in r]]}}
                     for r in rings],
    }
    Path(a.out).write_text(json.dumps(gj, separators=(",", ":")))
    n_pts = sum(len(r) for r in rings)
    print(f"wrote {a.out}: {len(rings)} rings, {n_pts} points, "
          f"{os.path.getsize(a.out) / 1000:.1f} KB (from {seen} source rings)")
    if a.stats:
        big = sorted(rings, key=len, reverse=True)[:5]
        for r in big:
            xs = [p[0] for p in r]
            ys = [p[1] for p in r]
            print(f"  {len(r):4d} pts  lon {min(xs):8.2f}..{max(xs):8.2f}  "
                  f"lat {min(ys):6.2f}..{max(ys):6.2f}")


if __name__ == "__main__":
    sys.exit(main())
