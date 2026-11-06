\set ON_ERROR_STOP on
-- Same join and data, with a random baseline distribution for comparison.
CREATE TEMP TABLE baseline_items AS SELECT * FROM dds.fact_order_items DISTRIBUTED RANDOMLY;
ANALYZE baseline_items;
EXPLAIN SELECT sum(i.quantity*i.price)
FROM dds.fact_orders o JOIN baseline_items i ON i.order_id=o.order_id
WHERE o.order_dt>=date '2026-09-01' AND o.order_dt<date '2026-10-01';
EXPLAIN ANALYZE SELECT sum(i.quantity*i.price)
FROM dds.fact_orders o JOIN baseline_items i ON i.order_id=o.order_id
WHERE o.order_dt>=date '2026-09-01' AND o.order_dt<date '2026-10-01';
EXPLAIN SELECT sum(i.quantity*i.price)
FROM dds.fact_orders o JOIN dds.fact_order_items i ON i.order_id=o.order_id
WHERE o.order_dt>=date '2026-09-01' AND o.order_dt<date '2026-10-01'
  AND i.order_dt>=date '2026-09-01' AND i.order_dt<date '2026-10-01';
EXPLAIN ANALYZE SELECT sum(i.quantity*i.price)
FROM dds.fact_orders o JOIN dds.fact_order_items i ON i.order_id=o.order_id
WHERE o.order_dt>=date '2026-09-01' AND o.order_dt<date '2026-10-01'
  AND i.order_dt>=date '2026-09-01' AND i.order_dt<date '2026-10-01';
EXPLAIN SELECT campaign_id,sum(order_amount) FROM dds.fact_orders
WHERE order_status='completed' AND order_dt>=date '2026-09-01' AND order_dt<date '2026-10-01'
GROUP BY campaign_id;
EXPLAIN ANALYZE SELECT campaign_id,sum(revenue) FROM cdm.dm_sales_performance
WHERE report_dt>=date '2026-09-01' AND report_dt<date '2026-10-01' GROUP BY campaign_id;
