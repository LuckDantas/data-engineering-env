

WITH transaction_fct AS (
  SELECT *
  FROM "dev"."dbt_gold"."transaction_fct"
),

customer_dim AS (
  SELECT *
  FROM "dev"."dbt_gold"."customer_dim"
)

SELECT
  b.id AS customer_id,
  ROUND(SUM(a.quantity * a.price)::NUMERIC, 2) AS revenue
FROM transaction_fct AS a
JOIN customer_dim AS b
ON a.customer_id = b.id
GROUP BY 1