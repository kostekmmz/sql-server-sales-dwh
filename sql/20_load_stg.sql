USE olist_dwh;
GO

DROP TABLE IF EXISTS stg.order_items;
DROP TABLE IF EXISTS stg.orders;
DROP TABLE IF EXISTS stg.products;
DROP TABLE IF EXISTS stg.product_category_name_translation;
DROP TABLE IF EXISTS stg.customers;
DROP TABLE IF EXISTS stg.rejected_customers;
GO

CREATE TABLE stg.customers (
    customer_id                CHAR(32)        NOT NULL,
    customer_unique_id         CHAR(32)        NOT NULL,
    customer_zip_code_prefix   CHAR(5)         NULL,
    customer_city              NVARCHAR(100)   NOT NULL,
    customer_state             CHAR(2)         NOT NULL,
    loaded_at                  DATETIME2       NOT NULL CONSTRAINT DF_stg_customers_loaded_at DEFAULT SYSUTCDATETIME(),
    CONSTRAINT PK_stg_customers PRIMARY KEY (customer_id)
);
GO

CREATE TABLE stg.orders (
    order_id                        CHAR(32)        NOT NULL,
    customer_id                     CHAR(32)        NOT NULL,
    order_status                    VARCHAR(20)     NOT NULL,
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
    seller_id               CHAR(32)        NOT NULL,
    shipping_limit_date     DATETIME2       NOT NULL,
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
	customer_id						CHAR(32)		NOT NULL,
	customer_unique_id				CHAR(32)		NOT NULL,
	customer_zip_code_prefix		CHAR(5)			NULL,
	customer_city					NVARCHAR(100)	NOT NULL,
	customer_state					CHAR(2)			NOT NULL,
	reject_reason					NVARCHAR(30)	NOT NULL,
	loaded_at						DATETIME2       NOT NULL CONSTRAINT DF_stg_rejected_customers DEFAULT SYSUTCDATETIME()

);
GO

CREATE OR ALTER PROCEDURE stg.sp_load_customers 
AS
BEGIN
	SET NOCOUNT ON; 

	BEGIN TRY
		BEGIN TRANSACTION;
	
	------------------------------
	
	------------------------------
		TRUNCATE TABLE stg.customers;
		TRUNCATE TABLE stg.rejected_customers;


	-----------------------------
	-- 1. Cleaning + validation rules
	-----------------------------

		SELECT 
			NULLIF(TRIM(customer_id), '')				AS customer_id,
			NULLIF(TRIM(customer_unique_id), '')		AS customer_unique_id,
			NULLIF(TRIM(customer_zip_code_prefix), '')	AS customer_zip_code_prefix,
			NULLIF(TRIM(customer_city), '')				AS customer_city,
			UPPER(NULLIF(TRIM(customer_state), ''))		AS customer_state,
			CASE 
				WHEN NULLIF(TRIM(customer_id), '') IS NULL
					THEN 'missing_customer_id'
				WHEN NULLIF(TRIM(customer_unique_id), '') IS NULL
					THEN 'missing_customer_unique_id'
			END											AS reject_reason
		INTO #cleaned
		FROM raw.customers;

		----------------------------------------------------------
		-- 2. Rows to staging based on reject_reason -> NULL
		----------------------------------------------------------
	
		INSERT INTO stg.customers
			(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state)

		SELECT
			customer_id,
			customer_unique_id,
			customer_zip_code_prefix,
			customer_city,
			customer_state
		FROM #cleaned
		WHERE reject_reason is NULL;
	
		----------------------------------------------------------
		-- 3.Rows to staging based on reject_reason -> NOT NULL
		----------------------------------------------------------
		INSERT INTO stg.rejected_customers
			(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, reject_reason)

		SELECT
			customer_id,
			customer_unique_id,
			customer_zip_code_prefix,
			customer_city,
			customer_state,
			reject_reason
		FROM #cleaned
		WHERE reject_reason IS NOT NULL;
	
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
	IF @@TRANCOUNT >0 ROLLBACK TRANSACTION;
	THROW;
	END CATCH
END;
GO


