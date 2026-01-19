

WITH silver AS (
  SELECT
    transaction_id,
    customer_id,
    product_id,
    customer_location_id,
    transaction_date,
    quantity,
    price,
    tax,
    CURRENT_TIMESTAMP AS load_timestamp
  FROM "dev"."dbt_silver"."transaction"
  
  
)

SELECT *
FROM silver