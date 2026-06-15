#requires -Version 7.0
<#
.SYNOPSIS
    Stub map-parser.ps1 for E2E integration tests.

.DESCRIPTION
    Autofix.ps1 passes -Frames as a JSON string (not a file path).
    This stub parses it and returns resolved stack frames on stdout.
#>
param(
    [string]$MapFile = '',
    [string]$Frames = ''
)

$resolved = @()
if (-not [string]::IsNullOrWhiteSpace($Frames)) {
    try {
        $frameData = $Frames | ConvertFrom-Json -Depth 10
        foreach ($f in @($frameData)) {
            $resolved += [pscustomobject]@{
                rva      = if ($f.PSObject.Properties['rva'])         { [string]$f.rva }         else { '0x00011000' }
                module   = if ($f.PSObject.Properties['module_name']) { [string]$f.module_name } else { 'StubModule' }
                function = 'StubProc'
                source   = 'StubModule.pas'
                line     = 42
            }
        }
    } catch { }
}

if ($resolved.Count -eq 0) {
    $resolved = @([pscustomobject]@{
        rva      = '0x00011000'
        module   = 'StubModule'
        function = 'StubProc'
        source   = 'StubModule.pas'
        line     = 42
    })
}

Write-Output ($resolved | ConvertTo-Json -Depth 10 -Compress)
exit 0
