USE testbaza;
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

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

-- Define the transaction name to filter
DECLARE @TransactionName NVARCHAR(255) = N'UPDATE'; -- Change this to the desired transaction name

-- Declare PartitionID variable
DECLARE @PartitionID BIGINT = 72057594046316544; -- Set this value as needed

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

-- Ensure LogData table exists before inserting data
IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'LogData' AND type = 'U')
BEGIN
    CREATE TABLE LogData (
        Iteration INT,
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
DECLARE @SQL NVARCHAR(MAX);
DECLARE @Iteration INT;

-- Set the initial iteration value
SET @Iteration = 1;

-- Cursor to iterate over file paths
DECLARE file_cursor CURSOR FOR 
SELECT FilePath FROM #LogBackupFiles;

OPEN file_cursor;

FETCH NEXT FROM file_cursor INTO @FilePath;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @PartitionID IS NULL
    BEGIN
        -- Step 1: Insert initial data into LogData when PartitionID is NULL
        SET @SQL = N'
            INSERT INTO LogData (Iteration, [TRANSACTION NAME], UserName, TransactionID, BeginTime)
            SELECT '+ CAST(@Iteration AS NVARCHAR(10)) + ',[TRANSACTION NAME], SUSER_SNAME([TRANSACTION SID]), [Transaction ID], [Begin Time]
            FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
            WHERE [TRANSACTION NAME] = N''' + @TransactionName + N''';
        ';

		PRINT @SQL;
        
        EXEC sp_executesql @SQL;

        -- Step 2: Get the TransactionID and retrieve the PartitionID for each transaction
        DECLARE @TransactionID NVARCHAR(255);
        DECLARE transaction_cursor CURSOR FOR
        SELECT TransactionID FROM LogData WHERE Iteration = @Iteration;
        
        OPEN transaction_cursor;
        FETCH NEXT FROM transaction_cursor INTO @TransactionID;
        
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Retrieve PartitionID for the specific TransactionID
            SET @SQL = N'
                SELECT @PartitionID = PartitionId 
                FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
                WHERE [Transaction ID] = N''' + @TransactionID + N''' AND Operation = ''LOP_MODIFY_ROW'';
            ';
            
            EXEC sp_executesql @SQL, N'@PartitionID BIGINT OUTPUT', @PartitionID OUTPUT;

            -- Step 3: If PartitionID is not NULL, get the table name and update LogData
            IF @PartitionID IS NOT NULL
            BEGIN
                DECLARE @TableName NVARCHAR(255);

                SELECT @TableName = so.name 
                FROM sys.objects so
                INNER JOIN sys.partitions sp ON so.object_id = sp.object_id
                WHERE partition_id = @PartitionID;

                UPDATE LogData
                SET PartitionID = @PartitionID, TableName = @TableName
                WHERE Iteration = @Iteration AND TransactionID = @TransactionID;
            END;

            FETCH NEXT FROM transaction_cursor INTO @TransactionID;
        END;

        CLOSE transaction_cursor;
        DEALLOCATE transaction_cursor;
		SET @PartitionID = NULL;
    END
    ELSE
    BEGIN
        -- When PartitionID is not NULL, perform a single query filtering by both Transaction Name and PartitionID
        SET @SQL = N'
            INSERT INTO LogData (Iteration, [TRANSACTION NAME], UserName, TransactionID, BeginTime, PartitionID)
            SELECT '+ CAST(@Iteration AS NVARCHAR(10)) + ',[TRANSACTION NAME], SUSER_SNAME([TRANSACTION SID]), [Transaction ID], [Begin Time], [PartitionID]
            FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
            
            WHERE PartitionID = ' + CAST(@PartitionID AS NVARCHAR(20)) + ';
        ';
        
		PRINT @SQL;

        EXEC sp_executesql @SQL
    END

    -- Move to the next file path
    FETCH NEXT FROM file_cursor INTO @FilePath;
    
    -- Increment the iteration counter
    SET @Iteration = @Iteration + 1;
END;

-- Close and deallocate the cursor
CLOSE file_cursor;
DEALLOCATE file_cursor;

-- Select final data from LogData
SELECT * FROM LogData;