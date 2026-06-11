CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Mild_CTE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH c1 AS (
        SELECT TOP 2000 Id, Text
        FROM dbo.Comments
        ORDER BY NEWID()
    ),
    c2 AS (
        SELECT Id,
               LEN(Text) AS L,
               CHARINDEX('sql', Text) AS Pos1
        FROM c1
    ),
    c3 AS (
        SELECT Id,
               L,
               Pos1,
               PATINDEX('%[0-9][0-9][0-9]%', (SELECT Text FROM dbo.Comments WHERE Id = c2.Id)) AS Pos2
        FROM c2
    )
    SELECT *
    FROM c3;
END
GO
