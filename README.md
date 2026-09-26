# Do families face higher inflation?

*Vibe-Coded by Claude Opus 5.5 · Mike Konczal*

- **Slides (PDF):** [`slides.pdf`](slides.pdf), viewable directly on GitHub.
- **Slides (interactive):** [`slides.html`](slides.html). Download it and open it in a browser; it is one self-contained file.
- **Paper:** [`paper/family_inflation.qmd`](paper/family_inflation.qmd).

*Preliminary; not for quotation.*

## The answer

**No. From December 2019 to July 2026, the spending basket of families with
children did not have higher inflation than the basket of single-person and
other households.** Priced with the same CPI item indexes, the family basket
rose 29.4 percent and the single/other basket rose 30.1 percent. The gap is
-0.7 percentage points over six and a half years, about 0.1 point a year.

| Dec 2019 to Jul 2026 | Families with children | Single-person and other | Gap |
|---|---|---|---|
| CPI-concept basket (headline) | 29.42% | 30.11% | **-0.69 pts** |

- **Uncertainty.** The approximate 95 percent sampling margin is ±0.41 points
  if CE survey errors are independent across years and ±0.95 under a
  cautious cross-year bound. Under the cautious bound the gap is not
  distinguishable from zero. No version shows families meaningfully above.
- **Robustness.** Across nine basket definitions the gap runs from -1.0 to
  +0.1 points. With more current spending weights (a Törnqvist index) it is
  about -0.5. CPI-W prices, seasonally adjusted CPI-U, married couples with children
  alone, and a minor-child proxy all keep it negative.
- **The comparison matters.** Against all households the family basket rose
  0.2 points less; against married couples without children, 0.2 points
  more. Household type barely moves inflation in these baskets.

## Why

**An inflation rate depends on budget shares, not dollars.** Families spend
about \$105,000 a year against \$57,000 for single-person and other
households, but a household that buys twice as much of the same basket has
the same inflation rate. A category moves the gap only when families put more
of their budget into it *and* its price rose faster than average.

**Housing explains about half the gap.** Single-person and other households
put 36 percent of spending into shelter, against 30 percent for families,
and shelter rose 33.5 percent against 27.9 percent for everything else. Most
of the difference is rent (12.7 percent of the single/other budget against
5.3 for families). Housing has economies of scale: a family of four needs one
kitchen and one roof, so its housing share is smaller.

**The rest is the non-housing mix.** Education (mostly parents of college-age
children), apparel, utilities and tobacco pull families down; gasoline pushes
them up. Vehicle purchases are too noisy in the survey to sign.

**Childcare contributes about zero.** Families put about eight times as much
of their budget into childcare, but day care prices rose 29.8 percent against
29.9 for all items. Childcare prices have tracked services generally since
2010. The childcare problem is the size of the bill (about \$5,600 a year for
married couples whose oldest child is under 6), not its inflation rate.

**It is not a pandemic artifact.** From December 2014 to December 2019 the
family gap was -1.05 points, led by rent. Families' 12-month rate did run
hotter in 2021-22, but over December 2020 to December 2022 the cumulative
difference was +0.23 points, not distinguishable from zero, and it reversed
in 2023-24 as rents caught up.

**Income matters more than family type.** The same method finds the lowest
income quintile's basket rose 1.84 points more than the highest's, close to
BLS's own research index by income quintile (+2.15 points, December 2019 to
December 2025), again led by rent.

## Rates are not bills

Similar inflation rates on different-sized baskets mean different dollar
increases. Buying the fixed 2019 non-housing basket at July 2026 prices costs
married couples with children about \$16,300 more per year, against about
\$8,100 for single-person and other households. One-parent households are
different: their basket rose about 0.9 points more than married parents'
(clear only under the independent-year assumption), and they spend 43 percent
of consumption on food at home, utilities and housing, closer to the lowest
income quintile (46 percent) than to married couples (37 percent).

## What this does not measure

- **Prices paid.** Every household is charged the same CPI price change for
  a given item. Scanner-data research finds households pay different prices
  within an item; that could widen or narrow the gap.
- **Age.** Family reference persons average 44 years old against 53 for the
  comparison group. The published tables do not allow an age-adjusted
  comparison.
- **Hardship.** A price index measures rates, not whether families can afford
  what they buy.

## How it was built

1. **What people buy:** BLS Consumer Expenditure Survey spending by household
   type, 41 categories, 1988 to 2024.
2. **What it cost:** each category matched to its CPI-U price series, 62
   series in all.
3. **Housing as CPI does it:** owners priced by owners' equivalent rent,
   weighted by the survey's rental-value question, the same one BLS uses.
   The all-household version tracks official CPI to about 0.1 point on
   12-month rates.
4. **Uncertainty:** BLS's published expenditure standard errors carried
   through to the gap.

Details: [`METHODS.md`](METHODS.md) for the method, and
[`docs/decisions_log.md`](docs/decisions_log.md) for every judgment call
(the `D-xx` numbers cited in the code).

## Reproducing

Requires R 4.4+ (`tidyverse`, `tidyusmacro`, `readxl`), Quarto, a
`BLS_EMAIL` contact address in `.Renviron`, and, for the PDF, Python with
`playwright` plus Google Chrome. From the project root:

```bash
for f in R/0[1-9]_*.R R/1[0-2]_*.R; do Rscript "$f" || break; done
Rscript slides/make_slide_figures.R
(cd paper && quarto render family_inflation.qmd)
(cd slides && quarto render family_inflation_slides.qmd) && cp slides/family_inflation_slides.html slides.html
python3 slides/export_pdf.py
```

Data: CE annual means through 2024 and CPI through July 2026, pulled
September 2026. BLS overwrites its flat files in place, so each run records
file sizes and timestamps in `data/raw/download_manifest.txt`.
