------------------------------------------------------------------------------------------------------------------------------
-- Validating stg_tracking_events
------------------------------------------------------------------------------------------------------------------------------
-- 1. Tracking Events: Event Counts and Date Checks
SELECT
    COUNT(*)                                                 AS total_events
    , COUNTIF(event_type = 'impression')                     AS total_impressions
    , COUNTIF(event_type = 'click')                          AS total_clicks
    , COUNTIF(event_timestamp IS NULL)                       AS invalid_timestamps
    , COUNTIF(event_date IS NULL)                            AS null_event_dates
    , MIN(event_date)                                        AS min_event_date
    , MAX(event_date)                                        AS max_event_date
    , MIN(stg_processed_at)                                  AS first_processed_at
    , MAX(stg_processed_at)                                  AS last_processed_at
FROM `about-you-assignment.aboutyou_dev.stg_tracking_events`;


------------------------------------------------------------------------------------------------------------------------------
-- Validating stg_teasers_cms & snap_teasers_cms
------------------------------------------------------------------------------------------------------------------------------
-- 2.1 Teaser CMS: Campaign IDs and Missing Values
SELECT
    COUNT(*) AS total_campaigns
    , COUNT(DISTINCT campaign_id)                            AS unique_campaigns
    , COUNTIF(campaign_id IS NULL)                           AS missing_campaign_ids
    , COUNTIF(campaign_name IS NULL)                         AS missing_campaign_names
    , COUNTIF(targeting_gender IS NULL)                      AS missing_targeting_gender
    , COUNTIF(active_from IS NULL)                           AS missing_start_dates
    , COUNTIF(active_to IS NULL)                             AS missing_end_dates
FROM `about-you-assignment.aboutyou_dev.stg_teasers_cms`;


-- 2.2 Teaser CMS Snapshot
SELECT
    campaign_id
    , campaign_name
    , active_from
    , active_to
    , dbt_scd_id
    , dbt_updated_at
    , dbt_valid_from
    , dbt_valid_to
FROM `about-you-assignment.aboutyou_dev.snap_teasers_cms`
LIMIT 50;


------------------------------------------------------------------------------------------------------------------------------
-- Validating stg_online_placements_salesforce
------------------------------------------------------------------------------------------------------------------------------
-- 3. Salesforce Placements: Missing Values and Benchmark CTR
SELECT
    COUNT(*) AS total_records
    , COUNTIF(campaign_name IS NULL)                         AS missing_campaign_names
    , COUNTIF(campaign_start IS NULL)                        AS missing_start_dates
    , COUNTIF(campaign_end IS NULL)                          AS missing_end_dates
    , COUNTIF(reach_numeric IS NULL)                         AS missing_reach
    , COUNTIF(benchmark_ctr IS NULL)                         AS missing_benchmark_ctr
    , COUNTIF(benchmark_ctr < 0 OR benchmark_ctr > 1)        AS invalid_benchmark_ctr
FROM `about-you-assignment.aboutyou_dev.stg_online_placements_salesforce`;


------------------------------------------------------------------------------------------------------------------------------
-- Validating int_teaser_events_enriched
------------------------------------------------------------------------------------------------------------------------------
-- 4. Teaser Events: Metadata Enrichment Check
SELECT
    metadata_source
    , COUNT(*)                                                   AS total_events
    , SUM(impressions)                                           AS impressions
    , SUM(clicks)                                                AS clicks
    , COUNTIF(targeting_gender IS NULL)                          AS missing_gender
FROM `about-you-assignment.aboutyou_dev.int_teaser_events_enriched`
GROUP BY metadata_source
ORDER BY metadata_source;


------------------------------------------------------------------------------------------------------------------------------
-- Validating int_online_placement_events_enriched
------------------------------------------------------------------------------------------------------------------------------
-- 5.1 Online Placements: Event Matching Summary
SELECT
    match_status
    , COUNT(*)                                                  AS total_events
    , ROUND(
        SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) * 100,
        2
      ) AS event_percentage
    , SUM(impressions) AS impressions
    , SUM(clicks) AS clicks
    , COUNTIF(targeting_gender IS NOT NULL)                      AS events_with_gender
    , COUNTIF(benchmark_ctr IS NOT NULL)                         AS events_with_benchmark
    , MAX(matching_configurations)                               AS max_matching_configurations
FROM `about-you-assignment.aboutyou_dev.int_online_placement_events_enriched`
GROUP BY match_status
ORDER BY match_status;

-- 5.2 Online Placements: Match Status and Enrichment Checks
SELECT
    COUNTIF(
        match_status != 'unique'
        AND (
            targeting_gender IS NOT NULL
            OR country_cluster IS NOT NULL
            OR benchmark_ctr IS NOT NULL
        )
    )                                                            AS incorrectly_enriched_events
    , COUNTIF(
        (match_status = 'unique' AND matching_configurations != 1)
        OR (match_status = 'ambiguous' AND matching_configurations <= 1)
        OR (match_status = 'unmatched' AND matching_configurations != 0)
    )                                                            AS incorrect_match_status
FROM `about-you-assignment.aboutyou_dev.int_online_placement_events_enriched`;


------------------------------------------------------------------------------------------------------------------------------
-- Validating dim_campaign
------------------------------------------------------------------------------------------------------------------------------
-- 6. Campaign Dimension: Campaign Keys and Missing Names
SELECT
    campaign_type
    , COUNT(*)                                                  AS total_campaigns
    , COUNT(DISTINCT campaign_key)                              AS distinct_campaign_keys
    , COUNTIF(campaign_name IS NULL)                            AS missing_campaign_names
FROM `about-you-assignment.aboutyou_dev.dim_campaign`
GROUP BY campaign_type
ORDER BY campaign_type;


------------------------------------------------------------------------------------------------------------------------------
-- Validating fct_campaign_events
------------------------------------------------------------------------------------------------------------------------------
-- 7.1 Campaign Events: Event Counts by Campaign Type
SELECT
    campaign_type
    , COUNT(*)                                                   AS total_events
    , SUM(impressions)                                           AS impressions
    , SUM(clicks)                                                AS clicks
    , COUNTIF(campaign_key IS NULL)                              AS missing_campaign_keys
FROM `about-you-assignment.aboutyou_dev.fct_campaign_events`
GROUP BY campaign_type

UNION ALL

SELECT
    'TOTAL'                                                      AS campaign_type
    , COUNT(*)                                                   AS total_events
    , SUM(impressions)                                           AS impressions
    , SUM(clicks)                                                AS clicks
    , COUNTIF(campaign_key IS NULL)                              AS missing_campaign_keys
FROM `about-you-assignment.aboutyou_dev.fct_campaign_events`;


-- 7.2 Online Placements: Attribution and Benchmark Availability
SELECT
    attribution_status
    , COUNT(*)                                                   AS total_events
    , SUM(impressions)                                           AS impressions
    , SUM(clicks)                                                AS clicks
    , COUNTIF(benchmark_ctr IS NOT NULL)                         AS events_with_benchmark
    , SUM(
        IF(benchmark_ctr IS NOT NULL, impressions, 0)
    ) AS impressions_with_benchmark
FROM `about-you-assignment.aboutyou_dev.fct_campaign_events`
WHERE campaign_type = 'online_placement'
GROUP BY attribution_status
ORDER BY total_events DESC;


------------------------------------------------------------------------------------------------------------------------------
-- Validating mart_campaign_daily_performance
------------------------------------------------------------------------------------------------------------------------------
-- 8.1 Campaign MART: Duplicate Row Check
SELECT
    event_date
    , campaign_key
    , device
    , targeting_gender
    , country_cluster
    , COUNT(*)                                                    AS row_count
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(*) > 1;

-- 8.2 Campaign MART: Impressions and Clicks Reconciliation
WITH fact_totals AS (
    SELECT
        SUM(impressions)                                           AS impressions
        , SUM(clicks)                                              AS clicks
    FROM `about-you-assignment.aboutyou_dev.fct_campaign_events`
)
, mart_totals AS (
    SELECT
        SUM(impressions)                                           AS impressions
        , SUM(clicks)                                              AS clicks
    FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
)
SELECT
    f.impressions AS fact_impressions
    , m.impressions AS mart_impressions
    , f.clicks AS fact_clicks
    , m.clicks AS mart_clicks
    , f.impressions - m.impressions AS impression_difference
    , f.clicks - m.clicks AS click_difference
FROM fact_totals f
CROSS JOIN mart_totals m;

-- 8.3 Campaign MART: Performance by Campaign Type
SELECT
    campaign_type
    , COUNT(*)                                                    AS total_rows
    , COUNTIF(benchmark_ctr IS NOT NULL)                         AS rows_with_benchmark
    , COUNTIF(benchmark_ctr IS NULL)                             AS rows_without_benchmark
    , ROUND(
        100 * SAFE_DIVIDE(
            COUNTIF(benchmark_ctr IS NOT NULL),
            COUNT(*)
        ),
        2
    ) AS benchmark_coverage_pct
    , SUM(impressions)                                           AS impressions
    , SUM(clicks)                                                AS clicks
    , ROUND(
        100 * SAFE_DIVIDE(
            SUM(clicks),
            SUM(impressions)
        ),
        2
    ) AS benchmark_row_coverage_pct
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
GROUP BY campaign_type
ORDER BY campaign_type;

-- 8.4 Campaign MART: Benchmark Metric Reconciliation
WITH fact_totals AS (
    SELECT
        SUM(impressions)                                           AS impressions
        , SUM(clicks)                                              AS clicks
        , SUM(
            IF(benchmark_ctr IS NOT NULL, impressions, 0)
        )                                                           AS impressions_with_benchmark
        , SUM(
            IF(benchmark_ctr IS NOT NULL, clicks, 0)
        )                                                         AS clicks_with_benchmark
    FROM `about-you-assignment.aboutyou_dev.fct_campaign_events`
)
, mart_totals AS (
    SELECT
        SUM(impressions)                                            AS impressions
        , SUM(clicks) AS clicks
        , SUM(impressions_with_benchmark)                           AS impressions_with_benchmark
        , SUM(clicks_with_benchmark)                                AS clicks_with_benchmark
    FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
)
SELECT
    f.impressions - m.impressions                                   AS impression_difference
    , f.clicks - m.clicks                                           AS click_difference
    , f.impressions_with_benchmark
        - m.impressions_with_benchmark                              AS benchmark_impression_difference
    , f.clicks_with_benchmark
        - m.clicks_with_benchmark                                   AS benchmark_click_difference
FROM fact_totals f
CROSS JOIN mart_totals m;


-- 8.5 Campaign MART: Missing Values by Campaign Type
SELECT
    campaign_type
    , COUNT(*)                                                    AS total_rows
    , COUNTIF(campaign_key IS NULL)                               AS null_campaign_key
    , COUNTIF(campaign_id IS NULL)                                AS null_campaign_id
    , COUNTIF(campaign_name IS NULL)                              AS null_campaign_name
    , COUNTIF(targeting_gender IS NULL)                           AS null_targeting_gender_rows
    , COUNTIF(country_cluster IS NULL)                            AS null_country_cluster_rows
    , SUM(impressions)                                            AS total_impressions
    , SUM(IF(targeting_gender IS NULL, impressions, 0))           AS impressions_without_gender
    , SUM(IF(country_cluster IS NULL, impressions, 0))            AS impressions_without_country_cluster
    , SUM(clicks)                                                 AS total_clicks
    , SUM(IF(targeting_gender IS NULL, clicks, 0))                AS clicks_without_gender
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
GROUP BY  campaign_type
ORDER BY campaign_type;

------------------------------------------------------------
-- Actual CTR vs Benchmark CTR — Online Placements
-- Validation against Data Studio chart
------------------------------------------------------------

SELECT
    campaign_name
    , SUM(impressions_with_benchmark) AS eligible_impressions
    , SUM(clicks_with_benchmark) AS eligible_clicks
    , ROUND(
        SAFE_DIVIDE(
            SUM(clicks_with_benchmark)
            , SUM(impressions_with_benchmark)
        ) * 100
        , 2
      ) AS actual_ctr_pct
    , ROUND(MAX(benchmark_ctr) * 100, 2) AS benchmark_ctr_pct
    , ROUND(
        (
            SAFE_DIVIDE(
                SUM(clicks_with_benchmark)
                , SUM(impressions_with_benchmark)
            ) - MAX(benchmark_ctr)
        ) * 100
        , 2
      ) AS ctr_difference_pp
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
WHERE campaign_type = 'online_placement'
  AND benchmark_ctr > 0
GROUP BY campaign_name
ORDER BY eligible_impressions DESC
LIMIT 10;