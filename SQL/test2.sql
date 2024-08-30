DECLARE @TableName NVARCHAR(128) = 'Employee';
DECLARE @ObjectID INT;

-- Get the Object ID of the table
SELECT @ObjectID = object_id 
FROM sys.tables 
WHERE name = @TableName;

-- Retrieve Partition IDs for the specific table
SELECT partition_id
FROM sys.partitions
WHERE object_id = @ObjectID;