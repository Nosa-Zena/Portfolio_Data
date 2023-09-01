--Data source: https://8weeksqlchallenge.com/case-study-2/
--Dialect: PostgreSQL 13

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


--Is there any relationship between the number of pizzas and how long the order takes to prepare?

SELECT
  co."order_id",
  COUNT(co."pizza_id") AS pizzas_number,
  AVG(EXTRACT(EPOCH FROM ro."pickup_time"::timestamp - co."order_time"::timestamp) / 60) AS avg_prep_time_minutes
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
WHERE
  ro."cancellation" IS NULL
GROUP BY
  co."order_id"
ORDER BY
  pizzas_number;

--What was the average distance travelled for each customer?

SELECT
  co."customer_id",
  AVG(CAST(SUBSTRING(ro."distance" FROM '(\d+\.\d+)') AS DECIMAL)) AS avg_distance
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
WHERE
  ro."cancellation" IS NULL
GROUP BY
  co."customer_id"
ORDER BY
  co."customer_id";



--What was the difference between the longest and shortest delivery times for all orders?
WITH delivery_times AS (
  SELECT
    co."order_id",
    EXTRACT(EPOCH FROM ro."pickup_time"::timestamp - co."order_time"::timestamp) / 60 AS delivery_time_minutes
  FROM
    pizza_runner.customer_orders co
  JOIN
    pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
  WHERE
    ro."cancellation" IS NULL
)
SELECT
  MAX(delivery_time_minutes) AS max_delivery_time_minutes,
  MIN(delivery_time_minutes) AS min_delivery_time_minutes,
  MAX(delivery_time_minutes) - MIN(delivery_time_minutes) AS difference_minutes
FROM
  delivery_times;


--What was the average speed for each runner for each delivery and do you notice any trend for these values?
WITH delivery_speeds AS (
  SELECT
    ro."runner_id",
    ro."order_id",
    CASE
      WHEN ro."duration" ~ '^\d+(\.\d+)? minutes?$' THEN 
        CAST(SUBSTRING(ro."duration" FROM '^\d+(\.\d+)?') AS DECIMAL)
      ELSE NULL
    END AS duration_minutes,
    CAST(SUBSTRING(ro."distance" FROM '^\d+(\.\d+)?') AS DECIMAL) AS distance_km
  FROM
    pizza_runner.runner_orders ro
  WHERE
    ro."cancellation" IS NULL
)
SELECT
  ds."runner_id",
  ds."order_id",
  ds."distance_km",
  ds."duration_minutes",
  CASE
    WHEN ds."duration_minutes" IS NOT NULL THEN
      ds."distance_km" / ds."duration_minutes"
    ELSE NULL
  END AS avg_speed_kmh
FROM
  delivery_speeds ds;


--What is the successful delivery percentage for each runner?

WITH delivery_counts AS (
  SELECT
    "runner_id",
    COUNT("order_id") AS total_deliveries,
    SUM(CASE WHEN "cancellation" IS NULL THEN 1 ELSE 0 END) AS successful_deliveries
  FROM
    pizza_runner.runner_orders
  GROUP BY
    "runner_id"
)
SELECT
  dc."runner_id",
  dc.total_deliveries,
  dc.successful_deliveries,
  (dc.successful_deliveries::DECIMAL / dc.total_deliveries) * 100 AS successful_delivery_percentage
FROM
  delivery_counts dc;



-- C.Ingredient Optimisation--

--What are the standard ingredients for each pizza?
SELECT
  pn."pizza_name",
  pr."toppings"
FROM
  pizza_runner.pizza_names pn
JOIN
  pizza_runner.pizza_recipes pr ON pn."pizza_id" = pr."pizza_id";


--What was the most commonly added extra?
SELECT
  pt."topping_name",
  COUNT(*) AS topping_count
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.pizza_recipes pr ON co."pizza_id" = pr."pizza_id"
JOIN
  pizza_runner.pizza_toppings pt ON co."extras" LIKE '%' || pt."topping_id" || '%'
WHERE
  co."extras" IS NOT NULL
GROUP BY
  pt."topping_name"
ORDER BY
  topping_count DESC
LIMIT 1;


--What was the most common exclusion?
SELECT
  "exclusions",
  COUNT(*) AS exclusion_count
FROM
  pizza_runner.customer_orders
WHERE
  "exclusions" IS NOT NULL
GROUP BY
  "exclusions"
ORDER BY
  exclusion_count DESC
LIMIT 1;



--Generate an order item for each record in the customers_orders table in the format of one of the following:

--Meat Lovers
--Meat Lovers - Exclude Beef
--Meat Lovers - Extra Bacon
--Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers


SELECT
  co."order_id",
  CASE
    WHEN pr."toppings" IS NULL THEN pn."pizza_name"
    ELSE
      pn."pizza_name"
      || CASE WHEN co."exclusions" IS NOT NULL THEN ' - Exclude ' || REPLACE(co."exclusions", ', ', ',')
              ELSE ''
         END
      || CASE WHEN co."extras" IS NOT NULL THEN ' - Extra ' || REPLACE(co."extras", ', ', ',')
              ELSE ''
         END
  END AS order_item
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.pizza_names pn ON co."pizza_id" = pn."pizza_id"
LEFT JOIN
  pizza_runner.pizza_recipes pr ON co."pizza_id" = pr."pizza_id";



--Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"
  SELECT
  co."order_id",
  pn."pizza_name"
  || ': '
  || STRING_AGG(
       CASE
         WHEN pt."topping_id"::TEXT IN (SELECT UNNEST(string_to_array(co."exclusions", ', '))) THEN pt."topping_name"
         ELSE '2x' || pt."topping_name"
       END,
       ', ' ORDER BY pt."topping_name"
     ) AS ingredient_list
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.pizza_names pn ON co."pizza_id" = pn."pizza_id"
JOIN
  pizza_runner.pizza_recipes pr ON co."pizza_id" = pr."pizza_id"
JOIN
  pizza_runner.pizza_toppings pt ON pt."topping_id"::TEXT = ANY(string_to_array(pr."toppings", ', '))
GROUP BY
  co."order_id", pn."pizza_name"
ORDER BY


--What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?

SELECT
  pt."topping_name" AS ingredient,
  COUNT(*) AS total_quantity
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.pizza_recipes pr ON co."pizza_id" = pr."pizza_id"
JOIN
  pizza_runner.pizza_toppings pt ON pt."topping_id"::TEXT = ANY(string_to_array(pr."toppings", ', '))
WHERE
  co."extras" IS NULL
  AND co."order_id" NOT IN (SELECT "order_id" FROM pizza_runner.runner_orders WHERE "cancellation" IS NOT NULL)
GROUP BY
  pt."topping_name"
ORDER BY
  total_quantity DESC;

--D. Pricing and Ratings


--If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?

SELECT
  SUM(
    CASE
      WHEN pn."pizza_name" = 'Meatlovers' THEN 12
      WHEN pn."pizza_name" = 'Vegetarian' THEN 10
      ELSE 0
    END
  ) AS total_revenue
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.pizza_names pn ON co."pizza_id" = pn."pizza_id"
WHERE
  co."order_id" NOT IN (SELECT "order_id" FROM pizza_runner.runner_orders WHERE "cancellation" IS NOT NULL);


--What if there was an additional $1 charge for any pizza extras?

SELECT
  SUM(
    CASE
      WHEN pn."pizza_name" = 'Meatlovers' THEN (12 + 1 * (LENGTH(co."extras") - LENGTH(REPLACE(co."extras", ',', ''))))
      WHEN pn."pizza_name" = 'Vegetarian' THEN (10 + 1 * (LENGTH(co."extras") - LENGTH(REPLACE(co."extras", ',', ''))))
      ELSE 0
    END
  ) AS total_revenue
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.pizza_names pn ON co."pizza_id" = pn."pizza_id"
WHERE
  co."order_id" NOT IN (SELECT "order_id" FROM pizza_runner.runner_orders WHERE "cancellation" IS NOT NULL);

--The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - 
--generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

DROP TABLE IF EXISTS customer_ratings;
  CREATE TABLE customer_ratings (
  "rating_id" SERIAL PRIMARY KEY,
  "order_id" INTEGER NOT NULL,
  "runner_id" INTEGER NOT NULL,
  "customer_id" INTEGER NOT NULL,
  "rating" INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  "comment" TEXT,
  "rating_time" TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

INSERT INTO customer_ratings ("order_id", "runner_id", "customer_id", "rating", "comment")
VALUES
  (1, 1, 101, 4, 'Good service'),
  (1, 1, 104, 3, 'Nice delivery!!'),  
  (2, 1, 101, 5, 'Excellent delivery!'),
  (3, 1, 102, 3, 'Average delivery'),
  (4, 2, 103, 5, 'Great runner!'),
  (4, 3, 102, 4, 'Awesome service'),
  (5, 3, 104, 4, 'Fast and friendly');


--Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--customer_id
--order_id
--runner_id
--rating
--order_time
--pickup_time
--Time between order and pickup
--Delivery duration
--Average speed
--Total number of pizzas

SELECT
  co."customer_id",
  co."order_id",
  ro."runner_id",
  cr."rating",
  co."order_time",
  ro."pickup_time",
  EXTRACT(EPOCH FROM (ro."pickup_time"::timestamp - co."order_time"::timestamp)) / 60 AS "time_between_order_and_pickup",
  ro."duration",
  CASE
    WHEN ro."distance" ~ E'^\\d+\\.\\d+$' THEN (ro."distance"::numeric / NULLIF(ro."duration"::numeric, 0))
    ELSE NULL
  END AS "average_speed",
  COUNT(co."pizza_id") AS "total_pizzas"
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
JOIN
  pizza_runner.customer_ratings cr ON co."order_id" = cr."order_id"
WHERE
  ro."cancellation" IS NULL
  AND ro."distance" ~ E'^\\d+\\.\\d+$' -- Check for numeric distance
GROUP BY
  co."customer_id",
  co."order_id",
  ro."runner_id",
  cr."rating",
  co."order_time",
  ro."pickup_time",
  ro."duration",
  ro."distance";



--If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled-
-- how much money does Pizza Runner have left over after these deliveries?

SELECT
  SUM(CASE
    WHEN pn."pizza_name" = 'Meatlovers' THEN 12
    WHEN pn."pizza_name" = 'Vegetarian' THEN 10
    ELSE 0
  END) AS "total_revenue",
  SUM(CASE
    WHEN ro."distance" ~ E'^\\d+\\.\\d+$' THEN (ro."distance"::numeric * 0.30)
    ELSE 0
  END) AS "total_runner_expenses",
  SUM(CASE
    WHEN pn."pizza_name" = 'Meatlovers' THEN 12
    WHEN pn."pizza_name" = 'Vegetarian' THEN 10
    ELSE 0
  END) - SUM(CASE
    WHEN ro."distance" ~ E'^\\d+\\.\\d+$' THEN (ro."distance"::numeric * 0.30)
    ELSE 0
  END) AS "profit"
FROM
  pizza_runner.customer_orders co
JOIN
  pizza_runner.pizza_names pn ON co."pizza_id" = pn."pizza_id"
LEFT JOIN
  pizza_runner.runner_orders ro ON co."order_id" = ro."order_id"
WHERE
  ro."cancellation" IS NULL;


--E. Bonus Questions

--If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to- 
  --demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

DROP TABLE IF EXISTS pizza_names;
CREATE TABLE pizza_names (
  "pizza_id" INTEGER,
  "pizza_name" TEXT
);
INSERT INTO pizza_names
  ("pizza_id", "pizza_name")
VALUES
  (1, 'Meatlovers'),
  (2, 'Vegetarian'),
  (3, 'Supreme');

DROP TABLE IF EXISTS pizza_recipes;
CREATE TABLE pizza_recipes (
  "pizza_id" INTEGER,
  "toppings" TEXT
);
INSERT INTO pizza_recipes
  ("pizza_id", "toppings")
VALUES
  (1, '1, 2, 3, 4, 5, 6, 8, 10'),
  (2, '4, 6, 7, 9, 11, 12'),
  (3, '1,2,3,4,5,6,7,8,9,10,11,12');


DROP TABLE IF EXISTS customer_orders;
CREATE TABLE customer_orders (
  "order_id" INTEGER,
  "customer_id" INTEGER,
  "pizza_id" INTEGER,
  "exclusions" VARCHAR(4),
  "extras" VARCHAR(4),
  "order_time" TIMESTAMP
);

INSERT INTO customer_orders
  ("order_id", "customer_id", "pizza_id", "exclusions", "extras", "order_time")
VALUES
  ('1', '101', '1', '', '', '2020-01-01 18:05:02'),
  ('2', '101', '1', '', '', '2020-01-01 19:00:52'),
  ('3', '102', '1', '', '', '2020-01-02 23:51:23'),
  ('3', '102', '2', '', NULL, '2020-01-02 23:51:23'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '1', '4', '', '2020-01-04 13:23:46'),
  ('4', '103', '2', '4', '', '2020-01-04 13:23:46'),
  ('5', '104', '1', 'null', '1', '2020-01-08 21:00:29'),
  ('6', '101', '2', 'null', 'null', '2020-01-08 21:03:13'),
  ('7', '105', '2', 'null', '1', '2020-01-08 21:20:29'),
  ('8', '102', '1', 'null', 'null', '2020-01-09 23:54:33'),
  ('9', '103', '1', '4', '1, 5', '2020-01-10 11:22:59'),
  ('10', '104', '1', 'null', 'null', '2020-01-11 18:34:49'),
  ('10', '102', '3', 'null' , 'null', '2020-01-12 19:45:00'),
  ('10', '104', '1', '2, 6', '1, 4', '2020-01-11 18:34:49');

--Add the "Supreme" pizza to the menu by inserting a new record in the "pizza_names" table. 
--Then, we define all the toppings for the "Supreme" pizza in the "pizza_recipes" table. Finally, we add an order for the new "Supreme" pizza to the "customer_orders" table.
--This demonstrates how the existing data design can accommodate the addition of new pizza options to the menu.


