# T-SQL Mysteries

A collection of real-world T-SQL investigations covering slow queries, execution plan analysis, and query rewrites.

## Structure

```
mysteries/          # Each mystery is a self-contained case
patterns/           # Reusable rewrite patterns and tips
execution-plans/    # Saved .sqlplan files for reference
```

## How Each Mystery Works

Each mystery folder contains:
- `problem.sql` — the original slow or broken query
- `solution.sql` — the rewrite with explanation
- `notes.md` — execution plan walkthrough and key findings

## Mysteries

| # | Title | Topic |
|---|-------|-------|
| 01 | [Missing Index](mysteries/01-missing-index/) | Index tuning |
| 02 | [Parameter Sniffing](mysteries/02-parameter-sniffing/) | Plan caching |
| 03 | [Implicit Conversions](mysteries/03-implicit-conversions/) | Data types |
| 04 | [SARGability](mysteries/04-sargability/) | WHERE clause rewrites |

## Tools Used

- SQL Server Management Studio (SSMS) 22
- SQL Server execution plans (.sqlplan)
- T-SQL
