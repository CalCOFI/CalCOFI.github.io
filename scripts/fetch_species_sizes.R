#!/usr/bin/env Rscript
# fetch_species_sizes.R — sizes and early-life lengths for every species-rank taxon of
# _data/taxa.json, from FishBase (fish classes) or SeaLifeBase (everything else), via
# rfishbase. WS-F2b of the "Species faces" plan (§ F5, F7, § D3). Writes
# .cache/species-media/sizes.json, merged by WS-F2a's fetcher into taxa_media.json's
# `size` / `early` / `refs`.
#
# Never a guessed number, never a fuzzy match, never a genus-level average: a taxon that
# does not resolve to an accepted FishBase/SeaLifeBase name (directly, by synonym, or by a
# name a source dataset used) gets no entry at all — the slot stays absent, same as a taxon
# with no photo (D1/D6).
#
# Usage:
#   Rscript scripts/fetch_species_sizes.R [--out .cache/species-media/sizes.json] [--taxa _data/taxa.json]

librarian::shelf(rfishbase, dplyr, jsonlite, readr, quiet = TRUE)

# args ----------------------------------------------------------------------
args <- commandArgs(trailingOnly = TRUE)
opt  <- function(flag, default) {
  i <- which(args == flag)
  if (length(i) == 1 && i < length(args)) args[i + 1] else default
}
out_path  <- opt("--out",  ".cache/species-media/sizes.json")
taxa_path <- opt("--taxa", "_data/taxa.json")

t0 <- Sys.time()
`%||%` <- function(a, b) if (is.null(a)) b else a

# fish classes: FishBase; everything else (molluscs, crustaceans, birds, mammals,
# phytoplankton, …) at species rank: SeaLifeBase — including the dolphin (umbrella § Context)
fish_classes <- c("Actinopteri", "Actinopterygii", "Teleostei", "Elasmobranchii",
                   "Holocephali", "Myxini", "Petromyzonti")

fields <- c("SpecCode", "Species", "Length", "LTypeMaxM", "CommonLength")

# load taxa -------------------------------------------------------------------
if (!file.exists(taxa_path)) stop(sprintf("taxa.json not found at %s — run scripts/fetch_release.sh first", taxa_path))
taxa_doc <- jsonlite::fromJSON(taxa_path, simplifyVector = FALSE)
taxa     <- taxa_doc$taxa
cat(sprintf("%s: %d taxa (release %s)\n", taxa_path, length(taxa), taxa_doc$release$version %||% "?"))

is_species_rank <- function(r) {
  rk <- r$rank
  !is.null(rk) && rk %in% c("Species", "Subspecies", "Variety", "Forma")
}
rows <- Filter(is_species_rank, taxa)
cat(sprintf("%d taxa at Species/Subspecies/Variety/Forma rank\n", length(rows)))

server_for <- function(row) {
  cls <- row$lineage$class
  if (!is.null(cls) && cls %in% fish_classes) "fishbase" else "sealifebase"
}

# alternate names to try as a last resort: the names each contributing dataset used for
# this taxon (datasets[].sources[].name), distinct from the accepted scientific_name
alt_names_for <- function(row) {
  nm <- character(0)
  for (ds in row$datasets %||% list()) {
    for (src in ds$sources %||% list()) {
      if (!is.null(src$name) && !is.na(src$name)) nm <- c(nm, src$name)
    }
  }
  unique(setdiff(nm, row$scientific_name))
}

fish_rows <- Filter(function(r) server_for(r) == "fishbase",    rows)
sl_rows   <- Filter(function(r) server_for(r) == "sealifebase", rows)
cat(sprintf("fish (class in %s) -> FishBase: %d\n", paste(fish_classes, collapse = ", "), length(fish_rows)))
cat(sprintf("non-fish -> SeaLifeBase: %d\n", length(sl_rows)))

# resolve one server's block of taxa to an accepted name ---------------------------------
# returns a data.frame: taxon_key, server, spec_code, name_matched, match_method
resolve_block <- function(taxon_rows, server) {
  if (length(taxon_rows) == 0) {
    return(data.frame(taxon_key = character(0), server = character(0), spec_code = integer(0),
                       name_matched = character(0), match_method = character(0)))
  }
  wanted_names <- vapply(taxon_rows, function(r) r$scientific_name %||% NA_character_, character(1))

  # pass 1 — accepted name, one batch call
  sp <- tryCatch(
    as.data.frame(rfishbase::species(unique(stats::na.omit(wanted_names)), fields = fields, server = server)),
    error = function(e) { cat(sprintf("ERROR rfishbase::species(server=%s): %s\n", server, conditionMessage(e))); NULL }
  )
  if (is.null(sp)) stop(sprintf("rfishbase::species() failed for server=%s — parquet download or schema issue, stopping", server))
  expected_cols <- c("SpecCode", "Species", "Length", "LTypeMaxM", "CommonLength")
  missing_cols  <- setdiff(expected_cols, names(sp))
  if (length(missing_cols) > 0) {
    stop(sprintf("rfishbase::species(server=%s) schema differs: missing column(s) %s (columns present: %s)",
                  server, paste(missing_cols, collapse = ", "), paste(names(sp), collapse = ", ")))
  }
  accepted_idx <- setNames(seq_len(nrow(sp)), sp$Species)

  out <- vector("list", length(taxon_rows))
  unresolved <- list()
  for (i in seq_along(taxon_rows)) {
    r  <- taxon_rows[[i]]
    nm <- r$scientific_name
    if (!is.null(nm) && !is.na(nm) && nm %in% names(accepted_idx)) {
      j <- accepted_idx[[nm]]
      out[[i]] <- data.frame(taxon_key = r$taxon_key, server = server, spec_code = sp$SpecCode[j],
                              name_matched = sp$Species[j], match_method = "accepted", stringsAsFactors = FALSE)
    } else {
      unresolved[[length(unresolved) + 1]] <- r
    }
  }
  n_direct <- sum(!vapply(out, is.null, logical(1)))
  cat(sprintf("  [%s] accepted-name match: %d / %d\n", server, n_direct, length(taxon_rows)))

  # pass 2 — synonym table, one batch call
  if (length(unresolved) > 0) {
    unres_names <- vapply(unresolved, function(r) r$scientific_name %||% NA_character_, character(1))
    syn <- tryCatch(as.data.frame(rfishbase::synonyms(unique(stats::na.omit(unres_names)), server = server)),
                     error = function(e) NULL)
    still_unresolved <- list()
    if (!is.null(syn) && nrow(syn) > 0 && all(c("synonym", "Species", "SpecCode") %in% names(syn))) {
      syn_ok  <- syn[!is.na(syn$Species) & !is.na(syn$SpecCode), c("synonym", "Species", "SpecCode")]
      syn_map <- setNames(seq_len(nrow(syn_ok)), syn_ok$synonym)
      for (r in unresolved) {
        nm <- r$scientific_name
        if (!is.null(nm) && !is.na(nm) && nm %in% names(syn_map)) {
          j <- syn_map[[nm]]
          out[[length(out) + 1]] <- NULL  # placeholder; appended below by taxon_key match instead
          idx <- which(vapply(taxon_rows, function(x) identical(x$taxon_key, r$taxon_key), logical(1)))
          out[[idx]] <- data.frame(taxon_key = r$taxon_key, server = server, spec_code = syn_ok$SpecCode[j],
                                    name_matched = syn_ok$Species[j], match_method = "synonym", stringsAsFactors = FALSE)
        } else {
          still_unresolved[[length(still_unresolved) + 1]] <- r
        }
      }
    } else {
      still_unresolved <- unresolved
    }
    unresolved <- still_unresolved
    n_syn <- sum(!vapply(out, is.null, logical(1)))
    cat(sprintf("  [%s] + synonym match: %d cumulative / %d\n", server, n_syn, length(taxon_rows)))
  }

  # pass 3 — dataset source names, one taxon at a time (small residual set): accepted, then synonym
  if (length(unresolved) > 0) {
    still_unresolved <- list()
    for (r in unresolved) {
      idx   <- which(vapply(taxon_rows, function(x) identical(x$taxon_key, r$taxon_key), logical(1)))
      found <- FALSE
      for (nm in alt_names_for(r)) {
        sp2 <- tryCatch(as.data.frame(rfishbase::species(nm, fields = fields, server = server)), error = function(e) NULL)
        if (!is.null(sp2) && nrow(sp2) > 0) {
          out[[idx]] <- data.frame(taxon_key = r$taxon_key, server = server, spec_code = sp2$SpecCode[1],
                                    name_matched = sp2$Species[1], match_method = "accepted (source name)", stringsAsFactors = FALSE)
          found <- TRUE; break
        }
        syn2 <- tryCatch(as.data.frame(rfishbase::synonyms(nm, server = server)), error = function(e) NULL)
        if (!is.null(syn2) && nrow(syn2) > 0 && "Species" %in% names(syn2) && !is.na(syn2$Species[1])) {
          out[[idx]] <- data.frame(taxon_key = r$taxon_key, server = server, spec_code = syn2$SpecCode[1],
                                    name_matched = syn2$Species[1], match_method = "synonym (source name)", stringsAsFactors = FALSE)
          found <- TRUE; break
        }
      }
      if (!found) still_unresolved[[length(still_unresolved) + 1]] <- r
    }
    unresolved <- still_unresolved
    n_src <- sum(!vapply(out, is.null, logical(1)))
    cat(sprintf("  [%s] + source-name match: %d cumulative / %d\n", server, n_src, length(taxon_rows)))
  }

  unmatched_names <- vapply(unresolved, function(r) sprintf("%s (%s)", r$scientific_name %||% "NA", r$taxon_key), character(1))
  if (length(unmatched_names) > 0) {
    cat(sprintf("  [%s] unmatched (%d): %s\n", server, length(unmatched_names),
                paste(unmatched_names, collapse = "; ")))
  }

  do.call(rbind, c(out[!vapply(out, is.null, logical(1))],
                    list(data.frame(taxon_key = character(0), server = character(0), spec_code = integer(0),
                                     name_matched = character(0), match_method = character(0)))))
}

fish_matches <- resolve_block(fish_rows, "fishbase")
sl_matches   <- resolve_block(sl_rows,   "sealifebase")
matches      <- rbind(fish_matches, sl_matches)
cat(sprintf("total matched: %d / %d (%.1f%%)\n", nrow(matches), length(rows), 100 * nrow(matches) / length(rows)))

# fetch length fields for every matched accepted name, one batch call per server ---------
fetch_fields <- function(names_matched, server) {
  if (length(names_matched) == 0) return(data.frame())
  as.data.frame(rfishbase::species(unique(names_matched), fields = fields, server = server))
}
fish_fields <- fetch_fields(matches$name_matched[matches$server == "fishbase"],    "fishbase")
sl_fields   <- fetch_fields(matches$name_matched[matches$server == "sealifebase"], "sealifebase")

# fetch eggs / larvae / refrens tables once per server, for the matched spec codes only ---
fish_codes <- matches$spec_code[matches$server == "fishbase"]
sl_codes   <- matches$spec_code[matches$server == "sealifebase"]

first_richest <- function(df, code_col, rank_cols) {
  # one row per code: prefer the row with the fewest NAs among rank_cols
  if (nrow(df) == 0) return(df)
  df$.n_na <- rowSums(is.na(df[rank_cols]))
  df <- df[order(df[[code_col]], df$.n_na), ]
  df[!duplicated(df[[code_col]]), setdiff(names(df), ".n_na")]
}

fetch_eggs <- function(codes, server) {
  if (length(codes) == 0) return(data.frame())
  eg <- as.data.frame(rfishbase::fb_tbl("eggs", server = server))
  eg <- eg[eg$Speccode %in% codes, c("Speccode", "Eggdiammin", "Eggdiammax", "EggsRefNo")]
  first_richest(eg, "Speccode", c("Eggdiammin", "Eggdiammax"))
}
fetch_larvae <- function(codes, server) {
  if (length(codes) == 0) return(data.frame())
  lv <- as.data.frame(rfishbase::fb_tbl("larvae", server = server))
  cols <- c("SpecCode", "LhMin", "LhMax", "FlexLengthMin", "FlexLengthMax",
            "TransLengthMin", "TransLengthMax", "LarvaeRefNo")
  lv <- lv[lv$SpecCode %in% codes, cols]
  first_richest(lv, "SpecCode", c("LhMin", "LhMax", "FlexLengthMin", "FlexLengthMax", "TransLengthMin", "TransLengthMax"))
}
fetch_refs <- function(refnos, server) {
  refnos <- unique(stats::na.omit(refnos))
  if (length(refnos) == 0) return(data.frame())
  rf <- as.data.frame(rfishbase::fb_tbl("refrens", server = server))
  rf <- rf[rf$RefNo %in% refnos, c("RefNo", "Author", "Year", "Title")]
  rf[!duplicated(rf$RefNo), ]
}

fish_eggs   <- fetch_eggs(fish_codes, "fishbase")
fish_larvae <- fetch_larvae(fish_codes, "fishbase")
sl_eggs     <- fetch_eggs(sl_codes, "sealifebase")
sl_larvae   <- fetch_larvae(sl_codes, "sealifebase")

format_ref <- function(author, year, title) {
  author <- trimws(author %||% "")
  author <- sub(",\\s*$", "", author)
  title  <- trimws(title %||% "")
  if (nchar(title) > 0 && !grepl("\\.$", title)) title <- paste0(title, ".")
  y <- if (is.na(year) || is.null(year)) "" else as.character(year)
  parts <- Filter(function(x) nchar(x) > 0, c(author, y, title))
  paste(parts, collapse = ". ")
}

fish_refs <- fetch_refs(c(fish_eggs$EggsRefNo, fish_larvae$LarvaeRefNo), "fishbase")
sl_refs   <- fetch_refs(c(sl_eggs$EggsRefNo, sl_larvae$LarvaeRefNo), "sealifebase")

ref_lookup <- list()
for (df in list(fish_refs, sl_refs)) {
  if (nrow(df) == 0) next
  for (i in seq_len(nrow(df))) {
    ref_lookup[[as.character(df$RefNo[i])]] <- format_ref(df$Author[i], df$Year[i], df$Title[i])
  }
}

# range helper: both bounds present, else NULL (never a half-guessed range) -------------
mm_range <- function(lo, hi) {
  if (is.null(lo) || is.null(hi) || is.na(lo) || is.na(hi)) return(NULL)
  list(unbox_num(lo), unbox_num(hi))
}
unbox_num <- function(x) jsonlite::unbox(as.numeric(x))
null_or <- function(x) if (is.null(x) || is.na(x)) NULL else jsonlite::unbox(x)

# assemble the sidecar --------------------------------------------------------------------
entries <- list()
n_with_length <- 0
n_with_early  <- 0

for (i in seq_len(nrow(matches))) {
  m <- matches[i, ]
  server <- m$server
  fields_tbl <- if (server == "fishbase") fish_fields else sl_fields
  eggs_tbl   <- if (server == "fishbase") fish_eggs   else sl_eggs
  larvae_tbl <- if (server == "fishbase") fish_larvae else sl_larvae

  frow <- fields_tbl[fields_tbl$Species == m$name_matched, ]
  frow <- frow[!duplicated(frow$Species), ]
  length_cm        <- if (nrow(frow) == 1) frow$Length[1]        else NA
  length_type       <- if (nrow(frow) == 1) frow$LTypeMaxM[1]     else NA
  common_length_cm  <- if (nrow(frow) == 1) frow$CommonLength[1]  else NA

  erow <- eggs_tbl[eggs_tbl$Speccode == m$spec_code, ]
  lrow <- larvae_tbl[larvae_tbl$SpecCode == m$spec_code, ]

  egg_mm  <- if (nrow(erow) == 1) mm_range(erow$Eggdiammin[1], erow$Eggdiammax[1]) else NULL
  hatch_mm <- if (nrow(lrow) == 1) mm_range(lrow$LhMin[1], lrow$LhMax[1]) else NULL
  flexion_mm <- if (nrow(lrow) == 1) mm_range(lrow$FlexLengthMin[1], lrow$FlexLengthMax[1]) else NULL
  transformation_mm <- if (nrow(lrow) == 1) mm_range(lrow$TransLengthMin[1], lrow$TransLengthMax[1]) else NULL

  refs_used <- list()
  if (!is.null(egg_mm) && nrow(erow) == 1 && !is.na(erow$EggsRefNo[1])) {
    rn <- as.character(erow$EggsRefNo[1])
    if (!is.null(ref_lookup[[rn]])) refs_used[[rn]] <- jsonlite::unbox(ref_lookup[[rn]])
  }
  if ((!is.null(hatch_mm) || !is.null(flexion_mm) || !is.null(transformation_mm)) &&
      nrow(lrow) == 1 && !is.na(lrow$LarvaeRefNo[1])) {
    rn <- as.character(lrow$LarvaeRefNo[1])
    if (!is.null(ref_lookup[[rn]])) refs_used[[rn]] <- jsonlite::unbox(ref_lookup[[rn]])
  }

  has_length <- !is.na(length_cm)
  has_early  <- !is.null(egg_mm) || !is.null(hatch_mm) || !is.null(flexion_mm) || !is.null(transformation_mm)
  if (has_length) n_with_length <- n_with_length + 1
  if (has_early)  n_with_early  <- n_with_early + 1

  entries[[m$taxon_key]] <- list(
    server            = jsonlite::unbox(server),
    spec_code         = jsonlite::unbox(as.integer(m$spec_code)),
    name_matched      = jsonlite::unbox(m$name_matched),
    length_cm         = null_or(length_cm),
    length_type       = null_or(length_type),
    common_length_cm  = null_or(common_length_cm),
    egg_mm            = egg_mm,
    hatch_mm          = hatch_mm,
    flexion_mm        = flexion_mm,
    transformation_mm = transformation_mm,
    refs              = if (length(refs_used) > 0) refs_used else structure(list(), names = character(0))
  )
}

entries <- entries[sort(names(entries))]

runtime_s <- as.numeric(difftime(Sys.time(), t0, units = "secs"))

# write ----------------------------------------------------------------------
dir.create(dirname(out_path), recursive = TRUE, showWarnings = FALSE)
jsonlite::write_json(entries, out_path, auto_unbox = FALSE, pretty = TRUE, na = "null", null = "null")
cat(sprintf("\nwrote %s (%d taxa)\n", out_path, length(entries)))

# measured summary -------------------------------------------------------------------
n_fish     <- length(fish_rows)
n_nonfish  <- length(sl_rows)
n_matched_accepted <- sum(matches$match_method == "accepted")
n_matched_synonym  <- sum(matches$match_method %in% c("synonym", "synonym (source name)"))
n_matched_source   <- sum(matches$match_method %in% c("accepted (source name)", "synonym (source name)"))
n_unmatched <- length(rows) - nrow(matches)
n_fish_matched <- sum(matches$server == "fishbase")
fish_match_pct <- if (n_fish > 0) 100 * n_fish_matched / n_fish else NA

cat("\n== measured ==\n")
cat(sprintf("species-rank taxa: %d (fish %d, non-fish %d)\n", length(rows), n_fish, n_nonfish))
cat(sprintf("matched: %d (accepted-name %d, synonym %d, dataset-source-name %d), unmatched: %d\n",
            nrow(matches), n_matched_accepted, n_matched_synonym, n_matched_source, n_unmatched))
cat(sprintf("fish match rate: %d / %d = %.1f%%\n", n_fish_matched, n_fish, fish_match_pct))
cat(sprintf("with a length: %d, with any early-life length: %d\n", n_with_length, n_with_early))
cat(sprintf("runtime: %.1f s\n", runtime_s))

if (!is.na(fish_match_pct) && fish_match_pct < 60) {
  stop(sprintf("GATE: fish match rate %.1f%% is below 60%% — stopping (see unmatched list above)", fish_match_pct))
}
