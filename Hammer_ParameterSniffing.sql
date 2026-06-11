CREATE OR ALTER PROCEDURE dbo.Hammer_ParameterSniffing
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @q INT = ABS(CHECKSUM(NEWID())) % 8 + 1;

    --------------------------------------------------------------------
    -- 0. Setup tables if not exist (lightweight, idempotent)
    --------------------------------------------------------------------
    IF OBJECT_ID('dbo.Sniff') IS NULL
    BEGIN
        CREATE TABLE dbo.Sniff
        (
            ID int IDENTITY(1,1),
            Category int,
            Payload char(200) NOT NULL DEFAULT 'x'
        );

        INSERT INTO dbo.Sniff (Category)
        SELECT CASE WHEN n < 100 THEN 1 ELSE 2 END
        FROM (SELECT TOP (100000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n
              FROM sys.objects a CROSS JOIN sys.objects b) x;
    END

    IF OBJECT_ID('dbo.SniffMem') IS NULL
    BEGIN
        CREATE TABLE dbo.SniffMem
        (
            ID int IDENTITY(1,1),
            Category int,
            Payload varchar(4000)
        );

        INSERT INTO dbo.SniffMem (Category, Payload)
        SELECT CASE WHEN n < 100 THEN 1 ELSE 2 END,
               REPLICATE('x', 4000)
        FROM (SELECT TOP (50000) ROW_NUMBER() OVER (ORDER BY (SELECT NULL)) n
              FROM sys.objects a CROSS JOIN sys.objects b) x;
    END

    --------------------------------------------------------------------
    -- 1. Classic Parameter Sniffing (small vs large)
    --------------------------------------------------------------------
    IF @q = 1
    BEGIN
        DECLARE @Cat0 int = CASE WHEN RAND() < 0.5 THEN 1 ELSE 2 END;

        SELECT *
        FROM dbo.Sniff
        WHERE Category = @Cat0;
    END

    --------------------------------------------------------------------
    -- 2. Memory Grant Sniffing (ORDER BY on large vs small)
    --------------------------------------------------------------------
    IF @q = 2
    BEGIN
        DECLARE @Cat2 int = CASE WHEN RAND() < 0.5 THEN 1 ELSE 2 END;

        SELECT *
        FROM dbo.SniffMem
        WHERE Category = @Cat2
        ORDER BY Payload;
    END

    --------------------------------------------------------------------
    -- 3. Optional Parameter Sniffing (worst-case)
    --------------------------------------------------------------------
    IF @q = 3
    BEGIN
        DECLARE @OwnerUserId int = CASE WHEN RAND() < 0.5 THEN 1 ELSE NULL END;
        DECLARE @Score int = CASE WHEN RAND() < 0.5 THEN 0 ELSE NULL END;

        SELECT *
        FROM dbo.Posts
        WHERE (@OwnerUserId IS NULL OR OwnerUserId = @OwnerUserId)
          AND (@Score IS NULL OR Score = @Score);
    END

    --------------------------------------------------------------------
    -- 4. Local Variable Anti-Sniffing (generic estimates)
    --------------------------------------------------------------------
    IF @q = 4
    BEGIN
        DECLARE @Cat4 int = CASE WHEN RAND() < 0.5 THEN 1 ELSE 2 END;
        DECLARE @Local int = @Cat4;  -- breaks sniffing

        SELECT *
        FROM dbo.Sniff
        WHERE Category = @Local;
    END

    --------------------------------------------------------------------
    -- 5. RECOMPILE Fix (fresh plan each time)
    --------------------------------------------------------------------
    IF @q = 5
    BEGIN
        DECLARE @Cat5 int = CASE WHEN RAND() < 0.5 THEN 1 ELSE 2 END;

        SELECT *
        FROM dbo.Sniff
        WHERE Category = @Cat5
        OPTION (RECOMPILE);
    END

    --------------------------------------------------------------------
    -- 6. OPTIMIZE FOR UNKNOWN Fix (generic plan)
    --------------------------------------------------------------------
    IF @q = 6
    BEGIN
        DECLARE @Cat6 int = CASE WHEN RAND() < 0.5 THEN 1 ELSE 2 END;

        SELECT *
        FROM dbo.Sniff
        WHERE Category = @Cat6
        OPTION (OPTIMIZE FOR UNKNOWN);
    END

    --------------------------------------------------------------------
    -- 7. Forced Plan / CE Hint Fix
    --------------------------------------------------------------------
    IF @q = 7
    BEGIN
        DECLARE @Cat7 int = CASE WHEN RAND() < 0.5 THEN 1 ELSE 2 END;

        SELECT *
        FROM dbo.Sniff
        WHERE Category = @Cat7
        OPTION (USE HINT('FORCE_LEGACY_CARDINALITY_ESTIMATION'));
    END

    --------------------------------------------------------------------
    -- 8. Parameter Sniffing with Join (realistic OLTP pattern)
    --------------------------------------------------------------------
    IF @q = 8
    BEGIN
        DECLARE @Score8 int = CASE WHEN RAND() < 0.5 THEN 0 ELSE 100 END;

        SELECT TOP 500
            p.Id,
            p.Title,
            p.Score,
            u.DisplayName
        FROM dbo.Posts p
        JOIN dbo.Users u ON u.Id = p.OwnerUserId
        WHERE p.Score = @Score8;
    END
END
GO
