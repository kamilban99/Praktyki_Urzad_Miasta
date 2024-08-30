USE testbaza;
EXEC sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sp_configure 'xp_cmdshell', 1;
RECONFIGURE;

DROP TABLE LogData;

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
DECLARE @TransactionName NVARCHAR(255) = 'UPDATE'; -- Set this value as needed
DECLARE @PartitionID BIGINT = NULL; -- Set this value as needed
DECLARE @TableName NVARCHAR(128) = 'Salary'; -- Set this value as needed
DECLARE @TransactionIDStart NVARCHAR(255) = NULL; -- Set this value as needed
DECLARE @FileName NVARCHAR(255) = 'C:\SQL_BACKUP\testbaza_logbackup5.bak'; -- Set this value as needed

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
		FileName NVARCHAR(255) ,
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
SELECT FilePath FROM #LogBackupFiles
WHERE (@FileName IS NULL OR FilePath LIKE '%' + @FileName + '%');

OPEN file_cursor;

FETCH NEXT FROM file_cursor INTO @FilePath;

WHILE @@FETCH_STATUS = 0
BEGIN
    IF @PartitionID IS NULL
    BEGIN
        -- Step 1: Insert initial data into LogData when PartitionID is NULL
        SET @SQL = N'
            INSERT INTO LogData (Iteration, FileName, [TRANSACTION NAME], UserName, TransactionID, BeginTime)
            SELECT '+ CAST(@Iteration AS NVARCHAR(10)) + ', N''' + @FilePath + ''',[TRANSACTION NAME], SUSER_SNAME([TRANSACTION SID]), [Transaction ID], [Begin Time]
            FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
            WHERE 1 = 1' +
            CASE 
                WHEN @TransactionName IS NOT NULL THEN ' AND [TRANSACTION NAME] = N''' + @TransactionName + ''''
                ELSE ''
            END + 
            CASE 
                WHEN @TransactionIDStart IS NOT NULL THEN ' AND [Transaction ID] = N''' + @TransactionIDStart + ''''
                ELSE ''
            END + ';
        ';
        
        PRINT @SQL;

        EXEC sp_executesql @SQL;
		IF @TransactionIDStart IS NULL
		BEGIN
			-- Step 2: Get the TransactionID and retrieve the PartitionID for each transaction
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
					WHERE [Transaction ID] = N''' + @TransactionID + ''' AND Operation = ''LOP_MODIFY_ROW'';
				';
            
				PRINT @SQL;
            
				EXEC sp_executesql @SQL, N'@PartitionID BIGINT OUTPUT', @PartitionID OUTPUT;
				PRINT @PartitionID;

				-- Step 3: If PartitionID is not NULL, get the table name and update LogData
				IF @PartitionID IS NOT NULL
				BEGIN

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
			SET @TransactionID = NULL;
		END
	END
    ELSE
    BEGIN
        -- When PartitionID is not NULL, perform a single query filtering by both Transaction Name and PartitionID
        SET @SQL = N'
            INSERT INTO LogData (Iteration, FileName, [TRANSACTION NAME], UserName, TransactionID, BeginTime, PartitionID)
            SELECT '+ CAST(@Iteration AS NVARCHAR(10)) + ', N''' + @FilePath + ''',[TRANSACTION NAME], SUSER_SNAME([TRANSACTION SID]), [Transaction ID], [Begin Time], [PartitionID]
            FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
            DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
            WHERE 1 = 1' + 
            CASE 
                WHEN @TransactionIDStart IS NOT NULL THEN ' AND [Transaction ID] = N''' + @TransactionIDStart + ''''
                ELSE ''
            END + 
            CASE 
                WHEN @PartitionID IS NOT NULL THEN ' AND PartitionID = ' + CAST(@PartitionID AS NVARCHAR(20))
                ELSE ''
            END + ';
        ';
        
        PRINT @SQL;

        EXEC sp_executesql @SQL;
		IF @TransactionIDStart IS NULL
		BEGIN
		-- Step 2: Get the TransactionID and retrieve the PartitionID for each transaction
        DECLARE transaction_cursor CURSOR FOR
        SELECT TransactionID FROM LogData WHERE Iteration = @Iteration;
        
        OPEN transaction_cursor;
        FETCH NEXT FROM transaction_cursor INTO @TransactionID;
        
		DECLARE @Username nVarchar(255);
		DECLARE @BeginTime nVarchar(255);
        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- Retrieve Username, Transaction name and BeginTime for the specific TransactionID
            SET @SQL = N'
                SELECT @Username = SUSER_SNAME([TRANSACTION SID]), @TransactionName = [Transaction Name], @BeginTime = [Begin Time]   
                FROM fn_dump_dblog(NULL, NULL, N''DISK'', 1, N''' + @FilePath + N''',
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT,
                DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT, DEFAULT)
                WHERE [Transaction ID] = N''' + @TransactionID + ''' AND Operation = ''LOP_BEGIN_XACT'';
            ';
            
            PRINT @SQL;
			EXEC sp_executesql @SQL, 
				N'@Username NVARCHAR(255) OUTPUT, @TransactionName NVARCHAR(255) OUTPUT, @BeginTime DATETIME OUTPUT',
				@Username OUTPUT, @TransactionName OUTPUT, @BeginTime OUTPUT;
			PRINT 'USERNAME is' + CAST(@Username as nVarchar(255));
			UPDATE LogData
               SET UserName = @Username, [TRANSACTION NAME] = @TransactionName, BeginTime = @BeginTime
               WHERE Iteration = @Iteration AND TransactionID = @TransactionID;
			FETCH NEXT FROM transaction_cursor INTO @TransactionID;
		END;
		
		
    END
	CLOSE transaction_cursor;
    DEALLOCATE transaction_cursor;
    -- Move to the next file path
    END
	FETCH NEXT FROM file_cursor INTO @FilePath;
    
    -- Increment the iteration counter
    SET @Iteration = @Iteration + 1;
END;

-- Close and deallocate the cursor
CLOSE file_cursor;
DEALLOCATE file_cursor;
DROP TABLE #LogBackupFiles;

-- Select final data from LogData
IF @TransactionName IS NULL
BEGIN
	SELECT * FROM LogData;
END
ELSE
BEGIN
	SELECT * FROM LogData WHERE [TRANSACTION NAME] = @TransactionName
END