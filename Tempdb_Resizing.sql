/* 
1. Pick a quiet window
Shrink only works if the space is actually free. Open transactions, running sorts/hashes, version store, 
and temp objects all pin space. Check what's using it first:
*/
SELECT
    SUM(user_object_reserved_page_count)     * 8 / 1024 AS user_obj_mb,
    SUM(internal_object_reserved_page_count) * 8 / 1024 AS internal_obj_mb,
    SUM(version_store_reserved_page_count)   * 8 / 1024 AS version_store_mb,
    SUM(unallocated_extent_page_count)       * 8 / 1024 AS free_mb
FROM tempdb.sys.dm_db_file_space_usage;

-- Active Transactions
SELECT
    name,
    size/128.0 AS SizeMB,
    FILEPROPERTY(name,'SpaceUsed')/128.0 AS UsedMB
FROM tempdb.sys.database_files;

-- Who is holding version store?
SELECT
    transaction_id,
    session_id,
    elapsed_time_seconds,
    is_snapshot,
    first_snapshot_sequence_num
FROM sys.dm_tran_active_snapshot_database_transactions
ORDER BY elapsed_time_seconds DESC;

DBCC OPENTRAN;

-- Flush the caches that hold tempdb pages

DBCC FREEPROCCACHE;      -- drops cached plans
DBCC DROPCLEANBUFFERS;   -- drops clean buffer pages
DBCC FREESYSTEMCACHE ('ALL');   -- releases cache entries, incl. temp table cache


/* Dynamic */
USE tempdb;
GO

SET NOCOUNT ON;

DECLARE @target_data_mb int = 8192;   -- desired size per DATA file
DECLARE @target_log_mb  int = 1024;   -- desired size for the LOG file

DECLARE @sql        nvarchar(max) = N'',
        @name       sysname,
        @type_desc  nvarchar(60),
        @cur_mb     int,
        @target_mb  int;

DECLARE file_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT name, type_desc, CAST(size AS bigint) * 8 / 1024
    FROM tempdb.sys.database_files
    ORDER BY type_desc, file_id;

OPEN file_cur;
FETCH NEXT FROM file_cur INTO @name, @type_desc, @cur_mb;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @target_mb = CASE WHEN @type_desc = 'LOG' THEN @target_log_mb ELSE @target_data_mb END;

    IF @cur_mb > @target_mb
    BEGIN
        IF @type_desc = 'LOG' CHECKPOINT;

        SET @sql = N'DBCC SHRINKFILE (' + QUOTENAME(@name) + N', ' + CONVERT(nvarchar(20), @target_mb) + N');';
        PRINT @sql + N'   -- current: ' + CONVERT(nvarchar(20), @cur_mb) + N' MB';
        EXEC sys.sp_executesql @sql;
    END
    ELSE
        PRINT N'-- skipping ' + QUOTENAME(@name) + N' (' + CONVERT(nvarchar(20), @cur_mb)
              + N' MB <= target ' + CONVERT(nvarchar(20), @target_mb) + N' MB)';

    FETCH NEXT FROM file_cur INTO @name, @type_desc, @cur_mb;
END

CLOSE file_cur;
DEALLOCATE file_cur;


USE tempdb;
GO
DBCC SHRINKFILE (tempdev, 8192);   -- target size in MB, per data file
DBCC SHRINKFILE (templog, 1024);


/* Dynamic */

USE master;
GO

SET NOCOUNT ON;

DECLARE @target_data_mb  int = 8192;   -- desired SIZE per DATA file
DECLARE @growth_data_mb  int = 512;    -- desired FILEGROWTH per DATA file
DECLARE @target_log_mb   int = 1024;   -- desired SIZE for the LOG file
DECLARE @growth_log_mb   int = 256;    -- desired FILEGROWTH for the LOG file

DECLARE @sql        nvarchar(max) = N'',
        @name       sysname,
        @type_desc  nvarchar(60),
        @size_mb    int,
        @growth_mb  int;

DECLARE file_cur CURSOR LOCAL FAST_FORWARD FOR
    SELECT name, type_desc
    FROM tempdb.sys.database_files
    ORDER BY type_desc, file_id;

OPEN file_cur;
FETCH NEXT FROM file_cur INTO @name, @type_desc;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @size_mb   = CASE WHEN @type_desc = 'LOG' THEN @target_log_mb ELSE @target_data_mb END;
    SET @growth_mb = CASE WHEN @type_desc = 'LOG' THEN @growth_log_mb ELSE @growth_data_mb END;

    SET @sql = N'ALTER DATABASE tempdb MODIFY FILE (NAME = ' + QUOTENAME(@name)
             + N', SIZE = ' + CONVERT(nvarchar(20), @size_mb) + N'MB'
             + N', FILEGROWTH = ' + CONVERT(nvarchar(20), @growth_mb) + N'MB);';

    PRINT @sql;
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM file_cur INTO @name, @type_desc;
END

CLOSE file_cur;
DEALLOCATE file_cur;




ALTER DATABASE tempdb MODIFY FILE (NAME = tempdev,  SIZE = 8192MB, FILEGROWTH = 512MB);
ALTER DATABASE tempdb MODIFY FILE (NAME = templog,  SIZE = 1024MB, FILEGROWTH = 256MB);
-- repeat for every tempdb data file; keep all data files equal in size and growth



-- Welke databases gebruiken snapshot of RCSI
SELECT
    name,
    snapshot_isolation_state_desc,
    is_read_committed_snapshot_on
FROM sys.databases
WHERE snapshot_isolation_state <> 0
   OR is_read_committed_snapshot_on = 1;

