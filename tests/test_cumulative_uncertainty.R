# Finite-difference check of the cumulative delta-method derivative.
# Run from the project root: Rscript tests/test_cumulative_uncertainty.R
source("R/00_setup.R")
source("R/functions/index_build.R")
source("R/functions/review_checks.R")

dates <- as.Date(c("2019-12-01", "2020-12-01", "2021-12-01"))
prices <- tibble::tibble(
  cat_id = rep(c("A", "B"), each = length(dates)),
  date = rep(dates, 2),
  index = c(100, 110, 115, 100, 100, 110)
)
w1 <- c(A = 0.5, B = 0.5)
w2 <- c(A = 0.3, B = 0.7)
link1 <- sum(w1 * c(A = 1.10, B = 1.00))
link2 <- sum(w2 * c(A = 115 / 110, B = 1.10))
idx <- tibble::tibble(date = dates, index = c(100, 100 * link1, 100 * link1 * link2))
weights <- tibble::tibble(date = rep(dates[-1], each = 2),
                          cat_id = rep(c("A", "B"), 2),
                          weight = c(w1, w2))
rse <- tibble::tibble(year = rep(c(2018L, 2019L), each = 2),
                      cat_id = rep(c("A", "B"), 2),
                      rse = c(0.1, 0, 0, 0))

# Perturb only the first vintage's expenditure for A; later-vintage weights
# remain fixed. The final-window derivative must carry the second link.
cumulative <- function(h) {
  wa <- exp(h) / (1 + exp(h))
  100 * ((wa * 1.10 + (1 - wa) * 1.00) * link2 - 1)
}
h <- 1e-5
fd <- (cumulative(h) - cumulative(-h)) / (2 * h)

se <- cum_se(idx, weights, prices, rse, dates[1], dates[3])
stopifnot(abs(unname(se["se_indep"]) - abs(fd) * 0.1) < 1e-6)

lt <- link_terms(idx, weights, prices, dates[1], dates[3])
phi <- tibble::tibble(year = rep(c(2018L, 2019L), each = 2),
                      cat_id = rep(c("A", "B"), 2), cell = "one", phi = 1)
D <- group_D(lt, phi)
got <- D$D[D$link == 1 & D$cat_id == "A"]
stopifnot(length(got) == 1, abs(got - fd) < 1e-6)

cat("Cumulative uncertainty derivatives match finite differences.\n")
