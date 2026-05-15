-- Mystery #01: Missing Index
-- Symptom: Query is slow on large tables, high logical reads
-- Look for: Table Scan or Index Scan in execution plan

SELECT
    o.OrderID,
    o.OrderDate,
    c.CustomerName
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= '2024-01-01'
  AND o.Status = 'Pending';
