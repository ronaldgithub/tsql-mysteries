-- Solution #04: SARGability
-- Fix: Move the function/calculation to the value side, not the column side

-- Instead of YEAR(OrderDate) = 2024:
SELECT * FROM Orders
WHERE OrderDate >= '2024-01-01' AND OrderDate < '2025-01-01';

-- Instead of CONVERT on date:
SELECT * FROM Orders
WHERE OrderDate = '2024-01-01';

-- Instead of LEFT(CustomerCode, 3) = 'ABC':
SELECT * FROM Customers
WHERE CustomerCode LIKE 'ABC%';  -- leading wildcard is still non-SARGable

-- Instead of OrderAmount * 1.1 > 1000:
SELECT * FROM Orders
WHERE OrderAmount > 1000 / 1.1;  -- move math to the value side

-- Instead of UPPER(LastName) = 'SMITH':
-- Option A: fix the collation to be case-insensitive (best long-term)
-- Option B: use a computed column with an index
ALTER TABLE Customers ADD LastNameUpper AS UPPER(LastName);
CREATE INDEX IX_Customers_LastNameUpper ON Customers (LastNameUpper);
SELECT * FROM Customers WHERE LastNameUpper = 'SMITH';
