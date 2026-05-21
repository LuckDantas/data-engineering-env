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
    -- dblink is a PostgreSQL extension that allows querying a DIFFERENT database
    -- from within a SQL statement. This is necessary because:
    --   - dbt runs its models inside the "dev" or "pro" database
    --   - But raw data was loaded by Airflow into the "data_lake" database
    --   - PostgreSQL does not support cross-database queries natively
    --
    -- The connection string is built from dbt variables (defined in dbt_project.yml)
    -- which read from environment variables injected by docker-compose:
    --   dblink_host     = DBLINK_HOST     = "postgres-dbt" (container name)
    --   dblink_dbname   = DBLINK_DBNAME   = "data_lake"
    --   dblink_user     = DBLINK_USER     = "dbt"
    --   dblink_password = DBLINK_PASSWORD = "dbt"
    --
    -- Using variables instead of hardcoded values allows the same model to run
    -- in different environments (dev/pro) without code changes.
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',

    -- The second argument is the SQL query executed on the REMOTE database.
    -- Columns must be explicitly listed (no SELECT *) because dblink requires
    -- knowing the return schema upfront to cast results correctly.
    'SELECT order_id, customer_id, order_status, order_purchase_timestamp,
            order_approved_at, order_delivered_carrier_date,
            order_delivered_customer_date, order_estimated_delivery_date
     FROM olist.orders'

  -- dblink returns an anonymous record type, so we must declare each column
  -- name and type explicitly in the AS clause.
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
