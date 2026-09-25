# Second methods review: checks 1 to 8

**Vintage:** 2026-09-25 (cumulative uncertainty correction) | **Scripts:** `R/11_review_checks.R` (checks 1-6, 8),
`R/12_external_benchmarks.R` (check 7)
**Logs:** `output/tables/t00i_review_checks.txt`, `t00j_external_benchmarks.txt`
**Decisions:** D-35 to D-40

The headline specification (D-30) is **unchanged**. Every result below is a
variant reported beside it. Before anything else runs, `11` rebuilds the
headline and co-headline for six groups and stops unless they match
`family_index.csv`; they match to 4e-13. `12` rebuilds the income-quintile
index and matches `07` to 3e-14.

Unless stated, "gap" is the cumulative price change for the first group minus
the second, December 2019 to July 2026, CPI-concept basket (OER, medical
pooled), in percentage points. SEs are CE sampling error built from the seven
disjoint LB06 cells (D-36) under three conventions: **independent** weight
vintages, **persistent** errors, and a **worst-case bound** over any
correlation across vintages.

Group codes: F1 = headline families (04 + 09); K1 = published-table proxy
(05 + 06 + 09: married couples whose oldest child is under 18, plus one-parent
CUs with a child under 18); 10 = single person and other CUs; 01 = all CUs;
03 = married couples without children.

K1 omits code 07, which mixes married couples with only adult children and
couples who also have a younger minor. It also cannot isolate a child exactly
age 18. K1 is not an exact "any child age 18 or younger at home" population.

---

## Bottom line

1. **Families never come out meaningfully above single/other CUs.** That holds
   under every definition, basket, weight timing and SE convention tried. The
   headline sign stands.
2. **The size of the gap is less settled than the write-ups say.** It is
   -0.69 on the headline, -0.84 for the K1 proxy, and about -0.47 with
   contemporaneous superlative weights. Under the worst-case SE bound the
   full-window gap is not significant (p = 0.15).
3. **"Families faced lower inflation" is a statement about the comparison
   group.** Against all CUs the gap is -0.20 (p = 0.11). Against married
   couples without children it is +0.20 (not significant), and +0.89 on the
   non-housing basket (p = 0.004 independent, 0.20 bound).
4. **The 2021-22 "families higher" episode does not survive a window test.**
   Over Dec 2020 to Dec 2022 the gap is +0.23 (p = 0.15), and +0.04 for
   the K1 proxy.
5. **"Tuition above all" is about parents of college-age children,** plus a
   pricing artifact. For the K1 proxy, education
   contributes about zero once K-12 and college tuition are priced separately.
6. **Real childcare items, finance-charge removal and new/used vehicle splits
   each move the gap by 0.01 to 0.07 pp.** The childcare share ratio is 8.5x
   (12x for the K1 proxy), not the 5x in the executive summary.
7. **Against BLS's own research index, the income gradient reproduces over
   2019-2025 but not 2014-2019.** Over 2019-2025 it is +1.84 against BLS's
   +2.15. Over 2014-2019 it is +1.27 against +0.28, and the gap looks like
   the income-ranking definition, not the method.

---

## Check 1. Which families? (`t37_family_definitions.csv`)

Code 04 is 05 + 06 + 07, and 07 is married couples whose oldest child is 18
or older. It spends $129 a year on childcare.

| Group minus single/other (10) | CPI concept | SE indep / bound | Ex-shelter |
|---|---|---|---|
| F1, headline (04 + 09) | **-0.69** | 0.21 / 0.48 | -0.41 |
| **K1, published-table minor-child proxy (05 + 06 + 09)** | **-0.84** | 0.24 / 0.54 | -0.67 |
| 05 Married, oldest child under 6 | -0.55 | 0.41 / 0.95 | -0.30 |
| 06 Married, oldest child 6-17 | -1.17 | 0.29 / 0.67 | -1.08 |
| 07 Married, oldest child 18+ | -0.37 | 0.33 / 0.72 | +0.12 |
| 09 One parent, child under 18 | +0.14 | 0.44 / 0.96 | +0.55 |

Dropping adult-children couples makes the gap **larger**, not smaller. My
review hypothesis that 07 drove the result was wrong on the total. It was
right on the mechanism: education contributes -0.27 for 07 against -0.13 for
K1 (headline pricing), and -0.30 against -0.01 once tuition is priced by
level (check 8). For the K1 proxy, the non-shelter part of the
gap is:

- apparel, -0.13 ± 0.04;
- utilities, -0.07 ± 0.04;
- tobacco and alcohol, -0.07 ± 0.02;
- a vehicle term that sampling error cannot sign (-0.16 ± 0.34).

## Check 2. Compared with whom? (`t38_comparators.csv`, `f19`)

| Gap | CPI concept | p (indep / bound) | Ex-shelter | p (indep / bound) |
|---|---|---|---|---|
| F1 minus single/other | -0.69 | 0.001 / 0.15 | -0.41 | 0.13 / 0.51 |
| F1 minus all CUs | -0.20 | 0.11 / 0.49 | +0.07 | 0.64 / 0.84 |
| F1 minus all other CUs | -0.32 | 0.10 / 0.47 | +0.10 | 0.70 / 0.86 |
| F1 minus married, no children | **+0.20** | 0.40 / 0.71 | **+0.89** | 0.004 / 0.20 |
| K1 minus single/other | -0.84 | <0.001 / 0.12 | -0.67 | 0.03 / 0.34 |
| K1 minus all CUs | -0.35 | 0.04 / 0.36 | -0.18 | 0.38 / 0.70 |
| K1 minus married, no children | +0.05 | 0.84 / 0.93 | **+0.63** | 0.06 / 0.41 |

Levels (headline): married, no children 29.22%; K1 29.27%; F1 29.42%; all
CUs 29.62%; single/other 30.11%.

Against childless couples, two lifecycle categories nearly cancel:

- **Medical, +0.36 ± 0.04.** Childless couples, at a mean age of 60, carry
  more medical weight, and medical prices lagged.
- **Owners' housing, -0.36 ± 0.11.** Childless couples carry more OER weight,
  and OER led.

Education (-0.20) and apparel (-0.16) take the families' side. So the
ordering of groups reflects age and household size, through shelter and
medical, more than children.

## Check 3. Weight timing (`t39_weight_timing.csv`, `t39b_weight_timing_links.csv`)

Dec 2019 to Dec 2024, the last year with contemporaneous CE weights:

| Method | All-CU | F1 - 10 | K1 - 10 | F1 - 01 | K1 - 03 |
|---|---|---|---|---|---|
| Laspeyres, 2-year lag (headline) | 22.74% | -0.67 | -0.79 | -0.18 | +0.09 |
| Laspeyres, 1-year lag | 22.75% | -0.54 | -0.51 | -0.14 | +0.23 |
| Laspeyres, contemporaneous | 22.70% | -0.34 | -0.23 | +0.02 | +0.66 |
| **Tornqvist, CE years Y-1 and Y** | 22.33% | **-0.47** | **-0.40** | -0.07 | **+0.43** |

- **Normal times are stable.** Over Dec 2014 to Dec 2019 the Tornqvist gives
  -0.99 against -1.05.
- **Extending to July 2026** with 2024 shares for 2025-26 gives F1 - 10 of
  -0.47 and K1 - 10 of -0.42, against -0.69 and -0.84 on the headline.
- **Where the difference comes from.** Year by year, most of it sits in the
  2023 link: -0.45 lag-2 against -0.35 Tornqvist for F1 - 10. That link runs
  on 2021 CE weights in the headline. The shelter-weight gap is about 6.2 to
  6.7 pp under every method, so fresher weights shrink the gap through other
  categories, not shelter.

**Reading.** The two-year lag is a CPI production constraint that a
retrospective study does not need. On the superlative index, which is also
the C-CPI-U concept, the family-minus-single gap is about a third to a half
smaller. Families against childless couples turns positive, at about +0.4.
The sign against single/other survives.

## Check 4. Real childcare items (`t44_childcare_weights.csv`)

Childcare is personal services less elder care (340906) and adult day care
(340910). That identity holds exactly in every published year, 2010-2024.

- **Cost weights, mean 2020-2026:**

  | Group | Real childcare | Proxy |
  |---|---|---|
  | F1 | 1.57% | 1.59% |
  | K1 | 2.23% | 2.24% |
  | 05 (oldest child under 6) | 6.06% | 6.06% |
  | 10 (single/other) | 0.18% | 0.30% |

- **Ratio to single/other:** 8.5x for F1 and 12x for K1, against 5.3x on the
  proxy.
- **Effect on the gap:** -0.01. The childcare contribution is +0.005 ± 0.018.

## Check 5. Finance charges (`t40_deep_variants.csv`)

| Removal | Change in gap |
|---|---|
| Vehicle finance charges (`VEHFINCH`, 1988+) | -0.02 |
| Every separable finance charge (vehicle; credit card and other; student loan, 2010+) | -0.02 to -0.04 |

Removing them moves the gap slightly toward families. The bias I flagged in
review was real in direction and negligible in size.

## Check 6. Tests (`t41_window_tests.csv`, `t42_contrib_se.csv`)

One test per cumulative window, F1 minus single/other, headline basket:

| Window | Gap | SE indep / bound | p indep / bound |
|---|---|---|---|
| Dec 2014 - Dec 2019 | -1.05 | 0.06 / 0.13 | <0.001 / <0.001 |
| Dec 2019 - Jul 2026 | -0.69 | 0.21 / 0.48 | 0.001 / 0.15 |
| Dec 2020 - Dec 2022 | **+0.23** | 0.16 / 0.22 | **0.15 / 0.30** |
| Dec 2022 - Dec 2024 | -0.65 | 0.06 / 0.09 | <0.001 / <0.001 |
| Dec 2024 - Jul 2026 | +0.01 | 0.04 / 0.06 | 0.77 / 0.83 |

In the 2021-22 window, the gap against childless couples is +0.44
(p = 0.016 under independent vintages, 0.08 under the bound). Against all CUs
it is +0.19 (p = 0.046 independent, 0.15 bound).

**Single parents minus married parents: +0.92** (p = 0.04 independent, 0.35
bound). In the deep variant it rises to +1.95. That rise is the used-car term,
+0.91 ± 1.02, so it is noise.

Contributions to the headline gap, with 95% intervals (independent vintages):

| Block | Contribution | ± 95% |
|---|---|---|
| Rent | -0.255 | 0.042 |
| Education | -0.175 | 0.050 |
| Utilities and phone | -0.117 | 0.041 |
| Apparel | -0.107 | 0.032 |
| Alcohol and tobacco | -0.065 | 0.014 |
| Food | +0.076 | 0.051 |
| Childcare | +0.005 | 0.018 |
| Vehicles, gas, transport | +0.022 | **0.298** |

Vehicle purchases carry large CE sampling error. No vehicle attribution in
the write-ups is statistically supported, in either direction.

## Check 7. BLS R-CPI-I benchmark (`t45`-`t47`, `f20`)

Lowest minus highest income quintile, cumulative (pp):

| Window | BLS R-CPI-I | Ours (lag-2) | BLS R-C-CPI-I | Ours (Tornqvist) |
|---|---|---|---|---|
| 2014-12 to 2019-12 | +0.28 | +1.27 | +1.24 | +1.18 |
| 2019-12 to 2024-12 | +2.06 | +1.47 | +3.52 | +1.36 |
| 2019-12 to 2025-12 | +2.15 | +1.84 | n/a | n/a |

- **Annual Dec-to-Dec gaps** correlate at 0.47 and share a sign in 9 of 12
  years. 2021 is the big miss: ours -0.53, BLS +0.22.
- **Shelter weights explain much of the gap in levels.** Our Q1 - Q5
  shelter-weight gap is about twice BLS's (+5.8 against +3.0 in Dec 2019).
  BLS ranks by equivalized income, which moves larger households down the
  ranking and single-person households up. BLS's Q1 therefore holds fewer
  high-shelter-share singles, so this reads as definition, not method. The
  flat files cannot separate the two.
- **Superlative against fixed weight, all CUs.** BLS's C-CPI-U minus CPI-U is
  -1.95 (2014-19) and -1.35 (2019-24). Ours is -0.54 and -0.41: the same sign
  and about a third the size, as expected from 34 categories against about
  243 items by 32 areas.

**Reading.** The machinery reproduces the order of magnitude of BLS's
gradient over the headline window. It is less reliable year by year, and
group definitions matter as much as method. The "income gradient is three
times the family gap" line should cite the 2019-2025 comparison with BLS, not
our 2014-2019 numbers.

## Check 8. Targeted deep crosswalk (`t40_deep_variants.csv`)

Change in F1 - 10 (K1 - 10), CPI concept:

| Split | Change |
|---|---|
| New / used / other vehicles; vehicle repair, insurance, rental-lease-license | -0.02 (+0.01) |
| Tuition by level (college, K-12, vocational, other) | +0.08 (+0.12) |
| All splits, finance removed | +0.02 (+0.10) |

- **Deep-variant gaps:** F1 - 10 is -0.66 and K1 - 10 is -0.74.
- **The all-CU level rises** from 29.62% to 29.93%. That is closer to
  published CPI-U (29.9%): pricing K-12 tuition and used vehicles separately
  improves the fit.

---

## What the write-ups changed

Applied 2026-09-23 to the paper, README, executive summary,
`docs/phase3_index.md`, METHODS and the slides, with F1 kept as the headline
(author decision). The recommendations as made:

1. **Lead with the comparison panel.** The robust claim is that household type
   barely moves inflation. That holds against every comparison group. "Lower"
   is a claim about single/other CUs.
2. **Qualify significance.** "Statistically distinguishable" holds under
   independent vintages and fails under the worst-case bound. Drop "exceeds
   1.96 SE in 91% of months."
3. **Retire the 2021-22 attribution.** Replace "driven by vehicles, food and
   gasoline" with this: over 2021-22 the family gap was positive but not
   statistically distinguishable from zero.
4. **Replace "tuition above all."** For the K1 proxy the
   non-housing tilt is apparel, utilities and tobacco. Tuition is a
   college-age story.
5. **Childcare share ratio:** eight to twelve times, not five.
6. **Report the superlative index** as the main robustness result: the gap is
   a third to a half smaller.
7. **Income gradient:** cite the BLS R-CPI-I comparison (+2.1 against +1.8,
   2019-2025).
8. **Family definition.** Consider K1 (the published-table proxy) as the headline.
   Decided: F1 stays the headline; K1 (-0.84) is reported as robustness.

## What is still not done

- **Age conditioning and equal-consumer-unit weights** are not identified in
  the published tables used here.
- **Sub-item RSEs are borrowed from the parent** for childcare, tuition
  pieces and other education. Their true RSEs are unknown; those
  contributions' intervals may be understated.
- **Cell-based RSEs run about 10% below published all-CU RSEs** (median ratio
  0.90) and 4% below group 04's (0.96). Cells are treated as independent, and
  CE's design is not fully captured.
- **Contribution intervals in `t42` are approximate link-level calculations.**
  The D-42 finite-difference check validates cumulative gap SEs, not the
  attribution intervals.
