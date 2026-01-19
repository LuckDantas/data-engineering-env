
    
    

select
    transaction_id as unique_field,
    count(*) as n_records

from "dev"."dbt_gold"."transaction_fct"
where transaction_id is not null
group by transaction_id
having count(*) > 1


