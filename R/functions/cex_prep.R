# ---------------------------------------------------------------------------
# R/functions/cex_prep.R
#
# Shared CEX preparation used by 02_build_shares.R and 04_adjusted_passes.R.
# Kept in one place so the gasoline splice and the additivity contract cannot
# drift between scripts.
# ---------------------------------------------------------------------------

SPLICE_YEAR <- 2023L

#' Apply the taxonomy's spliced-series rewrites.
#'
#' GASOIL ("Gasoline, other fuels, and motor oil", 1984-2022) becomes
#' GASFUEL ("Gasoline and other fuels", 2023-) for pre-splice years. 2023 is a
#' switch, not an overlap: GASOIL collapses to ~$1/CU that year. The old code is
#' dropped afterwards so it can never be double counted. See decisions_log D-05.
#'
#' @param d Long CEX frame with year, item_code, value.
#' @param tax Taxonomy tibble with cex_item_code, cex_item_code_pre2023.
#' @param verbose Print the splice diagnostics.
cex_apply_splices <- function(d, tax, verbose = TRUE) {
  sp <- tax[!is.na(tax$cex_item_code_pre2023), c("cex_item_code", "cex_item_code_pre2023")]
  for (i in seq_len(nrow(sp))) {
    new <- sp$cex_item_code[i]; old <- sp$cex_item_code_pre2023[i]
    if (verbose) {
      ov <- d[d$item_code %in% c(new, old) &
              d$year %in% c(SPLICE_YEAR - 1L, SPLICE_YEAR), ]
      agg <- stats::aggregate(value ~ year + item_code, ov, sum, na.rm = TRUE)
      message("  splice ", old, " -> ", new, " at ", SPLICE_YEAR, ":")
      for (j in seq_len(nrow(agg))) {
        message("    ", agg$year[j], " ", agg$item_code[j], " = ", round(agg$value[j]))
      }
    }
    d$item_code[d$item_code == old & d$year < SPLICE_YEAR] <- new
    d <- d[d$item_code != old, , drop = FALSE]
  }
  d
}

#' Pull the EXPEND panel for one CEX demographic dimension.
#'
#' Returns only the taxonomy's 41 categories plus TOTALEXP, splices applied.
cex_expend_panel <- function(cex, tax, demographics_code, characteristics_codes = NULL,
                             verbose = TRUE) {
  d <- cex |>
    dplyr::filter(category_code == "EXPEND",
                  .data$demographics_code == !!demographics_code) |>
    dplyr::select(year, characteristics_code, item_code, value)
  if (!is.null(characteristics_codes)) {
    d <- dplyr::filter(d, characteristics_code %in% characteristics_codes)
  }
  d <- cex_apply_splices(d, tax, verbose = verbose)
  dplyr::filter(d, item_code %in% c(tax$cex_item_code, "TOTALEXP"))
}

#' Assert the 41 categories partition TOTALEXP for every year x group.
#'
#' Stops on failure. Tolerance is in percent of TOTALEXP and covers BLS dollar
#' rounding. See decisions_log D-04.
cex_assert_additive <- function(d, tax, tol_pct = 0.25, label = "") {
  w <- tidyr::pivot_wider(d, id_cols = c(year, characteristics_code),
                          names_from = item_code, values_from = value)
  missing <- setdiff(tax$cex_item_code, names(w))
  if (length(missing)) {
    stop("[", label, "] taxonomy codes absent from extract: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  cs <- rowSums(as.matrix(w[, tax$cex_item_code]), na.rm = TRUE)
  dp <- 100 * (cs - w$TOTALEXP) / w$TOTALEXP
  bad <- which(abs(dp) > tol_pct)
  if (length(bad)) {
    stop("[", label, "] additivity failed in ", length(bad), " of ", nrow(w),
         " year x group cells. Worst: ", sprintf("%.3f%%", max(abs(dp))),
         " at ", w$year[bad[which.max(abs(dp[bad]))]], " group ",
         w$characteristics_code[bad[which.max(abs(dp[bad]))]], call. = FALSE)
  }
  message("  additivity OK [", label, "]: ", nrow(w), " cells, worst ",
          sprintf("%.3f%%", max(abs(dp))))
  invisible(max(abs(dp)))
}

#' Shares on an arbitrary category subset, renormalized to sum to 100.
#'
#' @param d Long frame with year, characteristics_code, item_code, value.
#' @param keep_codes CEX item codes forming the basket (the denominator).
cex_shares_on_base <- function(d, keep_codes) {
  b <- dplyr::filter(d, item_code %in% keep_codes)
  b |>
    dplyr::mutate(base = sum(value, na.rm = TRUE),
                  .by = c(year, characteristics_code)) |>
    dplyr::mutate(share = 100 * value / base)
}

#' Repair the all-consumer-units series using an equivalent CEX dimension.
#'
#' BLS does not publish LB06 (composition of consumer unit) "All Consumer
#' Units" for 2010-2013: all 42 items are absent for those four years, while
#' every other demographic dimension carries them. The "01" characteristic is
#' the same universe in every dimension, so the series are interchangeable.
#'
#' That is verified here rather than assumed: across 1,555 item-year overlaps
#' the maximum absolute difference between LB06/01 and LB04/01 is exactly 0.
#' The function asserts this on the actual data and stops if it ever fails.
#'
#' See decisions_log D-23.
#'
#' @param cex Full CEX frame from getBLSFiles.
#' @param d Long frame already filtered to one dimension, with columns
#'   year, characteristics_code, item_code, value.
#' @param fallback_dim Dimension to borrow the all-CU series from.
cex_repair_all_cu <- function(cex, d, fallback_dim = "LB04", verbose = TRUE) {
  fb <- cex |>
    dplyr::filter(category_code == "EXPEND",
                  demographics_code == fallback_dim,
                  characteristics_code == "01") |>
    dplyr::select(year, characteristics_code, item_code, value)

  have <- dplyr::filter(d, characteristics_code == "01")
  # Nothing to repair, and nothing to verify against, when the caller did not
  # request the all-CU group at all. Returning unchanged is correct here; the
  # assertion below only makes sense when there is an overlap to test.
  if (!nrow(have)) {
    if (verbose) message("  all-CU repair skipped: no '01' rows in this pull")
    return(d)
  }
  ov <- dplyr::inner_join(
    dplyr::select(have, year, item_code, v_main = value),
    dplyr::select(fb, year, item_code, v_fb = value),
    by = c("year", "item_code")) |>
    dplyr::filter(!is.na(v_main), !is.na(v_fb))
  if (!nrow(ov)) stop("No overlap to verify the all-CU fallback against.", call. = FALSE)
  worst <- max(abs(ov$v_main - ov$v_fb))
  if (worst > 0) {
    stop("All-CU series differ between dimensions by up to ", worst,
         " over ", nrow(ov), " item-years. They are not interchangeable; ",
         "do not substitute.", call. = FALSE)
  }
  if (verbose) {
    message("  all-CU fallback verified against ", fallback_dim, ": ",
            nrow(ov), " item-year overlaps, max difference ", worst)
  }

  # Add only the year-item cells the main dimension is missing.
  add <- dplyr::anti_join(fb, dplyr::select(have, year, item_code),
                          by = c("year", "item_code"))
  add <- dplyr::filter(add, year %in% unique(d$year))
  if (nrow(add) && verbose) {
    yrs <- sort(unique(add$year))
    message("  filled ", nrow(add), " all-CU cells from ", fallback_dim,
            " for year(s): ", paste(yrs, collapse = ", "))
  }
  dplyr::bind_rows(d, add)
}

#' Assert no group has an INTERIOR gap in its year panel.
#'
#' Groups legitimately start at different years (married-with-children begins
#' 1988, the others 1984), so a common-span test would fire spuriously. What is
#' never legitimate is a hole inside a group's own first-to-last range.
#'
#' Additivity checks only cells that EXIST, so an absent year x group cell
#' passes it silently. That is how the LB06 all-CU 2010-2013 hole survived
#' Phase 1 undetected and only surfaced when the index tried to fetch a weight
#' vintage four phases later. See decisions_log D-23.
cex_assert_no_interior_gaps <- function(d, label = "") {
  cells <- unique(d[, c("year", "characteristics_code")])
  bad <- list()
  for (g in sort(unique(cells$characteristics_code))) {
    y <- sort(unique(cells$year[cells$characteristics_code == g]))
    miss <- setdiff(seq(min(y), max(y)), y)
    if (length(miss)) bad[[g]] <- miss
  }
  if (length(bad)) {
    msg <- paste(vapply(names(bad), function(g)
      paste0("group ", g, ": ", paste(bad[[g]], collapse = ", ")),
      character(1)), collapse = " | ")
    stop("[", label, "] interior gap(s) in the year panel. ", msg, call. = FALSE)
  }
  spans <- vapply(sort(unique(cells$characteristics_code)), function(g) {
    y <- cells$year[cells$characteristics_code == g]
    paste0(g, ":", min(y), "-", max(y))
  }, character(1))
  message("  no interior year gaps [", label, "]: ",
          paste(spans, collapse = ", "))
  invisible(TRUE)
}
