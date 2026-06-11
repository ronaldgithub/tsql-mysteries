CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_CursorLoop
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @txt NVARCHAR(MAX);
    DECLARE @agg NVARCHAR(MAX) = N'';
    DECLARE @i INT = 0;

    DECLARE cur CURSOR FAST_FORWARD FOR
        SELECT TOP 500 Text
        FROM dbo.Comments
        ORDER BY NEWID();

    OPEN cur;
    FETCH NEXT FROM cur INTO @txt;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @agg += LEFT(@txt, 100);
        SET @i += 1;

        FETCH NEXT FROM cur INTO @txt;
    END

    CLOSE cur;
    DEALLOCATE cur;

    SELECT LEN(@agg) AS TotalLength, @i AS RowsProcessed;
END
GO
