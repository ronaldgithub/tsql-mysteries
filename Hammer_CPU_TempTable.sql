CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_TempTable
AS
BEGIN
    SET NOCOUNT ON;

    CREATE TABLE #t
    (
        Id INT IDENTITY(1,1),
        Txt NVARCHAR(MAX)
    );

    INSERT INTO #t (Txt)
    SELECT TOP 2000 Text
    FROM dbo.Comments
    ORDER BY NEWID();

    SELECT 
        Id,
        LEN(Txt) AS L,
        CHARINDEX('sql', Txt) AS Pos1,
        PATINDEX('%[0-9][0-9][0-9]%', Txt) AS Pos2
    FROM #t
    ORDER BY NEWID();
END
GO
