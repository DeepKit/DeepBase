#requires -Version 7.0
# Feature: autofix-runtime-errors, Property 11: diff-guard 边界守卫
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/diff-guard.Tests.ps1
#
# Validates Requirements 8.1, 8.2, 8.3, 8.4, 8.5 — design v2.0 §5.1 Property 11.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts\autofix\diff-guard.ps1'
    $script:CommonPath = Join-Path $script:RepoRoot 'scripts\autofix\_common.ps1'
    if (-not (Test-Path -LiteralPath $script:ScriptPath -PathType Leaf)) {
        throw "diff-guard.ps1 not found at: $script:ScriptPath"
    }

    # Pull in the framework default blocked-glob list (script-private name).
    . $script:CommonPath
    $script:DefaultBlocked = Get-AutoFixDefaultBlockedPaths

    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-dg-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    function script:New-RandomDiff {
        <#
        .SYNOPSIS
            Build a random unified-diff fixture and report the ground truth
            (touched files + total +/- line count).
        #>
        param([int]$Seed)
        $rng = [System.Random]::new($Seed)
        $candidates = @(
            'src/feature.pas', 'src/util.pas', 'lib/helper.pas',
            'Core/DeepBase.AutoFix.ErrorRecorder.pas',  # blocked by default
            'scripts/autofix/foo.ps1',                  # blocked by default
            'docs/notes.md', 'tests/runner.pas',
            'Foo.dproj',                                # blocked by default
            'Bundle.dpk'                                # blocked by default
        )

        $fileCount = $rng.Next(1, 4)
        $picks = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $fileCount; $i++) {
            $picks.Add($candidates[$rng.Next(0, $candidates.Count)]) | Out-Null
        }
        # Deduplicate while preserving order so '+++' counts uniquely.
        $picks = @($picks | Select-Object -Unique)

        $sb = [System.Text.StringBuilder]::new()
        $plus = 0
        $minus = 0
        foreach ($p in $picks) {
            [void]$sb.AppendLine(('diff --git a/{0} b/{0}' -f $p))
            [void]$sb.AppendLine(('--- a/{0}' -f $p))
            [void]$sb.AppendLine(('+++ b/{0}' -f $p))
            [void]$sb.AppendLine('@@ -1,3 +1,3 @@')
            [void]$sb.AppendLine(' context line')
            $delMinus = $rng.Next(0, 4)
            $addPlus  = $rng.Next(0, 4)
            for ($k = 0; $k -lt $delMinus; $k++) {
                [void]$sb.AppendLine(('-removed-{0}' -f $k))
                $minus++
            }
            for ($k = 0; $k -lt $addPlus; $k++) {
                [void]$sb.AppendLine(('+added-{0}' -f $k))
                $plus++
            }
        }

        $path = Join-Path $script:TmpRoot ("rand-{0}.diff" -f $Seed)
        $enc  = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($path, $sb.ToString(), $enc)
        return @{
            Path  = $path
            Files = @($picks)
            Plus  = $plus
            Minus = $minus
        }
    }

    function script:Test-MatchAnyGlob {
        <#
        .SYNOPSIS
            Mirror of _common.ps1::Test-PathGlob behaviour for ground-truth.
        #>
        param([string]$Path, [string[]]$Globs)
        if ([string]::IsNullOrEmpty($Path) -or $null -eq $Globs) { return $false }
        foreach ($g in $Globs) {
            if (-not $g) { continue }
            $re = ConvertTo-RegexFromGlob -Glob $g
            if ([System.Text.RegularExpressions.Regex]::IsMatch($Path, $re, 'IgnoreCase')) {
                return $true
            }
        }
        return $false
    }

    function script:Invoke-DiffGuard {
        param(
            [Parameter(Mandatory)][string]$DiffFile,
            [Parameter(Mandatory)][string]$OutputDir,
            [string]$AllowedPaths = '',
            [string]$BlockedPaths = '',
            [int]$MaxDiffLines = 200
        )
        $args = @('-DiffFile', $DiffFile, '-OutputDir', $OutputDir, '-MaxDiffLines', $MaxDiffLines)
        if ($AllowedPaths) { $args += @('-AllowedPaths', $AllowedPaths) }
        if ($BlockedPaths) { $args += @('-BlockedPaths', $BlockedPaths) }
        $null = & pwsh -NoProfile -NoLogo -NonInteractive -File $script:ScriptPath @args 2>$null
        return $LASTEXITCODE
    }
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'diff-guard.ps1 — boundary enforcement' {

    Context 'Property 11: accept iff allowed ∧ ¬blocked ∧ lines ≤ cap' {

        It 'matches the spec verdict on 100 random diff/config combinations' {
            $iterations = 100
            $rng = [System.Random]::new(2024)
            $allowedSets = @('src/**', 'src/**;lib/**', 'src/**;tests/**;docs/**')

            for ($i = 0; $i -lt $iterations; $i++) {
                $fix = New-RandomDiff -Seed ($i + 1)
                $allowedExpr = $allowedSets[$rng.Next(0, $allowedSets.Count)]
                $maxLines    = $rng.Next(2, 25)
                $outDir      = Join-Path $script:TmpRoot ("run-{0}" -f $i)
                New-Item -ItemType Directory -Path $outDir -Force | Out-Null

                $allowedGlobs = @($allowedExpr -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
                $blockedGlobs = $script:DefaultBlocked

                # Predict verdict
                $hitBlocked = $false
                $hitOutsideAllowed = $false
                foreach ($f in $fix.Files) {
                    $norm = $f.Replace('\', '/').TrimStart('./')
                    if (Test-MatchAnyGlob -Path $norm -Globs $blockedGlobs) {
                        $hitBlocked = $true
                        break
                    }
                    if (-not (Test-MatchAnyGlob -Path $norm -Globs $allowedGlobs)) {
                        $hitOutsideAllowed = $true
                    }
                }
                $totalLines = $fix.Plus + $fix.Minus
                $expectedAccept = ($fix.Files.Count -gt 0) -and `
                                  (-not $hitBlocked) -and `
                                  (-not $hitOutsideAllowed) -and `
                                  ($totalLines -le $maxLines)

                $rc = Invoke-DiffGuard -DiffFile $fix.Path -OutputDir $outDir `
                    -AllowedPaths $allowedExpr -MaxDiffLines $maxLines

                if ($expectedAccept) {
                    $rc | Should -Be 0
                } else {
                    $rc | Should -Not -Be 0
                }

                # Rejection ⇒ a parseable violation row landed in jsonl
                if ($rc -ne 0) {
                    $vlog = Join-Path $outDir 'diff-violations.jsonl'
                    Test-Path -LiteralPath $vlog -PathType Leaf | Should -BeTrue
                    $rows = @(Get-Content -LiteralPath $vlog -Encoding utf8 |
                              Where-Object { $_.Trim() } |
                              ForEach-Object { $_ | ConvertFrom-Json -Depth 8 })
                    $rows.Count | Should -BeGreaterThan 0
                    $rows[0].PSObject.Properties.Name | Should -Contain 'ts'
                    $rows[0].PSObject.Properties.Name | Should -Contain 'reason'
                    $rows[0].PSObject.Properties.Name | Should -Contain 'files'
                    $rows[0].PSObject.Properties.Name | Should -Contain 'lines'
                }
            }
        }
    }
}
