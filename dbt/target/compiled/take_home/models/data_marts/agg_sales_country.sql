

WITH transaction_fct AS (
  SELECT *
  FROM "dev"."dbt_gold"."transaction_fct"
),

location_dim AS (
  SELECT *
  FROM "dev"."dbt_gold"."location_dim"
)

SELECT
  b.country,
  ROUND(SUM(a.quantity * a.price)::NUMERIC, 2) AS monthly_revenue
FROM transaction_fct AS a
JOIN location_dim AS b
ON a.customer_location_id = b.id
GROUP BY 1