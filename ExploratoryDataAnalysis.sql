-- Exploratory Data Analysis

select * from layoffs_staging2;


-- looking at the scale of the data first
select max(total_laid_off), max(percentage_laid_off)
from layoffs_staging2;

-- percentage_laid_off = 1 means the whole company shut down
select * from layoffs_staging2
where percentage_laid_off = 1
order by total_laid_off desc;

-- same but checking which of those had the most funding before shutting down
select * from layoffs_staging2
where percentage_laid_off = 1
order by funds_raised_millions desc;


-- total layoffs per company across the whole period
select distinct company, sum(total_laid_off)
from layoffs_staging2
group by company
order by 2 desc;

-- breaking it down by industry
select industry, max(company), sum(total_laid_off)
from layoffs_staging2
group by industry
order by 3 desc;

-- date range of the dataset
select min(`date`), max(`date`)
from layoffs_staging2;

-- by country
select country, sum(total_laid_off)
from layoffs_staging2
group by country
order by 2 desc;

-- by date (daily level — gets noisy but useful for spotting spikes)
select `date`, sum(total_laid_off)
from layoffs_staging2
group by `date`
order by 1 desc;

-- annual totals — which year was worst
select year(`date`), sum(total_laid_off)
from layoffs_staging2
group by year(`date`)
order by 2 desc;

-- by funding stage
select stage, sum(total_laid_off)
from layoffs_staging2
group by stage
order by 2 desc;


-- Rolling total of layoffs by month

-- just the month number, not very useful on its own
select substring(`date`, 6, 2) as `month`, sum(total_laid_off)
from layoffs_staging2
group by `month`;

-- with year included — much more meaningful
select substring(`date`, 1, 7) as `month`, sum(total_laid_off)
from layoffs_staging2
where substring(`date`, 1, 7) is not null
group by `month`
order by 1 asc;

-- rolling cumulative total month over month
with rolling_total as
(
select substring(`date`, 1, 7) as `month`, sum(total_laid_off) as total_off
from layoffs_staging2
where substring(`date`, 1, 7) is not null
group by `month`
order by 1 asc
)
select `month`, total_off,
sum(total_off) over(order by `month`) as Rolling_Total
from rolling_total;


-- breaking down layoffs by company and year
select company, year(`date`), sum(total_laid_off)
from layoffs_staging2
group by company, year(`date`)
order by company asc;

-- same, ordered by total to see who laid off the most in a given year
select company, year(`date`), sum(total_laid_off)
from layoffs_staging2
group by company, year(`date`)
order by 3 desc;


-- top 5 companies per year by layoffs
-- using dense_rank so ties don't create gaps in the ranking
with company_year (company, years, total_laid_off) as
(
select company, year(`date`), sum(total_laid_off)
from layoffs_staging2
group by company, year(`date`)
)
select *, dense_rank() over(partition by years order by total_laid_off desc) as Ranking
from company_year
where years is not null
order by Ranking asc;

-- filtering to just the top 5 per year
with company_year (company, years, total_laid_off) as
(
select company, year(`date`), sum(total_laid_off)
from layoffs_staging2
group by company, year(`date`)
),
company_year_rank as
(
select *, dense_rank() over(partition by years order by total_laid_off desc) as Ranking
from company_year
where years is not null
)
select * from company_year_rank
where Ranking <= 5;
