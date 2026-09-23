# ---------------------------------------------------------------------------
# 01_download_data.R
#
# Downloads and caches the two BLS flat-file surveys this project needs.
# Caching is deliberate: the CEX main file is ~121 MB and BLS asks that users
# not re-pull large files unnecessarily. Delete data/raw/*.rds to force a
# refresh, or set FORCE_REFRESH = TRUE below.
#
# Sources (verified 2026-09-08):
#   CEX  https://download.bls.gov/pub/time.series/cx/   (prefix cx)
#   CPI  https://download.bls.gov/pub/time.series/cu/   (prefix cu)
#
# Outputs:
#   data/raw/cex_raw.rds       CEX annual means, all series, joined metadata
#   data/raw/cpi_raw.rds       CPI-U monthly indices, joined metadata + weights
#   data/raw/cx_item.rds       CEX item hierarchy (item_code, text, level)
#   data/raw/cx_characteristics.rds
#   data/raw/download_manifest.txt   file sizes and BLS modified timestamps
# ---------------------------------------------------------------------------

# Run from the project root: Rscript R/01_download_data.R
source("R/00_setup.R")

FORCE_REFRESH <- FALSE

cache <- function(name, expr) {
  path <- file.path(DIR_RAW, paste0(name, ".rds"))
  if (file.exists(path) && !FORCE_REFRESH) {
    message("Cache hit: ", name, ".rds (", round(file.size(path) / 1e6, 1), " MB)")
    return(readRDS(path))
  }
  message("Building: ", name)
  obj <- force(expr)
  saveRDS(obj, path, compress = "xz")
  message("Cached: ", path, " (", round(file.size(path) / 1e6, 1), " MB)")
  obj
}

# --- Record what BLS is serving right now ----------------------------------
# The manifest is the audit trail for the data vintage. BLS overwrites these
# files in place, so byte counts and modified stamps are the only version info.
# Written only when the main caches are (re)built. Rewriting it on a cache hit
# would stamp today's BLS listing onto data pulled on an earlier date.
main_cached <- all(file.exists(file.path(DIR_RAW, c("cex_raw.rds", "cpi_raw.rds"))))
if (FORCE_REFRESH || !main_cached) {
  manifest <- dplyr::bind_rows(
    dplyr::mutate(tidyusmacro:::bls_list_files("cx", BLS_EMAIL), survey = "cx"),
    dplyr::mutate(tidyusmacro:::bls_list_files("cu", BLS_EMAIL), survey = "cu"),
    dplyr::mutate(tidyusmacro:::bls_list_files("cw", BLS_EMAIL), survey = "cw")
  )
  writeLines(
    c(paste0("# BLS download manifest, captured ", VINTAGE),
      "",
      capture.output(print(as.data.frame(manifest[, c("survey", "file", "bytes", "modified")]),
                           right = FALSE, row.names = FALSE))),
    file.path(DIR_RAW, "download_manifest.txt")
  )
  message("Manifest written.")
} else {
  message("Main caches present; download_manifest.txt left as the record of their vintage.")
}

# --- CEX dimension files (small, always refreshed) --------------------------
# Fetched directly rather than through getBLSFiles because we need the item
# display_level, which the series join does not carry.
bls_tsv <- function(prefix, stem) {
  url <- paste0("https://download.bls.gov/pub/time.series/", prefix, "/", prefix, ".", stem)
  tmp <- tempfile(fileext = ".tsv")
  on.exit(unlink(tmp), add = TRUE)
  tidyusmacro:::bls_get(url, BLS_EMAIL, dest = tmp)
  readr::read_tsv(tmp, col_types = readr::cols(.default = readr::col_character())) |>
    dplyr::mutate(dplyr::across(dplyr::everything(), trimws))
}

cx_item <- bls_tsv("cx", "item") |>
  dplyr::transmute(subcategory_code, item_code,
                   item_text, display_level = as.integer(display_level),
                   sort_sequence = as.integer(sort_sequence))
saveRDS(cx_item, file.path(DIR_RAW, "cx_item.rds"))

cx_char <- bls_tsv("cx", "characteristics") |>
  dplyr::transmute(demographics_code, characteristics_code, characteristics_text,
                   display_level = as.integer(display_level))
saveRDS(cx_char, file.path(DIR_RAW, "cx_characteristics.rds"))

cu_item <- bls_tsv("cu", "item") |>
  dplyr::transmute(item_code, item_name, display_level = as.integer(display_level),
                   sort_sequence = as.integer(sort_sequence))
saveRDS(cu_item, file.path(DIR_RAW, "cu_item.rds"))

message("Dimension files cached: cx.item (", nrow(cx_item), " rows), ",
        "cx.characteristics (", nrow(cx_char), "), cu.item (", nrow(cu_item), ")")

# --- Main data files -------------------------------------------------------
# include_averages = TRUE is required for CEX: it publishes only A01 annual
# rows, so dropping "averages" would empty the frame.
cex_raw <- cache("cex_raw", getBLSFiles("cex", email = BLS_EMAIL,
                                        include_averages = TRUE, max_mb = 200))

# weights = TRUE attaches aspect_type "I" relative importance. Not used in
# Phase 1 but pulled here so the validation step in 03 does not re-download.
cpi_raw <- cache("cpi_raw", getBLSFiles("cpi", email = BLS_EMAIL,
                                        weights = TRUE, include_averages = TRUE,
                                        max_mb = 100))

# CPI-W item indices, for the price-input robustness run in 09_robustness.R.
# C-CPI-U (su) is NOT pulled: it publishes ~30 aggregate series and none of
# the item strata the crosswalk needs, so it cannot serve as a price input.
cpiw_raw <- cache("cpiw_raw", getBLSFiles("cpi_w", email = BLS_EMAIL,
                                          weights = FALSE, include_averages = TRUE,
                                          max_mb = 100))
writeLines(c(paste0("cpiw_raw pulled or verified: ", VINTAGE),
             paste0("date range: ", min(cpiw_raw$date, na.rm = TRUE), " to ",
                    max(cpiw_raw$date, na.rm = TRUE))),
           file.path(DIR_RAW, "cpiw_vintage.txt"))

# --- CE published tables with standard errors ------------------------------
# The flat files carry means only (cx.process has one code, M). BLS publishes
# standard errors, and the estimated rental value of owned homes, in the
# calendar-year "mean, share, standard error" workbooks. Those supply
#   (a) sampling error on the weight vectors (06_build_index.R, section 2c)
#   (b) a rental-equivalence weight for owners' equivalent rent (scope_cpi_b)
# Available from 2012. See decisions_log D-28, D-29.
DIR_CET <- file.path(DIR_RAW, "ce_tables")
dir.create(DIR_CET, showWarnings = FALSE)
CE_TABLES <- c(LB06 = "cu-composition", LB17 = "cu-housing-tenure",
               LB01 = "cu-income-quintiles-before-taxes",
               LB15 = "cu-income-deciles-before-taxes", LB05 = "cu-size")
CE_TABLE_YEARS <- 2012:2024
n_new <- 0L
for (stem in CE_TABLES) {
  for (y in CE_TABLE_YEARS) {
    dest <- file.path(DIR_CET, sprintf("%s-%d.xlsx", stem, y))
    if (file.exists(dest) && !FORCE_REFRESH) next
    url <- sprintf(paste0("https://www.bls.gov/cex/tables/calendar-year/",
                          "mean-item-share-average-standard-error/%s-%d.xlsx"), stem, y)
    ok <- tryCatch({ tidyusmacro:::bls_get(url, BLS_EMAIL, dest = dest); TRUE },
                   error = function(e) { message("  not published: ", basename(url)); FALSE })
    # httr writes the body to disk before the status check, so a 404 leaves an
    # HTML page named .xlsx behind. Remove it or it poisons the cache.
    if (!ok) unlink(dest)
    if (ok) n_new <- n_new + 1L
    Sys.sleep(0.5)  # BLS asks for polite request rates
  }
}
have <- list.files(DIR_CET, pattern = "\\.xlsx$")
message("CE standard-error tables: ", length(have), " cached (", n_new, " downloaded this run)")
# BLS does not publish every table for every year in this series: housing
# tenure starts 2019 and income deciles 2014. Composition (LB06) carries the
# headline and must be complete.
need <- sprintf("%s-%d.xlsx", CE_TABLES[["LB06"]], CE_TABLE_YEARS)
if (length(setdiff(need, have))) {
  stop("Missing LB06 CE tables: ", paste(setdiff(need, have), collapse = ", "), call. = FALSE)
}
for (stem in CE_TABLES) {
  yrs <- as.integer(sub(".*-(\\d{4})\\.xlsx$", "\\1", grep(paste0("^", stem, "-\\d{4}"), have, value = TRUE)))
  message(sprintf("  %-36s %d-%d (%d files)", stem, min(yrs), max(yrs), length(yrs)))
}

# --- Loud diagnostics ------------------------------------------------------
message("\n=== CEX ===")
message("rows: ", format(nrow(cex_raw), big.mark = ","))
message("years: ", min(cex_raw$year, na.rm = TRUE), "-", max(cex_raw$year, na.rm = TRUE))
message("cols: ", paste(names(cex_raw), collapse = ", "))

message("\n=== CPI ===")
message("rows: ", format(nrow(cpi_raw), big.mark = ","))
message("date range: ", as.character(min(cpi_raw$date, na.rm = TRUE)), " to ",
        as.character(max(cpi_raw$date, na.rm = TRUE)))
message("cols: ", paste(names(cpi_raw), collapse = ", "))
message("\nDone. Vintage ", VINTAGE)
