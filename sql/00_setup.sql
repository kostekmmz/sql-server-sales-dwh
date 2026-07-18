CREATE DATABASE olist_dwh;
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