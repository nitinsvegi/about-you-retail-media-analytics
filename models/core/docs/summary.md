# Test Queries & Findings — ABOUT YOU Retail Media

## Purpose
This file summarizes the exploratory data analysis (EDA), business reporting queries, and validation checks for the ABOUT YOU Retail Media assessment. It covers GA4 tracking events, CMS teaser campaigns, and Salesforce online-placement records, including source quality, campaign attribution, benchmark availability, and reconciliation from raw events to the reporting mart.

## Where to find the runnable queries
All queries are in the dbt project's `analyses/` folder:

- `analyses/about_you_eda.sql` — source profiling for Salesforce, CMS and GA4; cross-source matching and attribution analysis.
- `analyses/business_reporting.sql` — campaign performance, actual versus benchmark CTR, device/targeting breakdowns, and Salesforce benchmark coverage.
- `analyses/data_validation.sql` — checks across staging, CMS snapshot, intermediate models, dimension, fact, and daily reporting mart.

These are analytical SQL files, not dbt models. Run the relevant statements in BigQuery; they are not automatically executed by `dbt build`.

## Sample queries to rerun

### QA 1 — Raw GA4 event counts and CTR
```sql
SELECT
    COUNT(*) AS total_events,
    COUNTIF(LOWER(TRIM(event_type)) = 'impression') AS impressions,
    COUNTIF(LOWER(TRIM(event_type)) = 'click') AS clicks,
    ROUND(100 * SAFE_DIVIDE(
        COUNTIF(LOWER(TRIM(event_type)) = 'click'),
        COUNTIF(LOWER(TRIM(event_type)) = 'impression')
    ), 2) AS ctr_pct
FROM `about-you-assignment.aboutyou_raw.tracking_events`;
```
Expected for the assessment extract: 308,585 events; 300,093 impressions; 8,492 clicks; 2.83% CTR.

### QA 2 — Online-placement attribution status
```sql
SELECT
    match_status,
    COUNT(*) AS total_events,
    SUM(impressions) AS impressions,
    SUM(clicks) AS clicks,
    COUNTIF(benchmark_ctr IS NOT NULL) AS events_with_benchmark
FROM `about-you-assignment.aboutyou_dev.int_online_placement_events_enriched`
GROUP BY match_status
ORDER BY total_events DESC;
```
Check that the categories add up to 69,731 events and that ambiguous/unmatched records are not assigned unsupported Salesforce attributes. Refer to `data_validation.sql` section 5.2 for the explicit enrichment checks.

### QA 3 — Duplicate daily reporting grain
```sql
SELECT
    event_date,
    campaign_key,
    device,
    targeting_gender,
    country_cluster,
    COUNT(*) AS row_count
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
GROUP BY 1, 2, 3, 4, 5
HAVING COUNT(*) > 1;
```
Expected: zero rows.

### QA 4 — Fact-to-mart metric reconciliation
```sql
WITH fact_totals AS (
    SELECT SUM(impressions) AS impressions, SUM(clicks) AS clicks
    FROM `about-you-assignment.aboutyou_dev.fct_campaign_events`
),
mart_totals AS (
    SELECT SUM(impressions) AS impressions, SUM(clicks) AS clicks
    FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
)
SELECT
    f.impressions - m.impressions AS impression_difference,
    f.clicks - m.clicks AS click_difference
FROM fact_totals f
CROSS JOIN mart_totals m;
```
Expected for the checked build: both differences are zero.

### QA 5 — Campaign dimension coverage for all fact events
```sql
SELECT
    f.campaign_type,
    COUNT(*) AS fact_events_without_dimension
FROM `about-you-assignment.aboutyou_dev.fct_campaign_events` f
LEFT JOIN `about-you-assignment.aboutyou_dev.dim_campaign` d
    ON f.campaign_key = d.campaign_key
WHERE d.campaign_key IS NULL
GROUP BY 1;
```
Expected: zero rows. This is especially important when CMS records are removed from the current source extract.

### QA 6 — Online-placement benchmark coverage
```sql
SELECT
    SUM(impressions) AS total_impressions,
    SUM(impressions_with_benchmark) AS impressions_with_benchmark,
    ROUND(100 * SAFE_DIVIDE(
        SUM(impressions_with_benchmark), SUM(impressions)
    ), 2) AS impression_coverage_pct,
    SUM(clicks) AS total_clicks,
    SUM(clicks_with_benchmark) AS clicks_with_benchmark
FROM `about-you-assignment.aboutyou_dev.mart_campaign_daily_performance`
WHERE campaign_type = 'online_placement';
```
Use the full query in `business_reporting.sql` for both impression and click coverage percentages.

## Interpretation guidance — what to watch for
- **Event grain:** One GA4 row is one recorded interaction, not one visitor or session. Do not deduplicate identical-looking rows without a stable event ID.
- **Campaign identity:** Teasers have CMS IDs; online placements do not. The normalized Salesforce campaign name is a provisional grouping identity, not proof of a unique booking.
- **Join fanout:** Repeated Salesforce names and overlapping booking windows can multiply event rows if joined directly. Resolve matching at name × event-date grain and enrich only unique matches.
- **Missing versus inferred metadata:** A missing gender or country cluster does not mean all genders or all countries. Retain NULL/Unknown rather than inventing targeting.
- **Teaser history:** CMS removes deactivated campaigns. Preserve historical identities and snapshot versions; a current-source-only join can lose historical campaign reporting.
- **Activation anomalies:** Events before CMS activation may reflect setup delays, source-history gaps, or incorrect timestamps. Keep the events and investigate; do not silently discard them.
- **Benchmark comparisons:** Distinguish *benchmark-covered event measures* from reporting groups with a consistent benchmark. A group may contain benchmark-covered events yet have no safe group-level benchmark if source values conflict. Compare CTR only over a consistent, eligible population.
- **CTR aggregation:** Calculate `SUM(clicks) / SUM(impressions)`, not the average of row-level CTR values. Benchmark differences are in percentage points.
- **Date coverage:** The GA4 extract contains two days only; it cannot establish long-term trends or seasonality.
- **Production scope:** The assessment uses full-table materializations under Sandbox constraints. Proposed incremental partition replacement, lookback windows, and backfills are future work, not implemented production guarantees.

## Final assessment
The supplied SQL analysis supports a consistent event-preserving reporting model. Source-level gaps are documented rather than hidden, Salesforce enrichment is restricted to defensible matches, and the core impression/click metrics reconcile between fact and mart. The main outstanding improvements concern reliable source identifiers, historical metadata, benchmark completeness, and production-scale ingestion.
