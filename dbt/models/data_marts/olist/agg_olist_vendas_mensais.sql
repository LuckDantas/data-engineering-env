-- =============================================================================
-- LAYER: Data Marts
-- MODEL: agg_olist_vendas_mensais (Monthly Sales Trend)
-- MATERIALIZATION: view
-- =============================================================================
-- Data Mart models are pre-aggregated views designed for direct consumption
-- by BI tools (Power BI, Tableau, etc.) or analysts running ad-hoc queries.
--
-- MATERIALIZATION: view (not table) because:
--   - The Gold fact table is already a table — querying a view on top of it
--     is fast enough for reporting purposes
--   - Views always reflect the latest data without needing to be rebuilt
--   - Storage cost is zero (a view stores no data, only the SQL definition)
--
-- This model provides the time series of key business metrics by month,
-- useful for trend analysis, seasonality detection, and executive dashboards.
-- =============================================================================

{{ config(materialized='view') }}

WITH fct AS (
  -- Always reference Gold models, never Silver or Bronze directly.
  -- Data Marts sit on top of Gold — this keeps the dependency chain clean.
  SELECT * FROM {{ ref('fct_pedidos') }}
)

SELECT
  -- DATE_TRUNC truncates a date to the start of the specified period.
  -- 'month' → 2018-03-15 becomes 2018-03-01, grouping all March orders together.
  -- ::DATE cast removes the time component for cleaner display in Power BI.
  DATE_TRUNC('month', purchase_date)::DATE AS mes,

  -- COUNT DISTINCT order_id: counts orders (not items).
  -- If we used COUNT(*) we'd count items, inflating the number.
  COUNT(DISTINCT order_id)                 AS total_pedidos,
  COUNT(order_item_sk)                     AS total_itens,

  -- SUM of GMV: total revenue including freight across all items in the month
  ROUND(SUM(gmv)::NUMERIC, 2)              AS receita_total,

  -- AVG ticket at item level — divide by total_pedidos for order-level ticket
  ROUND(AVG(gmv)::NUMERIC, 2)              AS ticket_medio,

  -- NPS proxy: average review score (1-5 scale)
  ROUND(AVG(review_score)::NUMERIC, 2)     AS nps_medio,

  -- Operational metric: average delivery time helps track logistics performance
  ROUND(AVG(days_to_deliver)::NUMERIC, 1)  AS prazo_entrega_medio_dias

FROM fct
WHERE purchase_date IS NOT NULL
GROUP BY 1
ORDER BY 1
