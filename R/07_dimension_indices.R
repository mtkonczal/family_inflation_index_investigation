# ---------------------------------------------------------------------------
# 07_dimension_indices.R   ---  PHASE 4
#
# Runs the same index machinery on other CEX demographic dimensions.
# Revised 2026-09-23 (decisions_log D-27 to D-30): shared RI fill, OER basket,
# CE sampling error, gaps compared with the weight-source discrepancy on
# common months, and an LB05 household-size cut (D-32).
#
# WHY: a family gap (or its absence) means little without a benchmark. These
# cuts put it next to gaps the literature expects to exist, on identical
# machinery and yardsticks:
#
#   TENURE (LB17, owner vs renter). Every phase of this project pointed at
#   housing tenure as the thing that actually drives dispersion, while family
#   status drove none of it. Tenure is therefore the natural subject, not the
#   confound it was treated as in Phases 1b and 3.
#
#   INCOME (LB01 quintiles, LB15 deciles). There is a live literature finding
#   a real income gradient in inflation (Jaravel 2021; Argente and Lee 2021;
#   Klick and Stockburger at BLS). If this pipeline finds a gradient of the
#   expected sign there, it can resolve differences of that size, and the
#   family gap can be read against it.
#
#   SIZE (LB05, four-person versus one-person CUs), the pre-specified
#   group-definition robustness check for the family cut.
#
# The index layer is dimension-agnostic by construction: 06_build_index.R and
# functions/index_build.R contain no reference to any demographic dimension.
# Only the group definitions and the CEX pull change.
#
# Run from the project root:  Rscript R/07_dimension_indices.R
#
# Outputs
#   data/derived/dimension_shares.csv    shares for every dimension and group
#   data/derived/dimension_index.csv     indices for every dimension and group
#   output/tables/t00e_dimension_validation.txt
#   output/tables/t21_dimension_gaps.csv
#   output/tables/t22_dimension_decomposition.csv
#   output/figures/f12_dimension_gaps.png
#   output/figures/f13_income_gradient.png
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")
source("R/functions/index_build.R")
source("R/functions/ce_tables.R")

LOG <- file.path(DIR_TAB, "t00e_dimension_validation.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }
say("# Other-dimension index validation log"); say("# built_at: ", VINTAGE); say("")

cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))
cpi <- readRDS(file.path(DIR_RAW, "cpi_raw.rds"))
tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
prices <- readr::read_csv(file.path(DIR_DER, "cpi_category_index.csv"),
                          show_col_types = FALSE, col_types = readr::cols(cat_id = "c"))
xw <- readr::read_csv(file.path(DIR_XWALK, "cex_to_cpi.csv"),
                      col_types = readr::cols(.default = readr::col_character())) |>
  dplyr::filter(!is.na(cpi_item_code))

LAG <- 2L
mapped   <- sort(unique(prices$cat_id))
SHELTER  <- tax$cat_id[tax$major == "Housing"]
HOUSINGX <- tax$cat_id[tax$major %in% c("Housing", "Utilities", "Household ops")]
MEDICAL  <- tax$cat_id[tax$major == "Health"]

# ===========================================================================
# 1. Dimension definitions
# ===========================================================================
# `focus` minus `ref` is the headline gap for each dimension, chosen so a
# POSITIVE gap means the group usually assumed to be worse off has higher
# inflation. That keeps signs interpretable across cuts.
DIMS <- list(
  tenure = list(
    dim = "LB17", label = "Housing tenure",
    groups = c("01" = "All consumer units", "02" = "Homeowners",
               "05" = "Renters", "03" = "Homeowner with mortgage",
               "04" = "Homeowner without mortgage"),
    focus = "05", ref = "02",
    gap_label = "Renters minus homeowners"),
  income_quintile = list(
    dim = "LB01", label = "Income quintile",
    groups = c("01" = "All consumer units", "02" = "Lowest quintile",
               "03" = "Second quintile", "04" = "Third quintile",
               "05" = "Fourth quintile", "06" = "Highest quintile"),
    focus = "02", ref = "06",
    gap_label = "Lowest minus highest income quintile"),
  income_decile = list(
    dim = "LB15", label = "Income decile",
    groups = c("01" = "All consumer units", "02" = "Lowest decile",
               "06" = "Fifth decile", "11" = "Highest decile"),
    focus = "02", ref = "11",
    gap_label = "Lowest minus highest income decile"),
  # Pre-specified group-definition robustness (METHODS section 7, D-32): a
  # size cut instead of a composition cut. Four-person CUs are mostly
  # families with children; one-person CUs are the purest "single" group.
  cu_size = list(
    dim = "LB05", label = "Size of consumer unit",
    groups = c("01" = "All consumer units", "02" = "One person",
               "06" = "Four people", "07" = "Five or more people"),
    focus = "06", ref = "02",
    gap_label = "Four-person minus one-person CUs")
)

BASKETS <- list(all_in = mapped,
                ex_shelter = setdiff(mapped, SHELTER),
                ex_housing = setdiff(mapped, HOUSINGX),
                pm_ex_shelter = c(setdiff(mapped, c(MEDICAL, SHELTER)), "M0"),
                pm_oer_all_in = c(setdiff(mapped, c(MEDICAL, "06")), "M0", "H0"))
FOCUS_B <- c("pm_oer_all_in", "pm_ex_shelter")   # headline and co-headline (D-30)

# ===========================================================================
# 2. Shared inputs and yardsticks from Phase 3
# ===========================================================================
ri_cat <- ri_by_category(cpi, xw, fill = TRUE)

# Weight-source discrepancy: dimension-independent, the all-CU residual per
# basket and month from Phase 3. Compared with each gap on COMMON months (D-27).
resid <- readr::read_csv(file.path(DIR_TAB, "t15_benchmark_residual.csv"),
                         show_col_types = FALSE)
say("## Weight-source discrepancy carried over from Phase 3 (mean over all its months)")
for (b in names(BASKETS)) {
  r <- resid[resid$basket == b, ]
  say(sprintf("   %-16s %.3f pp  (%s to %s)", b, mean(abs(r$resid_pp)),
              format(min(r$date), "%Y-%m"), format(max(r$date), "%Y-%m")))
}
say("")

# ===========================================================================
# 3. Build shares and indices for each dimension
# ===========================================================================
all_shares <- NULL; all_index <- NULL; all_wts <- NULL; all_rse <- NULL
prices_by_b <- list()

for (nm in names(DIMS)) {
  D <- DIMS[[nm]]
  say("## ", D$label, " (", D$dim, ")")

  d <- cex_expend_panel(cex, tax, D$dim, names(D$groups), verbose = FALSE)
  d <- cex_repair_all_cu(cex, d, fallback_dim = "LB04", verbose = FALSE)
  d <- dplyr::filter(d, characteristics_code %in% names(D$groups))

  gm <- utils::capture.output(
    cex_assert_no_interior_gaps(d, label = paste(D$dim, "EXPEND")), type = "message")
  for (m in gm) say(m)
  am <- utils::capture.output(
    cex_assert_additive(d, tax, label = D$dim), type = "message")
  for (m in am) say(m)

  tot <- d |> dplyr::filter(item_code == "TOTALEXP") |>
    dplyr::select(year, characteristics_code, totalexp = value)
  sh <- d |> dplyr::filter(item_code %in% tax$cex_item_code) |>
    dplyr::left_join(tot, by = c("year", "characteristics_code")) |>
    dplyr::left_join(dplyr::select(tax, cat_id, item_code = cex_item_code,
                                   cat_label, major), by = "item_code") |>
    dplyr::mutate(share = 100 * value / totalexp,
                  group = D$groups[characteristics_code],
                  dimension = nm) |>
    dplyr::filter(!is.na(share))

  chk <- sh |> dplyr::summarise(s = sum(share), .by = c(year, characteristics_code))
  say(sprintf("  share sums: min %.3f max %.3f", min(chk$s), max(chk$s)))
  if (max(abs(chk$s - 100)) > 0.25) stop("Shares do not sum to 100 for ", D$dim)
  all_shares <- dplyr::bind_rows(all_shares, sh)

  # CE workbooks for this dimension: sampling error and rental value.
  ce <- ce_se_panel(D$dim) |> dplyr::filter(characteristics_code %in% names(D$groups))
  rec <- ce |> dplyr::filter(cat_id %in% tax$cat_id, !is.na(mean)) |>
    dplyr::inner_join(dplyr::select(sh, year, characteristics_code, cat_id, dollars = value),
                      by = c("year", "characteristics_code", "cat_id"))
  say(sprintf("  CE workbooks %d-%d: %d cells reconciled to flat files, max |diff| $%.0f",
              min(ce$year), max(ce$year), nrow(rec), max(abs(rec$mean - rec$dollars))))
  if (any(abs(rec$mean - rec$dollars) > 50 & abs(rec$mean - rec$dollars) / rec$dollars > 0.02)) {
    stop("CE workbook means disagree with flat files for ", D$dim, call. = FALSE)
  }
  rse_d <- ce |> dplyr::filter(!cat_id %in% c("NCU", "TOTALEXP")) |>
    dplyr::mutate(cat_id = dplyr::recode(cat_id, RENTVAL = "H0"), group = characteristics_code) |>
    dplyr::select(group, year, cat_id, rse) |>
    tidyr::complete(group, year, cat_id) |>
    dplyr::group_by(group, cat_id) |> dplyr::arrange(year, .by_group = TRUE) |>
    tidyr::fill(rse, .direction = "downup") |> dplyr::ungroup() |>
    dplyr::mutate(dimension = nm)
  all_rse <- dplyr::bind_rows(all_rse, rse_d)
  # Renters' rental value of owned home is published as "b/ no data": zero.
  rv <- ce |> dplyr::filter(cat_id == "RENTVAL") |>
    dplyr::transmute(group = characteristics_code, year, rentval_annual = 12 * dplyr::coalesce(mean, 0))
  n_na <- sum(is.na(ce$mean[ce$cat_id == "RENTVAL"]))
  if (n_na) say("  rental value of owned home not published (set to 0) in ", n_na, " group-years: ",
                paste(unique(ce$characteristics_code[ce$cat_id == "RENTVAL" & is.na(ce$mean)]), collapse = ", "))

  sh0 <- sh |> dplyr::transmute(group = characteristics_code, cat_id, year, share)
  base <- list(prices = dplyr::select(prices, cat_id, date, index), shares = sh0, ri = ri_cat)
  pm   <- pool_block(base$prices, base$shares, ri_cat, MEDICAL, "M0")
  pmo  <- add_oer(pm$prices, pm$shares, pm$ri, rv,
                  dplyr::distinct(tot, group = characteristics_code, year, totalexp), cpi)
  spec_of <- function(b) if (b == "pm_oer_all_in") pmo else if (b == "pm_ex_shelter") pm else base

  for (b in names(BASKETS)) {
    sp <- spec_of(b)
    for (cc in names(D$groups)) {
      s <- sp$shares |> dplyr::filter(group == cc) |> dplyr::select(cat_id, year, share)
      bi <- try(build_index(sp$prices, s, BASKETS[[b]], lag_years = LAG), silent = TRUE)
      if (inherits(bi, "try-error")) {
        say(sprintf("  [%s / %s] skipped: %s", b, D$groups[[cc]],
                    sub("\n.*", "", conditionMessage(attr(bi, "condition")))))
        next
      }
      all_index <- dplyr::bind_rows(all_index, bi$index |>
        dplyr::mutate(dimension = nm, basket = b, characteristics_code = cc,
                      group = D$groups[[cc]]))
      all_wts <- dplyr::bind_rows(all_wts, bi$weights |>
        dplyr::mutate(dimension = nm, basket = b, characteristics_code = cc))
    }
  }
  prices_by_b[[nm]] <- list(base = base$prices, pm = pm$prices, pmo = pmo$prices)
  sub_i <- dplyr::filter(all_index, dimension == nm)
  if (!nrow(sub_i)) {
    stop("No index could be built for dimension ", nm, ".", call. = FALSE)
  }
  for (b in names(BASKETS)) {
    z <- sub_i[sub_i$basket == b, ]
    if (nrow(z)) say(sprintf("  %-14s %s to %s", b, min(z$date), max(z$date)))
  }
  say("")
}

write_derived(all_shares |>
  dplyr::select(dimension, characteristics_code, group, year, cat_id, cat_label,
                major, dollars = value, totalexp, share), "dimension_shares")
write_derived(all_index |>
  dplyr::select(dimension, basket, characteristics_code, group, date, index,
                chg_12m, n_cats, w_ref_year), "dimension_index")

# ===========================================================================
# 4. Gaps against both yardsticks
# ===========================================================================
D0 <- as.Date("2019-12-01")
pi12_of <- function(px) {
  px |> dplyr::mutate(d12 = date - months(12)) |>
    dplyr::left_join(dplyr::select(px, cat_id, d12 = date, i12 = index), by = c("cat_id", "d12")) |>
    dplyr::transmute(cat_id, date, pi12 = 100 * (index / i12 - 1)) |>
    dplyr::filter(!is.na(pi12))
}
px_for <- function(nm, b) {
  pb <- prices_by_b[[nm]]
  if (b == "pm_oer_all_in") pb$pmo else if (b == "pm_ex_shelter") pb$pm else pb$base
}

say("## Headline gaps against both yardsticks")
say("   disc = mean all-CU weight-source discrepancy over the SAME months as the gap.")
say("   SE = CE sampling error of the gap (delta method, D-28).")
say("")
gaps <- NULL; verd <- NULL; cumg <- NULL
for (nm in names(DIMS)) {
  D <- DIMS[[nm]]
  say("   ", D$gap_label, " (", D$label, ")")
  say("     basket            months  mean gap  mean|gap|   disc   ratio   mean SE  sig   cum since Dec 2019 (95% CI)")
  for (b in names(BASKETS)) {
    x <- all_index |>
      dplyr::filter(dimension == nm, basket == b, characteristics_code %in% c(D$focus, D$ref)) |>
      dplyr::select(date, characteristics_code, chg_12m, index) |>
      tidyr::pivot_wider(names_from = characteristics_code, values_from = c(chg_12m, index))
    fcol <- paste0("chg_12m_", D$focus); rcol <- paste0("chg_12m_", D$ref)
    if (!all(c(fcol, rcol) %in% names(x))) next
    x$gap <- x[[fcol]] - x[[rcol]]
    xg <- x[!is.na(x$gap), ]
    if (!nrow(xg)) next
    r <- resid[resid$basket == b, ]
    cm <- xg$date[xg$date %in% r$date]
    disc <- mean(abs(r$resid_pp[r$date %in% cm]))
    ratio <- mean(abs(xg$gap[xg$date %in% cm])) / disc
    wf <- all_wts |> dplyr::filter(dimension == nm, basket == b, characteristics_code == D$focus) |>
      dplyr::select(date, cat_id, weight)
    wr <- all_wts |> dplyr::filter(dimension == nm, basket == b, characteristics_code == D$ref) |>
      dplyr::select(date, cat_id, weight)
    rs <- function(cc) all_rse |> dplyr::filter(dimension == nm, group == cc) |> dplyr::select(year, cat_id, rse)
    se <- gap_se_12m(wf, wr, rs(D$focus), rs(D$ref), pi12_of(px_for(nm, b)), LAG) |>
      dplyr::filter(as.integer(format(date, "%Y")) - LAG >= min(all_rse$year[all_rse$dimension == nm])) |>
      dplyr::inner_join(dplyr::select(xg, date, gap), by = "date")
    # cumulative since Dec 2019
    cum_f <- cum_r <- NA_real_; ci_i <- ci_c <- NA_real_
    if (D0 %in% x$date) {
      lastd <- max(x$date)
      ic <- function(cc) x[[paste0("index_", cc)]]
      cum_f <- 100 * (ic(D$focus)[x$date == lastd] / ic(D$focus)[x$date == D0] - 1)
      cum_r <- 100 * (ic(D$ref)[x$date == lastd] / ic(D$ref)[x$date == D0] - 1)
      cs <- lapply(c(D$focus, D$ref), function(cc) {
        idx <- all_index |> dplyr::filter(dimension == nm, basket == b, characteristics_code == cc)
        w <- all_wts |> dplyr::filter(dimension == nm, basket == b, characteristics_code == cc)
        cum_se(idx, w, px_for(nm, b), rs(cc), D0, lastd)
      })
      ci_i <- 1.96 * sqrt(cs[[1]][["se_indep"]]^2 + cs[[2]][["se_indep"]]^2)
      ci_c <- 1.96 * sqrt(cs[[1]][["se_corr"]]^2 + cs[[2]][["se_corr"]]^2)
    }
    v <- tibble::tibble(dimension = nm, gap_label = D$gap_label, basket = b,
      months = nrow(xg), mean_gap = mean(xg$gap), mean_abs_gap = mean(abs(xg$gap)),
      weight_source_disc = disc, disc_ratio = ratio,
      mean_se = if (nrow(se)) mean(se$se_gap) else NA_real_,
      share_sig = if (nrow(se)) mean(abs(se$gap / se$se_gap) > 1.96) else NA_real_,
      cum_focus = cum_f, cum_ref = cum_r, cum_gap = cum_f - cum_r, ci95_indep = ci_i, ci95_corr = ci_c)
    verd <- dplyr::bind_rows(verd, v)
    say(sprintf("     %-16s %5d   %+6.3f    %6.3f   %5.3f  %5.2f   %s  %s   %s", b, v$months,
                v$mean_gap, v$mean_abs_gap, v$weight_source_disc, v$disc_ratio,
                ifelse(is.na(v$mean_se), "  n/a ", sprintf("%6.3f", v$mean_se)),
                ifelse(is.na(v$share_sig), " n/a", sprintf("%3.0f%%", 100 * v$share_sig)),
                ifelse(is.na(v$cum_gap), "n/a",
                       sprintf("%+5.2f pp  (+/- %s / %s)", v$cum_gap,
                               ifelse(is.na(ci_i), "n/a", sprintf("%.2f", ci_i)),
                               ifelse(is.na(ci_c), "n/a", sprintf("%.2f", ci_c))))))
    gaps <- dplyr::bind_rows(gaps, tibble::tibble(dimension = nm, gap_label = D$gap_label,
      basket = b, date = xg$date, gap = xg$gap) |>
      dplyr::left_join(dplyr::select(se, date, se_gap), by = "date"))
  }
  say("")
}
readr::write_csv(gaps, file.path(DIR_TAB, "t21_dimension_gaps.csv"))

# Family result restated on the same footing, from Phase 3.
fv <- readr::read_csv(file.path(DIR_TAB, "t27_basket_verdicts.csv"), show_col_types = FALSE) |>
  dplyr::filter(pair == "fam")
fc <- readr::read_csv(file.path(DIR_TAB, "t28_cumulative_gaps.csv"), show_col_types = FALSE) |>
  dplyr::filter(pair == "fam", from == D0)
fam_v <- fv |> dplyr::inner_join(fc, by = c("basket", "pair")) |>
  dplyr::filter(basket %in% names(BASKETS)) |>
  dplyr::transmute(dimension = "family", gap_label = "Families with children minus single/other CUs",
                   basket, months, mean_gap, mean_abs_gap, weight_source_disc, disc_ratio,
                   mean_se, share_sig, cum_focus = cum_1, cum_ref = cum_2, cum_gap = gap_pp,
                   ci95_indep = 1.96 * se_indep, ci95_corr = 1.96 * se_corr)
say("   Families with children minus single-person and other CUs (Phase 3)")
for (i in seq_len(nrow(fam_v))) {
  v <- fam_v[i, ]
  say(sprintf("     %-16s %5d   %+6.3f    %6.3f   %5.3f  %5.2f   %6.3f  %3.0f%%   %+5.2f pp  (+/- %.2f / %.2f)",
              v$basket, v$months, v$mean_gap, v$mean_abs_gap, v$weight_source_disc, v$disc_ratio,
              v$mean_se, 100 * v$share_sig, v$cum_gap, v$ci95_indep, v$ci95_corr))
}
say("")
verd <- dplyr::bind_rows(verd, fam_v)
readr::write_csv(verd, file.path(DIR_TAB, "t30_dimension_verdicts.csv"))

# Cumulative levels by group (every group, not just focus/ref).
cum <- all_index |>
  dplyr::filter(date %in% c(D0, max(date))) |>
  dplyr::group_by(dimension, basket, group, characteristics_code) |>
  dplyr::filter(D0 %in% date) |>
  dplyr::summarise(cum_pct = 100 * (index[date == max(date)] / index[date == D0] - 1), .groups = "drop")
readr::write_csv(cum, file.path(DIR_TAB, "t23_dimension_cumulative.csv"))

# ===========================================================================
# 5. Decomposition
# ===========================================================================
dec <- NULL
for (nm in names(DIMS)) {
  D <- DIMS[[nm]]
  for (b in FOCUS_B) {
    wf <- all_wts |> dplyr::filter(dimension == nm, basket == b, characteristics_code == D$focus) |>
      dplyr::select(cat_id, date, wF = weight)
    wr <- all_wts |> dplyr::filter(dimension == nm, basket == b, characteristics_code == D$ref) |>
      dplyr::select(cat_id, date, wN = weight)
    wa <- all_wts |> dplyr::filter(dimension == nm, basket == b, characteristics_code == "01") |>
      dplyr::select(cat_id, date, wA = weight)
    if (!nrow(wf) || !nrow(wr)) next
    # Relative-price form (D-34): centred on the all-CU 12-month change.
    dec <- dplyr::bind_rows(dec,
      dplyr::inner_join(wf, wr, by = c("cat_id", "date")) |>
        dplyr::inner_join(wa, by = c("cat_id", "date")) |>
        dplyr::inner_join(pi12_of(px_for(nm, b)), by = c("cat_id", "date")) |>
        dplyr::mutate(pibar = sum(wA * pi12), .by = date) |>
        dplyr::mutate(dimension = nm, basket = b, contrib = (wF - wN) * (pi12 - pibar),
                      contrib_raw = (wF - wN) * pi12))
  }
}
labs_x <- dplyr::bind_rows(dplyr::select(tax, cat_id, cat_label, major),
  tibble::tibble(cat_id = c("M0", "H0"), cat_label = c("Medical care (pooled)", "Owners' equivalent rent"),
                 major = c("Health", "Housing")))
dec <- dec |> dplyr::left_join(labs_x, by = "cat_id")
readr::write_csv(dec, file.path(DIR_TAB, "t22_dimension_decomposition.csv"))
say("## Mean contributions since Jan 2020, headline basket, relative-price form (D-34)")
for (nm in names(DIMS)) {
  z <- dec |> dplyr::filter(dimension == nm, basket == "pm_oer_all_in", date >= as.Date("2020-01-01")) |>
    dplyr::summarise(mc = mean(contrib, na.rm = TRUE), .by = cat_label) |>
    dplyr::arrange(dplyr::desc(abs(mc)))
  if (!nrow(z)) next
  say("   ", DIMS[[nm]]$gap_label, ":")
  for (i in seq_len(min(6L, nrow(z)))) say(sprintf("     %-42s %+.3f pp", substr(z$cat_label[i], 1, 42), z$mc[i]))
}
say("")

# ===========================================================================
# 6. Figures
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
SRC <- paste0("Source: author's calculation from BLS CEX and CPI-U. Whiskers: 95% sampling interval from CE ",
              "standard errors.\nThick: weight vintages uncorrelated. Thin: perfectly correlated. ",
              "Renters vs owners has no CI (CE tenure tables start 2019). Vintage ", substr(VINTAGE, 1, 10), ".")
BL <- c(pm_oer_all_in = "CPI concept with OER, medical pooled",
        pm_ex_shelter = "Ex-shelter, medical pooled")
f12 <- verd |> dplyr::filter(basket %in% FOCUS_B, !is.na(cum_gap)) |>
  dplyr::mutate(basket = factor(BL[basket], levels = BL),
                cut = forcats::fct_reorder(stringr::str_wrap(gap_label, 36), cum_gap),
                fam = dimension == "family")
p12 <- ggplot2::ggplot(f12, ggplot2::aes(cum_gap, cut, colour = fam)) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.4) +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = cum_gap - ci95_corr, xmax = cum_gap + ci95_corr),
                         width = 0, linewidth = 0.5, orientation = "y") +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = cum_gap - ci95_indep, xmax = cum_gap + ci95_indep),
                         width = 0, linewidth = 1.6, orientation = "y") +
  ggplot2::geom_point(size = 2.6) +
  ggplot2::facet_wrap(~basket, ncol = 2) +
  ggplot2::scale_colour_manual(values = c(`FALSE` = "grey45", `TRUE` = ESP_NAVY), guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "Cumulative inflation gaps since December 2019, every cut",
    subtitle = "Percentage-point difference in cumulative price change, December 2019 to July 2026. Family cut in navy.",
    x = "Cumulative gap (pp)", y = NULL, caption = SRC) + theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f12_dimension_gaps.png"), p12, width = 11.5, height = 6, dpi = 200, bg = "white")

f13 <- all_index |>
  dplyr::filter(dimension == "income_quintile", basket == "pm_oer_all_in",
                characteristics_code != "01", date >= D0) |>
  dplyr::group_by(characteristics_code) |>
  dplyr::mutate(cum = 100 * (index / index[which.min(date)] - 1)) |> dplyr::ungroup() |>
  dplyr::mutate(group = factor(group, levels = DIMS$income_quintile$groups[c("02", "03", "04", "05", "06")]))
p13 <- ggplot2::ggplot(f13, ggplot2::aes(date, cum, colour = group)) +
  ggplot2::geom_line(linewidth = 0.85) +
  ggplot2::scale_colour_manual(values = c(ESP_RED, "#e8a07f", "grey60", "#7d90b0", ESP_NAVY)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(title = "Cumulative price change by income quintile",
    subtitle = "CPI-concept basket with owners' equivalent rent, medical pooled. Since December 2019.",
    x = NULL, y = "Cumulative change since Dec 2019",
    caption = paste0("Source: author's calculation from BLS CEX and CPI-U. Vintage ", substr(VINTAGE, 1, 10), ".")) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f13_income_gradient.png"), p13, width = 10, height = 5.5, dpi = 200, bg = "white")

say("## Ranking of cuts by cumulative gap since Dec 2019, headline basket")
rk <- verd |> dplyr::filter(basket == "pm_oer_all_in") |> dplyr::arrange(dplyr::desc(abs(cum_gap)))
for (i in seq_len(nrow(rk))) {
  say(sprintf("   %-46s %+5.2f pp  (95%% CI +/- %.2f to %.2f)   mean 12m gap %+.3f",
              rk$gap_label[i], rk$cum_gap[i], rk$ci95_indep[i], rk$ci95_corr[i], rk$mean_gap[i]))
}
say("")
message("\nValidation log: ", LOG)
