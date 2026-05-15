# Mystery #02: Parameter Sniffing

## Symptoms
- Stored proc runs fast in dev, slow in prod
- Same proc fast for one user, slow for another
- Flushing cache with DBCC FREEPROCCACHE fixes it temporarily

## What to look for in the execution plan
- Compare "Estimated Rows" vs "Actual Rows" — large gap = sniffing issue
- Right-click plan > Properties > Parameter List shows sniffed vs compiled values

## Diagnosis
```sql
-- See cached plan and sniffed parameters
SELECT  qp.query_plan, qs.execution_count, qs.total_elapsed_time
FROM    sys.dm_exec_procedure_stats ps
CROSS APPLY sys.dm_exec_query_plan(ps.plan_handle) qp
CROSS APPLY sys.dm_exec_sql_text(ps.sql_handle) qs
WHERE   OBJECT_NAME(ps.object_id) = 'GetOrdersByCustomer';
```

## Key Takeaways
- OPTION (RECOMPILE) is safest but adds CPU cost per execution
- Local variable trick is simple but loses all parameter statistics
- OPTIMIZE FOR UNKNOWN is a good middle ground for skewed data
