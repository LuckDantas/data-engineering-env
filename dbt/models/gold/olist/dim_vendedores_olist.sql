{{ config(materialized='table') }}

SELECT
  seller_sk,
  seller_id,
  seller_city,
  seller_state,
  seller_zip_code_prefix,
  load_timestamp
FROM {{ ref('stg_olist_sellers') }}
