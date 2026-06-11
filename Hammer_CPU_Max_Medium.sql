CREATE OR ALTER PROCEDURE dbo.Hammer_CPU_Max_Medium
AS
BEGIN
    SET NOCOUNT ON;

    -- Medium CPU: nested REPLACE() and hashing
    SELECT TOP 1000
        HASHBYTES('SHA2_256',
            REPLACE(
                REPLACE(
                    REPLACE(Text, 'a', 'aa'),
                'e', 'ee'),
            'i', 'ii')
        )
    FROM dbo.Comments
    ORDER BY NEWID();
END
GO
