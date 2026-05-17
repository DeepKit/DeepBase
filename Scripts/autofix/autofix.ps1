<#
.SYNOPSIS
    AutoFix main loop: drive runner -> dedup -> map-parser -> ai-call ->
    diff-guard -> compile -> commit/discard until clean or budget exhausted.

.DESCRIPTION
    Orchestrates the full auto-fix lifecycle described in design v2.0
    §3.8.1 / §2.2. Behaviour highlights:

      * Pre-flight: run the three lint scripts (pascal-deps,
        powershell-strict, no-reset-hard). Any lint failure aborts the run
        with exit 100 and an iteration-summary record of result='abort'.
      * Isolation: every iteration's mutations happen inside a temporary
        git worktree created via git-checkpoint.ps1. The main working
        tree is never modified.
      * Determinism: every iteration generates a fresh UUID v4 RunId.
        runtime-errors.jsonl is filtered by run_id so stale records from
        prior runs cannot confuse this iteration.
      * Crash fallback: if the EXE exits non-zero AND no record matches
        this iteration's RunId, wer-collector.ps1 synthesizes one record.
      * Oscillation guard: dedup_keys that survive >= 3 fix attempts are
        marked unfixable and skipped in subsequent iterations
        (Property 14).
      * Per-group fix flow:
            cache hit  -> git apply cached patch (in worktree)
            cache miss -> ai-call -> diff-guard -> git apply (in worktree)
      * Post-fix verification: run compiler.ps1. On failure: ask AI once
        to repair, diff-guard, apply. If still failing: discard.
      * On success: commit + cache store. Exit code per design §4.8.

.PARAMETER Project
    Path to the .dproj that should be compiled. May be relative; resolved
    against the worktree once it is created.

.PARAMETER Scenarios
    Comma-separated scenario names to ask the EXE to run.

.PARAMETER MaxIterations
    Hard cap on loop iterations.

.PARAMETER ScenarioTimeout
    Forwarded to runner.ps1 -ScenarioTimeout.

.PARAMETER AllowedPaths / -AllowedPathsFile
    AllowedPaths configuration forwarded to diff-guard.ps1.

.PARAMETER BlockedPaths / -BlockedPathsFile
    Extra blocked globs forwarded to diff-guard.ps1 (the built-in defaults
    are always layered on by diff-guard itself).

.PARAMETER AiBackend
    Backend selector forwarded to ai-call.ps1.

.PARAMETER OutputDir
    Directory under which all jsonl/json artefacts are written. Default:
    './autofix-output' (created if missing).

.PARAMETER WorktreePath
    Override for the git worktree path. Default: an OS temp directory.

.PARAMETER ExePath
    Optional override for the EXE produced by the build. Default:
    <project_dir>/Win64/Debug/<project_stem>.exe (BDS default).

.PARAMETER MapPath
    Optional override for the .map file. Default: alongside the EXE.

.PARAMETER OscillationWindow
    Iterations of history considered for the oscillation count. Default 5.

.NOTES
    Validates Requirements 5.1, 5.2, 6.1, 7.2, 7.3, 7.4, 8.3, 9.1, 10.4,
    11.1, 11.2, 11.3, 11.4, 11.5.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)][string]$Project,
    [Parameter(Mandatory)][string]$Scenarios,

    [int]$MaxIterations = 10,
    [int]$ScenarioTimeout = 600,
    [int]$StartupTimeout = 30,

    [string]$AllowedPaths = '',
    [string]$AllowedPathsFile = '',
    [string]$BlockedPaths = '',
    [string]$BlockedPathsFile = '',

    [ValidateSet('claude', 'openai', 'cli')]
    [string]$AiBackend = 'cli',

    [string]$OutputDir = 'autofix-output',
    [string]$WorktreePath = '',

    [string]$ExePath = '',
    [string]$MapPath = '',

    [int]$OscillationWindow = 5,
    [int]$OscillationThreshold = 3,

    [switch]$SkipLint
)

. "$PSScriptRoot/_common.ps1"

# =============================================================================
# Helpers
# =============================================================================
function Invoke-ChildScript {
    <#
    .SYNOPSIS
        Run a sibling .ps1 with -ArgumentList semantics. Captures stdout
        and the script's exit code; never throws on non-zero (caller decides).
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string[]]$ChildArgs
    )
    $path = Join-Path $PSScriptRoot $Script
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "child script not found: $path"
    }
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $stdout = & pwsh -NoProfile -NoLogo -NonInteractive -File $path @ChildArgs
        $rc = $LASTEXITCODE
        return [pscustomobject]@{
            ExitCode = $rc
            Stdout   = ($stdout | Out-String).TrimEnd()
        }
    }
    finally {
        $ErrorActionPreference = $oldPref
    }
}

function Invoke-LintGate {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$RepoRoot)
    $names = @('lint-pascal-deps.ps1', 'lint-powershell-strict.ps1', 'lint-no-reset-hard.ps1')
    foreach ($n in $names) {
        $r = Invoke-ChildScript -Script $n -ChildArgs @('-Root', $RepoRoot)
        if ($r.ExitCode -ne 0) {
            Write-AutoFixLog -Level error -Msg 'lint gate failed' -Ctx @{ script = $n; exit = $r.ExitCode; stdout = $r.Stdout }
            return $false
        }
    }
    return $true
}

function Resolve-ExePath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ProjectFile,
        [string]$Override
    )
    if ($Override) { return $Override }
    $dir = Split-Path -Parent $ProjectFile
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($ProjectFile)
    return (Join-Path $dir (Join-Path 'Win64' (Join-Path 'Debug' "$stem.exe")))
}

function Resolve-MapPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ExeFile,
        [string]$Override
    )
    if ($Override) { return $Override }
    return [System.IO.Path]::ChangeExtension($ExeFile, '.map')
}

function ConvertTo-AbsoluteIfPossible {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$BaseDir
    )
    if ([System.IO.Path]::IsPathRooted($Path)) { return $Path }
    return (Join-Path $BaseDir $Path)
}

function New-IterationSummary {
    [CmdletBinding()]
    param(
        [int]$Iteration,
        [string]$RunIdValue,
        [string]$TsStart,
        [string]$TsEnd,
        [int]$ExitCodeValue,
        [int]$ErrorsFound,
        [int]$ErrorsUnique,
        [int]$ErrorsFixed,
        [int]$ErrorsRemaining,
        [bool]$CompileSuccess,
        [int]$AiCalls,
        [int]$CacheHits,
        [bool]$Rollback,
        [string[]]$OscillationKeys,
        [string]$Result
    )
    $duration = 0
    try {
        $a = [datetime]::Parse($TsStart)
        $b = [datetime]::Parse($TsEnd)
        $duration = [int]($b - $a).TotalSeconds
    } catch { $duration = 0 }
    return [pscustomobject]@{
        iteration            = $Iteration
        ts_start             = $TsStart
        ts_end               = $TsEnd
        duration_sec         = $duration
        run_id               = $RunIdValue
        exit_code            = $ExitCodeValue
        errors_found         = $ErrorsFound
        errors_unique        = $ErrorsUnique
        errors_fixed         = $ErrorsFixed
        errors_remaining     = $ErrorsRemaining
        compile_success      = $CompileSuccess
        ai_calls             = $AiCalls
        cache_hits           = $CacheHits
        rollback             = $Rollback
        oscillation_detected = @($OscillationKeys)
        result               = $Result
    }
}

function Get-DedupGroups {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$ErrorsFile,
        [Parameter(Mandatory)][string]$RunIdValue
    )
    $r = Invoke-ChildScript -Script 'dedup.ps1' -ChildArgs @(
        '-ErrorsFile', $ErrorsFile, '-RunIdFilter', $RunIdValue)
    if ($r.ExitCode -ne 0) {
        Write-AutoFixLog -Level warn -Msg 'dedup.ps1 failed' -Ctx @{ exit = $r.ExitCode }
        return @()
    }
    if ([string]::IsNullOrWhiteSpace($r.Stdout)) { return @() }
    try {
        $arr = $r.Stdout | ConvertFrom-Json -Depth 32 -DateKind String
        return @($arr)
    } catch {
        Write-AutoFixLog -Level warn -Msg 'dedup output not JSON' -Ctx @{ stdout_head = $r.Stdout.Substring(0, [Math]::Min(200, $r.Stdout.Length)) }
        return @()
    }
}

function Resolve-StackFrames {
    <#
    .SYNOPSIS
        Best-effort .map resolution for a representative's top stack frames.
        Adds a 'resolved_top' field on the group; never raises.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Group,
        [Parameter(Mandatory)][string]$MapFile
    )
    if (-not (Test-Path -LiteralPath $MapFile -PathType Leaf)) { return $Group }
    if (-not $Group.PSObject.Properties['representative']) { return $Group }
    $stack = $Group.representative.stack
    if ($null -eq $stack) { return $Group }
    $frames = @($stack)
    if ($frames.Count -eq 0) { return $Group }

    $payload = ($frames | Select-Object -First 5) | ForEach-Object {
        [pscustomobject]@{
            module_name = if ($_.PSObject.Properties['module_name']) { [string]$_.module_name } else { '' }
            rva         = if ($_.PSObject.Properties['rva'])         { [string]$_.rva }         else { '' }
        }
    }
    $framesJson = ($payload | ConvertTo-Json -Depth 4 -Compress)

    $r = Invoke-ChildScript -Script 'map-parser.ps1' -ChildArgs @('-MapFile', $MapFile, '-Frames', $framesJson)
    if ($r.ExitCode -ne 0) {
        Write-AutoFixLog -Level debug -Msg 'map-parser failed' -Ctx @{ exit = $r.ExitCode }
        return $Group
    }
    try {
        $resolved = $r.Stdout | ConvertFrom-Json -Depth 8 -DateKind String
        Add-Member -InputObject $Group -NotePropertyName 'resolved_top' -NotePropertyValue @($resolved) -Force
    } catch { }
    return $Group
}

function Save-ErrorJsonForAi {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)]$Group
    )
    $name = ('ai-input-' + (Get-Sha1Hex -Text $Group.dedup_key) + '.json')
    $path = Join-Path $OutDir $name
    Write-JsonFile -Path $path -Object $Group
    return $path
}

function Apply-DiffInWorktree {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$DiffFile,
        [Parameter(Mandatory)][string]$Worktree
    )
    if (-not (Test-Path -LiteralPath $DiffFile -PathType Leaf)) { return $false }
    $oldLoc = (Get-Location).Path
    try {
        Set-Location -LiteralPath $Worktree
        $check = & git apply --check $DiffFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-AutoFixLog -Level warn -Msg 'git apply --check failed' -Ctx @{ diff = $DiffFile; out = ($check | Out-String).TrimEnd() }
            return $false
        }
        $apply = & git apply $DiffFile 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-AutoFixLog -Level warn -Msg 'git apply failed' -Ctx @{ diff = $DiffFile; out = ($apply | Out-String).TrimEnd() }
            return $false
        }
        return $true
    }
    finally {
        Set-Location -LiteralPath $oldLoc
    }
}

function Get-DiffPreimagePaths {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$DiffFile)
    if (-not (Test-Path -LiteralPath $DiffFile -PathType Leaf)) { return @() }
    $lines = [System.IO.File]::ReadAllLines($DiffFile, [System.Text.UTF8Encoding]::new($false))
    $set = New-Object System.Collections.Generic.HashSet[string]
    foreach ($raw in $lines) {
        if ($raw.StartsWith('--- ')) {
            $p = $raw.Substring(4).Trim()
            if ($p -eq '/dev/null') { continue }
            if ($p.StartsWith('a/') -or $p.StartsWith('b/')) { $p = $p.Substring(2) }
            [void]$set.Add($p)
        }
    }
    return ,@($set)
}

# =============================================================================
# Main
# =============================================================================
$started = Get-Date
$repoRoot = (Resolve-Path -LiteralPath '.').Path
$outDir   = Resolve-OutputDir -Path $OutputDir
$summaryFile = Join-Path $outDir 'iteration-summary.jsonl'

# Worktree branch + path
$stamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$branch = "autofix/$stamp"
$wt = if ($WorktreePath) { $WorktreePath } else {
    Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-wt-$stamp-" + [guid]::NewGuid().ToString('N').Substring(0,8))
}

$exitCode = $Script:AutoFixExit_Generic
$worktreeCreated = $false
$historyByKey = @{}        # dedup_key -> count of unfixed appearances
$ranIterations = 0
$lastResult = 'aborted'

try {
    # ---- Pre-flight: lint gate ----
    if (-not $SkipLint) {
        Write-AutoFixLog -Level info -Msg 'running pre-flight lint gate' -Ctx @{ root = $repoRoot }
        if (-not (Invoke-LintGate -RepoRoot $repoRoot)) {
            $now = Get-AutoFixTimestamp
            Write-Jsonl -Path $summaryFile -Object (
                New-IterationSummary -Iteration 0 -RunIdValue '' `
                    -TsStart $now -TsEnd $now -ExitCodeValue 100 `
                    -ErrorsFound 0 -ErrorsUnique 0 -ErrorsFixed 0 -ErrorsRemaining 0 `
                    -CompileSuccess $false -AiCalls 0 -CacheHits 0 -Rollback $false `
                    -OscillationKeys @() -Result 'abort'
            ) -Append
            $exitCode = $Script:AutoFixExit_BadParams
            return
        }
    } else {
        Write-AutoFixLog -Level warn -Msg 'pre-flight lint gate skipped (-SkipLint)' -Ctx @{}
    }

    # ---- Resolve project / exe / map paths against repo root first ----
    $projectAbs = ConvertTo-AbsoluteIfPossible -Path $Project -BaseDir $repoRoot

    # ---- Create worktree ----
    Write-AutoFixLog -Level info -Msg 'creating isolated worktree' -Ctx @{ branch = $branch; path = $wt }
    $r = Invoke-ChildScript -Script 'git-checkpoint.ps1' -ChildArgs @('-Action', 'create', '-Branch', $branch, '-WorktreePath', $wt)
    if ($r.ExitCode -ne 0) {
        Write-AutoFixLog -Level error -Msg 'worktree create failed' -Ctx @{ exit = $r.ExitCode; stdout = $r.Stdout }
        $exitCode = $Script:AutoFixExit_GitFailed
        return
    }
    $worktreeCreated = $true
    # The script printed the worktree absolute path on stdout; trust it.
    $wtAbs = $r.Stdout.Trim()
    if ($wtAbs -and (Test-Path -LiteralPath $wtAbs -PathType Container)) { $wt = $wtAbs }

    # Recompute project paths against the worktree (the .dproj lives there too).
    $projectInWt = ConvertTo-AbsoluteIfPossible -Path $Project -BaseDir $wt
    $exeInWt     = Resolve-ExePath -ProjectFile $projectInWt -Override $ExePath
    $mapInWt     = Resolve-MapPath -ExeFile $exeInWt -Override $MapPath

    # ---- Main loop ----
    for ($iter = 1; $iter -le $MaxIterations; $iter++) {
        $ranIterations = $iter
        $iterStartTs = Get-AutoFixTimestamp
        $runId = New-AutoFixRunId
        $aiCalls = 0
        $cacheHits = 0
        $errorsFixed = 0
        $rollbackThisIter = $false
        $oscillationKeys = New-Object System.Collections.Generic.List[string]

        Write-AutoFixLog -Level info -Msg ("==== iteration $iter / $MaxIterations ====") -Ctx @{ run_id = $runId }

        # 1. Spawn EXE
        if (-not (Test-Path -LiteralPath $exeInWt -PathType Leaf)) {
            Write-AutoFixLog -Level warn -Msg 'EXE not found; running compiler first' -Ctx @{ exe = $exeInWt }
            $cr = Invoke-ChildScript -Script 'compiler.ps1' -ChildArgs @(
                '-Project', $projectInWt,
                '-OutputJson', (Join-Path $outDir 'compile-errors.json'),
                '-LogFile',    (Join-Path $outDir 'compile.log'))
            if ($cr.ExitCode -eq $Script:AutoFixExit_BdsFailed) {
                Write-AutoFixLog -Level error -Msg 'BDS environment unavailable' -Ctx @{}
                $exitCode = $Script:AutoFixExit_BdsFailed
                return
            }
            if ($cr.ExitCode -ne 0) {
                Write-AutoFixLog -Level error -Msg 'initial compile failed (no fix possible without runnable EXE)' -Ctx @{ exit = $cr.ExitCode }
                Write-Jsonl -Path $summaryFile -Object (
                    New-IterationSummary -Iteration $iter -RunIdValue $runId `
                        -TsStart $iterStartTs -TsEnd (Get-AutoFixTimestamp) `
                        -ExitCodeValue 1 -ErrorsFound 0 -ErrorsUnique 0 `
                        -ErrorsFixed 0 -ErrorsRemaining 0 -CompileSuccess $false `
                        -AiCalls 0 -CacheHits 0 -Rollback $false `
                        -OscillationKeys @() -Result 'abort'
                ) -Append
                $exitCode = $Script:AutoFixExit_Generic
                return
            }
        }

        $rr = Invoke-ChildScript -Script 'runner.ps1' -ChildArgs @(
            '-Exe', $exeInWt,
            '-RunId', $runId,
            '-Iteration', $iter,
            '-Scenarios', $Scenarios,
            '-StartupTimeout', $StartupTimeout,
            '-ScenarioTimeout', $ScenarioTimeout,
            '-OutputDir', $outDir)

        $runnerStatus = $null
        try { $runnerStatus = $rr.Stdout | ConvertFrom-Json -Depth 8 -DateKind String } catch { $runnerStatus = $null }
        $exeExit = if ($runnerStatus -and $runnerStatus.PSObject.Properties['exit_code']) { [int]$runnerStatus.exit_code } else { -1 }
        Write-AutoFixLog -Level info -Msg 'runner returned' -Ctx @{ exit = $rr.ExitCode; exe_exit = $exeExit; status = (if ($runnerStatus) { $runnerStatus.status } else { 'unknown' }) }

        # 2. Read errors filtered by run_id
        $errorsFile = Join-Path $outDir 'runtime-errors.jsonl'
        $errorRecords = @(Read-Jsonl -Path $errorsFile | Where-Object {
            $_ -and $_.PSObject.Properties['run_id'] -and ([string]$_.run_id) -eq $runId
        })

        # 3. WER fallback if exit non-zero and no records yet
        if ($errorRecords.Count -eq 0 -and $exeExit -ne 0) {
            $procPid = if ($runnerStatus -and $runnerStatus.PSObject.Properties['pid']) { [int]$runnerStatus.pid } else { 0 }
            $startedAt = if ($runnerStatus -and $runnerStatus.PSObject.Properties['started_at']) { [string]$runnerStatus.started_at } else { '' }
            $exeName = [System.IO.Path]::GetFileName($exeInWt)
            Write-AutoFixLog -Level info -Msg 'invoking wer-collector for hard-crash fallback' -Ctx @{ pid = $procPid; exit = $exeExit }
            $wer = Invoke-ChildScript -Script 'wer-collector.ps1' -ChildArgs @(
                '-ExeName', $exeName,
                '-ProcessId', $procPid,
                '-ExitCode', $exeExit,
                '-RunId', $runId,
                '-OutputDir', $outDir,
                '-Iteration', $iter,
                '-Scenario', $Scenarios,
                '-StartedAt', $startedAt)
            if ($wer.ExitCode -ne 0) {
                Write-AutoFixLog -Level warn -Msg 'wer-collector failed' -Ctx @{ exit = $wer.ExitCode }
            }
            $errorRecords = @(Read-Jsonl -Path $errorsFile | Where-Object {
                $_ -and $_.PSObject.Properties['run_id'] -and ([string]$_.run_id) -eq $runId
            })
        }

        # 4. Success branch
        if ($errorRecords.Count -eq 0 -and $exeExit -eq 0) {
            Write-AutoFixLog -Level info -Msg 'iteration succeeded with no errors' -Ctx @{ iter = $iter }
            Write-Jsonl -Path $summaryFile -Object (
                New-IterationSummary -Iteration $iter -RunIdValue $runId `
                    -TsStart $iterStartTs -TsEnd (Get-AutoFixTimestamp) `
                    -ExitCodeValue 0 -ErrorsFound 0 -ErrorsUnique 0 `
                    -ErrorsFixed 0 -ErrorsRemaining 0 -CompileSuccess $true `
                    -AiCalls 0 -CacheHits 0 -Rollback $false `
                    -OscillationKeys @() -Result 'success'
            ) -Append
            $lastResult = 'success'
            $exitCode = $Script:AutoFixExit_Ok
            return
        }

        # 5. Dedup
        $groups = @(Get-DedupGroups -ErrorsFile $errorsFile -RunIdValue $runId)
        $groupCount = $groups.Count
        Write-AutoFixLog -Level info -Msg 'dedup grouping' -Ctx @{ raw = $errorRecords.Count; groups = $groupCount }

        # 6. .map resolution (best-effort)
        if (Test-Path -LiteralPath $mapInWt -PathType Leaf) {
            $resolved = New-Object System.Collections.Generic.List[object]
            foreach ($g in $groups) {
                $resolved.Add((Resolve-StackFrames -Group $g -MapFile $mapInWt)) | Out-Null
            }
            $groups = @($resolved.ToArray())
        }

        # 7. Oscillation accounting (Property 14)
        $unfixable = New-Object System.Collections.Generic.HashSet[string]
        foreach ($g in $groups) {
            $k = [string]$g.dedup_key
            if (-not $historyByKey.ContainsKey($k)) { $historyByKey[$k] = 0 }
            $historyByKey[$k]++
            if ($historyByKey[$k] -ge $OscillationThreshold) {
                [void]$unfixable.Add($k)
                if (-not $oscillationKeys.Contains($k)) { $oscillationKeys.Add($k) | Out-Null }
            }
        }
        $candidateGroups = @($groups | Where-Object { -not $unfixable.Contains([string]$_.dedup_key) })
        if ($candidateGroups.Count -eq 0) {
            Write-AutoFixLog -Level error -Msg 'all error groups marked unfixable (oscillation)' -Ctx @{ keys = $oscillationKeys }
            Write-Jsonl -Path $summaryFile -Object (
                New-IterationSummary -Iteration $iter -RunIdValue $runId `
                    -TsStart $iterStartTs -TsEnd (Get-AutoFixTimestamp) `
                    -ExitCodeValue $exeExit -ErrorsFound $errorRecords.Count `
                    -ErrorsUnique $groupCount -ErrorsFixed 0 -ErrorsRemaining $groupCount `
                    -CompileSuccess $false -AiCalls 0 -CacheHits 0 -Rollback $false `
                    -OscillationKeys @($oscillationKeys.ToArray()) -Result 'oscillation'
            ) -Append
            $lastResult = 'oscillation'
            $exitCode = $Script:AutoFixExit_Oscillation
            return
        }

        # 8. Fix loop per group
        $appliedDiffs = New-Object System.Collections.Generic.List[object]
        foreach ($g in $candidateGroups) {
            $key = [string]$g.dedup_key
            $errFile = Save-ErrorJsonForAi -OutDir $outDir -Group $g

            $cl = Invoke-ChildScript -Script 'fix-cache.ps1' -ChildArgs @(
                '-Action', 'lookup', '-Key', $key,
                '-OutputDir', $outDir, '-RepoRoot', $wt)
            $cacheStdout = $cl.Stdout.Trim()
            if ($cl.ExitCode -eq 0 -and $cacheStdout -and $cacheStdout -ne 'miss' -and (Test-Path -LiteralPath $cacheStdout -PathType Leaf)) {
                Write-AutoFixLog -Level info -Msg 'fix-cache hit' -Ctx @{ key = $key; patch = $cacheStdout }
                if (Apply-DiffInWorktree -DiffFile $cacheStdout -Worktree $wt) {
                    $cacheHits++
                    $errorsFixed++
                    $appliedDiffs.Add([pscustomobject]@{ Key = $key; Diff = $cacheStdout; FromCache = $true }) | Out-Null
                }
                continue
            }

            # Cache miss → AI
            $aiCalls++
            $aiRes = Invoke-ChildScript -Script 'ai-call.ps1' -ChildArgs @(
                '-Backend', $AiBackend,
                '-ErrorJson', $errFile,
                '-ContextDir', $wt,
                '-AllowedPaths', $AllowedPaths,
                '-OutputDir', $outDir)
            if ($aiRes.ExitCode -ne 0) {
                Write-AutoFixLog -Level warn -Msg 'ai-call failed for group; skipping' -Ctx @{ key = $key; exit = $aiRes.ExitCode }
                continue
            }
            $diffPath = $aiRes.Stdout.Trim()
            if (-not $diffPath -or -not (Test-Path -LiteralPath $diffPath -PathType Leaf)) {
                Write-AutoFixLog -Level warn -Msg 'ai-call returned no diff path' -Ctx @{ key = $key }
                continue
            }

            # Diff guard
            $guardArgs = New-Object System.Collections.Generic.List[string]
            $guardArgs.Add('-DiffFile') | Out-Null
            $guardArgs.Add($diffPath) | Out-Null
            $guardArgs.Add('-OutputDir') | Out-Null
            $guardArgs.Add($outDir) | Out-Null
            if ($AllowedPathsFile) { $guardArgs.Add('-AllowedPathsFile') | Out-Null; $guardArgs.Add($AllowedPathsFile) | Out-Null }
            if ($AllowedPaths)     { $guardArgs.Add('-AllowedPaths')     | Out-Null; $guardArgs.Add($AllowedPaths)     | Out-Null }
            if ($BlockedPathsFile) { $guardArgs.Add('-BlockedPathsFile') | Out-Null; $guardArgs.Add($BlockedPathsFile) | Out-Null }
            if ($BlockedPaths)     { $guardArgs.Add('-BlockedPaths')     | Out-Null; $guardArgs.Add($BlockedPaths)     | Out-Null }
            $guard = Invoke-ChildScript -Script 'diff-guard.ps1' -ChildArgs @($guardArgs.ToArray())
            if ($guard.ExitCode -ne 0) {
                Write-AutoFixLog -Level warn -Msg 'diff-guard rejected diff' -Ctx @{ key = $key; exit = $guard.ExitCode }
                continue
            }

            if (Apply-DiffInWorktree -DiffFile $diffPath -Worktree $wt) {
                $errorsFixed++
                $appliedDiffs.Add([pscustomobject]@{ Key = $key; Diff = $diffPath; FromCache = $false }) | Out-Null
            }
        }

        # 9. Compile
        $compileResultPath = Join-Path $outDir "compile-errors-iter-$iter.json"
        $compileLogPath    = Join-Path $outDir "compile-iter-$iter.log"
        $compile = Invoke-ChildScript -Script 'compiler.ps1' -ChildArgs @(
            '-Project', $projectInWt,
            '-OutputJson', $compileResultPath,
            '-LogFile', $compileLogPath)
        if ($compile.ExitCode -eq $Script:AutoFixExit_BdsFailed) {
            Write-AutoFixLog -Level error -Msg 'BDS environment unavailable mid-loop' -Ctx @{}
            $exitCode = $Script:AutoFixExit_BdsFailed
            return
        }
        $compileSuccess = ($compile.ExitCode -eq 0)

        # 9b. Single retry if compile failed (feed compile-errors.json to AI)
        if (-not $compileSuccess -and $appliedDiffs.Count -gt 0) {
            Write-AutoFixLog -Level warn -Msg 'compile failed; asking AI for one repair' -Ctx @{ iter = $iter }
            $aiCalls++
            $repair = Invoke-ChildScript -Script 'ai-call.ps1' -ChildArgs @(
                '-Backend', $AiBackend,
                '-ErrorJson', $compileResultPath,
                '-ContextDir', $wt,
                '-AllowedPaths', $AllowedPaths,
                '-OutputDir', $outDir)
            if ($repair.ExitCode -eq 0 -and (Test-Path -LiteralPath ($repair.Stdout.Trim()) -PathType Leaf)) {
                $repairDiff = $repair.Stdout.Trim()
                $guardArgs = New-Object System.Collections.Generic.List[string]
                $guardArgs.AddRange(@('-DiffFile', $repairDiff, '-OutputDir', $outDir))
                if ($AllowedPathsFile) { $guardArgs.AddRange(@('-AllowedPathsFile', $AllowedPathsFile)) }
                if ($AllowedPaths)     { $guardArgs.AddRange(@('-AllowedPaths', $AllowedPaths)) }
                if ($BlockedPathsFile) { $guardArgs.AddRange(@('-BlockedPathsFile', $BlockedPathsFile)) }
                if ($BlockedPaths)     { $guardArgs.AddRange(@('-BlockedPaths', $BlockedPaths)) }
                $guard2 = Invoke-ChildScript -Script 'diff-guard.ps1' -ChildArgs @($guardArgs.ToArray())
                if ($guard2.ExitCode -eq 0 -and (Apply-DiffInWorktree -DiffFile $repairDiff -Worktree $wt)) {
                    $compile2 = Invoke-ChildScript -Script 'compiler.ps1' -ChildArgs @(
                        '-Project', $projectInWt,
                        '-OutputJson', $compileResultPath,
                        '-LogFile', $compileLogPath)
                    $compileSuccess = ($compile2.ExitCode -eq 0)
                }
            } else {
                Write-AutoFixLog -Level warn -Msg 'compile-repair AI call failed' -Ctx @{ exit = $repair.ExitCode }
            }
        }

        # 10. Commit / discard
        if ($compileSuccess -and $appliedDiffs.Count -gt 0) {
            $msg = "autofix: iter $iter — fixed $errorsFixed group(s)"
            $cm = Invoke-ChildScript -Script 'git-checkpoint.ps1' -ChildArgs @(
                '-Action', 'commit', '-WorktreePath', $wt, '-Message', $msg)
            if ($cm.ExitCode -ne 0) {
                Write-AutoFixLog -Level warn -Msg 'commit failed in worktree' -Ctx @{ exit = $cm.ExitCode }
            } else {
                # Cache successful fixes
                foreach ($ad in $appliedDiffs) {
                    if ($ad.FromCache) { continue }   # already cached
                    $preimages = (Get-DiffPreimagePaths -DiffFile $ad.Diff) -join ';'
                    [void](Invoke-ChildScript -Script 'fix-cache.ps1' -ChildArgs @(
                        '-Action', 'store',
                        '-Key', $ad.Key,
                        '-DiffPatch', $ad.Diff,
                        '-PreimageFiles', $preimages,
                        '-AiBackend', $AiBackend,
                        '-IterationSolved', $iter,
                        '-OutputDir', $outDir,
                        '-RepoRoot', $wt))
                }
            }
        } elseif ($appliedDiffs.Count -gt 0) {
            Write-AutoFixLog -Level warn -Msg 'compile failed; discarding worktree changes' -Ctx @{ iter = $iter }
            $rollbackThisIter = $true
            $dis = Invoke-ChildScript -Script 'git-checkpoint.ps1' -ChildArgs @(
                '-Action', 'discard', '-WorktreePath', $wt)
            if ($dis.ExitCode -ne 0) {
                Write-AutoFixLog -Level warn -Msg 'discard failed' -Ctx @{ exit = $dis.ExitCode }
            }
        }

        # 11. Iteration summary
        $iterResult = if ($compileSuccess -and $errorsFixed -gt 0) { 'progress' }
                      elseif ($errorsFixed -eq 0) { 'stalled' }
                      else { 'rollback' }

        Write-Jsonl -Path $summaryFile -Object (
            New-IterationSummary -Iteration $iter -RunIdValue $runId `
                -TsStart $iterStartTs -TsEnd (Get-AutoFixTimestamp) `
                -ExitCodeValue $exeExit -ErrorsFound $errorRecords.Count `
                -ErrorsUnique $groupCount -ErrorsFixed $errorsFixed `
                -ErrorsRemaining ($groupCount - $errorsFixed) `
                -CompileSuccess $compileSuccess -AiCalls $aiCalls `
                -CacheHits $cacheHits -Rollback $rollbackThisIter `
                -OscillationKeys @($oscillationKeys.ToArray()) -Result $iterResult
        ) -Append
        $lastResult = $iterResult
    } # for iter

    # Loop exhausted without success
    Write-AutoFixLog -Level warn -Msg 'max iterations reached without success' -Ctx @{ iters = $ranIterations }
    $exitCode = $Script:AutoFixExit_MaxIter
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'autofix.ps1' }
    if ($lastResult -eq 'aborted') {
        $now = Get-AutoFixTimestamp
        Write-Jsonl -Path $summaryFile -Object (
            New-IterationSummary -Iteration $ranIterations -RunIdValue '' `
                -TsStart $now -TsEnd $now -ExitCodeValue 1 `
                -ErrorsFound 0 -ErrorsUnique 0 -ErrorsFixed 0 -ErrorsRemaining 0 `
                -CompileSuccess $false -AiCalls 0 -CacheHits 0 -Rollback $false `
                -OscillationKeys @() -Result 'abort'
        ) -Append
    }
    $exitCode = $Script:AutoFixExit_Generic
}
finally {
    if ($worktreeCreated) {
        Write-AutoFixLog -Level info -Msg 'cleaning up worktree' -Ctx @{ path = $wt; branch = $branch }
        $cl = Invoke-ChildScript -Script 'git-checkpoint.ps1' -ChildArgs @(
            '-Action', 'cleanup', '-WorktreePath', $wt, '-Branch', $branch)
        if ($cl.ExitCode -ne 0) {
            Write-AutoFixLog -Level warn -Msg 'worktree cleanup non-zero' -Ctx @{ exit = $cl.ExitCode }
        }
    }
    $duration = [int]((Get-Date) - $started).TotalSeconds
    Write-AutoFixLog -Level info -Msg 'autofix.ps1 done' -Ctx @{
        iterations = $ranIterations; result = $lastResult; exit = $exitCode; duration_sec = $duration
    }
}

exit $exitCode
