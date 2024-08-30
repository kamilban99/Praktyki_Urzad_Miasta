USE testbaza
SELECT so.name 
FROM sys.objects so
INNER JOIN sys.partitions sp on so.object_id = sp.object_id
WHERE partition_id = 72057594046316544

declare @uid VARBINARY(85) = 0x010500000000000515000000E0F6C28CEBF2429A7F24B9FFEA030000

SELECT SUSER_SNAME(@uid)
GO