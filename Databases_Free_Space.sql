SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#file_space') IS NOT NULL DROP TABLE #file_space;
CREATE TABLE #file_space
(
    database_name  sysname,
    logical_name   sysname,
    type_desc      nvarchar(60),
    physical_name  nvarchar(260),
    size_mb        decimal(18,2),
    used_mb        decimal(18,2),
    free_mb        decimal(18,2),
    free_pct       decimal(5,2),
    max_size       varchar(30)
);

DECLARE @sql nvarchar(max) = N'
USE ?;
INSERT INTO #file_space
SELECT
    DB_NAME(),
    df.name,
    df.type_desc,
    df.physical_name,
    ROUND(CAST(df.size AS bigint) * 8 / 1024.0, 2),
    ROUND(CAST(FILEPROPERTY(df.name, ''SpaceUsed'') AS bigint) * 8 / 1024.0, 2),
    ROUND((CAST(df.size AS bigint) - CAST(FILEPROPERTY(df.name, ''SpaceUsed'') AS bigint)) * 8 / 1024.0, 2),
    ROUND((CAST(df.size AS bigint) - CAST(FILEPROPERTY(df.name, ''SpaceUsed'') AS bigint)) * 100.0
        / NULLIF(CAST(df.size AS bigint), 0), 2),
    CASE df.max_size
        WHEN -1 THEN ''Unlimited''
        WHEN 0  THEN ''No growth''
        ELSE CAST(CAST(df.max_size AS bigint) * 8 / 1024 AS varchar(30)) + '' MB''
    END
FROM sys.database_files AS df;';

EXEC sp_MSforeachdb @sql;

SELECT *
FROM #file_space
ORDER BY free_mb desc, database_name, type_desc, logical_name;

DROP TABLE #file_space;