# ---------------------------------------------------------------------------
# 03_phase1_figures.R   ---  PHASE 1 presentation layer
#
# Consumes data/derived/cex_shares_long.csv. Produces the Phase 1 figures and
# the CPI-scope share table that Phase 3 will weight with.
#
# Run from the project root:  Rscript R/03_phase1_figures.R
#
# Outputs
#   output/tables/t04_share_gaps_cpiscope_2024.csv
#   output/tables/t05_gap_over_time.csv
#   output/figures/f01_share_gaps_2024.png
#   output/figures/f02_shelter_tenure_over_time.png
#   output/figures/f03_family_categories_over_time.png
# ---------------------------------------------------------------------------

source("R/00_setup.R")

shares <- readr::read_csv(file.path(DIR_DER, "cex_shares_long.csv"),
                          show_col_types = FALSE)
LATEST <- max(shares$year)

ESP_NAVY <- "#2c3254"; ESP_RED <- "#ff8361"; ESP_GREEN <- "#70ad8f"

theme_fii <- function(base_size = 12) {
  ggplot2::theme_minimal(base_size = base_size) +
    ggplot2::theme(
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey88"),
      plot.title    = ggplot2::element_text(face = "bold", size = base_size + 2),
      plot.subtitle = ggplot2::element_text(colour = "grey30", size = base_size - 1),
      plot.caption  = ggplot2::element_text(colour = "grey45", size = base_size - 3,
                                            hjust = 0),
      legend.position = "top",
      legend.title = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold")
    )
}

SRC <- paste0("Source: BLS Consumer Expenditure Survey, LB06 composition of ",
              "consumer unit. Vintage ", substr(VINTAGE, 1, 10),
              ".\nFamilies with children = married-with-children plus ",
              "single-parent CUs, weighted by consumer-unit counts.")

# ===========================================================================
# t04: CPI-scope shares and gaps
# ===========================================================================
# Renormalized on the CPI-consistent denominator (TOTALEXP less pensions,
# insurance, and cash contributions). This is the weight vector Phase 3 uses.
t04 <- shares |>
  dplyr::filter(year == LATEST, in_cpi_scope != "FALSE",
                group %in% c("families_kids", "single_other", "all_cu",
                             "married_kids", "single_parent")) |>
  dplyr::select(cat_id, major, cat_label, in_cpi_scope, group, share_cpi) |>
  tidyr::pivot_wider(names_from = group, values_from = share_cpi) |>
  dplyr::mutate(gap_pp = families_kids - single_other) |>
  dplyr::arrange(dplyr::desc(gap_pp))
readr::write_csv(t04, file.path(DIR_TAB, "t04_share_gaps_cpiscope_2024.csv"))

message("\n=== CPI-scope shares, ", LATEST, " (denominator excludes pensions/insurance/cash contributions) ===")
print(t04 |> dplyr::transmute(cat_label = substr(cat_label, 1, 44),
                             fam = round(families_kids, 2),
                             single = round(single_other, 2),
                             all_cu = round(all_cu, 2),
                             gap_pp = round(gap_pp, 2)) |> as.data.frame(),
      row.names = FALSE)

# ===========================================================================
# f01: the money chart
# ===========================================================================
# Uses RAW shares (denominator = TOTALEXP), not CPI-scope shares. Reason:
# scope_cpi_a drops owner-occupied mortgage interest and property taxes without
# substituting owners' equivalent rent, so it shows renters' shelter while
# hiding owners'. On a family-versus-single comparison, where tenure is the
# dominant difference, that would overstate the rent gap by construction.
#
# Out-of-scope categories (pensions and insurance, cash contributions) are
# omitted from the plot: they are saving and transfers, not consumption, and
# the pensions gap of +4.5 pp would dominate a chart about baskets. They are
# retained in the denominator, so no renormalization distortion is introduced.
#
# Shelter gets its own panel and its own x scale. The rented-dwellings gap is
# roughly nine percentage points and would flatten every other bar.
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

bar_panel <- function(dat, title) {
  ggplot2::ggplot(dat, ggplot2::aes(gap_pp, cat_label, fill = sign)) +
    ggplot2::geom_col(width = 0.72) +
    ggplot2::geom_vline(xintercept = 0, colour = "grey25", linewidth = 0.4) +
    ggplot2::scale_fill_manual(values = c(ESP_NAVY, ESP_RED), drop = FALSE) +
    ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
    ggplot2::labs(subtitle = title, x = NULL, y = NULL) +
    theme_fii() +
    ggplot2::theme(plot.subtitle = ggplot2::element_text(face = "bold",
                                                         colour = "grey20"))
}

p_other <- bar_panel(dplyr::filter(f01_d, !shelter),
                     "All categories except shelter") +
  ggplot2::theme(legend.position = "none")
p_shel  <- bar_panel(dplyr::filter(f01_d, shelter),
                     "Shelter (note the wider scale)") +
  ggplot2::labs(x = "Share gap (percentage points)") +
  ggplot2::theme(legend.position = "none")

legend_src <- ggplot2::ggplot(f01_d, ggplot2::aes(gap_pp, cat_label, fill = sign)) +
  ggplot2::geom_col() +
  ggplot2::scale_fill_manual(values = c(ESP_NAVY, ESP_RED)) + theme_fii()

p1 <- patchwork::wrap_plots(p_other, p_shel, ncol = 1,
                            heights = c(nrow(dplyr::filter(f01_d, !shelter)),
                                        nrow(dplyr::filter(f01_d, shelter)) + 2)) +
  patchwork::plot_annotation(
    title = paste0("Families with children buy a different basket, ", LATEST),
    subtitle = paste0("Difference in share of total expenditures, percentage points.\n",
                      "Pensions and cash contributions omitted as saving and transfers,\n",
                      "not consumption. Non-shelter gaps under 0.1 pp omitted."),
    caption = SRC,
    theme = theme_fii()) &
  patchwork::plot_layout(guides = "collect")

p1 <- patchwork::wrap_plots(
  cowplot::get_plot_component(legend_src + ggplot2::theme(legend.position = "top"),
                              "guide-box-top", return_all = TRUE),
  patchwork::wrap_plots(p_other, p_shel, ncol = 1,
                        heights = c(nrow(dplyr::filter(f01_d, !shelter)),
                                    nrow(dplyr::filter(f01_d, shelter)) + 2)),
  ncol = 1, heights = c(1, 26)) +
  patchwork::plot_annotation(
    title = paste0("Families with children buy a different basket, ", LATEST),
    subtitle = paste0("Difference in share of total expenditures, percentage points. ",
                      "Pensions and cash\ncontributions omitted as saving and transfers, ",
                      "not consumption. Non-shelter\ngaps under 0.1 pp omitted."),
    caption = SRC, theme = theme_fii())

ggplot2::ggsave(file.path(DIR_FIG, "f01_share_gaps_2024.png"), p1,
                width = 9.5, height = 8.5, dpi = 200, bg = "white")

# ===========================================================================
# f02: the tenure story
# ===========================================================================
# The largest single gap is rent versus owner-occupied shelter. That is a
# tenure-composition fact, and it is the reason the sign of any family
# inflation gap depends on shelter treatment.
f02_d <- shares |>
  dplyr::filter(group %in% c("families_kids", "single_other"),
                cat_id %in% c("04", "05", "06", "07")) |>
  dplyr::mutate(
    tenure = dplyr::if_else(cat_id == "07", "Rented dwellings",
                            "Owner-occupied shelter outlays"),
    grp = dplyr::if_else(group == "families_kids",
                         "Families with children", "Single-person and other CUs")) |>
  dplyr::summarise(share = sum(share_raw), .by = c(year, tenure, grp))

p2 <- ggplot2::ggplot(f02_d, ggplot2::aes(year, share, colour = grp)) +
  ggplot2::geom_line(linewidth = 0.9) +
  ggplot2::facet_wrap(~tenure) +
  ggplot2::scale_colour_manual(values = c(ESP_NAVY, ESP_RED)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%"),
                              limits = c(0, NA)) +
  ggplot2::labs(
    title = "The biggest budget difference is tenure, not children",
    subtitle = paste0("Share of total expenditures. Owner-occupied outlays = mortgage ",
                      "interest, property taxes,\nmaintenance and insurance. CPI replaces ",
                      "all three with owners' equivalent rent."),
    x = NULL, y = "Share of total expenditures", caption = SRC) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f02_shelter_tenure_over_time.png"), p2,
                width = 9.5, height = 5, dpi = 200, bg = "white")

# ===========================================================================
# f03: family-salient categories over time
# ===========================================================================
FAM_CATS <- c("14", "37", "20", "01", "24", "23")
f03_d <- shares |>
  dplyr::filter(group %in% c("families_kids", "single_other"),
                cat_id %in% FAM_CATS) |>
  dplyr::mutate(grp = dplyr::if_else(group == "families_kids",
                                     "Families with children",
                                     "Single-person and other CUs"),
                cat_label = factor(cat_label,
                                   levels = t04$cat_label[t04$cat_label %in% cat_label]))

p3 <- ggplot2::ggplot(f03_d, ggplot2::aes(year, share_raw, colour = grp)) +
  ggplot2::geom_line(linewidth = 0.85) +
  ggplot2::facet_wrap(~cat_label, scales = "free_y", ncol = 3,
                      labeller = ggplot2::label_wrap_gen(32)) +
  ggplot2::scale_colour_manual(values = c(ESP_NAVY, ESP_RED)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(
    title = "Family-salient budget shares, 1988-2024",
    subtitle = "Share of total expenditures. Note the childcare proxy is Personal services, which for single-person\nCUs is roughly half elderly care, so that gap is understated.",
    x = NULL, y = "Share of total expenditures", caption = SRC) +
  theme_fii(11)
ggplot2::ggsave(file.path(DIR_FIG, "f03_family_categories_over_time.png"), p3,
                width = 10.5, height = 6.5, dpi = 200, bg = "white")

# ===========================================================================
# t05: has the gap moved over time?
# ===========================================================================
t05 <- shares |>
  dplyr::filter(group %in% c("families_kids", "single_other")) |>
  dplyr::select(year, cat_id, cat_label, major, group, share_raw) |>
  tidyr::pivot_wider(names_from = group, values_from = share_raw) |>
  dplyr::mutate(gap_pp = families_kids - single_other) |>
  dplyr::arrange(cat_id, year)
readr::write_csv(t05, file.path(DIR_TAB, "t05_gap_over_time.csv"))

message("\nFigures written to ", DIR_FIG)
message("Tables written to ", DIR_TAB)
message("Vintage: ", VINTAGE)
