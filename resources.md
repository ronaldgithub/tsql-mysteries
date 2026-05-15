# Resources

## Books
- *SQL Server Query Performance Tuning* — Grant Fritchey
- *SQL Server Execution Plans* — Grant Fritchey (free PDF available)
- *The Art of SQL* — Stéphane Faroult

## Online
- [Brent Ozar's blog](https://www.brentozar.com/blog/) — sp_BlitzIndex, sp_BlitzCache
- [SQLskills.com](https://www.sqlskills.com/) — Paul Randal & Kimberly Tripp
- [Use The Index, Luke](https://use-the-index-luke.com/) — index tuning guide
- [SentryOne Plan Explorer](https://www.sentryone.com/plan-explorer) — free execution plan viewer

## Useful System DMVs

```sql
sys.dm_exec_query_stats          -- cached query plans and stats
sys.dm_exec_procedure_stats      -- stored procedure stats
sys.dm_db_missing_index_details  -- missing index suggestions
sys.dm_db_index_usage_stats      -- which indexes are used/unused
sys.dm_os_wait_stats             -- server-wide wait analysis
```
