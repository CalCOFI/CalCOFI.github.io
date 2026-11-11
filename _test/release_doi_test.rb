#!/usr/bin/env ruby
# _test/release_doi_test.rb — the release's DOI and the citation that ends in it, against small
# synthetic release blocks:
#
#     ruby _test/release_doi_test.rb
#
#   record      a record that carries its own DOI and cites it is returned as it is
#   catalog     a record with no DOI takes the DOI and the citation of the release's catalog.json
#   versions    with no catalog.json, the DOI is the versions.json row's and the citation's trailing
#               schema URL becomes https://doi.org/<doi>
#   version     a catalog.json or a versions.json row of ANOTHER release is never read
#   none        no DOI anywhere: the record's citation stays (the schema-URL fallback)
#   regression  v2026.11.09: the dataset pages cited db-schema/?v= while the release had a DOI
require "minitest/autorun"
require_relative "../_plugins/release_doi"

class ReleaseDoiTest < Minitest::Test
  DOI    = "10.5281/zenodo.1234567".freeze
  SCHEMA = "https://calcofi.io/db-schema/?v=v9.9.9".freeze
  LEAD   = "CalCOFI (2026). CalCOFI Integrated Database, release v9.9.9 [Data set]. Publisher. ".freeze

  def record(extra = {})
    { "version" => "v9.9.9", "release_date" => "2026-10-01", "doi" => nil,
      "concept_doi" => "10.5281/zenodo.1", "citation" => LEAD + SCHEMA, "schema_url" => SCHEMA }.merge(extra)
  end

  def catalog(extra = {})
    { "version" => "v9.9.9", "doi" => DOI, "citation" => "#{LEAD}https://doi.org/#{DOI}" }.merge(extra)
  end

  def versions(doi = DOI)
    [{ "version" => "v9.9.9", "doi" => doi }, { "version" => "v9.9.8", "doi" => "10.5281/zenodo.999" }]
  end

  def resolve(*args) = CalCOFI::ReleaseDoi.call(*args)

  def test_a_record_that_cites_its_own_doi_is_unchanged
    r = record("doi" => DOI, "citation" => "#{LEAD}https://doi.org/#{DOI}")
    assert_equal r, resolve(r, catalog("doi" => "10.5281/zenodo.7", "citation" => "other"), versions("10.5281/zenodo.8"))
  end

  def test_the_catalog_supplies_the_doi_and_its_own_citation
    out = resolve(record, catalog("citation" => "The catalog's own words. https://doi.org/#{DOI}"), versions)
    assert_equal DOI, out["doi"]
    assert_equal "The catalog's own words. https://doi.org/#{DOI}", out["citation"]
  end

  def test_the_versions_row_supplies_the_doi_and_the_schema_url_gives_way_to_it
    out = resolve(record, nil, versions)
    assert_equal DOI, out["doi"]
    assert_equal "#{LEAD}https://doi.org/#{DOI}", out["citation"]
  end

  def test_a_catalog_citation_without_the_doi_is_not_used
    out = resolve(record, catalog("citation" => LEAD + SCHEMA), nil)
    assert_equal "#{LEAD}https://doi.org/#{DOI}", out["citation"]
  end

  def test_another_releases_files_are_never_read
    r = record
    assert_equal r, resolve(r, catalog("version" => "v9.9.8"), [{ "version" => "v9.9.8", "doi" => DOI }])
  end

  def test_no_doi_anywhere_keeps_the_fallback
    r = record
    assert_equal r, resolve(r, catalog("doi" => nil, "citation" => nil), versions(nil))
    assert_equal r, resolve(r, nil, nil)
    assert_equal r, resolve(r)
    assert_equal LEAD + SCHEMA, resolve(r, { "version" => "v9.9.9", "doi" => "" }, [])["citation"]
  end

  def test_a_citation_that_does_not_end_in_the_schema_url_is_left_alone
    r = record("citation" => "Words that end somewhere else.")
    out = resolve(r, nil, versions)
    assert_equal DOI, out["doi"]
    assert_equal "Words that end somewhere else.", out["citation"]
  end

  def test_the_record_is_not_modified
    r = record.freeze
    resolve(r, catalog, versions)
    assert_nil r["doi"]
    assert_equal LEAD + SCHEMA, r["citation"]
  end

  def test_everything_else_in_the_record_is_kept
    out = resolve(record, catalog, versions)
    assert_equal "10.5281/zenodo.1", out["concept_doi"]
    assert_equal SCHEMA, out["schema_url"]
    assert_equal "2026-10-01", out["release_date"]
  end

  # regression (2026-11-11): calcofi_bottle's page cited the release as …db-schema/?v=v2026.11.09
  # while calcofi4r and docs/cite.html cited https://doi.org/10.5281/zenodo.24083894
  def test_v2026_11_09_cites_its_doi
    lead = "CalCOFI (2026). CalCOFI Integrated Database, release v2026.11.09 [Data set]. Scripps Institution of " \
           "Oceanography, NOAA Fisheries, and California Department of Fish and Wildlife. "
    rec  = { "version" => "v2026.11.09", "doi" => nil, "schema_url" => "https://calcofi.io/db-schema/?v=v2026.11.09",
             "citation" => "#{lead}https://calcofi.io/db-schema/?v=v2026.11.09" }
    vers = [{ "version" => "v2026.11.09", "doi" => "10.5281/zenodo.24083894" }]
    assert_equal "#{lead}https://doi.org/10.5281/zenodo.24083894", resolve(rec, nil, vers)["citation"]
  end

  def test_not_a_release_block_is_returned_as_it_is
    assert_nil resolve(nil, catalog, versions)
  end
end
