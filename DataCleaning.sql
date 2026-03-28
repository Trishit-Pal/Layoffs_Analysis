select * from layoffs;

-- Workflow ->
-- 1. Remove duplicates
-- 2. Standardize data
-- 3. Null values or blank values
-- 4. Remove unnecessary columns and rows

create table layoffs_staging like layoffs;
select * from layoffs_staging;

-- inserting data from layoffs table
insert layoffs_staging
select * from layoffs;

with duplicate_cte as
(
select *,
row_number() over(
partition by company,location, industry, total_laid_off, percentage_laid_off, 'date', stage, country, funds_raised_millions) as row_num
from layoffs_staging
)
select * from duplicate_cte where row_num >1;

select * from layoffs_staging where company = 'Oyster';




CREATE TABLE `layoffs_staging2` (
  `company` text,
  `location` text,
  `industry` text,
  `total_laid_off` int DEFAULT NULL,
  `percentage_laid_off` text,
  `date` text,
  `stage` text,
  `country` text,
  `funds_raised_millions` int DEFAULT NULL,
  row_num int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

select * from layoffs_staging2;
insert into layoffs_staging2
select * ,
row_number() over(
partition by company, location, industry, total_laid_off, percentage_laid_off, 'date',stage
,country, funds_raised_millions) as row_num
from layoffs_staging;

select * from layoffs_staging2
where row_num >1;

delete from layoffs_staging2
where row_num>1;

-- Standardizing Data
select company, trim(company)
from layoffs_staging2;

update layoffs_staging2
set company = trim(company);

select distinct industry
from layoffs_staging2 order by 1;

update layoffs_staging2
set industry = "Crypto"
where industry like "%Crypto%";

select distinct location from layoffs_staging2 order by 1;
select distinct country from layoffs_staging2 order by 1;

select distinct country, trim(trailing '.' from country)
from layoffs_staging2 order by 1;

update layoffs_staging2 set country = trim( trailing '.' from country)
where country like "United States%";

select 'date', str_to_date('date', '%m/%d/%Y') from layoffs_staging2;

update layoffs_staging2 set `date` = str_to_date(`date`, '%m/%d/%Y');
alter table layoffs_staging2 modify column `date` Date;

select * from layoffs_staging2;

select * from layoffs_staging2 where industry is null or industry ='';

select * from layoffs_staging2 where company = 'Airbnb';

select  * from layoffs_staging2 st1 join layoffs_staging2 st2 on st1.company= st2.company
where (st1.industry is null or st1.industry = '') and  st2.industry is not null;

update layoffs_staging2 set industry = NULL where industry = '';

update layoffs_staging2 st1 join layoffs_staging2 st2 on st1.company = st2.company
set st1.industry = st2.industry
where (st1.industry is null or st1.industry = '') and st2.industry is not null;

select * from layoffs_staging2
where company like "Bally%";

delete from layoffs_staging2 where total_laid_off is null 
and percentage_laid_off is null;

select * from layoffs_staging2
where total_laid_off is null and percentage_laid_off is null;

alter table layoffs_staging2 drop column  row_num;

select * from layoffs_staging2 order by 1;

with duplicate_cte as
(
select *,
row_number() over(
partition by company,location, industry, total_laid_off, percentage_laid_off, 'date', stage, country, funds_raised_millions) as row_num
from layoffs_staging
)
select * from duplicate_cte where row_num >1;