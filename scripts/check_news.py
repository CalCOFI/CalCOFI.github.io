#!/usr/bin/env python3
"""Hold every changelog anchor the ship's log uses to a real id on the rendered RELEASES.html.

    scripts/check_news.py                   # checks ./_site against the live changelog
    scripts/check_news.py path/to/_site
    scripts/check_news.py --url https://.../RELEASES.html      # a staging render

Why this exists (plan 2026-09-09 § N2): the release entry used to open raw markdown on
storage.googleapis.com. It now opens the RENDERED changelog at a heading —
`RELEASES.html#v2026.09.06` for a release entry, `RELEASES.html#one-climatology-for-every-anomaly`
for a hand-written `data` row of _data/news.yml. Both ids are stamped by workflows'
scripts/render_md_on_storage.R: the version string itself on a version heading, a slug on every
`##`/`###`. Nothing in this repo can see that page at build time, so an anchor could rot silently —
a re-titled section, a version whose notes were never re-rendered. This GETs the page ONCE and
asserts every fragment the built log uses is an `id=` on it.

It is strict, and it passes by construction: scripts/fetch_release.sh reads the page's version ids
into _data/release_anchors.json before the build, and _plugins/news.rb anchors a release entry only
where the id is in that set (a release the changelog collapsed into a range section links the page
unanchored). So a failure here means a real break — a hand-written news.yml row pointing at a
section that was renamed, or a page whose anchors moved between the fetch and this check.

Exit 1 on any miss, with every miss printed and the ids it looked for.
"""
import re
import sys
import urllib.parse
import urllib.request
from pathlib import Path

# the page the log anchors into, and the built pages that carry those links (the ship's log's own
# page and the front door's log tile — every release entry appears in both)
RELEASES_URL = "https://storage.calcofi.io/calcofi-db/ducklake/releases/RELEASES.html"
PAGES = ["news/index.html", "index.html"]

HREF    = re.compile(r'href="([^"]*RELEASES\.html#([^"]+))"')
ID      = re.compile(r'\bid="([^"]+)"')
VERSION = re.compile(r"\Av\d")


def main():
    args = sys.argv[1:]
    url = RELEASES_URL
    if "--url" in args:
        i = args.index("--url")
        url = args[i + 1]
        del args[i:i + 2]
    site = Path(args[0] if args else "_site").resolve()
    if not site.is_dir():
        sys.exit(f"no such build directory: {site} — run `bundle exec jekyll build` first")

    # every RELEASES.html#fragment the built pages link, with the pages that link it
    used = {}
    for rel in PAGES:
        p = site / rel
        if not p.is_file():
            sys.exit(f"missing {p} — the build did not write it")
        html = p.read_text(encoding="utf-8", errors="replace")
        for _, frag in HREF.findall(html):
            used.setdefault(urllib.parse.unquote(frag), set()).add(rel)
    if not used:
        print(f"no RELEASES.html anchors in {' · '.join(PAGES)} — nothing to check")
        return

    try:
        with urllib.request.urlopen(url, timeout=30) as r:
            page = r.read().decode("utf-8", "replace")
    except Exception as e:                     # a network failure is a failure: the anchors are unverified
        sys.exit(f"FAIL — could not GET {url}: {e}")
    ids = set(ID.findall(page))
    print(f"{url}: {len(page):,} bytes · {len(ids):,} ids")
    print(f"{len(used)} anchor(s) used by {' · '.join(PAGES)}")

    fails = []
    for frag in sorted(used):
        where = " · ".join(sorted(used[frag]))
        if frag in ids:
            print(f"  ok   #{frag}  ({where})")
        else:
            fails.append(f"#{frag}  linked from {where}")

    if fails:
        print(f"\nFAIL — {len(fails)} anchor(s) are not an id on {url}:")
        for f in fails:
            print(f"  {f}")
        near = sorted(i for i in ids if VERSION.match(i))[-4:]
        print(f"  the page's newest version ids: {', '.join('#' + i for i in near) or '(none)'}")
        print("  a version id that is gone: re-run scripts/fetch_release.sh and rebuild — the log "
              "links the unanchored page for a version RELEASES.html has no heading for")
        sys.exit(1)
    print("\nevery changelog anchor the log uses resolves")


if __name__ == "__main__":
    main()
