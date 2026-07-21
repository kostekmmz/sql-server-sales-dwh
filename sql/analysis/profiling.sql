/* ============================================================
   profiling.sql
   Data profiling queries for Olist raw layer.
   Findings and conclusions: docs/data_quality_findings.md
   ============================================================ */
USE olist_dwh;
GO

/* ------------------------------------------------------------
   raw.products
   ------------------------------------------------------------ */

-- Overview: row counts, key uniqueness, null counts per column
SELECT
    COUNT(*)                                     AS total_rows,
    COUNT(DISTINCT product_id)                   AS distinct_product_ids,
    COUNT(*) - COUNT(product_category_name)      AS null_category,
    COUNT(*) - COUNT(product_name_lenght)        AS null_name_len,      -- source "lenght"
    COUNT(*) - COUNT(product_description_lenght) AS null_desc_len,
    COUNT(*) - COUNT(product_photos_qty)         AS null_photos,
    COUNT(*) - COUNT(product_weight_g)           AS null_weight,
    COUNT(*) - COUNT(product_length_cm)          AS null_length,
    COUNT(*) - COUNT(product_height_cm)          AS null_height,
    COUNT(*) - COUNT(product_width_cm)           AS null_width
FROM raw.products

-- Drill-down: 
-- which product_id values are duplicated (expect: none)
SELECT product_id, COUNT(*) AS occurrences
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1

-- Category dictionary: distinct values
SELECT DISTINCT product_category_name
FROM raw.products
ORDER BY product_category_name

-- Hypothesis check: metadata nulls occur in the same rows
-- (category / name_len / desc_len missing together; expect: 0)
SELECT COUNT(*) AS category_null_but_name_len_present
FROM raw.products
WHERE product_category_name IS NULL
  AND product_name_lenght IS NOT NULL

-- Numeric ranges + castability (raw stores text; TRY_CAST reveals
-- both the real min/max and values that would fail conversion)
SELECT
    MIN(TRY_CAST(product_weight_g AS INT)) AS min_weight_g,
    MAX(TRY_CAST(product_weight_g AS INT)) AS max_weight_g,
    SUM(CASE WHEN product_weight_g IS NOT NULL
              AND TRY_CAST(product_weight_g AS INT) IS NULL
             THEN 1 ELSE 0 END)            AS weight_not_castable
FROM raw.products

-- Translation coverage: categories missing from the mapping table
SELECT DISTINCT p.product_category_name
FROM raw.products p
LEFT JOIN raw.product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL


  
/* ------------------------------------------------------------
   raw.orders
   ------------------------------------------------------------ */

-- Overview: row counts, key uniqueness, null counts per column

SELECT 
COUNT(*)										AS total_rows,
COUNT(DISTINCT order_id)						AS distinct_order_ids,
COUNT(*) - COUNT(customer_id)					AS null_customer_id,
COUNT(*) - COUNT(order_status)					AS null_order_status,
COUNT(*) - COUNT(order_purchase_timestamp)		AS null_purchase,
COUNT(*) - COUNT(order_approved_at)				AS null_approved,
COUNT(*) - COUNT(order_delivered_carrier_date)	AS null_delivered_carrier,
COUNT(*) - COUNT(order_delivered_customer_date)	AS null_delivered_customer,
COUNT(*) - COUNT(order_estimated_delivery_date)	AS null_estimated_delivery
FROM raw.orders

-- 
-- Drill-down: 

-- Status distribution with counts
SELECT 
	order_status,
	COUNT(*) as occurrences
FROM raw.orders
GROUP BY order_status
ORDER BY COUNT(*) DESC

-- Data ranges per timestamp column
SELECT 
MAX(TRY_CAST(order_purchase_timestamp as datetime2))		AS max_date_purchase,
MIN(TRY_CAST(order_purchase_timestamp as datetime2))		AS min_date_purchase,
MAX(TRY_CAST(order_approved_at as datetime2))		AS max_order_approved,
MIN(TRY_CAST(order_approved_at as datetime2))		AS min_order_approved,
MAX(TRY_CAST(order_delivered_carrier_date as datetime2))		AS max_delivered_carrier_date,
MIN(TRY_CAST(order_delivered_carrier_date as datetime2))		AS min_delivered_carrier_date,
MAX(TRY_CAST(order_delivered_customer_date as datetime2))		AS max_delivered_customer_date,
MIN(TRY_CAST(order_delivered_customer_date as datetime2))		AS min_delivered_customer_date,
MAX(TRY_CAST(order_estimated_delivery_date as datetime2))		AS max_estimated_delivery_date,
MIN(TRY_CAST(order_estimated_delivery_date as datetime2))		AS min_estimated_delivery_date
FROM raw.orders

-- Customer Coverage: Customers missing from customer table (0)

SELECT 
	COUNT(*)
FROM raw.orders o
LEFT JOIN raw.customers c on c.customer_id = o.customer_id
WHERE o.customer_id IS NOT NULL 
AND c.customer_id IS NULL 

-- Referential check: orders with no order_items rows (775 found,
-- mostly unavailable/canceled). These cannot enter fact_sales
-- (grain = order item) -> documented in design decisions.

SELECT 
	order_status,
	COUNT(*)
FROM raw.orders o
LEFT JOIN raw.order_items oi on o.order_id  = oi.order_id
WHERE o.order_id IS NOT NULL 
AND oi.order_id IS NULL 
GROUP BY order_status

-- NULLS per STATUS 
-- Supports date-key choice -> see design decisions
SELECT 
order_status,
COUNT(*) AS total_rows,
COUNT(*) - COUNT(order_purchase_timestamp)	AS null_purchase_timestamp,
COUNT(*) - COUNT(order_approved_at) AS null_order_approved_at , 
COUNT(*) - COUNT(order_delivered_carrier_date) AS null_order_delivered_carrier_date,
COUNT(*) - COUNT(order_delivered_customer_date) AS null_order_delivered_customer_date,
COUNT(*) - COUNT(order_estimated_delivery_date) AS null_order_estimated_delivery_date
FROM raw.orders o
GROUP BY  order_status


/* ------------------------------------------------------------
  raw.customers
   ------------------------------------------------------------ */

-- Overview: row counts, key uniqueness, null counts per column

SELECT
    COUNT(*)                                      AS total_rows,
    COUNT(*) - COUNT(DISTINCT customer_id)        AS duplicate_customer_id,
	COUNT(*) - COUNT(DISTINCT customer_unique_id) AS customer_unique_id,
    COUNT(*) - COUNT(customer_zip_code_prefix)    AS null_customer_zip_code_prefix,
    COUNT(*) - COUNT(customer_city)				  AS null_customer_city,      
    COUNT(*) - COUNT(customer_state)			  AS null_customer_state
FROM raw.customers;


-- Drill-down: 
-- Natural key: customer_unique_id
-- 2 997 customer_unique id has > 1 customer_id
SELECT  
customer_unique_id,
COUNT(customer_id)
FROM raw.customers
GROUP BY customer_unique_id
HAVING COUNT(customer_id) > 1 
ORDER BY COUNT(customer_id) DESC

-- 

SELECT customer_city, 
COUNT(DISTINCT customer_state) 
FROM raw.customers 
GROUP BY customer_city 
HAVING COUNT(DISTINCT customer_state) > 1


/* ------------------------------------------------------------
   raw.order_items
   ------------------------------------------------------------ */

-- Overview: row counts, key uniqueness, null counts per column

SELECT
    COUNT(*)                                    AS total_rows,
	COUNT(*) - COUNT(DISTINCT order_id)			AS non_unique_order_id,
    COUNT(*) - COUNT(order_id)					AS null_order_id,
	COUNT(*) - COUNT(order_item_id)				AS null_order_item_id,
    COUNT(*) - COUNT(product_id)				AS null_product_id,
    COUNT(*) - COUNT(seller_id)					AS null_seller_id,      
    COUNT(*) - COUNT(shipping_limit_date)		AS null_shipping_limit_date,
	COUNT(*) - COUNT(price)						AS null_price,
	COUNT(*) - COUNT(freight_value)				AS null_freight_value
FROM raw.order_items

-- Drill-down: 
-- Products Coverage: Products missing from products table (0)
SELECT COUNT(*)
FROM raw.order_items oi
LEFT JOIN raw.products p ON oi.product_id = p.product_id
WHERE p.product_id is null

--Composite key (order_id, order_item_id) uniqueness; expect: none
SELECT 
order_id,
order_item_id,
COUNT(*)
FROM raw.order_items
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1 


--

--MIN SHIPPING 2016-09-19
--MAX SHIPPINIG 2020-04-09
--0 NEGATIVE FREIGHT VALUE AND PRICE
--383 ZERO FREIGHT VALUE
-- 0 ZERO PRICE
-- 0.85 MIN_PRICE
-- 6735 MAX_PRICE

SELECT 
SUM(CASE WHEN TRY_CAST(price as DECIMAL(10,2)) < 0 THEN 1 ELSE 0 END) AS negative_price,
SUM(CASE WHEN TRY_CAST(freight_value as DECIMAL(10,2)) < 0 THEN 1 ELSE 0 END) AS negative_freight_value,
SUM(CASE WHEN TRY_CAST(price as DECIMAL(10,2)) = 0 THEN 1 ELSE 0 END) AS zero_price,
SUM(CASE WHEN TRY_CAST(freight_value as DECIMAL(10,2)) = 0 THEN 1 ELSE 0 END) AS zero_freight_value,
MAX(TRY_CAST(price as DECIMAL(10,2))) AS max_price,
MIN(TRY_CAST(price as DECIMAL(10,2))) AS min_price,
MAX(TRY_CAST(freight_value as DECIMAL(10,2))) AS max_freight_value,
MIN(TRY_CAST(freight_value as DECIMAL(10,2))) AS min_freight_value,
MIN(TRY_CAST(shipping_limit_date as DATETIME2))AS min_shipping_limit_date,
MAX(TRY_CAST(shipping_limit_date as DATETIME2)) AS max_shipping_limit_date
FROM raw.order_items

-- Referential check: orders_item with no order rows (0 FOUND)

SELECT 
	COUNT(*)
FROM raw.order_items oi
LEFT JOIN raw.orders o on o.order_id  = oi.order_id
WHERE oi.order_id IS NOT NULL 
AND o.order_id IS NULL 

