# Data Quality Findings - Olist raw layer
Profiled: 2026-07-21 | Source: Olist (Kaggle), 5 of 9 files 
Queries: sql/analysis/profiling.sql

## Summary:

- All five sources files were profiles 
- Data quality: keys are clean (no duplicates on any verifed key)
- The significant findings are structural rather than dirt: 775 orders have no items - Cant enter the fact table 
- Customers carry two indetifiers (per-order and per-person) - drives the natural key choice for dim_customer 
- Order purchase_timestamp is the only populated date that determines the date key

## raw.orders (99 441 rows)
- **775 orders have no order_items** (statuses: unavailable=603 canceled=164, created=5, invoiced=2, shipped=1).
  At fact grain (order item) these can't enter fact_sales → row-count
- **order_purchase_timestamp is the only timestamp with zero NULLs across
  all statuses** → chosen as basis for date_key. 
- Date range: 04-09-2016 to 17-10-2018 (purchase)

## raw.customers (99 441 rows)
- **customer_id is unique per row (verified); customer_unique_id has 96096
  distinct values — 2 997 unique_ids map to >1 customer_id** (max: 17 accounts).
  customer_id = per-order account, customer_unique_id = person.
  → natural key: customer_unique_id → design_decisions: dim_customer key
- 163 city names appear in multiple states (expected: name repetition
  across states + spelling variants). City = descriptive attribute only;
  geographic analysis groups by state or state+city. No cleanup planned.

## raw.products (32 951 rows)
- product_id unique (verified, 0 duplicates)
- **610 products lack all metadata** (category, name/desc length —
  verified same-row correlation) → staging: category → 'unknown' 
- 2 categories missing from translation table → staging decision
- Source column typo: "product_name_lenght" → renamed in staging
- Weight/dimensions: 2 rows fully NULL

## raw.order_items (112 650 rows)
- Grain: **composite key (order_id, order_item_id) — verified unique**
- price: 0 zeros, 0 negatives → supports CHECK (price > 0)
- freight_value: **383 zeros** (interpreted: free shipping — legal value,
  not dirt) → CHECK (freight_value >= 0)
- seller_id present (0 nulls) but sellers table out of scope for v1
  → passthrough column, no referential validation → design_decisions
- shipping_limit_date range: 2016-09-19 to 2020-04-09 — note: extends
  beyond order range → verify dim_date coverage


## Open questions carried to staging design
1. NULL category → 'unknown' vs keep NULL?
2. Untranslated categories → Portuguese vs manual translation?