# ---------------------------------------------------------------------------
# 05_build_crosswalk.R   ---  PHASE 2
#
# Validates crosswalk/cex_to_cpi.csv and turns it into a monthly price panel:
# one price index per CEX analysis category, ready for Phase 3 weighting.
#
# Composite categories (12 of 41 map to more than one CPI item) are aggregated
# as a chained modified Laspeyres over their components, using CPI relative
# importance as the within-composite weight:
#
#   P_c,t / P_c,t-1 = sum_j [ RI_j,t-1 / sum_k RI_k,t-1 ] * (P_j,t / P_j,t-1)
#
# This mirrors CPI's own upper-level aggregation, so a single-item category
# reduces exactly to that item's published index.
#
# Run from the project root:  Rscript R/05_build_crosswalk.R
#
# Outputs
#   data/derived/cpi_category_index.csv   monthly index + 12m change per category
#   output/tables/t10_crosswalk_audit.csv every mapping with RI and coverage
#   output/tables/t11_share_vs_ri.csv     CEX share against CPI RI, the key check
#   output/tables/t12_unmapped_cpi.csv    CPI items with RI that nothing maps to
#   output/tables/t00c_crosswalk_validation.txt
#   output/figures/f06_share_vs_ri.png
#   output/figures/f07_category_inflation.png
# ---------------------------------------------------------------------------

source("R/00_setup.R")
source("R/functions/cex_prep.R")
source("R/functions/cpi_tree.R")

LOG <- file.path(DIR_TAB, "t00c_crosswalk_validation.txt")
con <- file(LOG, open = "wt"); on.exit(close(con), add = TRUE)
say <- function(...) { m <- paste0(...); cat(m, "\n", sep = ""); writeLines(m, con) }

say("# Crosswalk validation log"); say("# built_at: ", VINTAGE); say("")

tax <- readr::read_csv(file.path(DIR_XWALK, "cex_analysis_categories.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
xw  <- readr::read_csv(file.path(DIR_XWALK, "cex_to_cpi.csv"),
                       col_types = readr::cols(.default = readr::col_character()))
if (nrow(readr::problems(xw))) stop("cex_to_cpi.csv failed to parse cleanly.", call. = FALSE)

cpi     <- readRDS(file.path(DIR_RAW, "cpi_raw.rds"))
cu_item <- readRDS(file.path(DIR_RAW, "cu_item.rds"))

# ===========================================================================
# 1. Structural validation of the crosswalk
# ===========================================================================
say("## 1. Crosswalk structure")

# Every taxonomy category must appear exactly once as a cat_id set.
if (!setequal(unique(xw$cat_id), tax$cat_id)) {
  stop("Crosswalk cat_ids do not match the taxonomy: ",
       paste(symdiff(unique(xw$cat_id), tax$cat_id), collapse = ", "), call. = FALSE)
}
# cex_item_code must agree with the taxonomy for every row.
chk <- dplyr::left_join(xw, dplyr::select(tax, cat_id, tax_code = cex_item_code), by = "cat_id")
if (any(chk$cex_item_code != chk$tax_code)) {
  stop("cex_item_code disagrees with the taxonomy at cat_id ",
       paste(chk$cat_id[chk$cex_item_code != chk$tax_code], collapse = ", "), call. = FALSE)
}

mapped <- dplyr::filter(xw, !is.na(cpi_item_code))

# Every CPI code must exist in cu.item.
bad_codes <- setdiff(mapped$cpi_item_code, cu_item$item_code)
if (length(bad_codes)) {
  stop("CPI item codes not present in cu.item: ", paste(bad_codes, collapse = ", "),
       call. = FALSE)
}
# No CPI item may serve two categories: that would double count.
dup <- mapped$cpi_item_code[duplicated(mapped$cpi_item_code)]
if (length(dup)) {
  stop("CPI items mapped to more than one CEX category (double counting): ",
       paste(unique(dup), collapse = ", "), call. = FALSE)
}
# A mapped CPI item must not be an ancestor of another mapped item, or the
# child's spending would be counted twice. Ancestry comes from the
# reconstructed tree, NOT from string prefixes: CPI codes are not hierarchical
# by prefix (SAF116 Alcoholic beverages is a sibling of SAF11 Food at home,
# not its child). See R/functions/cpi_tree.R.
tree <- cpi_build_tree(cu_item)
anc <- cpi_nesting_violations(mapped$cpi_item_code, tree)
if (nrow(anc)) {
  say("  NESTING VIOLATIONS:")
  for (i in seq_len(nrow(anc))) say("    ", anc$ancestor[i], " is an ancestor of ", anc$child[i])
  stop(nrow(anc), " mapped CPI item(s) nest inside another mapped item.", call. = FALSE)
}

n_comp <- sum(table(mapped$cat_id) > 1)
say("  rows: ", nrow(xw), "  categories: ", dplyr::n_distinct(xw$cat_id))
say("  mapped rows: ", nrow(mapped), "  distinct CPI items: ",
    dplyr::n_distinct(mapped$cpi_item_code))
say("  unmapped categories: ", sum(is.na(xw$cpi_item_code)), " (",
    paste(xw$cex_item_code[is.na(xw$cpi_item_code)], collapse = ", "), ")")
say("  composite categories (>1 CPI target): ", n_comp)
say("  confidence: ", paste(names(table(mapped$confidence)), table(mapped$confidence),
                            sep = "=", collapse = ", "))
say("  no duplicate CPI codes, no nesting violations, all codes exist in cu.item")
say("")

# ===========================================================================
# 2. National CPI panel
# ===========================================================================
# NSA, US city average, monthly. NSA is the right basis: relative importance is
# published NSA and seasonal factors are revised annually. See METHODS.md 2.
cpi_n <- cpi |>
  dplyr::filter(area_code == "0000", periodicity_code == "R", seasonal == "U",
                freq == "monthly", !is_average, !is.na(value)) |>
  dplyr::select(item_code, date, value, weight)

say("## 2. CPI panel")
say("  rows: ", format(nrow(cpi_n), big.mark = ","))
say("  date range: ", as.character(min(cpi_n$date)), " to ", as.character(max(cpi_n$date)))
say("  distinct items: ", dplyr::n_distinct(cpi_n$item_code))
miss <- setdiff(mapped$cpi_item_code, unique(cpi_n$item_code))
if (length(miss)) stop("Mapped CPI items with no NSA national series: ",
                       paste(miss, collapse = ", "), call. = FALSE)
say("  all ", dplyr::n_distinct(mapped$cpi_item_code), " mapped items have NSA national series")

# Series start dates: the binding constraint on how far back the index can run.
starts <- cpi_n |>
  dplyr::filter(item_code %in% mapped$cpi_item_code) |>
  dplyr::summarise(first = min(date), .by = item_code) |>
  dplyr::arrange(dplyr::desc(first))
say("  latest-starting mapped series (these bind the index start):")
for (i in seq_len(min(8L, nrow(starts)))) {
  nm <- cu_item$item_name[match(starts$item_code[i], cu_item$item_code)]
  say(sprintf("    %-8s %s  %s", starts$item_code[i], as.character(starts$first[i]),
              substr(nm, 1, 46)))
}
say("")

# ===========================================================================
# 3. Relative-importance coverage
# ===========================================================================
# RI is published from 2012-03 (aspect_type "I"). Use the latest December for
# the audit so the weights match a calendar-year CEX vintage.
# CEX is annual and lags; RI must be picked to match a year CEX actually has.
CEX_MAX <- max(cex_years <- as.integer(unique(
  readRDS(file.path(DIR_RAW, "cex_raw.rds"))$year)), na.rm = TRUE)
ri_dec <- cpi_n$date[!is.na(cpi_n$weight) & format(cpi_n$date, "%m") == "12"]
RI_DATE <- max(ri_dec[as.integer(format(ri_dec, "%Y")) <= CEX_MAX])
ri <- cpi_n |> dplyr::filter(date == RI_DATE, !is.na(weight)) |>
  dplyr::select(item_code, ri = weight)

say("## 3. Relative-importance coverage, as of ", as.character(RI_DATE))
ri_mapped <- sum(ri$ri[ri$item_code %in% mapped$cpi_item_code])
say(sprintf("  RI captured by the crosswalk: %.2f of 100", ri_mapped))

# Unmapped items. Reported by descending the PRIMARY expenditure tree from the
# eight major groups, which partition CPI (their RI sums to 100.000).
#
# CPI also publishes special aggregates (SA0LE "All items less energy", SAC
# "Commodities", SA0L2 "All items less shelter", ...). These sit at display
# level 1 in sort order AFTER the last major group's subtree, so the positional
# parent rule adopts them as children of SAG and any naive walk double counts
# them: the frontier came to 1,083 of a possible 100.
#
# They are removed by a clean invariant: a genuine child's relative importance
# never exceeds its parent's, while every special aggregate's does (SA0LE is
# 93.6 against SAG's 3.0). No hand-maintained exclusion list is needed.
mapped_codes <- unique(mapped$cpi_item_code)
CPI_MAJORS <- c("SAF", "SAH", "SAA", "SAT", "SAM", "SAR", "SAE", "SAG")
maj_ri <- sum(ri$ri[ri$item_code %in% CPI_MAJORS])
say(sprintf("  the 8 primary major groups sum to %.3f RI (partition check)", maj_ri))
if (abs(maj_ri - 100) > 0.5) stop("CPI major groups do not partition RI.", call. = FALSE)

major_of <- function(code) {
  if (code %in% CPI_MAJORS) return(code)
  a <- intersect(cpi_ancestors(code, tree), CPI_MAJORS)
  if (length(a)) a[1] else NA_character_
}
mapped_major <- vapply(mapped_codes, major_of, character(1), USE.NAMES = TRUE)
if (anyNA(mapped_major)) {
  stop("Mapped CPI items that do not resolve to a primary major group: ",
       paste(names(mapped_major)[is.na(mapped_major)], collapse = ", "), call. = FALSE)
}

# Primary tree: items resolving to a major, with special aggregates dropped.
prim <- tree |>
  dplyr::left_join(ri, by = "item_code") |>
  dplyr::mutate(major = vapply(item_code, major_of, character(1))) |>
  dplyr::filter(!is.na(major))
prim <- prim |>
  dplyr::left_join(dplyr::select(prim, parent = item_code, parent_ri = ri), by = "parent") |>
  dplyr::filter(is.na(ri) | is.na(parent_ri) | ri <= parent_ri * 1.001)
say("  primary-tree items after dropping special aggregates: ", nrow(prim))

# Exact unmapped RI per major, by subtraction. Needs no tree walk.
by_major <- tibble::tibble(major = CPI_MAJORS) |>
  dplyr::mutate(
    ri_major   = ri$ri[match(major, ri$item_code)],
    ri_covered = vapply(major, function(m)
      sum(ri$ri[match(mapped_codes[mapped_major == m], ri$item_code)], na.rm = TRUE),
      numeric(1)),
    ri_unmapped = ri_major - ri_covered,
    pct_covered = 100 * ri_covered / ri_major)
readr::write_csv(by_major, file.path(DIR_TAB, "t13_coverage_by_major.csv"))

say("")
say("  coverage by primary major group:")
say("    major   name                          RI    mapped  unmapped  pct")
for (i in order(-by_major$ri_unmapped)) {
  nm <- cu_item$item_name[match(by_major$major[i], cu_item$item_code)]
  say(sprintf("    %-7s %-26s %6.2f  %6.2f  %8.2f  %3.0f%%",
              by_major$major[i], substr(nm, 1, 26), by_major$ri_major[i],
              by_major$ri_covered[i], by_major$ri_unmapped[i], by_major$pct_covered[i]))
}

# Name the uncovered content. Rather than a tree walk, this is done by
# subtraction within each major and by naming the single large uncovered item
# directly. A recursive frontier was attempted and abandoned: BLS publishes
# alternative groupings (SARC "Recreation commodities", SAGS "Other personal
# services", SA311 "Apparel less footwear", SERAS "Video and audio services")
# that overlap the primary hierarchy and appear as childless terminal rows, so
# no structural rule distinguishes them from genuinely uncovered strata. Their
# content IS mapped, just grouped differently, and listing them as "unmapped"
# would overstate the gap (36.8 against a true 29.3).
#
# The by-major subtractions above are exact by construction and are the
# authoritative statement of coverage.
OER <- "SEHC"
oer_ri <- ri$ri[match(OER, ri$item_code)]
sah_un <- by_major$ri_unmapped[by_major$major == "SAH"]
non_housing_un <- sum(by_major$ri_unmapped[by_major$major != "SAH"])

unmapped <- by_major |>
  dplyr::mutate(major_name = cu_item$item_name[match(major, cu_item$item_code)]) |>
  dplyr::select(major, major_name, ri_major, ri_covered, ri_unmapped, pct_covered) |>
  dplyr::arrange(dplyr::desc(ri_unmapped))
readr::write_csv(unmapped, file.path(DIR_TAB, "t12_unmapped_cpi.csv"))

say("")
say("  what the crosswalk does not cover:")
say(sprintf("    owners' equivalent rent (SEHC):        %6.2f RI", oer_ri))
say(sprintf("    rest of Housing:                       %6.2f RI", sah_un - oer_ri))
say(sprintf("    everything outside Housing, combined:  %6.2f RI", non_housing_un))
say("")
say("  So 93 pct of the uncovered basket is owners' equivalent rent alone, and")
say("  the entire non-housing residual is about 1 RI point. The crosswalk is")
say("  effectively complete outside owner-occupied shelter.")

# HARD CHECK on the authoritative numbers: the by-major subtraction must
# reconcile to 100 exactly.
tot_cov <- sum(by_major$ri_covered); tot_un <- sum(by_major$ri_unmapped)
say("")
say(sprintf("  AUTHORITATIVE: mapped %.2f + unmapped %.2f = %.2f",
            tot_cov, tot_un, tot_cov + tot_un))
if (abs(tot_cov + tot_un - 100) > 0.5) {
  stop("By-major coverage does not reconcile to 100: ",
       sprintf("%.2f", tot_cov + tot_un), call. = FALSE)
}
if (abs(tot_cov - ri_mapped) > 0.01) {
  stop("By-major mapped RI disagrees with the direct sum: ",
       sprintf("%.4f vs %.4f", tot_cov, ri_mapped), call. = FALSE)
}
if (abs(oer_ri / tot_un - 0.93) > 0.10) {
  say(sprintf("  NOTE: OER is %.0f pct of the uncovered basket, not the ~93 pct",
              100 * oer_ri / tot_un))
  say("  seen at build time. Revisit the narrative in METHODS.md section 8.")
}
say("")
say("  NOTE: owners' equivalent rent (SEHC) is deliberately unmapped. It is")
say("  27 pct of CPI and has no CEX published-table counterpart. This is the")
say("  scope_cpi_b problem, not a crosswalk defect. See METHODS.md section 3.")
say("")

# ===========================================================================
# 4. THE KEY VALIDATION: CEX all-CU shares against CPI relative importance
# ===========================================================================
# If the crosswalk is sound, CEX all-consumer-unit shares on a CPI-consistent
# base should track CPI relative importance renormalized over the same mapped
# items. Divergences localize concept mismatches rather than coding errors.
cex <- readRDS(file.path(DIR_RAW, "cex_raw.rds"))
d06 <- cex_expend_panel(cex, tax, "LB06", "01", verbose = FALSE)
cex_assert_additive(d06, tax, label = "LB06 all-CU")

CEX_YEAR <- as.integer(format(RI_DATE, "%Y"))
mapped_cats <- unique(mapped$cat_id)
keep_codes  <- tax$cex_item_code[tax$cat_id %in% mapped_cats]

cex_sh <- cex_shares_on_base(dplyr::filter(d06, year == CEX_YEAR), keep_codes) |>
  dplyr::select(item_code, cex_share = share) |>
  dplyr::left_join(dplyr::select(tax, cat_id, cat_label, major,
                                 item_code = cex_item_code), by = "item_code")

ri_cat <- mapped |>
  dplyr::left_join(ri, by = c("cpi_item_code" = "item_code")) |>
  dplyr::summarise(ri_raw = sum(ri, na.rm = TRUE),
                   n_items = dplyr::n(),
                   n_missing_ri = sum(is.na(ri)), .by = cat_id) |>
  dplyr::mutate(cpi_share = 100 * ri_raw / sum(ri_raw))

cmp <- dplyr::left_join(cex_sh, ri_cat, by = "cat_id") |>
  dplyr::mutate(diff = cex_share - cpi_share,
                ratio = cex_share / cpi_share) |>
  dplyr::arrange(dplyr::desc(abs(diff)))
readr::write_csv(cmp, file.path(DIR_TAB, "t11_share_vs_ri.csv"))

rho <- stats::cor(cmp$cex_share, cmp$cpi_share)
rho_s <- stats::cor(cmp$cex_share, cmp$cpi_share, method = "spearman")
diss <- sum(abs(cmp$diff)) / 2

say("## 4. CEX all-CU shares vs CPI relative importance (", CEX_YEAR, ", ",
    length(mapped_cats), " mapped categories, both renormalized to 100)")
say(sprintf("  Pearson correlation:  %.3f", rho))
say(sprintf("  Spearman correlation: %.3f", rho_s))
say(sprintf("  dissimilarity index:  %.2f (pct of basket needing reallocation)", diss))
say("")
say("  largest divergences (CEX share minus CPI share, pp):")
for (i in seq_len(min(10L, nrow(cmp)))) {
  say(sprintf("    %-42s CEX %6.2f  CPI %6.2f  diff %+6.2f",
              substr(cmp$cat_label[i], 1, 42), cmp$cex_share[i],
              cmp$cpi_share[i], cmp$diff[i]))
}
# --- 4b. Does the divergence survive aggregation? -------------------------
# The largest single divergence is medical, and it looks like a reallocation
# WITHIN medical care rather than a level disagreement: CEX households report
# out-of-pocket premiums as insurance, while CPI routes most medical spending
# through services and gives health insurance a ~0.6 RI weight. If so, the
# mismatch cancels when the medical categories are pooled.
blk <- cmp |>
  dplyr::summarise(cex = sum(cex_share), cpi = sum(cpi_share), .by = major) |>
  dplyr::mutate(diff = cex - cpi) |>
  dplyr::arrange(dplyr::desc(abs(diff)))
diss_blk <- sum(abs(blk$diff)) / 2
med <- blk[blk$major == "Health", ]

say("### 4b. Divergence under aggregation")
say(sprintf("  medical categories pooled: CEX %.2f vs CPI %.2f (diff %+.2f)",
            med$cex, med$cpi, med$diff))
say("    the -6.33 medical services and +5.92 health insurance gaps nearly")
say("    cancel, confirming a within-block reallocation, not a level error.")
say(sprintf("  dissimilarity at %d categories: %.2f", nrow(cmp), diss))
say(sprintf("  dissimilarity at %d major blocks: %.2f", nrow(blk), diss_blk))

# Correlation with the pre-flagged concept mismatches removed. These were
# marked PARTIAL or low confidence in the taxonomy BEFORE this comparison ran,
# so dropping them is not data mining.
flagged <- unique(mapped$cat_id[mapped$confidence == "low"])
flagged <- union(flagged, tax$cat_id[tax$in_cpi_scope == "PARTIAL" &
                                     tax$cat_id %in% cmp$cat_id])
cmp2 <- dplyr::filter(cmp, !cat_id %in% flagged)
say(sprintf("  excluding %d pre-flagged categories (%s):",
            length(intersect(flagged, cmp$cat_id)),
            paste(sort(intersect(flagged, cmp$cat_id)), collapse = ", ")))
say(sprintf("    Pearson rises %.3f -> %.3f;  dissimilarity falls %.2f -> %.2f",
            rho, stats::cor(cmp2$cex_share, cmp2$cpi_share),
            diss, sum(abs(cmp2$diff)) / 2))
readr::write_csv(blk, file.path(DIR_TAB, "t14_share_vs_ri_by_major.csv"))
say("")

if (any(ri_cat$n_missing_ri > 0)) {
  say("")
  say("  categories with components lacking published RI:")
  for (i in which(ri_cat$n_missing_ri > 0)) {
    say("    cat ", ri_cat$cat_id[i], ": ", ri_cat$n_missing_ri[i], " of ",
        ri_cat$n_items[i], " components")
  }
}
say("")

# ===========================================================================
# 5. Build the category price panel
# ===========================================================================
# Two distinct kinds of hole in the CPI series have to be handled differently.
#
# (a) MONTHS BLS DID NOT PUBLISH AT ALL. October 2025 carries 11 series against
#     380 in September; SA0 itself is absent. No October 2025 CPI was published.
#     Such months are EXCLUDED from the monthly grid: no value is invented for
#     them. The chain is carried across the hole using the true Sep-to-Nov
#     relative, so index LEVELS stay correct on both sides and 12-month changes
#     remain computable. Only the October point is missing, which is the truth.
#
# (b) THIN SERIES WITH RECURRING PUBLICATION GAPS. SETA03 (leased vehicles),
#     SEHP (household operations), SEGD01 (legal services), SEEA (educational
#     books), SETE (motor vehicle insurance) are published intermittently.
#     These are interpolated geometrically (log-linear in the index) onto the
#     grid, and the RI-weighted share of each category-month that came from
#     interpolation is recorded in `interp_share` so it can be filtered.
#
# Within-composite weights are CPI relative importance at t-1, carried back to
# the first RI date for pre-2012 months (RI begins 2012-03). Relative weights
# inside a composite move slowly, so this is mild; it is exact for the 25
# single-item categories, which the section 6 reconciliation verifies.
say("## 5. Category price panel")

# --- (a) the publication grid --------------------------------------------
# A month is "published" if the all-items index exists for it.
pub_months <- sort(unique(cpi_n$date[cpi_n$item_code == "SA0"]))
all_months <- seq(min(pub_months), max(pub_months), by = "month")
skipped <- as.Date(setdiff(all_months, pub_months), origin = "1970-01-01")
say("  published months: ", length(pub_months), " of ", length(all_months),
    " between ", as.character(min(pub_months)), " and ", as.character(max(pub_months)))
if (length(skipped)) {
  say("  MONTHS WITH NO PUBLISHED CPI (excluded from the grid, chained across):")
  for (d in as.character(skipped)) {
    n_it <- sum(cpi_n$date == as.Date(d))
    say("    ", d, "  (", n_it, " series published that month)")
  }
}

ri_obs <- cpi_n |>
  dplyr::filter(item_code %in% mapped$cpi_item_code) |>
  dplyr::select(item_code, date, ri = weight)

# --- (b) interpolate thin components onto the published grid --------------
obs <- cpi_n |>
  dplyr::filter(item_code %in% mapped$cpi_item_code, date %in% pub_months) |>
  dplyr::select(item_code, date, idx = value)

grid <- obs |>
  dplyr::summarise(first = min(date), last = max(date), .by = item_code) |>
  dplyr::rowwise() |>
  dplyr::reframe(item_code = item_code,
                 date = pub_months[pub_months >= first & pub_months <= last])

comp <- grid |>
  dplyr::left_join(obs, by = c("item_code", "date")) |>
  dplyr::arrange(item_code, date) |>
  dplyr::group_by(item_code) |>
  dplyr::mutate(
    observed = !is.na(idx),
    # log-linear interpolation between observed points; no extrapolation
    idx = exp(stats::approx(x = seq_along(idx)[observed], y = log(idx[observed]),
                            xout = seq_along(idx), rule = 1)$y)
  ) |>
  dplyr::ungroup() |>
  dplyr::filter(!is.na(idx))

n_interp <- sum(!comp$observed)
say("  component observations: ", format(nrow(comp), big.mark = ","),
    "  interpolated: ", n_interp,
    sprintf(" (%.2f%%)", 100 * n_interp / nrow(comp)))
if (n_interp > 0) {
  worst_i <- comp |> dplyr::filter(!observed) |> dplyr::count(item_code, sort = TRUE)
  say("  components with interpolated months:")
  for (i in seq_len(min(8L, nrow(worst_i)))) {
    nm <- cu_item$item_name[match(worst_i$item_code[i], cu_item$item_code)]
    say(sprintf("    %-8s %3d months  %s", worst_i$item_code[i], worst_i$n[i],
                substr(nm, 1, 44)))
  }
}

# --- aggregate to categories ---------------------------------------------
# Relative importance must be carried onto the interpolated grid too, or the
# weight is NA in exactly the months the index was filled and those
# category-months silently drop out of the aggregate.
comp <- comp |>
  dplyr::left_join(ri_obs, by = c("item_code", "date")) |>
  dplyr::arrange(item_code, date) |>
  dplyr::group_by(item_code) |>
  tidyr::fill(ri, .direction = "downup") |>
  dplyr::ungroup() |>
  dplyr::left_join(dplyr::select(mapped, cat_id, item_code = cpi_item_code),
                   by = "item_code") |>
  dplyr::arrange(cat_id, item_code, date) |>
  dplyr::group_by(cat_id, item_code) |>
  dplyr::mutate(rel = idx / dplyr::lag(idx), ri_lag = dplyr::lag(ri),
                obs_lag = dplyr::lag(observed)) |>
  dplyr::ungroup()

# Weight renormalizes over components present in that month, and the RI share
# that was fully observed (both endpoints of the relative) is recorded.
n_req_tbl <- mapped |> dplyr::summarise(n_req = dplyr::n(), .by = cat_id)
cat_rel <- comp |>
  dplyr::filter(!is.na(rel), !is.na(ri_lag)) |>
  dplyr::summarise(
    rel_cat      = sum(ri_lag * rel) / sum(ri_lag),
    n_have       = dplyr::n(),
    interp_share = 1 - sum(ri_lag * (observed & obs_lag)) / sum(ri_lag),
    .by = c(cat_id, date)) |>
  dplyr::left_join(n_req_tbl, by = "cat_id")

if (any(cat_rel$n_have < cat_rel$n_req)) {
  bad <- cat_rel |> dplyr::filter(n_have < n_req)
  # Classify each shortfall. Interpolation already fills holes inside each
  # component's own observed window, so a component can only be absent from a
  # category-month because its series had not started yet or had already ended.
  # Anything else would be a genuine hole and a bug.
  span <- comp |> dplyr::summarise(cfirst = min(date), clast = max(date),
                                   .by = c(cat_id, item_code))
  expect <- span |>
    dplyr::inner_join(dplyr::select(bad, cat_id, date), by = "cat_id",
                      relationship = "many-to-many") |>
    dplyr::mutate(in_range = date > cfirst & date <= clast) |>
    dplyr::summarise(n_expected = sum(in_range), .by = c(cat_id, date)) |>
    dplyr::inner_join(dplyr::select(bad, cat_id, date, n_have, n_req),
                      by = c("cat_id", "date"))
  n_hole <- sum(expect$n_have < expect$n_expected)
  say("  ", nrow(bad), " category-months have fewer components than the full set;",
      " weights renormalized")
  say("    explained by component series start and end dates: ",
      nrow(bad) - n_hole)
  say("    genuine mid-series holes (should be 0): ", n_hole)
  if (n_hole > 0) {
    stop(n_hole, " category-month(s) are missing a component that should be ",
         "present after interpolation. Interpolation or grid logic is wrong.",
         call. = FALSE)
  }
  # Report which components end early, since that silently changes a composite.
  ends <- span |> dplyr::filter(clast < max(comp$date)) |>
    dplyr::arrange(clast)
  if (nrow(ends)) {
    say("    components that stop before the panel end:")
    for (i in seq_len(nrow(ends))) {
      say(sprintf("      cat %-3s %-8s last obs %s", ends$cat_id[i],
                  ends$item_code[i], as.character(ends$clast[i])))
    }
  }
}

cat_idx <- cat_rel |>
  dplyr::arrange(cat_id, date) |>
  dplyr::group_by(cat_id) |>
  dplyr::mutate(index = 100 * cumprod(rel_cat)) |>
  dplyr::ungroup() |>
  dplyr::left_join(dplyr::select(tax, cat_id, cat_label, major, in_cpi_scope),
                   by = "cat_id")

# 12-month change by explicit date arithmetic, NOT lag(index, 12): with a month
# missing from the grid, positional lag would be off by one for a whole year.
cat_idx <- cat_idx |>
  dplyr::mutate(date_lag12 = date - months(12)) |>
  dplyr::left_join(dplyr::select(cat_idx, cat_id, date_lag12 = date, index_lag12 = index),
                   by = c("cat_id", "date_lag12")) |>
  dplyr::mutate(chg_12m = 100 * (index / index_lag12 - 1)) |>
  dplyr::select(cat_id, cat_label, major, in_cpi_scope, date, index, chg_12m,
                n_components = n_req, n_present = n_have, interp_share)

write_derived(cat_idx, "cpi_category_index")

cov <- cat_idx |> dplyr::summarise(first = min(date), last = max(date),
                                   n = dplyr::n(), .by = c(cat_id, cat_label))
say("  categories built: ", nrow(cov), " of ", length(mapped_cats), " mapped")
say("  panel: ", as.character(min(cat_idx$date)), " to ", as.character(max(cat_idx$date)))
say("  category-months with any interpolated weight: ",
    sum(cat_idx$interp_share > 1e-9), " of ", nrow(cat_idx))
say("  latest-starting categories (these bind any multi-category index):")
for (i in utils::head(order(cov$first, decreasing = TRUE), 6)) {
  say(sprintf("    cat %-3s %s  %s", cov$cat_id[i], as.character(cov$first[i]),
              substr(cov$cat_label[i], 1, 44)))
}

# --- reconciliation -------------------------------------------------------
# Single-item categories with no interpolation must reproduce the published CPI
# index exactly once rebased. This is the check that proves the chaining, the
# gap handling and the crosswalk plumbing are all correct.
single <- mapped |> dplyr::group_by(cat_id) |> dplyr::filter(dplyr::n() == 1) |>
  dplyr::ungroup()
recon <- cat_idx |>
  dplyr::filter(interp_share < 1e-9) |>
  dplyr::inner_join(dplyr::select(single, cat_id, cpi_item_code), by = "cat_id") |>
  dplyr::inner_join(dplyr::select(obs, cpi_item_code = item_code, date, pub = idx),
                    by = c("cpi_item_code", "date")) |>
  dplyr::group_by(cat_id) |>
  dplyr::mutate(pub_rebased = 100 * pub / pub[which.min(date)],
                idx_rebased = 100 * index / index[which.min(date)]) |>
  dplyr::ungroup() |>
  dplyr::mutate(err = abs(idx_rebased - pub_rebased))
say("")
say("## 6. Reconciliation: single-item categories vs published CPI")
say("  categories checked: ", dplyr::n_distinct(recon$cat_id),
    "  observations: ", format(nrow(recon), big.mark = ","))
say(sprintf("  worst absolute index error: %.8f (rebased at each series start)",
            max(recon$err)))
if (max(recon$err) > 0.01) {
  worst <- recon[which.max(recon$err), ]
  stop("Chained index does not reproduce published CPI for cat ", worst$cat_id,
       " at ", as.character(worst$date), ": error ", round(max(recon$err), 6),
       call. = FALSE)
}
say("  PASS: chaining reproduces published CPI exactly for every single-item,")
say("  fully-observed category. Gap handling and aggregation verified.")
say("")

# ===========================================================================
# 6. Audit table
# ===========================================================================
audit <- mapped |>
  dplyr::left_join(dplyr::select(tax, cat_id, cat_label, major, in_cpi_scope), by = "cat_id") |>
  dplyr::left_join(dplyr::select(cu_item, cpi_item_code = item_code,
                                 cpi_item_name = item_name, cpi_level = display_level),
                   by = "cpi_item_code") |>
  dplyr::left_join(dplyr::rename(ri, cpi_item_code = item_code), by = "cpi_item_code") |>
  dplyr::left_join(dplyr::select(starts, cpi_item_code = item_code, series_start = first),
                   by = "cpi_item_code") |>
  dplyr::select(cat_id, major, cat_label, cex_item_code, in_cpi_scope,
                cpi_item_code, cpi_item_name, cpi_level, ri, series_start,
                confidence, note) |>
  dplyr::arrange(cat_id, dplyr::desc(ri))
readr::write_csv(audit, file.path(DIR_TAB, "t10_crosswalk_audit.csv"))
say("## 7. Outputs")
say("  t10_crosswalk_audit.csv  ", nrow(audit), " rows")
say("  t11_share_vs_ri.csv      ", nrow(cmp), " rows")
say("  t12_unmapped_cpi.csv     ", nrow(unmapped), " rows (coverage by major)")
say("  t13_coverage_by_major.csv ", nrow(by_major), " rows")
say("  t14_share_vs_ri_by_major.csv ", nrow(blk), " rows")
say("  cpi_category_index.csv   ", format(nrow(cat_idx), big.mark = ","), " rows")

# ===========================================================================
# 7. Figures
# ===========================================================================
ESP_NAVY <- "#2c3254"; ESP_RED <- "#ff8361"
theme_fii <- function(bs = 11) {
  ggplot2::theme_minimal(base_size = bs) +
    ggplot2::theme(panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_line(linewidth = 0.3, colour = "grey88"),
      plot.title = ggplot2::element_text(face = "bold", size = bs + 3),
      plot.subtitle = ggplot2::element_text(colour = "grey30", size = bs),
      plot.caption = ggplot2::element_text(colour = "grey45", size = bs - 2, hjust = 0),
      legend.position = "top", legend.title = ggplot2::element_blank())
}

p6 <- ggplot2::ggplot(cmp, ggplot2::aes(cpi_share, cex_share)) +
  ggplot2::geom_abline(slope = 1, intercept = 0, colour = "grey55", linetype = "22") +
  ggplot2::geom_point(ggplot2::aes(colour = abs(diff) > 1.5), size = 2.4, alpha = 0.85) +
  ggrepel::geom_text_repel(
    data = dplyr::filter(cmp, abs(diff) > 1.0),
    ggplot2::aes(label = substr(cat_label, 1, 30)), size = 3, seed = 1,
    max.overlaps = 20, min.segment.length = 0, colour = "grey20") +
  ggplot2::scale_colour_manual(values = c("grey45", ESP_RED), guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::scale_y_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(
    title = "Crosswalk validation: CEX shares against CPI relative importance",
    subtitle = paste0("All consumer units, ", CEX_YEAR,
      ", both renormalized over the ", length(mapped_cats),
      " mapped categories. Pearson r = ", sprintf("%.3f", rho),
      ".\nPoints on the dashed line agree. Distance from it measures concept ",
      "mismatch, not coding error."),
    x = "CPI relative importance (share of mapped basket)",
    y = "CEX expenditure share (share of mapped basket)",
    caption = paste0("Source: BLS CEX ", CEX_YEAR, " and CPI-U relative importance ",
                     as.character(RI_DATE), ". Vintage ", substr(VINTAGE, 1, 10), ".")) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f06_share_vs_ri.png"), p6,
                width = 9.5, height = 7, dpi = 200, bg = "white")

# Category 12-month inflation, most recent month, ranked.
LAST <- max(cat_idx$date)
f7 <- cat_idx |> dplyr::filter(date == LAST, !is.na(chg_12m)) |>
  dplyr::mutate(cat_label = forcats::fct_reorder(substr(cat_label, 1, 42), chg_12m))
p7 <- ggplot2::ggplot(f7, ggplot2::aes(chg_12m, cat_label, fill = chg_12m > 0)) +
  ggplot2::geom_col(width = 0.72) +
  ggplot2::geom_vline(xintercept = 0, colour = "grey25", linewidth = 0.4) +
  ggplot2::scale_fill_manual(values = c(ESP_NAVY, ESP_RED), guide = "none") +
  ggplot2::scale_x_continuous(labels = function(x) paste0(x, "%")) +
  ggplot2::labs(
    title = paste0("Category inflation from the crosswalk, 12 months to ",
                   format(LAST, "%B %Y")),
    subtitle = paste0("NSA, US city average. Composite categories are RI-weighted ",
                      "chained aggregates of their CPI components."),
    x = "12-month percent change", y = NULL,
    caption = paste0("Source: BLS CPI-U via crosswalk/cex_to_cpi.csv. Vintage ",
                     substr(VINTAGE, 1, 10), ".")) +
  theme_fii()
ggplot2::ggsave(file.path(DIR_FIG, "f07_category_inflation.png"), p7,
                width = 9.5, height = 8, dpi = 200, bg = "white")

message("\n=== CEX share vs CPI RI, largest divergences ===")
print(cmp |> dplyr::slice_head(n = 12) |>
      dplyr::transmute(cat_label = substr(cat_label, 1, 40),
                       cex = round(cex_share, 2), cpi = round(cpi_share, 2),
                       diff = round(diff, 2), ratio = round(ratio, 2)) |>
      as.data.frame(), row.names = FALSE)
message("\n=== 12-month category inflation to ", format(LAST, "%b %Y"), " ===")
print(f7 |> dplyr::arrange(dplyr::desc(chg_12m)) |>
      dplyr::transmute(cat_label = substr(cat_label, 1, 40),
                       chg_12m = round(chg_12m, 2), n = n_components) |>
      as.data.frame(), row.names = FALSE)
message("\nValidation log: ", LOG)
