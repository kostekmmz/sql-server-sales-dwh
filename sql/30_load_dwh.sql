CREATE OR ALTER PROCEDURE dwh.sp_load_customer_scd2
AS 
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;
		--Close record that has changed
		UPDATE d 
		SET d.valid_to = DATEADD(DAY, -1, CAST(GETDATE() AS DATE)),
			d.is_current = 0 
		FROM dwh.customers d 
		JOIN stg.customers s ON d.customer_id = s.customer_id
		WHERE d.is_current = 1 
		AND valid_from < CAST(GETDATE() AS DATE) -- Catching cases, where valid_from is earlier than today 
		AND (
			ISNULL(s.customer_zip_code_prefix, '') <> ISNULL(d.customer_zip_code_prefix, '')
		OR	ISNULL(s.customer_city, '') <> ISNULL(d.customer_city, '')
	    OR 	ISNULL(s.customer_state, '') <> ISNULL(d.customer_state, '')
		);

		UPDATE d
		SET 
			d.customer_zip_code_prefix = s.customer_zip_code_prefix,
			d.customer_city = s.customer_city,
			d.customer_state = s.customer_state,
			d.loaded_at = s.loaded_at
		FROM dwh.customers d
		JOIN stg.customers s ON d.customer_id = s.customer_id
		WHERE d.is_current = 1 
		AND valid_from = CAST(GETDATE() AS DATE)
		AND (
			ISNULL(s.customer_zip_code_prefix, '') <> ISNULL(d.customer_zip_code_prefix, '')
		OR	ISNULL(s.customer_city, '') <> ISNULL(d.customer_city, '')
		OR	ISNULL(s.customer_state, '') <> ISNULL(d.customer_state, '')
		);


	  INSERT INTO dwh.customers 
			(customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state, valid_from, valid_to, is_current)
	  SELECT
		s.customer_id,
		s.customer_unique_id,
		s.customer_zip_code_prefix,
		s.customer_city,
		s.customer_state,
		CAST(GETDATE() AS DATE),
		'9999-12-31',
		1
	  FROM stg.customers s
	  WHERE NOT EXISTS ( 
		SELECT 1 FROM dwh.customers d 
		WHERE d.customer_id = s.customer_id AND d.is_current = 1
	  );
	COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH
END;
GO

CREATE OR ALTER PROCEDURE dwh.sp_load_products
AS
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;
			MERGE INTO dwh.products AS TARGET
			USING 
				(
					
					SELECT 
						product_id,
						product_category_name,
						product_name_length,
						product_description_length,
						product_photos_qty,
						product_weight_g,
						product_length_cm,
						product_height_cm,
						product_width_cm
					FROM stg.products
				) AS SOURCE
				ON target.product_id = source.product_id
			WHEN MATCHED AND ( 
				ISNULL(target.product_category_name, '') <> ISNULL(source.product_category_name, '')
			 OR ISNULL(target.product_weight_g, -1) <> ISNULL(source.product_weight_g, -1)
			 OR ISNULL(target.product_length_cm, -1) <> ISNULL(source.product_length_cm, -1)
			 OR ISNULL(target.product_height_cm, -1) <> ISNULL(source.product_height_cm, -1)
			 OR ISNULL(target.product_width_cm, -1)  <> ISNULL(source.product_width_cm, -1)
			) THEN UPDATE SET
				target.product_category_name = source.product_category_name,
				target.product_name_length = source.product_name_length,
				target.product_description_length = source.product_description_length,
				target.product_photos_qty = source.product_photos_qty,
				target.product_weight_g = source.product_weight_g,
				target.product_length_cm = source.product_length_cm,
				target.product_height_cm = source.product_height_cm,
				target.product_width_cm = source.product_width_cm
			WHEN NOT MATCHED BY TARGET THEN
				INSERT(product_id, product_category_name, product_name_length, product_description_length, product_photos_qty,product_weight_g, product_length_cm,product_height_cm,
						product_width_cm)
				VALUES(source.product_id, source.product_category_name, source.product_name_length, source.product_description_length, source.product_photos_qty,source.product_weight_g, source.product_length_cm,source.product_height_cm,
						source.product_width_cm);
	COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
	IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
	THROW;
	END CATCH
END;
GO


CREATE OR ALTER PROCEDURE dwh.sp_load_fact_sales
AS 
BEGIN
	SET NOCOUNT ON;
	BEGIN TRY
		BEGIN TRANSACTION;

			INSERT INTO dwh.fact_sales
				(date_key, customer_key, product_key, order_id, order_item_id, order_status,
				 price, freight_value, seller_id)
			SELECT
				YEAR(o.order_purchase_timestamp) * 10000 + MONTH(o.order_purchase_timestamp) * 100 + DAY(o.order_purchase_timestamp),
				dc.customer_key,          
				dp.product_key,           
				o.order_id,
				oi.order_item_id,
				o.order_status,
				oi.price,
				oi.freight_value,
				oi.seller_id
			FROM stg.orders o                        
			JOIN stg.order_items oi ON o.order_id = oi.order_id
			JOIN dwh.customers dc
				ON dc.customer_id = o.customer_id
			   AND dc.is_current = 1                  
			JOIN dwh.products dp
				ON dp.product_id = oi.product_id
			WHERE NOT EXISTS (
				SELECT 1 FROM dwh.fact_sales f
				WHERE f.order_id = o.order_id
				AND f.order_item_id = oi.order_item_id
			);

	
				INSERT INTO dwh.rejected_facts
				(date_key, customer_key, product_key, order_id, order_item_id, order_status, reject_reason)
					SELECT
					YEAR(o.order_purchase_timestamp) * 10000 + MONTH(o.order_purchase_timestamp) * 100 + DAY(o.order_purchase_timestamp),
									dc.customer_key, 
									dp.product_key,           
									oi.order_id,
									oi.order_item_id,
									o.order_status,
					CASE WHEN dp.product_key IS NULL THEN 'unknown product' 
							WHEN dc.customer_key IS NULL THEN 'unknown customer' 
							END AS reject_reason
					FROM olist_dwh.stg.order_items  oi
					JOIN olist_dwh.stg.orders o ON oi.order_id = o.order_id
					LEFT JOIN olist_dwh.dwh.products dp ON dp.product_id = oi.product_id
					LEFT JOIN olist_dwh.dwh.customers dc ON dc.customer_id = o.customer_id and dc.is_current = 1 
					WHERE (dp.product_key IS NULL 
					OR dc.customer_key IS NULL)
					  AND NOT EXISTS (
							SELECT 1 FROM dwh.rejected_facts r
							WHERE r.order_id = oi.order_id AND r.order_item_id = oi.order_item_id
  );
			
				COMMIT TRANSACTION;
	END TRY
	BEGIN CATCH
		IF @@TRANCOUNT > 0 ROLLBACK TRANSACTION;
		THROW;
	END CATCH
END;
GO