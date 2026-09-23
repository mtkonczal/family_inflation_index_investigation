# Phase 3: the family inflation index

**Vintage:** 2026-09-23 (revised; supersedes 2026-09-08) | **Script:** `R/06_build_index.R`
**Log:** `output/tables/t00d_index_validation.txt` | **Decisions:** D-23 to D-34

---

## Answer

**Families with children did not face higher inflation than single-person and
other households. Over December 2019 to July 2026 they faced slightly lower
inflation: 29.42 percent against 30.11 percent, a gap of -0.69 percentage
points** (95% sampling interval +/- 0.37 if weight vintages are uncorrelated,
+/- 0.86 if perfectly correlated).

That is about 0.1 point a year. It is statistically distinguishable from zero
and economically small. The earlier version of this document said the gap was
"not measurable"; that verdict rested on a yardstick that did not cover
2021-2026 and did not measure noise in the gap, and it is withdrawn (D-27,
D-28).

Headline basket (specified before re-estimation, D-30): the **CPI concept**,
every mapped category plus owners' equivalent rent weighted by the CE rental
value of owned homes (D-29), medical care pooled (D-22). About 98 of 100 CPI
relative-importance points. Its all-consumer-unit version tracks published
CPI-U to a mean absolute 0.10 pp on 12-month changes (mean -0.05 pp).

---

## Every basket

Cumulative change December 2019 to July 2026, families with children minus
single-person and other CUs:

| Basket | Families | Single/other | Gap | 95% CI (uncorr. / corr.) |
|---|---|---|---|---|
| **CPI concept, medical pooled (headline)** | **29.42%** | **30.11%** | **-0.69** | 0.37 / 0.86 |
| CPI concept (OER), medical unpooled | 27.46% | 28.06% | -0.61 | 0.39 / 0.90 |
| **Ex-shelter, medical pooled (co-headline)** | **27.48%** | **27.89%** | **-0.41** | 0.48 / 1.12 |
| All-in, medical pooled, no owner shelter | 27.55% | 28.41% | -0.86 | 0.43 / 1.01 |
| All-in, no owner shelter | 25.12% | 25.90% | -0.78 | 0.46 / 1.08 |
| Ex-shelter | 24.69% | 24.69% | +0.00 | 0.51 / 1.20 |
| Ex-housing | 24.91% | 24.83% | +0.08 | 0.63 / 1.47 |
| All-in, long panel | 28.67% | 29.65% | -0.98 | 0.47 / 1.10 |
| Ex-shelter, long panel | 28.76% | 29.43% | -0.66 | 0.53 / 1.23 |

**Range: -0.98 to +0.08 pp.** No basket puts families meaningfully above
single households. The two baskets near zero are the ones that price CEX
health insurance premiums (about 8 times CPI's weight) with CPI's
retained-earnings health insurance index, which fell 19.0 percent while CPI
rose 29.9 percent. That artifact also explains why their levels (about 24.7
percent) sit five points below published CPI.

### The 12-month gap

| Basket | Months | Mean gap | Mean \|gap\| | Weight-source discrepancy | Mean sampling SE | Months with \|z\| > 1.96 |
|---|---|---|---|---|---|---|
| **CPI concept, medical pooled** | 139 | **-0.153** | 0.263 | 0.095 | 0.046 | 91% |
| Ex-shelter, medical pooled | 160 | -0.046 | 0.095 | 0.133 | 0.056 | 49% |
| Ex-shelter | 186 | -0.026 | 0.114 | 0.566 | 0.062 | 51% |

The weight-source discrepancy is the D-24 "error bar", now computed over the
same months as the gap. It bounds how much the weight concept moves index
levels; it is not noise in the group gap. CE sampling error, the noise that
does apply, is about 0.05 pp.

---

## Why

Mean cost weights, 2020-2026, CPI-concept basket:

| | Rent | OER | Lodging | **Shelter** |
|---|---|---|---|---|
| Families with children | 5.3% | 22.7% | 1.6% | **29.6%** |
| Single-person and other CUs | 12.7% | 22.1% | 1.1% | **35.9%** |

Shelter rose 33.5 percent over the window against 27.9 percent for everything
else. That accounts for roughly half the gap. The other half is the
non-housing mix.

Contributions to the cumulative gap, December 2019 to July 2026, in
relative-price form (share gap x price change relative to the all-CU change,
D-34; `t32_relative_contrib.csv`):

| Category | Share gap (pp) | Price change | vs average | Contribution (pp) |
|---|---|---|---|---|
| Rented dwellings | -7.50 | +33.0% | +3.4 | -0.26 |
| Education | +1.28 | +14.3% | -15.3 | -0.18 |
| Gasoline | +0.41 | +53.3% | +23.7 | +0.18 |
| Other entertainment | +0.29 | +12.8% | -16.8 | -0.10 |
| Tobacco | -0.43 | +53.6% | +24.0 | -0.09 |
| Vehicle purchases | +1.87 | +26.6% | -3.1 | -0.08 |
| Electricity | -0.39 | +48.6% | +19.0 | -0.07 |
| Food at home | +1.07 | +33.0% | +3.4 | +0.04 |
| **Childcare** | **+1.30** | **+29.8%** | **+0.2** | **+0.00** |

Sum -0.65 plus a compounding residual of -0.03 gives the -0.69.

Childcare is the instructive case. Families carry five times the weight (1.6
percent against 0.3), but day care prices rose at the average rate, so it
contributes nothing. An earlier version of this table used (share gap x price
change) without subtracting the average, which credited childcare with +0.05
pp a year simply because its price rose at all. That form sums to the same
total but misattributes it.

The rent term survives adding OER because families' OER weight is about the
same as single households' while their rent weight is far lower. CPI rent and
OER rose 33.0 and 33.9 percent, so the result does not hinge on how owners are
priced relative to renters.

**Normal times.** December 2014 to December 2019 the gap was -1.05 pp: rent
-0.68 (rent +19.9 percent against +9.1 overall), vehicles and gas -0.22 (car
prices fell), apparel -0.10, childcare +0.07, education +0.04. On the
ex-shelter long panel, 2010-2019, the gap is +0.07: childcare (+0.28) and
tuition (+0.28), both services that outran a goods-heavy average, offset by
cars (-0.26) and tobacco and alcohol (-0.24).

---

## Episodes

Runs of three or more months with the gap beyond 1.96 sampling SEs, headline
basket:

| Window | Months | Mean gap | Peak |
|---|---|---|---|
| Dec 2014 to Apr 2018 | 41 | -0.253 | -0.392 |
| Nov 2018 to Feb 2021 | 28 | -0.204 | -0.404 |
| **Apr 2021 to Aug 2022** | 17 | **+0.432** | +0.595 |
| **Nov 2022 to Feb 2026** | 39 | **-0.321** | -0.549 |

Families did face higher inflation in the 2021-22 goods surge (vehicles, food,
gasoline), then lower in the rent catch-up. Window means: +0.27 (2021-22),
-0.40 (2023-24), -0.11 (2025-26). The latest months are back near zero.

---

## Robustness

| Check | Headline cumulative gap since Dec 2019 |
|---|---|
| Baseline, CPI-U NSA | -0.69 pp |
| CPI-W prices | -0.80 |
| Seasonally adjusted CPI-U | -0.87 |
| Price updating: full / pivot / none | -0.69 / -0.61 / -0.61 |
| Married couples with children alone (04) | -0.79 |
| Four-person minus one-person CUs (LB05) | -0.41 (CI +/- 0.51 / 1.20) |

Not run: the deep (levels 4-7) crosswalk; C-CPI-U (no item strata published);
age conditioning (needs PUMD). See D-32.

One parent minus married with children: +0.92 pp on the headline (CI
+/- 0.77 / 1.73), +0.77 to +2.87 across baskets. The large figures come from
the baskets with the health insurance artifact; single parents carry the
smallest health insurance share.

---

## What this does and does not establish

**Establishes.** Through the composition channel, families with children did
not face higher inflation than single-person households over 2019-2026; on the
CPI concept they faced about 0.7 points less, roughly half because they spend
less of their budget on shelter and half because they lean toward categories
whose prices rose slowly. The gap reverses sign across episodes and is about a third
of the income gradient measured on the same machinery (+1.8 to +2.1 pp, lowest
minus highest quintile or decile).

**Does not establish.**

1. **The price-faced channel is untouched** (Kaplan and Schulhofer-Wohl 2017).
2. **Sampling error is approximate**: delta method, category means treated as
   uncorrelated, CE non-sampling error excluded.
3. **Age is not controlled.** The flat files publish no cross-tabs.
4. **OER rests on self-reported rental value**, as CPI's own OER weight does.
5. **Rates are not burdens.** See `08_burden.R` and D-31.

---

## How to say this in public

Defensible: *"Families with children have not faced higher inflation than
single-person households. Since December 2019 prices rose about 29.4 percent
for families and 30.1 percent for single-person households. The difference is
small, and it runs the other way: single households spend more of their
budget on rent, which rose fastest."*

Also defensible: *"During the 2021-22 surge families did face somewhat higher
inflation, up to about 0.6 points on a 12-month basis, because they buy more
vehicles, food and gasoline. That reversed in 2023-24 when rent caught up."*

Not defensible: that families face systematically higher inflation; that the
difference is "zero" or "unmeasurable"; the old 25.3 percent figure.
