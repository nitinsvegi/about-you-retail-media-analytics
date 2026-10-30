
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
   cluster_by=['campaign_id', 'event_type', 'device']

   Rebuild complete event-date partitions using a configurable
   rolling window for late-arriving events and historical backfills.

   Reprocess affected partitions when historical CMS corrections
   require changes to past enrichment.

   Resolve campaign attributes using point-in-time CMS history.
   For events predating snapshot coverage, use the first observed
   CMS version as a provisional baseline, not verified history.

   Current assessment implementation uses a regular table due
   to BigQuery Sandbox DML restrictions and partition expiration.
   ------------------------------------------------------------ #}

{{ config(
    materialized='table',
    tags=['intermediate', 'teasers']
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
    WHERE campaign_type = 'teaser'

)

, cms_history AS (
    SELECT
        campaign_id
        , campaign_name
        , targeting_gender
        , active_from
        , active_to
        , dbt_valid_from
        , dbt_valid_to
        , ROW_NUMBER() OVER (
            PARTITION BY campaign_id
            ORDER BY dbt_valid_from
          ) AS version_number
    FROM {{ ref('snap_teasers_cms') }}
)

, cms_baseline AS (
    SELECT
        campaign_id
        , campaign_name
        , targeting_gender
        , active_from
        , active_to
        , dbt_valid_from                            AS first_observed_at
    FROM cms_history
    WHERE version_number = 1
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

        , CASE
            WHEN h.campaign_id IS NOT NULL
                THEN h.campaign_name
            ELSE b.campaign_name
          END                                       AS cms_campaign_name

        , CASE
            WHEN h.campaign_id IS NOT NULL
                THEN h.targeting_gender
            ELSE b.targeting_gender
          END                                       AS targeting_gender

        , CASE
            WHEN h.campaign_id IS NOT NULL
                THEN h.active_from
            ELSE b.active_from
          END                                        AS active_from

        , CASE
            WHEN h.campaign_id IS NOT NULL
                THEN h.active_to
            ELSE b.active_to
          END                                        AS active_to

        , CASE
            WHEN h.campaign_id IS NOT NULL
                THEN 'point_in_time'

            WHEN b.campaign_id IS NOT NULL
                THEN 'baseline_assumed'

            ELSE 'unmatched'
          END                                        AS metadata_source

        , IF(t.event_type = 'impression', 1, 0)      AS impressions
        , IF(t.event_type = 'click', 1, 0)           AS clicks

    FROM tracking_events AS t
    LEFT JOIN cms_history AS h
        ON t.campaign_id = h.campaign_id
       AND t.event_timestamp >= h.dbt_valid_from
       AND (
            t.event_timestamp < h.dbt_valid_to
            OR h.dbt_valid_to IS NULL
       )
    LEFT JOIN cms_baseline AS b
        ON t.campaign_id = b.campaign_id
       AND t.event_timestamp < b.first_observed_at
)

SELECT *
FROM enriched
