#!/usr/bin/env python3
"""_test/check_layout_downloads_test.py — scripts/check_layout.py's `download_offers`, the expectation
the Download-button assertions are judged against. It must follow _plugins/downloads.rb's rule
exactly (pinned in _test/downloads_test.rb), or the layout check and the page would disagree:

    python3 _test/check_layout_downloads_test.py

  manifest   a written csv is the button's target; xlsx not written is not a format
  record     the record's own `bundle` rows win over the manifest
  holding    a holding (in holdings[], not datasets[]) never has an offer
  absent     no manifest, or a schema 2.x one: no offers at all (no button anywhere)
"""
import importlib.util, json, os, shutil, tempfile, unittest

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("check_layout", os.path.join(HERE, "..", "scripts", "check_layout.py"))
cl = importlib.util.module_from_spec(spec)
spec.loader.exec_module(cl)
MANIFEST = json.load(open(os.path.join(HERE, "fixtures", "zip_manifest.json")))


class DownloadOffers(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.mkdtemp()

    def tearDown(self):
        shutil.rmtree(self.dir)

    def write(self, name, obj):
        with open(os.path.join(self.dir, name), "w") as f:
            json.dump(obj, f)

    def record(self, *keys, holdings=(), dist=None):
        self.write("datasets.json", {"datasets": [{"dataset_key": k, "distributions": (dist or {}).get(k, [])} for k in keys],
                                     "holdings": [{"dataset_key": h} for h in holdings]})

    def test_manifest(self):
        self.record("x_all", "x_big", "x_none")
        self.write("zip_manifest.json", MANIFEST)
        o = cl.download_offers(self.dir)
        self.assertEqual(sorted(o), ["x_all", "x_big"])
        self.assertEqual(o["x_all"]["formats"], ["csv", "xlsx", "parquet"])
        self.assertEqual(o["x_big"]["formats"], ["csv", "parquet"])
        self.assertTrue(o["x_big"]["primary"].endswith("x_big_v9.9.9_csv.zip"))
        self.assertEqual(o["x_big"]["primary_format"], "csv")

    def test_record_bundles_win(self):
        self.record("x_all", dist={"x_all": [{"kind": "bundle", "format": "csv", "url": "https://e/r.zip"},
                                              {"kind": "bundle", "format": "dwca", "url": "https://e/d.zip"}]})
        self.write("zip_manifest.json", MANIFEST)
        self.assertEqual(cl.download_offers(self.dir)["x_all"], {"formats": ["csv"], "urls": {"csv": "https://e/r.zip"},
                                                                  "primary": "https://e/r.zip", "primary_format": "csv"})

    def test_holding_never(self):
        self.record(holdings=("x_all",))
        self.write("zip_manifest.json", MANIFEST)
        self.assertEqual(cl.download_offers(self.dir), {})

    def test_absent_or_foreign(self):
        self.record("x_all")
        self.assertEqual(cl.download_offers(self.dir), {})
        self.write("zip_manifest.json", dict(MANIFEST, schema_version="2.0"))
        self.assertEqual(cl.download_offers(self.dir), {})


if __name__ == "__main__":
    unittest.main()
