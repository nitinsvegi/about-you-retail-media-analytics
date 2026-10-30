{# ------------------------------------------------------------
   Production Design Recommendation

   For production GA4 volumes, consider incremental
   materialization with daily partition replacement:

   materialized='incremental'
   incremental_strategy='insert_overwrite'
   partition_by={
       'field': 'event_date',
       'data_type': 'date',
       'granularity': 'day'
   }
   cluster_by=['campaign_key', 'device', 'targeting_gender']

   Reprocess affected partitions for late-arriving events
   and historical backfills.

   CTR must be recalculated from aggregated clicks and
   impressions when dashboard filters span multiple rows.

   Benchmark CTR must not be summed or simply averaged.

   Country clusters are retained as source-provided values.
   Standardize regional labels and country codes only
   after confirming business-approved mappings.
   ------------------------------------------------------------ #}

{{ config(
    materialized='table',
    tags=['marts', 'campaign_performance']
) }}

WITH daily_events AS (
    SELECT
        event_date
        , campaign_key
        , device
        , targeting_gender
        , country_cluster
        , SUM(impressions)                                  AS impressions
        , SUM(clicks)                                       AS clicks
        , SUM(
            IF(benchmark_ctr IS NOT NULL, impressions, 0)
        )                                                   AS impressions_with_benchmark
        , SUM(
            IF(benchmark_ctr IS NOT NULL, clicks, 0)
        )                                                   AS clicks_with_benchmark
        , COUNTIF(
            benchmark_ctr IS NULL
        )                                                   AS events_without_benchmark
        , COUNT(DISTINCT benchmark_ctr)                     AS distinct_benchmarks
        , MAX(benchmark_ctr)                                AS benchmark_ctr_value

    FROM {{ ref('fct_campaign_events') }}
    GROUP BY 1, 2, 3, 4, 5

)

, daily_performance AS (
    SELECT
        event_date
        , campaign_key
        , device
        , targeting_gender
        , country_cluster
        , impressions
        , clicks
        , impressions_with_benchmark
        , clicks_with_benchmark
        , SAFE_DIVIDE(
            clicks,
            impressions
          )                                                    AS ctr
        , CASE
            WHEN events_without_benchmark = 0
             AND distinct_benchmarks = 1
                THEN benchmark_ctr_value
            ELSE NULL
          END                                                 AS benchmark_ctr
    FROM daily_events
)

SELECT
    p.event_date
    , p.campaign_key
    , c.campaign_type
    , c.campaign_id
    , c.campaign_name
    , p.device
    , p.targeting_gender
    , p.country_cluster
    , p.impressions
    , p.clicks
    , p.impressions_with_benchmark
    , p.clicks_with_benchmark
    , p.ctr
    , p.benchmark_ctr
FROM daily_performance p
INNER JOIN {{ ref('dim_campaign') }} c
    ON p.campaign_key = c.campaign_key