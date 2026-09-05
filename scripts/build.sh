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
scripts/fetch_release.sh

if [ "${1:-build}" = "serve" ]; then
  shift || true
  exec bundle exec jekyll serve "$@"
fi
exec bundle exec jekyll build "$@"
