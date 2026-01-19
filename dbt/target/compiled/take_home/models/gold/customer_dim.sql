

WITH silver AS (
    SELECT DISTINCT
        customer_id AS id,
        customer_first_name AS first_name,
        customer_last_name AS last_name,
        customer_email AS email,
        customer_phone AS phone
    FROM "dev"."dbt_silver"."transaction"

    
)

SELECT 
    *,
    CURRENT_TIMESTAMP AS load_timestamp
FROM silver