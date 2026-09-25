# Phase 3: the family inflation index

**Vintage:** 2026-09-23 (revised after review 2; supersedes earlier 2026-09-23 and 2026-09-08 versions)
**Scripts:** `R/06_build_index.R`, `R/11_review_checks.R`, `R/12_external_benchmarks.R`
**Logs:** `output/tables/t00d_index_validation.txt`, `t00i_review_checks.txt`, `t00j_external_benchmarks.txt`
**Decisions:** D-23 to D-40. Review-2 detail: `docs/review_checks.md`.

---

## Answer

**Families with children did not face higher inflation than single-person and
other households. Over December 2019 to July 2026 they faced slightly lower
inflation: 29.42 percent against 30.11 percent, a gap of -0.69 percentage
points.** The 95% sampling interval is +/- 0.37 if CE errors are independent
across survey years and +/- 0.86 in the worst case over any correlation.

That is about 0.1 point a year and economically small. It is 3.7 standard
errors under independent errors and 1.6 in the worst case (p = 0.11), so
"statistically distinguishable" depends on that assumption. On a superlative
index with contemporaneous weights it is about -0.47. Its sign is specific to
this comparison group. Against all households the gap is -0.20, and against
married couples without children +0.20, neither distinguishable from zero. The
robust statement is that household type barely moves inflation.

Headline basket (specified before re-estimation, D-30): the **CPI concept**,
every mapped category plus owners' equivalent rent weighted by the CE rental
value of owned homes (D-29), medical care pooled (D-22). About 98 of 100 CPI
relative-importance points. Its all-consumer-unit version tracks published
CPI-U to a mean absolute 0.10 pp on 12-month changes (mean -0.05 pp). Headline
families are LB06 04 + 09: married couples with children of any age, plus one
parent with a child under 18.

---

## Every basket

Cumulative change December 2019 to July 2026, families with children minus
single-person and other CUs:

| Basket | Families | Single/other | Gap | 95% CI (independent / worst case) |
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
single households.

- **The two baskets near zero** price CEX health insurance premiums (about 8
  times CPI's weight) with CPI's retained-earnings health insurance index,
  which fell 19.0 percent while CPI rose 29.9 percent. That artifact also
  explains why their levels (about 24.7 percent) sit five points below
  published CPI.
- **The other seven baskets** run from -0.41 to -0.98. They share survey
  samples, so this is robustness to specification, not to sampling.

### The 12-month gap

| Basket | Months | Mean gap | Mean \|gap\| | Weight-source discrepancy | Mean sampling SE |
|---|---|---|---|---|---|
| **CPI concept, medical pooled** | 139 | **-0.153** | 0.263 | 0.095 | 0.046 |
| Ex-shelter, medical pooled | 160 | -0.046 | 0.095 | 0.133 | 0.056 |
| Ex-shelter | 186 | -0.026 | 0.114 | 0.566 | 0.062 |

The weight-source discrepancy is the D-24 "error bar", computed over the same
months as the gap. It bounds how much the weight concept moves index levels;
it is not noise in the group gap.

An earlier version counted the months in which the 12-month gap exceeded 1.96
SEs (91 percent on the headline). That count is withdrawn: overlapping
12-month windows share most of their data and one weight vintage, so they are
not separate tests. Significance is tested once per cumulative window below.

---

## Comparison groups and family definitions (review 2, D-37)

Cumulative December 2019 to July 2026, CPI-concept basket; p-values with
independent errors / worst case (`t37`, `t38`):

| Gap | CPI concept | p | Ex-shelter | p |
|---|---|---|---|---|
| Families minus single/other | -0.69 | <0.001 / 0.11 | -0.41 | 0.09 / 0.46 |
| Families minus all other CUs | -0.32 | 0.06 / 0.42 | +0.10 | 0.66 / 0.85 |
| Families minus all CUs | -0.20 | 0.07 / 0.44 | +0.07 | 0.60 / 0.82 |
| Families minus married, no children | +0.20 | 0.33 / 0.68 | +0.89 | 0.001 / 0.16 |
| Child under 18 only (05 + 06 + 09) minus single/other | -0.84 | <0.001 / 0.08 | -0.67 | 0.01 / 0.29 |

Against childless couples, two lifecycle categories nearly cancel on the full
basket:

- **Medical, +0.36.** Childless couples, averaging 60 years old, carry more
  medical weight, and medical prices lagged.
- **Owners' housing, -0.36.** Childless couples carry more OER weight, and OER
  led.

The ordering of groups tracks age and household size, through shelter and
medical care, more than children. Within families the spread is wider than
between families and anyone else: married couples whose oldest child is 6 to
17 are -1.17 against single/other, one-parent households +0.14.

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
D-34; `t32_relative_contrib.csv`), with 95% sampling intervals under
independent errors (`t42_contrib_se.csv`):

| Category | Share gap (pp) | Price change | vs average | Contribution (pp) | +/- 95% |
|---|---|---|---|---|---|
| Rented dwellings | -7.50 | +33.0% | +3.4 | -0.26 | 0.04 |
| Education | +1.28 | +14.3% | -15.3 | -0.18 | 0.05 |
| Gasoline | +0.41 | +53.3% | +23.7 | +0.18 | 0.10 |
| Other entertainment | +0.29 | +12.8% | -16.8 | -0.10 | 0.06 |
| Tobacco | -0.43 | +53.6% | +24.0 | -0.09 | 0.01 |
| Vehicle purchases | +1.87 | +26.6% | -3.1 | -0.08 | **0.28** |
| Electricity | -0.39 | +48.6% | +19.0 | -0.07 | 0.02 |
| Food at home | +1.07 | +33.0% | +3.4 | +0.04 | |
| **Childcare** | **+1.30** | **+29.8%** | **+0.2** | **+0.00** | 0.02 |

Sum -0.65 plus a compounding residual of -0.03 gives the -0.69.

**Vehicle purchases.** Their interval is wider than their contribution, so no
vehicle attribution is supported in either direction.

**Education** is mostly parents of college-age children (LB06 07):

| Group | Education contribution |
|---|---|
| Couples whose oldest child is 18+ | -0.27 |
| Families with a child under 18 | -0.13 |
| Families with a child under 18, K-12 and college tuition priced separately | -0.01 (D-39) |

For under-18 families the non-housing tilt that lowers their inflation is
apparel (-0.13), utilities (-0.07) and tobacco (-0.07).

**Childcare** is the instructive case.

- *Weight.* On the CE childcare items, families carry about eight times the
  weight single households do: 1.6 percent against 0.2. For families with a
  child under 18 it is twelve times. The index's 0.3 for single households is
  the personal-services proxy, which includes elder care.
- *Contribution.* Day care prices rose at the average rate, so childcare
  contributes nothing.
- *An earlier table's error.* It used (share gap x price change) without
  subtracting the average, which credited childcare with +0.05 pp a year
  simply because its price rose at all. That form sums to the same total but
  misattributes it.

**Rent.** The rent term survives adding OER because families' OER weight is
about the same as single households' while their rent weight is far lower.
CPI rent and OER rose 33.0 and 33.9 percent, so the result does not hinge on
how owners are priced relative to renters.

**Normal times.**

- *December 2014 to December 2019:* the gap was -1.05 pp (SE 0.06, 0.13 worst
  case): rent -0.68 (rent +19.9 percent against +9.1 overall), vehicles and
  gas -0.22 (car prices fell), apparel -0.10, childcare +0.07, education +0.04.
- *Ex-shelter long panel, 2010-2019:* the gap is +0.07. Childcare (+0.28) and
  tuition (+0.28), both services that outran a goods-heavy average, offset
  cars (-0.26) and tobacco and alcohol (-0.24).

---

## Episodes, tested once per window

Cumulative gap, families minus single/other, headline basket (`t41`):

| Window | Gap | SE (independent / worst case) | p (independent / worst case) |
|---|---|---|---|
| Dec 2014 to Dec 2019 | -1.05 | 0.06 / 0.13 | <0.001 / <0.001 |
| Dec 2019 to Jul 2026 | -0.69 | 0.18 / 0.43 | <0.001 / 0.11 |
| **Dec 2020 to Dec 2022** | **+0.23** | 0.15 / 0.22 | **0.13 / 0.28** |
| Dec 2022 to Dec 2024 | -0.65 | 0.06 / 0.09 | <0.001 / <0.001 |
| Dec 2024 to Jul 2026 | +0.01 | 0.04 / 0.06 | 0.77 / 0.83 |

**2021-22.** The 12-month gap was positive from April 2021 to August 2022
(mean +0.43, peak +0.60). Over the two years it cumulated to +0.23, not
distinguishable from zero; for families with a child under 18, +0.04. Inside
that window:

- rent is the one precisely estimated piece, +0.12 (it lagged other prices,
  and single households carry more of it);
- vehicles and gasoline are +0.19 but +/- 0.25.

**2023-24.** The reversal is not in doubt: -0.65, led by rent (-0.36).
**Since December 2024** the gap is zero.

---

## Robustness

| Check | Headline cumulative gap since Dec 2019 |
|---|---|
| Baseline, CPI-U NSA | -0.69 pp |
| CPI-W prices | -0.80 |
| Seasonally adjusted CPI-U | -0.87 |
| Price updating: full / pivot / none | -0.69 / -0.61 / -0.61 |
| Married couples with children alone (04) | -0.79 |
| Families with a child under 18 (05 + 06 + 09) | -0.84 |
| Tornqvist on contemporaneous CE weights (extended past 2024 with 2024 shares) | -0.47 |
| Five categories split into published sub-items (D-39) | -0.66 |
| Vehicle / all separable finance charges removed | -0.71 / -0.71 |
| Four-person minus one-person CUs (LB05) | -0.41 (CI +/- 0.51 / 1.20) |

**Weight timing is the largest sensitivity (D-38).** Over December 2019 to
December 2024:

| Formula | Gap |
|---|---|
| Laspeyres, two-year-old weights (headline) | -0.67 |
| Laspeyres, one-year-old weights | -0.54 |
| Laspeyres, same-year weights | -0.34 |
| Tornqvist, adjacent CE years | -0.47 |

- *Where it comes from.* Most of the difference is the 2023 link, priced in
  the headline with 2021 CE weights.
- *Before 2020 the formula barely matters:* -0.99 against -1.05.
- *All households.* The Tornqvist runs 0.41 below the Laspeyres over
  2019-2024. BLS's C-CPI-U minus CPI-U has the same sign and is larger
  (-1.35), as expected at finer aggregation.

Not run: the full item-level (levels 4-7) crosswalk; age conditioning and
household-weighted indices (need PUMD).

**One parent minus married with children:** +0.92 pp on the headline (p = 0.02
with independent errors, 0.29 in the worst case), and +0.77 to +2.87 across
baskets. The large figures come from the baskets with the health insurance
artifact; single parents carry the smallest health insurance share.

---

## What this does and does not establish

**Establishes.** Through the composition channel, families with children did
not face higher inflation than single-person households over 2019-2026, under
any basket, price input, family definition or weight timing tried. Against
single/other CUs they faced 0.5 to 0.8 points less. Roughly half of that is
their smaller shelter share, and half a non-housing tilt toward categories
whose prices rose slowly.

Against all households or childless couples the difference is within a few
tenths of a point either way. The income gradient on the same machinery is
about three times larger (+1.8 to +2.1 pp, lowest minus highest quintile or
decile). BLS's own research index by income quintile gives +2.15 over December
2019 to December 2025, against +1.84 here.

**Does not establish.**

1. **The price-faced channel is untouched** (Kaplan and Schulhofer-Wohl 2017).
   It could move the gap either way.
2. **Sampling error is approximate**: delta method, category means treated as
   uncorrelated within a CE cell, CE non-sampling error excluded, and
   correlation across survey years unknown (hence two conventions).
3. **Age is not controlled.** The flat files publish no cross-tabs; the
   comparison with childless couples shows age acting through medical care.
4. **OER rests on self-reported rental value**, as CPI's own OER weight does.
5. **Rates are not burdens.** See `08_burden.R` and D-31.

---

## How to say this in public

Defensible: *"Families with children have not faced higher inflation than
other households. Since December 2019 prices rose about 29.4 percent for
families and 30.1 percent for single-person households. Compared with all
households, or with married couples without children, the difference is a few
tenths of a point either way. What moves inflation rates is housing's share of
the budget and income, not children."*

Also defensible: *"Families' 12-month inflation ran slightly above single
households' for part of 2021-22, but over those two years the difference was
too small to distinguish from zero, and it reversed in 2023-24 when rent
caught up."*

Not defensible:

- that families face systematically higher inflation;
- that families faced *lower* inflation than households in general (true only
  against single/other CUs);
- that the 2021-22 difference was driven by vehicles, food and gasoline;
- that tuition explains the family gap for families with young children;
- the old 25.3 percent figure.
