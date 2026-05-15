-- Mystery #03: Implicit Conversions
-- Symptom: Index exists but isn't used, full scan instead
-- Cause: Column is VARCHAR but parameter/value is NVARCHAR (or vice versa)

-- Table column: CustomerCode VARCHAR(20)
-- This causes an implicit conversion — index cannot be used
SELECT *
FROM Customers
WHERE CustomerCode = N'ABC123';  -- N prefix makes this NVARCHAR
