# frozen_string_literal: true

require "cgi"
require "json"

# The Species and Measurements finders (/species/, /measurements/; Betty 2026-11-15): the same shape as
# Browse datasets — a search band, a list, a preview beside it — and one download flow for all three.
#
# Writes two JSON files the pages read (assets/finder.js):
#   /species/finder.json       groups (the 22 classes), rows (every species), silhouettes, datasets
#   /measurements/finder.json  rows (every measurement), categories, datasets
#
# Every value is read from the release record (taxa.json, taxa_media.json, measurements.json,
# measurements_media.json), from disk: species.rb and measurements.rb replace their site.data keys
# with their own summaries, in an order that differs between platforms. The datasets are the
# CATALOG's (Catalog#datasets), so a `visibility: internal` record names no row here either.
#
# The rules are the plain functions of CalCOFI::Finder (tested in _test/finder_test.rb); the
# generator at the foot only reads the files and writes the two pages.
require_relative "datasets"

module CalCOFI
  module Finder
    module_function

    # The group names ("Bony fishes", "Seabirds" …) are the one thing typed here: the record names
    # classes only scientifically. This is an EDITORIAL list pending a decision by Ben and Erin on
    # whether the names move into the taxa record (a common name on each class); until then it is
    # kept honest by `stale_group_names` (a key that is not a class in the record is reported at
    # build time, and _test/finder_test.rb pins the rule). A class missing from it shows its
    # scientific name.
    GROUP_NAMES = {
      "Teleostei" => "Bony fishes", "Malacostraca" => "Crabs, shrimp & krill", "Cephalopoda" => "Squid & octopus",
      "Bacillariophyceae" => "Diatoms", "Aves" => "Seabirds", "Dinophyceae" => "Dinoflagellates",
      "Copepoda" => "Copepods", "Cyanophyceae" => "Cyanobacteria", "Coccolithophyceae" => "Coccolithophores",
      "Thaliacea" => "Salps", "Gastropoda" => "Snails & sea butterflies", "Appendicularia" => "Larvaceans",
      "Ostracoda" => "Seed shrimp", "Polychaeta" => "Bristle worms", "Mammalia" => "Marine mammals",
      "Pyramimonadophyceae" => "Green algae", "Hydrozoa" => "Hydrozoans", "Dictyochophyceae" => "Silicoflagellates",
      "Haptophyta incertae sedis" => "Other haptophytes", "Insecta" => "Insects",
      "Cryptophyta incertae sedis" => "Cryptophytes", "Xanthophyceae" => "Yellow-green algae"
    }.freeze
    # the group of a species whose lineage names no class (three sea turtles in v2026.11.14)
    OTHER = "Other"
    MEDIA_BASE = "https://storage.googleapis.com/calcofi-files-public/"

    def group_name(cls) = GROUP_NAMES[cls] || cls

    # the GROUP_NAMES keys that are NOT a class in the record (rank Class): a name typed for a class
    # the release no longer has. Empty is the healthy state.
    def stale_group_names(taxa, names = GROUP_NAMES)
      classes = (taxa || []).select { |t| t["rank"] == "Class" }.map { |t| t["scientific_name"] }
      names.keys - classes
    end

    # core first, newest last — the same order as the Browse datasets list: by the release the
    # dataset joined (`since`: {dataset_key => since_version}), then the larger first
    def core_sort(list, n_key, since)
      list.each_with_index.sort_by { |x, i| [since[x["dataset_key"]].to_s, -x[n_key].to_i, i] }.map(&:first)
    end

    # {"1987" => 1, "1988" => 0} → [1987]: the years with a count, ascending
    def years_of(h)
      (h || {}).select { |_, v| v.to_i.positive? }.keys.map(&:to_i).sort
    end

    # each dataset a finder row names: its short name and its page (the preview links the page, where a
    # CSV button beside every species or measurement downloads just that one)
    def files_for(keys, datasets)
      keys.uniq.to_h do |k|
        d = datasets[k] || {}
        [k, { "name" => d["dataset_name_short"] || d["dataset_name"] || k, "page" => "/datasets/#{k}/" }]
      end
    end

    # the Explorer opens prefilled only for an authority key (species.rb `ways`, the same rule): a
    # dataset-local key is not one the Explorer keys by
    def taxon_param(key)
      key.to_s.start_with?("worms:", "itis:") ? "?taxon=#{key}" : nil
    end

    # /species/finder.json, from taxa.json (`rec`), taxa_media.json (`media`) and the catalog's
    # datasets ({dataset_key => record}, the visible ones).
    #   rows    the species the record counts: rank Species AND observed as the species itself
    #           (direct.n_obs > 0), most observed first. A row's datasets are the catalog's only: one
    #           it does not show (visibility: internal) is not named, and a species seen ONLY there
    #           has no row.
    #   groups  the classes with observations, most observed first, each with its typed name, its
    #           counts and its three commonest species; then ONE group "Other" for the species whose
    #           lineage names no class, so every row is in a group that is drawn (it was in none).
    #   sils    the silhouettes, each outline once: a row's own, else its nearest ancestor's.
    def species(rec, media, datasets)
      return nil unless rec && rec["taxa"]
      media ||= {}
      mt = media["taxa"] || {}
      base = media["base"] || MEDIA_BASE
      tx = rec["taxa"]
      by = tx.to_h { |t| [t["taxon_key"], t] }
      since = datasets.transform_values { |d| d["since_version"] }
      sils = []
      sidx = {}
      sil_of = lambda do |key|
        t = by[key]
        s = nil
        seen = {}
        while t && s.nil? && !seen[t["taxon_key"]]
          seen[t["taxon_key"]] = true
          s = mt.dig(t["taxon_key"], "silhouette")
          t = s ? t : by[t["parent_taxon_key"]]
        end
        next nil unless s && s["svg_inner"]
        sidx[s["svg_inner"]] ||= (sils << [s["viewBox"], s["svg_inner"]]).size - 1
      end
      rows = tx.select { |t| t["rank"] == "Species" && t.dig("direct", "n_obs").to_i.positive? }.filter_map do |t|
        seen_in = (t["datasets"] || []).select { |d| datasets.key?(d["dataset_key"]) }
        next if seen_in.empty? && !(t["datasets"] || []).empty?
        f = mt[t["taxon_key"]] || {}
        ph = f["photo"]
        photo = ph && (Fmt.present(ph["cached"]) ? "#{base}#{ph['cached']}" : Fmt.present(ph["url"]))
        txt = f["text"] || {}
        cls = t.dig("lineage", "class") || OTHER
        dsl = core_sort(seen_in, "n_obs", since).map do |d|
          [d["dataset_key"], d["year_min"], d["year_max"], d["n_obs"]]
        end
        {
          "k" => t["taxon_key"], "url" => "/species/#{t['slug']}/", "sci" => t["scientific_name"],
          "com" => Fmt.present(t["common_name"].to_s.strip), "cls" => cls, "grp" => group_name(cls),
          "n" => t.dig("rollup", "n_obs"), "y0" => t.dig("rollup", "year_min"), "y1" => t.dig("rollup", "year_max"),
          "years" => seen_in.flat_map { |d| years_of(d["years"]) }.uniq.sort,
          "ds" => dsl, "stages" => t.dig("direct", "life_stages") || [],
          "photo" => photo, "photo_lic" => ph && Fmt.present(ph["license"]),
          "sil" => sil_of.(t["taxon_key"]),
          "text" => Fmt.present(txt["extract"].to_s[0, 420]), "wiki" => Fmt.present(txt["url"]),
          "size" => f.dig("size", "m"),
          "map" => taxon_param(t["taxon_key"])
        }
      end
      rows.sort_by!.with_index { |r, i| [-r["n"].to_i, i] }
      groups = tx.select { |t| t["rank"] == "Class" && t.dig("rollup", "n_obs").to_i.positive? }
                 .sort_by { |t| -t.dig("rollup", "n_obs").to_i }.map do |t|
        c = t["scientific_name"]
        top = rows.select { |r| r["cls"] == c }.first(3).map { |r| r["com"] || r["sci"] }
        first = rows.find { |r| r["cls"] == c }
        { "cls" => c, "grp" => group_name(c), "n_sp" => t.dig("rollup", "n_species").to_i,
          "n_taxa" => t.dig("rollup", "n_taxa").to_i, "n" => t.dig("rollup", "n_obs"),
          "top" => top, "sil" => sil_of.(t["taxon_key"]) || (first && first["sil"]) }
      end
      named = groups.map { |g| g["cls"] }
      rest = rows.reject { |r| named.include?(r["cls"]) }
      unless rest.empty?
        rest.each { |r| r["cls"] = OTHER; r["grp"] = OTHER }
        groups << { "cls" => OTHER, "grp" => OTHER, "n_sp" => rest.size, "n_taxa" => rest.size,
                    "n" => rest.sum { |r| r["n"].to_i }, "top" => rest.first(3).map { |r| r["com"] || r["sci"] },
                    "sil" => rest.first["sil"] }
      end
      { "release" => rec.dig("release", "version"), "counts" => rec["counts"], "groups" => groups, "rows" => rows,
        "sils" => sils, "files" => files_for(rows.flat_map { |r| r["ds"].map(&:first) }, datasets) }
    end

    # /measurements/finder.json, from measurements.json (`rec`), measurements_media.json's `sources`
    # (`med`), the release's coverage.json (`coverage`) and the catalog's datasets.
    #   rows   every measurement, most values first; its series are the catalog's datasets only (one in
    #          a dataset the catalog does not show is not named, and a measurement carried ONLY there
    #          has no row). Units through the site's ONE display map (Fmt.units).
    #   cats   the record's categories, in category.order
    #   map    "?var=<key>" only for a key the Explorer's picker carries: coverage.json's env
    #          variables (measurements.rb `explorer_keys`, the same rule)
    def measurements(rec, med, coverage, datasets)
      return nil unless rec && rec["measurements"]
      med ||= {}
      since = datasets.transform_values { |d| d["since_version"] }
      ekeys = (coverage.is_a?(Hash) ? coverage["variables"] || [] : []).select { |v| v["realm"] == "env" }
                .filter_map { |v| Fmt.present(v["variable"]) || Fmt.present(v["measurement_type"]) }
      cats = []
      rows = rec["measurements"].filter_map do |m|
        tt = m["totals"] || {}
        nerc = med.dig(m["key"], "nerc") || {}
        shown = (m["series"] || []).select { |s| datasets.key?(s["dataset_key"]) }
        next if shown.empty? && !(m["series"] || []).empty?
        se = core_sort(shown, "n_values", since)
        c = m["category"] || {}
        cats << { "name" => c["name"], "icon" => c["icon"], "order" => c["order"] } unless cats.any? { |x| x["name"] == c["name"] }
        {
          "k" => m["key"], "url" => "/measurements/#{m['slug']}/", "lab" => m["short_label"] || m["label"],
          "full" => m["label"], "desc" => Fmt.present(m["description"]), "units" => Fmt.units(m["units"]),
          "cat" => c["name"], "unified" => !!m["is_unified"],
          "n" => tt["n_values"], "y0" => tt["year_min"], "y1" => tt["year_max"],
          "dmin" => tt["depth_min_m"], "dmax" => tt["depth_max_m"],
          "years" => se.flat_map { |s| years_of(s["years"]) }.uniq.sort,
          "ds" => se.map { |s| [s["dataset_key"], s["year_min"], s["year_max"], s["n_values"]] },
          "defn" => Fmt.present(nerc["definition"].to_s[0, 380]), "nerc" => Fmt.present(nerc["pref"]),
          "map" => (ekeys.include?(m["key"]) ? "?var=#{CGI.escape(m['key'])}" : nil)
        }
      end
      rows.sort_by!.with_index { |r, i| [-r["n"].to_i, i] }
      { "release" => rec.dig("release", "version"), "counts" => rec["counts"], "rows" => rows,
        "cats" => cats.sort_by { |c| c["order"].to_i }, "files" => files_for(rows.flat_map { |r| r["ds"].map(&:first) }, datasets) }
    end
  end

  class FinderData < Jekyll::Generator
    safe false
    priority :low # after DatasetCatalog (:high), which builds the Catalog whose datasets this names

    GROUP_NAMES = Finder::GROUP_NAMES

    def generate(site)
      @site = site
      cat = BrowseData.catalog
      return unless cat
      datasets = cat.datasets.to_h { |d| [d["dataset_key"], d] }
      taxa = read("taxa")
      sp = Finder.species(taxa, read("taxa_media"), datasets)
      ms = Finder.measurements(read("measurements"), (read("measurements_media") || {})["sources"],
                               read("release_coverage"), datasets)
      if sp
        stale = Finder.stale_group_names(taxa["taxa"])
        unless stale.empty?
          Jekyll.logger.warn "finder:", "GROUP_NAMES names #{stale.size} class(es) the record does not have: #{stale.join(', ')}"
        end
        # the silhouettes are most of the bytes (potrace paths), so they load second and fill in
        write(site, "species", JSON.generate(sp.except("sils")))
        write(site, "species", JSON.generate(sp["sils"]), "finder-sils.json")
      end
      write(site, "measurements", JSON.generate(ms)) if ms
      site.data["finder"] = { "species_groups" => sp && sp["groups"].size, "measurement_cats" => ms && ms["cats"].size,
                              "measurements" => ms && ms["rows"].size }
    end

    private

    def read(name)
      f = File.join(@site.source, "_data", "#{name}.json")
      File.exist?(f) ? JSON.parse(File.read(f)) : nil
    rescue JSON::ParserError
      nil
    end

    def write(site, dir, body, name = "finder.json")
      page = Jekyll::PageWithoutAFile.new(site, site.source, dir, name)
      page.content = "{% raw %}#{body}{% endraw %}"
      page.data["layout"] = nil
      page.data["sitemap"] = false
      site.pages << page
    end
  end
end
