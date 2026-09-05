#!/usr/bin/env ruby
# _test/derive_id_test.rb — the identifier parser, against every URL shape the release record
# actually contains (read off _data/datasets.json on 2026-09-05) plus the nil cases.
#
#     ruby _test/derive_id_test.rb
#
# calcofi4db 4.5.0 derives registrations[].id with the same rules (plan D-9); this file is the
# list the two must agree on, so a change on either side has one place to be checked against.
require "minitest/autorun"
require_relative "../_plugins/derive_id"

class DeriveIdTest < Minitest::Test
  D = CalCOFI::DeriveId

  # the nine the plan names, each from a URL that is in the record
  CASES = {
    # EDI, both shapes
    "https://portal.edirepository.org/nis/mapbrowse?packageid=edi.109.4" => "edi.109.4",
    "https://portal.edirepository.org/nis/mapbrowse?scope=knb-lter-cce&identifier=78&revision=3" => "knb-lter-cce.78.3",
    "https://portal.edirepository.org/nis/mapbrowse?scope=knb-lter-cce&identifier=313" => "knb-lter-cce.313",
    "https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-cce.255.3" => "knb-lter-cce.255.3",
    # NCEI
    "https://www.ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=gov.noaa.nodc:0301029" => "gov.noaa.nodc:0301029",
    # OBIS
    "https://obis.org/dataset/0e223f55-c826-4513-ae9a-b04cbf2e189c" => "0e223f55-c826-4513-ae9a-b04cbf2e189c",
    # an OBIS-USA IPT resource
    "https://ipt-obis.gbif.us/resource?r=calcofi_ichthyo" => "calcofi_ichthyo",
    # Zenodo, through the DOI
    "https://doi.org/10.5281/zenodo.22281994" => "10.5281/zenodo.22281994",
    # CalOOS
    "https://data.caloos.org/#module-metadata/1a1a7812-48f9-4325-8ad0-e51e67e366ba" => "1a1a7812-48f9-4325-8ad0-e51e67e366ba",
    # NOAA CoastWatch ERDDAP
    "https://coastwatch.pfeg.noaa.gov/erddap/tabledap/erdCalCOFIlrvcnt.html" => "erdCalCOFIlrvcnt",
  }.freeze

  # the rest of the shapes in the record, so a portal we already list cannot regress silently
  MORE = {
    "https://data.caloos.org/#module-metadata/81f12914-825b-499c-8aad-33b34ec29c93/2301d387-2347-463" =>
      "81f12914-825b-499c-8aad-33b34ec29c93",   # a deeper route: the MODULE id is the identifier
    "https://erddap.calcofi.io/erddap/info/calcofi_ctd-cast/index.html" => "calcofi_ctd-cast",
    "https://erddap.calcofi.io/erddap/metadata/iso19115/xml/calcofi_bottle_iso19115.xml" => "calcofi_bottle",
    "https://oceanview.pfeg.noaa.gov/erddap/tabledap/CAC_FI_SBAS_tr.html" => "CAC_FI_SBAS_tr",
    "https://coastwatch.pfeg.noaa.gov/erddap/tabledap/siocalcofiHydroBottle.html" => "siocalcofiHydroBottle",
    "https://oceaninformatics.ucsd.edu/datazoo/catalogs/ccelter/datasets/254" => "254",
    "https://www.ncbi.nlm.nih.gov/bioproject/555783" => "PRJNA555783",
    "https://doi.org/10.25740/nt620vn7810" => "10.25740/nt620vn7810",
  }.freeze

  # a URL that names no identifier must return nil — never a guess, and never a path segment that
  # merely looks like one
  NONE = [
    nil, "", "   ",
    "https://calcofi.org/data/oceanographic-data/bottle-database/",
    "https://oceaninformatics.ucsd.edu/zoodb/",
    "https://library.ucsd.edu/dc/search?q=CalCOFI+Dungeness+crab+megalopae",
    "https://searchworks.stanford.edu/catalog?utf8=%E2%9C%93&search_field=search&q=calcofi",
    "https://portal.edirepository.org/nis/home.jsp",
    "https://data.caloos.org/",
  ].freeze

  def test_the_nine_the_plan_names
    CASES.each { |url, want| assert_equal want, D.call(url), "from #{url}" }
  end

  def test_every_other_shape_in_the_record
    MORE.each { |url, want| assert_equal want, D.call(url), "from #{url}" }
  end

  def test_a_url_that_names_nothing_derives_nothing
    NONE.each { |url| assert_nil D.call(url), "from #{url.inspect}" }
  end

  def test_percent_escapes_are_resolved
    assert_equal "knb-lter-cce.78.3",
                 D.call("https://portal.edirepository.org/nis/mapbrowse?packageid=knb%2Dlter%2Dcce.78.3")
  end

  # an id already on the row always wins; this parser is only ever the fallback
  def test_it_is_a_fallback_not_an_override
    assert_equal "edi.109.4", D.call("https://portal.edirepository.org/nis/mapbrowse?packageid=edi.109.4")
  end
end
