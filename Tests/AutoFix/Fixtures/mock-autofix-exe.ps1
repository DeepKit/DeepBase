#requires -Version 7.0
<#
.SYNOPSIS
    Mock AutoFix EXE for runner.ps1 and e2e testing.

.DESCRIPTION
    Simulates the AutoFix command-line contract that the real Delphi EXE
    implements. Reads ALL configuration from environment variables because
    pwsh -File silently discards --autofix-* named arguments.

    Environment variables:
      MOCK_AUTOFIX_BEHAVIOR   : 'pass' | 'error' | 'fatal' | 'crash' |
                                 'timeout' | 'no-health-signal'
                                 Default: 'pass'
      MOCK_AUTOFIX_DELAY_MS   : Milliseconds to sleep after writing
                                 health-signal.json. Default: 0
      MOCK_AUTOFIX_RUN_ID     : run_id to embed in artifacts.
      MOCK_AUTOFIX_SCENARIOS  : Comma-separated scenario names.
      MOCK_AUTOFIX_OUTPUT_DIR : Output directory for artifacts.

    The .cmd wrapper (created by runner.Tests.ps1) is what runner.ps1
    actually executes. It calls this script with no arguments; all
    config flows through environment variables set by the test.

    Behavior details:
      pass              Write health-signal, write empty runtime-errors.jsonl,
                        write scenario-results (running -> pass), exit 0.

      error             Write health-signal, write one runtime-error record,
                        write scenario-results (running -> fail), exit 1.

      fatal             Write health-signal, write one runtime-error record,
                        write exit-reason.json (exit_code=2), write
                        scenario-results (running -> fatal), exit 2.

      crash             Exit immediately with code 3, write NO files.

      timeout           Write health-signal, then sleep indefinitely.

      no-health-signal  Exit 0 without writing health-signal.json.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# ---- Read all config from env vars ----
$behavior    = if ($env:MOCK_AUTOFIX_BEHAVIOR)              { $env:MOCK_AUTOFIX_BEHAVIOR }              else { 'pass' }
$delayMs     = if ($env:MOCK_AUTOFIX_DELAY_MS)              { [int]$env:MOCK_AUTOFIX_DELAY_MS }         else { 0 }
$runId       = if ($env:MOCK_AUTOFIX_RUN_ID)                { $env:MOCK_AUTOFIX_RUN_ID }                else { '' }
$scenarioCsv = if ($env:MOCK_AUTOFIX_SCENARIOS)             { $env:MOCK_AUTOFIX_SCENARIOS }             else { 'mock-scene' }
$outputDir   = if ($env:MOCK_AUTOFIX_OUTPUT_DIR)            { $env:MOCK_AUTOFIX_OUTPUT_DIR }            else { '' }
$iteration   = if ($env:MOCK_AUTOFIX_ITERATION)             { [int]$env:MOCK_AUTOFIX_ITERATION }        else { 1 }

$enc = [System.Text.UTF8Encoding]::new($false)
$ts  = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz')
$scenarios = @($scenarioCsv -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ })

# ---- Helpers ----
function Write-Utf8File {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Append-Utf8File {
    param([string]$Path, [string]$Content)
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    if (-not (Test-Path -LiteralPath $Path)) {
        [System.IO.File]::WriteAllText($Path, $Content, $enc)
    } else {
        [System.IO.File]::AppendAllText($Path, $Content, $enc)
    }
}

# ---- crash: exit immediately, no files ----
if ($behavior -eq 'crash') {
    exit 3
}

# ---- no-health-signal: exit normally without health-signal ----
if ($behavior -eq 'no-health-signal') {
    exit 0
}

# ---- Write health-signal.json ----
if ($outputDir -and $runId) {
    $health = [pscustomobject]@{
        run_id       = $runId
        ready        = $true
        pid          = $PID
        timestamp    = $ts
        version      = 'mock-1.0.0'
        autofix_mode = $true
        scenarios    = $scenarios
    }
    $healthPath = Join-Path $outputDir 'health-signal.json'
    Write-Utf8File -Path $healthPath -Content ($health | ConvertTo-Json -Depth 6)
}

# ---- Optional delay after health-signal ----
if ($delayMs -gt 0) {
    Start-Sleep -Milliseconds $delayMs
}

# ---- timeout: sleep forever after health-signal ----
if ($behavior -eq 'timeout') {
    while ($true) {
        Start-Sleep -Seconds 60
    }
    exit 0  # unreachable
}

# ---- error: write runtime-errors.jsonl ----
if ($behavior -eq 'error') {
    $scenario = if ($scenarios.Count -gt 0) { $scenarios[0] } else { 'mock' }
    $rec = [pscustomobject]@{
        run_id          = $runId
        iteration       = $iteration
        ts              = $ts
        level           = 'error'
        class           = 'EConvertError'
        msg             = 'mock error from fixture'
        module_name     = 'mock-exe.exe'
        module_base     = '$00400000'
        rva             = '$00001234'
        stack           = @(
            [pscustomobject]@{ module_name = 'mock-exe.exe'; module_base = '$00400000'; rva = '$00001234' }
            [pscustomobject]@{ module_name = 'mock-exe.exe'; module_base = '$00400000'; rva = '$00005678' }
        )
        stack_truncated = $false
        context         = '<mock>'
        params          = ''
        state           = ''
        thread          = 'main'
        scenario        = $scenario
        dedup_key       = "EConvertError|mock error from fixture|`$00001234|$scenario"
    }
    $errPath = Join-Path $outputDir 'runtime-errors.jsonl'
    Append-Utf8File -Path $errPath -Content (($rec | ConvertTo-Json -Depth 8 -Compress) + "`n")
}

# ---- fatal: write runtime-errors.jsonl + exit-reason.json ----
if ($behavior -eq 'fatal') {
    $scenario = if ($scenarios.Count -gt 0) { $scenarios[0] } else { 'mock' }
    $rec = [pscustomobject]@{
        run_id          = $runId
        iteration       = $iteration
        ts              = $ts
        level           = 'fatal'
        class           = 'EAccessViolation'
        msg             = 'mock fatal from fixture'
        module_name     = 'mock-exe.exe'
        module_base     = '$00400000'
        rva             = '$0000DEAD'
        stack           = @(
            [pscustomobject]@{ module_name = 'mock-exe.exe'; module_base = '$00400000'; rva = '$0000DEAD' }
        )
        stack_truncated = $false
        context         = '<mock>'
        params          = ''
        state           = ''
        thread          = 'main'
        scenario        = $scenario
        dedup_key       = "EAccessViolation|mock fatal from fixture|`$0000DEAD|$scenario"
    }
    $errPath = Join-Path $outputDir 'runtime-errors.jsonl'
    Append-Utf8File -Path $errPath -Content (($rec | ConvertTo-Json -Depth 8 -Compress) + "`n")

    $exitReason = [pscustomobject]@{
        run_id       = $runId
        exit_code    = 2
        reason       = 'fatal_exception'
        fatal_class  = 'EAccessViolation'
        fatal_msg    = 'mock fatal from fixture'
        module_name  = 'mock-exe.exe'
        module_base  = '$00400000'
        rva          = '$0000DEAD'
        stack        = @(
            [pscustomobject]@{ module_name = 'mock-exe.exe'; module_base = '$00400000'; rva = '$0000DEAD' }
        )
        stack_truncated = $false
        total_errors = 1
        scenario     = $scenario
        timestamp    = $ts
    }
    $exitPath = Join-Path $outputDir 'exit-reason.json'
    Write-Utf8File -Path $exitPath -Content ($exitReason | ConvertTo-Json -Depth 8)
}

# ---- Write scenario-results.jsonl ----
if ($outputDir -and $scenarios.Count -gt 0) {
    $scenario = $scenarios[0]
    $resPath  = Join-Path $outputDir 'scenario-results.jsonl'

    # running row
    $running = [pscustomobject]@{
        run_id   = $runId
        name     = $scenario
        status   = 'running'
        ts       = $ts
        progress = 0
    }
    Append-Utf8File -Path $resPath -Content (($running | ConvertTo-Json -Depth 6 -Compress) + "`n")

    # terminal row
    $terminalStatus = switch ($behavior) {
        'pass'  { 'pass' }
        'error' { 'fail' }
        'fatal' { 'fatal' }
        default { 'pass' }
    }
    $terminal = [pscustomobject]@{
        run_id   = $runId
        name     = $scenario
        status   = $terminalStatus
        ts       = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz')
        duration_ms = 100
        errors   = if ($behavior -in @('error','fatal')) { 1 } else { 0 }
    }
    Append-Utf8File -Path $resPath -Content (($terminal | ConvertTo-Json -Depth 6 -Compress) + "`n")
}

# ---- Exit with appropriate code ----
$exitCode = switch ($behavior) {
    'pass'  { 0 }
    'error' { 1 }
    'fatal' { 2 }
    default { 0 }
}
exit $exitCode
