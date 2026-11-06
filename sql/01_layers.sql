\set ON_ERROR_STOP on
BEGIN;
CREATE SCHEMA stg;
CREATE SCHEMA dds;
CREATE SCHEMA cdm;

CREATE TABLE stg.customers (
    customer_id integer PRIMARY KEY, customer_name text NOT NULL,
    signup_dt date NOT NULL, region text NOT NULL, customer_segment text NOT NULL
) DISTRIBUTED BY (customer_id);
CREATE TABLE stg.channels (
    channel_id integer PRIMARY KEY, channel_name text NOT NULL, channel_type text NOT NULL
) DISTRIBUTED REPLICATED;
CREATE TABLE stg.campaigns (
    campaign_id integer PRIMARY KEY, campaign_name text NOT NULL, channel_id integer NOT NULL,
    start_dt date NOT NULL, end_dt date NOT NULL, budget numeric(14,2) NOT NULL CHECK (budget >= 0),
    CHECK (end_dt >= start_dt)
) DISTRIBUTED REPLICATED;
CREATE TABLE stg.orders (
    order_id bigint NOT NULL, order_dt date NOT NULL, customer_id integer NOT NULL,
    campaign_id integer NOT NULL, order_amount numeric(14,2) NOT NULL CHECK (order_amount >= 0),
    order_status text NOT NULL CHECK (order_status IN ('completed','cancelled','returned')),
    PRIMARY KEY (order_id, order_dt)
) DISTRIBUTED BY (order_id)
PARTITION BY RANGE (order_dt)
(START (date '2026-08-01') INCLUSIVE END (date '2026-11-01') EXCLUSIVE EVERY (INTERVAL '1 month'));
CREATE TABLE stg.order_items (
    order_item_id bigint NOT NULL, order_id bigint NOT NULL, product_id integer NOT NULL,
    product_name text NOT NULL, quantity integer NOT NULL CHECK (quantity > 0),
    price numeric(12,2) NOT NULL CHECK (price >= 0), PRIMARY KEY (order_id, order_item_id)
) DISTRIBUTED BY (order_id);

INSERT INTO stg.customers
SELECT n, 'Customer ' || n, date '2026-07-01' + (n % 31),
       (ARRAY['Moscow','Kazan','Samara','Perm'])[1+n%4],
       CASE n%3 WHEN 0 THEN 'business' WHEN 1 THEN 'retail' ELSE 'premium' END
FROM generate_series(1,120) AS s(n);
INSERT INTO stg.channels VALUES
    (1,'Search','paid'),(2,'Social','paid'),(3,'Email','owned'),(4,'Partners','affiliate');
INSERT INTO stg.campaigns
SELECT n, 'Campaign ' || n, 1+(n-1)%4, date '2026-08-01', date '2026-10-29',
       (18000+n*1800)::numeric(14,2)
FROM generate_series(1,12) AS s(n);
INSERT INTO stg.orders
SELECT n, date '2026-08-01' + ((n-1)/8)::integer,
       1+((n*37+((n-1)/120)*11)%120)::integer,
       1+((n*7+((n-1)/12)*5)%12)::integer, 0,
       CASE WHEN n%10=0 THEN 'cancelled' WHEN n%10=1 THEN 'returned' ELSE 'completed' END
FROM generate_series(1,720) AS s(n);
-- Random prices determine the order amount through the sum of its positions.
INSERT INTO stg.order_items
SELECT (o.order_id-1)*4+k, o.order_id,
       1+((o.order_id*3+k)%40)::integer,
       'Product ' || (1+(o.order_id*3+k)%40),
       1+(k%3), round((50+random()*950)::numeric,2)
FROM stg.orders o CROSS JOIN generate_series(1,4) AS s(k);
UPDATE stg.orders o SET order_amount = x.amount
FROM (SELECT order_id, sum(quantity*price) AS amount FROM stg.order_items GROUP BY order_id) x
WHERE o.order_id=x.order_id;

CREATE TABLE dds.dim_customers (
    customer_id integer PRIMARY KEY, customer_name text NOT NULL, signup_dt date NOT NULL,
    region text NOT NULL, customer_segment text NOT NULL,
    load_dt timestamp NOT NULL, load_src text NOT NULL
) DISTRIBUTED REPLICATED;
CREATE TABLE dds.dim_channels (
    channel_id integer PRIMARY KEY, channel_name text NOT NULL, channel_type text NOT NULL,
    load_dt timestamp NOT NULL, load_src text NOT NULL
) DISTRIBUTED REPLICATED;
CREATE TABLE dds.dim_campaigns (
    campaign_id integer PRIMARY KEY, campaign_name text NOT NULL, channel_id integer NOT NULL,
    start_dt date NOT NULL, end_dt date NOT NULL, budget numeric(14,2) NOT NULL,
    load_dt timestamp NOT NULL, load_src text NOT NULL
) DISTRIBUTED REPLICATED;
CREATE TABLE dds.fact_orders (
    order_id bigint NOT NULL, order_dt date NOT NULL, customer_id integer NOT NULL,
    campaign_id integer NOT NULL, order_amount numeric(14,2) NOT NULL,
    order_status text NOT NULL, load_dt timestamp NOT NULL, load_src text NOT NULL,
    PRIMARY KEY (order_id, order_dt)
) DISTRIBUTED BY (order_id)
PARTITION BY RANGE (order_dt)
(START (date '2026-08-01') INCLUSIVE END (date '2026-11-01') EXCLUSIVE EVERY (INTERVAL '1 month'));
CREATE TABLE dds.fact_order_items (
    order_item_id bigint NOT NULL, order_id bigint NOT NULL, order_dt date NOT NULL,
    product_id integer NOT NULL, product_name text NOT NULL, quantity integer NOT NULL,
    price numeric(12,2) NOT NULL, load_dt timestamp NOT NULL, load_src text NOT NULL,
    PRIMARY KEY (order_id, order_dt, order_item_id)
) DISTRIBUTED BY (order_id)
PARTITION BY RANGE (order_dt)
(START (date '2026-08-01') INCLUSIVE END (date '2026-11-01') EXCLUSIVE EVERY (INTERVAL '1 month'));
INSERT INTO dds.dim_customers SELECT DISTINCT s.*, current_timestamp, 'stg.customers' FROM stg.customers s;
INSERT INTO dds.dim_channels SELECT DISTINCT s.*, current_timestamp, 'stg.channels' FROM stg.channels s;
INSERT INTO dds.dim_campaigns SELECT DISTINCT s.*, current_timestamp, 'stg.campaigns' FROM stg.campaigns s;
INSERT INTO dds.fact_orders SELECT s.*, current_timestamp, 'stg.orders' FROM stg.orders s;
INSERT INTO dds.fact_order_items
SELECT i.order_item_id,i.order_id,o.order_dt,i.product_id,i.product_name,i.quantity,i.price,
       current_timestamp,'stg.order_items'
FROM stg.order_items i JOIN stg.orders o ON o.order_id=i.order_id;

CREATE TABLE cdm.dm_sales_performance (
    report_dt date NOT NULL, campaign_id integer NOT NULL, campaign_name text NOT NULL,
    channel_id integer NOT NULL, channel_name text NOT NULL,
    orders_count bigint NOT NULL, customers_count bigint NOT NULL,
    order_amount numeric(18,2) NOT NULL, avg_order_amount numeric(18,2),
    new_customers bigint NOT NULL, campaign_budget numeric(14,2) NOT NULL,
    spend numeric(18,2) NOT NULL, revenue numeric(18,2) NOT NULL, roi numeric(18,6),
    PRIMARY KEY (campaign_id,report_dt)
) DISTRIBUTED BY (campaign_id)
PARTITION BY RANGE (report_dt)
(START (date '2026-08-01') INCLUSIVE END (date '2026-11-01') EXCLUSIVE EVERY (INTERVAL '1 month'));
COMMIT;
ANALYZE stg.customers;
ANALYZE stg.channels;
ANALYZE stg.campaigns;
ANALYZE stg.orders;
ANALYZE stg.order_items;
ANALYZE dds.dim_customers;
ANALYZE dds.dim_channels;
ANALYZE dds.dim_campaigns;
ANALYZE dds.fact_orders;
ANALYZE dds.fact_order_items;
