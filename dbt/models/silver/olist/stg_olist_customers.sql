{{ config(materialized='table') }}

WITH bronze AS (
  SELECT * FROM {{ ref('olist_customers') }}
),

deduped AS (
  SELECT DISTINCT ON (customer_unique_id)
    customer_unique_id,
    customer_zip_code_prefix,
    INITCAP(NULLIF(TRIM(customer_city), ''))  AS customer_city,
    UPPER(NULLIF(TRIM(customer_state), ''))   AS customer_state
  FROM bronze
  WHERE customer_unique_id IS NOT NULL
  ORDER BY customer_unique_id
)

SELECT
  {{ dbt_utils.generate_surrogate_key(['customer_unique_id']) }} AS customer_sk,
  *,
  CURRENT_TIMESTAMP AS load_timestamp
FROM deduped
