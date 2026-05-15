# Execution Plan Reading Tips

## How to get an execution plan in SSMS
- **Estimated plan**: `Ctrl+L` (no query runs)
- **Actual plan**: `Ctrl+M` then run the query
- **Live query stats**: Query menu > Include Live Query Statistics

## Key operators to know

| Operator | Meaning |
|----------|---------|
| **Table Scan** | No usable index — reads every row |
| **Index Scan** | Uses index but reads all rows in it |
| **Index Seek** | Efficient — jumps to matching rows |
| **Key Lookup** | Extra trip to clustered index for missing columns |
| **Hash Match** | Join/aggregate with no useful order — memory intensive |
| **Nested Loops** | Good for small outer inputs |
| **Sort** | Expensive if not covered by index order |

## Warning signs (yellow triangle)
- Implicit type conversion
- No join predicate
- Spill to TempDB (memory pressure)

## Cost reading tips
- Cost % on each operator = relative cost within the plan
- Thick arrows = many rows flowing — follow the fat arrows
- Actual vs Estimated rows diverging = stale statistics or parameter sniffing

## Useful queries

```sql
-- Force actual plan for a specific query
SET STATISTICS IO ON;
SET STATISTICS TIME ON;
-- run your query
SET STATISTICS IO OFF;
SET STATISTICS TIME OFF;

-- Update statistics on a table
UPDATE STATISTICS dbo.Orders WITH FULLSCAN;

-- See all indexes on a table
SELECT * FROM sys.indexes WHERE object_id = OBJECT_ID('dbo.Orders');
```
