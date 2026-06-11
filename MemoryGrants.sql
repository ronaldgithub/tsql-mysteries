/* Learn T-SQL With Erik: Memory Grants Intro

https://www.youtube.com/watch?v=zCroamvgURM
*/


USE StackOverflow2013;
EXECUTE dbo.Dropindexes;
SET NOCOUNT ON;
DBCC FREEPROCCACHE;

ALTER DATABASE StackOverflow2013 SET COMPATIBILITY_LEVEL = 160 ; 
GO

/*
If I run this, there's one Sort
* The query asks for 182MB of memory for it
* No index to support my order by...
* Id is only an integer
*/

SELECT u.*
FROM
(
SELECT TOP (1000) u.Id
FROM dbo.Users AS u
ORDER BY u.Reputation
, u.Id
) AS u	
OPTION (MAXDOP 1);

SELECT u.*
FROM
(
SELECT TOP (1000) u.Id
FROM dbo.Users AS u
ORDER BY u.Reputation
, u.Id
) AS u	
OPTION (MAXDOP 2);

SELECT u.*
FROM
(
SELECT TOP (1000) u.Id
FROM dbo.Users AS u
ORDER BY u.Reputation
, u.Id
) AS u	
OPTION (MAXDOP 4);

SELECT u.*
FROM
(
SELECT TOP (1000) u.Id
FROM dbo.Users AS u
ORDER BY u.Reputation
, u.Id
) AS u	
OPTION (MAXDOP 8);

SELECT u.*
FROM
(
SELECT TOP (1000) u.Id
FROM dbo.Users AS u
ORDER BY u.Reputation
, u.Id
) AS u	
OPTION (MAXDOP 16);

SELECT u.*
FROM
(
SELECT TOP (1000) u.Id
FROM dbo.Users AS u
ORDER BY u.Reputation
, u.Id
) AS u	
OPTION (MAXDOP 32);

SELECT u.*
FROM
(
SELECT TOP (1000) u.Id
FROM dbo.Users AS u
ORDER BY u.Reputation
, u.Id
) AS u	
OPTION (MAXDOP 64);

/*
If I run this query, there are two Sorts
But the memory grant is about the same (182MB + 1MB Hash Join)
It goes up a little for the Hash Join

The blocking operation during the Hash Join (building the hash table) allows them to reuse memory
*/

SELECT u.*
, u2.*
FROM (
	SELECT TOP (1000) u.Id
	FROM dbo.Users AS u
	ORDER BY
	  u.Reputation
	, u.Id
	) AS u 
JOIN (
	SELECT TOP (1000) u.Id
	FROM dbo.Users AS u
	ORDER BY
	u.Reputation, u.Id
) AS u2
ON u.Id = u2.Id
OPTION (MAXDOP 1);

/* Share Memory between operators (Is the operator blocking?) 
If we force a Nested Loop Join, the memory grant doubles
* With no blocking operator, grants can't be reused
Nested loops doesn't block anything, it just starts looking for rows on 
the inner side as soon as they arrive
*/

-- 364 MB = 2 x 182MB
SELECT
u.*
, u2.* 
FROM (
	SELECT TOP (1000)
	u.Id 
	FROM dbo.Users AS u ORDER BY
	u.Reputation, u.Id
) AS u
INNER LOOP JOIN -- Force the loop join (are not stop and go operators)
(
	SELECT TOP (1000) u.Id
	FROM dbo.Users AS u
	ORDER BY
	u.Reputation, u.Id
) AS u2
ON u.Id = u2.Id
OPTION (MAXDOP 1);

/*
If I run this, there's still only one Sort, but as we add columns, 
the memory grant gets larger

Optimizer makes a fuzzy guess for string columns:
* They'll be half full.
* Or half empty.	
* Depends on how you look at it.

Check out the arrow going into the Sort for data size
*/

SELECT
u.*
FROM
(
	SELECT TOP (1000) 
	 u.Id			-- 182MB	(integer)	
	,u.DisplayName	-- 327MB	(nvarchar	40)
	,u.WebsiteUrl	-- 992MB	(nvarchar	200)
	,u.Location		-- 1.3GB	(nvarchar	100)
	,u.AboutMe		--  10GB	(nvarchar	MAX)
	FROM dbo.Users AS u ORDER BY
	u.Reputation, u.Id
) AS u
OPTION(MAXDOP 1, RECOMPILE);

SELECT 
    requested_memory_kb / 1024 AS RequestedMB,
    granted_memory_kb / 1024 AS GrantedMB,
    used_memory_kb / 1024 AS UsedMB,
    ideal_memory_kb / 1024 AS IdealMB,
     *
FROM sys.dm_exec_query_memory_grants;



/*

This is a good strategy when parallel row distributions are close-enough to equal
, but there are definitely times when that will not be the case. 
Think back to the Red Flags modules where I showed you a query that had all rows 
end up on a single thread. That would suck here.

We must be careful with memory grants!
* Bad estimates can inflate them
* Selecting a lot of columns can inflate them
* Especially strings	
* You can put data in order with indexes

Let's look at three ways to reduce a big memory grant, caused by a Window Function Sort:
1.	Narrow index
2.	Query rewrite (APPLY)
3.	Query rewrite (Self-Join)

*/


SELECT
  u.*
, u2.*
FROM
(
	SELECT TOP (1000) u.Id
	FROM dbo.Users AS u
	ORDER BY
	u.Reputation, u.Id
) AS u
INNER HASH JOIN
(
	SELECT TOP (1000) u.Id
	FROM dbo.Users AS u
	ORDER BY
	u.Reputation,
	u.Id
) AS u2
ON u.Id = u2.Id
ORDER BY u.Id ,u2.Id
OPTION (MAXDOP 8); 





/* Learn T SQL With Erik Controlling Memory Grants 

https://www.youtube.com/watch?v=PWjSXz-5nys&t=593s

*/

CREATE INDEX UserId_Score
ON dbo.Comments (Userid, Score) WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
GO

CREATE INDEX UserId_ScoreInclude ON dbo.Comments (Userid) INCLUDE (Score)
WITH (SORT_IN_TEMPDB = ON, DATA_COMPRESSION = PAGE);
GO

/*
For perspective, Row Mode.
* 43 seconds
* 10GB memory grant
* Sort still spills
*/

SELECT u.Id
, u.DisplayName
, c.Text
FROM dbo.Users AS u
JOIN
(
	SELECT
	c.*,
	n = ROW_NUMBER() OVER( PARTITION BY	c.UserId ORDER BY c.Score DESC, c.Id DESC)
	FROM dbo.Comments AS c
	) AS c
ON c.UserId = u.Id
WHERE u.Reputation >= 100000
AND c.n = 1
ORDER BY
u.Reputation DESC, u.Id DESC
OPTION (USE HINT('QUERY_OPTIMIZER_COMPATIBILITY_LEVEL_140' )
, RECOMPILE
);

/* Fix big memory grant?
a) Indexes support ordering (geen hash agg/hash join)
    Exploring Query Plans and Sort Operators
b) Separate columns 'information set' versus 'relational set'
   Separating Informational from Relational Columns
c) Rewrite more small sorts instead big sorts
   Using Cross-Apply for Smaller Sorts

*/

/*

Batch mode solves a lot of problems here *2.5 seconds
* No spill
* Still a 10GB memory grant though
Parallel batch mode operates on shared structures (hash tables), 
so an even split between threads doesn’t matter (as much).

*/

SELECT u.Id
, u.DisplayName
, c.Text
FROM dbo.Users AS u
JOIN
(
	SELECT
	c.*,
	n = ROW_NUMBER() OVER( PARTITION BY	c.UserId ORDER BY c.Score DESC, c.Id DESC)
	FROM dbo.Comments AS c
	) AS c
ON c.UserId = u.Id
WHERE u.Reputation >= 100000
AND c.n = 1
ORDER BY
u.Reputation DESC, u.Id DESC

/*
With a narrow key index, we can get this down to ~1.5 seconds on (UserId, Score).
*/

SELECT u.Id
, u.DisplayName
, c.Text
FROM dbo.Users AS u
CROSS APPLY
(
	SELECT *
	, n = ROW_NUMBER() OVER (PARTITION BY c.Userid ORDER BY c.Score DESC, c.id DESC)
	FROM dbo.Comments AS c WITH (INDEX = UserId_Score)
	WHERE c.Userid = u.Id 
) AS c 
WHERE u.Reputation >= 100000
AND c.n = 1
ORDER BY
u.Reputation DESC, u.Id DESC;


/*
We could get it down to ~500ms if we added in all the other columns as Includes. 
About 1 second of time is spent doing a Key Lookup.

The memory grant is down to 5,376KB, much lower than the initial 10GB! Cool, cool.
The trouble is that the optimizer will rarely choose this index naturally. 
We had to use an index hint for it to happen, and if we had more rows coming from the Users 
table (say we change the filter on Reputation to a much lower number) the time spent
in the lookup would get much worse.
*/

/* Lower predicate  From 100,000 to 10,000 */ 
SELECT
  u.Id
, u.DisplayName
, c.Text
FROM dbo.Users u
CROSS APPLY
( 
SELECT
 c.*
 , n = ROW_NUMBER() OVER (PARTITION BY c.Userid ORDER BY c.Score DESC,c.Id DESC)
FROM dbo.Comments AS c
WITH (INDEX = UserId_Score)
WHERE c.Userid = u.id
) AS c	
WHERE u.Reputation >= 10000
AND c.n = 1
ORDER BY
u.Reputation DESC, u.id DESC;

/*
The memory grant is still lower, and if that's all we're tuning for, 
we might choose to eat the time, or consider widening the index to Include c.Text.
For a small number of columns, this is a rather attractive arrangement. 
I don't want to dissuade you from employing it as a solution here. 
I do want you to think carefully before jumping to it, thought. Think!

Even with a non-ideal, but still narrow key index on (UserId, Include Score) 
we can reduce the memory grant to 1,417MB by using the APPLY pattern. 
This beats the Join pattern because the sort is done once-per-loop, rather than for the full table result.
We do 613 smaller Sorts here, which is a very cool trick.

*/

SELECT
  u.Id
, u.DisplayName 
, c.Text
FROM dbo.Users AS u
CROSS APPLY
(
	SELECT	c.*
	, n = ROW_NUMBER() OVER ( /*PARTITION BY c.Userid*/ ORDER BY c.Score DESC, c.Id DESC)
	FROM dbo.Comments AS c
	WITH (INDEX = UserId_ScoreInclude) 
	WHERE c.Userid = u.Id
) AS c
WHERE u.Reputation >= 100000
AND c.n = 1
ORDER BY u.Reputation DESC, u.Id DESC;

/*
Note that the Sort is back, since Score is no longer an index key column. 
We could also not put UserId as a PARTITION BY element as well, 
because we are logically partitioning with the correlation in 
the CROSS APPLY: WHERE c.Userid = u.Id

We can’t do that with the derived join, because like we learned in the beginner material, 
tables outside of the JOIN(...) can’t be referenced inside of the JOIN(...).
We can also use a self join to do something along the same lines. 
First, is to only get the two Join keys (UserId, Id) in the Select list while generating the row number. 
Second, is to add a Join to Comments (kinda like a self-service Key Lookup) to get 
the Text column for just the rows we’ve filtered to. 
This finishes in ~1.2 seconds and only asks for a 1,070MB memory grant.
Also cool.
*/

SELECT u.Id
, u.DisplayName  
, cl.Text
FROM dbo.Users AS u
JOIN
(
	SELECT
	/*Narrow column retrieval*/ 
	c.id
	, c.UserId 
	, n = ROW_NUMBER() OVER (PARTITION BY c.UserId ORDER BY c.Score DESC, c.id DESC)
   FROM dbo.Comments AS c
   ) AS c0
ON c0.Userid = u.Id
/* Join on primary key to get Text */ 
JOIN dbo.Comments AS cl
ON cl.Id = c0.Id
WHERE u.Reputation >= 100000 
AND c0.n = 1 ORDER BY
u.Reputation DESC, u.Id DESC;


/*
It often pays to mentally separate column usage in queries that you’re 
having performance problems with into two categories: Relational and informational.

Relational:
* WHERE
* ON 	
* GROUP/PARTITION/ORDER BY

Informational:
* SELECT list only

Once you do that, you can often start improving many metrics (like memory grants!) 
by separating data access for these purposes in your queries.
*/

























