#!/usr/bin/env python3
"""_test/check_layout_exemplars_test.py — scripts/check_layout.py's record-dependent exemplars.

    python3 _test/check_layout_exemplars_test.py

The organism face was checked on /measurements/synechococcus/, a picoplankton key. From v2026.10.01
the release's measurements record carries no picoplankton key, the page is not built, and the probe
measured a 404 page as "no phone menu button" (PR #27, 2026-10-05). Each rule below pins one branch.
"""
import importlib.util, os, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("check_layout", os.path.join(HERE, "..", "scripts", "check_layout.py"))
cl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cl)

SYN = "/measurements/synechococcus/"
PATHS = ["/", "/measurements/nitrate/", SYN, "/measurements/ammonia/"]


def record(*keys, faces=None):
    faces = faces or {}
    return {"measurements": [dict(key=k, **({"face": {"kind": faces[k]}} if k in faces else {})) for k in keys]}


class ResolveFaceExemplars(unittest.TestCase):
    def test_kept_when_the_record_carries_it(self):
        notes = []
        out = cl.resolve_face_exemplars(PATHS, record("nitrate", "synechococcus", "ammonia"), None, notes)
        self.assertEqual(out, PATHS)
        self.assertEqual(notes, [])

    def test_swapped_for_another_organism_key_from_the_record(self):
        notes = []
        rec = record("nitrate", "prochlorococcus", "ammonia", faces={"prochlorococcus": "organism"})
        out = cl.resolve_face_exemplars(PATHS, rec, None, notes)
        self.assertEqual(out, ["/", "/measurements/nitrate/", "/measurements/prochlorococcus/", "/measurements/ammonia/"])
        self.assertEqual(len(notes), 1)

    def test_swapped_by_the_media_sidecars_face_kind(self):
        media = {"measurements": {"het_bacteria": {"face": {"kind": "organism"}},
                                  "nitrate": {"face": {"kind": "structure"}}}}
        out = cl.resolve_face_exemplars(PATHS, record("nitrate", "het_bacteria", "ammonia"), media)
        self.assertEqual(out[2], "/measurements/het_bacteria/")

    def test_dropped_with_a_note_when_no_organism_key_exists(self):
        # v2026.10.01 / v2026.10.05: no picoplankton, no organism face in the measurements record
        notes = []
        rec = record("nitrate", "ammonia", faces={"nitrate": "structure", "ammonia": "structure"})
        out = cl.resolve_face_exemplars(PATHS, rec, None, notes)
        self.assertEqual(out, ["/", "/measurements/nitrate/", "/measurements/ammonia/"])
        self.assertEqual(len(notes), 1)
        self.assertIn("not exercised", notes[0])

    def test_non_exemplar_paths_are_never_touched(self):
        # a missing non-exemplar page stays in the list, so it fails as HTTP 404, never silently
        out = cl.resolve_face_exemplars(["/measurements/gone/"], record("nitrate"), None)
        self.assertEqual(out, ["/measurements/gone/"])

    def test_no_record_keeps_the_defaults(self):
        self.assertEqual(cl.resolve_face_exemplars(PATHS, None, None), PATHS)

    def test_the_committed_fixture_still_carries_synechococcus(self):
        rec = cl._read_json(os.path.join(HERE, "fixtures", "measurements_11.json"))
        self.assertEqual(cl.resolve_face_exemplars(PATHS, rec, None), PATHS)


if __name__ == "__main__":
    unittest.main()
