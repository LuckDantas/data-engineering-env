-- Fails if maximum temperature is lower than minimum temperature for any row.
-- This is a physical impossibility — if it happens the API returned corrupt data.
-- A passing test returns zero rows.

SELECT city, date, temperature_2m_max, temperature_2m_min
FROM {{ ref('stg_weather_daily') }}
WHERE temperature_2m_max < temperature_2m_min
