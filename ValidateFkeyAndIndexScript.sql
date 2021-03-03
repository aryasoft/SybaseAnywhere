CREATE TABLE "DB_SCHEMA"."DBA_MAINTENANCE" (
                "object_Name" "text" NULL,
                "StateScript" "text" NULL,
                "TableName" "text" NULL,
                "IsCompleted" int NOT NULL DEFAULT 0,
                "RowCount" int NOT NULL,
                "OperationDate" "datetime" NOT NULL DEFAULT CURRENT TIMESTAMP
) IN "system";

INSERT INTO "DB_SCHEMA"."DBA_MAINTENANCE" (object_Name,StateScript,TableName,IsCompleted,RowCount)
select 
    cte.object_Name, cte.StateScript, t.table_name,0,t.count
from 
    systable t
    INNER JOIN (
    select 
    f.role as object_Name, t.table_id, '0' as StateScript
    from sysforeignkey  f
    INNER JOIN systable t ON f.foreign_table_id=t.table_id
    where t.creator=103
    UNION ALL
    select 
    i.index_name as object_Name, t.table_id , '1' as StateScript
    from sysindex  i
    INNER JOIN systable t ON i.table_id=t.table_id
    where t.creator=103
    ) cte ON cte.table_id= t.table_id
WHERE
    1=1
--AND cte.StateScript='1'



DECLARE @msg varchar(255)
DECLARE
    @object_Name "text",
    @StateScript "text",
    @TableName "text",
    @IsCompleted int,
    @OperationDate "datetime",
    @RowCount int

DECLARE holding_cursor CURSOR FOR
SELECT
    object_Name,
                StateScript,
                TableName,
                IsCompleted,
                OperationDate,
    RowCount
FROM "DB_SCHEMA"."DBA_MAINTENANCE"
WHERE 
IsCompleted = 0
AND TableName<>'24846stat1'
AND TableName<>'PUR_PUR'
ORDER BY RowCount ASC

OPEN holding_cursor
fetch holding_cursor into @object_Name,@StateScript,@TableName,@IsCompleted,@OperationDate,@RowCount
WHILE (@@sqlstatus = 0)
BEGIN


if(@StateScript=1)
    BEGIN
    execute ('VALIDATE INDEX "'+@object_Name+'" ON "DB_SCHEMA"."'+@TableName+'";' )
    END

    if(@StateScript=2)
    BEGIN
    execute ('VALIDATE INDEX "DB_SCHEMA"."'+@TableName+'"."'+@object_Name+'";' )
    END

IF @@error <> 0
begin
    if(@StateScript=1)
    BEGIN
    print '2 | ALTER INDEX "'+@object_Name+'" ON "DB_SCHEMA"."'+@TableName+'" REBUILD;' 
    END

    if(@StateScript=2)
    BEGIN
    print '2 | ALTER FOREIGN KEY "'+@object_Name+'" ON "DB_SCHEMA"."'+@TableName+'" REBUILD;' 
    END
end
else
begin
    --error
     PRINT '1 | '+@TableName+' | '+@object_Name
     --PRINT @@error
     --SELECT @msg = description from sysmessages where error = @error
end


FETCH holding_cursor into @object_Name,@StateScript,@TableName,@IsCompleted,@OperationDate,@RowCount
END

CLOSE holding_cursor
DEALLOCATE holding_cursor
