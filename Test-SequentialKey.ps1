#Requires -Version 7.0
<#
.SYNOPSIS
    Measures the effect of OPTIMIZE_FOR_SEQUENTIAL_KEY on concurrent INSERT throughput.

.DESCRIPTION
    Creates two identical tables that differ only in the OPTIMIZE_FOR_SEQUENTIAL_KEY
    setting on their clustered PRIMARY KEY (BIGINT IDENTITY, narrow rows, so the last
    page is as hot as possible). Drives N concurrent sqlcmd sessions against each and
    compares elapsed time plus the page-latch and flow-control waits that accrued.

    Inserts are grouped into explicit transactions (BatchSize per commit) so that
    WRITELOG does not mask the page latch contention being measured.

    Each concurrency level runs -Rounds times, alternating which table goes first,
    to cancel out ordering and cache-warmup effects.

    Creates dbo.zz_SeqKeyTest_Off and dbo.zz_SeqKeyTest_On and drops them at the end
    unless -KeepTables is supplied. No database or instance settings are changed.

.PARAMETER ThreadCounts
    Concurrency levels to test. The effect only appears well above the scheduler count.

.PARAMETER TotalRows
    Rows inserted per run, split evenly across the sessions, so every concurrency
    level does the same amount of work.

.EXAMPLE
    .\Test-SequentialKey.ps1
    Default sweep: 1, 8 and 64 sessions, 800,000 rows per run, 2 rounds.

.EXAMPLE
    .\Test-SequentialKey.ps1 -ThreadCounts 64 -TotalRows 1600000 -Rounds 2
    Reproduces the high-concurrency test only, at the original row count.

.EXAMPLE
    .\Test-SequentialKey.ps1 -ServerInstance sql01 -Database TestDb -KeepTables
#>
[CmdletBinding()]
param(
    [string] $ServerInstance = 'win11',
    [string] $Database       = 'StackOverflow2013',
    [int[]]  $ThreadCounts   = @(1, 8, 64),
    [int]    $TotalRows      = 800000,
    [int]    $BatchSize      = 100,
    [int]    $Rounds         = 2,
    [switch] $KeepTables
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$TableOff  = 'zz_SeqKeyTest_Off'
$TableOn   = 'zz_SeqKeyTest_On'
$WaitTypes = @('PAGELATCH_EX', 'BTREE_INSERT_FLOW_CONTROL', 'WRITELOG')

# --- prerequisites -----------------------------------------------------------

# A stale PATH or a broken ODBC-tools copy (SQLCMD.rll missing) can shadow a working
# sqlcmd, so try every candidate with a real query and keep the first one that answers.
$candidates = @(
    'C:\Program Files\SqlCmd\sqlcmd.exe'
    Get-Command sqlcmd.exe -All -ErrorAction SilentlyContinue | ForEach-Object Source
) | Where-Object { $_ -and (Test-Path $_) } | Select-Object -Unique

$sqlcmdExe = $null
foreach ($c in $candidates) {
    $out = & $c -S $ServerInstance -E -d $Database -C -h -1 -Q 'SET NOCOUNT ON; SELECT 1' 2>&1
    if ($LASTEXITCODE -eq 0 -and "$out".Trim() -eq '1') { $sqlcmdExe = $c; break }
    Write-Verbose "Skipping $c : $out"
}
if (-not $sqlcmdExe) {
    throw "No working sqlcmd.exe found (tried: $($candidates -join ', ')). Install go-sqlcmd: winget install Microsoft.Sqlcmd"
}
Write-Verbose "Using $sqlcmdExe"
if (-not (Get-Module -ListAvailable -Name SqlServer)) {
    throw 'The SqlServer PowerShell module is required (Install-Module SqlServer).'
}
Import-Module SqlServer -ErrorAction Stop

function Invoke-Q {
    param([Parameter(Mandatory)][string]$Query)
    Invoke-Sqlcmd -ServerInstance $ServerInstance -Database $Database -Query $Query -TrustServerCertificate -QueryTimeout 0
}

# --- worker script -----------------------------------------------------------
# Single-quoted here-string: $(TBL) and friends are sqlcmd variables, not PowerShell.

$workerSql = @'
SET NOCOUNT ON;
DECLARE @i INT = 0, @b INT;
WHILE @i < $(NROWS)
BEGIN
    BEGIN TRAN;
    SET @b = 0;
    WHILE @b < $(BATCH) AND @i < $(NROWS)
    BEGIN
        INSERT INTO dbo.$(TBL) (Val) VALUES (@i);
        SET @b += 1;
        SET @i += 1;
    END
    COMMIT;
END
'@

$workerFile = Join-Path ([System.IO.Path]::GetTempPath()) "seqkey_worker_$PID.sql"
Set-Content -Path $workerFile -Value $workerSql -Encoding ASCII

# --- setup -------------------------------------------------------------------

function Initialize-TestTables {
    Write-Host "Creating test tables in $Database on $ServerInstance ..." -ForegroundColor Cyan
    $sql = @"
SET NOCOUNT ON;
DROP TABLE IF EXISTS dbo.$TableOff;
DROP TABLE IF EXISTS dbo.$TableOn;

CREATE TABLE dbo.$TableOff (
    Id     BIGINT IDENTITY(1,1) NOT NULL,
    Val    INT     NOT NULL,
    Filler CHAR(8) NOT NULL DEFAULT 'x',
    CONSTRAINT PK_$TableOff PRIMARY KEY CLUSTERED (Id)
        WITH (OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
);

CREATE TABLE dbo.$TableOn (
    Id     BIGINT IDENTITY(1,1) NOT NULL,
    Val    INT     NOT NULL,
    Filler CHAR(8) NOT NULL DEFAULT 'x',
    CONSTRAINT PK_$TableOn PRIMARY KEY CLUSTERED (Id)
        WITH (OPTIMIZE_FOR_SEQUENTIAL_KEY = ON)
);
"@
    Invoke-Q $sql | Out-Null

    $check = Invoke-Q @"
SELECT OBJECT_NAME(object_id) AS TableName, optimize_for_sequential_key AS Ofsk
FROM sys.indexes
WHERE object_id IN (OBJECT_ID('dbo.$TableOff'), OBJECT_ID('dbo.$TableOn')) AND index_id = 1
ORDER BY TableName;
"@
    foreach ($row in $check) {
        $state = if ($row.Ofsk) { 'ON' } else { 'OFF' }
        Write-Host ('  {0,-22} OPTIMIZE_FOR_SEQUENTIAL_KEY = {1}' -f $row.TableName, $state)
    }
}

function Remove-TestTables {
    Write-Host 'Dropping test tables ...' -ForegroundColor Cyan
    Invoke-Q "DROP TABLE IF EXISTS dbo.$TableOff; DROP TABLE IF EXISTS dbo.$TableOn;" | Out-Null
}

# --- measurement -------------------------------------------------------------

function Get-IndexStats {
    param([Parameter(Mandatory)][string]$Table)
    # MAX() without GROUP BY guarantees exactly one row even when the TVF returns none,
    # which happens right after a TRUNCATE creates a new rowset.
    Invoke-Q @"
SELECT ISNULL(MAX(page_latch_wait_count), 0) AS LatchWaits,
       ISNULL(MAX(page_latch_wait_in_ms), 0) AS LatchWaitMs,
       ISNULL(MAX(leaf_insert_count), 0)     AS LeafInserts
FROM sys.dm_db_index_operational_stats(DB_ID(), OBJECT_ID('dbo.$Table'), 1, NULL);
"@
}

function Get-WaitStats {
    $list = "'" + ($WaitTypes -join "','") + "'"
    $rows = Invoke-Q @"
SELECT wait_type AS WaitType, wait_time_ms AS WaitMs
FROM sys.dm_os_wait_stats
WHERE wait_type IN ($list);
"@
    $h = @{}
    foreach ($w in $WaitTypes) { $h[$w] = [int64]0 }
    foreach ($r in $rows)      { $h[$r.WaitType] = [int64]$r.WaitMs }
    return $h
}

function Invoke-LoadTest {
    param(
        [Parameter(Mandatory)][string]$Table,
        [Parameter(Mandatory)][int]$Threads,
        [Parameter(Mandatory)][int]$RowsPerThread,
        [Parameter(Mandatory)][int]$Round,
        [Parameter(Mandatory)][string]$Flag
    )

    Invoke-Q "TRUNCATE TABLE dbo.$Table;" | Out-Null

    $mBefore  = Get-IndexStats -Table $Table
    $wBefore  = Get-WaitStats
    $expected = $Threads * $RowsPerThread

    Write-Host ('  [{0,2} sessions] round {1} {2,-3} : {3,9:N0} rows ...' -f $Threads, $Round, $Flag, $expected) -NoNewline

    $sw = [System.Diagnostics.Stopwatch]::StartNew()
    $procs = @(
        foreach ($i in 1..$Threads) {
            Start-Process -FilePath $sqlcmdExe -NoNewWindow -PassThru -ArgumentList @(
                '-S', $ServerInstance, '-E', '-d', $Database, '-C', '-b',
                '-i', $workerFile,
                '-v', "TBL=$Table", "NROWS=$RowsPerThread", "BATCH=$BatchSize"
            )
        }
    )
    $null = $procs.Handle   # cache the handles so ExitCode is readable after exit
    $procs | Wait-Process
    $sw.Stop()

    $failed = @($procs | Where-Object { $_.ExitCode -ne 0 })
    if ($failed.Count -gt 0) {
        Write-Host ''
        throw "$($failed.Count) of $Threads sqlcmd workers exited with an error - aborting (see sqlcmd output above)."
    }

    $mAfter = Get-IndexStats -Table $Table
    $wAfter = Get-WaitStats

    $elapsedMs  = [int]$sw.Elapsed.TotalMilliseconds
    # TRUNCATE creates a new rowset, but the operational stats can reset lazily - after the
    # "before" snapshot was taken. When a counter went backwards, the reset happened mid-run,
    # so the after value alone is the run's total.
    function Get-Delta([int64]$before, [int64]$after) { if ($after -lt $before) { $after } else { $after - $before } }
    $actualRows = [int64](Invoke-Q "SELECT COUNT_BIG(*) AS N FROM dbo.$Table;").N
    $rowsPerSec = if ($elapsedMs -gt 0) { [int]($expected * 1000.0 / $elapsedMs) } else { 0 }

    Write-Host (' {0,8:N0} ms  ({1,9:N0} rows/sec)' -f $elapsedMs, $rowsPerSec) -ForegroundColor Green

    if ($actualRows -ne $expected) {
        Write-Warning ('Expected {0:N0} rows but the table contains {1:N0} - a worker may have failed.' -f $expected, $actualRows)
    }

    [pscustomobject]@{
        Sessions         = $Threads
        Flag             = $Flag
        Round            = $Round
        ElapsedMs        = $elapsedMs
        RowsPerSec       = $rowsPerSec
        RowsInserted     = $actualRows
        IndexLatchWaits  = Get-Delta $mBefore.LatchWaits  $mAfter.LatchWaits
        IndexLatchWaitMs = Get-Delta $mBefore.LatchWaitMs $mAfter.LatchWaitMs
        PagelatchExMs    = $wAfter['PAGELATCH_EX']              - $wBefore['PAGELATCH_EX']
        FlowControlMs    = $wAfter['BTREE_INSERT_FLOW_CONTROL'] - $wBefore['BTREE_INSERT_FLOW_CONTROL']
        WritelogMs       = $wAfter['WRITELOG']                  - $wBefore['WRITELOG']
    }
}

# --- main --------------------------------------------------------------------

$results = [System.Collections.Generic.List[object]]::new()

try {
    $info = Invoke-Q "SELECT CAST(SERVERPROPERTY('ProductVersion') AS VARCHAR(50)) AS Version, cpu_count AS Cpus FROM sys.dm_os_sys_info;"

    Write-Host ''
    Write-Host 'OPTIMIZE_FOR_SEQUENTIAL_KEY test' -ForegroundColor Yellow
    Write-Host ('  Target      : {0} / {1}' -f $ServerInstance, $Database)
    Write-Host ('  SQL Server  : {0}, {1} schedulers' -f $info.Version, $info.Cpus)
    Write-Host ('  Rows/run    : {0:N0}   Batch: {1}   Rounds: {2}' -f $TotalRows, $BatchSize, $Rounds)
    Write-Host ('  Concurrency : {0}' -f ($ThreadCounts -join ', '))
    Write-Host ''

    Initialize-TestTables
    Write-Host ''

    foreach ($threads in $ThreadCounts) {
        $rowsPerThread = [math]::Max(1, [int][math]::Floor($TotalRows / $threads))
        for ($round = 1; $round -le $Rounds; $round++) {
            # Alternate which table runs first so ordering effects cancel out.
            $order = if ($round % 2 -eq 1) { @($TableOff, $TableOn) } else { @($TableOn, $TableOff) }
            foreach ($table in $order) {
                $flag = if ($table -eq $TableOn) { 'ON' } else { 'OFF' }
                $results.Add((Invoke-LoadTest -Table $table -Threads $threads -RowsPerThread $rowsPerThread -Round $round -Flag $flag))
            }
        }
        Write-Host ''
    }
}
finally {
    if (-not $KeepTables) {
        try { Remove-TestTables } catch { Write-Warning "Cleanup failed: $($_.Exception.Message)" }
    }
    else {
        Write-Host "Leaving dbo.$TableOff and dbo.$TableOn in place (-KeepTables)." -ForegroundColor Yellow
    }
    Remove-Item -Path $workerFile -ErrorAction SilentlyContinue
}

if ($results.Count -eq 0) { return }

Write-Host ''
Write-Host 'Per-run detail' -ForegroundColor Yellow
$results | Format-Table Sessions, Flag, Round, ElapsedMs, RowsPerSec, IndexLatchWaitMs, PagelatchExMs, FlowControlMs, WritelogMs -AutoSize | Out-Host

Write-Host "Summary (averaged over $Rounds rounds)" -ForegroundColor Yellow
$summary = foreach ($threads in $ThreadCounts) {
    $off = @($results | Where-Object { $_.Sessions -eq $threads -and $_.Flag -eq 'OFF' })
    $on  = @($results | Where-Object { $_.Sessions -eq $threads -and $_.Flag -eq 'ON'  })
    if ($off.Count -eq 0 -or $on.Count -eq 0) { continue }

    $offMs = ($off | Measure-Object ElapsedMs -Average).Average
    $onMs  = ($on  | Measure-Object ElapsedMs -Average).Average

    [pscustomobject]@{
        Sessions     = $threads
        OffMs        = [int]$offMs
        OnMs         = [int]$onMs
        ChangePct    = [math]::Round((($onMs - $offMs) / $offMs) * 100, 1)
        OffLatchMs   = [int64](($off | Measure-Object IndexLatchWaitMs -Average).Average)
        OnLatchMs    = [int64](($on  | Measure-Object IndexLatchWaitMs -Average).Average)
        OnFlowCtrlMs = [int64](($on  | Measure-Object FlowControlMs -Average).Average)
    }
}
$summary | Format-Table -AutoSize | Out-Host
Write-Host 'ChangePct: negative means OPTIMIZE_FOR_SEQUENTIAL_KEY = ON was faster.' -ForegroundColor DarkGray
Write-Host ''

# Emit the raw results so the caller can pipe them onward.
$results
