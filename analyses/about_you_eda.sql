-- About You - Case Study EDA

------------------------------------------------------------------------------------------------------------------------------
-- EDA 1 -> source: online_placements_salesforce
------------------------------------------------------------------------------------------------------------------------------

--EDA 1.1 How many campaign names are populated, and how many distinct campaign names are there?
SELECT
    COUNT(*) AS total_rows,

    COUNTIF(
        campaign_name IS NOT NULL
        AND TRIM(campaign_name) != ''
    ) AS rows_with_campaign_name

    , COUNTIF(
          campaign_name IS NULL
          OR TRIM(campaign_name) = ''
      ) AS rows_without_campaign_name

    ,  COUNT(
          DISTINCT NULLIF(TRIM(campaign_name), '')
      ) AS distinct_campaign_names
FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`;

/*
total_rows                  : 38776
rows_with_campaign_name	    : 24800
rows_without_campaign_name	: 13976
distinct_campaign_names     : 18678

1. more than one-third of Salesforce records have no campaign name
2. campaign names are reused, so campaign_name isn't a unique identifier
*/

------------------------------------------------------------------------------------------------------------------------------
--EDA 1.2 Rows Profiling

WITH row_profile AS (
    SELECT
        *
        , (campaign_start IS NOT NULL
            OR campaign_end IS NOT NULL
            OR gender IS NOT NULL
            OR country_cluster IS NOT NULL
            OR reach IS NOT NULL
            OR currency_cpm IS NOT NULL
            OR cpm IS NOT NULL
            OR benchmark_ctr IS NOT NULL
            OR benchmark_clicks IS NOT NULL
            OR campaign_name IS NOT NULL
          ) AS has_any_data
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
)

SELECT
    COUNT(*) AS raw_rows
    , COUNTIF(has_any_data)     AS nonempty_rows
    , COUNTIF(NOT has_any_data) AS completely_empty_rows
    , COUNTIF(
          has_any_data AND NULLIF(TRIM(campaign_name), '') IS NOT NULL
      ) AS rows_with_campaign_name
    ,  COUNTIF(
          has_any_data AND NULLIF(TRIM(campaign_name), '') IS NULL
      ) AS nonempty_rows_missing_campaign_name
FROM row_profile;

/*
raw_rows                            : 38776
nonempty_rows	                    : 25019
completely_empty_rows	            : 13757
rows_with_campaign_name             : 24800
nonempty_rows_missing_campaign_name : 219
*/

------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.3: Duplicate analysis
WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE
        campaign_start IS NOT NULL
        OR campaign_end IS NOT NULL
        OR gender IS NOT NULL
        OR country_cluster IS NOT NULL
        OR reach IS NOT NULL
        OR currency_cpm IS NOT NULL
        OR cpm IS NOT NULL
        OR benchmark_ctr IS NOT NULL
        OR benchmark_clicks IS NOT NULL
        OR campaign_name IS NOT NULL
),
duplicate_groups AS (
    SELECT
        campaign_start
        , campaign_end
        , gender
        , country_cluster
        , reach
        , currency_cpm
        , cpm
        , benchmark_ctr
        , benchmark_clicks
        , campaign_name
        , COUNT(*) AS occurrence_count
    FROM nonempty_records
    GROUP BY ALL
)

SELECT
    SUM(occurrence_count)           AS total_nonempty_rows    -- All records containing at least one value
    , COUNT(*)                      AS distinct_records       -- Number of unique combinations across all ten original columns 
    , SUM(occurrence_count - 1)     AS excess_duplicate_rows  -- Number of rows beyond one occurrence per exact combination
    , COUNTIF(occurrence_count > 1) AS duplicate_groups       -- Number of distinct row combinations that appear more than once
FROM duplicate_groups;

/*
-- to view duplicate records
SELECT *
FROM duplicate_groups
WHERE TRUE
  AND occurrence_count > 1
ORDER BY campaign_start
        , campaign_end
        , gender
        , country_cluster
        , reach
        , currency_cpm
        , cpm
        , benchmark_ctr
        , benchmark_clicks;
*/        

/*
total_nonempty_rows     : 25019
distinct_records	    : 24765
excess_duplicate_rows	: 254  
duplicate_groups        : 27

-- exact duplicates are not necessarily duplicate campaigns
-- 254 excess identical rows. Without a booking ID, we can't tell whether these are duplicate exports or separate bookings
*/

------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.4: Normalized duplicate analysis
-- Case-insensitive and whitespace-trimmed comparison

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE
        campaign_start IS NOT NULL
        OR campaign_end IS NOT NULL
        OR gender IS NOT NULL
        OR country_cluster IS NOT NULL
        OR reach IS NOT NULL
        OR currency_cpm IS NOT NULL
        OR cpm IS NOT NULL
        OR benchmark_ctr IS NOT NULL
        OR benchmark_clicks IS NOT NULL
        OR campaign_name IS NOT NULL
),
normalized_records AS (
    SELECT
        TRIM(campaign_start)           AS campaign_start
        , TRIM(campaign_end)           AS campaign_end
        , LOWER(TRIM(gender))          AS gender
        , LOWER(TRIM(country_cluster)) AS country_cluster
        , TRIM(reach)                  AS reach
        , UPPER(TRIM(currency_cpm))    AS currency_cpm
        , TRIM(cpm)                    AS cpm
        , TRIM(benchmark_ctr)          AS benchmark_ctr
        , TRIM(benchmark_clicks)       AS benchmark_clicks
        , LOWER(TRIM(campaign_name))   AS campaign_name
    FROM nonempty_records
),
normalized_groups AS (
    SELECT
        *
        , COUNT(*) AS occurrence_count
    FROM normalized_records
    GROUP BY ALL
)

SELECT
    SUM(occurrence_count)           AS total_nonempty_rows,
    COUNT(*)                        AS normalized_distinct_records,
    SUM(occurrence_count - 1)       AS normalized_excess_duplicate_rows,
    COUNTIF(occurrence_count > 1)   AS normalized_duplicate_groups,
    SUM(occurrence_count - 1) - 254 AS additional_duplicates_after_normalization
FROM normalized_groups;

/*
total_nonempty_rows                       : 25019
normalized_distinct_records	              : 24765
normalized_excess_duplicate_rows	      : 254
normalized_duplicate_groups               : 27
additional_duplicates_after_normalization : 0

-- normalization didn't reveal any additional duplicates
*/

------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.5: Investigate repeated campaign names
-- Exclude empty names and exact duplicate records

WITH distinct_records AS (
    SELECT DISTINCT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
),
campaign_groups AS (
    SELECT
        LOWER(TRIM(campaign_name))                     AS normalized_campaign_name
        , COUNT(*)                                     AS record_count
        , COUNT(DISTINCT LOWER(TRIM(gender)))          AS distinct_genders
        , COUNT(DISTINCT LOWER(TRIM(country_cluster))) AS distinct_countries
        , COUNT(DISTINCT CONCAT(
              COALESCE(campaign_start, '<NULL>'),
              '|',
              COALESCE(campaign_end, '<NULL>')
          ))                                           AS distinct_date_ranges
    FROM distinct_records
    GROUP BY 1
)
SELECT *
FROM campaign_groups
WHERE record_count > 1
ORDER BY record_count DESC
LIMIT 50;


-- Campaign Name : nike launch
WITH distinct_records AS (
    SELECT DISTINCT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
)
SELECT
    LOWER(TRIM(campaign_name))                     AS normalized_campaign_name
    , LOWER(TRIM(gender))                          AS gender
    , LOWER(TRIM(country_cluster))                 AS country_cluster
    , CONCAT(
          COALESCE(campaign_start, '<NULL>'),
          '|',
          COALESCE(campaign_end, '<NULL>')
      )                                            AS date_ranges
FROM distinct_records
WHERE TRUE
  AND LOWER(TRIM(campaign_name)) = 'nike launch';

/*
SELECT
    LOWER(TRIM(campaign_name))                     AS normalized_campaign_name
    , LOWER(TRIM(gender))                          AS gender
    , COUNT(DISTINCT LOWER(TRIM(gender)))          AS distinct_genders
--    , LOWER(TRIM(country_cluster))                 AS country_cluster
--    , COUNT(DISTINCT LOWER(TRIM(country_cluster))) AS distinct_countries
FROM distinct_records
WHERE TRUE
  AND LOWER(TRIM(campaign_name)) LIKE 'nike launch'
GROUP BY 1, 2
*/

-- campaign names are not unique identifiers
-- the same campaign name appears across multiple date ranges, genders, and country clusters
-- country_cluster contains inconsistent representations:
--    Regional: DACH, Nordics, Southern Europe, etc.
--    Country codes: DE, FR, AT, NL, CH, etc.
--    Numeric codes: 1, 2, 3, 5 (meaning unknown)
-- some gender and country_cluster values are missing

------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.6: Salesforce column completeness

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE
        campaign_start IS NOT NULL
        OR campaign_end IS NOT NULL
        OR gender IS NOT NULL
        OR country_cluster IS NOT NULL
        OR reach IS NOT NULL
        OR currency_cpm IS NOT NULL
        OR cpm IS NOT NULL
        OR benchmark_ctr IS NOT NULL
        OR benchmark_clicks IS NOT NULL
        OR campaign_name IS NOT NULL
),
column_profile AS (
    SELECT
        COUNT(*) AS total_records
        , COUNTIF(NULLIF(TRIM(campaign_name), '') IS NULL)    AS missing_campaign_name
        , COUNTIF(NULLIF(TRIM(campaign_start), '') IS NULL)   AS missing_campaign_start
        , COUNTIF(NULLIF(TRIM(campaign_end), '') IS NULL)     AS missing_campaign_end
        , COUNTIF(NULLIF(TRIM(gender), '') IS NULL)           AS missing_gender
        , COUNTIF(NULLIF(TRIM(country_cluster), '') IS NULL)  AS missing_country_cluster
        , COUNTIF(NULLIF(TRIM(reach), '') IS NULL)            AS missing_reach
        , COUNTIF(NULLIF(TRIM(currency_cpm), '') IS NULL)     AS missing_currency_cpm
        , COUNTIF(NULLIF(TRIM(cpm), '') IS NULL)              AS missing_cpm
        , COUNTIF(NULLIF(TRIM(benchmark_ctr), '') IS NULL)    AS missing_benchmark_ctr
        , COUNTIF(NULLIF(TRIM(benchmark_clicks), '') IS NULL) AS missing_benchmark_clicks
 FROM nonempty_records
)
SELECT
    total_records
    , missing_campaign_name
    , missing_campaign_start
    , missing_campaign_end
    , missing_gender
    , missing_country_cluster
    , missing_reach
    , missing_currency_cpm
    , missing_cpm
    , missing_benchmark_ctr
    , missing_benchmark_clicks
FROM column_profile;

/*
total_records	           : 25019 
missing_campaign_name	   : 219   (0.9%)
missing_campaign_start     : 219   (0.9%)
missing_campaign_end	   : 0     
missing_gender	           : 3128  (12.5%)
missing_country_cluster	   : 4860  (19.4%)
missing_reach	           : 223   (0.9%)
missing_currency_cpm	   : 0
missing_cpm	               : 6062  (24.2%)
missing_benchmark_ctr	   : 16576 (66.3%)
missing_benchmark_clicks   : 19874 (79.4%)

-- campaign dates are largely populated
-- missing gender and country-cluster values should not automatically be interpreted as all-gender or international targeting
*/

-- EDA 1.6.1: Benchmark CTR and benchmark clicks completeness

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE
        campaign_start IS NOT NULL
        OR campaign_end IS NOT NULL
        OR gender IS NOT NULL
        OR country_cluster IS NOT NULL
        OR reach IS NOT NULL
        OR currency_cpm IS NOT NULL
        OR cpm IS NOT NULL
        OR benchmark_ctr IS NOT NULL
        OR benchmark_clicks IS NOT NULL
        OR campaign_name IS NOT NULL
),
benchmark_profile AS (
    SELECT
        *
        , NULLIF(TRIM(benchmark_ctr), '') IS NOT NULL    AS has_benchmark_ctr
        , NULLIF(TRIM(benchmark_clicks), '') IS NOT NULL AS has_benchmark_clicks
    FROM nonempty_records
)
SELECT
    COUNT(*) AS total_records
    , COUNTIF(has_benchmark_ctr AND has_benchmark_clicks)         AS both_benchmarks_present
    , COUNTIF(has_benchmark_ctr AND NOT has_benchmark_clicks)     AS only_benchmark_ctr_present
    , COUNTIF(NOT has_benchmark_ctr AND has_benchmark_clicks)     AS only_benchmark_clicks_present
    , COUNTIF(NOT has_benchmark_ctr AND NOT has_benchmark_clicks) AS both_benchmarks_missing
FROM benchmark_profile;

/*
total_records	              : 25019
both_benchmarks_present	      : 4607  (18.4%)
only_benchmark_ctr_present	  : 3836  (15.3%)
only_benchmark_clicks_present : 538   (2.2%)
both_benchmarks_missing       : 16038 (64.1%)

-- 64.1% of records have neither benchmark value - this limits benchmark reporting for online placements only
*/			


-- EDA 1.6.2: Inspect benchmark CTR formats and values

SELECT
    benchmark_ctr
    , COUNT(*) AS record_count
FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
WHERE NULLIF(TRIM(benchmark_ctr), '') IS NOT NULL
GROUP BY benchmark_ctr
ORDER BY record_count DESC
LIMIT 50;

-- the 50 most frequently occurring benchmark CTR values are represented as percentage-formatted strings (e.g., 0.57%, 1.39%, 3.00%)


-- EDA 1.6.3: Validate benchmark CTR values

WITH benchmark_values AS (
    SELECT
        TRIM(benchmark_ctr) AS benchmark_ctr
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(benchmark_ctr), '') IS NOT NULL

),
parsed_values AS (
    SELECT
        benchmark_ctr
        , SAFE_CAST(
              REPLACE(benchmark_ctr, '%', '') AS FLOAT64
          ) AS numeric_percentage
    FROM benchmark_values

)
SELECT
    COUNT(*)                                     AS populated_benchmark_records
    , COUNTIF(NOT ENDS_WITH(benchmark_ctr, '%')) AS missing_percentage_symbol
    , COUNTIF(numeric_percentage IS NULL)        AS invalid_numeric_values
    , COUNTIF(numeric_percentage < 0)            AS negative_benchmark_ctr
    , COUNTIF(numeric_percentage > 100)          AS benchmark_ctr_above_100_percent
    , MIN(numeric_percentage)                    AS min_benchmark_ctr_percent
    , MAX(numeric_percentage)                    AS max_benchmark_ctr_percent
FROM parsed_values;

/*
populated_benchmark_records	    : 8443 (33.7% Records with benchmark CTR populated)
missing_percentage_symbol	    : 0
invalid_numeric_values	        : 0
negative_benchmark_ctr	        : 0
benchmark_ctr_above_100_percent : 0
min_benchmark_ctr_percent	    : 0.02
max_benchmark_ctr_percent	    : 4.5
*/

------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.7: Campaign start and end date quality

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE COALESCE(
        NULLIF(TRIM(campaign_start), ''),
        NULLIF(TRIM(campaign_end), ''),
        NULLIF(TRIM(gender), ''),
        NULLIF(TRIM(country_cluster), ''),
        NULLIF(TRIM(reach), ''),
        NULLIF(TRIM(currency_cpm), ''),
        NULLIF(TRIM(cpm), ''),
        NULLIF(TRIM(benchmark_ctr), ''),
        NULLIF(TRIM(benchmark_clicks), ''),
        NULLIF(TRIM(campaign_name), '')
    ) IS NOT NULL
),
parsed_dates AS (
    SELECT
        campaign_start
        , campaign_end
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_start)) AS parsed_start_date
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_end))   AS parsed_end_date
    FROM nonempty_records
)
SELECT
    COUNT(*) AS total_records
    , COUNTIF(
          NULLIF(TRIM(campaign_start), '') IS NULL
          AND NULLIF(TRIM(campaign_end), '') IS NOT NULL
      )                                                     AS missing_start_only
    , COUNTIF(
          NULLIF(TRIM(campaign_start), '') IS NOT NULL
          AND NULLIF(TRIM(campaign_end), '') IS NULL
      )                                                     AS missing_end_only
    , COUNTIF(
          NULLIF(TRIM(campaign_start), '') IS NULL
          AND NULLIF(TRIM(campaign_end), '') IS NULL
      )                                                     AS missing_both_dates
    , COUNTIF(
          NULLIF(TRIM(campaign_start), '') IS NOT NULL
          AND parsed_start_date IS NULL
      )                                                     AS invalid_start_date
    , COUNTIF(
          NULLIF(TRIM(campaign_end), '') IS NOT NULL
          AND parsed_end_date IS NULL
      )                                                     AS invalid_end_date
    , COUNTIF(
          parsed_start_date > parsed_end_date
      )                                                     AS start_after_end
FROM parsed_dates;

/*
total_records	    : 25019
missing_start_only	: 219
missing_end_only	: 0
missing_both_dates	: 0
invalid_start_date	: 0
invalid_end_date	: 0
start_after_end	    : 0
*/

-- EDA 1.7.1: Missing campaign name vs missing start date

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE COALESCE(
        NULLIF(TRIM(campaign_start), ''),
        NULLIF(TRIM(campaign_end), ''),
        NULLIF(TRIM(gender), ''),
        NULLIF(TRIM(country_cluster), ''),
        NULLIF(TRIM(reach), ''),
        NULLIF(TRIM(currency_cpm), ''),
        NULLIF(TRIM(cpm), ''),
        NULLIF(TRIM(benchmark_ctr), ''),
        NULLIF(TRIM(benchmark_clicks), ''),
        NULLIF(TRIM(campaign_name), '')
    ) IS NOT NULL
)

SELECT
    COUNT(*) AS total_records
    , COUNTIF(
          NULLIF(TRIM(campaign_name), '') IS NULL
          AND NULLIF(TRIM(campaign_start), '') IS NULL
      )                                                     AS both_name_and_start_missing
    , COUNTIF(
          NULLIF(TRIM(campaign_name), '') IS NULL
          AND NULLIF(TRIM(campaign_start), '') IS NOT NULL
      )                                                     AS only_name_missing
    , COUNTIF(
          NULLIF(TRIM(campaign_name), '') IS NOT NULL
          AND NULLIF(TRIM(campaign_start), '') IS NULL
      )                                                     AS only_start_missing
FROM nonempty_records;

/*
total_records	            : 25019
both_name_and_start_missing	: 219
only_name_missing	        : 0
only_start_missing	        : 0
*/

-- EDA 1.7.2: Campaign duration and date range

WITH parsed_dates AS (
    SELECT
        SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_start)) AS campaign_start_date
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_end)) AS campaign_end_date
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_start), '') IS NOT NULL
      AND NULLIF(TRIM(campaign_end), '') IS NOT NULL
),
campaign_durations AS (
    SELECT
        campaign_start_date
        , campaign_end_date
        , DATE_DIFF(
            campaign_end_date,
            campaign_start_date,
            DAY
        ) + 1 AS campaign_duration_days
    FROM parsed_dates
)
SELECT
    COUNT(*)                                                    AS records_with_valid_dates
    , MIN(campaign_start_date)                                  AS earliest_campaign_start
    , MAX(campaign_end_date)                                    AS latest_campaign_end
    , MIN(campaign_duration_days)                               AS min_duration_days
    , MAX(campaign_duration_days)                               AS max_duration_days
    , ROUND(AVG(campaign_duration_days), 2)                     AS avg_duration_days
    , APPROX_QUANTILES(campaign_duration_days, 100)[OFFSET(50)] AS median_duration_days
    , COUNTIF(campaign_duration_days = 1)                       AS one_day_campaigns
    , COUNTIF(campaign_duration_days > 30)                      AS campaigns_over_30_days
    , COUNTIF(campaign_duration_days > 90)                      AS campaigns_over_90_days
FROM campaign_durations;

/*
records_with_valid_dates : 24800
earliest_campaign_start	 : 2022-05-11
latest_campaign_end	     : 2026-04-16
min_duration_days		 : 1
max_duration_days		 : 426
avg_duration_days		 : 9.54
median_duration_days	 : 7
one_day_campaigns		 : 99
campaigns_over_30_days	 : 1203
campaigns_over_90_days	 : 91
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.8: Numeric field completeness and validity

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE COALESCE(
        NULLIF(TRIM(campaign_start), ''),
        NULLIF(TRIM(campaign_end), ''),
        NULLIF(TRIM(gender), ''),
        NULLIF(TRIM(country_cluster), ''),
        NULLIF(TRIM(reach), ''),
        NULLIF(TRIM(currency_cpm), ''),
        NULLIF(TRIM(cpm), ''),
        NULLIF(TRIM(benchmark_ctr), ''),
        NULLIF(TRIM(benchmark_clicks), ''),
        NULLIF(TRIM(campaign_name), '')
    ) IS NOT NULL
),
numeric_profile AS (
    SELECT
        NULLIF(TRIM(reach), '')                                    AS reach_raw
        , NULLIF(TRIM(cpm), '')                                    AS cpm_raw
        , NULLIF(TRIM(benchmark_clicks), '')                       AS benchmark_clicks_raw
      
        -- Remove thousands separators before casting
        , SAFE_CAST(
              REPLACE(NULLIF(TRIM(reach), ''), ',', '')
              AS NUMERIC
          )                                                       AS reach_numeric
        , SAFE_CAST(
              NULLIF(TRIM(cpm), '')
              AS NUMERIC
          )                                                       AS cpm_numeric
        , SAFE_CAST(
              REPLACE(NULLIF(TRIM(benchmark_clicks), ''), ',', '')
              AS NUMERIC
          )                                                       AS benchmark_clicks_numeric
    FROM nonempty_records
)

SELECT
    COUNT(*)                                                    AS total_records

    -- Reach
    , COUNTIF(reach_raw IS NULL)                                AS missing_reach
    , COUNTIF(reach_raw IS NOT NULL AND reach_numeric IS NULL)  AS invalid_reach
    , COUNTIF(reach_numeric = 0)                                AS zero_reach
    , COUNTIF(reach_numeric < 0)                                AS negative_reach

    -- CPM
    , COUNTIF(cpm_raw IS NULL)                                  AS missing_cpm
    , COUNTIF(cpm_raw IS NOT NULL AND cpm_numeric IS NULL)      AS invalid_cpm
    , COUNTIF(cpm_numeric = 0)                                  AS zero_cpm
    , COUNTIF(cpm_numeric < 0)                                  AS negative_cpm

    -- Benchmark clicks
    , COUNTIF(benchmark_clicks_raw IS NULL)                     AS missing_benchmark_clicks
    , COUNTIF(
          benchmark_clicks_raw IS NOT NULL
          AND benchmark_clicks_numeric IS NULL
      )                                                         AS invalid_benchmark_clicks
    , COUNTIF(benchmark_clicks_numeric = 0)                     AS zero_benchmark_clicks
    , COUNTIF(benchmark_clicks_numeric < 0)                     AS negative_benchmark_clicks
FROM numeric_profile;


/*
missing_reach	          : 223 (0.9%)
invalid_reach	          : 0
zero_reach	              : 8039 (32.1%)
negative_reach            :	0
missing_cpm	              : 6062 (24.2%)
invalid_cpm	              : 0
zero_cpm	              : 2991 (12.0%)
negative_cpm	          : 0
missing_benchmark_clicks  : 19874 (79.4%)
invalid_benchmark_clicks  : 0
zero_benchmark_clicks	  : 1760 (7.0%)
negative_benchmark_clicks : 0
*/

-- benchmark clicks and CPM have the highest missing-value rates among these three numeric fields


------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.9: Gender and country cluster distribution

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE COALESCE(
        NULLIF(TRIM(campaign_start), ''),
        NULLIF(TRIM(campaign_end), ''),
        NULLIF(TRIM(gender), ''),
        NULLIF(TRIM(country_cluster), ''),
        NULLIF(TRIM(reach), ''),
        NULLIF(TRIM(currency_cpm), ''),
        NULLIF(TRIM(cpm), ''),
        NULLIF(TRIM(benchmark_ctr), ''),
        NULLIF(TRIM(benchmark_clicks), ''),
        NULLIF(TRIM(campaign_name), '')
    ) IS NOT NULL
),
targeting_values AS (
    SELECT
        'gender' AS field_name,
        COALESCE(NULLIF(TRIM(gender), ''), '[MISSING]') AS field_value
    FROM nonempty_records

    UNION ALL

    SELECT
        'country_cluster' AS field_name,
        COALESCE(NULLIF(TRIM(country_cluster), ''), '[MISSING]') AS field_value
    FROM nonempty_records
)
SELECT
    field_name
    , field_value
    , COUNT(*) AS record_count
FROM targeting_values
GROUP BY field_name, field_value
ORDER BY field_name, record_count DESC;

-- country_cluster	[MISSING]	4860 (19.43%)
-- gender         	[MISSING]	3128 (12.5%)


------------------------------------------------------------------------------------------------------------------------------
-- EDA 1.10: Salesforce candidate business key validation

WITH nonempty_records AS (
    SELECT *
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE COALESCE(
        NULLIF(TRIM(campaign_start), ''),
        NULLIF(TRIM(campaign_end), ''),
        NULLIF(TRIM(gender), ''),
        NULLIF(TRIM(country_cluster), ''),
        NULLIF(TRIM(reach), ''),
        NULLIF(TRIM(currency_cpm), ''),
        NULLIF(TRIM(cpm), ''),
        NULLIF(TRIM(benchmark_ctr), ''),
        NULLIF(TRIM(benchmark_clicks), ''),
        NULLIF(TRIM(campaign_name), '')
    ) IS NOT NULL
),
distinct_records AS (
    SELECT DISTINCT *
    FROM nonempty_records
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
      AND NULLIF(TRIM(campaign_start), '') IS NOT NULL
),
candidate_keys AS (
    SELECT
        LOWER(TRIM(campaign_name))                          AS campaign_name_key
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_start)) AS campaign_start_date
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_end))   AS campaign_end_date
        , LOWER(NULLIF(TRIM(gender), ''))                   AS gender_key
        , LOWER(NULLIF(TRIM(country_cluster), ''))          AS country_cluster_key
    FROM distinct_records
),
key_counts AS (
    SELECT
        campaign_name_key
        , campaign_start_date
        , campaign_end_date
        , gender_key
        , country_cluster_key
        , COUNT(*) AS records_per_key
    FROM candidate_keys
    GROUP BY 1, 2, 3, 4, 5
)
SELECT
    SUM(records_per_key) AS total_distinct_records
    , COUNT(*) AS distinct_candidate_keys
    , COUNTIF(records_per_key > 1) AS colliding_key_groups
    ,   SUM(
            IF(records_per_key > 1, records_per_key - 1, 0)
        ) AS excess_records_sharing_keys
    , MAX(records_per_key) AS max_records_per_key
FROM key_counts;

/*
total_distinct_records	    : 24761
distinct_candidate_keys	    : 24731
colliding_key_groups	    : 29     -- 29 key combinations map to multiple distinct Salesforce records
excess_records_sharing_keys : 30	
max_records_per_key	        : 3      -- largest number of distinct records sharing any single candidate key.
*/

------------------------------------------------------------------------------------------------------------------------------
/*
1. Source quality: 13,757 completely empty rows and 254 excess exact duplicates
2. Campaign identification: Campaign names are reused. Even the five-column candidate key has 29 collisions, so it cannot uniquely identify every Salesforce record
3. Benchmark CTR: 66.3% of nonempty records are missing benchmark CTR, although all populated values pass the format and range checks
4. Dates: All populated dates parse correctly; 219 records are missing both campaign name and start date
5. Numeric fields: All populated numeric values parse successfully
6. Targeting: Gender requires minor standardization; country clusters mix regions, country codes, and unexplained numeric codes
*/
------------------------------------------------------------------------------------------------------------------------------


------------------------------------------------------------------------------------------------------------------------------
-- EDA 2 -> source: teasers_cms
------------------------------------------------------------------------------------------------------------------------------

-- EDA 2.1 — Completeness

SELECT
    COUNT(*)                                             AS total_records
    , COUNTIF(
        COALESCE(
            NULLIF(TRIM(campaign_id), ''),
            NULLIF(TRIM(campaign_name), ''),
            NULLIF(TRIM(gender), ''),
            NULLIF(TRIM(active_from), ''),
            NULLIF(TRIM(active_to), '')
        ) IS NULL
      )                                                  AS completely_empty_records
    ,   COUNTIF(NULLIF(TRIM(campaign_id), '') IS NULL)   AS missing_campaign_id
    ,   COUNTIF(NULLIF(TRIM(campaign_name), '') IS NULL) AS missing_campaign_name
    ,   COUNTIF(NULLIF(TRIM(gender), '') IS NULL)        AS missing_gender
    ,   COUNTIF(NULLIF(TRIM(active_from), '') IS NULL)   AS missing_active_from
    ,   COUNTIF(NULLIF(TRIM(active_to), '') IS NULL)     AS missing_active_to
FROM `about-you-assignment.aboutyou_raw.teasers_cms`;

/*
total_records	          : 965
completely_empty_records  : 0
missing_campaign_id	      : 0
missing_campaign_name	  : 0
missing_gender	          : 0
missing_active_from	      : 0
missing_active_to	      : 409 (42.4%)
*/

-- EDA 2.1.1 — Missing Active To by Activation Year

SELECT
    EXTRACT(YEAR FROM SAFE_CAST(active_from AS TIMESTAMP)) AS activation_year
    , COUNT(*)                                             AS total_records
    , COUNTIF(NULLIF(TRIM(active_to), '') IS NULL)         AS missing_active_to
    , ROUND(
        SAFE_DIVIDE(
            COUNTIF(NULLIF(TRIM(active_to), '') IS NULL)
            , COUNT(*)
        ) * 100
        , 2
      )                                                   AS missing_active_to_pct

FROM `about-you-assignment.aboutyou_raw.teasers_cms`
GROUP BY activation_year
ORDER BY activation_year;

/*
Row	activation_year	total_records	missing_active_to	missing_active_to_pct
1	   2018	            1	            1               	100.0
2	   2019	            3	            3               	100.0
3	   2020	            38	            37              	97.37
4	   2021	            39	            39                  100.0
5	   2022	            63	            47              	74.6
6	   2023	            19	            8               	42.11
7	   2024	            182	            72              	39.56
8	   2025	            620	            202             	32.58	

-- missing active_to is especially common in older campaigns
-- 2025 has the lowest missing rate, but accounts for 202 of the 409 missing end dates
-- an old start date doesn't tell us whether a campaign is still active
-- as per the case study documentation - Required fields sometimes missing when team forgets to populate during campaign setup
-- which means a blank active_to could have two explanations:
    - the campaign remains active
    - the campaign end date was supposed to be entered but was omitted
*/

------------------------------------------------------------------------------------------------------------------------------
-- EDA 2.2 — Exact Duplicate Records

WITH duplicate_check AS (
    SELECT
        campaign_id
        , campaign_name
        , gender
        , active_from
        , active_to
        , COUNT(*)                                      AS occurrence_count
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
    GROUP BY 1, 2, 3, 4, 5

)

SELECT
    SUM(occurrence_count)                               AS total_records
    , COUNT(*)                                          AS distinct_records
    , SUM(occurrence_count - 1)                         AS excess_duplicate_records
    , COUNTIF(occurrence_count > 1)                     AS duplicate_groups
    , MAX(occurrence_count)                             AS max_records_per_group
FROM duplicate_check;

/*
total_records            : 965
distinct_records         : 965
excess_duplicate_records : 0
duplicate_groups         : 0
max_records_per_group    : 1
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 2.3 — Campaign ID Uniqueness

WITH campaign_id_check AS (
    SELECT
        campaign_id
        , COUNT(*)                                      AS records_per_campaign_id
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
    GROUP BY 1
)

SELECT
    SUM(records_per_campaign_id)                        AS total_records
    , COUNT(*)                                          AS distinct_campaign_ids
    , COUNTIF(records_per_campaign_id > 1)              AS repeated_campaign_id_groups
    , SUM(records_per_campaign_id - 1)                  AS excess_records_sharing_ids
    , MAX(records_per_campaign_id)                      AS max_records_per_campaign_id
FROM campaign_id_check;

/*
total_records                : 965
distinct_campaign_ids        : 965
repeated_campaign_id_groups  : 0
excess_records_sharing_ids   : 0
max_records_per_campaign_id  : 1
*/
------------------------------------------------------------------------------------------------------------------------------
-- EDA 2.4 — Campaign Name Reuse Across Campaign IDs

WITH campaign_name_check AS (
    SELECT
        LOWER(TRIM(campaign_name))                       AS normalized_campaign_name
        , COUNT(*)                                       AS records_per_campaign_name
        , COUNT(DISTINCT campaign_id)                    AS distinct_campaign_ids
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
    GROUP BY 1
)

SELECT
    COUNT(*)                                            AS distinct_campaign_names
    , COUNTIF(distinct_campaign_ids > 1)                AS campaign_names_with_multiple_ids
    , SUM(records_per_campaign_name - 1)                AS excess_records_sharing_names
    , MAX(distinct_campaign_ids)                        AS max_ids_per_campaign_name
FROM campaign_name_check;

/*
distinct_campaign_names          : 934
campaign_names_with_multiple_ids : 8
excess_records_sharing_names     : 31
max_ids_per_campaign_name        : 5

-- campaign_id is a suitable primary-key candidate for the CMS extract
-- campaign_name cannot serve as a unique CMS key
-- joining on campaign name alone could duplicate records because names are reused in both sources

*/
------------------------------------------------------------------------------------------------------------------------------
-- EDA 2.4.1 — Inspect Campaign Names Associated with Multiple IDs

WITH repeated_campaign_names AS (
    SELECT
        LOWER(TRIM(campaign_name))                       AS normalized_campaign_name
        , COUNT(DISTINCT campaign_id)                    AS distinct_campaign_ids
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
    GROUP BY 1
    HAVING COUNT(DISTINCT campaign_id) > 1
)
SELECT
    cms.campaign_id
    , cms.campaign_name
    , cms.gender
    , cms.active_from
    , cms.active_to
FROM `about-you-assignment.aboutyou_raw.teasers_cms` AS cms
INNER JOIN repeated_campaign_names AS repeated
    ON LOWER(TRIM(cms.campaign_name)) = repeated.normalized_campaign_name
ORDER BY
    LOWER(TRIM(cms.campaign_name))
    , campaign_id
    , cms.active_from
    , cms.campaign_id;

/*
- combination of campaign_name + gender would not uniquely identify CMS campaigns
-- activation periods overlap (e.g.000121 & 000321)
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 2.5 — Activation Date Validity

WITH parsed_dates AS (
    SELECT
        campaign_id
        , NULLIF(TRIM(active_from), '')                  AS active_from_raw
        , NULLIF(TRIM(active_to), '')                    AS active_to_raw
        , SAFE_CAST(NULLIF(TRIM(active_from), '') AS TIMESTAMP)
                                                         AS active_from_ts
        , SAFE_CAST(NULLIF(TRIM(active_to), '') AS TIMESTAMP)
                                                         AS active_to_ts
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
)
SELECT
    COUNT(*)                                             AS total_records
    , COUNTIF(active_from_raw IS NULL)                   AS missing_active_from
    , COUNTIF(active_to_raw IS NULL)                     AS missing_active_to
    , COUNTIF(
        active_from_raw IS NOT NULL
        AND active_from_ts IS NULL
      )                                                  AS invalid_active_from
    , COUNTIF(
        active_to_raw IS NOT NULL
        AND active_to_ts IS NULL
      )                                                  AS invalid_active_to
    , COUNTIF(active_to_ts < active_from_ts)             AS end_before_start
    , COUNTIF(active_to_ts = active_from_ts)             AS zero_duration

FROM parsed_dates;

/*
total_records       : 965
missing_active_from : 0
missing_active_to   : 409
invalid_active_from : 0
invalid_active_to   : 0
end_before_start    : 0
zero_duration       : 0

-- both date fields parse correctly and can be converted to timestamps in staging
-- source timestamps don't include explicit timezone offsets 
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 2.6 — Gender Distribution

SELECT
    COALESCE(NULLIF(TRIM(gender), ''), '[MISSING]')   AS gender
    , COUNT(*)                                        AS total_records
    , ROUND(
        SAFE_DIVIDE(COUNT(*), SUM(COUNT(*)) OVER ()) * 100
        , 2
      )                                               AS percentage_of_records
FROM `about-you-assignment.aboutyou_raw.teasers_cms`
GROUP BY 1
ORDER BY total_records DESC;

/*
gender	total_records	percentage_of_records
female	    519	                53.78
male	    271	            	28.08
unisex	    115	            	11.92
girls	    29	            	3.01
boys	    22	            	2.28
kids	    7	            	0.73
babies	    2	            	0.21	

-- no missing gender values
-- gender categories are already consistently lowercase
*/

------------------------------------------------------------------------------------------------------------------------------
/*
1. Primary key: Use campaign_id as the CMS primary-key candidate
2. Joining: Do not rely on campaign_name alone, or even campaign_name + gender + active dates, to uniquely identify campaigns
3. Missing active_to: Preserve as NULL. It may represent ongoing campaigns or incomplete setup information
4. Staging transformations: Convert activation fields to timestamps, normalize text fields, and confirm timezone assumptions
*/
------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------
-- EDA 3 -> source: tracking_events
-- In tracking_events, one row represents one recorded interaction (impression or click), not one session or one visitor
------------------------------------------------------------------------------------------------------------------------------

-- EDA 3.1 — Completeness

SELECT
    COUNT(*)                                              AS total_records
    , COUNTIF(
        COALESCE(
            NULLIF(TRIM(session_id), ''),
            NULLIF(TRIM(visitor_id), ''),
            NULLIF(TRIM(device), ''),
            NULLIF(TRIM(event_timestamp), ''),
            NULLIF(TRIM(event_type), ''),
            NULLIF(TRIM(campaign_id), ''),
            NULLIF(TRIM(campaign_name), ''),
            NULLIF(TRIM(campaign_type), '')
        ) IS NULL
      )                                                   AS completely_empty_records
    , COUNTIF(NULLIF(TRIM(session_id), '') IS NULL)       AS missing_session_id
    , COUNTIF(NULLIF(TRIM(visitor_id), '') IS NULL)       AS missing_visitor_id
    , COUNTIF(NULLIF(TRIM(device), '') IS NULL)           AS missing_device
    , COUNTIF(NULLIF(TRIM(event_timestamp), '') IS NULL)  AS missing_event_timestamp
    , COUNTIF(NULLIF(TRIM(event_type), '') IS NULL)       AS missing_event_type
    , COUNTIF(NULLIF(TRIM(campaign_id), '') IS NULL)      AS missing_campaign_id
    , COUNTIF(NULLIF(TRIM(campaign_name), '') IS NULL)    AS missing_campaign_name
    , COUNTIF(NULLIF(TRIM(campaign_type), '') IS NULL)    AS missing_campaign_type
FROM `about-you-assignment.aboutyou_raw.tracking_events`;

/*
total_records           : 308585
completely_empty_records: 0
missing_session_id      : 0
missing_visitor_id      : 0
missing_device          : 0
missing_event_timestamp : 0
missing_event_type      : 0
missing_campaign_id     : 69731 (22.6 %)
missing_campaign_name   : 0
missing_campaign_type   : 0
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 3.2 — Event Type Distribution

SELECT
    LOWER(TRIM(event_type))                             AS event_type
    , COUNT(*)                                          AS total_records
    , COUNTIF(NULLIF(TRIM(campaign_id), '') IS NULL)    AS missing_campaign_id
    , ROUND(
        SAFE_DIVIDE(
            COUNTIF(NULLIF(TRIM(campaign_id), '') IS NULL)
            , COUNT(*)
        ) * 100
        , 2
      )                                                 AS missing_campaign_id_pct

FROM `about-you-assignment.aboutyou_raw.tracking_events`

GROUP BY 1
ORDER BY total_records DESC;

/*
event_type	total_records	missing_campaign_id	 missing_campaign_id_pct
impression	    300093	        67929	               22.64
click	        8492	        1802	               21.22	

-- Total Events : 308585
-- Impressions  : 300093 (97.25%)
-- Clicks       : 8492 (2.75%)
*/

------------------------------------------------------------------------------------------------------------------------------
-- EDA 3.3 — Exact Duplicate Event Records

WITH duplicate_check AS (
    SELECT
        session_id
        , visitor_id
        , device
        , event_timestamp
        , event_type
        , campaign_id
        , campaign_name
        , campaign_type
        , COUNT(*)                                      AS occurrence_count
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    GROUP BY 1, 2, 3, 4, 5, 6, 7, 8
)

SELECT
    SUM(occurrence_count)                               AS total_records
    , COUNT(*)                                          AS distinct_records
    , SUM(occurrence_count - 1)                         AS excess_identical_records
    , COUNTIF(occurrence_count > 1)                     AS repeated_record_groups
    , MAX(occurrence_count)                             AS max_records_per_group
FROM duplicate_check;

/*
SELECT *
FROM duplicate_check
WHERE TRUE
    AND occurrence_count > 1
ORDER BY 1, 2, 3, 4, 5, 6, 7, 8
*/

/*
total_records            : 308585
distinct_records         : 308576
excess_identical_records : 9
repeated_record_groups   : 9
max_records_per_group    : 2

-- the 9 identical rows could be repeated events or ingestion duplicates
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 3.4 — Event Timestamp Validity and Date Coverage

WITH parsed_events AS (
    SELECT
        NULLIF(TRIM(event_timestamp), '')               AS event_timestamp_raw
        , SAFE_CAST(
            NULLIF(TRIM(event_timestamp), '')
            AS TIMESTAMP
          )                                             AS event_timestamp_ts
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
)
SELECT
    COUNT(*)                                            AS total_records
    , COUNTIF(event_timestamp_raw IS NULL)              AS missing_event_timestamp
    , COUNTIF(
        event_timestamp_raw IS NOT NULL
        AND event_timestamp_ts IS NULL
      )                                                 AS invalid_event_timestamp
    , MIN(event_timestamp_ts)                           AS earliest_event_timestamp
    , MAX(event_timestamp_ts)                           AS latest_event_timestamp
    , COUNT(DISTINCT DATE(event_timestamp_ts))          AS distinct_event_dates
FROM parsed_events;

/*
total_records            : 308585
missing_event_timestamp  : 0
invalid_event_timestamp  : 0
earliest_event_timestamp : 2025-06-07 00:00:00 UTC
latest_event_timestamp   : 2025-06-08 23:59:59 UTC
distinct_event_dates     : 2

-- the dataset covers only two days, so performance outside June 7–8, 2025 cannot be evaluated
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 3.5 — Campaign ID Consistency Across Names and Types

WITH campaign_id_check AS (
    SELECT
        TRIM(campaign_id)                                 AS campaign_id
        , COUNT(*)                                        AS total_events
        , COUNT(DISTINCT LOWER(TRIM(campaign_name)))      AS distinct_campaign_names
        , COUNT(DISTINCT LOWER(TRIM(campaign_type)))      AS distinct_campaign_types
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE NULLIF(TRIM(campaign_id), '') IS NOT NULL
    GROUP BY 1
)

SELECT
    COUNT(*)                                             AS distinct_campaign_ids
    , SUM(total_events)                                  AS events_with_campaign_id
    , COUNTIF(distinct_campaign_names > 1)               AS ids_with_multiple_names
    , COUNTIF(distinct_campaign_types > 1)               AS ids_with_multiple_types
    , MAX(distinct_campaign_names)                       AS max_names_per_id
    , MAX(distinct_campaign_types)                       AS max_types_per_id
FROM campaign_id_check;

/*
distinct_campaign_ids    : 963
events_with_campaign_id  : 238854 (238854/308585 = 77.4%)
ids_with_multiple_names  : 0
ids_with_multiple_types  : 0
max_names_per_id         : 1 -- No name inconsistencies within tracking
max_types_per_id         : 1 -- No type inconsistencies within tracking

Count reconciliation ->
- total events (impressions+clicks)             : 300093+8492 = 308585
- missing campaign IDs (for impressions+clicks) : 67929+1802 = 69731 (69731/308585 = 22.6%)

- events_with_campaign_id -> Total Events - missing_ids : 308585-69731=238854

-- no campaign ID maps to multiple names or types within tracking
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 3.6 — Device Distribution and Consistency

SELECT
    LOWER(TRIM(device))                                   AS device
    , COUNT(*)                                            AS total_events
    , COUNTIF(LOWER(TRIM(event_type)) = 'impression')     AS impressions
    , COUNTIF(LOWER(TRIM(event_type)) = 'click')          AS clicks
    , ROUND(
        SAFE_DIVIDE(
            COUNTIF(LOWER(TRIM(event_type)) = 'click')
            , COUNTIF(LOWER(TRIM(event_type)) = 'impression')
        ) * 100
        , 2
      )                                                 AS ctr_pct
FROM `about-you-assignment.aboutyou_raw.tracking_events`
GROUP BY 1
ORDER BY total_events DESC;

/*
device	total_events	impressions	clicks	ctr_pct
mobile	  209948	        204302	 5646	 2.76
desktop	  98637	            95791	 2846	 2.97	

Events      : 209948+98637 = 308585
Impressions : 204302+95791 = 300093
Clicks      : 5646+2846    = 8492
CTR : 8492/ 300093 = 2.83%

*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 3.7 — Session and Visitor Identifier Quality

WITH session_check AS (
    SELECT
        TRIM(session_id)                                  AS session_id
        , COUNT(*)                                        AS total_events
        , COUNT(DISTINCT TRIM(visitor_id))                AS distinct_visitors
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    GROUP BY 1
)
, visitor_check AS (
    SELECT
        TRIM(visitor_id)                                  AS visitor_id
        , COUNT(DISTINCT TRIM(session_id))                AS distinct_sessions
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    GROUP BY 1
)

SELECT
    (SELECT COUNT(*) FROM session_check)                 AS distinct_sessions
    , (SELECT COUNT(*) FROM visitor_check)               AS distinct_visitors
    , (SELECT COUNTIF(distinct_visitors > 1)
       FROM session_check)                               AS sessions_with_multiple_visitors
    , (SELECT MAX(distinct_visitors)
       FROM session_check)                               AS max_visitors_per_session
    , (SELECT ROUND(AVG(distinct_sessions), 2)
       FROM visitor_check)                               AS avg_sessions_per_visitor
    , (SELECT MAX(distinct_sessions)
       FROM visitor_check)                               AS max_sessions_per_visitor;

/*
distinct_sessions              : 29665
distinct_visitors              : 16234
sessions_with_multiple_visitors: 0
max_visitors_per_session       : 1
avg_sessions_per_visitor       : 1.83
max_sessions_per_visitor       : 4


-- every session maps to one visitor
-- one visitor can have multiple sessions, and one session can contain multiple events

Therefore, we have:
- 308,585 events
- 29,665 sessions
- 16,234 visitors
many events share the same session and visitor identifiers
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 3.8 — Campaign Type Distribution and Missing Campaign IDs

SELECT
    LOWER(TRIM(campaign_type))                            AS campaign_type
    , COUNT(*)                                            AS total_events
    , COUNTIF(LOWER(TRIM(event_type)) = 'impression')     AS impressions
    , COUNTIF(LOWER(TRIM(event_type)) = 'click')          AS clicks
    , COUNTIF(NULLIF(TRIM(campaign_id), '') IS NULL)      AS missing_campaign_id
    , ROUND(
        SAFE_DIVIDE(
            COUNTIF(NULLIF(TRIM(campaign_id), '') IS NULL)
            , COUNT(*)
        ) * 100
        , 2
      )                                                 AS missing_campaign_id_pct
FROM `about-you-assignment.aboutyou_raw.tracking_events`
GROUP BY 1
ORDER BY total_events DESC;

/*
campaign_type	total_events	impressions	clicks	missing_campaign_id	missing_campaign_id_pct
    teaser	        238854	        232164	 6690	          0	                    0.0
online_placement	69731	        67929	 1802	        69731	               100.0	

Events               : 238854+69731 = 308585 
Impressions          : 232164+67929 = 300093 
Clicks               : 6690+1802    = 8492
Missing Id's         : 69731
CTR teaser           : 6690/232164 = 2.88%
CTR online_placement : 1802/67929 = 2.65%

-- all teaser events have campaign IDs -> Match tracking events to CMS using campaign_id, after validating the relationship
-- all online placement events are missing campaign IDs 
*/

------------------------------------------------------------------------------------------------------------------------------
/*
1. Source quality: 308,585 events with no completely empty rows or invalid timestamps
   Only 9 excess identical records, which should not be automatically removed

2. Event types: 300,093 impressions and 8,492 clicks, resulting in an overall CTR of 2.83%

3. Campaign identification: 963 distinct populated campaign IDs, each consistently associated
   with one campaign name and type within tracking

4. Missing campaign IDs: All 238,854 teaser events have campaign IDs, while all 69,731
   online placement events lack them, hence different campaign-matching strategies are required

5. Date coverage: Tracking data covers only June 7–8, 2025 and all timestamps parse correctly

6. Device reporting: Mobile and desktop are the only device categories with CTRs of 2.76% and 2.97%

7. Event grain: 29,665 distinct sessions and 16,234 visitors, with no session-to-visitor inconsistencies

8. Modeling implications: Validate teaser IDs against CMS and investigate name/date-based
   matching for Salesforce online placements. Consider partitioning and incremental processing for production-scale GA4 data (>1 TB/day)
*/
------------------------------------------------------------------------------------------------------------------------------

------------------------------------------------------------------------------------------------------------------------------
-- EDA 4 -> Cross table analysis
------------------------------------------------------------------------------------------------------------------------------

-- EDA 4.1 — Teaser Campaign ID Coverage (tracking_events + teasers_cms)

WITH tracking_campaigns AS (
    SELECT
        TRIM(campaign_id)                                 AS campaign_id
        , COUNT(*)                                        AS total_events
        , COUNTIF(LOWER(TRIM(event_type)) = 'impression') AS impressions
        , COUNTIF(LOWER(TRIM(event_type)) = 'click')      AS clicks
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'teaser'
      AND NULLIF(TRIM(campaign_id), '') IS NOT NULL
    GROUP BY 1
)
, cms_campaigns AS (
    SELECT DISTINCT
        TRIM(campaign_id) AS campaign_id
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
    WHERE NULLIF(TRIM(campaign_id), '') IS NOT NULL
)
, campaign_matches AS (
    SELECT
        t.campaign_id
        , t.total_events
        , t.impressions
        , t.clicks
        , c.campaign_id IS NOT NULL AS is_matched
    FROM tracking_campaigns AS t
    LEFT JOIN cms_campaigns AS c
        ON t.campaign_id = c.campaign_id
)
SELECT
    COUNT(*)                                                AS tracking_campaign_ids
    , COUNTIF(is_matched)                                   AS matched_campaign_ids
    , COUNTIF(NOT is_matched)                               AS unmatched_campaign_ids
    , ROUND(
          SAFE_DIVIDE(COUNTIF(is_matched), COUNT(*)) * 100
        , 2
      )                                                      AS campaign_match_pct

    , SUM(total_events)                                      AS total_teaser_events
    , SUM(IF(is_matched, total_events, 0))                   AS matched_events
    , SUM(IF(NOT is_matched, total_events, 0))               AS unmatched_events
    , SUM(IF(NOT is_matched, impressions, 0))                AS unmatched_impressions
    , SUM(IF(NOT is_matched, clicks, 0))                     AS unmatched_clicks

    , (
        SELECT COUNT(*)
        FROM cms_campaigns AS c
        LEFT JOIN tracking_campaigns AS t
            ON c.campaign_id = t.campaign_id
        WHERE t.campaign_id IS NULL
      )                                                     AS cms_ids_without_tracking
FROM campaign_matches;

/*
tracking_campaign_ids   : 963
matched_campaign_ids    : 963 
unmatched_campaign_ids  : 0	
campaign_match_pct	    : 100.0
total_teaser_events	    : 238854
matched_events	        : 238854	
unmatched_events	    : 0
unmatched_impressions   : 0
unmatched_clicks	    : 0
cms_ids_without_tracking: 2	

*/

-- EDA 4.1.1 — Teaser Campaign Name Consistency (tracking_events + teasers_cms)

WITH tracking_campaigns AS (
    SELECT
        TRIM(campaign_id)                   AS campaign_id
        , LOWER(TRIM(campaign_name))        AS tracking_campaign_name
        , COUNT(*)                          AS total_events
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'teaser'
      AND NULLIF(TRIM(campaign_id), '') IS NOT NULL
    GROUP BY 1, 2
)
, cms_campaigns AS (
    SELECT
        TRIM(campaign_id)                   AS campaign_id
        , LOWER(TRIM(campaign_name))        AS cms_campaign_name
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
)
SELECT
    COUNT(*)                                                AS matched_campaign_ids
    , COUNTIF(
          t.tracking_campaign_name = c.cms_campaign_name
      )                                                     AS matching_campaign_names
    , COUNTIF(
          t.tracking_campaign_name != c.cms_campaign_name
      )                                                     AS mismatched_campaign_names
    , SUM(t.total_events)                                   AS total_teaser_events
    , SUM(
          IF(t.tracking_campaign_name != c.cms_campaign_name, t.total_events, 0)
      )                                                     AS events_with_name_mismatch
FROM tracking_campaigns AS t
INNER JOIN cms_campaigns AS c
    ON t.campaign_id = c.campaign_id;

/*
matched_campaign_ids	 : 963
matching_campaign_names	 : 963 
mismatched_campaign_names: 0
total_teaser_events	     : 238854
events_with_name_mismatch: 0
*/

-- EDA 4.1.2 — Teaser Event Activation Period Validation (tracking_events + teasers_cms)

WITH teaser_events AS (
    SELECT
        TRIM(campaign_id)                          AS campaign_id
        , SAFE_CAST(event_timestamp AS TIMESTAMP)  AS event_timestamp
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'teaser'
)
, cms_campaigns AS (
    SELECT
        TRIM(campaign_id)                          AS campaign_id
        , SAFE_CAST(active_from AS TIMESTAMP)      AS active_from
        , SAFE_CAST(active_to AS TIMESTAMP)        AS active_to
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
)

SELECT
    COUNT(*)                                                    AS total_teaser_events
    , COUNTIF(t.event_timestamp < c.active_from)                AS events_before_activation
    , COUNTIF(
          c.active_to IS NOT NULL
          AND t.event_timestamp > c.active_to
      )                                                         AS events_after_deactivation
    , COUNTIF(c.active_to IS NULL)                              AS events_with_missing_active_to
    , COUNTIF(
          t.event_timestamp >= c.active_from
          AND t.event_timestamp <= c.active_to
      )                                                         AS events_within_known_activation_period
    , COUNTIF(
          c.active_to IS NULL
          AND t.event_timestamp >= c.active_from
      )                                                         AS events_after_start_without_end_date
FROM teaser_events AS t
INNER JOIN cms_campaigns AS c
    ON t.campaign_id = c.campaign_id;

/*
total_teaser_events	                 : 238854
events_before_activation             : 2501 (1.05%)
events_after_deactivation            : 0
events_with_missing_active_to        : 101190
events_within_known_activation_period: 136296
events_after_start_without_end_date  : 100057


136296+100057+2,501 = 238854
101190-100057 = 1133 -- 1133 events occurred before activation and have a missing end date
2501-1133 = 1368 -- occurred before activation despite having a populated end date

*/

-- EDA 4.1.3 — Events Before Activation (tracking_events + teasers_cms)

WITH teaser_events AS (
    SELECT
        TRIM(campaign_id)                          AS campaign_id
        , SAFE_CAST(event_timestamp AS TIMESTAMP)  AS event_timestamp
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'teaser'
)
, cms_campaigns AS (
    SELECT
        TRIM(campaign_id)                          AS campaign_id
        , SAFE_CAST(active_from AS TIMESTAMP)      AS active_from
    FROM `about-you-assignment.aboutyou_raw.teasers_cms`
)
, early_events AS (
    SELECT
        t.campaign_id
        , TIMESTAMP_DIFF(
              c.active_from
              , t.event_timestamp
              , MINUTE
          ) AS minutes_before_activation
    FROM teaser_events AS t
    INNER JOIN cms_campaigns AS c
        ON t.campaign_id = c.campaign_id
    WHERE t.event_timestamp < c.active_from
)
SELECT
    CASE
        WHEN minutes_before_activation <= 60 THEN '01. Within 1 hour'
        WHEN minutes_before_activation <= 1440 THEN '02. Within 24 hours'
        WHEN minutes_before_activation <= 10080 THEN '03. Within 7 days'
        ELSE '04. More than 7 days'
    END                                                 AS time_difference_bucket
    , COUNT(*)                                          AS total_events
    , COUNT(DISTINCT campaign_id)                       AS affected_campaigns
FROM early_events
GROUP BY 1
ORDER BY 1;

/*
time_difference_bucket	total_events	affected_campaigns
01. Within 1 hour	          77	            7
02. Within 24 hours	          702	            11
03. Within 7 days	          1722	            9

-- 77+702+1722=2501
-- 7+11+9 = 27 affected campaigns 
*/


------------------------------------------------------------------------------------------------------------------------------
-- EDA 4.2.1 — Online/ Onsite Placement Campaign Name Match Coverage (tracking_events + online_placements_salesforce)

WITH placement_events AS (
    SELECT
        LOWER(TRIM(campaign_name))                        AS campaign_name
        , COUNT(*)                                        AS total_events
        , COUNTIF(LOWER(TRIM(event_type)) = 'impression') AS impressions
        , COUNTIF(LOWER(TRIM(event_type)) = 'click')      AS clicks
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'online_placement'
    GROUP BY 1
)
, salesforce_campaign_names AS (
    SELECT DISTINCT
        LOWER(TRIM(campaign_name)) AS campaign_name
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
)
SELECT
    COUNT(*)                                                  AS tracking_campaign_names
    , COUNTIF(s.campaign_name IS NOT NULL)                    AS matched_campaign_names
    , COUNTIF(s.campaign_name IS NULL)                        AS unmatched_campaign_names
    , SUM(p.total_events)                                     AS total_placement_events
    , SUM(IF(s.campaign_name IS NOT NULL, p.total_events, 0)) AS matched_events
    , SUM(IF(s.campaign_name IS NULL, p.total_events, 0))     AS unmatched_events
    , SUM(IF(s.campaign_name IS NULL, p.impressions, 0))      AS unmatched_impressions
    , SUM(IF(s.campaign_name IS NULL, p.clicks, 0))           AS unmatched_clicks
    , ROUND(
          100 * SAFE_DIVIDE(
              SUM(IF(s.campaign_name IS NOT NULL, p.total_events, 0))
              , SUM(p.total_events)
          )
          , 2
      ) AS event_match_pct
FROM placement_events AS p
LEFT JOIN salesforce_campaign_names AS s
    ON p.campaign_name = s.campaign_name;

/*
results:
tracking_campaign_names	 : 279
matched_campaign_names	 : 279
unmatched_campaign_names : 0
total_placement_events	 : 69731
matched_events	         : 69731
unmatched_events	     : 0
unmatched_impressions	 : 0
unmatched_clicks	     : 0
event_match_pct          : 100.0
*/

-- EDA 4.2.2 — Multiple Salesforce Name Matches


WITH placement_events AS (
    SELECT
        LOWER(TRIM(campaign_name))                     AS campaign_name
        , COUNT(*)                                     AS total_events
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'online_placement'
    GROUP BY 1
)
, salesforce_campaigns AS (
    SELECT
        LOWER(TRIM(campaign_name))                     AS campaign_name
        , TRIM(campaign_start)                         AS campaign_start
        , TRIM(campaign_end)                           AS campaign_end
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
)
, salesforce_name_counts AS (
    SELECT
        campaign_name
        , COUNT(*)                                     AS salesforce_rows
        , COUNT(DISTINCT TO_JSON_STRING(
              STRUCT(campaign_start, campaign_end)
          ))                                           AS distinct_date_windows
    FROM salesforce_campaigns
    GROUP BY 1
)
SELECT
    COUNT(*)                                           AS tracking_campaign_names
    , COUNTIF(s.salesforce_rows = 1)                   AS names_with_one_salesforce_row
    , COUNTIF(s.salesforce_rows > 1)                   AS names_with_multiple_salesforce_rows
    , COUNTIF(s.distinct_date_windows > 1)             AS names_with_multiple_date_windows
    , SUM(
          IF(s.salesforce_rows > 1, p.total_events, 0)
      )                                                AS events_with_multiple_salesforce_rows
    , SUM(
          IF(s.distinct_date_windows > 1, p.total_events, 0)
      )                                                AS events_with_multiple_date_windows
    , MAX(s.salesforce_rows)                           AS max_salesforce_rows_per_name
FROM placement_events AS p
LEFT JOIN salesforce_name_counts AS s
    ON p.campaign_name = s.campaign_name;

/*
tracking_campaign_names	            :279
names_with_one_salesforce_row       :161
names_with_multiple_salesforce_rows	:118
names_with_multiple_date_windows    :118
events_with_multiple_salesforce_rows:30005
events_with_multiple_date_windows	:30005
max_salesforce_rows_per_name        :160
						
-- single Salesforce row : 69731-30005 = 39,726 (57.0%)
-- multiple Salesforce row : 30,005 (43.0%)
*/

-- EDA 4.2.3 —  Multiple Campaign Matches by Name and Date

WITH placement_events AS (
    SELECT
        LOWER(TRIM(campaign_name))                    AS campaign_name
        , DATE(SAFE_CAST(event_timestamp AS TIMESTAMP)) AS event_date
        , COUNT(*)                                    AS total_events
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'online_placement'
    GROUP BY 1, 2
)
, salesforce_campaigns AS (
    SELECT
        LOWER(TRIM(campaign_name))                    AS campaign_name
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_start)) AS campaign_start
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_end))   AS campaign_end
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
)
, event_date_matches AS (
    SELECT
        p.campaign_name
        , p.event_date
        , p.total_events
        , COUNT(s.campaign_name)                      AS matching_salesforce_rows
    FROM placement_events AS p
    LEFT JOIN salesforce_campaigns AS s
        ON p.campaign_name = s.campaign_name
        AND p.event_date >= s.campaign_start
        AND p.event_date <= s.campaign_end
    GROUP BY 1, 2, 3
)
SELECT
    SUM(total_events) AS total_placement_events
    , SUM(IF(matching_salesforce_rows = 0, total_events, 0)) AS events_with_no_date_match
    , SUM(IF(matching_salesforce_rows = 1, total_events, 0)) AS events_with_one_date_match
    , SUM(IF(matching_salesforce_rows > 1, total_events, 0)) AS events_with_multiple_date_matches
    , MAX(matching_salesforce_rows) AS max_salesforce_matches_per_name_date
    , ROUND(
          100 * SAFE_DIVIDE(
              SUM(IF(matching_salesforce_rows = 1, total_events, 0))
              , SUM(total_events)
          )
          , 2
      ) AS unique_date_match_pct
FROM event_date_matches;

/*
total_placement_events	            :69731
events_with_no_date_match           :3387  (4.86%)
events_with_one_date_match          :63524 (91.10%)
events_with_multiple_date_matches   :2820  (4.04%)
max_salesforce_matches_per_name_date:4
unique_date_match_pct               :91.1
*/



-- EDA 4.2.4 — Investigating Events Without a Salesforce Date Match

WITH placement_events AS (
    SELECT
        LOWER(TRIM(campaign_name))                        AS campaign_name
        , DATE(SAFE_CAST(event_timestamp AS TIMESTAMP))   AS event_date
        , COUNT(*)                                        AS total_events
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'online_placement'
    GROUP BY 1, 2
)
, salesforce_campaigns AS (
    SELECT
        LOWER(TRIM(campaign_name))                        AS campaign_name
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_start)) AS campaign_start
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_end))   AS campaign_end
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
)
, match_analysis AS (
    SELECT
        p.campaign_name
        , p.event_date
        , p.total_events
        , COUNTIF(
              p.event_date BETWEEN s.campaign_start AND s.campaign_end
          )                                               AS valid_date_matches
        , MIN(s.campaign_start)                           AS earliest_campaign_start
        , MAX(s.campaign_end)                             AS latest_campaign_end
        , COUNTIF(s.campaign_start IS NULL)               AS missing_start_rows
        , COUNTIF(s.campaign_end IS NULL)                 AS missing_end_rows
    FROM placement_events AS p
    LEFT JOIN salesforce_campaigns AS s
        ON p.campaign_name = s.campaign_name
    GROUP BY 1, 2, 3
)
, unmatched_events AS (
    SELECT
        total_events
        , CASE
            WHEN event_date < earliest_campaign_start
                THEN '01. Before earliest campaign start'
            WHEN event_date > latest_campaign_end
                THEN '02. After latest campaign end'
            WHEN missing_start_rows > 0 OR missing_end_rows > 0
                THEN '03. Missing/invalid Salesforce dates'
            ELSE '04. Between campaign windows / other'
          END AS unmatched_reason
    FROM match_analysis
    WHERE valid_date_matches = 0
)
SELECT
    unmatched_reason
    , SUM(total_events) AS total_events
FROM unmatched_events
GROUP BY 1
ORDER BY 1;

/*
unmatched_reason	                total_events
02. After latest campaign end	        3223         -- campaign continued delivering after its configured end date
04. Between campaign windows / other	164	         
*/

-- EDA 4.2.6 — Investigate the 2,820 (mulitple date match events)

WITH placement_events AS (
    SELECT
        LOWER(TRIM(campaign_name))                       AS campaign_name
        , DATE(SAFE_CAST(event_timestamp AS TIMESTAMP))  AS event_date
        , COUNT(*)                                       AS total_events
    FROM `about-you-assignment.aboutyou_raw.tracking_events`
    WHERE LOWER(TRIM(campaign_type)) = 'online_placement'
    GROUP BY 1, 2
)
, salesforce_campaigns AS (
    SELECT
        LOWER(TRIM(campaign_name))                       AS campaign_name
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_start)) AS campaign_start
        , SAFE.PARSE_DATE('%d.%m.%Y', TRIM(campaign_end)) AS campaign_end
        , LOWER(TRIM(gender))                            AS gender
        , LOWER(TRIM(country_cluster))                   AS country_cluster
    FROM `about-you-assignment.aboutyou_raw.online_placements_salesforce`
    WHERE NULLIF(TRIM(campaign_name), '') IS NOT NULL
)
, match_analysis AS (
    SELECT
        p.campaign_name
        , p.event_date
        , p.total_events
        , COUNT(s.campaign_name) AS matching_salesforce_rows
        , COUNT(DISTINCT IF(
              s.campaign_name IS NOT NULL
              , TO_JSON_STRING(
                    STRUCT(
                        s.campaign_start
                        , s.campaign_end
                        , s.gender
                        , s.country_cluster
                    )
                )
              , NULL
          )) AS distinct_configurations
    FROM placement_events AS p
    LEFT JOIN salesforce_campaigns AS s
        ON p.campaign_name = s.campaign_name
        AND p.event_date BETWEEN s.campaign_start AND s.campaign_end
    GROUP BY 1, 2, 3
)
SELECT
    SUM(total_events) AS ambiguous_events
    , SUM(
          IF(distinct_configurations = 1, total_events, 0)
      ) AS events_with_duplicate_configurations
    , SUM(
          IF(distinct_configurations > 1, total_events, 0)
      ) AS events_with_distinct_configurations
    , MAX(distinct_configurations) AS max_distinct_configurations
    , MAX(matching_salesforce_rows) AS max_matching_salesforce_rows
FROM match_analysis
WHERE matching_salesforce_rows > 1;

/*
ambiguous_events	                : 2820
events_with_duplicate_configurations: 0	
events_with_distinct_configurations	: 2820
max_distinct_configurations	        : 4
max_matching_salesforce_rows        : 4
*/
------------------------------------------------------------------------------------------------------------------------------

/*
EDA 4 — Cross-Table Analysis: Key Findings

1. All 963 teaser campaign IDs from tracking matched CMS (100%). Campaign names were also consistent across both tables.

2. 2,501 teaser events (1.05%) occurred before their campaign activation date. No events occurred after a populated end date.

3. 101,190 teaser events belong to campaigns with missing end dates. These events will be retained and flagged where appropriate.

4. All 279 online-placement campaign names matched Salesforce,covering all 69731 placement events (100% name coverage).

5. 118 campaign names matched multiple Salesforce rows, affecting 30005 events (43%). Joining on campaign name alone is unsafe.

6. Adding campaign date conditions resulted in:
   - 63,524 events (91.10%) with one Salesforce match.
   - 3,387 events (4.86%) with no date match.
   - 2,820 events (4.04%) with multiple date matches.

7. Of the 3,387 unmatched events, 3,223 occurred after the latest populated Salesforce campaign end date. None had a possible open-ended date match.

8. All 2,820 ambiguous events matched multiple distinct Salesforce configurations. These cannot be reliably attributed to one row.

9. Benchmark CTR was available through a unique Salesforce match for 35,199 placement events (50.48%). The remaining events had missing or unreliable benchmark data.

10. - Preserve all tracking events for impressions and CTR.
    - Enrich only where Salesforce matching is unambiguous.
    - Keep unavailable benchmarks and campaign attributes as NULL.
    - Monitor unmatched events, ambiguous matches, and missing data.

11. Of the 2,820 events with multiple Salesforce date matches:
      - 1,870 events matched records with conflicting benchmark CTR values.
      - 950 events matched records with one distinct populated benchmark CTR, but incomplete benchmark coverage.
      - None could be assigned a benchmark CTR with full confidence.
      - These events will be retained for impression and click reporting, but Salesforce attributes and benchmark CTR will remain NULL until a reliable matching rule is established.
*/

