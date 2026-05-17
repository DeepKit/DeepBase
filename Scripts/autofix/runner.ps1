<#
.SYNOPSIS
    Spawn an AutoFix-mode EXE, wait for health-signal, enforce timeouts,
    and report the resulting exit code as a structured JSON object.

.DESCRIPTION
    runner.ps1 is the bridge between the main autofix.ps1 loop and the
    target EXE. It performs (design §3.8.2):

      1. Start EXE with the AutoFix command-line contract:
            --autofix-mode
            --autofix-run-id=<RunId>
            --autofix-iteration=<N>
            --autofix-scenario=<csv>
            --autofix-output=<OutputDir>
      2. Poll <OutputDir>/health-signal.json every 200ms until either:
           a) the file exists, parses, and run_id == $RunId  -> ready
           b) StartupTimeout elapses                         -> hard crash
           c) the process exits before becoming ready        -> hard crash
      3. After ready, enforce ScenarioTimeout. On timeout the process is
         force-terminated and a synthetic exit-reason.json is written.
      4. On any abnormal termination (timeout / startup failure) a
         synthetic record is appended to runtime-errors.jsonl so the
         caller has at least one error to feed into the dedup pipeline.
      5. Emit a JSON status object on stdout:
            { run_id, exit_code, started_at, stopped_at,
              duration_ms, status, pid, ready }
         status ∈ { 'normal' | 'startup-timeout' | 'scenario-timeout'
                  | 'startup-failed' | 'crashed' }.

    Exit codes:
        0   process exited normally  (real exit code is in the JSON payload)
        3   timeout (startup or scenario) — enforced by this script
       100  bad parameters
        1   any other unexpected failure

.NOTES
    Validates Requirements 2.4, 3.1, 3.2, 3.3.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Exe,
    [Parameter(Mandatory)][string]$RunId,
    [Parameter(Mandatory)][int]$Iteration,
    [Parameter(Mandatory)][string]$Scenarios,

    [int]$StartupTimeout = 30,
    [int]$ScenarioTimeout = 600,

    [string]$OutputDir = 'autofix-output',

    [int]$PollIntervalMs = 200
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Read-HealthIfReady {
    <#
    .SYNOPSIS
        Try to parse health-signal.json; return $null until run_id matches.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$ExpectedRunId
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return $null }
    try {
        $obj = Read-JsonFile -Path $Path
        if ($null -eq $obj) { return $null }
        if (-not $obj.PSObject.Properties['run_id']) { return $null }
        if ([string]$obj.run_id -ne $ExpectedRunId) { return $null }
        return $obj
    } catch {
        # File is being written; try again next tick.
        return $null
    }
}

function Stop-ChildProcess {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Process)
    try {
        if ($null -ne $Process -and -not $Process.HasExited) {
            Stop-Process -Id $Process.Id -Force -ErrorAction SilentlyContinue
            $null = $Process.WaitForExit(2000)
        }
    } catch {
        Write-AutoFixLog -Level warn -Msg 'Stop-Process failed' -Ctx @{ error = $_.Exception.Message }
    }
}

function Write-SyntheticRuntimeError {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RunIdValue,
        [Parameter(Mandatory)][int]$IterationValue,
        [Parameter(Mandatory)][string]$Cls,
        [Parameter(Mandatory)][string]$Msg,
        [Parameter(Mandatory)][string]$ExeName,
        [int]$ExitCodeValue = -1,
        [int]$DurationValue = 0,
        [string]$ScenarioValue = ''
    )
    $msgSlice = if ($Msg.Length -gt 80) { $Msg.Substring(0, 80) } else { $Msg }
    $rec = [pscustomobject]@{
        run_id          = $RunIdValue
        iteration       = $IterationValue
        ts              = Get-AutoFixTimestamp
        level           = 'fatal'
        class           = $Cls
        msg             = $Msg
        module_name     = $ExeName
        module_base     = '$00000000'
        rva             = '$00000000'
        stack           = @(@{
            module_name = $ExeName
            module_base = '$00000000'
            rva         = '$00000000'
        })
        stack_truncated = $true
        context         = '<runner.ps1>'
        params          = ''
        state           = ''
        thread          = 'unknown'
        scenario        = $ScenarioValue
        dedup_key       = "$Cls|$msgSlice|`$00000000|$ScenarioValue"
        exit_code       = $ExitCodeValue
        duration_ms     = $DurationValue
    }
    Write-Jsonl -Path $Path -Object $rec -Append
}

function Write-SyntheticExitReason {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$RunIdValue,
        [Parameter(Mandatory)][int]$ExitCodeValue,
        [Parameter(Mandatory)][string]$Reason,
        [Parameter(Mandatory)][string]$Cls,
        [Parameter(Mandatory)][string]$Msg,
        [string]$ScenarioValue = ''
    )
    $obj = [pscustomobject]@{
        run_id       = $RunIdValue
        exit_code    = $ExitCodeValue
        reason       = $Reason
        fatal_class  = $Cls
        fatal_msg    = $Msg
        module_name  = ''
        rva          = '$00000000'
        stack        = @()
        total_errors = 0
        scenario     = $ScenarioValue
        timestamp    = Get-AutoFixTimestamp
    }
    Write-JsonFile -Path $Path -Object $obj
}

function Emit-Status {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$RunIdValue,
        [Parameter(Mandatory)][int]$ExitCodeValue,
        [Parameter(Mandatory)][string]$Status,
        [Parameter(Mandatory)][string]$StartedAt,
        [Parameter(Mandatory)][string]$StoppedAt,
        [Parameter(Mandatory)][int]$DurationMs,
        [int]$ProcId = 0,
        [bool]$Ready = $false
    )
    $obj = [pscustomobject]@{
        run_id      = $RunIdValue
        exit_code   = $ExitCodeValue
        status      = $Status
        started_at  = $StartedAt
        stopped_at  = $StoppedAt
        duration_ms = $DurationMs
        pid         = $ProcId
        ready       = $Ready
    }
    [Console]::Out.WriteLine(($obj | ConvertTo-Json -Depth 6 -Compress))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
$started   = Get-Date
$startedTs = Get-AutoFixTimestamp

try {
    if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'Exe not found' -Ctx @{ exe = $Exe }
        exit $Script:AutoFixExit_BadParams
    }
    if ([string]::IsNullOrWhiteSpace($RunId)) {
        Write-AutoFixLog -Level error -Msg 'RunId is empty' -Ctx @{}
        exit $Script:AutoFixExit_BadParams
    }

    $outDir  = Resolve-OutputDir -Path $OutputDir
    $health  = Join-Path $outDir 'health-signal.json'
    $errsLog = Join-Path $outDir 'runtime-errors.jsonl'
    $exitLog = Join-Path $outDir 'exit-reason.json'
    $exeName = [System.IO.Path]::GetFileName($Exe)
    $exeStem = [System.IO.Path]::GetFileNameWithoutExtension($Exe)

    # Make sure stale health-signal from a previous iteration cannot be
    # mistaken for the current one. We don't touch error logs (the loop
    # decides whether to keep them across iterations).
    if (Test-Path -LiteralPath $health -PathType Leaf) {
        Remove-Item -LiteralPath $health -Force -ErrorAction SilentlyContinue
    }

    $runArgs = @(
        '--autofix-mode',
        ("--autofix-run-id=$RunId"),
        ("--autofix-iteration=$Iteration"),
        ("--autofix-scenario=$Scenarios"),
        ("--autofix-output=$outDir"),
        ("--autofix-scenario-timeout=$ScenarioTimeout")
    )

    Write-AutoFixLog -Level info -Msg 'spawning AutoFix EXE' -Ctx @{
        exe = $Exe; run_id = $RunId; iteration = $Iteration; scenarios = $Scenarios
    }

    $proc = Start-Process -FilePath $Exe -ArgumentList $runArgs `
        -PassThru -WindowStyle Hidden

    # ---- Phase A: wait for ready ----
    # Race-aware order: check health-signal first so a fast-exiting console
    # EXE that wrote health-signal then completed before we polled is still
    # classified as 'ready' (then phase B's WaitForExit returns immediately
    # and we report the real exit code). Only when no matching health-signal
    # has been observed AND the process has exited do we treat it as a
    # startup crash.
    $readyDeadline = $started.AddSeconds($StartupTimeout)
    $ready = $null
    while ((Get-Date) -lt $readyDeadline) {
        $ready = Read-HealthIfReady -Path $health -ExpectedRunId $RunId
        if ($null -ne $ready) { break }

        if ($proc.HasExited) {
            # Process exited before signalling ready.
            $rc = $proc.ExitCode
            $stoppedTs = Get-AutoFixTimestamp
            $duration = [int]((Get-Date) - $started).TotalMilliseconds

            Write-SyntheticRuntimeError -Path $errsLog `
                -RunIdValue $RunId -IterationValue $Iteration `
                -Cls 'HardCrash' -Msg "process exited during startup with code $rc" `
                -ExeName $exeName -ExitCodeValue $rc -DurationValue $duration `
                -ScenarioValue $Scenarios
            Write-SyntheticExitReason -Path $exitLog `
                -RunIdValue $RunId -ExitCodeValue $rc -Reason 'startup_crash' `
                -Cls 'HardCrash' -Msg "process exited during startup with code $rc" `
                -ScenarioValue $Scenarios

            Emit-Status -RunIdValue $RunId -ExitCodeValue $rc `
                -Status 'startup-failed' -StartedAt $startedTs `
                -StoppedAt $stoppedTs -DurationMs $duration `
                -ProcId $proc.Id -Ready $false
            exit 3
        }

        Start-Sleep -Milliseconds $PollIntervalMs
    }

    if ($null -eq $ready) {
        # Startup timeout: kill, synthesize records, exit 3.
        Stop-ChildProcess -Process $proc
        $stoppedTs = Get-AutoFixTimestamp
        $duration = [int]((Get-Date) - $started).TotalMilliseconds
        $rc = if ($proc.HasExited) { $proc.ExitCode } else { -1 }

        Write-AutoFixLog -Level error -Msg 'startup timeout exceeded' -Ctx @{
            timeout_sec = $StartupTimeout; elapsed_ms = $duration
        }
        Write-SyntheticRuntimeError -Path $errsLog `
            -RunIdValue $RunId -IterationValue $Iteration `
            -Cls 'HardCrash' -Msg "startup timeout: health-signal.json with run_id=$RunId not seen within ${StartupTimeout}s" `
            -ExeName $exeName -ExitCodeValue $rc -DurationValue $duration `
            -ScenarioValue $Scenarios
        Write-SyntheticExitReason -Path $exitLog `
            -RunIdValue $RunId -ExitCodeValue 3 -Reason 'startup_timeout' `
            -Cls 'HardCrash' -Msg "startup timeout: ${StartupTimeout}s elapsed without health-signal" `
            -ScenarioValue $Scenarios

        Emit-Status -RunIdValue $RunId -ExitCodeValue $rc `
            -Status 'startup-timeout' -StartedAt $startedTs `
            -StoppedAt $stoppedTs -DurationMs $duration `
            -ProcId $proc.Id -Ready $false
        exit 3
    }

    Write-AutoFixLog -Level info -Msg 'EXE reported ready' -Ctx @{
        pid = $ready.pid; version = $ready.version
    }

    # ---- Phase B: wait for normal exit or scenario timeout ----
    $exited = $proc.WaitForExit([int]([math]::Max(1, $ScenarioTimeout)) * 1000)
    if (-not $exited) {
        Stop-ChildProcess -Process $proc
        $stoppedTs = Get-AutoFixTimestamp
        $duration = [int]((Get-Date) - $started).TotalMilliseconds
        $rc = if ($proc.HasExited) { $proc.ExitCode } else { -1 }

        Write-AutoFixLog -Level error -Msg 'scenario timeout exceeded' -Ctx @{
            timeout_sec = $ScenarioTimeout; elapsed_ms = $duration
        }
        Write-SyntheticRuntimeError -Path $errsLog `
            -RunIdValue $RunId -IterationValue $Iteration `
            -Cls 'ScenarioTimeout' -Msg "scenarios did not finish within ${ScenarioTimeout}s" `
            -ExeName $exeName -ExitCodeValue 3 -DurationValue $duration `
            -ScenarioValue $Scenarios
        Write-SyntheticExitReason -Path $exitLog `
            -RunIdValue $RunId -ExitCodeValue 3 -Reason 'scenario_timeout' `
            -Cls 'ScenarioTimeout' -Msg "scenarios did not finish within ${ScenarioTimeout}s" `
            -ScenarioValue $Scenarios

        Emit-Status -RunIdValue $RunId -ExitCodeValue $rc `
            -Status 'scenario-timeout' -StartedAt $startedTs `
            -StoppedAt $stoppedTs -DurationMs $duration `
            -ProcId $proc.Id -Ready $true
        exit 3
    }

    # Normal exit path.
    $stoppedTs = Get-AutoFixTimestamp
    $duration = [int]((Get-Date) - $started).TotalMilliseconds
    $rc = $proc.ExitCode

    $status = if ($rc -ge 0 -and $rc -le 4) { 'normal' } else { 'crashed' }

    Write-AutoFixLog -Level info -Msg 'EXE exited' -Ctx @{
        exit_code = $rc; duration_ms = $duration; status = $status
    }
    Emit-Status -RunIdValue $RunId -ExitCodeValue $rc `
        -Status $status -StartedAt $startedTs `
        -StoppedAt $stoppedTs -DurationMs $duration `
        -ProcId $proc.Id -Ready $true
    exit 0
}
catch {
    $stoppedTs = Get-AutoFixTimestamp
    $duration = [int]((Get-Date) - $started).TotalMilliseconds
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'runner.ps1' }
    Emit-Status -RunIdValue $RunId -ExitCodeValue (-1) `
        -Status 'startup-failed' -StartedAt $startedTs `
        -StoppedAt $stoppedTs -DurationMs $duration `
        -ProcId 0 -Ready $false
    exit $Script:AutoFixExit_Generic
}
