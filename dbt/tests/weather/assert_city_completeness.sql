-- Fails if any loaded date is missing one or more of the 10 expected cities.
-- Every DAG run fetches all 10 cities — a partial load means a fetch or insert failed.
-- A passing test returns zero rows.

SELECT date, COUNT(*) AS cities_found
FROM {{ ref('stg_weather_daily') }}
GROUP BY date
HAVING COUNT(*) <> 10
