#!/usr/bin/env python3
"""fetch_dataset_measurements.py -- every per-cast measurement_type each dataset ships, MEASURED from the release.

The dataset record (datasets.json) and the release's coverage.json list a dataset's variables from the
`obs` grain only: one value per depth bin or per taxon (obs_env / obs_bio). A measurement taken once per
cast -- a mixed-layer depth, a chlorophyll maximum, wind speed, a volume filtered -- lives in
`sample_measurement`, and no sidecar the site reads carried it, so a dataset page listed 2 of the 9
measurements calcofi_ctd-derived ships (CalCOFI.github.io#26).  This script reads the release's own
`sample_measurement` parquet through the release catalog and writes the counts the page needs.

    _data/dataset_measurements.json
        { schema_version, release, source{...}, datasets{ <dataset_key>: { per_cast: {table, n_values,
          n_samples, types[{measurement_type, units, description, n_values, n_samples, year_min,
          year_max, date_min, date_max (YYYY-MM)}]} } } }

Never a hand-built `releases/{v}/parquet/` path: the object paths come from the release's catalog.json
(`_data/release_catalog.json`, fetched by fetch_release.sh), which is the one place a table's current
content-addressed object is named (workflows' release-objects skill).

Optional, like every sidecar: a missing catalog, a missing `duckdb` module or an unreachable object leaves
the file absent, and the dataset pages then list the profile variables the record already carries -- a
number the build cannot read is never typed (plan 2026-09-07 D-2).  Needs `pip install duckdb`
(.github/workflows install it; locally use the git-ignored .venv-media, never a system Python).

    python3 scripts/fetch_dataset_measurements.py [--data _data] [--base https://storage.googleapis.com/calcofi-db]
"""
import argparse
import json
import os
import sys

# the tables whose per-dataset rows are per-cast values.  One entry per table: a new per-cast table is
# one line here, and the page names the table beside its group.
PER_CAST_TABLES = ("sample_measurement",)


def object_urls(catalog, table, base):
    """The catalog's current objects for one table, as URLs under `base` (never hand-built paths)."""
    for t in catalog.get("tables", []):
        if t.get("name") == table:
            return [f"{base.rstrip('/')}/{o['path']}" for o in t.get("objects", []) if o.get("path")]
    return []


def sql_list(urls):
    return "[" + ", ".join("'" + u.replace("'", "''") + "'" for u in urls) + "]"


def main():
    ap = argparse.ArgumentParser()
    root = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), ".."))
    ap.add_argument("--data", default=os.path.join(root, "_data"))
    ap.add_argument("--base", default=os.environ.get("CALCOFI_OBJECT_BASE",
                                                      "https://storage.googleapis.com/calcofi-db"))
    a = ap.parse_args()
    out = os.path.join(a.data, "dataset_measurements.json")
    if os.path.exists(out):
        os.remove(out)

    cat_path = os.path.join(a.data, "release_catalog.json")
    if not os.path.exists(cat_path):
        print("NOTE: no release_catalog.json -- the dataset pages list the profile variables only")
        return 0
    try:
        import duckdb
    except ImportError:
        print("NOTE: python module `duckdb` is not installed -- the dataset pages list the profile "
              "variables only (pip install duckdb, in a venv locally)")
        return 0

    catalog = json.load(open(cat_path))
    sample_urls = object_urls(catalog, "sample", a.base)
    mtype_urls = object_urls(catalog, "measurement_type", a.base)
    datasets = {}
    source = {}
    try:
        con = duckdb.connect()
        con.execute("INSTALL httpfs; LOAD httpfs;")
        for table in PER_CAST_TABLES:
            urls = object_urls(catalog, table, a.base)
            if not urls or not sample_urls:
                continue
            source[table] = urls
            # years come from the sample each value belongs to; units and words from the release's own
            # measurement_type registry (never typed here)
            if mtype_urls:
                mt_sql = (f"SELECT measurement_type, units, description FROM read_parquet({sql_list(mtype_urls)}) "
                          "QUALIFY row_number() OVER (PARTITION BY measurement_type "
                          "ORDER BY is_canonical DESC NULLS LAST) = 1")
            else:
                mt_sql = ("SELECT NULL::VARCHAR AS measurement_type, NULL::VARCHAR AS units, "
                          "NULL::VARCHAR AS description WHERE false")
            q = f"""
              WITH sm AS (SELECT sample_key, dataset_key, measurement_type
                          FROM read_parquet({sql_list(urls)})),
                   sa AS (SELECT sample_key, year(datetime) AS yr, datetime AS dt
                          FROM read_parquet({sql_list(sample_urls)})),
                   mt AS ({mt_sql})
              SELECT sm.dataset_key, sm.measurement_type, any_value(mt.units) AS units,
                     any_value(mt.description) AS description,
                     count(*) AS n_values, count(DISTINCT sm.sample_key) AS n_samples,
                     min(sa.yr) AS year_min, max(sa.yr) AS year_max,
                     strftime(min(sa.dt), '%Y-%m') AS date_min, strftime(max(sa.dt), '%Y-%m') AS date_max
              FROM sm LEFT JOIN sa USING (sample_key) LEFT JOIN mt USING (measurement_type)
              GROUP BY 1, 2 ORDER BY 1, n_values DESC, 2"""
            for (dk, mt, units, desc, n, ns, y0, y1, d0, d1) in con.execute(q).fetchall():
                g = datasets.setdefault(dk, {}).setdefault(
                    "per_cast", {"table": table, "n_values": 0, "n_samples": None, "types": []})
                g["types"].append({"measurement_type": mt, "units": units or None,
                                   "description": desc or None, "n_values": n, "n_samples": ns,
                                   "year_min": y0, "year_max": y1, "date_min": d0, "date_max": d1})
                g["n_values"] += n
            # distinct samples per dataset (a cast carries several types)
            q2 = f"""SELECT dataset_key, count(DISTINCT sample_key) FROM read_parquet({sql_list(urls)}) GROUP BY 1"""
            for dk, ns in con.execute(q2).fetchall():
                datasets[dk]["per_cast"]["n_samples"] = ns
    except Exception as e:  # unreachable is not a fact: no sidecar, no per-cast group
        print(f"NOTE: could not measure the per-cast tables ({type(e).__name__}: {e}) -- "
              "the dataset pages list the profile variables only")
        return 0

    if not datasets:
        print("NOTE: no per-cast rows found in the release catalog's tables")
        return 0
    rel = catalog.get("version")
    json.dump({"schema_version": "1.0", "release": rel,
               "source": {"catalog": "release catalog.json", "objects": source},
               "datasets": datasets}, open(out, "w"), indent=1, ensure_ascii=False)
    n_types = sum(len(d["per_cast"]["types"]) for d in datasets.values())
    print(f"dataset measurements: release {rel} · {len(datasets)} datasets carry per-cast values · "
          f"{n_types} dataset x measurement_type series in {', '.join(PER_CAST_TABLES)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
