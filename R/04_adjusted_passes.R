# ---------------------------------------------------------------------------
# 04_adjusted_passes.R
#
# Two robustness passes on the Phase 1 shares, plus one decomposition.
#
#   PASS A  Net out housing. Shares renormalized on a consumption base with
#           (i) shelter removed and (ii) all housing removed.
#
#   PASS B  Control for age. The LB06 groups differ by 8.8 years of mean
#           reference-person age. Uses the LB04 age-bracket gradient to predict
#           the share gap that age composition alone would generate, then nets
#           it out. This is a BOUNDING decomposition, not an identification:
#           see the interpretation note in section 4 and METHODS.md section 9.
#
#   PASS C  Decompose the tenure contribution using LB17 owner/renter share
#           vectors and the LB06 groups' own homeownership rates. This is the
#           substantive version of Pass A: tenure shifts spending on utilities,
#           furnishings, and vehicles too, not only on shelter.
#
# Run from the project root:  Rscript R/04_adjusted_passes.R
#
# Outputs
#   output/tables/t06_gaps_ex_housing.csv
#   output/tables/t07_gaps_age_adjusted.csv
#   output/tables/t08_tenure_decomposition.csv
#   output/tables/t09_pass_summary.csv
#   output/figures/f04_gaps_ex_housing.png
#   output/figures/f05_age_adjustment.png
#   output/tables/t00b_adjusted_validation.txt
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")

LOG <- file.path(DIR_TAB, "t00b_adjusted_validation.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }

say("# Adjusted-passes validation log")
say("# built_at: ", VINTAGE); say("")

cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))
tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))

LATEST <- 2024L

# ===========================================================================
# 1. Category bases
# ===========================================================================
# Consumption base excludes saving and transfers (pensions, cash
# contributions). Every pass below renormalizes on a subset of it, so all
# shares remain additive to 100 within their own basket.
OOS      <- tax$cex_item_code[tax$in_cpi_scope == "FALSE" & tax$major == "Out of scope"]
SHELTER  <- tax$cex_item_code[tax$major == "Housing"]
HOUSING  <- tax$cex_item_code[tax$major %in% c("Housing", "Utilities", "Household ops")]

BASES <- list(
  consumption = setdiff(tax$cex_item_code, OOS),
  ex_shelter  = setdiff(tax$cex_item_code, c(OOS, SHELTER)),
  ex_housing  = setdiff(tax$cex_item_code, c(OOS, HOUSING))
)

say("## 1. Bases")
for (b in names(BASES)) say("  ", b, ": ", length(BASES[[b]]), " categories")
say("  shelter categories dropped: ", paste(SHELTER, collapse = ", "))
say("  housing categories dropped: ", paste(HOUSING, collapse = ", "))
say("")

# ===========================================================================
# 2. Group panels: LB06 (composition), LB04 (age), LB17 (tenure)
# ===========================================================================
message("Preparing LB06 (composition)...")
d06 <- cex_expend_panel(cex, tax, "LB06", c("01", "03", "04", "09", "10"))
cex_assert_additive(d06, tax, label = "LB06")

message("Preparing LB04 (age)...")
# Non-overlapping brackets only: 02 under 25, 03 25-34, 04 35-44, 05 45-54,
# 06 55-64, 07 65+. Codes 08/09 split 65+ and would double count.
AGE_CODES <- c("02", "03", "04", "05", "06", "07")
d04 <- cex_expend_panel(cex, tax, "LB04", c("01", AGE_CODES), verbose = FALSE)
cex_assert_additive(d04, tax, label = "LB04")

message("Preparing LB17 (tenure)...")
# 02 home owner, 05 renter. Codes 03/04 (with/without mortgage) start 2003 and
# are subsets of 02, so they are excluded to keep the partition clean.
TEN_CODES <- c("02", "05")
d17 <- cex_expend_panel(cex, tax, "LB17", c("01", TEN_CODES), verbose = FALSE)
cex_assert_additive(d17, tax, label = "LB17")

# --- Consumer-unit counts and mean ages, any dimension --------------------
cu_char <- function(dim, item) {
  cex |>
    dplyr::filter(category_code == "CUCHARS", demographics_code == dim,
                  item_code == item) |>
    dplyr::select(year, characteristics_code, v = value)
}
n06   <- cu_char("LB06", "CONSUNIT"); a06 <- cu_char("LB06", "980020")
n04   <- cu_char("LB04", "CONSUNIT"); a04 <- cu_char("LB04", "980020")
n17   <- cu_char("LB17", "CONSUNIT"); a17 <- cu_char("LB17", "980020")
own06 <- cu_char("LB06", "HOMEOWN")

# Verify the LB04 brackets partition the population.
p04 <- n04 |> dplyr::filter(year == LATEST, characteristics_code %in% AGE_CODES) |>
  dplyr::summarise(s = sum(v)) |> dplyr::pull(s)
tot04 <- n04 |> dplyr::filter(year == LATEST, characteristics_code == "01") |> dplyr::pull(v)
say("## 2. Partition checks, ", LATEST)
say(sprintf("  LB04 brackets sum to %s of %s CUs (%.3f%%)",
            format(p04, big.mark = ","), format(tot04, big.mark = ","), 100 * p04 / tot04))
if (abs(p04 / tot04 - 1) > 0.005) stop("LB04 brackets do not partition the population.")

p17 <- n17 |> dplyr::filter(year == LATEST, characteristics_code %in% TEN_CODES) |>
  dplyr::summarise(s = sum(v)) |> dplyr::pull(s)
tot17 <- n17 |> dplyr::filter(year == LATEST, characteristics_code == "01") |> dplyr::pull(v)
say(sprintf("  LB17 owner+renter sum to %s of %s CUs (%.3f%%)",
            format(p17, big.mark = ","), format(tot17, big.mark = ","), 100 * p17 / tot17))
if (abs(p17 / tot17 - 1) > 0.005) stop("LB17 tenure groups do not partition the population.")
say("")

# ===========================================================================
# 3. Pool families (04 + 09) by consumer-unit counts
# ===========================================================================
pool <- function(d, ncu, codes, new_code) {
  d |> dplyr::filter(characteristics_code %in% codes) |>
    dplyr::left_join(ncu, by = c("year", "characteristics_code")) |>
    dplyr::summarise(value = sum(value * v, na.rm = TRUE) / sum(v[!is.na(value)]),
                     .by = c(year, item_code)) |>
    dplyr::mutate(characteristics_code = new_code)
}
d06 <- dplyr::bind_rows(d06, pool(d06, n06, FAMILY_CODES, "F1"))

# Pooled family mean age and homeownership rate, CU-weighted.
pool_char <- function(cc, ncu, codes) {
  cc |> dplyr::filter(characteristics_code %in% codes) |>
    dplyr::left_join(ncu, by = c("year", "characteristics_code"),
                     suffix = c("", "_n")) |>
    dplyr::summarise(v = sum(v * v_n) / sum(v_n), .by = year)
}
a06 <- dplyr::bind_rows(a06, pool_char(a06, n06, FAMILY_CODES) |>
                          dplyr::mutate(characteristics_code = "F1"))
own06 <- dplyr::bind_rows(own06, pool_char(own06, n06, FAMILY_CODES) |>
                            dplyr::mutate(characteristics_code = "F1"))

GRP <- c("F1" = "Families with children", "10" = "Single-person and other CUs",
         "01" = "All consumer units", "04" = "Married couple with children",
         "09" = "One parent, child under 18", "03" = "Married couple only")

AGE_F <- a06$v[a06$year == LATEST & a06$characteristics_code == "F1"]
AGE_N <- a06$v[a06$year == LATEST & a06$characteristics_code == "10"]
OWN_F <- own06$v[own06$year == LATEST & own06$characteristics_code == "F1"] / 100
OWN_N <- own06$v[own06$year == LATEST & own06$characteristics_code == "10"] / 100

say("## 3. Group characteristics, ", LATEST)
say(sprintf("  families with children:      mean age %.1f, homeowner %.1f%%", AGE_F, 100 * OWN_F))
say(sprintf("  single-person and other CUs: mean age %.1f, homeowner %.1f%%", AGE_N, 100 * OWN_N))
say(sprintf("  age gap %.1f years, homeownership gap %.1f pp", AGE_F - AGE_N, 100 * (OWN_F - OWN_N)))
say("")

# ===========================================================================
# 4. Run all three passes for each base
# ===========================================================================
lab <- tax |> dplyr::select(item_code = cex_item_code, cat_id, major, cat_label)

run_pass <- function(base_name) {
  keep <- BASES[[base_name]]

  # --- observed shares, LB06 ---------------------------------------------
  s06 <- cex_shares_on_base(dplyr::filter(d06, year == LATEST), keep)
  obs <- s06 |> dplyr::select(item_code, characteristics_code, share) |>
    tidyr::pivot_wider(names_from = characteristics_code, values_from = share)

  # --- PASS B: age gradient from LB04 ------------------------------------
  # Share vector at each bracket's mean age, then piecewise-linear
  # interpolation evaluated at each LB06 group's mean age.
  s04 <- cex_shares_on_base(dplyr::filter(d04, year == LATEST), keep) |>
    dplyr::filter(characteristics_code %in% AGE_CODES) |>
    dplyr::left_join(dplyr::filter(a04, year == LATEST) |> dplyr::select(-year),
                     by = "characteristics_code")

  interp_at <- function(target_age) {
    s04 |> dplyr::summarise(
      pred = stats::approx(x = v, y = share, xout = target_age, rule = 2)$y,
      .by = item_code)
  }
  pred_F <- interp_at(AGE_F) |> dplyr::rename(pred_F = pred)
  pred_N <- interp_at(AGE_N) |> dplyr::rename(pred_N = pred)

  # --- PASS C: tenure decomposition from LB17 ----------------------------
  s17 <- cex_shares_on_base(dplyr::filter(d17, year == LATEST), keep) |>
    dplyr::filter(characteristics_code %in% TEN_CODES) |>
    dplyr::select(item_code, characteristics_code, share) |>
    tidyr::pivot_wider(names_from = characteristics_code, values_from = share) |>
    dplyr::rename(w_owner = `02`, w_renter = `05`)

  out <- obs |>
    dplyr::left_join(pred_F, by = "item_code") |>
    dplyr::left_join(pred_N, by = "item_code") |>
    dplyr::left_join(s17, by = "item_code") |>
    dplyr::left_join(lab, by = "item_code") |>
    dplyr::mutate(
      base            = base_name,
      gap_total       = F1 - `10`,
      # Pass B
      gap_age_pred    = pred_F - pred_N,
      gap_net_of_age  = gap_total - gap_age_pred,
      # Pass C
      gap_tenure_pred = (OWN_F - OWN_N) * (w_owner - w_renter),
      gap_net_of_ten  = gap_total - gap_tenure_pred
    ) |>
    dplyr::select(base, cat_id, major, cat_label, item_code,
                  share_fam = F1, share_single = `10`, share_all = `01`,
                  gap_total, gap_age_pred, gap_net_of_age,
                  gap_tenure_pred, gap_net_of_ten) |>
    dplyr::arrange(cat_id)

  # Shares must still sum to 100 on the restricted base.
  chk <- s06 |> dplyr::summarise(s = sum(share, na.rm = TRUE), .by = characteristics_code)
  say(sprintf("  [%s] share sums: min %.3f max %.3f  (%d categories)",
              base_name, min(chk$s), max(chk$s), length(keep)))
  out
}

say("## 4. Pass construction")
res <- dplyr::bind_rows(lapply(names(BASES), run_pass))
say("")

# ===========================================================================
# 5. Tables
# ===========================================================================
readr::write_csv(res, file.path(DIR_TAB, "t06_gaps_ex_housing.csv"))
readr::write_csv(dplyr::filter(res, base == "consumption"),
                 file.path(DIR_TAB, "t07_gaps_age_adjusted.csv"))
readr::write_csv(
  res |> dplyr::filter(base == "consumption") |>
    dplyr::select(cat_id, major, cat_label, gap_total, gap_tenure_pred, gap_net_of_ten) |>
    dplyr::mutate(pct_of_gap_tenure = 100 * gap_tenure_pred / gap_total) |>
    dplyr::arrange(dplyr::desc(abs(gap_total))),
  file.path(DIR_TAB, "t08_tenure_decomposition.csv"))

# Summary: total absolute basket dissimilarity under each pass.
# Half the sum of absolute share gaps is the standard dissimilarity index:
# the fraction of the budget that would have to be reallocated to make the two
# baskets identical.
summ <- res |>
  dplyr::summarise(
    n_cats            = dplyr::n(),
    diss_total        = sum(abs(gap_total),      na.rm = TRUE) / 2,
    diss_net_of_age   = sum(abs(gap_net_of_age), na.rm = TRUE) / 2,
    diss_net_of_ten   = sum(abs(gap_net_of_ten), na.rm = TRUE) / 2,
    .by = base) |>
  dplyr::mutate(base = factor(base, levels = names(BASES))) |>
  dplyr::arrange(base)
readr::write_csv(summ, file.path(DIR_TAB, "t09_pass_summary.csv"))

say("## 5. Basket dissimilarity index (percent of budget needing reallocation)")
for (i in seq_len(nrow(summ))) {
  say(sprintf("  %-12s  n=%2d  observed %5.2f  net of age %5.2f  net of tenure %5.2f",
              summ$base[i], summ$n_cats[i], summ$diss_total[i],
              summ$diss_net_of_age[i], summ$diss_net_of_ten[i]))
}
say("")

# ===========================================================================
# 6. Figures
# ===========================================================================
ESP_NAVY <- "#2c3254"; ESP_RED <- "#ff8361"; ESP_GREEN <- "#70ad8f"
theme_fii <- function(base_size = 11) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey88"),
      plot.title = ggplot2::element_text(face = "bold", size = base_size + 3),
      plot.subtitle = ggplot2::element_text(colour = "grey30", size = base_size),
      plot.caption = ggplot2::element_text(colour = "grey45", size = base_size - 2, hjust = 0),
      legend.position = "top", legend.title = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"))
}
SRC <- paste0("Source: BLS Consumer Expenditure Survey ", LATEST,
              ", dimensions LB06 (composition), LB04 (age), LB17 (tenure). Vintage ",
              substr(VINTAGE, 1, 10), ".")

# f04: how the gap profile changes as housing is removed
f04_d <- res |>
  dplyr::filter(!major %in% c("Out of scope")) |>
  dplyr::mutate(base = factor(base, levels = names(BASES),
                              labels = c("Consumption base\n(39 categories)",
                                         "Shelter removed\n(34 categories)",
                                         "All housing removed\n(25 categories)"))) |>
  dplyr::filter(!is.na(gap_total)) |>
  dplyr::group_by(base) |>
  dplyr::filter(abs(gap_total) >= 0.20) |> dplyr::ungroup()

p4 <- ggplot2::ggplot(f04_d, ggplot2::aes(gap_total,
        reorder(substr(cat_label, 1, 40), gap_total),
        fill = gap_total > 0)) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey25", linewidth = 0.4) +
  ggplot2::facet_wrap(~base, scales = "free", ncol = 3) +
  ggplot2::scale_fill_manual(values = c(ESP_RED, ESP_NAVY),
        labels = c("Single/other spend more", "Families spend more")) +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "Pass A: netting out housing",
    subtitle = paste0("Share-gap profile, families with children minus single-person and other CUs, on ",
                      "three renormalized bases.\nGaps under 0.2 pp omitted. Saving and transfers ",
                      "excluded from every base."),
    x = "Share gap (percentage points)", y = NULL, caption = SRC) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f04_gaps_ex_housing.png"), p4,
                width = 13, height = 6.5, dpi = 200, bg = "white")

# f05: observed vs age-predicted vs net-of-age, consumption base
# Shelter is split onto its own panel and scale. The rent gap spans roughly
# 12 pp while every other category sits inside 3 pp.
f05_d <- res |>
  dplyr::filter(base == "consumption", !is.na(gap_total), abs(gap_total) >= 0.15) |>
  dplyr::select(cat_id, cat_label, gap_total, gap_age_pred, gap_net_of_age) |>
  tidyr::pivot_longer(c(gap_total, gap_age_pred, gap_net_of_age)) |>
  dplyr::mutate(
    name = factor(name,
      levels = c("gap_total", "gap_age_pred", "gap_net_of_age"),
      labels = c("Observed gap", "Predicted by age composition alone",
                 "Residual, net of age")),
    shelter = cat_id %in% c("04", "05", "06", "07", "08"),
    cat_label = forcats::fct_reorder(substr(cat_label, 1, 42),
                  ifelse(name == "Observed gap", value, NA), .na_rm = TRUE))

age_panel <- function(dat, ttl) {
  ggplot2::ggplot(dat, ggplot2::aes(value, cat_label, fill = name)) +
    ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.78), width = 0.72) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey25", linewidth = 0.4) +
    ggplot2::scale_fill_manual(values = c(ESP_NAVY, "grey65", ESP_GREEN), drop = FALSE) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
    ggplot2::labs(subtitle = ttl, x = NULL, y = NULL) +
    theme_fii() +
    ggplot2::theme(legend.position = "none",
                   plot.subtitle = ggplot2::element_text(face = "bold", colour = "grey20"))
}

p_a <- age_panel(dplyr::filter(f05_d, !shelter), "All categories except shelter")
p_b <- age_panel(dplyr::filter(f05_d, shelter), "Shelter (note the wider scale)") +
  ggplot2::labs(x = "Share gap (percentage points)")

leg <- cowplot::get_plot_component(
  ggplot2::ggplot(f05_d, ggplot2::aes(value, cat_label, fill = name)) +
    ggplot2::geom_col() +
    ggplot2::scale_fill_manual(values = c(ESP_NAVY, "grey65", ESP_GREEN)) +
    theme_fii() + ggplot2::theme(legend.position = "top"),
  "guide-box-top", return_all = TRUE)

n_a <- dplyr::n_distinct(dplyr::filter(f05_d, !shelter)$cat_label)
n_b <- dplyr::n_distinct(dplyr::filter(f05_d, shelter)$cat_label)

p5 <- patchwork::wrap_plots(
  leg,
  patchwork::wrap_plots(p_a, p_b, ncol = 1, heights = c(n_a, n_b + 2)),
  ncol = 1, heights = c(1, n_a + n_b + 2)) +
  patchwork::plot_annotation(
    title = "Pass B: how much of the gap is age composition?",
    subtitle = paste0("Families with children average ", sprintf("%.1f", AGE_F),
      " years against ", sprintf("%.1f", AGE_N), " for single-person and other CUs.\n",
      "The age prediction interpolates the LB04 age-bracket gradient at each group's mean age.\n",
      "It is contaminated by family composition, so it OVERSTATES the age contribution."),
    caption = SRC, theme = theme_fii())

ggplot2::ggsave(file.path(DIR_FIG, "f05_age_adjustment.png"), p5,
                width = 10.5, height = 9, dpi = 200, bg = "white")

# ===========================================================================
# 7. Console summary
# ===========================================================================
show <- function(base_name, col, ttl, n = 12) {
  message("\n--- ", ttl, " ---")
  d <- res |> dplyr::filter(base == base_name, !is.na(.data[[col]])) |>
    dplyr::arrange(dplyr::desc(abs(.data[[col]]))) |> head(n)
  print(d |> dplyr::transmute(cat_label = substr(cat_label, 1, 42),
          fam = round(share_fam, 2), single = round(share_single, 2),
          gap = round(gap_total, 2), adj = round(.data[[col]], 2)) |>
        as.data.frame(), row.names = FALSE)
}
message("\n============== PASS A: NET OUT HOUSING (", LATEST, ") ==============")
show("ex_housing", "gap_total", "All housing removed, largest remaining gaps")
message("\n============== PASS B: AGE-ADJUSTED (", LATEST, ") ==============")
show("consumption", "gap_net_of_age", "Consumption base, gap net of age composition")
message("\n============== PASS C: TENURE DECOMPOSITION ==============")
show("consumption", "gap_net_of_ten", "Consumption base, gap net of tenure composition")
message("\n--- Basket dissimilarity (pct of budget to reallocate) ---")
print(as.data.frame(summ |> dplyr::mutate(dplyr::across(dplyr::where(is.numeric),
                                                        ~round(.x, 2)))), row.names = FALSE)
message("\nValidation log: ", LOG)

# ===========================================================================
# 8. Cross-script consistency guard
# ===========================================================================
# 02_build_shares.R computes shares on the TOTALEXP denominator; this script
# computes them on the consumption base. They must be reconcilable:
#   share_consumption = share_raw / (1 - out_of_scope_share)
# A mismatch means the two scripts have drifted apart. Fails loudly.
p1 <- file.path(DIR_DER, "cex_shares_long.csv")
if (file.exists(p1)) {
  s1 <- readr::read_csv(p1, show_col_types = FALSE,
                        col_types = readr::cols(cat_id = "c")) |>
    dplyr::filter(year == LATEST, group %in% c("families_kids", "single_other"))
  oos_sh <- s1 |> dplyr::filter(cat_id %in% c("40", "41")) |>
    dplyr::summarise(oos = sum(share_raw) / 100, .by = group)
  recon <- s1 |>
    dplyr::filter(!cat_id %in% c("40", "41")) |>
    dplyr::left_join(oos_sh, by = "group") |>
    dplyr::mutate(implied = share_raw / (1 - oos),
                  grp = dplyr::if_else(group == "families_kids", "F1", "10")) |>
    dplyr::select(cat_id, grp, implied) |>
    dplyr::left_join(
      res |> dplyr::filter(base == "consumption") |>
        dplyr::select(cat_id, share_fam, share_single) |>
        tidyr::pivot_longer(c(share_fam, share_single), values_to = "here") |>
        dplyr::mutate(grp = dplyr::if_else(name == "share_fam", "F1", "10")) |>
        dplyr::select(cat_id, grp, here),
      by = c("cat_id", "grp")) |>
    dplyr::mutate(delta = abs(implied - here))
  worst <- max(recon$delta, na.rm = TRUE)
  say("## 8. Cross-script consistency vs 02_build_shares.R")
  say(sprintf("  %d category x group reconciliations, worst delta %.4f pp",
              sum(!is.na(recon$delta)), worst))
  if (worst > 0.01) {
    bad <- recon[which.max(recon$delta), ]
    stop("Shares disagree with 02_build_shares.R by ", sprintf("%.4f", worst),
         " pp at cat_id ", bad$cat_id, " group ", bad$grp,
         ". The two scripts have drifted.", call. = FALSE)
  }
  message("\nCross-script consistency OK: worst delta ",
          sprintf("%.4f", worst), " pp vs 02_build_shares.R")
} else {
  say("## 8. Cross-script consistency: SKIPPED (run 02_build_shares.R first)")
}
