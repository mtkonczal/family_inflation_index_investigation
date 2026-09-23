# Phase 1 findings: budget shares by family type

**Vintage:** 2026-09-08 | **Data:** CEX 2024, LB06 | **Panel:** 1988-2024

Phase 1 asks only whether a composition story exists. It builds no price index.

---

## 1. Yes, there is a composition story, and it is bigger than expected

Families with children spend $104,849 a year per consumer unit against $56,587
for single-person and other CUs, and they allocate that budget differently
enough that a reweighted index will diverge from headline CPI.

But the largest difference is **not** children. It is **housing tenure.**

## 2. The dominant fact: tenure

2024 shares of total expenditures:

| Category | Families with children | Single and other CUs | Gap |
|---|---|---|---|
| Rented dwellings | 4.23% | 13.16% | **-8.92 pp** |
| Owned dwellings: mortgage interest | 5.94% | 3.52% | +2.42 pp |
| Owned dwellings: property taxes | 3.62% | 2.99% | +0.63 pp |
| Owned dwellings: maintenance, repairs, insurance | 3.24% | 3.58% | -0.33 pp |

Summing the three owner-occupied lines gives 12.81 percent for families against
10.09 percent for the comparison group, a gap of +2.72 pp, nowhere near enough
to offset the rent gap. Total housing is 18.58 percent for families against
24.55 percent for single and other CUs.

The rent gap is roughly seven times larger than the next biggest category gap.
It is present across the whole 1988-2024 panel and has **widened** since 2005:
the rent share for single-person and other CUs went 10.69 percent (1988), 9.83
percent (2005), 13.16 percent (2024), while the family share moved only 4.09,
3.39, 4.23.

**Why this governs the whole project.** CPI prices owner-occupied shelter via
owners' equivalent rent and renter shelter via market rent. Those two series
diverged sharply in 2021-2023, with market rent running well ahead. A group
whose budget is 13 percent rent and one whose budget is 4 percent rent will
therefore show very different measured inflation in that window, and the sign of
the family-versus-single gap will be determined by shelter methodology rather
than by anything about children.

Any Phase 3 estimate must be presented with the shelter robustness variants
side by side. A single headline number would be indefensible.

## 3. Where children actually show up

Excluding shelter, saving, and transfers, the largest 2024 gaps in share of
total expenditures:

| Category | Families | Single and other | Gap |
|---|---|---|---|
| Education | 2.76% | 1.54% | +1.22 pp |
| Personal services (childcare proxy) | 1.48% | 0.29% | +1.19 pp |
| Vehicle purchases (net outlay) | 7.26% | 6.14% | +1.13 pp |
| Food away from home | 5.30% | 4.63% | +0.67 pp |
| Fees and admissions | 1.49% | 0.87% | +0.62 pp |
| Food at home | 8.22% | 7.63% | +0.58 pp |
| Gasoline and other fuels | 3.56% | 3.25% | +0.30 pp |
| Apparel: children under 2 | 0.19% | 0.03% | +0.16 pp |

Running the other way:

| Category | Families | Single and other | Gap |
|---|---|---|---|
| Miscellaneous | 1.37% | 2.00% | -0.63 pp |
| Electricity | 2.12% | 2.63% | -0.51 pp |
| Audio and visual equipment and services | 0.96% | 1.43% | -0.46 pp |
| Tobacco | 0.28% | 0.67% | -0.38 pp |
| Health insurance | 4.51% | 4.85% | -0.34 pp |

**Rough sign intuition for 2021-2024.** Families are overweight vehicles,
gasoline, food, education, and childcare. Singles are overweight rent,
electricity, and medical. Vehicles, gasoline, and food all had large price
increases in 2021-2022; rent surged in 2022-2023. Which dominates depends on
window and shelter treatment. Do not guess; estimate it.

## 4. Families save and give more, which is not inflation

The largest single share gap in the raw data is **personal insurance and
pensions**, 14.87 percent for families versus 10.36 percent for single and
other CUs, +4.51 pp. Cash contributions run the other way, -1.07 pp.

Both are outside CPI scope: saving and transfers, not consumption. Together the
out-of-scope block is 17.0 percent of family spending against 13.6 percent for
the comparison group. **Renormalizing onto a CPI-consistent denominator
therefore shifts shares asymmetrically by about 3.4 pp before any price enters
the calculation.** This is a methodological choice with real consequences, not
a technicality.

## 5. Childcare is not a rising share of family budgets

The childcare proxy (Personal services) has been roughly flat at 1.2 to 1.5
percent of family expenditures across the entire 1988-2024 panel (1.21 percent
in 1988, 1.30 in 2005, 1.48 in 2024). This cuts
against a common framing. Two readings, not distinguishable here:

- Childcare prices rose while quantity purchased fell, roughly offsetting.
- Or the proxy is too coarse to capture a compositional shift.

Note also that the childcare *share* being small does not make childcare
*inflation* unimportant. A 1.5 percent weight with 5 percent annual price growth
contributes about 7.5 basis points a year, small in aggregate but concentrated
on the households that pay it. The share-weighted index is the right tool for
the aggregate question and the wrong tool for the distributional one.

## 6. Infants' apparel: a data-quality warning

Apparel for children under 2 falls steadily as a share of expenditure for both
groups across the panel, from 0.36 percent to 0.19 percent for families. Part of
this is real (apparel prices fell for decades), but a 47 percent decline in
share warrants checking against CPI apparel indices before it is reported. Do
not present this as a finding without that check.

## 7. Data quality: clean

- 197 year-by-group additivity cells checked, **zero failures**, worst absolute
  gap 0.016 percent of total expenditures.
- All 41 categories present in every year-by-group cell, 1988-2024. **No
  suppression** at this granularity.
- Share sums 99.98 to 100.02 percent.

Full log: `output/tables/t00_validation.txt`.

## 8. What Phase 1 does not establish

1. **No inflation estimate.** No prices have been touched.
2. **Age is not controlled.** Families with children are prime-age; the
   comparison group spans young adults and the elderly. Part of the gap,
   especially in medical and electricity, is lifecycle. See decisions_log D-02.
3. **No standard errors.** The CEX flat files publish means only. Whether a
   0.2 pp share gap is distinguishable from sampling noise is unknown without
   PUMD replicate weights.
4. **Composition channel only.** Within-item price dispersion across households
   is unmeasurable with CPI item indices.

## 9. Recommended next step

The tenure result changes the priority order. Before building the crosswalk,
resolve shelter, because it determines the sign of the headline.

Concretely, Phase 2 should start with the LB17 housing-tenure dimension
(homeowner with mortgage, homeowner without, renter) to see how much of the
family-versus-single share gap survives conditioning on tenure. If most of the
gap is tenure, the honest framing of the whole project shifts from "families
face higher inflation" to "the inflation families face is mostly a story about
whether they own."
