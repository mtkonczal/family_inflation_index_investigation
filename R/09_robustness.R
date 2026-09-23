# ---------------------------------------------------------------------------
# 09_robustness.R   ---  robustness runs from METHODS section 7 (D-32)
#
# Holds weights, baskets and formula fixed and swaps the PRICE INPUT:
#   * CPI-U, NSA          baseline (the 06 result)
#   * CPI-W, NSA          wage-earner price indices for the same item strata.
#                         Within-composite weights stay CPI-U RI (CPI-W RI not
#                         pulled); this changes only multi-item categories.
#   * CPI-U, SA           seasonally adjusted item indices where BLS publishes
#                         them, NSA otherwise (BLS's own practice for items
#                         without seasonality). Used for MONTHLY gaps, which
#                         NSA data make noisy; 12-month changes barely differ.
# C-CPI-U is not run: BLS publishes ~30 aggregate C-CPI-U series and none of
# the item strata (D-32). The deep (levels 4-7) crosswalk is not run either.
#
# Run from the project root:  Rscript R/09_robustness.R
#
# Outputs
#   output/tables/t00g_robustness.txt
#   output/tables/t31_robustness.csv
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/index_build.R")
source("R/functions/ce_tables.R")
source("R/functions/price_panel.R")

LOG <- file.path(DIR_TAB, "t00g_robustness.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }
say("# Robustness log"); say("# built_at: ", VINTAGE); say("")

tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
xw <- readr::read_csv(file.path(DIR_XWALK, "cex_to_cpi.csv"),
                      col_types = readr::cols(.default = readr::col_character())) |>
  dplyr::filter(!is.na(cpi_item_code))
prices0 <- readr::read_csv(file.path(DIR_DER, "cpi_category_index.csv"), show_col_types = FALSE,
                           col_types = readr::cols(cat_id = "c"))
shares <- readr::read_csv(file.path(DIR_DER, "cex_shares_long.csv"), show_col_types = FALSE,
                          col_types = readr::cols(cat_id = "c", characteristics_code = "c"))
cpi  <- readRDS(file.path(DIR_RAW, "cpi_raw.rds"))
cpiw <- readRDS(file.path(DIR_RAW, "cpiw_raw.rds"))

LAG <- 2L; D0 <- as.Date("2019-12-01")
LASTD <- max(prices0$date)   # hold the CPI-U vintage; CPI-W was pulled later
mapped   <- sort(unique(prices0$cat_id))
SHELTER  <- tax$cat_id[tax$major == "Housing"]
MEDICAL  <- tax$cat_id[tax$major == "Health"]
BK <- list(pm_oer_all_in = c(setdiff(mapped, c(MEDICAL, "06")), "M0", "H0"),
           pm_ex_shelter = c(setdiff(mapped, c(MEDICAL, SHELTER)), "M0"),
           ex_shelter    = setdiff(mapped, SHELTER))
PAIRS <- list(fam = c("families_kids", "single_other"), par = c("single_parent", "married_kids"))

nat <- function(x, seas) x[x$area_code == "0000" & x$periodicity_code == "R" & x$seasonal == seas &
                           x$freq == "monthly" & !x$is_average & !is.na(x$value) & x$date <= LASTD, ]
cu_n <- nat(cpi, "U"); cu_s <- nat(cpi, "S"); cw_n <- nat(cpiw, "U")
ri_obs <- cu_n |> dplyr::filter(item_code %in% xw$cpi_item_code) |>
  dplyr::select(item_code, date, ri = weight)

# --- 1. The function must reproduce 05 exactly --------------------------
pub_u <- sort(unique(cu_n$date[cu_n$item_code == "SA0"]))
chk <- build_category_prices(dplyr::transmute(cu_n, item_code, date, idx = value), ri_obs, xw, pub_u) |>
  dplyr::inner_join(dplyr::select(prices0, cat_id, date, index0 = index), by = c("cat_id", "date"))
worst <- max(abs(chk$index - chk$index0))
say(sprintf("## 1. Rebuild of the NSA CPI-U category panel: %d rows, max |diff| vs 05 output %.2e", nrow(chk), worst))
if (worst > 1e-8 || nrow(chk) != nrow(prices0)) stop("price_panel.R does not reproduce 05.", call. = FALSE)
say("")

# --- 2. Alternative price panels -----------------------------------------
panels <- list()
panels$cpiu_nsa <- dplyr::select(prices0, cat_id, date, index)
pub_w <- sort(unique(cw_n$date[cw_n$item_code == "SA0"]))
miss_w <- setdiff(xw$cpi_item_code, unique(cw_n$item_code))
say("## 2. Price inputs")
say("  CPI-W: ", length(pub_w), " published months to ", format(max(pub_w)),
    "; mapped items without a CPI-W series: ", ifelse(length(miss_w), paste(miss_w, collapse = ", "), "none"))
panels$cpiw_nsa <- build_category_prices(dplyr::transmute(cw_n, item_code, date, idx = value), ri_obs, xw, pub_w)
sa_items <- intersect(xw$cpi_item_code, unique(cu_s$item_code))
say("  CPI-U SA: ", length(sa_items), " of ", dplyr::n_distinct(xw$cpi_item_code),
    " mapped items have an SA series; the rest use NSA (not seasonal)")
sa_ser <- dplyr::bind_rows(
  dplyr::filter(cu_s, item_code %in% sa_items),
  dplyr::filter(cu_n, item_code %in% setdiff(xw$cpi_item_code, sa_items))) |>
  dplyr::transmute(item_code, date, idx = value)
panels$cpiu_sa <- build_category_prices(sa_ser, ri_obs, xw, pub_u)
say("")

# --- 3. Shared weight inputs (as in 06) ----------------------------------
ri_cat <- ri_by_category(cpi, xw, fill = TRUE)
CODE2GROUP <- c("01" = "all_cu", "03" = "married_nokids", "04" = "married_kids",
                "09" = "single_parent", "10" = "single_other", "F1" = "families_kids")
ce <- ce_se_panel("LB06")
ce01 <- ce_se_panel("LB01") |> dplyr::filter(characteristics_code == "01") |> dplyr::mutate(dim = "LB06")
ce <- dplyr::bind_rows(ce, dplyr::anti_join(ce01, ce, by = c("year", "characteristics_code", "cat_id")))
ce <- dplyr::bind_rows(ce, ce_pool(ce, c("04", "09"), "F1")) |>
  dplyr::mutate(group = CODE2GROUP[characteristics_code]) |> dplyr::filter(!is.na(group))
rentval <- ce |> dplyr::filter(cat_id == "RENTVAL") |> dplyr::transmute(group, year, rentval_annual = 12 * mean)
totexp <- dplyr::distinct(shares, group, year, totalexp)
sh0 <- shares |> dplyr::select(group, cat_id, year, share = share_raw)

# SEHC in each price source, carried into add_oer() through a CPI-shaped frame
# that keeps CPI-U relative importance.
sehc_frame <- function(src) {
  s <- src[src$item_code == "SEHC", c("area_code", "periodicity_code", "seasonal", "freq",
                                      "is_average", "item_code", "date", "value")]
  s$seasonal <- "U"   # add_oer() reads the national NSA slice
  w <- cu_n[cu_n$item_code == "SEHC", c("date", "weight")]
  dplyr::left_join(s, w, by = "date")
}
OER_SRC <- list(cpiu_nsa = sehc_frame(cu_n), cpiw_nsa = sehc_frame(cw_n), cpiu_sa = sehc_frame(cu_s))

# --- 4. Indices under each price input -----------------------------------
out <- NULL; monthly <- NULL
for (pn in names(panels)) {
  px <- panels[[pn]] |> dplyr::filter(date <= LASTD)
  pm <- pool_block(px, sh0, ri_cat, MEDICAL, "M0")
  pmo <- add_oer(pm$prices, pm$shares, pm$ri, rentval, totexp, OER_SRC[[pn]])
  spec <- list(pm_oer_all_in = pmo, pm_ex_shelter = pm,
               ex_shelter = list(prices = px, shares = sh0))
  for (b in names(BK)) {
    ix <- list()
    for (g in unique(unlist(PAIRS))) {
      s <- spec[[b]]$shares |> dplyr::filter(group == g) |> dplyr::select(cat_id, year, share)
      ix[[g]] <- build_index(spec[[b]]$prices, s, BK[[b]], LAG)$index
    }
    for (k in names(PAIRS)) {
      a <- ix[[PAIRS[[k]][1]]]; z <- ix[[PAIRS[[k]][2]]]
      j <- dplyr::inner_join(dplyr::select(a, date, ia = index, ca = chg_12m),
                             dplyr::select(z, date, iz = index, cz = chg_12m), by = "date") |>
        dplyr::arrange(date) |>
        dplyr::mutate(m_a = 100 * ((ia / dplyr::lag(ia))^12 - 1), m_z = 100 * ((iz / dplyr::lag(iz))^12 - 1),
                      mgap = m_a - m_z)
      cum <- function(v) 100 * (v[j$date == LASTD] / v[j$date == D0] - 1)
      g12 <- j$ca - j$cz
      out <- dplyr::bind_rows(out, tibble::tibble(price_input = pn, basket = b, pair = k,
        months = sum(!is.na(g12)), mean_gap_12m = mean(g12, na.rm = TRUE),
        mean_abs_gap_12m = mean(abs(g12), na.rm = TRUE),
        sd_monthly_gap_ann = stats::sd(j$mgap, na.rm = TRUE),
        cum_1 = cum(j$ia), cum_2 = cum(j$iz), cum_gap = cum(j$ia) - cum(j$iz)))
    }
  }
}
readr::write_csv(out, file.path(DIR_TAB, "t31_robustness.csv"))

say("## 3. Family gaps under each price input (cumulative Dec 2019 to ", format(LASTD, "%Y-%m"), ")")
say("   input      basket           pair  mean 12m gap  mean|12m gap|  sd monthly gap (ann.)  cumulative")
for (i in seq_len(nrow(out))) {
  o <- out[i, ]
  say(sprintf("   %-10s %-16s %-4s    %+6.3f        %6.3f          %6.2f            %6.2f%% vs %6.2f%%  gap %+5.2f pp",
              o$price_input, o$basket, o$pair, o$mean_gap_12m, o$mean_abs_gap_12m,
              o$sd_monthly_gap_ann, o$cum_1, o$cum_2, o$cum_gap))
}
say("")
say("   Group definition robustness (04 alone; LB05 size cut) is reported in 06 and 07:")
say("   t28_cumulative_gaps.csv pair 'mk', t30_dimension_verdicts.csv 'Four-person minus one-person'.")
message("\nValidation log: ", LOG)
