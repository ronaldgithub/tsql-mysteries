/*
In  SQL Server 2025 an executionplan of a query can be TRIVIAL or FULL Optimization Level. 
What kind of optimizations are skippen in a TRIVIAL plan?

In SQL Server, the optimizer first tries **trivial plan optimization** before falling back to full cost-based optimization (CBO). 
It's a fast-path shortcut used when the query is simple enough that only one reasonable plan exists — so spending 
time costing alternatives would be wasted effort.

What gets skipped when a plan goes trivial: 

- Cost-based costing entirely 
- Join order enumeration 
- Physical operator selection among alternatives 
- Index alternative comparison
- Parallelism consideration 
- Plan space exploration/transformation rules 
- Memory grant iteration/tuning 

- Cost-based costing entirely 
	* no cardinality/cost comparison between candidate plans. The optimizer picks the (only) plan without evaluating alternatives.
- Join order enumeration 
	* no exploration of different join orders via commutativity/associativity transformation rules 
	  (Phase 0/1/2 exploration rules in the CBO don't run).
- Physical operator selection among alternatives** 
	* no comparing hash match vs. merge join vs. nested loop; whatever the heuristic picks is used as-is.
- Index alternative comparison
	* if more than one index could satisfy the query, trivial plan doesn't apply at all (that ambiguity is 
	  exactly what forces it into full optimization). Trivial only fires when there's essentially one obvious 
	  access path (e.g., single table, unique clustered index seek, no useful nonclustered alternatives).
- Parallelism consideration 
	* trivial plans are assumed cheap enough that parallel plan generation/costing is skipped 
	  (this is also why trivial plans almost always come back serial, regardless of cost threshold for parallelism).
- Plan space exploration/transformation rules 
	* only *simplification* rules run (constant folding, contradiction detection, redundant join 
	  elimination, etc.), not the exploration rules that generate and cost multiple logically-equivalent plan shapes.
- Memory grant iteration/tuning against competing plan shapes there's nothing to tune against.

When it typically applies: single-table queries, queries with only 
one sensible join order, simple predicates with one usable index, or queries 
where hints/constraints already force a unique path.

Practical implication for tuning: if you see `StatementOptmLevel = "TRIVIAL"` in the plan XML 
but expected the optimizer to consider a different index or join strategy, it never got the chance — trivial plans don't 
compete against alternatives. Adding a second viable index, another join possibility, 
or removing something that made the path "obviously unique" is often what pushes the query into 
full optimization so the CBO actually evaluates options.

If you've got an actual `.sqlplan` you're staring at, I can dig into why it landed 
trivial (or didn't) — that's a good case for the query-plan-analysis skill.
*/

/* ============================================================================
   TRIVIAL vs FULL OPTIMIZATION — StackOverflow2013 demo script
   ============================================================================
   Purpose: for each optimizer behavior that a TRIVIAL plan skips, show one
   query that (typically) gets a TRIVIAL plan and one that (typically) forces
   FULL cost-based optimization.

   HOW TO VERIFY EACH PLAN:
     Option A (SSMS graphical plan):
       Ctrl+M to include actual execution plan, run the statement, click the
       leftmost operator (SELECT/INSERT icon), press F4, look at:
         - "Optimization Level"                 -> TRIVIAL or FULL
         - "Reason For Early Termination..."     -> e.g. "Good Enough Plan Found"
                                                     (only appears on FULL plans)
     Option B (raw XML):
       SET STATISTICS XML ON; then run the query and inspect the
       <StmtSimple StatementOptmLevel="TRIVIAL|FULL" ...> attribute.

   NOTE: Trivial vs. full is a function of your actual indexes/stats, not just
   query text. If a query below doesn't land where labeled, that itself is a
   useful diagnostic -- check what alternative access path made the optimizer
   decide there was a choice to cost.

   This script creates a couple of small demo nonclustered indexes so the
   "index alternative comparison" section is reproducible. A teardown section
   is included at the bottom (commented out) to remove them when you're done.
   ============================================================================ */

/* ============================================================================
   TRIVIAL vs FULL OPTIMIZATION — StackOverflow2013 demo script
   ============================================================================
   Purpose: for each optimizer behavior that a TRIVIAL plan skips, show one
   query that (typically) gets a TRIVIAL plan and one that (typically) forces
   FULL cost-based optimization.

   HOW TO VERIFY EACH PLAN:
     Option A (SSMS graphical plan):
       Ctrl+M to include actual execution plan, run the statement, click the
       leftmost operator (SELECT/INSERT icon), press F4, look at:
         - "Optimization Level"                 -> TRIVIAL or FULL
         - "Reason For Early Termination..."     -> e.g. "Good Enough Plan Found"
                                                     (only appears on FULL plans)
     Option B (raw XML):
       SET STATISTICS XML ON; then run the query and inspect the
       <StmtSimple StatementOptmLevel="TRIVIAL|FULL" ...> attribute.

   NOTE: Trivial vs. full is a function of your actual indexes/stats, not just
   query text. If a query below doesn't land where labeled, that itself is a
   useful diagnostic -- check what alternative access path made the optimizer
   decide there was a choice to cost.

   This script creates a couple of small demo nonclustered indexes so the
   "index alternative comparison" section is reproducible. A teardown section
   is included at the bottom (commented out) to remove them when you're done.
   ============================================================================ */

USE StackOverflow2013;
GO

SET STATISTICS XML OFF;
GO

-- ----------------------------------------------------------------------------
-- SETUP: demo indexes needed later (safe to re-run)
-- ----------------------------------------------------------------------------
IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Demo_Users_Reputation' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE INDEX IX_Demo_Users_Reputation ON dbo.Users(Reputation);
GO

IF NOT EXISTS (SELECT 1 FROM sys.indexes WHERE name = 'IX_Demo_Users_Views' AND object_id = OBJECT_ID('dbo.Users'))
    CREATE INDEX IX_Demo_Users_Views ON dbo.Users(Views);
GO


/* ============================================================================
   1) COST-BASED COSTING ENTIRELY
      Trivial skips costing candidate plans against each other because there
      is (allegedly) only one candidate. Full has to estimate cost for
      competing access paths and pick the cheapest.
   ============================================================================ */

-- 1a. TRIVIAL: single-row PK seek, no alternative access path exists at all
SELECT Id, PostTypeId, Score, Title
FROM dbo.Posts
WHERE Id = 4
OPTION (RECOMPILE);

-- 1b. FULL: range predicate on an indexed column -- optimizer must cost
--     "seek + key lookup" against "scan" and pick based on estimated rows
SELECT Id, DisplayName, Reputation
FROM dbo.Users
WHERE Reputation BETWEEN 10000 AND 11000
OPTION (RECOMPILE);


/* ============================================================================
   2) JOIN ORDER ENUMERATION
      Trivial never considers alternative join orders. Full enumerates and
      costs different orderings (which table drives the join).

      IMPORTANT CORRECTION: there is no genuine "trivial join" example.
      The trivial-plan check runs BEFORE cardinality estimation, so it can't
      reason "Posts.Id = 4 collapses to one row, so obviously drive from
      Posts." That conclusion itself requires cost-based reasoning. As soon
      as a query has 2+ tables joined (and no FK-based join elimination
      applies -- StackOverflow2013 has no FK constraints, so it never does),
      full optimization kicks in regardless of predicate selectivity. Use the
      single-table query from section 1a as the trivial reference point --
      both queries below are FULL, demonstrating that even a join collapsed
      to one row still needs full optimization to arrive at that plan.
   ============================================================================ */

-- 2a. FULL (not trivial, despite collapsing to one row): the optimizer still
--     has to enumerate/cost join order and operator to conclude "drive from
--     Posts, nested loop into Users" -- it can't skip straight there
SELECT p.Id, p.Title, u.DisplayName
FROM dbo.Posts p
JOIN dbo.Users u ON u.Id = p.OwnerUserId
WHERE p.Id = 4
OPTION (RECOMPILE);

-- 2b. FULL: three-way join with non-restrictive predicates -- multiple join
--     orders (Posts->Users->Badges vs Users->Badges->Posts, etc.) are
--     genuinely plausible and must be enumerated/costed
SELECT p.Title, u.DisplayName, b.Name
FROM dbo.Posts p
JOIN dbo.Users u ON u.Id = p.OwnerUserId
JOIN dbo.Badges b ON b.UserId = u.Id
WHERE p.PostTypeId = 1
OPTION (RECOMPILE);


/* ============================================================================
   3) PHYSICAL OPERATOR SELECTION AMONG ALTERNATIVES
      Trivial just takes the only operator that makes sense -- but that only
      ever happens for single-table statements. Any join at all needs full
      optimization to cost nested loop vs. hash match vs. merge join, even
      when the "obvious" answer (loop) is what comes out the other end.
      Reference the trivial single-table query in 1a for contrast.
   ============================================================================ */

-- 3a. FULL: same query as 2a -- even though nested loop is the operator that
--     wins, the optimizer had to cost it against hash/merge alternatives to
--     know that; it isn't a shortcut taken because the row count is small
SELECT p.Id, p.Title, u.DisplayName
FROM dbo.Posts p
JOIN dbo.Users u ON u.Id = p.OwnerUserId
WHERE p.Id = 4
OPTION (RECOMPILE);

-- 3b. FULL: large-to-large join with a non-restrictive filter -- hash match
--     is a real candidate that has to be costed against loop/merge
--     alternatives before it wins
SELECT v.VoteTypeId, COUNT(*) AS Cnt
FROM dbo.Posts p
JOIN dbo.Votes v ON v.PostId = p.Id
WHERE p.PostTypeId = 1
GROUP BY v.VoteTypeId
OPTION (RECOMPILE);


/* ============================================================================
   4) INDEX ALTERNATIVE COMPARISON
      Trivial only applies when there is exactly one usable index. Full has
      to weigh multiple indexes (or index vs. scan) against each other.
   ============================================================================ */

-- 4a. TRIVIAL: only the clustered PK can satisfy this predicate -- no
--     alternative index exists to compare it against
SELECT Id, DisplayName, Reputation
FROM dbo.Users
WHERE Id = 22656
OPTION (RECOMPILE);

-- 4b. FULL: predicate touches two separately-indexed columns via OR --
--     optimizer must weigh index union (both nonclustered indexes) vs. a
--     clustered index scan
SELECT Id, DisplayName
FROM dbo.Users
WHERE Reputation > 5000 OR Views > 10000
OPTION (RECOMPILE);


/* ============================================================================
   5) PARALLELISM CONSIDERATION
      Trivial plans are never costed for parallelism -- they always come back
      serial regardless of "cost threshold for parallelism". Full plans
      compare a serial candidate against a parallel one when cost warrants it.
   ============================================================================ */

-- 5a. TRIVIAL: point lookup, trivially cheap -- parallelism is never even
--     considered, not just "not chosen"
SELECT Id, PostTypeId, Score
FROM dbo.Posts
WHERE Id = 4
OPTION (RECOMPILE);

-- 5b. FULL: unfiltered aggregation over a large table -- estimated cost
--     should exceed "cost threshold for parallelism" (default 5), making a
--     parallel plan a real candidate that gets costed against serial
SELECT p.OwnerUserId, COUNT(*) AS PostCount, AVG(p.Score) AS AvgScore
FROM dbo.Posts p
GROUP BY p.OwnerUserId
OPTION (RECOMPILE);


/* ============================================================================
   6) PLAN SPACE EXPLORATION / TRANSFORMATION RULES
      Trivial only runs simplification rules (constant folding, redundant
      predicate removal, etc.). Full also runs exploration rules that expand
      and rewrite the logical tree (view/CTE expansion, predicate pushdown,
      join collapsing) into competing equivalent shapes.
   ============================================================================ */

-- 6a. TRIVIAL: redundant predicate gets simplified away, but the access path
--     was never in question -- no exploration rules needed
SELECT Id, Title
FROM dbo.Posts
WHERE Id = 4 AND 1 = 1
OPTION (RECOMPILE);

-- 6b. FULL: CTE has to be expanded/inlined, predicate pushed down through it,
--     and the resulting join explored/costed -- engages the transformation
--     rule set, not just simplification
;WITH RecentPosts AS
(
    SELECT Id, OwnerUserId, Score
    FROM dbo.Posts
    WHERE CreationDate >= '2013-01-01'
)
SELECT u.DisplayName, rp.Score
FROM RecentPosts rp
JOIN dbo.Users u ON u.Id = rp.OwnerUserId
WHERE rp.Score > 50
OPTION (RECOMPILE);


/* ============================================================================
   7) MEMORY GRANT ITERATION / TUNING
      Trivial plans with no sort/hash/spool need no meaningful memory grant
      to size. Full plans with sorts/hash operators require the optimizer to
      estimate cardinality and size (and, at execution, potentially adjust)
      the memory grant.
   ============================================================================ */

-- 7a. TRIVIAL: single-row seek, no sort or hash operator -- effectively no
--     memory grant to size
SELECT Id, PostTypeId, Score
FROM dbo.Posts
WHERE Id = 4
OPTION (RECOMPILE);

-- 7b. FULL: hash aggregate + sort over a large group-by -- check the actual
--     plan's <MemoryGrantInfo> (GrantedMemory / DesiredMemory / MaxUsedMemory)
--     to see the sizing the optimizer computed from its cardinality estimate
SELECT u.Location, COUNT(*) AS UserCount, AVG(u.Reputation) AS AvgRep
FROM dbo.Users u
WHERE u.Location IS NOT NULL
GROUP BY u.Location
ORDER BY UserCount DESC
OPTION (RECOMPILE);


/* ============================================================================
   TEARDOWN (optional) -- run when you're done experimenting
   ============================================================================
DROP INDEX IF EXISTS IX_Demo_Users_Reputation ON dbo.Users;
DROP INDEX IF EXISTS IX_Demo_Users_Views ON dbo.Users;
*/
