# ABOUT YOU Retail Media Analytics (dbt)

---

## Overview

This project builds a campaign-performance reporting layer for **ABOUT YOU Retail Media** using **dbt**, **Google BigQuery**, and **Looker Studio**.

It brings together GA4 tracking events, teaser campaign metadata from a CMS, and online-placement booking information from Salesforce. The goal is to provide reliable reporting on impressions, clicks, click-through rate (CTR), and benchmark performance while making source-data gaps and uncertain attribution visible.

---

## Data Sources

The supplied GA4 extract covers **June 7–8, 2025** only. Results describe this extract and should not be interpreted as long-term campaign trends.

---

## Project Structure

```text
models/
  staging/
    stg_tracking_events.sql
    stg_teasers_cms.sql
    stg_online_placements_salesforce.sql
  intermediate/
    int_teaser_events_enriched.sql
    int_online_placement_events_enriched.sql
  core/
    dim_campaign.sql
    fct_campaign_events.sql
  marts/
    mart_campaign_daily_performance.sql

snapshots/
  snap_teasers_cms.sql

analyses/
  about_you_eda.sql
  business_reporting.sql
  data_validation.sql
  summary.md

# YAML source, schema, and project configuration files are
# included in their respective dbt project locations.
```

The tree shows the **logical model organization**; folder names should match the submitted repository if they differ.

---

## Key Reporting Metrics

- **Impressions:** sum of impression events
- **Clicks:** sum of click events
- **CTR:** `SAFE_DIVIDE(SUM(clicks), SUM(impressions))`, displayed as a percentage
- **Benchmark CTR:** Salesforce-provided comparison value where attribution and benchmark eligibility are reliable

The reporting mart is intended for consumption in **Looker Studio**. Benchmark comparisons should always be read alongside benchmark coverage; a missing or conflicting benchmark is not treated as a zero benchmark.

---

## Key EDA Findings

- **GA4:** 308,585 events — 300,093 impressions and 8,492 clicks (**2.83% overall CTR**).
- **Teasers:** all 238,854 teaser events contain a campaign ID. The CMS extract has 965 unique campaign IDs; 409 records have no `active_to` value.
- **Online placements:** all 69,731 events lack a campaign ID, requiring a different matching strategy.
- **Salesforce:** 38,776 raw rows, including 13,757 fully empty rows. Campaign names are reused and no reliable booking ID is available.
- **Online-placement attribution:** 63,524 events (**91.10%**) have one date-window match; 2,820 (**4.04%**) have multiple matches; 3,387 (**4.86%**) have no date-window match.
- **Benchmark availability:** 66.3% of nonempty Salesforce rows lack benchmark CTR, so benchmark reporting has limited coverage.
- **Duplicate-looking GA4 events:** nine excess identical rows were retained because the source has no reliable event ID to prove they are ingestion duplicates.

More detail and runnable queries are documented in `analyses/summary.md`.

---

## Data Quality & Validation

Validation covers:

- Source completeness, duplicate patterns, date and numeric parsing
- CMS campaign-ID uniqueness and campaign-name reuse
- Salesforce matching ambiguity and benchmark coverage
- Fact-to-dimension coverage and reporting-grain uniqueness
- Impression and click reconciliation between the fact and daily mart

Supporting queries:

- `analyses/about_you_eda.sql`
- `analyses/business_reporting.sql`
- `analyses/data_validation.sql`
- `analyses/summary.md`

---

## Notes, Assumptions & Limitations

- **Event grain:** one GA4 row is one recorded impression or click, not one session or visitor. Identical-looking events are not automatically removed.
- **Teaser identity:** use `campaign_id`; campaign names are not unique. Historical campaigns with GA4 activity are retained in the dimension even if absent from the current CMS extract.
- **CMS history:** snapshots do not reconstruct changes or deletions that happened before the first capture. A missing `active_to` is not proof that a campaign is active.
- **Online-placement identity:** normalized campaign names are provisional grouping keys, not stable Salesforce booking IDs. Matching also considers event date; ambiguous matches are not resolved by arbitrary selection.
- **Targeting:** missing gender or country-cluster values are not assumed to mean unrestricted targeting.
- **Benchmark comparisons:** use only supported, eligible Salesforce benchmark values and disclose coverage.
- **Time coverage:** two days of tracking data do not support claims about seasonality or longer-term performance.
- **Production improvements:** stable GA4 event IDs and Salesforce booking IDs, ingestion metadata, stronger source validations, scheduled snapshots, attribution monitoring, and partitioned incremental processing with backfills.

---

## Author

**Nitin Vegi**  
Analytics Engineer
