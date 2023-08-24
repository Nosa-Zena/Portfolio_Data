--Details of Dataset--
--https://8weeksqlchallenge.com/case-study-5/--
--Dialect: The postgresql 13--


--1. Data Cleansing Steps--
--Convert the week_date to a DATE format-- 
--Add a week_number as the second column for each week_date value, for example any value from the 1st of January to 7th of January will be 1, 8th to 14th will be 2 etc--
--Add a month_number with the calendar month for each week_date value as the 3rd column--
--Add a calendar_year column as the 4th column containing either 2018, 2019 or 2020 values--
--Add a new column called age_band after the original segment column using the following mapping on the number inside the segment value--

CREATE TABLE data_mart.clean_weekly_sales AS
SELECT 
  To_date(week_date, 'DD/MM/YY') AS week_date,
  EXTRACT(WEEK FROM To_date(week_date, 'DD/MM/YY')) AS week_number, 
  EXTRACT(MONTH FROM To_date(week_date, 'DD/MM/YY')) AS month_number,
  CASE
    WHEN To_date("week_date", 'DD/MM/YY') BETWEEN '2018-01-01' AND '2018-12-31' THEN '2018'
    WHEN To_date("week_date", 'DD/MM/YY') BETWEEN '2019-01-01' AND '2019-12-31' THEN '2019'
    ELSE '2020'
  END AS calendar_year,
  CASE 
    WHEN segment = '1' THEN 'Young Adults'
    WHEN segment = '2' THEN 'Middle Aged'
    WHEN segment IN ('3', '4') THEN 'Retirees'
    ELSE 'Unknown'
  END AS age_band,
  CASE
    WHEN LEFT(segment, 1) = 'C' THEN 'Couples'
    WHEN LEFT(segment, 1) = 'F' THEN 'Families'
    ELSE 'Unknown'
  END AS demographic,
  ROUND(sales/transactions, 2) AS avg_transaction,
  region,
  platform,
  COALESCE(segment, 'Unknown') AS segment,
  customer_type,
  transactions,
  sales
FROM 
  data_mart.weekly_sales;
  
  
  
--2. Data Exploration--
  
--What day of the week is used for each week_date value?--

SELECT week_date, to_char(week_date, 'Day') AS day_of_week
FROM data_mart.clean_weekly_sales;

--What range of week numbers are missing from the dataset?--

WITH RECURSIVE counter(current_value) AS (
  SELECT 1
  UNION ALL
  SELECT current_value + 1 FROM counter WHERE current_value < 53
)
SELECT current_value FROM counter 
WHERE current_value NOT IN (
  SELECT DISTINCT week_number FROM data_mart.clean_weekly_sales
);
  --4 How many total transactions were there for each year in the dataset?--
SELECT calendar_year, SUM(transactions) AS total_transactions
FROM data_mart.clean_weekly_sales
GROUP BY calendar_year;

--5 What is the total sales for each region for each month?--
SELECT 
  month_number,
  region,
  SUM(sales) AS total_sales
FROM 
  data_mart.clean_weekly_sales
GROUP BY 
  month_number,
  region
ORDER BY 
  month_number,
  region;
  
 -- 5 What is the total count of transactions for each platform?--
  
  SELECT platform, SUM(transactions) AS total_transactions
  FROM data_mart.clean_weekly_sales
  GROUP BY platform;
  
 --6 What is the percentage of sales for Retail vs Shopify for each month?--
  WITH retail_sales AS (
  SELECT
    EXTRACT(MONTH FROM week_date) AS month_number,
    EXTRACT(YEAR FROM week_date) AS calendar_year,
    SUM(sales) AS retail_sales
  FROM
    data_mart.clean_weekly_sales
  WHERE
    platform = 'Retail'
  GROUP BY
    EXTRACT(MONTH FROM week_date),
    EXTRACT(YEAR FROM week_date)
), 
shopify_sales AS (
  SELECT
    EXTRACT(MONTH FROM week_date) AS month_number,
     EXTRACT(YEAR FROM week_date) AS calendar_year,
    SUM(sales) AS shopify_sales
  FROM
    data_mart.clean_weekly_sales
  WHERE
    platform = 'Shopify'
  GROUP BY
    EXTRACT(MONTH FROM week_date),
    EXTRACT(YEAR FROM week_date)
)
SELECT 
  retail_sales.month_number, 
  retail_sales.calendar_year,
  retail_sales.retail_sales, 
  shopify_sales.shopify_sales,
  ROUND(retail_sales.retail_sales/(retail_sales.retail_sales + shopify_sales.shopify_sales)::numeric * 100, 2) AS retail_percentage,
  ROUND(shopify_sales.shopify_sales/(retail_sales.retail_sales + shopify_sales.shopify_sales)::numeric * 100, 2) AS shopify_percentage
FROM 
  retail_sales 
JOIN 
  shopify_sales 
ON 
  retail_sales.month_number = shopify_sales.month_number
  AND retail_sales.calendar_year = shopify_sales.calendar_year
ORDER BY 
  retail_sales.month_number DESC;
  
--7 What is the percentage of sales by demographic for each year in the dataset?--

WITH demographics_sales AS (
  SELECT
    calendar_year,
    SUM(CASE When demographic='Couples' THEN sales ELSE 0 END) AS couples_sales,
    SUM(CASE WHEN demographic='Families' THEN sales ELSE 0 END) AS families_sales,
    SUM(CASE WHEN demographic='Unknown' THEN sales ELSE 0 END) AS unknown_sales,
    SUM(sales) AS total_sales
  FROM
    data_mart.clean_weekly_sales
  GROUP BY
    calendar_year
)
SELECT
  calendar_year,
  ROUND(couples_sales*100.0/total_sales, 2) AS couples_sales_percent,
  ROUND(families_sales*100.0/total_sales, 2) AS families_sales_percent,
  ROUND(unknown_sales*100.0/total_sales, 2) AS unknown_sales_percent
FROM
  demographics_sales
ORDER BY
  calendar_year DESC;
  
  
--8 Which age_band and demographic values contribute the most to Retail sales?--
 
 SELECT age_band, demographic, SUM(sales) AS total_sales
FROM data_mart.clean_weekly_sales
WHERE platform = 'Retail'
GROUP BY age_band, demographic
ORDER BY total_sales DESC;
 
 --9 Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?--
  
  SELECT
  calendar_year,
  platform,
  AVG(avg_transaction) AS average_transaction_size
FROM
  data_mart.clean_weekly_sales
WHERE
  calendar_year IN ('2018', '2019', '2020')
  AND platform IN ('Retail', 'Shopify')
GROUP BY
  calendar_year,
  platform
ORDER BY calendar_year , platform
  
 
  --3. Data analysis, before and after.--
--Taking the week_date value of 2020-06-15 as the baseline week where the Data Mart sustainable packaging changes came into effect.
We would include all week_date values for 2020-06-15 as the start of the period after the change and the previous week_date values would be before
Using this analysis approach - answer the following questions:--

a. What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?

WITH before_after AS (
  SELECT
    *,
    CASE WHEN week_date >= '2020-06-15' THEN 'after'
         ELSE 'before'
    END AS before_after
  FROM
    data_mart.clean_weekly_sales
  WHERE
    calendar_year = '2020'
),
sales_tab AS (
  SELECT
    SUM(CASE WHEN before_after = 'before' AND week_date >= '2020-05-18' THEN CAST(sales AS bigint) END) AS before_sales,
    SUM(CASE WHEN before_after = 'after' AND week_date <= '2020-07-13' THEN CAST(sales AS bigint) END) AS after_sales
  FROM
    before_after
)
SELECT
  DATE('2020-06-15') - INTERVAL '4 weeks' AS date_before,
  DATE('2020-06-15') AS baseline_date,
  DATE('2020-06-15') + INTERVAL '4 weeks' AS date_after,
  before_sales,
  after_sales,
  after_sales - before_sales AS sales_difference,
  ROUND(((after_sales - before_sales) * 100.0 / before_sales)::numeric, 2) AS percent_change
FROM
  sales_tab;
 
  
  b. What about the entire 12 weeks before and after?
  WITH before_after AS (
  SELECT
    *,
    CASE WHEN week_date >= DATE '2020-06-15' THEN 'after'
         ELSE 'before'
    END AS before_after
  FROM
   data_mart.clean_weekly_sales
  WHERE
    calendar_year = '2020'
),
sales_tab AS (
  SELECT
    SUM(CASE WHEN before_after = 'before' AND week_date >= DATE '2020-03-23' THEN CAST(sales AS bigint) END) AS before_sales,
    SUM(CASE WHEN before_after = 'after' AND week_date <= DATE '2020-09-07' THEN CAST(sales AS bigint) END) AS after_sales
  FROM
    before_after
)
SELECT
  DATE_TRUNC('week', DATE '2020-06-15' - INTERVAL '12 weeks') AS date_before,
  DATE '2020-06-15' AS baseline_date,
  DATE_TRUNC('week', DATE '2020-06-15' + INTERVAL '12 weeks') AS date_after,
  before_sales,
  after_sales,
  after_sales - before_sales AS sales_difference,
  ROUND(((after_sales - before_sales) * 100.0 / before_sales)::numeric, 2) AS percent_change
FROM
  sales_tab;

  c. How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
  WITH before_after AS (
  SELECT
    calendar_year,
    SUM(CASE WHEN week_number BETWEEN 21 AND 24 THEN Total_Sales END) AS before_sales,
    SUM(CASE WHEN week_number BETWEEN 25 AND 28 THEN Total_Sales END) AS after_sales
  FROM (
    SELECT
      calendar_year,
      week_number,
      SUM(CAST(sales AS bigint)) AS Total_Sales
    FROM
      data_mart.clean_weekly_sales
    WHERE
      calendar_year IN ('2018', '2019', '2020')
      AND week_number BETWEEN 21 AND 28
    GROUP BY
      calendar_year,
      week_number
  ) AS sales
  GROUP BY
    calendar_year
)
SELECT
  calendar_year,
  before_sales,
  after_sales,
  after_sales - before_sales AS sales_difference,
  ((after_sales - before_sales) * 100.0 / before_sales) AS percent_difference
FROM
  before_after;

--Bonus Question--
--Which areas of the business have the highest negative impact in sales metrics performance in 2020 for the 12 week before and after period?--

WITH sales AS (
  SELECT
    region,
    platform,
    age_band,
    demographic,
    customer_type,
    SUM(CASE WHEN week_number BETWEEN 21 AND 28 THEN sales END) AS total_sales,
    SUM(CASE WHEN week_number BETWEEN 21 AND 24 THEN sales END) AS before_sales,
    SUM(CASE WHEN week_number BETWEEN 25 AND 28 THEN sales END) AS after_sales
  FROM
    data_mart.clean_weekly_sales
  WHERE
    calendar_year = '2020'
  GROUP BY
    region,
    platform,
    age_band,
    demographic,
    customer_type
)
SELECT
  region,
  platform,
  age_band,
  demographic,
  customer_type,
  after_sales - before_sales AS sales_difference,
  ((after_sales - before_sales) * 100.0 / before_sales) AS percentage_difference
FROM
  sales
ORDER BY
  sales_difference ASC;


--Findings--
--In the previous years 2018 and 2019, there is a consistent increase in sales in the weeks 25 through 28. However, the implementation of the new packaging in 2020there was a drop in sales in week 25 compared to previous years.its reduction is by 6.7%--
--The "retail" platform,, age_band "unknown", region "oceania",demographic "families", customer type "existing" had the highest negative impact on the sales metric performance with a sales deifference of -6316023.

--Further Recommendation--
-- Seek Customer feedback on the sustainability updates already implemented, this way their input helps refine and improve your initiations.--
--Introduce incentives, this will encourage customers to support your sustainabilty updates e.g. discounts, loyalty cards.
--By balancing both environmental impact and customer satisfaction, the potential negative impact on sales can be minimised.
