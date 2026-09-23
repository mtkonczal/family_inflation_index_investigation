# ---------------------------------------------------------------------------
# R/functions/ce_tables.R
#
# Reader for the BLS CE calendar-year workbooks "Annual expenditure means,
# shares, standard errors, and relative standard errors" (one per demographic
# dimension per year, 2012 on). Downloaded by 01_download_data.R into
# data/raw/ce_tables/.
#
# They supply two things the flat files cannot:
#   * standard errors of the expenditure means (flat files carry means only),
#     used for sampling error on the index gap. See decisions_log D-28.
#   * "Estimated monthly rental value of owned home", the CE rental-equivalence
#     question that CPI itself uses to weight owners' equivalent rent. Used for
#     the scope_cpi_b baskets. See decisions_log D-29.
#
# Layout differs across years (column count, "Husband and wife" before 2013,
# "CV(%)" before 2013 and "RSE" after, "Health care" versus "Healthcare"), so
# columns are found by header text and items by label regex, never by position.
# Every parsed mean is reconciled against the flat-file value by the caller.
# ---------------------------------------------------------------------------

# Item label regexes -> analysis category. Anchored; labels are normalized
# (whitespace collapsed, footnote markers stripped) before matching.
CE_ITEM_MAP <- tibble::tribble(
  ~cat_id,    ~pattern,
  "01",       "^Food at home$",
  "02",       "^Food away from home$",
  "03",       "^Alcoholic beverages$",
  "04",       "^Mortgage interest and charges$",
  "05",       "^Property taxes$",
  "06",       "^Maintenance, repairs, insurance,( and)? other expenses$",
  "07",       "^Rented dwellings$",
  "08",       "^Other lodging$",
  "09",       "^Natural gas$",
  "10",       "^Electricity$",
  "11",       "^Fuel oil and other fuels$",
  "12",       "^Telephone services$",
  "13",       "^Water and other public services$",
  "14",       "^Personal services$",
  "15",       "^Other household expenses$",
  "16",       "^Housekeeping supplies$",
  "17",       "^Household furnishings and equipment$",
  "18",       "^Men and boys$",
  "19",       "^Women and girls$",
  "20",       "^Children under 2$",
  "21",       "^Footwear$",
  "22",       "^Other apparel products and services$",
  "23",       "^Vehicle purchases \\(net outlay\\)$",
  "24",       "^Gasoline.*(motor oil|other fuels)$",
  "25",       "^Other vehicle expenses$",
  "26",       "^Public( and other)? transportation$",
  "27",       "^Health insurance$",
  "28",       "^Medical services$",
  "29",       "^Drugs$",
  "30",       "^Medical supplies$",
  "31",       "^Fees and admissions$",
  "32",       "^(Audio and visual equipment and services|Television, radios,( and)? sound equipment)$",
  "33",       "^Pets, toys, hobbies, and playground equipment$",
  "34",       "^Other entertainment supplies, equipment, and services$",
  "35",       "^Personal care products and services$",
  "36",       "^Reading$",
  "37",       "^Education$",
  "38",       "^Tobacco products and smoking supplies$",
  "39",       "^Miscellaneous$",
  "40",       "^Cash contributions$",
  "41",       "^Personal insurance and pensions$",
  "M0",       "^Health ?care$",
  "TOTALEXP", "^Average annual expenditures$",
  "RENTVAL",  "^Estimated monthly rental value of owned home$"
)

# Column header regexes -> CEX characteristics_code, per dimension.
CE_COL_MAP <- list(
  LB06 = c("01" = "^All consumer units",
           "03" = "(Married couple|Husband and wife) only",
           "04" = "(Married couple|Husband and wife) with children",
           "09" = "^One parent",
           "10" = "^Single person"),
  LB01 = c("01" = "^All consumer units", "02" = "^Lowest 20", "03" = "^Second 20",
           "04" = "^Third 20", "05" = "^Fourth 20", "06" = "^Highest 20"),
  LB15 = c("01" = "^All consumer units", "02" = "^Lowest 10", "06" = "^Fifth 10",
           "11" = "^Highest 10"),
  LB17 = c("01" = "^All consumer units", "02" = "^Homeowner.*Total",
           "03" = "^Homeowner with mortgage", "04" = "^Homeowner without mortgage",
           "05" = "^Renter"),
  LB05 = c("01" = "^All consumer units", "02" = "^One person",
           "04" = "^Two (people|persons)$", "05" = "^Three (people|persons)$",
           "06" = "^Four (people|persons)", "07" = "^Five or more")
)

CE_TABLE_STEM <- c(LB06 = "cu-composition", LB17 = "cu-housing-tenure",
                   LB01 = "cu-income-quintiles-before-taxes",
                   LB15 = "cu-income-deciles-before-taxes", LB05 = "cu-size")

.ce_norm <- function(x) {
  x <- gsub("[\r\n]+", " ", x)
  x <- gsub("\\s+", " ", trimws(x))
  sub("\\s+[a-z]/$", "", x)   # trailing footnote marker such as "b/"
}

#' Parse one workbook into a long frame of (column header, item, stat, value).
ce_read_table <- function(path) {
  x <- suppressMessages(readxl::read_excel(path, col_names = FALSE,
                                           col_types = "text"))
  lab <- .ce_norm(x[[1]])
  h0 <- which(lab == "Item")[1]
  h1 <- grep("^Number of consumer units", lab)[1]
  if (is.na(h0) || is.na(h1)) stop("Unrecognized layout: ", basename(path), call. = FALSE)
  hdr <- vapply(seq_len(ncol(x))[-1], function(j) {
    v <- .ce_norm(x[[j]][h0:(h1 - 1L)]); paste(v[!is.na(v) & nzchar(v)], collapse = " ")
  }, character(1))
  # A spanning header ("Married couple with children") sits over its Total
  # column; subgroup columns to its right carry only their own label.
  stat_words <- c("Mean", "SE", "Share", "RSE", "CV(%)")
  cur <- NA_character_; rows <- list()
  for (i in seq_along(lab)) {
    if (is.na(lab[i])) next
    if (i == h1) {
      rows[[length(rows) + 1L]] <- data.frame(item = "NCU", stat = "Mean",
        col = hdr, value = unlist(x[i, -1]), stringsAsFactors = FALSE)
      next
    }
    if (!lab[i] %in% stat_words) { cur <- lab[i]; next }
    if (is.na(cur) || !lab[i] %in% c("Mean", "SE")) next
    rows[[length(rows) + 1L]] <- data.frame(item = cur, stat = lab[i], col = hdr,
      value = unlist(x[i, -1]), stringsAsFactors = FALSE)
  }
  out <- do.call(rbind, rows)
  out$value <- suppressWarnings(as.numeric(out$value))
  # First occurrence of each label wins: expenditure items precede the income
  # and addenda blocks, and some labels ("Health care") recur in footnote blocks.
  out$ord <- seq_len(nrow(out))
  first <- stats::aggregate(ord ~ item + stat + col, out, min)
  out[out$ord %in% first$ord, c("item", "stat", "col", "value")]
}

#' Means and standard errors for one dimension across years, mapped to the
#' project's categories and CEX characteristics codes.
#'
#' @return tibble: dim, year, characteristics_code, cat_id, mean, se, rse
ce_se_panel <- function(dim, dir = file.path(DIR_RAW, "ce_tables")) {
  stem <- CE_TABLE_STEM[[dim]]; cmap <- CE_COL_MAP[[dim]]
  files <- list.files(dir, pattern = paste0("^", stem, "-\\d{4}\\.xlsx$"), full.names = TRUE)
  if (!length(files)) stop("No CE tables for ", dim, call. = FALSE)
  res <- list()
  for (f in files) {
    yr <- as.integer(sub(".*-(\\d{4})\\.xlsx$", "\\1", f))
    t <- ce_read_table(f)
    cols <- unique(t$col)
    for (cc in names(cmap)) {
      hit <- cols[grepl(cmap[[cc]], cols)]
      if (length(hit) > 1) hit <- hit[1]
      if (!length(hit)) next   # e.g. no All-CU column in the 2012 LB06 table
      tt <- t[t$col == hit, ]
      for (k in seq_len(nrow(CE_ITEM_MAP))) {
        ii <- tt[grepl(CE_ITEM_MAP$pattern[k], tt$item), ]
        if (!nrow(ii)) next
        it1 <- ii$item[1]; ii <- ii[ii$item == it1, ]
        m <- ii$value[ii$stat == "Mean"][1]; s <- ii$value[ii$stat == "SE"][1]
        res[[length(res) + 1L]] <- tibble::tibble(dim = dim, year = yr,
          characteristics_code = cc, cat_id = CE_ITEM_MAP$cat_id[k],
          label = it1, mean = m, se = if (length(s)) s else NA_real_)
      }
      n <- tt$value[tt$item == "NCU"][1]
      res[[length(res) + 1L]] <- tibble::tibble(dim = dim, year = yr,
        characteristics_code = cc, cat_id = "NCU", label = "Number of CUs (000s)",
        mean = n, se = NA_real_)
    }
  }
  out <- dplyr::bind_rows(res)
  out$rse <- out$se / out$mean
  out
}

#' Pool two or more CEX groups the way 02_build_shares.R pools families
#' (consumer-unit-count weighted means). Standard errors combine as for a
#' weighted sum of independent estimates: the groups are disjoint samples.
ce_pool <- function(panel, codes, new_code) {
  n <- panel |> dplyr::filter(cat_id == "NCU", characteristics_code %in% codes) |>
    dplyr::select(year, characteristics_code, n = mean)
  panel |>
    dplyr::filter(cat_id != "NCU", characteristics_code %in% codes) |>
    dplyr::inner_join(n, by = c("year", "characteristics_code")) |>
    dplyr::summarise(mean = sum(n * mean) / sum(n),
                     se = sqrt(sum((n * se)^2)) / sum(n),
                     n_groups = dplyr::n(), .by = c(dim, year, cat_id)) |>
    dplyr::filter(n_groups == length(codes)) |>
    dplyr::mutate(characteristics_code = new_code, rse = se / mean) |>
    dplyr::select(-n_groups)
}
