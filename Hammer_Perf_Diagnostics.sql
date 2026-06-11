CREATE OR ALTER PROCEDURE dbo.Hammer_Perf_Diagnostics
AS
BEGIN
    SET NOCOUNT ON;

    /*===============================================================
        SQL SERVER PERFORMANCE DIAGNOSTICS TOOLKIT
        Author: Ronald’s Copilot
        Purpose: High‑signal, low‑noise performance insights
    ================================================================*/

    ---------------------------------------------------------------
    -- 1. CURRENT CPU‑HEAVY REQUESTS
    ---------------------------------------------------------------
    PRINT '1. CURRENT CPU REQUESTS';
    SELECT
        r.session_id,
        r.status,
        r.cpu_time,
        r.total_elapsed_time,
        r.logical_reads,
        r.reads,
        r.writes,
        SUBSTRING(t.text, r.statement_start_offset/2,
            (CASE WHEN r.statement_end_offset = -1
                  THEN LEN(t.text) * 2
                  ELSE r.statement_end_offset END - r.statement_start_offset)/2) AS statement_text
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    ORDER BY r.cpu_time DESC;


    ---------------------------------------------------------------
    -- 2. TOP CPU QUERIES (CACHED)
    ---------------------------------------------------------------
    PRINT '2. TOP CPU QUERIES (CACHED)';
    SELECT TOP 20
        qs.total_worker_time / 1000 AS total_cpu_ms,
        qs.execution_count,
        qs.total_worker_time / qs.execution_count AS avg_cpu,
        qs.total_elapsed_time / qs.execution_count AS avg_duration,
        SUBSTRING(st.text, (qs.statement_start_offset/2)+1,
            ((CASE qs.statement_end_offset
                WHEN -1 THEN DATALENGTH(st.text)
                ELSE qs.statement_end_offset END
                - qs.statement_start_offset)/2) + 1) AS query_text
    FROM sys.dm_exec_query_stats qs
    CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) st
    ORDER BY qs.total_worker_time DESC;


    ---------------------------------------------------------------
    -- 3. WAIT STATS (SERVER-WIDE)
    ---------------------------------------------------------------
    PRINT '3. WAIT STATS';
    SELECT TOP 20
        wait_type,
        wait_time_ms,
        signal_wait_time_ms,
        waiting_tasks_count
    FROM sys.dm_os_wait_stats
    ORDER BY wait_time_ms DESC;


    ---------------------------------------------------------------
    -- 4. TEMPDB USAGE BY SESSION
    ---------------------------------------------------------------
    PRINT '4. TEMPDB USAGE BY SESSION';
    SELECT
        s.session_id,
        s.login_name,
        tsk.internal_objects_alloc_page_count AS internal_pages,
        tsk.user_objects_alloc_page_count AS user_pages
    FROM sys.dm_db_session_space_usage tsk
    JOIN sys.dm_exec_sessions s ON tsk.session_id = s.session_id
    ORDER BY internal_pages DESC;


    ---------------------------------------------------------------
    -- 5. QUERIES CAUSING TEMPDB SPILLS
    ---------------------------------------------------------------
    PRINT '5. QUERIES CAUSING TEMPDB SPILLS';
    SELECT TOP 20
        qs.total_spills,
        qs.execution_count,
        qs.total_spills / qs.execution_count AS avg_spills,
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
    -- 6. MEMORY GRANTS (WAITING OR EXCESSIVE)
    ---------------------------------------------------------------
    PRINT '6. MEMORY GRANTS';
    SELECT
        mg.session_id,
        mg.requested_memory_kb,
        mg.granted_memory_kb,
        mg.required_memory_kb,
        mg.used_memory_kb,
        mg.wait_time_ms,
        --mg.is_next_fetch,
        t.text
    FROM sys.dm_exec_query_memory_grants mg
    CROSS APPLY sys.dm_exec_sql_text(mg.sql_handle) t
    ORDER BY mg.requested_memory_kb DESC;


    ---------------------------------------------------------------
    -- 7. INDEX USAGE (USED VS UNUSED)
    ---------------------------------------------------------------
    PRINT '7. INDEX USAGE';
    SELECT
        OBJECT_NAME(i.object_id) AS table_name,
        i.name AS index_name,
        user_seeks,
        user_scans,
        user_lookups,
        user_updates
    FROM sys.dm_db_index_usage_stats s
    JOIN sys.indexes i
        ON s.object_id = i.object_id
        AND s.index_id = i.index_id
    WHERE s.database_id = DB_ID()
    ORDER BY user_updates DESC;


    ---------------------------------------------------------------
    -- 8. MISSING INDEXES (DEDUPED)
    ---------------------------------------------------------------
    PRINT '8. MISSING INDEXES';
    SELECT TOP 20
        migs.avg_total_user_cost * migs.avg_user_impact AS improvement,
        mid.statement AS table_name,
        mid.equality_columns,
        mid.inequality_columns,
        mid.included_columns
    FROM sys.dm_db_missing_index_group_stats migs
    JOIN sys.dm_db_missing_index_groups mig ON migs.group_handle = mig.index_group_handle
    JOIN sys.dm_db_missing_index_details mid ON mig.index_handle = mid.index_handle
    ORDER BY improvement DESC;


    ---------------------------------------------------------------
    -- 9. BLOCKING SESSIONS
    ---------------------------------------------------------------
    PRINT '9. BLOCKING SESSIONS';
    SELECT
        r.session_id,
        r.status,
        r.wait_type,
        r.wait_time,
        r.blocking_session_id,
        t.text
    FROM sys.dm_exec_requests r
    CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) t
    WHERE r.blocking_session_id <> 0
    ORDER BY r.wait_time DESC;


    ---------------------------------------------------------------
    -- 10. PLAN CACHE BLOAT (AD-HOC POLLUTION)
    ---------------------------------------------------------------
    PRINT '10. PLAN CACHE BLOAT';
    SELECT
        objtype,
        COUNT(*) AS plan_count,
        SUM(size_in_bytes)/1024/1024 AS size_mb
    FROM sys.dm_exec_cached_plans
    GROUP BY objtype
    ORDER BY size_mb DESC;

END
GO
