# Decisions log

Every judgment call that could change a number. Numbered, dated, with the
alternative that was rejected and why. Cite these IDs in code comments.

---

## D-01. Family definition: LB06 codes 04 + 09
**Date:** 2026-09-08 | **Phase:** 1

"Families with children" = married-couple-with-children (04) plus one-parent
with a child under 18 (09). Comparison group is single-person-and-other CUs (10).

**Rejected alternatives.**
- *LB06 02 (all married couples)*: includes childless couples, which is a
  different question.
- *LB05 size of consumer unit (one person versus four)*: cleaner cut, no
  residual categories, but confounds family status with age and retirement even
  more heavily than LB06 does.
- *LB06 05/06/07 (by oldest child age)*: kept available in the pipeline but not
  the headline. Splitting by child age divides the sample three ways and
  invites suppression.

**Known defect.** Code 10 pools genuine single-person CUs with unrelated-adult
households, and pools the young with the elderly. Code 08 ("other married
couple") is a residual excluded from both groups. See D-02.

---

## D-02. Age confound left unaddressed in Phase 1
**Date:** 2026-09-08 | **Phase:** 1 | **Status:** open

Families with children are concentrated in prime age; the comparison group
spans young adults and the elderly. Part of any measured gap is lifecycle, not
family status. The elderly carry high medical shares, which biases the health
comparison specifically.

The flat files publish LB06 (composition) and LB21 (age) **marginally only**.
There is no LB06 x LB21 cross-tab. Conditioning requires CEX PUMD microdata.

**Decision:** proceed with the unconditional comparison in Phase 1, document the
confound prominently, and treat PUMD as the escalation path if the shares
justify a paper. Do not present an unconditional gap as a causal "cost of
children" estimate.

---

## D-03. Suppressed cells: verify, never zero-fill
**Date:** 2026-09-08 | **Phase:** 1

BLS writes `-` for cells with insufficient sample; these become `NA`. The full
CEX file contains 220,493 such values.

Zero-filling `NA` and summing components to build aggregates would silently
bias any group with a small sample, which is exactly the single-parent group.

**Decision:** use only BLS-published aggregates, never component sums (see
D-04), and validate additivity to `TOTALEXP` explicitly for every year and
group. Coverage is counted and logged.

**Result:** all 41 analysis categories are present in all 197 year-by-group
cells, 1988-2024. No suppression at this granularity. **This does not hold at
deeper item levels or for narrower groups; recheck before going deeper.**

---

## D-04. Never sum CEX components; display_level is not a tree
**Date:** 2026-09-08 | **Phase:** 1

The `display_level` field in `cx.item` cannot be used to build aggregates.
Verified counterexamples in the 2024 all-CU data:

- `HHOPER` (1,921) does not equal `HHPERSRV` + `670320` + `HHOTHXPN` (2,391).
  The 470 discrepancy is exactly childcare: `HHPERSRV` *contains* `670320`
  despite both being tagged display level 2.
- `GASFUEL` carries subcategory `VEHPURCH` and display level 2, but is a
  sibling of `VEHPURCH` in the `TRANS` identity.
- `800700` (Meals as pay) and `800710` (Rent as pay) sit at level 1 under
  `FOODTOTL` and `HOUSING` but are excluded from those totals. CPI also
  excludes in-kind income, so no adjustment is needed.

**Decision:** every category in the taxonomy is a BLS-published total.
Additivity is asserted in code and the script stops on failure. Tolerance is
0.25 percent of `TOTALEXP`, which covers BLS dollar rounding; observed worst
case is 0.016 percent.

---

## D-05. Gasoline splice at 2023, GASOIL to GASFUEL
**Date:** 2026-09-08 | **Phase:** 1

`GASOIL` ("Gasoline, other fuels, and motor oil") runs 1984-2022. `GASFUEL`
("Gasoline and other fuels") runs 2023-2024.

2023 is a switch, not an overlap. That year `GASOIL` sums to $6 across all five
groups while `GASFUEL` carries the value and satisfies the `TRANS` identity
(2023 all-CU: 5,539 + 2,694 + 3,845 + 1,096 = 13,174 = `TRANS`).

**Decision:** rewrite `GASOIL` to `GASFUEL` for years before 2023 and drop the
old code entirely so it cannot be double counted. Splice diagnostics are printed
to the validation log each run.

**Residual issue:** motor oil left the aggregate at the break, creating a small
level discontinuity in 2023. Unquantified because there is no overlap year to
measure it against. Immaterial at roughly $2 per CU.

---

## D-06. Childcare proxied by HHPERSRV; the bias is conservative
**Date:** 2026-09-08 | **Phase:** 1

The childcare item `670320` exists only for 2023-2024 at the LB06 level.
Predecessors `340210` and `670310` cover 2014-2023. Only the parent `HHPERSRV`
(Personal services) spans 1984-2024.

`HHPERSRV` = childcare + elderly/invalid care + adult day care. In 2024,
childcare is 96.5 percent of it for married-with-children, 100 percent for
one-parent CUs, but only 51.5 percent for single-person and other CUs.

**Decision:** use `HHPERSRV` as the long childcare proxy and label it as a proxy
in every table, figure, and axis label.

**Direction of bias:** the proxy credits the comparison group with elderly care
as if it were childcare, which **narrows** the measured gap. Conservative in the
direction that matters. For 2014-2024 robustness, `340210` + `670310` or
`670320` can be substituted.

---

## D-07. Pooling 04 and 09 by consumer-unit counts, not simple average
**Date:** 2026-09-08 | **Phase:** 1

Married-with-children CUs (30,318k) outnumber one-parent CUs (6,161k) about five
to one in 2024, and their mean expenditure is nearly double ($113,585 versus
$61,857). A simple average of the two group means would describe no real
population.

**Decision:** weight by `CUCHARS` / `CONSUNIT` counts. Pooled 2024 total
expenditure is $104,849, correctly close to the larger group.

---

## D-08. Three scope treatments; scope_cpi_a is not a weight vector
**Date:** 2026-09-08 | **Phase:** 1

See METHODS.md section 3 for definitions.

`scope_cpi_a` removes owner mortgage interest and property taxes without
substituting owners' equivalent rent. It therefore prices renters' shelter while
hiding owners'. Because tenure is the dominant budget difference between the
groups compared, this inflates the rent gap by construction: -10.7 pp under
scope_cpi_a against -8.9 pp on raw shares.

**Decision:** publish both `share_raw` and `share_cpi` in the derived data, use
`share_raw` for all Phase 1 figures, and mark `share_cpi` as unusable for index
construction until the OER imputation in scope_cpi_b exists.

---

## D-09. Figure f01 uses raw shares and omits saving and transfers
**Date:** 2026-09-08 | **Phase:** 1

The headline figure plots `share_raw` gaps and excludes `INSPENSN` (pensions and
insurance) and `CASHCONT` (cash contributions) from the *plot*, retaining them in
the *denominator*.

**Reason:** both are saving and transfers rather than consumption, and the
pensions gap of +4.5 pp is the single largest positive gap. Leaving it in makes
the chart appear to say families face more consumer price exposure when it
actually says they save more. No renormalization is applied, so no distortion is
introduced.

Shelter is drawn on a separate panel with its own x scale. The rented-dwellings
gap of -8.9 pp would otherwise flatten every other bar to invisibility.

---

## D-10. Balanced panel starts 1988
**Date:** 2026-09-08 | **Phase:** 1

Married-with-children (04) expenditure series begin in 1988; the other groups
begin in 1984. The panel start is computed as the latest year at which every
group satisfies additivity, floored at 1988, rather than hard-coded.

**Note for Phase 3:** `cu.data.0.Current` (CPI) begins in **1997**, not 1988.
Extending the price side back to 1988 requires the `cu.data.1` through
`cu.data.20` category files. The shares panel is longer than the index will be
until that is done.

---

## D-11. Item detail held at levels 0-3
**Date:** 2026-09-08 | **Phase:** 1

For married-with-children, levels 0-3 give about 98 series from 1988; levels 4-7
give about 750 series but only from 2010, with further additions in 2011,
2013-2015, 2017, 2019, and 2021-2024.

Building from "all available items" would produce a mechanically shifting
basket. **Decision:** pin the item set to the 41-category taxonomy for the
primary series; run the deep crosswalk over 2010-2024 as a Phase 3 robustness
check only.

---

## D-12. Pass A bases: consumption, ex-shelter, ex-housing
**Date:** 2026-09-08 | **Phase:** 1b

Three renormalized bases, each additive to 100 within its own basket:

| Base | Categories | Drops |
|---|---|---|
| `consumption` | 39 | `INSPENSN`, `CASHCONT` |
| `ex_shelter` | 34 | above + `OWNMORTG`, `220211`, `OWNEXPEN`, `RNTDWELL`, `OTHLODGE` |
| `ex_housing` | 25 | above + utilities (5), household operations and furnishings (4) |

Every base excludes saving and transfers, so the comparison is consumption to
consumption throughout.

**Why two housing variants.** `ex_shelter` isolates the tenure confound.
`ex_housing` additionally removes utilities and household operations, which are
themselves tenure-dependent: renters often have utilities bundled into rent,
and owners buy more furnishings. Reporting only one would invite the objection
that the other was cherry-picked.

**Rejected alternative.** Keeping saving and transfers in the base while
dropping housing. That mixes two different exclusions and makes the resulting
shares hard to interpret.

---

## D-13. Pass B is a bounding decomposition, not an age control
**Date:** 2026-09-08 | **Phase:** 1b | **Status:** important caveat

Families with children average 44.3 years of reference-person age; the
comparison group averages 53.1. The gap is 8.8 years.

There is no `LB06 x LB04` cross-tab in the flat files (D-02). `LB06` publishes
**mean** age only, and `LB04` publishes budget shares by age bracket
**marginally**, pooled across all family types. The method used is therefore:

1. Compute the share vector at each of the six non-overlapping `LB04` brackets
   (under 25, 25-34, 35-44, 45-54, 55-64, 65+), paired with that bracket's mean
   reference-person age (21.7, 29.9, 39.6, 49.5, 59.6, 74.2).
2. Interpolate piecewise-linearly and evaluate at 44.3 and 53.1. Both targets
   are interior to the support, so no extrapolation is involved.
3. `gap_age_pred` is the difference of those two predictions.
   `gap_net_of_age = gap_total - gap_age_pred`.

**The caveat that governs interpretation.** The `LB04` age gradient is not a
pure age effect. Moving from the 35-44 bracket to the 65+ bracket also removes
children from the household. So `gap_age_pred` **absorbs part of the true
family effect**, which makes it an *upper bound* on the age contribution and
makes `gap_net_of_age` an *attenuated, conservative* estimate of the family
effect.

The childcare proxy shows this plainly: observed gap +1.45 pp, age-predicted
+0.85 pp, residual +0.60 pp. Nearly all of that "age effect" is family
composition operating through age. Do not read +0.60 as the childcare family
effect; read it as a lower bound.

**Where the logic runs the other way and is therefore informative.** For rent,
`gap_age_pred` is **+1.98 pp**: because renting falls with age and families are
younger, age composition predicts families should spend *more* of their budget
on rent than the comparison group. They spend 10.12 pp *less*. The residual is
-12.10 pp, larger than the raw gap. **Age does not explain the tenure gap; it
runs against it.** This is a genuine identification win rather than an
assumption, because the sign of the bias is known.

**Rejected alternatives.** A regression on marginal shares (unidentified, same
collinearity). Substituting married-couple-only (03) as the comparison group
(mean age 60.1, worse on age, not better).

---

## D-14. Pass C: tenure decomposition via LB17 marginals
**Date:** 2026-09-08 | **Phase:** 1b

Added because Pass A answers "what does the gap look like without housing"
but not "how much of the gap is tenure." Tenure shifts spending on utilities,
furnishings, and vehicles too, not only on shelter.

Oaxaca-style composition term:

$$\Delta^{\text{tenure}}_i = (\pi_F - \pi_N)\,(w^{\text{owner}}_i - w^{\text{renter}}_i)$$

where $\pi_g$ is group $g$'s homeownership rate from `CUCHARS`/`HOMEOWN`
(families 74.6 percent, comparison group 51.0 percent, gap 23.6 pp) and
$w^{\text{owner}}, w^{\text{renter}}$ are the `LB17` share vectors on the same
base. Verified: `LB17` owner plus renter accounts for 135,760 of 135,760 CUs.

`LB17` codes 03 and 04 (homeowner with and without mortgage) are excluded: they
are subsets of 02 and begin only in 2003, so including them would double count.

**Caveat.** The `LB17` share vectors are pooled across family types, so this is
again a marginal-based decomposition. Family renters are not single renters.
The residual `gap_net_of_ten` should be read as "the gap that survives assuming
renters of all household types allocate alike."

---

## D-15. Basket dissimilarity index as the summary statistic
**Date:** 2026-09-08 | **Phase:** 1b

Half the sum of absolute share gaps, $\tfrac{1}{2}\sum_i |w^F_i - w^N_i|$: the
fraction of the budget that would have to be reallocated to make the two
baskets identical. Standard dissimilarity index, bounded 0 to 100, invariant to
category sign, and comparable across bases with different category counts in a
way that a raw sum of gaps is not.

Reported for observed, net-of-age, and net-of-tenure gaps in
`output/tables/t09_pass_summary.csv`.

**Caveat on cross-base comparison.** Coarser baskets mechanically show lower
dissimilarity because within-category variation is hidden. The drop from 13.88
(39 categories) to 7.27 (25 categories) therefore overstates the housing
contribution somewhat. The like-for-like comparison is `ex_shelter` at 8.33
against `consumption` at 13.88, both of which retain utilities and household
operations.

---

## D-16. Crosswalk is long-format, one row per CEX-category / CPI-item pair
**Date:** 2026-09-08 | **Phase:** 2

`crosswalk/cex_to_cpi.csv`, 66 rows: 62 mappings across 37 categories, plus 4
deliberately unmapped (`OWNMORTG`, `220211`, `CASHCONT`, `INSPENSN`). Twelve
categories are composites with more than one CPI target.

Long format rather than a `cpi_item_code` column on the taxonomy, because 12 of
41 categories need several CPI items and a delimited list in one cell is not
auditable. Every row carries `confidence` (high 49 / medium 11 / low 2) and a
free-text `note` giving the reasoning.

Composites are aggregated as a chained modified Laspeyres over their
components, weighted by CPI relative importance at t-1, mirroring CPI's own
upper-level aggregation. A single-item category therefore reduces exactly to
its published CPI index, which section 6 of the validation log verifies.

---

## D-17. CPI item codes are NOT hierarchical by string prefix
**Date:** 2026-09-08 | **Phase:** 2 | **Status:** trap

The first nesting check used `startsWith()` and immediately produced a false
violation: it claimed `SAF11` (Food at home) is an ancestor of `SAF116`
(Alcoholic beverages). They are siblings under `SAF1` (Food). The trailing
digit is sequence numbering, not depth.

Ancestry is positional, as in every BLS flat file: sort by `sort_sequence`, and
an item's parent is the nearest preceding item with a strictly lower
`display_level`. Implemented in `R/functions/cpi_tree.R` with the
counterexample recorded in the header so nobody reintroduces the shortcut.

The check matters: if a parent and one of its descendants were both mapped, the
same spending would be counted twice. Verified zero real violations.

---

## D-18. CPI special aggregates overlap the primary tree and must be excluded
**Date:** 2026-09-08 | **Phase:** 2 | **Status:** trap

CPI publishes alternative groupings alongside the primary expenditure tree:
`SA0LE` (All items less energy), `SAC` (Commodities), `SAS` (Services), `SA0L2`
(All items less shelter), `SARC` (Recreation commodities), `SA311` (Apparel
less footwear), and others. In sort order they sit at display level 1 *after*
the last major group's subtree, so the positional parent rule adopts them as
children of `SAG`.

A naive coverage walk therefore reported an unmapped frontier of **1,083** out
of a possible 100.

Two fixes, in order of reliability:

1. **Authoritative coverage is computed by subtraction within each of the eight
   primary major groups** (`SAF`, `SAH`, `SAA`, `SAT`, `SAM`, `SAR`, `SAE`,
   `SAG`), whose relative importances sum to 100.000. `unmapped(M) = RI(M) -
   sum(mapped RI resolving to M)`. Exact by construction, and the script hard-
   checks that mapped plus unmapped equals 100.
2. Most special aggregates are removed by the invariant that a genuine child's
   RI never exceeds its parent's, while a special aggregate's does (`SA0LE` is
   93.6 against `SAG`'s 3.0). This is used to build the primary-tree subset.

**A recursive unmapped-item itemization was attempted and abandoned.** Some
alternative groupings (`SARC`, `SAGS`, `SA311`, `SERAS`) have RI *below* their
bogus parent and appear as childless terminal rows, so no structural rule
separates them from genuinely uncovered strata. Worse, BLS display order breaks
RI additivity at intermediate levels: `SAF116` sits under `SAF1` (Food) though
its RI belongs to `SAF` (Food and beverages), so `SAF1`'s children over-sum its
RI. The itemization reported 36.8 against a true 29.3. It was replaced with the
exact by-major table plus a direct callout of owners' equivalent rent, which is
93 percent of the uncovered basket.

---

## D-19. BLS published no October 2025 CPI; months are excluded, not interpolated
**Date:** 2026-09-08 | **Phase:** 2 | **Status:** important

October 2025 carries **11 series against 380 in September**, and `SA0` itself is
absent. No October 2025 CPI exists.

**Decision:** define the monthly grid as the months for which `SA0` is
published, and exclude any month that is not. No value is invented for October
2025. The chain is carried across the hole using the true September-to-November
relative, so index **levels** remain correct on both sides and 12-month changes
stay computable. Only the October point is missing, which is the truth.

Two consequences that were bugs before being caught:

- **Never filter out a row because its price relative spans more than one
  month.** The first implementation dropped the November 2025 observation
  because the gap was two months, which discarded the chain link entirely and
  produced a 17.5-point error against published CPI for `SEHB`.
- **Never use `lag(index, 12)` for a 12-month change on a grid with a missing
  month.** Positional lag is off by one for a full year afterwards. The change
  is computed by an explicit join on `date - months(12)`.

---

## D-20. Thin CPI series are interpolated; the interpolated weight share is recorded
**Date:** 2026-09-08 | **Phase:** 2

Five mapped components are published intermittently rather than monthly:
`SETA03` leased cars and trucks (38 filled months, including a 17-month gap in
2022), `SEHP` household operations (18), `SEGD01` legal services (14), `SEEA`
educational books and supplies (7), `SETE` motor vehicle insurance (1).

**Decision:** interpolate log-linearly in the index, only *within* each
component's own observed window (no extrapolation), and record the
RI-weighted share of each category-month that came from interpolation as
`interp_share` in `data/derived/cpi_category_index.csv`. 78 of 21,211 component
observations are filled, 0.37 percent, affecting 108 of 12,589 category-months.

The reconciliation test in section 6 of the log excludes any category-month
with `interp_share > 0`, so the exactness claim is not contaminated by filled
values.

**A related bug worth recording:** relative importance was initially joined from
observed dates only, so `ri_lag` was `NA` in exactly the interpolated months
and those category-months silently dropped out of the aggregate. RI is now
carried onto the interpolated grid as well. The hard check
"genuine mid-series holes must be 0" catches this class of error.

---

## D-21. Two mapped CPI components have been discontinued
**Date:** 2026-09-08 | **Phase:** 2 | **Status:** watch

- `SEGD01` legal services, last observation **2024-09-01** (category 39, MISC)
- `SEHP` household operations, last observation **2024-10-01** (category 15,
  HHOTHXPN)

From those dates the two composites run on weights renormalized over their
surviving components. That is the correct fallback, but it means categories 15
and 39 change composition partway through the panel. Both are small (CPI RI of
about 0.8 and 0.8) and both were already flagged medium confidence.

The script lists every component that stops before the panel end, so a future
discontinuation surfaces automatically rather than silently.

---

## D-22. Medical divergence is a within-block reallocation, so pool medical in Phase 3
**Date:** 2026-09-08 | **Phase:** 2

The largest divergence between CEX shares and CPI relative importance is
medical, and it has opposite signs within the block:

| Category | CEX share | CPI share | Diff |
|---|---|---|---|
| Medical services | 2.08 | 8.42 | **-6.33** |
| Health insurance | 6.75 | 0.84 | **+5.92** |
| Drugs | 1.10 | 1.89 | -0.80 |
| Medical supplies | 0.39 | 0.16 | +0.23 |
| **Pooled** | **10.32** | **11.31** | **-0.99** |

CEX households report out-of-pocket premiums as insurance; CPI routes most
medical spending through services and assigns health insurance a relative
importance of about 0.6. The two sources disagree about *where* medical
spending sits, not *how much* there is.

**Decision for Phase 3:** run a variant that pools categories 27 to 30 into a
single medical block. That neutralizes the single largest crosswalk divergence
at the cost of assuming medical prices move alike within the block. Report it
alongside the disaggregated version.

---

## D-23. BLS omits LB06 all-consumer-units for 2010-2013; borrowed from LB04
**Date:** 2026-09-08 | **Phase:** 3 | **Status:** upstream bug found late

`LB06` (composition of consumer unit) has **no "All Consumer Units" data for
2010-2013**: all 42 items absent for four consecutive years, while every other
demographic dimension carries them. It surfaced only when the index tried to
fetch a weight vintage and failed.

The "01" characteristic is the same universe in every dimension. Verified, not
assumed: across **10,727 item-year overlaps the maximum absolute difference
between LB06/01 and LB04/01 is exactly 0**. `cex_repair_all_cu()` asserts this
on the live data and stops if it ever fails, then fills only the missing cells
(3,438 of them). The same repair is applied to the `CUCHARS`/`CONSUNIT` counts.

**The validation gap this exposed, which matters more than the bug.** Phase 1's
additivity check passed on 197 year-by-group cells and reported no problem,
because **additivity only inspects cells that exist**. An absent cell passes
silently. `cex_assert_no_interior_gaps()` now checks that no group has a hole
inside its own first-to-last span (groups legitimately start in different
years, so a common-span test would fire spuriously). The cell count is now 201.

Re-running the whole pipeline left `t02` (Phase 1 headline), `t09` (Phase 1b
summary) and `t11` (Phase 2 validation) **byte-identical**: every published
finding used 2024, so nothing moved. Only the all-CU time series was affected.

**Lesson recorded for future work:** completeness and consistency are separate
checks. Never let a consistency check stand in for a completeness check.

---

## D-24. The error bar is a weight-source residual, and the benchmark must not be double-lagged
**Date:** 2026-09-08 | **Phase:** 3 | **Status:** load-bearing

The error bar is the mean absolute residual between two all-consumer-unit
indices built on the identical basket, formula and price series, differing only
in weight source: CEX expenditure shares against CPI's own published relative
importance.

**The trap.** Published relative importance for month t already embodies a
two-year-lagged CEX vintage, price-updated by BLS to month t. Feeding it
through the same builder with `lag_years = 2` lags it a second time, giving the
benchmark an effectively four-year-old vintage and **inflating the error bar
from 0.304 to 0.478 pp**. Since the error bar is the number the whole verdict
rests on, that would have been a serious overstatement of the noise floor in
the direction that makes a null too easy to declare.

`build_index_ri()` exists solely to hold RI at t-1 as the cost weight at t,
with no further lag and no further price updating. Its header records why.

**Why this residual and not the comparison to published CPI-U.** The gap
against headline CPI-U is larger (mean -0.367 pp, mean absolute 0.717 pp)
because the basket also omits owners' equivalent rent, 27 relative-importance
points. That conflates basket scope with weight source and is reported as
context only.

---

## D-25. Pooling medical halves the error bar and sharpens the null
**Date:** 2026-09-08 | **Phase:** 3

Pre-specified in D-22 on the strength of the Phase 2 crosswalk validation, and
it worked: the error bar falls from 0.377 to **0.143 pp** on the ex-shelter
basket, and from 0.304 to 0.137 on the all-in basket.

The family gap does not grow to meet it. Ex-shelter with medical pooled, mean
absolute gap 0.093 against an error bar of 0.143, ratio 0.65. **The tighter
instrument confirms the null rather than overturning it**, which is the
outcome that should increase confidence in it.

The pooled-medical all-in basket does cross its error bar (ratio 2.34), but
that specification carries the shelter scope artifact of D-26 and is not
headlined.

---

## D-26. The all-in rent contribution is a scope artifact, reported but not headlined
**Date:** 2026-09-08 | **Phase:** 3 | **Status:** interpretation

On the all-in basket, rent contributes a mean **-0.297 pp** to the gap, more
than the entire mean gap of -0.150 pp. Every other category contributes under
0.06 pp.

That term cannot be read as an economic finding. The all-in basket contains no
mortgage interest, no property taxes and no owners' equivalent rent: the first
two are outside CPI scope and the third has no CEX published-table counterpart.
Families are 74.6 percent homeowners against 51.0 percent for the comparison
group. So the basket assigns families a rent weight of 6.4 percent against 15.8
percent while representing almost none of the housing costs they actually bear.

**Decision:** report the all-in results in full, including the two large
offsetting episodes (+0.629 pp mean over 15 months in 2021-22, -0.486 pp over
23 months in 2022-24), and headline the ex-shelter basket. Suppressing the
all-in numbers would be dishonest; headlining them would assert something the
construction cannot support.

The episode structure is itself the evidence that shelter drives it: ex-shelter
there is **not one episode outside the error bar in 186 months**, and the
window averages are +0.063, +0.001 and -0.015 pp for 2021-22, 2023-24 and
2025-26.

---

## D-27. The error bar covered 2013-2020 only; relative importance is now filled, and the benchmark price-updates like BLS
**Date:** 2026-09-23 | **Phase:** review | **Status:** load-bearing correction

Two defects in the D-24 error bar, found in review.

1. **Coverage.** Four thin components (`SETA03`, `SEHP`, `SEGD01`, `SEEA`) have
   no published relative importance in most months after mid-2020. The RI
   aggregation required every component of a category to be present, so those
   category-months dropped out, and with them most of the benchmark. The error
   bar was estimated on **88 months, 2013-03 to 2021-01**, and then compared
   against a gap averaged over 186 months, 2011-2026. It said nothing about the
   2021-2026 inflation that the headline is about.
   **Fix:** `ri_by_category()` carries each component's RI across its own
   holes, only inside the window where its price is published (the same rule
   the price panel uses, D-20/D-21). The share of each category-month that is
   carried is recorded. Gap and error bar are now compared **on the same
   months**.
2. **Price updating.** `build_index()` price-updated the Y-2 expenditure shares
   from December Y-1 only, skipping BLS's step from the expenditure reference
   period (the Y-2 average) to December Y-1. The RI benchmark embodies that step,
   so the "weight-source" residual also contained a formula difference.
   **Fix:** `price_update = "full"` implements
   `c_i,t = s_i,V * p_i,t-1 / pbar_i,V`. The old variant is kept as `"pivot"`
   and both are reported.

Also fixed: `build_index()` documented a "longest contiguous run" of complete
months but kept every complete month. It now keeps the longest run and warns if
anything outside it is dropped.

---

## D-28. The weight-source residual is not sampling error; sampling error is now estimated
**Date:** 2026-09-23 | **Phase:** review | **Status:** changes verdict language

The D-24 error bar measures how far the all-consumer-unit index moves when CEX
shares are replaced by CPI relative importance. Most of that disagreement is
common to every CEX group (CEX's health-insurance and vehicle concepts are the
same for families and singles), so it largely differences out of a
family-minus-single gap. It is a measure of **weight-concept uncertainty in
levels**, not noise in the gap. It also moves the wrong way for a noise floor:
the worse CEX and CPI agree, the easier a null becomes.

**Decision.** Keep it, relabelled "weight-source discrepancy," and stop calling
gaps inside it "not measurable." Add the uncertainty that does apply to the gap:
CE sampling error. BLS publishes a standard error for every expenditure mean in
the calendar-year workbooks (2012 on), downloaded by `01`. The delta method
(`gap_se_12m()`, `cum_se()`) propagates them to the 12-month and cumulative gap.
Assumptions stated in `R/functions/index_build.R`: category means treated as
uncorrelated within a group; groups independent; for cumulative changes, both
uncorrelated and perfectly correlated vintages reported. This is sampling error
only. It does not cover CE under-reporting or the price-faced channel.

"Statistically indistinguishable from zero" is only used where this test
supports it.

---

## D-29. scope_cpi_b built: owners' equivalent rent weighted by the CE rental-equivalence question
**Date:** 2026-09-23 | **Phase:** review

The CE workbooks carry "Estimated monthly rental value of owned home" by
demographic group. That is the survey question BLS itself uses to weight OER in
the CPI. `add_oer()` adds category `H0` = 12 x monthly rental value, priced with
CPI `SEHC`, and removes owner outlays (category 06; 04 and 05 were never in a
basket), exactly as CPI does. Available for weight vintages 2012-2024, so OER
baskets run from January 2014.

This also corrects a factual claim in earlier write-ups: CPI rent (`SEHA`) and
OER (`SEHC`) did **not** diverge sharply in 2021-2023. From December 2019 to
July 2026 they rose 33.0 and 33.9 percent. The all-in shelter artifact came
from **omitting owners' shelter weight**, not from a rent-versus-OER price gap.

---

## D-30. Headline basket re-specified before re-estimation: CPI-concept basket, medical pooled
**Date:** 2026-09-23 | **Phase:** review | **Status:** specified before the re-run

Written before `06` was re-run with D-27 to D-29, so the headline is not chosen
after seeing results.

**Problem with the old headline.** The ex-shelter basket priced CEX health
insurance (out-of-pocket premiums, about 8 times CPI's weight) with CPI `SEME`,
a retained-earnings index that fell 19.0 percent from December 2019 to July
2026 while CPI-U rose 29.9 percent. That one series pulled the all-CU
ex-shelter index about 4.8 points below the long basket that excludes three of
the four medical categories, and it set the sign of the family gap (+0.06 ex-shelter, -0.40
medical pooled, -0.60 long basket).

**Decision.**
- **Headline:** `pm_oer_all_in`, the CPI-concept basket: every mapped category,
  medical pooled (D-22), owners' equivalent rent per D-29. About 98 of 100 CPI
  relative-importance points.
- **Co-headline:** `pm_ex_shelter`, for "do families buy a more expensive
  non-housing basket."
- Every other basket reported, and the **range** across baskets stated
  alongside any single number.
- The unpooled `ex_shelter` basket is demoted to robustness.

---

## D-31. Burden calculations: consumption base, equivalence scale, necessity share with owner shelter
**Date:** 2026-09-23 | **Phase:** review

Three defects in `08_burden.R`.

1. **Base.** Dollar cost was 2019 `TOTALEXP` times ex-shelter inflation.
   `TOTALEXP` includes Social Security and pension contributions (the largest
   family gap, +4.5 pp) and cash transfers, neither of which is bought at
   consumer prices, plus shelter, which the ex-shelter index does not price.
   **Now:** each basket's own 2019 dollars times that basket's inflation.
2. **Per person.** Per-capita spending ignores economies of scale and ranked
   families below singles. **Now:** reported per equivalent adult (square-root
   scale) alongside per capita.
3. **Necessity share.** Counted rent but not mortgage interest, property taxes
   or owner maintenance, the same tenure asymmetry the index work avoids.
   **Now:** two definitions, (a) food at home, utilities and all shelter
   outlays for owners and renters, (b) food at home and utilities only, both
   over consumption (`TOTALEXP` less pensions and cash contributions).

---

## D-32. Status of the section 7 robustness table
**Date:** 2026-09-23 | **Phase:** review

| Pre-specified variant | Status |
|---|---|
| Shelter: scope_cpi_a / scope_cpi_b with OER / drop owner shelter | all run (`all_in` / `oer_all_in` / `ex_shelter`) |
| Crosswalk depth, levels 0-7 from 2010 | **not run**: needs a hand-built ~750-item crosswalk |
| Price input CPI-W | run, `09_robustness.R` |
| Price input C-CPI-U | **not possible**: BLS publishes ~30 aggregate C-CPI-U series, none of the item strata |
| Seasonality, SA monthly | run, `09_robustness.R` |
| Group: 04+09 vs 04 alone | run (`married_kids` in `06`) |
| Group: LB05 size cut | run, `07_dimension_indices.R` |
| Lifecycle, age-conditioned | **not run**: requires PUMD |

The word "pre-registered" is dropped from the write-ups: the specification was
written down before estimation, but not deposited anywhere, and half of it was
not run on the first pass.

---

## D-33. Results of the re-estimation, and which earlier findings survive
**Date:** 2026-09-23 | **Phase:** review | **Status:** supersedes D-25, D-26 headline readings

Headline (D-30), December 2019 to July 2026: families with children 29.42
percent, single-person and other CUs 30.11 percent, **gap -0.69 pp** (95% CI
+/- 0.37 uncorrelated vintages, +/- 0.86 perfectly correlated). Range across
nine baskets -0.98 to +0.08. Mean 12-month gap -0.153 pp against a sampling SE
of 0.046 and a weight-source discrepancy of 0.095.

| Earlier finding | Status |
|---|---|
| Families do not face higher inflation | **Survives, strengthened**: if anything lower |
| "No measurable difference", gap inside the error bar | **Withdrawn**: the headline gap is small but statistically distinguishable |
| Ex-shelter 25.32 vs 25.26 percent | **Withdrawn** as a headline: health insurance artifact (D-30) |
| 2021-22 family-higher episode, 2023-24 family-lower episode | **Survives** on the headline basket (+0.43, -0.32 mean) |
| All-in rent term is a pure scope artifact (D-26) | **Revised**: with OER the rent term survives (-0.33 pp), because families' total shelter share is lower |
| Income gradient exceeds the family gap | **Survives**: +1.84 (quintile), +2.06 (decile) on the headline basket |
| Tenure gap is large and measurable | **Withdrawn**: on the CPI concept renters minus owners averages +0.03 pp; the old +4.3 was the missing-OER artifact |
| One-parent 27.17 vs married 25.10 percent | **Revised**: +0.92 pp on the headline, borderline; half the old gap was the health insurance artifact |
| Burden: $22,563 vs $11,256; 19% less per person; necessity 29.3 vs 16.9 | **Revised** (D-31): $16,274 vs $8,121 non-shelter; 28% more per equivalent adult; 43.0 vs 36.6 with owner shelter counted |

---

## D-34. Category contributions are attributed relative to average inflation
**Date:** 2026-09-23 | **Phase:** review | **Status:** changes attribution, not totals

The gap decomposition used $(w^F_i - w^N_i)\pi_i$. Because both weight vectors
sum to one, $\sum_i (w^F_i - w^N_i) = 0$, so the total is identical to
$\sum_i (w^F_i - w^N_i)(\pi_i - \bar\pi)$ for any $\bar\pi$. The per-category
pieces are not. The uncentred form credits every category families over-weight
with a positive contribution simply because its price rose, and every category
singles over-weight with a negative one. It reported childcare as +0.05 pp a
year and rent as -0.33 pp a year; neither is a sensible attribution.

**Decision.** Centre on the all-CU change (`06`, `07` 12-month decompositions;
`10_intuition.R` cumulative, link by link, exact within each weight vintage,
compounding residual reported). The uncentred form is kept as `contrib_raw`.

**What it changes.** Childcare contributes about zero since 2019: day care
rose 29.8 percent against 29.9 for CPI, and has tracked services generally
since 2010. The headline gap is roughly half shelter (rent -0.26 of -0.69) and
half the non-housing mix (education -0.18, apparel -0.11, gasoline +0.18). In
2014-2019 (gap -1.05) rent is -0.68.

---

## D-35. Second review: eight checks run beside the headline, headline unchanged
**Date:** 2026-09-23 | **Phase:** review 2 | **Status:** results in `docs/review_checks.md`

`R/11_review_checks.R` (checks 1-6, 8) and `R/12_external_benchmarks.R`
(check 7) answer a second methods review. Several results bear on the
headline (a children-under-18 definition moves it from -0.69 to -0.84; a
superlative index moves it to about -0.47). None is promoted, because each
changes empirical meaning and the choice is the author's. `11` stops unless
its "headline" variant reproduces `family_index.csv` exactly (worst 4e-13
across two baskets and six groups).

Also fixed: `cum_se()` hard-coded a two-year lag when pairing links with RSE
vintages; it now takes `lag_years`. No published number changes (every
existing call used lag 2).

---

## D-36. Sampling error built from disjoint LB06 cells; three conventions
**Date:** 2026-09-23 | **Phase:** review 2

Every LB06 group is a consumer-unit-weighted mixture of seven disjoint
published cells (03, 05, 06, 07, 08, 09, 10; they sum to all CUs exactly in
every year). A group's log mean moves with each cell's log mean in
proportion to that cell's dollar share, phi. Differentiating the cumulative
change link by link against cell log means (D-28 treats category means as
uncorrelated; that assumption is kept) gives each gap's SE with the right
covariance, including gaps between overlapping groups such as families
minus all CUs, which D-28's group-level SEs cannot handle.

Three conventions, all reported:
- **independent** vintages;
- **persistent**: each cell-category's standardized error identical in every
  vintage. Can come out *below* independent when a category's gradient
  changes sign across links, so it is not a bound;
- **bound**: link SDs added, the largest SE any correlation across vintages
  can produce.

Checks: families minus single/other on the headline gives 0.184 against
D-28's 0.188 (independent). Cell-implied RSEs are a median 0.90 of the
published all-CU RSEs and 0.96 of group 04's, so treating cells as
independent slightly understates. Sub-items without a published SE
(childcare, tuition pieces, other education) borrow the parent's RSE, which
understates their contribution intervals.

**Rejected:** D-28's `se_corr` (sum of each group's link SDs, then combined
across groups) for the new pairs: it has no covariance term for overlapping
groups.

---

## D-37. Family definition and comparison groups
**Date:** 2026-09-23 | **Phase:** review 2 | **Status:** decided: F1 (04 + 09) stays the headline; K1 reported as robustness

LB06 04 = 05 + 06 + 07, and 07 is married couples whose oldest child is 18
or older, while 09 requires a child under 18. K1 = 05 + 06 + 09 pools
families with a child under 18 by CU counts, exactly as 02 pools F1. Rental
value of owned home pools with `ce_pool()` as 06 does for F1.

Comparison groups added: all CUs (01), married couples without children
(03), and the complement of each family group within all CUs (RF = 03 + 08
+ 10; RK = 03 + 07 + 08 + 10).

Result: K1 minus single/other is -0.84 (F1 -0.69). Against childless
couples, F1 is +0.20 and K1 +0.05 (both not significant), and +0.89 / +0.63
on the ex-shelter basket. The headline sign is specific to the
single/other comparison.

---

## D-38. Weight timing: contemporaneous Laspeyres and a Tornqvist
**Date:** 2026-09-23 | **Phase:** review 2

The two-year lag (D-24) is CPI's production constraint. A retrospective
index can use CE years as they happened through 2024.

- Laspeyres with `lag_years` 1 and 0 (same price updating, "full").
- Tornqvist: for every month of year Y, ln(P_t / P_t-1) = sum_i wbar_i
  ln(p_i,t / p_i,t-1) with wbar = (s_Y-1 + s_Y) / 2 on expenditure shares.
  Fixed geometric weights inside a year telescope, so each December link is
  exactly a Tornqvist on adjacent CE years. The approximation is treating
  calendar-year shares as those of the December endpoints. An
  annual-average-price Tornqvist is reported as a check on that choice.
- After 2024, "extended" uses 2024 shares on both sides.

This is the C-CPI-U's upper-level concept on the project's 34 categories.
D-32 said C-CPI-U was impossible; that was true of BLS's item strata, not
of the superlative formula. Result: F1 minus single/other, Dec 2019 to Dec
2024, -0.67 (headline) to -0.47 (Tornqvist). All-CU Tornqvist minus
Laspeyres is -0.41 against BLS's C-CPI-U minus CPI-U of -1.35 (same sign,
coarser aggregation).

---

## D-39. Targeted deep crosswalk: five categories split into published sub-items
**Date:** 2026-09-23 | **Phase:** review 2

Instead of the ~750-item crosswalk (D-32), only the categories the review
questioned are split, using sub-items published by LB06 cell:

| Parent | Pieces (CPI price) | From |
|---|---|---|
| 14 Personal services | childcare (SEEB03); elder, invalid and adult day care (SEMD03 + SEMD02) | 2010 |
| 23 Vehicle purchases | new (SETA01); used (SETA02); other vehicles (original 23 composite) | 1988 |
| 25 Other vehicle expenses | finance charges; repair (SETC + SETD); insurance (SETE); rental, leases, licenses (SETA03 + SETA04 + SETF) | 1988 |
| 37 Education | college incl. prepaid (SEEB01); K-12 (SEEB02); vocational (SEEB04); student-loan finance charges; other (SEEA) | 2010 |
| 39 Miscellaneous | finance charges excl. mortgage and vehicle; other (original 39 composite) | 2010 |

One piece per parent is the residual (parent less listed siblings), so the
pieces add to the published parent exactly; a suppressed sibling counts as
zero and lands in the residual (logged: 100 values under 14, 148 under 37,
155 under 39, nearly all in small cells). Childcare is the residual because
its item codes change in 2013 and 2023; personal services less 340906 and
340910 equals the childcare items exactly wherever all are published.
23O keeps the new-plus-used composite because CPI's new-motorcycle series
ended in 2000.

Finance charges are interest, out of CPI scope like mortgage interest
(scope note on categories 25, 37, 39). The finance switches drop them from
the basket; when a category is not split, its price is unchanged.

Result: every piece moves the headline gap by 0.01 to 0.12 pp; all splits
with finance removed, +0.02 (F1) and +0.10 (K1). The all-CU level moves
from 29.62 to 29.93 percent, closer to published CPI-U (29.9).

---

## D-40. External benchmarks: BLS R-CPI-I and C-CPI-U
**Date:** 2026-09-23 | **Phase:** review 2

`12` downloads BLS's R-CPI-I, R-C-CPI-I and their relative importance
(bls.gov/cpi/research-series), and the C-CPI-U all-items file, to
`data/raw/external/` with a manifest.

Not like-for-like: BLS ranks households by equivalized income (divided by
the square root of household size), household-weighted, with smoothed
expenditure weights and full item-area detail; `07` uses CE LB01
before-tax income quintiles, unadjusted, on 34 categories. The comparison
therefore tests the method and the definition jointly.

Result: lowest minus highest quintile, Dec 2019 to Dec 2025, BLS +2.15,
ours +1.84; Dec 2014 to Dec 2019, BLS +0.28, ours +1.27. Annual gaps
correlate at 0.47. Our Q1 - Q5 shelter weight gap is about twice BLS's,
which points at the income definition. Cite the 2019-2025 comparison, not
our 2014-2019 gradient.

---

## D-41. Write-ups revised to the review-2 results, headline unchanged
**Date:** 2026-09-23 | **Phase:** review 2

Paper, README, executive summary, `phase3_index.md`, METHODS sections 1, 2
and 10, and the slides now:

- lead with "household type barely moves inflation" and the comparison-group
  panel;
- report significance under both the independent and worst-case conventions;
- withdraw the "91% of months" count and the 2021-22 vehicles/food/gasoline
  attribution, in favour of one test per window;
- describe the tuition term as mostly parents of college-age children;
- give the childcare weight ratio on the CE childcare items (about eight
  times, not five);
- report the superlative index and the BLS R-CPI-I benchmark;
- replace "lower bound on dispersion" with "the price-faced channel could move
  the gap either way."

F1 remains the headline family group by author decision; no headline number
changes.
