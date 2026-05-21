{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',
    'SELECT seller_id, seller_zip_code_prefix, seller_city, seller_state
     FROM olist.sellers'
  ) AS remote_data(
    seller_id              VARCHAR,
    seller_zip_code_prefix VARCHAR,
    seller_city            VARCHAR,
    seller_state           VARCHAR
  )
)

SELECT * FROM source
