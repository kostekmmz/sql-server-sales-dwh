CREATE OR ALTER PROCEDURE dwh.sp_run_pipeline
AS 
BEGIN
	SET NOCOUNT ON;
	DECLARE @run_id INT = ISNULL((SELECT MAX(run_id) FROM etl.run_log), 0) + 1;
	DECLARE @current_step VARCHAR(100), @started DATETIME2;
	--stg.sp_load_customers------------------------------
	BEGIN TRY
	SET @current_step = 'stg.sp_load_customers';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');
	EXEC stg.sp_load_customers;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM stg.customers)
	WHERE run_id = @run_id AND step_name = @current_step; 


	--stg.sp_load_orders------------------------------
	SET @current_step = 'stg.sp_load_orders';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');
	EXEC stg.sp_load_orders;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM stg.orders)
	WHERE run_id = @run_id AND step_name = @current_step; 

	--stg.sp_load_orders_items------------------------------
	SET @current_step = 'stg.sp_load_order_items';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');
	EXEC stg.sp_load_order_items;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM stg.order_items)
	WHERE run_id = @run_id AND step_name = @current_step; 


	
	--stg.sp_load_products------------------------------
	SET @current_step = 'stg.sp_load_products';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');

	EXEC stg.sp_load_products;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM stg.products)
	WHERE run_id = @run_id AND step_name = @current_step; 

		--stg.sp.load_product_category_name_translation------------------------------
	SET @current_step = 'stg.sp_load_product_category_name_translation';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');

	EXEC stg.sp_load_product_category_name_translation;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM stg.product_category_name_translation)
	WHERE run_id = @run_id AND step_name = @current_step; 


	--dwh.sp_load_products------------------------------
	SET @current_step = 'dwh.sp_load_products';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');

	EXEC dwh.sp_load_products;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM dwh.products)
	WHERE run_id = @run_id AND step_name = @current_step; 

	--dwh.sp_load_customer_scd2-----------------------------
		SET @current_step = 'dwh.sp_load_customer_scd2';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');

	EXEC dwh.sp_load_customer_scd2;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM dwh.customers)
	WHERE run_id = @run_id AND step_name = @current_step; 

	--dwh.sp_load_fact_sales----------------------------
		SET @current_step = 'dwh.sp_load_fact_sales';
	SET @started = SYSDATETIME()
	INSERT INTO etl.run_log (run_id, step_name, started_at, status)
            VALUES (@run_id, @current_step, @started, 'running');

	EXEC dwh.sp_load_fact_sales;

	UPDATE etl.run_log
	SET finished_at = SYSDATETIME(), status = 'success',
		rows_affected = (SELECT COUNT(*) FROM dwh.fact_sales)
	WHERE run_id = @run_id AND step_name = @current_step; 


END TRY
BEGIN CATCH
	UPDATE etl.run_log SET  finished_at = SYSDATETIME(), status = 'failed'
	WHERE run_id = @run_id AND step_name = @current_step;

	INSERT INTO etl.error_log
		 (run_id, step_name, error_number, error_message, error_procedure, error_line)
        VALUES
            (@run_id, @current_step, ERROR_NUMBER(), ERROR_MESSAGE(),
             ERROR_PROCEDURE(), ERROR_LINE());
	THROW; 
END CATCH
END;