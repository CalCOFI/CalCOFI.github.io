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
#   the words  the committed list reads Data · Map · Query · Cite · Learn · Docs · FAQ · News · calcofi.org ↗;
#              Docs, FAQ and News are words of the bar (Ben, 2026-11-17) and not also lines of a menu; Learn is a
#              plain word to the #learn panel; and everything main's eight words reached (the catalogs, the apps,
#              access, build, docs, FAQ, news) is still linked
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
    ws = resolve([{ "id" => "q", "title" => "Query", "explore" => "builder.html" },
                  { "id" => "d", "title" => "Docs", "section" => "docs" },
                  { "id" => "m", "title" => "Map", "product" => "map-x" }])
    assert_equal ["https://calcofi.io/explore/builder.html", "https://calcofi.io/docs/", "https://x.example/map/"], ws.map { |w| w["url"] }
  end

  def test_explore_follows_the_previews_own_explorer
    w = resolve([{ "id" => "q", "title" => "Query", "explore" => "builder.html" }], explore_url: "/explore/").first
    assert_equal "/explore/builder.html", w["path"]
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
    assert_equal ["Data", "Map", "Query", "Cite", "Learn", "Docs", "FAQ", "News", "calcofi.org ↗"], N.titles(committed)
  end

  # regression (2026-11-17): front door v2 had Docs, FAQ and News only as lines of the Learn menu; Ben: "we lost
  # items like News and FAQ", then "Yes, Docs too". They are words of the bar, in main's order, and each is said
  # once: no menu also lists them.
  def test_docs_faq_and_news_are_words_and_not_also_lines_of_a_menu
    ws = committed
    assert_equal %w[docs faq news], ws.map { |w| w["id"] } & %w[docs faq news]
    assert_equal ["https://calcofi.io/docs/", "https://calcofi.io/docs/faq.html", "https://calcofi.io/news/"],
                 %w[docs faq news].map { |id| ws.find { |w| w["id"] == id }["url"] }
    %w[docs faq news].each { |id| assert_nil ws.find { |w| w["id"] == id }["menu"], "#{id} is a plain word" }
    lines = ws.select { |w| w["menu"] }.flat_map { |w| w["menu"].flat_map { |c| c["items"] } }.reject { |i| i["rule"] }
    assert_empty lines.map { |i| i["url"] } & ["https://calcofi.io/docs/", "https://calcofi.io/docs/faq.html", "https://calcofi.io/news/"]
  end

  # Learn's menu was left with one line once Docs, FAQ and News were words, so Learn is a plain word that opens
  # that line: the front door's #learn panel
  def test_learn_is_a_plain_word_to_the_learn_panel
    learn = committed.find { |w| w["id"] == "learn" }
    assert_nil learn["menu"]
    assert_equal "https://calcofi.io/#learn", learn["url"]
  end

  def test_two_words_open_menus
    assert_equal %w[data map], committed.select { |w| w["menu"] }.map { |w| w["id"] }
  end

  # everything main's eight words reached is still linked from the header (a word, or a line of a menu)
  def test_everything_mains_header_reached_is_still_linked
    urls = committed.flat_map { |w| w["menu"] ? w["menu"].flat_map { |c| c["items"] }.reject { |i| i["rule"] }.map { |i| i["url"] } : [w["url"]] }
    %w[https://calcofi.io/datasets/ https://calcofi.io/species/ https://calcofi.io/measurements/
       https://calcofi.io/explore/ https://calcofi.io/#explore https://calcofi.io/#services https://calcofi.io/#packages
       https://calcofi.io/#build https://calcofi.io/docs/ https://calcofi.io/docs/faq.html https://calcofi.io/news/
       https://calcofi.io/docs/cite.html https://calcofi.io/explore/builder.html https://calcofi.org].each do |u|
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
