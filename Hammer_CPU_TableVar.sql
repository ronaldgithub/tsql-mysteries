CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_TableVar
AS
BEGIN
    SET NOCOUNT ON;

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
GO
