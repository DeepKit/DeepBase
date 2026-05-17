#requires -Version 7.0
# Feature: autofix-runtime-errors, Property 9: dedup 分组完整性与排序
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/dedup.Tests.ps1
#
# Validates Requirements 5.1, 5.2, 5.3 — design v2.0 §5.1 Property 9.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts\autofix\dedup.ps1'
    if (-not (Test-Path -LiteralPath $script:ScriptPath -PathType Leaf)) {
        throw "dedup.ps1 not found at: $script:ScriptPath"
    }

    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-dd-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    function script:New-RandomErrorList {
        <#
        .SYNOPSIS
            Generate a random list of runtime-error records biased toward a
            small set of dedup_keys so that grouping behaviour can be checked.
        #>
        param([int]$Seed)

        $rng = [System.Random]::new($Seed)
        $classes   = @('EAccessViolation', 'EConvertError', 'EOutOfMemory', 'EArgumentException', 'EFooBar')
        $messages  = @('boom', 'panic', 'invalid input', 'overflow at index', 'unexpected null')
        $scenarios = @('scan', 'reload', 'commit', 'fetch')
        $levels    = @('fatal', 'error', 'warning')
        $rvas      = @('$00001234', '$0000ABCD', '$0000FFFF', '$DEADBEEF')

        # Pre-seed dedup-key prototypes so we can guarantee multi-element groups.
        $protoCount = $rng.Next(2, 6)
        $prototypes = New-Object System.Collections.Generic.List[hashtable]
        for ($i = 0; $i -lt $protoCount; $i++) {
            $prototypes.Add(@{
                'class'   = $classes[$rng.Next(0, $classes.Count)]
                msg       = $messages[$rng.Next(0, $messages.Count)] + ' #' + $i
                rva       = $rvas[$rng.Next(0, $rvas.Count)]
                scenario  = $scenarios[$rng.Next(0, $scenarios.Count)]
                level     = $levels[$rng.Next(0, $levels.Count)]
                stack_n   = $rng.Next(1, 8)
            }) | Out-Null
        }

        $count = $rng.Next(5, 60)
        $records = New-Object System.Collections.Generic.List[hashtable]
        for ($i = 0; $i -lt $count; $i++) {
            $p = $prototypes[$rng.Next(0, $prototypes.Count)]
            $stack = New-Object System.Collections.Generic.List[hashtable]
            $stack.Add(@{ module_name = 'X.exe'; module_base = '$00400000'; rva = $p.rva }) | Out-Null
            for ($k = 1; $k -lt $p.stack_n; $k++) {
                $stack.Add(@{ module_name = 'X.exe'; module_base = '$00400000'; rva = $rvas[$rng.Next(0, $rvas.Count)] }) | Out-Null
            }
            $tsBase = [datetime]::Parse('2025-01-01T10:00:00Z').ToUniversalTime()
            $ts = $tsBase.AddSeconds($rng.Next(0, 100000)).ToString('o')
            $records.Add(@{
                run_id      = '11111111-1111-4111-8111-111111111111'
                iteration   = 1
                ts          = $ts
                level       = $p.level
                'class'     = $p.'class'
                msg         = $p.msg
                module_name = 'X.exe'
                module_base = '$00400000'
                rva         = $p.rva
                stack       = $stack.ToArray()
                stack_truncated = $false
                context     = '<rand>'
                params      = ''
                state       = ''
                thread      = 'main'
                scenario    = $p.scenario
            }) | Out-Null
        }

        # Write to a temp jsonl
        $path = Join-Path $script:TmpRoot ("err-{0}.jsonl" -f $Seed)
        $enc = [System.Text.UTF8Encoding]::new($false)
        $sb = [System.Text.StringBuilder]::new()
        foreach ($r in $records) {
            [void]$sb.AppendLine(($r | ConvertTo-Json -Depth 8 -Compress))
        }
        [System.IO.File]::WriteAllText($path, $sb.ToString(), $enc)

        return @{
            Path    = $path
            Records = $records.ToArray()
        }
    }

    function script:Invoke-Dedup {
        param([Parameter(Mandatory)][string]$ErrorsFile)
        $stdout = & pwsh -NoProfile -NoLogo -NonInteractive -File $script:ScriptPath -ErrorsFile $ErrorsFile 2>$null
        $rc = $LASTEXITCODE
        if ($rc -ne 0) { throw "dedup.ps1 exit=$rc" }
        $text = ($stdout | Out-String).Trim()
        if (-not $text) { return @() }
        $obj = $text | ConvertFrom-Json -Depth 32
        return ,@($obj)
    }

    function script:Get-LevelPriority {
        param([string]$Level)
        switch ($Level) {
            'fatal'   { return 0 }
            'error'   { return 1 }
            'warning' { return 2 }
            default   { return 3 }
        }
    }

    function script:Build-DedupKey {
        param([hashtable]$Rec)
        $msg = [string]$Rec.msg
        $slice = if ($msg.Length -gt 80) { $msg.Substring(0, 80) } else { $msg }
        return ('{0}|{1}|{2}|{3}' -f $Rec.'class', $slice, $Rec.rva, $Rec.scenario)
    }
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'dedup.ps1 — grouping invariants' {

    Context 'Property 9: Σcount=|E|, key uniqueness, sort order, ts bounds' {

        It 'satisfies all four invariants across 100 random fixtures' {
            $iterations = 100
            for ($i = 0; $i -lt $iterations; $i++) {
                $fix = New-RandomErrorList -Seed ($i + 1)
                $records = @($fix.Records)
                $groups  = @(Invoke-Dedup -ErrorsFile $fix.Path)

                # 1) keys unique
                $keys = @($groups | ForEach-Object { [string]$_.dedup_key })
                $unique = @($keys | Select-Object -Unique)
                $unique.Count | Should -Be $keys.Count

                # 2) Σcount == |E|
                $totalCount = 0
                foreach ($g in $groups) { $totalCount += [int]$g.count }
                $totalCount | Should -Be $records.Count

                # 3) per-group count + ts bounds
                $byKey = @{}
                foreach ($r in $records) {
                    $k = Build-DedupKey -Rec $r
                    if (-not $byKey.ContainsKey($k)) {
                        $byKey[$k] = New-Object System.Collections.Generic.List[object]
                    }
                    $byKey[$k].Add($r) | Out-Null
                }
                foreach ($g in $groups) {
                    $k = [string]$g.dedup_key
                    $byKey.ContainsKey($k) | Should -BeTrue
                    [int]$g.count | Should -Be $byKey[$k].Count
                    $tsList = @($byKey[$k] | ForEach-Object { [string]$_.ts })
                    $minTs = ($tsList | Sort-Object | Select-Object -First 1)
                    $maxTs = ($tsList | Sort-Object | Select-Object -Last 1)
                    [string]$g.first_ts | Should -Be $minTs
                    [string]$g.last_ts  | Should -Be $maxTs
                }

                # 4) Sort: level priority asc → stack_depth asc → count desc
                if ($groups.Count -ge 2) {
                    for ($j = 0; $j -lt ($groups.Count - 1); $j++) {
                        $a = $groups[$j]
                        $b = $groups[$j + 1]
                        $pa = Get-LevelPriority ([string]$a.level)
                        $pb = Get-LevelPriority ([string]$b.level)
                        if ($pa -ne $pb) {
                            $pa | Should -BeLessOrEqual $pb
                        } elseif ([int]$a.stack_depth -ne [int]$b.stack_depth) {
                            ([int]$a.stack_depth) | Should -BeLessOrEqual ([int]$b.stack_depth)
                        } else {
                            ([int]$a.count) | Should -BeGreaterOrEqual ([int]$b.count)
                        }
                    }
                }
            }
        }
    }
}
