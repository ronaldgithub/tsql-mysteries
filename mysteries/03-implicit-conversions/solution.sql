-- Solution #03: Implicit Conversions
-- Fix: Match the data type exactly — remove the N prefix for VARCHAR columns

SELECT *
FROM Customers
WHERE CustomerCode = 'ABC123';  -- VARCHAR matches column type, index is used

-- In stored procedures: declare parameters with matching types
CREATE OR ALTER PROCEDURE GetCustomer
    @CustomerCode VARCHAR(20)  -- must match column definition
AS
BEGIN
    SELECT * FROM Customers WHERE CustomerCode = @CustomerCode;
END;

-- Find implicit conversions currently happening on your server:
SELECT  TOP 20
        qs.total_logical_reads,
        qs.execution_count,
        SUBSTRING(qt.text, (qs.statement_start_offset/2)+1,
            ((CASE qs.statement_end_offset WHEN -1 THEN DATALENGTH(qt.text)
              ELSE qs.statement_end_offset END - qs.statement_start_offset)/2)+1) AS query_text,
        qp.query_plan
FROM    sys.dm_exec_query_stats qs
CROSS APPLY sys.dm_exec_sql_text(qs.sql_handle) qt
CROSS APPLY sys.dm_exec_query_plan(qs.plan_handle) qp
WHERE   CAST(qp.query_plan AS NVARCHAR(MAX)) LIKE '%CONVERT_IMPLICIT%'
ORDER BY qs.total_logical_reads DESC;
