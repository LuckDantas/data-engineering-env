{{ config(materialized='view') }}

WITH fct AS (SELECT * FROM {{ ref('fct_pedidos') }}),
     dim_prod AS (SELECT * FROM {{ ref('dim_produtos_olist') }})

SELECT
  dim_prod.category_name_en                AS categoria,
  COUNT(DISTINCT fct.order_id)             AS total_pedidos,
  COUNT(fct.order_item_sk)                 AS total_itens,
  ROUND(SUM(fct.gmv)::NUMERIC, 2)          AS receita_total,
  ROUND(AVG(fct.price)::NUMERIC, 2)        AS preco_medio,
  ROUND(AVG(fct.review_score)::NUMERIC, 2) AS nps_medio
FROM fct
JOIN dim_prod ON fct.product_sk = dim_prod.product_sk
GROUP BY 1
ORDER BY receita_total DESC
