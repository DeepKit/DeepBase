#requires -Version 7.0
<#
.SYNOPSIS
    Stub dedup.ps1 for E2E integration tests.

.DESCRIPTION
    Reads runtime-errors.jsonl, groups by dedup_key, prints JSON array on stdout.
    Mirrors the real dedup.ps1 parameter names (-ErrorsFile, -RunIdFilter)
    and output schema (groups with 'representative' field).
#>
param(
    [Parameter(Mandatory)][string]$ErrorsFile,
    [Parameter(Mandatory)][string]$RunIdFilter
)

$groups = @()
if (Test-Path -LiteralPath $ErrorsFile -PathType Leaf) {
    $lines = [System.IO.File]::ReadAllLines($ErrorsFile, [System.Text.UTF8Encoding]::new($false))
    foreach ($line in $lines) {
        $trimmed = $line.Trim()
        if ([string]::IsNullOrWhiteSpace($trimmed)) { continue }
        try {
            $obj = $trimmed | ConvertFrom-Json -Depth 10
            if ($RunIdFilter -and [string]$obj.run_id -ne $RunIdFilter) { continue }
            $groups += [pscustomobject]@{
                dedup_key       = [string]$obj.dedup_key
                error_class     = [string]$obj.error_class
                message         = [string]$obj.message
                module          = [string]$obj.module
                rva             = [string]$obj.rva
                scenario        = [string]$obj.scenario
                count           = 1
                representative  = $obj
            }
        } catch { }
    }
}

$json = if ($groups.Count -gt 0) { ($groups | ConvertTo-Json -Depth 10) } else { '[]' }
Write-Output $json
exit 0
