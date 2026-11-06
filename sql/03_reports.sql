\set ON_ERROR_STOP on
-- 1. ROI for the entire campaign: ratio of totals, not mean daily ROI.
SELECT campaign_id,max(campaign_name) AS campaign_name,sum(revenue) AS revenue,sum(spend) AS spend,
       round((sum(revenue)-sum(spend))/nullif(sum(spend),0),6) AS roi
FROM cdm.dm_sales_performance GROUP BY campaign_id ORDER BY roi DESC NULLS LAST,campaign_id LIMIT 5;
-- 2. A campaign budget repeats by date: MAX avoids multiplying it by the number of days.
SELECT campaign_id,max(campaign_name) AS campaign_name,max(campaign_budget) AS budget,
       sum(spend) AS spend,sum(spend)-max(campaign_budget) AS budget_overrun,
       round(100*sum(spend)/nullif(max(campaign_budget),0),2) AS budget_used_pct
FROM cdm.dm_sales_performance GROUP BY campaign_id ORDER BY campaign_id;
-- 3. A new customer is attributed once, to their first completed order.
SELECT campaign_id,max(campaign_name) AS campaign_name,sum(new_customers) AS new_customers,
       sum(orders_count) AS orders_count,round(sum(spend)/nullif(sum(new_customers),0),2) AS acquisition_cost
FROM cdm.dm_sales_performance GROUP BY campaign_id ORDER BY new_customers DESC,campaign_id;
-- 4. Channel metrics. Daily distinct customers are deliberately not added together.
SELECT channel_id,max(channel_name) AS channel_name,sum(orders_count) AS orders_count,
       sum(new_customers) AS new_customers,sum(revenue) AS revenue,sum(spend) AS spend,
       round(sum(revenue)/nullif(sum(orders_count),0),2) AS avg_order_amount,
       round((sum(revenue)-sum(spend))/nullif(sum(spend),0),6) AS roi
FROM cdm.dm_sales_performance GROUP BY channel_id ORDER BY revenue DESC,channel_id;
