{{ config(materialized='table') }}

WITH bronze AS (
  SELECT * FROM {{ ref('olist_order_payments') }}
)

SELECT
  order_id,
  payment_sequential::INTEGER    AS payment_sequential,
  NULLIF(TRIM(payment_type), '') AS payment_type,
  payment_installments::INTEGER  AS payment_installments,
  payment_value::NUMERIC(10, 2)  AS payment_value,
  CURRENT_TIMESTAMP              AS load_timestamp
FROM bronze
WHERE order_id IS NOT NULL
