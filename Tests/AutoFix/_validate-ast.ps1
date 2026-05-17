#requires -Version 7.0
# Internal tool: validate that every Tests.ps1 file under Tests/AutoFix parses
# cleanly via the PowerShell AST. Used by the spec task verification step in
# place of actually invoking Pester (Pester 5 may not be installed).
#
# Exit codes: 0 = all parse, 1 = at least one parse error.
[CmdletBinding()]
param(
    [string]$Dir = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '.')).Path
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$files = @(Get-ChildItem -LiteralPath $Dir -Filter '*.Tests.ps1' -File -ErrorAction SilentlyContinue)
$failed = 0
foreach ($f in $files) {
    $tokens = $null
    $errs = $null
    [System.Management.Automation.Language.Parser]::ParseFile($f.FullName, [ref]$tokens, [ref]$errs) | Out-Null
    if ($errs -and $errs.Count -gt 0) {
        Write-Host ("FAIL: {0}" -f $f.Name) -ForegroundColor Red
        foreach ($e in $errs) {
            Write-Host ("  line {0}: {1}" -f $e.Extent.StartLineNumber, $e.Message) -ForegroundColor Red
        }
        $failed++
    } else {
        Write-Host ("OK  : {0}" -f $f.Name) -ForegroundColor Green
    }
}
if ($failed -gt 0) { exit 1 }
exit 0
