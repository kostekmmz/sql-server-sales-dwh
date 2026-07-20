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
FROM raw.products;

-- Drill-down: 
-- which product_id values are duplicated (expect: none)
SELECT product_id, COUNT(*) AS occurrences
FROM raw.products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- Category dictionary: distinct values
SELECT DISTINCT product_category_name
FROM raw.products
ORDER BY product_category_name;

-- Hypothesis check: metadata nulls occur in the same rows
-- (category / name_len / desc_len missing together; expect: 0)
SELECT COUNT(*) AS category_null_but_name_len_present
FROM raw.products
WHERE product_category_name IS NULL
  AND product_name_lenght IS NOT NULL;

-- Numeric ranges + castability (raw stores text; TRY_CAST reveals
-- both the real min/max and values that would fail conversion)
SELECT
    MIN(TRY_CAST(product_weight_g AS INT)) AS min_weight_g,
    MAX(TRY_CAST(product_weight_g AS INT)) AS max_weight_g,
    SUM(CASE WHEN product_weight_g IS NOT NULL
              AND TRY_CAST(product_weight_g AS INT) IS NULL
             THEN 1 ELSE 0 END)            AS weight_not_castable
FROM raw.products;

-- Translation coverage: categories missing from the mapping table
SELECT DISTINCT p.product_category_name
FROM raw.products p
LEFT JOIN raw.product_category_name_translation t
    ON p.product_category_name = t.product_category_name
WHERE p.product_category_name IS NOT NULL
  AND t.product_category_name IS NULL;


  
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
MAX(TRY_CAST(order_approved_at as datetime2))		AS MAX_order_approved,
MIN(TRY_CAST(order_approved_at as datetime2))		AS MIN_order_approved,
MAX(TRY_CAST(order_delivered_carrier_date as datetime2))		AS MAX_delivered_carrier_date,
MIN(TRY_CAST(order_delivered_carrier_date as datetime2))		AS MIN_delivered_carrier_date,
MAX(TRY_CAST(order_delivered_customer_date as datetime2))		AS MAX_delivered_customer_date,
MIN(TRY_CAST(order_delivered_customer_date as datetime2))		AS MIN_delivered_customer_date,
MAX(TRY_CAST(order_estimated_delivery_date as datetime2))		AS MAX_estimated_delivery_date,
MIN(TRY_CAST(order_estimated_delivery_date as datetime2))		AS MIN_estimated_delivery_date
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
-- Supports date-key choice -> see desing decisions
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
