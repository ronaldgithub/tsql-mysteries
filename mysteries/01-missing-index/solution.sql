-- Solution #01: Missing Index
-- Fix: Create a composite index covering the WHERE and JOIN columns
-- Include columns used in SELECT to avoid key lookups

CREATE INDEX IX_Orders_Status_OrderDate
    ON Orders (Status, OrderDate)
    INCLUDE (CustomerID, OrderID);

-- Rewritten query is identical — the index does the work
SELECT
    o.OrderID,
    o.OrderDate,
    c.CustomerName
FROM Orders o
JOIN Customers c ON o.CustomerID = c.CustomerID
WHERE o.OrderDate >= '2024-01-01'
  AND o.Status = 'Pending';
