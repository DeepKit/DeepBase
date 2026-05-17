#requires -Version 7.0
# Feature: autofix-runtime-errors, Property 13: 编译错误解析结构化
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/compiler.Tests.ps1
#
# Validates Requirements 10.2 — design v2.0 §5.1 Property 13.
#
# NOTE: compiler.ps1's Parse-CompileLine is a private function defined inside
# the script body, not exported. To exercise the parser without running real
# msbuild we mirror the documented regex (compiler.ps1 line 'pattern = ...').
# A dedicated test asserts that the test's regex matches the one used in the
# script verbatim — if compiler.ps1 ever drifts, this test fails fast.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts\autofix\compiler.ps1'
    if (-not (Test-Path -LiteralPath $script:ScriptPath -PathType Leaf)) {
        throw "compiler.ps1 not found at: $script:ScriptPath"
    }

    # Authoritative regex — must match the one in compiler.ps1.
    $script:CompileLineRegex = '^(.+?)\((\d+),(\d+)\)\s+(Error|Fatal|Warning|Hint)\s+([EFWH]\d+):\s+(.+?)\s*$'

    function script:Parse-OneLine {
        <#
        .SYNOPSIS
            Mirror of compiler.ps1's Parse-CompileLine. Returns $null on no match.
        #>
        param([string]$Line)
        if ([string]::IsNullOrWhiteSpace($Line)) { return $null }
        $m = [regex]::Match($Line, $script:CompileLineRegex)
        if (-not $m.Success) { return $null }
        return [pscustomobject]@{
            severity = $m.Groups[4].Value
            file     = $m.Groups[1].Value.Trim()
            line     = [int]$m.Groups[2].Value
            column   = [int]$m.Groups[3].Value
            code     = $m.Groups[5].Value
            message  = $m.Groups[6].Value.Trim()
        }
    }

    function script:New-RandomCompileLine {
        param([int]$Seed, [bool]$Legal)
        $rng = [System.Random]::new($Seed)
        if ($Legal) {
            $files     = @('Core/Foo.pas', 'src/Bar.pas', 'Tests/Baz.pas', 'Win64\Debug\Quux.pas')
            $severs    = @('Error', 'Fatal', 'Warning', 'Hint')
            $codeChars = @('E', 'F', 'W', 'H')
            $messages  = @('Undeclared identifier', 'Type mismatch', 'Missing semicolon', 'Constant expected')

            $sev = $severs[$rng.Next(0, $severs.Count)]
            $cc  = $codeChars[$rng.Next(0, $codeChars.Count)]
            $code = ('{0}{1}' -f $cc, $rng.Next(2000, 9999))
            $msg  = $messages[$rng.Next(0, $messages.Count)] + ': ' + 'sym' + $rng.Next(1, 9999)
            $file = $files[$rng.Next(0, $files.Count)]
            $ln   = $rng.Next(1, 5000)
            $col  = $rng.Next(1, 200)
            $line = ('{0}({1},{2}) {3} {4}: {5}' -f $file, $ln, $col, $sev, $code, $msg)
            return @{
                Legal     = $true
                Line      = $line
                File      = $file
                LineNo    = $ln
                ColNo     = $col
                Severity  = $sev
                Code      = $code
                Message   = $msg
            }
        }
        # Noise: deliberately not a valid Delphi compile message
        $patterns = @(
            ('Microsoft (R) Build Engine version {0}'                                 -f $rng.Next(1, 99)),
            ('Build started {0:00}/{1:00}/2025'                                       -f $rng.Next(1, 12), $rng.Next(1, 28)),
            'Project "DeepBaseTests.dproj" on node 1 (Build target(s)).',
            ('plain log line {0} no error here'                                       -f $rng.Next(0, 9999)),
            ('warning: this looks like a warning but lacks the code form'),
            ('FOO.pas(42) Error E2003 missing column field'),
            ('  spaces leading line {0}' -f $rng.Next(0, 9999)),
            ''
        )
        $line = $patterns[$rng.Next(0, $patterns.Count)]
        return @{
            Legal = $false
            Line  = $line
        }
    }
}

Describe 'compiler.ps1 — compile-error parsing regex' {

    Context 'parser regex equivalence to compiler.ps1' {
        It 'mirrors the regex literal in scripts/autofix/compiler.ps1' {
            $src = [System.IO.File]::ReadAllText($script:ScriptPath, [System.Text.UTF8Encoding]::new($false))
            # Parse pattern declaration: $pattern = '<expr>'
            $rx = [regex]::Match($src, "(?s)\`$pattern\s*=\s*'(?<lit>.+?)'")
            $rx.Success | Should -BeTrue
            $rx.Groups['lit'].Value | Should -Be $script:CompileLineRegex
        }
    }

    Context 'Property 13: per-line extraction across 100 random fixtures' {
        It 'extracts only legal lines and preserves field types/order' {
            $iterations = 100
            $rng = [System.Random]::new(31337)
            for ($i = 0; $i -lt $iterations; $i++) {
                $legal = ($rng.Next(0, 2) -eq 1)
                $f = New-RandomCompileLine -Seed ($i + 7) -Legal $legal
                $rec = Parse-OneLine -Line $f.Line
                if ($f.Legal) {
                    $rec | Should -Not -BeNullOrEmpty
                    $rec.file     | Should -Be $f.File
                    [int]$rec.line   | Should -Be $f.LineNo
                    [int]$rec.column | Should -Be $f.ColNo
                    $rec.severity | Should -Be $f.Severity
                    $rec.code     | Should -Be $f.Code
                    [string]::IsNullOrWhiteSpace($rec.message) | Should -BeFalse
                    $rec.code | Should -Match '^[EFWH]\d+$'
                    [int]$rec.line   | Should -BeGreaterThan 0
                    [int]$rec.column | Should -BeGreaterThan 0
                } else {
                    $rec | Should -BeNullOrEmpty
                }
            }
        }

        It 'returns N records for N legal input lines (mass extraction)' {
            $iterations = 100
            $batch = New-Object System.Collections.Generic.List[hashtable]
            for ($i = 0; $i -lt $iterations; $i++) {
                $batch.Add((New-RandomCompileLine -Seed (1000 + $i) -Legal $true)) | Out-Null
            }
            $noise = @(
                'Microsoft (R) Build Engine version 17.0',
                'Build succeeded.',
                ''
            )
            $allLines = @($batch | ForEach-Object { $_.Line }) + $noise
            $parsed = New-Object System.Collections.Generic.List[object]
            foreach ($l in $allLines) {
                $rec = Parse-OneLine -Line $l
                if ($rec) { $parsed.Add($rec) | Out-Null }
            }
            $parsed.Count | Should -Be $batch.Count
        }
    }
}
