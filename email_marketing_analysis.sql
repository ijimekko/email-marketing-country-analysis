WITH

-- extracting source data with union

 L1 AS (
   SELECT
     date,
     country,
     send_interval,
     is_verified,
     is_unsubscribed,
     COUNT(DISTINCT acc.id) acc_cnt,
     0 AS sent_cnt,
     0 AS open_cnt,
     0 AS visit_cnt
   FROM `DA.account` acc
   JOIN `DA.account_session` acs
     ON acc.id = acs.account_id
   JOIN `DA.session` ses
     ON acs.ga_session_id = ses.ga_session_id
   JOIN `DA.session_params` sp
     ON acs.ga_session_id = sp.ga_session_id
   GROUP BY date, country, send_interval, is_verified, is_unsubscribed

   UNION ALL

   SELECT
     date_add(ses.date, INTERVAL sent_date day),
     country,
     send_interval,
     is_verified,
     is_unsubscribed,
     0,
     COUNT(DISTINCT es.id_message),
     COUNT(DISTINCT eo.id_message),
     COUNT(ev.id_message)
   FROM `DA.email_sent` es
   LEFT JOIN `DA.email_open` eo
     ON es.id_message = eo.id_message
   LEFT JOIN `DA.email_visit` ev
     ON es.id_message = ev.id_message
   JOIN `DA.account_session` acs
     ON es.id_account = acs.account_id
   JOIN `DA.session` ses
     ON acs.ga_session_id = ses.ga_session_id
   JOIN `DA.account` acc
     ON es.id_account = acc.id
   JOIN `DA.session_params` sp
     ON acs.ga_session_id = sp.ga_session_id
   GROUP BY 1, country, send_interval, is_verified, is_unsubscribed
 ),

 -- calculating aggregated values by the overall grouping and collapsing zero values

 L1_aggr AS (
   SELECT
     date,
     country,
     send_interval,
     is_verified,
     is_unsubscribed,
     sum(acc_cnt) account_cnt,
     sum(sent_cnt) sent_msg,
     sum(open_cnt) open_msg,
     sum(visit_cnt) visit_msg
   FROM L1
   GROUP BY date, country, send_interval, is_verified, is_unsubscribed
 ),

 -- calculating aggregated values by country

 L2 AS (
   SELECT
     *,
     sum(account_cnt) OVER (PARTITION BY country) total_country_account_cnt,
     sum(sent_msg) OVER (PARTITION BY country) total_country_sent_cnt
   FROM L1_aggr
 ),

 -- ranking

 L3 AS (
   SELECT
     *,
     rank()
       OVER (PARTITION BY country ORDER BY total_country_account_cnt DESC)
         rank_total_country_account_cnt,
     rank()
       OVER (PARTITION BY country ORDER BY total_country_sent_cnt DESC) rank_total_country_sent_cnt
   FROM L2
 )

 -- final query

SELECT *
FROM L3
WHERE
 rank_total_country_account_cnt <= 10
 OR rank_total_country_sent_cnt <= 10;
