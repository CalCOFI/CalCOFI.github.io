#!/usr/bin/env python3
"""_test/check_layout_front_test.py — the pure rules scripts/check_layout.py judges front door v2 by
(the first screen of 2026-11-17: section.hero, _includes/front_door_hero.html). The browser only
measures; these functions decide, so each is pinned here on a small synthetic measurement:

    python3 _test/check_layout_front_test.py

  products   product_keys: every product is drawn except a `superseded` one; an `archived` one is
             still drawn (the student projects) — the rule Betty's change to the check stated too wide
  pixels     png_pixels / heading_contrast: "Where do you want to start?" lies on a picture, so it is
             read from two screenshots of its box, drawn and with its text transparent — the ink is
             what most letter pixels are, and it is held to the LOWEST contrast against any pixel
             behind a letter (white on the sky was 1.1:1 at 375 px until c38911f; white on the pale
             water 2.6:1 at 901 x 700 until the scrim of f58c2d3)
  tasks      task_links / task_words / check_first_screen: each of the seven tasks and the Query
             Builder is reached from the first screen in one step — a visible link under the bar, at
             least a tap target tall and above the 1280 x 645 fold when asked, or, for the two tasks
             the strip gave to the header on 2026-11-17 (learn, cite) and only those, the header: a
             word of the bar that is the link, or a word whose menu holds it (both are lines of the
             Learn menu since the evening of 2026-11-17); the strip under the cards; the numbers
             inside the window; the ship's label gone on a phone
  nav        nav_words: the header's words are read from _data/nav.yml, the ONE list — and the list
             itself is pinned here: Data ▾ · Map ▾ · Learn ▾ · calcofi.org ↗, three menus (the Query
             Builder, at its own address /query/, is a line of Data)
  wave       is_navy / check_wave (brand v3 § 4): one navy band directly under the bar, edge to edge,
             never the page ground, its edge drawn and a visible step from the band
"""
import importlib.util, os, re, sys, unittest

sys.dont_write_bytecode = True    # the script is loaded by path: leave no scripts/__pycache__ behind

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("check_layout", os.path.join(HERE, "..", "scripts", "check_layout.py"))
cl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cl)

PRODUCTS = """sections:
  - id: explore
products:
  - key: explore
    title: Explorer
    tab: explorer
  - key: db-viz-hex
    title: Hexagons
    status: superseded
    tab: general
  - key: marmam
    title: Marine mammals
    status: archived
    tab: student
  - key: docs
    title: Docs
    status: live
"""

def link(href, where="strip", h=40, bottom=600, visible=True, text=""):
    return {"href": href, "where": where, "h": h, "w": 120, "top": bottom - h, "bottom": bottom,
            "left": 0, "right": 120, "visible": visible, "text": text or href}


def word(wid, title, href=None, lines=(), visible=True):
    return {"id": wid, "title": title, "href": href, "lines": list(lines), "visible": visible,
            "top": 20, "bottom": 52, "left": 0, "right": 60, "h": 32, "w": 60}


LEARN_LINES = ["/#learn", "https://calcofi.io/docs/faq.html", "https://calcofi.io/docs/cite.html", "https://calcofi.io/docs/",
               "/news/?type=tutorial", "/news/?type=story", "/news/"]


def bar(visible=True):
    """the header's four words as the page draws them (brand v3, 2026-11-17 evening): Data, Map and
    Learn open menus, calcofi.org is a link. Data holds the catalogs and the ways to get the data, the
    Query Builder first among them; Learn holds the guides (How CalCOFI samples, FAQ, Cite the data,
    Documentation) and the news (Tutorials, Stories, All news)"""
    return [word("data", "Data", lines=["/datasets/", "/species/", "/measurements/", "https://calcofi.io/query/", "/#services", "/#packages", "/#build"], visible=visible),
            word("map", "Map", lines=["https://calcofi.io/explore/", "https://app.calcofi.io/station/", "/#explore"], visible=visible),
            word("learn", "Learn", lines=LEARN_LINES, visible=visible),
            word("org", "calcofi.org ↗", "https://calcofi.org", visible=visible)]


def hero(**over):
    """a first screen on which every assertion passes, at 1280 wide: the strip is Contribute and
    Statewide monitoring (2026-11-17); Cite the data is a line of the header's Learn menu; What CalCOFI
    collects is the ship's label in the drawing and the first line of Learn"""
    links = [link("#learn", "drawing", h=50), link("https://calcofi.io/explore/", "card"), link("/datasets/", "card"),
             link("#program", "card"), link("https://calcofi.io/docs/provide.html"), link("#monitor"),
             link("https://calcofi.io/query/", "card")]
    cards = [{"title": t, "top": 380, "bottom": 560, "left": x, "right": x + 380, "h": 180, "w": 380}
             for t, x in (("Visualize on a map", 20), ("Download a dataset", 420), ("Pull exact data", 820))]
    H = {"top": 106, "bottom": 712, "innerH": 645, "innerW": 1280, "links": links, "cards": cards,
         "header": bar(), "menuButton": False,
         "strip": {"top": 580, "bottom": 612, "left": 20, "right": 700, "h": 32, "w": 680},
         "start": {"top": 330, "bottom": 364, "left": 20, "right": 400, "h": 34, "w": 380, "color": "rgb(255,255,255)"},
         "tag": {"visible": True, "display": "inline", "w": 292},
         "nums": [{"label": "years", "left": 1100, "right": 1150}, {"label": "measurements", "left": 1160, "right": 1256}],
         "drawn": 8, "ridge": True, "floorData": True, "svgPins": 0}
    H.update(over)
    return H


def phone(**over):
    """the same first screen under NAV_BREAK: the bar's words are behind the menu button, the ship's
    label is gone"""
    H = hero(innerW=375, header=bar(visible=False), menuButton=True, tag={"visible": False, "display": "none", "w": 0},
             nums=[{"label": "years", "left": 24, "right": 64}])
    H["links"] = [x for x in H["links"] if x["where"] != "drawing"]
    H.update(over)
    return H


def run(H, width=1280, fold=False):
    fails, notes = [], []
    cl.check_first_screen("x", H, width, fails, notes, fold=fold)
    return fails


class ProductKeys(unittest.TestCase):
    def test_superseded_is_not_drawn_and_archived_still_is(self):
        drawn, superseded = cl.product_keys(PRODUCTS)
        self.assertEqual(drawn, ["explore", "marmam", "docs"])
        self.assertEqual(superseded, ["db-viz-hex"])

    def test_no_text_no_keys(self):
        self.assertEqual(cl.product_keys(""), ([], []))
        self.assertEqual(cl.product_keys(None), ([], []))

    # regression (2026-11-17): front-door-v2's _product_keys dropped `archived` too, so a page that
    # stopped drawing the six archived student projects would have passed
    def test_archived_must_be_drawn(self):
        self.assertIn("marmam", cl.product_keys(PRODUCTS)[0])

    def test_a_status_inside_another_products_block_does_not_leak(self):
        text = "products:\n  - key: a\n    title: A\n  - key: b\n    status: superseded\n  - key: c\n    title: C\n"
        self.assertEqual(cl.product_keys(text), (["a", "c"], ["b"]))


def png(w, h, px, alpha=False, filters=None):
    """a PNG of w x h from [(r, g, b), …], each row written with the filter asked for (0 none, 1 sub,
    2 up, 3 average, 4 Paeth) — the five a browser's screenshot may use"""
    import struct, zlib
    bpp = 4 if alpha else 3
    rows = [bytearray(b for c in px[y * w:(y + 1) * w] for b in (c + (255,) if alpha else c)) for y in range(h)]
    raw, prev = bytearray(), bytearray(w * bpp)
    for y, line in enumerate(rows):
        f = (filters or [0] * h)[y]
        out = bytearray(len(line))
        for i, v in enumerate(line):
            a = line[i - bpp] if i >= bpp else 0
            b = prev[i]
            c = prev[i - bpp] if i >= bpp else 0
            pa, pb, pc = abs(b - c), abs(a - c), abs(a + b - 2 * c)
            pred = [0, a, b, (a + b) >> 1, a if pa <= pb and pa <= pc else b if pb <= pc else c][f]
            out[i] = (v - pred) & 255
        raw += bytes([f]) + out
        prev = line
    chunk = lambda k, d: struct.pack(">I", len(d)) + k + d + struct.pack(">I", zlib.crc32(k + d))  # noqa: E731
    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6 if alpha else 2, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw))) + chunk(b"IEND", b""))


WHITE, INK, SKYPX, WATER, DEEP = (255, 255, 255), (24, 43, 73), (241, 246, 251), (140, 195, 230), (48, 110, 160)


class Pixels(unittest.TestCase):
    PX = [(i * 7 % 256, i * 13 % 256, i * 29 % 256) for i in range(6 * 5)]

    def test_png_round_trip_every_filter_rgb_and_rgba(self):
        for alpha in (False, True):
            for f in range(5):
                w, h, px = cl.png_pixels(png(6, 5, self.PX, alpha=alpha, filters=[f] * 5))
                self.assertEqual((w, h, px), (6, 5, self.PX), f"filter {f}, alpha {alpha}")
        self.assertEqual(cl.png_pixels(png(6, 5, self.PX, filters=[0, 1, 2, 3, 4]))[2], self.PX)

    def test_not_a_png_and_an_unsupported_one(self):
        with self.assertRaises(ValueError):
            cl.png_pixels(b"GIF89a")
        bad = bytearray(png(2, 2, [WHITE] * 4))
        bad[24] = 16                                        # bit depth 16
        with self.assertRaises(ValueError):
            cl.png_pixels(bytes(bad))

    def box(self, text, ground, w=8, h=4, letters=((1, 1), (2, 1), (3, 1), (5, 2), (6, 2)), edge=((4, 1),)):
        """(shown, hidden): a w x h box of `ground` (a colour, or one per pixel) with letter pixels of
        `text` and one soft edge pixel half way between"""
        g = ground if isinstance(ground, list) else [ground] * (w * h)
        shown = list(g)
        for x, y in letters:
            shown[y * w + x] = text
        for x, y in edge:
            shown[y * w + x] = tuple((a + b) // 2 for a, b in zip(text, g[y * w + x]))
        return (w, h, shown), (w, h, g)

    def test_the_ink_is_the_letters_solid_colour_not_their_soft_edge(self):
        hc = cl.heading_contrast(*self.box(WHITE, DEEP))
        self.assertEqual(hc["ink"], WHITE)
        self.assertEqual(hc["n"], 6)                        # five letter pixels and the edge
        self.assertAlmostEqual(hc["min"], cl.contrast(WHITE, DEEP), places=6)

    # the bug of 2026-11-17 at 375 px: white on the sky
    def test_white_on_the_sky_fails_and_ink_on_the_sky_passes(self):
        self.assertLess(cl.heading_contrast(*self.box(WHITE, SKYPX))["min"], 1.2)
        self.assertGreater(cl.heading_contrast(*self.box(INK, SKYPX))["min"], 12)

    # the bug the scrim fixed (f58c2d3): white over water that is pale where the heading happens to sit
    def test_the_palest_pixel_behind_a_letter_is_the_one_judged(self):
        ground = [DEEP] * 32
        ground[1 * 8 + 2] = WATER                           # one pale pixel under a letter
        hc = cl.heading_contrast(*self.box(WHITE, ground))
        self.assertEqual(hc["worst"], WATER)
        self.assertAlmostEqual(hc["min"], cl.contrast(WHITE, WATER), places=6)
        self.assertLess(hc["min"], cl.START_MIN_CONTRAST)
        self.assertGreater(cl.contrast(WHITE, DEEP), cl.START_MIN_CONTRAST)
        ground[1 * 8 + 2] = DEEP
        ground[0] = WATER                                   # pale, but under no letter: not behind the heading
        self.assertGreater(cl.heading_contrast(*self.box(WHITE, ground))["min"], cl.START_MIN_CONTRAST)

    def test_nothing_drawn_or_boxes_that_differ(self):
        g = (4, 2, [DEEP] * 8)
        self.assertIsNone(cl.heading_contrast(g, g))                         # no letters: the heading was not there
        self.assertIsNone(cl.heading_contrast(g, (2, 4, [DEEP] * 8)))        # two different boxes
        self.assertIsNone(cl.heading_contrast(None, g))

    def test_the_windows(self):
        for must in ((1470, 900), (1280, 645), (375, 667)):
            self.assertIn(must, cl.HEADING_WINDOWS)
        self.assertTrue(any(700 <= w <= 900 for w, _ in cl.HEADING_WINDOWS))  # a tablet
        self.assertTrue(any(901 <= w <= 1200 for w, _ in cl.HEADING_WINDOWS)) # where white measured 2.6:1 before the scrim
        self.assertEqual(cl.START_MIN_CONTRAST, 3.0)


class Contrast(unittest.TestCase):
    def test_wcag_ends(self):
        self.assertAlmostEqual(cl.contrast((0, 0, 0), (255, 255, 255)), 21.0, places=2)
        self.assertAlmostEqual(cl.contrast((255, 255, 255), (255, 255, 255)), 1.0, places=6)
        self.assertAlmostEqual(cl.contrast((255, 255, 255), (0, 0, 0)), cl.contrast((0, 0, 0), (255, 255, 255)), places=6)

    def test_rgb(self):
        self.assertEqual(cl._rgb("rgb(24,43,73)"), (24.0, 43.0, 73.0))
        self.assertEqual(cl._rgb("rgba(24, 43, 73, 0.5)"), (24.0, 43.0, 73.0))
        self.assertIsNone(cl._rgb(None))


class FirstScreen(unittest.TestCase):
    def test_a_sound_first_screen_passes(self):
        self.assertEqual(run(hero()), [])
        self.assertEqual(run(hero(), fold=True), [])
        self.assertEqual(run(phone(), width=375), [])

    def test_task_patterns(self):
        pat = {t[0]: t[2] for t in cl.FRONT_TASKS}
        hit = lambda t, h: bool(cl.task_links([link(h)], pat[t]))  # noqa: E731
        self.assertTrue(hit("explore", "https://calcofi.io/explore/"))
        self.assertTrue(hit("explore", "/explore/"))                       # a preview build's own folder
        self.assertFalse(hit("explore", "https://calcofi.io/explore/builder.html"))
        self.assertFalse(hit("explore", "https://calcofi.io/query/"))
        self.assertFalse(hit("explore", "#explore"))                       # the panel is not the app
        # the Query Builder's own address (2026-11-17): calcofi.io/query/, /query/ in a preview, with or
        # without a query string; its old place under the Explorer no longer answers the task
        self.assertTrue(hit("builder", "https://calcofi.io/query/"))
        self.assertTrue(hit("builder", "/query/"))
        self.assertTrue(hit("builder", "https://calcofi.io/query/?pick=bio:a:b&download=1"))
        self.assertFalse(hit("builder", "https://calcofi.io/explore/builder.html"))
        self.assertFalse(hit("builder", "/explore/builder.html?pick=bio:a:b"))
        self.assertFalse(hit("builder", "https://calcofi.io/query/help.html"))
        self.assertFalse(hit("builder", "https://calcofi.io/db-query/"))    # the SQL console is another product
        self.assertFalse(hit("builder", "/datasets/?q=query/"))
        self.assertFalse(hit("builder", "https://calcofi.io/query/#about"))
        self.assertTrue(hit("find", "/datasets/"))
        self.assertFalse(hit("find", "/datasets/swfsc_ichthyo/"))
        self.assertTrue(hit("cite", "https://calcofi.io/docs/cite.html"))
        self.assertFalse(hit("contribute", "https://calcofi.io/workflows/"))   # front-door-v2's "Share your data" went here
        self.assertTrue(hit("learn", "#learn"))                            # the ship's label
        self.assertTrue(hit("learn", "/#learn"))                           # the header's line, written from any page
        self.assertFalse(hit("learn", "https://calcofi.io/docs/#learn"))

    # 2026-11-17: the strip is Contribute and Statewide monitoring; the header's Learn menu holds How
    # CalCOFI samples (/#learn) and Cite the data
    def test_only_learn_and_cite_may_be_answered_by_the_header(self):
        self.assertEqual({t[0] for t in cl.FRONT_TASKS if "header" in t[3]}, {"learn", "cite"})
        self.assertTrue(all("hero" in t[3] for t in cl.FRONT_TASKS))

    def test_task_words(self):
        pat = {t[0]: t[2] for t in cl.FRONT_TASKS}
        self.assertEqual([x["id"] for x in cl.task_words(bar(), pat["cite"])], ["learn"])         # a word whose menu holds the line
        self.assertEqual([x["id"] for x in cl.task_words(bar(), pat["learn"])], ["learn"])        # (How CalCOFI samples → /#learn)
        plain = [word("cite", "Cite", "https://calcofi.io/docs/cite.html")]
        self.assertEqual([x["id"] for x in cl.task_words(plain, pat["cite"])], ["cite"])          # …or a word that is the link
        self.assertEqual([x["id"] for x in cl.task_words(bar(), pat["builder"])], ["data"])       # Data ▾ › Get it › Query Builder
        self.assertEqual([x["id"] for x in cl.task_words(bar(), pat["explore"])], ["map"])
        # the news lines are not the Learn panel, and a docs page is not the citation chapter
        self.assertEqual(cl.task_words([word("learn", "Learn", lines=["/news/", "https://calcofi.io/docs/"])], pat["learn"]), [])
        self.assertEqual(cl.task_words([word("learn", "Learn", lines=["/news/", "https://calcofi.io/docs/"])], pat["cite"]), [])
        self.assertEqual(cl.task_words(bar(), pat["monitor"]), [])
        self.assertEqual(cl.task_words(None, pat["cite"]), [])

    def test_cite_is_a_line_of_the_headers_learn_menu(self):
        self.assertEqual(run(hero()), [])
        H = hero()
        for x in H["header"]:
            if x["id"] == "learn":
                x["lines"] = [u for u in x["lines"] if not u.endswith("/docs/cite.html")]
        f = run(H)
        self.assertEqual(len(f), 1)
        self.assertIn("no visible link on the first screen for: cite (Cite the data)", f[0])
        H = hero()                                                         # Learn gone from the bar: both of its tasks
        H["header"] = [x for x in H["header"] if x["id"] != "learn"]
        H["links"] = [x for x in H["links"] if x["href"] != "#learn"]
        self.assertIn("learn (See what CalCOFI collects), cite (Cite the data)", run(H)[0])

    def test_learn_without_the_ships_label_is_the_headers_line(self):
        H = hero()
        H["links"] = [x for x in H["links"] if x["href"] != "#learn"]
        H["tag"] = {"visible": True, "display": "inline", "w": 292}
        self.assertEqual([x for x in run(H) if "no visible link" in x], [])
        for x in H["header"]:
            if x["id"] == "learn":
                x["lines"] = [u for u in x["lines"] if u != "/#learn"]
        self.assertTrue(any("learn (See what CalCOFI collects)" in x for x in run(H)))

    # nothing loosened: a card or a strip link that goes missing is NOT excused by a line of a menu
    def test_a_missing_card_is_not_excused_by_the_header(self):
        H = hero()
        H["links"] = [x for x in H["links"] if x["href"] != "https://calcofi.io/explore/"]
        f = run(H)                                                         # Map ▾ still holds the Explorer
        self.assertEqual(len(f), 1)
        self.assertIn("explore (Explore and download on a map) — a link on the first screen itself, not a line of a menu", f[0])
        H = hero()
        H["links"] = [x for x in H["links"] if x["href"] != "#program"]
        self.assertTrue(any("program (Work with the data in code)" in x for x in run(H)))
        # the third card's link gone: a line of the header's Data menu still links calcofi.io/query/, and does not excuse it
        H = hero()
        H["links"] = [x for x in H["links"] if x["href"] != "https://calcofi.io/query/"]
        self.assertEqual([x["id"] for x in cl.task_words(H["header"], cl.QUERY_PAT)], ["data"])
        f = run(H)
        self.assertEqual(len(f), 1)
        self.assertIn("builder (the Query Builder) — a link on the first screen itself, not a line of a menu", f[0])
        H = hero()                                                         # a card still linking the old address is a missing card
        for x in H["links"]:
            if x["href"] == "https://calcofi.io/query/":
                x["href"] = "https://calcofi.io/explore/builder.html"
        self.assertTrue(any("builder (the Query Builder)" in x for x in run(H)))

    def test_under_the_breakpoint_the_menu_button_carries_the_headers_tasks(self):
        self.assertEqual(run(phone(), width=375), [])
        f = run(phone(menuButton=False), width=375)                        # no button: the words are nowhere
        self.assertEqual(len(f), 1)
        self.assertIn("learn (See what CalCOFI collects), cite (Cite the data)", f[0])
        # over the breakpoint a hidden bar is not excused by a button
        f = run(hero(header=bar(visible=False), menuButton=True))
        self.assertTrue(any("cite (Cite the data)" in x for x in f))

    def test_in_the_folds_window_every_word_of_the_bar_is_drawn(self):
        H = hero()
        H["header"][3]["visible"] = False
        self.assertEqual(run(H), [])
        f = run(H, fold=True)
        self.assertEqual(len(f), 1)
        self.assertIn("the header's words ['calcofi.org ↗'] are not drawn in a 1280 x 645 window", f[0])

    def test_a_hidden_link_does_not_count(self):
        H = hero()
        for x in H["links"]:
            if x["href"] == "#monitor":
                x["visible"] = False
        self.assertTrue(any("monitor" in x and "no visible link" in x for x in run(H)))

    def test_a_link_under_the_tap_target_fails(self):
        H = hero()
        for x in H["links"]:
            if x["href"] == "https://calcofi.io/docs/provide.html":
                x["h"] = 18
        f = run(H)
        self.assertEqual(len(f), 1)
        self.assertIn("under the 32px tap target: contribute 18px", f[0])

    def test_the_tallest_link_of_a_task_is_the_one_judged(self):
        H = hero()
        H["links"].append(link("#monitor", "card", h=12))     # a second, smaller way to the same task changes nothing
        self.assertEqual(run(H), [])

    def test_the_fold_only_when_asked(self):
        H = hero()
        for x in H["links"]:
            if x["href"] == "#monitor":
                x["bottom"] = 694
        self.assertEqual(run(H), [])
        f = run(H, fold=True)
        self.assertEqual(len(f), 1)
        self.assertIn("end below the 645px fold", f[0])
        self.assertIn("monitor 694px", f[0])

    def test_a_card_below_the_fold(self):
        H = hero()
        H["cards"][2]["bottom"] = 660
        H["strip"]["top"] = 670
        self.assertTrue(any("start card(s) ['Pull exact data'] end below the 645px fold" in x for x in run(H, fold=True)))

    def test_three_cards(self):
        H = hero()
        H["cards"] = H["cards"][:2]
        self.assertTrue(any("draws 2 start cards, expected 3" in x for x in run(H)))

    # the bug of 2026-11-17: wrapped on a phone, the absolutely placed strip rode up over the last card
    def test_the_strip_over_the_cards_fails(self):
        H = hero()
        H["strip"]["top"] = 520
        f = run(H)
        self.assertEqual(len(f), 1)
        self.assertIn("the strip of links starts at 520px, over the start cards (the last ends at 560px)", f[0])

    # the bug of 2026-11-17: "MEASUREMENTS" ran off the right edge at 375 px
    def test_a_number_outside_the_window_fails(self):
        H = phone(nums=[{"label": "years", "left": 24, "right": 64}, {"label": "measurements", "left": 290, "right": 386}])
        f = run(H, width=375)
        self.assertEqual(len(f), 1)
        self.assertIn("number(s) ['measurements'] run outside the 375px window", f[0])

    # the bug of 2026-11-17: the label by the ship was cut by the screen's edge and lay under the first card, still a link
    def test_the_ships_label_on_a_phone_fails_and_missing_on_a_desktop_fails(self):
        f = run(phone(tag={"visible": True, "display": "inline", "w": 498}), width=375)
        self.assertEqual(len(f), 1)
        self.assertIn("the ship's label is still a drawn link under 900px", f[0])
        f = run(hero(tag={"visible": False, "display": "none", "w": 0}))
        self.assertEqual(len(f), 1)
        self.assertIn("the ship's label is not drawn at 1280px", f[0])

    def test_the_drawing(self):
        self.assertTrue(any("was not drawn" in x for x in run(hero(drawn=0))))
        self.assertTrue(any("has no floor" in x for x in run(hero(ridge=False))))
        self.assertEqual(run(hero(ridge=False, floorData=False)), [])      # no profile on the page: no floor is drawn, never a made-up one
        self.assertTrue(any("carries 3 pins" in x for x in run(hero(svgPins=3))))


NAV_YML = """# a comment
words:
  - id: data
    title: Data
    here: [datasets]
    menu:
      - title: Find
        items:
          - { title: Datasets, href: /datasets/, count: datasets }
  - { id: query, title: Query, query: "" }
  - id: learn
    title: Learn
    menu:
      - { title: Docs, section: docs }
  - { id: faq,  title: FAQ,  section: faq }
  - { id: org,  title: "calcofi.org ↗", href: "https://calcofi.org", ext: true }
"""


class Nav(unittest.TestCase):
    def test_words_in_order_with_their_ids_and_menus(self):
        self.assertEqual(cl.nav_words(NAV_YML), [
            {"id": "data", "title": "Data", "menu": True}, {"id": "query", "title": "Query", "menu": False},
            {"id": "learn", "title": "Learn", "menu": True}, {"id": "faq", "title": "FAQ", "menu": False},
            {"id": "org", "title": "calcofi.org ↗", "menu": False}])

    def test_a_menus_own_items_are_not_words(self):
        self.assertNotIn("Datasets", [x["title"] for x in cl.nav_words(NAV_YML)])
        self.assertNotIn("Find", [x["title"] for x in cl.nav_words(NAV_YML)])
        self.assertNotIn("Docs", [x["title"] for x in cl.nav_words(NAV_YML)])

    def test_no_list_no_words(self):
        self.assertEqual(cl.nav_words(""), [])
        self.assertEqual(cl.nav_words(None), [])
        self.assertEqual(cl.nav_words("products:\n  - key: a\n"), [])

    # THE list (Ben, 2026-11-17, evening: "simplify the nav and fold under [Learn]: How CalCOFI samples,
    # Frequently asked questions, Cite the data, Documentation, News with subnav to Tutorials, Stories(,
    # All)"; then Query off the bar, the Query Builder the first line of Data ▾ › Get it): four words,
    # three of them menus. Query, Cite, Docs, FAQ and News were words of the bar for a few hours that
    # day; they are lines of Data and Learn now, and NAV_REACH (judged on the built page) still holds
    # the header to linking each. The check holds the bar to _data/nav.yml, and this holds
    # _data/nav.yml: a word cannot leave the bar, or join it, by editing the list unseen.
    def test_the_sites_own_list_is_the_four_words(self):
        with open(os.path.join(HERE, "..", "_data", "nav.yml"), encoding="utf-8") as f:
            words = cl.nav_words(f.read())
        self.assertEqual([x["title"] for x in words], ["Data", "Map", "Learn", "calcofi.org ↗"])
        self.assertEqual([x["id"] for x in words], ["data", "map", "learn", "org"])
        self.assertEqual([x["title"] for x in words if x["menu"]], ["Data", "Map", "Learn"])
        self.assertEqual(cl.NAV_WORDS, [x["title"] for x in words])
        self.assertEqual(cl.NAV_IDS, [x["id"] for x in words])
        self.assertEqual(cl.NAV_MENUS, ["Data", "Map", "Learn"])

    # what the header must still link somewhere, a word or a line of a menu: everything main's eight
    # words reached. With four words, five of these are reached only through Learn, and the Query
    # Builder only through Data.
    def test_nav_reach_is_met_by_lines_of_the_menus(self):
        links = [u for x in bar() for u in ([x["href"]] if x["href"] else []) + x["lines"]]
        missing = [label for label, pat in cl.NAV_REACH if not any(re.search(pat, u) for u in links)]
        self.assertEqual(missing, [])
        through_learn = [label for label, pat in cl.NAV_REACH if any(re.search(pat, u) for u in LEARN_LINES)]
        self.assertEqual(through_learn, ["how to cite", "the docs", "the FAQ", "News", "what CalCOFI collects (#learn)"])
        no_learn = [u for x in bar() if x["id"] != "learn" for u in ([x["href"]] if x["href"] else []) + x["lines"]]
        self.assertEqual([label for label, pat in cl.NAV_REACH if not any(re.search(pat, u) for u in no_learn)], through_learn)
        no_query = [u for u in links if u != "https://calcofi.io/query/"]
        self.assertEqual([label for label, pat in cl.NAV_REACH if not any(re.search(pat, u) for u in no_query)], ["the Query Builder"])

    def test_nav_json_titles(self):
        self.assertEqual(cl.nav_json_titles({"version": "3", "words": [{"id": "a", "title": "A"}, {"id": "b", "title": "B", "menu": []}]}), ["A", "B"])
        self.assertEqual(cl.nav_json_titles(None), [])
        self.assertEqual(cl.nav_json_titles({}), [])


NAVY = ["rgb(20,40,74)", "rgb(29,61,102)"]


def band(**over):
    x = {"cls": "cc-wave cc-wave-slim cc-wave-auto", "own": False, "top": 72, "bottom": 106, "left": 0, "right": 1470, "h": 34,
         "paint": list(NAVY), "after": {"h": 18, "mask": True, "fill": "rgb(255,255,255)"}, "svg": None, "hidden": None}
    x.update(over)
    return x


def wave(*bands, ground="rgb(255,255,255)", header_bottom=72):
    return {"headerBottom": header_bottom, "ground": ground, "all": len(bands), "drawn": list(bands)}


def waves(wv, width=1470):
    fails, notes = [], []
    cl.check_wave("x", wv, width, fails, notes)
    return fails


class Wave(unittest.TestCase):
    def test_navy(self):
        self.assertTrue(cl.is_navy((20, 40, 74)))
        self.assertTrue(cl.is_navy((29, 61, 102)))
        self.assertFalse(cl.is_navy((255, 255, 255)))
        self.assertFalse(cl.is_navy((0, 98, 155)))          # the accent blue: too light
        self.assertFalse(cl.is_navy((74, 40, 20)))          # dark, but not blue
        self.assertFalse(cl.is_navy(None))

    def test_a_sound_band_passes_in_both_themes(self):
        self.assertEqual(waves(wave(band())), [])
        self.assertEqual(waves(wave(band(after={"h": 18, "mask": True, "fill": "rgb(15,26,46)"}), ground="rgb(15,26,46)")), [])
        own = band(cls="bd-head cc-wave cc-wave-own", own=True, after=None, bottom=206, h=134,
                   svg={"h": 40, "bottomGap": 1, "fill": "rgb(255,255,255)"})
        self.assertEqual(waves(wave(own)), [])

    def test_exactly_one(self):
        f = waves(wave())
        self.assertEqual(len(f), 1)
        self.assertIn("0 wave bands (.cc-wave) are drawn under the bar, expected exactly one", f[0])
        f = waves(wave(band(), band(cls="bd-head cc-wave cc-wave-own", top=106)))
        self.assertEqual(len(f), 1)
        self.assertIn("2 wave bands", f[0])

    def test_directly_under_the_bar(self):
        self.assertTrue(any("12px below the bar's bottom (72px): a gap" in x for x in waves(wave(band(top=84)))))
        self.assertTrue(any("under the bar (which ends at 72px)" in x for x in waves(wave(band(top=40)))))
        self.assertTrue(any("covered by 'hero'" in x for x in waves(wave(band(hidden="hero")))))
        self.assertTrue(any("not edge to edge" in x for x in waves(wave(band(left=24, right=1446)))))

    def test_navy_and_never_the_ground(self):
        f = waves(wave(band(paint=["rgb(255,255,255)"])))
        self.assertTrue(any("not the brand's navy" in x for x in f))
        self.assertTrue(any("painted with the page ground" in x for x in f))
        self.assertTrue(any("has no background" in x for x in waves(wave(band(paint=[])))))
        # the dark theme's ground is itself a dark navy: a band painted with it has vanished
        f = waves(wave(band(paint=["rgb(15,26,46)"], after={"h": 18, "mask": True, "fill": "rgb(15,26,46)"}), ground="rgb(15,26,46)"))
        self.assertTrue(any("painted with the page ground rgb(15,26,46)" in x for x in f))

    def test_the_edge_is_drawn_and_shows(self):
        self.assertTrue(any("edge is not drawn" in x for x in waves(wave(band(after=None)))))
        self.assertTrue(any("edge is not drawn" in x for x in waves(wave(band(after={"h": 18, "mask": False, "fill": "rgb(255,255,255)"})))))
        self.assertTrue(any("no edge shows" in x for x in waves(wave(band(after={"h": 18, "mask": True, "fill": "rgb(29,61,102)"})))))
        own = dict(cls="x cc-wave cc-wave-own", own=True, after=None)
        self.assertTrue(any("has no svg wave" in x for x in waves(wave(band(svg=None, **own)))))
        self.assertTrue(any("ends 30px from the band's bottom" in x for x in waves(wave(band(svg={"h": 40, "bottomGap": 30, "fill": "rgb(255,255,255)"}, **own)))))
        self.assertTrue(any("no edge shows" in x for x in waves(wave(band(svg={"h": 40, "bottomGap": 0, "fill": "rgb(29,61,102)"}, **own)))))


if __name__ == "__main__":
    unittest.main()
