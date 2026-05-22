-- =============================================================================
-- LAYER: Bronze
-- MODEL: weather_daily
-- MATERIALIZATION: view
-- =============================================================================
-- Raw daily weather data fetched from the Open-Meteo API by the
-- WEATHER__INGESTION__DAILY Airflow DAG and loaded into data_lake.weather.daily_forecast.
-- All columns remain VARCHAR / their original types — no casting here.
-- =============================================================================

{{ config(materialized='view') }}

WITH source AS (
  SELECT *
  FROM dblink(
    'host=' || '{{ var("dblink_host") }}' ||
    ' dbname=' || '{{ var("dblink_dbname") }}' ||
    ' user=' || '{{ var("dblink_user") }}' ||
    ' password=' || '{{ var("dblink_password") }}',

    'SELECT city, lat, lon, date,
            temperature_2m_max, temperature_2m_min,
            precipitation_sum, wind_speed_10m_max,
            sunrise, sunset
     FROM weather.daily_forecast'

  ) AS remote_data(
    city               VARCHAR,
    lat                DOUBLE PRECISION,
    lon                DOUBLE PRECISION,
    date               VARCHAR,
    temperature_2m_max REAL,
    temperature_2m_min REAL,
    precipitation_sum  REAL,
    wind_speed_10m_max REAL,
    sunrise            VARCHAR,
    sunset             VARCHAR
  )
)

SELECT * FROM source
