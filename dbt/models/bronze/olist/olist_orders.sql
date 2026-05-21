-- =============================================================================
-- LAYER: Bronze
-- MODEL: olist_orders
-- MATERIALIZATION: view
-- =============================================================================
-- Bronze is the raw landing layer — data is stored exactly as it arrived from
-- the source, with no transformations, type casting, or business logic.
-- Using a VIEW (not a table) avoids duplicating data that already exists in
-- data_lake. The view is just a "window" into the source.
-- =============================================================================

{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',

    'SELECT order_id, customer_id, order_status, order_purchase_timestamp,
            order_approved_at, order_delivered_carrier_date,
            order_delivered_customer_date, order_estimated_delivery_date
     FROM olist.orders'

  -- Everything is VARCHAR here because Bronze accepts data exactly as loaded —
  -- no type assumptions. Type casting happens in the Silver layer.
  ) AS remote_data(
    order_id                      VARCHAR,
    customer_id                   VARCHAR,
    order_status                  VARCHAR,
    order_purchase_timestamp      VARCHAR,
    order_approved_at             VARCHAR,
    order_delivered_carrier_date  VARCHAR,
    order_delivered_customer_date VARCHAR,
    order_estimated_delivery_date VARCHAR
  )
)

SELECT * FROM source
