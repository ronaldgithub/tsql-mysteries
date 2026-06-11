CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_RecursiveTemp
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #seed (Txt NVARCHAR(MAX));

    INSERT INTO #seed
    SELECT TOP 1 Text
    FROM dbo.Comments
    ORDER BY NEWID();

    DECLARE @s NVARCHAR(MAX) = (SELECT Txt FROM #seed);

    ;WITH r AS (
        SELECT 1 AS n, @s AS txt
        UNION ALL
        SELECT n + 1,
               txt + SUBSTRING(txt, 1, 200)
        FROM r
        WHERE n < 40
    )
    SELECT n, LEN(txt)
    FROM r
    OPTION (MAXRECURSION 0);
END
GO
