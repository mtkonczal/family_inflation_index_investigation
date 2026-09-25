# CE microdata extension: age and household weighting

**Status:** design only, 2026-09-25. No microdata have been downloaded or analyzed for this extension. The published-table index and its headline specification remain unchanged.

## Question and estimands

The existing index compares expenditure-weighted baskets for LB06 families (04 + 09) and single-person-and-other consumer units (10). It is an unconditional **composition-channel** comparison. CE public-use microdata (PUMD) can ask whether that gap persists after putting the groups on a common age distribution and can replace aggregate expenditure weighting with equal consumer-unit weighting. Neither exercise identifies the causal effect of a child: groups still differ in unobserved characteristics, and every household within an item continues to receive the same national CPI price change.

Report these estimands separately:

1. **Published-table replication:** the current group-aggregate expenditure shares and index, rebuilt from PUMD as closely as the public files permit.
2. **Age-standardized group baskets:** each group's category expenditures averaged within reference-person age cells, then reweighted to the same pooled age distribution. Keep the index formula, CPI series, OER treatment, crosswalk, window, and price-update rule fixed. This changes the *population weighting* estimand, so show it beside the original.
3. **Household-weighted index distribution:** compute each consumer unit's expenditure shares on the same CPI-consistent basket, apply the common price relatives, then average consumer-unit index changes with CE sampling weights. Contrast this with the expenditure-weighted group index. State explicitly how zero and near-zero basket denominators are handled.
4. **Resident child age 18 or younger:** use member-level age, relationship,
   and CU-membership fields to identify at least one child aged 0–18 in the
   CU. Prespecify whether stepchildren, grandchildren, and other dependents
   count. This corrects a limitation of the published-table 05 + 06 + 09
   proxy: married couples are classified by their **oldest** child, so code
   07 mixes all-adult-child couples with couples who also have a younger
   minor. Keep F1 and the published-table proxy beside the exact definition.

## Data and construction

- Use the CE Interview and Diary PUMD for every **expenditure vintage needed by the December 2019–July 2026 index**. Under the existing two-year lag these are 2017–2024. Fix and record the exact annual file releases and any revisions. The CE [PUMD guide](https://www.bls.gov/cex/pumd-getting-started-guide.htm) identifies FMLI (CU characteristics and weights), MTBI (Interview expenditures), FMLD (Diary characteristics and weights), and EXPD (Diary expenditures). Use the guide's source-selection and calendar-year procedures so an item is not counted in both surveys.
- Construct the same CPI-consistent 34-category basket as `pm_oer_all_in`, including the CE rental-value question for OER and pooled medical care. Verify the OER field, UCC-to-category map, calendar-year allocation, and any PUMD disclosure adjustments against the year-specific BLS dictionary before coding. Do not infer variable names from the published-table labels.
- Derive household type, reference-person age, household size, income, and tenure from CU and member records as appropriate. Validate that the PUMD definitions reproduce the published LB06 groups; report any residual/unclassifiable CUs. Include an urban-only sensitivity, since CPI-U's target population is urban while the published CE tables used here cover the national CE universe ([BLS CPI concepts](https://www.bls.gov/opub/hom/cpi/concepts.htm)).
- Use `FINLWT21` with BLS's calendar-year adjustment for point estimates. Use the 44 `WTREP` replicate weights and BLS's balanced repeated replication rule for uncertainty, rebuilding **both groups and their gap in every replicate**. This retains survey covariance among spending categories and between overlapping groups. Account for repeat interviews across adjacent years when estimating a multi-vintage gap; if a defensible joint replicate across years is unavailable, report explicit sensitivity bounds rather than treating vintages as independent by default.

## Standardization and interpretation

Choose age cells before inspecting index results (for example, under 35, 35–44, 45–54, 55–64, and 65+), then combine sparse cells or use a prespecified smooth model if replicate estimates are unstable. Use the pooled comparison population's CU-weighted age distribution as the common standard. Show cell counts, effective sample sizes, and overlap by year. A standardized estimate should not extrapolate into unsupported age cells.

Add income and tenure **one at a time** as diagnostics. Income may itself change with household composition; tenure can be part of the pathway from family size to spending shares. Conditioning on either changes the question and should not be described as a cleaner causal estimate. Report the unconditional gap, age-standardized gap, age-plus-income gap, and age-plus-tenure gap as distinct descriptive comparisons.

## Validation gates before interpreting a new gap

1. Reproduce published CE consumer-unit counts, total expenditure, each major spending share, and the rental-value mean by group-year; quantify deviations caused by PUMD disclosure treatment and Interview/Diary integration.
2. Require the 34 CPI-basket components to sum to the constructed denominator for every group-year and to have nonnegative, nonmissing shares. Record suppression, zero-expenditure rates, and imputation rates.
3. Hold the existing CPI price panel fixed and confirm that the PUMD replication of the **unadjusted** group index is close to the published-table index before interpreting any standardization. If it is not, decompose the difference into sample universe, expenditure construction, and weighting.
4. Report family-minus-single/other cumulative gaps and 95% intervals for each estimand, plus comparisons with all other CUs and married couples without children. Report shelter and medical contributions with uncertainty. The substantive question is whether age or equal-CU weighting materially changes the small headline gap, not whether one arbitrary p-value crosses 0.05.

Sources: [BLS CE PUMD](https://www.bls.gov/cex/pumd.htm), [BLS PUMD getting-started guide](https://www.bls.gov/cex/pumd-getting-started-guide.htm), and [BLS CE tables guide](https://www.bls.gov/cex/tables-getting-started-guide.htm).
