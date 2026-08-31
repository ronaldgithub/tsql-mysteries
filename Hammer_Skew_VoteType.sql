--------------------------------------------------------------------
-- 0. Setup: seek-able index on the skewed column (idempotent)
--------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Votes') AND name = 'IX_Votes_VoteTypeId_Skew')
BEGIN
    CREATE NONCLUSTERED INDEX IX_Votes_VoteTypeId_Skew ON dbo.Votes (VoteTypeId);
END
GO

--------------------------------------------------------------------
-- Votes.VoteTypeId distribution (StackOverflow2013, 52,929,133 rows):
--   VoteTypeId = 2  (UpMod)      37,332,607 rows  (~70.5%)
--   VoteTypeId = 4  (Offensive)         733 rows  (~0.0014%)
-- One column, one index, a 50,000x gap between the two ends of the skew.
--------------------------------------------------------------------

CREATE OR ALTER PROCEDURE dbo.Hammer_Skew_VoteType_Sniff
    @VoteTypeId int
AS
BEGIN
    SET NOCOUNT ON;

    SELECT Id, PostId, UserId, CreationDate
    FROM dbo.Votes
    WHERE VoteTypeId = @VoteTypeId;
END
GO

--------------------------------------------------------------------
-- 1. Literal predicates: the optimizer sees the real histogram value,
--    so each gets its own correct plan (turn on Actual Execution Plan)
--------------------------------------------------------------------
SELECT Id, PostId, UserId, CreationDate FROM dbo.Votes WHERE VoteTypeId = 2;   -- seek, ~37.3M actual rows -> should go parallel / scan-shaped
SELECT Id, PostId, UserId, CreationDate FROM dbo.Votes WHERE VoteTypeId = 4;   -- seek, 733 actual rows -> tiny, cheap

--------------------------------------------------------------------
-- 2. Parameter sniffing meets skew: whichever value compiles the plan
--    first gets reused for the opposite end of the 50,000x skew.
--    Run each EXEC separately with Actual Execution Plan on and compare
--    estimated vs. actual rows on the Index Seek.
--------------------------------------------------------------------
EXEC sys.sp_recompile 'dbo.Hammer_Skew_VoteType_Sniff';   -- clear any cached plan first

EXEC dbo.Hammer_Skew_VoteType_Sniff @VoteTypeId = 4;   -- compiles a cheap plan sized for 733 rows
EXEC dbo.Hammer_Skew_VoteType_Sniff @VoteTypeId = 2;   -- reuses that cheap plan for 37.3M rows -> huge estimate/actual mismatch

--------------------------------------------------------------------
-- 3. Fix: force a fresh, correctly-sized plan per call
--------------------------------------------------------------------
EXEC dbo.Hammer_Skew_VoteType_Sniff @VoteTypeId = 2 WITH RECOMPILE;
GO

--------------------------------------------------------------------
-- 4. Thread skew: GROUP BY hides this (SQL Server pre-aggregates
--    locally per thread before redistributing), so use a window
--    function instead -- PARTITION BY forces every row for a given
--    VoteTypeId onto the SAME thread, with no local shortcut.
--    Cost alone should push this parallel (MAXDOP 8, threshold 50);
--    click the Segment/Sequence Project operator after the
--    Parallelism (Repartition Streams) exchange, open the Properties
--    window (F4), and expand "Actual Number of Rows" to see the
--    per-thread breakdown -- one thread should own ~37.3M rows
--    (VoteTypeId = 2) while the other seven split the rest.
--------------------------------------------------------------------
SELECT VoteTypeId,
       ROW_NUMBER() OVER (PARTITION BY VoteTypeId ORDER BY Id) AS rn
FROM dbo.Votes
OPTION (RECOMPILE);
GO

--------------------------------------------------------------------
-- 5. Erik Darling's version of this demo -- reconstructed from the
--    (code-free, video-transcript) posts below, not a verbatim copy:
--    https://erikdarling.com/a-little-about-skewed-data-and-skewed-parallelism/
--    https://erikdarling.com/a-follow-up-on-fixing-parallel-plan-row-skew-in-sql-server/
--
--    93% of Votes.UserId is NULL in the public dump (voting is
--    anonymized). He backfills those NULLs with VoteTypeId to
--    fabricate a skewed UserId, then joins Users to it.
--------------------------------------------------------------------

-- 5a. One-time setup: copies ~53M rows (~2GB) -- this will take a while.
IF OBJECT_ID('dbo.VotesSkewed') IS NULL
BEGIN
    SELECT Id, PostId, UserId, BountyAmount, VoteTypeId, CreationDate
    INTO dbo.VotesSkewed
    FROM dbo.Votes;

    UPDATE dbo.VotesSkewed
    SET UserId = VoteTypeId
    WHERE UserId IS NULL;

    ALTER TABLE dbo.VotesSkewed ADD CONSTRAINT PK_VotesSkewed_Id PRIMARY KEY CLUSTERED (Id);

    CREATE NONCLUSTERED INDEX IX_VotesSkewed_UserId_VoteTypeId
        ON dbo.VotesSkewed (UserId, VoteTypeId);
END
GO

--------------------------------------------------------------------
-- 5b. Original (skewed): a correlated OUTER APPLY per user, filtered
--     to VoteTypeId BETWEEN 1 AND 4. Because the fabricated UserId
--     values ARE those same 4 VoteTypeIds, every matching row hashes
--     to the same thread on the way into the apply's inner seek --
--     check the clustered index operator's per-thread actual rows.
--     A DOP 8 plan still divides the memory grant by 8, so whichever
--     thread gets all the rows is starved and the Sort spills hard.
--------------------------------------------------------------------
SELECT u.Id, u.DisplayName, x.VoteTypeId, x.CreationDate
FROM dbo.Users u
OUTER APPLY (
    SELECT TOP (5) v.VoteTypeId, v.CreationDate
    FROM dbo.VotesSkewed v
    WHERE v.UserId = u.Id
      AND v.VoteTypeId BETWEEN 1 AND 4
    ORDER BY v.CreationDate DESC
) x
OPTION (RECOMPILE);

--------------------------------------------------------------------
-- 5c. His fix: stop correlating on the 4 VoteTypeIds directly. Push
--     them into a VALUES constant scan, rank everything in
--     VotesSkewed ONCE (uncorrelated), then join Users on afterward.
--     This trades the skewed nested-loops/apply shape for hash joins
--     fed by the constant scan -- and tends to qualify for batch mode.
--------------------------------------------------------------------
SELECT u.Id, u.DisplayName, x.VoteTypeId, x.CreationDate
FROM (VALUES (1), (2), (3), (4)) AS vt(VoteTypeId)
LEFT JOIN (
    SELECT v.UserId, v.VoteTypeId, v.CreationDate,
           ROW_NUMBER() OVER (PARTITION BY v.UserId, v.VoteTypeId ORDER BY v.CreationDate DESC) AS rn
    FROM dbo.VotesSkewed v
) AS x ON x.VoteTypeId = vt.VoteTypeId
JOIN dbo.Users u ON u.Id = x.UserId
WHERE x.rn <= 5
OPTION (RECOMPILE);
GO
