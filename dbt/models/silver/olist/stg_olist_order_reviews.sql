{{ config(materialized='table') }}

WITH bronze AS (
  SELECT * FROM {{ ref('olist_order_reviews') }}
)

SELECT
  review_id,
  order_id,
  review_score::INTEGER                                AS review_score,
  NULLIF(TRIM(review_comment_title), '')               AS review_comment_title,
  NULLIF(TRIM(review_comment_message), '')             AS review_comment_message,
  NULLIF(review_creation_date, '')::TIMESTAMP          AS review_creation_date,
  NULLIF(review_answer_timestamp, '')::TIMESTAMP       AS review_answer_timestamp,
  CURRENT_TIMESTAMP                                    AS load_timestamp
FROM bronze
WHERE order_id IS NOT NULL
  AND review_score IS NOT NULL
