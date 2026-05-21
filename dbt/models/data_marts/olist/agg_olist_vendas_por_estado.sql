{{ config(materialized='view') }}

WITH fct AS (SELECT * FROM {{ ref('fct_pedidos') }}),
     dim_cli AS (SELECT * FROM {{ ref('dim_clientes_olist') }})

SELECT
  dim_cli.customer_state                   AS estado,
  COUNT(DISTINCT fct.order_id)             AS total_pedidos,
  COUNT(fct.order_item_sk)                 AS total_itens,
  ROUND(SUM(fct.gmv)::NUMERIC, 2)          AS receita_total,
  ROUND(AVG(fct.gmv)::NUMERIC, 2)          AS ticket_medio_item,
  ROUND(AVG(fct.review_score)::NUMERIC, 2) AS nps_medio
FROM fct
JOIN dim_cli ON fct.customer_sk = dim_cli.customer_sk
GROUP BY 1
ORDER BY receita_total DESC
