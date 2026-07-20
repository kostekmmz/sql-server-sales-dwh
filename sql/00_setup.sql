CREATE DATABASE olist_dwh;
GO
USE olist_dwh;
GO
CREATE SCHEMA raw;
GO
CREATE SCHEMA stg;
GO
CREATE SCHEMA dwh;
GO
CREATE SCHEMA mart;
GO

DROP TABLE IF EXISTS raw.orders;
CREATE TABLE raw.orders (
    order_id NVARCHAR(MAX),
    customer_id NVARCHAR(MAX),
    order_status NVARCHAR(MAX),
    order_purchase_timestamp NVARCHAR(MAX),
    order_approved_at NVARCHAR(MAX),
    order_delivered_carrier_date NVARCHAR(MAX),
    order_delivered_customer_date NVARCHAR(MAX),
    order_estimated_delivery_date NVARCHAR(MAX)
);
GO

DROP TABLE IF EXISTS raw.customers;
CREATE TABLE raw.customers (
    customer_id NVARCHAR(MAX),
    customer_unique_id NVARCHAR(MAX),
    customer_zip_code_prefix NVARCHAR(MAX),
    customer_city NVARCHAR(MAX),
    customer_state NVARCHAR(MAX)
);
GO

DROP TABLE IF EXISTS raw.order_items;
CREATE TABLE raw.order_items (
    order_id NVARCHAR(MAX),
    order_item_id NVARCHAR(MAX),
    product_id NVARCHAR(MAX),
    seller_id NVARCHAR(MAX),
    shipping_limit_date NVARCHAR(MAX),
    price NVARCHAR(MAX),
    freight_value NVARCHAR(MAX)
);
GO

DROP TABLE IF EXISTS raw.products;
CREATE TABLE raw.products (
    product_id NVARCHAR(MAX),
    product_category_name NVARCHAR(MAX),
    product_name_lenght NVARCHAR(MAX),
    product_description_lenght NVARCHAR(MAX),
    product_photos_qty NVARCHAR(MAX),
    product_weight_g NVARCHAR(MAX),
    product_length_cm NVARCHAR(MAX),
    product_height_cm NVARCHAR(MAX),
    product_width_cm NVARCHAR(MAX)
);
GO

DROP TABLE IF EXISTS raw.product_category_name_translation;
CREATE TABLE raw.product_category_name_translation (
    product_category_name NVARCHAR(MAX),
    product_category_name_english NVARCHAR(MAX)
);