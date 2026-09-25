# ---------------------------------------------------------------------------
# 11_review_checks.R   ---  second methods review, checks 1-6 and 8
#                          (decisions_log D-35 to D-40)
#
# Holds the D-30 headline machinery fixed and puts eight questions to it.
# NOTHING HERE CHANGES THE HEADLINE: every variant is reported beside it, and
# section 3 stops the script unless the headline is reproduced exactly.
#
#   1. FAMILY DEFINITION. LB06 code 04 includes married couples whose oldest
#      child is 18 or over (code 07). Rebuild with children under 18 only:
#      05 + 06 + 09.
#   2. COMPARATORS. Families against single/other CUs, all CUs, married
#      couples without children, and all CUs outside the family group.
#   3. WEIGHT TIMING. Laspeyres with one-year and contemporaneous weights, and
#      a Tornqvist on adjacent CE years, against the two-year-lagged headline.
#   4. CHILDCARE. Real childcare items in place of the HHPERSRV proxy.
#   5. FINANCE CHARGES. Vehicle finance charges, then every separable finance
#      charge, removed from the basket (interest is out of CPI scope).
#   6. TESTS. One test per cumulative window; SEs on category contributions.
#   8. TARGETED DEEP CROSSWALK. New vs used vehicles, vehicle cost pieces,
#      tuition by level, each with its own CPI price.
# (Check 7, the BLS R-CPI-I benchmark, is 12_external_benchmarks.R.)
#
# Sampling error here is built from the seven disjoint LB06 cells (D-36), so
# gaps between overlapping groups carry the right covariance.
#
# Run from the project root after 06:  Rscript R/11_review_checks.R
#
# Outputs
#   output/tables/t00i_review_checks.txt   validation log
#   output/tables/t37_family_definitions.csv
#   output/tables/t38_comparators.csv
#   output/tables/t39_weight_timing.csv
#   output/tables/t40_deep_variants.csv
#   output/tables/t41_window_tests.csv
#   output/tables/t42_contrib_se.csv
#   output/tables/t43_se_diagnostics.csv
#   output/tables/t44_childcare_weights.csv
#   data/derived/review_index.csv          variant x basket x group x month
#   output/figures/f19_definitions_comparators.png
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")
source("R/functions/index_build.R")
source("R/functions/ce_tables.R")
source("R/functions/price_panel.R")
source("R/functions/review_checks.R")

LOG <- file.path(DIR_TAB, "t00i_review_checks.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }
say("# Review checks log (11_review_checks.R)"); say("# built_at: ", VINTAGE); say("")

tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
xw <- readr::read_csv(file.path(DIR_XWALK, "cex_to_cpi.csv"),
                      col_types = readr::cols(.default = readr::col_character())) |>
  dplyr::filter(!is.na(cpi_item_code))
prices0 <- readr::read_csv(file.path(DIR_DER, "cpi_category_index.csv"), show_col_types = FALSE,
                           col_types = readr::cols(cat_id = "c"))
fam_ref <- readr::read_csv(file.path(DIR_DER, "family_index.csv"), show_col_types = FALSE)
cpi <- readRDS(file.path(DIR_RAW, "cpi_raw.rds"))
cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))

LAG <- 2L
D0 <- as.Date("2019-12-01")
LASTD <- max(prices0$date)
Y0 <- 2010L                                   # deep items start here (D-11)
mapped  <- sort(unique(prices0$cat_id))
SHELTER <- tax$cat_id[tax$major == "Housing"]
MEDICAL <- tax$cat_id[tax$major == "Health"]

CODES <- c("01", LB06_CELLS, "04")
GL <- c("01" = "All consumer units", "03" = "Married couple, no children",
        "04" = "Married couple with children (any age)", "05" = "Married, oldest child under 6",
        "06" = "Married, oldest child 6-17", "07" = "Married, oldest child 18+",
        "08" = "Other married couple CUs", "09" = "One parent, child under 18",
        "10" = "Single person and other CUs",
        F1 = "Families with children, headline (04 + 09)",
        K1 = "Families with children under 18 (05 + 06 + 09)",
        RF = "All CUs except 04 + 09", RK = "All CUs except 05 + 06 + 09")
# Groups whose SHARES come from pooling published groups (as 02 pools F1).
SHARE_SRC <- list(F1 = c("04", "09"), K1 = c("05", "06", "09"),
                  RF = c("03", "08", "10"), RK = c("03", "07", "08", "10"))
# Disjoint cells behind every group, for sampling error (D-36).
CELLS_OF <- c(list("01" = LB06_CELLS, "04" = c("05", "06", "07")),
              stats::setNames(as.list(LB06_CELLS), LB06_CELLS),
              list(F1 = c("05", "06", "07", "09"), K1 = c("05", "06", "09"),
                   RF = c("03", "08", "10"), RK = c("03", "07", "08", "10")))
GROUPS <- names(CELLS_OF)
REF_NAME <- c(F1 = "families_kids", "10" = "single_other", "01" = "all_cu",
              "03" = "married_nokids", "04" = "married_kids", "09" = "single_parent")

# ===========================================================================
# 1. CEX flat files: every LB06 cell, taxonomy categories and deep pieces
# ===========================================================================
say("## 1. CEX panel (LB06, ", Y0, "-2024)")
d <- cex |> dplyr::filter(category_code == "EXPEND", demographics_code == "LB06",
                          characteristics_code %in% CODES) |>
  dplyr::select(year, characteristics_code, item_code, value)
rm_msgs <- utils::capture.output(d <- cex_repair_all_cu(cex, d, fallback_dim = "LB04"), type = "message")
for (m in rm_msgs) say(m)
d <- cex_apply_splices(d, tax, verbose = FALSE) |> dplyr::filter(year >= Y0)
gm <- utils::capture.output(cex_assert_no_interior_gaps(d, label = "LB06 all cells"), type = "message")
for (m in gm) say(m)
am <- utils::capture.output(
  cex_assert_additive(dplyr::filter(d, item_code %in% c(tax$cex_item_code, "TOTALEXP")), tax,
                      label = "LB06 all cells"), type = "message")
for (m in am) say(m)

dp <- deep_piece_dollars(d)
for (i in seq_len(nrow(dp$log))) {
  say(sprintf("  pieces of %s (%s): %d cells, %d suppressed sub-item values counted as zero, min residual $%.0f",
              dp$log$parent[i], DEEP_PARENTS[[dp$log$parent[i]]], dp$log$cells[i],
              dp$log$suppressed_items[i], dp$log$min_residual[i]))
}
# Long piece frame: split parents contribute their pieces, every other
# category contributes itself.
plain <- d |> dplyr::inner_join(dplyr::select(tax, cat_id, item_code = cex_item_code), by = "item_code") |>
  dplyr::filter(!cat_id %in% names(DEEP_PARENTS)) |>
  dplyr::transmute(year, characteristics_code, piece = cat_id, parent = cat_id, dollars = value)
if (anyNA(plain$dollars)) stop("Suppressed taxonomy category in the LB06 cells.", call. = FALSE)
pieces <- dplyr::bind_rows(plain, dp$pieces)
chk_p <- pieces |> dplyr::summarise(s = sum(dollars), .by = c(year, characteristics_code, parent)) |>
  dplyr::inner_join(d |> dplyr::inner_join(dplyr::select(tax, parent = cat_id, item_code = cex_item_code),
                                           by = "item_code") |>
                      dplyr::select(year, characteristics_code, parent, v = value),
                    by = c("year", "characteristics_code", "parent"))
say(sprintf("  pieces re-add to published categories: %d cells, max |diff| $%.2f",
            nrow(chk_p), max(abs(chk_p$s - chk_p$v))))
if (max(abs(chk_p$s - chk_p$v)) > 3.5) stop("Pieces do not add to parents.", call. = FALSE)
totexp_c <- d |> dplyr::filter(item_code == "TOTALEXP") |>
  dplyr::select(year, characteristics_code, totalexp = value)

cu <- cex |> dplyr::filter(category_code == "CUCHARS", item_code == "CONSUNIT",
                           demographics_code == "LB06", characteristics_code %in% CODES) |>
  dplyr::select(year, characteristics_code, n_cu = value)
cu01 <- cex |> dplyr::filter(category_code == "CUCHARS", item_code == "CONSUNIT",
                             demographics_code == "LB04", characteristics_code == "01") |>
  dplyr::select(year, characteristics_code, n_cu = value)
cu <- dplyr::bind_rows(cu, dplyr::anti_join(cu01, cu, by = c("year", "characteristics_code"))) |>
  dplyr::filter(year >= Y0)
cs <- cu |> dplyr::filter(characteristics_code %in% LB06_CELLS) |>
  dplyr::summarise(cells = sum(n_cu), .by = year) |>
  dplyr::inner_join(dplyr::filter(cu, characteristics_code == "01"), by = "year")
say(sprintf("  CU counts: the seven cells sum to all CUs within %.2f%% in every year",
            100 * max(abs(cs$cells / cs$n_cu - 1))))
if (max(abs(cs$cells / cs$n_cu - 1)) > 0.005) stop("LB06 cells do not partition all CUs.", call. = FALSE)

# Pool published groups into the analysis groups, CU-weighted (D-07).
grp_pieces <- dplyr::filter(pieces, characteristics_code %in% c("01", "03", "04", LB06_CELLS)) |>
  dplyr::rename(group = characteristics_code)
grp_tot <- dplyr::rename(totexp_c, group = characteristics_code)
for (g in names(SHARE_SRC)) {
  src <- SHARE_SRC[[g]]
  pp <- pieces |> dplyr::filter(characteristics_code %in% src) |>
    dplyr::inner_join(cu, by = c("year", "characteristics_code")) |>
    dplyr::summarise(dollars = sum(dollars * n_cu) / sum(n_cu), .by = c(year, piece, parent)) |>
    dplyr::mutate(group = g)
  tt <- totexp_c |> dplyr::filter(characteristics_code %in% src) |>
    dplyr::inner_join(cu, by = c("year", "characteristics_code")) |>
    dplyr::summarise(totalexp = sum(totalexp * n_cu) / sum(n_cu), .by = year) |>
    dplyr::mutate(group = g)
  grp_pieces <- dplyr::bind_rows(grp_pieces, pp); grp_tot <- dplyr::bind_rows(grp_tot, tt)
}
grp_pieces <- dplyr::distinct(grp_pieces)
grp_tot <- dplyr::distinct(grp_tot)

# The headline family group must match 02's pooled dollars exactly.
sh02 <- readr::read_csv(file.path(DIR_DER, "cex_shares_long.csv"), show_col_types = FALSE,
                        col_types = readr::cols(cat_id = "c", characteristics_code = "c")) |>
  dplyr::filter(group == "families_kids", year >= Y0)
mm <- grp_pieces |> dplyr::filter(group == "F1") |>
  dplyr::summarise(dollars = sum(dollars), .by = c(year, parent)) |>
  dplyr::inner_join(dplyr::select(sh02, year, parent = cat_id, d02 = dollars), by = c("year", "parent"))
say(sprintf("  F1 pooled dollars vs 02 (families_kids): %d cells, max |diff| $%.4f", nrow(mm),
            max(abs(mm$dollars - mm$d02))))
if (max(abs(mm$dollars - mm$d02)) > 1e-6) stop("F1 pooling does not reproduce 02.", call. = FALSE)
say("")

# ===========================================================================
# 2. CE workbooks: sampling error for every cell, rental value of owned home
# ===========================================================================
say("## 2. CE workbooks (2012-2024)")
CE_COL_MAP$LB06 <- c(CE_COL_MAP$LB06, "05" = "^Oldest child under 6", "06" = "^Oldest child 6 to 17",
                     "07" = "^Oldest child 18", "08" = "^Other (married couple|husband and wife)")
CE_ITEM_MAP <- dplyr::bind_rows(CE_ITEM_MAP, CE_ITEM_MAP_DEEP)
ce <- ce_se_panel("LB06")
ce01 <- ce_se_panel("LB01") |> dplyr::filter(characteristics_code == "01") |> dplyr::mutate(dim = "LB06")
ce <- dplyr::bind_rows(ce, dplyr::anti_join(ce01, ce, by = c("year", "characteristics_code", "cat_id")))
cov_ce <- ce |> dplyr::filter(cat_id == "TOTALEXP", !is.na(mean)) |>
  dplyr::summarise(years = paste(range(year), collapse = "-"), n = dplyr::n(), .by = characteristics_code)
say("  workbook columns found: ", paste(sprintf("%s (%s, %d yrs)", cov_ce$characteristics_code,
                                                  cov_ce$years, cov_ce$n), collapse = "; "))
fd <- dplyr::bind_rows(
  plain |> dplyr::rename(cat_id = piece),
  pieces |> dplyr::filter(piece %in% DEEP_OWN_SE) |> dplyr::rename(cat_id = piece),
  pieces |> dplyr::filter(parent %in% names(DEEP_PARENTS)) |>
    dplyr::summarise(dollars = sum(dollars), .by = c(year, characteristics_code, parent)) |>
    dplyr::mutate(cat_id = parent))
rec <- ce |> dplyr::filter(!is.na(mean)) |>
  dplyr::inner_join(dplyr::select(fd, year, characteristics_code, cat_id, dollars),
                    by = c("year", "characteristics_code", "cat_id")) |>
  dplyr::mutate(dd = mean - dollars, rel = dd / pmax(dollars, 1))
say(sprintf("  workbook means vs flat files: %d cells, %d exact, max |diff| $%.0f",
            nrow(rec), sum(abs(rec$dd) < 0.5), max(abs(rec$dd))))
bad <- rec |> dplyr::filter(abs(dd) > 50 & abs(rel) > 0.02)
if (nrow(bad)) {
  print(as.data.frame(utils::head(bad, 20)))
  stop("CE workbook means disagree with the flat files.", call. = FALSE)
}

# RSE panel by CELL. Suppressed cells carry the nearest year's RSE (as 06).
rse_long <- ce |> dplyr::filter(characteristics_code %in% LB06_CELLS, !cat_id %in% c("NCU", "TOTALEXP")) |>
  dplyr::mutate(cat_id = dplyr::recode(cat_id, RENTVAL = "H0")) |>
  dplyr::select(cell = characteristics_code, year, cat_id, rse) |>
  tidyr::complete(cell, year, cat_id) |>
  dplyr::arrange(cell, cat_id, year) |>
  dplyr::mutate(was_na = is.na(rse)) |>
  dplyr::group_by(cell, cat_id) |> tidyr::fill(rse, .direction = "downup") |> dplyr::ungroup()
say(sprintf("  cell RSE panel: %d cells, %d carried from an adjacent year, %d never published",
            nrow(rse_long), sum(rse_long$was_na & !is.na(rse_long$rse)), sum(is.na(rse_long$rse))))
rse_long <- dplyr::select(rse_long, -was_na)

# Rental value of owned home. F1 exactly as 06 (ce_pool of 04 and 09).
rv_code <- ce |> dplyr::filter(cat_id == "RENTVAL", characteristics_code %in% c("01", "03", "04", LB06_CELLS)) |>
  dplyr::transmute(group = characteristics_code, year, rentval_annual = 12 * mean)
rv_pool <- dplyr::bind_rows(lapply(names(SHARE_SRC), function(g)
  ce_pool(ce, SHARE_SRC[[g]], g) |> dplyr::filter(cat_id == "RENTVAL") |>
    dplyr::transmute(group = g, year, rentval_annual = 12 * mean)))
rentval <- dplyr::bind_rows(rv_code, rv_pool)
if (anyNA(rentval$rentval_annual)) stop("Missing rental value of owned home.", call. = FALSE)
say("")

# ===========================================================================
# 3. Prices, variants, indices; reproduce the headline exactly
# ===========================================================================
say("## 3. Prices and variants")
nat <- cpi[cpi$area_code == "0000" & cpi$periodicity_code == "R" & cpi$seasonal == "U" &
             cpi$freq == "monthly" & !cpi$is_average & !is.na(cpi$value) & cpi$date <= LASTD, ]
pub_u <- sort(unique(nat$date[nat$item_code == "SA0"]))
ri_obs <- nat |> dplyr::select(item_code, date, ri = weight)
chk <- build_category_prices(dplyr::transmute(nat, item_code, date, idx = value), ri_obs, xw, pub_u) |>
  dplyr::inner_join(dplyr::select(prices0, cat_id, date, i0 = index), by = c("cat_id", "date"))
say(sprintf("  price_panel.R rebuild of 05's category panel: max |diff| %.2e", max(abs(chk$index - chk$i0))))
if (max(abs(chk$index - chk$i0)) > 1e-8) stop("price_panel.R does not reproduce 05.", call. = FALSE)
# One call per piece: 23O shares SETA01/SETA02 with 23N/23U.
px_deep <- dplyr::bind_rows(lapply(split(DEEP_XW, DEEP_XW$cat_id), function(m)
  build_category_prices(dplyr::transmute(nat, item_code, date, idx = value), ri_obs, m, pub_u)))
o23 <- dplyr::inner_join(dplyr::filter(px_deep, cat_id == "23O"), dplyr::filter(prices0, cat_id == "23"), by = "date")
say(sprintf("  23O (other vehicles) is priced as the original vehicle composite: max |diff| %.2e", max(abs(o23$index.x - o23$index.y))))
if (max(abs(o23$index.x - o23$index.y)) > 1e-8) stop("23O price differs from category 23.", call. = FALSE)
ri_cat <- ri_by_category(cpi, xw, fill = TRUE)
m0 <- build_index_ri(dplyr::select(prices0, cat_id, date, index), ri_cat, MEDICAL) |>
  dplyr::transmute(cat_id = "M0", date, index)
cn <- cpi_national(cpi)
h0 <- cn |> dplyr::filter(item_code == "SEHC", !is.na(value), date %in% unique(prices0$date)) |>
  dplyr::transmute(cat_id = "H0", date, index = value)
px_all <- dplyr::bind_rows(dplyr::select(prices0, cat_id, date, index), px_deep, m0, h0)
dd_px <- px_deep |> dplyr::summarise(first = min(date), last = max(date), .by = cat_id)
say("  deep price series: ", paste(sprintf("%s %s-%s", dd_px$cat_id, format(dd_px$first, "%Y-%m"),
                                            format(dd_px$last, "%Y-%m")), collapse = "; "))

SW0 <- c(fin_veh = FALSE, fin_all = FALSE, cc = FALSE, veh = FALSE, edu = FALSE)
sw <- function(...) { s <- SW0; a <- c(...); s[names(a)] <- a; s }
VARIANTS <- list(
  headline  = SW0,
  fin_veh   = sw(fin_veh = TRUE),
  fin_all   = sw(fin_all = TRUE),
  childcare = sw(cc = TRUE),
  vehicles  = sw(veh = TRUE),
  education = sw(edu = TRUE),
  deep_xw   = sw(cc = TRUE, veh = TRUE, edu = TRUE),
  deep      = sw(fin_all = TRUE, cc = TRUE, veh = TRUE, edu = TRUE))
VLAB <- c(headline = "Headline (D-30)", fin_veh = "Vehicle finance charges removed (5)",
          fin_all = "All separable finance charges removed (5)",
          childcare = "Real childcare items (4)", vehicles = "Vehicles split: new, used, cost pieces (8)",
          education = "Education split by level (8)", deep_xw = "All deep splits, finance kept (4 + 8)",
          deep = "All deep splits, finance removed (4 + 5 + 8)")
BASKETS <- c(oer = "CPI concept, medical pooled (headline)", exsh = "Ex-shelter, medical pooled (co-headline)")

# Category-level dollars for a variant, for any frame keyed by `key`.
variant_dollars <- function(p, s, key) {
  p |> dplyr::mutate(cat_id = piece_price_id(piece, parent, s)) |>
    dplyr::filter(!is.na(cat_id)) |>
    dplyr::summarise(dollars = sum(dollars), .by = dplyr::all_of(c(key, "year", "cat_id")))
}
# Shares with medical pooled and OER added, as 06 builds pm / pmo.
variant_shares <- function(s, basket) {
  x <- variant_dollars(grp_pieces, s, "group") |>
    dplyr::mutate(cat_id = dplyr::if_else(cat_id %in% MEDICAL, "M0", cat_id)) |>
    dplyr::summarise(dollars = sum(dollars), .by = c(group, year, cat_id)) |>
    dplyr::inner_join(grp_tot, by = c("group", "year")) |>
    dplyr::mutate(share = 100 * dollars / totalexp)
  if (basket == "oer") {
    x <- dplyr::bind_rows(dplyr::filter(x, cat_id != "06"),
      rentval |> dplyr::inner_join(grp_tot, by = c("group", "year")) |>
        dplyr::transmute(group, year, cat_id = "H0", dollars = rentval_annual, totalexp,
                         share = 100 * rentval_annual / totalexp)) |>
      dplyr::filter(year %in% unique(rentval$year))
  }
  x
}
basket_cats <- function(ids, basket) {
  ids <- setdiff(ids, c("04", "05", "40", "41", MEDICAL))
  if (basket == "oer") c(setdiff(ids, c("06", "M0", "H0")), "M0", "H0")
  else c(setdiff(ids, c(SHELTER, "M0", "H0")), "M0")
}

IDX <- list(); WTS <- list(); SHR <- list()
key <- function(v, b, g) paste(v, b, g, sep = "|")
for (v in names(VARIANTS)) for (b in names(BASKETS)) {
  sh <- variant_shares(VARIANTS[[v]], b)
  cats <- basket_cats(unique(sh$cat_id), b)
  SHR[[paste(v, b)]] <- sh
  for (g in GROUPS) {
    s <- sh |> dplyr::filter(group == g) |> dplyr::select(cat_id, year, share)
    bi <- build_index(px_all, s, cats, lag_years = LAG, price_update = "full")
    IDX[[key(v, b, g)]] <- bi$index
    WTS[[key(v, b, g)]] <- bi$weights
  }
  say(sprintf("  %-10s %-5s %2d categories  %s to %s", v, b, length(cats),
              format(min(IDX[[key(v, b, "F1")]]$date), "%Y-%m"), format(max(IDX[[key(v, b, "F1")]]$date), "%Y-%m")))
}
ref_b <- c(oer = "pm_oer_all_in", exsh = "pm_ex_shelter")
worst <- 0
for (b in names(ref_b)) for (g in names(REF_NAME)) {
  a <- IDX[[key("headline", b, g)]]
  r <- fam_ref |> dplyr::filter(basket == ref_b[[b]], group == REF_NAME[[g]])
  z <- dplyr::inner_join(a, r, by = "date", suffix = c("", ".ref"))
  if (nrow(z) != nrow(r)) stop("Headline reproduction: month count differs for ", b, " ", g, call. = FALSE)
  worst <- max(worst, abs(z$index - z$index.ref))
}
say(sprintf("  HEADLINE REPRODUCTION: 'headline' variant vs 06 family_index.csv, 2 baskets x %d groups: max |diff| %.2e",
            length(REF_NAME), worst))
if (worst > 1e-6) stop("Headline not reproduced; nothing below would be comparable.", call. = FALSE)
say("")

res_long <- dplyr::bind_rows(lapply(names(IDX), function(k) {
  p <- strsplit(k, "|", fixed = TRUE)[[1]]
  IDX[[k]] |> dplyr::transmute(variant = p[1], basket = p[2], group = p[3], date, index, chg_12m)
}))
write_derived(res_long, "review_index")

# ===========================================================================
# 4. Cell-level phi and RSE per variant (D-36)
# ===========================================================================
cell_pieces <- pieces |> dplyr::filter(characteristics_code %in% LB06_CELLS) |>
  dplyr::rename(cell = characteristics_code)
rv_cell <- rv_code |> dplyr::filter(group %in% LB06_CELLS) |>
  dplyr::transmute(cell = group, year, cat_id = "H0", dollars = rentval_annual)
cu_cell <- cu |> dplyr::filter(characteristics_code %in% LB06_CELLS) |> dplyr::rename(cell = characteristics_code)
PHI <- list(); RSEV <- list()
for (v in names(VARIANTS)) {
  x <- variant_dollars(cell_pieces, VARIANTS[[v]], "cell")
  x <- dplyr::bind_rows(x, x |> dplyr::filter(cat_id %in% MEDICAL) |>
                          dplyr::summarise(dollars = sum(dollars), .by = c(cell, year)) |>
                          dplyr::mutate(cat_id = "M0"), rv_cell) |>
    dplyr::inner_join(cu_cell, by = c("cell", "year")) |>
    dplyr::mutate(nx = n_cu * dollars)
  PHI[[v]] <- stats::setNames(lapply(GROUPS, function(g) {
    x |> dplyr::filter(cell %in% CELLS_OF[[g]]) |>
      dplyr::mutate(phi = if (sum(nx) > 0) nx / sum(nx) else 0 * nx, .by = c(year, cat_id)) |>
      dplyr::select(year, cat_id, cell, phi) |> as.data.frame()
  }), GROUPS)
  ids <- unique(x$cat_id)
  RSEV[[v]] <- tidyr::expand_grid(cell = LB06_CELLS, year = unique(rse_long$year), cat_id = ids) |>
    dplyr::mutate(src = rse_source(cat_id)) |>
    dplyr::left_join(dplyr::rename(rse_long, src = cat_id), by = c("cell", "year", "src")) |>
    dplyr::select(cell, year, cat_id, rse) |> as.data.frame()
}
nb <- sum(is.na(RSEV$deep$rse))
say("## 4. Sampling-error inputs")
say(sprintf("  deep variant: %d cell-category-years without any RSE (only matters if the category has spending)", nb))
say(sprintf("  pieces priced separately but borrowing the parent's RSE: %s",
            paste(setdiff(unique(DEEP_XW$cat_id), DEEP_OWN_SE), collapse = ", ")))

# Diagnostic: published group RSE against the RSE implied by its cells.
diag <- NULL
pubr <- ce |> dplyr::filter(characteristics_code %in% c("01", "04"), cat_id %in% c(tax$cat_id, "M0"), !is.na(rse))
for (g in c("01", "04")) {
  ph <- PHI$headline[[g]]
  z <- ph |> dplyr::inner_join(dplyr::rename(rse_long, rse_c = rse), by = c("cell", "year", "cat_id")) |>
    dplyr::summarise(rse_impl = sqrt(sum((phi * rse_c)^2)), .by = c(year, cat_id)) |>
    dplyr::inner_join(pubr |> dplyr::filter(characteristics_code == g) |> dplyr::select(year, cat_id, rse_pub = rse),
                      by = c("year", "cat_id"))
  diag <- dplyr::bind_rows(diag, z |> dplyr::mutate(group = g))
}
diag_s <- diag |> dplyr::summarise(cells = dplyr::n(), median_ratio = stats::median(rse_impl / rse_pub),
                                   p10 = stats::quantile(rse_impl / rse_pub, 0.1),
                                   p90 = stats::quantile(rse_impl / rse_pub, 0.9), .by = group)
for (i in seq_len(nrow(diag_s))) {
  say(sprintf("  group %s: cell-implied RSE / published RSE, %d category-years: median %.2f (p10 %.2f, p90 %.2f)",
              diag_s$group[i], diag_s$cells[i], diag_s$median_ratio[i], diag_s$p10[i], diag_s$p90[i]))
}
say("")

# ===========================================================================
# 5. Gaps with sampling error
# ===========================================================================
pair_cum <- function(v, b, g1, g2, d0, d1) {
  i1 <- IDX[[key(v, b, g1)]]; i2 <- IDX[[key(v, b, g2)]]
  if (!all(c(d0, d1) %in% i1$date) || !all(c(d0, d1) %in% i2$date)) return(NULL)
  c1 <- 100 * (i1$index[i1$date == d1] / i1$index[i1$date == d0] - 1)
  c2 <- 100 * (i2$index[i2$date == d1] / i2$index[i2$date == d0] - 1)
  lt1 <- link_terms(i1, WTS[[key(v, b, g1)]], px_all, d0, d1, LAG)
  lt2 <- link_terms(i2, WTS[[key(v, b, g2)]], px_all, d0, d1, LAG)
  se <- se_from_D(rbind(group_D(lt1, PHI[[v]][[g1]], 1), group_D(lt2, PHI[[v]][[g2]], -1)), RSEV[[v]])
  m12 <- dplyr::inner_join(dplyr::select(i1, date, a = chg_12m), dplyr::select(i2, date, b = chg_12m), by = "date") |>
    dplyr::filter(!is.na(a), !is.na(b), date > d0, date <= d1)
  gap <- c1 - c2
  tibble::tibble(variant = v, basket = b, g1 = g1, g2 = g2, from = d0, to = d1,
                 cum1 = c1, cum2 = c2, gap = gap,
                 se_indep = se[["se_indep"]], se_persist = se[["se_persist"]], se_bound = se[["se_bound"]],
                 z_indep = gap / se_indep, z_bound = gap / se_bound,
                 p_indep = 2 * stats::pnorm(-abs(gap / se_indep)),
                 p_persist = 2 * stats::pnorm(-abs(gap / se_persist)),
                 p_bound = 2 * stats::pnorm(-abs(gap / se_bound)),
                 mean_gap_12m = if (nrow(m12)) mean(m12$a - m12$b) else NA_real_)
}
fmt_pair <- function(x) sprintf("%-4s-%-4s %-9s %-4s %+6.2f pp  (%5.2f%% vs %5.2f%%)  SE %.2f / %.2f / %.2f  z %+5.1f / %+5.1f",
                                x$g1, x$g2, x$variant, x$basket, x$gap, x$cum1, x$cum2,
                                x$se_indep, x$se_persist, x$se_bound, x$z_indep, x$z_bound)

say("## 5. Check 1: family definition (Dec 2019 to ", format(LASTD, "%b %Y"), ")")
say("   gap, cumulative percent (group vs single/other), SE (independent / persistent / worst-case bound), z (independent / bound)")
t37 <- NULL
for (b in names(BASKETS)) for (g in c("F1", "K1", "04", "05", "06", "07", "09")) {
  x <- pair_cum("headline", b, g, "10", D0, LASTD); t37 <- dplyr::bind_rows(t37, x); say("   ", fmt_pair(x))
}
for (b in names(BASKETS)) { x <- pair_cum("headline", b, "F1", "K1", D0, LASTD); t37 <- dplyr::bind_rows(t37, x); say("   ", fmt_pair(x)) }
leg <- readr::read_csv(file.path(DIR_TAB, "t28_cumulative_gaps.csv"), show_col_types = FALSE) |>
  dplyr::filter(basket == "pm_oer_all_in", pair == "fam", from == D0)
h1 <- t37 |> dplyr::filter(basket == "oer", g1 == "F1", g2 == "10")
say(sprintf("   cross-check vs 06 (group-level RSEs): SE %.3f (06) vs %.3f (cells), independent vintages",
            leg$se_indep, h1$se_indep))
readr::write_csv(t37 |> dplyr::mutate(label1 = GL[g1], label2 = GL[g2]), file.path(DIR_TAB, "t37_family_definitions.csv"))
say("")

say("## 6. Check 2: comparison groups (Dec 2019 to ", format(LASTD, "%b %Y"), ")")
t38 <- NULL
for (v in c("headline", "deep")) for (b in names(BASKETS)) {
  for (fg in c("F1", "K1")) for (cg in c("10", "01", "03", if (fg == "F1") "RF" else "RK")) {
    x <- pair_cum(v, b, fg, cg, D0, LASTD); t38 <- dplyr::bind_rows(t38, x); say("   ", fmt_pair(x))
  }
}
readr::write_csv(t38 |> dplyr::mutate(label1 = GL[g1], label2 = GL[g2]), file.path(DIR_TAB, "t38_comparators.csv"))
say("")

say("## 7. Checks 4, 5, 8: basket variants, families minus single/other (Dec 2019 to ", format(LASTD, "%b %Y"), ")")
t40 <- NULL
for (v in names(VARIANTS)) for (b in names(BASKETS)) for (fg in c("F1", "K1")) {
  x <- pair_cum(v, b, fg, "10", D0, LASTD); t40 <- dplyr::bind_rows(t40, x)
}
for (fg in c("F1", "K1")) for (b in names(BASKETS)) {
  base <- t40$gap[t40$variant == "headline" & t40$basket == b & t40$g1 == fg]
  for (v in names(VARIANTS)) {
    x <- t40[t40$variant == v & t40$basket == b & t40$g1 == fg, ]
    say(sprintf("   %-3s %-4s %-46s gap %+6.2f  (change vs headline %+5.2f)  SE %.2f / %.2f / %.2f",
                fg, b, VLAB[[v]], x$gap, x$gap - base, x$se_indep, x$se_persist, x$se_bound))
  }
}
readr::write_csv(t40 |> dplyr::mutate(variant_label = VLAB[variant]), file.path(DIR_TAB, "t40_deep_variants.csv"))
say("")

say("## 8. Check 6: one test per cumulative window")
WINS <- list(c("2014-12-01", "2019-12-01"), c("2019-12-01", format(LASTD)),
             c("2020-12-01", "2022-12-01"), c("2022-12-01", "2024-12-01"), c("2024-12-01", format(LASTD)))
WPAIRS <- list(c("F1", "10"), c("K1", "10"), c("F1", "01"), c("K1", "01"), c("F1", "03"), c("K1", "03"), c("09", "04"))
t41 <- NULL
for (v in c("headline", "deep")) for (b in names(BASKETS)) for (w in WINS) for (pr in WPAIRS) {
  x <- pair_cum(v, b, pr[1], pr[2], as.Date(w[1]), as.Date(w[2]))
  if (!is.null(x)) t41 <- dplyr::bind_rows(t41, x)
}
readr::write_csv(t41 |> dplyr::mutate(label1 = GL[g1], label2 = GL[g2]), file.path(DIR_TAB, "t41_window_tests.csv"))
for (w in WINS) {
  say(sprintf("   window %s to %s, headline basket:", substr(w[1], 1, 7), substr(w[2], 1, 7)))
  z <- t41 |> dplyr::filter(variant == "headline", basket == "oer", from == as.Date(w[1]))
  for (i in seq_len(nrow(z))) say(sprintf("     %-4s-%-4s %+6.2f pp  SE %.2f / %.2f / %.2f  p %.3f / %.3f / %.3f",
                                          z$g1[i], z$g2[i], z$gap[i], z$se_indep[i], z$se_persist[i], z$se_bound[i],
                                          z$p_indep[i], z$p_persist[i], z$p_bound[i]))
}
say("")

# ===========================================================================
# 6. Contributions with standard errors (check 6)
# ===========================================================================
BLOCK <- function(id) dplyr::case_when(
  id == "07" ~ "Rent",
  id %in% c("H0", "06", "08") ~ "Owners' housing and lodging",
  id %in% c("14", "14C") ~ "Childcare",
  substr(id, 1, 2) == "37" ~ "Education",
  substr(id, 1, 2) %in% c("23", "24", "25", "26") ~ "Vehicles, gas, transport",
  id %in% c("01", "02") ~ "Food",
  id %in% c("09", "10", "11", "12", "13") ~ "Utilities and phone",
  id %in% c("M0", MEDICAL) ~ "Medical",
  id %in% c("03", "38") ~ "Alcohol and tobacco",
  id %in% c("18", "19", "20", "21", "22") ~ "Apparel",
  TRUE ~ "Everything else")
labs_x <- dplyr::bind_rows(dplyr::select(tax, cat_id, cat_label),
  tibble::tibble(cat_id = c("M0", "H0"), cat_label = c("Medical care (pooled)", "Owners' equivalent rent")),
  dplyr::select(DEEP_PIECES, cat_id = piece, cat_label = label))
t42 <- NULL
CW <- list(c("2019-12-01", format(LASTD)), c("2014-12-01", "2019-12-01"),
           c("2020-12-01", "2022-12-01"), c("2022-12-01", "2024-12-01"))
CPAIRS <- list(c("F1", "10"), c("K1", "10"), c("07", "10"), c("F1", "03"), c("K1", "03"), c("09", "04"))
for (v in c("headline", "deep")) for (b in names(BASKETS)) for (pr in CPAIRS) for (w in CW) {
  fg <- pr[1]; ng <- pr[2]
  if ((fg %in% c("07", "09") || ng == "03" || b == "exsh") && w[1] != "2019-12-01") next
  d0 <- as.Date(w[1]); d1 <- as.Date(w[2])
  lt <- lapply(c(fg, ng, "01"), function(g) link_terms(IDX[[key(v, b, g)]], WTS[[key(v, b, g)]], px_all, d0, d1, LAG))
  for (lev in c("block", "category")) {
    bf <- if (lev == "block") BLOCK else identity
    cc <- contrib_with_se(lt[[1]], lt[[2]], lt[[3]], PHI[[v]][[fg]], PHI[[v]][[ng]], PHI[[v]][["01"]],
                          RSEV[[v]], bf)
    cumg <- function(g) { x <- IDX[[key(v, b, g)]]; x$index[x$date == d1] / x$index[x$date == d0] }
    gap <- 100 * (cumg(fg) - cumg(ng))
    t42 <- dplyr::bind_rows(t42, tibble::as_tibble(cc) |>
      dplyr::mutate(variant = v, basket = b, g1 = fg, g2 = ng, from = d0, to = d1, level = lev, gap = gap,
                    residual = gap - sum(cc$contrib)))
  }
}
t42 <- t42 |> dplyr::left_join(dplyr::rename(labs_x, block = cat_id), by = "block") |>
  dplyr::mutate(cat_label = dplyr::coalesce(cat_label, block))
readr::write_csv(t42, file.path(DIR_TAB, "t42_contrib_se.csv"))
say("## 9. Check 6: contributions to the cumulative gap with 95% sampling intervals (independent vintages)")
old_blocks <- readr::read_csv(file.path(DIR_TAB, "t33_contrib_blocks.csv"), show_col_types = FALSE) |>
  dplyr::filter(basket == "pm_oer_all_in", from == D0)
chk_b <- t42 |> dplyr::filter(variant == "headline", basket == "oer", g1 == "F1", g2 == "10", level == "block", from == D0) |>
  dplyr::inner_join(dplyr::select(old_blocks, block, contrib_10 = contrib), by = "block")
say(sprintf("   point estimates vs 10_intuition.R (t33), headline F1: max |diff| %.2e", max(abs(chk_b$contrib - chk_b$contrib_10))))
if (max(abs(chk_b$contrib - chk_b$contrib_10)) > 1e-8) stop("Contribution point estimates differ from t33.", call. = FALSE)
for (v in c("headline", "deep")) for (b in names(BASKETS)) for (pr in CPAIRS) {
  z <- t42 |> dplyr::filter(variant == v, basket == b, g1 == pr[1], g2 == pr[2], level == "block", from == D0) |>
    dplyr::arrange(contrib)
  say(sprintf("   [%s, %s, %s minus %s, Dec 2019-%s] gap %+.2f (residual %+.3f)", v, b, pr[1], pr[2],
              format(LASTD, "%b %Y"), z$gap[1], z$residual[1]))
  for (i in seq_len(nrow(z))) say(sprintf("     %-30s %+6.3f  +/- %.3f   (bound +/- %.3f)",
                                          z$block[i], z$contrib[i], 1.96 * z$se_indep[i], 1.96 * z$se_bound[i]))
}
say("")

# ===========================================================================
# 7. Check 3: weight timing
# ===========================================================================
say("## 10. Check 3: weight timing (Laspeyres lag 2 / 1 / 0, Tornqvist on adjacent CE years)")
TG <- c("F1", "K1", "10", "01", "03")
t39 <- NULL
cumw <- function(ix, d0, d1) if (all(c(d0, d1) %in% ix$date)) 100 * (ix$index[ix$date == d1] / ix$index[ix$date == d0] - 1) else NA_real_
for (v in c("headline", "deep")) for (b in names(BASKETS)) {
  sh <- SHR[[paste(v, b)]]
  cats <- basket_cats(unique(sh$cat_id), b)
  ymax <- max(sh$year)
  for (g in TG) {
    s <- sh |> dplyr::filter(group == g) |> dplyr::select(cat_id, year, share)
    idx <- list(
      lasp_lag2 = IDX[[key(v, b, g)]],
      lasp_lag1 = build_index(dplyr::filter(px_all, date <= as.Date(sprintf("%d-12-01", ymax + 1L))), s, cats, 1L, "full")$index,
      lasp_lag0 = build_index(dplyr::filter(px_all, date <= as.Date(sprintf("%d-12-01", ymax))), s, cats, 0L, "full")$index,
      tornqvist = build_index_tornqvist(px_all, s, cats, extend = FALSE),
      tornqvist_ext = build_index_tornqvist(px_all, s, cats, extend = TRUE))
    for (m in names(idx)) for (w in list(c("2014-12-01", "2019-12-01"), c("2019-12-01", "2024-12-01"),
                                          c("2019-12-01", format(LASTD)))) {
      t39 <- dplyr::bind_rows(t39, tibble::tibble(variant = v, basket = b, group = g, method = m,
        from = as.Date(w[1]), to = as.Date(w[2]), cum = cumw(idx[[m]], as.Date(w[1]), as.Date(w[2]))))
    }
    an <- build_index_tornqvist_annual(px_all, s, cats)
    la <- IDX[[key(v, b, g)]] |> dplyr::mutate(year = as.integer(format(date, "%Y"))) |>
      dplyr::summarise(index = mean(index), n = dplyr::n(), .by = year)
    for (w in list(c(2014L, 2019L), c(2019L, 2024L))) {
      t39 <- dplyr::bind_rows(t39,
        tibble::tibble(variant = v, basket = b, group = g, method = "annual_avg_lasp_lag2",
                       from = as.Date(sprintf("%d-07-01", w[1])), to = as.Date(sprintf("%d-07-01", w[2])),
                       cum = 100 * (la$index[la$year == w[2]] / la$index[la$year == w[1]] - 1)),
        tibble::tibble(variant = v, basket = b, group = g, method = "annual_avg_tornqvist",
                       from = as.Date(sprintf("%d-07-01", w[1])), to = as.Date(sprintf("%d-07-01", w[2])),
                       cum = 100 * (an$index[an$year == w[2]] / an$index[an$year == w[1]] - 1)))
    }
  }
}
readr::write_csv(t39, file.path(DIR_TAB, "t39_weight_timing.csv"))

# Where the methods differ: Dec-to-Dec link gaps by year, and the shelter
# weight each method gives the two groups (headline variant, CPI concept).
SHEL <- c("07", "08", "H0")
t39b <- NULL
sh <- SHR[["headline oer"]]; cats <- basket_cats(unique(sh$cat_id), "oer")
for (g in c("F1", "K1", "10")) {
  s <- sh |> dplyr::filter(group == g) |> dplyr::select(cat_id, year, share)
  l0 <- build_index(dplyr::filter(px_all, date <= as.Date("2024-12-01")), s, cats, 0L, "full")
  tq <- build_index_tornqvist(px_all, s, cats)
  sn <- s |> dplyr::filter(cat_id %in% cats) |> dplyr::mutate(share = share / sum(share), .by = year)
  for (Y in 2015:2024) {
    dd <- as.Date(sprintf(c("%d-12-01", "%d-12-01"), c(Y - 1L, Y)))
    lk <- function(ix) 100 * (ix$index[ix$date == dd[2]] / ix$index[ix$date == dd[1]] - 1)
    wj <- function(w) 100 * sum(w$weight[w$date == as.Date(sprintf("%d-01-01", Y)) & w$cat_id %in% SHEL])
    t39b <- dplyr::bind_rows(t39b, tibble::tibble(group = g, year = Y,
      link_lasp_lag2 = lk(IDX[[key("headline", "oer", g)]]), link_lasp_lag0 = lk(l0$index), link_tornqvist = lk(tq),
      shelter_w_lag2 = wj(WTS[[key("headline", "oer", g)]]), shelter_w_lag0 = wj(l0$weights),
      shelter_w_tornqvist = 100 * (sum(sn$share[sn$year == Y - 1L & sn$cat_id %in% SHEL]) +
                                   sum(sn$share[sn$year == Y & sn$cat_id %in% SHEL])) / 2,
))
  }
}
readr::write_csv(t39b, file.path(DIR_TAB, "t39b_weight_timing_links.csv"))
wl <- t39b |> tidyr::pivot_wider(id_cols = year, names_from = group,
                                 values_from = c(link_lasp_lag2, link_tornqvist, shelter_w_lag2, shelter_w_tornqvist))
say("   Dec-to-Dec link gaps, F1 minus 10 (pp), and shelter weight gap (F1 minus 10, pp of basket):")
for (i in seq_len(nrow(wl))) {
  say(sprintf("     %d   link gap: lag-2 Laspeyres %+5.2f  Tornqvist %+5.2f   shelter weight gap: lag-2 %+5.1f  Tornqvist %+5.1f",
              wl$year[i], wl$link_lasp_lag2_F1[i] - wl$link_lasp_lag2_10[i],
              wl$link_tornqvist_F1[i] - wl$link_tornqvist_10[i],
              wl$shelter_w_lag2_F1[i] - wl$shelter_w_lag2_10[i],
              wl$shelter_w_tornqvist_F1[i] - wl$shelter_w_tornqvist_10[i]))
}
tw <- t39 |> dplyr::select(variant, basket, group, method, from, to, cum) |>
  tidyr::pivot_wider(names_from = group, values_from = cum) |>
  dplyr::mutate(F1_10 = F1 - `10`, K1_10 = K1 - `10`, F1_01 = F1 - `01`, K1_03 = K1 - `03`)
for (v in c("headline", "deep")) for (w in unique(paste(tw$from, tw$to))) {
  z <- tw |> dplyr::filter(variant == v, basket == "oer", paste(from, to) == w, !is.na(F1_10))
  if (!nrow(z)) next
  say(sprintf("   [%s, oer] %s:", v, w))
  for (i in seq_len(nrow(z))) say(sprintf("     %-22s all-CU %6.2f%%   F1-10 %+5.2f   K1-10 %+5.2f   F1-01 %+5.2f   K1-03 %+5.2f",
                                          z$method[i], z$`01`[i], z$F1_10[i], z$K1_10[i], z$F1_01[i], z$K1_03[i]))
}
say("")

# ===========================================================================
# 8. Check 4: childcare weights, proxy against real items
# ===========================================================================
say("## 11. Check 4: childcare cost weight, mean 2020-2026, CPI-concept basket")
t44 <- NULL
for (v in c("headline", "childcare")) for (g in c("F1", "K1", "05", "06", "07", "09", "10", "01")) {
  w <- WTS[[key(v, "oer", g)]] |> dplyr::filter(date >= as.Date("2020-01-01"), cat_id %in% c("14", "14C", "14E")) |>
    dplyr::summarise(w = 100 * mean(weight), .by = cat_id)
  t44 <- dplyr::bind_rows(t44, w |> dplyr::mutate(variant = v, group = g))
}
t44 <- t44 |> dplyr::mutate(label = GL[group])
readr::write_csv(t44, file.path(DIR_TAB, "t44_childcare_weights.csv"))
cw <- t44 |> dplyr::filter(cat_id %in% c("14", "14C")) |> dplyr::select(variant, group, w) |>
  tidyr::pivot_wider(names_from = variant, values_from = w)
for (i in seq_len(nrow(cw))) say(sprintf("   %-3s %-48s proxy (HHPERSRV) %4.2f%%   real childcare %4.2f%%", cw$group[i],
                                         GL[[cw$group[i]]], cw$headline[i], cw$childcare[i]))
rr <- function(v, g) cw[[v]][cw$group == g]
say(sprintf("   families (F1) / single-other ratio: proxy %.1fx, real childcare %.1fx; K1: %.1fx",
            rr("headline", "F1") / rr("headline", "10"), rr("childcare", "F1") / rr("childcare", "10"),
            rr("childcare", "K1") / rr("childcare", "10")))
say("")

# ===========================================================================
# 9. Sampling-error diagnostics table and figure
# ===========================================================================
readr::write_csv(diag, file.path(DIR_TAB, "t43_se_diagnostics.csv"))

NAVY <- "#2c3254"; GREEN <- "#70ad8f"; GREY <- "#8a8fa3"
theme_fii <- function(bs = 11) {
  ggplot2::theme_minimal(base_size = bs) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey88"),
      plot.title = ggplot2::element_text(face = "bold", size = bs + 3, colour = "#232849"),
      plot.subtitle = ggplot2::element_text(colour = "#3c4164", size = bs),
      plot.caption = ggplot2::element_text(colour = "grey45", size = bs - 2, hjust = 0),
      strip.text = ggplot2::element_text(face = "bold"))
}
fd19 <- dplyr::bind_rows(
  t37 |> dplyr::filter(basket == "oer", g2 == "10") |> dplyr::mutate(panel = "Which families? (each minus single/other CUs)"),
  t38 |> dplyr::filter(variant == "headline", basket == "oer") |> dplyr::mutate(panel = "Compared with whom?")) |>
  dplyr::mutate(lab = ifelse(panel == "Compared with whom?", paste0(GL[g1], " minus ", GL[g2]), GL[g1]),
                lab = forcats::fct_reorder(stringr::str_wrap(lab, 44), gap),
                hl = g1 %in% c("F1", "K1"))
p19 <- ggplot2::ggplot(fd19, ggplot2::aes(gap, lab, colour = hl)) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey50", linewidth = 0.4) +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = gap - 1.96 * se_bound, xmax = gap + 1.96 * se_bound),
                         width = 0, linewidth = 0.5, orientation = "y") +
  ggplot2::geom_errorbar(ggplot2::aes(xmin = gap - 1.96 * se_indep, xmax = gap + 1.96 * se_indep),
                         width = 0, linewidth = 1.6, orientation = "y") +
  ggplot2::geom_point(size = 2.4) +
  ggplot2::facet_wrap(~panel, scales = "free_y", ncol = 2) +
  ggplot2::scale_colour_manual(values = c(`TRUE` = NAVY, `FALSE` = GREY), guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "The family gap depends on who families are compared with, and which families",
    subtitle = paste0("Cumulative inflation gap, December 2019 to ", format(LASTD, "%B %Y"),
                      ", CPI-concept basket (owners' equivalent rent, medical pooled)."),
    x = "Gap in cumulative price change (percentage points)", y = NULL,
    caption = paste0("Source: author's calculation from BLS CEX (LB06 cells, CE standard errors) and CPI-U. ",
                     "Thick whiskers: 95% sampling interval, independent weight vintages.\n",
                     "Thin: worst case over any correlation across vintages. Vintage ", substr(VINTAGE, 1, 10), ".")) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f19_definitions_comparators.png"), p19, width = 12.5, height = 6.2, dpi = 200, bg = "white")

message("\nValidation log: ", LOG)
