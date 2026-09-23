# ---------------------------------------------------------------------------
# R/functions/cpi_tree.R
#
# Reconstructs the CPI item hierarchy from cu.item.
#
# WHY THIS EXISTS: CPI item codes are NOT hierarchical by string prefix. The
# obvious shortcut is wrong and silently so. Counterexample: SAF116
# (Alcoholic beverages) is a SIBLING of SAF11 (Food at home) under SAF1 (Food),
# not its child, even though "SAF116" starts with "SAF11". Any prefix-based
# ancestry test will report a false nesting violation there.
#
# The real hierarchy is encoded positionally, as in every BLS flat file: sort
# by sort_sequence, and an item's parent is the nearest preceding item with a
# strictly lower display_level.
# ---------------------------------------------------------------------------

#' Build the CPI item tree with an explicit parent column.
#'
#' @param cu_item The cu.item frame (item_code, item_name, display_level,
#'   sort_sequence).
#' @param drop_old_base Remove the pre-1967 "old base" roots (AA0, AA0R), which
#'   are parallel roots rather than part of the SA0 tree.
cpi_build_tree <- function(cu_item, drop_old_base = TRUE) {
  it <- cu_item
  if (drop_old_base) it <- it[!it$item_code %in% c("AA0", "AA0R"), , drop = FALSE]
  it <- it[order(it$sort_sequence), , drop = FALSE]
  lv <- it$display_level
  parent <- rep(NA_character_, nrow(it))
  for (i in seq_len(nrow(it))) {
    j <- i - 1L
    while (j >= 1L && lv[j] >= lv[i]) j <- j - 1L
    if (j >= 1L) parent[i] <- it$item_code[j]
  }
  it$parent <- parent
  it
}

#' Ancestors of one CPI item code, nearest first.
cpi_ancestors <- function(code, tree) {
  out <- character(0)
  p <- tree$parent[match(code, tree$item_code)]
  while (!is.na(p)) {
    out <- c(out, p)
    p <- tree$parent[match(p, tree$item_code)]
  }
  out
}

#' Which of `codes` has an ancestor that is also in `codes`?
#'
#' Returns a data frame of child/ancestor pairs. A non-empty result means the
#' set double counts: a parent and one of its descendants are both present.
cpi_nesting_violations <- function(codes, tree) {
  codes <- unique(codes[!is.na(codes)])
  res <- lapply(codes, function(c) {
    hit <- intersect(cpi_ancestors(c, tree), codes)
    if (length(hit)) data.frame(child = c, ancestor = hit, stringsAsFactors = FALSE)
       else NULL
  })
  res <- do.call(rbind, res)
  if (is.null(res)) data.frame(child = character(0), ancestor = character(0)) else res
}

#' TRUE for each of `codes` that is a descendant of any item in `covered`.
cpi_is_covered_by <- function(codes, covered, tree) {
  vapply(codes, function(c) any(cpi_ancestors(c, tree) %in% covered),
         logical(1), USE.NAMES = FALSE)
}
