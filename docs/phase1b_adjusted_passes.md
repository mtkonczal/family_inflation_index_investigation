# Phase 1b: netting out housing, and controlling for age

**Vintage:** 2026-09-08 | **Data:** CEX 2024 | **Script:** `R/04_adjusted_passes.R`

Two passes requested, plus one decomposition that answers the housing question
more sharply than the mechanical version does.

Summary statistic throughout is the **basket dissimilarity index**: half the sum
of absolute share gaps, i.e. the percent of the budget that would have to be
reallocated to make the two baskets identical.

---

## Headline

| Base | Categories | Observed | Net of age | Net of tenure |
|---|---|---|---|---|
| Consumption | 39 | **13.88** | 14.26 | **10.00** |
| Shelter removed | 34 | **8.33** | 6.32 | 9.05 |
| All housing removed | 25 | **7.27** | 6.08 | 7.81 |

Three results, in order of importance.

1. **Housing is roughly 40 percent of the basket difference.** Dissimilarity
   falls from 13.88 to 8.33 when shelter is removed. A real difference survives.
2. **Age does not explain the gap. It runs against it.** Net of age composition,
   dissimilarity on the consumption base *rises* to 14.26.
3. **Tenure explains about 28 percent of the total,** and 73 percent of the rent
   gap specifically. Dissimilarity falls from 13.88 to 10.00 net of tenure.

---

## Pass A: netting out housing

Bases are defined in `decisions_log.md` D-12. All exclude saving and transfers.

### What survives when all housing is removed (25 categories)

| Category | Families | Single/other | Gap | Net of age |
|---|---|---|---|---|
| Education | 5.33% | 3.14% | **+2.19 pp** | +3.09 pp |
| Vehicle purchases | 14.02% | 12.51% | **+1.51 pp** | +1.32 pp |
| Fees and admissions | 2.88% | 1.77% | +1.11 pp | +0.75 pp |
| Food away from home | 10.24% | 9.45% | +0.79 pp | -0.01 pp |
| Apparel: children under 2 | 0.37% | 0.06% | +0.31 pp | +0.19 pp |
| Food at home | 15.86% | 15.56% | +0.30 pp | -0.59 pp |
| Gasoline and other fuels | 6.86% | 6.63% | +0.23 pp | +0.17 pp |
| Other vehicle expenses | 10.45% | 11.02% | -0.57 pp | -0.26 pp |
| Health insurance | 8.70% | 9.88% | **-1.18 pp** | -0.69 pp |
| Audio and visual equipment | 1.86% | 2.91% | **-1.05 pp** | -0.81 pp |
| Tobacco | 0.55% | 1.36% | -0.81 pp | -0.76 pp |
| Miscellaneous | 2.64% | 4.08% | **-1.44 pp** | -0.93 pp |

Note that the childcare proxy disappears from this table: it lives inside CEX
household operations, so `ex_housing` removes it. That is a defect of the CEX
hierarchy, not of the concept. **Use `ex_shelter` (34 categories) when childcare
matters**, where the childcare gap is +1.83 pp and the education gap +1.80 pp.

### Reading it

Ex-housing, the family basket tilts toward **education, vehicles, recreation
fees, and food**, and away from **health insurance, entertainment electronics,
tobacco, and miscellaneous** (the last being largely finance charges, legal and
funeral costs, all of which skew older).

For a price index this matters because these categories have very different
inflation profiles from shelter. Vehicles and food spiked in 2021-2022;
education and health insurance did not. So the ex-housing family index will
diverge from the all-in one not just in size but in **timing**.

---

## Pass B: controlling for age

Families with children average **44.3** years of reference-person age against
**53.1** for single-person and other CUs, an 8.8-year gap.

### Method, and why it is a bound not a control

There is no `LB06 x LB04` cross-tab in the CEX flat files. `LB06` publishes mean
age only; `LB04` publishes shares by age bracket pooled across family types.
The method interpolates the `LB04` gradient (six non-overlapping brackets with
mean ages 21.7 through 74.2) at each group's mean age. Both targets are interior
to the support, so no extrapolation.

**The `LB04` age gradient is not a pure age effect.** Moving from the 35-44
bracket to 65+ also removes children from the household. So the age prediction
absorbs part of the true family effect, making it an **upper bound on the age
contribution** and the residual an **attenuated, conservative** family effect.

The childcare proxy demonstrates this: observed +1.45 pp, age-predicted
+0.85 pp, residual +0.60 pp. Nearly all of that apparent age effect *is* family
composition operating through age. Read +0.60 as a floor, not an estimate.

### The result that is not a bound

For **rented dwellings**, the age prediction is **+1.98 pp**. Renting falls
sharply with age (homeownership by bracket: 10, 44, 60, 70, 76, 78 percent), and
families are younger, so age composition predicts families should spend *more*
of their budget on rent. They spend **10.12 pp less**. The residual net of age
is **-12.10 pp, larger than the raw gap.**

**Age does not explain the tenure gap; it runs against it.** Because the sign of
the bias is known, this conclusion does not depend on the bounding assumption.
It is the cleanest identification available from these files, and it kills the
most obvious objection to the Phase 1 finding.

### Where age does explain something

| Category | Gap | Age-predicted | Net of age |
|---|---|---|---|
| Personal services (childcare proxy) | +1.45 | +0.85 | +0.60 |
| Food at home | +1.07 | +0.40 | +0.67 |
| Food away from home | +1.03 | +0.39 | +0.64 |
| Health insurance | -0.18 | -0.38 | +0.21 |
| Education | +1.55 | **-0.59** | +2.14 |
| Owned dwellings: mortgage interest | +3.08 | +0.88 | +2.20 |

**Health insurance flips sign, but only just.** Raw, families spend slightly
less of their budget on health insurance (-0.18 pp). Age composition predicts
they should spend less still (-0.38 pp), because the comparison group contains
the elderly. Net of age the sign flips to +0.21 pp. The magnitudes are small
enough that with no standard errors available this should be described as "no
meaningful difference once age is accounted for," not as a family effect.

Note the sign reversal does not survive on the ex-housing base, where health
insurance is a much larger share of a smaller basket: gap -1.18 pp,
age-predicted -0.49 pp, residual -0.69 pp. Renormalization changes which
categories look large, so quote the base alongside any number.

**Education widens.** Age predicts singles should spend more on education (young
single students), so netting out age raises the family education gap from +1.55
to +2.14 pp.

Once housing is removed, age explains more of what remains: dissimilarity falls
from 8.33 to 6.32 on the ex-shelter base, about 24 percent. Non-housing
differences are more lifecycle-driven than housing differences are.

---

## Pass C: tenure decomposition

The mechanical ex-housing pass cannot say *how much* of the gap is tenure, only
what the gap looks like with housing gone. This decomposition answers it, using
each group's own homeownership rate against the `LB17` owner and renter share
vectors:

$$\Delta^{\text{tenure}}_i = (\pi_F - \pi_N)(w^{\text{owner}}_i - w^{\text{renter}}_i)$$

Homeownership rates: families **74.6 percent**, single and other **51.0
percent**, gap **23.6 pp**.

| Category | Gap | Tenure-predicted | Net of tenure | Percent tenure |
|---|---|---|---|---|
| Rented dwellings | -10.12 | -7.43 | -2.69 | **73%** |
| Owned dwellings: mortgage interest | +3.08 | +1.74 | +1.34 | 57% |
| Owned dwellings: property taxes | +0.91 | +1.31 | -0.40 | 144% |
| Vehicle purchases | +1.65 | +0.55 | +1.10 | 33% |
| Education | +1.55 | +0.08 | +1.47 | **5%** |
| Personal services (childcare proxy) | +1.45 | +0.08 | +1.37 | **6%** |
| Food away from home | +1.03 | +0.00 | +1.03 | 0% |
| Food at home | +1.07 | -0.17 | +1.24 | -16% |

**Education and childcare are essentially untouched by tenure** (5 and 6
percent). Combined with Pass B, where tenure-adjustment is not the binding
issue, these two categories look like genuine family effects rather than
composition artifacts.

**Property taxes are over-explained** (144 percent). Given how much more likely
families are to own, the tenure model predicts a larger property-tax share than
they actually have. Plausibly family homeowners hold cheaper houses per dollar
of spending, or live in lower-tax jurisdictions. Worth a look but not central.

---

## Bottom line for Phase 3

Two things are now settled that were open at the end of Phase 1.

1. **The tenure gap is not an age artifact.** It is the opposite of what age
   composition predicts. This survives the weakest link in the method, because
   the direction of the bias is known.
2. **A real non-housing basket difference exists** and is worth indexing:
   dissimilarity of 8.33 percent ex-shelter, concentrated in education,
   vehicles, childcare, recreation, and food on the family side, and health
   insurance, electronics, tobacco, and finance charges on the other.

**Recommendation.** Build Phase 3 to report **three** headline indices, not one:
all-in, ex-shelter, and ex-housing. The all-in number will be dominated by the
OER-versus-market-rent methodology choice and should never be quoted alone. The
ex-shelter index is the defensible "do families buy a more expensive basket"
number.

## Limitations specific to Phase 1b

1. Both passes use **marginal** tabulations. `LB04` and `LB17` share vectors are
   pooled across household types, so neither is a true within-group control.
2. Age adjustment assumes **piecewise linearity in mean age**. With six bracket
   points and interior targets this is mild, but it is an assumption.
3. **Mean age is not the age distribution.** Two groups with equal mean age and
   different dispersion would be treated identically.
4. **No standard errors.** Unchanged from Phase 1.
5. Age and tenure are **not jointly adjusted**. They are correlated (renters
   average 44.7 years, owners 56.2), so the two adjustments are not additive and
   should not be summed.
