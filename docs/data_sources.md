# Data sources

All data comes from the BLS time-series flat files at `download.bls.gov`, pulled
via `tidyusmacro::getBLSFiles()`. Metadata below was verified on 2026-09-08.

---

## 1. Consumer Expenditure Survey (prefix `cx`)

Directory: <https://download.bls.gov/pub/time.series/cx/>

| File | Size | Purpose |
|---|---|---|
| `cx.data.1.AllData` | 120.8 MB | The expenditure means. Only data file published. |
| `cx.series` | 31.1 MB | Series metadata and coverage years |
| `cx.item` | 70 KB | Item hierarchy, 1,214 items, display levels 0-7 |
| `cx.characteristics` | 8.4 KB | Demographic group labels (164 rows) |
| `cx.demographics` | 861 B | The 19 demographic dimensions |
| `cx.subcategory` | 1.2 KB | 23 subcategories under 4 categories |
| `cx.category` | 238 B | EXPEND, INCOME, ADDENDA, CUCHARS |
| `cx.process` | 83 B | `M` = Means. **This is the only process code.** |
| `cx.aspect` | 739 MB | Not used. Large; do not pull casually. |

### Frequency and units

Annual only. Period code is `A01`. Values are **mean annual dollars per
consumer unit**, unadjusted, in current dollars of the reference year. There is
no real/deflated variant and no seasonal adjustment.

### Categories (`cx.category`)

- `EXPEND` Expenditures. **The only category used here.**
- `INCOME` Income and taxes
- `ADDENDA` Assets, liabilities, other financial info
- `CUCHARS` Consumer unit characteristics (household counts, percent distributions)

### The dimension we need: `LB06`, Composition of consumer unit

From `cx.characteristics`:

| Code | Level | Label |
|---|---|---|
| 01 | 0 | All Consumer Units |
| 02 | 0 | Total married couple consumer units |
| 03 | 1 | Married couple only consumer units |
| 04 | 1 | Total married couple with children cons. units |
| 05 | 2 | Married couple w/ children, oldest child under 6 |
| 06 | 2 | Married couple w/ children, oldest child 6 to 17 |
| 07 | 2 | Married couple w/ children, old. child 18 or over |
| 08 | 1 | Other married couple consumer units |
| 09 | 0 | One parent, at least one child under 18 |
| 10 | 0 | Single person and other consumer units |

Note the hierarchy: 02 = 03 + 04 + 08, and 04 = 05 + 06 + 07. Codes 01, 09, and
10 sit at level 0 but **01 is the universe**, not a sibling of 09 and 10.

### Other useful dimensions

| Code | Dimension | Why it matters here |
|---|---|---|
| `LB05` | Size of consumer unit | Cleaner cut than LB06 but confounds age |
| `LB07` | Number of earners | Distinguishes single-earner from dual-earner families |
| `LB17` | Housing tenure (owner w/ mortgage, owner w/o, renter) | **Critical.** The rent-vs-OER wedge is the main confound |
| `LB21` | Selected age of reference person | Lifecycle control |
| `LB01`/`LB15` | Income quintiles / deciles | For the income-gradient comparison |

The flat files publish each dimension **marginally**. There are no
`LB06 x LB21` or `LB06 x LB17` cross-tabs. Conditioning on age or tenure
*within* family type requires CEX PUMD microdata.

### Coverage is uneven across time

For `characteristics_code == "04"` (married with children), `EXPEND` series
begin as follows:

| Item display level | Series beginning 1988 | Series beginning 2010 |
|---|---|---|
| 0 | 15 | 0 |
| 1 | 26 | 54 |
| 2 | 35 | 147 |
| 3 | 22 | 284 |
| 4 | 0 | 145 |
| 5 | 0 | 104 |
| 6-7 | 0 | 20 |

Smaller batches also begin in 2011, 2013-2015, 2017, 2019, 2021-2024 as BLS
added items. **A time series built from "all available items" would therefore
have a mechanically shifting basket.** The scripts pin the item set to a
balanced panel; see `decisions_log.md` D-04.

Latest year: **2024**.

### Suppression

BLS writes `-` for cells with insufficient sample. `getBLSFiles()` coerces these
to `NA` and reports the count (220,493 across the whole file on the initial
pull). Suppression is **not random**: it hits small demographic cells and fine
items hardest, which means single-parent households and deep item detail. Any
share denominator built by summing components will be biased if suppressed
cells are silently treated as zero. See `decisions_log.md` D-03.

---

## 2. CPI-U (prefix `cu`)

Directory: <https://download.bls.gov/pub/time.series/cu/>

| File | Size | Purpose |
|---|---|---|
| `cu.data.0.Current` | 48.9 MB | All current index series |
| `cu.item` | 16.6 KB | 400 items, display levels 0-8 |
| `cu.aspect` | 31.5 MB | Includes `aspect_type = "I"`, relative importance |
| `cu.series` | 1.3 MB | Series metadata |

Monthly. Coverage through **2026 M07**.

### Series ID structure

`CU` + seasonal (`U`/`S`) + periodicity (`R` monthly, `S` semiannual) +
area (4) + item code. National, monthly, NSA is `CUUR0000<item>`.

### Filters used

- `area_code == "0000"` (US city average)
- `periodicity_code == "R"` (monthly)
- `seasonal == "U"` (not seasonally adjusted) for index-level and 12-month work.
  NSA is the right default: relative importance is published NSA, and SA factors
  are revised annually.

### Relative importance

`cu.aspect` carries `aspect_type == "I"` = relative importance, by
`area_code x item_code x month`. `tidyusmacro:::cpi_weights_monthly(email, "cu")`
wraps it into a panel with `weight` and `weight_12mo`. In the slice inspected,
type-`I` rows begin in **2012**; pre-2012 relative importance requires the
annual RI tables published separately on bls.gov.

This is used for **validation only**, not to build the index. The index weights
come from CEX.

### Child-specific CPI strata

These are where a family index should diverge most:

| Item code | Name |
|---|---|
| `SEEB03` | Day care and preschool |
| `SEEB02` | Elementary and high school tuition and fees |
| `SEAF` | Infants' and toddlers' apparel |
| `SSFV031A` | Food at elementary and secondary schools |
| `SSGE013` | Infants' equipment |
| `SSHJ031` | Infants' furniture |
| `SERE01` / `SS61011` | Toys / toys, games, hobbies, playground equipment |

---

## 3. Files deliberately not used

- `cx.aspect` (739 MB). Not needed for means.
- CPI-W (`cw`) and C-CPI-U (`su`) are pulled only in the robustness stage.
- `cu.data.1`-`cu.data.20` regional and size-class breakouts. National only here.

---

## 4. What these files cannot give you

1. **Standard errors.** `cx.process` has one code, `M` (means). CEX standard
   errors are published in separate tables on bls.gov, not in the flat files.
   Sampling error on the weight vectors is unquantified without PUMD replicate
   weights (44 of them).
2. **Cross-tabs.** Marginal dimensions only, as noted above.
3. **Rental equivalence.** CEX published tables report owner *outlays*, not the
   imputed rental value CPI uses. The rental-equivalence question exists in
   PUMD, not here. This is the largest single scope wedge. See `METHODS.md`.
4. **A CEX-to-CPI item concordance.** Not published in either flat-file
   directory. The mapping in `crosswalk/` is built by hand and versioned.
