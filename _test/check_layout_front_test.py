#!/usr/bin/env python3
"""_test/check_layout_front_test.py — the pure rules scripts/check_layout.py judges front door v2 by
(the first screen of 2026-11-17: section.hero, _includes/front_door_hero.html). The browser only
measures; these functions decide, so each is pinned here on a small synthetic measurement:

    python3 _test/check_layout_front_test.py

  products   product_keys: every product is drawn except a `superseded` one; an `archived` one is
             still drawn (the student projects) — the rule Betty's change to the check stated too wide
  gradient   grad_at: the colour of the drawing's sky or water at a height, from its own stops
  contrast   contrast / start_contrast: WCAG's ratio, and the LOWEST of the start heading's sample
             points (white on the sky was 1.1:1 at 375 px until c38911f)
  tasks      task_links / check_first_screen: each of the seven tasks and the Query Builder is one
             visible link, at least a tap target tall, above the 1280 x 645 fold when asked; the
             strip under the cards; the numbers inside the window; the ship's label gone on a phone
"""
import importlib.util, os, unittest

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

SKY = [[0, "rgb(255,255,255)"], [0.72, "rgb(241,246,251)"], [1, "rgb(220,233,244)"]]
WATER = [[0, "rgb(140,195,230)"], [0.25, "rgb(74,146,198)"], [0.7, "rgb(30,95,147)"], [1, "rgb(18,63,104)"]]


def link(href, where="strip", h=40, bottom=600, visible=True, text=""):
    return {"href": href, "where": where, "h": h, "w": 120, "top": bottom - h, "bottom": bottom,
            "left": 0, "right": 120, "visible": visible, "text": text or href}


def hero(**over):
    """a first screen on which every assertion passes, at 1280 wide"""
    links = [link("#learn"), link("https://calcofi.io/explore/", "card"), link("/datasets/", "card"),
             link("#program", "card"), link("https://calcofi.io/docs/cite.html"),
             link("https://calcofi.io/docs/provide.html"), link("#monitor"),
             link("https://calcofi.io/explore/builder.html", "card"), link("#explore")]
    cards = [{"title": t, "top": 380, "bottom": 560, "left": x, "right": x + 380, "h": 180, "w": 380}
             for t, x in (("Visualize on a map", 20), ("Download a dataset", 420), ("Pull exact data", 820))]
    H = {"top": 72, "bottom": 712, "innerH": 645, "innerW": 1280, "links": links, "cards": cards,
         "strip": {"top": 580, "bottom": 612, "left": 20, "right": 700, "h": 32, "w": 680},
         "start": {"top": 330, "bottom": 364, "left": 20, "right": 400, "h": 34, "w": 380, "color": "rgb(255,255,255)",
                   "behind": {"pts": [{"layer": "hero-water", "t": 0.5}], "stops": {"hero-sky": SKY, "hero-water": WATER}}},
         "tag": {"visible": True, "display": "inline", "w": 292},
         "nums": [{"label": "years", "left": 1100, "right": 1150}, {"label": "measurements", "left": 1160, "right": 1256}],
         "drawn": 8, "ridge": True, "floorData": True, "svgPins": 0}
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


class Gradient(unittest.TestCase):
    def test_at_a_stop_between_stops_and_outside(self):
        self.assertEqual(cl.grad_at(WATER, 0), (140.0, 195.0, 230.0))
        self.assertEqual(cl.grad_at(WATER, 1), (18.0, 63.0, 104.0))
        self.assertEqual(cl.grad_at(WATER, 0.125), (107.0, 170.5, 214.0))      # half way from the first stop to the second
        self.assertEqual(cl.grad_at(WATER, -1), (140.0, 195.0, 230.0))
        self.assertEqual(cl.grad_at(WATER, 2), (18.0, 63.0, 104.0))

    def test_unsorted_stops_and_none(self):
        self.assertEqual(cl.grad_at(list(reversed(WATER)), 0.125), (107.0, 170.5, 214.0))
        self.assertIsNone(cl.grad_at([], 0.5))
        self.assertIsNone(cl.grad_at([[0, "none"]], 0.5))

    def test_rgb(self):
        self.assertEqual(cl._rgb("rgb(24,43,73)"), (24.0, 43.0, 73.0))
        self.assertEqual(cl._rgb("rgba(24, 43, 73, 0.5)"), (24.0, 43.0, 73.0))
        self.assertIsNone(cl._rgb(None))


class Contrast(unittest.TestCase):
    def test_wcag_ends(self):
        self.assertAlmostEqual(cl.contrast((0, 0, 0), (255, 255, 255)), 21.0, places=2)
        self.assertAlmostEqual(cl.contrast((255, 255, 255), (255, 255, 255)), 1.0, places=6)
        self.assertAlmostEqual(cl.contrast((255, 255, 255), (0, 0, 0)), cl.contrast((0, 0, 0), (255, 255, 255)), places=6)

    # the bug of 2026-11-17: at 375 px "Where do you want to start?" sat in the SKY, white on #f1f6fb
    def test_white_on_the_sky_fails_and_ink_on_the_sky_passes(self):
        behind = {"pts": [{"layer": "hero-sky", "t": 0.72}], "stops": {"hero-sky": SKY, "hero-water": WATER}}
        c, layer = cl.start_contrast({"color": "rgb(255,255,255)", "behind": behind})
        self.assertLess(c, 1.2)
        self.assertEqual(layer, "hero-sky")
        c, _ = cl.start_contrast({"color": "rgb(24,43,73)", "behind": behind})
        self.assertGreater(c, 12)

    def test_the_lowest_sample_point_is_the_one_reported(self):
        behind = {"pts": [{"layer": "hero-water", "t": 0.7}, {"layer": "hero-water", "t": 0.0}, {"layer": "hero-water", "t": 1.0}],
                  "stops": {"hero-water": WATER}}
        c, layer = cl.start_contrast({"color": "rgb(255,255,255)", "behind": behind})
        self.assertAlmostEqual(c, cl.contrast((255, 255, 255), (140, 195, 230)), places=6)   # the light water at the surface
        self.assertLess(c, cl.START_MIN_CONTRAST)

    def test_nothing_to_read(self):
        self.assertEqual(cl.start_contrast(None), (None, None))
        self.assertEqual(cl.start_contrast({"color": "rgb(255,255,255)", "behind": None}), (None, None))


class FirstScreen(unittest.TestCase):
    def test_a_sound_first_screen_passes(self):
        self.assertEqual(run(hero()), [])
        self.assertEqual(run(hero(), fold=True), [])

    def test_task_patterns(self):
        pat = {t: p for t, _, p in cl.FRONT_TASKS}
        hit = lambda t, h: bool(cl.task_links([link(h)], pat[t]))  # noqa: E731
        self.assertTrue(hit("explore", "https://calcofi.io/explore/"))
        self.assertTrue(hit("explore", "/explore/"))                       # a preview build's own folder
        self.assertFalse(hit("explore", "https://calcofi.io/explore/builder.html"))
        self.assertFalse(hit("explore", "#explore"))                       # the panel is not the app
        self.assertTrue(hit("builder", "/explore/builder.html"))
        self.assertTrue(hit("builder", "https://calcofi.io/explore/builder.html?pick=bio:a:b"))
        self.assertTrue(hit("find", "/datasets/"))
        self.assertFalse(hit("find", "/datasets/swfsc_ichthyo/"))
        self.assertTrue(hit("cite", "https://calcofi.io/docs/cite.html"))
        self.assertFalse(hit("contribute", "https://calcofi.io/workflows/"))   # front-door-v2's "Share your data" went here

    def test_a_missing_task_is_named(self):
        H = hero()
        H["links"] = [x for x in H["links"] if x["href"] != "#program"]
        f = run(H)
        self.assertEqual(len(f), 1)
        self.assertIn("no visible link on the first screen for: program (Work with the data in code)", f[0])

    def test_a_hidden_link_does_not_count(self):
        H = hero()
        for x in H["links"]:
            if x["href"] == "#monitor":
                x["visible"] = False
        self.assertTrue(any("monitor" in x and "no visible link" in x for x in run(H)))

    def test_a_link_under_the_tap_target_fails(self):
        H = hero()
        for x in H["links"]:
            if x["href"] == "https://calcofi.io/docs/cite.html":
                x["h"] = 18
        f = run(H)
        self.assertEqual(len(f), 1)
        self.assertIn("under the 32px tap target: cite 18px", f[0])

    def test_the_tallest_link_of_a_task_is_the_one_judged(self):
        H = hero()
        H["links"].append(link("#learn", "drawing", h=12))     # a second, smaller way to the same task changes nothing
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

    def test_white_heading_on_the_sky_fails(self):
        H = hero()
        H["start"]["behind"]["pts"] = [{"layer": "hero-sky", "t": 0.7}]
        f = run(H, width=375)
        self.assertTrue(any("under 3:1" in x and "against the sky" in x for x in f))

    # the bug of 2026-11-17: "MEASUREMENTS" ran off the right edge at 375 px
    def test_a_number_outside_the_window_fails(self):
        H = hero(innerW=375)
        H["nums"] = [{"label": "years", "left": 24, "right": 64}, {"label": "measurements", "left": 290, "right": 386}]
        H["tag"] = {"visible": False, "display": "none", "w": 0}
        f = run(H, width=375)
        self.assertEqual(len(f), 1)
        self.assertIn("number(s) ['measurements'] run outside the 375px window", f[0])

    # the bug of 2026-11-17: the label by the ship was cut by the screen's edge and lay under the first card, still a link
    def test_the_ships_label_on_a_phone_fails_and_missing_on_a_desktop_fails(self):
        f = run(hero(innerW=375, nums=[]), width=375)
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


if __name__ == "__main__":
    unittest.main()
