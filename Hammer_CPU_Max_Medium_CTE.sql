CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Medium_CTE
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH base AS (
        SELECT TOP 1500 Id, Text
        FROM dbo.Comments
        ORDER BY NEWID()
    ),
    r1 AS (
        SELECT Id, REPLACE(Text, 'a', 'aa') AS T
        FROM base
    ),
    r2 AS (
        SELECT Id, REPLACE(T, 'e', 'ee') AS T
        FROM r1
    ),
    r3 AS (
        SELECT Id, REPLACE(T, 'i', 'ii') AS T
        FROM r2
    )
    SELECT Id, HASHBYTES('SHA2_256', T)
    FROM r3;
END
GO
