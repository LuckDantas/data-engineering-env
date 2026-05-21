-- =============================================================================
-- LAYER: Gold
-- MODEL: fct_pedidos (Fact Table)
-- GRAIN: one row per ORDER ITEM (order_id + order_item_id)
-- =============================================================================
-- The fact table is the center of the Star Schema. It holds:
--   - Foreign keys (SKs) pointing to each dimension table
--   - Measurable facts/metrics (price, freight, review_score, etc.)
--   - No descriptive attributes — those live in the dimensions
--
-- GRAIN DECISION: We chose order_item (not order) as the grain because:
--   - One order can have multiple products from multiple sellers
--   - Item-level grain allows analysis by product and seller simultaneously
--   - Aggregating to order level is easy (GROUP BY order_id); the reverse is not
--
-- STAR SCHEMA:
--                  dim_clientes_olist
--                         |
--   dim_produtos_olist — fct_pedidos — dim_vendedores_olist
--                         |
--                      date_dim (reused from existing project)
-- =============================================================================

{{ config(materialized='table') }}

WITH order_items AS (
  SELECT * FROM {{ ref('stg_olist_order_items') }}
),

orders AS (
  SELECT * FROM {{ ref('stg_olist_orders') }}
),

-- We need customers to resolve customer_id → customer_unique_id.
-- Explanation: the orders table has customer_id, but our dimension is keyed
-- on customer_unique_id (the true person). One person can have many customer_ids
-- (one per order placed). We join through the customers table to get the right SK.
customers AS (
  SELECT customer_id, customer_unique_id FROM {{ ref('olist_customers') }}
),

customer_dim AS (
  SELECT customer_sk, customer_unique_id FROM {{ ref('dim_clientes_olist') }}
),

-- Payments are aggregated at order level here because:
--   - A single order can be split across multiple payment methods
--     (e.g. part credit card, part voucher)
--   - The fact is at item level, so we aggregate payments to order level
--     and join them in — each item in an order shares the same payment total
payments AS (
  SELECT
    order_id,
    SUM(payment_value)                         AS total_payment_value,
    MAX(payment_installments)                  AS payment_installments,
    -- STRING_AGG concatenates all payment types used in one order
    -- e.g. "credit_card | voucher"
    STRING_AGG(DISTINCT payment_type, ' | ')   AS payment_types
  FROM {{ ref('stg_olist_order_payments') }}
  GROUP BY order_id
),

-- Reviews: keep only the most recent review per order.
-- An order can technically have multiple reviews (rare edge case in the data).
-- DISTINCT ON is PostgreSQL-specific syntax that keeps one row per group,
-- ordered by the specified column — equivalent to ROW_NUMBER() OVER (...) = 1
reviews AS (
  SELECT DISTINCT ON (order_id)
    order_id,
    review_score
  FROM {{ ref('stg_olist_order_reviews') }}
  ORDER BY order_id, review_answer_timestamp DESC
)

SELECT
  -- Composite surrogate key: surrogate key for the fact row itself.
  -- Uses both order_id and order_item_id because neither alone is unique.
  {{ dbt_utils.generate_surrogate_key(['oi.order_id', 'oi.order_item_id']) }} AS order_item_sk,

  -- Foreign keys — these point to the dimension tables (the "star" arms)
  cd.customer_sk,   -- → dim_clientes_olist
  oi.product_sk,    -- → dim_produtos_olist
  oi.seller_sk,     -- → dim_vendedores_olist
  -- purchase_date is used as FK to date_dim (reusing the existing dimension)
  o.order_purchase_timestamp::DATE                                              AS purchase_date,

  -- Degenerate dimensions: attributes that describe the fact but don't
  -- warrant their own dimension table (too simple or too volatile)
  oi.order_id,
  oi.order_item_id,
  o.order_status,

  -- Measures (additive facts — can be summed across any dimension)
  oi.price,
  oi.freight_value,
  -- GMV (Gross Merchandise Value) = price + freight — the total value of the transaction
  oi.price + oi.freight_value                                                   AS gmv,
  COALESCE(p.total_payment_value, 0)                                            AS total_payment_value,
  COALESCE(p.payment_installments, 1)                                           AS payment_installments,
  p.payment_types,

  -- Semi-additive fact: review_score can be averaged but not summed meaningfully
  r.review_score,

  -- Derived metric: delivery time in days
  -- EXTRACT(EPOCH FROM interval) gives seconds → divide by 86400 for days
  -- NULL when order was not delivered (cancelled, in transit, etc.)
  EXTRACT(
    EPOCH FROM (o.order_delivered_customer_date - o.order_purchase_timestamp)
  ) / 86400                                                                     AS days_to_deliver,

  CURRENT_TIMESTAMP                                                             AS load_timestamp

FROM order_items oi
-- INNER JOIN orders: every item must have an order (referential integrity)
JOIN orders         o   ON oi.order_id = o.order_id
-- JOIN chain to resolve customer_id → customer_unique_id → customer_sk
JOIN customers      c   ON o.customer_id = c.customer_id
JOIN customer_dim   cd  ON c.customer_unique_id = cd.customer_unique_id
-- LEFT JOINs: not every order has payments or reviews recorded — keep all items
LEFT JOIN payments  p   ON oi.order_id = p.order_id
LEFT JOIN reviews   r   ON oi.order_id = r.order_id
