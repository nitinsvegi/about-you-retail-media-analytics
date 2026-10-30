------------------------------------------------------------------------------------------------------
/*
1. Overall Campaign Performance

Business question: 
How is each Retail Media campaign performing?

Approach: 
Aggregate impressions and clicks from mart_campaign_daily_performance by campaign. 
Calculate CTR using total clicks divided by total impressions.

Outcome: 
Provides campaign-level performance across teasers and online placements using a common campaign_key, 
even where source campaign IDs are unavailable.
*/
------------------------------------------------------------------------------------------------------

SELECT
    campaign_key
    , campaign_id
    , campaign_name
    , campaign_type
    , SUM(impressions)                                              AS total_impressions
    , SUM(clicks)                                                   AS total_clicks
    , ROUND(
        SAFE_DIVIDE(
            SUM(clicks)
            , SUM(impressions)
        ) * 100
        , 2
      )                                                             AS ctr_pct
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
GROUP BY campaign_key, campaign_id, campaign_name, campaign_type
ORDER BY total_impressions DESC, campaign_name
LIMIT 20;

------------------------------------------------------------------------------------------------------
/*
2. Actual CTR vs. Benchmark CTR

Business question: 
Which online-placement campaigns perform above or below their expected CTR?

Approach: 
Calculate actual CTR using impressions and clicks with an available Salesforce benchmark. 
Compare it against the campaign benchmark and report the difference in percentage points.

Outcome: 
Enables campaign-level performance comparisons against Salesforce benchmarks where consistent benchmark 
information is available.
*/
------------------------------------------------------------------------------------------------------

SELECT
    campaign_key
    , campaign_name
    , SUM(impressions_with_benchmark)                               AS benchmark_eligible_impressions
    , SUM(clicks_with_benchmark)                                    AS benchmark_eligible_clicks
    , ROUND(
        SAFE_DIVIDE(
            SUM(clicks_with_benchmark)
            , SUM(impressions_with_benchmark)
        ) * 100
        , 2
      )                                                             AS actual_ctr_pct
    , ROUND(MAX(benchmark_ctr) * 100, 2)                            AS benchmark_ctr_pct
    , ROUND(
        (
            SAFE_DIVIDE(
                SUM(clicks_with_benchmark)
                , SUM(impressions_with_benchmark)
            ) - MAX(benchmark_ctr)
        ) * 100
        , 2
      )                                                             AS ctr_difference_pp
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
WHERE campaign_type = 'online_placement'
GROUP BY campaign_key, campaign_name
HAVING COUNT(DISTINCT benchmark_ctr) = 1
    AND SUM(impressions_with_benchmark) > 0
ORDER BY benchmark_eligible_impressions DESC
LIMIT 20;

-- 2A. SUPPORTING ANALYSIS:: BENCHMARK PERFORMANCE DISTRIBUTION
WITH benchmark_comparison AS (
    SELECT
        campaign_key
        , impressions
        , clicks
        , benchmark_ctr
        , SAFE_DIVIDE(clicks, impressions)                         AS actual_ctr
    FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
    WHERE campaign_type = 'online_placement'
        AND benchmark_ctr IS NOT NULL
        AND impressions > 0
)
SELECT
    CASE
        WHEN actual_ctr > benchmark_ctr THEN 'Above benchmark'
        WHEN actual_ctr < benchmark_ctr THEN 'Below benchmark'
        ELSE 'At benchmark'
    END                                                             AS benchmark_status
    , COUNT(*)                                                      AS reporting_groups
    , SUM(impressions)                                              AS total_impressions
    , SUM(clicks)                                                   AS total_clicks
FROM benchmark_comparison
GROUP BY benchmark_status
ORDER BY reporting_groups DESC;

/*
Results:
- 416 of 572 benchmark-eligible reporting groups (72.7%) performed above benchmark.
- 156 reporting groups (27.3%) performed below benchmark.

Note: These are reporting groups, not distinct campaigns.
*/

------------------------------------------------------------------------------------------------------
/*
3. Device and targeting-gender performance

Business question:
How does campaign performance vary across devices and targeting-gender segments?

Approach:
Aggregate impressions and clicks by campaign type, device, and targeting gender.
Calculate CTR from aggregated metrics and retain missing targeting values as 'Unknown'.

Outcome:
Enables performance comparisons across campaign types, devices, and targeting-gender
segments without excluding activity with missing targeting information.
*/
------------------------------------------------------------------------------------------------------

SELECT
    campaign_type
    , COALESCE(device, 'Unknown')                                    AS device
    , COALESCE(targeting_gender, 'Unknown')                          AS targeting_gender
    , SUM(impressions)                                              AS total_impressions
    , SUM(clicks)                                                   AS total_clicks
    , ROUND(
        SAFE_DIVIDE(SUM(clicks), SUM(impressions)) * 100
        , 2
      )                                                             AS ctr_pct
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
GROUP BY campaign_type, device, targeting_gender
ORDER BY campaign_type, device, targeting_gender, total_impressions DESC;

------------------------------------------------------------------------------------------------------
/*
4. Salesforce benchmark coverage

Business question:
What proportion of online-placement impressions and clicks have an available Salesforce benchmark?

Approach:
Aggregate total impressions and clicks alongside their benchmark-covered equivalents.
Calculate coverage percentages to assess the completeness of benchmark information.

Outcome:
Provides visibility into Salesforce benchmark availability, helping stakeholders
understand how representative benchmark-based performance comparisons are.
*/
------------------------------------------------------------------------------------------------------

SELECT
    campaign_type
    , SUM(impressions)                                              AS total_impressions
    , SUM(impressions_with_benchmark)                               AS impressions_with_benchmark
    , ROUND(
        SAFE_DIVIDE(
            SUM(impressions_with_benchmark)
            , SUM(impressions)
        ) * 100
        , 2
      )                                                             AS impression_coverage_pct
    , SUM(clicks)                                                   AS total_clicks
    , SUM(clicks_with_benchmark)                                    AS clicks_with_benchmark
    , ROUND(
        SAFE_DIVIDE(
            SUM(clicks_with_benchmark)
            , SUM(clicks)
        ) * 100
        , 2
      )                                                             AS click_coverage_pct
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
WHERE campaign_type = 'online_placement'
GROUP BY campaign_type;

