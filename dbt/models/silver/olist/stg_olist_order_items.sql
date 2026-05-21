{{ config(materialized='table') }}

WITH bronze AS (
  SELECT * FROM {{ ref('olist_order_items') }}
)

SELECT
  order_id,
  order_item_id::INTEGER                                   AS order_item_id,
  product_id,
  seller_id,
  {{ dbt_utils.generate_surrogate_key(['product_id']) }}   AS product_sk,
  {{ dbt_utils.generate_surrogate_key(['seller_id']) }}    AS seller_sk,
  NULLIF(shipping_limit_date, '')::TIMESTAMP               AS shipping_limit_date,
  price::NUMERIC(10, 2)                                    AS price,
  freight_value::NUMERIC(10, 2)                            AS freight_value,
  CURRENT_TIMESTAMP                                        AS load_timestamp
FROM bronze
WHERE order_id IS NOT NULL
  AND product_id IS NOT NULL
