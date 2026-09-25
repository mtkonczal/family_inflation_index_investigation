# Phase 2: the CEX-to-CPI crosswalk

**Vintage:** 2026-09-08 | **Script:** `R/05_build_crosswalk.R`
**Crosswalk:** `crosswalk/cex_to_cpi.csv` | **Log:** `output/tables/t00c_crosswalk_validation.txt`

Maps the 41 CEX analysis categories onto CPI item strata and turns the result
into a monthly price panel, one index per category, ready for Phase 3
weighting.

---

## What was built

| | |
|---|---|
| Crosswalk rows | 66 |
| Categories mapped | 37 of 41 |
| Distinct CPI items used | 62 |
| Composite categories (>1 CPI target) | 12 |
| Deliberately unmapped | 4 (`OWNMORTG`, `220211`, `CASHCONT`, `INSPENSN`) |
| Confidence | high 49, medium 11, low 2 |
| Price panel | 1997-02 to 2026-07, 12,589 category-months |

Composites aggregate as a chained modified Laspeyres over their components,
weighted by CPI relative importance at t-1. This mirrors CPI's own upper-level
aggregation, so a single-item category reduces exactly to its published index.

---

## Validation

### The test that matters: does chaining reproduce published CPI?

**Yes, exactly.** For all 25 single-item, fully-observed categories, across
8,353 monthly observations, the worst absolute index error rebased at each
series start is **0.00000000**. Spot-checking 12-month changes to July 2026:
food at home 2.68, rent 2.86, electricity 4.20, motor fuel 24.81, day care
3.39, each matching the published series to two decimals.

This proves the chaining, the gap handling, the relative-importance weighting
and the crosswalk plumbing are all correct.

### Structural checks, all passing

- Every CPI code exists in `cu.item`.
- No CPI item serves two CEX categories (would double count spending).
- No mapped item is an ancestor of another mapped item (would double count).
  Ancestry is computed from the reconstructed tree, not string prefixes: see
  `decisions_log.md` D-17 for why that distinction is load-bearing.
- All 62 mapped items have a national NSA monthly series.
- The eight primary CPI major groups sum to 100.000 relative importance.
- Mapped plus unmapped relative importance reconciles to 100.00.
- Zero genuine mid-series holes after interpolation.

### Coverage: 70.72 of 100 CPI relative importance

| Major | Name | RI | Mapped | Unmapped | Covered |
|---|---|---|---|---|---|
| SAH | Housing | 45.48 | 17.29 | 28.19 | 38% |
| SAT | Transportation | 15.76 | 15.18 | 0.58 | 96% |
| SAF | Food and beverages | 14.33 | 14.33 | 0.00 | 100% |
| SAM | Medical care | 8.00 | 8.00 | 0.00 | 100% |
| SAE | Education and communication | 5.78 | 5.62 | 0.16 | 97% |
| SAR | Recreation | 5.22 | 5.20 | 0.02 | 100% |
| SAG | Other goods and services | 2.92 | 2.59 | 0.33 | 89% |
| SAA | Apparel | 2.52 | 2.52 | 0.00 | 100% |

The uncovered 29.27 decomposes as:

- **Owners' equivalent rent (`SEHC`): 27.18** — 93 percent of the whole gap
- Rest of housing: 1.01
- Everything outside housing combined: 1.08

**Outside owner-occupied shelter the crosswalk is effectively complete.** The
OER hole is the `scope_cpi_b` problem from Phase 1, not a crosswalk defect: CPI
prices owner shelter via rental equivalence and the CEX flat files report
owner *outlays* instead. The later index fills this gap with the CE rental-value
means in the annual workbooks (D-29).

### The economic validation: CEX shares against CPI relative importance

If the crosswalk is sound, all-consumer-unit CEX shares should track CPI
relative importance over the same mapped items. They do, with three exceptions
that were flagged as concept mismatches in the taxonomy *before* this
comparison was run.

| | 37 categories | Excluding 6 pre-flagged | 14 major blocks |
|---|---|---|---|
| Pearson r | 0.830 | **0.922** | |
| Dissimilarity | 14.79 | 8.04 | 5.80 |

Largest divergences (CEX share minus CPI share, pp):

| Category | CEX | CPI | Diff | Ratio |
|---|---|---|---|---|
| Medical services | 2.08 | 8.42 | **-6.33** | 0.25 |
| Health insurance | 6.75 | 0.84 | **+5.92** | 8.08 |
| Owned dwellings: maintenance, repairs, insurance | 4.87 | 0.58 | **+4.29** | 8.44 |
| Rented dwellings | 9.42 | 10.96 | -1.53 | 0.86 |
| Miscellaneous | 2.03 | 0.77 | +1.25 | 2.62 |
| Vehicle purchases | 8.89 | 7.71 | +1.17 | 1.15 |
| Fees and admissions | 1.56 | 2.65 | -1.09 | 0.59 |
| Food away from home | 6.57 | 7.65 | -1.08 | 0.86 |
| Food at home | 10.36 | 11.41 | -1.05 | 0.91 |

Everything outside the top three sits within about 1.5 pp of the 45-degree
line. See `output/figures/f06_share_vs_ri.png`.

### The medical divergence cancels

The two largest divergences have opposite signs inside the same block:

| Category | CEX | CPI | Diff |
|---|---|---|---|
| Medical services | 2.08 | 8.42 | -6.33 |
| Health insurance | 6.75 | 0.84 | +5.92 |
| Drugs | 1.10 | 1.89 | -0.80 |
| Medical supplies | 0.39 | 0.16 | +0.23 |
| **Pooled** | **10.32** | **11.31** | **-0.99** |

CEX households report out-of-pocket premiums as insurance; CPI routes most
medical spending through services and gives health insurance a relative
importance near 0.6. **The sources disagree about where medical spending sits,
not how much there is.** Phase 3 should run a pooled-medical variant, which
neutralizes the largest single divergence in the crosswalk. See D-22.

---

## Two data problems found along the way

### BLS published no October 2025 CPI

October 2025 carries **11 series against 380 in September**. `SA0` itself is
absent. This is not a quirk of one item; there is no October 2025 CPI.

The panel excludes that month rather than inventing a value, and chains across
it with the true September-to-November relative, so index **levels** stay
correct on both sides and 12-month changes remain computable. Only the October
point is missing.

This matters beyond this project: any real-time inflation script that assumes
contiguous monthly CPI rows will silently produce wrong 12-month changes for a
year after October 2025. Two specific traps, both of which bit here first:

1. Dropping an observation because its price relative spans two months
   discards the chain link. That produced a 17.5-point error against published
   CPI for lodging away from home before it was caught.
2. `lag(index, 12)` is off by one for twelve months. Use an explicit
   `date - months(12)` join.

### Five thin series, and two that have stopped

`SETA03` (leased vehicles, 38 filled months including a 17-month gap in 2022),
`SEHP` (household operations, 18), `SEGD01` (legal services, 14), `SEEA`
(educational books, 7), `SETE` (motor vehicle insurance, 1) publish
intermittently. These are interpolated log-linearly within each component's own
observed window and the interpolated weight share is recorded per
category-month. 78 of 21,211 component observations, 0.37 percent.

Two components have been **discontinued**: `SEGD01` last published 2024-09,
`SEHP` last published 2024-10. Categories 39 (Miscellaneous) and 15 (Other
household expenses) therefore run on renormalized weights from those dates.
Both are small and both were already medium confidence, but it means those two
composites change composition partway through the panel.

---

## Category inflation, 12 months to July 2026

Fastest: gasoline 24.8, fuel oil 22.4, public transportation 16.1, other
apparel services 9.9, tobacco 6.7.

Slowest: health insurance -8.0, telephone services -3.0, medical supplies -2.7,
drugs -2.7, infants' apparel -1.7, other vehicle expenses -0.9.

For reference, published all-items CPI was 3.36 over the same window.

The relevant Phase 1 finding: families are overweight vehicles, gasoline, food,
education and childcare; single-person and other CUs are overweight rent,
electricity and medical. In this particular window gasoline is running at 24.8
and rent at 2.9, which points toward families facing higher inflation right
now. **That is a one-month read, not a result.** Do not quote it before the
index is built and the shelter variants are in place.

---

## Limitations

1. **Panel starts 1997-02, not 1988.** `cu.data.0.Current` begins in 1997. The
   CEX share panel runs from 1988, so the index will be shorter than the
   weights until the `cu.data.1` through `cu.data.20` category files are pulled.
2. **Owners' equivalent rent is unmapped**, by design. Any all-in index is
   therefore missing 27 RI points of CPI on the price side and owner shelter
   outlays on the weight side. This is why Phase 3 must report ex-shelter and
   ex-housing variants.
3. **Three low-confidence mappings drive most of the residual divergence**:
   health insurance (`SEME`, concept mismatch), owner maintenance (`SEHD`, only
   the insurance leg has a target), medical services. All were flagged before
   validation.
4. **Composite weights before 2012-03** use the earliest published relative
   importance carried back, because CPI relative importance begins then.
   Immaterial for the 25 single-item categories, mild for the rest since
   within-composite weights move slowly.
5. **Vehicle purchases remain net-outlay against gross transaction price.** Not
   fixable from published tables.
6. **The crosswalk is hand-built.** BLS publishes no CEX-to-CPI concordance in
   either flat-file directory. Every judgment is versioned with a confidence
   flag and a note in `crosswalk/cex_to_cpi.csv`.

## Next step

Phase 3 has everything it needs: `data/derived/cex_shares_long.csv` for weights
and `data/derived/cpi_category_index.csv` for prices. The order of work:

1. Build the all-CU index and compare it to published CPI-U. **That residual is
   the method's error bar and governs whether any family/non-family gap is
   reportable.**
2. Then the three headline indices: all-in, ex-shelter, ex-housing.
3. Then the robustness table in `METHODS.md` section 7, including the
   pooled-medical variant from D-22.
