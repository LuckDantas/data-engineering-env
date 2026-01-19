
    
    

with child as (
    select transaction_date as from_field
    from "dev"."dbt_gold"."transaction_fct"
    where transaction_date is not null
),

parent as (
    select date as to_field
    from "dev"."dbt_gold"."date_dim"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


