-- =============================================================================
-- LAYER: Bronze
-- MODEL: olist_order_items
-- SOURCE TABLE: data_lake.olist.order_items
-- GRAIN: one row per item within an order (order_id + order_item_id)
-- =============================================================================
-- An order can have multiple items (e.g. order A has 3 products = 3 rows).
-- This is the most granular table in the dataset and will become the grain
-- of our fact table (fct_pedidos) in the Gold layer.
-- =============================================================================

{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    -- Same dblink connection pattern used across all Bronze models.
    -- See olist_orders.sql for full explanation of why dblink is needed.
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',

    'SELECT order_id, order_item_id, product_id, seller_id,
            shipping_limit_date, price, freight_value
     FROM olist.order_items'

  -- price and freight_value are numeric in the source but loaded as VARCHAR
  -- by the Airflow task (dtype=str). They will be cast to NUMERIC in Silver.
  ) AS remote_data(
    order_id            VARCHAR,
    order_item_id       VARCHAR,
    product_id          VARCHAR,
    seller_id           VARCHAR,
    shipping_limit_date VARCHAR,
    price               VARCHAR,
    freight_value       VARCHAR
  )
)

SELECT * FROM source
