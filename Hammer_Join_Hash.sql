SELECT TOP 500
    p.Id,
    p.Title,
    u.DisplayName,
    t.TagName
FROM dbo.Posts p
INNER JOIN dbo.Users u WITH (HASH JOIN)
    ON u.Id = p.OwnerUserId
INNER JOIN dbo.PostTags pt WITH (HASH JOIN)
    ON pt.PostId = p.Id
INNER JOIN dbo.Tags t WITH (HASH JOIN)
    ON t.Id = pt.TagId
WHERE p.Score > 5
ORDER BY p.CreationDate DESC;
