#!/usr/bin/env ruby
# _test/source_way_test.rb — a dataset's original page in its ways in (Erin, 2026-10-19: "for the
# individual datasets can it take people to the original page … zooplankton goes to EDI or the
# ZooScan DB; other datasets go to ERDDAP"), against small synthetic records:
#
#     ruby _test/source_way_test.rb
#
#   named     an app the URL names wins (the ZooScan DB, not its host's DataZoo portal)
#   portal    else the portal of the distribution at that URL, or the longest portal address
#   host      else the bare host
#   way       links.data_source is one "Original at …" way, after the apps, before ERDDAP
#   once      a URL is listed once: an original page that is also calcofi.org's is not repeated
#   none      no data_source, or not a web address, no way
require "minitest/autorun"
require "logger"

unless defined?(Jekyll)
  module Jekyll
    class Generator
      def self.safe(*) = nil
      def self.priority(*) = nil
    end
    module Errors
      class FatalException < StandardError; end
    end
    def self.logger = (@logger ||= Class.new { def warn(*) = nil }.new)
  end
end
require_relative "../_plugins/datasets"

class SourceWayTest < Minitest::Test
  FakeSite = Struct.new(:data, :config)

  PORTALS = [
    { "portal" => "edi",      "url" => "https://portal.edirepository.org" },
    { "portal" => "datazoo",  "url" => "https://oceaninformatics.ucsd.edu" },
    { "portal" => "ncei",     "url" => "https://www.ncei.noaa.gov" },
    { "portal" => "calcofi.org", "url" => "https://calcofi.org/data/" }
  ].freeze

  def catalog
    CalCOFI::Catalog.new(FakeSite.new({ "products" => { "products" => [] } }, { "url" => "https://calcofi.io" }),
                         { "release" => { "version" => "v9.9.9" }, "datasets" => [], "portals" => PORTALS },
                         [])
  end

  def record(src, dist = [])
    { "dataset_key" => "x_y", "dataset_name" => "An X dataset", "links" => { "data_source" => src },
      "distributions" => dist, "coverage" => {}, "status" => { "stage" => "released" } }
  end

  def test_named_app_wins_over_its_hosts_portal
    assert_equal "ZooScan DB", catalog.source_name(record(nil), "https://oceaninformatics.ucsd.edu/zooscandb/")
    assert_equal "ZooDB", catalog.source_name(record(nil), "https://oceaninformatics.ucsd.edu/zoodb/")
  end

  def test_portal_by_address_then_by_distribution
    c = catalog
    assert_equal "EDI", c.source_name(record(nil), "https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-cce.21.3")
    assert_equal "NCEI", c.source_name(record(nil), "https://www.ncei.noaa.gov/access/metadata/landing-page/bin/iso?id=x")
    u = "https://example.org/a/b"
    assert_equal "EDI", c.source_name(record(u, [{ "url" => u, "portal" => "edi" }]), u)
  end

  def test_host_when_nothing_names_it
    assert_equal "library.example.edu", catalog.source_name(record(nil), "https://library.example.edu/dc/object/bb9")
    assert_equal "GBIF", catalog.source_name(record(nil), "https://www.gbif.org/dataset/1052")
  end

  def test_one_original_way_after_the_apps_before_erddap
    dist = [{ "kind" => "service", "format" => "erddap", "portal" => "erddap", "url" => "https://erddap.calcofi.io/erddap/tabledap/x_y.html" }]
    r = record("https://portal.edirepository.org/nis/mapbrowse?packageid=knb-lter-cce.21.3", dist)
    ways = catalog.ways(r)
    src = ways.select { |w| w["kind"] == "source" }
    assert_equal 1, src.size
    assert_equal "Original at EDI", src.first["label"]
    i_src = ways.index(src.first)
    i_erd = ways.index { |w| w["label"] == "ERDDAP" }
    assert i_erd.nil? || i_src < i_erd, "the original page comes before ERDDAP: #{ways.map { |w| w['label'] }}"
    assert ways.each_index.select { |i| ways[i]["kind"] == "app" }.all? { |i| i < i_src }
  end

  def test_a_url_is_listed_once
    u = "https://calcofi.org/data/oceanographic-data/ctd-cast-files/"
    r = record(u, [{ "kind" => "page", "portal" => "calcofi.org", "url" => u }])
    ways = catalog.ways(r)
    assert_equal 1, ways.count { |w| w["url"] == u }
    assert_equal "Original at CalCOFI.org", ways.find { |w| w["url"] == u }["label"]
  end

  def test_no_source_no_way
    assert_empty catalog.ways(record(nil)).select { |w| w["kind"] == "source" }
    assert_empty catalog.ways(record("see the provider")).select { |w| w["kind"] == "source" }
  end
end
