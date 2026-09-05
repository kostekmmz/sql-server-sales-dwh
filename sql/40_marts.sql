USE olist_dwh;
GO
CREATE OR ALTER VIEW mart.v_sales_by_month AS
SELECT 
    dd.year_num,
    dd.month_num,
    COUNT(DISTINCT fs.order_id)     AS distinct_orders,
    COUNT(DISTINCT fs.customer_key) AS distinct_customers,
    SUM(fs.price)                   AS total_value
FROM dwh.fact_sales fs
JOIN dwh.dim_date dd ON dd.date_key = fs.date_key
GROUP BY dd.year_num, dd.month_num;
GO
CREATE OR ALTER VIEW mart.v_sales_by_product_category AS
SELECT 
product_category_name, 
COUNT(sales_key) as order_items_count
FROM dwh.fact_sales fs 
JOIN dwh.products p 
	ON fs.product_key = p.product_key
GROUP BY product_category_name;
GO