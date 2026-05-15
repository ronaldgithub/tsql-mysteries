# Mystery #01: Missing Index

## Symptoms
- High logical reads
- Table Scan or Index Scan in execution plan
- Query slows as table grows

## What to look for in the execution plan
- Green "Missing Index" hint at the top of the plan
- Table Scan operator (reads every row)
- High estimated vs actual row count differences

## Key Takeaways
- Composite indexes should have equality columns first, range columns last
- Use INCLUDE for columns only in SELECT — keeps the index narrower
- Check `sys.dm_db_missing_index_details` for SQL Server suggestions
