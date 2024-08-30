DECLARE @Counter INT = 0;
DECLARE @MaxCounter INT = 6; -- Set this to the number of log backups you have
DECLARE @FilePath NVARCHAR(255);
DECLARE @SQL NVARCHAR(MAX);

-- Temporary table creation for the structure
-- Initialize the #LogData table by querying fn_dump_dblog and filtering out any data

-- Create the table schema using an empty query
SET @FilePath = N'C:\SQL_BACKUP\testbaza_logbackup' + CAST(@Counter AS NVARCHAR(10)) + N'.bak';

SET @SQL = N'
    SELECT -1 AS Iteration ,*
    INTO LogData
    FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
    DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
    DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
    DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
    DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
    DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
    WHERE 1 = 0; -- Use WHERE 1 = 0 to avoid inserting any rows
';

-- Execute the dynamic SQL to create the table schema
EXEC sp_executesql @SQL;

-- Start the loop to insert data
WHILE @Counter <= @MaxCounter
BEGIN
    -- Set the file path dynamically
    SET @FilePath = N'C:\SQL_BACKUP\testbaza_logbackup' + CAST(@Counter AS NVARCHAR(10)) + N'.bak';

    -- Build the dynamic SQL query
    SET @SQL = N'
        INSERT INTO LogData
        SELECT ' + CAST(@Counter AS NVARCHAR(10)) + ' AS Iteration, * 
        FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
        WHERE [Operation] = ''LOP_DELETE_ROWS'';
    ';

    -- Execute the dynamic SQL
    EXEC sp_executesql @SQL;

    -- Increment the counter
    SET @Counter = @Counter + 1;
END

-- Return the aggregated results
SELECT * FROM LogData;

-- Clean up
DROP TABLE LogData;