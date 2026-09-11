# _plugins/species.rb — the species catalog, generated from the release's taxa record.
#
# `_data/taxa.json` (calcofi4db::build_taxa_catalog(), schema 1.0; fetched by
# scripts/fetch_release.sh) is the ONLY source of a taxon fact on this site, exactly as
# `_data/datasets.json` is for a dataset. Its FACE — the silhouette, the photo, the lengths, the
# plate and the borrowed sentence — comes from `_data/taxa_media.json`, written by
# scripts/fetch_species_media.py rather than by the release (plan 2026-09-11 § D6), and from
# `_data/size_reference.csv`. A taxon with no entry in the sidecar renders exactly as it did
# before. This generator turns it into:
#
#   /species/                 the index: the counts, search + the tree, the class x dataset matrix,
#                             the icicle — all four drawn by assets/species.js from ONE inline JSON
#   /species/{slug}/          one page per taxon with an observation at or below it (2,410 today),
#                             with schema.org/Taxon JSON-LD
#   /species/{slug}.json      that taxon's entry of the record, verbatim
#   /species/sitemap.xml      the pages, lastmod = release_date (linked from /species/, the way
#                             /datasets/sitemap.xml is linked from /datasets/)
#
# and hands the index `site.data.species` (the numbers, the datasets, the inline JSON) so the
# layout stays Liquid.
#
# The slug is the record's own: the taxon key with its ":" written "-" — `worms:217452` becomes
# `/species/worms-217452/`. The reverse is the split on the LAST dash before the trailing digits
# (`/^(.*)-(\d+)$/`), so a dataset key's own hyphens survive: `cce-lter_zooscan-13` is
# `cce-lter_zooscan:13`.
#
# The record is a FOREST, not a tree: `worms:1` Biota, `worms:3` Plantae, `worms:6` Bacteria,
# `worms:7` Chromista, `itis:202423` Animalia (the ITIS bird lineage — WoRMS lags on Aves) and the
# 14 dataset-local classes are all roots. The pages follow the record exactly; only the INDEX's
# tree merges what the two authorities say twice — see `display_nodes` below.
#
# Rules that hold here because they hold in the record:
#   · a number is read, never typed; a field the record cannot supply is not rendered
#   · without `_data/taxa.json` NOTHING is generated — one NOTE, no species pages, and the front
#     door's Life tile falls back to the Explorer (plan 2026-09-09 § D7, the D-2 rule)
#   · dataset colour is never the only cue: a dot always has its dataset's name beside it
#
# This runs at :normal — after datasets.rb (:high), which it reads `site.data.catalog` from for the
# dataset pages' URLs, and before news.rb (:low).

require "json"
require "cgi"

module CalCOFI
  # ── the taxa record, wrapped ───────────────────────────────────────────────
  class Taxa
    attr_reader :rec

    def initialize(site, rec)
      @site = site
      @rec  = rec
      @base = (site.config["url"].to_s + site.config["baseurl"].to_s).sub(%r{/\z}, "")
      @base = "https://calcofi.io" if @base.empty?
    end

    def release  = rec["release"]
    def counts   = rec["counts"] || {}
    def taxa     = @taxa ||= rec["taxa"] || []
    def datasets = @datasets ||= rec["datasets"] || []
    def abs(path) = "#{@base}#{path}"

    def by_key  = @by_key ||= taxa.to_h { |t| [t["taxon_key"], t] }
    def ds_by_key = @ds_by_key ||= datasets.to_h { |d| [d["dataset_key"], d] }

    # taxon_key => the taxa whose parent it is, most observed first
    def children
      @children ||= begin
        h = Hash.new { |x, k| x[k] = [] }
        taxa.each { |t| h[t["parent_taxon_key"]] << t if t["parent_taxon_key"] }
        h.each_value { |a| a.sort_by! { |t| [-t.dig("rollup", "n_obs").to_i, t["scientific_name"].to_s] } }
        h
      end
    end

    def page_url(t)     = "/species/#{t['slug']}/"
    def url_for_key(k)  = (x = by_key[k]) ? page_url(x) : nil

    # Biota › Animalia › … › Sardinops — the record's own parent chain, root first
    def ancestors(t)
      out = []
      seen = {}
      p = t["parent_taxon_key"]
      while p && (a = by_key[p]) && !seen[p]
        seen[p] = true
        out.unshift(a)
        p = a["parent_taxon_key"]
      end
      out
    end

    # ── names and ranks ──────────────────────────────────────────────────────
    # The accepted name, written once. A dataset-local class has none: it is headed by the name its
    # dataset gives it, and the page says so.
    def name_of(t)
      Fmt.present(t["scientific_name"]) ||
        Fmt.present(t.dig("local", "name")) ||
        Fmt.present(t.dig("local", "code")) ||
        t["taxon_key"].to_s.sub(/\A[^:]+:/, "")
    end

    def local?(t)  = t.key?("local") && !t["local"].nil?
    def italic?(t) = ITALIC_RANKS.include?(t["rank"])

    ITALIC_RANKS = %w[Genus Species Subspecies Variety Forma].freeze

    # the mockup's rank abbreviations, extended by rule: an unknown rank shows its first three
    # letters rather than nothing, so a rank the next release introduces still reads
    RANK_ABBR = {
      "Superdomain" => "BIO", "Domain" => "D", "Kingdom" => "K", "Subkingdom" => "sK",
      "Infrakingdom" => "iK", "Phylum" => "P", "Phylum (Division)" => "P", "Subphylum" => "sP",
      "Subphylum (Subdivision)" => "sP", "Infraphylum" => "iP", "Parvphylum" => "pP",
      "Gigaclass" => "gC", "Megaclass" => "mC", "Superclass" => "SC", "Class" => "C",
      "Subclass" => "sC", "Infraclass" => "iC", "Subterclass" => "stC", "Superorder" => "SO",
      "Order" => "O", "Suborder" => "sO", "Infraorder" => "iO", "Section" => "sec",
      "Subsection" => "ssec", "Superfamily" => "SF", "Family" => "F", "Subfamily" => "sF",
      "Tribe" => "T", "Genus" => "G", "Species" => "sp", "Subspecies" => "ssp",
      "Forma" => "f", "Variety" => "var"
    }.freeze
    def rank_abbr(r) = r.nil? ? "loc" : (RANK_ABBR[r] || r[0, 3])

    # ── the flags a dataset's own name can carry ─────────────────────────────
    # A label map with a plain-text fallback, so a flag the next release adds renders as itself
    # rather than disappearing.
    FLAG_LABELS = {
      "synonym"     => ["synonym",     "the name this dataset uses is not the accepted name"],
      "sp_to_genus" => ["sp. → genus", "a \"sp.\" name in the dataset resolved to its genus"],
      "rekeyed"     => ["re-keyed",    "the id this dataset supplied was deprecated by the authority and re-keyed to its successor"],
      "id_conflict" => ["id conflict", "a secondary authority's id this dataset supplied disagrees with the key authority's cross-reference"],
      "no_name"     => ["code only",   "this dataset carries only a code for it, no name"]
    }.freeze

    def flag_chip(f)
      label, title = FLAG_LABELS[f] || [f.to_s.tr("_", " "), "a flag this release introduced: #{f}"]
      { "flag" => f, "label" => label, "title" => title }
    end

    # ── ids, linked out ──────────────────────────────────────────────────────
    ID_LINKS = [
      ["worms_id", "WoRMS", "https://www.marinespecies.org/aphia.php?p=taxdetails&id=%s"],
      ["itis_id",  "ITIS",  "https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=%s"],
      ["gbif_id",  "GBIF",  "https://www.gbif.org/species/%s"],
      ["ncbi_id",  "NCBI",  "https://www.ncbi.nlm.nih.gov/Taxonomy/Browser/wwwtax.cgi?id=%s"],
      ["inat_id",  "iNat",  "https://www.inaturalist.org/taxa/%s"]
    ].freeze

    def id_rows(t)
      ids = t["ids"] || {}
      ID_LINKS.filter_map do |field, label, pattern|
        v = ids[field]
        next if v.nil?
        { "label" => label, "id" => v, "url" => format(pattern, v) }
      end
    end

    # the authority's own identifier for the JSON-LD: WoRMS's LSID, ITIS's TSN page, and for a
    # dataset-local class the key itself (no authority has one — saying so is the honest answer)
    def identifier(t)
      key = t["taxon_key"].to_s
      if key.start_with?("worms:") && t.dig("ids", "worms_id")
        "urn:lsid:marinespecies.org:taxname:#{t.dig('ids', 'worms_id')}"
      elsif key.start_with?("itis:") && t.dig("ids", "itis_id")
        "https://www.itis.gov/servlet/SingleRpt/SingleRpt?search_topic=TSN&search_value=#{t.dig('ids', 'itis_id')}"
      else
        key
      end
    end

    # ── the display tree (the INDEX only; every page follows the record) ─────
    # The record keys birds through ITIS and everything else through WoRMS, so four names are in it
    # twice — Kingdom Animalia, Phylum Chordata, Subphylum Vertebrata, Infraphylum Gnathostomata.
    # Listing Chordata twice in a browsing tree would be a lie about the data, so the index MERGES
    # display nodes of the same rank AND scientific_name: one node, the summed observations, linked
    # to the `worms:` page where both exist. Nothing is lost — a merged node's members keep their
    # own pages, and the non-primary member's children re-parent to the merged node.
    #
    #   · a merge group's PRIMARY is its `worms:` member, else its `itis:` member, else the first key
    #   · a display node's parent is its primary's nearest ancestor that is not merged away
    #   · a node left with no observations of its own and no children is not drawn (the two ITIS
    #     scaffolding ranks, Bilateria and Deuterostomia, whose only descendant chain merges into
    #     the WoRMS Chordata); its page still exists and its lineage still names it
    #   · the tree's top is the KINGDOMS: a root above kingdom rank (`worms:1` Biota, rank_order 1)
    #     is lifted and its children take the top, so the four kingdoms and the dataset-local
    #     classes are what a reader opens on. Biota keeps its page and every lineage names it.
    #   · the 14 dataset-local classes hang under one synthetic "Dataset-local classes" node
    LOCAL_NODE = "_local"
    KINGDOM_RANK_ORDER = 4      # the record's own rank_order for Kingdom; anything above it is scaffolding

    def merge_groups
      @merge_groups ||= begin
        g = Hash.new { |h, k| h[k] = [] }
        taxa.each do |t|
          next unless Fmt.present(t["rank"]) && Fmt.present(t["scientific_name"])
          g[[t["rank"], t["scientific_name"]]] << t
        end
        g.select { |_, v| v.size > 1 }
      end
    end

    # taxon_key => the display node's key (itself, unless it is a merged non-primary)
    def rep
      @rep ||= begin
        h = {}
        merge_groups.each_value do |members|
          primary = members.find { |t| t["taxon_key"].start_with?("worms:") } ||
                    members.find { |t| t["taxon_key"].start_with?("itis:") } || members.first
          members.each { |t| h[t["taxon_key"]] = primary["taxon_key"] }
        end
        h
      end
    end

    def rep_of(k) = rep[k] || k

    # one hash per drawn node: k key · g slug · n name · c common · r rank · p display parent ·
    # o DIRECT observations (summed over merged members) · d per-dataset direct observations ·
    # l the dataset's own label for a local class · m the number of members when merged
    def display_nodes
      @display_nodes ||= begin
        members = Hash.new { |h, k| h[k] = [] }
        taxa.each { |t| members[rep_of(t["taxon_key"])] << t }

        nodes = {}
        members.each do |key, ms|
          primary = by_key[key]
          # the parent: the nearest ancestor whose display node is not this one
          p = nil
          a = primary["parent_taxon_key"]
          while a
            r = rep_of(a)
            if r != key
              p = r
              break
            end
            a = by_key[a] && by_key[a]["parent_taxon_key"]
          end
          d = Hash.new(0)
          ms.each { |t| (t["datasets"] || []).each { |x| d[x["dataset_key"]] += x["n_obs"].to_i } }
          nodes[key] = {
            "k" => key, "g" => primary["slug"],
            "n" => Fmt.present(primary["scientific_name"]),
            "c" => Fmt.present(primary["common_name"]),
            "r" => Fmt.present(primary["rank"]),
            "ro" => primary["rank_order"],
            "p" => local?(primary) ? LOCAL_NODE : p,
            "o" => ms.sum { |t| t.dig("direct", "n_obs").to_i },
            "d" => d,
            "l" => local?(primary) ? "#{Fmt.present(primary.dig('local', 'name')) || primary.dig('local', 'code')} (#{primary.dig('local', 'dataset_key')})" : nil,
            "m" => ms.size > 1 ? ms.size : nil
          }.compact
        end

        # the synthetic parent of the dataset-local classes
        nodes[LOCAL_NODE] = { "k" => LOCAL_NODE, "n" => "Dataset-local classes",
                              "c" => "codes a dataset uses that are not a WoRMS or ITIS taxon",
                              "p" => nil, "o" => 0, "d" => {} }

        # lift the roots above kingdom rank, so the tree opens on the kingdoms
        lifted = nodes.values.select { |n| n["p"].nil? && n["ro"] && n["ro"] < KINGDOM_RANK_ORDER }
                      .map { |n| n["k"] }
        unless lifted.empty?
          nodes.each_value { |n| n["p"] = nodes[n["p"]] && nodes[n["p"]]["p"] if lifted.include?(n["p"]) }
          lifted.each { |k| nodes.delete(k) }
        end

        # drop what the merge left empty: no observations of its own, no children (repeat until
        # nothing more falls out — the chain is two deep today)
        loop do
          kids = Hash.new(0)
          nodes.each_value { |n| kids[n["p"]] += 1 if n["p"] }
          dead = nodes.values.select { |n| n["o"].to_i.zero? && kids[n["k"]].zero? && n["k"] != LOCAL_NODE }
          break if dead.empty?
          dead.each { |n| nodes.delete(n["k"]) }
        end
        nodes
      end
    end

    def tree_roots = display_nodes.values.select { |n| n["p"].nil? }
                                  .sort_by { |n| [n["k"] == LOCAL_NODE ? 1 : 0, -rollup_obs(n["k"])] }

    # a display node's observations including its display descendants — used for the root order
    def rollup_obs(key)
      @rollup_obs ||= begin
        kids = Hash.new { |h, k| h[k] = [] }
        display_nodes.each_value { |n| kids[n["p"]] << n["k"] if n["p"] }
        memo = {}
        walk = lambda do |k|
          memo[k] ||= display_nodes[k]["o"].to_i + kids[k].sum { |c| walk.(c) }
        end
        display_nodes.each_key { |k| walk.(k) }
        memo
      end
      @rollup_obs[key].to_i
    end

    # ── the class x dataset matrix (which species, in which datasets) ────────
    # rows = the classes that have an observed taxon, grouped by phylum, plus the two rows the
    # record makes necessary: taxa identified above class, and the dataset-local classes. The cell
    # is the number of DISTINCT taxa that dataset observed in that class; the tooltip names the
    # three biggest. Computed here, once, from the record — species.js only paints it.
    ABOVE_CLASS = "_above"

    def matrix
      @matrix ||= begin
        cls_key = taxa.select { |t| t["rank"] == "Class" }.to_h { |t| [t["scientific_name"], t["taxon_key"]] }
        rows = {}
        taxa.each do |t|
          next if t.dig("direct", "n_obs").to_i.zero?
          cname = Fmt.present(t.dig("lineage", "class"))
          rk = local?(t) ? LOCAL_NODE : (cname ? (cls_key[cname] || cname) : ABOVE_CLASS)
          row = (rows[rk] ||= { "key" => rk, "name" => cname || (local?(t) ? "Dataset-local classes" : "Identified above class"),
                                # only a real class row has a phylum: "Identified above class" gathers
                                # taxa from every phylum and a dataset-local class has none
                                "phylum" => cname ? Fmt.present(t.dig("lineage", "phylum")) : nil,
                                "url" => cname ? url_for_key(cls_key[cname]) : nil,
                                "cells" => Hash.new { |h, k| h[k] = { "n" => 0, "obs" => 0, "top" => [] } },
                                "n" => 0, "obs" => 0 })
          row["n"] += 1
          (t["datasets"] || []).each do |x|
            c = row["cells"][x["dataset_key"]]
            c["n"] += 1
            c["obs"] += x["n_obs"].to_i
            c["top"] << [name_of(t), x["n_obs"].to_i]
            row["obs"] += x["n_obs"].to_i
          end
        end
        ordered = rows.values.sort_by { |r| [r["phylum"] || "zzz", -r["obs"]] }
        cols = datasets.map { |d| d["dataset_key"] }.select { |k| ordered.any? { |r| r["cells"].key?(k) } }
        ordered.each do |r|
          r["cells"].each_value { |c| c["top"] = c["top"].sort_by { |_, n| -n }.first(3).map(&:first) }
        end
        { "rows" => ordered.map { |r| r.merge("cells" => cols.map { |k| r["cells"][k]["n"].zero? ? nil : r["cells"][k] }) },
          "cols" => cols }
      end
    end

    # ── the icicle: kingdom → phylum → class → order → family ────────────────
    # The record's flattened lineage columns, aggregated once here. Each node carries its
    # observations, the species under it and the datasets that saw it, so the drawing is a pure
    # rendering of counts read from the record.
    LEVELS = %w[kingdom phylum class order family].freeze

    def icicle
      @icicle ||= begin
        keyed = {}
        LEVELS.each do |lev|
          rk = lev == "order" ? "Order" : lev.capitalize
          taxa.each { |t| keyed[[lev, t["scientific_name"]]] ||= t["taxon_key"] if t["rank"] == rk && t["scientific_name"] }
        end
        root = { "name" => "All taxa", "o" => 0, "sp" => 0, "d" => Hash.new(0), "kids" => {} }
        taxa.each do |t|
          n_obs = t.dig("direct", "n_obs").to_i
          next if n_obs.zero? || local?(t)
          path = LEVELS.map { |lev| Fmt.present(t.dig("lineage", lev)) }
          path = path.take_while { |x| !x.nil? }
          sp = t["rank"] == "Species" ? 1 : 0
          per = (t["datasets"] || []).to_h { |x| [x["dataset_key"], x["n_obs"].to_i] }
          node = root
          node["o"] += n_obs
          node["sp"] += sp
          per.each { |k, v| node["d"][k] += v }
          path.each_with_index do |nm, i|
            node = (node["kids"][nm] ||= { "name" => nm, "k" => keyed[[LEVELS[i], nm]],
                                          "o" => 0, "sp" => 0, "d" => Hash.new(0), "kids" => {} })
            node["o"] += n_obs
            node["sp"] += sp
            per.each { |k, v| node["d"][k] += v }
          end
        end
        pack = lambda do |n|
          kids = n["kids"].values.sort_by { |x| -x["o"] }.map { |x| pack.(x) }
          out = { "name" => n["name"], "o" => n["o"], "sp" => n["sp"], "d" => n["d"] }
          out["k"] = n["k"] if n["k"]
          out["kids"] = kids unless kids.empty?
          out
        end
        pack.(root)
      end
    end

    # WS-F4: the taxon's silhouette for a phylum/class tree row — 18 px tall, `fill: currentColor`,
    # drawn by assets/species.js. Sourced from _data/taxa_media.json (WS-F2a's fetch, never
    # git-tracked); a rank outside the tree's fold levels, or a key the sidecar lacks, carries no
    # "sil" and the row keeps its height with no glyph (the correct empty state).
    SIL_RANKS = ["Phylum", "Phylum (Division)", "Class"].freeze

    def sil_of(key, rank)
      return nil unless SIL_RANKS.include?(rank)
      s = @site.data.dig("taxa_media", "taxa", key, "silhouette")
      return nil unless s && Fmt.present(s["svg_inner"]) && Fmt.present(s["viewBox"]) && s["aspect"]
      { "inner" => s["svg_inner"], "vb" => s["viewBox"], "aspect" => s["aspect"] }
    end

    # ── the one payload the index inlines ────────────────────────────────────
    # key · slug · name · common · rank · parent · direct observations · per-dataset observations,
    # plus the matrix and the icicle, both already counted here. Datasets are referenced by their
    # INDEX in ds[] so 2,410 nodes do not repeat ten dataset keys each.
    def inline
      @inline ||= begin
        di = datasets.each_with_index.to_h { |d, i| [d["dataset_key"], i] }
        cat = @site.data.dig("catalog", "index") || {}
        { "rel"   => release["version"],
          "date"  => release["release_date"],
          "base"  => "/species/",
          "counts" => counts.merge("tree" => display_nodes.size - 1),   # the synthetic node is not a taxon
          "ds"    => datasets.map do |d|
            { "k" => d["dataset_key"],
              "s" => d["dataset_name_short"] || d["dataset_key"],
              "c" => d["color"],
              "cat" => d.dig("category", "name"),
              "u" => cat.dig(d["dataset_key"], "url") || "/datasets/#{d['dataset_key']}/",
              "n" => d["n_obs"], "t" => d["n_taxa"] }
          end,
          # the slug is NOT carried: it is the key with its ":" written "-", so species.js derives
          # it and 2,403 nodes do not repeat their own key twice (48 KB of the payload)
          "nodes" => display_nodes.values.map do |n|
            { "k" => n["k"], "n" => n["n"], "c" => n["c"], "r" => n["r"],
              "p" => n["p"], "o" => n["o"],
              "d" => n["d"].map { |k, v| [di[k], v] }.select { |i, _| i },
              "l" => n["l"], "m" => n["m"], "sil" => sil_of(n["k"], n["r"]) }.compact
          end,
          "mx"    => { "cols" => matrix["cols"].map { |k| di[k] },
                       "rows" => matrix["rows"].map do |r|
                         { "n" => r["name"], "ph" => r["phylum"], "u" => r["url"], "t" => r["n"],
                           "c" => r["cells"].map { |c| c && { "n" => c["n"], "o" => c["obs"], "t" => c["top"] } } }
                       end },
          "ice"   => index_icicle(di) }
      end
    end

    # the icicle with its dataset keys written as indices into ds[] — the same trade the nodes make
    def index_icicle(di)
      walk = lambda do |n|
        out = { "name" => n["name"], "o" => n["o"], "sp" => n["sp"],
                "d" => n["d"].map { |k, v| [di[k], v] }.select { |i, _| i } }
        out["k"] = n["k"] if n["k"]
        out["kids"] = n["kids"].map { |x| walk.(x) } if n["kids"]
        out
      end
      walk.(icicle)
    end

    # ── one species page's own facts ─────────────────────────────────────────
    # The record's own word for its biggest number (plan 2026-09-11 § D9). A row of `obs_bio` is
    # not an organism: 75.5 % of the CUFES rows and 85.0 % of the phytoplankton rows are
    # `value = 0`, so "62,898 observations" of the sardine counted 38,929 tows that caught none.
    # Until `build_taxa_catalog()` carries `n_present` (rows with `value > 0`) the page says
    # **records**; when it does, the stat reads `n_present` observations with `n_obs` records
    # beside it. Nothing here is typed: the word follows the field the record actually has.
    def stat_row(t)
      direct = t["direct"] || {}
      roll   = t["rollup"] || {}
      obs    = roll["n_obs"] || direct["n_obs"]
      present = roll["n_present"] || direct["n_present"]
      rows = []
      if present
        rows << { "dd" => Fmt.num(present), "dt" => "observations",
                  "title" => "rows of obs_bio with value > 0 — the taxon was actually caught" }
        rows << { "dd" => Fmt.num(obs), "dt" => "records",
                  "title" => "every row of obs_bio keyed to it, including the sampling events that caught none" }
      elsif obs
        title = (roll["n_obs"].to_i > direct["n_obs"].to_i) ?
          "#{Fmt.num(direct['n_obs'])} keyed to this taxon itself · #{Fmt.num(roll['n_obs'])} including every taxon under it" :
          "#{Fmt.num(obs)} rows of obs_bio — one taxon × one life stage × one sampling event, whether or not any was caught"
        rows << { "dd" => Fmt.num(obs), "dt" => "records", "title" => title }
      end
      rows << { "dd" => Fmt.num(direct["n_samples"]), "dt" => "sampling events" } if direct["n_samples"].to_i.positive?
      y0 = roll["year_min"] || direct["year_min"]
      y1 = roll["year_max"] || direct["year_max"]
      rows << { "dd" => (y0 == y1 ? y0.to_s : "#{y0}–#{y1}"), "dt" => "years" } if y0 && y1
      rows << { "dd" => Fmt.num(roll["n_datasets"] || direct["n_datasets"]), "dt" => "datasets" } if (roll["n_datasets"] || direct["n_datasets"])
      if roll["n_taxa"].to_i > 1
        rows << { "dd" => Fmt.num(roll["n_species"]), "dt" => "species under it",
                  "title" => "#{Fmt.num(roll['n_taxa'])} taxa with an observation at or below this one" }
      end
      stages = direct["life_stages"] || []
      rows << { "dd" => stages.join(" · "), "dt" => "life stages", "small" => true } unless stages.empty?
      rows
    end

    # ══ faces (WS-F3) ════════════════════════════════════════════════════════
    # The page's picture, its size and its sentence — plan 2026-09-11 § D1–D5, D8, D9.
    #
    # The ONLY new source is `_data/taxa_media.json`, written by scripts/fetch_species_media.py
    # (never by the release: the media depend on eight external services and change on their own
    # cadence — plan § D6). A taxon with no entry renders exactly as it did before this section
    # existed: every slot below is nil-safe and an absent slot leaves no gap.
    #
    # Nothing here is typed. A length, a licence, a credit and a reference object all come from the
    # sidecar or from `_data/size_reference.csv`; the only numbers in this file are the layout's
    # own (a bar's percentage width) and the one display THRESHOLD below.
    MEDIA_BASE = "https://storage.googleapis.com/calcofi-files-public/"
    # hair and mesh are not "familiar" objects to compare an organism with — they join the glance's
    # candidates only for something too small for a coin. A display rule, not a measurement.
    GLANCE_SMALL_M = 0.002
    GLANCE_FAMILIAR = %w[quarter ring person ship].freeze

    def media = @media ||= (@site.data["taxa_media"] || {})
    def media_taxa = @media_taxa ||= (media["taxa"] || {})

    # a cached thumbnail on the public bucket first (pages are stable and no third party is
    # hot-linked — plan § D8); the source URL only while the fetcher has not cached it yet
    def media_url(a)
      return nil if a.nil?
      cached = Fmt.present(a["cached"])
      return "#{media['base'] || MEDIA_BASE}#{cached}" if cached
      Fmt.present(a["url"])
    end

    def license_url_of(a) = Fmt.present(a["license_url"])
    def nc?(a) = a && a["license"].to_s.match?(/\bNC\b|NonCommercial/i)

    # 0.395 → "39.5 cm". The page's one length formatter; assets/species.js mirrors it for the
    # figures it draws.
    def fmt_len(m)
      return nil if m.nil?
      m = m.to_f
      v, u = if m < 1e-3 then [m * 1e6, "µm"]
             elsif m < 1e-2 then [m * 1e3, "mm"]
             elsif m < 1 then [m * 100, "cm"]
             else [m, "m"]
             end
      "#{(v - v.round).abs < 0.05 ? v.round.to_s : format('%.1f', v)} #{u}"
    end

    # the ladder's reference objects, from _data/size_reference.csv and nowhere else
    def size_refs
      @size_refs ||= (@site.data["size_reference"] || []).filter_map do |r|
        m = r["m"].to_s.strip
        next if m.empty? || Fmt.present(r["key"]).nil?
        { "k" => r["key"], "label" => r["label"], "m" => Float(m), "note" => r["note"], "source" => r["source"] }
      end
    end

    # the reference within an order of magnitude whose log-ratio is smallest (plan § D3)
    def nearest_ref(m)
      pool = size_refs.select { |r| GLANCE_FAMILIAR.include?(r["k"]) }
      pool = size_refs if m < GLANCE_SMALL_M || pool.empty?
      pool.min_by { |r| (Math.log10(m / r["m"])).abs }
    end

    # the short name the glance and the beside figure label the organism with
    def short_name(t)
      c = Fmt.present(t["common_name"])
      c ? c.sub(/\s*\(.*\)\s*\z/, "") : name_of(t)
    end

    def face_of(t) = media_taxa[t["taxon_key"]]

    # ── the face row: the silhouette, the photo, the glance ──────────────────
    def face(t)
      f = face_of(t)
      return nil if f.nil?
      out = {}
      if (s = f["silhouette"]) && Fmt.present(s["svg_inner"])
        # no svg_inner means the generator could not normalise the vector: draw NO silhouette
        # rather than an <img> that cannot take the page's ink
        steps = s["steps_up"].to_i
        shown = Fmt.present(s["taxon_shown"])
        out["sil"] = {
          "inner" => s["svg_inner"], "viewBox" => s["viewBox"] || "0 0 1 1",
          "aspect" => s["aspect"], "axis" => Fmt.present(s["length_axis"]),
          "label" => "Silhouette of #{shown || name_of(t)}",
          "stand_in" => (steps.positive? || (shown && shown != name_of(t))),
          "shown" => shown, "steps_up" => steps,
          "credit" => { "kind" => "Silhouette", "by" => Fmt.present(s["credit"]),
                        "license" => Fmt.present(s["license"]), "license_url" => license_url_of(s),
                        "via" => "PhyloPic", "page" => Fmt.present(s["url"]) }
        }.compact
      end
      if (p = f["photo"]) && (src = media_url(p))
        focal = p["focal"].is_a?(Array) ? p["focal"] : [0.5, 0.5]
        out["photo"] = {
          "src" => src, "alt" => Fmt.present(p["shows"]) || "Photograph of #{name_of(t)}",
          "w" => p["w"], "h" => p["h"],
          "pos" => "#{(focal[0].to_f * 100).round(1)}% #{(focal[1].to_f * 100).round(1)}%",
          "nc" => nc?(p), "license" => Fmt.present(p["license"]),
          "license_url" => license_url_of(p), "page" => Fmt.present(p["page"]),
          "credit" => { "kind" => "Photo", "by" => Fmt.present(p["credit"]),
                        "license" => Fmt.present(p["license"]), "license_url" => license_url_of(p),
                        "via" => Fmt.present(p["via"]) || Fmt.present(p["source"]),
                        "page" => Fmt.present(p["page"]), "shows" => Fmt.present(p["shows"]) }
        }.compact
      end
      if (x = f["text"]) && Fmt.present(x["url"])
        out["text"] = { "kind" => "Text", "title" => Fmt.present(x["title"]),
                        "page" => Fmt.present(x["url"]), "license" => Fmt.present(x["license"]),
                        "revision" => Fmt.present(x["revision"].to_s), "timestamp" => Fmt.present(x["timestamp"]),
                        "via" => "Wikipedia" }.compact
      end
      out.empty? ? nil : out
    end

    # ── the glance: two bars, the taxon and the nearest familiar reference ───
    def glance(t)
      f = face_of(t)
      sz = f && f["size"]
      return nil if sz.nil? || sz["m"].nil? || size_refs.empty?
      m = sz["m"].to_f
      ref = nearest_ref(m)
      return nil if ref.nil?
      r = m / ref["m"]
      { "org_label" => short_name(t), "org_len" => fmt_len(m), "org_w" => format("%.1f", r >= 1 ? 100 : r * 100),
        "ref_key" => ref["k"], "ref_label" => ref["label"], "ref_len" => fmt_len(ref["m"]),
        "ref_w" => format("%.1f", r >= 1 ? 100 / r : 100), "ref_note" => ref["note"],
        "kind" => Fmt.present(sz["kind"]), "source" => Fmt.present(sz["source"]), "url" => Fmt.present(sz["url"]) }
    end

    # ── the sentence: borrowed prose, generated facts, each part marked ──────
    LEAD_MAX = 320

    def stages_text(st)
      st = (st || []).compact
      return nil if st.empty?
      return st.join(" and ") if st.size == 2
      return "#{st.first(3).join(', ')} and #{st.size - 3} more stages" if st.size > 4
      st.join(", ")
    end

    # the WoRMS/ITIS authority string, iff the RECORD carries one. v2026.09.10's taxa.json does
    # not, so the clause is simply absent — it is never fetched and never invented.
    def authority_of(t)
      a = Fmt.present(t["taxonomic_authority"]) || Fmt.present(t.dig("worms", "authority"))
      return nil if a.nil?
      m = /\A\(?(.+?),\s*(\d{4})\)?\z/.match(a)
      m ? "Named by #{m[1]} in #{m[2]}" : nil
    end

    def sentence(t)
      f = face_of(t)
      roll = t["rollup"] || {}
      direct = t["direct"] || {}
      out = {}

      if (x = f && f["text"])
        lead = Fmt.present(x["lead"]) || Fmt.present(x["extract"])
        if lead && lead.length > LEAD_MAX
          # the last sentence end inside the cap. The character BEFORE the stop must be a lower-case
          # letter, a digit or a closing bracket, so "C. G. Ehrenberg" and "Moser, H.G." are not
          # mistaken for the end of a sentence (the fixture's own Chaetoceros lead is cut there).
          cut = lead[0, LEAD_MAX].rindex(/[a-z0-9)\]”"'][.!?](?=\s|\z)/)
          lead = cut ? lead[0, cut + 2] : "#{lead[0, LEAD_MAX].rstrip}…"
        end
        # the borrowed half and the measured half are two sentences, so the borrowed one has to end
        # like one. The fixture's Chaetoceros lead stops at "the German naturalist C. G." — without
        # this the record's sentence ran straight on from it.
        lead = "#{lead}…" if lead && !lead.match?(/[.!?”"'’)\]…]\z/)
        out["wp"] = lead
        out["wp_about_genus"] = (x["about"].to_s == "genus")
        out["wp_title"] = Fmt.present(x["title"])
        out["wp_url"] = Fmt.present(x["url"])
        out["wp_revision"] = Fmt.present(x["revision"].to_s)
      end

      present = roll["n_present"] || direct["n_present"]
      n  = present || roll["n_obs"] || direct["n_obs"]
      if n
        word = present ? "observations" : "records"
        nd   = (roll["n_datasets"] || direct["n_datasets"]).to_i
        y0, y1 = roll["year_min"] || direct["year_min"], roll["year_max"] || direct["year_max"]
        rec = +"CalCOFI holds #{Fmt.num(n)} #{word} of it in #{Fmt.num(nd)} dataset#{'s' if nd != 1}"
        rec << " between #{y0} and #{y1}" if y0 && y1
        if (st = stages_text(direct["life_stages"]))
          rec << ", as #{st}"
        end
        rec << ", across #{Fmt.num(roll['n_taxa'])} taxa under it" if roll["n_taxa"].to_i > 1
        out["rec"] = "#{rec}."
        out["rec_word"] = word
      end

      if (au = authority_of(t))
        g = glance(t)
        au = "#{au}; grows to #{g['org_len']} (#{g['kind']})" if g && g["kind"]
        out["au"] = "#{au}."
      end
      out.compact.empty? ? nil : out
    end

    # ── the credit line under the face row ───────────────────────────────────
    def credits(t)
      f = face(t)
      return [] if f.nil?
      [f.dig("sil", "credit"), f.dig("photo", "credit"), f["text"]].compact
    end

    # ── How big: the ladder, the beside figure and the plate, as ONE payload ─
    # assets/species.js draws all three from this; the Liquid include only hosts them.
    def size_json(t)
      f = face_of(t)
      sil = face(t) && face(t)["sil"]
      sz = f && f["size"]
      early = ((f && f["early"]) || []).filter_map do |e|
        mm = e["mm"]
        next unless mm.is_a?(Array) && mm.size == 2 && mm[0]
        { "stage" => e["stage"], "mm" => [mm[0].to_f, mm[1].to_f],
          "source" => Fmt.present(e["source"]) || (e["ref"] && (media.dig("refs", e["ref"].to_s) || "ref #{e['ref']}")) }
      end
      plate = f && f["plate"]
      { "name" => name_of(t), "short" => short_name(t), "italic" => italic?(t), "rank" => t["rank"],
        "refs" => size_refs,
        "sil" => sil && { "vb" => sil["viewBox"], "inner" => sil["inner"],
                          "aspect" => sil["aspect"], "axis" => sil["axis"] },
        "size" => sz && sz["m"] && { "m" => sz["m"].to_f, "kind" => Fmt.present(sz["kind"]),
                                     "source" => Fmt.present(sz["source"]), "url" => Fmt.present(sz["url"]) },
        "early" => early,
        "plate" => (plate && media_url(plate)) && {
          "src" => media_url(plate), "alt" => Fmt.present(plate["shows"]) || "Developmental plate of #{name_of(t)}",
          "credit" => { "kind" => "Plate", "by" => Fmt.present(plate["credit"]),
                        "license" => Fmt.present(plate["license"]), "license_url" => license_url_of(plate),
                        "via" => Fmt.present(plate["via"]) || Fmt.present(plate["source"]),
                        "page" => Fmt.present(plate["page"]), "shows" => Fmt.present(plate["shows"]) }.compact },
        "stages" => (t["datasets"] || []).filter_map do |x|
          st = x["life_stages"] || []
          next if st.empty?
          d = ds_by_key[x["dataset_key"]] || {}
          { "name" => d["dataset_name_short"] || x["dataset_key"], "stages" => st }
        end }
    end

    # is there anything to put in a How big section at all?
    def has_size_section?(t)
      j = size_json(t)
      !(j["size"].nil? && j["early"].empty? && j["plate"].nil?)
    end

    # ── one row per dataset that observed it: what it counted, and the name it uses
    def dataset_rows(t)
      (t["datasets"] || []).map do |x|
        d = ds_by_key[x["dataset_key"]] || {}
        cat = @site.data.dig("catalog", "index", x["dataset_key"]) || {}
        { "key"    => x["dataset_key"],
          "name"   => d["dataset_name_short"] || cat["name"] || x["dataset_key"],
          "url"    => cat["url"] || "/datasets/#{x['dataset_key']}/",
          "color"  => d["color"],
          "n_obs"  => Fmt.num(x["n_obs"]), "n_samples" => Fmt.num(x["n_samples"]),
          "years"  => (x["year_min"] && x["year_max"]) ?
                        (x["year_min"] == x["year_max"] ? x["year_min"].to_s : "#{x['year_min']}–#{x['year_max']}") : nil,
          "stages" => (x["life_stages"] || []).join(" · "),
          "sources" => (x["sources"] || []).map do |s|
            { "name"   => Fmt.present(s["name"]), "common" => Fmt.present(s["common_name"]),
              "code"   => Fmt.present(s["code"]),
              "italic" => italic?(t) && Fmt.present(s["name"]).to_s.match?(/\A[A-Z][a-z]/),
              "chips"  => (s["flags"] || []).map { |f| flag_chip(f) } }
          end }.compact
      end
    end

    # the years strip's own payload: one row per dataset, one cell per year, 1949 → the release year.
    # It carries `n` and `e` as well — the record's own observation and event counts for that
    # dataset — so scripts/check_layout.py has a RECORD-side number to compare the rendered
    # "Observed in" rows against, rather than a number typed into the check.
    def strip_json(t)
      { "y0" => 1949, "y1" => release["release_date"].to_s[0, 4].to_i,
        "key" => t["taxon_key"],
        "rows" => (t["datasets"] || []).map do |x|
          d = ds_by_key[x["dataset_key"]] || {}
          { "k" => x["dataset_key"], "s" => d["dataset_name_short"] || x["dataset_key"],
            "c" => d["color"], "n" => x["n_obs"], "e" => x["n_samples"], "y" => x["years"] || {} }
        end }
    end

    # ── the ways in: a tool opens prefilled, one row per endpoint ────────────
    EXPLORE = "https://calcofi.io/explore/"
    DBQUERY = "https://calcofi.io/db-query/"
    ERDDAP  = "https://erddap.calcofi.io/erddap/tabledap/"

    def ways(t)
      key = t["taxon_key"]
      authority = key.start_with?("worms:") || key.start_with?("itis:")
      out = []
      out << { "name" => "Explorer",
               "about" => authority ? "maps, sections and time series of this taxon — opens prefilled"
                                    : "a dataset-local class the Explorer does not key by; the organism picker opens on its dataset",
               "url"   => authority ? "#{EXPLORE}?taxon=#{key}" : EXPLORE }
      sql = "SELECT * FROM __TBL:obs_bio__ WHERE taxon_key = '#{key}' LIMIT 100;"
      out << { "name" => "db-query", "about" => "SQL in your browser — the shell opens with this query",
               "url"  => "#{DBQUERY}?sql=#{CGI.escape(sql)}", "sql" => sql }
      if (e = erddap_way(t))
        out << e
      end
      out << { "name" => "R", "code" => <<~R.strip }
        library(calcofi4r)
        con <- cc_get_db()                      # the promoted release
        tbl(con, "obs_bio") |> filter(taxon_key == "#{key}")
      R
      out << { "name" => "Python", "code" => <<~PY.strip }
        import calcofi4py as cc
        con = cc.cc_get_db()
        con.sql("SELECT * FROM obs_bio WHERE taxon_key = '#{key}'").df()
      PY
      out
    end

    # the dataset that observed it most, if its own ERDDAP table is current — constrained to the
    # taxon only where erddap.calcofi.io says the table HAS a taxon_key column (probed once by
    # scripts/fetch_release.sh into _data/erddap_taxon_key.json); otherwise the plain page.
    def erddap_way(t)
      probed = @site.data["erddap_taxon_key"] || {}
      catalog = @site.data.dig("catalog", "index") || {}
      (t["datasets"] || []).each do |x|
        dk = x["dataset_key"]
        rec = (@site.data.dig("datasets", "datasets") || []).find { |d| d["dataset_key"] == dk }
        dist = (rec && rec["distributions"] || []).find do |y|
          y["format"] == "erddap" && y["status"] != "superseded" &&
            y["id"] == dk && y["url"].to_s.end_with?(".html")
        end
        next unless dist
        name = (catalog[dk] || {})["name"] || dk
        has = probed[dist["id"]]
        return { "name" => "ERDDAP",
                 "about" => has ? "CalCOFI's own server, the #{name} table constrained to this taxon"
                                : "CalCOFI's own server: the #{name} table (it carries no taxon_key column to constrain on)",
                 "url" => has ? "#{ERDDAP}#{dist['id']}.html?&taxon_key=%22#{key_quoted(t)}%22" : dist["url"] }
      end
      nil
    end

    def key_quoted(t) = t["taxon_key"]

    # ── schema.org/Taxon ─────────────────────────────────────────────────────
    def jsonld(t)
      url = abs(page_url(t))
      parent = by_key[t["parent_taxon_key"]]
      same = id_rows(t).map { |r| r["url"] }.reject { |u| u.start_with?("https://www.ncbi") || u.start_with?("https://www.inaturalist") }
      node = {
        "@context" => "https://schema.org",
        "@type"    => "Taxon",
        "@id"      => url,
        "url"      => url,
        "name"     => name_of(t),
        "identifier" => identifier(t)
      }
      node["alternateName"] = t["common_name"] if Fmt.present(t["common_name"])
      node["taxonRank"] = t["rank"] if Fmt.present(t["rank"])
      if parent
        node["parentTaxon"] = { "@type" => "Taxon", "@id" => abs(page_url(parent)),
                                "url" => abs(page_url(parent)), "name" => name_of(parent) }
      end
      node["sameAs"] = same unless same.empty?
      # the photo, with the terms it is shown under (plan 2026-09-11 § D8). Only where a photo is
      # actually drawn: a page without one gains nothing here.
      if (p = face(t) && face(t)["photo"])
        img = { "@type" => "ImageObject", "contentUrl" => p["src"] }
        img["license"] = p["license_url"] || p["license"] if p["license_url"] || p["license"]
        img["creditText"] = p.dig("credit", "by") if p.dig("credit", "by")
        img["acquireLicensePage"] = p["page"] if p["page"]
        img["caption"] = p["alt"] if p["alt"]
        node["image"] = img
      end
      node["isPartOf"] = { "@type" => "CollectionPage", "@id" => abs("/species/"),
                           "name" => "CalCOFI species catalog" }
      node
    end

    def index_jsonld
      { "@context" => "https://schema.org",
        "@type"    => "CollectionPage",
        "@id"      => abs("/species/"),
        "url"      => abs("/species/"),
        "name"     => "CalCOFI species catalog",
        "description" => "Every organism CalCOFI has counted, keyed to one accepted name — " \
                         "#{Fmt.num(counts['species_observed'])} identified to species of " \
                         "#{Fmt.num(counts['taxa_observed'])} taxa observed across " \
                         "#{counts['datasets']} datasets in release #{release['version']}.",
        "isPartOf" => { "@type" => "WebSite", "@id" => abs("/"), "url" => abs("/") } }
    end
  end

  # ── the generator ────────────────────────────────────────────────────────
  class SpeciesCatalog < Jekyll::Generator
    safe false
    priority :normal      # after datasets.rb (:high), before news.rb (:low)

    def generate(site)
      rec = site.data["taxa"]
      if rec.nil? || rec["taxa"].nil?
        # the D-2 rule: without the record NOTHING is drawn and nothing is typed. The front door's
        # Life tile reads site.data.species to know whether /species/ exists.
        site.data["species"] = nil
        Jekyll.logger.info "species:",
                           "no _data/taxa.json — no species pages (set TAXA_RELEASE_URL, or wait " \
                           "for a promoted release that carries taxa.json)"
        return
      end
      unless rec["schema_version"].to_s.start_with?("1.")
        Jekyll.logger.warn "species:", "record schema #{rec['schema_version'].inspect}, expected \"1.x\""
      end

      tx = Taxa.new(site, rec)
      inline = tx.inline
      # "</" inside a JSON string would end the <script> element early; \/ is the same string
      json = JSON.generate(inline).gsub("</", "<\\/")

      site.data["species"] = {
        "release"  => tx.release,
        "counts"   => inline["counts"],
        # the same counts written the way a page prints them (1,008, not 1008) — one rule, so the
        # index and the front door can never disagree about a comma
        "counts_fmt" => inline["counts"].transform_values { |v| v.is_a?(Integer) ? Fmt.num(v) : v }
                              .merge("ancestors" => Fmt.num(inline["counts"]["pages"].to_i - inline["counts"]["taxa_observed"].to_i)),
        "datasets" => inline["ds"],
        "matrix"   => { "rows" => tx.matrix["rows"].size, "cols" => tx.matrix["cols"].size },
        "roots"    => tx.tree_roots.map { |n| { "key" => n["k"], "name" => n["n"], "obs" => tx.rollup_obs(n["k"]) } },
        "jsonld"   => JSON.pretty_generate(tx.index_jsonld),
        # taxon_key => slug, so a dataset page can link the taxa in its Coverage list to the pages
        # that EXIST (a vocabulary-only taxon has none) without guessing the slug rule
        "slugs"    => tx.taxa.to_h { |t| [t["taxon_key"], t["slug"]] },
        # dataset_key => the names in that dataset's vocabulary with no observation anywhere: no
        # page, but a provider wants to know they are declared (plan § D6)
        "vocab"    => tx.datasets.to_h { |d| [d["dataset_key"], d["vocabulary_only"] || []] },
        "inline"   => json,
        "inline_kb" => (json.bytesize / 1024.0).round
      }

      pages = [index_page(site, tx)]
      tx.taxa.each { |t| pages.concat(taxon_pages(site, tx, t)) }
      pages << json_page(site, "/species/", "sitemap.xml", sitemap(tx))
      site.pages.concat(pages)

      # faces (WS-F3): what the sidecar actually covers of the pages being drawn, measured here
      if tx.media_taxa.empty?
        Jekyll.logger.info "species:", "no _data/taxa_media.json — no faces (run scripts/fetch_species_media.py)"
      else
        if Fmt.present(tx.media["release"]) && tx.media["release"] != tx.release["version"]
          Jekyll.logger.warn "species:", "taxa_media.json was fetched for release " \
                                         "#{tx.media['release']}, the record is #{tx.release['version']}"
        end
        hit = tx.taxa.count { |t| tx.media_taxa.key?(t["taxon_key"]) }
        Jekyll.logger.info "species:",
                           "faces #{hit} of #{tx.taxa.size} pages · " \
                           "silhouettes #{tx.taxa.count { |t| tx.face(t)&.key?('sil') }} · " \
                           "photos #{tx.taxa.count { |t| tx.face(t)&.key?('photo') }} · " \
                           "sizes #{tx.taxa.count { |t| tx.glance(t) }} · " \
                           "How big #{tx.taxa.count { |t| tx.has_size_section?(t) }} · " \
                           "#{tx.size_refs.size} size references"
      end

      Jekyll.logger.info "species:",
                         "#{tx.taxa.size} pages · #{Fmt.num(tx.counts['taxa_observed'])} taxa observed · " \
                         "#{Fmt.num(tx.counts['species_observed'])} species · #{tx.counts['datasets']} datasets " \
                         "from #{tx.release['version']} · tree #{tx.display_nodes.size - 1} nodes · " \
                         "matrix #{tx.matrix['rows'].size}x#{tx.matrix['cols'].size} · " \
                         "inline #{site.data['species']['inline_kb']} KB"
    end

    def index_page(site, tx)
      page = Jekyll::PageWithoutAFile.new(site, site.source, "species", "index.html")
      page.content = ""
      page.data.merge!(
        "layout" => "species_index",
        "title"  => "Species · CalCOFI",
        "description" => "Every organism CalCOFI has counted — #{Fmt.num(tx.counts['species_observed'])} " \
                         "identified to species of #{Fmt.num(tx.counts['taxa_observed'])} taxa observed, " \
                         "keyed to WoRMS (ITIS for birds), searchable and browsable by phylum, class and family."
      )
      page
    end

    def taxon_pages(site, tx, t)
      ancestors = tx.ancestors(t)
      kids = tx.children[t["taxon_key"]] || []
      page = Jekyll::PageWithoutAFile.new(site, site.source, "species/#{t['slug']}", "index.html")
      page.content = ""
      page.data.merge!(
        "layout"     => "species",
        "title"      => "#{tx.name_of(t)} · CalCOFI species",
        "description" => page_description(tx, t),
        "taxon"      => t,
        "taxon_key"  => t["taxon_key"],
        "h1"         => tx.name_of(t),
        "italic"     => tx.italic?(t),
        "is_local"   => tx.local?(t),
        "local_ds"   => tx.local?(t) ? (tx.ds_by_key.dig(t.dig("local", "dataset_key"), "dataset_name_short") || t.dig("local", "dataset_key")) : nil,
        "local_url"  => tx.local?(t) ? (site.data.dig("catalog", "index", t.dig("local", "dataset_key"), "url") || "/datasets/#{t.dig('local', 'dataset_key')}/") : nil,
        "rank"       => t["rank"],
        "rank_abbr"  => tx.rank_abbr(t["rank"]),
        "status"     => t["taxonomic_status"],
        "status_odd" => Fmt.present(t["taxonomic_status"]) && t["taxonomic_status"] != "accepted",
        "checked"    => t["status_checked"],
        "lineage"    => ancestors.map do |a|
          { "name" => tx.name_of(a), "rank" => a["rank"], "abbr" => tx.rank_abbr(a["rank"]),
            "url" => tx.page_url(a), "italic" => tx.italic?(a) }
        end,
        "ids"        => tx.id_rows(t),
        # faces (WS-F3): all nil where the sidecar has no entry for this taxon, and the includes
        # draw nothing at all then — the page is what it was
        "face"       => tx.face(t),
        "glance"     => tx.glance(t),
        "sentence"   => tx.sentence(t),
        "credits"    => tx.credits(t),
        "has_size"   => tx.has_size_section?(t),
        "size_data"  => JSON.generate(tx.size_json(t)).gsub("</", "<\\/"),
        "stats"      => tx.stat_row(t),
        "ds_rows"    => tx.dataset_rows(t),
        "strip"      => JSON.generate(tx.strip_json(t)),
        "children"   => kids.map do |c|
          { "name" => tx.name_of(c), "common" => Fmt.present(c["common_name"]), "rank" => c["rank"],
            "abbr" => tx.rank_abbr(c["rank"]), "url" => tx.page_url(c), "italic" => tx.italic?(c),
            "obs" => Fmt.num(c.dig("rollup", "n_obs")), "n_obs" => c.dig("rollup", "n_obs").to_i,
            "sp" => c.dig("rollup", "n_species").to_i }
        end,
        "groups"     => t["groups"] || [],
        "ways"       => tx.ways(t),
        "jsonld"     => JSON.pretty_generate(tx.jsonld(t))
      )
      [page, json_page(site, "/species/", "#{t['slug']}.json", JSON.pretty_generate(t))]
    end

    # one sentence a search engine can show, every number from the record
    def page_description(tx, t)
      roll = t["rollup"] || {}
      bits = ["#{tx.name_of(t)}#{Fmt.present(t['common_name']) ? " (#{t['common_name']})" : ''}"]
      bits << (t["rank"] ? t["rank"].downcase : "a dataset-local class")
      if roll["n_obs"].to_i.positive?
        bits << "#{Fmt.num(roll['n_obs'])} observations in #{roll['n_datasets']} CalCOFI dataset#{'s' if roll['n_datasets'].to_i != 1}"
        bits << "#{roll['year_min']}–#{roll['year_max']}" if roll["year_min"] && roll["year_max"]
      end
      "#{bits.join(' · ')} — CalCOFI integrated database #{tx.release['version']}."
    end

    def sitemap(tx)
      lastmod = tx.release["release_date"] || Time.now.utc.strftime("%Y-%m-%d")
      urls = [tx.abs("/species/")] + tx.taxa.map { |t| tx.abs(tx.page_url(t)) }
      body = urls.map do |u|
        "  <url><loc>#{u}</loc><lastmod>#{lastmod}</lastmod><changefreq>monthly</changefreq></url>"
      end.join("\n")
      %(<?xml version="1.0" encoding="UTF-8"?>\n) +
        %(<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">\n#{body}\n</urlset>\n)
    end

    def json_page(site, dir, name, body)
      page = Jekyll::PageWithoutAFile.new(site, site.source, dir.sub(%r{\A/}, "").sub(%r{/\z}, ""), name)
      page.content = "{% raw %}#{body}{% endraw %}"
      page.data["layout"] = nil
      page.data["sitemap"] = false
      page
    end
  end
end
