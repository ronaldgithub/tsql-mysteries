
/* ============================================================
   Unified Database User → Login → Role Mapping 
   Author: Copilot for Ronald 
   
   Uhh.. Copilot tried.. What is the compatiblity level of SQL 2025?
   "SQL Server 2025 does not exists" yeah right..

   Purpose: Full audit mapping across all databases
   ============================================================ */

-- a) Database User > Login > Role Mapping

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#Result') IS NOT NULL DROP TABLE #Result;

CREATE TABLE #Result (
    DatabaseName sysname NULL,
    DatabaseUser sysname NULL,
    UserType varchar(50) NULL,
    AuthType varchar(50) NULL,
    DatabaseSID varbinary(85) NULL,
    ServerLogin sysname NULL,
    LoginType varchar(50) NULL,
    LoginSID varbinary(85) NULL,
    MappingStatus varchar(20) NULL,
    DatabaseRole sysname NULL,
    RoleType varchar(50) NULL,
    WindowsGroupMember sysname NULL,
    WindowsGroupMemberType varchar(50) NULL
);

DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state = 0;   -- online only

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    ;WITH Users AS (
        SELECT
            DB_NAME() AS DatabaseName,
            dp.name AS DatabaseUser,
            dp.type_desc AS UserType,
            dp.authentication_type_desc AS AuthType,
            dp.sid AS DatabaseSID,
            sp.name AS ServerLogin,
            sp.type_desc AS LoginType,
            sp.sid AS LoginSID,
            CASE 
                WHEN sp.sid IS NULL THEN ''Orphaned''
                WHEN dp.sid = sp.sid THEN ''Mapped''
                ELSE ''SID Mismatch''
            END AS MappingStatus,
            dp.principal_id
        FROM sys.database_principals dp
        LEFT JOIN sys.server_principals sp
            ON dp.sid = sp.sid
        WHERE dp.type IN (''S'',''U'',''G'')
          AND dp.principal_id > 4
    ),
    Roles AS (
        SELECT 
            rm.member_principal_id,
            rp.name AS DatabaseRole,
            rp.type_desc AS RoleType
        FROM sys.database_role_members rm
        JOIN sys.database_principals rp
            ON rm.role_principal_id = rp.principal_id
    )
    INSERT INTO #Result
    SELECT
        u.DatabaseName,
        u.DatabaseUser,
        u.UserType,
        u.AuthType,
        u.DatabaseSID,
        u.ServerLogin,
        u.LoginType,
        u.LoginSID,
        u.MappingStatus,
        r.DatabaseRole,
        r.RoleType,
        NULL AS WindowsGroupMember,
        NULL AS WindowsGroupMemberType
    FROM Users u
    LEFT JOIN Roles r
        ON u.principal_id = r.member_principal_id;
    ';
	print @sql
    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;

---------------------------------------------------------------
-- OPTIONAL: Expand Windows group membership
-- Uncomment this block if you want AD group expansion
---------------------------------------------------------------
/*
DECLARE @group sysname;

DECLARE grp CURSOR FOR
SELECT DISTINCT ServerLogin
FROM #Result
WHERE LoginType = 'WINDOWS_GROUP';

OPEN grp;
FETCH NEXT FROM grp INTO @group;

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #Result (DatabaseName, DatabaseUser, UserType, AuthType,
                         DatabaseSID, ServerLogin, LoginType, LoginSID,
                         MappingStatus, DatabaseRole, RoleType,
                         WindowsGroupMember, WindowsGroupMemberType)
    EXEC xp_logininfo @group, 'members';

    FETCH NEXT FROM grp INTO @group;
END

CLOSE grp;
DEALLOCATE grp;
*/

---------------------------------------------------------------
-- Final unified output
---------------------------------------------------------------
SELECT *
FROM #Result
ORDER BY DatabaseName, DatabaseUser, DatabaseRole, WindowsGroupMember;



-- b) Login Pivot per database 

IF OBJECT_ID('tempdb..#Flat') IS NOT NULL DROP TABLE #Flat;

CREATE TABLE #Flat (
    DatabaseName sysname,
    DatabaseUser sysname,
    MappingStatus varchar(20)
);

DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE ' + QUOTENAME(@db) + N';

    INSERT INTO #Flat (DatabaseName, DatabaseUser, MappingStatus)
    SELECT
        DB_NAME(),
        dp.name,
        CASE 
            WHEN sp.sid IS NULL THEN ''Orphaned''
            WHEN dp.sid = sp.sid THEN ''Mapped''
            ELSE ''SID Mismatch''
        END
    FROM sys.database_principals dp
    LEFT JOIN sys.server_principals sp
        ON dp.sid = sp.sid
    WHERE dp.type IN (''S'',''U'',''G'')
      AND dp.principal_id > 4;
    ';

    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;

DECLARE @cols nvarchar(max) = N'';

SELECT @cols = @cols + QUOTENAME(DatabaseName) + ','
FROM (SELECT DISTINCT DatabaseName FROM #Flat) AS d
ORDER BY DatabaseName;

-- Remove trailing comma
SET @cols = LEFT(@cols, LEN(@cols) - 1);

-- Build dynamic pivot SQL
SET @sql = N'
SELECT DatabaseUser, ' + @cols + N'
into dbo.Ultimo
FROM (
    SELECT DatabaseUser, DatabaseName, MappingStatus
    FROM #Flat
) AS src
PIVOT (
    MAX(MappingStatus)
    FOR DatabaseName IN (' + @cols + N')
) AS p
ORDER BY DatabaseUser;
';

EXEC sys.sp_executesql @sql;






DECLARE @cols nvarchar(max) = N'';

SELECT @cols = @cols + QUOTENAME(DatabaseName) + ','
FROM (SELECT DISTINCT DatabaseName FROM #Flat) AS d
ORDER BY DatabaseName;

-- Remove trailing comma
SET @cols = LEFT(@cols, LEN(@cols) - 1);




IF OBJECT_ID('tempdb..#Flat') IS NOT NULL DROP TABLE #Flat;

CREATE TABLE #Flat (
    DatabaseName sysname,
    DatabaseUser sysname,
    MappingStatus varchar(20)
);

DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state = 0;

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE [' + QUOTENAME(@db) + N'];

    INSERT INTO #Flat (DatabaseName, DatabaseUser, MappingStatus)
    SELECT
        DB_NAME(),
        dp.name,
        CASE 
            WHEN sp.sid IS NULL THEN ''Orphaned''
            WHEN dp.sid = sp.sid THEN ''Mapped''
            ELSE ''SID Mismatch''
        END
    FROM sys.database_principals dp
    LEFT JOIN sys.server_principals sp
        ON dp.sid = sp.sid
    WHERE dp.type IN (''S'',''U'',''G'')
      AND dp.principal_id > 4;
    ';

    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;

DECLARE @cols nvarchar(max), @sql nvarchar(max);

-- Build dynamic column list
SELECT @cols = STRING_AGG(QUOTENAME(DatabaseName), ',')
FROM (SELECT DISTINCT DatabaseName FROM #Flat) AS d;

-- Build dynamic pivot SQL
SET @sql = N'
SELECT DatabaseUser, ' + @cols + N'
FROM (
    SELECT DatabaseUser, DatabaseName, MappingStatus
    FROM #Flat
) AS src
PIVOT (
    MAX(MappingStatus)
    FOR DatabaseName IN (' + @cols + N')
) AS p
ORDER BY DatabaseUser;
';

EXEC sys.sp_executesql @sql;









/* ============================================================
   Unified Database User → Login → Role Mapping
   Author: Copilot for Ronald
   Purpose: Full audit mapping across all databases
   ============================================================ */

SET NOCOUNT ON;

IF OBJECT_ID('tempdb..#Result') IS NOT NULL DROP TABLE #Result;

CREATE TABLE #Result (
    DatabaseName sysname,
    DatabaseUser sysname,
    UserType varchar(50),
    AuthType varchar(50),
    DatabaseSID varbinary(85),
    ServerLogin sysname,
    LoginType varchar(50),
    LoginSID varbinary(85),
    MappingStatus varchar(20),
    DatabaseRole sysname,
    RoleType varchar(50),
    WindowsGroupMember sysname NULL,
    WindowsGroupMemberType varchar(50) NULL
);

DECLARE @db sysname, @sql nvarchar(max);

DECLARE dbs CURSOR FOR
SELECT name
FROM sys.databases
WHERE database_id > 4
  AND state = 0;   -- online only

OPEN dbs;
FETCH NEXT FROM dbs INTO @db;

WHILE @@FETCH_STATUS = 0
BEGIN
    SET @sql = N'
    USE [' + QUOTENAME(@db) + N'];

    ;WITH Users AS (
        SELECT
            DB_NAME() AS DatabaseName,
            dp.name AS DatabaseUser,
            dp.type_desc AS UserType,
            dp.authentication_type_desc AS AuthType,
            dp.sid AS DatabaseSID,
            sp.name AS ServerLogin,
            sp.type_desc AS LoginType,
            sp.sid AS LoginSID,
            CASE 
                WHEN sp.sid IS NULL THEN ''Orphaned''
                WHEN dp.sid = sp.sid THEN ''Mapped''
                ELSE ''SID Mismatch''
            END AS MappingStatus,
            dp.principal_id
        FROM sys.database_principals dp
        LEFT JOIN sys.server_principals sp
            ON dp.sid = sp.sid
        WHERE dp.type IN (''S'',''U'',''G'')
          AND dp.principal_id > 4
    ),
    Roles AS (
        SELECT 
            rm.member_principal_id,
            rp.name AS DatabaseRole,
            rp.type_desc AS RoleType
        FROM sys.database_role_members rm
        JOIN sys.database_principals rp
            ON rm.role_principal_id = rp.principal_id
    )
    INSERT INTO #Result
    SELECT
        u.DatabaseName,
        u.DatabaseUser,
        u.UserType,
        u.AuthType,
        u.DatabaseSID,
        u.ServerLogin,
        u.LoginType,
        u.LoginSID,
        u.MappingStatus,
        r.DatabaseRole,
        r.RoleType,
        NULL AS WindowsGroupMember,
        NULL AS WindowsGroupMemberType
    FROM Users u
    LEFT JOIN Roles r
        ON u.principal_id = r.member_principal_id;
    ';

    EXEC sys.sp_executesql @sql;

    FETCH NEXT FROM dbs INTO @db;
END

CLOSE dbs;
DEALLOCATE dbs;

---------------------------------------------------------------
-- OPTIONAL: Expand Windows group membership
-- Uncomment this block if you want AD group expansion
---------------------------------------------------------------
/*
DECLARE @group sysname;

DECLARE grp CURSOR FOR
SELECT DISTINCT ServerLogin
FROM #Result
WHERE LoginType = 'WINDOWS_GROUP';

OPEN grp;
FETCH NEXT FROM grp INTO @group;

WHILE @@FETCH_STATUS = 0
BEGIN
    INSERT INTO #Result (DatabaseName, DatabaseUser, UserType, AuthType,
                         DatabaseSID, ServerLogin, LoginType, LoginSID,
                         MappingStatus, DatabaseRole, RoleType,
                         WindowsGroupMember, WindowsGroupMemberType)
    EXEC xp_logininfo @group, 'members';

    FETCH NEXT FROM grp INTO @group;
END

CLOSE grp;
DEALLOCATE grp;
*/

---------------------------------------------------------------
-- Final unified output
---------------------------------------------------------------
SELECT *
FROM #Result
ORDER BY DatabaseName, DatabaseUser, DatabaseRole, WindowsGroupMember;
