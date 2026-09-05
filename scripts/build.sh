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
fi

scripts/fetch_release.sh

if [ "${1:-build}" = "serve" ]; then
  shift || true
  exec bundle exec jekyll serve "$@"
fi
exec bundle exec jekyll build "$@"
