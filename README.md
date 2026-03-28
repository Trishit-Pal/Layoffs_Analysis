# Tech Layoffs — SQL Data Analysis (2020–2023)

A data analysis project on global tech sector layoffs using MySQL — covering data cleaning and exploratory analysis.

**Tool:** MySQL Workbench 8.0  
**Dataset:** `layoffs.csv` — 2,361 rows, 9 columns  

---

## Files

```
├── layoffs.csv                       # raw dataset
├── DataCleaning.sql                  # cleaning pipeline
├── ExploratoryDataAnalysis.sql       # EDA queries
├── tech_layoffs_dashboard.html       # interactive dashboard
└── README.md
```

---

## Dataset

| Column | Type | Description |
|---|---|---|
| `company` | TEXT | company name |
| `location` | TEXT | city |
| `industry` | TEXT | sector |
| `total_laid_off` | INT | headcount cut |
| `percentage_laid_off` | TEXT | fraction of workforce; 1.0 = full shutdown |
| `date` | TEXT → DATE | announcement date |
| `stage` | TEXT | funding stage at time of layoff |
| `country` | TEXT | country of HQ |
| `funds_raised_millions` | INT | total capital raised |

---

## Data Cleaning

The raw table is never touched. Everything runs on a staging table (`layoffs_staging`), and a second one (`layoffs_staging2`) is created to handle the deduplication step since MySQL doesn't allow deleting directly from a CTE.

**Steps followed:**

**1. Remove duplicates** — used `row_number()` partitioned over all columns to flag duplicates, then deleted rows where `row_num > 1` from `layoffs_staging2`.

**2. Standardize data** — trimmed whitespace from company names, collapsed crypto industry variants (`'Crypto Currency'`, `'CryptoCurrency'` etc.) into `'Crypto'`, removed a trailing period from `'United States.'`, and converted the date column from text to a proper `DATE` type using `str_to_date()`.

**3. Handle nulls** — blanks in the industry column were set to null first, then filled in using a self-join where another row for the same company had the value. Rows where both `total_laid_off` and `percentage_laid_off` were null got deleted since they're not useful for analysis.

**4. Drop helper column** — `row_num` was only needed for deduplication so it gets dropped at the end.

---

## Exploratory Analysis

Queries are in `ExploratoryDataAnalysis.sql` and cover:

- max layoffs and companies that fully shut down (`percentage_laid_off = 1`)
- totals by company, industry, country, year, and funding stage
- monthly breakdown and rolling cumulative total using a window function
- top 5 companies per year using a two-CTE approach with `dense_rank()`

`dense_rank()` is used instead of `rank()` so ties don't create gaps that would push companies out of the top 5 filter.

---

## What the data shows

- **2022 was the worst year** — 161,711 layoffs, compared to just 15,823 in 2021. The 2021 low came from zero-interest-rate hiring booms; 2022 was the correction.
- **January 2023 was the worst single month** — 84,714 layoffs. Google, Microsoft, Amazon, and Salesforce all cut in the same month.
- **Post-IPO companies accounted for the most layoffs** — public market pressure to cut costs hit harder than early-stage companies.
- **US made up ~66% of all layoffs** — 258,159 out of 386,379. India was second at 35,993.
- **Consumer and Retail were hit hardest by sector** — 46,682 and 43,613 respectively.
- **116 companies laid off 100% of staff** — some had raised hundreds of millions before shutting down.

---

## How to run

1. Import `layoffs.csv` into MySQL as a table called `layoffs`
2. Run `DataCleaning.sql` — this creates and populates `layoffs_staging2`
3. Run `ExploratoryDataAnalysis.sql` against `layoffs_staging2`
4. Open `tech_layoffs_dashboard.html` in a browser for the visual summary

---

*MySQL Workbench 8.0 · dataset from public layoff tracking records*
