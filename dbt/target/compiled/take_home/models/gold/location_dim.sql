

WITH silver AS (
    SELECT DISTINCT
        customer_location_id AS id,
        customer_city AS city,
        customer_country AS country
    FROM "dev"."dbt_silver"."transaction"

    
)

SELECT 
    *,
    CURRENT_TIMESTAMP AS load_timestamp
FROM silver