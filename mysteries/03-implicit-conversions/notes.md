# Mystery #03: Implicit Conversions

## Symptoms
- Index exists on column but execution plan shows a Scan instead of a Seek
- CONVERT_IMPLICIT appears in the execution plan
- Query slow despite good indexing

## What to look for in the execution plan
- Yellow warning triangle on SELECT or Filter operator
- Hover over it — shows "Type conversion in expression may affect CardinalityEstimate"
- CONVERT_IMPLICIT in the XML of the plan

## Common causes
| Column Type | Parameter Type | Result |
|-------------|---------------|--------|
| VARCHAR | NVARCHAR (N'...') | Implicit conversion, index skipped |
| INT | VARCHAR | Implicit conversion |
| DATE | DATETIME | Sometimes safe, sometimes not |

## Key Takeaways
- Always match parameter data types to column definitions exactly
- Be careful with ORM-generated queries — they often use NVARCHAR by default
- Use `sys.dm_exec_query_plan` to find CONVERT_IMPLICIT across the server
