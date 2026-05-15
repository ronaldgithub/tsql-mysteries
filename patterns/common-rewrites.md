# Common T-SQL Rewrite Patterns

## 1. EXISTS vs IN vs JOIN for existence checks
```sql
-- Avoid: IN with subquery (can be slow with NULLs)
SELECT * FROM Orders WHERE CustomerID IN (SELECT CustomerID FROM VIPCustomers);

-- Better: EXISTS
SELECT * FROM Orders o WHERE EXISTS (
    SELECT 1 FROM VIPCustomers v WHERE v.CustomerID = o.CustomerID
);
```

## 2. Avoid SELECT *
```sql
-- Bad: fetches all columns, prevents covering indexes
SELECT * FROM Orders WHERE Status = 'Pending';

-- Good: fetch only what you need
SELECT OrderID, OrderDate, CustomerID FROM Orders WHERE Status = 'Pending';
```

## 3. Set-based vs Cursor
```sql
-- Avoid: row-by-row cursor
DECLARE cur CURSOR FOR SELECT OrderID FROM Orders WHERE Status = 'New';
-- ... FETCH / UPDATE loop

-- Better: single UPDATE statement
UPDATE Orders SET Status = 'Processing' WHERE Status = 'New';
```

## 4. Pagination with OFFSET/FETCH
```sql
-- Old pattern (slow on large pages)
SELECT TOP 10 * FROM (
    SELECT ROW_NUMBER() OVER (ORDER BY OrderDate) AS rn, *
    FROM Orders
) x WHERE rn BETWEEN 91 AND 100;

-- Modern pattern
SELECT OrderID, OrderDate FROM Orders
ORDER BY OrderDate
OFFSET 90 ROWS FETCH NEXT 10 ROWS ONLY;
```

## 5. Conditional aggregation instead of multiple passes
```sql
-- Avoid: multiple queries or UNION
SELECT 'Pending' AS Status, COUNT(*) FROM Orders WHERE Status = 'Pending'
UNION ALL
SELECT 'Shipped', COUNT(*) FROM Orders WHERE Status = 'Shipped';

-- Better: one pass
SELECT
    COUNT(CASE WHEN Status = 'Pending' THEN 1 END) AS Pending,
    COUNT(CASE WHEN Status = 'Shipped' THEN 1 END) AS Shipped
FROM Orders;
```
