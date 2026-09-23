# ---------------------------------------------------------------------------
# 08_burden.R   ---  PHASE 5
#
# The index answers a question about RATES. Equal rates on unequal budgets are
# not equal hardship, and the rate null makes the level question sharper rather
# than settling it. This script quantifies the burden side:
#
#   1. Dollar cost of the observed inflation, by group, on a base that matches
#      the index (D-31).
#   2. Spending per person and per equivalent adult (square-root scale).
#   3. Necessity share of consumption, with and without shelter (D-31).
#   4. The same by income quintile, where the rate gap is larger.
#
# Run from the project root:  Rscript R/08_burden.R
#
# Outputs
#   output/tables/t24_burden_by_group.csv
#   output/tables/t25_necessity_shares.csv
#   output/figures/f14_burden.png
#   output/tables/t00f_burden_validation.txt
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")
source("R/functions/ce_tables.R")

LOG <- file.path(DIR_TAB, "t00f_burden_validation.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }
say("# Burden analysis log"); say("# built_at: ", VINTAGE); say("")

cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))
tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
fam_idx <- readr::read_csv(file.path(DIR_DER, "family_index.csv"), show_col_types = FALSE)
dim_idx <- readr::read_csv(file.path(DIR_DER, "dimension_index.csv"), show_col_types = FALSE)

BASE_YEAR <- 2019L   # CEX vintage for the pre-inflation budget
D0 <- as.Date("2019-12-01")

# ===========================================================================
# 1. Household characteristics by group
# ===========================================================================
# Consumer-unit characteristics live in category CUCHARS. Item codes verified
# against cx.item: 980020 age, 980010 people, 980050 children under 18.
chars <- function(dim, codes) {
  cex |>
    dplyr::filter(category_code == "CUCHARS", demographics_code == dim,
                  characteristics_code %in% codes,
                  item_code %in% c("CONSUNIT", "980010", "980050", "980020", "INCBFTAX")) |>
    dplyr::select(year, characteristics_code, item_code, value) |>
    tidyr::pivot_wider(names_from = item_code, values_from = value) |>
    dplyr::rename(n_cu = CONSUNIT, people = `980010`, kids = `980050`,
                  age = `980020`, income = INCBFTAX)
}

# Total expenditure by group, from the EXPEND panel (splices applied).
totals <- function(dim, codes) {
  d <- cex_expend_panel(cex, tax, dim, codes, verbose = FALSE)
  d <- cex_repair_all_cu(cex, d, fallback_dim = "LB04", verbose = FALSE)
  d |> dplyr::filter(item_code == "TOTALEXP", characteristics_code %in% codes) |>
    dplyr::select(year, characteristics_code, totalexp = value)
}

GRPS <- list(
  list(dim = "LB06", code = "04", label = "Married couple with children"),
  list(dim = "LB06", code = "09", label = "One parent, child under 18"),
  list(dim = "LB06", code = "10", label = "Single person and other CUs"),
  list(dim = "LB06", code = "01", label = "All consumer units"),
  list(dim = "LB01", code = "02", label = "Lowest income quintile"),
  list(dim = "LB01", code = "06", label = "Highest income quintile"),
  list(dim = "LB17", code = "05", label = "Renters"),
  list(dim = "LB17", code = "02", label = "Homeowners"))

info <- NULL
for (g in GRPS) {
  ch <- chars(g$dim, g$code) |> dplyr::filter(year == BASE_YEAR)
  tt <- totals(g$dim, g$code) |> dplyr::filter(year == BASE_YEAR)
  ch24 <- chars(g$dim, g$code) |> dplyr::filter(year == 2024L)
  tt24 <- totals(g$dim, g$code) |> dplyr::filter(year == 2024L)
  info <- dplyr::bind_rows(info, tibble::tibble(
    dim = g$dim, code = g$code, label = g$label,
    n_cu = ch$n_cu, people = ch$people, kids = ch$kids, age = ch$age,
    exp_2019 = tt$totalexp, exp_2024 = tt24$totalexp,
    people_2024 = ch24$people, income_2019 = ch$income))
}

say("## 1. Groups at the ", BASE_YEAR, " base year")
say("   group                          CUs(000s)  people   exp/CU    exp/person")
for (i in seq_len(nrow(info))) {
  say(sprintf("   %-30s %9s   %5.1f  $%7s   $%7s", info$label[i],
              format(round(info$n_cu[i]), big.mark = ","), info$people[i],
              format(round(info$exp_2019[i]), big.mark = ","),
              format(round(info$exp_2019[i] / info$people[i]), big.mark = ",")))
}
say("")

# ===========================================================================
# 2. Dollar cost of the observed inflation (revised, D-31)
# ===========================================================================
# Cost of buying each group's 2019 basket at July 2026 prices, using the
# group's OWN index on the SAME basket as the dollars:
#
#   cash_nonshelter  2019 spending on the mapped non-shelter categories
#                    x the ex-shelter, medical-pooled index. Cash outlays only.
#   cpi_concept      2019 spending on every mapped category except owner
#                    outlays, plus 12 x the CE rental value of the owned home,
#                    x the CPI-concept (OER, medical pooled) index. Includes
#                    imputed owner rent, which is not a cash cost to an owner
#                    with a fixed mortgage payment.
#
# Pre-D-31 this multiplied 2019 TOTALEXP (which includes pensions, Social
# Security contributions and cash gifts, none bought at consumer prices, and
# shelter, which the ex-shelter index does not price) by ex-shelter inflation.
# That figure is kept as `dollars_old` for the record only.
MAPPED   <- tax$cat_id[!tax$cat_id %in% c("04", "05", "40", "41")]
SHELTER  <- tax$cat_id[tax$major == "Housing"]
NONSHELT <- setdiff(MAPPED, SHELTER)

dollars_2019 <- function(dim, code) {
  d <- cex_expend_panel(cex, tax, dim, code, verbose = FALSE)
  d <- cex_repair_all_cu(cex, d, fallback_dim = "LB04", verbose = FALSE)
  d |> dplyr::filter(characteristics_code == code, year == BASE_YEAR) |>
    dplyr::inner_join(dplyr::select(tax, cat_id, item_code = cex_item_code), by = "item_code")
}
ce_rv <- list()
rentval_2019 <- function(dim, code) {
  if (is.null(ce_rv[[dim]])) ce_rv[[dim]] <<- ce_se_panel(dim)
  v <- ce_rv[[dim]]
  v <- v$mean[v$cat_id == "RENTVAL" & v$characteristics_code == code & v$year == BASE_YEAR]
  if (!length(v)) return(NA_real_)
  12 * dplyr::coalesce(v[1], 0)
}
cum_of <- function(idx, filt, basket) {
  x <- idx[filt & idx$basket == basket, ]
  if (!nrow(x) || !D0 %in% x$date) return(NA_real_)
  100 * (x$index[which.max(x$date)] / x$index[match(D0, x$date)] - 1)
}
LB06G <- c("04" = "married_kids", "09" = "single_parent", "10" = "single_other", "01" = "all_cu")
cum_for <- function(dim, code, basket) {
  if (dim == "LB06") return(cum_of(fam_idx, fam_idx$group == LB06G[[code]], basket))
  dd <- c(LB01 = "income_quintile", LB17 = "tenure")[[dim]]
  cum_of(dim_idx, dim_idx$dimension == dd & dim_idx$characteristics_code == code, basket)
}

burden <- info
for (i in seq_len(nrow(burden))) {
  d <- dollars_2019(burden$dim[i], burden$code[i])
  burden$base_nonshelter[i] <- sum(d$value[d$cat_id %in% NONSHELT])
  burden$rentval_2019[i]    <- rentval_2019(burden$dim[i], burden$code[i])
  burden$base_cpi[i]        <- sum(d$value[d$cat_id %in% setdiff(MAPPED, "06")]) + burden$rentval_2019[i]
  burden$consumption_2019[i] <- burden$exp_2019[i] - sum(d$value[d$cat_id %in% c("40", "41")])
  burden$cum_nonshelter[i]  <- cum_for(burden$dim[i], burden$code[i], "pm_ex_shelter")
  burden$cum_cpi[i]         <- cum_for(burden$dim[i], burden$code[i], "pm_oer_all_in")
  burden$cum_ex_shelter_old[i] <- cum_for(burden$dim[i], burden$code[i], "ex_shelter")
}
burden <- burden |>
  dplyr::mutate(
    eq_scale           = sqrt(people),
    dollars_nonshelter = base_nonshelter * cum_nonshelter / 100,
    dollars_cpi        = base_cpi * cum_cpi / 100,
    dollars_old        = exp_2019 * cum_ex_shelter_old / 100,
    per_person         = dollars_nonshelter / people,
    per_equiv_adult    = dollars_nonshelter / eq_scale,
    pct_of_income      = 100 * dollars_nonshelter / income_2019,
    # CEX under-reports income badly at the bottom of the distribution, and
    # low-income households also dissave, receive in-kind transfers, and
    # include students and retirees drawing down assets. Where reported
    # expenditure exceeds reported income, the income-share column is not
    # usable. Flagged rather than silently printed.
    exp_over_income    = exp_2019 / income_2019,
    income_usable      = exp_over_income < 1)
readr::write_csv(burden, file.path(DIR_TAB, "t24_burden_by_group.csv"))

say("## 2. Cost of the ", BASE_YEAR, " basket at July 2026 prices")
say("   cash, non-shelter = 2019 non-shelter spending x ex-shelter medical-pooled index")
say("   CPI concept       = 2019 consumption incl. imputed owner rent x CPI-concept index")
say("   group                          infl(ns)  extra $/yr   per eq. adult   infl(CPI)  extra $/yr   [old method]")
for (i in order(-burden$dollars_nonshelter)) {
  b <- burden[i, ]
  say(sprintf("   %-30s %6.2f%%   $%7s    $%7s       %s   %s   [$%s]", b$label,
              b$cum_nonshelter, format(round(b$dollars_nonshelter), big.mark = ","),
              format(round(b$per_equiv_adult), big.mark = ","),
              ifelse(is.na(b$cum_cpi), "   n/a ", sprintf("%6.2f%%", b$cum_cpi)),
              ifelse(is.na(b$dollars_cpi), "     n/a", sprintf("$%7s", format(round(b$dollars_cpi), big.mark = ","))),
              format(round(b$dollars_old), big.mark = ",")))
}
say("   (tenure groups have no CPI-concept index from Dec 2019: the CE rental-value table starts 2019)")
say("")
say("   CAVEAT on income shares. CEX reported expenditure exceeds reported income")
say("   for some groups, so an income share is not usable there:")
for (i in order(-burden$exp_over_income)) {
  say(sprintf("     %-30s expenditure / income = %.2f  %s", burden$label[i],
              burden$exp_over_income[i],
              ifelse(burden$income_usable[i], "usable", "NOT USABLE")))
}
say("")

# ===========================================================================
# 3. Necessity shares (revised, D-31)
# ===========================================================================
# Over CONSUMPTION (TOTALEXP less pensions and cash contributions).
#   (a) with shelter: food at home, utilities, rent, and owner shelter outlays
#       (mortgage interest, property taxes, maintenance/repairs/insurance), so
#       owners and renters are treated alike.
#   (b) without shelter: food at home and utilities.
# The pre-D-31 definition (food at home + rent + utilities over TOTALEXP)
# counted renters' shelter and not owners', and is kept as `old` for the record.
UTIL <- tax$cat_id[tax$major == "Utilities"]
NEC_A <- c("01", UTIL, "04", "05", "06", "07")
NEC_B <- c("01", UTIL)
NEC_OLD <- c("01", UTIL, "07")
nec <- NULL
for (g in GRPS) {
  d <- cex_expend_panel(cex, tax, g$dim, g$code, verbose = FALSE)
  d <- cex_repair_all_cu(cex, d, fallback_dim = "LB04", verbose = FALSE)
  d <- dplyr::filter(d, characteristics_code == g$code, year == 2024L) |>
    dplyr::left_join(dplyr::select(tax, cat_id, item_code = cex_item_code), by = "item_code")
  te <- d$value[d$item_code == "TOTALEXP"]
  cons <- te - sum(d$value[d$cat_id %in% c("40", "41")], na.rm = TRUE)
  v <- function(ids) sum(d$value[d$cat_id %in% ids], na.rm = TRUE)
  nec <- dplyr::bind_rows(nec, tibble::tibble(
    label = g$label, consumption = cons, totalexp = te,
    with_shelter = 100 * v(NEC_A) / cons, without_shelter = 100 * v(NEC_B) / cons,
    old = 100 * v(NEC_OLD) / te))
}
readr::write_csv(nec, file.path(DIR_TAB, "t25_necessity_shares.csv"))
say("## 3. Necessity share of consumption, 2024")
say("   group                          with shelter   without shelter   [old: food at home+rent+utilities / TOTALEXP]")
for (i in order(-nec$with_shelter)) {
  say(sprintf("   %-30s %6.1f%%          %6.1f%%          [%5.1f%%]", nec$label[i],
              nec$with_shelter[i], nec$without_shelter[i], nec$old[i]))
}
say("")

# ===========================================================================
# 4. Rate versus burden
# ===========================================================================
say("## 4. Rate versus burden")
f <- burden[burden$code == "04" & burden$dim == "LB06", ]
p <- burden[burden$code == "09" & burden$dim == "LB06", ]
s <- burden[burden$code == "10" & burden$dim == "LB06", ]
lo <- burden[burden$code == "02" & burden$dim == "LB01", ]
hi <- burden[burden$code == "06" & burden$dim == "LB01", ]
say(sprintf("   Married with children:  CPI-concept %.2f%%, non-shelter %.2f%%, $%s extra per year (non-shelter)",
            f$cum_cpi, f$cum_nonshelter, format(round(f$dollars_nonshelter), big.mark = ",")))
say(sprintf("   Single/other CUs:       CPI-concept %.2f%%, non-shelter %.2f%%, $%s extra per year (non-shelter)",
            s$cum_cpi, s$cum_nonshelter, format(round(s$dollars_nonshelter), big.mark = ",")))
say(sprintf("   Spending per person 2019:          married-with-children $%s, single/other $%s",
            format(round(f$exp_2019 / f$people), big.mark = ","),
            format(round(s$exp_2019 / s$people), big.mark = ",")))
say(sprintf("   Spending per equivalent adult 2019 (square-root scale): $%s vs $%s  (families %+.0f%%)",
            format(round(f$exp_2019 / f$eq_scale), big.mark = ","),
            format(round(s$exp_2019 / s$eq_scale), big.mark = ","),
            100 * ((f$exp_2019 / f$eq_scale) / (s$exp_2019 / s$eq_scale) - 1)))
say("   -> per capita, families look poorer; per equivalent adult they spend more. The")
say("      per-capita comparison ignores economies of scale and should not be headlined.")
say("")
say(sprintf("   Lowest income quintile: CPI-concept %.2f%%, non-shelter %.2f%%, $%s extra",
            lo$cum_cpi, lo$cum_nonshelter, format(round(lo$dollars_nonshelter), big.mark = ",")))
say(sprintf("   Highest income quintile: CPI-concept %.2f%%, non-shelter %.2f%%, $%s extra, %.1f%% of pretax income",
            hi$cum_cpi, hi$cum_nonshelter, format(round(hi$dollars_nonshelter), big.mark = ","),
            hi$pct_of_income))
say("")

# --- "Families" is not one group -----------------------------------------
say("## 5. \"Families\" splits: one-parent versus married with children")
cg <- readr::read_csv(file.path(DIR_TAB, "t28_cumulative_gaps.csv"), show_col_types = FALSE) |>
  dplyr::filter(pair == "par", from == D0)
for (b in c("pm_oer_all_in", "pm_ex_shelter", "ex_shelter")) {
  z <- cg[cg$basket == b, ]
  say(sprintf("   %-16s one-parent %.2f%% vs married %.2f%%: gap %+.2f pp (95%% CI +/- %.2f uncorrelated, %.2f correlated vintages)",
              b, z$cum_1, z$cum_2, z$gap_pp, 1.96 * z$se_indep, 1.96 * z$se_corr))
}
say(sprintf("   necessity share 2024 (with shelter): one-parent %.1f%%, married with children %.1f%%",
            nec$with_shelter[nec$label == "One parent, child under 18"],
            nec$with_shelter[nec$label == "Married couple with children"]))
say(sprintf("   necessity share 2024 (without shelter): one-parent %.1f%%, married with children %.1f%%",
            nec$without_shelter[nec$label == "One parent, child under 18"],
            nec$without_shelter[nec$label == "Married couple with children"]))
say("")

# ===========================================================================
# 5. Figure
# ===========================================================================
ESP_NAVY <- "#2c3254"; ESP_RED <- "#ff8361"
theme_fii <- function(bs = 11) {
  ggplot2::theme_minimal(base_size = bs) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey88"),
      plot.title = ggplot2::element_text(face = "bold", size = bs + 3),
      plot.subtitle = ggplot2::element_text(colour = "grey30", size = bs),
      plot.caption = ggplot2::element_text(colour = "grey45", size = bs - 2, hjust = 0),
      legend.position = "none",
      strip.text = ggplot2::element_text(face = "bold"))
}
f14d <- burden |>
  dplyr::filter(!(dim == "LB06" & code == "01"), dim != "LB17") |>
  dplyr::select(label, cum_cpi, dollars_nonshelter) |>
  dplyr::left_join(dplyr::select(nec, label, with_shelter), by = "label") |>
  dplyr::rename(`Inflation, CPI concept (%)` = cum_cpi,
                `Extra non-shelter cost per year ($)` = dollars_nonshelter,
                `Necessity share with shelter (%)` = with_shelter) |>
  tidyr::pivot_longer(-label) |>
  dplyr::mutate(name = factor(name, levels = c("Inflation, CPI concept (%)",
                  "Extra non-shelter cost per year ($)", "Necessity share with shelter (%)")),
                label = stringr::str_wrap(label, 22))
p14 <- ggplot2::ggplot(f14d, ggplot2::aes(value, forcats::fct_rev(label), fill = name)) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::facet_wrap(~name, scales = "free_x") +
  ggplot2::scale_fill_manual(values = c("grey65", ESP_NAVY, ESP_RED)) +
  ggplot2::labs(
    title = "Inflation rates, dollar costs and necessity shares by household type",
    subtitle = paste0("Inflation: cumulative change in each group's CPI-concept index, December 2019 to ",
      "July 2026.\nExtra cost: 2019 non-shelter spending at July 2026 prices. Necessity share: food at ",
      "home, utilities and all shelter\noutlays as a share of 2024 consumption."),
    x = NULL, y = NULL,
    caption = paste0("Source: author's calculation from BLS CEX and CPI-U. Vintage ",
                     substr(VINTAGE, 1, 10), ".")) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f14_burden.png"), p14, width = 12, height = 5.5, dpi = 200, bg = "white")

message("\nValidation log: ", LOG)
