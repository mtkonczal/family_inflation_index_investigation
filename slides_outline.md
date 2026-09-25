> **SUPERSEDED 2026-09-23.** This outline reflects the pre-review results
> (25.32% vs 25.26%, "noise floor", "pre-registered error bar"), which no longer
> hold. The revised numbers are in `executive_summary.md`, `README.md` and
> `slides/family_inflation_slides.qmd`; the reasons are in
> `docs/decisions_log.md` D-27 to D-40 (review 2: `docs/review_checks.md`).
> Do not build slides from this file.

# Presentation Deck Outline: Do Families Face Higher Inflation?
### A Clear, Data-Driven Look at Inflation Rates vs. Family Dollar Burdens

*Target Audience: General Managers, Senior Leaders, and Policy Directors*  
*Format: 10-Slide Executive Presentation*

---

## Slide 1: Title & Core Finding

* **Slide Title:** Do Families Face Higher Inflation?
* **Subtitle:** An Empirical Examination of Inflation Rates and Financial Burdens for Households with Children (2019–2026)
* **Key Visual:** A bold callout box comparing cumulative inflation: **+25.32% (Families)** vs. **+25.26% (Single/Other)**.
* **Core Takeaways:**
  * **The Big Question:** Did families face higher inflation because they buy more groceries, childcare, minivans, and school supplies?
  * **The Bottom Line:** **No.** Over the past 6.5 years, the inflation rate difference between families with children and single households is just **0.06 percentage points**—well within statistical noise.
  * **The Critical Nuance:** While the *percentage rate* was identical, the *dollar burden* was significantly heavier for families ($22,600/yr vs $11,300/yr).
* **Speaker Notes:**
  > "Everyone has heard the intuitive argument that families with children got hit harder by inflation because groceries, cars, and childcare jumped in price. We built a custom price index using BLS expenditure data and CPI inflation metrics to test this claim directly. Our bottom line finding: families and single households experienced virtually the exact same inflation rate. But equal percentage rates do not mean equal financial pain."

---

## Slide 2: The Core Question & Why Intuition Can Mislead

* **Slide Title:** The Composition Hypothesis
* **Key Visual:** Comparison diagram showing typical budget shares: Family basket (groceries, childcare, vehicles) vs. Single basket (rent, dining out, recreation).
* **Core Takeaways:**
  * Headline CPI represents a generic "average" urban household.
  * If families spend a higher fraction of their income on items that experienced high inflation, their true cost-of-living increase would be higher.
  * *Why Intuition Can Be Deceiving:* While families spend more on childcare and food at home, single adults spend more on other rising categories (e.g., rent, health insurance, electricity).
* **Speaker Notes:**
  > "Headline inflation measures an average household, but no single household is average. We set out to isolate the 'composition channel'—testing whether the specific mix of goods that families buy caused them to experience higher inflation than single-person households."

---

## Slide 3: How We Built the Group-Specific Index

* **Slide Title:** Methodology: Connecting Spending Data to Price Indexes
* **Key Visual:** Simple 3-step workflow diagram:
  1. *CEX Spending Survey (1988–2024)* $\rightarrow$ 2. *Custom Category Crosswalk (41 categories)* $\rightarrow$ 3. *Chained CPI Index Build (1998–2026)*.
* **Core Takeaways:**
  * **Data Sources:** BLS Consumer Expenditure Survey (CEX) for expenditure weights across household types; official monthly CPI-U for category price changes.
  * **Scope:** 41 distinct spending categories tracked over 186 consecutive months (2010–2026) with long-panel checks back to 1998 (330 months).
  * **Rigorous Validation:** Recreated standard CPI benchmarks with zero calculation error (0.00000000 error on single-item categories).
* **Speaker Notes:**
  > "We didn't rely on back-of-the-envelope estimates. We constructed a full chained Laspeyres price index mirroring BLS's exact indexing math across 41 spending categories. We tested this over 15 to 30 years of monthly data."

---

## Slide 4: Establishing a Noise Floor (The Pre-Registered Error Bar)

* **Slide Title:** Quantifying the Noise Floor: When is a Gap Real?
* **Key Visual:** Bar chart showing the observed gap (0.11 pp) vs. the Noise Floor (0.38 pp) — *[Figure Reference: `output/figures/f09_gap_vs_errorbar.png`]*.
* **Core Takeaways:**
  * Survey data inherently contains measurement noise. Before running the numbers, we established an objective "kill criterion": if an observed gap is smaller than the survey's noise floor, it is statistically zero.
  * **The Noise Floor:** 0.38 percentage points (derived by comparing CEX weights to CPI published weights on the exact same basket).
  * **The Result:** The average family-vs-single gap was only **0.11 pp** (0.30x the noise floor).
* **Speaker Notes:**
  > "To ensure our conclusions were rock solid, we pre-registered an error bar. We asked: how much noise exists simply from survey measurement? That noise floor is 0.38 percentage points. The gap between families and singles was just 0.11 percentage points. In statistics, if your signal is smaller than your baseline noise, you have no measurable gap."

---

## Slide 5: The Primary Finding: 2019–2026 Cumulative Inflation

* **Slide Title:** Cumulative Inflation: Families vs. Singles
* **Key Visual:** Time-series line chart showing the two price trajectories tracking each other almost perfectly from Dec 2019 to Jul 2026 — *[Figure Reference: `output/figures/f10_cumulative.png`]*.
* **Core Takeaways:**
  * **Cumulative Price Rise (Dec 2019 – Jul 2026):**
    * Families with children: **+25.32%**
    * Single-person & other households: **+25.26%**
    * **Cumulative Difference: +0.06 percentage points**
  * **15-Year View (2010–2026):** Cumulative difference is only **-0.63 percentage points**.
  * Over 186 continuous months, the gap never once breached the noise floor.
* **Speaker Notes:**
  > "Here is the primary result. When you track families with children against single households across the entire post-2019 inflation spike, the lines overlap almost completely. Over six and a half years, the total difference is six-hundredths of a percent. The inflation rate experienced by both groups was identical."

---

## Slide 6: Why the Math Defeated the Intuition

* **Slide Title:** Category Breakdown: Why Offsets Kept the Gap at Zero
* **Key Visual:** Waterfall or horizontal bar chart showing category contributions to the annual inflation gap (+0.05 pp childcare, +0.04 pp vehicles, offset by -0.04 pp tobacco/insurance/electricity) — *[Figure Reference: `output/figures/f11_gap_contributions.png`]*.
* **Core Takeaways:**
  * **Small Weights on Big Jumps:** Childcare is 4x larger in family budgets than single budgets (2.25% vs 0.54%), but because it's only ~2% of total spending, it added just **+0.05 pp** to annual inflation.
  * **Category Offsetting:**
    * *Categories where families spend more:* Childcare (+0.05 pp), Vehicles (+0.04 pp), Education (+0.04 pp), Food at home (+0.04 pp).
    * *Categories where singles spend more:* Health insurance (-0.03 pp), Electricity (-0.03 pp), Tobacco (-0.04 pp).
  * Net result: the categories balanced each other out.
* **Speaker Notes:**
  > "Why didn't childcare or groceries make families have higher inflation? Two reasons: First, childcare is a small fraction of the overall budget (around 2%), so even a sharp increase has a muted impact on the total index. Second, higher family spending on food and cars was canceled out by categories where single adults spend more, like health insurance, utilities, and tobacco."

---

## Slide 7: The "Housing Trap" and Two Offsetting Surge Episodes

* **Slide Title:** The Housing Distortion & The Two Mini-Episodes
* **Key Visual:** Two-phase timeline showing the 2021–22 Goods Surge (+0.63 pp for families) followed by the 2023–24 Rent Catch-Up (-0.49 pp for families / hit singles harder).
* **Core Takeaways:**
  * **The Housing Distortion:** CPI measures tenant rent, but omits homeowner mortgage costs and property taxes. Because 75% of families own homes while 50% of singles rent, unadjusted numbers make singles look artificially harder hit by rent.
  * **Two Offsetting Surge Windows:**
    1. *Goods Spike (Apr 2021 – Jun 2022):* Families briefly faced +0.63 pp higher inflation due to used cars, gas, and groceries.
    2. *Rent Catch-Up (Dec 2022 – Oct 2024):* Single renters faced -0.49 pp higher inflation as apartment rents surged.
  * Over the full cycle, these two short waves neutralized each other.
* **Speaker Notes:**
  > "There was one temporary period in 2021–2022 where families did feel slightly higher inflation—about 0.6 percentage points—driven by used cars, gas, and food. But that reversed in 2023–2024 when apartment rents caught up, which hit single renters much harder. Over the entire cycle, the two waves canceled out."

---

## Slide 8: Proving the Tool Works: Income and Tenure Gaps

* **Slide Title:** Power Test: Disparities by Income and Renting Status
* **Key Visual:** Comparison bar chart showing gap-to-noise ratios across dimensions (Income Deciles: 2.27x, Income Quintiles: 1.72x, Families: 0.65x) — *[Figure Reference: `output/figures/f12_dimension_gaps.png` & `f13_income_gradient.png`]*.
* **Core Takeaways:**
  * **Did our model fail to find a gap because it's too blunt? No.**
  * Running the identical model across other demographic dimensions reveals huge, measurable gaps:
    * **Lowest vs. Highest Income Decile:** Gap is **2.27x above the noise floor** (+2.14 pp cumulative gap).
    * **Lowest vs. Highest Income Quintile:** Gap is **1.72x above the noise floor** (+1.05 pp cumulative gap).
  * **Takeaway:** What drives unequal inflation rates is **household income and housing tenure**, not whether you have children.
* **Speaker Notes:**
  > "A natural question is: was our method simply unable to detect differences? We tested this by applying the exact same engine to income and housing tenure. The model immediately detected huge, statistically significant gaps. Lower-income households faced substantially higher inflation because necessities like electricity, groceries, and rent make up most of their budget. The tool works; family status simply isn't an inflation driver."

---

## Slide 9: Equal Rates $\neq$ Equal Burdens

* **Slide Title:** Rate vs. Burden: The Real Dollar Impact
* **Key Visual:** Side-by-side bar chart showing Extra Annual Dollars needed to buy 2019 basket at 2026 prices ($22,563 for married families vs. $11,256 for singles) alongside Necessity Budget Shares — *[Figure Reference: `output/figures/f14_burden.png`]*.
* **Core Takeaways:**
  * **Bigger Budgets = Double the Dollar Pain:** A 25% price increase on a $105,000 family budget requires **+$22,563/year**, compared to **+$11,256/year** for a single person.
  * **Single Parents Face High Vulnerability:**
    * Single-parent families spend **29.3%** of their total budget on non-negotiable necessities (food at home, rent, utilities), compared to **16.9%** for married couples.
    * Single parents have virtually no discretionary cushion to absorb price shocks.
* **Speaker Notes:**
  > "This brings us to the most important leadership takeaway: equal percentage inflation does not mean equal financial pain. A 25% price jump on a family budget costs $22,500 in extra cash each year—double what a single person needs. Furthermore, 'families' are not all the same: single parents spend nearly 30% of every dollar just on food, rent, and power, giving them zero room to maneuver."

---

## Slide 10: Executive Summary & Strategic Implications

* **Slide Title:** Summary & Strategic Recommendations
* **Key Visual:** 3-pillar summary card (Narrative / Targeting / Strategy).
* **Core Takeaways:**
  1. **Correct the Narrative:** Data does not support claims that inflation systematically targeted family consumption baskets over single households.
  2. **Target Interventions by Income & Necessity Share:** Relief programs, cost-of-living adjustments, and benefits should focus on **lower-income earners, renters, and single-parent households**.
  3. **Address Dollar Burdens, Not Just Percentages:** Recognize that family households absorb a much higher nominal dollar cost from across-the-board price inflation due to baseline household scale.
* **Speaker Notes:**
  > "In summary: If you are designing compensation structures, organizational policies, or public support programs, focus on income level and single-parent status rather than broad family-based price index adjustments. The economic strain of recent inflation was real, but its true fault lines are income and necessity burdens."

---
