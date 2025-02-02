{{
    config(
        materialized='view'
    )
}}


{% set statuses=['returned', 'completed', 'return_pending', 'shipped', 'placed'] %}


with id_series as (

{{ dbt_utils.generate_series(100000) }}

),

adding_order_id as (


select 
    generated_number as id,
    
    -- wacky way to get some semblance of randomness for which ids are tied to which orders
    dense_rank() over (
        order by 
            case 
                when id % 5 = 0
                    then id - 1
                when id % 5 = 1 
                    then id - 2
                when id % 9 = 0
                    then id - 1
                else id
            end
    )
     as order_id
        

from id_series

),

distinct_order_ids as (
    select 
        distinct order_id
    
    from adding_order_id
),

adding_order_created_at as (
    select 
        order_id,
        {{ dbt.dateadd(
            'month',
            -1,
            dbt.dateadd("second", "order_id", dbt.date_trunc('day', 'current_timestamp'))) 
        }} as order_created_at
    
    from distinct_order_ids
),

final as (
    select 
        order_id,
        -- every 5th order gets an update
        order_id % 5 = 0 as needs_update,

        case 
            when adding_order_created_at.order_id % 10 <= 6
                then 'credit'
            when adding_order_created_at.order_id % 10 <= 8
                then 'debit'
            else 'cash'
        end as payment_method,
        
        case 
            -- every 5th order gets randomly updated
            when order_id % 5 = 0
                then 
                    case 
                        when uniform(0, 5, random()) = 0
                            then '{{ statuses[0] }}'
                        when uniform(0, 5, random()) = 1
                            then '{{ statuses[1] }}'
                        when uniform(0, 5, random()) = 2
                            then '{{ statuses[2] }}'
                        when uniform(0, 5, random()) = 3
                            then '{{ statuses[3] }}'
                        else '{{ statuses[4] }}'
                    end 
            when order_id % 3 = 0
                then 'placed'
            when order_id % 3 = 1
                then 'shipped'
            else 'returned'
        end as status,

        order_created_at,

        case 
            -- every 5th order gets randomly updated
            when order_id % 5 = 0
                then current_timestamp
            else order_created_at
        end as order_updated_at


    from  adding_order_created_at
) 

select 
    order_id,
    status,
    payment_method,
    order_created_at,
    order_updated_at

from final

order by 1