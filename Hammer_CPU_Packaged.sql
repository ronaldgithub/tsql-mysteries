CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Packaged
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @q INT = ABS(CHECKSUM(NEWID())) % 6 + 1;

    --------------------------------------------------------------------
    -- 1. Temp Table + String Ops
    --------------------------------------------------------------------
    IF @q = 1
    BEGIN
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

    --------------------------------------------------------------------
    -- 2. Table Variable + REPLACE() Pipeline
    --------------------------------------------------------------------
    IF @q = 2
    BEGIN
        DECLARE @t TABLE
        (
            Id INT,
            Txt NVARCHAR(MAX)
        );

        INSERT INTO @t
        SELECT TOP 1500 Id, Text
        FROM dbo.Comments
        ORDER BY NEWID();

        SELECT 
            Id,
            HASHBYTES('SHA2_256',
                REPLACE(
                    REPLACE(
                        REPLACE(Txt, 'a', 'aa'),
                    'e', 'ee'),
                'i', 'ii')
            )
        FROM @t
        ORDER BY NEWID();
    END

    --------------------------------------------------------------------
    -- 3. Cursor Loop + String Aggregation
    --------------------------------------------------------------------
    IF @q = 3
    BEGIN
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

    --------------------------------------------------------------------
    -- 4. CTE → Temp Table → Hashing
    --------------------------------------------------------------------
    IF @q = 4
    BEGIN
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

    --------------------------------------------------------------------
    -- 5. Recursive CTE String Expansion
    --------------------------------------------------------------------
    IF @q = 5
    BEGIN
        DECLARE @s NVARCHAR(MAX) =
            (SELECT TOP 1 Text FROM dbo.Comments ORDER BY NEWID());

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

    --------------------------------------------------------------------
    -- 6. Cursor + Temp Table + Hashing
    --------------------------------------------------------------------
    IF @q = 6
    BEGIN
        CREATE TABLE #st (Txt NVARCHAR(MAX));

        DECLARE @txt2 NVARCHAR(MAX);

        DECLARE cur2 CURSOR LOCAL FAST_FORWARD FOR
            SELECT TOP 1000 Text
            FROM dbo.Comments
            ORDER BY NEWID();

        OPEN cur2;
        FETCH NEXT FROM cur2 INTO @txt2;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            INSERT INTO #st VALUES (@txt2);
            FETCH NEXT FROM cur2 INTO @txt2;
        END

        CLOSE cur2;
        DEALLOCATE cur2;

        SELECT TOP 1000 HASHBYTES('SHA2_256', Txt)
        FROM #st
        ORDER BY NEWID();
    END
END
GO
