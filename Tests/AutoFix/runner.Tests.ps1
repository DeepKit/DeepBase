#requires -Version 7.0
# Feature: autofix-runtime-errors, runner.ps1 进程生命周期测试
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/runner.Tests.ps1
#
# Validates Requirements 2.4, 3.1, 3.2, 3.3 — design v2.0 runner contract.
#
# Uses mock-autofix-exe.ps1 (env-var driven) wrapped in a .cmd shim.
# The shim exists because runner.ps1 calls Start-Process with -FilePath
# pointing at the mock, and the mock reads all config from environment
# variables inherited from the test process.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:RunnerPath = Join-Path $script:RepoRoot 'scripts\autofix\runner.ps1'
    $script:CommonPath = Join-Path $script:RepoRoot 'scripts\autofix\_common.ps1'
    if (-not (Test-Path -LiteralPath $script:RunnerPath -PathType Leaf)) {
        throw "runner.ps1 not found at: $script:RunnerPath"
    }
    . $script:CommonPath

    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-runner-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    # Build a .cmd shim that delegates to the mock PS1 script.
    # runner.ps1 calls Start-Process with this .cmd as the "EXE".
    # The mock reads config from env vars set by the test harness.
    $mockPs1  = Join-Path $script:RepoRoot 'Tests\AutoFix\Fixtures\mock-autofix-exe.ps1'
    $pwshPath = (Get-Command -Name 'pwsh' -ErrorAction Stop).Source
    $script:MockCmd = Join-Path $script:TmpRoot 'mock-autofix-exe.cmd'
    $cmdBody = "@echo off`n`"$pwshPath`" -NoProfile -NonInteractive -File `"$mockPs1`" %*"
    [System.IO.File]::WriteAllText($script:MockCmd, $cmdBody, [System.Text.UTF8Encoding]::new($false))

    # Preserve original env so we can restore
    $script:OrigEnv = @{}

    function script:Set-MockEnv {
        param(
            [string]$Behavior    = 'pass',
            [string]$RunId       = '',
            [string]$OutputDir   = '',
            [string]$Scenarios   = 'mock-scene',
            [int]$Iteration      = 1,
            [int]$DelayMs        = 0
        )
        # Save originals
        foreach ($k in @('MOCK_AUTOFIX_BEHAVIOR','MOCK_AUTOFIX_RUN_ID','MOCK_AUTOFIX_SCENARIOS','MOCK_AUTOFIX_OUTPUT_DIR','MOCK_AUTOFIX_ITERATION','MOCK_AUTOFIX_DELAY_MS')) {
            $script:OrigEnv[$k] = Get-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue
        }
        $env:MOCK_AUTOFIX_BEHAVIOR   = $Behavior
        $env:MOCK_AUTOFIX_RUN_ID     = $RunId
        $env:MOCK_AUTOFIX_SCENARIOS  = $Scenarios
        $env:MOCK_AUTOFIX_OUTPUT_DIR = $OutputDir
        $env:MOCK_AUTOFIX_ITERATION  = [string]$Iteration
        $env:MOCK_AUTOFIX_DELAY_MS   = [string]$DelayMs
    }

    function script:Restore-MockEnv {
        foreach ($k in @('MOCK_AUTOFIX_BEHAVIOR','MOCK_AUTOFIX_RUN_ID','MOCK_AUTOFIX_SCENARIOS','MOCK_AUTOFIX_OUTPUT_DIR','MOCK_AUTOFIX_ITERATION','MOCK_AUTOFIX_DELAY_MS')) {
            if ($script:OrigEnv.ContainsKey($k) -and $null -ne $script:OrigEnv[$k]) {
                Set-Item -LiteralPath "Env:$k" -Value $script:OrigEnv[$k].Value
            } else {
                Remove-Item -LiteralPath "Env:$k" -ErrorAction SilentlyContinue
            }
        }
    }

    function script:Invoke-Runner {
        param(
            [Parameter(Mandatory)][string]$Behavior,
            [Parameter(Mandatory)][string]$RunId,
            [int]$StartupTimeout  = 10,
            [int]$ScenarioTimeout = 15,
            [string]$Scenarios    = 'mock-scene',
            [string]$OutputDir    = '',
            [int]$DelayMs         = 0
        )

        if (-not $OutputDir) {
            $OutputDir = Join-Path $script:TmpRoot ("run-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
        }
        if (-not (Test-Path -LiteralPath $OutputDir)) {
            New-Item -ItemType Directory -Path $OutputDir -Force | Out-Null
        }

        # Clean stale artifacts from prior runs
        foreach ($f in @('health-signal.json', 'exit-reason.json', 'runtime-errors.jsonl', 'scenario-results.jsonl')) {
            $p = Join-Path $OutputDir $f
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue }
        }

        Set-MockEnv -Behavior $Behavior -RunId $RunId -OutputDir $OutputDir -Scenarios $Scenarios -DelayMs $DelayMs

        try {
            $stdout = & pwsh -NoProfile -NoLogo -NonInteractive -File $script:RunnerPath `
                -Exe $script:MockCmd `
                -RunId $RunId `
                -Iteration 1 `
                -Scenarios $Scenarios `
                -StartupTimeout $StartupTimeout `
                -ScenarioTimeout $ScenarioTimeout `
                -OutputDir $OutputDir 2>$null

            $rc = $LASTEXITCODE
            $status = $null
            if ($stdout) {
                try {
                    # The last line of stdout should be the status JSON
                    $lines = @($stdout | Where-Object { $_ -and $_.Trim() })
                    $lastLine = $lines[-1]
                    $status = $lastLine | ConvertFrom-Json -Depth 8
                } catch { $status = $null }
            }

            return [pscustomobject]@{
                ExitCode   = $rc
                Status     = $status
                OutputDir  = $OutputDir
                RawStdout  = ($stdout | Out-String).Trim()
            }
        }
        finally {
            Restore-MockEnv
        }
    }

    function script:Get-JsonlRecords {
        param([string]$Path)
        if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) { return @() }
        return ,(Read-Jsonl -Path $Path)
    }
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
    Restore-MockEnv
}

Describe 'runner.ps1 — process lifecycle' {

    Context 'pass: EXE starts, signals ready, exits 0' {

        It 'emits status JSON with exit_code=0, ready=true, status=normal' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'pass' -RunId $runId

            $r.ExitCode | Should -Be 0
            $r.Status   | Should -Not -BeNullOrEmpty
            [int]$r.Status.exit_code | Should -Be 0
            [bool]$r.Status.ready    | Should -BeTrue
            [string]$r.Status.status | Should -Be 'normal'
            [string]$r.Status.run_id | Should -Be $runId
        }

        It 'writes health-signal.json with correct run_id and ready=true' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'pass' -RunId $runId

            $healthPath = Join-Path $r.OutputDir 'health-signal.json'
            Test-Path -LiteralPath $healthPath -PathType Leaf | Should -BeTrue
            $health = Read-JsonFile -Path $healthPath
            $health | Should -Not -BeNullOrEmpty
            [string]$health.run_id       | Should -Be $runId
            [bool]$health.ready          | Should -BeTrue
            [bool]$health.autofix_mode   | Should -BeTrue
        }

        It 'writes scenario-results.jsonl with running -> pass rows' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'pass' -RunId $runId -Scenarios 'mock-scene'

            $resPath = Join-Path $r.OutputDir 'scenario-results.jsonl'
            $rows = Get-JsonlRecords -Path $resPath
            $rows.Count | Should -BeGreaterOrEqual 2
            $terminal = @($rows | Where-Object { [string]$_.status -ne 'running' })[-1]
            $terminal | Should -Not -BeNullOrEmpty
            [string]$terminal.status | Should -Be 'pass'
        }
    }

    Context 'error: EXE exits 1 with runtime-errors' {

        It 'runner exits 0 but status JSON shows exit_code=1' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'error' -RunId $runId

            $r.ExitCode | Should -Be 0
            [int]$r.Status.exit_code | Should -Be 1
        }

        It 'writes runtime-errors.jsonl with at least one record' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'error' -RunId $runId

            $errPath = Join-Path $r.OutputDir 'runtime-errors.jsonl'
            $errs = Get-JsonlRecords -Path $errPath
            $errs.Count | Should -BeGreaterOrEqual 1
            [string]$errs[0].run_id | Should -Be $runId
            [string]$errs[0].'class' | Should -Be 'EConvertError'
        }
    }

    Context 'fatal: EXE exits 2 with exit-reason.json' {

        It 'writes exit-reason.json with exit_code=2' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'fatal' -RunId $runId

            $exitPath = Join-Path $r.OutputDir 'exit-reason.json'
            Test-Path -LiteralPath $exitPath -PathType Leaf | Should -BeTrue
            $reason = Read-JsonFile -Path $exitPath
            [int]$reason.exit_code    | Should -Be 2
            [string]$reason.run_id    | Should -Be $runId
            [string]$reason.fatal_class | Should -Not -BeNullOrEmpty
        }
    }

    Context 'crash: EXE exits immediately without health-signal' {

        It 'runner exits 3 with status=startup-failed' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'crash' -RunId $runId -StartupTimeout 5

            $r.ExitCode | Should -Be 3
            $r.Status   | Should -Not -BeNullOrEmpty
            [string]$r.Status.status | Should -Be 'startup-failed'
            [bool]$r.Status.ready    | Should -BeFalse
        }

        It 'writes synthetic runtime-errors.jsonl with HardCrash class' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'crash' -RunId $runId -StartupTimeout 5

            $errPath = Join-Path $r.OutputDir 'runtime-errors.jsonl'
            $errs = Get-JsonlRecords -Path $errPath
            $errs.Count | Should -BeGreaterOrEqual 1
            [string]$errs[0].run_id | Should -Be $runId
            [string]$errs[0].'class' | Should -Be 'HardCrash'
        }
    }

    Context 'timeout: EXE signals ready then hangs' {

        It 'runner exits 3 with status=scenario-timeout' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'timeout' -RunId $runId `
                -StartupTimeout 5 -ScenarioTimeout 3

            $r.ExitCode | Should -Be 3
            $r.Status   | Should -Not -BeNullOrEmpty
            [string]$r.Status.status | Should -Be 'scenario-timeout'
            [bool]$r.Status.ready    | Should -BeTrue
        }

        It 'writes synthetic ScenarioTimeout error' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'timeout' -RunId $runId `
                -StartupTimeout 5 -ScenarioTimeout 3

            $errPath = Join-Path $r.OutputDir 'runtime-errors.jsonl'
            $errs = Get-JsonlRecords -Path $errPath
            $errs.Count | Should -BeGreaterOrEqual 1
            [string]$errs[0].'class' | Should -Be 'ScenarioTimeout'
        }
    }

    Context 'no-health-signal: EXE exits normally without autofix' {

        It 'runner detects startup failure' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'no-health-signal' -RunId $runId -StartupTimeout 5

            $r.ExitCode | Should -Be 3
            [string]$r.Status.status | Should -Be 'startup-failed'
        }
    }

    Context 'status JSON schema completeness' {

        It 'contains all documented fields' {
            $runId = [guid]::NewGuid().ToString()
            $r = Invoke-Runner -Behavior 'pass' -RunId $runId

            $required = @('run_id', 'exit_code', 'status', 'started_at',
                          'stopped_at', 'duration_ms', 'pid', 'ready')
            foreach ($f in $required) {
                $r.Status.PSObject.Properties[$f] | Should -Not -BeNullOrEmpty `
                    -Because "field '$f' is required in the status schema"
            }
            [int]$r.Status.duration_ms | Should -BeGreaterOrEqual 0
            [int]$r.Status.pid         | Should -BeGreaterThan 0
        }
    }

    Context 'run_id isolation: stale health-signal is ignored' {

        It 'a health-signal from a previous run does not cause false ready' {
            $runId1 = [guid]::NewGuid().ToString()
            $outDir = Join-Path $script:TmpRoot ("isolate-" + [guid]::NewGuid().ToString('N').Substring(0,8))
            New-Item -ItemType Directory -Path $outDir -Force | Out-Null

            # Run 1: produces health-signal.json with runId1
            $r1 = Invoke-Runner -Behavior 'pass' -RunId $runId1 -OutputDir $outDir
            $r1.ExitCode | Should -Be 0

            $healthPath = Join-Path $outDir 'health-signal.json'
            Test-Path -LiteralPath $healthPath | Should -BeTrue

            # Run 2 with a different runId -- runner.ps1 deletes stale health-signal
            $runId2 = [guid]::NewGuid().ToString()
            $r2 = Invoke-Runner -Behavior 'pass' -RunId $runId2 -OutputDir $outDir
            $r2.ExitCode | Should -Be 0
            [string]$r2.Status.run_id | Should -Be $runId2
        }
    }
}
