<#
.SYNOPSIS
    WER / minidump fallback collector for hard crashes.

.DESCRIPTION
    Invoked by runner.ps1 when the EXE exits with a non-zero code AND no
    exit-reason.json was written. Always emits at least one synthetic
    record to runtime-errors.jsonl so the main loop has something to feed
    into dedup → AI fix.

    Behaviour (Req 13.1-13.3):
      1. Look for %LOCALAPPDATA%\CrashDumps\<ExeName>.<ProcessId>.dmp
      2. If found, try to extract exception code + top frame module via
         cdb.exe (Debugging Tools for Windows). Failures degrade silently.
      3. Always append exactly one record:
           class = 'WerExtracted'  when cdb output parsed
           class = 'HardCrash'     otherwise
         Record carries: run_id, exit_code, duration_ms (if startup ts known),
         module_name, rva, dump_path.

.PARAMETER ExeName
    Name of the EXE that crashed (with or without .exe suffix).

.PARAMETER ProcessId
    PID of the crashed process.

.PARAMETER ExitCode
    Process exit code as reported by the OS.

.PARAMETER RunId
    Current AutoFix run_id (UUID).

.PARAMETER OutputDir
    Output directory containing runtime-errors.jsonl. Default 'autofix-output'.

.PARAMETER StartedAt
    Optional ISO-8601 start timestamp. When supplied, duration_ms is
    computed against the current time.

.PARAMETER DumpsDir
    Optional override for the WER CrashDumps directory. Defaults to
    "$env:LOCALAPPDATA\CrashDumps". Used to allow tests to point at a
    fixture directory without touching real WER output.

.PARAMETER CdbPath
    Optional override for cdb.exe. Defaults to 'cdb.exe' (PATH lookup).

.NOTES
    Validates Requirements 13.1, 13.2, 13.3.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$ExeName,
    [Parameter(Mandatory)][int]$ProcessId,
    [Parameter(Mandatory)][int]$ExitCode,
    [Parameter(Mandatory)][string]$RunId,

    [string]$OutputDir = 'autofix-output',
    [string]$StartedAt,
    [string]$DumpsDir,
    [string]$CdbPath,
    [int]$Iteration = 0,
    [string]$Scenario = ''
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Resolve-DumpsDir {
    [CmdletBinding()]
    param([string]$Override)
    if ($Override) { return $Override }
    if ($env:LOCALAPPDATA) {
        return (Join-Path $env:LOCALAPPDATA 'CrashDumps')
    }
    return $null
}

function Find-DumpFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Dir,
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][int]$ProcId
    )
    if (-not (Test-Path -LiteralPath $Dir -PathType Container)) { return $null }

    $stem = $Exe
    if ($stem.ToLowerInvariant().EndsWith('.exe')) {
        $stem = $stem.Substring(0, $stem.Length - 4)
    }

    # Most precise match first: <stem>.<pid>.dmp
    $exact = Get-ChildItem -LiteralPath $Dir -Filter "$stem.$ProcId.dmp" -File -ErrorAction SilentlyContinue
    if ($exact -and $exact.Count -gt 0) { return $exact[0].FullName }

    # Fallback: most recent <stem>.*.dmp
    $candidates = Get-ChildItem -LiteralPath $Dir -Filter "$stem.*.dmp" -File -ErrorAction SilentlyContinue |
                  Sort-Object LastWriteTime -Descending
    if ($candidates -and $candidates.Count -gt 0) { return $candidates[0].FullName }

    return $null
}

function Find-Cdb {
    [CmdletBinding()]
    param([string]$Override)
    if ($Override) {
        if (Test-Path -LiteralPath $Override -PathType Leaf) { return $Override }
        return $null
    }
    $cmd = Get-Command -Name 'cdb.exe' -ErrorAction SilentlyContinue
    if ($cmd) { return $cmd.Source }
    foreach ($candidate in @(
        'C:\Program Files (x86)\Windows Kits\10\Debuggers\x64\cdb.exe',
        'C:\Program Files\Debugging Tools for Windows (x64)\cdb.exe'
    )) {
        if (Test-Path -LiteralPath $candidate -PathType Leaf) { return $candidate }
    }
    return $null
}

function Read-CdbAnalysis {
    <#
    .SYNOPSIS
        Run "cdb -z <dmp> -c '!analyze -v;q'" and extract a few fields.
    .OUTPUTS
        @{ ExceptionCode; ExceptionAddress; ModuleName; FaultingFunc } or $null on failure.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Cdb,
        [Parameter(Mandatory)][string]$DumpFile
    )
    try {
        $args = @('-z', $DumpFile, '-c', '!analyze -v;q')
        $out = & $Cdb @args 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-AutoFixLog -Level warn -Msg 'cdb returned non-zero' -Ctx @{ exit = $LASTEXITCODE }
        }
        $text = ($out | Out-String)
        $info = @{
            ExceptionCode    = $null
            ExceptionAddress = $null
            ModuleName       = $null
            FaultingFunc     = $null
        }
        $m = [regex]::Match($text, 'ExceptionCode:\s*([0-9A-Fa-fxX]+)')
        if ($m.Success) { $info.ExceptionCode = $m.Groups[1].Value }
        $m = [regex]::Match($text, 'ExceptionAddress:\s*([0-9A-Fa-fxX`]+)')
        if ($m.Success) { $info.ExceptionAddress = $m.Groups[1].Value -replace '`', '' }
        $m = [regex]::Match($text, 'MODULE_NAME:\s*(\S+)')
        if ($m.Success) { $info.ModuleName = $m.Groups[1].Value }
        $m = [regex]::Match($text, 'FAULTING_IP:\s*\r?\n\S+\s+([0-9A-Fa-fxX`]+)\s+([^\r\n]+)')
        if ($m.Success) { $info.FaultingFunc = $m.Groups[2].Value.Trim() }
        return $info
    }
    catch {
        Write-AutoFixLog -Level warn -Msg 'cdb invocation failed' -Ctx @{ error = $_.Exception.Message }
        return $null
    }
}

function ConvertTo-RvaText {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Hex)
    $t = $Hex
    if ([string]::IsNullOrWhiteSpace($t)) { return '$00000000' }
    $t = $t.Trim() -replace '`', ''
    if ($t.StartsWith('0x') -or $t.StartsWith('0X')) { $t = $t.Substring(2) }
    elseif ($t.StartsWith('$')) { $t = $t.Substring(1) }
    try {
        $val = [Convert]::ToUInt64($t, 16)
        return ('$' + $val.ToString('X8'))
    } catch {
        return '$00000000'
    }
}

function Get-DurationMs {
    [CmdletBinding()]
    param([string]$Started)
    if ([string]::IsNullOrWhiteSpace($Started)) { return 0 }
    [datetime]$dt = [datetime]::MinValue
    if (-not [datetime]::TryParse($Started, [ref]$dt)) { return 0 }
    $span = (Get-Date) - $dt
    $ms = $span.TotalMilliseconds
    # Clamp to Int32 range to avoid overflow from ancient sentinel dates
    if ($ms -gt [int]::MaxValue) { return [int]::MaxValue }
    if ($ms -lt [int]::MinValue) { return [int]::MinValue }
    return [int]$ms
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    if ([string]::IsNullOrWhiteSpace($ExeName)) {
        Write-AutoFixLog -Level error -Msg 'missing -ExeName' -Ctx @{}
        exit $Script:AutoFixExit_BadParams
    }
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        Write-AutoFixLog -Level error -Msg 'missing -RunId' -Ctx @{}
        exit $Script:AutoFixExit_BadParams
    }

    $outDir = Resolve-OutputDir -Path $OutputDir
    $jsonl  = Join-Path $outDir 'runtime-errors.jsonl'

    $dumpsDir = Resolve-DumpsDir -Override $DumpsDir
    $dumpFile = $null
    if ($dumpsDir) {
        $dumpFile = Find-DumpFile -Dir $dumpsDir -Exe $ExeName -ProcId $ProcessId
    }

    $analysis = $null
    $cls      = 'HardCrash'
    $msg      = ("process exited with code $ExitCode and no exit-reason.json was written")
    $module   = $ExeName
    $rva      = '$00000000'

    if ($dumpFile) {
        $cdb = Find-Cdb -Override $CdbPath
        if ($cdb) {
            Write-AutoFixLog -Level info -Msg 'analysing dump with cdb' -Ctx @{ dump = $dumpFile; cdb = $cdb }
            $analysis = Read-CdbAnalysis -Cdb $cdb -DumpFile $dumpFile
            if ($analysis) {
                $cls = 'WerExtracted'
                $code = if ($analysis.ExceptionCode) { $analysis.ExceptionCode } else { 'unknown' }
                $func = if ($analysis.FaultingFunc) { $analysis.FaultingFunc } else { '<unknown>' }
                $msg = "WER analysis: ExceptionCode=$code in $func (exit=$ExitCode)"
                if ($analysis.ModuleName) { $module = [string]$analysis.ModuleName }
                if ($analysis.ExceptionAddress) { $rva = ConvertTo-RvaText -Hex $analysis.ExceptionAddress }
            }
        } else {
            Write-AutoFixLog -Level warn -Msg 'cdb.exe not available; falling back to HardCrash record' -Ctx @{ dump = $dumpFile }
        }
    } else {
        Write-AutoFixLog -Level info -Msg 'no minidump found; emitting HardCrash record' -Ctx @{ dumps_dir = $dumpsDir; pid = $ProcessId }
    }

    $durationMs = Get-DurationMs -Started $StartedAt

    $stackEntry = [pscustomobject]@{
        module_name = $module
        module_base = '$00000000'
        rva         = $rva
    }

    $msgSlice = if ($msg.Length -gt 80) { $msg.Substring(0, 80) } else { $msg }
    $dedupKey = ("$cls|$msgSlice|$rva|$Scenario")

    $record = [pscustomobject]@{
        run_id          = $RunId
        iteration       = $Iteration
        ts              = Get-AutoFixTimestamp
        level           = 'fatal'
        class           = $cls
        msg             = $msg
        module_name     = $module
        module_base     = '$00000000'
        rva             = $rva
        stack           = @($stackEntry)
        stack_truncated = $true
        context         = '<wer-collector>'
        params          = ''
        state           = ''
        thread          = 'unknown'
        scenario        = $Scenario
        dedup_key       = $dedupKey
        exit_code       = $ExitCode
        duration_ms     = $durationMs
        dump_path       = $dumpFile
    }

    Write-Jsonl -Path $jsonl -Object $record -Append
    Write-AutoFixLog -Level info -Msg 'wer-collector record written' -Ctx @{
        path = $jsonl; class = $cls; exit_code = $ExitCode; dump_found = ([bool]$dumpFile)
    }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'wer-collector.ps1' }
    exit $Script:AutoFixExit_Generic
}
