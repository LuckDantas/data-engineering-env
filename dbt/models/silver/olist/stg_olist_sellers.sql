{{ config(materialized='table') }}

WITH bronze AS (
  SELECT * FROM {{ ref('olist_sellers') }}
)

SELECT
  {{ dbt_utils.generate_surrogate_key(['seller_id']) }} AS seller_sk,
  seller_id,
  NULLIF(TRIM(seller_zip_code_prefix), '')              AS seller_zip_code_prefix,
  INITCAP(NULLIF(TRIM(seller_city), ''))                AS seller_city,
  UPPER(NULLIF(TRIM(seller_state), ''))                 AS seller_state,
  CURRENT_TIMESTAMP                                     AS load_timestamp
FROM bronze
WHERE seller_id IS NOT NULL
