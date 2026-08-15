# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repository is

A flat collection of standalone T-SQL (`.sql`) scripts, all written against the **StackOverflow2010** sample database (some also assume `StackOverflow2013`). There is no build system, package manager, linter, or test suite — these are scripts meant to be opened in SSMS or run via `sqlcmd`/`osql` against a live SQL Server-compatible instance (tested against Azure SQL Edge and mainline SQL Server; compatibility level 150 in the reference environment).

No connection string or credentials are stored in this repo. Every script assumes the connection is already pointed at the target database — none use `USE <db>;` or three-part names; tables are referenced as `dbo.<Table>`.

## Two families of scripts

**`Hammer_*.sql`** — intentionally inefficient stored procedures used to demonstrate specific SQL Server performance problems (CPU pressure, join strategies, parameter sniffing) for teaching/diagnostic purposes. Naming: `Hammer_<Category>_<Variant>.sql`, e.g. `Hammer_CPU_Max_{Mild,Medium,Hot,Nuclear}[_CTE].sql` — each variant escalates how badly the query behaves, for demonstrating progressively worse impact. Most are `CREATE OR ALTER PROCEDURE dbo.Hammer_<Name> ... GO`. Several (`Hammer_CPU_Packaged.sql`, `Hammer_ParameterSniffing.sql`, `Hammer_StackOverflow.sql`) use a dispatcher pattern — `DECLARE @q INT = ABS(CHECKSUM(NEWID())) % N + 1;` followed by a run of `IF @q = k BEGIN ... END` branches — so repeated executions of the same proc randomly exercise different bad patterns. `Hammer_Perf_Advanced.sql` and `Hammer_Perf_Diagnostics.sql` are diagnostic toolkits (DMV queries) rather than stress generators.

**`Strings.sql`** — a running catalog of T-SQL string functions, one section per function, each linking to its official Microsoft Learn docs page. Unlike the `Hammer_*` files, this is **not** a stored procedure: it's a sequence of standalone batches separated by `GO`, meant to be run one at a time in SSMS with "Include Actual Execution Plan" enabled. Every query deliberately appends `WHERE 1 = (SELECT 1)` — a correlated scalar-subquery predicate that filters nothing but adds a per-row CPU cost estimate, nudging the optimizer's plan cost above the parallelism threshold so a parallel plan is more likely. Demo queries mostly run against `dbo.Posts` (the largest table, ~3.7M rows in the reference dataset) to make that trick reliable; a few use `dbo.Users`/`dbo.Comments` where a second column or an aggregation fits the function better (e.g. `DIFFERENCE`/`SOUNDEX` on `DisplayName`, `STRING_AGG` grouped by post).

Known version-compatibility caveats baked into `Strings.sql`, worth checking before adding new sections:
- `COMPRESS`, `DECOMPRESS`, and `FORMAT` require CLR integration enabled on the target instance — they fail outright if it's off.
- `STRING_SPLIT`'s `enable_ordinal` third argument requires SQL Server 2022+ or Azure SQL Database proper; the broadly-compatible 2-argument form is used instead, so output order isn't guaranteed.
- `STRING_AGG` output is capped at 8000 bytes by default and **errors** (rather than silently truncating) if exceeded — inputs must be cast to a LOB type (e.g. `NVARCHAR(MAX)`) when aggregating a column that can produce a long result, like `Comments.Text` across many rows.

## `.sqlplan` files

`string_<FUNCTION>_<p|s>.sqlplan` files at the repo root are actual execution plans (raw `ShowPlanXML`, captured via `SET STATISTICS XML ON`) for the matching query in `Strings.sql`. The `p`/`s` suffix records whether that query's plan went parallel or stayed serial on the reference dataset — it's a snapshot tied to that data volume and server configuration (cost threshold, MDOP), not a guarantee for other environments.
