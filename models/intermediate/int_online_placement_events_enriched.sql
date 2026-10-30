
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
   cluster_by=['campaign_name_normalized', 'event_type', 'device']

   Reprocess complete event-date partitions for late arrivals,
   backfills, and changes to Salesforce booking metadata.

   Resolve Salesforce matches at campaign-name and event-date
   grain before joining back to individual GA4 events.

   Current assessment implementation uses a regular table due
   to BigQuery Sandbox DML restrictions and partition expiration.
   ------------------------------------------------------------ #}

{{ config(
    materialized='table',
    tags=['intermediate', 'online_placements']
) }}

WITH tracking_events AS (
    SELECT
        session_id
        , visitor_id
        , device
        , event_timestamp
        , event_date
        , event_type
        , campaign_id
        , campaign_name
        , campaign_name_normalized
        , campaign_type
    FROM {{ ref('stg_tracking_events') }}
    WHERE campaign_type = 'online_placement'

)

, campaign_dates AS (
    SELECT DISTINCT
        campaign_name_normalized
        , event_date
    FROM tracking_events
)

, salesforce_configurations AS (
    SELECT DISTINCT
        campaign_name_normalized
        , campaign_start
        , campaign_end
        , targeting_gender
        , country_cluster
        , reach_numeric
        , currency_cpm
        , cpm
        , benchmark_ctr
        , benchmark_clicks
    FROM {{ ref('stg_online_placements_salesforce') }}
    WHERE campaign_name_normalized IS NOT NULL

)

, campaign_date_matches AS (

    SELECT
        d.campaign_name_normalized
        , d.event_date

        , COUNT(s.campaign_name_normalized) AS matching_configurations

        , IF(
            COUNT(s.campaign_name_normalized) = 1,
            MAX(s.targeting_gender),
            NULL
          )                                 AS targeting_gender

        , IF(
            COUNT(s.campaign_name_normalized) = 1,
            MAX(s.country_cluster),
            NULL
          ) AS country_cluster

        , IF(
            COUNT(s.campaign_name_normalized) = 1,
            MAX(s.benchmark_ctr),
            NULL
          )                                  AS benchmark_ctr

    FROM campaign_dates AS d

    LEFT JOIN salesforce_configurations AS s
        ON d.campaign_name_normalized = s.campaign_name_normalized
       AND d.event_date BETWEEN s.campaign_start AND s.campaign_end

    GROUP BY
        d.campaign_name_normalized
        , d.event_date

)

, enriched AS (
    SELECT
        t.session_id
        , t.visitor_id
        , t.device
        , t.event_timestamp
        , t.event_date
        , t.event_type

        , t.campaign_id
        , t.campaign_name
        , t.campaign_name_normalized
        , t.campaign_type

        , m.targeting_gender
        , m.country_cluster
        , m.benchmark_ctr
        , m.matching_configurations

        , CASE
            WHEN m.matching_configurations = 1 THEN 'unique'
            WHEN m.matching_configurations > 1 THEN 'ambiguous'
            ELSE 'unmatched'
          END AS match_status

        , IF(t.event_type = 'impression', 1, 0) AS impressions
        , IF(t.event_type = 'click', 1, 0) AS clicks

    FROM tracking_events AS t
    LEFT JOIN campaign_date_matches AS m
        ON t.campaign_name_normalized = m.campaign_name_normalized
       AND t.event_date = m.event_date
)

SELECT *
FROM enriched
