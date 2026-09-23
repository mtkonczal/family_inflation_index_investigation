# Methods

Version 0.2, revised 2026-09-23 after a methods review (decisions_log D-27 to D-33).
Vintage of results reported here: 2026-09-23 (CEX through 2024, CPI-U through 2026 M07).

---

## 1. Question and scope

Do households with children face a different inflation rate than
single-person households or the urban average?

A group-specific price index decomposes into two channels:

1. **Composition.** Groups allocate their budgets differently across items, and
   item-level inflation rates diverge.
2. **Prices faced.** Within an item stratum, households pay different prices
   and face different variety and quality trajectories.

This project measures channel 1. Channel 2 is unreachable with CPI data, because
CPI item indices are common to all households by construction. Kaplan and
Schulhofer-Wohl (2017) find channel 2 is large and roughly orthogonal to channel
1, so **estimates here are a lower bound on total dispersion across household
types.** State this in any write-up.

## 2. Group definitions

CEX dimension `LB06`, composition of consumer unit. A *consumer unit* is
roughly a household, defined by shared expenses rather than by kinship.

| Analytic group | LB06 codes | 2024 CUs (000s) | 2024 total exp. |
|---|---|---|---|
| All consumer units | 01 | 135,760 | $78,535 |
| **Families with children** | **04 + 09** | **36,479** | **$104,849** |
| Married couple with children | 04 | 30,318 | $113,585 |
| One parent, child under 18 | 09 | 6,161 | $61,857 |
| **Single person and other CUs** | **10** | **64,426** | **$56,587** |
| Married couple only | 03 | 29,434 | $88,687 |

**Pooling.** The family aggregate combines codes 04 and 09 weighted by consumer
unit counts (`CUCHARS` / `CONSUNIT`), not by simple average:

$$\bar x_{F} = \frac{\sum_{g \in \{04,09\}} n_g \bar x_g}{\sum_{g} n_g}$$

This reproduces the mean expenditure of the pooled population, which a simple
average would not, since married-with-children CUs outnumber single-parent CUs
roughly five to one.

**Two cautions on the comparison group.**

- Code 10 pools genuine single-person CUs with unrelated-adult households
  (roommates). It is not "single people."
- Code 10 also pools the young with the elderly, while families with children
  are concentrated in prime age. **Part of any measured gap is lifecycle, not
  family status.** The flat files publish `LB06` and `LB21` (age) only
  marginally, with no cross-tab, so conditioning on age requires CEX PUMD
  microdata. This is the most important unaddressed confound.

## 3. Expenditure scope: CEX is not CPI

CPI weights derive from CEX microdata but with adjustments that the published
CEX tables do not reflect. Three scope treatments are defined; Phase 1 reports
the first two.

### scope_raw
Denominator is `TOTALEXP`. All 41 categories included. Complete and additive to
100 percent. This is the honest descriptive basket and the basis of Figure f01.

### scope_cpi_a
Denominator is `TOTALEXP` less categories wholly out of CPI scope:

| Excluded | CEX code | Reason |
|---|---|---|
| Personal insurance and pensions | `INSPENSN` | Social Security contributions, pensions, life insurance. Saving, not consumption. |
| Cash contributions | `CASHCONT` | Gifts, alimony, child support, charity. Transfers, not consumption by the giving household. |
| Owned dwellings: mortgage interest | `OWNMORTG` | Financing cost. CPI replaces owner shelter outlays with owners' equivalent rent. |
| Owned dwellings: property taxes | `220211` | Excluded from CPI; subsumed into OER. |

The excluded block is **not** neutral across groups. In 2024 it is 17.0 percent
of family spending against 13.6 percent for single-person and other CUs, so
renormalization itself shifts shares asymmetrically by roughly 3.4 pp.

> **scope_cpi_a is deliberately incomplete and is NOT a usable weight vector.**
> It removes owner-occupied shelter without substituting owners' equivalent
> rent, so it prices renters' shelter while hiding owners'. Since tenure is the
> dominant budget difference between the groups being compared, `share_cpi` in
> `data/derived/cex_shares_long.csv` exaggerates the rent gap by construction
> (-10.7 pp versus -8.9 pp on raw shares). Phase 3 requires an OER imputation
> before any index is built.

### scope_cpi_b (built in review, D-29)
scope_cpi_a plus owners' equivalent rent replacing `OWNMORTG`, `220211`, and
`OWNEXPEN`. The OER weight is 12 x "Estimated monthly rental value of owned
home" from the CE calendar-year mean/SE workbooks, the same CE question BLS
uses to weight OER in CPI; it is priced with CPI `SEHC`. Available for weight
vintages 2012-2024. Validation: the implied all-CU OER-to-rent dollar ratio is
2.9 to 3.4 across 2012-2024 against 3.0 to 3.7 for the CPI relative-importance
ratio. Finance charges embedded in `VEHOTHXP`, `MISC` and `EDUCATN` are still
not removed (not separable at this level).

### Partial-scope categories, flagged not dropped

Six categories are marked `PARTIAL` in the taxonomy. The two that matter:

- **Health insurance** (`HLTHINSR`), 4.5 to 4.9 percent of spending. CEX
  reports household out-of-pocket premiums. CPI's health insurance index
  captures only retained earnings, with employer- and government-paid medical
  care out of scope. This is the largest concept mismatch after shelter.
- **Vehicle purchases** (`VEHPURCH`), 6 to 7 percent. CEX reports net outlay,
  net of trade-in; CPI prices the gross transaction value of new and used
  vehicles.

## 4. Category taxonomy

`crosswalk/cex_analysis_categories.csv`, 41 categories that partition
`TOTALEXP`. Chosen to be (i) mutually exclusive and exhaustive, (ii)
CPI-mappable, (iii) available continuously from 1988 for every group.

### Never sum CEX components

The `display_level` field in `cx.item` is **not a clean tree.** Verified
counterexamples:

- `HHPERSRV` (Personal services, level 2) *contains* `670320` (childcare, also
  level 2). Summing siblings-by-level double counts childcare.
- `GASFUEL` sits at level 2 under subcategory `VEHPURCH` while being a sibling
  of `VEHPURCH` in the real accounting identity for `TRANS`.
- `800700` (Meals as pay) and `800710` (Rent as pay) appear at level 1 under
  `FOODTOTL` and `HOUSING` but are **excluded** from those totals. They are
  in-kind income, which CPI also excludes, so no adjustment is needed.

Every aggregate used here is a BLS-published total. Additivity is verified
explicitly, not assumed.

## 5. Spliced and proxied series

### Gasoline
`GASOIL` ("Gasoline, other fuels, and motor oil") runs 1984-2022.
`GASFUEL` ("Gasoline and other fuels") runs 2023-2024. 2023 is a **switch, not
an overlap**: that year `GASOIL` collapses to about $1 per CU while `GASFUEL`
carries the value and satisfies the `TRANS` identity. The script rewrites
`GASOIL` to `GASFUEL` for years before 2023 and drops the old code so it can
never be double counted. Motor oil left the aggregate at the break, a small
level discontinuity.

### Childcare
The childcare item `670320` exists only for 2023-2024 at the `LB06` level. The
long series is its parent `HHPERSRV` (Personal services), 1984-2024, which
equals childcare plus elderly and invalid care plus adult day care.

Contamination is asymmetric, and 2024 shares of `HHPERSRV` that are childcare:

| Group | Childcare share of HHPERSRV |
|---|---|
| Married with children (04) | 96.5% |
| One parent (09) | 100% |
| All CUs (01) | 85.9% |
| **Single person and other (10)** | **51.5%** |

Using `HHPERSRV` therefore attributes elderly care to "childcare" for the
comparison group, which **narrows** the measured family-versus-single childcare
gap. The proxy is conservative in the direction that matters.

## 6. Validation regime

`output/tables/t00_validation.txt`, regenerated every run. Checks that **stop
the script** on failure:

1. **Additivity.** The 41 categories must sum to `TOTALEXP` within 0.25 percent,
   for every year and group. Result: 197 cells checked, 0 failures, worst
   absolute gap 0.016 percent.
2. **Share sums.** `share_raw` and `share_cpi` must each sum to 100 within
   tolerance per group-year. Result: 99.98 to 100.02.
3. **Taxonomy resolution.** Every item code in the taxonomy must exist in the
   CEX extract.
4. **Coverage.** Counts non-missing categories per group-year. Result: all 41
   present in every cell, 1988-2024. No suppression at this granularity.
5. **Balanced panel.** Start year is set to the latest year at which every group
   satisfies additivity, floored at 1988. Result: 1988.

Suppression deserves emphasis. BLS writes `-` for cells with insufficient
sample, and `getBLSFiles()` reports 220,493 such values across the full CEX
file. None fall in the 41 analysis categories for these five groups, but
suppression is **not random**: it hits small demographic cells and fine items
hardest. Any move to deeper item detail or narrower groups must recheck.

## 7. Index formulas (Phase 3, specified in advance)

Group-specific chained Laspeyres, matching CPI's own upper-level aggregation
(as specified before estimation; section 10 gives the implemented form):

$$\pi^g_t = \sum_i w^g_{i,t-1}\,\pi_{i,t}, \qquad
P^g_t = P^g_{t-1}\Big(\sum_i w^g_{i,t-1}\frac{p_{i,t}}{p_{i,t-1}}\Big)$$

Weight vintage lagged two years, matching CPI convention since the 2023 shift to
annual single-year weight updates: 2026 months use 2024 CEX weights.

Gap decomposition, the headline result:

$$\pi^{F}_t - \pi^{N}_t = \sum_i \big(w^{F}_i - w^{N}_i\big)\pi_{i,t}$$

### The validation that governs credibility

Build the index with `LB06 == "01"` (all CUs) and compare to published CPI-U.
The residual is the method's error bar. **If the all-CU residual is comparable
in magnitude to the family-versus-single gap, there is no result.** Report the
residual alongside every estimate.

### Robustness table, specified before estimation

| Dimension | Variants | Status (D-32) |
|---|---|---|
| Shelter | scope_cpi_a; scope_cpi_b with OER; drop owner shelter and renormalize | all run |
| Crosswalk depth | levels 0-3 (1988-) versus levels 0-7 (2010-) | **not run** |
| Price input | CPI-U; C-CPI-U (`su`); CPI-W (`cw`) | CPI-W run; C-CPI-U impossible (no item strata published) |
| Seasonality | NSA 12-month changes; SA monthly | run |
| Group definition | 04+09 versus 04 alone; `LB05` size cut | run |
| Lifecycle | age-conditioned comparison (requires PUMD) | **not run** |

The "kill criterion" above compared the gap with the weight-source residual.
The review found that yardstick answers a different question (level
uncertainty common to all groups, not noise in the gap) and added CE sampling
error; see section 10 and D-28.

## 8. Adjustment passes (Phase 1b)

`R/04_adjusted_passes.R`. Full results in `docs/phase1b_adjusted_passes.md`,
rationale in `decisions_log.md` D-12 through D-15.

### Bases
Three renormalized baskets, each additive to 100 within itself: `consumption`
(39 categories, saving and transfers excluded), `ex_shelter` (34), `ex_housing`
(25). See D-12.

### Summary statistic
Basket dissimilarity index, $\tfrac{1}{2}\sum_i |w^F_i - w^N_i|$: the percent
of budget needing reallocation to equalize the baskets. Not comparable across
bases with different category counts without the caveat in D-15.

| Base | Categories | Observed | Net of age | Net of tenure |
|---|---|---|---|---|
| Consumption | 39 | 13.88 | 14.26 | 10.00 |
| Shelter removed | 34 | 8.33 | 6.32 | 9.05 |
| All housing removed | 25 | 7.27 | 6.08 | 7.81 |

### Age adjustment
Interpolates the `LB04` age-bracket share gradient at each `LB06` group's mean
reference-person age (families 44.3, comparison group 53.1). **A bounding
decomposition, not a control**: the `LB04` gradient is contaminated by family
composition, so the age term is an upper bound and the residual is an
attenuated family effect. See D-13.

The exception, where the bound's direction makes the conclusion firm: renting
falls with age and families are younger, so age composition predicts families
should spend **more** of their budget on rent (+1.98 pp). They spend 10.12 pp
less. **Age does not explain the tenure gap; it runs against it.**

### Tenure decomposition
$\Delta^{\text{tenure}}_i = (\pi_F - \pi_N)(w^{\text{owner}}_i - w^{\text{renter}}_i)$
using `CUCHARS`/`HOMEOWN` rates (families 74.6 percent, comparison 51.0 percent)
against `LB17` share vectors. Explains 73 percent of the rent gap but only 5 to
6 percent of the education and childcare gaps. See D-14.

### Consequence for Phase 3
Report **three** headline indices, not one: all-in, ex-shelter, ex-housing. The
all-in number is dominated by the OER-versus-market-rent methodology choice and
must never be quoted alone. Ex-shelter is the defensible "do families buy a
more expensive basket" number.

## 9. The CEX-to-CPI crosswalk (Phase 2)

`crosswalk/cex_to_cpi.csv`, built and validated by `R/05_build_crosswalk.R`.
Full results in `docs/phase2_crosswalk.md`, rationale in `decisions_log.md`
D-16 through D-22.

66 rows mapping 37 of the 41 categories onto 62 CPI item strata, 12 of them
composites. Four categories are deliberately unmapped as out of scope. Every
row carries a confidence flag (high 49 / medium 11 / low 2) and a note.

### Aggregation
Composites are chained modified Laspeyres over their components, weighted by
CPI relative importance at t-1, mirroring CPI's own upper-level aggregation:

$$\frac{P_{c,t}}{P_{c,t-1}} = \sum_{j \in J(c)}
  \frac{RI_{j,t-1}}{\sum_{k \in J(c)} RI_{k,t-1}} \cdot \frac{P_{j,t}}{P_{j,t-1}}$$

A single-item category therefore reduces exactly to its published CPI index.

### Verification
Across all 25 single-item, fully-observed categories and 8,353 monthly
observations, the chained index reproduces published CPI with a worst absolute
error of **0.00000000** after rebasing at each series start. This is the check
that proves chaining, gap handling, weighting and plumbing are correct, and the
script stops if it ever fails.

### Coverage
70.72 of 100 CPI relative importance. The uncovered 29.27 is 93 percent
owners' equivalent rent (`SEHC`, 27.18); the entire non-housing residual is
about 1 RI point. Coverage is computed by subtraction within each of the eight
primary major groups, which is exact, rather than by walking the item tree.

### Economic validation
CEX all-CU shares against CPI relative importance over the mapped items:
Pearson 0.830 across 37 categories, rising to **0.922** once the six
pre-flagged concept mismatches are excluded. The largest divergence, medical,
is a within-block reallocation that cancels when medical is pooled (CEX 10.32
against CPI 11.31), not a level disagreement.

### Data hazards handled
- **No October 2025 CPI exists** (11 series against 380 in September; `SA0`
  absent). That month is excluded from the grid rather than interpolated, and
  the chain is carried across it with the true two-month relative. Never filter
  a row for spanning more than one month, and never use positional
  `lag(index, 12)` on such a grid. See D-19.
- **Five thin series are interpolated** log-linearly inside their own observed
  windows, 0.37 percent of component observations, with the interpolated weight
  share recorded per category-month. See D-20.
- **Two components are discontinued** (`SEGD01` 2024-09, `SEHP` 2024-10), so
  categories 39 and 15 change composition partway through. See D-21.
- **CPI codes are not hierarchical by string prefix** and CPI **special
  aggregates overlap the primary tree**. Both produced wrong answers before
  being caught. See D-17 and D-18.

## 10. The index (Phase 3, revised)

`R/06_build_index.R` with `R/functions/index_build.R`. Results in
`docs/phase3_index.md`, decisions in `decisions_log.md` D-23 through D-33.

### Aggregation
Chained Laspeyres with BLS-style price-updated cost weights. For month t in
year Y, expenditure shares from CEX year V = Y-2, price-updated from the
expenditure reference period (the average of year V) to t-1:

$$c_{i,t} = s_{i,V}\frac{p_{i,t-1}}{\bar p_{i,V}},\quad
w_{i,t} = \frac{c_{i,t}}{\sum_k c_{k,t}},\quad
P_t = P_{t-1}\sum_i w_{i,t}\frac{p_{i,t}}{p_{i,t-1}}$$

The pre-review code price-updated from December Y-1 only (`"pivot"`). The two,
and fixed shares, differ by under 0.1 pp in the cumulative family gap
(`t29_price_update_variants.csv`).

### Baskets
Nine, all balanced panels: `all_in` (37, no owner shelter), `ex_shelter` (34),
`ex_housing` (25), two long panels from 1998, `pm_all_in` and `pm_ex_shelter`
(medical pooled, D-22), `oer_all_in` (scope_cpi_b), and **`pm_oer_all_in`,
the headline (D-30)**: every mapped category, OER, medical pooled, about 98 CPI
relative-importance points from January 2014. **Co-headline:
`pm_ex_shelter`.** The index never changes basket composition mid-series.

### Two yardsticks
**Weight-source discrepancy** (formerly "the error bar"): the all-CU index on
CEX shares versus CPI's own relative importance, same basket, formula and
prices; mean absolute difference over the same months as the gap. After D-27
it covers 2013-2026. It measures how much the weight concept moves index
levels, most of which is common to every CEX group and differences out of a
group gap. Headline basket: 0.095 pp.

**Sampling error of the gap** (D-28): CE standard errors propagated by the
delta method, $\mathrm{Var}(\pi_g) \approx \sum_i [w_i(r_i - \pi_g)]^2
\mathrm{RSE}_i^2$, groups independent. Mean SE of the 12-month headline gap:
0.046 pp. Cumulative intervals are reported for uncorrelated and perfectly
correlated weight vintages.

### Result
Headline, December 2019 to July 2026: families with children 29.42 percent,
single-person and other CUs 30.11 percent, gap -0.69 pp (95% CI +/- 0.37 to
0.86). Across all nine baskets -0.98 to +0.08 pp. **Families did not face
higher inflation; they faced slightly lower inflation.** Roughly half is
shelter (single/other households' share 35.9 against 29.6 percent, shelter
+33.5 against +27.9 for everything else); the rest is families' tilt toward
slow-rising categories, tuition above all. Contributions are attributed in
relative-price form, $(w^F_i - w^N_i)(\pi_i - \bar\pi)$ (D-34).

## 11. Known limitations

1. **Sampling error is approximate.** The flat files have no standard errors;
   the CE workbooks do (2012 on). The delta method treats category means as
   uncorrelated within a group, and does not cover CE non-sampling error.
2. **Age confound.** Unaddressed. See section 2.
3. **Tenure is the dominant budget difference,** not children. In 2024 the
   rented dwellings share is 5.8 percent for families against 16.5 percent for
   single-person and other CUs. Once OER is added the families' total shelter
   share is still lower (29.6 against 35.9 percent of the headline basket),
   and that, not a rent-versus-OER price divergence, drives the headline gap.
4. **Composition channel only.** See section 1.
5. **Weights are annual and lagged.** CEX 2024 published around September 2025.
6. **No CEX-to-CPI concordance is published** in either flat-file directory. The
   Phase 2 crosswalk is hand-built and versioned in `crosswalk/`.
7. **CPI history.** `cu.data.0.Current` begins in 1997. Extending the index back
   to 1988 requires the `cu.data.1`-`cu.data.20` category files. The OER and
   pooled-medical baskets start in 2012-2014 (CE workbooks, CPI RI).
8. **Adjustments rest on marginal tabulations.** `LB04` and `LB17` share vectors
   are pooled across household types, so neither pass is a true within-group
   control. Mean age is not the age distribution.
9. **Age and tenure are not jointly adjusted.** They are correlated (renters
   average 44.7 years, owners 56.2), so the two adjustments are not additive
   and must not be summed.
10. **The price panel starts 1997-02, the weight panel 1988.** The index will be
    shorter than the shares until the `cu.data.1`-`cu.data.20` CPI category
    files are pulled for pre-1997 history.
11. **Owners' equivalent rent is absent from the flat files** but present in
    the CE workbooks as the rental-value question, which is now used (D-29).
    The all-in basket without it gives families a rent weight of 6.4 percent
    against 15.8 percent and represents almost none of their housing costs;
    it is reported but not headlined.
12. **Rates are not burdens.** Families spend $104,849 a year against $56,587.
    Burden figures are computed on a base that matches the index and on an
    equivalence scale (D-31); see `08_burden.R`.
