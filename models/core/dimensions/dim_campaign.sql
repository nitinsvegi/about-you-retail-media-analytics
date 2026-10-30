
{# ------------------------------------------------------------
   Production Design Recommendation

   Maintain one row per source-qualified campaign identity.

   For teaser campaigns, combine current CMS records with
   historically enriched GA4 events. This preserves campaign
   identities when teasers are removed from the current CMS.

   Prefer current CMS metadata for active campaigns and the
   latest enriched event metadata for historical campaigns.

   For online placements, normalized campaign names remain
   provisional identifiers until stable campaign IDs are
   available across GA4 and Salesforce.

   Keep time-dependent campaign attributes outside this
   dimension. They are resolved in the intermediate models.

   This assessment uses a table materialization.
   ------------------------------------------------------------ #}

{{ config(
    materialized='table',
    tags=['core', 'campaign']
) }}

WITH teaser_sources AS (
    -- Current CMS campaigns.
    SELECT
        campaign_id
        , campaign_name
        , campaign_name_normalized
        , 1 AS source_priority
        , CAST(NULL AS TIMESTAMP) AS event_timestamp
    FROM {{ ref('stg_teasers_cms') }}
    WHERE campaign_id IS NOT NULL

    UNION ALL

    -- Historical teaser campaigns with recorded GA4 activity.
    SELECT
        campaign_id
        , COALESCE(cms_campaign_name, campaign_name) AS campaign_name
        , LOWER(
            NULLIF(
                TRIM(COALESCE(cms_campaign_name, campaign_name)),
                ''
            )
          ) AS campaign_name_normalized
        , 2 AS source_priority
        , event_timestamp
    FROM {{ ref('int_teaser_events_enriched') }}
    WHERE campaign_id IS NOT NULL

)

, teaser_names AS (
    SELECT
        campaign_id

        , ARRAY_AGG(
            campaign_name IGNORE NULLS
            ORDER BY source_priority, event_timestamp DESC, campaign_name
            LIMIT 1
          )[SAFE_OFFSET(0)] AS campaign_name
        , ARRAY_AGG(
            campaign_name_normalized IGNORE NULLS
            ORDER BY source_priority, event_timestamp DESC, campaign_name_normalized
            LIMIT 1
          )[SAFE_OFFSET(0)] AS campaign_name_normalized
    FROM teaser_sources
    GROUP BY campaign_id
)

, teaser_campaigns AS (
    SELECT
        TO_HEX(
            SHA256(
                CONCAT('teaser|', CAST(campaign_id AS STRING))
            )
        ) AS campaign_key
        , 'teaser' AS campaign_type
        , CAST(campaign_id AS STRING) AS campaign_id
        , campaign_name
        , campaign_name_normalized
        , 'cms_campaign_id' AS campaign_identity_source
    FROM teaser_names
)

, online_placement_sources AS (
    SELECT
        campaign_name_normalized
        , campaign_name
        , 1 AS source_priority
    FROM {{ ref('stg_online_placements_salesforce') }}
    WHERE campaign_name_normalized IS NOT NULL

    UNION ALL

    SELECT
        campaign_name_normalized
        , campaign_name
        , 2 AS source_priority
    FROM {{ ref('stg_tracking_events') }}
    WHERE campaign_type = 'online_placement'
      AND campaign_name_normalized IS NOT NULL

)

, online_placement_names AS (

    SELECT
        campaign_name_normalized
        , ARRAY_AGG(
            campaign_name
            ORDER BY source_priority, campaign_name
            LIMIT 1
          )[OFFSET(0)] AS campaign_name
    FROM online_placement_sources
    GROUP BY campaign_name_normalized

)

, online_placement_campaigns AS (

    SELECT
        TO_HEX(
            SHA256(
                CONCAT(
                    'online_placement|',
                    campaign_name_normalized
                )
            )
        ) AS campaign_key

        , 'online_placement' AS campaign_type
        , CAST(NULL AS STRING) AS campaign_id
        , campaign_name
        , campaign_name_normalized
        , 'normalized_campaign_name' AS campaign_identity_source

    FROM online_placement_names

)

, combined AS (

    SELECT *
    FROM teaser_campaigns

    UNION ALL

    SELECT *
    FROM online_placement_campaigns

)

SELECT *
FROM combined
