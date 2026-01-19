
    
    

with child as (
    select product_id as from_field
    from "dev"."dbt_gold"."transaction_fct"
    where product_id is not null
),

parent as (
    select id as to_field
    from "dev"."dbt_gold"."product_dim"
)

select
    from_field

from child
left join parent
    on child.from_field = parent.to_field

where parent.to_field is null


