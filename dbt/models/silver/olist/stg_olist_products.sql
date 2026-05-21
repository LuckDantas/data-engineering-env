-- =============================================================================
-- LAYER: Silver
-- MODEL: stg_olist_products
-- MATERIALIZATION: table
-- =============================================================================
-- This is the only Silver model that joins two Bronze sources:
--   - olist_products: product attributes (weight, dimensions, category in PT)
--   - olist_category_translation: maps PT category names to English
--
-- Joining in Silver (rather than Gold) is acceptable here because the
-- translation is a simple lookup with no business logic — it just enriches
-- the product record to make it usable by the Gold dimension.
-- =============================================================================

{{ config(materialized='table') }}

WITH bronze AS (
  SELECT * FROM {{ ref('olist_products') }}
),

-- Lookup table: Portuguese category name → English category name
translation AS (
  SELECT * FROM {{ ref('olist_category_translation') }}
)

SELECT
  -- product_sk is the surrogate key for this product, used as FK in fct_pedidos
  {{ dbt_utils.generate_surrogate_key(['p.product_id']) }}           AS product_sk,
  p.product_id,

  NULLIF(TRIM(p.product_category_name), '')                          AS category_name_pt,

  -- COALESCE: if no English translation exists for a category, fall back to
  -- the Portuguese name rather than showing NULL in reports
  COALESCE(t.product_category_name_english, p.product_category_name) AS category_name_en,

  -- Cast numeric fields — note the typo "lenght" in the original Olist dataset
  -- (product_name_lenght, product_description_lenght). We keep the original
  -- column names in Bronze but could rename them here in Silver.
  NULLIF(p.product_photos_qty, '')::INTEGER                          AS photos_qty,
  NULLIF(p.product_weight_g, '')::NUMERIC                            AS weight_g,
  NULLIF(p.product_length_cm, '')::NUMERIC                           AS length_cm,
  NULLIF(p.product_height_cm, '')::NUMERIC                           AS height_cm,
  NULLIF(p.product_width_cm, '')::NUMERIC                            AS width_cm,

  CURRENT_TIMESTAMP                                                   AS load_timestamp

FROM bronze p
-- LEFT JOIN: keep all products even if their category has no English translation
LEFT JOIN translation t ON p.product_category_name = t.product_category_name
WHERE p.product_id IS NOT NULL
