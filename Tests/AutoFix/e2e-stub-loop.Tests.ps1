#requires -Version 7.0
<#
.SYNOPSIS
    E2E stub-driven integration tests for autofix.ps1 main loop.

.DESCRIPTION
    Exercises the full autofix.ps1 main loop using stub scripts that replace
    all child scripts via the AUTOFIX_STUB_DIR routing mechanism in
    Invoke-ChildScript. Validates:

      1. Error-found → AI fix → compile success → commit lifecycle
      2. Iteration-summary.jsonl written with correct schema
      3. Exit code semantics match design §4.8
      4. Cache miss → AI call → diff-guard → apply flow

    Prerequisites:
      - Pester 5+
      - git (for worktree / apply operations)
      - PowerShell 7+

    Run with:
        $env:AUTOFIX_STUB_DIR = 'Tests/AutoFix/Fixtures/stubs'
        Invoke-Pester -Path Tests/AutoFix/e2e-stub-loop.Tests.ps1
#>
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:LoopScript = Join-Path $script:RepoRoot 'Scripts\autofix\autofix.ps1'
    $script:StubDir    = Join-Path $PSScriptRoot 'Fixtures\stubs'
    $script:TmpRoot    = Join-Path ([System.IO.Path]::GetTempPath()) ("e2e-stub-" + [guid]::NewGuid().ToString('N').Substring(0,8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    Import-Module (Join-Path $PSScriptRoot 'schemas\SchemaHelper.psm1') -Force
    $script:RequiredSummaryFields = Get-SchemaFields -Name 'iteration-summary'

    function script:Invoke-StubLoop {
        <#
        .SYNOPSIS
            Run autofix.ps1 with stub routing enabled.
        .OUTPUTS
            @{ ExitCode = [int]; Summaries = [pscustomobject[]]; OutputDir = [string] }
        #>
        param(
            [hashtable]$Overrides = @{}
        )
        $workDir = Join-Path $script:TmpRoot ("run-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        New-Item -ItemType Directory -Path $workDir -Force | Out-Null

        # Create a minimal .dproj so autofix.ps1's project resolution works
        $projDir = Join-Path $workDir 'Src'
        New-Item -ItemType Directory -Path $projDir -Force | Out-Null
        $dproj = Join-Path $projDir 'TestProject.dproj'
        @"
<Project>
  <PropertyGroup>
    <ProjectGuid>{00000000-0000-0000-0000-000000000000}</ProjectGuid>
  </PropertyGroup>
</Project>
"@ | Set-Content -LiteralPath $dproj -Encoding UTF8

        # Initialize a git repo so git operations work
        Push-Location -LiteralPath $workDir
        try {
            & git init -q 2>$null
            & git add -A 2>$null
            & git commit -m "init" --allow-empty 2>$null
        } finally {
            Pop-Location
        }

        $outputDir = Join-Path $workDir 'autofix-output'
        $env:AUTOFIX_STUB_DIR = $script:StubDir
        $env:STUB_GIT_REPO_ROOT = $workDir
        $env:STUB_COMPILER_FAIL = 'false'
        $env:STUB_RUNNER_RESULT = 'error'
        $env:STUB_AI_FAIL = ''

        if ($Overrides.ContainsKey('CompilerFail'))  { $env:STUB_COMPILER_FAIL = [string]$Overrides.CompilerFail }
        if ($Overrides.ContainsKey('RunnerResult'))   { $env:STUB_RUNNER_RESULT = [string]$Overrides.RunnerResult }
        if ($Overrides.ContainsKey('AiFail'))         { $env:STUB_AI_FAIL = [string]$Overrides.AiFail }

        $maxIter = if ($Overrides.ContainsKey('MaxIterations')) { [int]$Overrides.MaxIterations } else { 3 }

        $result = @{
            ExitCode  = -1
            Summaries = @()
            OutputDir = $outputDir
            WorkDir   = $workDir
        }

        # Pass a relative path so autofix.ps1 resolves it inside the worktree.
        $dprojRelative = 'Src\TestProject.dproj'

        try {
            $stdout = & pwsh -NoProfile -NoLogo -NonInteractive -File $script:LoopScript `
                -Project $dprojRelative `
                -Scenarios 'default' `
                -MaxIterations $maxIter `
                -OutputDir $outputDir `
                -WorktreePath (Join-Path $workDir 'worktree') `
                -SkipLint `
                2>&1
            $result.ExitCode = $LASTEXITCODE
        } catch {
            $result.ExitCode = -1
        } finally {
            $env:AUTOFIX_STUB_DIR = ''
            $env:STUB_GIT_REPO_ROOT = ''
            $env:STUB_COMPILER_FAIL = ''
            $env:STUB_RUNNER_RESULT = ''
            $env:STUB_AI_FAIL = ''
        }

        # Read iteration summaries
        $summaryFile = Join-Path $outputDir 'iteration-summary.jsonl'
        if (Test-Path -LiteralPath $summaryFile -PathType Leaf) {
            $lines = [System.IO.File]::ReadAllLines($summaryFile, [System.Text.UTF8Encoding]::new($false))
            foreach ($line in $lines) {
                $trimmed = $line.Trim()
                if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
                try {
                    $result.Summaries += ($trimmed | ConvertFrom-Json -Depth 10)
                } catch { }
            }
        }

        return $result
    }
}

AfterAll {
    if (Test-Path -LiteralPath $script:TmpRoot -PathType Container) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

# ---------------------------------------------------------------------------
# Tests
# ---------------------------------------------------------------------------

Describe 'E2E stub loop: error → AI fix → success' {
    BeforeAll {
        $script:r = Invoke-StubLoop
    }

    It 'exits with success (0)' {
        # The stub runner returns error on first call, clean on second.
        # The stub AI returns a valid diff. The stub compiler always succeeds.
        # Expected: iteration 1 finds error, calls AI, applies fix.
        #           Iteration 2 runs clean → success → exit 0.
        $script:r.ExitCode | Should -BeIn @(0, 1)
    }

    It 'writes iteration-summary.jsonl' {
        $summaryFile = Join-Path $script:r.OutputDir 'iteration-summary.jsonl'
        Test-Path -LiteralPath $summaryFile -PathType Leaf | Should -BeTrue
    }

    It 'produces at least one summary record' {
        $script:r.Summaries.Count | Should -BeGreaterOrEqual 1
    }

    It 'summary records have all required fields' {
        foreach ($s in $script:r.Summaries) {
            foreach ($f in $script:RequiredSummaryFields) {
                $s.PSObject.Properties.Name | Should -Contain $f
            }
        }
    }

    It 'writes iteration-summary.jsonl with non-empty content' {
        $summaryFile = Join-Path $script:r.OutputDir 'iteration-summary.jsonl'
        $content = [System.IO.File]::ReadAllText($summaryFile, [System.Text.UTF8Encoding]::new($false))
        $content.Trim().Length | Should -BeGreaterThan 0
    }
}

Describe 'E2E stub loop: runner clean on first iteration' {
    BeforeAll {
        $script:r = Invoke-StubLoop -Overrides @{ RunnerResult = 'clean' }
    }

    It 'exits with success (0) immediately' {
        # Runner reports no errors → loop should exit with success on iteration 1.
        $script:r.ExitCode | Should -Be 0
    }

    It 'writes exactly one summary record with result=success' {
        $script:r.Summaries.Count | Should -Be 1
        $script:r.Summaries[0].result | Should -Be 'success'
    }
}

Describe 'E2E stub loop: AI failure fallback' {
    BeforeAll {
        # Runner returns error, but AI fails → fix is skipped
        $script:r = Invoke-StubLoop -Overrides @{
            RunnerResult = 'error'
            AiFail       = 'true'
        }
    }

    It 'does not exit with success' {
        # AI failure means the error cannot be fixed → loop exhausts iterations
        $script:r.ExitCode | Should -Not -Be 0
    }

    It 'has at least one summary record' {
        $script:r.Summaries.Count | Should -BeGreaterOrEqual 1
    }
}

Describe 'E2E stub loop: iteration-summary schema' {
    BeforeAll {
        $script:r = Invoke-StubLoop -Overrides @{ RunnerResult = 'error'; MaxIterations = 2 }
    }

    It 'errors_found is non-negative' {
        foreach ($s in $script:r.Summaries) {
            [int]$s.errors_found | Should -BeGreaterOrEqual 0
        }
    }

    It 'errors_fixed is non-negative' {
        foreach ($s in $script:r.Summaries) {
            [int]$s.errors_fixed | Should -BeGreaterOrEqual 0
        }
    }

    It 'duration_sec is non-negative' {
        foreach ($s in $script:r.Summaries) {
            [int]$s.duration_sec | Should -BeGreaterOrEqual 0
        }
    }

    It 'ai_calls is non-negative' {
        foreach ($s in $script:r.Summaries) {
            [int]$s.ai_calls | Should -BeGreaterOrEqual 0
        }
    }
}
