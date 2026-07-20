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