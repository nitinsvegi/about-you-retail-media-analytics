{% snapshot snap_teasers_cms %}

{{
    config(
        target_schema='aboutyou_dev',
        unique_key='campaign_id',
        strategy='check',
        check_cols=[
            'campaign_name',
            'campaign_name_normalized',
            'targeting_gender',
            'active_from',
            'active_to'
        ],
        hard_deletes='invalidate',
        tags=['snapshot', 'teasers_cms']
    )
}}

SELECT *
FROM {{ ref('stg_teasers_cms') }}

{% endsnapshot %}
