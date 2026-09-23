# ---------------------------------------------------------------------------
# 00_setup.R
# Project paths, constants, and shared helpers for the family inflation index.
# Sourced by every numbered script. Contains no side effects beyond dir creation.
# ---------------------------------------------------------------------------

suppressPackageStartupMessages({
  library(tidyverse)
  library(tidyusmacro)
})

# --- Paths -----------------------------------------------------------------
# Project root is located by walking up from the working directory until we
# find the .projroot marker. Scripts can therefore be run from anywhere.
.find_root <- function(start = getwd()) {
  d <- normalizePath(start, mustWork = TRUE)
  for (i in 1:8) {
    if (file.exists(file.path(d, ".projroot"))) return(d)
    parent <- dirname(d)
    if (identical(parent, d)) break
    d <- parent
  }
  stop("Could not find .projroot marker. Run from inside the project.", call. = FALSE)
}

PROJ      <- .find_root()
DIR_RAW   <- file.path(PROJ, "data", "raw")
DIR_DER   <- file.path(PROJ, "data", "derived")
DIR_XWALK <- file.path(PROJ, "crosswalk")
DIR_TAB   <- file.path(PROJ, "output", "tables")
DIR_FIG   <- file.path(PROJ, "output", "figures")
DIR_LOG   <- file.path(PROJ, "logs")
for (d in c(DIR_RAW, DIR_DER, DIR_XWALK, DIR_TAB, DIR_FIG, DIR_LOG)) {
  dir.create(d, showWarnings = FALSE, recursive = TRUE)
}

# --- BLS access ------------------------------------------------------------
# BLS requires a contact email in the User-Agent for download.bls.gov.
# Set BLS_EMAIL in .Renviron; this is not an API key, just a contact address.
BLS_EMAIL <- Sys.getenv("BLS_EMAIL", unset = "mike@economicsecurityproject.org")

# --- Vintage stamping ------------------------------------------------------
# Every derived artifact records when it was built. BLS revises both surveys.
VINTAGE <- format(Sys.time(), "%Y-%m-%dT%H:%M:%S%z")

stamp <- function(df) {
  attr(df, "vintage") <- VINTAGE
  df
}

#' Write a derived table with a vintage sidecar so results are traceable.
write_derived <- function(df, name, dir = DIR_DER) {
  path <- file.path(dir, paste0(name, ".csv"))
  readr::write_csv(df, path)
  writeLines(
    c(paste0("artifact: ", name),
      paste0("built_at: ", VINTAGE),
      paste0("rows: ", nrow(df)),
      paste0("cols: ", paste(names(df), collapse = ", "))),
    file.path(dir, paste0(name, ".vintage.txt"))
  )
  message("Wrote ", path, " (", nrow(df), " rows)")
  invisible(path)
}

# --- CEX group definitions -------------------------------------------------
# LB06 = "Composition of consumer unit" in the CEX time-series files.
# Codes verified against https://download.bls.gov/pub/time.series/cx/cx.characteristics
#
# Analytic groups. See docs/decisions_log.md D-01 for why these and not others.
LB06_GROUPS <- tibble::tribble(
  ~characteristics_code, ~group,          ~group_label,
  "01",                  "all_cu",        "All consumer units",
  "04",                  "married_kids",  "Married couple with children",
  "09",                  "single_parent", "One parent, child under 18",
  "10",                  "single_other",  "Single person and other CUs",
  "03",                  "married_nokids","Married couple only"
)

# Family aggregate = married-with-children + single-parent, pooled by
# population-weighted expenditure. Built in 02_build_shares.R.
FAMILY_CODES    <- c("04", "09")
NONFAMILY_CODES <- c("10")

# --- CPI-scope exclusions --------------------------------------------------
# CPI's expenditure universe is narrower than CEX "Total average annual
# expenditures". These CEX subcategories are wholly or largely out of CPI
# scope and are removed before shares are renormalized.
# See METHODS.md section 3 for the justification of each.
CEX_SUBCAT_OUT_OF_SCOPE <- c(
  "INSPENSN",  # Personal insurance and pensions: SS contributions, pensions,
               # life insurance. CPI excludes all three (saving, not consumption).
  "CASHCONT"   # Cash contributions: gifts, alimony, charity. Transfers, not
               # consumption of the giving household.
)

# Non-expenditure categories in the CEX file, never part of a share denominator.
CEX_CAT_KEEP <- "EXPEND"

