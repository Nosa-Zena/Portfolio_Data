--Data source: https://8weeksqlchallenge.com/case-study-2/
--using PostgreSQL 13

--Questions

--A. Pizza Metrics
--How many pizzas were ordered?
SELECT
COUNT(*) AS pizzas_ordered
FROM pizza_runner.customer_orders;

--How many unique customer orders were made?
SELECT 
COUNT(DISTINCT "order_id") AS unique_orders
FROM pizza_runner.customer_orders;

--How many successful orders were delivered by each runner?

SELECT
  pizza_runner.runner_orders.runner_id,
  COUNT(*) AS orders_delivered
FROM
  pizza_runner.runner_orders
JOIN
  pizza_runner.customer_orders ON pizza_runner.runner_orders.order_id = pizza_runner.customer_orders.order_id
WHERE
  pizza_runner.runner_orders.cancellation IS NULL
GROUP BY
  pizza_runner.runner_orders.runner_id;


--How many of each type of pizza was delivered?

SELECT
  pizza_runner.pizza_names.pizza_name,
  COUNT(*) AS pizza_count
FROM
  pizza_runner.runner_orders
JOIN
  pizza_runner.customer_orders ON pizza_runner.runner_orders.order_id = pizza_runner.customer_orders.order_id
JOIN
  pizza_runner.pizza_names ON pizza_runner.customer_orders.pizza_id = pizza_runner.pizza_names.pizza_id
JOIN
  pizza_runner.pizza_recipes ON pizza_runner.customer_orders.pizza_id = pizza_runner.pizza_recipes.pizza_id
WHERE
  pizza_runner.runner_orders.cancellation IS NULL
GROUP BY
  pizza_runner.pizza_names.pizza_name;



--How many Vegetarian and Meatlovers were ordered by each customer?

SELECT
  pizza_runner.customer_orders.customer_id,
  pizza_runner.pizza_names.pizza_name,
  COUNT(*) AS pizza_count
FROM
  pizza_runner.customer_orders
JOIN
  pizza_runner.pizza_names ON pizza_runner.customer_orders.pizza_id = pizza_runner.pizza_names.pizza_id
WHERE
  pizza_runner.pizza_names.pizza_name IN ('Vegetarian', 'Meatlovers')
GROUP BY
  pizza_runner.customer_orders.customer_id,
  pizza_runner.pizza_names.pizza_name
ORDER BY
  pizza_runner.customer_orders.customer_id,
  pizza_runner.pizza_names.pizza_name;



--What was the maximum number of pizzas delivered in a single order?
-- ro and co are aliases for the table names; runner_orders and customer_orders
SELECT
  ro."order_id",
  COUNT(co."pizza_id") AS pizzas_delivered
FROM
  pizza_runner.runner_orders ro
JOIN
  pizza_runner.customer_orders co ON ro."order_id" = co."order_id"
WHERE
  ro."cancellation" IS NULL
GROUP BY
  ro."order_id"
ORDER BY
  pizzas_delivered DESC



--For each customer, how many delivered pizzas had at least 1 change and how many had no changes?

SELECT
  co."customer_id",
  COUNT(CASE WHEN co."exclusions" <> '' OR co."extras" IS NOT NULL THEN 1 END) AS pizzas_with_changes,
  COUNT(CASE WHEN co."exclusions" = '' AND co."extras" IS NULL THEN 1 END) AS pizzas_with_no_changes
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
WHERE
  ro."cancellation" IS NULL
GROUP BY
  co."customer_id";


--How many pizzas were delivered that had both exclusions and extras?

SELECT
  COUNT(*) AS pizza_exclusions_and_extras
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
WHERE
  ro."cancellation" IS NULL
  AND co."exclusions" <> ''
  AND co."extras" IS NOT NULL;


--What was the total volume of pizzas ordered for each hour of the day?

SELECT
  DATE_PART('hour', co."order_time") AS hour_of_day,
  COUNT(*) AS pizzas_ordered
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
WHERE
  ro."cancellation" IS NULL
GROUP BY
  hour_of_day
ORDER BY
  hour_of_day;



--What was the volume of orders for each day of the week?

SELECT
  EXTRACT(DOW FROM co."order_time") AS day_of_week,
  COUNT(*) AS total_orders
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
WHERE
  ro."cancellation" IS NULL
GROUP BY
  day_of_week
ORDER BY
  day_of_week;



--B.Runner and Customer Experience

--How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT
  DATE_TRUNC('week', "registration_date") AS week,
  COUNT(*) AS total_runners_signed_up
FROM
  pizza_runner.runners
GROUP BY
  week
ORDER BY
  week;


--What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?

SELECT
  ro."runner_id",
  AVG(EXTRACT(EPOCH FROM ro."pickup_time"::timestamp - co."order_time"::timestamp) / 60) AS avgerage time_minutes
FROM
  pizza_runner.runner_orders ro
JOIN
  pizza_runner.customer_orders co ON ro."order_id" = co."order_id"
WHERE
  ro."cancellation" IS NULL
GROUP BY
  ro."runner_id";
