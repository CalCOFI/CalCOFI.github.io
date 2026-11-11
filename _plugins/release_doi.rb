# _plugins/release_doi.rb — the release's DOI and the citation that ends in it, read from whichever
# of the release's own files carries them.
#
# The record (`_data/datasets.json`) is written when the release is frozen. The release's DOI is
# minted after that and written back to the release's own `catalog.json` (with the citation that
# ends in it) and to `versions.json`, but not to the record: v2026.11.09's record says `doi: null`
# and cites `https://calcofi.io/db-schema/?v=v2026.11.09`, while its catalog.json and versions.json
# both carry 10.5281/zenodo.24083894. A dataset page and /datasets/release/ then printed a release
# citation without the DOI that calcofi4r::cc_cite() and calcofi.io/docs/cite.html print.
#
# The rule, in the order a file is trusted (all three are fetched by scripts/fetch_release.sh):
#
#   doi       the record's own · else catalog.json's, where it is the SAME version · else the
#             versions.json row of that version · else none, and the record is returned unchanged
#   citation  the record's, where it already carries the DOI · else catalog.json's own string,
#             where that carries it · else the record's with its trailing schema URL (the
#             no-DOI fallback calcofi4db writes) replaced by https://doi.org/<doi> · else the
#             record's, untouched
#
# Nothing is typed: a release with no DOI in any of the three keeps the record's citation as it is.
#
# No Jekyll dependency on purpose: `_test/release_doi_test.rb` requires this file alone.
module CalCOFI
  module ReleaseDoi
    module_function

    # release: the record's `release` block · catalog: the release's catalog.json (or nil) ·
    # versions: versions.json's `versions` array (or nil). Returns a release block; the argument is
    # never modified.
    def call(release, catalog = nil, versions = nil)
      return release unless release.is_a?(Hash)
      ver = release["version"]
      cat = catalog.is_a?(Hash) && catalog["version"] == ver ? catalog : {}
      row = versions.is_a?(Array) ? versions.find { |v| v.is_a?(Hash) && v["version"] == ver } : nil
      doi = present(release["doi"]) || present(cat["doi"]) || present(row && row["doi"])
      return release if doi.nil?
      release.merge("doi" => doi, "citation" => citation(release, cat, doi))
    end

    def citation(release, cat, doi)
      url    = "https://doi.org/#{doi}"
      own    = present(release["citation"])
      theirs = present(cat["citation"])
      tail   = present(release["schema_url"])
      return own    if own&.include?(url)
      return theirs if theirs&.include?(url)
      return own.delete_suffix(tail) + url if own && tail && own.end_with?(tail)
      own
    end

    def present(v)
      v.is_a?(String) && !v.strip.empty? ? v.strip : nil
    end
  end
end
