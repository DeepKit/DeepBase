<#
.SYNOPSIS
    Group runtime errors by dedup_key and emit sorted unique groups.

.DESCRIPTION
    Reads a list of runtime-error records (jsonl file or inline JSON array) and
    groups them by dedup_key. The dedup_key follows design §3.8.8:

        error_class + '|' + msg.Substring(0, 80) + '|' + top_stack_rva + '|' + scenario

    If a record already carries a dedup_key field, that value is used verbatim;
    otherwise it is computed.

    Each output group contains: dedup_key, level, count, first_ts, last_ts,
    stack_depth, representative.

    Sort order: level priority (fatal=0, error=1, warning=2) ascending,
    then stack_depth ascending, then count descending.

.PARAMETER ErrorsFile
    Path to a runtime-errors.jsonl file. Mutually exclusive with -Errors.

.PARAMETER Errors
    Inline JSON array of error records. Mutually exclusive with -ErrorsFile.

.PARAMETER OutputJson
    Optional path to write the output array to. When omitted, prints to stdout.

.PARAMETER RunIdFilter
    Optional run_id filter. When provided, only records with run_id == filter
    are kept.

.OUTPUTS
    JSON array of group objects.

.EXAMPLE
    pwsh -File dedup.ps1 -ErrorsFile autofix-output/runtime-errors.jsonl

.NOTES
    Validates Requirements 5.1, 5.2, 5.3.
#>
[CmdletBinding(DefaultParameterSetName = 'File')]
param(
    [Parameter(Mandatory, ParameterSetName = 'File')]
    [string]$ErrorsFile,

    [Parameter(Mandatory, ParameterSetName = 'Inline')]
    [string]$Errors,

    [string]$OutputJson,

    [string]$RunIdFilter
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Get-LevelPriority {
    [CmdletBinding()]
    param([string]$Level)
    $lvl = if ($Level) { $Level.ToLowerInvariant() } else { '' }
    switch ($lvl) {
        'fatal'   { return 0 }
        'error'   { return 1 }
        'warning' { return 2 }
        default   { return 3 }
    }
}

function Get-TopStackRva {
    [CmdletBinding()]
    param($Record)
    if ($Record.PSObject.Properties['stack']) {
        $stack = $Record.stack
        if ($null -ne $stack) {
            $arr = @($stack)
            if ($arr.Count -gt 0) {
                $top = $arr[0]
                if ($null -ne $top -and $top.PSObject.Properties['rva']) {
                    return [string]$top.rva
                }
            }
        }
    }
    if ($Record.PSObject.Properties['rva']) {
        return [string]$Record.rva
    }
    return ''
}

function Get-StackDepth {
    [CmdletBinding()]
    param($Record)
    if ($Record.PSObject.Properties['stack']) {
        $stack = $Record.stack
        if ($null -ne $stack) {
            return @($stack).Count
        }
    }
    return 0
}

function Build-DedupKey {
    [CmdletBinding()]
    param($Record)

    if ($Record.PSObject.Properties['dedup_key']) {
        $dk = [string]$Record.dedup_key
        if ($dk) { return $dk }
    }

    $cls   = if ($Record.PSObject.Properties['class'])    { [string]$Record.'class' }    else { '' }
    $msg   = if ($Record.PSObject.Properties['msg'])      { [string]$Record.msg }        else { '' }
    $scen  = if ($Record.PSObject.Properties['scenario']) { [string]$Record.scenario }   else { '' }
    $top   = Get-TopStackRva -Record $Record

    $msgSlice = if ($msg.Length -gt 80) { $msg.Substring(0, 80) } else { $msg }
    return "$cls|$msgSlice|$top|$scen"
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    if ($PSCmdlet.ParameterSetName -eq 'File') {
        $records = Read-Jsonl -Path $ErrorsFile
    } else {
        $parsed = $Errors | ConvertFrom-Json -Depth 32 -DateKind String
        $records = @($parsed)
    }

    if ($RunIdFilter) {
        $records = @($records | Where-Object {
            $_ -and $_.PSObject.Properties['run_id'] -and ([string]$_.run_id) -eq $RunIdFilter
        })
    }

    # Group
    $groups = [ordered]@{}
    foreach ($r in $records) {
        if ($null -eq $r) { continue }
        $key = Build-DedupKey -Record $r
        if (-not $groups.Contains($key)) {
            $groups[$key] = [pscustomobject]@{
                dedup_key      = $key
                level          = if ($r.PSObject.Properties['level']) { [string]$r.level } else { 'error' }
                count          = 0
                first_ts       = $null
                last_ts        = $null
                stack_depth    = (Get-StackDepth -Record $r)
                representative = $r
            }
        }
        $g = $groups[$key]
        $g.count++

        $ts = if ($r.PSObject.Properties['ts']) { [string]$r.ts } else { '' }
        if ($ts) {
            if ($null -eq $g.first_ts -or $ts -lt $g.first_ts) { $g.first_ts = $ts }
            if ($null -eq $g.last_ts  -or $ts -gt $g.last_ts ) { $g.last_ts  = $ts }
        }
    }

    # Sort: level priority asc → stack_depth asc → count desc
    $sorted = @($groups.Values | Sort-Object @(
        @{ Expression = { Get-LevelPriority $_.level }; Ascending = $true },
        @{ Expression = { [int]$_.stack_depth };        Ascending = $true },
        @{ Expression = { [int]$_.count };              Ascending = $false }
    ))

    $json = $sorted | ConvertTo-Json -Depth 32
    if ($OutputJson) {
        Write-Utf8NoBom -Path $OutputJson -Content $json
        Write-AutoFixLog -Level info -Msg 'wrote dedup groups' -Ctx @{ path = $OutputJson; groups = $sorted.Count }
    } else {
        [Console]::Out.WriteLine($json)
    }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'dedup.ps1' }
    exit $Script:AutoFixExit_Generic
}
