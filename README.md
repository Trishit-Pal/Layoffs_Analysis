# Tech Layoffs — SQL Data Analysis Project (2020–2023)

> End-to-end data analysis project using MySQL — covering data cleaning, exploratory analysis, and business intelligence on global tech sector layoffs.

---

## Project Overview

This project demonstrates a complete data analyst workflow applied to a real-world dataset of global tech layoffs spanning March 2020 to March 2023. The goal was to clean raw, inconsistent data and extract business-meaningful insights using SQL alone — no BI tool dependency.

**Tool:** MySQL Workbench 8.0  
**Dataset:** `layoffs.csv` — 2,361 rows, 9 columns  
**Output:** Clean analytical table (`layoffs_staging2`) + EDA query suite

---

## Repository Structure

```
├── layoffs.csv                          # Raw dataset (source data)
├── DataCleaning_annotated.sql           # Full cleaning pipeline with comments
├── ExploratoryDataAnalysis_annotated.sql # EDA queries with commentary
├── tech_layoffs_dashboard.html          # Interactive business dashboard
└── README.md                            # This file
```

---

## Dataset Schema

| Column | Type | Null Rate | Description |
|---|---|---|---|
| `company` | TEXT | 0% | Company name |
| `location` | TEXT | 0% | City of headquarters |
| `industry` | TEXT | ~0.2% | Industry sector |
| `total_laid_off` | INT | 31.3% | Headcount reduction |
| `percentage_laid_off` | TEXT | 33.2% | Fraction of workforce; 1.0 = full shutdown |
| `date` | TEXT → DATE | ~0% | Date of layoff announcement |
| `stage` | TEXT | ~0.3% | Funding stage at time of layoff |
| `country` | TEXT | 0% | Country of HQ |
| `funds_raised_millions` | INT | 8.8% | Total capital raised to date |

---

## Data Cleaning Pipeline — Step by Step

### Why a Staging Table?

Raw data is never modified. Two staging tables are created:

- `layoffs_staging` — exact copy of raw data (safety backup)
- `layoffs_staging2` — workspace for transformation, includes `row_num` helper column

This mirrors production ETL best practice: raw data is always recoverable.

---

### Step 1: Remove Duplicates

**Method:** `ROW_NUMBER()` window function partitioned over all 9 columns.

Any row with `row_num > 1` is an exact duplicate. MySQL does not support `DELETE` on a CTE directly, so duplicates are removed from `layoffs_staging2` where the `row_num` column was pre-computed.

**Bug found in original code:**  
The original query used `'date'` (string literal) in the `PARTITION BY` clause instead of `` `date` `` (column reference). This meant the date field was not actually being used for deduplication.

```sql
-- ❌ Original (bug)
PARTITION BY company, location, ..., 'date', ...

-- ✅ Fixed
PARTITION BY company, location, ..., `date`, ...
```

---

### Step 2: Standardize Data

Issues found and corrected:

| Issue | Fix Applied |
|---|---|
| Leading/trailing spaces in company names | `TRIM(company)` |
| "Crypto", "Crypto Currency", "CryptoCurrency" variants | `LIKE '%Crypto%'` → standardized to "Crypto" |
| "United States." with trailing period | `TRIM(TRAILING '.' FROM country)` |
| Date stored as TEXT in `MM/DD/YYYY` format | `STR_TO_DATE()` then `ALTER TABLE MODIFY COLUMN date DATE` |

Converting the date column to a proper `DATE` type is critical — it unlocks `YEAR()`, `MONTH()`, `DATE_FORMAT()`, and date arithmetic in all downstream queries.

---

### Step 3: NULL and Blank Value Handling

**Strategy:**
1. Convert blank strings `''` to `NULL` for consistent NULL semantics in SQL
2. Impute missing `industry` values using a self-join on `company` name — if the same company appears elsewhere with an industry filled in, backfill the NULL rows
3. Delete rows where **both** `total_laid_off` AND `percentage_laid_off` are NULL — these have zero analytical value

**Self-join imputation query:**
```sql
UPDATE layoffs_staging2 st1
JOIN layoffs_staging2 st2 ON st1.company = st2.company
SET st1.industry = st2.industry
WHERE st1.industry IS NULL AND st2.industry IS NOT NULL;
```

This is smarter than deletion — it recovers otherwise useful records. Example: Airbnb had `industry` missing in one row but present in another; the self-join backfills it.

---

### Step 4: Remove Helper Columns

The `row_num` column was a deduplication tool only. After cleaning, it is dropped:

```sql
ALTER TABLE layoffs_staging2 DROP COLUMN row_num;
```

---

## Exploratory Data Analysis — Key Queries

### Annual Totals

```sql
SELECT YEAR(`date`) AS year, SUM(total_laid_off)
FROM layoffs_staging2
GROUP BY YEAR(`date`)
ORDER BY 2 DESC;
```

| Year | Total Layoffs |
|---|---|
| 2022 | 161,711 |
| 2023 (Q1) | 127,277 |
| 2020 | 81,068 |
| 2021 | 15,823 |

2022 was the worst year — a 922% increase over 2021's near-zero level. The 2021 "calm" was caused by zero-interest-rate policy (ZIRP) fuelling aggressive over-hiring across the sector.

---

### Rolling Cumulative Total

```sql
WITH rolling_total AS (
  SELECT DATE_FORMAT(`date`, '%Y-%m') AS `month`,
         SUM(total_laid_off) AS total_off
  FROM layoffs_staging2
  WHERE `date` IS NOT NULL
  GROUP BY `month` ORDER BY 1 ASC
)
SELECT `month`, total_off,
       SUM(total_off) OVER(ORDER BY `month`) AS Rolling_Total
FROM rolling_total;
```

The rolling total crossed 100K in early 2022, and then surged past 300K by January 2023 — driven by the single worst month on record: **84,714 layoffs in January 2023 alone** (Google 12K + Microsoft 10K + Amazon 8K + Salesforce 8K in one month).

---

### Top Companies Per Year — Multi-CTE + DENSE_RANK()

```sql
WITH company_year (company, years, total_laid_off) AS (
  SELECT company, YEAR(`date`), SUM(total_laid_off)
  FROM layoffs_staging2
  GROUP BY company, YEAR(`date`)
),
company_year_rank AS (
  SELECT *,
    DENSE_RANK() OVER (PARTITION BY years ORDER BY total_laid_off DESC) AS Ranking
  FROM company_year
  WHERE years IS NOT NULL
)
SELECT * FROM company_year_rank WHERE Ranking <= 10;
```

**Why `DENSE_RANK` over `RANK`?**  
`RANK()` creates gaps on ties (1, 1, 3, 4) and can incorrectly exclude companies from a top-10 filter. `DENSE_RANK()` uses consecutive values (1, 1, 2, 3) and is correct for filtering.

---

## Key Findings

### 1. The 2022 Correction Was Unprecedented
2022 saw 161,711 layoffs — nearly 10× the 2021 figure. The Federal Reserve's rate hiking cycle deflated overvalued tech stocks and forced a mass correction of ZIRP-era over-hiring.

### 2. January 2023 Was the Single Worst Month
84,714 layoffs in one month. Google, Microsoft, Amazon, and Salesforce all announced major rounds simultaneously. The cumulative total jumped from ~275K to ~360K in 30 days.

### 3. Post-IPO Companies Dominate
204,882 of total layoffs (53%) came from Post-IPO stage companies. Public market pressure to cut costs and restore margins — under analyst scrutiny — drove far larger absolute cuts than private companies.

### 4. Big Tech Concentration
The top 10 companies (Amazon, Google, Meta, Salesforce, Philips, Microsoft, Ericsson, Uber, Dell, Booking.com) account for approximately 108,576 layoffs — 28% of the entire dataset total — from just 10 companies out of 1,893.

### 5. US Accounts for 66.8% of All Layoffs
United States: 258,159 layoffs. India is a distant second at 35,993. US concentration is partly explained by the prevalence of US-headquartered tech companies in the dataset.

### 6. Consumer and Retail Hardest Hit by Sector
Consumer (46,682) and Retail (43,613) led all industries. Both sectors expanded dramatically during COVID-era stimulus spending and contracted sharply as consumer sentiment cooled.

### 7. 116 Complete Shutdowns
116 companies laid off 100% of staff. Several had raised hundreds of millions in funding before closure. Notable examples: Britishvolt ($2.4B raised), Convoy ($900M), Olive AI ($852M).

### 8. India's Edtech and Fintech Correction
India ranked 2nd globally. WhiteHat Jr, Byju's affiliates, and multiple fintech firms were significant contributors — reflecting a broader correction in Indian startup valuations post-2021.

---

## SQL Techniques Demonstrated

| Technique | Application |
|---|---|
| CTEs (`WITH` clause) | Duplicate detection, rolling totals, multi-step ranking |
| Window Functions | `ROW_NUMBER()` for dedup, `DENSE_RANK()` for ranking, `SUM() OVER()` for rolling totals |
| Self JOIN | NULL industry imputation |
| `STR_TO_DATE()` + `ALTER TABLE` | Type casting TEXT date column to DATE |
| `TRIM()` / `LIKE` | Whitespace removal and label standardization |
| `GROUP BY` + `HAVING` | Aggregation and duplicate detection |
| `SUBSTRING()` / `YEAR()` / `DATE_FORMAT()` | Temporal extraction and slicing |
| Staging tables | Raw data preservation and audit trail |
| `COALESCE()` | NULL-safe aggregation (enhancement applied) |

---

## Suggested Enhancements Applied

1. **`'date'` → `` `date` ``** — Fixed string literal bug in original PARTITION BY clause
2. **`DATE_FORMAT()` over `SUBSTRING()`** — More robust once column is proper DATE type
3. **`COALESCE(total_laid_off, 0)`** — Prevents silent exclusion of NULL rows in SUM aggregations
4. **Validation query at end** — Re-run duplicate check post-cleaning to confirm 0 duplicates remain
5. **Index suggestions** — Add indexes on `company`, `date`, `country`, `industry` for query performance at scale

---

## How to Run

1. Import `layoffs.csv` into MySQL as table `layoffs`
2. Run `DataCleaning_annotated.sql` in sequence — creates and populates `layoffs_staging2`
3. Run `ExploratoryDataAnalysis_annotated.sql` against `layoffs_staging2`
4. Open `tech_layoffs_dashboard.html` in any modern browser for the interactive dashboard

---

## About This Project

This project was built to demonstrate core data analyst competencies valued at product-based firms:

- **Data quality thinking** — identifying and fixing issues before analysis, not after
- **SQL fluency** — window functions, CTEs, self-joins, type casting
- **Business framing** — translating query results into decision-relevant narratives
- **Reproducibility** — staging table pattern, validation queries, annotated code

---

*Dataset sourced from public layoff tracking data. Analysis performed in MySQL Workbench 8.0.*
