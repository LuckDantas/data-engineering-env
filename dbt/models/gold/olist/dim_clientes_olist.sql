-- =============================================================================
-- LAYER: Gold
-- MODEL: dim_clientes_olist (Customer Dimension)
-- GRAIN: one row per unique customer (customer_unique_id)
-- =============================================================================
-- Dimension tables describe the "who, what, where, when" of the fact.
-- This dimension answers: WHO bought? WHERE are they from?
--
-- KEY DESIGN DECISION — customer_unique_id vs customer_id:
--   The source has customer_id (changes per order) and customer_unique_id
--   (stable identifier for the actual person). We build the dimension on
--   customer_unique_id so one customer appears once regardless of how many
--   orders they placed. This is the correct dimensional modeling approach.
--
-- The Silver model (stg_olist_customers) already handled the deduplication
-- using DISTINCT ON (customer_unique_id), so this model is intentionally simple.
-- =============================================================================

{{ config(materialized='table') }}

SELECT
  customer_sk,           -- surrogate key — used as FK in fct_pedidos
  customer_unique_id,    -- natural key from source (the real person identifier)
  customer_city,
  customer_state,
  customer_zip_code_prefix,
  load_timestamp
FROM {{ ref('stg_olist_customers') }}
