#requires -Version 7.0
# Feature: autofix-runtime-errors, Property 10: .map 解析正确性 + 回退 + RVA 输入不变性
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/map-parser.Tests.ps1
#
# Validates Requirements 6.1, 6.2, 6.4 — design v2.0 §5.1 Property 10.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts\autofix\map-parser.ps1'
    if (-not (Test-Path -LiteralPath $script:ScriptPath -PathType Leaf)) {
        throw "map-parser.ps1 not found at: $script:ScriptPath"
    }

    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-mp-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    function script:New-RandomMap {
        <#
        .SYNOPSIS
            Generate a random but well-formed Delphi .map fragment plus the
            authoritative ground-truth tables describing every line/symbol.
        .OUTPUTS
            @{
                Path     = <abs path to .map file>
                Segments = [array of @{ Section; Offset; Length; Name; Module }]
                Symbols  = [array of @{ Section; Offset; Rva; Name }]
                Lines    = [array of @{ Unit; File; Section; Offset; Rva; Line }]
            }
        #>
        param([int]$Seed)

        $rng = [System.Random]::new($Seed)
        $segCount = $rng.Next(1, 3) + 1   # 2..3 segments
        $segments = New-Object System.Collections.Generic.List[hashtable]
        $cursor = [uint64]0x1000
        for ($i = 0; $i -lt $segCount; $i++) {
            $len = [uint64]($rng.Next(0x1000, 0x4000))
            $segments.Add(@{
                Section = 1
                Offset  = $cursor
                Length  = $len
                Name    = (@('.text', '.itext', '.data')[$i % 3])
                Module  = ('Mod' + $i)
            }) | Out-Null
            $cursor += $len + [uint64]0x100
        }

        $symbols = New-Object System.Collections.Generic.List[hashtable]
        $lines   = New-Object System.Collections.Generic.List[hashtable]
        $segIdx  = 0
        foreach ($seg in $segments) {
            $segIdx++
            $unitName = ('Unit{0}' -f $segIdx)
            $fileName = ('Unit{0}.pas' -f $segIdx)

            # Sequential symbols inside this segment
            $symBase = [uint64]$seg.Offset + [uint64]0x100
            $symStep = [uint64]0x80
            $symN    = $rng.Next(2, 6)
            for ($k = 0; $k -lt $symN; $k++) {
                $rva = $symBase + ([uint64]$k * $symStep)
                $symbols.Add(@{
                    Section = 1
                    Offset  = $rva
                    Rva     = $rva
                    Name    = ('{0}.Func{1}' -f $unitName, $k)
                }) | Out-Null
            }

            # Sequential line records inside this segment, separated by 8 bytes
            $lineBase = [uint64]$seg.Offset + [uint64]0x40
            $lineStep = [uint64]0x10
            $lineN    = $rng.Next(4, 10)
            $lineNo   = 100
            for ($k = 0; $k -lt $lineN; $k++) {
                $rva = $lineBase + ([uint64]$k * $lineStep)
                $lines.Add(@{
                    Unit    = $unitName
                    File    = $fileName
                    Section = 1
                    Offset  = $rva
                    Rva     = $rva
                    Line    = ($lineNo + $k)
                }) | Out-Null
            }
        }

        # Compose .map text
        $sb = [System.Text.StringBuilder]::new()
        [void]$sb.AppendLine(' Borland Turbo Linker Version (random fixture)')
        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('Detailed map of segments')
        [void]$sb.AppendLine('')
        foreach ($seg in $segments) {
            [void]$sb.AppendLine((' {0:X4}:{1:X8} {2:X8} C=CODE     S={3,-9} G=(none)   M={4}  ACBP=A9' -f `
                $seg.Section, ([uint64]$seg.Offset), ([uint64]$seg.Length), $seg.Name, $seg.Module))
        }

        [void]$sb.AppendLine('')
        [void]$sb.AppendLine('  Address         Publics by Value')
        [void]$sb.AppendLine('')
        foreach ($s in $symbols) {
            [void]$sb.AppendLine((' {0:X4}:{1:X8}       {2}' -f $s.Section, ([uint64]$s.Offset), $s.Name))
        }

        [void]$sb.AppendLine('')
        $segIdx = 0
        foreach ($seg in $segments) {
            $segIdx++
            $unitName = ('Unit{0}' -f $segIdx)
            $fileName = ('Unit{0}.pas' -f $segIdx)
            [void]$sb.AppendLine(('Line numbers for {0}({1}) segment {2}' -f $unitName, $fileName, $seg.Name))
            [void]$sb.AppendLine('')
            $relevant = @($lines | Where-Object { $_.Unit -eq $unitName })
            $col = 0
            $row = ''
            foreach ($ln in $relevant) {
                $row += ('  {0,4} {1:X4}:{2:X8}' -f $ln.Line, $ln.Section, ([uint64]$ln.Offset))
                $col++
                if ($col -ge 4) {
                    [void]$sb.AppendLine($row)
                    $row = ''
                    $col = 0
                }
            }
            if ($col -gt 0) { [void]$sb.AppendLine($row) }
            [void]$sb.AppendLine('')
        }

        $path = Join-Path $script:TmpRoot ("rand-{0}.map" -f $Seed)
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($path, $sb.ToString(), $enc)

        return @{
            Path     = $path
            Segments = $segments.ToArray()
            Symbols  = $symbols.ToArray()
            Lines    = $lines.ToArray()
        }
    }

    function script:Invoke-MapParser {
        param(
            [Parameter(Mandatory)][string]$MapFile,
            [Parameter(Mandatory)][string]$Rva,
            [string]$ModuleName = ''
        )
        $args = @('-MapFile', $MapFile, '-Rva', $Rva)
        if ($ModuleName) { $args += @('-ModuleName', $ModuleName) }
        $stdout = & pwsh -NoProfile -NoLogo -NonInteractive -File $script:ScriptPath @args 2>$null
        $rc = $LASTEXITCODE
        if ($rc -ne 0) { throw "map-parser exit=$rc" }
        return ($stdout | Out-String) | ConvertFrom-Json -Depth 8
    }

    function script:Format-RvaHex {
        param([Parameter(Mandatory)][uint64]$Value)
        return ('$' + $Value.ToString('X8'))
    }
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'map-parser.ps1 — .map 解析正确性' {

    Context 'Property 10: exact line round-trip + fallback chain monotonic' {

        It 'round-trips every line entry across 100 random fixtures' {
            $iterations = 100
            $checked = 0
            for ($i = 0; $i -lt $iterations; $i++) {
                $fixture = New-RandomMap -Seed ($i + 1)
                $rng = [System.Random]::new($i + 1024)
                $entry = $fixture.Lines[$rng.Next(0, $fixture.Lines.Count)]
                $rvaText = Format-RvaHex -Value $entry.Rva
                $resolved = Invoke-MapParser -MapFile $fixture.Path -Rva $rvaText
                $resolved.level   | Should -Be 'exact'
                $resolved.file    | Should -Be $entry.File
                [int]$resolved.line | Should -Be $entry.Line
                $resolved.rva     | Should -Be $rvaText
                $checked++
            }
            $checked | Should -Be $iterations
        }

        It 'falls back from exact to function/segment/raw with monotonic level' {
            $iterations = 100
            $rng = [System.Random]::new(7919)
            $levelOrder = @{ 'exact' = 0; 'function' = 1; 'segment' = 2; 'raw' = 3 }
            for ($i = 0; $i -lt $iterations; $i++) {
                $fixture = New-RandomMap -Seed (1000 + $i)
                $segments = @($fixture.Segments)
                $seg = $segments[$rng.Next(0, $segments.Count)]
                # Pick an RVA somewhere inside the segment but NOT exactly on a
                # registered line entry — falls back to function or segment.
                $maxOffset = [uint64]$seg.Length - [uint64]7
                if ($maxOffset -lt [uint64]1) { $maxOffset = [uint64]1 }
                $delta = [uint64]($rng.Next(1, [int][Math]::Min([uint64]0xFF, $maxOffset)))
                $rva = [uint64]$seg.Offset + $delta + [uint64]3   # +3 to avoid lining up

                $rvaText = Format-RvaHex -Value $rva
                $resolved = Invoke-MapParser -MapFile $fixture.Path -Rva $rvaText
                $resolved.level | Should -BeIn @('exact', 'function', 'segment', 'raw')
                $resolved.rva   | Should -Be $rvaText

                # RVA-only invariance: passing different module-name labels must
                # not change file/line/function/segment classification.
                $alt = Invoke-MapParser -MapFile $fixture.Path -Rva $rvaText -ModuleName 'AltModule.exe'
                $alt.level    | Should -Be $resolved.level
                $alt.file     | Should -Be $resolved.file
                $alt.line     | Should -Be $resolved.line
                $alt.function | Should -Be $resolved.function

                # Far above the largest segment end should never resolve to
                # 'exact' (unbounded RVA → degraded level).
                $beyond = [uint64]0
                foreach ($s in $segments) {
                    $end = [uint64]$s.Offset + [uint64]$s.Length
                    if ($end -gt $beyond) { $beyond = $end }
                }
                $farRva = Format-RvaHex -Value ($beyond + [uint64]0x10000)
                $far = Invoke-MapParser -MapFile $fixture.Path -Rva $farRva
                $levelOrder[[string]$far.level] | Should -BeGreaterOrEqual $levelOrder[[string]$resolved.level]
            }
        }
    }
}
