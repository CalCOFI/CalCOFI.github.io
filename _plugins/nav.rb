# frozen_string_literal: true

require "json"

# _plugins/nav.rb — the header's words, resolved once (brand v3, 2026-11-17).
#
# _data/nav.yml is the one hand-edited list of the header's words and menus. CalCOFI::Nav.resolve turns it
# into the list both the site's own header (_includes/site_nav.html) and /brand/v3/nav.json (drawn into the
# other products by brand/v3/header.js) are made from, so the two cannot disagree:
#
#   · `product: key`  → that product's live_url from _data/products.yml (`title: product` → its title);
#                       a key that is not there drops the item, so a retired product leaves no dead line
#   · `section: id`   → that page-section's url (docs, faq); an unknown id drops the item
#   · `explore: path` → the Explorer's address + path (site.local_explore on a preview, else the product's)
#   · `count: name`   → the release's own number, formatted (datasets / species / measurements), as the
#                       grey line; a number the build cannot read leaves the line off — never a typed one
#   · a site path (/datasets/, /#learn) → `path` (for this site's relative links) and `url` (site_url + path,
#     for a product on another origin); a full URL is both
#   · a menu emptied by dropped items is dropped; a rule is kept only between two items
#
# Pure functions with no Jekyll dependency, so _test/nav_test.rb pins them on fixtures.
module CalCOFI
  module Nav
    module_function

    QUERY_URL = "https://calcofi.io/query/"

    # the Query Builder's address: a preview's or a local build's own copy when it names one, else the live one
    def query_address(local) = present?(local) ? local : QUERY_URL

    def present?(v) = !(v.nil? || (v.respond_to?(:empty?) && v.empty?))

    # nav: the parsed _data/nav.yml · products / sections: products.yml's two lists · counts: {name => "1,000"}
    def resolve(nav, products: [], sections: [], counts: {}, site_url: "", explore_url: nil, query_url: nil)
      prod = (products || []).to_h { |p| [p["key"], p] }
      sect = (sections || []).to_h { |s| [s["id"], s] }
      explore = explore_url || prod.dig("explore", "live_url") || "https://calcofi.io/explore/"
      # the Query Builder has its own address (Ben, 2026-11-17: "move the Query Builder to its own dedicated query");
      # a preview or a local build names its own copy (_config.*.yml local_query)
      query = query_address(query_url)
      ctx = { prod: prod, sect: sect, counts: counts || {}, site_url: site_url.to_s.sub(%r{/\z}, ""), explore: explore, query: query }
      ((nav || {})["words"] || []).filter_map { |w| word(w, ctx) }
    end

    def word(w, ctx)
      base = { "id" => w["id"], "title" => w["title"], "here" => w["here"] || [] }
      if w["menu"]
        cols = columns(w["menu"], ctx)
        return nil if cols.empty?
        base.merge("menu" => cols, "align" => %w[right center].include?(w["align"]) ? w["align"] : "left")
      else
        l = link(w, ctx) or return nil
        base.merge(l).merge("ext" => w["ext"] == true)
      end
    end

    # a menu is columns ({title:, items:}) or one untitled column of items
    def columns(menu, ctx)
      cols = menu.all? { |m| m.is_a?(Hash) && m.key?("items") } ? menu : [{ "title" => nil, "items" => menu }]
      cols.filter_map do |c|
        items = tidy_rules((c["items"] || []).filter_map { |i| item(i, ctx) })
        items.empty? ? nil : { "title" => c["title"], "items" => items }
      end
    end

    def item(i, ctx)
      return { "rule" => true } if i["rule"]
      l = link(i, ctx) or return nil
      title = i["title"] == "product" ? ctx[:prod].dig(i["product"], "title") : i["title"]
      return nil unless present?(title)
      small = i["count"] ? count_line(i["count"], ctx[:counts], i["before"], i["after"]) : i["small"]
      out = { "title" => title, "small" => present?(small) ? small : nil, "icon" => i["icon"], "go" => i["go"] }.merge(l)
      out["new"] = true if i["new"] == true   # opens in a new tab (the Map menu's apps); absent otherwise
      out
    end

    # "All 20" for datasets (the menu's first line names the whole list), the bare number otherwise
    # `before` / `after` (nav.yml) put words round the number: "Browse all 20 datasets"
    def count_line(name, counts, before = nil, after = nil)
      n = counts[name]
      return nil unless present?(n)
      return "#{before}#{n}#{after}" if present?(before) || present?(after)
      name == "datasets" ? "All #{n}" : n.to_s
    end

    # {path:, url:}: `path` is what this site links (a site path stays a path), `url` what another origin links
    def link(x, ctx)
      href =
        if x["product"] then ctx[:prod].dig(x["product"], "live_url")
        elsif x["section"] then ctx[:sect].dig(x["section"], "url")
        elsif x["explore"] then "#{ctx[:explore]}#{x['explore']}"
        elsif x.key?("query") then "#{ctx[:query]}#{x['query']}"
        else x["href"]
        end
      return nil unless present?(href)
      href.start_with?("/") ? { "path" => href, "url" => "#{ctx[:site_url]}#{href}" } : { "path" => href, "url" => href }
    end

    # a rule only between two items: none first, none last, never two together
    def tidy_rules(items)
      out = items.each_with_object([]) { |i, a| a << i unless i["rule"] && (a.empty? || a.last["rule"]) }
      out.pop while out.last && out.last["rule"]
      out
    end

    # the words a reader sees in the bar, in order (scripts/check_layout.py and check_brand.py read nav.json's)
    def titles(resolved) = resolved.map { |w| w["title"] }
  end

  # site.data["nav"] is replaced by the resolved list wrapped as {"words" => […]}, and /brand/v3/nav.json is written
  class NavData < Jekyll::Generator
    safe true
    priority :lowest # after the catalog, whose numbers the Data menu shows

    def generate(site)
      raw = site.data["nav"] or return
      cat = site.data["catalog"] || {}
      nums = cat["numbers"] || {}
      counts = { "datasets" => cat.dig("counts", "datasets")&.to_s, "species" => nums["species_fmt"],
                 "measurements" => nums["measurements_keys_fmt"] }
      prods = site.data["products"] || {}
      words = Nav.resolve(raw, products: prods["products"], sections: prods["sections"], counts: counts,
                               site_url: "#{site.config['url']}#{site.config['baseurl']}",
                               explore_url: site.config["local_explore"], query_url: site.config["local_query"])
      site.data["nav_words"] = words
      # the one address of the Query Builder, for the start card and the dataset pages' CSV links
      site.data["query_url"] = Nav.query_address(site.config["local_query"])
      page = Jekyll::PageWithoutAFile.new(site, site.source, "brand/v3", "nav.json")
      page.content = "{% raw %}#{JSON.pretty_generate({ 'version' => '3', 'words' => words })}{% endraw %}"
      page.data["layout"] = nil
      page.data["sitemap"] = false
      site.pages << page
    end
  end
end
