#!/usr/bin/env ruby
# _test/licence_pending_test.rb — what a citation and the JSON-LD say about a licence the provider
# has not stated yet (metadata/license.csv `unknown`, "Not yet established"; the five datasets of
# v2026.10.04 include two of them), against small synthetic records:
#
#     ruby _test/licence_pending_test.rb
#
#   unknown   cite_text / bibtex say "License: not yet established", never the raw id "unknown"
#   stated    CC-BY-4.0 and custom (with its URL) keep their wording
#   blank     no licence, no line
#   jsonld    the schema.org `license` is a URL or a licence id: "unknown" is neither, so it is absent
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

class LicencePendingTest < Minitest::Test
  FakeSite = Struct.new(:data, :config)

  def catalog
    CalCOFI::Catalog.new(FakeSite.new({}, { "url" => "https://calcofi.io" }),
                         { "release" => { "version" => "v9.9.9", "release_date" => "2026-10-01" }, "datasets" => [] },
                         [])
  end

  def record(attribution)
    { "dataset_key" => "x_y", "dataset_name" => "An X dataset", "attribution" => attribution,
      "provider" => { "key" => "x", "name" => "X" }, "coverage" => {} }
  end

  def test_unknown_reads_as_pending_in_the_citation
    r = record("license" => "unknown", "license_name" => "Not yet established")
    txt = catalog.cite_text(r)
    assert_includes txt, "License: not yet established"
    refute_match(/License: unknown/, txt)
    assert_includes catalog.bibtex(r), "License: not yet established"
    refute_match(/License: unknown/, catalog.bibtex(r))
  end

  def test_unknown_without_a_name_still_reads_as_pending
    txt = catalog.cite_text(record("license" => "unknown"))
    assert_includes txt, "License: not yet established"
  end

  def test_stated_licences_keep_their_wording
    assert_includes catalog.cite_text(record("license" => "CC-BY-4.0")), "License: CC-BY-4.0"
    custom = record("license" => "custom", "license_url" => "https://example.org/terms")
    assert_includes catalog.cite_text(custom), "License: custom (https://example.org/terms)"
  end

  def test_a_blank_licence_adds_no_line
    refute_match(/License:/, catalog.cite_text(record("license" => nil)))
    refute_match(/License:/, catalog.cite_text(record({})))
  end

  def test_jsonld_leaves_out_a_pending_licence
    ld = catalog.jsonld(record("license" => "unknown", "license_name" => "Not yet established"))
    refute ld.key?("license") && ld["license"], "an unknown licence is not a JSON-LD licence"
    ld2 = catalog.jsonld(record("license" => "CC-BY-4.0", "license_url" => "https://creativecommons.org/licenses/by/4.0/"))
    assert_equal "https://creativecommons.org/licenses/by/4.0/", ld2["license"]
  end
end
