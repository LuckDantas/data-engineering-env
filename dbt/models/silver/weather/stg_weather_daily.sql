-- =============================================================================
-- LAYER: Silver
-- MODEL: stg_weather_daily
-- MATERIALIZATION: incremental (unique_key: city + date)
-- =============================================================================
-- Staging model for daily weather data.
-- INCREMENTAL strategy:
--   On the first run, the full history is loaded.
--   On every subsequent daily run, only rows with date > MAX(date already in table)
--   unique_key ensures that if the same date is re-processed (e.g. API correction),
--   the existing row is updated rather than duplicated.
-- =============================================================================

{{ config(
    materialized='incremental',
    unique_key=['city', 'date']
) }}

WITH bronze AS (
  SELECT * FROM {{ ref('weather_daily') }}

  {% if is_incremental() %}
  WHERE date::DATE > (SELECT MAX(date) FROM {{ this }})
  {% endif %}
),

cleaned AS (
  SELECT
    NULLIF(TRIM(city), '')                                              AS city,
    lat,
    lon,
    date::DATE                                                          AS date,
    temperature_2m_max::NUMERIC                                         AS temperature_2m_max,
    temperature_2m_min::NUMERIC                                         AS temperature_2m_min,
    ROUND((temperature_2m_max::NUMERIC - temperature_2m_min::NUMERIC), 1)
                                                                        AS temperature_range,
    COALESCE(precipitation_sum::NUMERIC, 0)                             AS precipitation_sum,
    wind_speed_10m_max::NUMERIC                                         AS wind_speed_10m_max,
    NULLIF(sunrise, '')::TIMESTAMP                                      AS sunrise,
    NULLIF(sunset,  '')::TIMESTAMP                                      AS sunset
  FROM bronze
  WHERE city IS NOT NULL AND date IS NOT NULL
)

SELECT
  {{ dbt_utils.generate_surrogate_key(['city', 'date']) }} AS weather_sk,
  *,
  CURRENT_TIMESTAMP AS load_timestamp
FROM cleaned
