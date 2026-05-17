#requires -Version 7.0
# Feature: autofix-runtime-errors,
#   Property 14: max-iter 不变量与振荡终止
#   Property 15: iteration-summary 完整性
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/autofix-loop.Tests.ps1
#
# Validates Requirements 11.3, 11.4 (P14) and 11.5 (P15) — design v2.0 §5.1.
#
# NOTE: autofix.ps1 cannot be invoked end-to-end without git, BDS 37.0, an EXE,
# and an AI backend. Per design §3.8.1 the loop's algorithmic invariants
# (max-iter cap, oscillation threshold, iteration-summary schema) are pure
# bookkeeping. We exercise those invariants two ways:
#   (a) A reference implementation of the loop's bookkeeping using the same
#       semantics documented in design §3.8.1 / §4.5.
#   (b) An equivalence guard that greps autofix.ps1 for the matching defaults
#       (OscillationThreshold = 3, the MaxIterations for-loop bound,
#        iteration-summary writes).

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:LoopScript = Join-Path $script:RepoRoot 'scripts\autofix\autofix.ps1'
    if (-not (Test-Path -LiteralPath $script:LoopScript -PathType Leaf)) {
        throw "autofix.ps1 not found at: $script:LoopScript"
    }

    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-loop-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    # Iteration-summary required fields per design §4.5 / Property 15.
    $script:RequiredSummaryFields = @(
        'iteration', 'errors_found', 'errors_fixed', 'compile_success',
        'duration_sec', 'ai_calls', 'rollback', 'result'
    )

    function script:New-IterationSummaryRow {
        <#
        .SYNOPSIS
            Build an iteration-summary record matching design §4.5.
        #>
        param(
            [int]$Iteration,
            [int]$ErrorsFound,
            [int]$ErrorsFixed,
            [bool]$CompileSuccess,
            [int]$DurationSec,
            [int]$AiCalls,
            [bool]$Rollback,
            [string]$Result,
            [string[]]$OscillationKeys = @()
        )
        return [pscustomobject]@{
            iteration            = $Iteration
            errors_found         = $ErrorsFound
            errors_fixed         = $ErrorsFixed
            compile_success      = $CompileSuccess
            duration_sec         = $DurationSec
            ai_calls             = $AiCalls
            rollback             = $Rollback
            result               = $Result
            oscillation_detected = @($OscillationKeys)
        }
    }

    function script:Invoke-LoopSimulation {
        <#
        .SYNOPSIS
            Faithful reference implementation of autofix.ps1's iteration loop
            bookkeeping for property testing. Tracks the algorithm's invariants
            without spawning child scripts.
        .OUTPUTS
            @{
                Summaries        = [pscustomobject[]]   # one per actual iteration
                Iterations       = [int]                # actual iterations run
                UnfixableKeys    = [string[]]           # keys hit threshold
                Result           = [string]             # final loop verdict
            }
        #>
        param(
            [Parameter(Mandatory)][int]$MaxIter,
            [Parameter(Mandatory)][int]$Threshold,
            [Parameter(Mandatory)][hashtable[]]$Schedule  # one entry per iteration
        )

        $history = @{}
        $unfixable = New-Object System.Collections.Generic.HashSet[string]
        $summaries = New-Object System.Collections.Generic.List[object]
        $result = 'max-iter'
        $actualIter = 0

        for ($i = 1; $i -le $MaxIter; $i++) {
            if ($i -gt $Schedule.Count) { break }
            $actualIter = $i
            $entry = $Schedule[$i - 1]
            $keys  = @($entry.Keys)

            # Update history (only count keys that re-appear from prior iter).
            foreach ($k in $keys) {
                if (-not $history.ContainsKey($k)) { $history[$k] = 0 }
                $history[$k]++
                if ($history[$k] -ge $Threshold) {
                    [void]$unfixable.Add($k)
                }
            }

            # Filter out unfixable keys for this iteration's fix list.
            $candidates = @($keys | Where-Object { -not $unfixable.Contains($_) })

            $errorsFound = $keys.Count
            $errorsFixed = if ($entry.ContainsKey('Fixed')) { [int]$entry.Fixed } else { $candidates.Count }
            $compileOk   = if ($entry.ContainsKey('Compile')) { [bool]$entry.Compile } else { $true }
            $aiCalls     = if ($entry.ContainsKey('AiCalls')) { [int]$entry.AiCalls } else { $candidates.Count }
            $rollback    = if ($entry.ContainsKey('Rollback')) { [bool]$entry.Rollback } else { (-not $compileOk) }

            $iterResult = if ($keys.Count -eq 0)         { 'success' }
                          elseif ($candidates.Count -eq 0)  { 'oscillation' }
                          else                              { 'progress' }

            $summaries.Add((
                New-IterationSummaryRow -Iteration $i -ErrorsFound $errorsFound `
                    -ErrorsFixed $errorsFixed -CompileSuccess $compileOk `
                    -DurationSec $i -AiCalls $aiCalls -Rollback $rollback `
                    -Result $iterResult `
                    -OscillationKeys (@($unfixable.ToArray()))
            )) | Out-Null

            if ($iterResult -eq 'success') {
                $result = 'success'
                break
            }
            if ($iterResult -eq 'oscillation') {
                $result = 'oscillation'
                break
            }
        }
        if ($result -eq 'max-iter' -and $actualIter -lt $MaxIter -and $actualIter -lt $Schedule.Count) {
            $result = 'stalled'
        }

        return @{
            Summaries     = @($summaries.ToArray())
            Iterations    = $actualIter
            UnfixableKeys = @($unfixable.ToArray())
            Result        = $result
        }
    }

    function script:New-RandomSchedule {
        <#
        .SYNOPSIS
            Generate a random per-iteration error-key plan. With small
            probability, lock one key in for >= Threshold iterations to
            force oscillation.
        #>
        param([int]$Seed, [int]$Length, [int]$Threshold)
        $rng = [System.Random]::new($Seed)
        $forceOsc = ($rng.Next(0, 100) -lt 40 -and $Length -ge $Threshold)
        $stickyKey = ('osc-' + $rng.Next(1, 9999))
        $sched = New-Object System.Collections.Generic.List[hashtable]
        for ($i = 0; $i -lt $Length; $i++) {
            $randKeys = New-Object System.Collections.Generic.HashSet[string]
            $n = $rng.Next(1, 4)
            for ($k = 0; $k -lt $n; $k++) {
                [void]$randKeys.Add('k' + $rng.Next(1, 6))
            }
            if ($forceOsc) { [void]$randKeys.Add($stickyKey) }
            $sched.Add(@{ Keys = @($randKeys.ToArray()) }) | Out-Null
        }
        return @{
            Schedule  = $sched.ToArray()
            ForceOsc  = $forceOsc
            StickyKey = $stickyKey
        }
    }
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'autofix.ps1 — loop invariants' {

    Context 'spec-source equivalence' {
        It 'autofix.ps1 caps iterations with the MaxIterations for-loop bound' {
            $src = [System.IO.File]::ReadAllText($script:LoopScript, [System.Text.UTF8Encoding]::new($false))
            $src | Should -Match 'for\s*\(\s*\$iter\s*=\s*1\s*;\s*\$iter\s*-le\s*\$MaxIterations\s*;'
        }
        It 'autofix.ps1 uses OscillationThreshold default 3' {
            $src = [System.IO.File]::ReadAllText($script:LoopScript, [System.Text.UTF8Encoding]::new($false))
            $src | Should -Match '\[int\]\$OscillationThreshold\s*=\s*3'
        }
        It 'autofix.ps1 writes iteration-summary.jsonl on every iteration' {
            $src = [System.IO.File]::ReadAllText($script:LoopScript, [System.Text.UTF8Encoding]::new($false))
            $src | Should -Match 'iteration-summary\.jsonl'
        }
    }

    Context 'Property 14: max-iter cap + oscillation termination' {
        It 'never exceeds MaxIterations and detects oscillation across 100 schedules' {
            $iterations = 100
            $rng = [System.Random]::new(20250115)
            for ($i = 0; $i -lt $iterations; $i++) {
                $maxIter   = $rng.Next(1, 31)
                $threshold = 3
                $schedLen  = $rng.Next(1, 31)
                $plan = New-RandomSchedule -Seed ($i + 1) -Length $schedLen -Threshold $threshold

                $r = Invoke-LoopSimulation -MaxIter $maxIter -Threshold $threshold -Schedule $plan.Schedule

                # Hard cap: actual iterations never exceed MaxIter.
                $r.Iterations | Should -BeLessOrEqual $maxIter
                $r.Summaries.Count | Should -BeLessOrEqual $maxIter

                # When the sticky key was forced and we have enough room, the
                # final result must be 'oscillation' or 'success' (when the
                # caller stopped early before reaching the threshold).
                if ($plan.ForceOsc -and $maxIter -ge $threshold -and $schedLen -ge $threshold) {
                    $r.UnfixableKeys | Should -Contain $plan.StickyKey
                    $r.Result        | Should -Be 'oscillation'
                    $r.Summaries[-1].oscillation_detected | Should -Contain $plan.StickyKey
                }
            }
        }
    }

    Context 'Property 15: iteration-summary completeness + monotonic numbering' {
        It 'each iteration emits exactly one row with all required fields' {
            $iterations = 100
            $rng = [System.Random]::new(31415)
            for ($i = 0; $i -lt $iterations; $i++) {
                $maxIter   = $rng.Next(1, 31)
                $threshold = 3
                $schedLen  = $rng.Next(1, 31)
                $plan = New-RandomSchedule -Seed ($i + 100) -Length $schedLen -Threshold $threshold
                $r = Invoke-LoopSimulation -MaxIter $maxIter -Threshold $threshold -Schedule $plan.Schedule

                # 1) one row per executed iteration
                $r.Summaries.Count | Should -Be $r.Iterations

                # 2) iteration field is monotonic increasing with no gaps
                $expected = 1
                foreach ($row in $r.Summaries) {
                    [int]$row.iteration | Should -Be $expected
                    $expected++
                }

                # 3) every required field present + correct type
                foreach ($row in $r.Summaries) {
                    foreach ($f in $script:RequiredSummaryFields) {
                        $row.PSObject.Properties[$f] | Should -Not -BeNullOrEmpty
                    }
                    [int]$row.iteration       | Should -BeGreaterThan 0
                    [int]$row.errors_found    | Should -BeGreaterOrEqual 0
                    [int]$row.errors_fixed    | Should -BeGreaterOrEqual 0
                    [int]$row.duration_sec    | Should -BeGreaterOrEqual 0
                    [int]$row.ai_calls        | Should -BeGreaterOrEqual 0
                    ($row.compile_success -is [bool]) | Should -BeTrue
                    ($row.rollback        -is [bool]) | Should -BeTrue
                    [string]::IsNullOrEmpty([string]$row.result) | Should -BeFalse
                }

                # 4) Round-trip via jsonl
                $jsonl = Join-Path $script:TmpRoot ("summary-{0}.jsonl" -f $i)
                $enc = [System.Text.UTF8Encoding]::new($false)
                $sb = [System.Text.StringBuilder]::new()
                foreach ($row in $r.Summaries) {
                    [void]$sb.AppendLine(($row | ConvertTo-Json -Depth 8 -Compress))
                }
                [System.IO.File]::WriteAllText($jsonl, $sb.ToString(), $enc)

                $rt = @(Get-Content -LiteralPath $jsonl -Encoding utf8 |
                        Where-Object { $_.Trim() } |
                        ForEach-Object { $_ | ConvertFrom-Json -Depth 8 })
                $rt.Count | Should -Be $r.Summaries.Count
            }
        }
    }
}
