-- =============================================================================
-- LAYER: Gold
-- MODEL: dim_produtos_olist (Product Dimension)
-- GRAIN: one row per product (product_id)
-- =============================================================================
-- This dimension answers: WHAT was bought?
-- It includes physical attributes (weight, dimensions) and the category
-- in both Portuguese and English (translated in Silver).
--
-- The computed field "volume_litros" is an example of a derived attribute —
-- calculated once here so every downstream query gets it for free.
-- =============================================================================

{{ config(materialized='table') }}

SELECT
  product_sk,         -- surrogate key — used as FK in fct_pedidos
  product_id,         -- natural key from source
  category_name_pt,   -- original Portuguese category name
  category_name_en,   -- English translation (joined in Silver)
  photos_qty,
  weight_g,
  length_cm,
  height_cm,
  width_cm,
  -- Derived attribute: volume in liters (length × height × width in cm³ ÷ 1000)
  -- Computed here once rather than in every query that needs it
  ROUND((length_cm * height_cm * width_cm) / 1000, 2) AS volume_litros,
  load_timestamp
FROM {{ ref('stg_olist_products') }}
