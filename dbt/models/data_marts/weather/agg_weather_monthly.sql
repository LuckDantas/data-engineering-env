-- =============================================================================
-- LAYER: Data Marts
-- MODEL: agg_weather_monthly
-- =============================================================================
-- Monthly weather summary per city — designed for trend dashboards in Power BI.
-- =============================================================================

{{ config(materialized='view') }}

WITH fct AS (
  SELECT * FROM {{ ref('fct_weather_daily') }}
)

SELECT
  DATE_TRUNC('month', date)::DATE             AS month,
  city,

  ROUND(AVG(temperature_2m_max)::NUMERIC, 1)  AS avg_max_temp,
  ROUND(MAX(temperature_2m_max)::NUMERIC, 1)  AS record_high,
  ROUND(MIN(temperature_2m_min)::NUMERIC, 1)  AS record_low,
  ROUND(AVG(temperature_range)::NUMERIC, 1)   AS avg_daily_range,

  ROUND(SUM(precipitation_sum)::NUMERIC, 1)   AS total_rain_mm,
  COUNT(*) FILTER (WHERE is_rainy_day)         AS rainy_days,

  ROUND(AVG(wind_speed_10m_max)::NUMERIC, 1)  AS avg_wind_speed,
  ROUND(AVG(daylight_hours)::NUMERIC, 2)      AS avg_daylight_hours,

  COUNT(*)                                     AS days_recorded

FROM fct
GROUP BY 1, 2
ORDER BY 1, 2
