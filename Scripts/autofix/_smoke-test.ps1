#requires -Version 7.0
<#
.SYNOPSIS
    Phase 2 smoke test — verifies each script reports parameter errors with
    the documented exit codes and that happy-path actions on stub inputs
    succeed.
#>
[CmdletBinding()]
param()

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$here = $PSScriptRoot
$tmp  = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-smoke-" + [guid]::NewGuid().ToString('N').Substring(0,8))
New-Item -ItemType Directory -Path $tmp -Force | Out-Null

$results = New-Object System.Collections.Generic.List[object]
function Add-Result {
    param([string]$Name, [int]$Expected, [int]$Actual, [string]$Note = '')
    $ok = ($Expected -eq $Actual)
    $script:results.Add([pscustomobject]@{
        Name = $Name; Expected = $Expected; Actual = $Actual; Pass = $ok; Note = $Note
    }) | Out-Null
}

function Run-Script {
    param([string]$Script, [string[]]$ChildArgs)
    # NOTE: do not name the array parameter $Args — that name shadows the
    # automatic $Args variable and makes splatting (@Args) behave inconsistently
    # depending on context.
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $null = & pwsh -NoProfile -NoLogo -NonInteractive -File (Join-Path $here $Script) @ChildArgs 2>&1
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $oldPref
    }
}

try {
    # ---- map-parser: missing required arg should fail ----
    # (PowerShell's mandatory-param prompt is non-interactive when run via -File,
    #  so missing -MapFile yields a non-zero exit.)
    $rc = Run-Script 'map-parser.ps1' @()
    Add-Result -Name 'map-parser missing args'   -Expected 1 -Actual ([Math]::Sign($rc)) -Note "raw=$rc"

    # ---- dedup: same ----
    $rc = Run-Script 'dedup.ps1' @()
    Add-Result -Name 'dedup missing args'        -Expected 1 -Actual ([Math]::Sign($rc)) -Note "raw=$rc"

    # ---- compiler: bad project file → BadParams 100 ----
    $rc = Run-Script 'compiler.ps1' @('-Project', (Join-Path $tmp 'nonexistent.dproj'),
                                      '-OutputJson', (Join-Path $tmp 'compile-errors.json'),
                                      '-LogFile',    (Join-Path $tmp 'compile.log'))
    Add-Result -Name 'compiler bad project'      -Expected 100 -Actual $rc

    # ---- git-checkpoint: missing -Action → mandatory prompt failure (rc=1) ----
    $rc = Run-Script 'git-checkpoint.ps1' @()
    Add-Result -Name 'git-checkpoint no action'  -Expected 1 -Actual ([Math]::Sign($rc)) -Note "raw=$rc"

    # ---- git-checkpoint: action=create without -Branch → 100 ----
    $rc = Run-Script 'git-checkpoint.ps1' @('-Action', 'create')
    Add-Result -Name 'git-checkpoint create no branch' -Expected 100 -Actual $rc

    # ---- diff-guard: nonexistent diff → 100 ----
    $rc = Run-Script 'diff-guard.ps1' @('-DiffFile', (Join-Path $tmp 'nope.diff'),
                                        '-OutputDir', $tmp)
    Add-Result -Name 'diff-guard missing diff'   -Expected 100 -Actual $rc

    # ---- diff-guard: empty diff → rejected (1, no_files_touched) ----
    $emptyDiff = Join-Path $tmp 'empty.diff'
    Set-Content -LiteralPath $emptyDiff -Value '' -Encoding utf8
    $rc = Run-Script 'diff-guard.ps1' @('-DiffFile', $emptyDiff, '-OutputDir', $tmp)
    Add-Result -Name 'diff-guard empty diff'     -Expected 1 -Actual $rc

    # ---- diff-guard: blocked path → 1 ----
    $blockedDiff = Join-Path $tmp 'blocked.diff'
    @"
diff --git a/Core/DeepBase.AutoFix.ErrorRecorder.pas b/Core/DeepBase.AutoFix.ErrorRecorder.pas
--- a/Core/DeepBase.AutoFix.ErrorRecorder.pas
+++ b/Core/DeepBase.AutoFix.ErrorRecorder.pas
@@ -1,1 +1,2 @@
 unit DeepBase.AutoFix.ErrorRecorder;
+// noop
"@ | Set-Content -LiteralPath $blockedDiff -Encoding utf8
    $rc = Run-Script 'diff-guard.ps1' @('-DiffFile', $blockedDiff,
                                        '-AllowedPaths', 'Core/**',
                                        '-OutputDir', $tmp)
    Add-Result -Name 'diff-guard blocked path'   -Expected 1 -Actual $rc

    # ---- diff-guard: allowed path under user-supplied src/ → 0 ----
    $okDiff = Join-Path $tmp 'ok.diff'
    @"
diff --git a/src/sample.pas b/src/sample.pas
--- a/src/sample.pas
+++ b/src/sample.pas
@@ -1,2 +1,3 @@
 unit sample;
 begin
+  // fix
"@ | Set-Content -LiteralPath $okDiff -Encoding utf8
    $rc = Run-Script 'diff-guard.ps1' @('-DiffFile', $okDiff,
                                        '-AllowedPaths', 'src/**',
                                        '-OutputDir', $tmp,
                                        '-MaxDiffLines', '50')
    Add-Result -Name 'diff-guard allowed path'   -Expected 0 -Actual $rc

    # ---- fix-cache: bad action → mandatory parameter rejection (rc=1) ----
    $rc = Run-Script 'fix-cache.ps1' @()
    Add-Result -Name 'fix-cache no action'       -Expected 1 -Actual ([Math]::Sign($rc)) -Note "raw=$rc"

    # ---- fix-cache: lookup with no key → 100 ----
    $rc = Run-Script 'fix-cache.ps1' @('-Action', 'lookup', '-OutputDir', $tmp)
    Add-Result -Name 'fix-cache lookup no key'   -Expected 100 -Actual $rc

    # ---- fix-cache: lookup with no entry → 0 (miss) ----
    $rc = Run-Script 'fix-cache.ps1' @('-Action', 'lookup', '-Key', 'unknown-key', '-OutputDir', $tmp)
    Add-Result -Name 'fix-cache lookup miss'     -Expected 0 -Actual $rc

    # ---- fix-cache: clear → 0 ----
    $rc = Run-Script 'fix-cache.ps1' @('-Action', 'clear', '-OutputDir', $tmp)
    Add-Result -Name 'fix-cache clear'           -Expected 0 -Actual $rc

    # ---- fix-cache: prune (empty cache) → 0 ----
    $rc = Run-Script 'fix-cache.ps1' @('-Action', 'prune', '-OutputDir', $tmp)
    Add-Result -Name 'fix-cache prune empty'     -Expected 0 -Actual $rc

    # ---- wer-collector: missing required → mandatory prompt failure (rc=1) ----
    $rc = Run-Script 'wer-collector.ps1' @()
    Add-Result -Name 'wer-collector no args'     -Expected 1 -Actual ([Math]::Sign($rc)) -Note "raw=$rc"

    # ---- wer-collector: synthetic HardCrash record (no real dump) → 0 ----
    $werDir = Join-Path $tmp 'werout'
    New-Item -ItemType Directory -Path $werDir -Force | Out-Null
    $emptyDumps = Join-Path $tmp 'no-dumps'
    New-Item -ItemType Directory -Path $emptyDumps -Force | Out-Null
    $rc = Run-Script 'wer-collector.ps1' @(
        '-ExeName', 'AutoFixHarness',
        '-ProcessId', '12345',
        '-ExitCode', '-1073741819',
        '-RunId', '11111111-1111-4111-8111-111111111111',
        '-OutputDir', $werDir,
        '-DumpsDir', $emptyDumps
    )
    Add-Result -Name 'wer-collector synthetic'   -Expected 0 -Actual $rc
    $jsonlPath = Join-Path $werDir 'runtime-errors.jsonl'
    $jsonlOk = (Test-Path -LiteralPath $jsonlPath -PathType Leaf)
    Add-Result -Name 'wer-collector wrote jsonl' -Expected 1 -Actual ([int]$jsonlOk)
}
finally {
    # Print results
    "`n=== Smoke Results ==="
    $script:results | ConvertTo-Json -Depth 3 | Write-Host
    Remove-Item -LiteralPath $tmp -Recurse -Force -ErrorAction SilentlyContinue
}

$failures = @($script:results | Where-Object { -not $_.Pass })
if ($failures.Count -gt 0) {
    Write-Host ("FAIL: $($failures.Count) check(s)")
    exit 1
}
Write-Host 'PASS: all smoke checks ok'
exit 0
