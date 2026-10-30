{# ------------------------------------------------------------
   Production Design Recommendation

   For production GA4 volumes (>1 TB/day), use:

   materialized='incremental'
   incremental_strategy='insert_overwrite'
   partition_by={
       'field': 'event_date',
       'data_type': 'date',
       'granularity': 'day'
   }
   cluster_by=['campaign_key', 'campaign_type', 'device']

   Reprocess affected date partitions for late-arriving events,
   historical backfills and changes to campaign attribution.

   Keep source-specific enrichment in the intermediate layer.

   The assessment uses table materialization due to
   BigQuery Sandbox DML limitations.
   ------------------------------------------------------------ #}

{{ config(
    materialized='table',
    tags=['core', 'campaign_events']
) }}

WITH teaser_events AS (

    SELECT
        TO_HEX(
            SHA256(
                CONCAT('teaser|', CAST(campaign_id AS STRING))
            )
        ) AS campaign_key

        , campaign_type
        , CAST(campaign_id AS STRING) AS campaign_id
        , campaign_name
        , session_id
        , visitor_id
        , device
        , event_timestamp
        , event_date
        , event_type
        , targeting_gender
        , CAST(NULL AS STRING) AS country_cluster
        , CAST(NULL AS NUMERIC) AS benchmark_ctr
        , metadata_source AS attribution_status
        , impressions
        , clicks

    FROM {{ ref('int_teaser_events_enriched') }}

)

, online_placement_events AS (

    SELECT
        TO_HEX(
            SHA256(
                CONCAT('online_placement|', campaign_name_normalized)
            )
        ) AS campaign_key

        , campaign_type
        , CAST(campaign_id AS STRING) AS campaign_id
        , campaign_name
        , session_id
        , visitor_id
        , device
        , event_timestamp
        , event_date
        , event_type
        , targeting_gender
        , country_cluster
        , benchmark_ctr
        , match_status AS attribution_status
        , impressions
        , clicks

    FROM {{ ref('int_online_placement_events_enriched') }}

)

, combined_events AS (

    SELECT *
    FROM teaser_events

    UNION ALL

    SELECT *
    FROM online_placement_events

)

SELECT *
FROM combined_events
