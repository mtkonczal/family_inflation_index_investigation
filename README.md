# Do families face higher inflation?

A group-specific price index for households with children, built from BLS
Consumer Expenditure Survey (CEX) budget shares and CPI-U item price indices.

**Status:** Complete, revised 2026-09-25 after two methods reviews and a cumulative uncertainty correction. Phases 1,
1b, 2, 3, 4 (other dimensions), 5 (burden) and two robustness passes, written
up in [paper/family_inflation.qmd](paper/family_inflation.qmd). The first
review corrected the error bar, built the owners'-equivalent-rent basket,
added CE sampling error and re-specified the headline basket (D-27 to D-34).
The second tested comparison groups, family definitions, weight timing, a
targeted deep crosswalk and BLS's own income index, with the headline held
fixed (D-35 to D-40, [docs/review_checks.md](docs/review_checks.md)). Earlier
answers ("no measurable difference"; "statistically detectable, in families'
favour") are superseded.

---

## Answer

**No, families with children did not face higher inflation. Since December
2019 they faced slightly lower inflation than single-person and other
households, about 0.7 percentage points cumulatively, roughly 0.1 point a
year. The robust finding is that household type barely moves inflation:
against all households or married couples without children, the difference is
a few tenths of a point either way and not distinguishable from zero.**

Headline basket: the CPI concept (every mapped category, owners' equivalent
rent weighted by the CE rental-value question, medical care pooled), about 98
of 100 CPI relative-importance points. Its all-consumer-unit version tracks
published CPI-U to a mean absolute 0.10 pp on 12-month changes. The headline
family group is married couples with children (of any age) plus one parent
with a child under 18 (LB06 04 + 09).

| Dec 2019 to Jul 2026 | Families with children | Single/other CUs | Gap | 95% sampling margin (independent / year bound) |
|---|---|---|---|---|
| **CPI concept (headline)** | **29.42%** | **30.11%** | **-0.69 pp** | +/- 0.42 to 0.97 |
| Ex-shelter, medical pooled | 27.48% | 27.89% | -0.41 pp | +/- 0.55 to 1.24 |
| Range across all 9 baskets | | | -0.98 to +0.08 pp | |

The margins are approximate CE sampling error using group-level standard errors, with errors independent across survey years
(0.42) and in the worst case over any correlation (0.97). The disjoint-cell check gives 0.41 and 0.95, respectively; the headline gap is
3.3 standard errors under the first and 1.4 under the second (p = 0.15), so
"statistically distinguishable" depends on that assumption. No basket shows
families meaningfully above single households.

**Compared with whom.** The sign is a property of the comparison group
(`t38_comparators.csv`, D-37):

| Families with children minus | CPI concept | p (independent / worst case) | Ex-shelter |
|---|---|---|---|
| Single-person and other CUs | -0.69 | 0.001 / 0.15 | -0.41 |
| All other CUs | -0.32 | 0.10 / 0.47 | +0.10 |
| All CUs | -0.20 | 0.11 / 0.49 | +0.07 |
| Married couples without children | +0.20 | 0.40 / 0.71 | **+0.89** (0.004 / 0.20) |

Against childless couples, two lifecycle categories nearly cancel: they carry
more medical weight (medical lagged, +0.36 for families) and more OER weight
(OER led, -0.36).

**How robust.**

| Check | Headline gap |
|---|---|
| Baseline | -0.69 pp |
| Published-table minor-child proxy (05 + 06 + 09) | -0.84 |
| Married couples with children alone (04) | -0.79 |
| Tornqvist on contemporaneous CE weights (superlative) | -0.47 |
| CPI-W prices / seasonally adjusted CPI-U | -0.80 / -0.87 |
| Five categories split into published sub-items | -0.66 |
| Finance charges removed | -0.71 |
| Four-person minus one-person CUs | -0.41 (not significant) |

The superlative index is the largest change. The headline follows CPI's
two-year weight lag, which prices 2022-23 with pandemic-era spending; with
same-year weights the gap is a third smaller (D-38).

The 05 + 06 + 09 check is narrower than "any resident child under 18": the
married-couple cells classify by **oldest** child's age, so a couple with an
adult oldest child and a younger minor is in excluded code 07. The published
tables also cannot isolate households with a child exactly age 18. The exact
"18 or younger at home" group is not identifiable in these published tables.

**Why.** A category moves the gap only if families buy more (or less) of it
*and* its price outran (or lagged) the average (D-34). Two pieces, roughly
equal:

- *Housing.* Single/other households put 35.9 percent of spending into shelter
  against 29.6 percent for families, and shelter rose 33.5 percent against
  27.9 for everything else. Rent contributes -0.26 +/- 0.04 of the -0.69.
  Housing has economies of scale, so bigger households spend a smaller share
  on it.
- *The rest of the basket.* Education (-0.18 +/- 0.05) is mostly parents of
  college-age children; for the 05 + 06 + 09 proxy it is about zero
  once K-12 and college tuition are priced separately. Their non-housing tilt
  is apparel (-0.13), utilities (-0.07) and tobacco (-0.07). Gasoline (+0.18)
  and food (+0.08) push the other way. Vehicle purchases carry too much CE
  sampling error (+/- 0.28) to attribute in either direction.
- *Childcare contributes about zero.* Families carry about eight times the
  weight (twelve times for the 05 + 06 + 09 proxy), but day care
  prices rose 29.8 percent against 29.9 for CPI. It tracks services generally
  (2.6 percent a year in the 2010s against 2.6 for all services). The
  childcare problem is the size of the bill ($5,586 a year, 6.4 percent of
  spending, for married couples whose oldest child is under 6), not its
  inflation rate.

In 2014-2019 the gap was -1.05 pp, well outside sampling error: rent -0.68
(rent +20 percent against 9 percent overall), vehicles and gas -0.22 as car
prices fell, childcare +0.07. See `R/10_intuition.R`.

**2021-22, tested once.** The 12-month gap was positive from April 2021 to
August 2022 (peak +0.60 pp). Over December 2020 to December 2022 as a whole,
families' prices rose 0.23 pp more, not distinguishable from zero (p = 0.15).
The reversal is clear: December 2022 to December 2024, -0.65 pp, significant
under either assumption. Since December 2024, zero.

### What the reviews changed

| Earlier claim | Now |
|---|---|
| Ex-shelter headline: 25.32% vs 25.26%, gap +0.06 pp | That basket prices CEX health insurance with CPI's retained-earnings index, which fell 19% while CPI rose 30%. Demoted. CPI-concept headline: 29.42% vs 30.11%. |
| "Never escapes the method's own error bar" | The error bar covered 2013-2020 only and measured level discrepancy, not sampling noise. Replaced by CE sampling error. |
| "No measurable difference", then "statistically detectable" | Distinguishable if survey errors are independent across years, not in the worst case. |
| "The headline gap exceeds 1.96 SE in 91% of months" | Withdrawn: overlapping 12-month windows are not independent tests. One test per window instead. |
| Families faced higher inflation in 2021-22, "driven by vehicles, food and gasoline" | Not distinguishable from zero over the window; the vehicle term is too noisy to sign. |
| "Tuition above all" | A college-age-children effect. |
| Families carry five times the childcare weight | About eight times on the CE childcare items (the proxy included elder care). |
| Shelter sign "a function of shelter methodology" because rent and OER diverged | CPI rent and OER rose 33.0% and 33.9%. With OER in the basket the answer is determinate. |

### Comparison cuts on the same machinery

CPI-concept basket, cumulative since December 2019:

| Cut | Gap | 95% margin (independent / year bound) |
|---|---|---|
| Lowest minus highest income decile | **+2.06 pp** | +/- 0.90 to 1.96 |
| Lowest minus highest income quintile | **+1.84 pp** | +/- 0.59 to 1.32 |
| Families with children minus single/other | **-0.69 pp** | +/- 0.42 to 0.97 |
| Four-person minus one-person CUs | -0.41 pp | +/- 0.59 to 1.35 |
| Renters minus homeowners (2021 on, 12-month mean) | +0.03 pp | |

The income gradient is about three times the family gap and runs the other
way, led by rent and vehicle purchases, consistent in direction with Jaravel
(2021) and Argente and Lee (2021). BLS's own research index by income quintile
(R-CPI-I; Klick and Stockburger 2024), with households
ranked by size-adjusted income, shows +2.15 pp from December 2019 to December
2025 against +1.84 here. Before 2020 the two diverge (+0.28 against +1.27),
because the income rankings differ, so cite the post-2019 comparison (D-40).
Tenure, which looked like the largest gap on the old all-in basket (+4.3 pp),
all but vanishes once owners are priced with OER: renters and owners faced
nearly the same shelter inflation.

### Rates versus burdens

| Group | CPI-concept inflation | Extra non-shelter $/yr | Necessity share, with shelter |
|---|---|---|---|
| Married couple with children | 29.32% | $16,274 | 36.6% |
| Single person and other CUs | 30.11% | $8,121 | 43.3% |
| One parent, child under 18 | 30.25% | $9,485 | 43.0% |
| Lowest income quintile | 30.48% | $5,763 | 46.3% |

Extra cost is 2019 non-shelter spending at July 2026 prices on the
ex-shelter, medical-pooled index. Necessity share is food at home, utilities
and all shelter outlays (rent and owner costs) as a share of 2024 consumption.

- Married-couple families pay about twice the dollar increase of single
  households on a lower inflation rate, because they spend more.
- Per equivalent adult (square-root scale) they spend 28 percent **more** than
  single/other CUs. The earlier "19 percent less per person" ignored economies
  of scale and is withdrawn.
- One-parent households faced 0.92 pp more cumulative inflation than married
  parents (p = 0.04 with independent errors, 0.35 in the worst case; range
  +0.77 to +2.87 across baskets). Their
  necessity-share gap is 43.0 versus 36.6 percent once owner shelter costs
  count, not the 29.3 versus 16.9 the rent-only definition gave.

Do not quote any share-of-income figure for the bottom quintile: CEX reported
expenditure there is 2.38x reported income, a documented artifact.

**Author:** Mike Konczal, Economic Security Project.

---

## The question

Headline CPI-U is a single number describing the average urban household. But
households buy different baskets, and item-level inflation rates diverge. If
families with children spend a larger share of their budget on categories whose
prices rose fastest, they experienced higher inflation than the headline implies,
and vice versa.

This project measures that **composition channel** and only that channel. It
cannot measure the *price-faced* channel: within a CPI item stratum, different
households pay different prices and face different variety and quality
trajectories. Kaplan and Schulhofer-Wohl (2017) show that channel is large at
the household level. It could widen the family gap estimated here or narrow
it; nothing in this project signs it.

## Sign of the answer is not obvious

Families with children are disproportionately homeowners; single-person
households are disproportionately renters. Food away from home skews single;
food at home, vehicles, and gasoline skew family. Without owners' equivalent
rent the shelter comparison is undefined, which is why the robustness table was
specified in `METHODS.md` before the estimate was run. (An earlier version said
CPI rent and OER diverged sharply in 2021-2023. They did not: 33.0 versus 33.9
percent from December 2019 to July 2026. See D-29.)

---

## Repository layout

```
.
├── README.md                  This file
├── METHODS.md                 Methodology, scope adjustments, index formulas
├── .projroot                  Marker used by R/00_setup.R to locate the root (required)
├── R/
│   ├── 00_setup.R             Paths, constants, group definitions, helpers
│   ├── 01_download_data.R     Pull and cache CEX + CPI flat files
│   ├── 02_build_shares.R      PHASE 1: budget shares, with validation
│   ├── 03_phase1_figures.R    PHASE 1: figures and CPI-scope share table
│   ├── 04_adjusted_passes.R   PHASE 1b: ex-housing, age, tenure passes
│   ├── 05_build_crosswalk.R   PHASE 2: CEX-to-CPI crosswalk + price panel
│   ├── 06_build_index.R       PHASE 3: the index, error bar, decomposition
│   ├── 07_dimension_indices.R PHASE 4: income and tenure cuts (power test)
│   ├── 08_burden.R            PHASE 5: dollar burden, necessity shares
│   ├── 09_robustness.R        Price-input robustness: CPI-W, SA CPI-U
│   ├── 10_intuition.R         Relative-price decomposition, childcare vs services, household size
│   ├── 11_review_checks.R     REVIEW 2: definitions, comparators, weight timing, deep splits, tests
│   ├── 12_external_benchmarks.R  REVIEW 2: BLS R-CPI-I and C-CPI-U benchmarks
│   └── functions/
│       ├── cex_prep.R         Shared splice, additivity + completeness checks
│       ├── cpi_tree.R         CPI item hierarchy (codes are NOT prefix-nested)
│       ├── index_build.R      Chained Laspeyres, RI benchmark, OER, sampling SE
│       ├── ce_tables.R        Reader for CE mean/SE workbooks (SEs, rental value)
│       ├── price_panel.R      Category price panel from any CPI item source
│       └── review_checks.R    Deep pieces, cell-based sampling error, Tornqvist
├── crosswalk/
│   ├── cex_analysis_categories.csv  The 41-category taxonomy
│   └── cex_to_cpi.csv               CEX-to-CPI item mapping, with confidence
├── data/
│   ├── raw/                   BLS downloads (gitignored, reproducible; manifest tracked)
│   └── derived/               Analysis-ready tables + .vintage.txt sidecars
├── output/
│   ├── tables/                Publication tables
│   └── figures/               Publication figures
├── docs/
│   ├── data_sources.md        Exact files, dimensions, coverage, gotchas
│   ├── decisions_log.md       Every judgment call, numbered, with rationale
│   ├── phase1_findings.md     Phase 1 results and what they do not establish
│   ├── phase1b_adjusted_passes.md  Ex-housing and age-adjusted results
│   ├── phase2_crosswalk.md    Crosswalk construction and validation
│   ├── phase3_index.md        THE RESULT: the index and its error bar
│   └── review_checks.md       Second review: checks 1-8 and what they change
├── logs/                      Script run logs
└── paper/                     Quarto write-up
```

## Reproducing

Run from the project root, in order:

```bash
Rscript R/01_download_data.R
Rscript R/02_build_shares.R
Rscript R/03_phase1_figures.R
Rscript R/04_adjusted_passes.R
Rscript R/05_build_crosswalk.R
Rscript R/06_build_index.R
Rscript R/07_dimension_indices.R
Rscript R/08_burden.R
Rscript R/09_robustness.R
Rscript R/10_intuition.R
Rscript R/11_review_checks.R
Rscript R/12_external_benchmarks.R
Rscript slides/make_slide_figures.R
cd paper && quarto render family_inflation.qmd
cd ../slides && quarto render family_inflation_slides.qmd
```

`01` caches to `data/raw/*.rds` and `data/raw/ce_tables/`. Delete those files or
set `FORCE_REFRESH <- TRUE` to re-pull from BLS. The manifest is only rewritten
when the main caches are rebuilt.

### Requirements

- R 4.4+, `tidyverse`, `tidyusmacro`, `readxl`
- `BLS_EMAIL` in `.Renviron`. This is a contact address, not an API key:
  `download.bls.gov` requires an email in the User-Agent string. Falls back to
  the author's address if unset.

## Data vintage

BLS overwrites these flat files in place, so there is no version number to cite.
Every run writes `data/raw/download_manifest.txt` recording byte counts and BLS
modified timestamps, and every derived table gets a `.vintage.txt` sidecar. Cite
those, not "the current file."

As of the initial build:

- **CEX** annual means through **2024** (published ~September 2025).
- **CPI-U** monthly through **2026 M07** (August 2026 CPI is now out; not yet pulled).
- **CPI-W** pulled 2026-09-23, truncated to 2026 M07 for comparability.
- **CE mean/SE workbooks** 2012-2024 (tenure from 2019, deciles from 2014), pulled 2026-09-23.

## Key coverage constraint

CEX family-composition detail is not uniformly deep across time. For
married-couple-with-children, the `LB06` expenditure series break down as:

| Item display level | Series | Coverage |
|---|---|---|
| 0-3 (major groups, expenditure classes) | ~98 | **1988-2024** |
| 4-7 (fine detail) | ~750 | **2010-2024** |

The primary index therefore uses levels 0-3 over 1988-2024, with the deep
crosswalk run over 2010-2024 as a robustness check.

---

## Phase 1 headline result

Families with children spend $104,849 a year per consumer unit against $56,587
for single-person and other CUs, and the baskets differ enough that a reweighted
index will diverge from headline CPI. But the largest difference is **not
children. It is housing tenure.**

2024 share of total expenditures, families with children minus single and other:

| Category | Gap |
|---|---|
| Rented dwellings | **-8.92 pp** |
| Personal insurance and pensions (out of CPI scope) | +4.51 pp |
| Owned dwellings: mortgage interest | +2.42 pp |
| Education | +1.22 pp |
| Personal services (childcare proxy) | +1.19 pp |
| Vehicle purchases | +1.13 pp |

CPI prices owner shelter via owners' equivalent rent and renter shelter via
rent, and CEX published tables carry owner outlays rather than rental
equivalence. So **no family index is complete until owner shelter is priced
with OER**, which the review did with the CE rental-value question (D-29).
(The original text here said CPI rent and OER diverged sharply in 2021-2023;
they did not.)

Validation: 197 year-by-group additivity cells, zero failures, worst gap 0.016
percent. All 41 categories present in every cell, 1988-2024, no suppression.

## Phase 1b: is it just housing, or just age?

Basket dissimilarity index, the percent of budget needing reallocation to make
the two baskets identical:

| Base | Categories | Observed | Net of age | Net of tenure |
|---|---|---|---|---|
| Consumption | 39 | **13.88** | 14.26 | **10.00** |
| Shelter removed | 34 | **8.33** | 6.32 | 9.05 |
| All housing removed | 25 | **7.27** | 6.08 | 7.81 |

**Housing is roughly 40 percent of the difference, and a real basket gap
survives** (education +1.80 pp, childcare +1.83 pp, vehicles, recreation, food
on one side; health insurance, electronics, tobacco, finance charges on the
other).

**Age does not explain the gap. It runs against it.** Families average 44.3
years against 53.1, and renting falls steeply with age, so age composition
predicts families should spend *more* of their budget on rent (+1.98 pp). They
spend 10.12 pp less. The residual net of age is -12.10 pp, *larger* than the raw
gap. Because the direction of the bias is known, this survives the weakest link
in the method.

**Tenure explains 73 percent of the rent gap but only 5 to 6 percent of the
education and childcare gaps.** Homeownership is 74.6 percent for families
against 51.0 percent for the comparison group.

Consequence: Phase 3 reports several baskets. The all-in basket without OER
omits owners' shelter and should never be quoted alone; the CPI-concept basket
with OER (D-29, D-30) is the headline.

---

## Phase 2: the crosswalk

37 of 41 categories mapped onto 62 CPI item strata, 12 as composites, 4
deliberately unmapped as out of scope. Composites chain as RI-weighted modified
Laspeyres, mirroring CPI's own aggregation.

**The test that matters:** across all 25 single-item categories and 8,353
monthly observations, the chained index reproduces published CPI with a worst
absolute error of **0.00000000**.

**Coverage** is 70.72 of 100 CPI relative importance, and **93 percent of the
gap is owners' equivalent rent alone** (27.18 RI). Outside owner-occupied
shelter the crosswalk is effectively complete.

**Economic validation:** CEX all-CU shares against CPI relative importance give
Pearson 0.830 across 37 categories, rising to **0.922** excluding the six
concept mismatches flagged before the comparison ran. The largest divergence,
medical, is a within-block reallocation that cancels when pooled (CEX 10.32 vs
CPI 11.31), not a level error.

**A finding with reach beyond this project: BLS published no October 2025 CPI.**
That month carries 11 series against 380 in September, and `SA0` itself is
absent. Any real-time script assuming contiguous monthly CPI rows will produce
wrong 12-month changes for a year afterwards. Details and the two specific
traps are in [decisions_log.md](docs/decisions_log.md) D-19.

## Literature

- BLS **CPI-E** (experimental index for the elderly) is the direct
  methodological precedent and its published caveats apply here.
- Hobijn and Lagakos (2005), *Review of Income and Wealth*: canonical
  CEX-plus-CPI household-group index construction.
- Kaplan and Schulhofer-Wohl (2017), *JME*: household-level inflation from
  scanner data; the price-faced channel.
- Jaravel (2019), *QJE* and Jaravel (2021), *Annual Review of Economics*:
  product variety, innovation, and inflation inequality.
- Argente and Lee (2021), *JEEA*: cost-of-living inequality in the Great
  Recession.
- Klick and Stockburger (2024), *Monthly Labor Review*: BLS's research CPIs by
  equivalized income quintile (R-CPI-I, R-C-CPI-I), the external benchmark in
  `R/12_external_benchmarks.R`.
- Michael (1979); Hagemann (1982): early group-specific CPI work.
