CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Hot_CTE
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @seed NVARCHAR(MAX) =
        (SELECT TOP 1 Text FROM dbo.Comments ORDER BY NEWID());

    ;WITH rec AS (
        SELECT 1 AS n, @seed AS txt
        UNION ALL
        SELECT n + 1,
               txt + SUBSTRING(txt, 1, 100)
        FROM rec
        WHERE n < 50
    )
    SELECT n, LEN(txt)
    FROM rec
    OPTION (MAXRECURSION 0);
END
GO
