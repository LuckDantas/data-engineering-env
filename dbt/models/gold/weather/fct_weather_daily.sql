-- =============================================================================
-- LAYER: Gold
-- MODEL: fct_weather_daily
-- GRAIN: one row per (city, date)
-- =============================================================================
-- Fact table for daily weather observations.
-- Adds derived metrics useful for BI and analysis:
--   - daylight_hours: total hours of sunlight
--   - is_rainy_day: boolean flag for days with precipitation > 1 mm
--   - heat_category: temperature bucket for easy BI filtering
--
-- INCREMENTAL strategy:
--   On the first run, the full history is loaded.
--   On every subsequent daily run, only rows with date > MAX(date already in table)
-- =============================================================================

{{ config(
    materialized='incremental',
    unique_key=['city', 'date']
) }}

WITH silver AS (
  SELECT * FROM {{ ref('stg_weather_daily') }}

  {% if is_incremental() %}
  WHERE date > (SELECT MAX(date) FROM {{ this }})
  {% endif %}
)

SELECT
  weather_sk,
  city,
  lat,
  lon,
  date,

  -- Temperature metrics
  temperature_2m_max,
  temperature_2m_min,
  temperature_range,

  -- Precipitation
  precipitation_sum,
  CASE WHEN precipitation_sum > 1 THEN TRUE ELSE FALSE END  AS is_rainy_day,

  -- Wind
  wind_speed_10m_max,

  -- Daylight hours derived from sunrise/sunset
  ROUND(
    EXTRACT(EPOCH FROM (sunset - sunrise)) / 3600.0,
    2
  )                                                         AS daylight_hours,

  sunrise,
  sunset,

  -- Temperature category for easy filtering in BI tools
  CASE
    WHEN temperature_2m_max >= 35 THEN 'Extreme Heat'
    WHEN temperature_2m_max >= 28 THEN 'Hot'
    WHEN temperature_2m_max >= 20 THEN 'Warm'
    WHEN temperature_2m_max >= 12 THEN 'Mild'
    ELSE 'Cold'
  END                                                       AS heat_category,

  load_timestamp

FROM silver
