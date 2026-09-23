# ---------------------------------------------------------------------------
# 02_build_shares.R   ---  PHASE 1
#
# Builds budget shares by CEX consumer-unit composition (LB06), 1988-2024,
# on the 41-category taxonomy in crosswalk/cex_analysis_categories.csv.
#
# Answers the descriptive question directly: what do families with children
# spend proportionally more on than single-person households?
#
# This script constructs NO price index. It is the cheap test of whether a
# composition story exists before the CEX-to-CPI crosswalk is built (Phase 2).
#
# Design principle: never sum CEX components to build an aggregate. The
# display_level field in cx.item is NOT a clean tree (documented cases:
# HHPERSRV contains 670320 at the same display level; GASFUEL sits at level 2
# under VEHPURCH while being a sibling of it in the real accounting identity).
# Every aggregate used here is a BLS-published total, and additivity to
# TOTALEXP is verified explicitly and fails loudly.
#
# Run from the project root:  Rscript R/02_build_shares.R
#
# Outputs
#   data/derived/cex_shares_long.csv        cat x group x year, dollars + shares
#   output/tables/t01_shares_2024.csv       2024 headline shares, wide
#   output/tables/t02_share_gaps_2024.csv   family-vs-nonfamily gaps, ranked
#   output/tables/t03_shares_majors.csv     collapsed to 15 major groups
#   output/tables/t00_validation.txt        additivity + coverage diagnostics
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")

LOG <- file.path(DIR_TAB, "t00_validation.txt")
con <- file(LOG, open = "wt")
say <- function(...) {
  msg <- paste0(...)
  cat(msg, "\n", sep = "")
  writeLines(msg, con)
}
on.exit(close(con), add = TRUE)

say("# Phase 1 validation log")
say("# built_at: ", VINTAGE)
say("")

# ===========================================================================
# 1. Load
# ===========================================================================
cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))
tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))

stopifnot(nrow(tax) == 41L, !any(duplicated(tax$cat_id)))

# LB06 = composition of consumer unit. Keep expenditures only.
d <- cex |>
  dplyr::filter(category_code == CEX_CAT_KEEP,
                demographics_code == "LB06",
                characteristics_code %in% LB06_GROUPS$characteristics_code) |>
  dplyr::select(year, characteristics_code, item_code, item_text, value)

# BLS does not publish LB06 "All Consumer Units" for 2010-2013. Borrow those
# cells from LB04, which is the same universe; the helper verifies the two
# series are identical where both exist and stops if they are not. See D-23.
say("## 1. Input")
repair_msgs <- utils::capture.output(
  d <- cex_repair_all_cu(cex, d, fallback_dim = "LB04"), type = "message")
for (m in repair_msgs) say(m)
say("CEX EXPEND x LB06 rows: ", format(nrow(d), big.mark = ","))
say("years: ", min(d$year), "-", max(d$year))
say("groups: ", paste(sort(unique(d$characteristics_code)), collapse = ", "))
say("")

# ===========================================================================
# 2. Resolve the spliced gasoline series
# ===========================================================================
# Splice logic lives in R/functions/cex_prep.R so it cannot drift between this
# script and 04_adjusted_passes.R. See decisions_log D-05.
say("## 2. Spliced series")
splice_msgs <- utils::capture.output(
  d <- cex_apply_splices(d, tax, verbose = TRUE), type = "message")
for (m in splice_msgs) say(m)
say("")

# ===========================================================================
# 3. Additivity validation  ---  fails loudly
# ===========================================================================
# The 41 categories must partition TOTALEXP. Check every year x group.
TOL_PCT <- 0.25   # tolerance in percent of TOTALEXP, covers BLS rounding

wide <- d |>
  dplyr::select(year, characteristics_code, item_code, value) |>
  tidyr::pivot_wider(names_from = item_code, values_from = value)

cat_codes <- tax$cex_item_code
missing_cols <- setdiff(cat_codes, names(wide))
if (length(missing_cols)) {
  stop("Taxonomy references item codes absent from the CEX extract: ",
       paste(missing_cols, collapse = ", "), call. = FALSE)
}

add_chk <- wide |>
  dplyr::mutate(
    cat_sum  = rowSums(dplyr::across(dplyr::all_of(cat_codes)), na.rm = TRUE),
    total    = TOTALEXP,
    diff     = cat_sum - total,
    diff_pct = 100 * diff / total
  ) |>
  dplyr::select(year, characteristics_code, total, cat_sum, diff, diff_pct)

# The panel must be balanced BEFORE additivity: additivity only inspects
# cells that exist, so an absent year x group cell passes it silently.
bal_msgs <- utils::capture.output(
  cex_assert_no_interior_gaps(d, label = "LB06 EXPEND"), type = "message")
for (m in bal_msgs) say(m)
say("")

say("## 3. Additivity: 41 categories vs TOTALEXP")
say("tolerance: ", TOL_PCT, "% of TOTALEXP")
bad <- add_chk |> dplyr::filter(abs(diff_pct) > TOL_PCT)
say("year x group cells checked: ", nrow(add_chk))
say("cells outside tolerance:    ", nrow(bad))
say("worst absolute gap:         ", sprintf("%.3f%%", max(abs(add_chk$diff_pct))))

if (nrow(bad)) {
  say("")
  say("FAILURES (first 25):")
  for (i in seq_len(min(25L, nrow(bad)))) {
    say(sprintf("  %d  group %s  total=%.0f  sum=%.0f  diff=%.0f (%.2f%%)",
                bad$year[i], bad$characteristics_code[i],
                bad$total[i], bad$cat_sum[i], bad$diff[i], bad$diff_pct[i]))
  }
}

# Restrict to the balanced window where every group has every category.
# Married-with-children (04) starts in 1988; the others start in 1984.
YEAR_MIN <- add_chk |>
  dplyr::filter(abs(diff_pct) <= TOL_PCT) |>
  dplyr::summarise(y = max(min(year), 1988L), .by = characteristics_code) |>
  dplyr::pull(y) |> max()

say("")
say("balanced-panel start year: ", YEAR_MIN)
say("")

# Coverage: how many of the 41 categories are non-NA, by group x year
cov <- d |>
  dplyr::filter(item_code %in% cat_codes) |>
  dplyr::summarise(n_nonmissing = sum(!is.na(value)), .by = c(year, characteristics_code))
say("## 4. Category coverage (of 41)")
say("minimum non-missing categories in any year x group: ", min(cov$n_nonmissing))
sparse <- cov |> dplyr::filter(n_nonmissing < 41L) |> dplyr::arrange(year)
if (nrow(sparse)) {
  say("year x group cells with suppressed categories: ", nrow(sparse))
  for (i in seq_len(min(15L, nrow(sparse)))) {
    say(sprintf("  %d  group %s  %d/41 present",
                sparse$year[i], sparse$characteristics_code[i], sparse$n_nonmissing[i]))
  }
} else {
  say("all 41 categories present in every year x group. No suppression.")
}
say("")

# ===========================================================================
# 4. Build the family / non-family aggregates
# ===========================================================================
# "Families with children" pools married-with-children (04) and single-parent
# (09). Pooling requires population weights: the number of consumer units in
# each group, which lives in category CUCHARS, item CONSUNIT (thousands).
cu_counts <- cex |>
  dplyr::filter(category_code == "CUCHARS", demographics_code == "LB06",
                item_code == "CONSUNIT",
                characteristics_code %in% LB06_GROUPS$characteristics_code) |>
  dplyr::select(year, characteristics_code, n_cu = value)
# Same 2010-2013 hole affects the all-CU consumer-unit counts.
cu_fb <- cex |>
  dplyr::filter(category_code == "CUCHARS", demographics_code == "LB04",
                item_code == "CONSUNIT", characteristics_code == "01") |>
  dplyr::select(year, characteristics_code, n_cu = value)
cu_ov <- dplyr::inner_join(
  dplyr::filter(cu_counts, characteristics_code == "01") |>
    dplyr::select(year, a = n_cu),
  dplyr::select(cu_fb, year, b = n_cu), by = "year") |>
  dplyr::filter(!is.na(a), !is.na(b))
if (nrow(cu_ov) && max(abs(cu_ov$a - cu_ov$b)) > 0) {
  stop("All-CU consumer-unit counts differ between LB06 and LB04.", call. = FALSE)
}
cu_counts <- dplyr::bind_rows(
  cu_counts,
  dplyr::anti_join(cu_fb, dplyr::select(cu_counts, year, characteristics_code),
                   by = c("year", "characteristics_code")))

if (!nrow(cu_counts)) stop("Could not find CUCHARS/CONSUNIT counts.", call. = FALSE)

say("## 5. Consumer-unit counts (thousands), 2024")
cu24 <- cu_counts |> dplyr::filter(year == 2024) |>
  dplyr::left_join(LB06_GROUPS, by = "characteristics_code")
for (i in seq_len(nrow(cu24))) {
  say(sprintf("  %-16s %s  %10s", cu24$group[i], cu24$characteristics_code[i],
              format(round(cu24$n_cu[i]), big.mark = ",")))
}

# Dollar-weighted pooling: total group spending / total group CUs.
d_cat <- d |>
  dplyr::filter(item_code %in% c(cat_codes, "TOTALEXP")) |>
  dplyr::left_join(cu_counts, by = c("year", "characteristics_code"))

pooled <- d_cat |>
  dplyr::filter(characteristics_code %in% FAMILY_CODES) |>
  dplyr::summarise(
    value = sum(value * n_cu, na.rm = TRUE) / sum(n_cu[!is.na(value)]),
    n_cu  = sum(unique(n_cu)),
    .by = c(year, item_code)
  ) |>
  dplyr::mutate(characteristics_code = "F1")

d_all <- dplyr::bind_rows(
  d_cat |> dplyr::select(year, characteristics_code, item_code, value, n_cu),
  pooled |> dplyr::select(year, characteristics_code, item_code, value, n_cu)
)

GROUPS <- dplyr::bind_rows(
  LB06_GROUPS,
  tibble::tibble(characteristics_code = "F1", group = "families_kids",
                 group_label = "Families with children (04 + 09, CU-weighted)")
)
say("")

# ===========================================================================
# 5. Shares
# ===========================================================================
# Two denominators:
#   share_raw = category / TOTALEXP                (descriptive)
#   share_cpi = category / (TOTALEXP less out-of-scope), in-scope cats only
# in_cpi_scope == "FALSE" categories are dropped from the CPI denominator.
# "PARTIAL" categories are retained but flagged; scope_cpi_b (dropping owner
# shelter outlays as well) is deferred to Phase 3.
out_of_scope <- tax$cex_item_code[tax$in_cpi_scope == "FALSE"]

totals <- d_all |>
  dplyr::filter(item_code == "TOTALEXP") |>
  dplyr::select(year, characteristics_code, totalexp = value)

oos <- d_all |>
  dplyr::filter(item_code %in% out_of_scope) |>
  dplyr::summarise(oos = sum(value, na.rm = TRUE), .by = c(year, characteristics_code))

shares <- d_all |>
  dplyr::filter(item_code %in% cat_codes) |>
  dplyr::left_join(totals, by = c("year", "characteristics_code")) |>
  dplyr::left_join(oos,    by = c("year", "characteristics_code")) |>
  dplyr::left_join(tax |> dplyr::select(cat_id, major, cat_label,
                                        item_code = cex_item_code,
                                        in_cpi_scope, cpi_item_code),
                   by = "item_code") |>
  dplyr::left_join(GROUPS, by = "characteristics_code") |>
  dplyr::mutate(
    share_raw = 100 * value / totalexp,
    share_cpi = dplyr::if_else(in_cpi_scope == "FALSE", NA_real_,
                               100 * value / (totalexp - oos))
  ) |>
  dplyr::filter(year >= YEAR_MIN) |>
  dplyr::select(year, group, group_label, characteristics_code, cat_id, major,
                cat_label, item_code, in_cpi_scope, n_cu,
                dollars = value, totalexp, share_raw, share_cpi) |>
  dplyr::arrange(year, group, cat_id)

# Shares must sum to 100 within group x year
s_chk <- shares |>
  dplyr::summarise(raw = sum(share_raw, na.rm = TRUE),
                   cpi = sum(share_cpi, na.rm = TRUE),
                   .by = c(year, group))
say("## 6. Share sums (should be 100)")
say(sprintf("  share_raw: min %.3f  max %.3f", min(s_chk$raw), max(s_chk$raw)))
say(sprintf("  share_cpi: min %.3f  max %.3f", min(s_chk$cpi), max(s_chk$cpi)))
if (max(abs(s_chk$raw - 100)) > TOL_PCT || max(abs(s_chk$cpi - 100)) > TOL_PCT) {
  stop("Shares do not sum to 100 within tolerance. Inspect ", LOG, call. = FALSE)
}
say("")

write_derived(shares, "cex_shares_long")

# ===========================================================================
# 6. Output tables
# ===========================================================================
LATEST <- max(shares$year)

# t01: 2024 shares, wide by group
t01 <- shares |>
  dplyr::filter(year == LATEST) |>
  dplyr::select(cat_id, major, cat_label, in_cpi_scope, group, share_raw) |>
  tidyr::pivot_wider(names_from = group, values_from = share_raw) |>
  dplyr::arrange(cat_id)
readr::write_csv(t01, file.path(DIR_TAB, "t01_shares_2024.csv"))

# t02: the headline. Family-vs-single share gaps in percentage points.
t02 <- shares |>
  dplyr::filter(year == LATEST, group %in% c("families_kids", "single_other", "all_cu")) |>
  dplyr::select(cat_id, major, cat_label, in_cpi_scope, group, share_raw, dollars) |>
  tidyr::pivot_wider(names_from = group, values_from = c(share_raw, dollars)) |>
  dplyr::mutate(
    gap_pp        = share_raw_families_kids - share_raw_single_other,
    gap_vs_all_pp = share_raw_families_kids - share_raw_all_cu,
    dollar_ratio  = dollars_families_kids / dollars_single_other
  ) |>
  dplyr::arrange(dplyr::desc(gap_pp))
readr::write_csv(t02, file.path(DIR_TAB, "t02_share_gaps_2024.csv"))

# t03: collapsed to majors, for presentation
t03 <- shares |>
  dplyr::filter(year == LATEST) |>
  dplyr::summarise(share_raw = sum(share_raw, na.rm = TRUE),
                   dollars = sum(dollars, na.rm = TRUE),
                   .by = c(major, group)) |>
  tidyr::pivot_wider(names_from = group, values_from = c(share_raw, dollars)) |>
  dplyr::mutate(gap_pp = share_raw_families_kids - share_raw_single_other) |>
  dplyr::arrange(dplyr::desc(gap_pp))
readr::write_csv(t03, file.path(DIR_TAB, "t03_shares_majors.csv"))

say("## 7. Outputs")
say("  t01_shares_2024.csv      ", nrow(t01), " rows")
say("  t02_share_gaps_2024.csv  ", nrow(t02), " rows")
say("  t03_shares_majors.csv    ", nrow(t03), " rows")
say("  cex_shares_long.csv      ", nrow(shares), " rows, ", YEAR_MIN, "-", LATEST)
say("")

# ===========================================================================
# 7. Console summary
# ===========================================================================
message("\n================ PHASE 1 HEADLINE (", LATEST, ") ================")
message("\nTotal expenditures per consumer unit:")
tt <- totals |> dplyr::filter(year == LATEST) |>
  dplyr::left_join(GROUPS, by = "characteristics_code")
for (i in seq_len(nrow(tt))) {
  message(sprintf("  %-16s $%s", tt$group[i], format(round(tt$totalexp[i]), big.mark = ",")))
}

message("\nLargest share GAPS, families with children minus single/other (pp):")
print(t02 |> dplyr::slice_head(n = 10) |>
      dplyr::transmute(cat_label = substr(cat_label, 1, 44),
                       fam = round(share_raw_families_kids, 2),
                       single = round(share_raw_single_other, 2),
                       gap_pp = round(gap_pp, 2)) |> as.data.frame(), row.names = FALSE)

message("\nWhere singles spend proportionally MORE (pp):")
print(t02 |> dplyr::slice_tail(n = 8) |> dplyr::arrange(gap_pp) |>
      dplyr::transmute(cat_label = substr(cat_label, 1, 44),
                       fam = round(share_raw_families_kids, 2),
                       single = round(share_raw_single_other, 2),
                       gap_pp = round(gap_pp, 2)) |> as.data.frame(), row.names = FALSE)

message("\nBy major group (pp gap):")
print(t03 |> dplyr::transmute(major,
                              fam = round(share_raw_families_kids, 2),
                              single = round(share_raw_single_other, 2),
                              gap_pp = round(gap_pp, 2)) |> as.data.frame(), row.names = FALSE)

message("\nValidation log: ", LOG)
message("Vintage: ", VINTAGE)
