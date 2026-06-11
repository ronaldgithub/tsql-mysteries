CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_CTE_Temp
AS
BEGIN
    SET NOCOUNT ON;

    ;WITH c AS (
        SELECT TOP 2000 Id, Text
        FROM dbo.Comments
        ORDER BY NEWID()
    )
    SELECT *
    INTO #tmp
    FROM c;

    SELECT TOP 2000
        Id,
        HASHBYTES('SHA2_256', Text)
    FROM #tmp
    ORDER BY NEWID();
END
GO
