<#
.SYNOPSIS
    Resolve Delphi .map RVA -> {file, line, function, segment} with fallback chain.

.DESCRIPTION
    Parses a Delphi-generated .map file (segments / public symbols / line numbers)
    and resolves a Relative Virtual Address (RVA) to source file/line.

    Fallback chain (design §6.2):
        exact line  ->  function name  ->  segment name  ->  raw module:rva
    Returned 'level' field reports which step succeeded.

.PARAMETER MapFile
    Path to the .map file produced by Delphi linker.

.PARAMETER Rva
    Single RVA in hex form (with or without leading '$' / '0x').

.PARAMETER ModuleName
    Module name (used only when emitting raw fallback). Optional.

.PARAMETER Frames
    JSON array string of {module_name, rva} objects, used when resolving multiple
    stack frames in one call. Mutually exclusive with -Rva.

.PARAMETER OutputJson
    Optional path to write the result as JSON. If absent, writes to stdout.

.OUTPUTS
    Single frame mode: object { file, line, function, segment, level, rva }
    Multi-frame mode : array of the same objects (same order as input).

.EXAMPLE
    pwsh -File map-parser.ps1 -MapFile bin/MyApp.map -Rva 0x1234 -ModuleName MyApp.exe

.EXAMPLE
    pwsh -File map-parser.ps1 -MapFile bin/MyApp.map -Frames '[{"module_name":"MyApp.exe","rva":"$1234"}]'

.NOTES
    Validates Requirements 6.1, 6.2, 6.3, 6.4.
#>
[CmdletBinding(DefaultParameterSetName = 'Single')]
param(
    [Parameter(Mandatory)]
    [string]$MapFile,

    [Parameter(ParameterSetName = 'Single')]
    [string]$Rva,

    [Parameter(ParameterSetName = 'Single')]
    [string]$ModuleName = '',

    [Parameter(Mandatory, ParameterSetName = 'Multi')]
    [string]$Frames,

    [string]$OutputJson
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function ConvertFrom-HexRva {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Text)
    $t = $Text.Trim()
    if ($t.StartsWith('$')) { $t = $t.Substring(1) }
    elseif ($t.StartsWith('0x') -or $t.StartsWith('0X')) { $t = $t.Substring(2) }
    return [Convert]::ToUInt64($t, 16)
}

function ConvertTo-HexRva {
    [CmdletBinding()]
    param([Parameter(Mandatory)][uint64]$Value)
    return ('$' + $Value.ToString('X8'))
}

function Read-MapModel {
    <#
    .SYNOPSIS
        Parse a Delphi .map file into an in-memory model.

    .OUTPUTS
        [pscustomobject] @{
            Segments = [array] of @{ Section; Offset; Length; Class; Group; Name }
            Symbols  = [array] of @{ Section; Offset; Rva; Name } (sorted by Rva asc)
            Lines    = [array] of @{ Unit; File; Section; Offset; Rva; Line } (sorted by Rva asc)
        }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "map file not found: $Path"
    }

    $text  = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    $lines = $text -split "`r?`n"

    $segments = New-Object System.Collections.Generic.List[object]
    $symbols  = New-Object System.Collections.Generic.List[object]
    $lineRecs = New-Object System.Collections.Generic.List[object]

    $section = ''            # 'segments' | 'symbols' | 'lines' | ''
    $currentUnit = ''
    $currentFile = ''

    # Detailed map of segments
    #  0001:00001000 00000A20 C=CODE     S=.text    G=(none)   M=System  ACBP=A9
    $segRe = [regex]'^\s*([0-9A-Fa-f]{4}):([0-9A-Fa-f]{8})\s+([0-9A-Fa-f]{8})\s+C=(\S+)\s+S=(\S+)\s+G=(\S+)\s+M=(\S+)'

    # Detailed map of public symbols
    #  0001:00001234       SystemError
    $symRe = [regex]'^\s*([0-9A-Fa-f]{4}):([0-9A-Fa-f]{8})\s+(\S.*)$'

    # Line numbers section header (e.g. "Line numbers for System(System.pas) segment .text")
    $lineHdrRe = [regex]'^Line numbers for\s+([^(]+)\(([^)]+)\)\s+segment\s+(\S+)'

    # Line numbers data:  "   123 0001:00002000   125 0001:00002010 ..."
    $lineRowRe = [regex]'(\d+)\s+([0-9A-Fa-f]{4}):([0-9A-Fa-f]{8})'

    foreach ($raw in $lines) {
        if ($raw -match '^\s*Detailed map of segments') { $section = 'segments'; continue }
        elseif ($raw -match '^\s*Detailed map of public symbols') { $section = 'symbols'; continue }
        elseif ($raw -match '^\s*Address\s+Publics') { $section = 'symbols'; continue }
        elseif ($raw -match '^\s*Bound resource files') { $section = ''; continue }
        elseif ($raw -match '^Program entry point') { $section = ''; continue }

        $hdrMatch = $lineHdrRe.Match($raw)
        if ($hdrMatch.Success) {
            $section     = 'lines'
            $currentUnit = $hdrMatch.Groups[1].Value.Trim()
            $currentFile = $hdrMatch.Groups[2].Value.Trim()
            continue
        }

        if ($section -eq 'segments') {
            $m = $segRe.Match($raw)
            if ($m.Success) {
                $segments.Add([pscustomobject]@{
                    Section = [Convert]::ToInt32($m.Groups[1].Value, 16)
                    Offset  = [Convert]::ToUInt64($m.Groups[2].Value, 16)
                    Length  = [Convert]::ToUInt64($m.Groups[3].Value, 16)
                    Class   = $m.Groups[4].Value
                    Name    = $m.Groups[5].Value
                    Group   = $m.Groups[6].Value
                    Module  = $m.Groups[7].Value
                }) | Out-Null
            }
            continue
        }

        if ($section -eq 'symbols') {
            $m = $symRe.Match($raw)
            if ($m.Success) {
                $sec = [Convert]::ToInt32($m.Groups[1].Value, 16)
                $off = [Convert]::ToUInt64($m.Groups[2].Value, 16)
                $name = $m.Groups[3].Value.Trim()
                # Skip lines like "Address  Publics by Value"
                if ($name -match '^(Publics|Name)') { continue }
                $symbols.Add([pscustomobject]@{
                    Section = $sec
                    Offset  = $off
                    Rva     = $off
                    Name    = $name
                }) | Out-Null
            }
            continue
        }

        if ($section -eq 'lines') {
            foreach ($mm in $lineRowRe.Matches($raw)) {
                $lineNo = [int]$mm.Groups[1].Value
                $sec    = [Convert]::ToInt32($mm.Groups[2].Value, 16)
                $off    = [Convert]::ToUInt64($mm.Groups[3].Value, 16)
                $lineRecs.Add([pscustomobject]@{
                    Unit    = $currentUnit
                    File    = $currentFile
                    Section = $sec
                    Offset  = $off
                    Rva     = $off
                    Line    = $lineNo
                }) | Out-Null
            }
            continue
        }
    }

    # Build segment base lookup: section_number -> base offset.
    # Line and symbol offsets in Delphi .map files are section-relative.
    # Convert to flat (module-relative) RVA by adding the segment base.
    # Heuristic: if offset >= base for its section the offset is already
    # a flat RVA (single-section EXE case); leave it unchanged.
    $segBase = @{}
    foreach ($seg in $segments) {
        $sec = [int]$seg.Section
        if (-not $segBase.ContainsKey($sec)) {
            $segBase[$sec] = [uint64]$seg.Offset
        }
    }
    foreach ($sym in $symbols) {
        $sec  = [int]$sym.Section
        $off  = [uint64]$sym.Offset
        $base = if ($segBase.ContainsKey($sec)) { $segBase[$sec] } else { [uint64]0 }
        if ($off -lt $base) { $sym.Rva = $base + $off }
    }
    foreach ($line in $lineRecs) {
        $sec  = [int]$line.Section
        $off  = [uint64]$line.Offset
        $base = if ($segBase.ContainsKey($sec)) { $segBase[$sec] } else { [uint64]0 }
        if ($off -lt $base) { $line.Rva = $base + $off }
    }

    # Sort by Rva for fast nearest-lookup
    $sortedSyms  = @($symbols  | Sort-Object Rva)
    $sortedLines = @($lineRecs | Sort-Object Rva)
    $segArr      = @($segments.ToArray())

    # Use a plain hashtable + manual indexer to avoid PSCustomObject array
    # auto-unwrap quirks when arrays have a single element.
    $model = New-Object psobject
    $model | Add-Member -MemberType NoteProperty -Name Segments -Value $segArr
    $model | Add-Member -MemberType NoteProperty -Name Symbols  -Value $sortedSyms
    $model | Add-Member -MemberType NoteProperty -Name Lines    -Value $sortedLines
    return $model
}

function Find-NearestLeq {
    <#
    .SYNOPSIS
        Find the entry in a sorted list whose <Property> is the largest value <= Target.

    .NOTES
        Uses linear scan (.map sizes are small; binary search not needed for clarity).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()]$List,
        [Parameter(Mandatory)][string]$Property,
        [Parameter(Mandatory)][uint64]$Target
    )
    if ($null -eq $List) { return $null }
    $best = $null
    $bestVal = [uint64]0
    foreach ($item in @($List)) {
        if ($null -eq $item) { continue }
        $raw = $item.$Property
        if ($null -eq $raw) { continue }
        $v = [uint64]$raw
        if ($v -le $Target) {
            if ($null -eq $best -or $v -gt $bestVal) {
                $best = $item
                $bestVal = $v
            }
        }
    }
    return $best
}

function Resolve-MapRva {
    <#
    .SYNOPSIS
        Resolve one RVA against a parsed map model.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Model,
        [Parameter(Mandatory)][uint64]$RvaValue,
        [string]$ModuleName = ''
    )

    $result = [ordered]@{
        rva      = ConvertTo-HexRva -Value $RvaValue
        file     = $null
        line     = $null
        function = $null
        segment  = $null
        level    = 'raw'
        module   = $ModuleName
    }

    # Step 1: exact line lookup (largest line.Rva <= target)
    $bestLine = Find-NearestLeq -List $Model.Lines -Property 'Rva' -Target $RvaValue
    if ($bestLine) {
        # Same section as target? we don't know target section here; rely on Rva proximity.
        # Accept only when within 1 KiB (heuristic: line records are typically dense)
        $delta = $RvaValue - [uint64]$bestLine.Rva
        if ($delta -le 0x1000) {
            $result.file     = $bestLine.File
            $result.line     = [int]$bestLine.Line
            $result.function = $null
            $result.segment  = $null
            $result.level    = 'exact'
        }
    }

    # Step 2: function-level fallback
    if ($result.level -eq 'raw') {
        $bestSym = Find-NearestLeq -List $Model.Symbols -Property 'Rva' -Target $RvaValue
        if ($bestSym) {
            $result.function = $bestSym.Name
            $result.level    = 'function'
        }
    } else {
        # already exact; still attach function name when we can find it
        $bestSym = Find-NearestLeq -List $Model.Symbols -Property 'Rva' -Target $RvaValue
        if ($bestSym) { $result.function = $bestSym.Name }
    }

    # Step 3: segment-level fallback
    if ($result.level -eq 'raw') {
        foreach ($seg in $Model.Segments) {
            $start = [uint64]$seg.Offset
            $end   = $start + [uint64]$seg.Length
            if ($RvaValue -ge $start -and $RvaValue -lt $end) {
                $result.segment = $seg.Name
                $result.level   = 'segment'
                break
            }
        }
    }

    return [pscustomobject]$result
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    $model = Read-MapModel -Path $MapFile

    if ($PSCmdlet.ParameterSetName -eq 'Single') {
        if (-not $Rva) {
            Write-AutoFixLog -Level error -Msg 'missing -Rva for single mode' -Ctx @{ paramSet = 'Single' }
            exit $Script:AutoFixExit_BadParams
        }
        $rvaVal = ConvertFrom-HexRva -Text $Rva
        $resolved = Resolve-MapRva -Model $model -RvaValue $rvaVal -ModuleName $ModuleName
        $output = $resolved
    } else {
        $framesArr = $Frames | ConvertFrom-Json -Depth 16 -DateKind String
        if ($null -eq $framesArr) { $framesArr = @() }
        $list = New-Object System.Collections.Generic.List[object]
        foreach ($fr in $framesArr) {
            $rvaVal = ConvertFrom-HexRva -Text ([string]$fr.rva)
            $modName = if ($fr.PSObject.Properties['module_name']) { [string]$fr.module_name } else { '' }
            $list.Add((Resolve-MapRva -Model $model -RvaValue $rvaVal -ModuleName $modName)) | Out-Null
        }
        $output = ,$list.ToArray()
    }

    $json = $output | ConvertTo-Json -Depth 8
    if ($OutputJson) {
        Write-Utf8NoBom -Path $OutputJson -Content $json
        Write-AutoFixLog -Level info -Msg 'wrote map resolution' -Ctx @{ path = $OutputJson }
    } else {
        [Console]::Out.WriteLine($json)
    }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'map-parser.ps1' }
    exit $Script:AutoFixExit_Generic
}
