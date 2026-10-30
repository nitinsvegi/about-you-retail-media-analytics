
{{
    config(
        materialized='view',
        tags=['staging', 'teasers_cms']
    )
}}

WITH raw AS (
    SELECT *
    FROM {{ source('aboutyou_raw', 'teasers_cms') }}
),

cleaned AS (
    SELECT
        NULLIF(TRIM(campaign_id), '')                  AS campaign_id
        , NULLIF(TRIM(campaign_name), '')              AS campaign_name
        , LOWER(NULLIF(TRIM(campaign_name), ''))       AS campaign_name_normalized
        , LOWER(NULLIF(TRIM(gender), ''))              AS targeting_gender
        , SAFE_CAST(active_from AS TIMESTAMP)          AS active_from
        , SAFE_CAST(active_to AS TIMESTAMP)            AS active_to
    FROM raw
)

SELECT *
FROM cleaned
