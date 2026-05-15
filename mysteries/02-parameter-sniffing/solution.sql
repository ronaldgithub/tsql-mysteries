-- Solution #02: Parameter Sniffing
-- Option A: OPTIMIZE FOR UNKNOWN — use average statistics, not sniffed value
CREATE OR ALTER PROCEDURE GetOrdersByCustomer
    @CustomerID INT
AS
BEGIN
    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders
    WHERE CustomerID = @CustomerID
    ORDER BY OrderDate DESC
    OPTION (OPTIMIZE FOR (@CustomerID UNKNOWN));
END;

-- Option B: Local variable trick — prevents sniffing entirely
CREATE OR ALTER PROCEDURE GetOrdersByCustomer
    @CustomerID INT
AS
BEGIN
    DECLARE @LocalCustomerID INT = @CustomerID;

    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders
    WHERE CustomerID = @LocalCustomerID
    ORDER BY OrderDate DESC;
END;

-- Option C: RECOMPILE — generates a fresh plan every execution (use sparingly)
CREATE OR ALTER PROCEDURE GetOrdersByCustomer
    @CustomerID INT
AS
BEGIN
    SELECT OrderID, OrderDate, TotalAmount
    FROM Orders
    WHERE CustomerID = @CustomerID
    ORDER BY OrderDate DESC
    OPTION (RECOMPILE);
END;
