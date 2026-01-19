
    
    

select
    customer_email as unique_field,
    count(*) as n_records

from "dev"."dbt_silver"."transaction"
where customer_email is not null
group by customer_email
having count(*) > 1


