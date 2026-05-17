#requires -Version 7.0
<#
.SYNOPSIS
    Quick AST parse check for one or more PowerShell scripts.
    Used internally by Phase 2 acceptance gate.
.EXAMPLE
    pwsh -NoProfile -File scripts/autofix/_check-parse.ps1 scripts/autofix/_common.ps1
#>
param(
    [Parameter(Mandatory, ValueFromRemainingArguments)]
    [string[]]$Paths
)

$rc = 0
foreach ($p in $Paths) {
    $tokens = $null
    $errors = $null
    if (-not (Test-Path -LiteralPath $p)) {
        Write-Host ("MISSING: " + $p)
        $rc = 1
        continue
    }
    [void][System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errors)
    if ($errors -and $errors.Count -gt 0) {
        Write-Host ("FAIL   : " + $p)
        foreach ($e in $errors) {
            Write-Host ("  - " + $e.Message + "  @ " + $e.Extent.StartLineNumber + ":" + $e.Extent.StartColumnNumber)
        }
        $rc = 1
    } else {
        Write-Host ("OK     : " + $p)
    }
}
exit $rc
