/* --------------------
   https://8weeksqlchallenge.com/case-study-1/
   
   Case Study Questions;
   --------------------*/

-- 1. What is the total amount each customer spent at the restaurant?
-- 2. How many days has each customer visited the restaurant?
-- 3. What was the first item from the menu purchased by each customer?
-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- 5. Which item was the most popular for each customer?
-- 6. Which item was purchased first by the customer after they became a member?
-- 7. Which item was purchased just before the customer became a member?
-- 8. What is the total items and amount spent for each member before they became a member?
-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?

-- Solutions--
-- 1. What is the total amount each customer spent at the restaurant?
--To calculate the amount each customer spent,  on the product_id, join the sales table and the menu table and sum up the prices for each customer.m denotes menu and s denotes sales.

SELECT
  s.customer_id,
  SUM(m.price) AS amount_spent
FROM
  dannys_diner.sales s
JOIN
  dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY
  s.customer_id
ORDER BY
  s.customer_id;

-- 2. How many days has each customer visited the restaurant?
-- count the distinct order dates.
SELECT
  customer_id,
  COUNT(DISTINCT order_date) AS days_visited
FROM
  dannys_diner.sales
GROUP BY
  customer_id
ORDER BY
  customer_id;

-- 3. What was the first item from the menu purchased by each customer?
-- To get first Item purcahsed,  use a subquery with the MIN() function to determine the earliest order-date for each customer_id on the sales table.Then join the results with the sales and menu table.

SELECT
  s.customer_id,
  m.product_name AS first_item_purchased
FROM
  dannys_diner.sales s
JOIN
  dannys_diner.menu m ON s.product_id = m.product_id
JOIN (
  SELECT
    customer_id,
    MIN(order_date) AS first_order_date
  FROM
    dannys_diner.sales
  GROUP BY
    customer_id
) AS first_orders
ON s.customer_id = first_orders.customer_id AND s.order_date = first_orders.first_order_date
ORDER BY
  s.customer_id;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
-- Using the GROUP BY and COUNT functions;

SELECT
  m.product_name AS most_purchased_item,
  COUNT(s.product_id) AS total_purchases
FROM
  dannys_diner.sales s
JOIN
  dannys_diner.menu m ON s.product_id = m.product_id
GROUP BY
  m.product_name
ORDER BY
  total_purchases DESC
limit 1;


-- 5. Which item was the most popular for each customer?

SELECT
  customer_id,
  product_name AS most_popular_item
FROM (
  SELECT
    s.customer_id,
    m.product_name,
    RANK() OVER (PARTITION BY s.customer_id ORDER BY COUNT(s.product_id) DESC) AS item_rank
  FROM
    dannys_diner.sales s
  JOIN
    dannys_diner.menu m ON s.product_id = m.product_id
  GROUP BY
    s.customer_id,
    m.product_name
) AS ranked_items
WHERE item_rank = 1;

-- 6. Which item was purchased first by the customer after they became a member?
-- Join the 'sales' and 'members' tables based on the 'customer_id'. Then, we can use the MIN() function to find the earliest 'order_date' for each customer after their 'join_date'. 
--Finally, we join the result with the 'menu' table to get the corresponding 'product_name' for the first purchase.

SELECT
  first_purchases.customer_id,
  m.product_name AS member_first_item_purchased
FROM (
  SELECT
    s.customer_id,
    s.product_id,
    MIN(s.order_date) AS member_first_item_purchased
  FROM
    dannys_diner.sales s
  GROUP BY
    s.customer_id,
    s.product_id
) AS first_purchases
JOIN
  dannys_diner.sales s ON first_purchases.customer_id = s.customer_id AND first_purchases.member_first_item_purchased = s.order_date
JOIN
  dannys_diner.menu m ON s.product_id = m.product_id
JOIN
  dannys_diner.members mem ON first_purchases.customer_id = mem.customer_id AND first_purchases.member_first_item_purchased>= mem.join_date
ORDER BY
 first_purchases.customer_id;

-- 7. Which item was purchased just before the customer became a member?
--  join the sales and members tables based on the customer_id and filter the sales records that occurred before the member's join_date.
SELECT
  mem.customer_id,
  m.product_name AS item_purchased_before_membership
FROM (
  SELECT
    s.customer_id,
    MAX(s.order_date) AS last_order_date_before_membership
  FROM
    dannys_diner.sales s
  JOIN
    dannys_diner.members m ON s.customer_id = m.customer_id
  WHERE s.order_date < m.join_date
  GROUP BY
    s.customer_id
) AS last_purchases
JOIN
  dannys_diner.sales s ON last_purchases.customer_id = s.customer_id AND last_purchases.last_order_date_before_membership = s.order_date
JOIN
  dannys_diner.menu m ON s.product_id = m.product_id
JOIN
  dannys_diner.members mem ON last_purchases.customer_id = mem.customer_id
ORDER BY
  mem.customer_id;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
  m.customer_id,
  COUNT(s.product_id) AS total_items_purchased,
  SUM(menu.price) AS total_amount_spent
FROM
  dannys_diner.sales s
JOIN
  dannys_diner.members m ON s.customer_id = m.customer_id
JOIN
  dannys_diner.menu ON s.product_id = menu.product_id
WHERE
  s.order_date < m.join_date
GROUP BY
  m.customer_id
ORDER BY
  m.customer_id;

-- 9.  If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT
  s.customer_id,
  SUM(
    CASE
      WHEN m.product_name = 'sushi' THEN 20  -- Points for sushi (2x multiplier)
      ELSE 10  -- Points for other items
    END
  ) AS total_points
FROM
  dannys_diner.sales s
JOIN
  dannys_diner.menu m ON s.product_id = m.product_id
JOIN
  dannys_diner.members mem ON s.customer_id = mem.customer_id
WHERE
  s.order_date < mem.join_date
GROUP BY
  s.customer_id
ORDER BY
  s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT
  s.customer_id,
  SUM(
    CASE
      WHEN s.order_date >= m.join_date AND s.order_date < (m.join_date + INTERVAL '1 week') THEN menu.price * 20  -- Points for the first week (2x multiplier)
      ELSE menu.price * 10  -- Points for subsequent weeks (1x multiplier)
    END
  ) AS total_points
FROM
  dannys_diner.sales s
JOIN
  dannys_diner.menu ON s.product_id = menu.product_id
JOIN
  dannys_diner.members m ON s.customer_id = m.customer_id
WHERE
  (s.customer_id = 'A' OR s.customer_id = 'B') AND s.order_date <= '2021-01-31'
GROUP BY
  s.customer_id;
