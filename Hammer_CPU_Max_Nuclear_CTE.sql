CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Nuclear_CTE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH a AS (
        SELECT TOP 500 Id, Text
        FROM dbo.Comments
        WHERE Id % 500 = 0
        ORDER BY NEWID()
    ),
    b AS (
        SELECT TOP 500 Id, Text
        FROM dbo.Comments
        WHERE Id % 500 = 0
        ORDER BY NEWID()
    ),
    x AS (
        SELECT a.Id AS AId,
               b.Id AS BId,
               a.Text AS AText,
               b.Text AS BText
        FROM a
        CROSS JOIN b
    )
    SELECT TOP 20000
        AId,
        BId,
        HASHBYTES('SHA2_256', AText + BText)
    FROM x
    ORDER BY NEWID();
END
GO
