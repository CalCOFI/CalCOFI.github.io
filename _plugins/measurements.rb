# _plugins/measurements.rb — the measurements catalog, generated from the release's measurements
# record (plan 2026-09-10 § D2, D4, D6; brief WS-M3).
#
# `_data/measurements.json` (calcofi4db::build_measurements_catalog(), schema 1.0; fetched by
# scripts/fetch_release.sh) is the ONLY source of a measurement fact on this site, exactly as
# `_data/taxa.json` is for a taxon and `_data/datasets.json` for a dataset. This generator turns
# it into:
#
#   /measurements/              the index: the counts, search, the timeline of every measurement by
#                               dataset and the category x dataset matrix — all drawn by
#                               assets/measurements.js (WS-M4) from ONE inline JSON
#   /measurements/{key}/        one page per measurement key (79 today), with schema.org/DefinedTerm
#                               JSON-LD and a PropertyValue per series
#   /measurements/{key}.json    that measurement's entry of the record, verbatim
#   /measurements/sitemap.xml   the pages, lastmod = release_date
#   /measurements/search.json   the rows the front door's one search reads (assets/door-search.js)
#
# and hands the rest of the site `site.data.measurements` (the counts, the datasets, the inline
# JSON, the key => slug maps a dataset page links its variables with) so the layouts stay Liquid.
#
# THE KEY. A page is one measurement KEY — the registry's `variable` where the crosswalk unifies
# two series (bottle `temperature` + CTD `temperature_ave`), else the canonical `measurement_type`.
# The record has already made that decision and carries `key` and `slug`; nothing is re-derived
# here. A SERIES is one `measurement_type` x dataset under that key, with the dataset's own source
# column and flag column — "what the source called it", the `dataset_taxon` of this catalog.
#
# Rules that hold here because they hold in the record:
#   · a number is read, never typed; a field the record cannot supply is not rendered
#   · without `_data/measurements.json` NOTHING is generated — one NOTE, no measurement pages, and
#     the front door's measurement doors fall back to the Explorer (the D-2 rule)
#   · dataset colour is never the only cue: a dot always has its dataset's name beside it
#   · a value outside a DECLARED bound is a bug being removed at the ingest, not an open question
#     (Ben, 2026-09-10, D9 revised): the observed range is stated within bounds, and one line says
#     how many values fell outside it and that they leave the database at the next release
#
# This runs at :normal — after datasets.rb (:high), whose `site.data.catalog` it reads for the
# dataset pages' URLs and whose `numbers` it corrects from the record where the two can disagree.

require "json"
require "cgi"

module CalCOFI
  # ── the measurements record, wrapped ────────────────────────────────────────
  class MeasurementsRecord
    attr_reader :rec

    def initialize(site, rec)
      @site = site
      @rec  = rec
      @base = (site.config["url"].to_s + site.config["baseurl"].to_s).sub(%r{/\z}, "")
      @base = "https://calcofi.io" if @base.empty?
    end

    def release      = rec["release"] || {}
    # the record's counts plus three the head's copy needs, so "79 measurements" reads as the TOTAL
    # and the NERC-keyed count as a part of it (Ben, 2026-09-10): how many keys unify two datasets'
    # series (the same NERC P01 concept for the same kind of sample), how many carry a concept at
    # all, and how many carry none and keep their own names
    def counts
      @counts ||= (rec["counts"] || {}).merge(
        "n_unified" => measurements.count { |m| m["is_unified"] },
        "n_p01"     => measurements.count { |m| Fmt.present(m["nerc_p01"]) },
        "n_no_p01"  => measurements.count { |m| !Fmt.present(m["nerc_p01"]) })
    end
    # A measurement the registry left without a category takes its first series' dataset's. In
    # v2026.09.10 the 17 calcofi_mets keys carried `category: null` (their measurement_type.csv rows
    # were empty until 2026-09-11), and every figure that groups by category — the index matrix,
    # the chips, the timeline headings — silently dropped them. The registry fix reaches the record
    # at the next release; this keeps a gap in the registry from ever removing rows from the page.
    def measurements
      @measurements ||= (rec["measurements"] || []).map do |m|
        next m if m.dig("category", "name")
        d = ds_by_key[m.dig("series", 0, "dataset_key")]
        d && d.dig("category", "name") ? m.merge("category" => d["category"]) : m
      end
    end
    # the record entry exactly as released, for /measurements/{key}.json ("verbatim"), which must not
    # carry the category the page borrowed above
    def raw(key)     = (@raw ||= (rec["measurements"] || []).to_h { |x| [x["key"], x] })[key]
    def datasets     = @datasets ||= rec["datasets"] || []
    def abs(path)    = "#{@base}#{path}"

    def by_key     = @by_key ||= measurements.to_h { |m| [m["key"], m] }
    def ds_by_key  = @ds_by_key ||= datasets.to_h { |d| [d["dataset_key"], d] }
    def page_url(m) = "/measurements/#{m['slug']}/"

    def release_year = release["release_date"].to_s[0, 4].to_i

    # the dataset's display name and page, from the dataset catalog where it has one
    def ds_name(k) = ds_by_key.dig(k, "dataset_name_short") ||
                     @site.data.dig("catalog", "index", k, "name") || k
    def ds_url(k)  = @site.data.dig("catalog", "index", k, "url") || "/datasets/#{k}/"
    def ds_color(k) = ds_by_key.dig(k, "color")

    # ── names, units and ids ─────────────────────────────────────────────────
    # The label is the record's: `variable.csv`'s authored one on the five unified keys, else the
    # canonical series' registry DESCRIPTION with a `no_label` flag. Two of those descriptions
    # carry a "; …" tail that is a sentence, not a name ("Reported Specific Volume Anomaly
    # (pre-QC); WARNING: different parameter/scale than salinity PSS-78"), so the head becomes the
    # h1 and the WHOLE description is written under it — nothing is dropped and nothing is coined.
    def heading(m)   = m["label"].to_s.split("; ", 2).first.to_s.strip
    def subtitle(m)
      d = Fmt.present(m["description"])
      d && d != heading(m) ? d : nil
    end

    def no_label?(m) = (m["flags"] || []).include?("no_label")

    # http://vocab.nerc.ac.uk/collection/P01/current/TEMPPR01/ → TEMPPR01
    def nerc_id(url) = url.to_s.split("/").reject(&:empty?).last

    def series_types(m) = (m["series"] || []).map { |s| s["measurement_type"] }

    # ── the quiet pills a series can carry ───────────────────────────────────
    # A label map with a plain-text fallback, so a flag the next release adds renders as itself
    # rather than disappearing. `sentinel_suspected` is handled separately: with a declared bound
    # it is a counted bug (n out of bounds), without one it is the heuristic.
    FLAG_LABELS = {
      "sensor_mean"      => ["sensor mean",
                             "the headline series is the file's own average of the paired sensors; the per-sensor series with their own flags ride the full-resolution table"],
      "replicate"        => ["replicate",
                             "one replicate of the source's repeated analyses, not their mean — the two are kept apart on purpose"],
      "reported_pre_qc"  => ["reported · pre-QC",
                             "the source's own reported value, before its QC; the QC'd counterpart is its own measurement"],
      "no_bound"         => ["no bound declared",
                             "the registry declares no valid_min / valid_max for this series, so nothing is enforced at the ingest"],
      "no_flag_at_grain" => ["no flag at this grain",
                             "this series carries no measurement_qual at the release grain"],
      "no_p01"           => ["no P01 concept",
                             "no NERC P01 concept says exactly this quantity — an empty id means that, never \"not looked at\""]
    }.freeze

    def flag_chip(f)
      label, title = FLAG_LABELS[f] || [f.to_s.tr("_", " "), "a flag this release introduced: #{f}"]
      { "flag" => f, "label" => label, "title" => title }
    end

    # the chips one series wears, in the record's own order, with the two readings of
    # `sentinel_suspected` (plan D9 as Ben revised it on 2026-09-10)
    def series_chips(m, s)
      bounded = !(m.dig("bounds", "valid_min").nil? && m.dig("bounds", "valid_max").nil?)
      oob = s["out_of_bounds"] || {}
      (s["flags"] || []).filter_map do |f|
        if f == "sentinel_suspected"
          if bounded && oob["n"].to_i.positive?
            { "flag" => f, "label" => "#{Fmt.num(oob['n'])} out of bounds",
              "title" => "#{Fmt.num(oob['n'])} values fall outside the declared bound; they are excluded from the range below and leave the database at the next release" }
          elsif bounded
            nil                        # a bound is declared and nothing is outside it: no chip
          else
            { "flag" => f, "label" => "range suspect · no bound",
              "title" => "the maximum is two orders of magnitude above the 95th percentile and no bound is declared for this series" }
          end
        else
          flag_chip(f)
        end
      end
    end

    # ── the page's own facts ─────────────────────────────────────────────────
    def span(a, b) = (a && b) ? (a == b ? a.to_s : "#{a}–#{b}") : nil

    def depth_txt(a, b)
      return nil if a.nil? && b.nil?
      return "surface" if b.to_f.zero? && a.to_f.zero?
      "#{Fmt.num(a.to_f.round)}–#{Fmt.num(b.to_f.round)} m"
    end

    # every month the record counts a value in, summed over the series — "every month" when all
    # twelve carry one, else the months that do (never a season name the record cannot support)
    MONTHS = %w[Jan Feb Mar Apr May Jun Jul Aug Sep Oct Nov Dec].freeze

    def months_txt(m)
      tot = Array.new(12, 0)
      (m["series"] || []).each do |s|
        (s["months"] || []).each_with_index { |n, i| tot[i] += n.to_i if i < 12 }
      end
      seen = tot.each_with_index.select { |n, _| n.positive? }.map { |_, i| i }
      return nil if seen.empty?
      seen.size == 12 ? "every month" : seen.map { |i| MONTHS[i] }.join(" · ")
    end

    # ── flagged: what the provider marks questionable or bad ─────────────────
    # The Explorer's definition (explore/sql/picker.sql `n_flagged`): a value is flagged when
    # `qual_ok` is FALSE, i.e. its provider's own code says questionable or bad. A code that says
    # the value is fine (the bottle's 6, "Data OK but taken from CTD") is NOT flagged, so the count
    # is `n_values - qual_ok_n`, never "rows carrying any code". A series with no flag column at
    # this grain is counted separately, because a zero there means "not flagged", not "all good".
    #
    # Since schema 1.1 the RECORD carries `n_flagged` per series and per key, measured at release
    # by the same rule (plan 2026-09-11 § handoff delta 4). The record is then the source and the
    # arithmetic below the fallback — and the two must never disagree, so a difference is collected
    # here and warned about ONCE at the end of the build rather than silently resolved.
    def flag_mismatches = @flag_mismatches ||= []

    def reconcile(own, said, where)
      return own if said.nil?
      said = said.to_i
      flag_mismatches << "#{where}: record #{said}, n_values − qual_ok_n #{own}" if !own.nil? && own != said
      said
    end

    def flagged(s)
      own = s["qual_ok_n"].nil? ? nil : [s["n_values"].to_i - s["qual_ok_n"].to_i, 0].max
      reconcile(own, s["n_flagged"], "series #{s['dataset_key']} #{s['measurement_type']}").to_i
    end

    def flagged_total(m)
      own = (m["series"] || []).sum { |s| flagged(s) }
      reconcile(own, m["n_flagged"], "key #{m['key']}").to_i
    end
    # a CTD average ("sensor_mean") has no flag of its own, but since v2026.09.11 it is REBUILT from its two
    # sensors with any sensor its provider flags 8 or 9 left out (the flag rule, calcofi4db::
    # combine_sensor_pair()), so it is screened even though no code sits on its rows
    def sensor_mean?(s) = (s["flags"] || []).include?("sensor_mean")
    def unflaggable(m) = (m["series"] || []).select { |s| !Fmt.present(s["qual_column"]) && !sensor_mean?(s) }
    def screened_means(m) = (m["series"] || []).select { |s| !Fmt.present(s["qual_column"]) && sensor_mean?(s) }

    # the heads-up under the stats band: how many values the provider flags, that the Explorer,
    # the climatology and its anomalies leave them out, and which series have no flag to consult
    def flag_note(m)
      t = m["totals"] || {}
      n = flagged_total(m)
      bare = unflaggable(m).map { |s| "the <code>#{CGI.escapeHTML(s['measurement_type'])}</code> series from #{CGI.escapeHTML(ds_name(s['dataset_key']).to_s)}" }
      means = screened_means(m).map { |s| "the <code>#{CGI.escapeHTML(s['measurement_type'])}</code> series from #{CGI.escapeHTML(ds_name(s['dataset_key']).to_s)}" }
      return nil if n.zero? && bare.empty? && means.empty?
      parts = []
      if n.positive?
        pct = 100.0 * n / [t["n_values"].to_i, 1].max
        pct_s = pct < 0.1 ? "under 0.1 %" : "#{pct < 10 ? format('%.1f', pct) : pct.round} %"
        parts << "<b>#{Fmt.num(n)}</b> of these #{Fmt.num(t['n_values'])} values (#{pct_s}) are flagged by " \
                 "their provider as questionable or bad. The Explorer, the climatology and its anomalies leave " \
                 "them out; do the same when you read the data yourself " \
                 "(<code>cc_qual_ok_sql()</code> in calcofi4r, <code>qual_ok_sql()</code> in calcofi4py)."
      end
      unless bare.empty?
        lead = bare.join(" and ")
        parts << "#{lead[0].upcase}#{lead[1..]} #{bare.size == 1 ? 'carries' : 'carry'} no flag at this grain, " \
                 "so #{bare.size == 1 ? 'its' : 'their'} values cannot be screened this way."
      end
      unless means.empty?
        lead = means.join(" and ")
        parts << "#{lead[0].upcase}#{lead[1..]} #{means.size == 1 ? 'is an average' : 'are averages'} of two sensors, " \
                 "rebuilt with any sensor its provider flags questionable or bad left out, so " \
                 "#{means.size == 1 ? 'it carries' : 'they carry'} no flag of #{means.size == 1 ? 'its' : 'their'} own."
      end
      parts.join(" ")
    end

    def stat_rows(m)
      t = m["totals"] || {}
      rows = []
      rows << { "dd" => Fmt.num(t["n_values"]), "dt" => "values",
                "title" => "rows of obs_env — one measurement × one sample" } if t["n_values"]
      if (nf = flagged_total(m)).positive?
        rows << { "dd" => Fmt.num(nf), "dt" => "flagged",
                  "title" => "values their provider flags questionable or bad (qual_ok is FALSE); " \
                             "the Explorer, the climatology and its anomalies leave them out" }
      end
      if t["n_roots"]
        rows << { "dd" => Fmt.num(t["n_roots"]), "dt" => "sampling events",
                  "title" => "the cast, tow or underway record each sample belongs to (sample_root) — " \
                             "#{Fmt.num(t['n_samples'])} samples hang from them; the record does not say " \
                             "which KIND of root, so this page does not say \"casts\"" }
      end
      if (y = span(t["year_min"], t["year_max"]))
        rows << { "dd" => y, "dt" => "years" }
      end
      if t["n_datasets"]
        rows << { "dd" => Fmt.num(t["n_datasets"]),
                  "dt" => t["n_datasets"].to_i == 1 ? "dataset" : "datasets" }
      end
      if (d = depth_txt(t["depth_min_m"], t["depth_max_m"]))
        rows << { "dd" => d, "dt" => "depth" }
      end
      if (mo = months_txt(m))
        rows << { "dd" => mo, "dt" => "seasons", "small" => true }
      end
      rows
    end

    # one row per series: the dataset, what it counted, and what the source calls it
    def dataset_rows(m)
      (m["series"] || []).map do |s|
        k = s["dataset_key"]
        nf = flagged(s)
        chips = series_chips(m, s)
        if nf.positive? && s["n_values"].to_i.positive?
          pct = (100.0 * nf / s["n_values"].to_i)
          # under a tenth of a percent the percentage reads "0.0 %", which says less than the count
          label = pct < 0.1 ? "#{Fmt.num(nf)} flagged" :
                  "#{Fmt.num(nf)} flagged · #{pct < 10 ? format('%.1f', pct) : pct.round} %"
          chips = chips + [{ "flag" => "flagged", "label" => label,
                             "title" => "#{Fmt.num(nf)} values their provider flags questionable or bad; qual_ok " \
                                        "keeps #{Fmt.num(s['qual_ok_n'])} of #{Fmt.num(s['n_values'])}, and the Explorer, " \
                                        "the climatology and its anomalies use only those" }]
        end
        { "key"    => k,
          "name"   => ds_name(k),
          "url"    => ds_url(k),
          "color"  => ds_color(k),
          "type"   => s["measurement_type"],
          "source_column" => Fmt.present(s["source_column"]),
          "qual_column"   => Fmt.present(s["qual_column"]),
          "units"  => Fmt.units(s["units"]),
          "units_raw" => Fmt.present(s["units"]),
          "desc"   => Fmt.present(s["description"]),
          "meta"   => [Fmt.num(s["n_values"]) && "#{Fmt.num(s['n_values'])} values",
                       s["n_roots"] && "#{Fmt.num(s['n_roots'])} sampling events",
                       span(s["year_min"], s["year_max"]),
                       depth_txt(s["depth_min_m"], s["depth_max_m"]),
                       s["n_cells"] && "#{Fmt.num(s['n_cells'])} grid cells",
                       s["n_cruises"] && "#{Fmt.num(s['n_cruises'])} cruises"].compact.join(" · "),
          "chips"  => chips }
      end
    end

    # ── Range & quality ──────────────────────────────────────────────────────
    # bounds as the registry declares them · the observed range WITHIN those bounds · what fell
    # outside (a bug leaving the database, never a suspicion) · the flag counts by code · the
    # baseline. The flag codes are each dataset's own vocabulary, uninterpreted: the code is
    # printed as the record has it, with its count.
    # a MEASURED value, not a count: it can be negative (Fmt.num's reverse-and-scan drops a minus
    # sign, which turned the CTD's −3.07e17 spar into a positive 307 quadrillion on 2026-09-10) and
    # it can be absurd, because an out-of-bounds value is exactly what this block reports.
    def numfmt(v)
      return nil if v.nil?
      f = v.to_f
      return format("%.4g", f) if f.abs >= 1_000_000        # scientific: -3.07e+17
      if f.abs >= 10_000
        return "#{f.negative? ? '−' : ''}#{Fmt.num(f.abs.round)}"
      end
      s = format("%.4g", f)
      s.include?("e") ? format("%g", f) : s
    end

    # "−2 … 40" · "at least 0" · "at most 700" — a half-open bound is stated as the half it is
    def bounds_txt(lo, hi)
      return nil if lo.nil? && hi.nil?
      return "#{numfmt(lo)} … #{numfmt(hi)}" if lo && hi
      lo ? "at least #{numfmt(lo)}" : "at most #{numfmt(hi)}"
    end

    def bounds_row(m)
      b = m["bounds"] || {}
      lo, hi = b["valid_min"], b["valid_max"]
      units = Fmt.units(m["units"])
      by = (b["declared_by"] || []).join(" · ")
      if lo.nil? && hi.nil?
        { "dt" => "bounds",
          "dd" => "No physical bound is declared for #{(m['series'] || []).size == 1 ? 'this series' : 'these series'} " \
                  "in <span class=\"mono\">metadata/measurement_type.csv</span>, so nothing is enforced at the ingest and " \
                  "the range below is simply what the release carries." }
      else
        { "dt" => "bounds",
          "dd" => "The registry declares <code>#{bounds_txt(lo, hi)}#{units ? " #{CGI.escapeHTML(units)}" : ''}</code>" \
                  "#{by.empty? ? '' : " for <code>#{CGI.escapeHTML(by)}</code>"}; a value outside it is dropped at the ingest " \
                  "(<span class=\"mono\">drop_out_of_bounds()</span>)." }
      end
    end

    def observed_rows(m)
      (m["series"] || []).filter_map do |s|
        o = s["observed"] || {}
        next if o["min"].nil? && o["max"].nil?
        "#{CGI.escapeHTML(ds_name(s['dataset_key']))} <code>#{CGI.escapeHTML(s['measurement_type'].to_s)}</code> " \
          "#{numfmt(o['min'])} · median #{numfmt(o['p50'])} · #{numfmt(o['max'])}" \
          "#{Fmt.units(s["units"]) ? " #{CGI.escapeHTML(Fmt.units(s["units"]))}" : ""} " \
          "(5th–95th percentile #{numfmt(o['p05'])}–#{numfmt(o['p95'])})"
      end
    end

    # Ben's ruling of 2026-09-10: a value outside a DECLARED bound is a certain bug, removed at the
    # ingest for the next release — impossible and excluded, never "suspect".
    def out_of_bounds_rows(m)
      b = m["bounds"] || {}
      bounded = !(b["valid_min"].nil? && b["valid_max"].nil?)
      return [] unless bounded
      units = Fmt.units(m["units"])
      (m["series"] || []).filter_map do |s|
        o = s["out_of_bounds"] || {}
        n = o["n"].to_i
        next if n.zero?
        vals = [numfmt(o["min"]), numfmt(o["max"])].compact.uniq
        "#{Fmt.num(n)} value#{'s' unless n == 1} outside the declared " \
          "<code>#{bounds_txt(b['valid_min'], b['valid_max'])}#{units ? " #{CGI.escapeHTML(units)}" : ''}</code> " \
          "(#{vals.join(' and ')}) in #{CGI.escapeHTML(ds_name(s['dataset_key']))} <code>#{CGI.escapeHTML(s['measurement_type'].to_s)}</code> " \
          "are excluded from this range and from the Explorer, and leave the database at the next release."
      end
    end

    def qual_rows(m)
      (m["series"] || []).filter_map do |s|
        q = s["qual"] || {}
        coded = q.reject { |k, _| k == "none" }.sort_by { |k, _| k.to_s }
        name = "#{CGI.escapeHTML(ds_name(s['dataset_key']))} <code>#{CGI.escapeHTML(s['measurement_type'].to_s)}</code>"
        if coded.empty?
          col = Fmt.present(s["qual_column"])
          next "#{name} carries no quality code at the release grain" \
               "#{col ? " (its source column is <code>#{CGI.escapeHTML(col)}</code>)" : ''}; " \
               "<span class=\"mono\">qual_ok</span> keeps all #{Fmt.num(s['qual_ok_n'])}."
        end
        codes = coded.map { |k, v| "<code>#{CGI.escapeHTML(k.to_s)}</code> #{Fmt.num(v)}" }.join(" · ")
        flagged = coded.sum { |_, v| v.to_i }
        "#{name}#{Fmt.present(s['qual_column']) ? " <code>#{CGI.escapeHTML(s['qual_column'])}</code>" : ''} on " \
          "#{Fmt.num(flagged)} of #{Fmt.num(s['n_values'])} rows: #{codes}; " \
          "<span class=\"mono\">qual_ok</span> keeps #{Fmt.num(s['qual_ok_n'])}. " \
          "The codes are this dataset's own vocabulary, uninterpreted."
      end
    end

    def baseline_row(m)
      if m["climatology"]
        "A monthly climatology exists for this measurement (the release's <span class=\"mono\">climatology</span> " \
          "table: 1993–2013, dataset × grid cell × calendar month × 10 m bin), so the Explorer can draw anomalies " \
          "against it rather than values."
      else
        "No climatology row is built for this measurement, so the Explorer draws values, not anomalies."
      end
    end

    def quality_rows(m)
      rows = [bounds_row(m)]
      obs = observed_rows(m)
      rows << { "dt" => "observed", "dd" => obs.join("<br>") } unless obs.empty?
      oob = out_of_bounds_rows(m)
      rows << { "dt" => "out of bounds", "dd" => oob.join("<br>") } unless oob.empty?
      qual = qual_rows(m)
      rows << { "dt" => "flags", "dd" => qual.join("<br>") } unless qual.empty?
      rows << { "dt" => "baseline", "dd" => baseline_row(m) }
      if (d = Fmt.present(m["derivation"]))
        rows << { "dt" => "derivation", "dd" => CGI.escapeHTML(d) }
      end
      rows
    end

    # ── related measurements ─────────────────────────────────────────────────
    # The record says which key and WHY it is kept apart; the sentence is written once here, so a
    # reason the next release adds renders as itself rather than as a blank.
    WHY = {
      "same_bottles"      => "the same quantity from the CTD files' own bottle samples — plausibly the same physical bottles, so merging them would count the bottle dataset twice",
      "underway_vs_cast"  => "an underway surface intake, not a cast — the same quantity, a different kind of sample",
      "replicate_vs_mean" => "a replicate of the source's repeated analyses beside a reported mean; the providers have been asked which to publish",
      "pre_qc_twin"       => "the source's own reported value before its QC — this page is the QC'd twin",
      "sensor_vs_mean"    => "one sensor of the pair beside the mean the file publishes",
      "paired_sensors"    => "the other sensor of the pair, logged alongside",
      "same_casts"        => "the same casts logged by another instrument on the same station"
    }.freeze

    def related_rows(m)
      (m["related"] || []).filter_map do |r|
        o = by_key[r["key"]]
        next if o.nil?
        t = o["totals"] || {}
        { "key"   => r["key"],
          "label" => heading(o),
          "url"   => page_url(o),
          "why"   => WHY[r["why"]] || r["why"].to_s.tr("_", " "),
          "why_code" => r["why"],
          "color" => ds_color((o["series"] || []).first&.dig("dataset_key")),
          "meta"  => [(o["series"] || []).map { |s| s["measurement_type"] }.uniq.join(" · "),
                      (o["series"] || []).map { |s| ds_name(s["dataset_key"]) }.uniq.join(" · "),
                      span(t["year_min"], t["year_max"]),
                      t["n_values"] && "#{Fmt.num(t['n_values'])} values",
                      o["nerc_p01"] && "P01 #{nerc_id(o['nerc_p01'])}"].compact.join(" · ") }
      end
    end

    # the series this dataset carries that are NOT canonical for any key: no page, listed under
    # the dataset (the `vocabulary_only[]` of this catalog)
    def full_resolution_only = @full_res ||= datasets.to_h { |d| [d["dataset_key"], d["full_resolution_only"] || []] }

    # ── the ways in: a tool opens prefilled, one row per endpoint ────────────
    EXPLORE = "https://calcofi.io/explore/"
    DBQUERY = "https://calcofi.io/db-query/"
    ERDDAP  = "https://erddap.calcofi.io/erddap/tabledap/"

    # the keys the Explorer's own picker lists: coverage.json's env variables, keyed the same way
    # (`variable` where the crosswalk sets one, else the measurement_type). A key the Explorer does
    # not carry gets the plain app, never a ?var= that opens on nothing.
    def explorer_keys
      @explorer_keys ||= begin
        cov = @site.data["release_coverage"]
        rows = cov.is_a?(Hash) ? (cov["variables"] || []) : []
        rows.select { |v| v["realm"] == "env" }
            .filter_map { |v| Fmt.present(v["variable"]) || Fmt.present(v["measurement_type"]) }
            .uniq
      end
    end

    def ways(m)
      key   = m["key"]
      types = series_types(m)
      known = explorer_keys.include?(key)
      out = []
      out << { "name" => "Explorer",
               "about" => known ? "maps, sections and time series of this measurement — opens prefilled"
                                : "the Explorer's variable picker; it does not key by this series, so it opens on the release's own list",
               "url"   => known ? "#{EXPLORE}?var=#{CGI.escape(key)}" : EXPLORE }
      if known && m["climatology"]
        out << { "name" => "Explorer · a depth section vs normal",
                 "about" => "the newest cruise's section against the climatology baseline",
                 "url"   => "#{EXPLORE}?lens=section&var=#{CGI.escape(key)}&anom=1" }
      end
      inlist = types.map { |t| "'#{t}'" }.join(", ")
      sql = types.size == 1 ?
        "SELECT * FROM __TBL:obs_env__ WHERE measurement_type = #{inlist} LIMIT 100;" :
        "SELECT * FROM __TBL:obs_env__ WHERE measurement_type IN (#{inlist}) LIMIT 100;"
      out << { "name" => "db-query", "about" => "SQL in your browser — the shell opens with this query",
               "url"  => "#{DBQUERY}?sql=#{CGI.escape(sql)}", "sql" => sql }
      out.concat(erddap_ways(m))
      out << { "name" => "Parquet",
               "about" => "obs_env is partitioned by measurement_type in the content-addressed store — resolved through the release catalog, never a path built by hand",
               "code"  => (["SELECT * FROM read_json('…/#{release['version']}/catalog.json')",
                            "-- objects[] WHERE table = 'obs_env'"] +
                           types.each_with_index.map do |t, i|
                             i.zero? ? "--   AND partition_value = '#{t}'" : "--                    | '#{t}'"
                           end).join("\n") }
      out << { "name" => "R", "code" => <<~R.strip }
        library(calcofi4r)
        con <- cc_get_db()                      # the promoted release
        tbl(con, "obs_env") |> filter(measurement_type %in% c(#{types.map { |t| "\"#{t}\"" }.join(', ')}))
      R
      out << { "name" => "Python", "code" => <<~PY.strip }
        import calcofi4py as cc
        con = cc.cc_get_db()
        con.sql("SELECT * FROM obs_env WHERE measurement_type IN (#{inlist})").df()
      PY
      out
    end

    # one ERDDAP row per series whose dataset publishes a CURRENT tabledap table — constrained to
    # that series only where erddap.calcofi.io says the table HAS a measurement_type column
    # (probed once by scripts/fetch_release.sh into _data/erddap_measurement_type.json). Where it
    # does not, the plain tabledap page, saying so.
    def erddap_ways(m)
      probed = @site.data["erddap_measurement_type"] || {}
      (m["series"] || []).filter_map do |s|
        dk = s["dataset_key"]
        rec = (@site.data.dig("datasets", "datasets") || []).find { |d| d["dataset_key"] == dk }
        dist = (rec && rec["distributions"] || []).find do |y|
          y["format"] == "erddap" && y["status"] != "superseded" &&
            y["id"] == dk && y["url"].to_s.end_with?(".html")
        end
        next if dist.nil?
        has = probed[dist["id"]]
        { "name"  => "ERDDAP · #{ds_name(dk)}",
          "about" => has ? "CalCOFI's own server, the #{ds_name(dk)} table constrained to this series"
                         : "CalCOFI's own server: the #{ds_name(dk)} table (it carries no measurement_type column to constrain on)",
          "url"   => has ? "#{ERDDAP}#{dist['id']}.html?&measurement_type=%22#{CGI.escape(s['measurement_type'].to_s)}%22"
                         : dist["url"] }
      end
    end

    # ── the figure payloads WS-M4 draws (#mm-strip, #mm-depth, #mm-months) ───
    # One row per series, carrying its dataset's colour and short name (never colour alone) and the
    # record's own counts, so a check has a RECORD-side number to compare the drawing against.
    def series_row(s)
      { "k" => s["dataset_key"], "s" => ds_name(s["dataset_key"]), "c" => ds_color(s["dataset_key"]),
        "mt" => s["measurement_type"], "n" => s["n_values"] }
    end

    def strip_json(m)
      { "y0" => 1949, "y1" => release_year, "key" => m["key"],
        "rows" => (m["series"] || []).map { |s| series_row(s).merge("y" => s["years"] || {}) } }
    end

    def depth_json(m)
      bands = (m["series"] || []).flat_map { |s| (s["depth_bands"] || {}).keys }.uniq
      { "key" => m["key"], "bands" => bands,
        "rows" => (m["series"] || []).map { |s| series_row(s).merge("b" => s["depth_bands"] || {}) } }
    end

    def months_json(m)
      { "key" => m["key"],
        "rows" => (m["series"] || []).map { |s| series_row(s).merge("m" => s["months"] || []) } }
    end

    # ── the one payload the index inlines ────────────────────────────────────
    # keys · labels · category · units · P01 · the spans and totals per series — everything the
    # timeline, the matrix, the datasets list and the search need, and nothing else (a page's
    # per-year, per-month and per-depth maps stay on the page). Datasets are referenced by their
    # INDEX in ds[] so 84 series do not repeat five dataset keys each.
    def inline
      @inline ||= begin
        di = datasets.each_with_index.to_h { |d, i| [d["dataset_key"], i] }
        cats = {}
        measurements.each do |m|
          c = m["category"] || {}
          e = (cats[c["name"]] ||= { "n" => c["name"], "i" => c["icon"], "r" => c["realm"],
                                     "o" => c["order"], "k" => 0, "v" => 0 })
          e["k"] += 1
          e["v"] += m.dig("totals", "n_values").to_i
        end
        { "rel"    => release["version"],
          "date"   => release["release_date"],
          "base"   => "/measurements/",
          "y0"     => 1949, "y1" => release_year,
          "counts" => counts,
          "ds"     => datasets.map do |d|
            { "k" => d["dataset_key"], "s" => d["dataset_name_short"] || d["dataset_key"],
              "c" => d["color"], "cat" => d.dig("category", "name"), "r" => d.dig("category", "realm"),
              "u" => ds_url(d["dataset_key"]),
              "n" => d["n_series"], "v" => d["n_values"],
              "y0" => d["year_min"], "y1" => d["year_max"],
              "fr" => (d["full_resolution_only"] || []).size }
          end,
          "cats"   => cats.values.sort_by { |c| [c["o"] || 99, c["n"].to_s] },
          # the slug is NOT carried: it is the key itself in this record, so measurements.js uses
          # `base + key + "/"` and 79 rows do not repeat their own key twice
          "rows"   => measurements.map do |m|
            { "k"  => m["key"], "l" => heading(m), "c" => m.dig("category", "name"),
              "u"  => Fmt.units(m["units"]), "ur" => Fmt.present(m["units"]),
              "p" => m["nerc_p01"] && nerc_id(m["nerc_p01"]),
              "un" => m["is_unified"] ? 1 : nil,
              "cl" => m["climatology"] ? 1 : nil,
              "t"  => { "n" => m.dig("totals", "n_values"), "y0" => m.dig("totals", "year_min"),
                        "y1" => m.dig("totals", "year_max"), "d0" => m.dig("totals", "depth_min_m"),
                        "d1" => m.dig("totals", "depth_max_m") },
              "se" => (m["series"] || []).map do |s|
                { "d" => di[s["dataset_key"]], "mt" => s["measurement_type"],
                  "n" => s["n_values"], "sm" => s["n_samples"], "rt" => s["n_roots"],
                  "y0" => s["year_min"], "y1" => s["year_max"],
                  "d0" => s["depth_min_m"], "d1" => s["depth_max_m"],
                  "sc" => s["source_column"], "qc" => s["qual_column"],
                  "p" => s["nerc_p01"] && nerc_id(s["nerc_p01"]),
                  "de" => Fmt.present(s["description"]), "fg" => s["flags"] }.compact
              end }.compact
          end }
      end
    end

    # ── the front door's one search (assets/door-search.js, group "M") ───────
    # The row shape WS-M0's coverage-built stub established, now generated from the record:
    #   n the label · c the category · r the datasets · o values · y0/y1 the years ·
    #   u the page · t the haystack (label, key, series, datasets, units, P01)
    def search_rows
      measurements.map do |m|
        t = m["totals"] || {}
        dsn = (m["series"] || []).map { |s| ds_name(s["dataset_key"]) }.uniq
        hay = ([heading(m), m["key"], m["description"], m["units"], Fmt.units(m["units"]),
                m["nerc_p01"] && nerc_id(m["nerc_p01"]), m.dig("category", "name")] +
               series_types(m) + dsn +
               (m["series"] || []).map { |s| s["dataset_key"] }).compact.join(" ").downcase
        { "n" => heading(m), "c" => m.dig("category", "name"), "r" => dsn.join(" · "),
          "o" => t["n_values"], "y0" => t["year_min"], "y1" => t["year_max"],
          "u" => page_url(m), "t" => hay }
      end
    end

    # ══ faces (WS-MF5) ═══════════════════════════════════════════════════════
    # What the thing IS, how it is taken and why it matters, on every measurement page
    # (plan 2026-09-11 "Measurement faces …" § D1–D7). Two sources, and neither is typed here:
    #
    #   the RECORD  `measurements.json` 1.1 — `face`, `chem`, `method`, `scale`, `why`, `anomaly`
    #               and `n_flagged`, all measured or authored at release from the five registries
    #               (metadata/measurement_{chem,method,scale,why,face}.csv)
    #   the MEDIA   `_data/measurements_media.json` — the NERC concept and its definition, the
    #               structures drawn by RDKit from ChEBI's molfiles, the Wikipedia leads, the GOOS
    #               EOV sheet and the ONI table. Written by scripts/fetch_measurement_faces.py
    #               (WS-MF4) into ONE version-free copy at
    #               gs://calcofi-files-public/measurement-media/ — a molecule and an EOV outlive a
    #               release exactly as a taxon does, and keying media by {release} blanked every
    #               species page on 2026-09-11. `scripts/fetch_release.sh` pulls it into `_data/`.
    #
    # EVERY slot below is nil-safe: a key with neither a face block nor a media entry renders
    # exactly as it did before this section existed, and the face row is not emitted at all.
    #
    # Three things this file will not do, whatever the data says:
    #   · a ChEBI ROLE is never shown (dioxygen's include "anti-inflammatory drug", and the S27
    #     behind DIC is the carbon ATOM, whose roles include "antidepressant" — § F3)
    #   · a GOOS question is QUOTED and linked, never paraphrased and never more than the sheet's
    #     own sentence (goosocean.org reserves all rights — § F4)
    #   · a STAND-IN never wears the ids of the face it borrows (§ D3): it draws the picture, says
    #     whose it is, and its ids row and its JSON-LD stay empty of ChEBI, CAS and WoRMS
    MEDIA_BASE = "https://storage.googleapis.com/calcofi-files-public/measurement-media/"

    PLATFORMS = { "bottle" => "rosette bottle", "ctd" => "CTD sensor", "lab" => "counted ashore",
                  "mast" => "underway, on the mast", "underway" => "underway intake",
                  "net" => "net tow" }.freeze
    WHY_KIND  = { "authored" => "authored", "goos" => "GOOS asks", "wikipedia" => "Wikipedia",
                  "calcofi" => "calcofi.org" }.freeze

    def media        = @media ||= (@site.data["measurements_media"] || {})
    def media_keys   = @media_keys ||= (media["measurements"] || {})
    def media_of(m)  = media_keys[m["key"]] || {}
    def media_base   = Fmt.present(media["base"]) || MEDIA_BASE
    def oni          = media["oni"] || {}
    def media_tables = media["tables"] || {}

    # a page has a face when the release gave it one OR the fetcher found the concept behind it
    def face_kind(m) = Fmt.present((m["face"] || {})["kind"])
    def has_face?(m) = !face_kind(m).nil? || !media_of(m).empty?
    def stands_in?(m) = face_kind(m) == "standsin"

    # "NO3" + charge −1 → NO<sub>3</sub><sup>−</sup>. A formula is markup, not a number.
    def formula_html(x)
      f = Fmt.present(x["formula"])
      return nil if f.nil?
      out = CGI.escapeHTML(f).gsub(/(\d+)/) { "<sub>#{Regexp.last_match(1)}</sub>" }
      q = x["charge"].to_i
      return out if q.zero?
      "#{out}<sup>#{q.abs > 1 ? q.abs : ''}#{q.positive? ? '+' : '−'}</sup>"
    end

    # NERC's definitions run to several sentences; the face row shows the first and the What
    # section the whole of it. Split on the first full stop or semicolon, never on a fixed length.
    def first_sentence(t)
      s = Fmt.present(t.to_s.strip)
      return nil if s.nil?
      (s[/\A.*?[.;](?:\s|\z)/] || s).strip
    end

    CHEBI_URL = "https://www.ebi.ac.uk/chebi/searchId.do?chebiId="
    WORMS_URL = "https://www.marinespecies.org/aphia.php?p=taxdetails&id="

    # the drawn structures, in the page's own ink: RDKit writes `currentColor`, so one file is navy
    # on white and bone on navy. `svg_inner` is emitted RAW, so the picture is there without JS.
    def structures(m)
      # only entries the fetcher DREW: a monatomic ion of salinity's composition (Na⁺, Cl⁻, …)
      # is a ChEBI record with a mass fraction and no molfile picture, and belongs to the ion
      # bar, not to an empty <svg> (check_layout: "a structure drew 0 shapes")
      (media_of(m)["structures"] || []).select { |s| Fmt.present(s["svg_inner"]) }.each_with_index.map do |s, i|
        { "chebi"   => Fmt.present(s["chebi"]),
          "name"    => Fmt.present(s["name"]),
          "formula" => formula_html(s),
          "mass"    => Fmt.present(s["mass"].to_s),
          "role"    => Fmt.present(s["role"]),
          # ChEBI's own definition may be quoted (CC BY 4.0); its ROLES never are
          "definition" => Fmt.present(s["definition"]),
          "viewBox" => Fmt.present(s["viewBox"]) || "0 0 1 1",
          "inner"   => s["svg_inner"].to_s,
          "label"   => "Structure of #{s['name'] || m['key']}",
          "drawn_by" => Fmt.present(s["drawn_by"]),
          "license" => Fmt.present(s["license"]),
          "chebi_url" => Fmt.present(s["chebi"]) && "#{CHEBI_URL}#{s['chebi']}",
          # the file on the bucket, for JSON-LD's `image`: the fetcher's own URL where it gives
          # one, else the version-free path it writes (never a {release} segment)
          "file"    => Fmt.present(s["url"]) || (i.zero? ? "#{media_base}keys/#{m['key']}/structure.svg" : nil) }.compact
      end
    end

    def nerc_of(m) = media_of(m)["nerc"] || {}

    # An id is claimed only where it identifies THIS measurement's own thing:
    #   · the S27's ChEBI and CAS only where the face IS that one substance (`structure`). A pool
    #     or a mixture takes composition rows instead: DIC's S27 is "total inorganic carbon"
    #     `sameAs` CHEBI:27594, which is the carbon ATOM, and salinity is not a molecule at all
    #     (§ F3, § D2) — claiming either would say the page is about something it is not.
    #   · the S25's WoRMS only where the face IS that organism (`organism`).
    #   · nothing at all on a stand-in, which borrows a picture and not an identity (§ D3).
    def owns_substance?(m) = face_kind(m) == "structure"
    def owns_organism?(m)  = face_kind(m) == "organism"

    # the ids a face adds beside the P01 row
    def face_ids(m)
      return [] if stands_in?(m)
      n = nerc_of(m)
      rows = []
      st = structures(m).first
      if owns_substance?(m) && st && st["chebi"]
        rows << { "label" => "ChEBI", "id" => st["chebi"].to_s.sub("CHEBI:", ""), "url" => st["chebi_url"] }
      end
      if owns_substance?(m) && (cas = Fmt.present(n.dig("s27", "cas")))
        rows << { "label" => "CAS", "id" => cas, "url" => "https://commonchemistry.cas.org/detail?cas_rn=#{cas}" }
      end
      if owns_organism?(m) && (w = Fmt.present(n.dig("s25", "worms").to_s))
        rows << { "label" => "WoRMS", "id" => w, "url" => "#{WORMS_URL}#{w}" }
      end
      e = eov_of(m)
      rows << { "label" => "EOV", "id" => e["name"], "url" => Fmt.present(e["doc"]) } if Fmt.present(e["name"])
      rows
    end

    def eov_of(m)
      e = media_of(m)["eov"] || {}
      # where the fetcher has no sheet, the why rows still name the variable (§ D5's `eov` column)
      w = (m["why"] || []).find { |r| Fmt.present(r["eov"]) }
      { "name" => Fmt.present(e["name"]) || (w && Fmt.present(w["eov"])),
        "doc"  => Fmt.present(e["doc"]) || (w && Fmt.present(w["goos_doc"])),
        "membership" => Fmt.present(e["membership"]),
        # quoted, never paraphrased, and each with the sheet it is quoted from
        "questions" => (e["questions"] || []).map { |q| q.to_s.strip },
        "phenomena" => (e["phenomena"] || []).map { |p| p.to_s.strip } }
    end

    def stands_in(m)
      return nil unless stands_in?(m)
      of = Fmt.present((m["face"] || {})["face_of"])
      o = of && by_key[of]
      { "face_of" => of, "label" => o ? heading(o) : of,
        "url" => o && page_url(o),
        "why" => Fmt.present((m["face"] || {})["stands_in_note"]) }.compact
    end

    # ── What: the entity NERC names, reached only by identity ────────────────
    def what_of(m)
      n = nerc_of(m)
      st = structures(m)
      { "kind" => face_kind(m),
        "note" => Fmt.present((m["face"] || {})["note"]),
        "structures" => st,
        "structure_ct" => st.size,
        # the composition rows: a pool or a mixture takes components with their mass fractions,
        # never one S27 (§ D2, § F3)
        "chem" => (m["chem"] || []).map do |x|
          { "chebi" => Fmt.present(x["chebi"]), "name" => Fmt.present(x["name"]),
            "formula" => formula_html(x), "role" => Fmt.present(x["role"]),
            "fraction" => x["mass_fraction"], "via" => Fmt.present(x["via"]),
            "source" => Fmt.present(x["source"]),
            "url" => Fmt.present(x["chebi"]) && "#{CHEBI_URL}#{x['chebi']}" }.compact
        end,
        "nerc" => { "p01" => Fmt.present(n["p01"]), "url" => Fmt.present(n["url"]),
                    "pref" => Fmt.present(n["pref"]),
                    "definition" => Fmt.present(n["definition"]),
                    "lead" => first_sentence(n["definition"]),
                    "license" => Fmt.present(n["license"]) }.compact,
        "a05_only" => (m["face"] || {})["a05_only"],
        "p01_borrowed_from" => (m["face"] || {})["p01_borrowed_from"],
        "taxon" => media_of(m)["taxon"],
        "composition" => media_of(m)["composition"],
        "bjerrum" => media_of(m)["bjerrum"],
        "stands_in" => stands_in(m),
        "ids" => face_ids(m) }.compact
    end

    # the identity chain the What section lists: P01 → its parts → the EOV. Read from the media's
    # own `links`, so a part the vocabulary adds appears without a code change here.
    CHAIN_PARTS = %w[S27 S25 S06 A05 P07 P02].freeze

    def chain_rows(m)
      n = nerc_of(m)
      rows = []
      if Fmt.present(n["p01"])
        rows << { "c" => "P01", "title" => Fmt.present(n["pref"]) || n["p01"],
                  "url" => Fmt.present(n["url"]),
                  "note" => (m["face"] || {})["p01_borrowed_from"] &&
                            "not on this key: carried by #{Array((m['face'] || {})['p01_borrowed_from']).join(' and ')}" }.compact
        (n["links"] || {}).each do |k, v|
          coll, id = k.to_s.split(" ", 2)
          next unless CHAIN_PARTS.include?(coll) && Fmt.present(v["pref"])
          same = (v["sameAs"] || []).filter_map { |u| same_as_label(u) && { "label" => same_as_label(u), "url" => u } }
          rows << { "c" => coll, "title" => v["pref"], "id" => id, "same" => same }
        end
      elsif (si = stands_in(m))
        rows << { "c" => "P01", "title" => "none on this key",
                  "note" => "it stands in for #{si['label']}, drawn but not claimed: the ids row shows none" }
      elsif (a = (m["face"] || {})["a05_only"])
        rows << { "c" => "P01", "title" => "none on this key",
                  "note" => "the nearest concept is A05 #{a['code']} — #{a['def']}" }
      end
      e = eov_of(m)
      if e["name"]
        rows << { "c" => "EOV", "title" => e["name"], "url" => e["doc"], "note" => e["membership"] }.compact
      end
      rows
    end

    def same_as_label(u)
      u = u.to_s
      return "ChEBI #{u.split('CHEBI_').last}" if u.include?("CHEBI_")
      return "CAS #{u.split('/rn/').last}"      if u.include?("chemidplus/rn/")
      return "WoRMS #{u.split('/').last}"       if u.include?("aphia") || u.include?("marinespecies")
      return "QUDT #{u.split('/').last}"        if u.include?("qudt")
      Fmt.present(u.split("/").reject(&:empty?).last)
    end

    # ── How: one card per series, from the method registry ───────────────────
    def how_rows(m)
      (m["method"] || []).map do |h|
        dk = h["dataset_key"]
        s = (m["series"] || []).find do |x|
          x["dataset_key"] == dk &&
            (Fmt.present(h["measurement_type"]).nil? || x["measurement_type"] == h["measurement_type"])
        end || {}
        nf = s.empty? ? nil : flagged(s)
        { "dataset_key" => dk, "name" => ds_name(dk), "url" => ds_url(dk), "color" => ds_color(dk),
          "platform" => Fmt.present(h["platform"]),
          "platform_label" => PLATFORMS[h["platform"]] || Fmt.present(h["platform"]),
          "instrument" => Fmt.present(h["instrument"]),
          "principle"  => Fmt.present(h["principle"]),
          "steps"      => h["steps"] || [],
          "nm"         => h["wavelength_nm"],
          "nm_note"    => Fmt.present(h["wavelength_note"]),
          "precision"  => Fmt.present(h["precision"]),
          "acid_figure" => h["acid_figure"] ? true : nil,
          # linked the way the front door's pins are: the method page and the text fragment that
          # lands on its section (calcofi.org has no stable anchors — § F5)
          "page"       => Fmt.present(h["page"]) || "Methods",
          "link"       => Fmt.present(h["calcofi_org"]),
          "source"     => Fmt.present(h["source"]),
          "type"       => Fmt.present(s["measurement_type"]),
          "meta"       => [Fmt.num(s["n_values"]) && "#{Fmt.num(s['n_values'])} values",
                           span(s["year_min"], s["year_max"]),
                           Fmt.present(s["source_column"]) && "column #{s['source_column']}"].compact,
          "qual_column" => Fmt.present(s["qual_column"]),
          "flagged"    => nf && nf.positive? ? Fmt.num(nf) : nil }.compact
      end
    end

    # ── Why: the pick, the alternatives, the anomaly, the EOV ────────────────
    def why_rows_sorted(m) = (m["why"] || []).sort_by { |r| r["rank"].to_i }

    def why_pick(m) = why_rows_sorted(m).find { |r| r["rank"].to_i == 1 } || why_rows_sorted(m).first

    def cites_of(r)
      (r["cites"] || []).filter_map do |c|
        next { "label" => c["label"] || c["key"], "url" => Fmt.present(c["url"]), "key" => c["key"] } if c.is_a?(Hash)
        { "label" => c[1] || c[0], "url" => Fmt.present(c[2]), "key" => c[0] } if c.is_a?(Array)
      end.compact
    end

    # ranks 2… — the datasets catalog's "not yet in the database" idiom, closed on load
    def why_alts(m)
      why_rows_sorted(m).reject { |r| r["rank"].to_i == 1 }.map do |r|
        cs = cites_of(r)
        { "kind" => Fmt.present(r["kind"]) || "authored",
          "kind_label" => WHY_KIND[r["kind"]] || Fmt.present(r["kind"]) || "authored",
          "text" => Fmt.present(r["text"]),
          "cites" => cs,
          "url" => Fmt.present(r["source_url"]),
          # § D5: an authored alternative with no citation says so rather than reading as a fact
          "needs_cite" => (r["kind"].to_s == "authored" && cs.empty? && Fmt.present(r["source_url"]).nil?) }
      end.select { |r| r["text"] }
    end

    # ONE rounding for a measured value written to two decimals. `format("%.2f", x)` rounds the
    # BINARY value half-to-even, while assets/measurements.js's toLocaleString rounds half away
    # from zero — so nitrate's +0.225 per decade read "0.22" in the sentence and "+0.23" in the
    # spark line beside it on the same page (measured 2026-09-12). Round first, then format.
    def dp2(v) = format("%.2f", v.to_f.round(2))

    # the record's own half of the sentence, every number read from `totals` and `anomaly`
    def rec_sentence(m)
      t = m["totals"] || {}
      return nil if t["n_values"].nil?
      s = +"CalCOFI holds #{Fmt.num(t['n_values'])} values of it from #{Fmt.num(t['n_roots'])} sampling events"
      s << " in #{t['n_datasets'].to_i == 1 ? 'one dataset' : "#{t['n_datasets']} datasets"}" if t["n_datasets"]
      s << ", #{span(t['year_min'], t['year_max'])}" if span(t["year_min"], t["year_max"])
      s << (t["depth_max_m"].to_f.zero? ? ", at the surface." : ", from the surface to #{Fmt.num(t['depth_max_m'].to_f.round)} m.")
      a = m["anomaly"]
      b = a && (a["bands"] || []).find { |x| x["band"] == a["spark_band"] }
      if b
        u = Fmt.present(a["units"]) ? " #{Fmt.units(a['units'])}" : ""
        band = b["band"].to_s.tr("-", "–")
        if (tr = b["trend"]) && !tr["per_decade"].nil?
          v = tr["per_decade"].to_f
          s << " At #{band} m it has #{v.negative? ? 'fallen' : 'risen'} #{dp2(v.abs)}#{u} per decade since #{tr['from']}."
        elsif (ex = b["ext"])
          s << " At #{band} m its high was #{ex['hi'][0]} (#{ex['hi'][1].to_f.positive? ? '+' : ''}#{dp2(ex['hi'][1])}#{u} against the #{Array(a['baseline']).join('–')} normal), its low #{ex['lo'][0]} (#{dp2(ex['lo'][1])}#{u})."
        end
      end
      s
    end

    # NERC says what it is · the record says what we hold · the pick says why it matters, each
    # underlined in its source's colour, with a legend that names exactly the parts drawn (§ D5)
    def sentence(m)
      pick = why_pick(m)
      parts = []
      lead = what_of(m).dig("nerc", "lead")
      parts << { "cls" => "s-nerc", "text" => lead, "src" => "NERC" } if lead
      if (r = rec_sentence(m))
        parts << { "cls" => "s-rec", "text" => r, "src" => "record" }
      end
      if pick && Fmt.present(pick["text"])
        cs = cites_of(pick)
        parts << { "cls" => "s-why", "text" => pick["text"], "cites" => cs,
                   "src" => cs.empty? ? "authored, needs a citation" : "authored, cited" }
      end
      return nil if parts.empty?
      parts
    end

    # ── the familiar scale: the axis, the marks, the flags (§ D7) ────────────
    # The MARKS are the record's (`metadata/measurement_scale.csv`). The AXIS a mark sits on —
    # linear · log · Beaufort and its domain — and the quality flags the scale surfaced come from
    # `scale_axis` / `scale_flags` where the record carries them; where it does not, a linear axis
    # is DERIVED from the declared bounds, the observed range and the marks, so the figure is drawn
    # from measured values either way and nothing is typed.
    def scale_axis(m)
      ax = m["scale_axis"] || {}
      dom = ax["domain"]
      unless dom.is_a?(Array) && dom.size == 2
        vals = []
        b = m["bounds"] || {}
        [b["valid_min"], b["valid_max"]].compact.each { |v| vals << v.to_f }
        (m["series"] || []).each do |s|
          o = s["observed"] || {}
          [o["min"], o["p05"], o["p95"], o["max"]].compact.each { |v| vals << v.to_f }
        end
        (m["scale"] || []).each { |r| vals << r["value"].to_f unless r["value"].nil? || r["off"] }
        return nil if vals.empty?
        lo, hi = vals.min, vals.max
        pad = (hi - lo).abs * 0.05
        pad = 1.0 if pad.zero?
        dom = [lo - pad, hi + pad]
      end
      out = { "type" => Fmt.present(ax["type"]) || "linear", "domain" => dom,
              "source" => Fmt.present(ax["source"]), "zero_pct" => ax["zero_pct"] }.compact
      if out["type"] == "beaufort"
        out["beaufort"] = media_tables.dig("beaufort", "rows")
        out["beaufort_source"] = media_tables.dig("beaufort", "source")
      end
      out
    end

    def scale_of(m)
      marks = (m["scale"] || []).map do |r|
        { "v" => r["value"], "lo" => r["lo"], "hi" => r["hi"], "label" => Fmt.present(r["label"]),
          "kind" => Fmt.present(r["kind"]), "src" => Fmt.present(r["source"]) || Fmt.present(r["how"]),
          "off" => r["off"] }.compact
      end
      ax = scale_axis(m)
      return nil if ax.nil? && marks.empty?
      { "axis" => ax, "marks" => marks,
        "flags" => (m["scale_flags"] || []).map { |f| { "text" => f["text"], "v" => f["value"], "off" => f["off"] }.compact },
        "bounds" => m["bounds"] || {},
        "units" => Fmt.units(m["units"]),
        "series" => (m["series"] || []).map do |s|
          { "k" => s["dataset_key"], "s" => ds_name(s["dataset_key"]), "c" => ds_color(s["dataset_key"]),
            "mt" => s["measurement_type"], "o" => s["observed"] || {} }
        end }
    end

    # ── the one payload the figures are drawn from (#mm-face) ────────────────
    def face_json(m)
      w = what_of(m)
      { "key" => m["key"], "kind" => face_kind(m), "units" => Fmt.units(m["units"]),
        "label" => heading(m),
        "scale" => scale_of(m),
        "anomaly" => m["anomaly"],
        "anomaly_note" => Fmt.present(m["anomaly_note"]),
        "oni" => { "strong" => oni["strong_el_nino"] || [], "latest" => oni["latest"] },
        "y0" => 1949, "y1" => release_year,
        "composition" => w["composition"], "bjerrum" => w["bjerrum"], "taxon" => w["taxon"],
        "chem" => w["chem"],
        "ph" => (m["series"] || []).map { |s| s["observed"] }.compact.first }.compact
    end

    # everything the page's Liquid reads, or nil where the key has no face at all
    def face_of(m)
      return nil unless has_face?(m)
      w = what_of(m)
      e = eov_of(m)
      wp = (media_of(m)["wikipedia"] || []).first
      { "kind" => face_kind(m) || "none",
        "kind_label" => (face_kind(m) == "standsin" ? "stands in" : face_kind(m)),
        "what" => w,
        "chain" => chain_rows(m),
        "how" => how_rows(m),
        "eov" => e,
        "why" => { "pick" => (p = why_pick(m)) && { "text" => Fmt.present(p["text"]), "cites" => cites_of(p) },
                   "alts" => why_alts(m) },
        "sentence" => sentence(m),
        "scale" => scale_of(m),
        "anomaly_note" => Fmt.present(m["anomaly_note"]),
        "anomaly_bands" => (m["anomaly"] || {})["bands"]&.size,
        "anomaly_deeper" => ((m["anomaly"] || {})["deeper"] || []).map do |d|
          "#{Fmt.num(d['n_obs'])} values at #{d['band'].to_s.tr('-', '–')} m"
        end,
        "calcofi_quote" => Fmt.present(media_of(m)["calcofi_quote"]),
        "wikipedia" => wp && { "title" => Fmt.present(wp["title"]),
                               "url" => Fmt.present(wp["url"]) && "#{wp['url']}?oldid=#{wp['revision']}",
                               "revision" => wp["revision"].to_s,
                               "license" => Fmt.present(wp["license"]) || "CC BY-SA 4.0",
                               # two sentences of a CC BY-SA lead, linked to its revision — borrowed
                               # context beside the sentence, never inside it
                               "extract" => wp["extract"].to_s.split(/(?<=\.)\s/).first(2).join(" ") },
        "media_release" => Fmt.present(media["release"]),
        "json" => JSON.generate(face_json(m)).gsub("</", "<\\/") }
    end

    # ── schema.org/DefinedTerm ───────────────────────────────────────────────
    # A measurement is a term in the NERC P01 term set, with one PropertyValue per series: the
    # dataset's own name for it, its units (P06 as unitCode where the record has one) and its
    # description. `termCode` is the P01 id where one says exactly this and is simply absent
    # otherwise — an empty id means "no concept says exactly this", never "not looked at".
    P01_SET = "http://vocab.nerc.ac.uk/collection/P01/current/"

    def jsonld(m)
      url = abs(page_url(m))
      node = {
        "@context" => "https://schema.org",
        "@type"    => "DefinedTerm",
        "@id"      => url,
        "url"      => url,
        "name"     => heading(m),
        "identifier" => m["key"],
        "inDefinedTermSet" => { "@type" => "DefinedTermSet", "@id" => P01_SET,
                                "name" => "NERC Vocabulary Server P01 (BODC Parameter Usage Vocabulary)",
                                "url" => P01_SET }
      }
      node["description"] = Fmt.present(m["description"]) || heading(m)
      node["termCode"] = nerc_id(m["nerc_p01"]) if Fmt.present(m["nerc_p01"])
      # `sameAs` is the concepts this term IS, so it grows with the face's identity chain: the P01
      # the record carries, then the ChEBI entry, the CAS registry entry and the WoRMS record the
      # S27/S25 reach (plan § D1, § F1). A STAND-IN never lists any of them — it borrows a picture,
      # not an identity (§ D3) — and a key with no structure gains nothing here.
      same = []
      same << m["nerc_p01"] if Fmt.present(m["nerc_p01"])
      face_ids(m).each { |r| same << r["url"] unless r["label"] == "EOV" }
      same = same.compact.uniq
      node["sameAs"] = same.size == 1 ? same.first : same unless same.empty?
      # the picture, and the terms it is shown under: an ImageObject exactly where the face IS one
      # drawn structure, and nowhere else — never on a stand-in (whose structure is another key's)
      # and never on a pool or a mixture (whose components are not the thing)
      # (scripts/check_jsonld.py asserts both halves)
      if owns_substance?(m) && (st = structures(m).first) && st["file"]
        img = { "@type" => "ImageObject", "contentUrl" => st["file"] }
        img["license"] = "https://creativecommons.org/licenses/by/4.0/" if st["license"]
        img["creditText"] = st["drawn_by"] if st["drawn_by"]
        img["acquireLicensePage"] = st["chebi_url"] if st["chebi_url"]
        img["caption"] = st["label"] if st["label"]
        node["image"] = img
      end
      props = (m["series"] || []).map do |s|
        { "@type" => "PropertyValue",
          "name"  => s["measurement_type"],
          "description" => Fmt.present(s["description"]),
          "propertyID" => Fmt.present(s["nerc_p01"]),
          "unitText" => Fmt.present(s["units"]),
          "unitCode" => Fmt.present(m["units_nerc_p06"]) }.compact
      end
      node["hasPart"] = props unless props.empty?
      node["isPartOf"] = { "@type" => "CollectionPage", "@id" => abs("/measurements/"),
                           "name" => "CalCOFI measurements catalog" }
      node
    end

    def index_jsonld
      { "@context" => "https://schema.org",
        "@type"    => "DefinedTermSet",
        "@id"      => abs("/measurements/"),
        "url"      => abs("/measurements/"),
        "name"     => "CalCOFI measurements catalog",
        "description" => "Every environmental measurement CalCOFI publishes, keyed to one name — " \
                         "#{Fmt.num(counts['measurements'])} measurements in #{Fmt.num(counts['series'])} series " \
                         "across #{counts['datasets']} datasets in release #{release['version']}.",
        "hasDefinedTerm" => measurements.map do |m|
          { "@type" => "DefinedTerm", "@id" => abs(page_url(m)), "url" => abs(page_url(m)),
            "name" => heading(m), "termCode" => Fmt.present(m["nerc_p01"]) ? nerc_id(m["nerc_p01"]) : nil }.compact
        end,
        "isPartOf" => { "@type" => "WebSite", "@id" => abs("/"), "url" => abs("/") } }
    end
  end

  # ── the generator ──────────────────────────────────────────────────────────
  class MeasurementsCatalog < Jekyll::Generator
    safe false
    priority :normal      # after datasets.rb (:high), before news.rb (:low)

    def generate(site)
      # `_data/measurements.json` IS site.data["measurements"], and this generator replaces that key
      # with what the layouts read — so the guard is the record's own shape, not the key's presence
      # (on a `jekyll serve` regeneration site.data is re-read from disk and the record is back).
      rec = site.data["measurements"]
      rec = nil unless rec.is_a?(Hash) && rec["measurements"].is_a?(Array)
      if rec.nil?
        # the D-2 rule: without the record NOTHING is drawn and nothing is typed. The front door
        # reads site.data.measurements to know whether /measurements/ exists, and falls back to
        # the Explorer's variable picker where it does not.
        site.data["measurements"] = nil
        Jekyll.logger.info "measurements:",
                           "no _data/measurements.json — no measurement pages (set " \
                           "MEASUREMENTS_RELEASE_URL, or wait for a promoted release that carries it)"
        return
      end
      unless rec["schema_version"].to_s.start_with?("1.")
        Jekyll.logger.warn "measurements:", "record schema #{rec['schema_version'].inspect}, expected \"1.x\""
      end

      mm = MeasurementsRecord.new(site, rec)
      inline = mm.inline
      # "</" inside a JSON string would end the <script> element early; \/ is the same string
      json = JSON.generate(inline).gsub("</", "<\\/")

      site.data["measurements"] = {
        "release"    => mm.release,
        "counts"     => mm.counts,
        "counts_fmt" => mm.counts.transform_values { |v| v.is_a?(Integer) ? Fmt.num(v) : v }
                          .merge("obs_env_rows_m" => Fmt.millions(mm.counts["obs_env_rows"]),
                                 "full_rows_m"    => Fmt.millions(mm.counts["full_rows"])),
        "datasets"   => inline["ds"],
        "categories" => inline["cats"],
        # the keys that unify two datasets' series, for the head's one sentence on how the count works
        "unified"    => mm.measurements.select { |m| m["is_unified"] }
                          .map { |m| { "key" => m["key"], "label" => mm.heading(m), "url" => mm.page_url(m),
                                       "n_series" => (m["series"] || []).size } },
        "jsonld"     => JSON.pretty_generate(mm.index_jsonld),
        # measurement_type => the slug of the page it belongs to, so a dataset page can link the
        # variables in its Coverage list to pages that EXIST without guessing the key rule
        "type_slugs" => mm.measurements.flat_map { |m| (m["series"] || []).map { |s| [s["measurement_type"], m["slug"]] } }.to_h,
        "key_slugs"  => mm.measurements.to_h { |m| [m["key"], m["slug"]] },
        "labels"     => mm.measurements.flat_map { |m| (m["series"] || []).map { |s| [s["measurement_type"], mm.heading(m)] } }.to_h,
        # dataset_key => the series it carries that are not canonical for any key: no page, but a
        # reader of that dataset's page wants to know they exist (plan § D2)
        "full_res"   => mm.full_resolution_only,
        "inline"     => json,
        "inline_kb"  => (json.bytesize / 1024.0).round
      }

      # The front door's Data section reads the measurement counts through
      # site.data.catalog.numbers, which datasets.rb measures from coverage.json because until now
      # there was no record. Where the record exists it is the authority, so the same keys are
      # rewritten from it here — one number, one source, and the tab, the pills and the index can
      # never disagree (WS-M0 shipped the coverage fallback for exactly this handover).
      if (nums = site.data.dig("catalog", "numbers"))
        c = mm.counts
        nums["measurements_keys"]       = c["measurements"]
        nums["measurements_keys_fmt"]   = Fmt.num(c["measurements"])
        nums["measurements_series"]     = c["series"]
        nums["measurements_series_fmt"] = Fmt.num(c["series"])
        nums["measurements_datasets"]   = c["datasets"]
        nums["measurements_year_min"]   = mm.datasets.filter_map { |d| d["year_min"] }.min
        nums["measurements_year_max"]   = mm.datasets.filter_map { |d| d["year_max"] }.max
      end

      pages = [index_page(site, mm)]
      mm.measurements.each { |m| pages.concat(measurement_pages(site, mm, m)) }
      pages << json_page(site, "/measurements/", "sitemap.xml", sitemap(mm))
      pages << json_page(site, "/measurements/", "search.json",
                         JSON.generate({ "release" => mm.release["version"], "rows" => mm.search_rows }))
      site.pages.concat(pages)

      # ── the faces (plan 2026-09-11 § D8) ────────────────────────────────────
      # The media sidecar is the fetcher's, not the release's, and it is version-FREE: one copy at
      # measurement-media/measurements_media.json beside measurement-media/keys/{key}/structure.svg.
      # Its own `release` field says which record it was walked against — a mismatch is worth
      # saying out loud, but it is never a reason to drop a face (a molecule outlives a release).
      if mm.media_keys.empty?
        Jekyll.logger.info "measurements:",
                           "no _data/measurements_media.json — no measurement faces " \
                           "(run scripts/fetch_measurement_faces.py, or fetch_release.sh)"
      else
        if Fmt.present(mm.media["release"]) && mm.media["release"] != mm.release["version"]
          Jekyll.logger.info "measurements:",
                             "measurements_media.json was fetched for release " \
                             "#{mm.media['release']}, the record is #{mm.release['version']} " \
                             "(the media are not keyed by release — this is a note, not a fault)"
        end
        faced = mm.measurements.count { |m| mm.has_face?(m) }
        kinds = mm.measurements.filter_map { |m| mm.face_kind(m) }.tally.sort_by { |_, v| -v }
                  .map { |k, v| "#{k} #{v}" }.join(" · ")
        Jekyll.logger.info "measurements:",
                           "#{faced} face(s) · #{kinds.empty? ? 'no face_kind in the record' : kinds} · " \
                           "#{mm.media_keys.size} key(s) in the media sidecar"
      end
      # the record's `n_flagged` and this file's own `n_values − qual_ok_n` must not disagree
      # (handoff delta 4): one warning for the build, never a silent pick
      unless (mis = mm.flag_mismatches.uniq).empty?
        Jekyll.logger.warn "measurements:",
                           "n_flagged disagrees with n_values − qual_ok_n on #{mis.size} row(s); " \
                           "the record wins, and the release must be fixed: #{mis.first(3).join('; ')}" \
                           "#{mis.size > 3 ? " (and #{mis.size - 3} more)" : ''}"
      end

      Jekyll.logger.info "measurements:",
                         "#{mm.measurements.size} pages · #{Fmt.num(mm.counts['series'])} series · " \
                         "#{mm.counts['datasets']} datasets · #{Fmt.num(mm.counts['obs_env_rows'])} values " \
                         "at the release grain from #{mm.release['version']} · inline #{site.data['measurements']['inline_kb']} KB"
    end

    def index_page(site, mm)
      page = Jekyll::PageWithoutAFile.new(site, site.source, "measurements", "index.html")
      page.content = ""
      page.data.merge!(
        "layout" => "measurements_index",
        "title"  => "Measurements · CalCOFI",
        "description" => "Every environmental measurement CalCOFI publishes — " \
                         "#{Fmt.num(mm.counts['measurements'])} measurements in #{Fmt.num(mm.counts['series'])} " \
                         "series across #{mm.counts['datasets']} datasets, keyed to one name and to its NERC P01 " \
                         "concept where one says exactly this."
      )
      page
    end

    def measurement_pages(site, mm, m)
      page = Jekyll::PageWithoutAFile.new(site, site.source, "measurements/#{m['slug']}", "index.html")
      page.content = ""
      page.data.merge!(
        "layout"      => "measurement",
        "title"       => "#{mm.heading(m)} · CalCOFI measurements",
        "description" => page_description(mm, m),
        "m"           => m,
        "key"         => m["key"],
        "slug"        => m["slug"],
        "h1"          => mm.heading(m),
        "sub"         => mm.subtitle(m),
        "no_label"    => mm.no_label?(m),
        "category"    => m.dig("category", "name"),
        "units"       => Fmt.units(m["units"]),
        "units_raw"   => Fmt.present(m["units"]),
        "is_unified"  => m["is_unified"],
        "ids"         => id_rows(mm, m),
        # the face (plan 2026-09-11 § D1–D7) — nil for a key with neither a `face` block in the
        # record nor an entry in the media sidecar, and the layout then draws the page it drew
        # before this existed
        "face"        => mm.face_of(m),
        "stats"       => mm.stat_rows(m),
        "flag_note"   => mm.flag_note(m),
        "ds_rows"     => mm.dataset_rows(m),
        "quality"     => mm.quality_rows(m),
        "related"     => mm.related_rows(m),
        "ways"        => mm.ways(m),
        "strip"       => JSON.generate(mm.strip_json(m)),
        "depth"       => JSON.generate(mm.depth_json(m)),
        "months"      => JSON.generate(mm.months_json(m)),
        "jsonld"      => JSON.pretty_generate(mm.jsonld(m))
      )
      [page, json_page(site, "/measurements/", "#{m['slug']}.json", JSON.pretty_generate(mm.raw(m["key"]) || m))]
    end

    # the ids, linked out to the vocabulary that defines them
    def id_rows(mm, m)
      rows = []
      if Fmt.present(m["nerc_p01"])
        rows << { "label" => "NERC P01", "id" => mm.nerc_id(m["nerc_p01"]), "url" => m["nerc_p01"] }
      end
      if Fmt.present(m["units_nerc_p06"])
        rows << { "label" => "P06 units", "id" => mm.nerc_id(m["units_nerc_p06"]), "url" => m["units_nerc_p06"],
                  "note" => Fmt.present(m["units"]) }
      end
      rows
    end

    # one sentence a search engine can show, every number from the record
    def page_description(mm, m)
      t = m["totals"] || {}
      bits = [mm.heading(m)]
      bits << m.dig("category", "name") if m.dig("category", "name")
      if t["n_values"]
        bits << "#{Fmt.num(t['n_values'])} values in #{t['n_datasets']} CalCOFI dataset#{'s' if t['n_datasets'].to_i != 1}"
      end
      bits << "#{t['year_min']}–#{t['year_max']}" if t["year_min"] && t["year_max"]
      "#{bits.join(' · ')} — CalCOFI integrated database #{mm.release['version']}."
    end

    def sitemap(mm)
      lastmod = mm.release["release_date"] || Time.now.utc.strftime("%Y-%m-%d")
      urls = [mm.abs("/measurements/")] + mm.measurements.map { |m| mm.abs(mm.page_url(m)) }
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
