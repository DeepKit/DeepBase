# ============================================================================
# AutoFix Library - shared functions for all autofix scripts
# Dot-source this file: . (Join-Path $PSScriptRoot 'autofix-lib.ps1')
# ============================================================================

function Read-SafeJsonl([string]$Path) {
    if (-not (Test-Path $Path)) { return @() }
    Get-Content $Path -Encoding UTF8 | Where-Object { $_.Trim() -ne '' } | ForEach-Object {
        try { $_ | ConvertFrom-Json } catch { <# skip malformed line #> }
    }
}

function Invoke-Git {
    <#
    .SYNOPSIS Wrapper that throws on git failure (A-6 compliance)
    #>
    $output = & git @args 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "git $($args -join ' ') failed (exit=$LASTEXITCODE): $output"
    }
    return $output
}

function Invoke-Compiler {
    param(
        [string]$Project,
        [string]$WorkDir,
        [string]$OutDir,
        [string]$ErrorLogDir
    )
    $envBat = 'D:\_Progs\02Business\scripts\env\delphi-13.1.bat'
    $projPath = Join-Path $WorkDir $Project
    $outArgs = "/p:DCC_ExeOutput=`"$OutDir`" /p:DCC_DcuOutput=`"$OutDir\dcu`" /p:DCC_BplOutput=`"$OutDir`" /p:DCC_MapOutput=`"$OutDir`""

    $output = & cmd /c "`"$envBat`" & msbuild `"$projPath`" /t:Build /p:Config=Release /p:Platform=Win64 $outArgs" 2>&1
    $code = $LASTEXITCODE

    if ($code -ne 0) {
        $logPath = Join-Path $ErrorLogDir 'compile-errors.txt'
        $output | Out-File $logPath -Encoding UTF8
        return @{ Success = $false; ExitCode = $code; LogPath = $logPath }
    }
    return @{ Success = $true; ExitCode = 0; LogPath = '' }
}

function Invoke-Runner {
    param(
        [string]$Exe,
        [string]$Scenarios,
        [string]$Output,
        [int]$Timeout,
        [string]$RunId
    )
    $startTime = Get-Date

    # Use ProcessStartInfo to avoid quoting issues
    $psi = [System.Diagnostics.ProcessStartInfo]::new()
    $psi.FileName = $Exe
    $psi.UseShellExecute = $false
    $psi.ArgumentList.Add('--autofix-mode')
    $psi.ArgumentList.Add("--autofix-run-id=$RunId")
    $psi.ArgumentList.Add("--autofix-output=$Output")
    $psi.ArgumentList.Add("--autofix-scenario=$Scenarios")
    $psi.ArgumentList.Add("--autofix-timeout=$Timeout")

    $proc = [System.Diagnostics.Process]::Start($psi)

    # Wait for health signal
    $healthFile = Join-Path $Output 'health-signal.json'
    $healthTimeout = 30
    $elapsed = 0
    while (-not (Test-Path $healthFile) -and $elapsed -lt $healthTimeout) {
        Start-Sleep -Milliseconds 500
        $elapsed += 0.5
        if ($proc.HasExited) { break }
    }

    # Health check
    if (-not (Test-Path $healthFile)) {
        if (-not $proc.HasExited) { $proc.Kill() }
        Reconcile-MissingScenarios -Output $Output -RunId $RunId `
            -Scenarios $Scenarios -Status 'startup_failed'
        return @{ Status = 'startup_failed'; ExitCode = -1 }
    }
    $health = Get-Content $healthFile -Raw | ConvertFrom-Json
    if ($health.run_id -ne $RunId) {
        if (-not $proc.HasExited) { $proc.Kill() }
        Reconcile-MissingScenarios -Output $Output -RunId $RunId `
            -Scenarios $Scenarios -Status 'startup_failed'
        return @{ Status = 'startup_failed'; ExitCode = -1 }
    }

    # Wait for exit
    $exited = $proc.WaitForExit($Timeout * 1000)
    if (-not $exited) {
        $proc.Kill()
        Reconcile-MissingScenarios -Output $Output -RunId $RunId `
            -Scenarios $Scenarios -Status 'timeout'
        return @{ Status = 'timeout'; ExitCode = 3 }
    }

    $exitCode = $proc.ExitCode

    # WER dump check (only after startTime)
    $dumpPath = $null
    $dumpDir = "$env:LOCALAPPDATA\CrashDumps"
    $exeName = [System.IO.Path]::GetFileNameWithoutExtension($Exe)
    if (Test-Path $dumpDir) {
        $recent = Get-ChildItem "$dumpDir\$exeName*.dmp" -ErrorAction SilentlyContinue |
                  Where-Object { $_.LastWriteTime -ge $startTime }
        if ($recent) {
            $dumpPath = Join-Path $Output 'crash-dump.dmp'
            Copy-Item $recent[0].FullName $dumpPath
        }
    }

    if ($dumpPath -or ($exitCode -notin 0..4)) {
        Reconcile-MissingScenarios -Output $Output -RunId $RunId `
            -Scenarios $Scenarios -Status 'crashed'
        return @{ Status = 'crash'; ExitCode = $exitCode; DumpPath = $dumpPath }
    }

    # Reconcile any missing scenario terminal states
    Reconcile-MissingScenarios -Output $Output -RunId $RunId `
        -Scenarios $Scenarios -Status 'crashed'

    return @{ Status = 'normal'; ExitCode = $exitCode }
}

function Reconcile-MissingScenarios {
    param(
        [string]$Output,
        [string]$RunId,
        [string]$Scenarios,
        [string]$Status
    )
    $resultsPath = Join-Path $Output 'scenario-results.jsonl'
    $lines = Read-SafeJsonl $resultsPath | Where-Object { $_.run_id -eq $RunId }
    $requested = $Scenarios -split ','

    foreach ($name in $requested) {
        $last = $lines | Where-Object { $_.name -eq $name } | Select-Object -Last 1
        if (-not $last -or $last.status -eq 'running') {
            $entry = @{ run_id = $RunId; name = $name; status = $Status; ts = (Get-Date -Format 'o') }
            $entry | ConvertTo-Json -Compress -Depth 5 |
                Out-File $resultsPath -Append -Encoding UTF8
        }
    }
}

function Test-ScenarioSuccess([array]$Lines, [string[]]$Expected) {
    foreach ($name in $Expected) {
        $terminal = $Lines | Where-Object {
            $_.name -eq $name -and $_.status -in @('pass','fail','fatal','crashed','timeout','startup_failed')
        } | Select-Object -Last 1
        if (-not $terminal -or $terminal.status -ne 'pass') { return $false }
    }
    return $true
}

function Test-FullSuccess($RunResult, $OutputDir, $RunId, $ScenarioLines, $Expected, $Errors) {
    if ($RunResult.Status -ne 'normal') { return $false }
    if ($RunResult.ExitCode -ne 0) { return $false }
    if ($Errors.Count -ne 0) { return $false }
    return (Test-ScenarioSuccess -Lines $ScenarioLines -Expected $Expected)
}

function Invoke-BoundaryCheck {
    param(
        [string]$WorktreePath,
        [string]$BaseCommit
    )
    # Read boundary from trusted baseline (A-5: fail-closed)
    $configContent = Invoke-Git -C $WorktreePath show "${BaseCommit}:.deepspec/autofix/boundary.json" 2>$null
    if (-not $configContent) {
        Write-Host '✗ boundary.json not found at base commit. Stopping (fail-closed).'
        return $false
    }
    $config = ($configContent -join "`n") | ConvertFrom-Json

    # Hard-blocked (cannot be overridden by config)
    $hardBlocked = @('boundary.json', '*.ps1', '*.bat', '*.cmd')

    # All changes: tracked + untracked
    $tracked = @(Invoke-Git -C $WorktreePath diff --name-only $BaseCommit)
    $untracked = @(Invoke-Git -C $WorktreePath ls-files --others --exclude-standard)
    $all = @($tracked) + @($untracked) | Where-Object { $_ }

    if ($all.Count -eq 0) { return $true }

    foreach ($file in $all) {
        # Hard block
        foreach ($hp in $hardBlocked) {
            if ($file -like $hp -or $file.EndsWith($hp.TrimStart('*'))) {
                Write-Host "✗ HARD-BLOCKED: $file"
                return $false
            }
        }
        # Config blocked
        foreach ($p in $config.blocked_paths) {
            if (Test-PathPattern $file $p) {
                Write-Host "✗ BLOCKED: $file (pattern: $p)"
                return $false
            }
        }
        # Config allowed
        $allowed = $false
        foreach ($p in $config.allowed_paths) {
            if (Test-PathPattern $file $p) { $allowed = $true; break }
        }
        if (-not $allowed) {
            Write-Host "✗ NOT ALLOWED: $file"
            return $false
        }
    }

    # Line count check
    $totalLines = 0
    if ($tracked) {
        Invoke-Git -C $WorktreePath diff --numstat $BaseCommit | ForEach-Object {
            if ($_ -match '^(\d+)\s+(\d+)') { $totalLines += [int]$Matches[1] + [int]$Matches[2] }
        }
    }
    foreach ($f in $untracked) {
        $fp = Join-Path $WorktreePath $f
        if (Test-Path $fp) { $totalLines += (Get-Content $fp).Count }
    }
    $maxLines = if ($config.max_diff_lines) { $config.max_diff_lines } else { 200 }
    if ($totalLines -gt $maxLines) {
        Write-Host "✗ $totalLines lines > max $maxLines"
        return $false
    }

    Write-Host "✓ Boundary OK: $($all.Count) files, $totalLines lines"
    return $true
}

function Test-PathPattern([string]$File, [string]$Pattern) {
    if ($Pattern.EndsWith('/')) { return $File.StartsWith($Pattern) -or $File.StartsWith($Pattern.TrimEnd('/') + '\') }
    if ($Pattern.StartsWith('*')) { return $File -like $Pattern }
    return $File -eq $Pattern -or $File.StartsWith("$Pattern/") -or $File.StartsWith("$Pattern\")
}

function Invoke-WorktreeRollback([string]$Path, [string]$BaseCommit) {
    Invoke-Git -C $Path restore --staged --worktree .
    Invoke-Git -C $Path clean -fd
    $current = Invoke-Git -C $Path rev-parse HEAD
    if ($current -ne $BaseCommit) {
        Invoke-Git -C $Path reset --hard $BaseCommit
    }
}
