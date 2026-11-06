\set ON_ERROR_STOP on
BEGIN;
TRUNCATE cdm.dm_sales_performance;
INSERT INTO cdm.dm_sales_performance
WITH completed AS (
    SELECT o.*, row_number() OVER (PARTITION BY customer_id ORDER BY order_dt,order_id) AS purchase_number
    FROM dds.fact_orders o WHERE order_status='completed'
), sales AS (
    SELECT order_dt,campaign_id,count(*) AS orders_count,count(DISTINCT customer_id) AS customers_count,
           sum(order_amount) AS amount,avg(order_amount) AS avg_amount,
           count(*) FILTER (WHERE purchase_number=1) AS new_customers
    FROM completed GROUP BY order_dt,campaign_id
), calendar AS (
    SELECT c.*, c.start_dt+n AS report_dt
    FROM dds.dim_campaigns c CROSS JOIN generate_series(0,89) AS s(n)
    WHERE c.start_dt+n<=c.end_dt
), daily AS (
    SELECT c.*,ch.channel_name,
           round(c.budget/(c.end_dt-c.start_dt+1) * (0.7+(c.campaign_id%4)*0.15) *
                 (0.8+((c.campaign_id+(c.report_dt-c.start_dt))%5)*0.1),2) AS spend
    FROM calendar c JOIN dds.dim_channels ch ON ch.channel_id=c.channel_id
)
SELECT d.report_dt,d.campaign_id,d.campaign_name,d.channel_id,d.channel_name,
       coalesce(s.orders_count,0),coalesce(s.customers_count,0),coalesce(s.amount,0),
       round(s.avg_amount,2),coalesce(s.new_customers,0),d.budget,d.spend,coalesce(s.amount,0),
       round((coalesce(s.amount,0)-d.spend)/nullif(d.spend,0),6)
FROM daily d LEFT JOIN sales s ON s.campaign_id=d.campaign_id AND s.order_dt=d.report_dt;
COMMIT;
ANALYZE cdm.dm_sales_performance;
