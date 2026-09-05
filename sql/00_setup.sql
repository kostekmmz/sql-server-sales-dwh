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
CREATE SCHEMA etl;
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

DROP TABLE IF EXISTS stg.order_items;
DROP TABLE IF EXISTS stg.orders;
DROP TABLE IF EXISTS stg.products;
DROP TABLE IF EXISTS stg.product_category_name_translation;
DROP TABLE IF EXISTS stg.customers;
DROP TABLE IF EXISTS stg.rejected_customers;
DROP TABLE IF EXISTS stg.rejected_orders;
DROP TABLE IF EXISTS stg.rejected_order_items;
DROP TABLE IF EXISTS stg.rejected_products;
DROP TABLE IF EXISTS stg.rejected_product_category_name_translation;
GO

CREATE TABLE stg.customers (
    customer_id                CHAR(32)        NOT NULL,
    customer_unique_id         CHAR(32)        NOT NULL,
    customer_zip_code_prefix   CHAR(5)         NULL,
    customer_city              NVARCHAR(100)   NULL,
    customer_state             CHAR(2)         NULL,
    loaded_at                  DATETIME2       NOT NULL CONSTRAINT DF_stg_customers_loaded_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_stg_customers PRIMARY KEY (customer_id)
);
GO

CREATE TABLE stg.orders (
    order_id                        CHAR(32)        NOT NULL,
    customer_id                     CHAR(32)        NOT NULL,
    order_status                    VARCHAR(20)      NULL,
    order_purchase_timestamp        DATETIME2       NOT NULL,
    order_approved_at               DATETIME2       NULL,
    order_delivered_carrier_date    DATETIME2       NULL,
    order_delivered_customer_date   DATETIME2       NULL,
    order_estimated_delivery_date   DATETIME2       NULL,
    loaded_at                       DATETIME2       NOT NULL CONSTRAINT DF_stg_orders_loaded_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_stg_orders PRIMARY KEY (order_id)
);
GO

CREATE TABLE stg.order_items (
    order_id                CHAR(32)        NOT NULL,
    order_item_id           SMALLINT        NOT NULL,
    product_id              CHAR(32)        NOT NULL,
    seller_id               CHAR(32)        NULL,
    shipping_limit_date     DATETIME2       NULL,
    price                   DECIMAL(10,2)   NOT NULL,
    freight_value           DECIMAL(10,2)   NOT NULL,
    loaded_at               DATETIME2       NOT NULL CONSTRAINT DF_stg_order_items_loaded_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_stg_order_items PRIMARY KEY (order_id, order_item_id),
    CONSTRAINT CK_stg_order_items_price CHECK (price > 0),
    CONSTRAINT CK_stg_order_items_freight_value CHECK (freight_value >= 0)
);
GO

CREATE TABLE stg.products (
    product_id                    CHAR(32)        NOT NULL,
    product_category_name         NVARCHAR(100)   NULL,
    product_name_length           SMALLINT        NULL,
    product_description_length    SMALLINT        NULL,
    product_photos_qty            SMALLINT        NULL,
    product_weight_g              INT             NULL,
    product_length_cm             SMALLINT        NULL,
    product_height_cm             SMALLINT        NULL,
    product_width_cm              SMALLINT        NULL,
    loaded_at                     DATETIME2       NOT NULL CONSTRAINT DF_stg_products_loaded_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_stg_products PRIMARY KEY (product_id)
);
GO

CREATE TABLE stg.product_category_name_translation (
    product_category_name           NVARCHAR(100)   NOT NULL,
    product_category_name_english   NVARCHAR(100)   NOT NULL,
    loaded_at                       DATETIME2       NOT NULL CONSTRAINT DF_stg_pcnt_loaded_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_stg_product_category_name_translation PRIMARY KEY (product_category_name)
);
GO

CREATE TABLE stg.rejected_customers (
	customer_id						NVARCHAR(100)		NULL,
	customer_unique_id				NVARCHAR(100)		NULL,
	customer_zip_code_prefix		NVARCHAR(100)		NULL,
	customer_city					NVARCHAR(100)		NULL,
	customer_state					NVARCHAR(100)		NULL,
	reject_reason					NVARCHAR(100)		NULL,
	loaded_at						DATETIME2			NOT NULL CONSTRAINT DF_stg_rejected_customers DEFAULT SYSUTCDATETIME()

);
GO

CREATE TABLE stg.rejected_orders (

		order_id					  NVARCHAR(100)	NULL,
		customer_id				      NVARCHAR(100)	NULL,
		order_status				  NVARCHAR(100)	NULL,
		order_purchase_timestamp	  NVARCHAR(100)	NULL,
		order_approved_at			  NVARCHAR(100)	NULL,
		order_delivered_carrier_date  NVARCHAR(100)	NULL,
		order_delivered_customer_date NVARCHAR(100)	NULL,
		order_estimated_delivery_date NVARCHAR(100)	NULL,
		reject_reason				  NVARCHAR(100)	NULL,
		loaded_at					  DATETIME2     NOT NULL CONSTRAINT DF_stg_rejected_orders DEFAULT SYSUTCDATETIME()


);
GO


CREATE TABLE stg.rejected_order_items (
    order_id                NVARCHAR(100)		NULL,
    order_item_id           NVARCHAR(100)       NULL,
    product_id              NVARCHAR(100)       NULL,
    seller_id               NVARCHAR(100)       NULL,
    shipping_limit_date     NVARCHAR(100)       NULL,
    price                   NVARCHAR(100)	    NULL,
    freight_value           NVARCHAR(100)       NULL,
	reject_reason			NVARCHAR(100)	    NULL,
    loaded_at               DATETIME2           NOT NULL CONSTRAINT DF_rejected_order_items_loaded_at DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE stg.rejected_products (
    product_id                    NVARCHAR(100)   NULL,
    product_category_name         NVARCHAR(100)   NULL,
    product_name_length           NVARCHAR(100)   NULL,
    product_description_length    NVARCHAR(100)   NULL,
    product_photos_qty            NVARCHAR(100)   NULL,
    product_weight_g              NVARCHAR(100)   NULL,
    product_length_cm             NVARCHAR(100)   NULL,
    product_height_cm             NVARCHAR(100)   NULL,
    product_width_cm              NVARCHAR(100)   NULL,
	reject_reason				  NVARCHAR(100)   NULL,
    loaded_at                     DATETIME2       NOT NULL CONSTRAINT DF_stg_rejected_products_loaded_at DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE stg.rejected_product_category_name_translation (
    product_category_name           NVARCHAR(100)   NULL,
    product_category_name_english   NVARCHAR(100)   NULL,
	reject_reason					NVARCHAR(100)	NULL,
    loaded_at                       DATETIME2       NOT NULL CONSTRAINT DF_rejected_product_category_name_translation DEFAULT SYSUTCDATETIME()
);
GO

CREATE TABLE dwh.dim_date (
    date_key        INT NOT NULL PRIMARY KEY,
    full_date       DATE NOT NULL,
    year_num        INT NOT NULL,
    quarter_num     INT NOT NULL,
    month_num       INT NOT NULL,
    month_name      NVARCHAR(20) NOT NULL,
    day_of_month    INT NOT NULL,
    day_of_week     INT NOT NULL,
    day_name        NVARCHAR(20) NOT NULL,
    is_weekend      BIT NOT NULL,
	CONSTRAINT UQ_dim_date_full_date UNIQUE (full_date)
);
GO

WITH dates AS (
    SELECT CAST('2016-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d)
    FROM dates
    WHERE d < '2020-12-31'
)
INSERT INTO dwh.dim_date (date_key, full_date, year_num, quarter_num, month_num, month_name, day_of_month, day_of_week, day_name, is_weekend)
SELECT
	YEAR(d) * 10000 + MONTH(d) * 100 + DAY(d) AS date_key,
	d as full_date,
	YEAR(d) AS year_num,
	DATEPART(QUARTER, d) AS quarter_num,
	DATEPART(m, d) as month_num,
	DATENAME(MONTH, d) AS  month_name,
	DAY(d) AS day_of_month,
	DATEDIFF(DAY, '1900-01-01', d) % 7 +1 AS day_of_week,
    DATENAME(WEEKDAY, d) AS day_name,
    CAST(CASE WHEN DATEDIFF(DAY, '1900-01-01', d) %7 in (5,6) then 1 else 0 end as bit) as is_weekend
FROM dates dt
OPTION (MAXRECURSION 0);

CREATE TABLE dwh.products (
    product_key                 INT IDENTITY(1,1) NOT NULL,
    product_id                  CHAR(32)          NOT NULL,
    product_category_name       NVARCHAR(100)     NULL,
    product_name_length         SMALLINT          NULL,
    product_description_length  SMALLINT          NULL,
    product_photos_qty          SMALLINT          NULL,
    product_weight_g            INT               NULL,
    product_length_cm           SMALLINT          NULL,
    product_height_cm           SMALLINT          NULL,
    product_width_cm            SMALLINT          NULL,
    loaded_at                   DATETIME2         NOT NULL
        CONSTRAINT DF_dwh_dim_product_loaded_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_dwh_dim_product PRIMARY KEY (product_key),
    CONSTRAINT UQ_dwh_dim_product_product_id UNIQUE (product_id)
);


CREATE TABLE dwh.customers (
    customer_key					INT IDENTITY(1,1) NOT NULL PRIMARY KEY,
	customer_id						CHAR(32)        NOT NULL,
	customer_unique_id				CHAR(32)        NOT NULL,
    customer_zip_code_prefix        CHAR(5)         NULL,
	customer_city					NVARCHAR(100)   NULL,
    customer_state					CHAR(2)         NULL,
	valid_from						DATE			NOT NULL,
	valid_to						DATE			NOT NULL DEFAULT '9999-12-31',
	is_current						BIT				NOT NULL DEFAULT 1,
    loaded_at						DATETIME2       NOT NULL CONSTRAINT DF_dwh_customers_loaded_at DEFAULT SYSUTCDATETIME(),
	CONSTRAINT ck_customer_valid_range CHECK (valid_from <= valid_to)
);
GO

USE olist_dwh;
CREATE TABLE dwh.fact_sales (
    sales_key       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    date_key        INT NOT NULL,
    customer_key    INT NOT NULL,
	product_key		INT NOT NULL,
    order_id        CHAR(32) NOT NULL,
	order_item_id   SMALLINT        NOT NULL,
    order_status    VARCHAR(50) NULL,
    price           DECIMAL(10,2) NOT NULL,
    freight_value   DECIMAL(10,2) NOT NULL,
    seller_id       CHAR(32) NOT NULL,
    -- kolumny techniczne:
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    _source         VARCHAR(50) NOT NULL DEFAULT 'etl_practice'
);
 


CREATE UNIQUE INDEX IX_customers_current
	ON dwh.customers(customer_id)
	WHERE is_current = 1; 
GO


CREATE TABLE dwh.rejected_facts (
    rejected_sales_key       BIGINT IDENTITY(1,1) NOT NULL PRIMARY KEY,
    date_key        INT NOT NULL,
    customer_key    INT,
	product_key		INT,
    order_id        CHAR(32) NOT NULL,
	order_item_id	SMALLINT NOT NULL,
	order_status    VARCHAR(20) NOT NULL,
	reject_reason				  NVARCHAR(100)   NULL,
    _loaded_at      DATETIME2 NOT NULL DEFAULT SYSDATETIME(),
    _source         VARCHAR(50) NOT NULL DEFAULT 'etl_practice'
);


CREATE TABLE etl.run_log (
    run_id        INT           NOT NULL,
    step_name     VARCHAR(100)  NOT NULL,
    started_at    DATETIME2     NOT NULL,
    finished_at   DATETIME2     NULL,          
    rows_affected INT           NULL,
    status        VARCHAR(20)   NOT NULL       
);
CREATE TABLE etl.error_log (
    run_id          INT            NOT NULL,
    step_name       VARCHAR(100)   NULL,
    error_number    INT            NULL,
    error_message   NVARCHAR(4000) NULL,
    error_procedure NVARCHAR(200)  NULL,
    error_line      INT            NULL,
    logged_at       DATETIME2      NOT NULL DEFAULT SYSDATETIME()
);
