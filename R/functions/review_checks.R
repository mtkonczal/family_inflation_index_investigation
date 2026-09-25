# ---------------------------------------------------------------------------
# R/functions/review_checks.R
#
# Helpers for 11_review_checks.R (decisions_log D-35 to D-40).
#
#   * DEEP PIECES: split five taxonomy categories into published CEX
#     sub-items (childcare, new/used vehicles, vehicle cost components,
#     tuition by level, finance charges), with additivity enforced.
#   * CELL-BASED SAMPLING ERROR: every LB06 group is a consumer-unit-weighted
#     mixture of seven disjoint published cells, so the sampling error of a
#     gap between OVERLAPPING groups (families vs all CUs) gets its covariance
#     right, and every pair is on one footing.
#   * A Tornqvist-type index with contemporaneous annual weights.
# ---------------------------------------------------------------------------

# Disjoint LB06 cells. 01 = 03 + 05 + 06 + 07 + 08 + 09 + 10, 04 = 05 + 06 + 07.
LB06_CELLS <- c("03", "05", "06", "07", "08", "09", "10")

# Parent category -> CEX item code of the published parent total.
DEEP_PARENTS <- c("14" = "HHPERSRV", "23" = "VEHPURCH", "25" = "VEHOTHXP",
                  "37" = "EDUCATN", "39" = "MISC")

# One row per piece. `items` are summed (a suppressed item counts as zero and
# is logged); the one `resid` piece per parent is the parent less its listed
# siblings, so the pieces always add to the published parent exactly.
# Childcare is the residual because its item codes change twice (2013, 2023)
# while elder care (340906) and adult day care (340910) are stable.
DEEP_PIECES <- tibble::tribble(
  ~piece, ~parent, ~items,                  ~resid, ~label,
  "14C",  "14",    "",                      TRUE,   "Childcare (personal services less elder and adult day care)",
  "14E",  "14",    "340906;340910",         FALSE,  "Elder, invalid and adult day care",
  "23N",  "23",    "NEWCARS",               FALSE,  "Cars and trucks, new",
  "23U",  "23",    "USEDCARS",              FALSE,  "Cars and trucks, used",
  "23O",  "23",    "",                      TRUE,   "Other vehicles",
  "25F",  "25",    "VEHFINCH",              FALSE,  "Vehicle finance charges",
  "25R",  "25",    "CAREPAIR",              FALSE,  "Vehicle maintenance and repairs",
  "25I",  "25",    "500110",                FALSE,  "Vehicle insurance",
  "25L",  "25",    "",                      TRUE,   "Vehicle rental, leases, licenses and other charges",
  "37C",  "37",    "670110;671000",         FALSE,  "College tuition (incl. prepaid tuition)",
  "37K",  "37",    "670210",                FALSE,  "Elementary and high school tuition",
  "37V",  "37",    "670410",                FALSE,  "Vocational and technical school tuition",
  "37F",  "37",    "005520",                FALSE,  "Student loan finance charges",
  "37O",  "37",    "",                      TRUE,   "Other education (books, supplies, other schools)",
  "39F",  "39",    "710110;005420;005620",  FALSE,  "Finance charges excl. mortgage and vehicle",
  "39O",  "39",    "",                      TRUE,   "Other miscellaneous"
)

# CPI targets for the pieces that get their own price. Composites are
# aggregated by CPI relative importance, as in 05 (D-16). 23O keeps the
# original new-plus-used composite: CPI's new-motorcycle series ended in 2000.
DEEP_XW <- tibble::tribble(
  ~cat_id, ~cpi_item_code,
  "14C", "SEEB03",
  "14E", "SEMD03", "14E", "SEMD02",
  "23N", "SETA01",
  "23U", "SETA02",
  "23O", "SETA01", "23O", "SETA02",
  "25R", "SETC",   "25R", "SETD",
  "25I", "SETE",
  "25L", "SETA03", "25L", "SETA04", "25L", "SETF",
  "37C", "SEEB01",
  "37K", "SEEB02",
  "37V", "SEEB04",
  "37O", "SEEA"
)

# Pieces with their own published CE standard error. The rest borrow the
# parent's relative SE (logged; a sub-item's true RSE is larger).
DEEP_OWN_SE <- c("23N", "23U", "23O", "25F", "25R", "25I", "25L")
CE_ITEM_MAP_DEEP <- tibble::tribble(
  ~cat_id, ~pattern,
  "23N", "^Cars and trucks, new$",
  "23U", "^Cars and trucks, used$",
  "23O", "^Other vehicles$",
  "25F", "^Vehicle finance charges$",
  "25R", "^Maintenance and repairs$",
  "25I", "^Vehicle insurance$",
  "25L", "^Vehicle rental, leases, licenses, and other charges$"
)

#' Piece dollars from the flat-file items.
#'
#' @param d Long frame: year, characteristics_code, item_code, value.
#' @param tol_abs,tol_rel A residual piece may fall below zero only by
#'   BLS dollar rounding; anything larger stops the script.
#' @return list(pieces = frame year, characteristics_code, piece, parent,
#'   dollars; log = per-parent diagnostics).
deep_piece_dollars <- function(d, tol_abs = 3, tol_rel = 0.005) {
  items <- unique(c(unname(DEEP_PARENTS), unlist(strsplit(DEEP_PIECES$items, ";"))))
  items <- items[nzchar(items)]
  w <- d |> dplyr::filter(item_code %in% items) |>
    dplyr::select(year, characteristics_code, item_code, value) |>
    tidyr::pivot_wider(names_from = item_code, values_from = value)
  for (it in setdiff(items, names(w))) w[[it]] <- NA_real_
  out <- NULL; log <- NULL
  for (par in names(DEEP_PARENTS)) {
    pv <- w[[DEEP_PARENTS[[par]]]]
    if (anyNA(pv)) {
      bad <- w[is.na(pv), c("year", "characteristics_code")]
      stop("Parent ", DEEP_PARENTS[[par]], " missing for ",
           paste(bad$characteristics_code, bad$year, collapse = ", "), call. = FALSE)
    }
    pp <- DEEP_PIECES[DEEP_PIECES$parent == par, ]
    listed <- 0; n_na <- 0L
    for (i in which(!pp$resid)) {
      codes <- strsplit(pp$items[i], ";")[[1]]
      m <- as.matrix(w[, codes, drop = FALSE])
      n_na <- n_na + sum(is.na(m))
      v <- rowSums(m, na.rm = TRUE)
      listed <- listed + v
      out <- dplyr::bind_rows(out, tibble::tibble(year = w$year,
        characteristics_code = w$characteristics_code, piece = pp$piece[i], parent = par, dollars = v))
    }
    res <- pv - listed
    worst <- min(res + pmax(tol_abs, tol_rel * pv))
    if (worst < 0) {
      k <- which.min(res + pmax(tol_abs, tol_rel * pv))
      stop(sprintf("Residual piece for %s is negative beyond rounding: %s %s, %.0f",
                   par, w$characteristics_code[k], w$year[k], res[k]), call. = FALSE)
    }
    out <- dplyr::bind_rows(out, tibble::tibble(year = w$year,
      characteristics_code = w$characteristics_code, piece = pp$piece[pp$resid], parent = par,
      dollars = pmax(res, 0)))
    log <- dplyr::bind_rows(log, tibble::tibble(parent = par, cells = nrow(w),
      suppressed_items = n_na, min_residual = min(res)))
  }
  list(pieces = out, log = log)
}

#' Map a piece to the price category it is aggregated into under a variant.
#'
#' @param sw Named logical switches: fin_veh, fin_all, cc, veh, edu.
#' @return Category id, or NA_character_ when the piece leaves the basket
#'   (finance charges are interest, out of CPI scope like mortgage interest).
piece_price_id <- function(piece, parent, sw) {
  dplyr::case_when(
    piece == "25F" & (sw[["fin_veh"]] | sw[["fin_all"]]) ~ NA_character_,
    piece %in% c("37F", "39F") & sw[["fin_all"]] ~ NA_character_,
    parent == "14" & sw[["cc"]] ~ piece,
    parent %in% c("23", "25") & sw[["veh"]] & piece != "25F" ~ piece,
    parent == "37" & sw[["edu"]] & piece != "37F" ~ piece,
    TRUE ~ parent)
}

#' Relative-SE source for a category id.
rse_source <- function(id) {
  ifelse(id %in% DEEP_OWN_SE, id,
         ifelse(nchar(id) == 3 & substr(id, 1, 2) %in% names(DEEP_PARENTS), substr(id, 1, 2), id))
}

# ===========================================================================
# Cell-based sampling error
# ===========================================================================
#
# A group's CE mean on category i is the CU-weighted mean of its cells,
# x_G,i = sum_c n_c x_c,i / N_G, so d log x_G,i = sum_c phi_G,c,i d log x_c,i
# with phi_G,c,i = n_c x_c,i / sum_c' n_c' x_c',i. Cells are disjoint samples,
# treated as independent; category means within a cell as uncorrelated (the
# D-28 assumption). For a link y with first-month cost weights w and
# relatives r, L_y = sum_i w_i r_i and dL_y / d log x_G,i = w_i (r_i - L_y);
# the cumulative change moves by [(I_end / I_0) / (1 + L_y)] dL_y. The factor
# includes price growth after the link as well as before it.
#
#   independent vintages:   Var = sum_y sum_c sum_i (D_y,c,i * rse_y,c,i)^2
#   persistent errors:      Var = sum_c sum_i (sum_y D_y,c,i * rse_y,c,i)^2
#
# "Persistent" means each cell-category's standardized error is the same in
# every vintage. It is the natural perfectly-correlated case and is tighter
# than D-28's se_corr, which adds link SDs as if every link's error were
# perfectly correlated regardless of which categories drive it.

#' Link-level terms of one group's cumulative change, d0 to d1.
link_terms <- function(index, weights, prices, d0, d1, lag_years = 2L) {
  idx <- index[order(index$date), c("date", "index")]
  cuts <- c(d0, seq(as.Date(sprintf("%s-12-01", format(d0, "%Y"))), d1, by = "year"), d1)
  cuts <- sort(unique(cuts[cuts >= d0 & cuts <= d1]))
  if (!d0 %in% idx$date || !d1 %in% idx$date) stop("Window outside the index.", call. = FALSE)
  I0 <- idx$index[idx$date == d0]
  out <- vector("list", length(cuts) - 1L)
  for (k in seq_len(length(cuts) - 1L)) {
    a <- cuts[k]; b <- cuts[k + 1L]
    first_m <- min(idx$date[idx$date > a])
    w <- weights[weights$date == first_m, c("cat_id", "weight")]
    pa <- prices[prices$date == a, c("cat_id", "index")]
    pb <- prices[prices$date == b, c("cat_id", "index")]
    z <- merge(w, merge(pa, pb, by = "cat_id", suffixes = c("_a", "_b")), by = "cat_id")
    if (nrow(z) != nrow(w)) stop("Link prices missing for some categories.", call. = FALSE)
    z$r <- z$index_b / z$index_a - 1
    out[[k]] <- data.frame(link = k, a = a, b = b,
      vy = as.integer(format(first_m, "%Y")) - lag_years,
      cat_id = z$cat_id, w = z$weight, r = z$r, L = sum(z$weight * z$r),
      lev = idx$index[idx$date == a] / I0,
      sensitivity = (idx$index[idx$date == d1] / I0) /
        (idx$index[idx$date == b] / idx$index[idx$date == a]),
      stringsAsFactors = FALSE)
  }
  do.call(rbind, out)
}

#' Derivative terms D of a group's cumulative change (pp) w.r.t. cell log means.
group_D <- function(lt, phi_g, sign = 1) {
  have <- paste(phi_g$year, phi_g$cat_id)
  if (!all(paste(lt$vy, lt$cat_id) %in% have)) {
    stop("phi missing for link categories: ",
         paste(utils::head(setdiff(paste(lt$vy, lt$cat_id), have), 5), collapse = ", "), call. = FALSE)
  }
  m <- merge(lt, phi_g, by.x = c("vy", "cat_id"), by.y = c("year", "cat_id"))
  data.frame(link = m$link, vy = m$vy, cell = m$cell, cat_id = m$cat_id,
             D = sign * 100 * m$sensitivity * m$w * (m$r - m$L) * m$phi,
             stringsAsFactors = FALSE)
}

#' Standard errors from stacked D terms.
se_from_D <- function(D, rse_cell) {
  D <- stats::aggregate(D ~ link + vy + cell + cat_id, D, sum)
  m <- merge(D, rse_cell, by.x = c("cell", "vy", "cat_id"), by.y = c("cell", "year", "cat_id"),
             all.x = TRUE)
  miss <- is.na(m$rse) & abs(m$D) > 1e-12
  if (any(miss)) stop("No RSE for ", sum(miss), " cell-category-vintage terms, e.g. ",
                      paste(utils::head(unique(paste(m$cell, m$cat_id, m$vy)[miss]), 5), collapse = "; "),
                      call. = FALSE)
  m$rse[is.na(m$rse)] <- 0
  m$Dr <- m$D * m$rse
  pc <- stats::aggregate(Dr ~ cell + cat_id, m, sum)
  pl <- stats::aggregate(Dr2 ~ link, transform(m, Dr2 = Dr^2), sum)
  # se_bound adds link SDs: the largest SE any correlation across vintages
  # can produce (triangle inequality). Persistent errors can come out BELOW
  # independent ones when a category's gradient changes sign across links.
  c(se_indep = sqrt(sum(m$Dr^2)), se_persist = sqrt(sum(pc$Dr^2)), se_bound = sum(sqrt(pl$Dr2)))
}

#' Contribution of category blocks to a cumulative gap, with SEs.
#'
#' Point estimates replicate 10_intuition.R: contrib = 100 * Ibar *
#' (w_F - w_N) * (r - rbar_A), rbar_A the all-CU link inflation, Ibar the mean
#' of the two groups' cumulative levels at the link start (D-34). The SE
#' differentiates through w_F, w_N and rbar_A.
contrib_with_se <- function(ltF, ltN, ltA, phiF, phiN, phiA, rse_cell, block_of) {
  j <- merge(merge(ltF[, c("link", "vy", "cat_id", "w", "r", "lev")],
                   ltN[, c("link", "cat_id", "w", "lev")], by = c("link", "cat_id"),
                   suffixes = c("F", "N")),
             ltA[, c("link", "cat_id", "w", "L")], by = c("link", "cat_id"))
  names(j)[names(j) == "w"] <- "wA"; names(j)[names(j) == "L"] <- "LA"
  j$Ibar <- (j$levF + j$levN) / 2
  j$block <- block_of(j$cat_id)
  j$rel <- j$r - j$LA
  j$contrib <- 100 * j$Ibar * (j$wF - j$wN) * j$rel
  pts <- stats::aggregate(contrib ~ block, j, sum)
  res <- NULL
  for (B in unique(j$block)) {
    inB <- j$block == B
    tmp <- data.frame(link = j$link, cF = ifelse(inB, j$wF * j$rel, 0),
                      cN = ifelse(inB, j$wN * j$rel, 0), dW = ifelse(inB, j$wF - j$wN, 0))
    agg <- stats::aggregate(cbind(cF, cN, dW) ~ link, tmp, sum)
    k <- merge(j, agg, by = "link")
    kB <- k$block == B
    dF <- 100 * k$Ibar * k$wF * (ifelse(kB, k$rel, 0) - k$cF)
    dN <- -100 * k$Ibar * k$wN * (ifelse(kB, k$rel, 0) - k$cN)
    dA <- -100 * k$Ibar * k$dW * k$wA * k$rel
    mk <- function(dd, phi) {
      m <- merge(data.frame(link = k$link, vy = k$vy, cat_id = k$cat_id, dd = dd), phi,
                 by.x = c("vy", "cat_id"), by.y = c("year", "cat_id"))
      data.frame(link = m$link, vy = m$vy, cell = m$cell, cat_id = m$cat_id, D = m$dd * m$phi)
    }
    se <- se_from_D(rbind(mk(dF, phiF), mk(dN, phiN), mk(dA, phiA)), rse_cell)
    res <- rbind(res, data.frame(block = B, contrib = pts$contrib[pts$block == B],
                                 se_indep = se[["se_indep"]], se_persist = se[["se_persist"]],
                                 se_bound = se[["se_bound"]]))
  }
  res
}

# ===========================================================================
# Tornqvist-type index with contemporaneous annual weights (D-38)
# ===========================================================================
#
# ln(P_t / P_t-1) = sum_i wbar_i,Y ln(p_i,t / p_i,t-1),  wbar_Y = (s_Y-1 + s_Y) / 2,
# for every month t of calendar year Y. With fixed geometric weights inside a
# year the monthly chain telescopes, so the December-to-December link is
# exactly a Tornqvist on the two adjacent CE years' expenditure shares. The
# approximation is treating calendar-year shares as the shares of the two
# December endpoints. This is the C-CPI-U's upper-level concept, applied to
# the project's categories.
#
# @param extend If TRUE, months after the last CE year use the last year's
#   shares on both sides (a geometric index); flagged in output.
build_index_tornqvist <- function(prices, shares, basket, extend = FALSE) {
  p <- prices[prices$cat_id %in% basket, c("cat_id", "date", "index")]
  wide <- tidyr::pivot_wider(p, id_cols = "date", names_from = "cat_id", values_from = "index")
  wide <- wide[order(wide$date), ]
  ok <- stats::complete.cases(wide[, basket])
  r <- rle(ok); ends <- cumsum(r$lengths); starts <- ends - r$lengths + 1L
  best <- which(r$values)[which.max(r$lengths[r$values])]
  wide <- wide[starts[best]:ends[best], ]
  P <- as.matrix(wide[, basket]); dates <- wide$date
  yr <- as.integer(format(dates, "%Y"))
  sh <- shares[shares$cat_id %in% basket, c("cat_id", "year", "share")]
  S <- tidyr::pivot_wider(sh, id_cols = "year", names_from = "cat_id", values_from = "share")
  S <- S[order(S$year), ]
  ys <- S$year
  S <- as.matrix(S[, basket]); rownames(S) <- ys
  if (anyNA(S)) stop("Missing shares in Tornqvist input.", call. = FALSE)
  S <- S / rowSums(S)
  y_last <- max(ys)
  # Base: the first December in the price panel whose year has shares.
  decs <- as.Date(sprintf("%d-12-01", ys))
  start <- match(decs[decs %in% dates][1], dates)
  if (is.na(start)) stop("No December base month with shares.", call. = FALSE)
  end <- if (extend) length(dates) else max(which(yr <= y_last))
  keep <- start:end
  idx <- rep(NA_real_, length(keep)); idx[1] <- 100; ext <- rep(FALSE, length(keep))
  for (k in 2:length(keep)) {
    t <- keep[k]; Y <- yr[t]
    s1 <- S[as.character(min(Y - 1L, y_last)), ]
    s2 <- S[as.character(min(Y, y_last)), ]
    ext[k] <- Y > y_last
    idx[k] <- idx[k - 1L] * exp(sum((s1 + s2) / 2 * log(P[t, ] / P[t - 1L, ])))
  }
  data.frame(date = dates[keep], index = idx, extended = ext)
}

#' Annual-average Tornqvist: annual mean prices, adjacent-year share averages.
build_index_tornqvist_annual <- function(prices, shares, basket) {
  p <- prices[prices$cat_id %in% basket, c("cat_id", "date", "index")]
  p$year <- as.integer(format(p$date, "%Y"))
  pb <- stats::aggregate(index ~ cat_id + year, p, mean)
  full <- stats::aggregate(index ~ cat_id + year, p, length)
  pb <- pb[full$index >= 11, ]  # October 2025 is absent from the CPI grid
  sh <- shares[shares$cat_id %in% basket, c("cat_id", "year", "share")]
  sh$share <- sh$share / stats::ave(sh$share, sh$year, FUN = sum)
  n_p <- table(pb$year); n_s <- table(sh$year)
  okp <- as.integer(names(n_p)[n_p == length(basket)]); oks <- as.integer(names(n_s)[n_s == length(basket)])
  ys <- sort(intersect(okp, oks))
  # Chain only over the first run of consecutive complete years.
  brk <- which(diff(ys) != 1L)
  if (length(brk)) ys <- ys[seq_len(brk[1])]
  out <- data.frame(year = ys[1], index = 100)
  lev <- 100
  for (Y in ys[-1]) {
    a <- merge(pb[pb$year == Y - 1L, c("cat_id", "index")], pb[pb$year == Y, c("cat_id", "index")],
               by = "cat_id", suffixes = c("0", "1"))
    s <- merge(sh[sh$year == Y - 1L, c("cat_id", "share")], sh[sh$year == Y, c("cat_id", "share")],
               by = "cat_id", suffixes = c("0", "1"))
    z <- merge(a, s, by = "cat_id")
    if (nrow(z) != length(basket)) stop("Annual Tornqvist: incomplete year ", Y, call. = FALSE)
    lev <- lev * exp(sum((z$share0 + z$share1) / 2 * log(z$index1 / z$index0)))
    out <- rbind(out, data.frame(year = Y, index = lev))
  }
  out
}
