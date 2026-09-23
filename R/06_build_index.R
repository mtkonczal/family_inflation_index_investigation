# ---------------------------------------------------------------------------
# 06_build_index.R   ---  PHASE 3 (revised 2026-09-23, decisions_log D-27 to D-30)
#
# Builds the group-specific price indices and the two yardsticks they are read
# against:
#
#   * the WEIGHT-SOURCE DISCREPANCY: the all-consumer-unit index on CEX shares
#     versus the same basket on CPI's own relative importance. A measure of
#     how much the weight concept matters for index LEVELS (D-24, D-27, D-28).
#   * SAMPLING ERROR on the family gap itself, from the CE published standard
#     errors by the delta method (D-28).
#
# Headline basket, specified before this re-run (D-30): pm_oer_all_in, the
# CPI-concept basket with owners' equivalent rent (D-29) and medical pooled
# (D-22). Co-headline: pm_ex_shelter. All baskets reported, with the range.
#
# Run from the project root:  Rscript R/06_build_index.R
#
# Outputs
#   data/derived/family_index.csv        basket x group x month index + 12m
#   data/derived/index_weights.csv       the cost weights actually used
#   output/tables/t00d_index_validation.txt
#   output/tables/t15_benchmark_residual.csv
#   output/tables/t16_headline_summary.csv
#   output/tables/t17_gap_decomposition.csv
#   output/tables/t18_benchmark_indices.csv
#   output/tables/t19_episodes.csv
#   output/tables/t20_window_gaps.csv
#   output/tables/t26_gap_sampling_se.csv      monthly SE of the 12-month gap
#   output/tables/t27_basket_verdicts.csv      every basket, both yardsticks
#   output/tables/t28_cumulative_gaps.csv      cumulative gaps with 95% CIs
#   output/tables/t29_price_update_variants.csv
#   output/figures/f08_index_12m.png, f09_gap_vs_errorbar.png,
#                  f10_cumulative.png, f11_gap_contributions.png
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/index_build.R")
source("R/functions/ce_tables.R")

LOG <- file.path(DIR_TAB, "t00d_index_validation.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }
say("# Index validation log"); say("# built_at: ", VINTAGE); say("")

tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
prices <- readr::read_csv(file.path(DIR_DER, "cpi_category_index.csv"),
                          show_col_types = FALSE,
                          col_types = readr::cols(cat_id = "c"))
shares <- readr::read_csv(file.path(DIR_DER, "cex_shares_long.csv"),
                          show_col_types = FALSE,
                          col_types = readr::cols(cat_id = "c", characteristics_code = "c"))
cpi <- readRDS(file.path(DIR_RAW, "cpi_raw.rds"))
xw <- readr::read_csv(file.path(DIR_XWALK, "cex_to_cpi.csv"),
                      col_types = readr::cols(.default = readr::col_character())) |>
  dplyr::filter(!is.na(cpi_item_code))

LAG <- 2L   # CPI convention since the 2023 move to annual weight updates
D0 <- as.Date("2019-12-01")

mapped   <- sort(unique(prices$cat_id))
SHELTER  <- tax$cat_id[tax$major == "Housing"]
HOUSINGX <- tax$cat_id[tax$major %in% c("Housing", "Utilities", "Household ops")]
MEDICAL  <- tax$cat_id[tax$major == "Health"]
late <- prices |> dplyr::summarise(first = min(date), .by = cat_id) |>
  dplyr::filter(first > as.Date("1998-01-01")) |> dplyr::pull(cat_id)

GROUPS <- c(all_cu = "All consumer units",
            families_kids = "Families with children",
            single_other = "Single-person and other CUs",
            married_kids = "Married couple with children",
            single_parent = "One parent, child under 18",
            married_nokids = "Married couple only")
CODE2GROUP <- c("01" = "all_cu", "03" = "married_nokids", "04" = "married_kids",
                "09" = "single_parent", "10" = "single_other", "F1" = "families_kids")
# Gap pairs reported throughout: the headline, and the within-family split.
PAIRS <- list(fam = c("families_kids", "single_other"),
              par = c("single_parent", "married_kids"),
              mk  = c("married_kids", "single_other"))
PAIR_LABEL <- c(fam = "Families with children minus single/other",
                par = "One parent minus married with children",
                mk  = "Married with children (04 alone) minus single/other")

# ===========================================================================
# 1. Inputs: relative importance, CE standard errors, rental equivalence
# ===========================================================================
say("## 1. Inputs")

ri_old <- ri_by_category(cpi, xw, fill = FALSE)
ri_cat <- ri_by_category(cpi, xw, fill = TRUE)
say(sprintf("  relative importance, category-months: %d strict (all components published) vs %d filled (D-27)",
            nrow(ri_old), nrow(ri_cat)))
fs <- ri_cat |> dplyr::filter(filled_share > 0) |>
  dplyr::summarise(months = dplyr::n(), mean_filled = mean(filled_share),
                   max_filled = max(filled_share), .by = cat_id) |>
  dplyr::left_join(dplyr::select(tax, cat_id, cat_label), by = "cat_id")
for (i in seq_len(nrow(fs))) {
  say(sprintf("    cat %s %-34s %3d months carried, mean %.1f%% / max %.1f%% of category RI",
              fs$cat_id[i], substr(fs$cat_label[i], 1, 34), fs$months[i],
              100 * fs$mean_filled[i], 100 * fs$max_filled[i]))
}

# --- CE standard errors and rental value (D-28, D-29) ---------------------
ce <- ce_se_panel("LB06")
# The 2012-2013 LB06 workbooks have no All-CU column. The All-CU universe is
# identical in every dimension (D-23); borrow from the quintile workbook and
# verify on the years both publish.
ce01 <- ce_se_panel("LB01") |> dplyr::filter(characteristics_code == "01") |>
  dplyr::mutate(dim = "LB06")
ov <- dplyr::inner_join(ce |> dplyr::filter(characteristics_code == "01"), ce01,
                        by = c("year", "cat_id"), suffix = c("", ".q")) |>
  dplyr::filter(!is.na(mean), !is.na(mean.q))
worst <- max(abs(ov$mean - ov$mean.q)); worst_se <- max(abs(ov$se - ov$se.q), na.rm = TRUE)
say(sprintf("  CE workbooks: All-CU LB06 vs LB01 on %d overlapping cells: max |diff| mean %.2f, SE %.2f",
            nrow(ov), worst, worst_se))
if (worst > 0) stop("All-CU CE workbook values differ across dimensions.", call. = FALSE)
ce <- dplyr::bind_rows(ce, dplyr::anti_join(ce01, ce, by = c("year", "characteristics_code", "cat_id")))
ce <- dplyr::bind_rows(ce, ce_pool(ce, c("04", "09"), "F1")) |>
  dplyr::mutate(group = CODE2GROUP[characteristics_code]) |>
  dplyr::filter(!is.na(group))

# Reconcile against the flat-file dollars the index actually uses.
rec <- ce |> dplyr::filter(cat_id %in% tax$cat_id) |>
  dplyr::inner_join(dplyr::select(shares, group, year, cat_id, dollars),
                    by = c("group", "year", "cat_id")) |>
  dplyr::filter(!is.na(mean)) |>
  dplyr::mutate(d = mean - dollars, rel = d / pmax(dollars, 1))
say(sprintf("  CE workbook means vs flat files: %d cells, %d exact, max |diff| $%.0f, max relative %.2f%%",
            nrow(rec), sum(abs(rec$d) < 0.5), max(abs(rec$d)), 100 * max(abs(rec$rel))))
if (any(abs(rec$d) > 50 & abs(rec$rel) > 0.02)) {
  stop("CE workbook means disagree with the flat files beyond revision noise.", call. = FALSE)
}

# RSE panel. Suppressed or tiny cells ("c/") have no SE; carry the same
# group-category's RSE from the nearest year and count how often.
rse <- ce |> dplyr::filter(!cat_id %in% c("NCU", "TOTALEXP")) |>
  dplyr::mutate(cat_id = dplyr::recode(cat_id, RENTVAL = "H0")) |>
  dplyr::select(group, year, cat_id, rse) |>
  tidyr::complete(group, year, cat_id) |>
  dplyr::arrange(group, cat_id, year) |>
  dplyr::mutate(was_na = is.na(rse)) |>
  dplyr::group_by(group, cat_id) |> tidyr::fill(rse, .direction = "downup") |>
  dplyr::ungroup()
say(sprintf("  RSE cells: %d, of which %d carried from an adjacent year (no SE published)",
            nrow(rse), sum(rse$was_na)))
rse <- dplyr::select(rse, -was_na)

rentval <- ce |> dplyr::filter(cat_id == "RENTVAL") |>
  dplyr::transmute(group, year, rentval_annual = 12 * mean)
totexp <- dplyr::distinct(shares, group, year, totalexp)

# Validation: implied all-CU OER-to-rent dollar ratio against CPI's own RI ratio.
cn <- cpi_national(cpi)
ri_ratio <- cn |> dplyr::filter(item_code %in% c("SEHC", "SEHA"), !is.na(weight),
                                format(date, "%m") == "12") |>
  dplyr::select(item_code, date, weight) |>
  tidyr::pivot_wider(names_from = item_code, values_from = weight) |>
  dplyr::transmute(year = as.integer(format(date, "%Y")), cpi_ratio = SEHC / SEHA)
oer_chk <- rentval |> dplyr::filter(group == "all_cu") |>
  dplyr::inner_join(shares |> dplyr::filter(group == "all_cu", cat_id == "07") |>
                      dplyr::select(year, rent = dollars), by = "year") |>
  dplyr::mutate(ce_ratio = rentval_annual / rent) |>
  dplyr::left_join(ri_ratio, by = "year")
say("  OER validation: all-CU rental value / rent outlays (CE) vs SEHC / SEHA relative importance (CPI, December)")
for (i in seq_len(nrow(oer_chk))) {
  say(sprintf("    %d  CE %.2f   CPI %s", oer_chk$year[i], oer_chk$ce_ratio[i],
              ifelse(is.na(oer_chk$cpi_ratio[i]), "  n/a", sprintf("%.2f", oer_chk$cpi_ratio[i]))))
}
rv <- rentval |> dplyr::filter(year == 2024L) |>
  dplyr::inner_join(dplyr::filter(totexp, year == 2024L), by = c("group", "year"))
say("  2024 rental value of owned home, share of total expenditures:")
for (i in seq_len(nrow(rv))) {
  say(sprintf("    %-16s $%6.0f / yr   %5.1f%%", rv$group[i], rv$rentval_annual[i],
              100 * rv$rentval_annual[i] / rv$totalexp[i]))
}

# Health insurance diagnostic that motivates D-30.
hc <- function(code) {
  s <- cn[cn$item_code == code & !is.na(cn$value), ]
  100 * (s$value[s$date == max(prices$date)] / s$value[s$date == D0] - 1)
}
say(sprintf("  CPI Dec 2019 to %s: all items %+.1f%%, health insurance (SEME) %+.1f%%, rent (SEHA) %+.1f%%, OER (SEHC) %+.1f%%",
            format(max(prices$date), "%Y-%m"), hc("SA0"), hc("SEME"), hc("SEHA"), hc("SEHC")))
say("")

# ===========================================================================
# 2. Basket specifications
# ===========================================================================
sh0 <- shares |> dplyr::select(group, cat_id, year, share = share_raw)
base <- list(prices = dplyr::select(prices, cat_id, date, index), shares = sh0, ri = ri_cat)
pm   <- pool_block(base$prices, base$shares, ri_cat, MEDICAL, "M0")
oer  <- add_oer(base$prices, base$shares, ri_cat, rentval, totexp, cpi)
pmo  <- add_oer(pm$prices, pm$shares, pm$ri, rentval, totexp, cpi)

SPECS <- list(
  all_in          = c(base, list(cats = mapped)),
  ex_shelter      = c(base, list(cats = setdiff(mapped, SHELTER))),
  ex_housing      = c(base, list(cats = setdiff(mapped, HOUSINGX))),
  all_in_long     = c(base, list(cats = setdiff(mapped, late))),
  ex_shelter_long = c(base, list(cats = setdiff(mapped, c(SHELTER, late)))),
  pm_all_in       = c(pm,   list(cats = c(setdiff(mapped, MEDICAL), "M0"))),
  pm_ex_shelter   = c(pm,   list(cats = c(setdiff(mapped, c(MEDICAL, SHELTER)), "M0"))),
  oer_all_in      = c(oer,  list(cats = c(setdiff(mapped, "06"), "H0"))),
  pm_oer_all_in   = c(pmo,  list(cats = c(setdiff(mapped, c(MEDICAL, "06")), "M0", "H0")))
)
HEADLINE <- "pm_oer_all_in"; COHEAD <- "pm_ex_shelter"
BLAB <- c(all_in = "All-in, no owner shelter (37 categories)",
          ex_shelter = "Ex-shelter (34)",
          ex_housing = "Ex-housing (25)",
          all_in_long = "All-in, long panel (34)",
          ex_shelter_long = "Ex-shelter, long panel (31)",
          pm_all_in = "All-in, medical pooled (34)",
          pm_ex_shelter = "Ex-shelter, medical pooled (31)",
          oer_all_in = "CPI concept with OER (37)",
          pm_oer_all_in = "CPI concept with OER, medical pooled (34)")

say("## 2. Baskets")
for (b in names(SPECS)) {
  say(sprintf("  %-16s %2d categories  %s%s", b, length(SPECS[[b]]$cats), BLAB[[b]],
              ifelse(b == HEADLINE, "   <- HEADLINE (D-30)",
                     ifelse(b == COHEAD, "   <- co-headline", ""))))
}
say("")

# ===========================================================================
# 3. Group indices
# ===========================================================================
say("## 3. Group indices")
res <- NULL; wts <- NULL
for (b in names(SPECS)) {
  sp <- SPECS[[b]]
  for (g in names(GROUPS)) {
    s <- sp$shares |> dplyr::filter(group == g) |> dplyr::select(cat_id, year, share)
    bi <- build_index(sp$prices, s, sp$cats, lag_years = LAG, price_update = "full")
    res <- dplyr::bind_rows(res, bi$index |>
      dplyr::mutate(group = g, group_label = GROUPS[[g]], basket = b))
    wts <- dplyr::bind_rows(wts, bi$weights |> dplyr::mutate(group = g, basket = b))
  }
  r <- res[res$basket == b, ]
  say(sprintf("  %-16s %s to %s   months on 'pivot' fallback (no prices for vintage year): %d",
              b, min(r$date), max(r$date), sum(r$pu_fallback[r$group == "all_cu"])))
}
res <- res |> dplyr::select(basket, group, group_label, date, index, chg_12m,
                            n_cats, w_ref_year)
write_derived(res, "family_index")
write_derived(wts, "index_weights")
wchk <- wts |> dplyr::summarise(s = sum(weight), .by = c(basket, group, date))
say(sprintf("  weight sums: min %.9f max %.9f", min(wchk$s), max(wchk$s)))
if (max(abs(wchk$s - 1)) > 1e-8) stop("Cost weights do not sum to 1.", call. = FALSE)
say("")

pair_gap <- function(pr) {
  res |> dplyr::filter(group %in% pr) |>
    dplyr::select(basket, group, date, chg_12m) |>
    tidyr::pivot_wider(names_from = group, values_from = chg_12m) |>
    dplyr::transmute(basket, date, gap_12m = .data[[pr[1]]] - .data[[pr[2]]]) |>
    dplyr::filter(!is.na(gap_12m))
}
gaps <- dplyr::bind_rows(lapply(names(PAIRS), function(k)
  pair_gap(PAIRS[[k]]) |> dplyr::mutate(pair = k)))
gap <- dplyr::filter(gaps, pair == "fam")

# ===========================================================================
# 4. Weight-source discrepancy (the D-24 "error bar", corrected per D-27)
# ===========================================================================
say("## 4. Weight-source discrepancy: all-CU index, CEX shares vs CPI relative importance")
say("   Same basket, formula and prices; only the weight source differs. This bounds")
say("   how much the weight CONCEPT moves index levels. It is not sampling error in")
say("   the family gap, most of which it differences out (D-28).")
bench <- NULL
for (b in names(SPECS)) {
  sp <- SPECS[[b]]
  a <- res |> dplyr::filter(basket == b, group == "all_cu") |>
    dplyr::transmute(basket = b, source = "CEX weights", date, index, chg_12m)
  r <- try(build_index_ri(sp$prices, sp$ri, sp$cats), silent = TRUE)
  if (inherits(r, "try-error")) { say("   [", b, "] no RI benchmark"); next }
  bench <- dplyr::bind_rows(bench, a, r |>
    dplyr::transmute(basket = b, source = "CPI relative importance", date, index, chg_12m))
}
readr::write_csv(bench, file.path(DIR_TAB, "t18_benchmark_indices.csv"))
resid <- bench |>
  dplyr::select(basket, date, source, chg_12m) |>
  tidyr::pivot_wider(names_from = source, values_from = chg_12m) |>
  dplyr::rename(cex = `CEX weights`, ri = `CPI relative importance`) |>
  dplyr::filter(!is.na(cex), !is.na(ri)) |>
  dplyr::mutate(resid_pp = cex - ri)
readr::write_csv(resid, file.path(DIR_TAB, "t15_benchmark_residual.csv"))

# The pre-D-27 construction, for the before/after record: strict RI and
# pivot-only price updating, on the two baskets the old verdict used.
old_eb <- NULL
for (b in c("ex_shelter", "pm_ex_shelter")) {
  sp <- SPECS[[b]]
  ri_o <- if (b == "ex_shelter") ri_old else pool_block(base$prices, base$shares, ri_old, MEDICAL, "M0")$ri
  px_o <- if (b == "ex_shelter") sp$prices else pool_block(base$prices, base$shares, ri_old, MEDICAL, "M0")$prices
  sh_o <- sp$shares |> dplyr::filter(group == "all_cu") |> dplyr::select(cat_id, year, share)
  a <- build_index(px_o, sh_o, sp$cats, LAG, price_update = "pivot")$index
  r <- build_index_ri(px_o, ri_o, sp$cats, carry = FALSE)
  z <- dplyr::inner_join(dplyr::select(a, date, cex = chg_12m), dplyr::select(r, date, ri = chg_12m),
                         by = "date") |> dplyr::filter(!is.na(cex), !is.na(ri))
  old_eb <- dplyr::bind_rows(old_eb, tibble::tibble(basket = b, months = nrow(z),
    from = min(z$date), to = max(z$date), eb = mean(abs(z$cex - z$ri))))
}

say("")
say("   basket            months  from     to        mean |resid|   2021+     corr")
for (b in unique(resid$basket)) {
  r <- resid[resid$basket == b, ]
  say(sprintf("   %-16s %5d   %s  %s   %6.3f      %6.3f    %.3f", b, nrow(r),
              format(min(r$date), "%Y-%m"), format(max(r$date), "%Y-%m"),
              mean(abs(r$resid_pp)), mean(abs(r$resid_pp[r$date >= as.Date("2021-01-01")])),
              stats::cor(r$cex, r$ri)))
}
say("   pre-D-27 construction (strict RI, pivot price updating), for the record:")
for (i in seq_len(nrow(old_eb))) {
  say(sprintf("   %-16s %5d   %s  %s   %6.3f", old_eb$basket[i], old_eb$months[i],
              format(old_eb$from[i], "%Y-%m"), format(old_eb$to[i], "%Y-%m"), old_eb$eb[i]))
}
pub <- cn |> dplyr::filter(item_code == "SA0") |> dplyr::select(date, sa0 = value)
pub$sa0_12m <- 100 * (pub$sa0 / pub$sa0[match(pub$date - months(12), pub$date)] - 1)
vs_pub <- res |> dplyr::filter(basket == HEADLINE, group == "all_cu") |>
  dplyr::inner_join(pub, by = "date") |> dplyr::filter(!is.na(chg_12m), !is.na(sa0_12m))
say(sprintf("   headline all-CU CEX-weighted index vs published CPI-U, %d months: mean %+.3f pp, mean |gap| %.3f pp",
            nrow(vs_pub), mean(vs_pub$chg_12m - vs_pub$sa0_12m), mean(abs(vs_pub$chg_12m - vs_pub$sa0_12m))))
say("")

# ===========================================================================
# 5. Sampling error of the gap (D-28)
# ===========================================================================
say("## 5. Sampling error of the 12-month gap, from CE standard errors (delta method)")
pi12_of <- function(px) {
  px |> dplyr::mutate(d12 = date - months(12)) |>
    dplyr::left_join(dplyr::select(px, cat_id, d12 = date, i12 = index), by = c("cat_id", "d12")) |>
    dplyr::transmute(cat_id, date, pi12 = 100 * (index / i12 - 1)) |>
    dplyr::filter(!is.na(pi12))
}
rse_g <- function(g) rse |> dplyr::filter(group == g) |> dplyr::select(year, cat_id, rse)
se_tab <- NULL
for (b in names(SPECS)) {
  p12 <- pi12_of(SPECS[[b]]$prices)
  for (k in names(PAIRS)) {
    pr <- PAIRS[[k]]
    wF <- wts |> dplyr::filter(basket == b, group == pr[1]) |> dplyr::select(date, cat_id, weight)
    wN <- wts |> dplyr::filter(basket == b, group == pr[2]) |> dplyr::select(date, cat_id, weight)
    se <- gap_se_12m(wF, wN, rse_g(pr[1]), rse_g(pr[2]), p12, LAG) |>
      dplyr::filter(as.integer(format(date, "%Y")) - LAG >= min(rse$year))
    se_tab <- dplyr::bind_rows(se_tab, se |> dplyr::mutate(basket = b, pair = k))
  }
}
se_tab <- se_tab |> dplyr::inner_join(gaps, by = c("basket", "pair", "date")) |>
  dplyr::mutate(z = gap_12m / se_gap)
readr::write_csv(se_tab, file.path(DIR_TAB, "t26_gap_sampling_se.csv"))
say("   basket / pair                                  months  mean gap  mean SE   |z|>1.96   share")
for (b in names(SPECS)) for (k in names(PAIRS)) {
  x <- se_tab[se_tab$basket == b & se_tab$pair == k, ]
  if (!nrow(x)) next
  say(sprintf("   %-16s %-28s %5d   %+6.3f   %6.3f    %4d      %4.0f%%", b, k, nrow(x),
              mean(x$gap_12m), mean(x$se_gap), sum(abs(x$z) > 1.96), 100 * mean(abs(x$z) > 1.96)))
}
say("   (5 percent of months exceeding 1.96 is what pure noise would produce)")
say("")

# ===========================================================================
# 6. Verdict table: every basket, both yardsticks, common months
# ===========================================================================
say("## 6. Family gap against both yardsticks")
say("   The discrepancy ratio compares mean |gap| with mean |resid| over the SAME months.")
verd <- NULL
for (b in names(SPECS)) for (k in names(PAIRS)) {
  g <- gaps[gaps$basket == b & gaps$pair == k, ]
  r <- resid[resid$basket == b, ]
  cm <- g$date[g$date %in% r$date]
  s <- se_tab[se_tab$basket == b & se_tab$pair == k, ]
  verd <- dplyr::bind_rows(verd, tibble::tibble(
    basket = b, pair = k, months = nrow(g), mean_gap = mean(g$gap_12m),
    mean_abs_gap = mean(abs(g$gap_12m)),
    common_months = length(cm),
    mean_abs_gap_common = mean(abs(g$gap_12m[g$date %in% cm])),
    weight_source_disc = mean(abs(r$resid_pp[r$date %in% cm])),
    disc_ratio = mean_abs_gap_common / weight_source_disc,
    se_months = nrow(s), mean_se = if (nrow(s)) mean(s$se_gap) else NA_real_,
    share_sig = if (nrow(s)) mean(abs(s$z) > 1.96) else NA_real_))
}
readr::write_csv(verd, file.path(DIR_TAB, "t27_basket_verdicts.csv"))
say("   basket            pair  months  mean gap  mean|gap|  disc   ratio   mean SE  sig months")
for (i in seq_len(nrow(verd))) {
  v <- verd[i, ]
  say(sprintf("   %-16s %-4s  %5d   %+6.3f    %6.3f   %5.3f  %5.2f   %6.3f   %4.0f%%",
              v$basket, v$pair, v$months, v$mean_gap, v$mean_abs_gap, v$weight_source_disc,
              v$disc_ratio, v$mean_se, 100 * v$share_sig))
}
say("")

# ===========================================================================
# 7. Cumulative change, with sampling confidence intervals
# ===========================================================================
say("## 7. Cumulative price change and cumulative gap")
LASTD <- max(res$date)
WINDOWS <- list(c("2019-12-01"), c("2020-12-01"), c("2013-12-01"), c("2010-12-01"))
summ <- NULL; cumg <- NULL
for (b in names(SPECS)) {
  r <- res[res$basket == b, ]
  for (w in WINDOWS) {
    d0 <- as.Date(w[1]); if (!d0 %in% r$date) next
    for (g in names(GROUPS)) {
      x <- r[r$group == g, ]
      i0 <- x$index[match(d0, x$date)]; i1 <- x$index[match(LASTD, x$date)]
      summ <- dplyr::bind_rows(summ, tibble::tibble(basket = b, group = g, from = d0, to = LASTD,
        cum_pct = 100 * (i1 / i0 - 1),
        annualized = 100 * ((i1 / i0)^(365.25 / as.numeric(LASTD - d0)) - 1)))
    }
    sp <- SPECS[[b]]
    for (k in names(PAIRS)) {
      pr <- PAIRS[[k]]
      cs <- lapply(pr, function(g) cum_se(r[r$group == g, ], wts[wts$basket == b & wts$group == g, ],
                                          sp$prices, rse_g(g), d0, LASTD))
      cF <- summ$cum_pct[summ$basket == b & summ$group == pr[1] & summ$from == d0]
      cN <- summ$cum_pct[summ$basket == b & summ$group == pr[2] & summ$from == d0]
      cumg <- dplyr::bind_rows(cumg, tibble::tibble(basket = b, pair = k, from = d0, to = LASTD,
        cum_1 = cF, cum_2 = cN, gap_pp = cF - cN,
        se_indep = sqrt(cs[[1]][["se_indep"]]^2 + cs[[2]][["se_indep"]]^2),
        se_corr  = sqrt(cs[[1]][["se_corr"]]^2 + cs[[2]][["se_corr"]]^2)))
    }
  }
}
readr::write_csv(summ, file.path(DIR_TAB, "t16_headline_summary.csv"))
readr::write_csv(cumg, file.path(DIR_TAB, "t28_cumulative_gaps.csv"))
for (k in names(PAIRS)) {
  say("   ", PAIR_LABEL[[k]], ", since December 2019 (95% CI: uncorrelated / correlated vintages)")
  z <- cumg[cumg$pair == k & cumg$from == D0, ]
  for (i in seq_len(nrow(z))) {
    say(sprintf("     %-16s %+7.2f%% vs %+7.2f%%   gap %+5.2f pp   +/- %s / %s%s", z$basket[i],
                z$cum_1[i], z$cum_2[i], z$gap_pp[i],
                ifelse(is.na(z$se_indep[i]), " n/a", sprintf("%.2f", 1.96 * z$se_indep[i])),
                ifelse(is.na(z$se_corr[i]), " n/a", sprintf("%.2f", 1.96 * z$se_corr[i])),
                ifelse(z$basket[i] == HEADLINE, "   <- headline", "")))
  }
  say(sprintf("     range across the %d baskets: %+.2f to %+.2f pp", nrow(z), min(z$gap_pp), max(z$gap_pp)))
  say("")
}

# ===========================================================================
# 8. Price-updating variants (D-27)
# ===========================================================================
say("## 8. Price-updating variants, effect on the family gap (12-month, pp)")
puv <- NULL
for (b in c("ex_shelter", "pm_ex_shelter", HEADLINE)) {
  sp <- SPECS[[b]]
  for (pu in c("full", "pivot", "none")) {
    ix <- lapply(PAIRS$fam, function(g) {
      s <- sp$shares |> dplyr::filter(group == g) |> dplyr::select(cat_id, year, share)
      build_index(sp$prices, s, sp$cats, LAG, price_update = pu)$index
    })
    z <- dplyr::inner_join(dplyr::select(ix[[1]], date, a = chg_12m, ia = index),
                           dplyr::select(ix[[2]], date, b = chg_12m, ib = index), by = "date")
    cum <- function(v) 100 * (v[z$date == LASTD] / v[z$date == D0] - 1)
    puv <- dplyr::bind_rows(puv, tibble::tibble(basket = b, price_update = pu,
      mean_gap = mean(z$a - z$b, na.rm = TRUE), mean_abs_gap = mean(abs(z$a - z$b), na.rm = TRUE),
      cum_gap_since_2019 = cum(z$ia) - cum(z$ib)))
  }
}
readr::write_csv(puv, file.path(DIR_TAB, "t29_price_update_variants.csv"))
for (i in seq_len(nrow(puv))) {
  say(sprintf("   %-16s %-5s  mean gap %+.3f  mean |gap| %.3f  cumulative since Dec 2019 %+.2f pp",
              puv$basket[i], puv$price_update[i], puv$mean_gap[i], puv$mean_abs_gap[i],
              puv$cum_gap_since_2019[i]))
}
say("")

# ===========================================================================
# 9. Gap decomposition
# ===========================================================================
# gap_12m ~= sum_i (w_F,i - w_N,i) * (pi_i,12m - pibar_12m), weights at t.
# Because both weight vectors sum to one, subtracting pibar (the all-CU
# weighted 12-month change) leaves the total unchanged but attributes it
# properly: a category contributes only if families over- or under-weight it
# AND its price outran or lagged the average (D-34). The pre-D-34 form,
# (w_F - w_N) * pi12, credited every over-weighted category merely for having
# positive inflation; it is kept as contrib_raw. The approximation residual
# is reported.
decomp <- NULL
for (b in names(SPECS)) {
  p12 <- pi12_of(SPECS[[b]]$prices)
  wF <- wts |> dplyr::filter(basket == b, group == "families_kids") |> dplyr::select(cat_id, date, wF = weight)
  wN <- wts |> dplyr::filter(basket == b, group == "single_other") |> dplyr::select(cat_id, date, wN = weight)
  wA <- wts |> dplyr::filter(basket == b, group == "all_cu") |> dplyr::select(cat_id, date, wA = weight)
  decomp <- dplyr::bind_rows(decomp, dplyr::inner_join(wF, wN, by = c("cat_id", "date")) |>
    dplyr::inner_join(wA, by = c("cat_id", "date")) |>
    dplyr::inner_join(p12, by = c("cat_id", "date")) |>
    dplyr::mutate(pibar = sum(wA * pi12), .by = date) |>
    dplyr::mutate(basket = b, contrib = (wF - wN) * (pi12 - pibar), contrib_raw = (wF - wN) * pi12))
}
labs_x <- dplyr::bind_rows(dplyr::select(tax, cat_id, cat_label, major),
  tibble::tibble(cat_id = c("M0", "H0"), cat_label = c("Medical care (pooled)", "Owners' equivalent rent"),
                 major = c("Health", "Housing")))
decomp <- dplyr::left_join(decomp, labs_x, by = "cat_id")
readr::write_csv(decomp, file.path(DIR_TAB, "t17_gap_decomposition.csv"))
chk <- decomp |> dplyr::summarise(approx = sum(contrib), .by = c(basket, date)) |>
  dplyr::inner_join(gap, by = c("basket", "date"))
say("## 9. Gap decomposition check (sum of contributions vs actual index gap)")
say(sprintf("   mean |approximation error|: %.4f pp,  max %.4f pp",
            mean(abs(chk$approx - chk$gap_12m)), max(abs(chk$approx - chk$gap_12m))))
for (b in c(HEADLINE, COHEAD)) {
  say("   Mean contributions (relative-price form, D-34), ", b, ", since Jan 2020:")
  z <- decomp |> dplyr::filter(basket == b, date >= as.Date("2020-01-01")) |>
    dplyr::summarise(mc = mean(contrib), wF = mean(wF), wN = mean(wN), .by = cat_label) |>
    dplyr::arrange(dplyr::desc(abs(mc)))
  for (i in 1:8) say(sprintf("     %-40s w_F %5.2f%%  w_N %5.2f%%  contrib %+.3f pp",
                             substr(z$cat_label[i], 1, 40), 100 * z$wF[i], 100 * z$wN[i], z$mc[i]))
}
say("")

# ===========================================================================
# 10. Episodes and window averages
# ===========================================================================
say("## 10. Episodes: runs of 3+ months where the family gap exceeds 1.96 sampling SEs")
episodes <- NULL
for (b in c(HEADLINE, COHEAD, "oer_all_in", "all_in", "ex_shelter")) {
  a <- se_tab[se_tab$basket == b & se_tab$pair == "fam", ]
  a <- a[order(a$date), ]
  rr <- rle(abs(a$z) > 1.96); pos <- cumsum(c(1, utils::head(rr$lengths, -1)))
  idx <- which(rr$values & rr$lengths >= 3L)
  say(sprintf("   [%-16s] %d episode(s) in %d months", b, length(idx), nrow(a)))
  for (i in idx) {
    s0 <- pos[i]; e0 <- pos[i] + rr$lengths[i] - 1L; seg <- a$gap_12m[s0:e0]
    say(sprintf("     %s to %s (%2d mo)  mean %+.3f  peak %+.3f  mean SE %.3f",
                format(a$date[s0], "%Y-%m"), format(a$date[e0], "%Y-%m"), rr$lengths[i],
                mean(seg), seg[which.max(abs(seg))], mean(a$se_gap[s0:e0])))
    episodes <- dplyr::bind_rows(episodes, tibble::tibble(basket = b, from = a$date[s0],
      to = a$date[e0], months = rr$lengths[i], mean_gap = mean(seg),
      peak_gap = seg[which.max(abs(seg))], mean_se = mean(a$se_gap[s0:e0])))
  }
}
if (!is.null(episodes)) readr::write_csv(episodes, file.path(DIR_TAB, "t19_episodes.csv"))
say("")
say("## 11. Family gap averaged over named windows (pp)")
WIN <- list(c("2021-01-01", "2022-12-01"), c("2023-01-01", "2024-12-01"),
            c("2025-01-01", format(LASTD)))
winsum <- NULL
for (w in WIN) for (b in c(HEADLINE, COHEAD, "oer_all_in", "all_in", "ex_shelter")) {
  x <- gap[gap$basket == b & gap$date >= as.Date(w[1]) & gap$date <= as.Date(w[2]), ]
  winsum <- dplyr::bind_rows(winsum, tibble::tibble(basket = b, from = as.Date(w[1]),
    to = as.Date(w[2]), mean_gap = mean(x$gap_12m)))
}
for (w in WIN) {
  x <- winsum[winsum$from == as.Date(w[1]), ]
  say(sprintf("   %s to %s :  %s", substr(w[1], 1, 7), substr(w[2], 1, 7),
              paste(sprintf("%s %+.3f", x$basket, x$mean_gap), collapse = "  ")))
}
readr::write_csv(winsum, file.path(DIR_TAB, "t20_window_gaps.csv"))
say("")

# ===========================================================================
# 12. Figures
# ===========================================================================
ESP_NAVY <- "#2c3254"; ESP_RED <- "#ff8361"
theme_fii <- function(bs = 11) {
  ggplot2::theme_minimal(base_size = bs) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey88"),
      plot.title = ggplot2::element_text(face = "bold", size = bs + 3),
      plot.subtitle = ggplot2::element_text(colour = "grey30", size = bs),
      plot.caption = ggplot2::element_text(colour = "grey45", size = bs - 2, hjust = 0),
      legend.position = "top", legend.title = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"))
}
SRC <- paste0("Source: author's calculation from BLS CEX (weights, 2-year lagged vintage; rental value ",
              "of owned home from CE tables) and CPI-U item\nindices (NSA). Chained Laspeyres with BLS-style ",
              "price-updated cost weights. Vintage ", substr(VINTAGE, 1, 10), ".")
FB <- c(HEADLINE, COHEAD)
flab <- function(x) factor(BLAB[x], levels = BLAB[FB])

f8 <- res |> dplyr::filter(basket %in% FB, group %in% PAIRS$fam, !is.na(chg_12m)) |>
  dplyr::mutate(basket = flab(basket), grp = GROUPS[group])
p8 <- ggplot2::ggplot(f8, ggplot2::aes(date, chg_12m, colour = grp)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.3) +
  ggplot2::geom_line(linewidth = 0.75) +
  ggplot2::facet_wrap(~basket, ncol = 1) +
  ggplot2::scale_colour_manual(values = c(ESP_NAVY, ESP_RED)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(title = "Twelve-month inflation, families with children and single-person households",
    subtitle = "Group-specific price index, 12-month percent change.",
    x = NULL, y = "12-month change", caption = SRC) + theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f08_index_12m.png"), p8, width = 10, height = 7, dpi = 200, bg = "white")

eb_b <- verd |> dplyr::filter(pair == "fam") |> dplyr::select(basket, weight_source_disc)
f9 <- se_tab |> dplyr::filter(basket %in% FB, pair == "fam") |>
  dplyr::left_join(eb_b, by = "basket") |> dplyr::mutate(basket = flab(basket))
p9 <- ggplot2::ggplot(f9, ggplot2::aes(date, gap_12m)) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = -weight_source_disc, ymax = weight_source_disc),
                       fill = "grey92") +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = gap_12m - 1.96 * se_gap, ymax = gap_12m + 1.96 * se_gap),
                       fill = "#6f8fd0", alpha = 0.45) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey40", linewidth = 0.35) +
  ggplot2::geom_line(colour = ESP_NAVY, linewidth = 0.8) +
  ggplot2::facet_wrap(~basket, ncol = 1) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "The family inflation gap, with its sampling error",
    subtitle = paste0("Line: 12-month gap, families with children minus single-person and other CUs. ",
      "Blue band: 95% sampling interval\nfrom CE standard errors. Grey band: mean all-CU ",
      "weight-source discrepancy (CEX vs CPI weights) over the same months."),
    x = NULL, y = "Gap (percentage points)", caption = SRC) + theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f09_gap_vs_errorbar.png"), p9, width = 10, height = 7, dpi = 200, bg = "white")

f10 <- res |> dplyr::filter(basket %in% FB, group %in% c(PAIRS$fam, "single_parent", "married_kids"),
                            date >= D0) |>
  dplyr::group_by(basket, group) |>
  dplyr::mutate(cum = 100 * (index / index[which.min(date)] - 1)) |> dplyr::ungroup() |>
  dplyr::mutate(basket = flab(basket), grp = GROUPS[group])
p10 <- ggplot2::ggplot(f10, ggplot2::aes(date, cum, colour = grp)) +
  ggplot2::geom_line(linewidth = 0.8) +
  ggplot2::facet_wrap(~basket, ncol = 2) +
  ggplot2::scale_colour_manual(values = c(ESP_NAVY, "#7d90b0", ESP_RED, "#e8a07f")) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(title = "Cumulative price change since December 2019",
    x = NULL, y = "Cumulative change since Dec 2019", caption = SRC) +
  theme_fii() + ggplot2::guides(colour = ggplot2::guide_legend(nrow = 2))
ggplot2::ggsave(file.path(DIR_FIG, "f10_cumulative.png"), p10, width = 11, height = 5.5, dpi = 200, bg = "white")

f11 <- decomp |> dplyr::filter(basket %in% FB, date >= as.Date("2020-01-01")) |>
  dplyr::summarise(mc = mean(contrib, na.rm = TRUE), .by = c(basket, cat_label)) |>
  dplyr::filter(abs(mc) >= 0.008) |>
  dplyr::mutate(basket = flab(basket), cat_label = forcats::fct_reorder(substr(cat_label, 1, 40), mc))
p11 <- ggplot2::ggplot(f11, ggplot2::aes(mc, cat_label, fill = mc > 0)) +
  ggplot2::geom_col(width = 0.72) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey25", linewidth = 0.4) +
  ggplot2::facet_wrap(~basket, scales = "free", ncol = 2) +
  ggplot2::scale_fill_manual(values = c(ESP_RED, ESP_NAVY), guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "What drives the family gap",
    subtitle = paste0("Mean contribution to the 12-month gap, 2020-2026: (family share - single share) x ",
      "(category inflation - average inflation).\nA category matters only if families buy more or less of it AND its price outran or lagged the average."),
    x = "Mean contribution to the gap (pp)", y = NULL, caption = SRC) + theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f11_gap_contributions.png"), p11, width = 12, height = 6, dpi = 200, bg = "white")

message("\nValidation log: ", LOG)
