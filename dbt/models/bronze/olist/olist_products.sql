{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',
    'SELECT product_id, product_category_name, product_name_lenght,
            product_description_lenght, product_photos_qty,
            product_weight_g, product_length_cm, product_height_cm, product_width_cm
     FROM olist.products'
  ) AS remote_data(
    product_id                 VARCHAR,
    product_category_name      VARCHAR,
    product_name_lenght        VARCHAR,
    product_description_lenght VARCHAR,
    product_photos_qty         VARCHAR,
    product_weight_g           VARCHAR,
    product_length_cm          VARCHAR,
    product_height_cm          VARCHAR,
    product_width_cm           VARCHAR
  )
)

SELECT * FROM source
