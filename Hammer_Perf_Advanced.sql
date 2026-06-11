CREATE OR ALTER PROCEDURE dbo.Hammer_Perf_Advanced
AS
BEGIN
    SET NOCOUNT ON;

    /*===============================================================
        ADVANCED SQL SERVER PERFORMANCE DIAGNOSTICS (VERSION SAFE)
    ================================================================*/

    ---------------------------------------------------------------
    -- 1. PARAMETER SNIFFING DETECTION
    ---------------------------------------------------------------
    PRINT '1. PARAMETER SNIFFING DETECTION';
    SELECT TOP 20
        qs.min_rows,
        qs.max_rows,
        qs.last_rows,
        qs.total_rows,
        qs.execution_count,
        ABS(qs.max_rows - qs.min_rows) AS row_variance,
        SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
            ((CASE qs.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset END
                - qs.statement_start_offset)/2) + 1) AS query_text
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    ORDER BY row_variance DESC;


    ---------------------------------------------------------------
    -- 2. BAD CARDINALITY ESTIMATES
    ---------------------------------------------------------------
    PRINT '2. BAD CARDINALITY ESTIMATES';
    SELECT TOP 20
        qs.last_rows,
        qs.last_logical_reads,
        qs.last_worker_time,
        qs.last_elapsed_time,
        SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
            ((CASE qs.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset END
                - qs.statement_start_offset)/2) + 1) AS query_text
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE qs.last_rows > 100000 AND qs.last_logical_reads < 1000
    ORDER BY qs.last_rows DESC;


    ---------------------------------------------------------------
    -- 3. HIGH RECOMPILE QUERIES (VERSION SAFE)
    -- SQL Server versions before 2016 do NOT expose recompile counters.
    -- So we detect recompiles by looking for OPTION(RECOMPILE) in the plan.
    ---------------------------------------------------------------
    PRINT '3. HIGH RECOMPILE QUERIES';
    SELECT TOP 20
        SUBSTRING(t.text, 1, 4000) AS query_text,
        qp.query_plan
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
    WHERE CAST(qp.query_plan AS NVARCHAR(MAX)) LIKE '%RECOMPILE%'
    ORDER BY qs.total_worker_time DESC;


    ---------------------------------------------------------------
    -- 4. IMPLICIT CONVERSIONS (FIXED XML LIKE)
    ---------------------------------------------------------------
    PRINT '4. IMPLICIT CONVERSIONS';
    SELECT 
        t.text,
        qp.query_plan
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
    CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
    WHERE CAST(qp.query_plan AS NVARCHAR(MAX)) LIKE '%CONVERT_IMPLICIT%';


    ---------------------------------------------------------------
    -- 5. MISSING STATISTICS
    ---------------------------------------------------------------
    PRINT '5. MISSING STATISTICS';
    SELECT 
        OBJECT_NAME(s.object_id) AS table_name,
        s.name AS stat_name
    FROM sys.stats s
    WHERE STATS_DATE(s.object_id, s.stats_id) IS NULL;


    ---------------------------------------------------------------
    -- 6. OUT-OF-DATE STATISTICS
    ---------------------------------------------------------------
    PRINT '6. OUT-OF-DATE STATISTICS';
    SELECT 
        OBJECT_NAME(s.object_id) AS table_name,
        s.name AS stat_name,
        STATS_DATE(s.object_id, s.stats_id) AS last_updated
    FROM sys.stats s
    ORDER BY last_updated;


    ---------------------------------------------------------------
    -- 7. SPILLS (SORT/HASH)
    ---------------------------------------------------------------
    PRINT '7. SPILLS (SORT/HASH)';
    SELECT TOP 20
        qs.total_spills,
        qs.last_spills,
        qs.execution_count,
        SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
            ((CASE qs.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset END
                - qs.statement_start_offset)/2) + 1) AS query_text
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    WHERE qs.total_spills > 0
    ORDER BY qs.total_spills DESC;


    ---------------------------------------------------------------
    -- 8. BLOCKING
    ---------------------------------------------------------------
    PRINT '8. BLOCKING SESSIONS';
    SELECT
        r.session_id,
        r.blocking_session_id,
        r.wait_type,
        r.wait_time,
        t.text
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.blocking_session_id <> 0
    ORDER BY r.wait_time DESC;


    ---------------------------------------------------------------
    -- 9. SCALAR UDF HOTSPOTS (VERSION SAFE)
    ---------------------------------------------------------------
    PRINT '9. SCALAR UDF HOTSPOTS';
    SELECT TOP 20
        SUBSTRING(t.text, 1, 200) AS udf_text,
        qs.total_worker_time,
        qs.execution_count,
        qs.total_worker_time / qs.execution_count AS avg_cpu
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) t
    WHERE t.text LIKE '%FUNCTION%'
    ORDER BY qs.total_worker_time DESC;


    ---------------------------------------------------------------
    -- 10. BAD INDEXES
    ---------------------------------------------------------------
    PRINT '10. BAD INDEXES';
    SELECT
        OBJECT_NAME(i.object_id) AS table_name,
        i.name AS index_name,
        user_updates AS writes,
        user_seeks + user_scans + user_lookups AS reads
    FROM sys.dm_db_index_usage_stats s
    JOIN sys.indexes i
        ON s.object_id = i.object_id
        AND s.index_id = i.index_id
    WHERE s.database_id = DB_ID()
    ORDER BY writes DESC;

END
GO
