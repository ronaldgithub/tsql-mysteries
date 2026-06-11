CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Nuclear
AS
BEGIN
    SET NOCOUNT ON;

    -- Nuclear CPU: cross join explosion
    SELECT TOP 20000
        c1.Id,
        c2.Id,
        HASHBYTES('SHA2_256', c1.Text + c2.Text)
    FROM dbo.Comments c1
    CROSS JOIN dbo.Comments c2
    WHERE c1.Id % 500 = 0
      AND c2.Id % 500 = 0
    ORDER BY NEWID();
END
GO
