

WITH silver AS (
    SELECT DISTINCT
        product_id AS id,
        product_name AS name
    FROM "dev"."dbt_silver"."transaction"

    
)

SELECT 
    *,
    CURRENT_TIMESTAMP AS load_timestamp
FROM silver