EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

-- Define the directory containing log backup files
DECLARE @Directory NVARCHAR(255) = N'C:\SQL_BACKUP';

-- Define input parameters
DECLARE @TransactionName NVARCHAR(255) = 'UPDATE'; -- Must
DECLARE @PartitionID BIGINT = 72057594046316544; -- Must
DECLARE @FileName NVARCHAR(255) = NULL; -- Set this value as needed

--- Unavailable now
DECLARE @TableName NVARCHAR(128) = NULL; -- Doesnt work anymore
DECLARE @TransactionIDStart NVARCHAR(255) = NULL; -- Set this value as needed (doesnt work right now_


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

/* --doesnt work right now\
-- Get Object ID for the table if a table name is provided
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
*/
-- Declare @LogData as a table variable
DECLARE @LogData TABLE (
    Iteration INT,
    FileName NVARCHAR(255),
    [TRANSACTION NAME] NVARCHAR(255),
    UserName VARBINARY(85),
    TransactionID NVARCHAR(255),
    BeginTime DATETIME,
    PartitionID BIGINT, 
    TableName NVARCHAR(255)
);

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
    UserName VARBINARY(85),
    BeginTime DATETIME
);

DECLARE @TempPartitionData TABLE (
    TransactionID NVARCHAR(255),
    PartitionID BIGINT
);

-- Declare variables for cursor and iteration
DECLARE @FilePath NVARCHAR(255);
DECLARE @Iteration INT = 1;

-- Cursor to iterate over file paths
DECLARE file_cursor CURSOR FOR 
SELECT FilePath FROM @LogBackupFiles
WHERE (@FileName IS NULL OR FilePath LIKE '%' + @FileName + '%');

OPEN file_cursor;

FETCH NEXT FROM file_cursor INTO @FilePath;

WHILE @@FETCH_STATUS = 0
BEGIN
    -- Clear the temporary table variables before each iteration
    DELETE FROM @TempTransactionData;
    DELETE FROM @TempPartitionData;
	DELETE FROM @AllLogData;

	 INSERT INTO @AllLogData ([Transaction ID], [TRANSACTION NAME], [TRANSACTION SID], [Begin Time], OPERATION, PartitionID)
     SELECT [Transaction ID], [Transaction Name], [Transaction SID], [Begin Time], [Operation], [PartitionId]
     FROM fn_dump_dblog(NULL, NULL, N'DISK', 1, @FilePath, 
     DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
     DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
     DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
     DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
     DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT);

     IF EXISTS (SELECT 1 FROM @AllLogData)
        BEGIN
            -- Extract Transaction Data
            INSERT INTO @TempTransactionData (TransactionID, TransactionName, UserName, BeginTime)
            SELECT [Transaction ID], [TRANSACTION NAME], [TRANSACTION SID], [Begin Time]
            FROM @AllLogData
            WHERE [TRANSACTION NAME] = @TransactionName AND OPERATION = 'LOP_BEGIN_XACT';

            -- Extract Partition Data
            INSERT INTO @TempPartitionData (TransactionID, PartitionID)
            SELECT [Transaction ID], PartitionID
            FROM @AllLogData
            WHERE PartitionID = @PartitionID AND OPERATION = 'LOP_MODIFY_ROW';


            -- Insert filtered data into LogData, including the TableName
            INSERT INTO @LogData (Iteration, FileName, [TRANSACTION NAME], UserName, TransactionID, BeginTime, PartitionID, TableName)
            SELECT @Iteration, @FilePath, T.TransactionName, T.UserName, T.TransactionID, T.BeginTime, P.PartitionID, @TableName
            FROM @TempTransactionData T
            JOIN @TempPartitionData P ON T.TransactionID = P.TransactionID;
        END

    -- Move to the next file path
    FETCH NEXT FROM file_cursor INTO @FilePath;
    
    -- Increment the iteration counter
    SET @Iteration = @Iteration + 1;
END;

-- Close and deallocate the cursor
CLOSE file_cursor;
DEALLOCATE file_cursor;

-- Select the data from the @LogData table variable
SELECT * FROM @LogData;
