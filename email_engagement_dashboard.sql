-- Viz - SQL Advanced Module Task - Mentor Reviewed


-- SQL for Looker Studio visualization
-- Raw-level data with country-level ranks only

CREATE OR REPLACE VIEW `data-analytics-mate.Students.v_hrushko_country_metrics_viz_mentor-rev_view` AS (

-- STEP 1: Join account with session and country info
WITH account_session_details AS (
  SELECT
    acs.account_id,
    s.date,
    sp.country,
    a.send_interval,
    a.is_verified,
    a.is_unsubscribed
  FROM `data-analytics-mate.DA.account` AS a
  JOIN `data-analytics-mate.DA.account_session` AS acs ON a.id = acs.account_id
  JOIN `data-analytics-mate.DA.session` AS s ON s.ga_session_id = acs.ga_session_id
  JOIN `data-analytics-mate.DA.session_params` AS sp ON s.ga_session_id = sp.ga_session_id
),

-- STEP 2: Email-level events
email_events AS (
  SELECT
    DATE_ADD(acs.date, INTERVAL es.sent_date DAY) AS date,
    acs.country,
    acs.send_interval,
    acs.is_verified,
    acs.is_unsubscribed,

    NULL AS account_id,
    es.id_message AS sent_id_message,
    eo.id_message AS open_id_message,
    ev.id_message AS visit_id_message,
  FROM `data-analytics-mate.DA.email_sent` AS es
  LEFT JOIN `data-analytics-mate.DA.email_open` AS eo ON es.id_message = eo.id_message
  LEFT JOIN `data-analytics-mate.DA.email_visit` AS ev ON es.id_message = ev.id_message
  JOIN account_session_details AS acs ON es.id_account = acs.account_id
),

-- STEP 3: Account-level events
account_events AS (
  SELECT
    date,
    country,
    send_interval,
    is_verified,
    is_unsubscribed,

    account_id,
    CAST(NULL AS STRING) AS sent_id_message,
    CAST(NULL AS STRING) AS open_id_message,
    CAST(NULL AS STRING) AS visit_id_message
  FROM account_session_details
),

-- STEP 4: Combine email and account events
combined_events AS (
  SELECT * FROM email_events
  UNION ALL
  SELECT * FROM account_events
),


-- STEP 5: Add country-level totals and ranks

-- STEP 5a: Calculate country-level totals
country_totals AS (
  SELECT *,
    COUNT(DISTINCT account_id) OVER (PARTITION BY country) AS total_country_account_cnt,
    COUNT(DISTINCT sent_id_message) OVER (PARTITION BY country) AS total_country_sent_cnt
  FROM combined_events
),

-- STEP 5b: Apply DENSE_RANK() on precomputed totals
country_ranked_events AS (
  SELECT *,
    DENSE_RANK() OVER (ORDER BY total_country_account_cnt DESC) AS rank_total_country_account_cnt,
    DENSE_RANK() OVER (ORDER BY total_country_sent_cnt DESC) AS rank_total_country_sent_cnt
  FROM country_totals
)


-- STEP 6: Final output for Looker Studio
SELECT
  date,
  country,
  send_interval,
  is_verified,
  is_unsubscribed,

  account_id,
  sent_id_message,
  open_id_message,
  visit_id_message,


  total_country_account_cnt,
  total_country_sent_cnt,
  rank_total_country_account_cnt,
  rank_total_country_sent_cnt
FROM country_ranked_events
WHERE rank_total_country_account_cnt <= 10 OR rank_total_country_sent_cnt <= 10
ORDER BY rank_total_country_account_cnt, date

);