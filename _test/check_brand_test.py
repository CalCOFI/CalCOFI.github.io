#!/usr/bin/env python3
"""_test/check_brand_test.py — the pure rules scripts/check_brand.py holds a brand v3 product to
(brand/v3/README.md § 4, 2026-11-17). The browser only measures; judge_v3 decides, so it is pinned here
on small synthetic measurements, one per rule:

    python3 _test/check_brand_test.py

  list   nav_json_url: the brand's words are the nav.json BESIDE the header.js the page loads (a preview
         is held to its own copy, the live site to calcofi.io's); nav_titles reads them in order
  nav    the bar's words equal that list, in order — v2's uppercase DATA · APPS · … is not it
  case   sentence case: text-transform none on every word of the bar and on .cc-title
  wave   exactly one .cc-wave band is drawn and it starts where the bar ends
  menu   one pixel under NAV_BREAK the menu button is shown and the nav is not
"""
import importlib.util, os, sys, unittest

sys.dont_write_bytecode = True    # the script is loaded by path: leave no scripts/__pycache__ behind

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("check_brand", os.path.join(HERE, "..", "scripts", "check_brand.py"))
cb = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cb)          # a bare python3: the script must not need PyYAML to be imported

# a list of nine words to judge a page against: what a product's nav.json may carry (the brand's list
# on the afternoon of 2026-11-17). judge_v3 holds a page to whatever list its nav.json gives, so the
# fixture does not follow the repo's list; REPO_WORDS below is the list this repo's _data/nav.yml states now.
WORDS = ["Data", "Map", "Query", "Cite", "Learn", "Docs", "FAQ", "News", "calcofi.org ↗"]
# the repo's own list since the evening of 2026-11-17 (9f2b542): four words; Query, Cite, Docs, FAQ and
# News are lines of the Data and Learn menus
REPO_WORDS = ["Data", "Map", "Learn", "calcofi.org ↗"]


def page(**over):
    """a v3 page on which all four pass"""
    v3 = {"header": True, "headerJs": "https://calcofi.io/brand/v3/header.js", "headerVersion": "3", "navState": None,
          "navClass": "cc-links cc-nav", "words": list(WORDS), "cased": ["none"] * 10, "headerBottom": 72,
          "waves": [{"cls": "cc-wave cc-wave-slim", "top": 72, "h": 34}]}
    v3.update(over)
    return v3


NARROW = {"width": 1099, "header": True, "button": True, "nav": False}


class NavList(unittest.TestCase):
    def test_nav_json_is_beside_the_header_js_the_page_loads(self):
        self.assertEqual(cb.nav_json_url("https://calcofi.io/brand/v3/header.js"), "https://calcofi.io/brand/v3/nav.json")
        self.assertEqual(cb.nav_json_url("http://100.119.247.126:4046/brand/v3/header.js?v=3"), "http://100.119.247.126:4046/brand/v3/nav.json")
        self.assertEqual(cb.nav_json_url("http://localhost:4000/brand/v3/header.js#x"), "http://localhost:4000/brand/v3/nav.json")
        self.assertIsNone(cb.nav_json_url(None))
        self.assertIsNone(cb.nav_json_url(""))

    def test_titles_in_order(self):
        self.assertEqual(cb.nav_titles({"version": "3", "words": [{"id": "data", "title": "Data", "menu": []}, {"id": "faq", "title": "FAQ"}]}), ["Data", "FAQ"])
        self.assertEqual(cb.nav_titles(None), [])

    def test_nav_yml_titles(self):
        text = "# c\nwords:\n  - id: data\n    title: Data\n    menu:\n      - { title: Datasets, href: /datasets/ }\n  - { id: cite, title: Cite, href: x }\n  - { id: org, title: \"calcofi.org ↗\", ext: true }\n"
        self.assertEqual(cb.nav_yml_titles(text), ["Data", "Cite", "calcofi.org ↗"])
        self.assertEqual(cb.nav_yml_titles(""), [])
        self.assertEqual(cb.nav_yml_titles(None), [])

    # the repo's own list is the four words, and the layout check's reader of the same file agrees
    def test_the_repos_list(self):
        with open(os.path.join(HERE, "..", "_data", "nav.yml"), encoding="utf-8") as f:
            text = f.read()
        self.assertEqual(cb.nav_yml_titles(text), REPO_WORDS)
        s2 = importlib.util.spec_from_file_location("check_layout", os.path.join(HERE, "..", "scripts", "check_layout.py"))
        cl = importlib.util.module_from_spec(s2)
        s2.loader.exec_module(cl)
        self.assertEqual([x["title"] for x in cl.nav_words(text)], cb.nav_yml_titles(text))
        self.assertEqual(cl.NAV_BREAK, cb.NAV_BREAK)

    def test_the_breakpoint_is_the_headers(self):
        self.assertEqual(cb.NAV_BREAK, 1100)      # = brand/v3/header.css @media (max-width: 1099px) and header.js NAV_BREAK


class JudgeV3(unittest.TestCase):
    def test_a_sound_page_passes_all_four(self):
        got, why = cb.judge_v3(page(), NARROW, WORDS)
        self.assertEqual(got, {"nav": True, "case": True, "wave": True, "menu": True})
        self.assertEqual(why, [])

    # the header this replaced (brand v2 § 4): uppercase, each product's own words, no wave
    def test_the_v2_header_fails_nav_case_and_wave(self):
        old = page(words=["Data", "Apps", "Access", "Build", "Docs", "FAQ", "News", "calcofi.org ↗"], cased=["uppercase"] * 8, waves=[], headerJs=None)
        got, why = cb.judge_v3(old, {"width": 1099, "header": True, "button": True, "nav": False}, WORDS)
        self.assertEqual(got, {"nav": False, "case": False, "wave": False, "menu": True})
        self.assertEqual(len(why), 3)

    def test_nav_words_in_order(self):
        self.assertFalse(cb.judge_v3(page(words=WORDS[:5] + ["calcofi.org ↗"]), NARROW, WORDS)[0]["nav"])       # Docs, FAQ and News left the bar
        self.assertFalse(cb.judge_v3(page(words=["Map", "Data"] + WORDS[2:]), NARROW, WORDS)[0]["nav"])          # out of order
        self.assertFalse(cb.judge_v3(page(words=["Data", "Map", "Query Builder", "Cite the data"] + WORDS[4:]), NARROW, WORDS)[0]["nav"])
        self.assertFalse(cb.judge_v3(page(words=[]), NARROW, WORDS)[0]["nav"])                                  # a nav the script never filled
        got, why = cb.judge_v3(page(), NARROW, None)                                                            # no list to hold it to is a failure, not a pass
        self.assertFalse(got["nav"])
        self.assertIn("no nav.json", why[0])

    def test_sentence_case(self):
        got, why = cb.judge_v3(page(cased=["none"] * 9 + ["uppercase"]), NARROW, WORDS)                         # the .cc-title alone
        self.assertFalse(got["case"])
        self.assertIn("['none', 'uppercase']", why[0])
        self.assertFalse(cb.judge_v3(page(cased=["capitalize"] * 10), NARROW, WORDS)[0]["case"])
        self.assertFalse(cb.judge_v3(page(words=[], cased=[]), NARROW, WORDS)[0]["case"])

    def test_one_wave_where_the_bar_ends(self):
        self.assertFalse(cb.judge_v3(page(waves=[]), NARROW, WORDS)[0]["wave"])
        self.assertFalse(cb.judge_v3(page(waves=[{"cls": "cc-wave", "top": 120, "h": 34}]), NARROW, WORDS)[0]["wave"])      # a gap, or something between
        self.assertFalse(cb.judge_v3(page(waves=[{"cls": "cc-wave", "top": 72, "h": 34}, {"cls": "cc-wave cc-wave-own", "top": 106, "h": 120}]), NARROW, WORDS)[0]["wave"])
        self.assertTrue(cb.judge_v3(page(waves=[{"cls": "bd-head cc-wave cc-wave-own", "top": 73, "h": 134}]), NARROW, WORDS)[0]["wave"])   # a page's own band; 1 px of rounding
        self.assertFalse(cb.judge_v3(page(headerBottom=None), NARROW, WORDS)[0]["wave"])

    # brand v3 § 6: a bar a framework owns (Quarto, pkgdown, mkdocs, bslib) is held to the wave and the
    # case, not to the markup — so not to the words' list or the menu button
    def test_a_framework_owned_bar_is_held_to_the_wave_and_the_case_only(self):
        fw = page(header=False, framework=True, words=["Get started", "Reference", "Articles"], cased=["none"] * 4, headerJs=None,
                  waves=[{"cls": "cc-wave cc-wave-slim", "top": 56, "h": 34}], headerBottom=56)
        got, why = cb.judge_v3(fw, None, None)
        self.assertEqual(got, {"nav": None, "case": True, "wave": True, "menu": None})
        self.assertEqual(why, [])
        got, why = cb.judge_v3(dict(fw, cased=["uppercase"] * 4, waves=[]), None, None)
        self.assertEqual(got, {"nav": None, "case": False, "wave": False, "menu": None})
        self.assertEqual(len(why), 2)

    def test_the_menu_button_under_the_breakpoint(self):
        self.assertFalse(cb.judge_v3(page(), {"width": 1099, "button": False, "nav": True}, WORDS)[0]["menu"])   # v2 kept the words down to 480 px
        self.assertFalse(cb.judge_v3(page(), {"width": 1099, "button": True, "nav": True}, WORDS)[0]["menu"])
        self.assertFalse(cb.judge_v3(page(), {"width": 1099, "button": False, "nav": False}, WORDS)[0]["menu"])  # the words are nowhere
        self.assertFalse(cb.judge_v3(page(), {"error": "SecurityError"}, WORDS)[0]["menu"])
        self.assertFalse(cb.judge_v3(page(), None, WORDS)[0]["menu"])


if __name__ == "__main__":
    unittest.main()
