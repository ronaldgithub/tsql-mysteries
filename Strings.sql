select @@version

/*=============================================================================
  Strings.sql

  Purpose : Running catalog of T-SQL string functions, tested one at a time
            against the StackOverflow2010 sample database.

            Each query appends `WHERE 1 = (SELECT 1)` -- a correlated scalar
            subquery predicate that filters nothing but adds a per-row CPU
            cost estimate, nudging the optimizer's estimated plan cost above
            the parallelism threshold so a parallel plan is more likely.

            Run each batch individually in SSMS with "Include Actual
            Execution Plan" enabled (Ctrl+M) to capture its plan.

  Assumes : Connection is already pointed at the StackOverflow2010 database.
=============================================================================*/

--------------------------------------------------------------------
-- ASCII ( character_expression )
-- Returns the ASCII code (int) of the leftmost character of a
-- char/varchar expression.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/ascii-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, ASCII(p.Title) AS TitleFirstCharAscii
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- CHAR ( integer_expression )
-- Converts an int code (0-255) to the matching character. Inverse
-- of ASCII.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/char-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, CHAR(ASCII(p.Title)) AS TitleFirstChar
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- CHARINDEX ( expressionToFind, expressionToSearch [ , start_location ] )
-- Returns the starting position (int) of the first occurrence of
-- one string within another.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/charindex-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, CHARINDEX(N'SQL', p.Title) AS SqlPosition
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- COMPRESS ( expression )
-- Gzip-compresses the input, returning varbinary(max).
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/compress-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, COMPRESS(p.Title) AS TitleCompressed
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- CONCAT ( string1, string2 [ , stringN ] )
-- Concatenates two or more strings; NULLs are treated as empty
-- strings.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/concat-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, CONCAT(u.DisplayName, N' (', u.Reputation, N' rep)') AS DisplayNameWithReputation
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- CONCAT_WS ( separator, argument1, argument2 [ , argumentN ] )
-- Concatenates two or more strings with a separator, skipping NULLs.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/concat-ws-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, CONCAT_WS(N' | ', u.DisplayName, u.Reputation, u.LastAccessDate) AS UserSummary
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- DECOMPRESS ( expression )
-- Decompresses Gzip-compressed data back to varbinary(max); cast
-- to a string type to read it.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/decompress-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title,
       CAST(DECOMPRESS(COMPRESS(p.Title)) AS NVARCHAR(MAX)) AS TitleRoundTrip
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- DIFFERENCE ( character_expression, character_expression )
-- Returns 0-4 measuring how closely two strings' SOUNDEX values
-- match.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/difference-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, u.DisplayName, DIFFERENCE(u.DisplayName, N'John') AS SoundsLikeJohn
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- FORMAT ( value, format [ , culture ] )
-- Formats a number or date as a string using a .NET format string.
-- Nondeterministic (the only nondeterministic string function).
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/format-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, u.Reputation, FORMAT(u.Reputation, N'N0', N'en-US') AS ReputationFormatted
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- FORMATMESSAGE ( { msg_number | 'msg_string' | @msg_variable } , [ param_value [ , ...n ] ] )
-- Substitutes parameter values into a message template (printf-style).
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/formatmessage-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, FORMATMESSAGE('User %s has %d reputation points.', u.DisplayName, u.Reputation) AS Message
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- LEFT ( character_expression, integer_expression )
-- Returns the leftmost N characters of a string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/left-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, LEFT(p.Title, 20) AS TitleLeft20
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- LEN ( string_expression )
-- Returns the number of characters (int), excluding trailing spaces.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/len-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, LEN(p.Title) AS TitleLength
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- LOWER ( character_expression )
-- Converts a string to lowercase.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/lower-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, LOWER(p.Title) AS TitleLower
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- LTRIM ( character_expression )
-- Removes leading spaces from a string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/ltrim-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, LTRIM(p.Title) AS TitleLTrim
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- NCHAR ( integer_expression [ , collation ] )
-- Converts a Unicode code point to its nchar(1) character. Inverse
-- of UNICODE; handles code points ASCII cannot (>127).
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/nchar-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, NCHAR(UNICODE(p.Title)) AS TitleFirstCharUnicode
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- PATINDEX ( '%pattern%' , expression )
-- Returns the starting position of a pattern (wildcards allowed)
-- within a string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/patindex-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, PATINDEX(N'%SQL%', p.Title) AS SqlPatternPosition
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- QUOTENAME ( 'character_string' [ , 'quote_character' ] )
-- Wraps a string as a delimited (bracketed by default) identifier.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/quotename-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, u.DisplayName, QUOTENAME(u.DisplayName) AS DisplayNameQuoted
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- REPLACE ( string_expression, string_pattern, string_replacement )
-- Replaces all occurrences of a substring with another substring.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/replace-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, REPLACE(p.Title, N'SQL', N'T-SQL') AS TitleReplaced
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- REPLICATE ( string_expression, integer_expression )
-- Repeats a string a specified number of times.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/replicate-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, REPLICATE(LEFT(p.Title, 1), 3) AS FirstCharReplicated
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- REVERSE ( string_expression )
-- Reverses the order of characters in a string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/reverse-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, REVERSE(p.Title) AS TitleReversed
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- RIGHT ( character_expression, integer_expression )
-- Returns the rightmost N characters of a string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/right-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, RIGHT(p.Title, 20) AS TitleRight20
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- RTRIM ( character_expression )
-- Removes trailing spaces from a string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/rtrim-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, RTRIM(p.Title) AS TitleRTrim
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- SOUNDEX ( character_expression )
-- Returns a 4-character phonetic code for how a string sounds.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/soundex-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, u.DisplayName, SOUNDEX(u.DisplayName) AS DisplayNameSoundex
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- SPACE ( integer_expression )
-- Returns a string of repeated spaces.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/space-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, SPACE(3) + p.Title AS TitleIndented
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- STR ( float_expression [ , length [ , decimal ] ] )
-- Converts a numeric expression to a formatted string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/str-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT u.Id, u.Reputation, STR(u.Reputation, 10, 0) AS ReputationAsString
FROM dbo.Users AS u
WHERE 1 = (SELECT 1)
ORDER BY u.Id;
GO

--------------------------------------------------------------------
-- STRING_AGG ( expression, separator ) [ WITHIN GROUP ( ORDER BY ... ) ]
-- Concatenates values from multiple rows into one delimited string
-- per group. Default output is capped at 8000 bytes/4000 chars and
-- errors (rather than truncates) if exceeded on posts with many
-- comments -- CAST to NVARCHAR(MAX) so the result is LOB-typed.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/string-agg-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT c.PostId, STRING_AGG(CAST(c.Text AS NVARCHAR(MAX)), N' | ') AS AllCommentsForPost
FROM dbo.Comments AS c
WHERE 1 = (SELECT 1)
GROUP BY c.PostId;
GO

--------------------------------------------------------------------
-- STRING_ESCAPE ( text, type )
-- Escapes special characters for a target format (currently only
-- 'json' is supported).
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/string-escape-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, STRING_ESCAPE(p.Title, 'json') AS TitleJsonEscaped
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- STRING_SPLIT ( string, separator [ , enable_ordinal ] )
-- Table-valued function: splits a delimited string into rows.
-- Posts.Tags is stored as e.g. '<sql><tsql>', so the '<' markers
-- are stripped before splitting on '>'.
-- enable_ordinal (the 3-arg form) needs SQL Server 2022+ / Azure SQL
-- Database proper -- omitted here for compatibility with older
-- engines/compat levels (output order is then not guaranteed).
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/string-split-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, s.value AS Tag
FROM dbo.Posts AS p
    CROSS APPLY STRING_SPLIT(REPLACE(p.Tags, '<', ''), '>') AS s
WHERE 1 = (SELECT 1)
  AND s.value <> ''
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- STUFF ( character_expression, start, length, replaceWith_expression )
-- Deletes a length of characters at a position and inserts another
-- string there.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/stuff-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, STUFF(p.Title, 1, 5, N'START') AS TitleStuffed
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- SUBSTRING ( expression, start, length )
-- Extracts part of a string.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/substring-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, SUBSTRING(p.Title, 1, 10) AS TitleFirst10
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- TRANSLATE ( inputString, characters, translations )
-- Replaces each character in `characters` with the character at
-- the same position in `translations`, in one pass (unlike nested
-- REPLACE calls).
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/translate-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, TRANSLATE(p.Title, N'<>[]{}', N'()()()') AS TitleBracketsNormalized
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- TRIM ( [ LEADING | TRAILING | BOTH ] [ characters FROM ] string )
-- Removes leading/trailing spaces (or specified characters) from a
-- string. Basic form used here for broad version compatibility.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/trim-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, TRIM(p.Title) AS TitleTrimmed
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- UNICODE ( ncharacter_expression )
-- Returns the Unicode code point (int) of the leftmost character;
-- unlike ASCII, correctly handles characters beyond 7-bit ASCII.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/unicode-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, UNICODE(p.Title) AS TitleFirstCharUnicodeValue
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

--------------------------------------------------------------------
-- UPPER ( character_expression )
-- Converts a string to uppercase.
-- https://learn.microsoft.com/en-us/sql/t-sql/functions/upper-transact-sql?view=sql-server-ver17
--------------------------------------------------------------------
SELECT p.Id, p.Title, UPPER(p.Title) AS TitleUpper
FROM dbo.Posts AS p
WHERE 1 = (SELECT 1)
ORDER BY p.Id;
GO

-- End of catalog: every function listed under Microsoft's "String Functions (Transact-SQL)"
-- category is now covered above (ASCII, CHAR, CHARINDEX, COMPRESS, CONCAT, CONCAT_WS,
-- DECOMPRESS, DIFFERENCE, FORMAT, FORMATMESSAGE, LEFT, LEN, LOWER, LTRIM, NCHAR, PATINDEX,
-- QUOTENAME, REPLACE, REPLICATE, REVERSE, RIGHT, RTRIM, SOUNDEX, SPACE, STR, STRING_AGG,
-- STRING_ESCAPE, STRING_SPLIT, STUFF, SUBSTRING, TRANSLATE, TRIM, UNICODE, UPPER).

