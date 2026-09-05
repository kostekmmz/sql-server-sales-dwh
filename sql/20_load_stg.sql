USE olist_dwh;
GO
CREATE OR ALTER PROCEDURE stg.sp_load_customers 
AS
BEGIN
	SET NOCOUNT ON; 
	DROP TABLE IF EXISTS #cleaned
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


CREATE OR ALTER PROCEDURE stg.sp_load_orders
AS
BEGIN
	SET NOCOUNT ON;
	DROP TABLE IF EXISTS #cleaned_orders;
	BEGIN TRY 
		BEGIN TRANSACTION; 


		-------------------------------------------
		-- Truncating stg tables
		-------------------------------------------
		TRUNCATE TABLE stg.orders;
		TRUNCATE TABLE stg.rejected_orders;
		
		-------------------------------------------
		-- 1. Cleaning and validation rules
		-------------------------------------------

		
		
		SELECT 
			NULLIF(TRIM(order_id), '')											AS order_id,
			NULLIF(TRIM(customer_id), '')										AS customer_id,
			NULLIF(TRIM(order_status), '')										AS order_status,
			TRY_CAST(order_purchase_timestamp AS DATETIME2)						AS order_purchase_timestamp,
			TRY_CAST(order_approved_at AS DATETIME2)							AS order_approved_at,
			TRY_CAST(order_delivered_carrier_date AS DATETIME2)					AS order_delivered_carrier_date,
			TRY_CAST(order_delivered_customer_date AS DATETIME2)				AS order_delivered_customer_date,
			TRY_CAST(order_estimated_delivery_date AS DATETIME2)				AS order_estimated_delivery_date,
			order_purchase_timestamp											AS order_purchase_timestamp_raw,
			order_status														AS order_status_raw,
			CASE 
				WHEN NULLIF(TRIM(order_id), '') IS NULL
					THEN 'missing_order_id'
				WHEN NULLIF(TRIM(customer_id), '') IS NULL
					THEN 'missing_customer_id'
				WHEN TRY_CAST(order_purchase_timestamp AS DATETIME2) IS NULL
					THEN 'missing_or_invalid_order_purchase_date'
				WHEN NULLIF(TRIM(order_status), '') IS NULL
					THEN 'missing_order_status'
						END														AS reject_reason
		INTO #cleaned_orders
		FROM raw.orders

		-------------------------------------------
		--  2. Rows to staging based on reject_reason -> NULL
		-------------------------------------------

		
		INSERT INTO stg.orders
			(order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date)
		SELECT
			order_id,
			customer_id, 
			order_status,
			order_purchase_timestamp,
			order_approved_at,
			order_delivered_carrier_date,
			order_delivered_customer_date, 
			order_estimated_delivery_date
		FROM #cleaned_orders
		WHERE reject_reason is NULL;

		----------------------------------------------------------
		-- 3.Rows to staging based on reject_reason -> NOT NULL
		----------------------------------------------------------
		INSERT INTO stg.rejected_orders
			(order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date,
			reject_reason)
		SELECT
			order_id,
			customer_id, 
			order_status_raw,
			order_purchase_timestamp_raw,
			order_approved_at,
			order_delivered_carrier_date,
			order_delivered_customer_date, 
			order_estimated_delivery_date,
			reject_reason
		FROM #cleaned_orders
		WHERE reject_reason is NOT NULL;

		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
	THROW;
	END CATCH
END;
GO

CREATE OR ALTER PROCEDURE stg.sp_load_order_items
AS
BEGIN
	SET NOCOUNT ON;
	DROP TABLE IF EXISTS #cleaned_order_items;
	BEGIN TRY 
		BEGIN TRANSACTION; 


		-------------------------------------------
		-- Truncating stg tables
		-------------------------------------------
		TRUNCATE TABLE stg.order_items;
		TRUNCATE TABLE stg.rejected_order_items;
		
		-------------------------------------------
		-- 1. Cleaning and validation rules
		-------------------------------------------
		
		SELECT 
			NULLIF(TRIM(order_id), '')											AS order_id,
			TRY_CAST(TRIM(order_item_id) AS smallint)						AS order_item_id,
			NULLIF(TRIM(product_id), '')										AS product_id,
			NULLIF(TRIM(seller_id), '')											AS seller_id,
			TRY_CAST(shipping_limit_date AS DATETIME2)							AS shipping_limit_date,
			TRY_CAST(price AS decimal(10,2))									AS price,
			TRY_CAST(freight_value AS decimal(10,2))							AS freight_value,
			price																AS price_raw,
			freight_value														AS freight_value_raw,
			CASE 
				WHEN NULLIF(TRIM(order_id), '') IS NULL
					THEN 'missing_order_id'
				WHEN NULLIF(TRIM(product_id), '') IS NULL
					THEN 'missing_product_id'
				WHEN TRY_CAST(TRIM(order_item_id) AS SMALLINT) IS NULL
					 THEN 'missing_or_invalid_order_item_id'
				WHEN TRY_CAST(price AS DECIMAL(10,2)) IS NULL
					 OR TRY_CAST(price AS DECIMAL(10,2)) <= 0        
					 THEN 'invalid_price'
					WHEN TRY_CAST(freight_value AS DECIMAL(10,2)) IS NULL
					 OR TRY_CAST(freight_value AS DECIMAL(10,2)) < 0        
					 THEN 'invalid_freight_value'
						END														AS reject_reason
		INTO #cleaned_order_items
		FROM raw.order_items

		-------------------------------------------
		--  2. Rows to staging based on reject_reason -> NULL
		-------------------------------------------

		
		INSERT INTO stg.order_items
			(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value)
		SELECT
			order_id,
			order_item_id,
			product_id,
			seller_id,
			shipping_limit_date,
			price, 
			freight_value
		FROM #cleaned_order_items
		WHERE reject_reason is NULL;

		----------------------------------------------------------
		-- 3.Rows to staging based on reject_reason -> NOT NULL
		----------------------------------------------------------
		INSERT INTO stg.rejected_order_items
			(order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value, reject_reason)
		SELECT
			order_id,
			order_item_id,
			product_id,
			seller_id,
			shipping_limit_date,
			price_raw, 
			freight_value_raw,
			reject_reason
		FROM #cleaned_order_items
		WHERE reject_reason is NOT NULL;
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
	IF @@TRANCOUNT >0 ROLLBACK TRANSACTION;
	THROW;
	END CATCH
END;
GO

CREATE OR ALTER PROCEDURE stg.sp_load_products
AS
BEGIN
	SET NOCOUNT ON;
	DROP TABLE IF EXISTS #cleaned_products;
	BEGIN TRY 
		BEGIN TRANSACTION; 


		-------------------------------------------
		-- Truncating stg tables
		-------------------------------------------
		TRUNCATE TABLE stg.products;
		TRUNCATE TABLE stg.rejected_products;
		
		-------------------------------------------
		-- 1. Cleaning and validation rules
		-------------------------------------------

		SELECT 
			NULLIF(TRIM(product_id), '')										AS product_id,
			NULLIF(TRIM(product_category_name), '')								AS product_category_name,
			TRY_CAST(TRIM(product_name_lenght) AS smallint)						AS product_name_length,
			TRY_CAST(TRIM(product_description_lenght) AS smallint)				AS product_description_length,
			TRY_CAST(TRIM(product_photos_qty) AS smallint)						AS product_photos_qty,
			TRY_CAST(TRIM(product_weight_g) AS int)							AS product_weight_g,
			TRY_CAST(TRIM(product_length_cm) AS smallint)						AS product_length_cm,
			TRY_CAST(TRIM(product_height_cm) AS smallint)						AS product_height_cm,
			TRY_CAST(TRIM(product_width_cm) AS smallint)							AS product_width_cm,
			
			CASE 
				WHEN NULLIF(TRIM(product_id), '') IS NULL
					THEN 'missing_product_id'
						END														AS reject_reason
		INTO #cleaned_products
		FROM raw.products

		-------------------------------------------
		--  2. Rows to staging based on reject_reason -> NULL
		-------------------------------------------

		
		INSERT INTO stg.products
			(product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm)
		SELECT
			product_id,
			CASE WHEN product_category_name IS NULL THEN 'unknown' ELSE product_category_name END AS product_category_name,
			product_name_length,
			product_description_length,
			product_photos_qty,
			product_weight_g,
			product_length_cm,
			product_height_cm,
			product_width_cm
		FROM #cleaned_products
		WHERE reject_reason IS NULL;

		----------------------------------------------------------
		-- 3.Rows to staging based on reject_reason -> NOT NULL
		----------------------------------------------------------
		

			INSERT INTO stg.rejected_products
			(product_id, product_category_name, product_name_length, product_description_length, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm, reject_reason)
		SELECT
			product_id,
			product_category_name,
			product_name_length,
			product_description_length,
			product_photos_qty,
			product_weight_g,
			product_length_cm,
			product_height_cm,
			product_width_cm,
			reject_reason
		FROM #cleaned_products
		WHERE reject_reason IS NOT NULL;
		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
	IF @@TRANCOUNT >0 ROLLBACK TRANSACTION;
	THROW;
	END CATCH
END;
GO


CREATE OR ALTER PROCEDURE stg.sp_load_product_category_name_translation
AS
BEGIN
	SET NOCOUNT ON;
	DROP TABLE IF EXISTS #cleaned_product_category_name_translation;
	BEGIN TRY 
		BEGIN TRANSACTION; 


		-------------------------------------------
		-- Truncating stg tables
		-------------------------------------------
		TRUNCATE TABLE stg.product_category_name_translation;
		TRUNCATE TABLE stg.rejected_product_category_name_translation;
		
		-------------------------------------------
		-- 1. Cleaning and validation rules
		-------------------------------------------

		SELECT 
			NULLIF(TRIM(product_category_name), '')								AS product_category_name,
			NULLIF(TRIM(product_category_name_english), '')						AS product_category_name_english,
			CASE 
				WHEN NULLIF(TRIM(product_category_name), '') IS NULL
					THEN 'missing_product_category_name'
				WHEN NULLIF(TRIM(product_category_name_english), '') IS NULL
					THEN 'missing_product_category_name_english'
						END														AS reject_reason
		INTO #cleaned_product_category_name_translation
		FROM raw.product_category_name_translation

		-------------------------------------------
		--  2. Rows to staging based on reject_reason -> NULL
		-------------------------------------------

		
		INSERT INTO stg.product_category_name_translation
			(product_category_name, product_category_name_english)
		SELECT
			product_category_name,
			product_category_name_english
		FROM #cleaned_product_category_name_translation
		WHERE reject_reason IS NULL;

		----------------------------------------------------------
		-- 3.Rows to staging based on reject_reason -> NOT NULL
		----------------------------------------------------------
		

				
		INSERT INTO stg.rejected_product_category_name_translation
			(product_category_name, product_category_name_english, reject_reason)
		SELECT
			product_category_name,
			product_category_name_english,
			reject_reason
		FROM #cleaned_product_category_name_translation
		WHERE reject_reason IS NOT NULL;


		COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
	IF @@TRANCOUNT >0 ROLLBACK TRANSACTION;
	THROW;
	END CATCH
END;
GO



