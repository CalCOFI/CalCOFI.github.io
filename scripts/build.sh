#!/usr/bin/env bash
# build.sh — the one command a fresh clone runs: gems, the release record, the site.
#
#   scripts/build.sh            # build _site
#   scripts/build.sh serve      # build and serve on http://localhost:4000
#
# `scripts/fetch_release.sh` pulls the record into _data/ (git-ignored); the Jekyll generator
# `_plugins/datasets.rb` turns it into /datasets/, /data.json and the sitemap.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

bundle install --quiet

# the identifier parser is a rule about what a portal calls a dataset, so it is unit-tested rather
# than eyeballed on a page — and calcofi4db 4.5.0 derives the same ids (plan D-9), so the two have
# one list to agree on. Skip with CC_SKIP_TESTS=1.
if [ -z "${CC_SKIP_TESTS:-}" ]; then
  ruby _test/derive_id_test.rb >/dev/null || { echo "FAIL: _test/derive_id_test.rb" >&2; exit 1; }
  # the rules behind a dataset page's variable list: per-cast groups, the shared per-cast table, the
  # successor note (CalCOFI.github.io#26)
  ruby _test/dataset_measurements_test.rb >/dev/null || { echo "FAIL: _test/dataset_measurements_test.rb" >&2; exit 1; }
  # what a measurement page does with grain "sample" (one value per cast: no depth figure, no anomaly)
  ruby _test/measurements_grain_test.rb >/dev/null || { echo "FAIL: _test/measurements_grain_test.rb" >&2; exit 1; }
  # the short label a measurement's title wears (issue #30 D13): cut at the first comma outside parentheses
  ruby _test/measurements_short_label_test.rb >/dev/null || { echo "FAIL: _test/measurements_short_label_test.rb" >&2; exit 1; }
  # a licence the provider has not stated yet reads as pending in the citation and is absent from JSON-LD
  ruby _test/licence_pending_test.rb >/dev/null || { echo "FAIL: _test/licence_pending_test.rb" >&2; exit 1; }
  # a dataset's original page is one "Original at …" way, after the apps, before ERDDAP
  ruby _test/source_way_test.rb >/dev/null || { echo "FAIL: _test/source_way_test.rb" >&2; exit 1; }
  # the release citation ends in the release's DOI wherever one of the release's own files carries it
  ruby _test/release_doi_test.rb >/dev/null || { echo "FAIL: _test/release_doi_test.rb" >&2; exit 1; }
  # what the Download button and its dialog offer: CSV first, Excel's reason, the licence said truthfully
  ruby _test/downloads_test.rb >/dev/null || { echo "FAIL: _test/downloads_test.rb" >&2; exit 1; }
  # the redesigned dataset page's pure rules: the download form's whole dataset is the release zip
  ruby _test/dataset_page_test.rb >/dev/null || { echo "FAIL: _test/dataset_page_test.rb" >&2; exit 1; }
  # the header's words (brand v3): one list, resolved once, for this site's header and /brand/v3/nav.json
  ruby _test/nav_test.rb >/dev/null || { echo "FAIL: _test/nav_test.rb" >&2; exit 1; }
  # Browse datasets' rules: the order, what is in a dataset and how many, asserted years, no typed axis
  ruby _test/browse_test.rb >/dev/null || { echo "FAIL: _test/browse_test.rb" >&2; exit 1; }
  # the Species and Measurements finders: which rows, the groups (every species in one), the hidden datasets,
  # the taxa a search finds that are not species rows, what a closed measurement category says is inside
  ruby _test/finder_test.rb >/dev/null || { echo "FAIL: _test/finder_test.rb" >&2; exit 1; }
  # the dataset display words come from the record; a typed _data/dataset_extras.yml fails here
  ruby _test/dataset_extras_test.rb >/dev/null || { echo "FAIL: _test/dataset_extras_test.rb" >&2; exit 1; }
fi

scripts/fetch_release.sh

if [ "${1:-build}" = "serve" ]; then
  shift || true
  exec bundle exec jekyll serve "$@"
fi
exec bundle exec jekyll build "$@"
