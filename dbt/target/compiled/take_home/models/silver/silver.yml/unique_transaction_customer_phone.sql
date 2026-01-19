
    
    

select
    customer_phone as unique_field,
    count(*) as n_records

from "dev"."dbt_silver"."transaction"
where customer_phone is not null
group by customer_phone
having count(*) > 1


