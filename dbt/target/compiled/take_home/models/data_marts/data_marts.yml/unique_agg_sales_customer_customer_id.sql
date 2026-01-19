
    
    

select
    customer_id as unique_field,
    count(*) as n_records

from "dev"."dbt_data_marts"."agg_sales_customer"
where customer_id is not null
group by customer_id
having count(*) > 1


