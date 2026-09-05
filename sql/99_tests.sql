/* ============================================================
   Post-pipeline verification: balances, reject distributions,
   dimension quality, fact integrity.
   Run after EXEC dwh.sp_run_pipeline. Every query states its
   expected result — any deviation is a finding to investigate.
   ============================================================ */
USE olist_dwh;
GO

/* ------------------------------------------------------------
   1. STAGING BALANCES — nothing lost between shelves
      expect: raw = stg + rejected (per table)
   ------------------------------------------------------------ */
SELECT 'customers' AS entity,
    (SELECT COUNT(*) FROM raw.customers)          AS raw_rows,
    (SELECT COUNT(*) FROM stg.customers)          AS stg_rows,
    (SELECT COUNT(*) FROM stg.rejected_customers) AS rejected_rows
UNION ALL
SELECT 'orders',
    (SELECT COUNT(*) FROM raw.orders),
    (SELECT COUNT(*) FROM stg.orders),
    (SELECT COUNT(*) FROM stg.rejected_orders)
UNION ALL
SELECT 'order_items',
    (SELECT COUNT(*) FROM raw.order_items),
    (SELECT COUNT(*) FROM stg.order_items),
    (SELECT COUNT(*) FROM stg.rejected_order_items)
UNION ALL
SELECT 'products',
    (SELECT COUNT(*) FROM raw.products),
    (SELECT COUNT(*) FROM stg.products),
    (SELECT COUNT(*) FROM stg.rejected_products)
UNION ALL
SELECT 'category_translation',
    (SELECT COUNT(*) FROM raw.product_category_name_translation),
    (SELECT COUNT(*) FROM stg.product_category_name_translation),
    (SELECT COUNT(*) FROM stg.rejected_product_category_name_translation);

/* ------------------------------------------------------------
   2. REJECT DISTRIBUTIONS — quarantine is never anonymous
      expect: empty result sets on this dataset
      (any rows = list of reasons with counts; each reason must
       be explainable against data_quality_findings.md)
   ------------------------------------------------------------ */
SELECT 'customers' AS entity, reject_reason, COUNT(*) AS rows_rejected
FROM stg.rejected_customers GROUP BY reject_reason
UNION ALL
SELECT 'orders', reject_reason, COUNT(*)
FROM stg.rejected_orders GROUP BY reject_reason
UNION ALL
SELECT 'order_items', reject_reason, COUNT(*)
FROM stg.rejected_order_items GROUP BY reject_reason
UNION ALL
SELECT 'products', reject_reason, COUNT(*)
FROM stg.rejected_products GROUP BY reject_reason
UNION ALL
SELECT 'category_translation', reject_reason, COUNT(*)
FROM stg.rejected_product_category_name_translation GROUP BY reject_reason
ORDER BY entity, rows_rejected DESC;

/* ------------------------------------------------------------
   3. FACT BALANCE — every staged item is in fact or rejected
      expect: stg_items = fact_rows + rejected_rows
      (with freight rule fixed: 112650 = 112650 + 0)
   ------------------------------------------------------------ */
SELECT
    (SELECT COUNT(*) FROM stg.order_items)    AS stg_items,
    (SELECT COUNT(*) FROM dwh.fact_sales)     AS fact_rows,
    (SELECT COUNT(*) FROM dwh.rejected_facts) AS rejected_rows;

/* ------------------------------------------------------------
   4. FACT INTEGRITY
   ------------------------------------------------------------ */
-- 4a. No duplicate grain (composite key) — expect: empty
SELECT order_id, order_item_id, COUNT(*) AS occurrences
FROM dwh.fact_sales
GROUP BY order_id, order_item_id
HAVING COUNT(*) > 1;

-- 4b. Every fact date_key exists in dim_date — expect: 0
SELECT COUNT(*) AS facts_with_unknown_date
FROM dwh.fact_sales f
LEFT JOIN dwh.dim_date d ON f.date_key = d.date_key
WHERE d.date_key IS NULL;

-- 4c. Reconciliation of order coverage — expect: itemless_orders = 775
--     (orders correctly absent from the fact at item grain)
SELECT COUNT(*) AS itemless_orders
FROM stg.orders o
WHERE NOT EXISTS (
    SELECT 1 FROM stg.order_items oi WHERE oi.order_id = o.order_id
);

/* ------------------------------------------------------------
   5. DIM_CUSTOMER (SCD2) SANITY
   ------------------------------------------------------------ */
-- 5a. No negative-lifetime versions — expect: empty
SELECT * FROM dwh.customers WHERE valid_to < valid_from;

-- 5b. Exactly one current version per natural key — expect: empty
--     (also enforced structurally by the filtered unique index)
SELECT customer_id, COUNT(*) AS current_versions
FROM dwh.customers
WHERE is_current = 1
GROUP BY customer_id
HAVING COUNT(*) > 1;

/* ------------------------------------------------------------
   6. products (SCD1) SANITY
   ------------------------------------------------------------ */
-- 6a. One row per product — expect: empty (enforced by UNIQUE)
SELECT product_id, COUNT(*) AS occurrences
FROM dwh.products
GROUP BY product_id
HAVING COUNT(*) > 1;

-- 6b. Dimension covers staging — expect: dim_rows = stg_rows
SELECT
    (SELECT COUNT(*) FROM stg.products)    AS stg_rows,
    (SELECT COUNT(*) FROM dwh.products) AS dim_rows;

/* ------------------------------------------------------------
   7. DIM_DATE SANITY
   ------------------------------------------------------------ */
-- 7a. Every year complete — expect: empty
SELECT year_num, COUNT(*) AS days_cnt
FROM dwh.dim_date
GROUP BY year_num
HAVING COUNT(*) NOT IN (365, 366);


/* ------------------------------------------------------------
   8. PIPELINE LOG — last run healthy
      expect: all steps 'success', no NULL finished_at
   ------------------------------------------------------------ */
SELECT step_name, started_at, finished_at, rows_affected, status
FROM etl.run_log
WHERE run_id = (SELECT MAX(run_id) FROM etl.run_log)
ORDER BY started_at;