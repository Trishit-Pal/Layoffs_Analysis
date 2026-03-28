-- Exploratory Data Analysis
select * from layoffs_staging2 order by 1;

select  max(total_laid_off) from layoffs_staging2;
select * from layoffs_staging2 where percentage_laid_off =1 order by funds_raised_millions desc;

select distinct company, sum(total_laid_off) from layoffs_staging2 group by company order by 2 desc;

select industry, max(company), sum(total_laid_off) from layoffs_staging2 group by industry order by 3 desc;
select min(`date`), max(`date`) from layoffs_staging2;

select country, sum(total_laid_off) from layoffs_staging2 group by country order by 2 desc;

select `date` , sum(total_laid_off)
from layoffs_staging2 group by `date` order by 1 desc;

select year(`date`) , sum(total_laid_off)
from layoffs_staging2 group by year(`date`) order by 2 desc;

select stage , sum(total_laid_off)
from layoffs_staging2 group by stage order by 2 desc;

-- Rolling total of layoffs  by month
select substring(`date`, 6,2) as `month`, sum(total_laid_off)
from layoffs_staging2 group by `month`;

select substring(`date`, 1,7) as `month`, sum(total_laid_off)
from layoffs_staging2  where substring(`date`, 1,7) is not null group by `month` order by 1 asc;

with rolling_total as 
(
select substring(`date`, 1,7) as `month`, sum(total_laid_off) as total_off
from layoffs_staging2  where substring(`date`, 1,7) is not null group by `month` order by 1 asc
)
select `month`, total_off,
sum(total_off) over(order by `month`) as Rolling_Total from rolling_total;

select company , year(`date`), sum(total_laid_off) from layoffs_staging2
group by company, year(`date`) order by company asc;

select company , year(`date`), sum(total_laid_off) from layoffs_staging2
group by company, year(`date`) order by 3 desc;


select * from layoffs_staging2 where percentage_laid_off =1 order by total_laid_off desc;
select * from layoffs_staging2 where percentage_laid_off =1 order by funds_raised_millions desc;

-- Complex query
with company_year ( company, years, total_laid_off) as 
(
select company, year(`date`), sum(total_laid_off) from layoffs_staging2 group by company, year(`date`)
)
select *, dense_rank() over (partition by years order by total_laid_off desc)  as Ranking
from company_year where years is not null order by Ranking asc;


with company_year ( company, years, total_laid_off) as 
(
select company, year(`date`), sum(total_laid_off) from layoffs_staging2 group by company, year(`date`)
), company_year_rank as 
(select *, dense_rank() over (partition by years order by total_laid_off desc)  as Ranking
from company_year where years is not null
) 
select * from company_year_rank where Ranking <=10;