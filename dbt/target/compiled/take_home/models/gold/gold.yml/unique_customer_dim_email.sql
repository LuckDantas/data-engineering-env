
    
    

select
    email as unique_field,
    count(*) as n_records

from "dev"."dbt_gold"."customer_dim"
where email is not null
group by email
having count(*) > 1


