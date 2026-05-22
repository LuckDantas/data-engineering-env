-- Fails if any row in silver has a date in the future.
-- Future dates indicate a bug in the DAG's date calculation or a corrupt API response.
-- A passing test returns zero rows.

SELECT city, date
FROM {{ ref('stg_weather_daily') }}
WHERE date > CURRENT_DATE
