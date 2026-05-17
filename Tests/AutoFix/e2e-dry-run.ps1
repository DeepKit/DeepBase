<#
.SYNOPSIS
    End-to-end dry-run for the AutoFix pipeline (lint + fixture).

.DESCRIPTION
    Two-step dry-run that validates the AutoFix scaffolding without
    touching a real AI backend or running the autofix.ps1 main loop:

      Step 1: Run all four AutoFix linters and require exit 0 from each.
                - lint-pascal-deps.ps1
                - lint-powershell-strict.ps1
                - lint-no-reset-hard.ps1
                - lint-doc-version.ps1

      Step 2: Drive the AutoFixHarness fixture through runner.ps1 once
              per scenario ('pass', 'error', 'fatal') and validate:
                - The expected exit code (0 / 1 / 2)
                - health-signal.json is present and contains the
                  expected run_id, ready=true, version, scenarios.
                - runtime-errors.jsonl rows (if any) carry the same
                  run_id and the documented schema fields.
                - scenario-results.jsonl contains a 'running' row plus
                  a terminal row matching the expected status
                  (pass / fail / fatal).
                - exit-reason.json is written iff scenario == 'fatal'
                  and contains the documented schema (exit_code 2,
                  fatal_class, stack array, total_errors, scenario,
                  matching run_id).

      If the fixture EXE is missing or fails to build, Step 2 is
      skipped with a warning and the script still exits 0 as long as
      Step 1 succeeded — Step 2 is the strict gate, Step 1 is the
      always-on minimum.

      Output mode:
        Default      : structured summary on stdout, exit 0/1
        -Verbose     : Step 2 dumps per-scenario file listings and
                       the first few lines of each captured artifact

.NOTES
    Validates Requirements 11.1, 11.5 (subset).
    Companion: design v2.0 §7.5.
#>
[CmdletBinding()]
param(
    [string]$Harness  = (Join-Path $PSScriptRoot 'Fixtures\AutoFixHarness.exe'),
    [string]$WorkDir  = (Join-Path $PSScriptRoot '..\..\TestResults\autofix-e2e-dry-run'),
    [int]$StartupTimeout  = 10,
    [int]$ScenarioTimeout = 30
)

. "$PSScriptRoot/../../scripts/autofix/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Get-RepoRoot {
    [CmdletBinding()]
    param()
    return (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
}

function Invoke-Lint {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$ScriptPath
    )
    if (-not (Test-Path -LiteralPath $ScriptPath -PathType Leaf)) {
        return [pscustomobject]@{ name = $Name; status = 'missing'; exit_code = -1; path = $ScriptPath }
    }
    & pwsh -NoProfile -File $ScriptPath *> $null
    $rc = $LASTEXITCODE
    return [pscustomobject]@{
        name      = $Name
        status    = if ($rc -eq 0) { 'pass' } else { 'fail' }
        exit_code = $rc
        path      = $ScriptPath
    }
}

function Get-JsonlObjects {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
    return ,(Read-Jsonl -Path $Path)
}

function Test-RecordSchema {
    <#
    .SYNOPSIS
        Validate that all required field names exist on a PSObject.
    .OUTPUTS
        Array of missing field names (empty if compliant).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()]$Record,
        [Parameter(Mandatory)][string[]]$Fields
    )
    $missing = New-Object System.Collections.Generic.List[string]
    if ($null -eq $Record) {
        foreach ($f in $Fields) { $missing.Add($f) | Out-Null }
        return ,@($missing.ToArray())
    }
    foreach ($f in $Fields) {
        if (-not $Record.PSObject.Properties[$f]) { $missing.Add($f) | Out-Null }
    }
    return ,@($missing.ToArray())
}

function Invoke-ScenarioRun {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string]$Scenario,
        [Parameter(Mandatory)][string]$OutputDir,
        [int]$StartupTimeout  = 10,
        [int]$ScenarioTimeout = 30
    )

    if (Test-Path -LiteralPath $OutputDir) {
        Remove-Item -LiteralPath $OutputDir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null

    $runId = New-AutoFixRunId
    $runner = Join-Path (Get-RepoRoot) 'scripts\autofix\runner.ps1'

    $statusJson = & pwsh -NoProfile -File $runner `
        -Exe $Exe -RunId $runId -Iteration 1 `
        -Scenarios $Scenario -OutputDir $OutputDir `
        -StartupTimeout $StartupTimeout -ScenarioTimeout $ScenarioTimeout 2> $null

    $runnerExit = $LASTEXITCODE
    $status = $null
    if ($statusJson) {
        try { $status = ($statusJson | Select-Object -Last 1) | ConvertFrom-Json -Depth 6 } catch { $status = $null }
    }

    return [pscustomobject]@{
        scenario       = $Scenario
        run_id         = $runId
        runner_exit    = $runnerExit
        runner_status  = $status
        output_dir     = $OutputDir
    }
}

function Test-ScenarioOutputs {
    <#
    .SYNOPSIS
        Validate JSONL/JSON artifacts produced by a single scenario run.
    .OUTPUTS
        PSObject with .checks (array of {name, ok, detail}) and .ok.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Run,
        [Parameter(Mandatory)][string]$ExpectedScenario,
        [Parameter(Mandatory)][int]$ExpectedExitCode,
        [Parameter(Mandatory)][ValidateSet('pass','fail','fatal')]$ExpectedFinalStatus,
        [Parameter(Mandatory)][bool]$ExpectExitReason
    )

    $checks = New-Object System.Collections.Generic.List[object]
    $expectedRunId = $Run.run_id
    $out = $Run.output_dir

    function Add-Check {
        param([string]$Name, [bool]$Ok, [string]$Detail = '')
        $checks.Add([pscustomobject]@{ name = $Name; ok = $Ok; detail = $Detail }) | Out-Null
    }

    # ---- exit code from runner status payload ----
    $rs = $Run.runner_status
    if ($null -eq $rs) {
        Add-Check 'runner emitted status JSON' $false 'runner.ps1 produced no parseable status object'
    } else {
        Add-Check 'runner status: run_id matches' ([string]$rs.run_id -eq $expectedRunId) "runner.run_id=$($rs.run_id) expected=$expectedRunId"
        Add-Check 'runner status: exit_code matches' ([int]$rs.exit_code -eq $ExpectedExitCode) "runner.exit_code=$($rs.exit_code) expected=$ExpectedExitCode"
        Add-Check 'runner status: ready=true' ([bool]$rs.ready) "runner.ready=$($rs.ready)"
    }

    # ---- health-signal.json ----
    $healthPath = Join-Path $out 'health-signal.json'
    $health = $null
    if (-not (Test-Path -LiteralPath $healthPath -PathType Leaf)) {
        Add-Check 'health-signal.json exists' $false "missing: $healthPath"
    } else {
        try { $health = Read-JsonFile -Path $healthPath } catch { $health = $null }
        if ($null -eq $health) {
            Add-Check 'health-signal.json parses' $false 'failed to parse health-signal.json'
        } else {
            $missing = Test-RecordSchema -Record $health -Fields @('run_id','ready','pid','timestamp','version','autofix_mode','scenarios')
            Add-Check 'health-signal: schema fields present' ($missing.Count -eq 0) ("missing=" + ($missing -join ','))
            Add-Check 'health-signal: run_id matches'        ([string]$health.run_id -eq $expectedRunId) "got=$($health.run_id) expected=$expectedRunId"
            Add-Check 'health-signal: ready=true'            ([bool]$health.ready)                       ''
            Add-Check 'health-signal: autofix_mode=true'     ([bool]$health.autofix_mode)                ''
            $sceneList = @($health.scenarios)
            Add-Check 'health-signal: scenarios contains expected' ($sceneList -contains $ExpectedScenario) ("got=" + ($sceneList -join ','))
        }
    }

    # ---- scenario-results.jsonl ----
    $resPath = Join-Path $out 'scenario-results.jsonl'
    $rows = Get-JsonlObjects -Path $resPath
    if ($rows.Count -lt 2) {
        Add-Check 'scenario-results.jsonl has >= 2 rows' $false "row_count=$($rows.Count)"
    } else {
        $running = $rows | Where-Object { [string]$_.status -eq 'running' } | Select-Object -First 1
        $terminal = $rows | Where-Object { [string]$_.status -ne 'running' } | Select-Object -Last 1
        Add-Check 'scenario-results: contains running row' ($null -ne $running) ''
        Add-Check 'scenario-results: contains terminal row' ($null -ne $terminal) ''
        if ($null -ne $terminal) {
            Add-Check 'scenario-results: terminal status matches' ([string]$terminal.status -eq $ExpectedFinalStatus) "got=$($terminal.status) expected=$ExpectedFinalStatus"
            Add-Check 'scenario-results: terminal name matches'   ([string]$terminal.name   -eq $ExpectedScenario)    "got=$($terminal.name)"
            Add-Check 'scenario-results: run_id matches'           ([string]$terminal.run_id -eq $expectedRunId)        "got=$($terminal.run_id)"
        }
    }

    # ---- runtime-errors.jsonl ----
    $errPath = Join-Path $out 'runtime-errors.jsonl'
    $errs = Get-JsonlObjects -Path $errPath
    if ($ExpectedFinalStatus -eq 'fail') {
        Add-Check 'runtime-errors.jsonl has >= 1 row' ($errs.Count -ge 1) "row_count=$($errs.Count)"
        if ($errs.Count -ge 1) {
            $first = $errs[0]
            $missing = Test-RecordSchema -Record $first -Fields @(
                'run_id','iteration','ts','level','class','msg','module_name',
                'module_base','rva','stack','stack_truncated','context','thread',
                'scenario','dedup_key')
            Add-Check 'runtime-errors[0]: schema fields present' ($missing.Count -eq 0) ("missing=" + ($missing -join ','))
            Add-Check 'runtime-errors[0]: run_id matches' ([string]$first.run_id -eq $expectedRunId) "got=$($first.run_id)"
            Add-Check 'runtime-errors[0]: scenario matches' ([string]$first.scenario -eq $ExpectedScenario) "got=$($first.scenario)"
        }
    } else {
        # pass and fatal scenarios produce no runtime-errors entries (BOM-only file is OK)
        Add-Check 'runtime-errors.jsonl has 0 records' ($errs.Count -eq 0) "row_count=$($errs.Count)"
    }

    # ---- exit-reason.json ----
    $exitPath = Join-Path $out 'exit-reason.json'
    if ($ExpectExitReason) {
        if (-not (Test-Path -LiteralPath $exitPath -PathType Leaf)) {
            Add-Check 'exit-reason.json exists' $false "missing: $exitPath"
        } else {
            $reason = $null
            try { $reason = Read-JsonFile -Path $exitPath } catch { $reason = $null }
            if ($null -eq $reason) {
                Add-Check 'exit-reason.json parses' $false 'parse failure'
            } else {
                $missing = Test-RecordSchema -Record $reason -Fields @(
                    'run_id','exit_code','reason','fatal_class','fatal_msg',
                    'module_name','module_base','rva','stack','stack_truncated',
                    'total_errors','scenario','timestamp')
                Add-Check 'exit-reason: schema fields present' ($missing.Count -eq 0) ("missing=" + ($missing -join ','))
                Add-Check 'exit-reason: run_id matches' ([string]$reason.run_id -eq $expectedRunId) "got=$($reason.run_id)"
                Add-Check 'exit-reason: exit_code == 2' ([int]$reason.exit_code -eq 2) "got=$($reason.exit_code)"
                Add-Check 'exit-reason: scenario matches' ([string]$reason.scenario -eq $ExpectedScenario) "got=$($reason.scenario)"
                Add-Check 'exit-reason: fatal_class non-empty' (-not [string]::IsNullOrEmpty([string]$reason.fatal_class)) "got=$($reason.fatal_class)"
            }
        }
    } else {
        Add-Check 'exit-reason.json absent' (-not (Test-Path -LiteralPath $exitPath -PathType Leaf)) "scenario=$ExpectedScenario"
    }

    $allOk = (@($checks | Where-Object { -not $_.ok }).Count -eq 0)
    return [pscustomobject]@{ ok = $allOk; checks = $checks.ToArray() }
}

# -----------------------------------------------------------------------------
# Step 1: linters
# -----------------------------------------------------------------------------
function Invoke-Step1 {
    [CmdletBinding()]
    param()

    $repo = Get-RepoRoot
    $sd = Join-Path $repo 'scripts\autofix'
    $lints = @(
        @{ name = 'lint-pascal-deps';       path = Join-Path $sd 'lint-pascal-deps.ps1' }
        @{ name = 'lint-powershell-strict'; path = Join-Path $sd 'lint-powershell-strict.ps1' }
        @{ name = 'lint-no-reset-hard';     path = Join-Path $sd 'lint-no-reset-hard.ps1' }
        @{ name = 'lint-doc-version';       path = Join-Path $sd 'lint-doc-version.ps1' }
    )

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($l in $lints) {
        $r = Invoke-Lint -Name $l.name -ScriptPath $l.path
        $results.Add($r) | Out-Null
    }
    return $results.ToArray()
}

# -----------------------------------------------------------------------------
# Step 2: fixture-driven scenario runs
# -----------------------------------------------------------------------------
function Invoke-Step2 {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Exe,
        [Parameter(Mandatory)][string]$WorkDir,
        [int]$StartupTimeout  = 10,
        [int]$ScenarioTimeout = 30
    )

    if (-not (Test-Path -LiteralPath $Exe -PathType Leaf)) {
        return [pscustomobject]@{
            skipped = $true
            reason  = "harness EXE not found: $Exe (run Tests\AutoFix\Fixtures\build.bat)"
            results = @()
        }
    }

    $expectations = @(
        @{ scenario = 'pass';  exit_code = 0; final = 'pass';  exit_reason = $false }
        @{ scenario = 'error'; exit_code = 1; final = 'fail';  exit_reason = $false }
        @{ scenario = 'fatal'; exit_code = 2; final = 'fatal'; exit_reason = $true  }
    )

    if (-not (Test-Path -LiteralPath $WorkDir)) {
        New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
    }

    $results = New-Object System.Collections.Generic.List[object]
    foreach ($e in $expectations) {
        $sub = Join-Path $WorkDir $e.scenario
        $run = Invoke-ScenarioRun -Exe $Exe -Scenario $e.scenario `
            -OutputDir $sub -StartupTimeout $StartupTimeout -ScenarioTimeout $ScenarioTimeout
        $verdict = Test-ScenarioOutputs -Run $run `
            -ExpectedScenario $e.scenario -ExpectedExitCode $e.exit_code `
            -ExpectedFinalStatus $e.final -ExpectExitReason ([bool]$e.exit_reason)
        $results.Add([pscustomobject]@{
            scenario = $e.scenario
            ok       = $verdict.ok
            checks   = $verdict.checks
            run      = $run
        }) | Out-Null
    }
    return [pscustomobject]@{ skipped = $false; reason = ''; results = $results.ToArray() }
}

# -----------------------------------------------------------------------------
# Reporting
# -----------------------------------------------------------------------------
function Write-Section {
    [CmdletBinding()]
    param([string]$Title)
    [Console]::Out.WriteLine("")
    [Console]::Out.WriteLine("== $Title ==")
}

function Write-LintResults {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyCollection()][object[]]$Lints)
    foreach ($l in @($Lints)) {
        $tag = if ($l.status -eq 'pass') { 'OK  ' } else { 'FAIL' }
        [Console]::Out.WriteLine("  [$tag] $($l.name) (exit=$($l.exit_code))")
    }
}

function Write-Step2Results {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Step2)

    if ($Step2.skipped) {
        [Console]::Out.WriteLine("  [SKIP] $($Step2.reason)")
        return
    }
    foreach ($r in @($Step2.results)) {
        $tag = if ($r.ok) { 'OK  ' } else { 'FAIL' }
        [Console]::Out.WriteLine("  [$tag] scenario=$($r.scenario) run_id=$($r.run.run_id)")
        if (-not $r.ok) {
            foreach ($c in @($r.checks)) {
                if (-not $c.ok) {
                    [Console]::Error.WriteLine("        x $($c.name) -- $($c.detail)")
                }
            }
        }
    }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
$startedAt = Get-AutoFixTimestamp

try {
    Write-Section 'Step 1: linters'
    $lints = @(Invoke-Step1)
    Write-LintResults -Lints $lints
    $lintFailed = (@($lints | Where-Object { $_.status -ne 'pass' }).Count -gt 0)

    if ($lintFailed) {
        [Console]::Error.WriteLine('e2e-dry-run: lint step failed; aborting before fixture runs.')
        exit 1
    }

    Write-Section 'Step 2: harness fixture'
    $step2 = Invoke-Step2 -Exe $Harness -WorkDir $WorkDir `
        -StartupTimeout $StartupTimeout -ScenarioTimeout $ScenarioTimeout
    Write-Step2Results -Step2 $step2

    if ($step2.skipped) {
        Write-Section 'Result'
        [Console]::Out.WriteLine("  PASS (lint only; fixture skipped: $($step2.reason))")
        exit 0
    }

    $step2Failed = (@($step2.results | Where-Object { -not $_.ok }).Count -gt 0)
    Write-Section 'Result'
    if ($step2Failed) {
        [Console]::Out.WriteLine('  FAIL (see fixture-run check failures above)')
        exit 1
    }

    $finishedAt = Get-AutoFixTimestamp
    $lintsCount = @($lints).Count
    $sceneCount = @($step2.results).Count
    [Console]::Out.WriteLine("  PASS (lints=$lintsCount scenarios=$sceneCount started=$startedAt finished=$finishedAt)")
    exit 0
}
catch {
    [Console]::Error.WriteLine("e2e-dry-run: unhandled error: $($_.Exception.Message)")
    exit 1
}
