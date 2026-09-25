# ---------------------------------------------------------------------------
# 12_external_benchmarks.R   ---  second methods review, check 7 (D-39, D-40)
#
# Puts the project's machinery next to two BLS products it can be checked
# against, neither of which the flat files contain:
#
#   * R-CPI-I and R-C-CPI-I, BLS's research CPIs by income quintile (Klick and
#     Stockburger, MLR July 2024). BLS uses full CPI item-area detail. If the flat-file method reproduces BLS's
#     lowest-minus-highest quintile gap, that is the strongest external
#     validation available for the family cut, which uses the same method.
#     NOT a like-for-like comparison: BLS ranks households by EQUIVALIZED
#     income (divided by the square root of household size), household-
#     weighted, and smooths expenditure weights; the CE LB01 quintiles used in
#     07 rank consumer units by unadjusted before-tax income.
#   * C-CPI-U, for the superlative index built in 11 (check 3): is our
#     Tornqvist-minus-Laspeyres gap for all CUs the size of BLS's C-CPI-U
#     minus CPI-U?
#
# Downloads are cached in data/raw/external/ with a manifest. Delete the
# folder to re-pull.
#
# Run from the project root after 07 and 11:  Rscript R/12_external_benchmarks.R
#
# Outputs
#   output/tables/t00j_external_benchmarks.txt
#   output/tables/t45_rcpi_i_benchmark.csv     cumulative and annual quintile gaps
#   output/tables/t46_rcpi_i_shelter.csv       shelter weight by quintile, BLS vs ours
#   output/tables/t47_ccpiu_benchmark.csv      superlative minus fixed-weight, all CUs
#   output/figures/f20_rcpi_i_benchmark.png
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")
source("R/functions/index_build.R")
source("R/functions/ce_tables.R")
source("R/functions/review_checks.R")

LOG <- file.path(DIR_TAB, "t00j_external_benchmarks.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }
say("# External benchmarks log (12_external_benchmarks.R)"); say("# built_at: ", VINTAGE); say("")

# ===========================================================================
# 1. Downloads (cached)
# ===========================================================================
DIR_EXT <- file.path(DIR_RAW, "external"); dir.create(DIR_EXT, showWarnings = FALSE)
SRC <- c(
  "r-cpi-i-data.xlsx"   = "https://www.bls.gov/cpi/research-series/r-cpi-i-data.xlsx",
  "r-c-cpi-i-data.xlsx" = "https://www.bls.gov/cpi/research-series/r-c-cpi-i-data.xlsx",
  "r-cpi-i-ri.xlsx"     = "https://www.bls.gov/cpi/research-series/r-cpi-i-ri.xlsx",
  "su.data.1.AllItems"  = "https://download.bls.gov/pub/time.series/su/su.data.1.AllItems",
  "su.series"           = "https://download.bls.gov/pub/time.series/su/su.series")
man_path <- file.path(DIR_EXT, "manifest.txt")
new_pull <- FALSE
for (f in names(SRC)) {
  dest <- file.path(DIR_EXT, f)
  if (!file.exists(dest)) { tidyusmacro:::bls_get(SRC[[f]], BLS_EMAIL, dest = dest); new_pull <- TRUE }
}
if (new_pull || !file.exists(man_path)) {
  writeLines(c(paste0("# External downloads, captured ", VINTAGE),
               sprintf("%-22s %8d bytes  %s", names(SRC), file.size(file.path(DIR_EXT, names(SRC))), SRC)),
             man_path)
}
say("## 1. Inputs (see data/raw/external/manifest.txt for the pull date)")
for (f in names(SRC)) say(sprintf("  %-22s %8d bytes", f, file.size(file.path(DIR_EXT, f))))

read_rcpi <- function(f, prefix) {
  x <- suppressMessages(readxl::read_excel(file.path(DIR_EXT, f), col_names = FALSE, col_types = "text"))
  hdr <- which(x[[1]] == "Year")[1]
  names(x) <- as.character(unlist(x[hdr, ]))
  x <- x[(hdr + 1L):nrow(x), ]
  x <- x[!is.na(suppressWarnings(as.integer(x$Year))), ]
  x |> tidyr::pivot_longer(dplyr::starts_with(prefix), names_to = "q", values_to = "index") |>
    dplyr::transmute(quintile = as.integer(sub(prefix, "", q)),
                     date = as.Date(sprintf("%s-%02d-01", Year, as.integer(Month))),
                     index = as.numeric(index))
}
rcpi  <- read_rcpi("r-cpi-i-data.xlsx", "R-CPI-I")
rccpi <- read_rcpi("r-c-cpi-i-data.xlsx", "R-C-CPI-I")
say(sprintf("  R-CPI-I %s to %s; R-C-CPI-I %s to %s; quintiles 1 (lowest) to 5",
            min(rcpi$date), max(rcpi$date), min(rccpi$date), max(rccpi$date)))
say("")

# ===========================================================================
# 2. Our income-quintile indices, rebuilt as in 07 (and checked against it)
# ===========================================================================
cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))
cpi <- readRDS(file.path(DIR_RAW, "cpi_raw.rds"))
tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
xw <- readr::read_csv(file.path(DIR_XWALK, "cex_to_cpi.csv"),
                      col_types = readr::cols(.default = readr::col_character())) |>
  dplyr::filter(!is.na(cpi_item_code))
prices <- readr::read_csv(file.path(DIR_DER, "cpi_category_index.csv"), show_col_types = FALSE,
                          col_types = readr::cols(cat_id = "c")) |> dplyr::select(cat_id, date, index)
dim07 <- readr::read_csv(file.path(DIR_DER, "dimension_index.csv"), show_col_types = FALSE,
                         col_types = readr::cols(characteristics_code = "c"))
LAG <- 2L
mapped <- sort(unique(prices$cat_id)); MEDICAL <- tax$cat_id[tax$major == "Health"]
BASKET <- c(setdiff(mapped, c(MEDICAL, "06")), "M0", "H0")
QC <- c("02" = 1L, "03" = 2L, "04" = 3L, "05" = 4L, "06" = 5L)   # LB01 code -> quintile

d <- cex_expend_panel(cex, tax, "LB01", c("01", names(QC)), verbose = FALSE)
d <- cex_repair_all_cu(cex, d, fallback_dim = "LB04", verbose = FALSE) |>
  dplyr::filter(characteristics_code %in% c("01", names(QC)))
tot <- d |> dplyr::filter(item_code == "TOTALEXP") |> dplyr::select(year, group = characteristics_code, totalexp = value)
sh <- d |> dplyr::filter(item_code %in% tax$cex_item_code) |>
  dplyr::left_join(dplyr::select(tax, cat_id, item_code = cex_item_code), by = "item_code") |>
  dplyr::inner_join(tot, by = c("year", "characteristics_code" = "group")) |>
  dplyr::transmute(group = characteristics_code, cat_id, year, share = 100 * value / totalexp)
ce1 <- ce_se_panel("LB01") |> dplyr::filter(characteristics_code %in% c("01", names(QC)))
rv <- ce1 |> dplyr::filter(cat_id == "RENTVAL") |>
  dplyr::transmute(group = characteristics_code, year, rentval_annual = 12 * dplyr::coalesce(mean, 0))
ri_cat <- ri_by_category(cpi, xw, fill = TRUE)
pm  <- pool_block(prices, sh, ri_cat, MEDICAL, "M0")
pmo <- add_oer(pm$prices, pm$shares, pm$ri, rv, dplyr::distinct(tot), cpi)
ours <- NULL; ours_t <- NULL; ours_w <- NULL
for (cc in c("01", names(QC))) {
  s <- pmo$shares |> dplyr::filter(group == cc) |> dplyr::select(cat_id, year, share)
  bi <- build_index(pmo$prices, s, BASKET, LAG)
  ours <- dplyr::bind_rows(ours, bi$index |> dplyr::mutate(code = cc))
  ours_w <- dplyr::bind_rows(ours_w, bi$weights |> dplyr::mutate(code = cc))
  ours_t <- dplyr::bind_rows(ours_t, build_index_tornqvist(pmo$prices, s, BASKET) |> dplyr::mutate(code = cc))
}
ref <- dim07 |> dplyr::filter(dimension == "income_quintile", basket == "pm_oer_all_in") |>
  dplyr::select(code = characteristics_code, date, index_ref = index)
z <- dplyr::inner_join(ours, ref, by = c("code", "date"))
say("## 2. Our LB01 quintile index (CPI concept, medical pooled), rebuilt")
say(sprintf("  rebuild vs 07 dimension_index.csv: %d rows, max |diff| %.2e", nrow(z), max(abs(z$index - z$index_ref))))
if (nrow(z) == 0 || max(abs(z$index - z$index_ref)) > 1e-6) stop("LB01 rebuild does not match 07.", call. = FALSE)
say("")

# ===========================================================================
# 3. Cumulative and annual lowest-minus-highest gaps
# ===========================================================================
cum_of <- function(x, d0, d1) {
  a <- x$index[x$date == d0]; b <- x$index[x$date == d1]
  if (length(a) != 1 || length(b) != 1) NA_real_ else 100 * (b / a - 1)
}
qgap <- function(frame, key, lo, hi, d0, d1) {
  cum_of(frame[frame[[key]] == lo, ], d0, d1) - cum_of(frame[frame[[key]] == hi, ], d0, d1)
}
WIN <- list(c("2014-12-01", "2019-12-01"), c("2019-12-01", "2022-12-01"), c("2022-12-01", "2024-12-01"),
            c("2019-12-01", "2024-12-01"), c("2019-12-01", "2025-12-01"))
t45 <- NULL
for (w in WIN) {
  d0 <- as.Date(w[1]); d1 <- as.Date(w[2])
  t45 <- dplyr::bind_rows(t45, tibble::tibble(kind = "cumulative", from = d0, to = d1,
    bls_rcpi_i = qgap(rcpi, "quintile", 1L, 5L, d0, d1),
    ours_laspeyres = qgap(ours, "code", "02", "06", d0, d1),
    bls_r_c_cpi_i = qgap(rccpi, "quintile", 1L, 5L, d0, d1),
    ours_tornqvist = qgap(ours_t, "code", "02", "06", d0, d1),
    bls_q1 = cum_of(rcpi[rcpi$quintile == 1L, ], d0, d1), ours_q1 = cum_of(ours[ours$code == "02", ], d0, d1),
    bls_q5 = cum_of(rcpi[rcpi$quintile == 5L, ], d0, d1), ours_q5 = cum_of(ours[ours$code == "06", ], d0, d1)))
}
for (Y in 2014:2025) {
  d0 <- as.Date(sprintf("%d-12-01", Y - 1L)); d1 <- as.Date(sprintf("%d-12-01", Y))
  t45 <- dplyr::bind_rows(t45, tibble::tibble(kind = "annual", from = d0, to = d1,
    bls_rcpi_i = qgap(rcpi, "quintile", 1L, 5L, d0, d1),
    ours_laspeyres = qgap(ours, "code", "02", "06", d0, d1),
    bls_r_c_cpi_i = qgap(rccpi, "quintile", 1L, 5L, d0, d1),
    ours_tornqvist = qgap(ours_t, "code", "02", "06", d0, d1)))
}
readr::write_csv(t45, file.path(DIR_TAB, "t45_rcpi_i_benchmark.csv"))
say("## 3. Lowest minus highest income quintile, cumulative gap (pp)")
say("   BLS: equivalized-income quintiles, full CPI item-area detail.")
say("   Ours: CE LB01 before-tax income quintiles, flat files, 34 categories (07).")
say("   window               R-CPI-I   ours (lag-2 Laspeyres)   R-C-CPI-I   ours (Tornqvist)")
cu <- t45[t45$kind == "cumulative", ]
for (i in seq_len(nrow(cu))) {
  say(sprintf("   %s to %s   %+6.2f      %+6.2f                   %s      %s", format(cu$from[i], "%Y-%m"),
              format(cu$to[i], "%Y-%m"), cu$bls_rcpi_i[i], cu$ours_laspeyres[i],
              ifelse(is.na(cu$bls_r_c_cpi_i[i]), "  n/a ", sprintf("%+6.2f", cu$bls_r_c_cpi_i[i])),
              ifelse(is.na(cu$ours_tornqvist[i]), "  n/a ", sprintf("%+6.2f", cu$ours_tornqvist[i]))))
}
an <- t45[t45$kind == "annual" & !is.na(t45$bls_rcpi_i) & !is.na(t45$ours_laspeyres), ]
say("   annual Dec-to-Dec gaps:")
for (i in seq_len(nrow(an))) say(sprintf("     %s   R-CPI-I %+5.2f   ours %+5.2f", format(an$to[i], "%Y"),
                                         an$bls_rcpi_i[i], an$ours_laspeyres[i]))
say(sprintf("   correlation of annual gaps, %d years: %.2f; same sign in %d of %d years",
            nrow(an), stats::cor(an$bls_rcpi_i, an$ours_laspeyres),
            sum(sign(an$bls_rcpi_i) == sign(an$ours_laspeyres)), nrow(an)))
say("")

# ===========================================================================
# 4. Shelter weight by quintile: BLS relative importance vs our cost weights
# ===========================================================================
shel_bls <- NULL
for (y in c(2019L, 2021L, 2023L, 2024L)) {
  sheet <- sprintf("R-CPI-I RI %d12", y)
  x <- suppressMessages(readxl::read_excel(file.path(DIR_EXT, "r-cpi-i-ri.xlsx"), sheet = sheet,
                                           col_names = FALSE, col_types = "text"))
  rows <- x[x[[1]] %in% c("SEHA", "SEHB", "SEHC"), ]
  for (q in 1:5) shel_bls <- dplyr::bind_rows(shel_bls, tibble::tibble(year = y, quintile = q,
    bls_shelter = sum(as.numeric(unlist(rows[, 2 + q])))))
}
shel_ours <- ours_w |> dplyr::filter(code %in% names(QC), cat_id %in% c("07", "08", "H0"),
                                     format(date, "%m") == "01") |>
  dplyr::mutate(year = as.integer(format(date, "%Y")) - 1L) |>
  dplyr::summarise(ours_shelter = 100 * sum(weight), .by = c(code, year)) |>
  dplyr::mutate(quintile = QC[code])
t46 <- dplyr::inner_join(shel_bls, shel_ours, by = c("year", "quintile"))
readr::write_csv(t46, file.path(DIR_TAB, "t46_rcpi_i_shelter.csv"))
say("## 4. Shelter weight (rent + lodging + OER), December relative importance, percent of basket")
say("   ours: cost weight in the January basket, i.e. price-updated to December")
for (y in unique(t46$year)) {
  z <- t46[t46$year == y, ]
  say(sprintf("   Dec %d   BLS  %s   |   ours  %s   |  Q1-Q5: BLS %+5.1f, ours %+5.1f", y,
              paste(sprintf("%4.1f", z$bls_shelter), collapse = " "), paste(sprintf("%4.1f", z$ours_shelter), collapse = " "),
              z$bls_shelter[1] - z$bls_shelter[5], z$ours_shelter[1] - z$ours_shelter[5]))
}
say("")

# ===========================================================================
# 5. C-CPI-U: superlative minus fixed-weight, all CUs
# ===========================================================================
su <- readr::read_tsv(file.path(DIR_EXT, "su.data.1.AllItems"), show_col_types = FALSE,
                      col_types = readr::cols(.default = "c")) |>
  dplyr::mutate(series_id = trimws(series_id)) |>
  dplyr::filter(series_id == "SUUR0000SA0", grepl("^M(0[1-9]|1[0-2])$", period)) |>
  dplyr::transmute(date = as.Date(sprintf("%s-%s-01", year, substr(period, 2, 3))),
                   ccpiu = as.numeric(value), footnote = trimws(footnote_codes))
cn <- cpi_national(cpi) |> dplyr::filter(item_code == "SA0", !is.na(value)) |> dplyr::select(date, cpiu = value)
t39 <- readr::read_csv(file.path(DIR_TAB, "t39_weight_timing.csv"), show_col_types = FALSE)
t47 <- NULL
for (w in list(c("2014-12-01", "2019-12-01"), c("2019-12-01", "2024-12-01"))) {
  d0 <- as.Date(w[1]); d1 <- as.Date(w[2])
  pc <- function(x, col) 100 * (x[[col]][x$date == d1] / x[[col]][x$date == d0] - 1)
  g <- t39 |> dplyr::filter(variant == "headline", basket == "oer", group == "01", from == d0, to == d1)
  t47 <- dplyr::bind_rows(t47, tibble::tibble(from = d0, to = d1,
    cpiu = pc(cn, "cpiu"), ccpiu = pc(su, "ccpiu"),
    ccpiu_footnote_end = su$footnote[su$date == d1],
    ours_laspeyres = g$cum[g$method == "lasp_lag2"], ours_tornqvist = g$cum[g$method == "tornqvist"],
    ours_laspeyres_lag0 = g$cum[g$method == "lasp_lag0"]) |>
    dplyr::mutate(bls_diff = ccpiu - cpiu, ours_diff = ours_tornqvist - ours_laspeyres))
}
readr::write_csv(t47, file.path(DIR_TAB, "t47_ccpiu_benchmark.csv"))
say("## 5. Superlative minus fixed-weight, all consumer units (cumulative, pp)")
for (i in seq_len(nrow(t47))) {
  x <- t47[i, ]
  say(sprintf("   %s to %s   BLS: C-CPI-U %.2f%% - CPI-U %.2f%% = %+.2f  (C-CPI-U end-month footnote: %s)",
              format(x$from, "%Y-%m"), format(x$to, "%Y-%m"), x$ccpiu, x$cpiu, x$bls_diff,
              ifelse(is.na(x$ccpiu_footnote_end), "final", x$ccpiu_footnote_end)))
  say(sprintf("                          ours: Tornqvist %.2f%% - lag-2 Laspeyres %.2f%% = %+.2f  (lag-0 Laspeyres %.2f%%)",
              x$ours_tornqvist, x$ours_laspeyres, x$ours_diff, x$ours_laspeyres_lag0))
}
say("   Ours aggregates 34 categories; C-CPI-U aggregates about 243 items x 32 areas, so it")
say("   captures more substitution. Ours should be smaller in magnitude, same sign.")
say("")

# ===========================================================================
# 6. Figure
# ===========================================================================
NAVY <- "#2c3254"; GREEN <- "#70ad8f"
fa <- an |> dplyr::select(to, `BLS R-CPI-I (equivalized income)` = bls_rcpi_i,
                          `This project (CE income quintiles, flat files)` = ours_laspeyres) |>
  tidyr::pivot_longer(-to) |> dplyr::mutate(year = as.integer(format(to, "%Y")))
p20 <- ggplot2::ggplot(fa, ggplot2::aes(year, value, fill = name)) +
  ggplot2::geom_hline(yintercept = 0, colour = "grey50", linewidth = 0.4) +
  ggplot2::geom_col(position = ggplot2::position_dodge(width = 0.8), width = 0.75) +
  ggplot2::scale_fill_manual(values = c(NAVY, GREEN)) +
  ggplot2::scale_x_continuous(breaks = unique(fa$year)) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, " pp")) +
  ggplot2::labs(title = "Lowest minus highest income quintile, December-to-December inflation",
    subtitle = "BLS's research index by income quintile against this project's flat-file method (CPI concept, medical pooled).",
    x = NULL, y = "Gap (percentage points)", fill = NULL,
    caption = paste0("Source: BLS R-CPI-I (Klick and Stockburger); author's calculation from BLS CEX and CPI-U. ",
                     "Quintile definitions differ (see text). Vintage ", substr(VINTAGE, 1, 10), ".")) +
  ggplot2::theme_minimal(base_size = 11) +
  ggplot2::theme(panel.grid.minor = ggplot2::element_blank(), legend.position = "top",
                 panel.grid.major.x = ggplot2::element_blank(),
                 plot.title = ggplot2::element_text(face = "bold", size = 14, colour = "#232849"),
                 plot.caption = ggplot2::element_text(colour = "grey45", size = 9, hjust = 0))
ggplot2::ggsave(file.path(DIR_FIG, "f20_rcpi_i_benchmark.png"), p20, width = 11, height = 5.5, dpi = 200, bg = "white")

message("\nValidation log: ", LOG)
