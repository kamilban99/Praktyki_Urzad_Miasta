USE testbaza;
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

DROP TABLE IF EXISTS LogData;

-- Create LogBackupFiles table as a temporary table
IF OBJECT_ID('tempdb..#LogBackupFiles') IS NOT NULL
BEGIN
    DROP TABLE #LogBackupFiles;
END;

CREATE TABLE #LogBackupFiles (
    FileID INT IDENTITY(1,1) PRIMARY KEY, -- Auto-incrementing ID
    FilePath NVARCHAR(255)                -- Path or name of the file
);

-- Define the directory containing log backup files
DECLARE @Directory NVARCHAR(255) = N'C:\SQL_BACKUP';

-- Define input parameters
DECLARE @TransactionName NVARCHAR(255) = 'UPDATE'; -- Must
DECLARE @PartitionID BIGINT = NULL; -- Must
DECLARE @TableName NVARCHAR(128) = 'Salary'; -- Must if no partitionID
DECLARE @TransactionIDStart NVARCHAR(255) = NULL; -- Set this value as needed
DECLARE @FileName NVARCHAR(255) = NULL; -- Set this value as needed

DECLARE @TransactionID NVARCHAR(255) = NULL;

-- Build the command to list files in the directory using PowerShell
DECLARE @Command NVARCHAR(255);
DECLARE @VarcharCommand VARCHAR(255);

SET @Command = N'PowerShell -Command "Get-ChildItem -Path ''' + @Directory + ''' -Filter *.bak | ForEach-Object { $_.FullName }"';

-- Convert NVARCHAR command to VARCHAR for xp_cmdshell
SET @VarcharCommand = CAST(@Command AS VARCHAR(255));

-- Insert file paths into LogBackupFiles table
INSERT INTO #LogBackupFiles (FilePath)
EXEC xp_cmdshell @VarcharCommand;

-- Disable xp_cmdshell (Optional for security)
EXEC sp_configure 'xp_cmdshell', 0;
RECONFIGURE;

-- Disable advanced options (Optional)
EXEC sp_configure 'show advanced options', 0;
RECONFIGURE;

IF @TableName IS NOT NULL
BEGIN
	DECLARE @ObjectID INT;

	-- Get the Object ID of the table
	SELECT @ObjectID = object_id 
	FROM sys.tables 
	WHERE name = @TableName;

	-- Retrieve Partition IDs for the specific table
	SELECT @PartitionID = partition_id
	FROM sys.partitions
	WHERE object_id = @ObjectID;
END

-- Ensure LogData table exists before inserting data
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'LogData' AND type = 'U')
BEGIN
    CREATE TABLE LogData (
        Iteration INT,
        FileName NVARCHAR(255),
        [TRANSACTION NAME] NVARCHAR(255),
        UserName NVARCHAR(255),
        TransactionID NVARCHAR(255),
        BeginTime DATETIME,
        PartitionID BIGINT, -- Column for Partition ID
        TableName NVARCHAR(255) -- Column for Table Name
    );
END

DELETE FROM LogData;

-- Declare variables for cursor and iteration
DECLARE @FilePath NVARCHAR(255);
DECLARE @Iteration INT;

-- Set the initial iteration value
SET @Iteration = 1;

-- Cursor to iterate over file paths
DECLARE file_cursor CURSOR FOR 
SELECT FilePath FROM #LogBackupFiles
WHERE (@FileName IS NULL OR FilePath LIKE '%' + @FileName + '%');

OPEN file_cursor;

FETCH NEXT FROM file_cursor INTO @FilePath;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Single dynamic SQL block for all operations
    DECLARE @SQL NVARCHAR(MAX) = N'
        -- Create temporary tables for transaction and partition data
        DECLARE @PartitionIDLocal BIGINT = ' + ISNULL(CAST(@PartitionID AS NVARCHAR(20)), 'NULL') + N';
        DECLARE @TransactionNameLocal NVARCHAR(255) = ' + QUOTENAME(@TransactionName, '''') + N';
        DECLARE @TableNameLocal NVARCHAR(255) = ' + QUOTENAME(@TableName, '''') + N';
        
        SELECT * INTO #AllLogData
        FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''', 
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT);

        -- Only if there are rows
        IF EXISTS (SELECT 1 FROM #AllLogData)
        BEGIN
            -- Extract Transaction Data
            SELECT [Transaction ID] AS TransactionID, [TRANSACTION NAME] AS TransactionName, SUSER_SNAME([TRANSACTION SID]) as [UserName], [Begin Time] as [BeginTime]
            INTO #TempTransactionData
            FROM #AllLogData
            WHERE [TRANSACTION NAME] = @TransactionNameLocal AND OPERATION = ''LOP_BEGIN_XACT'';

            -- Extract Partition Data
            SELECT [Transaction ID] AS TransactionID, PartitionID
            INTO #TempPartitionData
            FROM #AllLogData
            WHERE PartitionID = @PartitionIDLocal AND OPERATION = ''LOP_MODIFY_ROW'';

            -- Insert filtered data into LogData, including the TableName
            INSERT INTO LogData (Iteration, FileName, [TRANSACTION NAME], UserName, TransactionID, BeginTime, PartitionID, TableName)
            SELECT ' + CAST(@Iteration AS NVARCHAR(10)) + ', N''' + @FilePath + ''', T.TransactionName, T.UserName, T.TransactionID, T.BeginTime, P.PartitionID, @TableNameLocal
            FROM #TempTransactionData T
            JOIN #TempPartitionData P ON T.TransactionID = P.TransactionID;

            -- Clean up
            DROP TABLE IF EXISTS #TempTransactionData;
            DROP TABLE IF EXISTS #TempPartitionData;
        END
        
        DROP TABLE IF EXISTS #AllLogData;
    ';

    -- Execute the dynamic SQL
    EXEC sp_executesql @SQL;
	PRINT @SQL;
    -- Move to the next file path
    FETCH NEXT FROM file_cursor INTO @FilePath;
    
    -- Increment the iteration counter
    SET @Iteration = @Iteration + 1;
END;

-- Close and deallocate the cursor
CLOSE file_cursor;
DEALLOCATE file_cursor;
DROP TABLE IF EXISTS #LogBackupFiles;

SELECT * FROM LogData;