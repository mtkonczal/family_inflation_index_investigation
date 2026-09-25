# ---------------------------------------------------------------------------
# make_slide_figures.R  ---  presentation-only derivatives of Phase 1 figures
#
# Not part of the numbered analysis pipeline; run after R/10_intuition.R.
# Rebuilds f01 (share gaps, 2024)
# without the baked-in title/subtitle/source caption and on a beige background
# that matches the slide deck, so it can run larger on a slide with the
# equivalent text moved into the slide body instead of the image.
#
# Run from anywhere inside the repo: Rscript slides/make_slide_figures.R
# ---------------------------------------------------------------------------

# Run as: Rscript slides/make_slide_figures.R   (from the project root)
setup_candidates <- c("R/00_setup.R", "../R/00_setup.R")
source(setup_candidates[file.exists(setup_candidates)][1])

shares <- readr::read_csv(file.path(DIR_DER, "cex_shares_long.csv"),
                          show_col_types = FALSE)
LATEST <- max(shares$year)

# C3 palette (Economic Security Project): soft green accent, warm navy anchor.
# The deck is C3, so Warm Red (the C4 accent) is not used.
ESP_NAVY <- "#2c3254"; ESP_GREEN <- "#70ad8f"; ESP_BEIGE <- "#f4f2e4"
ESP_GOLD <- "#ebc382"; ESP_PURPLE <- "#472b51"; ESP_TEXT <- "#3c4164"

theme_slide <- function(base_size = 15) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey80"),
      legend.position = "top",
      legend.title = ggplot2::element_blank(),
      plot.background  = ggplot2::element_rect(fill = ESP_BEIGE, colour = NA),
      panel.background = ggplot2::element_rect(fill = ESP_BEIGE, colour = NA),
      legend.background = ggplot2::element_rect(fill = ESP_BEIGE, colour = NA),
      legend.key = ggplot2::element_rect(fill = ESP_BEIGE, colour = NA)
    )
}

f01_d <- shares |>
  dplyr::filter(year == LATEST, group %in% c("families_kids", "single_other"),
                in_cpi_scope != "FALSE" | cat_id %in% c("04", "05")) |>
  dplyr::select(cat_id, major, cat_label, group, share_raw) |>
  tidyr::pivot_wider(names_from = group, values_from = share_raw) |>
  dplyr::mutate(
    gap_pp = families_kids - single_other,
    shelter = cat_id %in% c("04", "05", "06", "07", "08"),
    sign  = ifelse(gap_pp > 0, "Families with children spend more",
                   "Single-person and other CUs spend more")) |>
  dplyr::filter(abs(gap_pp) >= 0.10 | shelter) |>
  dplyr::mutate(cat_label = forcats::fct_reorder(cat_label, gap_pp))

bar_panel <- function(dat, subtitle) {
  ggplot2::ggplot(dat, ggplot2::aes(gap_pp, cat_label, fill = sign)) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey25", linewidth = 0.4) +
    ggplot2::scale_fill_manual(values = c(ESP_NAVY, ESP_GREEN), drop = FALSE) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
    ggplot2::labs(subtitle = subtitle, x = NULL, y = NULL) +
    theme_slide() +
    ggplot2::theme(plot.subtitle = ggplot2::element_text(face = "bold", colour = "grey20"))
}

p_other <- bar_panel(dplyr::filter(f01_d, !shelter), "All categories except shelter") +
  ggplot2::theme(legend.position = "none")
p_shel  <- bar_panel(dplyr::filter(f01_d, shelter), "Shelter (note the wider scale)") +
  ggplot2::labs(x = "Share gap (percentage points)") +
  ggplot2::theme(legend.position = "none")

legend_src <- ggplot2::ggplot(f01_d, ggplot2::aes(gap_pp, cat_label, fill = sign)) +
  ggplot2::geom_col() +
  ggplot2::scale_fill_manual(values = c(ESP_NAVY, ESP_GREEN)) + theme_slide()

p1 <- patchwork::wrap_plots(
  cowplot::get_plot_component(legend_src + ggplot2::theme(legend.position = "top"),
                              "guide-box-top", return_all = TRUE),
  patchwork::wrap_plots(p_other, p_shel, ncol = 1,
                        heights = c(nrow(dplyr::filter(f01_d, !shelter)),
                                    nrow(dplyr::filter(f01_d, shelter)) + 2)),
  ncol = 1, heights = c(1, 30)) &
  ggplot2::theme(plot.background = ggplot2::element_rect(fill = ESP_BEIGE, colour = NA))

dir.create(file.path(PROJ, "slides", "assets", "figures"),
           showWarnings = FALSE, recursive = TRUE)
OUT <- file.path(PROJ, "slides", "assets", "figures", "f01_budget_diff_slide.png")
ggplot2::ggsave(OUT, p1, width = 11, height = 8, dpi = 220, bg = ESP_BEIGE)
message("wrote ", OUT)

# ===========================================================================
# income_bars: lowest vs. highest, decile / quintile / family status
# ===========================================================================
# Same test (t23_dimension_cumulative.csv), same headline comparison
# (t16_headline_summary.csv), both CPI-concept basket (D-30), both Dec 2019 - Jul 2026.
# Plotted as levels (not gaps) on a zero baseline: the point is that income
# bars visibly differ in length and the family-status bars do not, and a
# zero baseline is the only honest way to show that.
dim_cum <- readr::read_csv(file.path(DIR_TAB, "t23_dimension_cumulative.csv"),
                           show_col_types = FALSE)
headline <- readr::read_csv(file.path(DIR_TAB, "t16_headline_summary.csv"),
                            show_col_types = FALSE)

get_dim <- function(dimension_, group_) {
  dim_cum |>
    dplyr::filter(dimension == dimension_, basket == "pm_oer_all_in", group == group_) |>
    dplyr::pull(cum_pct)
}
get_headline <- function(group_) {
  headline |>
    dplyr::filter(basket == "pm_oer_all_in", group == group_, from == "2019-12-01") |>
    dplyr::pull(cum_pct)
}

income_d <- tibble::tibble(
  cluster = c("Income\n(lowest vs. highest decile)", "Income\n(lowest vs. highest decile)",
              "Income\n(lowest vs. highest quintile)", "Income\n(lowest vs. highest quintile)",
              "Family status", "Family status"),
  bar_label = c("Lowest decile", "Highest decile",
                "Lowest quintile", "Highest quintile",
                "Families with children", "Single/other households"),
  side = c("A", "B", "A", "B", "A", "B"),
  value = c(get_dim("income_decile", "Lowest decile"),
            get_dim("income_decile", "Highest decile"),
            get_dim("income_quintile", "Lowest quintile"),
            get_dim("income_quintile", "Highest quintile"),
            get_headline("families_kids"),
            get_headline("single_other"))
) |>
  dplyr::mutate(
    cluster = factor(cluster, levels = c("Income\n(lowest vs. highest decile)",
                                          "Income\n(lowest vs. highest quintile)",
                                          "Family status")),
    bar_label = factor(bar_label, levels = rev(bar_label))
  )

p_income <- ggplot2::ggplot(income_d, ggplot2::aes(value, bar_label, fill = side)) +
  ggplot2::geom_col(width = 0.68) +
  ggplot2::geom_text(ggplot2::aes(label = paste0(sprintf("%.2f", value), "%"), x = value),
                      hjust = -0.15, size = 4.6, colour = "#2c3254", fontface = "bold") +
  ggplot2::scale_fill_manual(values = c(A = ESP_NAVY, B = ESP_GREEN), guide = "none") +
  ggplot2::scale_x_continuous(limits = c(0, 36), expand = c(0, 0)) +
  ggplot2::facet_grid(rows = ggplot2::vars(cluster), scales = "free_y", space = "free_y",
                      switch = "y") +
  ggplot2::labs(x = "Cumulative price change, Dec 2019 to Jul 2026", y = NULL) +
  theme_slide() +
  ggplot2::theme(
    strip.placement = "outside",
    strip.background = ggplot2::element_blank(),
    strip.text.y.left = ggplot2::element_text(face = "bold", colour = "#2c3254", angle = 0,
                                              hjust = 0),
    axis.text.y = ggplot2::element_text(colour = "#3c4164"),
    panel.grid.major.y = ggplot2::element_blank(),
    panel.spacing = ggplot2::unit(1.1, "lines")
  )

OUT2 <- file.path(PROJ, "slides", "assets", "figures", "income_bars_slide.png")
ggplot2::ggsave(OUT2, p_income, width = 10.5, height = 6, dpi = 220, bg = ESP_BEIGE)
message("wrote ", OUT2)


# ===========================================================================
# Slide versions of the headline and intuition charts (from 06 and 10 outputs)
# ===========================================================================
fam_idx <- readr::read_csv(file.path(DIR_DER, "family_index.csv"), show_col_types = FALSE)
D0 <- as.Date("2019-12-01")
save_slide <- function(p, name, w = 11, h = 6) {
  out <- file.path(PROJ, "slides", "assets", "figures", name)
  ggplot2::ggsave(out, p, width = w, height = h, dpi = 220, bg = ESP_BEIGE)
  message("wrote ", out)
}

# --- cumulative, headline basket ----------------------------------------
cum <- fam_idx |>
  dplyr::filter(basket == "pm_oer_all_in", group %in% c("families_kids", "single_other"), date >= D0) |>
  dplyr::group_by(group) |>
  dplyr::mutate(cum = 100 * (index / index[date == D0] - 1)) |> dplyr::ungroup() |>
  dplyr::mutate(grp = ifelse(group == "families_kids", "Families with children", "Single-person and other"))
ends <- cum |> dplyr::filter(date == max(date))
p_cum <- ggplot2::ggplot(cum, ggplot2::aes(date, cum, colour = grp)) +
  ggplot2::geom_line(linewidth = 1.3) +
  ggplot2::geom_text(data = ends, ggplot2::aes(label = sprintf("%.1f%%", cum), x = date + 20),
                     hjust = 0, vjust = ifelse(ends$group == "families_kids", 1.3, -0.3),
                     size = 4.8, fontface = "bold") +
  ggplot2::annotate("text", x = as.Date("2023-03-01"), y = 25, label = "Single-person and other",
                    colour = ESP_NAVY, fontface = "bold", size = 4.8, hjust = 1) +
  ggplot2::annotate("text", x = as.Date("2024-03-01"), y = 15.5, label = "Families with children",
                    colour = "#3d7a5c", fontface = "bold", size = 4.8, hjust = 0) +
  ggplot2::scale_x_date(expand = ggplot2::expansion(mult = c(0.02, 0.09))) +
  ggplot2::scale_colour_manual(values = c(ESP_GREEN, ESP_NAVY), guide = "none") +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(x = NULL, y = "Cumulative price change since Dec 2019") +
  theme_slide() + ggplot2::theme(legend.position = "none")
save_slide(p_cum, "cumulative_slide.png", 10, 5.6)

# --- 12-month gap with sampling band --------------------------------------
se <- readr::read_csv(file.path(DIR_TAB, "t26_gap_sampling_se.csv"), show_col_types = FALSE) |>
  dplyr::filter(basket == "pm_oer_all_in", pair == "fam", date >= as.Date("2017-01-01"))
p_gap <- ggplot2::ggplot(se, ggplot2::aes(date, gap_12m)) +
  ggplot2::annotate("rect", xmin = as.Date("2021-04-01"), xmax = as.Date("2022-08-01"),
                    ymin = -Inf, ymax = Inf, fill = ESP_GREEN, alpha = 0.12) +
  ggplot2::annotate("rect", xmin = as.Date("2022-11-01"), xmax = as.Date("2026-02-01"),
                    ymin = -Inf, ymax = Inf, fill = ESP_NAVY, alpha = 0.07) +
  ggplot2::geom_ribbon(ggplot2::aes(ymin = gap_12m - 1.96 * se_gap, ymax = gap_12m + 1.96 * se_gap),
                       fill = ESP_NAVY, alpha = 0.18) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey40") +
  ggplot2::geom_line(colour = ESP_NAVY, linewidth = 1.1) +
  ggplot2::annotate("text", x = as.Date("2021-12-15"), y = 0.86, label = "Families hotter",
                    colour = "#3d7a5c", fontface = "bold", size = 4.6) +
  ggplot2::annotate("text", x = as.Date("2024-06-15"), y = -0.72, label = "Singles hotter",
                    colour = ESP_NAVY, fontface = "bold", size = 4.6) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, " pp")) +
  # coord_cartesian, not scale limits: limits turn band values past 0.8 into NA
  # and break the ribbon.
  ggplot2::coord_cartesian(ylim = c(-0.8, 0.9)) +
  ggplot2::labs(x = NULL, y = "12-month inflation, families minus singles") +
  theme_slide()
save_slide(p_gap, "gap12_slide.png", 11, 5.4)

# --- where the gap comes from, two periods ----------------------------------
blk <- readr::read_csv(file.path(DIR_TAB, "t33_contrib_blocks.csv"), show_col_types = FALSE) |>
  dplyr::filter(window %in% c("2014-2019, CPI concept", "2019-2026, CPI concept (headline)")) |>
  dplyr::mutate(period = ifelse(grepl("^2014", window), "2014 to 2019 (total -1.05 pp)",
                                "2019 to 2026 (total -0.69 pp)"),
                block = forcats::fct_reorder(block, contrib, .fun = sum))
p_blk <- ggplot2::ggplot(blk, ggplot2::aes(contrib, block, fill = contrib > 0)) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey25") +
  ggplot2::facet_wrap(~period, ncol = 2) +
  ggplot2::scale_fill_manual(values = c(`TRUE` = ESP_GREEN, `FALSE` = ESP_NAVY), guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(x = "Contribution to the family-minus-single gap (pp)", y = NULL) +
  theme_slide() + ggplot2::theme(strip.text = ggplot2::element_text(face = "bold", size = 15, colour = ESP_NAVY))
save_slide(p_blk, "blocks_slide.png", 12, 6)

# --- share gap vs relative price ------------------------------------------
dec <- readr::read_csv(file.path(DIR_TAB, "t32_relative_contrib.csv"), show_col_types = FALSE,
                       col_types = readr::cols(cat_id = "c")) |>
  dplyr::filter(window == "2019-2026, CPI concept (headline)")
# Hand-placed labels (lx, ly): ggrepel put names next to the wrong points.
lab_pos <- tibble::tribble(
  ~cat_id, ~lab,                ~lx,   ~ly,
  "07",    "Rent",              -6.6,   9.0,
  "37",    "Education",          2.35, -15.3,
  "24",    "Gasoline",           1.4,   26.5,
  "38",    "Tobacco",           -2.2,   26.5,
  "10",    "Electricity",       -2.4,   18.5,
  "23",    "Vehicle purchases",  2.35,  -6.5,
  "14",    "Childcare",          2.35,   1.5,
  "01",    "Food at home",       2.35,   6.5,
  "19",    "Women's apparel",    1.4,  -24.0)
dd <- dec |> dplyr::left_join(lab_pos, by = "cat_id")
p_sc <- ggplot2::ggplot(dd, ggplot2::aes(mean_dw, rel_chg)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey50") +
  ggplot2::geom_vline(xintercept = 0, colour = "grey50") +
  ggplot2::geom_point(ggplot2::aes(size = abs(contrib), colour = contrib > 0), alpha = 0.85) +
  ggplot2::geom_point(data = dplyr::filter(dd, cat_id == "14"), shape = 21, size = 7,
                      stroke = 1.3, colour = ESP_GREEN, fill = NA) +
  ggplot2::geom_segment(data = dplyr::filter(dd, !is.na(lab)),
                        ggplot2::aes(xend = lx, yend = ly), colour = "grey55", linewidth = 0.35) +
  ggplot2::geom_label(data = dplyr::filter(dd, !is.na(lab)), ggplot2::aes(x = lx, y = ly, label = lab),
                      size = 4.6, colour = ESP_TEXT, fill = ESP_BEIGE, label.size = 0,
                      hjust = ifelse(dplyr::filter(dd, !is.na(lab))$lx > 2, 0, 0.5)) +
  ggplot2::annotate("text", x = -7.6, y = -24, hjust = 0, size = 4, colour = "grey35",
                    label = "Left of zero: singles spend more of their budget on it.\nAbove zero: its price rose faster than average.") +
  ggplot2::scale_colour_manual(values = c(`TRUE` = ESP_GREEN, `FALSE` = ESP_NAVY), guide = "none") +
  ggplot2::scale_size_area(max_size = 14, guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp"), limits = c(-8, 4.2)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(x = "Family budget share minus single share",
                y = "Price change minus average, Dec 2019 to Jul 2026") +
  theme_slide()
save_slide(p_sc, "scatter_slide.png", 11, 6.4)

# --- childcare vs other services -----------------------------------------
rt <- readr::read_csv(file.path(DIR_TAB, "t34_services_rates.csv"), show_col_types = FALSE) |>
  dplyr::filter(item_code %in% c("SEEB03", "SAS", "SASL2RS", "SAC")) |>
  dplyr::mutate(series = factor(series, levels = c("Day care and preschool", "All services",
                                                   "Services less rent of shelter", "Goods")),
                period = factor(period, levels = c("2000s", "2010s", "2019-2026"),
                                labels = c("2000 to 2010", "2010 to 2019", "2019 to 2026")))
p_cc <- ggplot2::ggplot(rt, ggplot2::aes(period, annualized, fill = series)) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.82), width = 0.76) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f", annualized)),
                     position = ggplot2::position_dodge(width = 0.82), vjust = -0.45, size = 4.4,
                     colour = ESP_TEXT) +
  ggplot2::scale_fill_manual(values = c(ESP_GREEN, ESP_NAVY, "#7d86a8", "#caccd4")) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%"),
                              expand = ggplot2::expansion(mult = c(0, 0.12))) +
  ggplot2::labs(x = NULL, y = "Annual price growth (CPI)") +
  theme_slide()
save_slide(p_cc, "childcare_services_slide.png", 11, 5.6)

# --- shares by household size -------------------------------------------
sz <- readr::read_csv(file.path(DIR_TAB, "t35_size_shares.csv"), show_col_types = FALSE,
                      col_types = readr::cols(characteristics_code = "c")) |>
  dplyr::select(size, Housing = shelter_share, `Food at home` = food_home_share,
                `Vehicles and gas` = vehicle_share) |>
  tidyr::pivot_longer(-size) |>
  dplyr::mutate(size = factor(size, levels = c("1 person", "2 people", "3 people", "4 people", "5 or more")),
                name = factor(name, levels = c("Housing", "Food at home", "Vehicles and gas")))
p_sz <- ggplot2::ggplot(sz, ggplot2::aes(size, value, fill = name)) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.74) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.0f%%", value)),
                     position = ggplot2::position_dodge(width = 0.8), vjust = -0.45, size = 4.4, colour = ESP_TEXT) +
  ggplot2::scale_fill_manual(values = c(ESP_NAVY, ESP_GREEN, ESP_GOLD)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%"),
                              expand = ggplot2::expansion(mult = c(0, 0.12))) +
  ggplot2::labs(x = "Household size", y = "Share of spending, 2024") +
  theme_slide()
save_slide(p_sz, "size_slide.png", 11, 5.6)

# --- comparison groups (review 2, from 11_review_checks.R) -----------------
cmp <- readr::read_csv(file.path(DIR_TAB, "t38_comparators.csv"), show_col_types = FALSE,
                       col_types = readr::cols(g1 = "c", g2 = "c")) |>
  dplyr::filter(variant == "headline", basket == "oer", g1 == "F1") |>
  dplyr::mutate(who = c("10" = "Single-person and other households", "RF" = "All other households",
                        "01" = "All households", "03" = "Married couples without children")[g2],
                who = factor(who, levels = rev(c("Single-person and other households", "All other households",
                                                 "All households", "Married couples without children"))))
p_cmp <- ggplot2::ggplot(cmp, ggplot2::aes(gap, who)) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey40", linewidth = 0.5) +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = gap - 1.96 * se_indep, xmax = gap + 1.96 * se_indep),
                         width = 0, linewidth = 1.6, colour = ESP_NAVY, alpha = 0.45, orientation = "y") +
  ggplot2::geom_point(size = 4.2, colour = ESP_NAVY) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%+.1f", gap)), vjust = -1.1, size = 4.8,
                     colour = ESP_NAVY, fontface = "bold") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pts"), limits = c(-1.2, 0.8)) +
  ggplot2::labs(x = "Families minus comparison group, cumulative inflation since Dec 2019", y = NULL) +
  theme_slide() + ggplot2::theme(panel.grid.major.y = ggplot2::element_blank(),
                                 axis.text.y = ggplot2::element_text(colour = ESP_TEXT, size = 15))
save_slide(p_cmp, "comparators_slide.png", 11, 5.2)
