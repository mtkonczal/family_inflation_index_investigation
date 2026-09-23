# ---------------------------------------------------------------------------
# R/functions/index_build.R
#
# Group-specific chained Laspeyres price index with annually updated,
# price-updated expenditure weights. This is CPI's own upper-level
# aggregation, so that a residual against published CPI reflects the WEIGHT
# SOURCE rather than a difference in formula.
#
# For month t in calendar year Y, with expenditure shares from CEX year
# V = Y - LAG (the expenditure reference period):
#
#   cost weight   c_i,t = s_i,V * ( p_i,t-1 / pbar_i,V )
#   normalized    w_i,t = c_i,t / sum_k c_k,t
#   index         P_t   = P_t-1 * sum_i w_i,t * ( p_i,t / p_i,t-1 )
#
# where pbar_i,V is category i's average price over year V. That is BLS's
# procedure: expenditure weights are price-updated from the expenditure
# reference period to the December link month, then monthly thereafter.
# Equivalently c = s * (p_Dec(Y-1) / pbar_V) * (p_t-1 / p_Dec(Y-1)).
#
# price_update = "full"   the BLS procedure above (default since D-27)
#                "pivot"  the pre-D-27 variant: s * p_t-1 / p_Dec(Y-1), which
#                         skips the step from pbar_V to December Y-1
#                "none"   fixed shares, no price updating
# TRUE and FALSE are accepted as "full" and "none".
# ---------------------------------------------------------------------------

#' Build one chained index.
#'
#' @param prices Long frame: cat_id, date, index (monthly, one row per pair).
#' @param shares Long frame: cat_id, year, share (expenditure shares, any
#'   scale; renormalized internally over `basket`).
#' @param basket Character vector of cat_id to include.
#' @param lag_years Weight vintage lag. 2 matches CPI convention since the
#'   2023 move to annual single-year weight updates.
#' @param price_update "full", "pivot" or "none" (see header).
#' @return list(index = frame of date, index, chg_12m, n_cats, w_ref_year,
#'   pu_fallback; weights = long frame of the normalized cost weights used).
#'   pu_fallback is TRUE for months whose vintage year has no prices in the
#'   panel, where "full" falls back to "pivot" (only the first LAG years).
build_index <- function(prices, shares, basket, lag_years = 2L,
                        price_update = "full") {
  if (isTRUE(price_update)) price_update <- "full"
  if (isFALSE(price_update)) price_update <- "none"
  price_update <- match.arg(price_update, c("full", "pivot", "none"))
  p <- prices[prices$cat_id %in% basket, c("cat_id", "date", "index")]
  p <- p[order(p$cat_id, p$date), ]

  # Balanced panel only: the index may never change basket composition.
  n_by_date <- tapply(p$cat_id, p$date, length)
  full <- as.Date(names(n_by_date)[n_by_date == length(basket)])
  if (!length(full)) stop("No month has all ", length(basket), " basket categories.",
                          call. = FALSE)
  # Longest contiguous run of complete months on the basket's own grid, so a
  # hole in any one category is never chained over implicitly. A month absent
  # from the CPI grid entirely (October 2025) is not a gap in this sense: it is
  # absent for every category, so it is not on the grid and the run continues
  # with the chain link spanning it correctly.
  grid <- sort(unique(p$date))
  ok <- grid %in% full
  r <- rle(ok); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1L
  best <- which(r$values)[which.max(r$lengths[r$values])]
  keep <- grid[starts[best]:ends[best]]
  if (length(keep) < sum(ok)) {
    warning(sprintf("build_index: %d complete month(s) outside the longest contiguous run dropped (run %s to %s).",
                    sum(ok) - length(keep), min(keep), max(keep)), call. = FALSE)
  }
  p <- p[p$date %in% keep, ]

  # pivot_wider, not stats::reshape: reshape silently drops or reorders the
  # id index when the input is sorted by the timevar, which produced a
  # phantom "missing weight vintage" error for years that were present.
  wide <- tidyr::pivot_wider(p, id_cols = "date", names_from = "cat_id",
                             values_from = "index")
  wide <- wide[order(wide$date), ]
  cats <- setdiff(names(wide), "date")
  P <- as.matrix(wide[, cats, drop = FALSE])
  colnames(P) <- cats
  dates <- wide$date
  if (anyNA(P)) stop("Balanced-panel construction left NA prices.", call. = FALSE)

  yr <- as.integer(format(dates, "%Y"))

  # Weight-reference month per observation: December of the prior calendar
  # year where the panel has it, else the panel's first month (only affects
  # the partial first year).
  ref_idx <- integer(length(dates))
  for (k in seq_along(dates)) {
    want <- as.Date(sprintf("%d-12-01", yr[k] - 1L))
    j <- match(want, dates)
    ref_idx[k] <- if (is.na(j)) 1L else j
  }

  # Expenditure shares for the lagged vintage, renormalized over the basket.
  sh <- shares[shares$cat_id %in% basket, c("cat_id", "year", "share")]
  s_wide <- tidyr::pivot_wider(sh, id_cols = "year", names_from = "cat_id",
                               values_from = "share")
  s_wide <- s_wide[order(s_wide$year), ]
  miss_cat <- setdiff(cats, names(s_wide))
  if (length(miss_cat)) {
    stop("No expenditure shares for basket categor(y/ies): ",
         paste(miss_cat, collapse = ", "), call. = FALSE)
  }
  S <- as.matrix(s_wide[, cats, drop = FALSE])
  colnames(S) <- cats
  rownames(S) <- s_wide$year
  if (anyNA(S)) {
    bad <- which(apply(S, 1, anyNA))
    stop("Missing share values for year(s): ",
         paste(rownames(S)[bad], collapse = ", "), call. = FALSE)
  }
  S <- S / rowSums(S)

  # Annual average price by calendar year, the expenditure-reference-period
  # price level used by "full" price updating. Computed on the whole price
  # panel BEFORE trimming to months with a weight vintage, so the first index
  # year can still see its vintage year's prices. Only years with at least six
  # months qualify; otherwise the month falls back to "pivot".
  yr_tab <- table(yr)
  pyears <- as.integer(names(yr_tab)[yr_tab >= 6L])
  Pbar <- t(vapply(pyears, function(y) colMeans(P[yr == y, , drop = FALSE]),
                   numeric(length(cats))))
  if (length(pyears) == 1L) Pbar <- matrix(Pbar, nrow = 1)
  dimnames(Pbar) <- list(pyears, cats)

  # Start the index at the first month whose weight vintage exists. Prices
  # before that are used only for Pbar and as the first chain base.
  w_year <- yr - lag_years
  have_w <- w_year %in% as.integer(rownames(S))
  first_ok <- which(have_w)[1]
  if (is.na(first_ok) || !all(have_w[first_ok:length(have_w)])) {
    missing_w <- setdiff(unique(w_year[if (is.na(first_ok)) TRUE else first_ok:length(w_year)]),
                         as.integer(rownames(S)))
    stop("No CEX shares for weight vintage year(s): ",
         paste(sort(missing_w), collapse = ", "),
         ". Shorten the panel or reduce lag_years.", call. = FALSE)
  }
  # Keep one month before first_ok as the chain base.
  keep_i <- max(1L, first_ok - 1L):length(dates)
  P <- P[keep_i, , drop = FALSE]; dates <- dates[keep_i]; yr <- yr[keep_i]
  w_year <- w_year[keep_i]
  ref_idx <- integer(length(dates))
  for (k in seq_along(dates)) {
    j <- match(as.Date(sprintf("%d-12-01", yr[k] - 1L)), dates)
    ref_idx[k] <- if (is.na(j)) 1L else j
  }

  n <- length(dates)
  idx <- rep(NA_real_, n); idx[1] <- 100
  W <- matrix(NA_real_, n, length(cats), dimnames = list(NULL, cats))
  fallback <- rep(FALSE, n)

  for (k in 2:n) {
    s <- S[as.character(w_year[k]), ]
    if (price_update == "full" && as.character(w_year[k]) %in% rownames(Pbar)) {
      # p_{t-1} / pbar_{V}
      cw <- s * P[k - 1L, ] / Pbar[as.character(w_year[k]), ]
    } else if (price_update %in% c("full", "pivot")) {
      # p_{t-1} / p_{Dec(Y-1)}
      fallback[k] <- price_update == "full"
      cw <- s * P[k - 1L, ] / P[ref_idx[k], ]
    } else {
      cw <- s
    }
    w <- cw / sum(cw)
    W[k, ] <- w
    idx[k] <- idx[k - 1L] * sum(w * (P[k, ] / P[k - 1L, ]))
  }

  out <- data.frame(date = dates, index = idx, n_cats = length(cats),
                    w_ref_year = w_year, pu_fallback = fallback,
                    stringsAsFactors = FALSE)
  # 12-month change by explicit date arithmetic. Positional lag is unsafe:
  # October 2025 is absent from the CPI grid.
  j <- match(dates - months(12), dates)
  out$chg_12m <- 100 * (out$index / out$index[j] - 1)

  wl <- data.frame(date = rep(dates, times = length(cats)),
                   cat_id = rep(cats, each = length(dates)),
                   weight = as.vector(W), stringsAsFactors = FALSE)
  list(index = out, weights = wl[!is.na(wl$weight), ])
}

#' Benchmark index built directly from CPI's own monthly cost weights.
#'
#' WHY THIS IS SEPARATE FROM build_index(): published relative importance for
#' month t ALREADY embodies a two-year-lagged CEX vintage, price-updated by BLS
#' to month t. Feeding it through build_index() with lag_years = 2 would lag it
#' a second time, giving the benchmark an effective four-year-old weight
#' vintage and inflating the residual it is supposed to measure.
#'
#' Here RI at t-1 is used as the cost weight at t, renormalized over the
#' basket, with no further lag and no further price updating:
#'
#'   P_t = P_t-1 * sum_i [ RI_i,t-1 / sum_k RI_k,t-1 ] * ( p_i,t / p_i,t-1 )
#'
#' That is CPI's own aggregation restricted to the basket, so a residual
#' against it isolates the weight SOURCE and nothing else.
#'
#' @param prices Long frame: cat_id, date, index.
#' @param ri_monthly Long frame: cat_id, date, ri (monthly relative importance).
#' @param basket Character vector of cat_id.
#' @param carry Carry RI forward onto price months with no published RI.
build_index_ri <- function(prices, ri_monthly, basket, carry = TRUE) {
  p <- prices[prices$cat_id %in% basket, c("cat_id", "date", "index")]
  w <- ri_monthly[ri_monthly$cat_id %in% basket, c("cat_id", "date", "ri")]
  if (carry) {
    # BLS skips relative importance in a few months (2025 carries ten). Carry
    # the last published RI forward onto every later price month so the chain
    # never has to bridge a month with stale weights implicitly (D-27).
    pd <- sort(unique(p$date)); pd <- pd[pd >= min(w$date)]
    w <- tidyr::complete(w, cat_id, date = pd) |>
      dplyr::arrange(cat_id, date) |>
      dplyr::group_by(cat_id) |> tidyr::fill(ri, .direction = "down") |>
      dplyr::ungroup()
    w <- as.data.frame(w)
  }

  d <- merge(p, w, by = c("cat_id", "date"))
  d <- d[!is.na(d$index) & !is.na(d$ri), ]

  # Balanced panel: every basket category present with both a price and a weight
  n_by_date <- tapply(d$cat_id, d$date, length)
  keep <- as.Date(names(n_by_date)[n_by_date == length(basket)])
  if (length(keep) < 14) {
    stop("Fewer than 14 complete months for the RI benchmark on this basket.",
         call. = FALSE)
  }
  d <- d[d$date %in% keep, ]

  P <- tidyr::pivot_wider(d[, c("cat_id", "date", "index")], id_cols = "date",
                          names_from = "cat_id", values_from = "index")
  W <- tidyr::pivot_wider(d[, c("cat_id", "date", "ri")], id_cols = "date",
                          names_from = "cat_id", values_from = "ri")
  P <- P[order(P$date), ]; W <- W[order(W$date), ]
  stopifnot(identical(P$date, W$date))
  cats <- setdiff(names(P), "date")
  Pm <- as.matrix(P[, cats]); Wm <- as.matrix(W[, cats])
  dates <- P$date

  n <- length(dates)
  idx <- rep(NA_real_, n); idx[1] <- 100
  for (k in 2:n) {
    wk <- Wm[k - 1L, ] / sum(Wm[k - 1L, ])
    idx[k] <- idx[k - 1L] * sum(wk * (Pm[k, ] / Pm[k - 1L, ]))
  }
  out <- data.frame(date = dates, index = idx, n_cats = length(cats),
                    stringsAsFactors = FALSE)
  j <- match(dates - months(12), dates)
  out$chg_12m <- 100 * (out$index / out$index[j] - 1)
  out
}

# ===========================================================================
# Shared inputs: relative importance, pooled medical, owners' equivalent rent
# ===========================================================================

#' National, monthly, NSA CPI rows (index levels and relative importance).
cpi_national <- function(cpi) {
  cpi[cpi$area_code == "0000" & cpi$periodicity_code == "R" &
        cpi$seasonal == "U" & cpi$freq == "monthly" & !cpi$is_average, ]
}

#' Category-level CPI relative importance, monthly.
#'
#' WHY THE FILL (D-27): four thin components (SETA03, SEHP, SEGD01, SEEA) have
#' no published relative importance in most months after mid-2020. Requiring
#' every component to be present, as the pre-D-27 code did, dropped their
#' whole category-month, which removed 2020-07 to 2026-07 from the error bar
#' almost entirely: 88 of 159 possible months, all but one before 2021.
#'
#' With fill = TRUE each component's RI is carried forward (and, before its
#' first published value, back) across its own holes, but only inside the
#' window in which its PRICE is published. That mirrors how the price panel
#' treats the same series (D-20) and drops discontinued components exactly
#' when the price composite drops them (D-21). `filled_share` records the
#' RI-weighted share of each category-month that is carried rather than
#' published.
#'
#' @return tibble: cat_id, date, ri, filled_share
ri_by_category <- function(cpi, xw, fill = TRUE) {
  cn <- cpi_national(cpi)
  codes <- unique(xw$cpi_item_code)
  obs <- cn[cn$item_code %in% codes & !is.na(cn$weight), c("item_code", "date", "weight")]
  names(obs)[3] <- "ri"
  if (!fill) {
    return(xw |>
      dplyr::inner_join(obs, by = c(cpi_item_code = "item_code"),
                        relationship = "many-to-many") |>
      dplyr::summarise(ri = sum(ri), n_have = dplyr::n(), .by = c(cat_id, date)) |>
      dplyr::inner_join(dplyr::summarise(xw, n_req = dplyr::n(), .by = cat_id), by = "cat_id") |>
      dplyr::filter(n_have == n_req) |>
      dplyr::transmute(cat_id, date, ri, filled_share = 0))
  }
  grid <- sort(unique(cn$date[!is.na(cn$weight)]))
  win <- cn[cn$item_code %in% codes & !is.na(cn$value), ] |>
    dplyr::summarise(first = min(date), last = max(date), .by = item_code)
  comp <- tidyr::expand_grid(item_code = codes, date = grid) |>
    dplyr::inner_join(win, by = "item_code") |>
    dplyr::filter(date >= first, date <= last) |>
    dplyr::left_join(obs, by = c("item_code", "date")) |>
    dplyr::mutate(observed = !is.na(ri)) |>
    dplyr::arrange(item_code, date) |>
    dplyr::group_by(item_code) |>
    tidyr::fill(ri, .direction = "downup") |>
    dplyr::ungroup() |>
    dplyr::filter(!is.na(ri))
  xw |>
    dplyr::inner_join(comp, by = c(cpi_item_code = "item_code"),
                      relationship = "many-to-many") |>
    dplyr::summarise(filled_share = 1 - sum(ri * observed) / sum(ri),
                     ri = sum(ri), .by = c(cat_id, date)) |>
    dplyr::select(cat_id, date, ri, filled_share)
}

#' Collapse a block of categories into one, for prices, shares and RI.
#'
#' Prices for the pooled block are aggregated with CPI relative importance,
#' since within-block weights are exactly what CEX and CPI disagree about
#' (D-22). Shares are summed. Used for medical (M0, D-22/D-25).
#'
#' @param shares Frame with group, cat_id, year and the column `share_col`.
pool_block <- function(prices, shares, ri_cat, block, new_id, share_col = "share") {
  bpx <- build_index_ri(prices, ri_cat, block) |> dplyr::transmute(cat_id = new_id, date, index)
  list(
    prices = dplyr::bind_rows(
      dplyr::filter(prices, !cat_id %in% block) |> dplyr::select(cat_id, date, index), bpx),
    shares = shares |>
      dplyr::mutate(cat_id = dplyr::if_else(cat_id %in% block, new_id, cat_id)) |>
      dplyr::summarise(share = sum(.data[[share_col]]), .by = c(group, cat_id, year)),
    ri = dplyr::bind_rows(
      dplyr::filter(ri_cat, !cat_id %in% block),
      ri_cat |> dplyr::filter(cat_id %in% block) |>
        dplyr::summarise(ri = sum(ri), n = dplyr::n(), .by = date) |>
        dplyr::filter(n == length(block)) |>
        dplyr::transmute(cat_id = new_id, date, ri))
  )
}

#' Add an owners' equivalent rent category (scope_cpi_b, D-29).
#'
#' OER is weighted with the CE rental-equivalence question, "Estimated monthly
#' rental value of owned home", annualized. That is the same CE question BLS
#' uses to weight OER in the CPI. It is priced with CPI SEHC. Owner outlays
#' (mortgage interest, property taxes, maintenance/repairs/insurance) are
#' replaced by it, as in CPI, so category 06 leaves the basket.
#'
#' @param shares Frame with group, cat_id, year, share (percent of TOTALEXP).
#' @param rentval Frame with group, year, rentval_annual (dollars per CU).
#' @param totalexp Frame with group, year, totalexp.
#' @param cpi Raw CPI frame, for the SEHC price and relative importance.
add_oer <- function(prices, shares, ri_cat, rentval, totalexp, cpi, new_id = "H0") {
  cn <- cpi_national(cpi)
  # Restrict to the existing price grid. A series published in a month the
  # rest of CPI skipped (October 2025) would otherwise break the balanced run.
  sehc <- cn[cn$item_code == "SEHC" & !is.na(cn$value) & cn$date %in% unique(prices$date), ]
  oer_sh <- rentval |>
    dplyr::inner_join(totalexp, by = c("group", "year")) |>
    dplyr::transmute(group, cat_id = new_id, year, share = 100 * rentval_annual / totalexp)
  list(
    prices = dplyr::bind_rows(
      dplyr::select(prices, cat_id, date, index),
      tibble::tibble(cat_id = new_id, date = sehc$date, index = sehc$value)),
    shares = dplyr::bind_rows(
      dplyr::filter(shares, cat_id != "06") |> dplyr::select(group, cat_id, year, share),
      oer_sh) |>
      dplyr::filter(year %in% unique(oer_sh$year)),
    ri = dplyr::bind_rows(
      dplyr::filter(ri_cat, cat_id != "06"),
      cn[cn$item_code == "SEHC" & !is.na(cn$weight), ] |>
        dplyr::transmute(cat_id = new_id, date, ri = weight))
  )
}

# ===========================================================================
# Sampling error on the gap (D-28)
# ===========================================================================
#
# The flat files publish means only. The CE workbooks publish a standard error
# for every expenditure mean. The group index's inflation over a window is
# pi_g = sum_i w_i r_i, with w_i proportional to x_i * u_i (x_i the CE mean,
# u_i the price-update factor, fixed by prices). So
#
#   d pi_g / d log x_i = w_i (r_i - pi_g)
#   Var(pi_g) ~= sum_i [ w_i (r_i - pi_g) ]^2 RSE_i^2
#
# by the delta method, treating the category means as uncorrelated. The two
# groups are disjoint samples, so Var(gap) = Var(pi_F) + Var(pi_N).
#
# What this leaves out, stated so nobody reads more into it than is there:
#   * covariance between category means within a group. Positive covariance
#     (big spenders spend more on everything) largely cancels in shares, which
#     is what enters the index; the sign of the residual bias is unknown.
#   * CE's non-sampling error (under-reporting), which is not sampling noise.
#   * price-side error. CPI item indices carry their own sampling error, but
#     the same index enters both groups, so most of it differences out.

#' Standard error of the 12-month gap, month by month.
#'
#' Uses the weights of month t and the vintage in force at t; a 12-month
#' window that spans a vintage change is approximated by the later vintage.
#'
#' @param wF,wN Frames: date, cat_id, weight (cost weights from build_index).
#' @param rseF,rseN Frames: year, cat_id, rse (relative SE of the CE mean).
#' @param pi12 Frame: cat_id, date, pi12 (category 12-month % change).
#' @param lag_years Weight vintage lag.
gap_se_12m <- function(wF, wN, rseF, rseN, pi12, lag_years = 2L) {
  one <- function(w, rse) {
    w |>
      dplyr::mutate(year = as.integer(format(date, "%Y")) - lag_years) |>
      dplyr::inner_join(pi12, by = c("cat_id", "date")) |>
      dplyr::left_join(rse, by = c("year", "cat_id")) |>
      dplyr::mutate(pibar = sum(weight * pi12), .by = date) |>
      dplyr::summarise(var = sum((weight * (pi12 - pibar) * rse)^2),
                       rse_missing = sum(is.na(rse)), .by = date)
  }
  a <- one(wF, rseF); b <- one(wN, rseN)
  dplyr::inner_join(a, b, by = "date", suffix = c("_F", "_N")) |>
    dplyr::filter(rse_missing_F == 0, rse_missing_N == 0) |>
    dplyr::transmute(date, se_F = sqrt(var_F), se_N = sqrt(var_N),
                     se_gap = sqrt(var_F + var_N))
}

#' Standard error of a cumulative index change from d0 to d1.
#'
#' The change is chained over calendar-year links (Dec to Dec, last link to
#' d1); each link uses one CEX vintage. Within link y the link inflation's SE
#' follows the formula above with the link's reference-month cost weights.
#' The cumulative change is prod(1 + L_y) - 1, so its SE contribution from
#' link y is (I_{y-1}/I_0) * (I_{y}/I_{y-1}) / (1 + L_y) * SE(L_y) ~= (I_{y-1}/I_0)
#' * SE(L_y) to first order.
#'
#' Vintages from different years come from overlapping but different CE
#' samples, so their errors are neither independent nor identical. Both
#' bounds are returned: `se_indep` (uncorrelated across vintages) and
#' `se_corr` (perfectly correlated).
cum_se <- function(index, weights, prices, rse, d0, d1) {
  idx <- index[order(index$date), c("date", "index")]
  cuts <- c(d0, seq(as.Date(sprintf("%s-12-01", format(d0, "%Y"))), d1, by = "year"), d1)
  cuts <- sort(unique(cuts[cuts >= d0 & cuts <= d1]))
  I0 <- idx$index[idx$date == d0]
  parts <- NULL
  for (k in seq_len(length(cuts) - 1L)) {
    a <- cuts[k]; b <- cuts[k + 1L]
    first_m <- min(idx$date[idx$date > a])
    w <- weights[weights$date == first_m, c("cat_id", "weight")]
    pa <- prices[prices$date == a, c("cat_id", "index")]
    pb <- prices[prices$date == b, c("cat_id", "index")]
    r <- dplyr::inner_join(pa, pb, by = "cat_id", suffix = c("_a", "_b")) |>
      dplyr::transmute(cat_id, r = index_b / index_a - 1)
    vy <- as.integer(format(first_m, "%Y")) - 2L
    z <- w |> dplyr::inner_join(r, by = "cat_id") |>
      dplyr::left_join(dplyr::filter(rse, year == vy) |> dplyr::select(cat_id, rse), by = "cat_id")
    if (anyNA(z$rse)) return(c(se_indep = NA_real_, se_corr = NA_real_))
    rbar <- sum(z$weight * z$r)
    se_l <- sqrt(sum((z$weight * (z$r - rbar) * z$rse)^2))
    parts <- c(parts, (idx$index[idx$date == a] / I0) * se_l)
  }
  100 * c(se_indep = sqrt(sum(parts^2)), se_corr = sum(parts))
}
