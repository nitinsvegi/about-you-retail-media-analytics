
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
   cluster_by=['campaign_type', 'campaign_id', 'event_type']

   Reprocess a configurable rolling window for late-arriving
   events and support explicit historical backfills.

   Current assessment implementation uses a regular table
   because BigQuery Sandbox expires historical partitions.
   ------------------------------------------------------------ #}

{{
    config(
        materialized='table',
        tags=['staging', 'tracking_events']
    )
}}

WITH raw AS (
    SELECT *
    FROM {{ source('aboutyou_raw', 'tracking_events') }}
),

cleaned AS (
    SELECT
        NULLIF(TRIM(CAST(session_id AS STRING)), '')             AS session_id
        , NULLIF(TRIM(CAST(visitor_id AS STRING)), '')           AS visitor_id
        , LOWER(NULLIF(TRIM(device), ''))                        AS device
        , SAFE_CAST(event_timestamp AS TIMESTAMP)                AS event_timestamp
        , DATE(SAFE_CAST(event_timestamp AS TIMESTAMP), 'UTC')   AS event_date
        , LOWER(NULLIF(TRIM(event_type), ''))                    AS event_type
        , NULLIF(TRIM(CAST(campaign_id AS STRING)), '')          AS campaign_id
        , NULLIF(TRIM(campaign_name), '')                        AS campaign_name
        , LOWER(NULLIF(TRIM(campaign_name), ''))                 AS campaign_name_normalized
        , LOWER(NULLIF(TRIM(campaign_type), ''))                 AS campaign_type
    FROM raw
),

final AS (
    SELECT
        *
        {# Records when dbt processes this staging table.
           This is not the original GA4 ingestion timestamp. #}
        , CURRENT_TIMESTAMP() AS stg_processed_at
    FROM cleaned
)

SELECT *
FROM final
