/*
    Check-StatisticsStaleness.sql
    Read-only. Run it in the database you want to check (USE <db> first).

    Part 1  Every user-table statistic: how many rows changed since the last update,
            against the auto-update threshold, and how old the statistics are.
    Part 2  Date-led statistics only: how far the newest data in the table sits beyond
            the end of the histogram. This is the "ascending key" problem: rows past the
            histogram get a flat guess no matter which time window you ask about.

    Reading the status:
      REFRESH NOW   80% or more of the auto-update threshold (or, in Part 2, the data is
                    more than @gap_hours_refresh beyond the histogram).
      WATCH         20% or more of the threshold (or more than @gap_hours_watch beyond it).
      ok            neither.
    The thresholds are rules of thumb, not SQL Server rules. In the demo the estimates were
    wrong from the first stale row, long before the auto-update threshold, so for tables that
    grow at the end and are queried on recent dates, trust the Part 2 gap over the percentage.

    Threshold: SQL Server 2016+ at compat 130+ uses MIN(500 + 20% of rows, SQRT(1000 * rows)).
    Cost: Part 1 reads statistics metadata and histograms. Part 2 runs one MAX() per candidate;
    that is a cheap seek only when the date column leads an index, so Part 2 skips columns that
    do not lead an index.

    Note: this file does not change anything. To refresh, use UPDATE STATISTICS yourself.
*/

------------------------------------------------------------------------------
-- Part 1: all statistics, worst first
------------------------------------------------------------------------------
SELECT
    schema_name           = SCHEMA_NAME(o.schema_id),
    table_name            = o.name,
    stat_name             = s.name,
    leading_column        = lc.name,
    leading_type          = lt.name,
    sp.rows,
    sp.modification_counter,
    auto_update_threshold = CONVERT(bigint, t.thr),
    pct_of_threshold      = CONVERT(decimal(7,1), p.pct_thr),
    pct_of_rows           = CONVERT(decimal(7,2), 100.0 * sp.modification_counter / NULLIF(sp.rows, 0)),
    sp.last_updated,
    days_since_update     = DATEDIFF(DAY, sp.last_updated, SYSDATETIME()),
    histogram_end         = he.histogram_end,
    status = CASE WHEN p.pct_thr >= 80 THEN 'REFRESH NOW'
                  WHEN p.pct_thr >= 20 THEN 'WATCH'
                  ELSE 'ok' END
FROM sys.stats AS s
JOIN sys.objects AS o
    ON  o.object_id = s.object_id
    AND o.type = 'U'
    AND o.is_ms_shipped = 0
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
CROSS APPLY (SELECT thr = CASE WHEN 500 + 0.20 * sp.rows < SQRT(1000.0 * sp.rows)
                               THEN 500 + 0.20 * sp.rows
                               ELSE SQRT(1000.0 * sp.rows) END) AS t
CROSS APPLY (SELECT pct_thr = 100.0 * sp.modification_counter / NULLIF(t.thr, 0)) AS p
JOIN sys.stats_columns AS sc
    ON  sc.object_id = s.object_id
    AND sc.stats_id = s.stats_id
    AND sc.stats_column_id = 1
JOIN sys.columns AS lc
    ON  lc.object_id = sc.object_id
    AND lc.column_id = sc.column_id
JOIN sys.types AS lt
    ON  lt.user_type_id = lc.user_type_id
OUTER APPLY
(
    SELECT histogram_end = MAX(CASE WHEN SQL_VARIANT_PROPERTY(x.range_high_key, 'BaseType')
                                         IN ('date', 'datetime', 'datetime2', 'smalldatetime')
                                    THEN CONVERT(datetime2(0), x.range_high_key) END)
    FROM sys.dm_db_stats_histogram(s.object_id, s.stats_id) AS x
    WHERE lt.name IN ('date', 'datetime', 'datetime2', 'smalldatetime')
) AS he
WHERE sp.rows > 0
ORDER BY p.pct_thr DESC, sp.rows DESC;
GO

------------------------------------------------------------------------------
-- Part 2: date-led statistics -- gap between the histogram end and the real max
------------------------------------------------------------------------------
SET NOCOUNT ON;

DECLARE @gap_hours_watch   int = 6;    -- adjust to how fresh your queries need the data
DECLARE @gap_hours_refresh int = 24;

CREATE TABLE #cand
(
    id             int IDENTITY(1,1) PRIMARY KEY,
    schema_name    sysname,
    table_name     sysname,
    stat_name      sysname,
    column_name    sysname,
    rows           bigint,
    mods           bigint,
    histogram_end  datetime2(0),
    table_max      datetime2(0) NULL
);

-- Only statistics whose leading column is a date type AND leads an index
-- (so the MAX() below is a one-row seek, not a scan).
INSERT #cand (schema_name, table_name, stat_name, column_name, rows, mods, histogram_end)
SELECT SCHEMA_NAME(o.schema_id), o.name, s.name, lc.name, sp.rows, sp.modification_counter, he.histogram_end
FROM sys.stats AS s
JOIN sys.objects AS o ON o.object_id = s.object_id AND o.type = 'U' AND o.is_ms_shipped = 0
CROSS APPLY sys.dm_db_stats_properties(s.object_id, s.stats_id) AS sp
JOIN sys.stats_columns AS sc ON sc.object_id = s.object_id AND sc.stats_id = s.stats_id AND sc.stats_column_id = 1
JOIN sys.columns AS lc ON lc.object_id = sc.object_id AND lc.column_id = sc.column_id
JOIN sys.types AS lt ON lt.user_type_id = lc.user_type_id AND lt.name IN ('datetime2', 'datetime', 'smalldatetime')
CROSS APPLY
(
    SELECT histogram_end = MAX(CASE WHEN SQL_VARIANT_PROPERTY(x.range_high_key, 'BaseType')
                                         IN ('datetime2', 'datetime', 'smalldatetime')
                                    THEN CONVERT(datetime2(0), x.range_high_key) END)
    FROM sys.dm_db_stats_histogram(s.object_id, s.stats_id) AS x
) AS he
WHERE sp.rows > 0
AND EXISTS
(
    SELECT 1
    FROM sys.index_columns AS ic
    WHERE ic.object_id = lc.object_id
    AND   ic.column_id = lc.column_id
    AND   ic.key_ordinal = 1
);

DECLARE @id int = 1, @max int = (SELECT MAX(id) FROM #cand), @sql nvarchar(max), @mx datetime2(0);

WHILE @id <= @max
BEGIN
    SELECT @sql = N'SELECT @mx = MAX(' + QUOTENAME(column_name) + N') FROM '
                + QUOTENAME(schema_name) + N'.' + QUOTENAME(table_name) + N';'
    FROM #cand WHERE id = @id;

    SET @mx = NULL;
    EXEC sys.sp_executesql @sql, N'@mx datetime2(0) OUTPUT', @mx = @mx OUTPUT;
    UPDATE #cand SET table_max = @mx WHERE id = @id;

    SET @id += 1;
END;

SELECT schema_name, table_name, stat_name, column_name, rows,
       modification_counter = mods,
       histogram_end,
       table_max,
       gap_hours = DATEDIFF(HOUR, histogram_end, table_max),
       status = CASE WHEN DATEDIFF(HOUR, histogram_end, table_max) >= @gap_hours_refresh THEN 'REFRESH NOW'
                     WHEN DATEDIFF(HOUR, histogram_end, table_max) >= @gap_hours_watch   THEN 'WATCH'
                     ELSE 'ok' END
FROM #cand
ORDER BY DATEDIFF(SECOND, histogram_end, table_max) DESC;

DROP TABLE #cand;
GO
