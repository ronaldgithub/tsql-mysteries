# tsql-mysteries

A collection of standalone T-SQL scripts for exploring SQL Server query performance and behavior against the [StackOverflow2010](https://www.brentozar.com/archive/2015/10/how-to-download-the-stack-overflow-database-via-bittorrent/) sample database.

There's no build system, package manager, or test suite here — just `.sql` files meant to be opened in SQL Server Management Studio (or run via `sqlcmd`) against a SQL Server-compatible instance with the StackOverflow2010 database restored. None of the scripts contain a `USE` statement or connection details; point your session at the target database before running them.

## Contents

### `Hammer_*.sql`

Intentionally inefficient stored procedures that reproduce specific SQL Server performance problems — CPU pressure, join strategy choice, parameter sniffing — for teaching and diagnostics. Several files come in escalating variants (`Mild` → `Medium` → `Hot` → `Nuclear`) to show how much worse a pattern can get. A few (`Hammer_CPU_Packaged.sql`, `Hammer_ParameterSniffing.sql`, `Hammer_StackOverflow.sql`) pick a random branch on each execution, so running the same procedure repeatedly exercises different bad patterns. `Hammer_Perf_Advanced.sql` and `Hammer_Perf_Diagnostics.sql` are DMV-based diagnostic toolkits rather than stress generators.

### `Strings.sql`

A running catalog of T-SQL string functions, one section per function, each linking to its official [Microsoft Learn](https://learn.microsoft.com/en-us/sql/t-sql/functions/string-functions-transact-sql) documentation. Each demo query appends `WHERE 1 = (SELECT 1)` — a predicate that filters nothing but adds enough estimated cost to nudge the optimizer toward a parallel plan — so the resulting plans are useful for comparing how these functions behave under parallelism. Run one batch (`GO`-separated) at a time in SSMS with "Include Actual Execution Plan" enabled.

### `*.sqlplan`

Captured actual execution plans (`SET STATISTICS XML ON` output) for the queries in `Strings.sql`, named `string_<FUNCTION>_<p|s>.sqlplan` — `p` if that query's plan went parallel, `s` if it stayed serial. These reflect one run against a specific dataset and server configuration (cost threshold for parallelism, MAXDOP), not a universal guarantee.

## License

[MIT](LICENSE)
