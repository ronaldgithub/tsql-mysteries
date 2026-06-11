CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Hot
AS
BEGIN
    SET NOCOUNT ON;

    -- Hot CPU: JSON parsing + hashing
    SELECT *
    FROM OPENJSON((
        SELECT TOP 2000 Text
        FROM dbo.Comments
        ORDER BY NEWID()
        FOR JSON AUTO
    ));
END
GO
