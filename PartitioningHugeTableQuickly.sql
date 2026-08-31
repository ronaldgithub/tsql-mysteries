/* =====================================================================
   Partitioning a huge table quickly, without a size-of-data operation.
   Source: Michael J. Swart, https://michaeljswart.com/2026/08/partitioning-a-huge-table-quickly/

   Idea: create the partition function with NO boundaries first (so the
   whole table lands on partition 1), SWITCH the data out, rebuild the
   clustered index onto the (still boundary-less) partition scheme while
   the table is empty, SWITCH the data back in, then grow real partition
   boundaries afterwards with SPLIT RANGE, which only touches rows near
   each new boundary (index seek) instead of scanning the whole table.

   Prerequisite: the clustered index's leading column must be the same
   column you intend to partition on (here: LogDate).
   ===================================================================== */

-- ---------------------------------------------------------------------
-- Step 0 (optional) - sample table + sample data, for testing the script
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS dbo.HumongousTable;
CREATE TABLE dbo.HumongousTable
(
    Id          INT NOT NULL IDENTITY,
    Name        NVARCHAR(100) NOT NULL,
    Description NVARCHAR(500) NULL,
    LogDate     DATETIME2 NOT NULL,
    CONSTRAINT PK_HumungousTable UNIQUE CLUSTERED (LogDate, Id)
);

INSERT dbo.HumongousTable (Name, Description, LogDate)
SELECT CAST(text AS NVARCHAR(100)), CAST(text AS NVARCHAR(500)), GETUTCDATE()
FROM sys.messages;

UPDATE dbo.HumongousTable
SET LogDate = DATEADD(SECOND, Id * -1, LogDate);

-- ---------------------------------------------------------------------
-- Step 1 - create the partition function/scheme with NO boundaries yet
-- ---------------------------------------------------------------------
CREATE PARTITION FUNCTION PF_MonthlySlidingWindow (DATETIME2)
AS RANGE RIGHT
FOR VALUES
(
    /* no partition boundaries to start with */
);

CREATE PARTITION SCHEME PS_MonthlySlidingWindow
AS PARTITION PF_MonthlySlidingWindow
ALL TO ([PRIMARY]);

-- ---------------------------------------------------------------------
-- Step 2 - create a matching staging table (same schema, same clustered key)
-- ---------------------------------------------------------------------
CREATE TABLE dbo.HumongousTable_Temp
(
    Id          INT NOT NULL IDENTITY,
    Name        NVARCHAR(100) NOT NULL,
    Description NVARCHAR(500) NULL,
    LogDate     DATETIME2 NOT NULL,
    CONSTRAINT PK_HumungousTable_Temp UNIQUE CLUSTERED (LogDate, Id)
);

-- ---------------------------------------------------------------------
-- Step 3 - SWITCH the data out to the staging table (metadata-only, instant)
-- ---------------------------------------------------------------------
ALTER TABLE dbo.HumongousTable
SWITCH TO dbo.HumongousTable_Temp;

-- ---------------------------------------------------------------------
-- Step 4 - rebuild the clustered index onto the partition scheme while
--          HumongousTable is empty, so this is cheap regardless of the
--          real data volume
-- ---------------------------------------------------------------------
CREATE UNIQUE CLUSTERED INDEX PK_HumongousTable
    ON dbo.HumongousTable (LogDate, Id)
    WITH (DROP_EXISTING = ON)
ON PS_MonthlySlidingWindow (LogDate);

-- ---------------------------------------------------------------------
-- Step 5 - SWITCH the data back in (metadata-only again). All rows now
--          sit on partition 1 of the properly partition-scheme-backed
--          clustered index - no scan required to get here.
-- ---------------------------------------------------------------------
ALTER TABLE dbo.HumongousTable_Temp
SWITCH TO dbo.HumongousTable PARTITION 1;

DROP TABLE IF EXISTS dbo.HumongousTable_Temp;

-- ---------------------------------------------------------------------
-- Step 6 - grow real partition boundaries by splitting. Each SPLIT RANGE
--          is NOT metadata-only, but because the clustered index's
--          leading column (LogDate) matches the partitioning column, it
--          can seek to the boundary via the index instead of scanning
--          the whole table.
-- ---------------------------------------------------------------------
DECLARE @Month DATETIME2 = DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1);
WHILE @Month < '20300101'
BEGIN
    SET @Month = DATEADD(MONTH, 1, @Month);
    ALTER PARTITION FUNCTION PF_MonthlySlidingWindow() SPLIT RANGE (@Month);
    ALTER PARTITION SCHEME PS_MonthlySlidingWindow NEXT USED [PRIMARY];
END

-- ---------------------------------------------------------------------
-- Step 7 - verify
-- ---------------------------------------------------------------------
SELECT COUNT(*) AS NumberOfPartitions
FROM sys.partitions
WHERE object_id = OBJECT_ID('dbo.HumongousTable');
