-- Mystery #02: Parameter Sniffing
-- Symptom: Stored proc is fast sometimes, slow other times
-- Cause: SQL Server cached a plan optimized for the first parameter value

CREATE OR ALTER PROCEDURE GetOrdersByCustomer
    @CustomerID INT
AS
BEGIN
    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders
    WHERE CustomerID = @CustomerID
    ORDER BY OrderDate DESC;
END;
