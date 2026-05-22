-- =============================================================================
-- LAYER: Data Marts
-- MODEL: agg_weather_by_city
-- =============================================================================
-- All-time weather ranking by city — useful for comparing cities at a glance.
-- =============================================================================

{{ config(materialized='view') }}

WITH fct AS (
  SELECT * FROM {{ ref('fct_weather_daily') }}
)

SELECT
  city,
  lat,
  lon,

  ROUND(AVG(temperature_2m_max)::NUMERIC, 1)  AS avg_max_temp,
  ROUND(MAX(temperature_2m_max)::NUMERIC, 1)  AS all_time_high,
  ROUND(MIN(temperature_2m_min)::NUMERIC, 1)  AS all_time_low,

  ROUND(SUM(precipitation_sum)::NUMERIC, 1)   AS total_rain_mm,
  COUNT(*) FILTER (WHERE is_rainy_day)         AS total_rainy_days,
  ROUND(
    COUNT(*) FILTER (WHERE is_rainy_day)::NUMERIC / NULLIF(COUNT(*), 0) * 100,
    1
  )                                            AS pct_rainy_days,

  ROUND(AVG(wind_speed_10m_max)::NUMERIC, 1)  AS avg_wind_speed,
  ROUND(AVG(daylight_hours)::NUMERIC, 2)      AS avg_daylight_hours,

  COUNT(*)                                     AS days_recorded,
  MIN(date)                                    AS first_date,
  MAX(date)                                    AS last_date

FROM fct
GROUP BY 1, 2, 3
ORDER BY avg_max_temp DESC
