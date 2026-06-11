CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Mild
AS
BEGIN
    SET NOCOUNT ON;

    -- Mild CPU: simple string scans
    SELECT TOP 2000
        LEN(Text),
        CHARINDEX('sql', Text),
        PATINDEX('%[0-9][0-9][0-9]%', Text)
    FROM dbo.Comments
    ORDER BY NEWID();
END
GO
