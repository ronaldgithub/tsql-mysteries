# Mystery #04: SARGability

## What is SARGability?
A WHERE predicate is **SARGable** if SQL Server can use an index seek to evaluate it.
Wrapping a column in a function forces SQL Server to evaluate every row — turning a seek into a scan.

## Non-SARGable patterns to avoid
| Bad (non-SARGable) | Good (SARGable) |
|--------------------|-----------------|
| `YEAR(col) = 2024` | `col >= '2024-01-01' AND col < '2025-01-01'` |
| `LEFT(col, 3) = 'ABC'` | `col LIKE 'ABC%'` |
| `col * 1.1 > 1000` | `col > 909.09` |
| `UPPER(col) = 'X'` | Fix collation or use computed column |
| `ISNULL(col, 0) = 0` | `col IS NULL OR col = 0` |
| `DATEPART(dw, col) = 1` | Store day-of-week separately |

## What to look for in the execution plan
- Index Scan instead of Index Seek
- High "Estimated Rows" relative to actual results
- No visible index benefit despite index existing on the column

## Key Takeaways
- The rule: never apply a function to the column side of a WHERE predicate
- Move all transformations to the value (right-hand) side
- Leading `%` wildcards (`LIKE '%ABC'`) are also non-SARGable
