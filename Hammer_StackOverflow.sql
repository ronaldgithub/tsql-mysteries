CREATE OR ALTER PROCEDURE dbo.Hammer_StackOverflow50
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @q INT = ABS(CHECKSUM(NEWID())) % 50 + 1;

    ------------------------------------------------------------
    -- 1–8: Point Lookups
    ------------------------------------------------------------
    IF @q = 1  SELECT * FROM dbo.Users WHERE Id = ABS(CHECKSUM(NEWID())) % 2000000;
    IF @q = 2  SELECT * FROM dbo.Posts WHERE Id = ABS(CHECKSUM(NEWID())) % 20000000;
    IF @q = 3  SELECT * FROM dbo.Comments WHERE Id = ABS(CHECKSUM(NEWID())) % 60000000;
    IF @q = 4  SELECT * FROM dbo.Votes WHERE Id = ABS(CHECKSUM(NEWID())) % 150000000;
    IF @q = 5  SELECT DisplayName, Reputation FROM dbo.Users WHERE Id = 1;
    IF @q = 6  SELECT Title, Score FROM dbo.Posts WHERE Id = 100;
    IF @q = 7  SELECT Text FROM dbo.Comments WHERE PostId = 500;
    IF @q = 8  SELECT * FROM dbo.Badges WHERE UserId = 1000;

    ------------------------------------------------------------
    -- 9–16: Filtered Reads
    ------------------------------------------------------------
    IF @q = 9  SELECT TOP 50 * FROM dbo.Posts WHERE Score > 10 ORDER BY CreationDate DESC;
    IF @q = 10 SELECT TOP 100 * FROM dbo.Comments WHERE Score < 0 ORDER BY CreationDate DESC;
    IF @q = 11 SELECT TOP 20 * FROM dbo.Users WHERE Reputation BETWEEN 1000 AND 2000;
    IF @q = 12 SELECT TOP 100 * FROM dbo.Posts WHERE ViewCount > 10000;
    IF @q = 13 SELECT TOP 50 * FROM dbo.Posts WHERE Tags LIKE '%sql%';
    IF @q = 14 SELECT TOP 100 * FROM dbo.Comments WHERE Text LIKE '%help%';
    IF @q = 15 SELECT TOP 100 * FROM dbo.Posts WHERE OwnerUserId = 22656 ORDER BY CreationDate DESC;
    IF @q = 16 SELECT TOP 100 * FROM dbo.Votes WHERE VoteTypeId = 2;

    ------------------------------------------------------------
    -- 17–24: Aggregations
    ------------------------------------------------------------
    IF @q = 17 SELECT COUNT(*) FROM dbo.Posts;
    IF @q = 18 SELECT COUNT(*) FROM dbo.Comments WHERE Score > 0;
    IF @q = 19 SELECT OwnerUserId, COUNT(*) FROM dbo.Posts GROUP BY OwnerUserId ORDER BY COUNT(*) DESC;
    IF @q = 20 SELECT PostId, COUNT(*) FROM dbo.Comments GROUP BY PostId ORDER BY COUNT(*) DESC;
    IF @q = 21 SELECT TagName, COUNT(*) FROM dbo.Tags GROUP BY TagName ORDER BY COUNT(*) DESC;
    IF @q = 22 SELECT DATEPART(YEAR, CreationDate), COUNT(*) FROM dbo.Posts GROUP BY DATEPART(YEAR, CreationDate);
    IF @q = 23 SELECT UserId, COUNT(*) FROM dbo.Badges GROUP BY UserId HAVING COUNT(*) > 10;
    IF @q = 24 SELECT VoteTypeId, COUNT(*) FROM dbo.Votes GROUP BY VoteTypeId;

    ------------------------------------------------------------
    -- 25–32: Joins
    ------------------------------------------------------------
    IF @q = 25 SELECT p.Id, p.Title, u.DisplayName
               FROM dbo.Posts p
               JOIN dbo.Users u ON u.Id = p.OwnerUserId
               WHERE p.Score > 5;

    IF @q = 26 SELECT c.Id, c.Text, u.DisplayName
               FROM dbo.Comments c
               JOIN dbo.Users u ON u.Id = c.UserId
               WHERE c.Score > 0;

    IF @q = 27 SELECT p.Id, p.Title, COUNT(c.Id) AS CommentCount
               FROM dbo.Posts p
               LEFT JOIN dbo.Comments c ON c.PostId = p.Id
               GROUP BY p.Id, p.Title;

    IF @q = 28 SELECT TOP 100 p.Id, p.Title, v.VoteTypeId
               FROM dbo.Posts p
               JOIN dbo.Votes v ON v.PostId = p.Id
               ORDER BY p.CreationDate DESC;

    IF @q = 29 SELECT TOP 50 u.Id, u.DisplayName, b.Name
               FROM dbo.Users u
               JOIN dbo.Badges b ON b.UserId = u.Id
               ORDER BY b.Date DESC;

    IF @q = 30 SELECT TOP 100 p.Id, p.Title, t.TagName
               FROM dbo.Posts p
               JOIN dbo.PostTags pt ON pt.PostId = p.Id
               JOIN dbo.Tags t ON t.Id = pt.TagId;

    IF @q = 31 SELECT TOP 100 c.Id, c.Text, p.Title
               FROM dbo.Comments c
               JOIN dbo.Posts p ON p.Id = c.PostId
               WHERE p.Score > 10;

    IF @q = 32 SELECT TOP 100 u.Id, u.DisplayName, p.Title
               FROM dbo.Users u
               JOIN dbo.Posts p ON p.OwnerUserId = u.Id
               WHERE u.Reputation > 1000;

    ------------------------------------------------------------
    -- 33–38: Inserts
    ------------------------------------------------------------
    IF @q = 33 INSERT INTO dbo.Comments (PostId, Score, Text, CreationDate, UserId)
               VALUES (ABS(CHECKSUM(NEWID())) % 20000000, 0, 'Test comment', GETDATE(), 1);

    IF @q = 34 INSERT INTO dbo.Votes (PostId, VoteTypeId, CreationDate, UserId)
               VALUES (ABS(CHECKSUM(NEWID())) % 20000000, 2, GETDATE(), 1);

    IF @q = 35 INSERT INTO dbo.Posts (PostTypeId, OwnerUserId, CreationDate, Score, ViewCount, Title, Body)
               VALUES (1, 1, GETDATE(), 0, 0, 'Test title', 'Test body');

    IF @q = 36 INSERT INTO dbo.Users (DisplayName, Reputation, CreationDate)
               VALUES ('TestUser', 1, GETDATE());

    IF @q = 37 INSERT INTO dbo.Badges (UserId, Name, Date)
               VALUES (1, 'TestBadge', GETDATE());

    IF @q = 38 INSERT INTO dbo.PostLinks (PostId, RelatedPostId, LinkTypeId, CreationDate)
               VALUES (ABS(CHECKSUM(NEWID())) % 20000000,
                       ABS(CHECKSUM(NEWID())) % 20000000,
                       1, GETDATE());

    ------------------------------------------------------------
    -- 39–44: Updates
    ------------------------------------------------------------
    IF @q = 39 UPDATE dbo.Users
               SET Reputation = Reputation + 1
               WHERE Id = ABS(CHECKSUM(NEWID())) % 2000000;

    IF @q = 40 UPDATE dbo.Posts
               SET Score = Score + 1
               WHERE Id = ABS(CHECKSUM(NEWID())) % 20000000;

    IF @q = 41 UPDATE dbo.Comments
               SET Score = Score - 1
               WHERE Id = ABS(CHECKSUM(NEWID())) % 60000000;

    IF @q = 42 UPDATE dbo.Posts
               SET ViewCount = ViewCount + 10
               WHERE Id = ABS(CHECKSUM(NEWID())) % 20000000;

    IF @q = 43 UPDATE dbo.Users
               SET LastAccessDate = GETDATE()
               WHERE Id = ABS(CHECKSUM(NEWID())) % 2000000;

    IF @q = 44 UPDATE dbo.Posts
               SET Title = Title
               WHERE Id = ABS(CHECKSUM(NEWID())) % 20000000;

    ------------------------------------------------------------
    -- 45–50: Deletes & Random Stress
    ------------------------------------------------------------
    IF @q = 45 DELETE TOP (1) FROM dbo.Comments WHERE Id = ABS(CHECKSUM(NEWID())) % 60000000;
    IF @q = 46 DELETE TOP (1) FROM dbo.Votes WHERE Id = ABS(CHECKSUM(NEWID())) % 150000000;
    IF @q = 47 DELETE TOP (1) FROM dbo.Badges WHERE UserId = ABS(CHECKSUM(NEWID())) % 2000000;
    IF @q = 48 DELETE TOP (1) FROM dbo.PostLinks WHERE PostId = ABS(CHECKSUM(NEWID())) % 20000000;
    IF @q = 49 SELECT TOP 100 * FROM dbo.Posts ORDER BY NEWID();
    IF @q = 50 SELECT TOP 100 * FROM dbo.Comments ORDER BY NEWID();
END
GO
