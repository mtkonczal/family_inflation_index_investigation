# ---------------------------------------------------------------------------
# 10_intuition.R   ---  why the family gap is what it is (D-34)
#
# Four pieces of evidence for the slides and paper, none of which changes an
# estimate:
#
#   1. RELATIVE-PRICE DECOMPOSITION of the cumulative gap, by category and
#      period. Because both groups' weights sum to one,
#        gap = sum_i (w_F,i - w_N,i) * r_i = sum_i (w_F,i - w_N,i) * (r_i - rbar)
#      for any rbar. Only the second form attributes the gap sensibly: a
#      category matters when families over- or under-weight it AND its price
#      rose faster or slower than average. The first form credits every
#      over-weighted category with a positive contribution merely because
#      prices rose at all. rbar is the all-CU link inflation.
#      Exact within each calendar-year link (one weight vintage per link,
#      Laspeyres over the link); links are combined at the average cumulative
#      level, and the small compounding residual is reported.
#   2. CHILDCARE AGAINST OTHER SERVICES: CPI day care and preschool versus
#      services aggregates, by decade.
#   3. CHILDCARE SPENDING LEVELS by family type (CE).
#   4. ECONOMIES OF SCALE IN SHELTER: budget shares by household size (LB05),
#      with owners' housing at rental value (CE rental-value question).
#
# Run from the project root after 06:  Rscript R/10_intuition.R
#
# Outputs
#   output/tables/t00h_intuition.txt
#   output/tables/t32_relative_contrib.csv     category x window
#   output/tables/t33_contrib_blocks.csv       category blocks x window
#   output/tables/t34_services_rates.csv       annualized CPI rates by period
#   output/tables/t35_size_shares.csv          shares by household size
#   output/tables/t36_childcare_levels.csv
#   output/figures/f15_share_vs_relprice.png, f16_contrib_blocks.png,
#                  f17_childcare_vs_services.png, f18_shares_by_size.png
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")
source("R/functions/index_build.R")
source("R/functions/ce_tables.R")

LOG <- file.path(DIR_TAB, "t00h_intuition.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }
say("# Intuition log"); say("# built_at: ", VINTAGE); say("")

tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
xw <- readr::read_csv(file.path(DIR_XWALK, "cex_to_cpi.csv"),
                      col_types = readr::cols(.default = readr::col_character())) |>
  dplyr::filter(!is.na(cpi_item_code))
prices <- readr::read_csv(file.path(DIR_DER, "cpi_category_index.csv"), show_col_types = FALSE,
                          col_types = readr::cols(cat_id = "c")) |> dplyr::select(cat_id, date, index)
fam <- readr::read_csv(file.path(DIR_DER, "family_index.csv"), show_col_types = FALSE)
wts <- readr::read_csv(file.path(DIR_DER, "index_weights.csv"), show_col_types = FALSE,
                       col_types = readr::cols(cat_id = "c"))
cpi <- readRDS(file.path(DIR_RAW, "cpi_raw.rds"))
cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))
cn <- cpi_national(cpi)
MEDICAL <- tax$cat_id[tax$major == "Health"]

# Category prices for each basket family, as in 06.
ri_cat <- ri_by_category(cpi, xw, fill = TRUE)
m0 <- build_index_ri(prices, ri_cat, MEDICAL) |> dplyr::transmute(cat_id = "M0", date, index)
sehc <- cn |> dplyr::filter(item_code == "SEHC", date %in% unique(prices$date)) |>
  dplyr::transmute(cat_id = "H0", date, index = value)
px_all <- dplyr::bind_rows(prices, m0, sehc)

labs_x <- dplyr::bind_rows(dplyr::select(tax, cat_id, cat_label),
  tibble::tibble(cat_id = c("M0", "H0"), cat_label = c("Medical care (pooled)", "Owners' equivalent rent")))
BLOCK <- function(id) dplyr::case_when(
  id %in% c("07") ~ "Rent",
  id %in% c("H0", "06", "08") ~ "Owners' housing and lodging",
  id == "14" ~ "Childcare",
  id == "37" ~ "Education",
  id %in% c("23", "24", "25", "26") ~ "Vehicles, gas, transport",
  id %in% c("01", "02") ~ "Food",
  id %in% c("09", "10", "11", "12", "13") ~ "Utilities and phone",
  id %in% c("M0", MEDICAL) ~ "Medical",
  id %in% c("03", "38") ~ "Alcohol and tobacco",
  id %in% c("18", "19", "20", "21", "22") ~ "Apparel",
  TRUE ~ "Everything else")

# ===========================================================================
# 1. Relative-price decomposition of the cumulative gap
# ===========================================================================
decomp_window <- function(basket, d0, d1, gF = "families_kids", gN = "single_other") {
  ix <- fam[fam$basket == basket, ]
  dates <- sort(unique(ix$date))
  if (!d0 %in% dates) stop("window start not in ", basket)
  cuts <- sort(unique(c(d0, dates[format(dates, "%m") == "12" & dates > d0 & dates < d1], d1)))
  lev <- function(g, d) ix$index[ix$group == g & ix$date == d] / ix$index[ix$group == g & ix$date == d0]
  out <- NULL; chk <- NULL
  for (k in seq_len(length(cuts) - 1L)) {
    a <- cuts[k]; b <- cuts[k + 1L]; m <- min(dates[dates > a])
    w <- wts |> dplyr::filter(basket == !!basket, date == m, group %in% c(gF, gN, "all_cu")) |>
      dplyr::select(group, cat_id, weight) |>
      tidyr::pivot_wider(names_from = group, values_from = weight)
    r <- px_all |> dplyr::filter(date %in% c(a, b), cat_id %in% w$cat_id) |>
      tidyr::pivot_wider(names_from = date, values_from = index)
    names(r) <- c("cat_id", "pa", "pb")
    z <- dplyr::inner_join(w, r, by = "cat_id") |> dplyr::mutate(rr = pb / pa - 1)
    rbar <- sum(z$all_cu * z$rr)
    Ibar <- (lev(gF, a) + lev(gN, a)) / 2
    z$contrib <- 100 * Ibar * (z[[gF]] - z[[gN]]) * (z$rr - rbar)
    z$contrib_raw <- 100 * Ibar * (z[[gF]] - z[[gN]]) * z$rr
    # Laspeyres check: link inflation from weights equals the index ratio.
    chk <- c(chk, abs(sum(z[[gF]] * z$rr) - (lev(gF, b) / lev(gF, a) - 1)))
    out <- dplyr::bind_rows(out, dplyr::transmute(z, cat_id, link = k, contrib, contrib_raw,
                                                   dw = 100 * (.data[[gF]] - .data[[gN]])))
  }
  gap <- 100 * (lev(gF, d1) - lev(gN, d1))
  byc <- out |> dplyr::summarise(contrib = sum(contrib), contrib_raw = sum(contrib_raw),
                                 mean_dw = mean(dw), .by = cat_id)
  pr <- px_all |> dplyr::filter(date %in% c(d0, d1), cat_id %in% byc$cat_id) |>
    tidyr::pivot_wider(names_from = date, values_from = index)
  names(pr) <- c("cat_id", "p0", "p1")
  allcu <- 100 * (ix$index[ix$group == "all_cu" & ix$date == d1] / ix$index[ix$group == "all_cu" & ix$date == d0] - 1)
  byc |> dplyr::left_join(pr, by = "cat_id") |>
    dplyr::mutate(price_chg = 100 * (p1 / p0 - 1), rel_chg = price_chg - allcu) |>
    dplyr::select(-p0, -p1) |>
    dplyr::mutate(basket = basket, from = d0, to = d1, gap = gap,
                  residual = gap - sum(contrib), allcu_chg = allcu,
                  max_link_check = max(chk), block = BLOCK(cat_id)) |>
    dplyr::left_join(labs_x, by = "cat_id")
}

WINDOWS <- list(
  list(b = "pm_oer_all_in", d0 = "2019-12-01", d1 = "2026-07-01", lab = "2019-2026, CPI concept (headline)"),
  list(b = "pm_oer_all_in", d0 = "2014-12-01", d1 = "2019-12-01", lab = "2014-2019, CPI concept"),
  list(b = "pm_ex_shelter", d0 = "2014-12-01", d1 = "2019-12-01", lab = "2014-2019, ex-shelter"),
  list(b = "pm_ex_shelter", d0 = "2019-12-01", d1 = "2026-07-01", lab = "2019-2026, ex-shelter"),
  list(b = "ex_shelter_long", d0 = "2010-12-01", d1 = "2019-12-01", lab = "2010-2019, ex-shelter (long panel)"))
dec <- dplyr::bind_rows(lapply(WINDOWS, function(w)
  decomp_window(w$b, as.Date(w$d0), as.Date(w$d1)) |> dplyr::mutate(window = w$lab)))
readr::write_csv(dec, file.path(DIR_TAB, "t32_relative_contrib.csv"))

say("## 1. Relative-price decomposition of the cumulative family gap")
say("   contribution_i = (w_family - w_single) x (price change_i - all-CU change), summed over links")
for (w in unique(dec$window)) {
  z <- dec[dec$window == w, ]
  say(sprintf("   [%s]  gap %+.2f pp = sum of contributions %+.2f + compounding residual %+.3f  (all-CU %+.1f%%; Laspeyres link check %.1e)",
              w, z$gap[1], sum(z$contrib), z$residual[1], z$allcu_chg[1], z$max_link_check[1]))
  zz <- z |> dplyr::arrange(dplyr::desc(abs(contrib))) |> utils::head(9)
  for (i in seq_len(nrow(zz))) {
    say(sprintf("     %-40s share gap %+5.2f pp  price %+6.1f%% (vs avg %+6.1f)  contrib %+.3f  [raw form %+.3f]",
                substr(zz$cat_label[i], 1, 40), zz$mean_dw[i], zz$price_chg[i], zz$rel_chg[i],
                zz$contrib[i], zz$contrib_raw[i]))
  }
}
blocks <- dec |> dplyr::summarise(contrib = sum(contrib), .by = c(window, basket, from, to, block, gap))
readr::write_csv(blocks, file.path(DIR_TAB, "t33_contrib_blocks.csv"))
say("")
say("   By block:")
for (w in unique(blocks$window)) {
  z <- blocks[blocks$window == w, ] |> dplyr::arrange(contrib)
  say("   [", w, "] ", paste(sprintf("%s %+.2f", z$block, z$contrib), collapse = "; "))
}
say("")

# ===========================================================================
# 2. Childcare against other services
# ===========================================================================
SVC <- c(SEEB03 = "Day care and preschool", SAS = "All services",
         SASL2RS = "Services less rent of shelter", SA0 = "All items", SAC = "Goods",
         SEHA = "Rent", SEFV = "Food away from home", SEGC = "Personal care services",
         SEMD02 = "Nursing homes and adult day care", SERB02 = "Pet services incl. veterinary",
         SEEB01 = "College tuition", SEEB02 = "K-12 tuition")
PER <- list(c("2000-12-01", "2010-12-01", "2000s"), c("2010-12-01", "2019-12-01", "2010s"),
            c("2019-12-01", format(max(prices$date)), "2019-2026"))
rates <- NULL
for (p in PER) for (code in names(SVC)) {
  s <- cn[cn$item_code == code & !is.na(cn$value), ]
  v0 <- s$value[s$date == as.Date(p[1])]; v1 <- s$value[s$date == as.Date(p[2])]
  if (!length(v0) || !length(v1)) next
  yrs <- as.numeric(as.Date(p[2]) - as.Date(p[1])) / 365.25
  rates <- dplyr::bind_rows(rates, tibble::tibble(item_code = code, series = SVC[[code]], period = p[3],
    cum = 100 * (v1 / v0 - 1), annualized = 100 * ((v1 / v0)^(1 / yrs) - 1)))
}
readr::write_csv(rates, file.path(DIR_TAB, "t34_services_rates.csv"))
say("## 2. Childcare prices against other services (annualized CPI change)")
rw <- rates |> dplyr::select(series, period, annualized) |>
  tidyr::pivot_wider(names_from = period, values_from = annualized)
for (i in seq_len(nrow(rw))) say(sprintf("   %-34s %s", rw$series[i],
  paste(sprintf("%s %5.2f%%", names(rw)[-1], unlist(rw[i, -1])), collapse = "   ")))
say("")

# ===========================================================================
# 3. Childcare spending levels
# ===========================================================================
lev06 <- cex |> dplyr::filter(category_code == "EXPEND", demographics_code == "LB06",
                              characteristics_code %in% c("01", "04", "05", "06", "07", "09", "10"),
                              item_code %in% c("HHPERSRV", "670320", "TOTALEXP", "INSPENSN", "CASHCONT"),
                              year == 2024L) |>
  dplyr::select(characteristics_code, characteristics_text, item_code, value) |>
  tidyr::pivot_wider(names_from = item_code, values_from = value) |>
  dplyr::mutate(consumption = TOTALEXP - INSPENSN - CASHCONT,
                childcare_share = 100 * `670320` / consumption,
                perssrv_share = 100 * HHPERSRV / consumption)
readr::write_csv(lev06, file.path(DIR_TAB, "t36_childcare_levels.csv"))
say("## 3. Childcare spending, 2024 (CE item 670320; mean over ALL CUs in the group, users and non-users)")
for (i in seq_len(nrow(lev06))) say(sprintf("   %-50s childcare $%5.0f  = %4.1f%% of consumption",
  substr(lev06$characteristics_text[i], 1, 50), lev06$`670320`[i], lev06$childcare_share[i]))
say("   Means include households that pay nothing for care, so the share for a family")
say("   that pays for full-time care is several times larger. The CE tables do not")
say("   publish the conditional mean.")
say("")

# ===========================================================================
# 4. Budget shares by household size, owners at rental value
# ===========================================================================
SIZES <- c("02" = "1 person", "04" = "2 people", "05" = "3 people", "06" = "4 people", "07" = "5 or more")
d5 <- cex_expend_panel(cex, tax, "LB05", names(SIZES), verbose = FALSE) |>
  dplyr::filter(year == 2024L) |>
  dplyr::left_join(dplyr::select(tax, cat_id, item_code = cex_item_code), by = "item_code")
rv5 <- ce_se_panel("LB05") |> dplyr::filter(year == 2024L, cat_id == "RENTVAL") |>
  dplyr::transmute(characteristics_code, rentval = 12 * mean)
cu5 <- cex |> dplyr::filter(category_code == "CUCHARS", demographics_code == "LB05", year == 2024L,
                            item_code == "980010", characteristics_code %in% names(SIZES)) |>
  dplyr::select(characteristics_code, people = value)
size <- d5 |> dplyr::group_by(characteristics_code) |>
  dplyr::summarise(
    rent = sum(value[cat_id %in% "07"]), lodging = sum(value[cat_id %in% "08"]),
    food_home = sum(value[cat_id %in% "01"]), vehicles = sum(value[cat_id %in% c("23", "24", "25")]),
    childcare = sum(value[cat_id %in% "14"]), education = sum(value[cat_id %in% "37"]),
    base = sum(value[cat_id %in% setdiff(tax$cat_id, c("04", "05", "06", "40", "41"))]), .groups = "drop") |>
  dplyr::left_join(rv5, by = "characteristics_code") |>
  dplyr::left_join(cu5, by = "characteristics_code") |>
  dplyr::mutate(cons = base + rentval, size = SIZES[characteristics_code],
                shelter_share = 100 * (rent + rentval + lodging) / cons,
                food_home_share = 100 * food_home / cons, vehicle_share = 100 * vehicles / cons,
                childcare_share = 100 * childcare / cons, education_share = 100 * education / cons,
                shelter_dollars = rent + rentval + lodging,
                shelter_per_person = shelter_dollars / people)
readr::write_csv(size, file.path(DIR_TAB, "t35_size_shares.csv"))
say("## 4. Budget shares by household size, 2024 (consumption with owners' housing at rental value)")
for (i in seq_len(nrow(size))) {
  s <- size[i, ]
  say(sprintf("   %-10s shelter %4.1f%% ($%6.0f, $%6.0f per person)  food at home %4.1f%%  vehicles/gas %4.1f%%  childcare %3.1f%%  education %3.1f%%",
              s$size, s$shelter_share, s$shelter_dollars, s$shelter_per_person, s$food_home_share,
              s$vehicle_share, s$childcare_share, s$education_share))
}
say("")

# ===========================================================================
# 5. Figures (C3 palette: soft green accent, warm navy anchor)
# ===========================================================================
NAVY <- "#2c3254"; GREEN <- "#70ad8f"; PURPLE <- "#472b51"; GOLD <- "#ebc382"; GREY <- "#caccd4"
theme_fii <- function(bs = 11) {
  ggplot2::theme_minimal(base_size = bs) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey88"),
      plot.title = ggplot2::element_text(face = "bold", size = bs + 3, colour = "#232849"),
      plot.subtitle = ggplot2::element_text(colour = "#3c4164", size = bs),
      plot.caption = ggplot2::element_text(colour = "grey45", size = bs - 2, hjust = 0),
      legend.position = "top", legend.title = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(face = "bold"))
}
SRC <- paste0("Source: author's calculation from BLS CEX and CPI-U. Vintage ", substr(VINTAGE, 1, 10), ".")

h <- dec |> dplyr::filter(window == "2019-2026, CPI concept (headline)")
lab_ids <- h |> dplyr::arrange(dplyr::desc(abs(contrib))) |> utils::head(9) |> dplyr::pull(cat_id)
lab_ids <- union(lab_ids, "14")
p15 <- ggplot2::ggplot(h, ggplot2::aes(mean_dw, rel_chg)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey55", linewidth = 0.4) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey55", linewidth = 0.4) +
  ggplot2::geom_point(ggplot2::aes(size = abs(contrib), colour = contrib > 0), alpha = 0.85) +
  ggrepel::geom_text_repel(data = dplyr::filter(h, cat_id %in% lab_ids),
    ggplot2::aes(label = substr(cat_label, 1, 32)), size = 3.2, seed = 3, colour = "#3c4164",
    min.segment.length = 0) +
  ggplot2::scale_colour_manual(values = c(`TRUE` = GREEN, `FALSE` = NAVY),
    labels = c(`TRUE` = "Raises family inflation relative to single", `FALSE` = "Lowers it")) +
  ggplot2::scale_size_area(max_size = 12, guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "A category moves the family gap only if families overweight it AND its price outran average",
    subtitle = paste0("Horizontal: family budget share minus single share, 2020-2026 mean. Vertical: category price ",
      "change minus all-household change, Dec 2019 to Jul 2026.\nBubble size: contribution to the cumulative gap. ",
      "Childcare sits on the zero line: families buy far more of it, but its price rose at the average rate."),
    x = "Family share minus single share (pp)", y = "Price change relative to average (pp)", caption = SRC) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f15_share_vs_relprice.png"), p15, width = 12, height = 7, dpi = 200, bg = "white")

bw <- blocks |> dplyr::filter(window %in% c("2019-2026, CPI concept (headline)", "2014-2019, CPI concept")) |>
  dplyr::mutate(window = factor(window, levels = c("2014-2019, CPI concept", "2019-2026, CPI concept (headline)")),
                block = forcats::fct_reorder(block, contrib, .fun = sum))
p16 <- ggplot2::ggplot(bw, ggplot2::aes(contrib, block, fill = contrib > 0)) +
  ggplot2::geom_col(width = 0.7) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey25", linewidth = 0.4) +
  ggplot2::facet_wrap(~window, ncol = 2) +
  ggplot2::scale_fill_manual(values = c(`TRUE` = GREEN, `FALSE` = NAVY), guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "Where the family gap comes from, in normal times and in the surge",
    subtitle = "Contribution to the cumulative family-minus-single gap, relative-price form. Totals: -1.05 pp (2014-2019), -0.69 pp (2019-2026).",
    x = "Contribution (pp)", y = NULL, caption = SRC) + theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f16_contrib_blocks.png"), p16, width = 12, height = 5.5, dpi = 200, bg = "white")

rf <- rates |> dplyr::filter(item_code %in% c("SEEB03", "SASL2RS", "SAS", "SA0", "SAC")) |>
  dplyr::mutate(series = factor(series, levels = SVC[c("SEEB03", "SAS", "SASL2RS", "SA0", "SAC")]),
                period = factor(period, levels = c("2000s", "2010s", "2019-2026")))
p17 <- ggplot2::ggplot(rf, ggplot2::aes(period, annualized, fill = series)) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.75) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.1f", annualized)),
                     position = ggplot2::position_dodge(width = 0.8), vjust = -0.4, size = 3.1, colour = "#3c4164") +
  ggplot2::scale_fill_manual(values = c(GREEN, NAVY, "#7d86a8", GOLD, GREY)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%"), expand = ggplot2::expansion(mult = c(0, 0.1))) +
  ggplot2::labs(title = "Childcare prices rise like other services",
    subtitle = "Annualized CPI-U change. 2000s: Dec 2000 to Dec 2010. 2010s: Dec 2010 to Dec 2019. 2019-2026: Dec 2019 to Jul 2026.",
    x = NULL, y = "Annualized change", caption = SRC) + theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f17_childcare_vs_services.png"), p17, width = 11, height = 5.5, dpi = 200, bg = "white")

sz <- size |> dplyr::select(size, Shelter = shelter_share, `Food at home` = food_home_share,
                            `Vehicles and gas` = vehicle_share) |>
  tidyr::pivot_longer(-size) |>
  dplyr::mutate(size = factor(size, levels = SIZES), name = factor(name, levels = c("Shelter", "Food at home", "Vehicles and gas")))
p18 <- ggplot2::ggplot(sz, ggplot2::aes(size, value, fill = name)) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.75) +
  ggplot2::geom_text(ggplot2::aes(label = sprintf("%.0f%%", value)),
                     position = ggplot2::position_dodge(width = 0.8), vjust = -0.4, size = 3.2, colour = "#3c4164") +
  ggplot2::scale_fill_manual(values = c(NAVY, GREEN, GOLD)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%"), expand = ggplot2::expansion(mult = c(0, 0.1))) +
  ggplot2::labs(title = "Housing has economies of scale",
    subtitle = "Share of 2024 consumption by household size. Shelter is rent, lodging and the rental value of owned homes.",
    x = "Household size", y = "Share of consumption", caption = SRC) + theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f18_shares_by_size.png"), p18, width = 10, height = 5.5, dpi = 200, bg = "white")

message("\nValidation log: ", LOG)
