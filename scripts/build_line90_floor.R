#!/usr/bin/env Rscript
# build_line90_floor.R — the sea floor under CalCOFI Line 90, for the landing page's section
# drawing (assets/section.js). One-off, like scripts/build_land.py: the output,
# _data/line90_floor.json, is COMMITTED — it is cartography, not a dataset fact — and this script
# is re-run only to change the interval or the extent.
#
#   Rscript scripts/build_line90_floor.R
#
# What it does (plan 2026-09-07 § D-9, Decision 6):
#   1. positions along Line 90 from station 130 (offshore) to station 0 (inland), one per station
#      unit, through PROJ's `calcofi` projection (x = line, y = station; Clarke 1866, the
#      projection's own datum) — the same positions the release's `grid` centroids resolve to
#      (checked 2026-09-07: st120-ln90 → −123.999, 30.418, identical to the record);
#   2. `calcofi4r::cc_transect_bathy()` samples GEBCO 2025 (sub-ice, 15 arc-second, positive-down,
#      land clamped to 0 — `cc_bathy()`) every 500 m BETWEEN those positions, on a ruler of station
#      units, so the profile lands on the drawing's own x-axis (12.5 px per station unit) and is
#      anchored at every station; ctd-transects draws its sections from the same call;
#   3. writes the profile as [station, depth_m] pairs — every 500 m sample kept (thinning is what
#      invents terrain: see ?cc_transect_bathy), stations to 2 decimals, depths to the metre — with
#      the coast (the first on-land sample from the sea side) recorded as `coast_station`.
#
# Land is clamped to 0 in the raster, so the profile carries no elevation: the headland the
# drawing raises above the surface east of `coast_station` is drawn, not measured, and
# assets/section.js says so where it draws it.

suppressPackageStartupMessages({
  library(calcofi4r)
  library(sf)
  library(jsonlite)
})

line       <- 90
st_from    <- 130          # offshore end: one station past the last standard cell (st120-ln90)
st_to      <- 0            # inland: the profile is cut at the coast, this only bounds the sampling
interval_m <- 500          # ?cc_transect_bathy: just above GEBCO's ~390 m cell
station_km <- 7.386        # 4 nmi per station unit (the calcofi projection's spacing), for the record
out        <- file.path(dirname(dirname(normalizePath(sub("--file=", "", grep("--file=", commandArgs(), value = TRUE)[1])))), "_data", "line90_floor.json")

stations <- seq(st_from, st_to, by = -1)
pts <- st_sfc(lapply(stations, function(s) st_point(c(line, s))), crs = "+proj=calcofi +ellps=clrk66 +no_defs") |>
  st_transform(4326) |>
  st_coordinates()

# the ruler runs offshore → coast, increasing: 0 at station 130, 130 at station 0
prof <- cc_transect_bathy(
  lon = pts[, "X"], lat = pts[, "Y"],
  dist_km    = st_from - stations,
  interval_m = interval_m)

prof$station <- st_from - prof$dist_km
stopifnot(!anyNA(prof$depth_m))       # a position outside the raster would be a bug in the extent

# cut at the coast: the first on-land sample from the sea side; keep that one sample so the path
# reaches 0 m exactly where the land begins
i_coast <- which(prof$on_land)[1]
stopifnot(!is.na(i_coast), i_coast > 1)
coast_station <- prof$station[i_coast]
keep <- prof[seq_len(i_coast), ]

deepest <- keep[which.max(keep$depth_m), ]
cat(sprintf("Line %d: %d samples at %d m from station %d to the coast at station %.2f (lon %.3f, lat %.3f); deepest %.0f m at station %.1f\n",
            line, nrow(keep), interval_m, st_from, coast_station, keep$lon[i_coast], keep$lat[i_coast],
            deepest$depth_m, deepest$station))

json <- list(
  line          = line,
  axis          = "station",
  station_km    = station_km,
  interval_m    = interval_m,
  built         = format(Sys.Date()),
  source        = paste0("GEBCO 2025 sub-ice bathymetry (calcofi4r::cc_bathy(), positive down, land 0) sampled along Line 90 by calcofi4r ",
                         as.character(packageVersion("calcofi4r")), "::cc_transect_bathy(interval_m = ", interval_m,
                         "); positions from PROJ +proj=calcofi (station 130 to the coast, one per station unit)"),
  coast_station = round(coast_station, 2),
  coast_lon     = round(keep$lon[i_coast], 3),
  coast_lat     = round(keep$lat[i_coast], 3),
  n             = nrow(keep),
  depth_max_m   = round(max(keep$depth_m)),
  # [station, depth_m], offshore first — the drawing reads it in this order
  profile       = lapply(seq_len(nrow(keep)), function(i) c(round(keep$station[i], 2), round(keep$depth_m[i]))))

writeLines(toJSON(json, auto_unbox = TRUE, digits = NA), out)
cat("wrote", out, "(", file.size(out), "bytes )\n")
