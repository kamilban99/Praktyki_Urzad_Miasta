EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

DROP TABLE IF EXISTS LogData;

-- Define the directory containing log backup files
DECLARE @Directory NVARCHAR(255) = N'C:\SQL_BACKUP';

-- Define input parameters
DECLARE @TransactionName NVARCHAR(255) = 'UPDATE'; -- Must
DECLARE @PartitionID BIGINT = NULL; -- Must
DECLARE @TableName NVARCHAR(128) = 'Salary'; -- Must if no partitionID
DECLARE @TransactionIDStart NVARCHAR(255) = NULL; -- Set this value as needed
DECLARE @FileName NVARCHAR(255) = NULL; -- Set this value as needed

DECLARE @TransactionID NVARCHAR(255) = NULL;

-- Create table variable for storing file paths
DECLARE @LogBackupFiles TABLE (
    FileID INT IDENTITY(1,1) PRIMARY KEY, -- Auto-incrementing ID
    FilePath NVARCHAR(255)                -- Path or name of the file
);

-- Build the command to list files in the directory using PowerShell
DECLARE @Command NVARCHAR(255);
DECLARE @VarcharCommand VARCHAR(255);

SET @Command = N'PowerShell -Command "Get-ChildItem -Path ''' + @Directory + ''' -Filter *.bak | ForEach-Object { $_.FullName }"';

-- Convert NVARCHAR command to VARCHAR for xp_cmdshell
SET @VarcharCommand = CAST(@Command AS VARCHAR(255));

-- Insert file paths into @LogBackupFiles table variable
INSERT INTO @LogBackupFiles (FilePath)
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
        UserName varbinary(85),
        TransactionID NVARCHAR(255),
        BeginTime DATETIME,
        PartitionID BIGINT, 
        TableName NVARCHAR(255)
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
SELECT FilePath FROM @LogBackupFiles
WHERE (@FileName IS NULL OR FilePath LIKE '%' + @FileName + '%');

OPEN file_cursor;

FETCH NEXT FROM file_cursor INTO @FilePath;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Single dynamic SQL block for all operations
    DECLARE @SQL NVARCHAR(MAX) = N'
        -- Create table variables for transaction and partition data
        DECLARE @AllLogData TABLE (
            [Transaction ID] NVARCHAR(255),
            [TRANSACTION NAME] NVARCHAR(255),
            [TRANSACTION SID] varbinary(85),
            [Begin Time] DATETIME,
            OPERATION NVARCHAR(255),
            PartitionID BIGINT
        );

        DECLARE @TempTransactionData TABLE (
            TransactionID NVARCHAR(255),
            TransactionName NVARCHAR(255),
            UserName varbinary(85),
            BeginTime DATETIME
        );

        DECLARE @TempPartitionData TABLE (
            TransactionID NVARCHAR(255),
            PartitionID BIGINT
        );

        -- Populate @AllLogData from fn_dump_dblog
        INSERT INTO @AllLogData ([Transaction ID], [TRANSACTION NAME], [TRANSACTION SID], [Begin Time], OPERATION, PartitionID)
        SELECT [Transaction ID], [Transaction Name], [Transaction SID], [Begin Time], [Operation], [PartitionId]
        FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''', 
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
        DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT);

        -- Only if there are rows
        IF EXISTS (SELECT 1 FROM @AllLogData)
        BEGIN
            -- Extract Transaction Data
            INSERT INTO @TempTransactionData (TransactionID, TransactionName, UserName, BeginTime)
            SELECT [Transaction ID], [TRANSACTION NAME], [TRANSACTION SID], [Begin Time]
            FROM @AllLogData
            WHERE [TRANSACTION NAME] = @TransactionNameLocal AND OPERATION = ''LOP_BEGIN_XACT'';

            -- Extract Partition Data
            INSERT INTO @TempPartitionData (TransactionID, PartitionID)
            SELECT [Transaction ID], PartitionID
            FROM @AllLogData
            WHERE PartitionID = @PartitionIDLocal AND OPERATION = ''LOP_MODIFY_ROW'';

            -- Insert filtered data into LogData, including the TableName
            INSERT INTO LogData (Iteration, FileName, [TRANSACTION NAME], UserName, TransactionID, BeginTime, PartitionID, TableName)
            SELECT ' + CAST(@Iteration AS NVARCHAR(10)) + ', N''' + @FilePath + ''', T.TransactionName, T.UserName, T.TransactionID, T.BeginTime, P.PartitionID, @TableNameLocal
            FROM @TempTransactionData T
            JOIN @TempPartitionData P ON T.TransactionID = P.TransactionID;
        END
    ';

    -- Execute the dynamic SQL
    EXEC sp_executesql @SQL, 
         N'@TransactionNameLocal NVARCHAR(255), @PartitionIDLocal BIGINT, @TableNameLocal NVARCHAR(255)',
         @TransactionName, @PartitionID, @TableName;

    -- Move to the next file path
    FETCH NEXT FROM file_cursor INTO @FilePath;
    
    -- Increment the iteration counter
    SET @Iteration = @Iteration + 1;
END;

-- Close and deallocate the cursor
CLOSE file_cursor;
DEALLOCATE file_cursor;

SELECT * FROM LogData;
DROP TABLE LogData;
