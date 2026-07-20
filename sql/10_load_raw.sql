USE olist_dwh;
GO

-- Set your local data folder path before running this script
DECLARE @data_path NVARCHAR(260) = N'C:\Users\stary\sql-server-sales-dwh\data\';

DECLARE @sql NVARCHAR(MAX);

-- orders
TRUNCATE TABLE raw.orders;
SET @sql = N'
BULK INSERT raw.orders
FROM ''' + @data_path + N'olist_orders_dataset.csv''
WITH (
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    FORMAT = ''CSV''
);';
EXEC sp_executesql @sql;

-- customers
TRUNCATE TABLE raw.customers;
SET @sql = N'
BULK INSERT raw.customers
FROM ''' + @data_path + N'olist_customers_dataset.csv''
WITH (
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    FORMAT = ''CSV''
);';
EXEC sp_executesql @sql;

-- order_items
TRUNCATE TABLE raw.order_items;
SET @sql = N'
BULK INSERT raw.order_items
FROM ''' + @data_path + N'olist_order_items_dataset.csv''
WITH (
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    FORMAT = ''CSV''
);';
EXEC sp_executesql @sql;

-- products
TRUNCATE TABLE raw.products;
SET @sql = N'
BULK INSERT raw.products
FROM ''' + @data_path + N'olist_products_dataset.csv''
WITH (
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    FORMAT = ''CSV''
);';
EXEC sp_executesql @sql;

-- product_category_name_translation
TRUNCATE TABLE raw.product_category_name_translation;
SET @sql = N'
BULK INSERT raw.product_category_name_translation
FROM ''' + @data_path + N'product_category_name_translation.csv''
WITH (
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    FIRSTROW = 2,
    FIELDQUOTE = ''"'',
    CODEPAGE = ''65001'',
    FORMAT = ''CSV''
);';
EXEC sp_executesql @sql;
