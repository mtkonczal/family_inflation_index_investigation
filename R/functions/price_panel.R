# ---------------------------------------------------------------------------
# R/functions/price_panel.R
#
# Category price panel from any national monthly CPI item series. The same
# construction as 05_build_crosswalk.R section 5 (publication grid, log-linear
# interpolation of thin series inside their own window, RI-weighted chained
# composites), packaged so 09_robustness.R can swap the price INPUT (CPI-W,
# seasonally adjusted CPI-U) while holding everything else fixed.
#
# 09_robustness.R first rebuilds the baseline NSA CPI-U panel with this
# function and stops unless it matches data/derived/cpi_category_index.csv, so
# the two implementations cannot drift apart silently.
# ---------------------------------------------------------------------------

#' @param series Frame: item_code, date, idx (one national monthly series per item).
#' @param ri_obs Frame: item_code, date, ri (CPI-U relative importance; NA allowed).
#' @param mapped Crosswalk rows with cat_id, cpi_item_code (mapped only).
#' @param pub_months Dates on the publication grid.
#' @return Frame: cat_id, date, index.
build_category_prices <- function(series, ri_obs, mapped, pub_months) {
  obs <- series |>
    dplyr::filter(item_code %in% mapped$cpi_item_code, date %in% pub_months, !is.na(idx))
  grid <- obs |>
    dplyr::summarise(first = min(date), last = max(date), .by = item_code) |>
    dplyr::rowwise() |>
    dplyr::reframe(item_code = item_code,
                   date = pub_months[pub_months >= first & pub_months <= last])
  comp <- grid |>
    dplyr::left_join(obs, by = c("item_code", "date")) |>
    dplyr::arrange(item_code, date) |>
    dplyr::group_by(item_code) |>
    dplyr::mutate(observed = !is.na(idx),
                  idx = exp(stats::approx(x = seq_along(idx)[observed], y = log(idx[observed]),
                                          xout = seq_along(idx), rule = 1)$y)) |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(idx))
  comp <- comp |>
    dplyr::left_join(ri_obs, by = c("item_code", "date")) |>
    dplyr::arrange(item_code, date) |>
    dplyr::group_by(item_code) |>
    tidyr::fill(ri, .direction = "downup") |>
    dplyr::ungroup() |>
    dplyr::left_join(dplyr::select(mapped, cat_id, item_code = cpi_item_code), by = "item_code") |>
    dplyr::arrange(cat_id, item_code, date) |>
    dplyr::group_by(cat_id, item_code) |>
    dplyr::mutate(rel = idx / dplyr::lag(idx), ri_lag = dplyr::lag(ri)) |>
    dplyr::ungroup()
  comp |>
    dplyr::filter(!is.na(rel), !is.na(ri_lag)) |>
    dplyr::summarise(rel_cat = sum(ri_lag * rel) / sum(ri_lag), .by = c(cat_id, date)) |>
    dplyr::arrange(cat_id, date) |>
    dplyr::group_by(cat_id) |>
    dplyr::mutate(index = 100 * cumprod(rel_cat)) |>
    dplyr::ungroup() |>
    dplyr::select(cat_id, date, index)
}
