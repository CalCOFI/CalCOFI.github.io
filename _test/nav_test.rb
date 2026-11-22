#!/usr/bin/env ruby
# _test/nav_test.rb — the header's words (_plugins/nav.rb, CalCOFI::Nav), on a small synthetic list and on the
# committed _data/nav.yml:
#
#     ruby _test/nav_test.rb
#
#   links      a site path keeps its path and gains the site's URL; a full URL is both; a product key takes the
#              product's live_url; a section id takes that page-section's url; `explore:` hangs off the Explorer
#   dropped    an item whose product or section is not there is dropped (no dead line), a menu emptied that way
#              is dropped, and a rule is kept only between two items
#   counts     the grey line is the release's own number ("All 20" for datasets), absent when the build has none
#   the words  the committed list reads Data · Map · Learn · calcofi.org ↗ (Ben, 2026-11-17, evening); the Query
#              Builder is the first line of Data ▾ › Get it, at its own address;
#              Learn holds Guides (How CalCOFI samples, FAQ, Cite the data, Documentation) and News (Tutorials,
#              Stories, All news); no destination is linked twice; and everything main's eight words reached
#              (the catalogs, the apps, access, build, docs, FAQ, news) is still linked
require "minitest/autorun"
require "yaml"
require "date"

unless defined?(Jekyll)
  module Jekyll
    class Generator
      def self.safe(*) = nil
      def self.priority(*) = nil
    end
  end
end
require_relative "../_plugins/nav"

class NavTest < Minitest::Test
  N = CalCOFI::Nav

  PRODUCTS = [{ "key" => "explore", "title" => "CalCOFI Explorer", "live_url" => "https://calcofi.io/explore/" },
              { "key" => "map-x", "title" => "The X Map", "live_url" => "https://x.example/map/" }].freeze
  SECTIONS = [{ "id" => "docs", "kind" => "page", "url" => "https://calcofi.io/docs/" }].freeze
  COUNTS = { "datasets" => "20", "species" => "1,000" }.freeze

  def resolve(words, **kw)
    N.resolve({ "words" => words }, products: PRODUCTS, sections: SECTIONS, counts: COUNTS, site_url: "https://calcofi.io", **kw)
  end

  def test_a_site_path_keeps_its_path_and_gains_the_site_url
    w = resolve([{ "id" => "news", "title" => "News", "href" => "/news/", "here" => ["news"] }]).first
    assert_equal({ "id" => "news", "title" => "News", "here" => ["news"], "path" => "/news/", "url" => "https://calcofi.io/news/", "ext" => false }, w)
  end

  def test_a_full_url_is_both_and_ext_is_carried
    w = resolve([{ "id" => "org", "title" => "calcofi.org ↗", "href" => "https://calcofi.org", "ext" => true }]).first
    assert_equal ["https://calcofi.org", "https://calcofi.org", true], w.values_at("path", "url", "ext")
  end

  def test_with_no_site_url_a_path_stays_a_path
    w = N.resolve({ "words" => [{ "id" => "n", "title" => "News", "href" => "/news/" }] }, site_url: "").first
    assert_equal ["/news/", "/news/"], w.values_at("path", "url"), "a preview with url \"\" keeps every link inside itself"
  end

  def test_product_section_and_explore_links
    ws = resolve([{ "id" => "q", "title" => "Lens", "explore" => "?lens=hex" },
                  { "id" => "d", "title" => "Docs", "section" => "docs" },
                  { "id" => "m", "title" => "Map", "product" => "map-x" }])
    assert_equal ["https://calcofi.io/explore/?lens=hex", "https://calcofi.io/docs/", "https://x.example/map/"], ws.map { |w| w["url"] }
  end

  def test_explore_follows_the_previews_own_explorer
    w = resolve([{ "id" => "q", "title" => "Lens", "explore" => "?lens=hex" }], explore_url: "/explore/").first
    assert_equal "/explore/?lens=hex", w["path"]
  end

  # the Query Builder has its own address, calcofi.io/query/ (Ben, 2026-11-17), not a page of the Explorer
  def test_query_is_its_own_address
    w = resolve([{ "id" => "query", "title" => "Query", "query" => "" }]).first
    assert_equal ["https://calcofi.io/query/", "https://calcofi.io/query/"], w.values_at("path", "url")
    get = committed.find { |x| x["id"] == "data" }["menu"].find { |c| c["title"] == "Get the data" }["items"]
    assert_equal ["Query Builder", "https://calcofi.io/query/"], get.first.values_at("title", "url"), "the committed line: first under Data ▾ › Get the data"
    assert_nil committed.find { |x| x["id"] == "query" }, "Query is not also a word of the bar (Ben, 2026-11-17)"
  end

  def test_query_follows_the_previews_own_copy
    w = resolve([{ "id" => "query", "title" => "Query", "query" => "" }], query_url: "/query/").first
    assert_equal "/query/", w["path"]
    w = resolve([{ "id" => "query", "title" => "Query", "query" => "" }], query_url: "").first
    assert_equal "https://calcofi.io/query/", w["path"], "an empty setting is not an address"
    assert_equal ["https://calcofi.io/query/", "https://calcofi.io/query/", "/query/"], [nil, "", "/query/"].map { |l| N.query_address(l) }
  end

  def test_a_word_whose_product_or_section_is_gone_is_dropped
    assert_empty resolve([{ "id" => "f", "title" => "FAQ", "section" => "faq" }, { "id" => "g", "title" => "Gone", "product" => "retired" }])
  end

  def test_menu_items_columns_counts_and_the_products_own_title
    w = resolve([{ "id" => "data", "title" => "Data", "menu" => [
      { "title" => "Find", "items" => [{ "title" => "Datasets", "href" => "/datasets/", "count" => "datasets", "icon" => "ui-data" },
                                         { "title" => "Species", "href" => "/species/", "count" => "species" },
                                         { "title" => "Measurements", "href" => "/measurements/", "count" => "measurements" }] },
      { "title" => "Apps", "items" => [{ "title" => "product", "product" => "map-x", "small" => "A map" }] }
    ] }]).first
    assert_equal "left", w["align"]
    assert_equal %w[Find Apps], w["menu"].map { |c| c["title"] }
    find = w["menu"][0]["items"]
    assert_equal({ "title" => "Datasets", "small" => "All 20", "icon" => "ui-data", "go" => nil, "path" => "/datasets/", "url" => "https://calcofi.io/datasets/" }, find[0])
    assert_equal "1,000", find[1]["small"]
    assert_nil find[2]["small"], "a number the build cannot read is not drawn"
    assert_equal ["The X Map", "A map", "https://x.example/map/"], w["menu"][1]["items"][0].values_at("title", "small", "url")
  end

  def test_a_flat_menu_is_one_untitled_column_and_rules_are_tidied
    w = resolve([{ "id" => "map", "title" => "Map", "align" => "right", "menu" => [
      { "rule" => true }, { "title" => "Gone", "product" => "retired" }, { "title" => "Explorer", "product" => "explore" },
      { "rule" => true }, { "rule" => true }, { "title" => "All apps", "href" => "/#explore" }, { "rule" => true }
    ] }]).first
    assert_equal "right", w["align"]
    assert_equal 1, w["menu"].size
    assert_nil w["menu"][0]["title"]
    assert_equal ["Explorer", :rule, "All apps"], w["menu"][0]["items"].map { |i| i["rule"] ? :rule : i["title"] }
  end

  def test_a_menu_with_nothing_left_is_dropped
    assert_empty resolve([{ "id" => "m", "title" => "Map", "menu" => [{ "title" => "Gone", "product" => "retired" }, { "rule" => true }] }])
  end

  # ── the committed list ──
  def committed
    nav = YAML.safe_load(File.read(File.join(__dir__, "..", "_data", "nav.yml")))
    prods = YAML.safe_load(File.read(File.join(__dir__, "..", "_data", "products.yml")), permitted_classes: [Date], aliases: true)
    N.resolve(nav, products: prods["products"], sections: prods["sections"], counts: { "datasets" => "20", "species" => "1,000", "measurements" => "104" },
                   site_url: "https://calcofi.io")
  end

  def test_the_committed_words
    assert_equal ["Data", "Map", "Learn", "calcofi.org ↗"], N.titles(committed)
  end

  # Ben, 2026-11-17 (evening): the bar is simplified and Learn holds the rest. Docs, FAQ, News and Cite had been
  # words of the bar that afternoon; each is now a line of Learn, said once, and none is also a word.
  def test_learn_holds_the_guides_and_the_news
    ws = committed
    learn = ws.find { |w| w["id"] == "learn" }
    assert_equal %w[Guides News], learn["menu"].map { |c| c["title"] }
    assert_equal ["How CalCOFI samples", "Frequently asked questions", "Cite the data", "Documentation"], learn["menu"][0]["items"].map { |i| i["title"] }
    assert_equal ["https://calcofi.io/#learn", "https://calcofi.io/docs/faq.html", "https://calcofi.io/docs/cite.html", "https://calcofi.io/docs/"],
                 learn["menu"][0]["items"].map { |i| i["url"] }
    assert_equal [["Tutorials", "https://calcofi.io/news/?type=tutorial"], ["Stories", "https://calcofi.io/news/?type=story"], ["All news", "https://calcofi.io/news/"]],
                 learn["menu"][1]["items"].map { |i| [i["title"], i["url"]] }
    assert_equal "center", learn["align"]
    assert_equal %w[news stories tutorials], learn["here"]
    assert_empty ws.map { |w| w["id"] } & %w[docs faq news cite], "none of them is also a word of the bar"
  end

  # every destination is linked once in the header: no line repeats a word, no line repeats a line
  def test_no_destination_is_linked_twice
    urls = committed.flat_map { |w| w["menu"] ? w["menu"].flat_map { |c| c["items"] }.reject { |i| i["rule"] }.map { |i| i["url"] } : [w["url"]] }
    assert_equal urls.uniq, urls
  end

  def test_three_words_open_menus
    assert_equal %w[data map learn], committed.select { |w| w["menu"] }.map { |w| w["id"] }
  end

  # everything main's eight words reached is still linked from the header (a word, or a line of a menu)
  def test_everything_mains_header_reached_is_still_linked
    urls = committed.flat_map { |w| w["menu"] ? w["menu"].flat_map { |c| c["items"] }.reject { |i| i["rule"] }.map { |i| i["url"] } : [w["url"]] }
    %w[https://calcofi.io/datasets/ https://calcofi.io/species/ https://calcofi.io/measurements/
       https://calcofi.io/explore/ https://calcofi.io/#explore https://calcofi.io/#services https://calcofi.io/#packages
       https://calcofi.io/#build https://calcofi.io/docs/ https://calcofi.io/docs/faq.html https://calcofi.io/news/
       https://calcofi.io/docs/cite.html https://calcofi.io/query/ https://calcofi.org].each do |u|
      assert_includes urls, u
    end
  end

  def test_every_committed_menu_line_has_a_title_and_a_url
    committed.select { |w| w["menu"] }.each do |w|
      w["menu"].flat_map { |c| c["items"] }.reject { |i| i["rule"] }.each do |i|
        refute_nil i["title"], w["id"]
        assert_match %r{\Ahttps?://}, i["url"], "#{w['id']} › #{i['title']}"
      end
    end
  end
end
