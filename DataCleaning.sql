select * from layoffs;

-- 1. Remove duplicates
-- 2. Standardize the data
-- 3. Null values or blank values
-- 4. Remove any unnecessary columns


-- working on a staging table so the raw data is untouched
create table layoffs_staging
like layoffs;

select * from layoffs_staging;

insert layoffs_staging
select * from layoffs;


-- 1. Remove Duplicates

-- checking for duplicates
with duplicate_cte as
(
select *,
row_number() over(
partition by company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) as row_num
from layoffs_staging
)
select * from duplicate_cte
where row_num > 1;

-- spot checking one of the results
select * from layoffs_staging where company = 'Oyster';


-- can't delete directly from a CTE in MySQL, so creating another staging table with row_num included
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
  `row_num` int
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_0900_ai_ci;

select * from layoffs_staging2;

insert into layoffs_staging2
select *,
row_number() over(
partition by company, location, industry, total_laid_off, percentage_laid_off, `date`, stage, country, funds_raised_millions) as row_num
from layoffs_staging;

-- verifying before delete
select * from layoffs_staging2
where row_num > 1;

delete from layoffs_staging2
where row_num > 1;


-- 2. Standardizing Data

select company, trim(company)
from layoffs_staging2;

update layoffs_staging2
set company = trim(company);

-- looking at industry values for anything inconsistent
select distinct industry
from layoffs_staging2 order by 1;

-- 'Crypto', 'Crypto Currency', 'CryptoCurrency' are all the same thing
update layoffs_staging2
set industry = 'Crypto'
where industry like '%Crypto%';

select distinct location from layoffs_staging2 order by 1;
select distinct country from layoffs_staging2 order by 1;

-- 'United States' and 'United States.' are showing up as separate — removing the trailing period
select distinct country, trim(trailing '.' from country)
from layoffs_staging2 order by 1;

update layoffs_staging2
set country = trim(trailing '.' from country)
where country like 'United States%';

-- date column came in as text, converting it properly
select `date`, str_to_date(`date`, '%m/%d/%Y')
from layoffs_staging2;

update layoffs_staging2
set `date` = str_to_date(`date`, '%m/%d/%Y');

-- now changing the column type from text to date
alter table layoffs_staging2
modify column `date` Date;

select * from layoffs_staging2;


-- 3. Null values or blank values

select * from layoffs_staging2
where industry is null or industry = '';

select * from layoffs_staging2 where company = 'Airbnb';

-- joining the table on itself to fill in missing industry values where another row for the same company has it
select st1.*, st2.industry
from layoffs_staging2 st1
join layoffs_staging2 st2
	on st1.company = st2.company
where (st1.industry is null or st1.industry = '')
and st2.industry is not null;

-- setting blanks to null first so the join update works cleanly
update layoffs_staging2
set industry = NULL
where industry = '';

update layoffs_staging2 st1
join layoffs_staging2 st2
	on st1.company = st2.company
set st1.industry = st2.industry
where st1.industry is null
and st2.industry is not null;

-- Bally's only has one row so nothing to fill from, leaving it as null
select * from layoffs_staging2
where company like 'Bally%';

-- rows where both layoff columns are null aren't useful for analysis
delete from layoffs_staging2
where total_laid_off is null
and percentage_laid_off is null;

select * from layoffs_staging2
where total_laid_off is null and percentage_laid_off is null;


-- 4. Remove unnecessary columns

-- row_num was only needed to identify duplicates, dropping it now
alter table layoffs_staging2
drop column row_num;

select * from layoffs_staging2;
