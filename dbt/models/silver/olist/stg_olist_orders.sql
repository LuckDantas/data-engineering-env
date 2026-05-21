-- =============================================================================
-- LAYER: Silver
-- MODEL: stg_olist_orders
-- MATERIALIZATION: table
-- =============================================================================
-- Silver is the cleaning and typing layer. Responsibilities:
--   1. Cast VARCHAR fields to their correct types (TIMESTAMP, INTEGER, etc.)
--   2. Handle nulls and empty strings consistently
--   3. Generate a surrogate key for use as a primary key in Gold
--   4. Remove invalid rows (WHERE order_id IS NOT NULL)
--
-- Silver does NOT apply business logic or join tables — that happens in Gold.
-- =============================================================================

-- Materialized as TABLE (not view) because:
--   - Type casting and cleaning is CPU-intensive — we don't want it repeated
--     every time a Gold model queries this
--   - Silver is a stable, reusable layer referenced by multiple Gold models
{{ config(materialized='table') }}

WITH bronze AS (
  -- ref() is dbt's way of referencing another model.
  -- It automatically resolves to the correct schema (bronze.olist_orders)
  -- and creates a dependency in the DAG so Bronze always runs before Silver.
  SELECT * FROM {{ ref('olist_orders') }}
),

cleaned AS (
  SELECT
    order_id,
    customer_id,

    -- NULLIF(TRIM(...), '') is the standard pattern for cleaning string fields:
    --   TRIM removes leading/trailing whitespace
    --   NULLIF converts empty strings '' to NULL
    -- This ensures downstream models can use IS NULL checks consistently
    NULLIF(TRIM(order_status), '')                          AS order_status,

    -- Direct cast: order_purchase_timestamp is always present in this dataset
    order_purchase_timestamp::TIMESTAMP                     AS order_purchase_timestamp,

    -- Optional timestamps: must handle empty strings before casting.
    -- Casting '' to TIMESTAMP would throw an error, so NULLIF converts it to
    -- NULL first, which PostgreSQL safely casts to NULL::TIMESTAMP.
    NULLIF(order_approved_at, '')::TIMESTAMP                AS order_approved_at,
    NULLIF(order_delivered_carrier_date, '')::TIMESTAMP     AS order_delivered_carrier_date,
    NULLIF(order_delivered_customer_date, '')::TIMESTAMP    AS order_delivered_customer_date,
    NULLIF(order_estimated_delivery_date, '')::TIMESTAMP    AS order_estimated_delivery_date

  FROM bronze
  -- Filter out rows without a primary key — these would cause issues in joins
  WHERE order_id IS NOT NULL
)

SELECT
  -- Surrogate key: a hashed, system-generated ID that is stable and unique.
  -- dbt_utils.generate_surrogate_key() produces an MD5 hash of the input columns.
  -- We use order_id (the natural key from the source) as input.
  --
  -- Why not use order_id directly as the PK in Gold?
  --   - Natural keys from source systems can change or be reused
  --   - Surrogate keys are consistent across systems and environments
  --   - Follows dimensional modeling best practices (Kimball methodology)
  {{ dbt_utils.generate_surrogate_key(['order_id']) }} AS order_sk,
  *,
  CURRENT_TIMESTAMP AS load_timestamp
FROM cleaned
