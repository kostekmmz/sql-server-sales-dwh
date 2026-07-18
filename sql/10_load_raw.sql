-- Set your local data folder path before runninng this script
DECLARE @data_path NVARCHAR(260) = N'C:\Users\stary\sql-server-sales-dwh\data';

DECLARE @sql NVARCHAR(MAX);


SET @sql = N'
BULK INSERT raw.orders
FROM ''' +@data_path +N'olist_order_dataset.csv''
WITH (
    FIELDTERMINATOR = '','',
    ROWTERMINATOR = ''0x0a'',
    FIRSTROW = 2,
    CODEPAGE = ''65001'',
    FORMAT = ''CSV''
);';
EXEC sp_executesql @sql;

