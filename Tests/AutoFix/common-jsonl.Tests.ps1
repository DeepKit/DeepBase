#requires -Version 7.0

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    . (Join-Path $script:RepoRoot 'Scripts\autofix\_common.ps1')
    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) (
        'autofix-common-' + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null
}

AfterAll {
    if (Test-Path -LiteralPath $script:TmpRoot) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force
    }
}

Describe 'AutoFix common JSONL and check semantics' {
    It 'treats a BOM-only runtime-errors.jsonl as zero records' {
        $path = Join-Path $script:TmpRoot 'runtime-errors.jsonl'
        [System.IO.File]::WriteAllBytes(
            $path,
            [System.Text.UTF8Encoding]::new($true).GetPreamble())
        @(Read-Jsonl -Path $path).Count | Should -Be 0
    }

    It 'fails check when a scenario failed even if the process exited zero' {
        (Get-AutoFixCheckExitCode `
            -RunnerExitCode 0 `
            -ScenarioFailureCount 1 `
            -RuntimeErrorCount 0) | Should -Be $AutoFixExit_Generic
    }

    It 'passes only when runner, scenarios and runtime errors are clean' {
        (Get-AutoFixCheckExitCode `
            -RunnerExitCode 0 `
            -ScenarioFailureCount 0 `
            -RuntimeErrorCount 0) | Should -Be $AutoFixExit_Ok
    }
}
