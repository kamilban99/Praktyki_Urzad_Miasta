EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

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
    -- Populate a table variable from fn_dump_dblog using the file path
    INSERT INTO @LogData (Iteration, FileName, [TRANSACTION NAME], UserName, TransactionID, BeginTime, PartitionID, TableName)
    SELECT @Iteration, @FilePath, A.[TRANSACTION NAME], A.[TRANSACTION SID], A.[Transaction ID], A.[Begin Time], B.PartitionID, @TableName
    FROM (
        SELECT [Transaction ID], [TRANSACTION NAME], [TRANSACTION SID], [Begin Time]
        FROM fn_dump_dblog(NULL, NULL, N'DISK', 1, @FilePath, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
    ) A
    JOIN (
        SELECT [Transaction ID], PartitionID
        FROM fn_dump_dblog(NULL, NULL, N'DISK', 1, @FilePath, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
    ) B ON A.[Transaction ID] = B.[Transaction ID]
    WHERE A.[TRANSACTION NAME] = @TransactionName
    AND B.PartitionID = @PartitionID;

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