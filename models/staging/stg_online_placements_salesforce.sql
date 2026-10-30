
{{
    config(
        materialized='view',
        tags=['staging', 'online_placements_salesforce']
    )
}}

WITH raw AS (

    SELECT *
    FROM {{ source('aboutyou_raw', 'online_placements_salesforce') }}

),

cleaned AS (
    SELECT
        NULLIF(TRIM(campaign_name), '')                         AS campaign_name
        , LOWER(NULLIF(TRIM(campaign_name), ''))                AS campaign_name_normalized

        , SAFE.PARSE_DATE(
            '%d.%m.%Y',
            NULLIF(TRIM(campaign_start), '')
        )                                                       AS campaign_start

        , SAFE.PARSE_DATE(
            '%d.%m.%Y',
            NULLIF(TRIM(campaign_end), '')
        )                                                       AS campaign_end

        , LOWER(NULLIF(TRIM(gender), ''))                       AS targeting_gender
        , NULLIF(TRIM(country_cluster), '')                     AS country_cluster

        , SAFE_CAST(
            REPLACE(NULLIF(TRIM(reach), ''), ',', '')
            AS NUMERIC
        )                                                       AS reach_numeric

        , NULLIF(TRIM(currency_cpm), '')                        AS currency_cpm

        , SAFE_CAST(
            REPLACE(NULLIF(TRIM(cpm), ''), ',', '')
            AS NUMERIC
        )                                                       AS cpm

        -- Convert percentage strings such as 0.57% to 0.0057.
        , SAFE_CAST(
            REPLACE(NULLIF(TRIM(benchmark_ctr), ''), '%', '')
            AS NUMERIC
        ) / 100                                                 AS benchmark_ctr

        , SAFE_CAST(
            REPLACE(NULLIF(TRIM(benchmark_clicks), ''), ',', '')
            AS NUMERIC
        )                                                       AS benchmark_clicks
    FROM raw

    -- Remove only completely blank spreadsheet rows.
    WHERE COALESCE(
        NULLIF(TRIM(campaign_start), '')
        , NULLIF(TRIM(campaign_end), '')
        , NULLIF(TRIM(gender), '')
        , NULLIF(TRIM(country_cluster), '')
        , NULLIF(TRIM(reach), '')
        , NULLIF(TRIM(currency_cpm), '')
        , NULLIF(TRIM(cpm), '')
        , NULLIF(TRIM(benchmark_ctr), '')
        , NULLIF(TRIM(benchmark_clicks), '')
        , NULLIF(TRIM(campaign_name), '')
    ) IS NOT NULL

),
final AS (
    SELECT *
    FROM cleaned
)

SELECT *
FROM final
