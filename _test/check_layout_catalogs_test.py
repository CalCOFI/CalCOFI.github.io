#!/usr/bin/env python3
"""_test/check_layout_catalogs_test.py — the pure rules scripts/check_layout.py judges the three catalog
pages by since 2026-11-17 (Ben: "fix with mix. Should be able to add species hierarchy view back as
another tab"). The browser only measures; these functions decide, so each is pinned here on a small
synthetic measurement, one fixture per rule:

    python3 _test/check_layout_catalogs_test.py

  categories  category_faults (/measurements/, issue #30 D8): By category opens with every category a
              CLOSED button that says what is inside; a press opens one in place and a second shuts
              it; a search opens the categories that hold a match and draws no other; clearing it
              shuts them; ?q= on the URL lands the same way; the preview never shows a hidden row
  higher taxa higher_faults (/species/): a search lists the taxa that are not species rows (a genus,
              a family …) apart from the species, under them, each a link to its page saying its
              rank and what it holds — and nothing of the kind without a search
  hierarchy   hierarchy_faults (/species/): main's icicle is a tab again, drawn when shown and only
              then, zooming on a band and climbing back by the breadcrumb
  views       SPECIES_VIEWS, SPECIES_OLD_VIEWS: the five tabs, and main's ?tab=classes → Groups
  ceiling     MAX_DS_H: the catalog's height ceiling as restated for a finder — the measured page and
              two more datasets, not 25; the dataset page's ceiling and the measurements index's
              are the numbers they were
"""
import copy, importlib.util, os, sys, unittest

sys.dont_write_bytecode = True    # the script is loaded by path: leave no scripts/__pycache__ behind

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("check_layout", os.path.join(HERE, "..", "scripts", "check_layout.py"))
cl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cl)


# ── the catalogs' crumb row ───────────────────────────────────────────────────
class CrumbCanWrap(unittest.TestCase):
    """found by the PR workflow on Linux, 2026-11-17: all three catalog pages scrolled sideways 2 to 4 px at 375 px"""

    def test_a_row_that_wraps_stays_in_its_box(self):
        self.assertEqual([], cl.crumb_faults({"squeezed": 300, "box": 300, "links": 3}))

    def test_a_row_that_cannot_wrap_runs_past_it(self):
        faults = cl.crumb_faults({"squeezed": 368, "box": 300, "links": 3})
        self.assertEqual(1, len(faults))
        self.assertIn("cannot wrap", faults[0])
        self.assertIn("368", faults[0])

    def test_a_pixel_of_rounding_is_not_a_fault(self):
        self.assertEqual([], cl.crumb_faults({"squeezed": 301, "box": 300, "links": 3}))

    def test_a_page_without_the_row_is_not_judged(self):
        self.assertEqual([], cl.crumb_faults(None))


# ── /measurements/, By category ───────────────────────────────────────────────
def cat(name, rows, says="false", shown=0, **over):
    c = {"cat": name, "rows": rows, "shown": shown, "n": rows, "button": True, "says": says, "controls": True,
         "bodyHidden": says != "true", "hint": 30}
    c.update(over)
    return c


def found(*cats, **over):
    """what one typed search read back: the categories drawn, each open with its matches in view"""
    cs = [{"cat": n, "rows": r, "shown": r, "says": "true"} for n, r in cats]
    v = {"rows": sum(r for _, r in cats), "list": sum(r for _, r in cats), "shown": sum(r for _, r in cats), "cats": cs, "pvRow": "in view"}
    v.update(over)
    return v


def mm(**over):
    """the measurements index as it loads By category on a wide screen, every assertion passing"""
    m = {"view": "cat", "q": "", "pvRow": None,
         "listCats": [cat("Physical", 55), cat("Nutrients", 16), cat("Carbonate", 6)],
         "press": {"cat": "Physical", "says": "true", "shown": 55, "rows": 55, "others": 0, "moved": 0, "focusKept": True,
                   "pvRow": "in view", "pvTitle": "Temperature", "colHeads": 1,
                   "again": {"says": "false", "shown": 0, "pvRow": None}},
         "search": {"nitrate": found(("Nutrients", 6)), "METS": found(("Physical", 9), ("Nutrients", 1))},
         "cleared": {"cats": [{"cat": n, "rows": r, "shown": 0, "says": "false"} for n, r in (("Physical", 55), ("Nutrients", 16), ("Carbonate", 6))]}}
    m.update(over)
    return m


def faults(m, width=1470):
    return cl.category_faults(m, width)


class Categories(unittest.TestCase):
    def test_a_sound_page_passes_wide_and_on_a_phone(self):
        self.assertEqual(faults(mm()), [])
        self.assertEqual(faults(mm(), 375), [])

    def test_another_view_is_not_judged(self):
        self.assertEqual(faults(mm(view="az", listCats=[], press=None)), [])

    # THE regression: front door v2 listed every category open, 104 rows, 8,643 px
    def test_a_category_open_on_load_fails(self):
        m = mm()
        m["listCats"][1] = cat("Nutrients", 16, says="true", shown=16)
        f = faults(m)
        self.assertEqual(len(f), 1)
        self.assertIn("category 'Nutrients' is open on load (aria-expanded=true, 16 row(s) in view)", f[0])
        self.assertEqual(len(faults(mm(listCats=[cat(n, r, says="true", shown=r) for n, r in (("Physical", 55), ("Nutrients", 16))]))), 2)

    def test_closed_in_name_only_fails(self):
        m = mm()
        m["listCats"][0] = cat("Physical", 55, shown=55)                    # says shut, rows in view
        self.assertIn("is open on load (aria-expanded=false, 55 row(s) in view)", faults(m)[0])
        m = mm()
        m["listCats"][0] = cat("Physical", 55, bodyHidden=False)            # says shut, its rows not hidden
        self.assertIn("'Physical' is open on load", faults(m)[0])

    def test_a_category_must_be_a_button_naming_its_rows(self):
        m = mm()
        m["listCats"][2] = cat("Carbonate", 6, button=False)
        self.assertEqual(faults(m), ["category 'Carbonate' is not a button naming its rows (h3 > button[aria-controls])"])
        m["listCats"][2] = cat("Carbonate", 6, controls=False)
        self.assertEqual(len(faults(m)), 1)

    def test_a_closed_category_says_what_is_inside(self):
        m = mm()
        m["listCats"][0] = cat("Physical", 55, hint=0)
        self.assertEqual(faults(m), ["closed category 'Physical' does not say what is inside"])

    def test_the_preview_never_shows_a_hidden_row(self):
        self.assertEqual(faults(mm(pvRow="hidden")), ["the preview shows a row that is hidden inside a closed category"])
        self.assertEqual(faults(mm(pvRow="in view")), [])                   # a row in an open category (?cat=)

    def test_a_press_opens_that_category_and_no_other(self):
        m = mm()
        m["press"].update(says="false", shown=0)
        self.assertIn("pressing 'Physical': aria-expanded=false, 0 of 55 row(s) in view", faults(m)[0])
        m = mm()
        m["press"]["shown"] = 20
        self.assertIn("20 of 55 row(s) in view", faults(m)[0])
        m = mm()
        m["press"]["others"] = 2
        self.assertEqual(faults(m), ["pressing 'Physical' opened 2 other categories"])
        self.assertEqual(faults(mm(press=None)), ["no category button to press"])

    def test_a_press_does_not_move_the_button_or_take_the_focus(self):
        m = mm()
        m["press"]["moved"] = 45                                            # column heads drawn above every category on open
        self.assertEqual(faults(m), ["pressing 'Physical' moved its own button 45px"])
        m["press"]["moved"] = 1                                             # a rounding pixel
        self.assertEqual(faults(m), [])
        m["press"]["focusKept"] = False                                     # the list was redrawn under the button
        self.assertEqual(faults(m), ["pressing 'Physical' lost the focus from its button"])

    def test_with_a_category_open_the_preview_is_on_a_row_in_view(self):
        m = mm()
        m["press"].update(pvRow=None, pvTitle="Choose a measurement")
        self.assertEqual(faults(m), ["with 'Physical' open the preview is not on a row in view ('Choose a measurement')"])
        self.assertEqual(faults(m, 375), [])                                # under 1000 px there is no preview pane

    def test_a_second_press_shuts_it(self):
        m = mm()
        m["press"]["again"] = {"says": "true", "shown": 55, "pvRow": "in view"}
        self.assertIn("a second press does not shut 'Physical'", faults(m)[0])
        m["press"]["again"] = {"says": "false", "shown": 0, "pvRow": "hidden"}
        self.assertEqual(faults(m), ["with 'Physical' shut again the preview still shows one of its rows"])

    def test_a_search_opens_the_categories_that_hold_a_match(self):
        m = mm()
        m["search"]["nitrate"]["cats"][0].update(says="false", shown=0)
        m["search"]["nitrate"]["shown"] = 0
        f = faults(m)
        self.assertEqual(f, ["search 'nitrate' leaves ['Nutrients'] closed though each holds a match",
                             "search 'nitrate': 0 of 6 match(es) in view"])

    def test_a_search_draws_no_category_without_a_match(self):
        m = mm()
        m["search"]["nitrate"]["cats"].append({"cat": "Carbonate", "rows": 0, "shown": 0, "says": "false"})
        self.assertEqual(faults(m), ["search 'nitrate' draws ['Carbonate'] though none holds a match"])

    def test_clearing_the_search_shuts_what_it_opened(self):
        m = mm()
        m["cleared"]["cats"][1].update(says="true", shown=16)
        self.assertEqual(faults(m), ["with the search cleared ['Nutrients'] stay open: what the search opened is shut again"])

    def test_a_search_on_the_url_lands_open(self):
        landed = mm(q="nitrate", listCats=[cat("Nutrients", 6, says="true", shown=6)], pvRow="in view", press=None, search={}, cleared=None)
        self.assertEqual(faults(landed), [])
        shut = copy.deepcopy(landed)
        shut["listCats"] = [cat("Nutrients", 6)]                            # ?q= read, the category left closed
        shut["pvRow"] = None
        f = faults(shut)
        self.assertIn("?q=nitrate: category 'Nutrients' says aria-expanded=false with 0 of 6 match(es) in view", f[0])
        self.assertIn("?q=nitrate: the preview is not on a row in view", f[1])
        self.assertEqual(len(faults(shut, 375)), 1)


# ── /species/, a search: the taxa that are not species rows ────────────────────
GENUS = {"name": "Sardinops", "sub": "Genus · Bony fishes", "holds": "1 species", "href": "/species/worms-203974/"}


def finder(**over):
    fi = {"rows": ["Pacific sardine (pilchard) Sardinops sagax"], "recRows": 1000, "recTaxa": 1430, "rowsInHigher": 0,
          "higher": [dict(GENUS)], "higherHead": "Groups and other taxa 1", "higherAfterList": True, "higherStatus": 200}
    fi.update(over)
    return fi


class HigherTaxa(unittest.TestCase):
    def test_a_sound_search_passes(self):
        self.assertEqual(cl.higher_faults(finder(), True, 2430), [])
        self.assertEqual(cl.higher_faults(finder(higher=[], higherHead="", higherStatus=None), True, 2430), [])   # a search that finds species only

    def test_no_search_no_block(self):
        self.assertEqual(cl.higher_faults(finder(higher=[], higherHead="", higherStatus=None), False, 2430), [])
        self.assertEqual(cl.higher_faults(finder(), False, 2430), ["1 other taxa are listed with no search (the block is drawn only on a search)"])

    # THE regression: the finder's search found species only, so "sardin" lost the genus
    def test_the_record_of_the_other_taxa_must_be_there(self):
        for gone in (None, 0):
            self.assertIn("/species/finder-taxa.json is missing or empty", cl.higher_faults(finder(recTaxa=gone, higher=[], higherHead=""), True, 2430)[0])

    def test_rows_and_other_taxa_cannot_outnumber_the_pages(self):
        self.assertIn("1000 species rows and 1431 other taxa for 2430 taxon pages", cl.higher_faults(finder(recTaxa=1431), True, 2430)[0])
        self.assertEqual(cl.higher_faults(finder(recTaxa=1400), True, 2430), [])   # a hidden dataset's taxa: fewer is sound
        self.assertEqual(cl.higher_faults(finder(recTaxa=9999), True, None), [])   # no page count read: not judged

    def test_the_species_list_stays_species(self):
        self.assertIn("1 species row(s) inside the other-taxa block", cl.higher_faults(finder(rowsInHigher=1), True, 2430)[0])

    def test_the_block_is_headed_and_under_the_species(self):
        self.assertEqual(cl.higher_faults(finder(higherHead=""), True, 2430), ["the other taxa are listed with no heading that says they are not species"])
        self.assertEqual(cl.higher_faults(finder(higherAfterList=False), True, 2430), ["the other taxa are listed before the species rows, expected under them"])

    def test_each_links_a_species_page_that_answers(self):
        f = cl.higher_faults(finder(higher=[dict(GENUS, href="/datasets/x/")]), True, 2430)
        self.assertEqual(f, ["1 other-taxa row(s) do not link a species page: ['/datasets/x/']"])
        self.assertEqual(cl.higher_faults(finder(higher=[dict(GENUS, href="/preview/species/worms-1/")]), True, 2430), [])   # a build under a baseurl
        self.assertEqual(cl.higher_faults(finder(higherStatus=404), True, 2430), ["the first other-taxa link (/species/worms-203974/) answers HTTP 404"])
        self.assertIn("answers HTTP None", cl.higher_faults(finder(higherStatus=None), True, 2430)[0])

    def test_each_says_its_rank_and_what_it_holds(self):
        self.assertEqual(cl.higher_faults(finder(higher=[dict(GENUS, sub="")]), True, 2430), ["1 other-taxa row(s) say no rank or not what they hold: ['Sardinops']"])
        self.assertEqual(len(cl.higher_faults(finder(higher=[dict(GENUS, holds="")]), True, 2430)), 1)


# ── /species/, the hierarchy tab ──────────────────────────────────────────────
def species(view="groups", **over):
    """the species index as the probe read it: the hierarchy drawn only if it is the view, and drawn
    when its tab is pressed"""
    shown = view == "hierarchy"
    sp = {"view": view,
          "ice": {"rects": 61 if shown else 0, "labels": 40 if shown else 0, "w": 1138 if shown else 0, "crumb": 1 if shown else 0,
                  "seg": 2, "inPanel": "hierarchy"},
          "icePressed": {"view": "hierarchy", "rects": 61, "w": 1138, "crumb": 1, "panels": 1, "zoomCrumb": 2, "backCrumb": 1, "backRects": 61}}
    sp.update(over)
    return sp


class Hierarchy(unittest.TestCase):
    def test_sound_behind_another_view_and_as_the_view(self):
        self.assertEqual(cl.hierarchy_faults(species()), [])
        self.assertEqual(cl.hierarchy_faults(species("hierarchy")), [])

    # THE regression (review S-26, S-29): the tab was dropped and the icicle drawn into a hidden block
    def test_no_icicle_in_the_tabs_panel(self):
        self.assertEqual(cl.hierarchy_faults(species(ice=None)), ["the hierarchy tab's panel holds no icicle (#sp-ice)"])
        legacy = species()
        legacy["ice"]["inPanel"] = None                                     # #sp-ice outside the tabset
        self.assertEqual(cl.hierarchy_faults(legacy), ["the hierarchy tab's panel holds no icicle (#sp-ice)"])

    def test_landing_on_the_view_draws_it(self):
        blank = species("hierarchy")
        blank["ice"].update(rects=0, crumb=0)
        self.assertEqual(cl.hierarchy_faults(blank), ["the hierarchy view is showing but drew 0 band(s) and 0 breadcrumb(s)"])

    def test_drawn_only_when_shown(self):
        eager = species("groups")
        eager["ice"]["rects"] = 61
        self.assertEqual(cl.hierarchy_faults(eager), ["the hierarchy drew 61 band(s) while the 'groups' view is showing"])

    def test_pressing_the_tab_selects_and_draws_it(self):
        self.assertEqual(cl.hierarchy_faults(species(icePressed=None)), ["the hierarchy tab was not pressed (no tab, or no #sp-ice)"])
        sp = species()
        sp["icePressed"].update(view="groups")
        self.assertEqual(cl.hierarchy_faults(sp), ["pressing The hierarchy selects 'groups' with 1 panel(s) showing"])
        sp = species()
        sp["icePressed"].update(panels=2)
        self.assertIn("with 2 panel(s) showing", cl.hierarchy_faults(sp)[0])
        sp = species()
        sp["icePressed"].update(rects=0, crumb=0)
        self.assertEqual(cl.hierarchy_faults(sp), ["pressing The hierarchy drew 0 band(s) in 1138px with 0 breadcrumb(s)"])
        sp = species()
        sp["icePressed"].update(w=0)                                        # drawn into a panel that has no width
        self.assertIn("in 0px", cl.hierarchy_faults(sp)[0])

    def test_a_band_zooms_and_the_breadcrumb_climbs_back(self):
        sp = species()
        sp["icePressed"]["zoomCrumb"] = 1
        self.assertEqual(cl.hierarchy_faults(sp), ["a press on a band does not zoom into it (breadcrumb 1 → 1)"])
        sp = species()
        sp["icePressed"]["backCrumb"] = 2
        self.assertEqual(cl.hierarchy_faults(sp), ["the breadcrumb does not climb back out (2 crumb(s), 61 band(s))"])

    def test_sized_two_ways(self):
        sp = species()
        sp["ice"]["seg"] = 0
        self.assertEqual(cl.hierarchy_faults(sp), ["the hierarchy offers 0 ways to size it, expected 2 (observations, species)"])


class Views(unittest.TestCase):
    def test_the_five_tabs(self):
        self.assertEqual(cl.SPECIES_VIEWS, ["groups", "list", "tree", "matrix", "hierarchy"])

    def test_mains_first_view_lands_on_groups(self):
        self.assertEqual(cl.SPECIES_OLD_VIEWS, {"classes": "groups"})
        self.assertIn(cl.SPECIES_OLD_VIEWS["classes"], cl.SPECIES_VIEWS)

    def test_the_paths_that_exercise_them(self):
        for p in ("/species/?tab=hierarchy", "/species/?tab=classes", "/species/?q=sardin", "/measurements/", "/measurements/?q=nitrate", "/datasets/"):
            self.assertIn(p, cl.DEFAULT_PATHS)


# ── the height ceilings ───────────────────────────────────────────────────────
class Ceilings(unittest.TestCase):
    # the arithmetic the constant's comment states (measured 2026-11-17 on v2026.11.14 at 1470 px)
    FIXED, ROWS_PX, ROWS = 1096, 1479, 20

    def test_the_catalog_ceiling_holds_the_measured_page_and_two_more_datasets(self):
        row = round(self.ROWS_PX / self.ROWS)
        self.assertEqual(row, 74)
        self.assertEqual(self.FIXED + self.ROWS_PX, 2575)
        self.assertGreaterEqual(cl.MAX_DS_H["catalog"], 2575)
        self.assertGreaterEqual(cl.MAX_DS_H["catalog"], self.FIXED + 22 * row)
        self.assertLess(cl.MAX_DS_H["catalog"], self.FIXED + 23 * row, "a 23rd dataset is noticed")
        self.assertLess(cl.MAX_DS_H["catalog"] + 200, self.FIXED + 25 * row, "25 datasets are over by more than 200 px")

    def test_it_is_not_room_for_taller_rows(self):
        self.assertLess((cl.MAX_DS_H["catalog"] - self.FIXED) / self.ROWS, 82)

    # the ONE threshold restated on 2026-11-17: the others are the numbers they were
    def test_no_other_ceiling_moved(self):
        self.assertEqual(cl.MAX_DS_H["dataset"], 2650)   # restated 2026-11-23 with its reason beside the number (PR 57 review D2); was 2200
        self.assertEqual(cl.MAX_MM_INDEX_H, 1625)
        self.assertEqual(cl.MAX_SPECIES_INDEX_H, 2220)
        self.assertEqual(cl.MAX_SPECIES_PAGE_H, 1500)
        self.assertEqual(cl.MAX_MM_PAGE_H, 1850)


if __name__ == "__main__":
    unittest.main()
