#!/usr/bin/env python3
"""_test/media_due_test.py — scripts/media_due.py, the rule that decides whether a release's deploy
fetches the species and measurement faces (workflows/scripts/deploy_consumers.sh, step 7).

    python3 _test/media_due_test.py

The step was printed and never run until 2026-10-06, so a release that added a taxon or a
measurement key left it with no face and nothing said so. Each case pins one branch of "due".
"""
import importlib.util, io, json, os, tempfile, unittest
from contextlib import redirect_stdout, redirect_stderr

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("media_due", os.path.join(HERE, "..", "scripts", "media_due.py"))
md = importlib.util.module_from_spec(spec)
spec.loader.exec_module(md)


def taxa_rec(*keys):
    return {"release": "v2099.01.01", "taxa": [{"taxon_key": k, "slug": k.replace(":", "-")} for k in keys]}


def meas_rec(*keys):
    return {"release": "v2099.01.01", "measurements": [{"key": k} for k in keys]}


def taxa_media(*keys, release="v2099.01.01"):
    return {"release": release, "taxa": {k: {"silhouette": {}} for k in keys}}


def meas_media(*keys, release="v2099.01.01"):
    return {"release": release, "measurements": {k: {} for k in keys},
            "skipped": [{"key": "dic", "why": "the carbon atom"}]}


class Rules(unittest.TestCase):
    def test_missing_is_record_minus_sidecar_sorted(self):
        self.assertEqual(md.due({"b", "a", "c"}, {"c"}), ["a", "b"])

    def test_a_key_only_the_sidecar_has_is_not_due(self):
        # the sidecars are one copy for every release: a key a release dropped keeps its entry
        self.assertEqual(md.due({"a"}, {"a", "gone"}), [])

    def test_absent_sidecar_means_every_key_is_due(self):
        self.assertEqual(md.sidecar_keys(None, "taxa"), set())
        self.assertEqual(md.due({"a", "b"}, md.sidecar_keys(None, "taxa")), ["a", "b"])

    def test_skipped_measurement_key_still_has_an_entry(self):
        # dic is in `skipped` (no structure) AND in `measurements`, so it is covered
        doc = meas_media("dic", "temperature")
        self.assertEqual(md.due(md.record_measurement_keys(meas_rec("dic", "temperature")),
                                md.sidecar_keys(doc, "measurements")), [])

    def test_record_key_extractors(self):
        self.assertEqual(md.record_taxon_keys(taxa_rec("worms:1", "itis:2")), {"worms:1", "itis:2"})
        self.assertEqual(md.record_measurement_keys(meas_rec("nitrate")), {"nitrate"})


class Main(unittest.TestCase):
    def run_main(self, taxa, meas, tm, mm):
        d = tempfile.mkdtemp()
        paths = {}
        for name, doc in (("taxa", taxa), ("meas", meas), ("tm", tm), ("mm", mm)):
            p = os.path.join(d, f"{name}.json")
            if doc is not None:
                with open(p, "w") as f:
                    json.dump(doc, f)
            paths[name] = p
        out, err = io.StringIO(), io.StringIO()
        with redirect_stdout(out), redirect_stderr(err):
            rc = md.main(["--taxa", paths["taxa"], "--measurements", paths["meas"],
                          "--taxa-media", paths["tm"], "--measurements-media", paths["mm"], "--json"])
        return rc, (json.loads(out.getvalue()) if out.getvalue() else None)

    def test_nothing_due_exits_0(self):
        rc, o = self.run_main(taxa_rec("a", "b"), meas_rec("x"), taxa_media("a", "b"), meas_media("x"))
        self.assertEqual(rc, md.EXIT_NONE)
        self.assertEqual(o["species"]["missing"], [])
        self.assertEqual(o["measurements"]["missing"], [])

    def test_new_taxon_exits_3_and_names_it(self):
        rc, o = self.run_main(taxa_rec("a", "new"), meas_rec("x"), taxa_media("a"), meas_media("x"))
        self.assertEqual(rc, md.EXIT_DUE)
        self.assertEqual(o["species"]["missing"], ["new"])
        self.assertEqual(o["measurements"]["missing"], [])

    def test_new_measurement_key_exits_3(self):
        rc, o = self.run_main(taxa_rec("a"), meas_rec("x", "pco2"), taxa_media("a"), meas_media("x"))
        self.assertEqual(rc, md.EXIT_DUE)
        self.assertEqual(o["measurements"]["missing"], ["pco2"])

    def test_a_newer_release_alone_is_not_due(self):
        # the sidecar was built for an older release but already covers every key
        rc, _ = self.run_main(taxa_rec("a"), meas_rec("x"), taxa_media("a", release="v2000.01.01"),
                              meas_media("x", release="v2000.01.01"))
        self.assertEqual(rc, md.EXIT_NONE)

    def test_missing_sidecar_exits_3(self):
        rc, o = self.run_main(taxa_rec("a"), meas_rec("x"), None, meas_media("x"))
        self.assertEqual(rc, md.EXIT_DUE)
        self.assertFalse(o["species"]["sidecar_present"])

    def test_missing_record_exits_2(self):
        rc, _ = self.run_main(None, meas_rec("x"), taxa_media("a"), meas_media("x"))
        self.assertEqual(rc, md.EXIT_UNKNOWN)


if __name__ == "__main__":
    unittest.main()
