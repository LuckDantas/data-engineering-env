{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',
    'SELECT review_id, order_id, review_score, review_comment_title,
            review_comment_message, review_creation_date, review_answer_timestamp
     FROM olist.order_reviews'
  ) AS remote_data(
    review_id               VARCHAR,
    order_id                VARCHAR,
    review_score            VARCHAR,
    review_comment_title    VARCHAR,
    review_comment_message  VARCHAR,
    review_creation_date    VARCHAR,
    review_answer_timestamp VARCHAR
  )
)

SELECT * FROM source
