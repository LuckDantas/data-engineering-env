-- =============================================================================
-- LAYER: Bronze
-- MODEL: olist_category_translation
-- SOURCE TABLE: data_lake.olist.category_translation
-- GRAIN: one row per product category
-- =============================================================================
-- The products table stores category names in Portuguese (e.g. "cama_mesa_banho").
-- This lookup table maps each Portuguese category name to its English equivalent.
-- It is joined in the Silver layer (stg_olist_products) to translate categories,
-- making the Gold layer consumable by international stakeholders and Power BI.
-- =============================================================================

{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    -- dblink_host    → "postgres-dbt" (the PostgreSQL container name)
    -- dblink_dbname  → "data_lake"    (where Airflow loaded the CSVs)
    -- dblink_user    → "dbt"
    -- dblink_password → "dbt"
    -- These values come from environment variables set in docker-compose.yml,
    -- read by dbt_project.yml via env_var(), and passed here as dbt vars.
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',

    'SELECT product_category_name, product_category_name_english
     FROM olist.category_translation'

  ) AS remote_data(
    product_category_name         VARCHAR,
    product_category_name_english VARCHAR
  )
)

SELECT * FROM source
