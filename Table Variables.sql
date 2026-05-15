/*  Table Variables
 
 Version: Microsoft SQL Server 2025 (RTM-GDR) (KB5091223) - 17.0.1115.1 (X64)   Apr 19 2026 01:00:58   Copyright (C) 2025 Microsoft Corporation  Enterprise Developer Edition (64-bit) 
	on Windows 10 Pro 10.0 <X64> (Build 19045: ) (Hypervisor) 
 Database: StackOverflow2013
 
 T-SQL/Execution Plan
 Solution T-SQL/Execution Plan 

 Drop Indexes: https://dbaronald.nl/dropindexes-are-you-sure/
 Credits go to https://erikdarling.com/

*/

EXEC dbo.DropIndexes;
DBCC FREEPROCCACHE;

create index ixnc_Posts_OwnerUserId_PostTypeId_Scorefoibles on dbo.Posts(OwnerUserId, PostTypeId, Score DESC);
create index ixnc_Badges_Name_incl_UserIdmarbles on dbo.Badges (Name) INCLUDE (UserId);

/* code is proc */
create or alter proc dbo.pcl_TableVariable
as

DECLARE @PopUsers TABLE (UserId INT NOT NULL);

INSERT @PopUsers (UserId) 
SELECT b.UserId 
FROM dbo.Badges AS b 
WHERE b.Name = N'Popular Question';
/*
(1286465 rows affected)
Completion time: 2026-05-15T12:18:34.8983875+02:00
*/

SELECT TOP (50) w.UserId,
       p.Title,
       p.Score
FROM @PopUsers AS w
OUTER APPLY
(
    SELECT TOP (10) p.*
    FROM dbo.Posts AS p
    WHERE p.OwnerUserId = w.UserId
      AND p.PostTypeId = 1
      AND p.Score > 1
    ORDER BY p.Score DESC
) AS p
ORDER BY w.UserId asc;

SELECT TOP (1200000) w.UserId,
       p.Title,
       p.Score
FROM @PopUsers AS w
OUTER APPLY
(
    SELECT TOP (10) p.*
    FROM dbo.Posts AS p
    WHERE p.OwnerUserId = w.UserId
      AND p.PostTypeId = 1
      AND p.Score > 1
    ORDER BY p.Score DESC
) AS p
ORDER BY w.UserId asc;


EXEC dbo.pcl_TableVariable;
EXEC sp_BlitzCache @StoredProcName = 'pcl_TableVariable';

/*
The key change: “Parallelism-eligible operators” SQL Server 2025 will parallelize if:
A join or scan operator has a high estimated cost
Even if the overall subtree cost is low and even if CTFP is not exceeded.

This is especially true for:
- Hash joins
- Hash aggregates
- Columnstore scans
- Batch mode operators
- Large rowset APPLYs
- Memory-grant-heavy operators
These operators have their own internal cost thresholds.
*/ 

