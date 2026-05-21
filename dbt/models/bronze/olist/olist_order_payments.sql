{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',
    'SELECT order_id, payment_sequential, payment_type,
            payment_installments, payment_value
     FROM olist.order_payments'
  ) AS remote_data(
    order_id             VARCHAR,
    payment_sequential   VARCHAR,
    payment_type         VARCHAR,
    payment_installments VARCHAR,
    payment_value        VARCHAR
  )
)

SELECT * FROM source
