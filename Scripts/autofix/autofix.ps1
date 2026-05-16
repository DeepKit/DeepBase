param(
    [string]$ProjectName = 'DeepSpec',
    [string]$DprojRelPath = 'DeepSpec.dproj',
    [string]$ExeRelName = 'DeepSpec.exe',
    [string]$Scenarios = 'open-project,scan',
    [int]$MaxIterations = 10,
    [int]$MaxCompileFixAttempts = 2,
    [int]$TimeoutSec = 60,
    [ValidateSet('kiro', 'claude-code', 'aider', 'dry-run')]
    [string]$AIMode = 'kiro'
)
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

. (Join-Path $PSScriptRoot 'autofix-lib.ps1')

# --- Setup paths (GUID for concurrency safety) ---
$guid = [guid]::NewGuid().ToString('N').Substring(0, 8)
$WorktreePath = "$env:TEMP\autofix-$ProjectName-$guid"
$BuildOutPath = "$env:TEMP\autofix-$ProjectName-$guid-build"
$OutputDir    = "$env:TEMP\autofix-$ProjectName-$guid-output"
$branchName   = "autofix/$guid"

New-Item -ItemType Directory -Path $BuildOutPath, $OutputDir -Force | Out-Null

# --- Create worktree ---
Write-Host "Creating worktree: $WorktreePath"
Invoke-Git worktree add -b $branchName $WorktreePath HEAD

try {
    # --- Initial compile ---
    Write-Host 'Initial compile...'
    $cr = Invoke-Compiler -Project $DprojRelPath -WorkDir $WorktreePath `
                          -OutDir $BuildOutPath -ErrorLogDir $OutputDir
    if (-not $cr.Success) {
        Write-Host "✗ Initial compile failed. See: $($cr.LogPath)"
        exit 1
    }

    # Assert worktree clean after compile (A-7)
    $dirty = Invoke-Git -C $WorktreePath status --porcelain
    if ($dirty) {
        throw "Worktree not clean after compile. Fix .gitignore:`n$dirty"
    }

    # --- Oscillation state ---
    $oscillation = @{}
    $consecutiveCrashes = 0

    # --- Main loop ---
    for ($i = 1; $i -le $MaxIterations; $i++) {
        Write-Host "`n=== AutoFix Iteration $i/$MaxIterations ==="

        $runId = [guid]::NewGuid().ToString()
        $baseCommit = Invoke-Git -C $WorktreePath rev-parse HEAD

        # Clean previous output
        'runtime-errors.jsonl', 'health-signal.json', 'scenario-results.jsonl' |
            ForEach-Object { Remove-Item (Join-Path $OutputDir $_) -ErrorAction SilentlyContinue }

        # 1. Run
        $exePath = Join-Path $BuildOutPath $ExeRelName
        $runResult = Invoke-Runner -Exe $exePath -Scenarios $Scenarios `
                                   -Output $OutputDir -Timeout $TimeoutSec -RunId $runId

        # Crash handling
        if ($runResult.Status -in @('crash', 'startup_failed')) {
            $consecutiveCrashes++
            Write-Host "⚠ $($runResult.Status) (consecutive: $consecutiveCrashes)"
            if ($consecutiveCrashes -ge 2) {
                Write-Host '✗ 2 consecutive crashes. Human intervention needed.'
                break
            }
            continue
        }
        $consecutiveCrashes = 0

        if ($runResult.Status -eq 'timeout') {
            Write-Host '⚠ Timeout. Retrying...'
            continue
        }

        # 2. Read results
        $errors = Read-SafeJsonl (Join-Path $OutputDir 'runtime-errors.jsonl') |
                  Where-Object { $_.run_id -eq $runId }
        $scenarioLines = Read-SafeJsonl (Join-Path $OutputDir 'scenario-results.jsonl') |
                         Where-Object { $_.run_id -eq $runId }
        $requestedScenarios = $Scenarios -split ','

        # 3. Success check (A-4)
        $success = Test-FullSuccess -RunResult $runResult -OutputDir $OutputDir `
                                    -RunId $runId -ScenarioLines $scenarioLines `
                                    -Expected $requestedScenarios -Errors $errors
        if ($success) {
            Write-Host "`n✓ All scenarios pass, no errors. AutoFix complete."
            Write-Host "修复分支: $branchName"
            Write-Host "Review 后执行: git merge $branchName --no-ff"
            exit 0
        }

        if ($errors.Count -eq 0) {
            Write-Host '⚠ No errors but scenarios not all pass. Retrying...'
            continue
        }

        # 4. Dedup (simple: group by dedup_key, take first)
        $groups = @{}
        foreach ($err in $errors) {
            $key = $err.dedup_key
            if (-not $groups.ContainsKey($key)) { $groups[$key] = @{ error = $err; count = 0 } }
            $groups[$key].count++
        }
        $sorted = $groups.Values | Sort-Object { $_.count } -Descending
        $topError = $sorted[0].error
        $topError | Add-Member -NotePropertyName 'occurrence_count' -NotePropertyValue $sorted[0].count -Force

        Write-Host "Top error: $($topError.class) at $($topError.module):$($topError.rva) [$($topError.context)] x$($sorted[0].count)"

        # 5. Oscillation check
        $dk = $topError.dedup_key
        if (-not $oscillation.ContainsKey($dk)) { $oscillation[$dk] = 0 }
        $oscillation[$dk]++
        if ($oscillation[$dk] -ge 3) {
            Write-Host "✗ Oscillation: $dk failed 3 times. Stopping."
            break
        }

        # 6. Map resolve (best effort)
        $mapFile = Join-Path $BuildOutPath "$ProjectName.map"
        $sourceHint = ''
        if (Test-Path $mapFile) {
            # Phase 1: just pass map path + RVA to AI
            $sourceHint = "Map file: $mapFile`nRVA: $($topError.rva)"
        }

        # 7. Build prompt
        $prompt = @"
【安全约束 - 不可违反】
- 只修改 src/ 目录内的 .pas/.dfm 文件
- 禁止修改：DeepBase 框架、.dproj、.dpr、脚本、二进制、boundary.json
- 修改必须最小化

【运行时错误】
- 异常类型：$($topError.class)
- 异常消息：$($topError.msg)
- 模块：$($topError.module)
- RVA：$($topError.rva)
- 场景：$($topError.context)
- 出现次数：$($topError.occurrence_count)

【源码定位】
$sourceHint

请修复这个运行时错误，确保编译通过。
"@

        # 8. Call AI
        switch ($AIMode) {
            'dry-run' {
                Write-Host "--- DRY RUN PROMPT ---`n$prompt`n--- END ---"
                Write-Host 'Dry-run mode. Stopping.'
                exit 0
            }
            'kiro' {
                Write-Host "=== 请在 Kiro/IDE 中修复以下错误 ===`n$prompt"
                Write-Host '=== 修复完成后按 Enter 继续 ==='
                Read-Host | Out-Null
            }
            'claude-code' {
                Write-Host 'Calling Claude Code CLI...'
                Push-Location $WorktreePath
                claude -p $prompt --max-turns 3 2>&1 | Out-Null
                Pop-Location
            }
            'aider' {
                Write-Host 'Calling Aider...'
                Push-Location $WorktreePath
                aider --message $prompt --no-auto-commits --yes-always 2>&1 | Out-Null
                Pop-Location
            }
        }

        # 9. Boundary check
        $boundaryOk = Invoke-BoundaryCheck -WorktreePath $WorktreePath -BaseCommit $baseCommit
        if (-not $boundaryOk) {
            Write-Host '✗ Boundary violation. Rolling back.'
            Invoke-WorktreeRollback $WorktreePath $baseCommit
            continue
        }

        # 10. Compile + fix loop
        $compileOk = $false
        for ($c = 1; $c -le $MaxCompileFixAttempts; $c++) {
            $cr = Invoke-Compiler -Project $DprojRelPath -WorkDir $WorktreePath `
                                  -OutDir $BuildOutPath -ErrorLogDir $OutputDir
            if ($cr.Success) { $compileOk = $true; break }
            if ($c -eq $MaxCompileFixAttempts) { break }

            Write-Host "Compile failed ($c/$MaxCompileFixAttempts). AI fixing..."
            $compileErrors = Get-Content $cr.LogPath -Raw -ErrorAction SilentlyContinue
            $compilePrompt = "【安全约束同上】`n`n编译错误：`n$compileErrors`n`n请修复编译错误。"

            switch ($AIMode) {
                'kiro' {
                    Write-Host "编译错误：`n$compileErrors`n按 Enter 继续..."
                    Read-Host | Out-Null
                }
                'claude-code' {
                    Push-Location $WorktreePath
                    claude -p $compilePrompt --max-turns 2 2>&1 | Out-Null
                    Pop-Location
                }
                'aider' {
                    Push-Location $WorktreePath
                    aider --message $compilePrompt --no-auto-commits --yes-always 2>&1 | Out-Null
                    Pop-Location
                }
            }
        }

        if (-not $compileOk) {
            Write-Host '✗ Compile failed. Rolling back.'
            Invoke-WorktreeRollback $WorktreePath $baseCommit
            continue
        }

        # 11. Post-compile boundary check
        $boundaryOk2 = Invoke-BoundaryCheck -WorktreePath $WorktreePath -BaseCommit $baseCommit
        if (-not $boundaryOk2) {
            Write-Host '✗ Post-compile boundary violation. Rolling back.'
            Invoke-WorktreeRollback $WorktreePath $baseCommit
            continue
        }

        # 12. Commit fix
        Invoke-Git -C $WorktreePath add -A
        Invoke-Git -C $WorktreePath commit -m "autofix: iter $i - fix $($topError.class) at $($topError.rva)"
        Write-Host "✓ Committed fix. Rerunning..."
    }

    Write-Host "`n✗ Max iterations reached."
    Write-Host "修复分支: $branchName (部分修复可能已提交)"
    exit 1
}
finally {
    # Cleanup worktree (keep branch for review)
    if (Test-Path $WorktreePath) {
        git worktree remove $WorktreePath --force 2>$null
    }
}
