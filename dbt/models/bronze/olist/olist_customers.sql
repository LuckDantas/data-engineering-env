-- =============================================================================
-- LAYER: Bronze
-- MODEL: olist_customers
-- SOURCE TABLE: data_lake.olist.customers
-- GRAIN: one row per customer_id (NOT per unique customer)
-- =============================================================================
-- IMPORTANT: customer_id and customer_unique_id are different concepts here.
--   - customer_id: a new ID is generated for each ORDER placed. One customer
--     placing 3 orders gets 3 different customer_ids.
--   - customer_unique_id: the true identifier of the person/entity.
--
-- This is a common pattern in operational systems where the order system
-- generates a new customer record per transaction to avoid conflicts.
-- The Silver layer deduplicates on customer_unique_id to get one row per
-- real customer for the dimension table.
-- =============================================================================

{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',

    'SELECT customer_id, customer_unique_id, customer_zip_code_prefix,
            customer_city, customer_state
     FROM olist.customers'

  ) AS remote_data(
    customer_id              VARCHAR,
    customer_unique_id       VARCHAR,
    customer_zip_code_prefix VARCHAR,
    customer_city            VARCHAR,
    customer_state           VARCHAR
  )
)

SELECT * FROM source
