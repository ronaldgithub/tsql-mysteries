/*==============================================================================
    BlockWatch - capture the blocked process report to a DBA table via Agent

    Author:   Ronald.de.Groot@OpenData.nl
    Source:   https://github.com/ronaldgithub/tsql-mysteries/blob/main/BlockWatch_sp_HumanEvents_setup.sql
    License:  MIT

    Drafted with the help of Claude Code (Anthropic), thanks Claude, I am such a bad keyboard typer!(?)

    Section 8 calls sp_HumanEventsBlockViewer from Erik Darling's DarlingData
    toolkit - https://github.com/erikdarlingdata/DarlingData (MIT licensed).
    Used url: https://github.com/erikdarlingdata/DarlingData/tree/main/sp_HumanEvents
    That procedure is a separate install and is NOT included here; grab it via
    his Install-All script so you get updates.

    Tested on: SQL Server 2025
==============================================================================*/


/*==============================================================================
    BlockWatch - capture the blocked process report to a DBA table via Agent
    ---------------------------------------------------------------------------
    Consistent naming used throughout:

        blocked process threshold .... server setting that MUST be > 0
        BlockWatch ................... the Extended Events session
        BlockWatch*.xel ............. the event_file target (SQL Server LOG folder)
        DBA.dbo.BlockWatch .......... destination table for the raw reports
        DBA.dbo.BlockWatch_Collect .. proc that shreds the .xel into the table
        DBA.dbo.BlockWatch_Demo ..... throwaway table used only for the test
        "DBA - BlockWatch Collect" .. the SQL Server Agent job

    Run sections 1-5 once, in order
    Section 6 is a manual two-window test.
    Sections 7-9 are verification, analysis, and cleanup.
==============================================================================*/


/*------------------------------------------------------------------------------
    SECTION 1 : Server configuration

    The blocked process report is produced by the engine only when a task has
    been blocked for longer than this many SECONDS. It is NOT part of the XE
    session - if it stays 0, the session captures nothing. 5 is the minimum
    that actually works.
------------------------------------------------------------------------------*/
EXEC sys.sp_configure 'show advanced options', 1;
RECONFIGURE;
EXEC sys.sp_configure 'blocked process threshold', 5;   /* seconds */
RECONFIGURE;
GO

/* verify: value_in_use must be 5, not 0 */
SELECT name, value_in_use
FROM   sys.configurations
WHERE  name = 'blocked process threshold (s)';
GO


/*------------------------------------------------------------------------------
    SECTION 2 : Extended Events session

    filename = N'BlockWatch' writes files named BlockWatch_0_<number>.xel into
    the default SQL Server LOG directory. The search pattern in the collector
    proc (BlockWatch*.xel) must share that prefix.
------------------------------------------------------------------------------*/
IF EXISTS (SELECT 1 FROM sys.server_event_sessions WHERE name = N'BlockWatch')
    DROP EVENT SESSION BlockWatch ON SERVER;
GO

CREATE EVENT SESSION BlockWatch ON SERVER
ADD EVENT sqlserver.blocked_process_report
ADD TARGET package0.event_file
(
    SET filename          = N'BlockWatch',
        max_file_size     = 64,   /* MB per file */
        max_rollover_files = 5
)
WITH
(
    MAX_MEMORY           = 4096 KB,
    EVENT_RETENTION_MODE = ALLOW_SINGLE_EVENT_LOSS,
    MAX_DISPATCH_LATENCY = 5 SECONDS,
    STARTUP_STATE        = ON      /* survives a SQL Server restart */
);
GO

ALTER EVENT SESSION BlockWatch ON SERVER STATE = START;
GO

/* verify: is_running must be 1 */
SELECT
    s.name,
    is_running = IIF(r.create_time IS NULL, 0, 1),
    r.create_time
FROM       sys.server_event_sessions AS s
LEFT JOIN  sys.dm_xe_sessions        AS r ON r.name = s.name
WHERE      s.name = N'BlockWatch';
GO


/*------------------------------------------------------------------------------
    SECTION 3 : DBA database, destination table, collector proc
------------------------------------------------------------------------------*/
IF DB_ID(N'DBA') IS NULL
    CREATE DATABASE DBA;
GO

USE DBA;
GO

/* destination table for the raw reports */
DROP TABLE IF EXISTS dbo.BlockWatch;
GO
CREATE TABLE dbo.BlockWatch
(
    BlockWatchID     bigint IDENTITY(1,1) CONSTRAINT PK_BlockWatch PRIMARY KEY,
    event_time_utc   datetime2(3)  NOT NULL,   /* from the event; already UTC */
    event_xml        xml           NOT NULL,   /* the full blocked_process_report event */
    event_hash       AS CONVERT(binary(32),
                          HASHBYTES('SHA2_256', CONVERT(nvarchar(max), event_xml))) PERSISTED,
    collected_at_utc datetime2(3)  NOT NULL
        CONSTRAINT DF_BlockWatch_collected DEFAULT (SYSUTCDATETIME())
);
GO

/* IGNORE_DUP_KEY lets the proc re-read the whole .xel every run without
   creating duplicates - only genuinely new events get inserted */
CREATE UNIQUE INDEX UQ_BlockWatch
    ON dbo.BlockWatch (event_time_utc, event_hash)
    WITH (IGNORE_DUP_KEY = ON);
GO

CREATE OR ALTER PROCEDURE dbo.BlockWatch_Collect
AS
BEGIN
    SET NOCOUNT ON;

    /* sys.fn_xe_file_target_read_file needs VIEW SERVER STATE (or sysadmin).
       If the Agent job step fails, that permission is usually why - see Section 5. */
    INSERT dbo.BlockWatch (event_time_utc, event_xml)
    SELECT
        x.event_xml.value('(event/@timestamp)[1]', 'datetime2(3)'),
        x.event_xml
    FROM
    (
        SELECT event_xml = CONVERT(xml, f.event_data)
        FROM   sys.fn_xe_file_target_read_file(N'BlockWatch*.xel', NULL, NULL, NULL) AS f
    ) AS x
    WHERE x.event_xml.value('(event/@name)[1]', 'sysname') = N'blocked_process_report';
END;
GO


/*------------------------------------------------------------------------------
    SECTION 4 : SQL Server Agent job

    Owner = sa means the T-SQL step runs in the context of the SQL Server Agent
    service account, which normally already has VIEW SERVER STATE.
------------------------------------------------------------------------------*/
USE msdb;
GO

IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = N'DBA - BlockWatch Collect')
    EXEC msdb.dbo.sp_delete_job @job_name = N'DBA - BlockWatch Collect';
GO

EXEC msdb.dbo.sp_add_job
    @job_name         = N'DBA - BlockWatch Collect',
    @owner_login_name = N'sa',
    @description      = N'Shreds BlockWatch*.xel into DBA.dbo.BlockWatch';

EXEC msdb.dbo.sp_add_jobstep
    @job_name       = N'DBA - BlockWatch Collect',
    @step_name      = N'Collect',
    @subsystem      = N'TSQL',
    @database_name  = N'DBA',
    @command        = N'EXEC dbo.BlockWatch_Collect;',
    @retry_attempts = 2,
    @retry_interval = 1;

EXEC msdb.dbo.sp_add_jobschedule
    @job_name             = N'DBA - BlockWatch Collect',
    @name                 = N'Every 1 minutes',
    @freq_type            = 4,   /* daily   */
    @freq_interval        = 1,
    @freq_subday_type     = 4,   /* minutes */
    @freq_subday_interval = 1;

EXEC msdb.dbo.sp_add_jobserver
    @job_name = N'DBA - BlockWatch Collect';
GO


/*------------------------------------------------------------------------------
    SECTION 5 : (only if the job step fails with a permissions error)

    Grant VIEW SERVER STATE to whatever account the step runs as. Find the
    SQL Server Agent service account in Configuration Manager, then:
------------------------------------------------------------------------------*/
-- GRANT VIEW SERVER STATE TO [DOMAIN\SqlAgentServiceAccount];
GO


/*==============================================================================
    SECTION 6 : Blocking simulation  --  RUN THIS IN TWO SEPARATE WINDOWS
==============================================================================*/

/* --- one-time setup: throwaway test table ---------------------------------- */
USE DBA;
GO
DROP TABLE IF EXISTS dbo.BlockWatch_Demo;
CREATE TABLE dbo.BlockWatch_Demo (id int PRIMARY KEY, col int);
INSERT dbo.BlockWatch_Demo (id, col) VALUES (1, 100);
GO

/* --- WINDOW 1 : the blocker ----------------------------------------------- */
/* Run these three lines, then STOP and switch to Window 2.                   */
/*
USE DBA;
BEGIN TRANSACTION;
UPDATE dbo.BlockWatch_Demo SET col = 999 WHERE id = 1;
*/

/* --- WINDOW 2 : the victim ---------------------------------------------------
   Run this - it will hang. Leave it hanging ~20 seconds so the engine emits
   3-4 blocked_process_report events (one per 5s threshold interval).
*/
/*
USE DBA;
UPDATE dbo.BlockWatch_Demo SET col = 1 WHERE id = 1;
*/

/* --- WINDOW 1 : release --------------------------------------------------- */
/*
ROLLBACK;
*/


/*==============================================================================
    SECTION 7 : Verification
==============================================================================*/

/* 7a. Did the events reach the .xel target?
       If this returns rows, capture works and the problem (if any) is downstream.
       If it returns nothing, go back to Section 1 (threshold) / Section 2. */
SELECT
    event_time_utc = CONVERT(xml, f.event_data).value('(event/@timestamp)[1]', 'datetime2(3)'),
    event_xml      = CONVERT(xml, f.event_data)
FROM   sys.fn_xe_file_target_read_file(N'BlockWatch*.xel', NULL, NULL, NULL) AS f
WHERE  CONVERT(xml, f.event_data).value('(event/@name)[1]', 'sysname') = N'blocked_process_report'
ORDER BY event_time_utc DESC;
GO

/* 7b. Run the collector by hand - rows must land here before the job matters */
EXEC DBA.dbo.BlockWatch_Collect;
SELECT * FROM DBA.dbo.BlockWatch ORDER BY event_time_utc DESC;
GO

/* 7c. Run the Agent job and read its outcome (run_status 1 = success) */
EXEC msdb.dbo.sp_start_job N'DBA - BlockWatch Collect';
WAITFOR DELAY '00:00:05';

SELECT TOP (10)
    j.name,
    h.step_id,
    h.step_name,
    h.run_status,
    h.message
FROM       msdb.dbo.sysjobhistory AS h
JOIN       msdb.dbo.sysjobs       AS j ON j.job_id = h.job_id
WHERE      j.name = N'DBA - BlockWatch Collect'
ORDER BY   h.run_date DESC, h.run_time DESC;

SELECT rows_in_table = COUNT(*) FROM DBA.dbo.BlockWatch;
GO


/*==============================================================================
    SECTION 8 : Analyse the collected data with sp_HumanEventsBlockViewer

    Passing @target_table + @target_column switches it into "table mode" -
    it reads the report XML from your table instead of from the .xel files.
    @timestamp_column must be a UTC column (event_time_utc is UTC).
==============================================================================*/
EXEC master.dbo.sp_HumanEventsBlockViewer
    @target_type      = N'table',
    @target_database  = N'DBA',
    @target_schema    = N'dbo',
    @target_table     = N'BlockWatch',
    @target_column    = N'event_xml',
    @timestamp_column = N'event_time_utc',
    @start_date       = '20260831',
    @end_date         = '20260901';
GO


/*==============================================================================
    SECTION 9 : Retention  --  add as a second job step, or its own job
==============================================================================*/
DELETE TOP (50000) FROM DBA.dbo.BlockWatch
WHERE event_time_utc < DATEADD(DAY, -90, SYSUTCDATETIME());
GO


/*==============================================================================
    SECTION 10 : Teardown (commented out - uncomment to remove everything)
==============================================================================*/
/*
EXEC msdb.dbo.sp_delete_job @job_name = N'DBA - BlockWatch Collect';
ALTER EVENT SESSION BlockWatch ON SERVER STATE = STOP;
DROP EVENT SESSION BlockWatch ON SERVER;
DROP TABLE IF EXISTS DBA.dbo.BlockWatch;
DROP TABLE IF EXISTS DBA.dbo.BlockWatch_Demo;
DROP PROCEDURE IF EXISTS DBA.dbo.BlockWatch_Collect;
EXEC sys.sp_configure 'blocked process threshold', 0;
RECONFIGURE;
*/