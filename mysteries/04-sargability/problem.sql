-- Mystery #04: SARGability (Search ARGument Able)
-- Symptom: WHERE clause wraps a column in a function — index is bypassed
-- A predicate is non-SARGable when SQL Server cannot use an index seek for it

-- Non-SARGable examples:
SELECT * FROM Orders WHERE YEAR(OrderDate) = 2024;           -- function on column
SELECT * FROM Orders WHERE CONVERT(VARCHAR, OrderDate, 101) = '01/01/2024';
SELECT * FROM Customers WHERE LEFT(CustomerCode, 3) = 'ABC';
SELECT * FROM Orders WHERE OrderAmount * 1.1 > 1000;         -- math on column
SELECT * FROM Customers WHERE UPPER(LastName) = 'SMITH';
