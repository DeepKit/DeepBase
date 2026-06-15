#requires -Version 7.0
<#
.SYNOPSIS
    Stub runner.ps1 for E2E integration tests.

.DESCRIPTION
    Writes runtime-errors.jsonl and emits a structured JSON status on stdout
    matching the real runner.ps1 contract:
        { run_id, exit_code, started_at, stopped_at, duration_ms, status, pid, ready }

    Env vars:
        STUB_RUNNER_RESULT  : 'error' to produce a runtime error record,
                              'clean' for no errors (default: 'error').
                              First call: error; subsequent calls: clean.
#>
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$RunId,
    [int]$Iteration = 1,
    [string]$Scenarios = 'default',
    [int]$ScenarioTimeout = 30,
    [int]$StartupTimeout = 10,
    [string]$OutputDir = ''
)

if (-not $OutputDir) { $OutputDir = (Get-Location).Path }
$now1 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'

# Track call count via a temp file
$callFile = Join-Path $OutputDir '.stub-runner-calls'
$callCount = 0
if (Test-Path -LiteralPath $callFile -PathType Leaf) {
    $callCount = [int]([System.IO.File]::ReadAllText($callFile).Trim())
}
$callCount++
[System.IO.File]::WriteAllText($callFile, $callCount.ToString(), [System.Text.UTF8Encoding]::new($false))

$mode = $env:STUB_RUNNER_RESULT
if (-not $mode) { $mode = 'error' }

# First call: error. Subsequent calls: clean.
if ($callCount -gt 1) { $mode = 'clean' }

$errorFile = Join-Path $OutputDir 'runtime-errors.jsonl'
$signalFile = Join-Path $OutputDir 'health-signal.json'
$scenarioFile = Join-Path $OutputDir 'scenario-results.jsonl'
$exitReasonFile = Join-Path $OutputDir 'exit-reason.json'

# health-signal
$signal = [pscustomobject]@{
    run_id    = $RunId
    ready     = $true
    version   = '1.0.0-stub'
    scenarios = @($Scenarios -split '[,;]' | ForEach-Object { $_.Trim() })
}
$signalJson = ($signal | ConvertTo-Json -Compress)
[System.IO.File]::WriteAllText($signalFile, $signalJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

# scenario-results
$scenarioName = ($Scenarios -split '[,;]' | ForEach-Object { $_.Trim() })[0]
$scenarioLine = @{ run_id = $RunId; scenario = $scenarioName; iteration = $Iteration; status = 'running'; ts = $now1 }
$scenarioDone = @{ run_id = $RunId; scenario = $scenarioName; iteration = $Iteration; status = if ($mode -eq 'clean') { 'pass' } else { 'fail' }; ts = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz') }
$scenarioJsonl = (($scenarioLine | ConvertTo-Json -Compress) + [Environment]::NewLine + ($scenarioDone | ConvertTo-Json -Compress) + [Environment]::NewLine)
[System.IO.File]::WriteAllText($scenarioFile, $scenarioJsonl, [System.Text.UTF8Encoding]::new($false))

$now2 = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz'

if ($mode -eq 'error') {
    # Write a runtime error record
    $record = [pscustomobject]@{
        ts           = $now2
        run_id       = $RunId
        iteration    = $Iteration
        error_class  = 'EStubError'
        message      = 'stub runtime error for testing'
        module       = 'StubModule'
        rva          = '0x00011000'
        scenario     = $scenarioName
        stack        = @(
            @{ module = 'StubModule'; rva = '0x00011000'; function = 'StubProc'; line = 42; file = 'StubModule.pas' }
        )
        dedup_key    = 'EStubError|stub runtime error for testing|0x00011000'
    }
    $line = ($record | ConvertTo-Json -Compress)
    [System.IO.File]::WriteAllText($errorFile, $line + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

    # exit-reason
    $exitReason = [pscustomobject]@{
        run_id       = $RunId
        exit_code    = 1
        reason       = 'runtime_error'
        total_errors = 1
        scenario     = $scenarioName
    }
    $erJson = ($exitReason | ConvertTo-Json -Compress)
    [System.IO.File]::WriteAllText($exitReasonFile, $erJson + [Environment]::NewLine, [System.Text.UTF8Encoding]::new($false))

    # Emit structured JSON status on stdout (real runner contract)
    $status = [pscustomobject]@{
        run_id      = $RunId
        exit_code   = 1
        started_at  = $now1
        stopped_at  = $now2
        duration_ms = 1000
        status      = 'normal'
        pid         = $PID
        ready       = $true
    }
    Write-Output ($status | ConvertTo-Json -Compress)
    exit 0
} else {
    # Clean run — remove stale errors
    if (Test-Path -LiteralPath $errorFile -PathType Leaf) {
        Remove-Item -LiteralPath $errorFile -Force -ErrorAction SilentlyContinue
    }

    $status = [pscustomobject]@{
        run_id      = $RunId
        exit_code   = 0
        started_at  = $now1
        stopped_at  = $now2
        duration_ms = 500
        status      = 'normal'
        pid         = $PID
        ready       = $true
    }
    Write-Output ($status | ConvertTo-Json -Compress)
    exit 0
}
