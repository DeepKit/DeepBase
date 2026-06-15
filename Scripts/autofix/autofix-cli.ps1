#!/usr/bin/env pwsh
#requires -Version 7.0
# =============================================================================
# DeepBase AutoFix CLI
# =============================================================================
# Standalone command-line wrapper for the AutoFix framework.
# Delegates to existing Scripts/autofix/*.ps1 scripts — no logic duplication.
#
# Usage:
#   autofix-cli.ps1 init   <project.dproj> [--force]
#   autofix-cli.ps1 wire   <project.dproj>
#   autofix-cli.ps1 run    [project.dproj] [-s <scenarios>] [-n 10] [-b cli]
#   autofix-cli.ps1 check  [project.dproj] [-s <scenarios>]
#   autofix-cli.ps1 status [output-dir]
#
# When .dproj is omitted, auto-detects the only .dproj in cwd.
# When -s is omitted, discovers scenarios from .dpr and prompts for selection.
# =============================================================================

. "$PSScriptRoot/_common.ps1"

# =============================================================================
# Argument Parsing
# =============================================================================

$Command = ''
$CmdArgs = @()

if ($args.Count -gt 0) {
    $Command = $args[0]
    if ($args.Count -gt 1) {
        $CmdArgs = @($args[1..($args.Count - 1)])
    }
}

# =============================================================================
# Helpers
# =============================================================================

function Get-NamedArg {
    param(
        [string[]]$ArgList = @(),
        [Parameter(Mandatory)][string]$Name,
        [string]$Default = ''
    )
    for ($i = 0; $i -lt $ArgList.Count; $i++) {
        if ($ArgList[$i] -eq "-$Name" -or $ArgList[$i] -eq "--$Name") {
            if ($i + 1 -lt $ArgList.Count) { return $ArgList[$i + 1] }
        }
        if ($Name -eq 'scenario' -and $ArgList[$i] -eq '-s') {
            if ($i + 1 -lt $ArgList.Count) { return $ArgList[$i + 1] }
        }
        if ($Name -eq 'max-iter' -and $ArgList[$i] -eq '-n') {
            if ($i + 1 -lt $ArgList.Count) { return $ArgList[$i + 1] }
        }
        if ($Name -eq 'backend' -and $ArgList[$i] -eq '-b') {
            if ($i + 1 -lt $ArgList.Count) { return $ArgList[$i + 1] }
        }
    }
    return $Default
}

function Test-SwitchArg {
    param(
        [string[]]$ArgList = @(),
        [Parameter(Mandatory)][string]$Name
    )
    if ($null -eq $ArgList -or $ArgList.Count -eq 0) { return $false }
    return $ArgList -contains "-$Name" -or $ArgList -contains "--$Name"
}

function Get-PositionalArg {
    param(
        [string[]]$ArgList = @(),
        [int]$Index = 0
    )
    if ($null -eq $ArgList -or $ArgList.Count -eq 0) { return '' }
    $pos = 0
    foreach ($a in $ArgList) {
        # Skip flags: --name or -name (letter-based), but not negative numbers like -1
        if ($a -match '^-+[a-zA-Z]') { continue }
        if ($pos -eq $Index) { return $a }
        $pos++
    }
    return ''
}

function Resolve-ProjectInfo {
    <#
    .SYNOPSIS
        Parse a .dproj path into project metadata.
    #>
    param([Parameter(Mandatory)][string]$DprojPath)

    if (-not (Test-Path -LiteralPath $DprojPath -PathType Leaf)) {
        throw "Project file not found: $DprojPath"
    }

    $absolute = (Resolve-Path -LiteralPath $DprojPath).Path
    $dir = Split-Path -Parent $absolute
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($absolute)

    $mainSource = "$stem.dpr"
    $exeOutputDir = ''
    try {
        $xml = [xml](Get-Content -LiteralPath $absolute -Raw -Encoding UTF8)
        $ns = New-Object System.Xml.XmlNamespaceManager($xml.NameTable)
        $ns.AddNamespace('msb', 'http://schemas.microsoft.com/developer/msbuild/2003')
        $node = $xml.SelectSingleNode('//msb:MainSource', $ns)
        if ($node -and -not [string]::IsNullOrWhiteSpace($node.InnerText)) {
            $fromProj = $node.InnerText.Trim()
            # Fallback: if MainSource .dpr doesn't exist, use stem-matched .dpr
            if (Test-Path -LiteralPath (Join-Path $dir $fromProj) -PathType Leaf) {
                $mainSource = $fromProj
            }
        }
        # Try to read DCC_ExeOutput from any property group
        $exeOut = $xml.SelectSingleNode('//msb:DCC_ExeOutput', $ns)
        if ($exeOut -and -not [string]::IsNullOrWhiteSpace($exeOut.InnerText)) {
            $exeOutputDir = $exeOut.InnerText.Trim()
        }
    } catch {
        Write-Host "Warning: could not parse dproj XML ($($_.Exception.Message))"
    }

    # Compute default EXE path
    $exeDir = if ($exeOutputDir) {
        [System.IO.Path]::GetFullPath([System.IO.Path]::Combine($dir, $exeOutputDir))
    } else {
        [System.IO.Path]::Combine($dir, 'Win64', 'Debug')
    }
    $exePath = Join-Path $exeDir "$stem.exe"

    return [pscustomobject]@{
        DprojPath    = $absolute
        ProjectDir   = $dir
        Stem         = $stem
        DprPath      = Join-Path $dir $mainSource
        MainSource   = $mainSource
        ExePath      = $exePath
        ExeOutputDir = $exeOutputDir
    }
}

function Get-SourceDirectories {
    param([Parameter(Mandatory)][string]$ProjectDir)

    $exclude = [System.Collections.Generic.HashSet[string]]::new(
        [string[]]@('bin', 'dcu', 'Debug', 'Release', '__history', '__recovery',
                     '.git', '.vs', '.idea', '.claude', '.kiro', 'node_modules',
                     'DeepBase', 'DeepBaseCore', 'autofix-output', 'TestResults'),
        [System.StringComparer]::OrdinalIgnoreCase
    )

    # Single pass: find all .pas files, collect unique parent directories
    $dirSet = [System.Collections.Generic.HashSet[string]]::new()
    foreach ($pasFile in (Get-ChildItem -LiteralPath $ProjectDir -Filter '*.pas' -File -Recurse -Depth 3 -ErrorAction SilentlyContinue)) {
        $parentDir = $pasFile.Directory
        # Walk up to depth 2 from project root, check exclusions at each level
        $rel = [System.IO.Path]::GetRelativePath($ProjectDir, $parentDir.FullName)
        $parts = $rel -split '[\\/]'
        $skip = $false
        foreach ($p in $parts) {
            if ($exclude.Contains($p)) { $skip = $true; break }
        }
        if (-not $skip) {
            $dirSet.Add(($rel.Replace('\', '/') + '/')) | Out-Null
        }
    }

    $dirs = @($dirSet | Sort-Object)
    return $dirs
}

# =============================================================================
# Auto-discovery helpers
# =============================================================================

function Find-ProjectDproj {
    <#
    .SYNOPSIS
        Find a .dproj in the current directory (or let user pick if multiple).
    #>
    $candidates = @(Get-ChildItem -LiteralPath (Get-Location) -Filter '*.dproj' -File -ErrorAction SilentlyContinue)
    if ($candidates.Count -eq 0) {
        Write-Host "No .dproj found in current directory."
        Write-Host "Run 'autofix init <project.dproj>' first, or cd into the project directory."
        exit $AutoFixExit_BadParams
    }
    if ($candidates.Count -eq 1) {
        return $candidates[0].FullName
    }
    Write-Host "Multiple .dproj found:"
    for ($i = 0; $i -lt $candidates.Count; $i++) {
        Write-Host "  [$($i + 1)] $($candidates[$i].Name)"
    }
    $choice = Read-Host 'Select project (number)'
    $idx = 0
    if (-not [int]::TryParse($choice, [ref]$idx) -or $idx -lt 1 -or $idx -gt $candidates.Count) {
        Write-Host "Invalid selection."
        exit $AutoFixExit_BadParams
    }
    return $candidates[$idx - 1].FullName
}

function Find-Scenarios {
    <#
    .SYNOPSIS
        Extract RegisterScenario names from a .dpr file.
    #>
    param([Parameter(Mandatory)][string]$DprPath)

    if (-not (Test-Path -LiteralPath $DprPath -PathType Leaf)) { return @() }
    $enc = [System.Text.UTF8Encoding]::new($false)
    $content = [System.IO.File]::ReadAllText($DprPath, $enc)
    $matches = [regex]::Matches($content,
        "RegisterScenario\s*\(\s*'([^']+)'",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)
    return @($matches | ForEach-Object { $_.Groups[1].Value })
}

function Select-Scenarios {
    <#
    .SYNOPSIS
        Show scenario list, let user pick. Returns comma-separated scenario names.
    #>
    param([Parameter(Mandatory)][string[]]$Available)

    if ($Available.Count -eq 0) {
        Write-Host "No scenarios found. Add one with:"
        Write-Host "  AutoFix.RegisterScenario('smoke', procedure begin ... end);"
        exit $AutoFixExit_BadParams
    }
    if ($Available.Count -eq 1) {
        Write-Host "  Scenario: $($Available[0]) (only one, auto-selected)"
        return $Available[0]
    }
    Write-Host "Scenarios:"
    for ($i = 0; $i -lt $Available.Count; $i++) {
        Write-Host "  [$($i + 1)] $($Available[$i])"
    }
    Write-Host "  [A] all ($($Available.Count) scenarios)"
    $choice = Read-Host 'Select'
    $trimmed = $choice.Trim()
    if ($trimmed -match '^[aA]$') {
        $all = $Available -join ','
        Write-Host "  -> $($Available.Count) scenarios selected: $all"
        return $all
    }
    $selected = New-Object System.Collections.Generic.List[string]
    foreach ($part in ($trimmed -split '[,\s]+')) {
        $idx = 0
        if ([int]::TryParse($part, [ref]$idx) -and $idx -ge 1 -and $idx -le $Available.Count) {
            $selected.Add($Available[$idx - 1]) | Out-Null
        }
    }
    if ($selected.Count -eq 0) {
        Write-Host "Invalid selection."
        exit $AutoFixExit_BadParams
    }
    $result = ($selected -join ',')
    Write-Host "  -> $($selected.Count) scenario(ies) selected: $result"
    return $result
}

function Invoke-AutoFixChild {
    <#
    .SYNOPSIS
        Run a sibling .ps1 script, capture stdout and exit code.
        Stderr is written through to the console, not merged into stdout.
    #>
    param(
        [Parameter(Mandatory)][string]$Script,
        [Parameter(Mandatory)][string[]]$ChildArgs
    )
    $path = Join-Path $PSScriptRoot $Script
    if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {
        throw "Script not found: $path"
    }
    $oldPref = $ErrorActionPreference
    $ErrorActionPreference = 'Continue'
    try {
        $stdout = & pwsh -NoProfile -NoLogo -NonInteractive -File $path @ChildArgs
        $rc = $LASTEXITCODE
    } catch {
        Write-Host "Error launching $Script : $($_.Exception.Message)"
        return [pscustomobject]@{ Stdout = @(); ExitCode = $AutoFixExit_Generic }
    } finally {
        $ErrorActionPreference = $oldPref
    }
    # Normalize stdout: ensure it is always a string array
    if ($null -eq $stdout) { $stdout = @() }
    elseif ($stdout -isnot [array]) { $stdout = @($stdout.ToString()) }
    else { $stdout = @($stdout | ForEach-Object { $_.ToString() }) }
    return [pscustomobject]@{ Stdout = $stdout; ExitCode = $rc }
}

# =============================================================================
# Command: status
# =============================================================================

function Invoke-AutoFixStatus {
    param([string[]]$CmdArgs)

    $jsonMode = Test-SwitchArg -ArgList $CmdArgs -Name 'json'
    $outDir = Get-PositionalArg -ArgList $CmdArgs -Index 0
    if ([string]::IsNullOrEmpty($outDir)) { $outDir = 'autofix-output' }

    if (-not (Test-Path -LiteralPath $outDir)) {
        if ($jsonMode) {
            [Console]::Out.WriteLine((ConvertTo-Json -Compress -Depth 4 ([pscustomobject]@{ ok = $false; error = 'output_dir_not_found'; output_dir = $outDir })))
        } else {
            Write-Host "Output directory not found: $outDir"
        }
        exit $AutoFixExit_BadParams
    }
    $outDir = (Resolve-Path -LiteralPath $outDir).Path

    # --- Iteration summary ---
    $summaryFile = Join-Path $outDir 'iteration-summary.jsonl'
    $summaries = Read-Jsonl -Path $summaryFile
    if ($summaries.Count -eq 0) {
        if ($jsonMode) {
            [Console]::Out.WriteLine((ConvertTo-Json -Compress -Depth 4 ([pscustomobject]@{ ok = $true; output_dir = $outDir; summaries = @(); last = $null })))
        } else {
            Write-Host "AutoFix Status: $outDir"
            Write-Host ('=' * 60)
            Write-Host "No iteration summary found. Run 'autofix run' first."
        }
        return
    }

    $last = $summaries[$summaries.Count - 1]
    $scenarioFile = Join-Path $outDir 'scenario-results.jsonl'
    $scenarios = @(Read-Jsonl -Path $scenarioFile)
    $errorsFile = Join-Path $outDir 'runtime-errors.jsonl'
    $errors = @(Read-Jsonl -Path $errorsFile)
    if (-not $jsonMode) {
    Write-Host "AutoFix Status: $outDir"
    Write-Host ('=' * 60)
    Write-Host ""
    Write-Host "Last Iteration (#$($last.iteration)):"
    Write-Host "  Result:    $($last.result)"
    if ($last.PSObject.Properties['duration_sec']) {
        Write-Host "  Duration:  $($last.duration_sec)s"
    }
    if ($last.PSObject.Properties['exit_code']) {
        Write-Host "  Exit Code: $($last.exit_code)"
    }
    if ($last.PSObject.Properties['errors_found']) {
        $fixed = if ($last.PSObject.Properties['errors_fixed']) { $last.errors_fixed } else { '?' }
        $remaining = if ($last.PSObject.Properties['errors_remaining']) { $last.errors_remaining } else { '?' }
        Write-Host "  Errors:    $($last.errors_found) found, $fixed fixed, $remaining remaining"
    }
    if ($last.PSObject.Properties['compile_success']) {
        Write-Host "  Compile:   $(if ($last.compile_success) { 'OK' } else { 'FAILED' })"
    }

    Write-Host ""
    Write-Host "Total Iterations: $($summaries.Count)"
    $groups = $summaries | Group-Object -Property result -NoElement
    foreach ($g in $groups) { Write-Host "  $($g.Name): $($g.Count)" }

    # --- Scenario results ---
    $terminals = @($scenarios | Where-Object {
        $_.status -in @('pass', 'fail', 'fatal', 'timeout', 'crashed', 'startup_failed')
    })
    if ($terminals.Count -gt 0) {
        Write-Host ""
        Write-Host "Scenario Results (last run):"
        $byName = $terminals | Group-Object -Property name
        foreach ($g in $byName) {
            $s = $g.Group[$g.Count - 1]
            $icon = switch ($s.status) {
                'pass'  { '  [PASS]' }
                'fail'  { '  [FAIL]' }
                'fatal' { '  [FATAL]' }
                default { "  [$($s.status.ToUpper())]" }
            }
            Write-Host "$icon $($s.name)"
        }
    }

    # --- Runtime errors ---
    if ($errors.Count -gt 0) {
        Write-Host ""
        Write-Host "Runtime Errors: $($errors.Count) total"
        $byLevel = $errors | Group-Object -Property level
        foreach ($g in $byLevel) { Write-Host "  $($g.Name): $($g.Count)" }

        $topClasses = $errors | Group-Object -Property class -NoElement |
            Sort-Object Count -Descending | Select-Object -First 5
        if ($topClasses.Count -gt 0) {
            Write-Host "  Top error classes:"
            foreach ($g in $topClasses) { Write-Host "    $($g.Name): $($g.Count)" }
        }
    }
    } else {
        $terminalScenarios = @($scenarios | Where-Object { $_.status -in @('pass', 'fail', 'fatal', 'timeout', 'crashed', 'startup_failed') })
        [Console]::Out.WriteLine((ConvertTo-Json -Compress -Depth 8 ([pscustomobject]@{
            ok = $true
            output_dir = $outDir
            last = $last
            total_iterations = $summaries.Count
            result_counts = @($summaries | Group-Object -Property result -NoElement | ForEach-Object { [pscustomobject]@{ result = $_.Name; count = $_.Count } })
            scenarios = @($terminalScenarios)
            runtime_error_count = $errors.Count
            runtime_error_levels = @($errors | Group-Object -Property level -NoElement | ForEach-Object { [pscustomobject]@{ level = $_.Name; count = $_.Count } })
        })))
    }
}

# =============================================================================
# Command: init
# =============================================================================

function Invoke-AutoFixInit {
    param([string[]]$CmdArgs)

    $dproj = Get-PositionalArg -ArgList $CmdArgs -Index 0
    if ([string]::IsNullOrEmpty($dproj)) {
        Write-Host "Usage: autofix init <project.dproj> [--force]"
        exit $AutoFixExit_BadParams
    }

    $force = Test-SwitchArg -ArgList $CmdArgs -Name 'force'
    $info = Resolve-ProjectInfo -DprojPath $dproj

    Write-Host "AutoFix Init: $($info.Stem)"
    Write-Host ('=' * 60)

    # --- boundary.json ---
    $boundaryPath = Join-Path $info.ProjectDir 'boundary.json'

    if ((Test-Path -LiteralPath $boundaryPath) -and -not $force) {
        Write-Host "boundary.json already exists: $boundaryPath"
        Write-Host "Use --force to overwrite."
    } else {
        # Backup existing boundary.json before overwrite
        if ($force -and (Test-Path -LiteralPath $boundaryPath)) {
            $backupPath = "$boundaryPath.bak"
            Copy-Item -LiteralPath $boundaryPath -Destination $backupPath -Force
            Write-Host "Backed up: $backupPath"
        }

        $sourceDirs = @(Get-SourceDirectories -ProjectDir $info.ProjectDir)
        if ($sourceDirs.Count -eq 0) { $sourceDirs = @('./') }

        $boundary = [ordered]@{
            allowed_paths      = $sourceDirs
            blocked_paths      = @(
                'DeepBase/', '*.dproj', '*.dpr',
                '*.ps1', '*.bat', '*.cmd',
                '*.exe', '*.dll', '*.bpl',
                '*.dcu', '*.res',
                'bin/', 'dcu/', 'boundary.json'
            )
            max_changed_files  = 5
            max_diff_lines     = 200
        }

        # Write to temp file first, then move (near-atomic on most filesystems)
        $tmpPath = "$boundaryPath.tmp"
        try {
            Write-JsonFile -Path $tmpPath -Object $boundary
            Move-Item -LiteralPath $tmpPath -Destination $boundaryPath -Force
        } catch {
            if (Test-Path -LiteralPath $tmpPath) { Remove-Item -LiteralPath $tmpPath -Force }
            throw
        }
        Write-Host "Generated: $boundaryPath"
        Write-Host "  Allowed: $($boundary.allowed_paths -join ', ')"
    }

    # --- Wiring snippet (detect framework) ---
    $isFmx = $false
    if (Test-Path -LiteralPath $info.DprPath -PathType Leaf) {
        $dprContent = [System.IO.File]::ReadAllText($info.DprPath, [System.Text.UTF8Encoding]::new($false))
        $isFmx = $dprContent -match '\bFMX\b'
    }
    # VclHook lives under DeepBase/VCL/ — search common relative positions from project dir
    $vclHookPath = @(
        (Join-Path $info.ProjectDir '../DeepBase/VCL/DeepBase.AutoFix.VclHook.pas'),
        (Join-Path $info.ProjectDir '../../DeepBase/VCL/DeepBase.AutoFix.VclHook.pas'),
        (Join-Path $info.ProjectDir 'DeepBase/VCL/DeepBase.AutoFix.VclHook.pas')
    ) | Where-Object { Test-Path -LiteralPath $_ -PathType Leaf } | Select-Object -First 1
    $hasVclHook = [bool]$vclHookPath

    Write-Host ""
    Write-Host "Add to $($info.MainSource):"
    Write-Host ('-' * 40)
    Write-Host "  // Framework: $(if ($isFmx) { 'FMX' } else { 'VCL' })"
    Write-Host "  // In the 'uses' clause, add:"
    Write-Host "    DeepBase.AutoFix,"
    if (-not $isFmx -and $hasVclHook) {
        Write-Host "    DeepBase.AutoFix.VclHook,"
    }
    Write-Host ""
    Write-Host "  // After 'begin', before Application.Initialize:"
    Write-Host "    AutoFix.Install;"
    if (-not $isFmx -and $hasVclHook) {
        Write-Host "    TAutoFixVclHook.Install;"
    }
    Write-Host ""
    Write-Host "  // Register scenarios (any time after Install):"
    Write-Host "    AutoFix.RegisterScenario('smoke',"
    Write-Host "      procedure"
    Write-Host "      begin"
    Write-Host "        // your smoke test logic"
    Write-Host "      end);"
    Write-Host ""
    Write-Host "  // In main form DoShow or AfterShow:"
    Write-Host "    AutoFix.NotifyShellShown;"
    Write-Host ""
    Write-Host "Or run: autofix wire $($info.DprojPath)"
}

# =============================================================================
# Command: run
# =============================================================================

function Invoke-AutoFixRun {
    param([string[]]$CmdArgs)

    # --- Resolve project ---
    $dproj = Get-PositionalArg -ArgList $CmdArgs -Index 0
    if ([string]::IsNullOrEmpty($dproj)) {
        $dproj = Find-ProjectDproj
    }

    $maxIter   = Get-NamedArg -ArgList $CmdArgs -Name 'max-iter' -Default '10'
    $backend   = Get-NamedArg -ArgList $CmdArgs -Name 'backend' -Default 'cli'
    $timeout   = Get-NamedArg -ArgList $CmdArgs -Name 'timeout' -Default '600'
    $outputDir = Get-NamedArg -ArgList $CmdArgs -Name 'output'  -Default 'autofix-output'
    $exeOverride  = Get-NamedArg -ArgList $CmdArgs -Name 'exe'
    $startupWait  = Get-NamedArg -ArgList $CmdArgs -Name 'startup-timeout'
    $oscWindow    = Get-NamedArg -ArgList $CmdArgs -Name 'oscillation-window'
    $oscThreshold = Get-NamedArg -ArgList $CmdArgs -Name 'oscillation-threshold'
    $skipLint     = Test-SwitchArg -ArgList $CmdArgs -Name 'skip-lint'
    $allowExternalAi = Test-SwitchArg -ArgList $CmdArgs -Name 'allow-external-ai'

    # --- Resolve scenarios ---
    $scenarios = Get-NamedArg -ArgList $CmdArgs -Name 'scenario' -Default ''
    if (-not [string]::IsNullOrWhiteSpace($scenarios)) {
        $scenarios = ($scenarios -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ }) -join ','
    }

    $info = Resolve-ProjectInfo -DprojPath $dproj

    if ([string]::IsNullOrWhiteSpace($scenarios)) {
        Write-Host "AutoFix: $($info.Stem)"
        $available = Find-Scenarios -DprPath $info.DprPath
        $scenarios = Select-Scenarios -Available $available
    }

    Write-Host "AutoFix Run: $($info.Stem) | Scenarios: $scenarios"
    Write-Host ('=' * 60)

    # Read boundary.json
    $boundaryPath = Join-Path $info.ProjectDir 'boundary.json'
    $afArgs = @(
        '-Project', $info.DprojPath,
        '-Scenarios', $scenarios,
        '-MaxIterations', $maxIter,
        '-ScenarioTimeout', $timeout,
        '-AiBackend', $backend,
        '-OutputDir', $outputDir
    )

    # Forward optional overrides
    if ($exeOverride)         { $afArgs += @('-ExePath', $exeOverride) }
    elseif ($info.ExePath)    { $afArgs += @('-ExePath', $info.ExePath) }
    if ($startupWait)         { $afArgs += @('-StartupTimeout', $startupWait) }
    if ($oscWindow)           { $afArgs += @('-OscillationWindow', $oscWindow) }
    if ($oscThreshold)        { $afArgs += @('-OscillationThreshold', $oscThreshold) }
    if ($skipLint)            { $afArgs += '-SkipLint' }
    if ($allowExternalAi)     { $afArgs += '-AllowExternalAi' }

    if (Test-Path -LiteralPath $boundaryPath) {
        $boundary = Read-JsonFile -Path $boundaryPath
        if ($boundary.PSObject.Properties['allowed_paths'] -and $boundary.allowed_paths -and
            $boundary.allowed_paths.Count -gt 0) {
            $afArgs += @('-AllowedPaths', ($boundary.allowed_paths -join ';'))
        } else {
            Write-Host "Warning: boundary.json has empty allowed_paths — diff guard may reject all patches."
        }
        if ($boundary.PSObject.Properties['blocked_paths'] -and $boundary.blocked_paths -and
            $boundary.blocked_paths.Count -gt 0) {
            $afArgs += @('-BlockedPaths', ($boundary.blocked_paths -join ';'))
        }
        if ($boundary.PSObject.Properties['max_diff_lines'] -and $boundary.max_diff_lines) {
            $afArgs += @('-MaxDiffLines', [string]$boundary.max_diff_lines)
        }
        if ($boundary.PSObject.Properties['max_changed_files'] -and $boundary.max_changed_files) {
            $afArgs += @('-MaxChangedFiles', [string]$boundary.max_changed_files)
        }
        Write-Host "Loaded boundary.json"
    } else {
        Write-Host "Error: boundary.json not found. Run 'autofix init <project.dproj>' first."
        exit $AutoFixExit_BadParams
    }

    # Delegate to autofix.ps1
    Write-Host "Starting fix loop (max $maxIter iterations)..."
    Write-Host ""

    $autofixScript = Join-Path $PSScriptRoot 'autofix.ps1'
    & pwsh -NoProfile -NoLogo -NonInteractive -File $autofixScript @afArgs
    $exitCode = $LASTEXITCODE

    # Print summary (wrapped in try/catch to never override the real exit code)
    try {
        Write-Host ""
        Write-Host ('=' * 60)
        $resolvedOutput = if (Test-Path -LiteralPath $outputDir) {
            (Resolve-Path -LiteralPath $outputDir).Path
        } else { $outputDir }

        $summaryFile = Join-Path $resolvedOutput 'iteration-summary.jsonl'
        if (Test-Path -LiteralPath $summaryFile) {
            $summaries = @(Read-Jsonl -Path $summaryFile)
            if ($summaries.Count -gt 0) {
                $last = $summaries[$summaries.Count - 1]
                $fixed = if ($last.PSObject.Properties['errors_fixed']) { $last.errors_fixed } else { '?' }
                $remaining = if ($last.PSObject.Properties['errors_remaining']) { $last.errors_remaining } else { '?' }
                Write-Host "Result: $($last.result) | Iterations: $($last.iteration) | Fixed: $fixed | Remaining: $remaining"
            }
        }
    } catch {
        Write-Host "Warning: could not read summary: $($_.Exception.Message)"
    }

    exit $exitCode
}

# =============================================================================
# Command: check
# =============================================================================

function Invoke-AutoFixCheck {
    param([string[]]$CmdArgs)

    # --- Resolve project ---
    $dproj = Get-PositionalArg -ArgList $CmdArgs -Index 0
    if ([string]::IsNullOrEmpty($dproj)) {
        $dproj = Find-ProjectDproj
    }

    $scenarios = Get-NamedArg -ArgList $CmdArgs -Name 'scenario' -Default ''
    $info = Resolve-ProjectInfo -DprojPath $dproj

    Write-Host "AutoFix Check: $($info.Stem)"
    Write-Host ('=' * 60)

    # --- Compile ---
    $compileOutput = Join-Path $info.ProjectDir 'autofix-output' 'compile-errors.json'
    Write-Host "Compiling..."

    $result = Invoke-AutoFixChild -Script 'compiler.ps1' -ChildArgs @(
        '-Project', $info.DprojPath,
        '-OutputJson', $compileOutput
    )

    if ($result.ExitCode -eq 0) {
        Write-Host "  Compile: OK"
    } else {
        Write-Host "  Compile: FAILED (exit $($result.ExitCode))"
        $shownErrors = $false
        if (Test-Path -LiteralPath $compileOutput) {
            $cr = Read-JsonFile -Path $compileOutput
            if ($cr.PSObject.Properties['errors'] -and $cr.errors -and $cr.errors.Count -gt 0) {
                $shownErrors = $true
                Write-Host ""
                Write-Host "  Errors ($($cr.errors.Count)):"
                foreach ($err in $cr.errors) {
                    Write-Host "    $($err.file)($($err.line),$($err.column)) $($err.code): $($err.message)"
                }
            }
            # Fallback: show last lines of raw log when parser found no structured errors
            if (-not $shownErrors -and $cr.PSObject.Properties['log_path'] -and
                (Test-Path -LiteralPath $cr.log_path -PathType Leaf)) {
                $rawLines = [System.IO.File]::ReadAllLines($cr.log_path,
                    [System.Text.UTF8Encoding]::new($false))
                $tail = @($rawLines | Where-Object { $_ -match 'error' } | Select-Object -Last 5)
                if ($tail.Count -gt 0) {
                    Write-Host ""
                    Write-Host "  Raw errors (from log):"
                    foreach ($line in $tail) {
                        Write-Host "    $line"
                    }
                }
            }
        }
        exit $result.ExitCode
    }

    # --- Run scenarios (optional, only if EXE exists and scenarios specified) ---
    if ([string]::IsNullOrWhiteSpace($scenarios)) {
        Write-Host ""
        Write-Host "Compile check passed. Use -s <scenarios> to also run scenarios."
        exit 0
    }

    # Locate EXE (use .dproj DCC_ExeOutput or default)
    $exePath = $info.ExePath
    # Allow --exe override
    $exeOverride = Get-NamedArg -ArgList $CmdArgs -Name 'exe'
    if ($exeOverride) { $exePath = $exeOverride }
    if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
        Write-Host "  Warning: EXE not found at $exePath"
        Write-Host "  Compile OK, but cannot run scenarios."
        exit 0
    }

    $runId = New-AutoFixRunId
    $outputDir = Join-Path $info.ProjectDir 'autofix-output'

    Write-Host "  Running scenarios: $scenarios ..."

    $runnerArgs = @(
        '-Exe', $exePath,
        '-RunId', $runId,
        '-Iteration', '1',
        '-Scenarios', $scenarios,
        '-OutputDir', $outputDir
    )
    $startupWait = Get-NamedArg -ArgList $CmdArgs -Name 'startup-timeout'
    if ($startupWait) { $runnerArgs += @('-StartupTimeout', $startupWait) }

    $runResult = Invoke-AutoFixChild -Script 'runner.ps1' -ChildArgs $runnerArgs

    $status = 'unknown'
    try {
        $payload = $runResult.Stdout | Where-Object { $_ -match '^\{' } | Select-Object -Last 1
        if ($payload) {
            $obj = $payload | ConvertFrom-Json -Depth 16
            $status = $obj.status
        }
    } catch {}

    Write-Host "  Runner status: $status (exit $($runResult.ExitCode))"

    # Display runtime errors
    $errorsFile = Join-Path $outputDir 'runtime-errors.jsonl'
    $errors = @(Read-Jsonl -Path $errorsFile)
    if ($errors.Count -gt 0) {
        Write-Host ""
        Write-Host "  Runtime Errors: $($errors.Count)"
        foreach ($err in $errors | Select-Object -First 10) {
            $loc = if ($err.PSObject.Properties['source_location']) {
                " at $($err.source_location)"
            } else { '' }
            Write-Host "    [$($err.level)] $($err.class)$($loc)"
        }
    }

    exit $runResult.ExitCode
}

# =============================================================================
# Command: wire
# =============================================================================

function Invoke-AutoFixWire {
    param([string[]]$CmdArgs)

    $dproj = Get-PositionalArg -ArgList $CmdArgs -Index 0
    $dryRun = Test-SwitchArg -ArgList $CmdArgs -Name 'dry-run'
    if ([string]::IsNullOrEmpty($dproj)) {
        Write-Host "Usage: autofix wire <project.dproj> [--dry-run]"
        exit $AutoFixExit_BadParams
    }

    $info = Resolve-ProjectInfo -DprojPath $dproj

    Write-Host "AutoFix Wire: $($info.Stem)"
    Write-Host ('=' * 60)

    if (-not (Test-Path -LiteralPath $info.DprPath -PathType Leaf)) {
        Write-Host "Error: .dpr not found: $($info.DprPath)"
        exit $AutoFixExit_BadParams
    }

    $enc = [System.Text.UTF8Encoding]::new($false)
    $content = [System.IO.File]::ReadAllText($info.DprPath, $enc)

    if ($content -match 'DeepBase\.AutoFix\b') {
        Write-Host "Already wired: $($info.MainSource) already references DeepBase.AutoFix"
        exit 0
    }

    # Backup before modifying (skip in dry-run since we don't write anyway)
    $backupPath = $info.DprPath + '.autofix-backup'
    if (-not $dryRun) {
        [System.IO.File]::Copy($info.DprPath, $backupPath, $true)
        Write-Host "Backup: $backupPath"
    }

    $lines = [System.Collections.Generic.List[string]]::new(
        [System.IO.File]::ReadAllLines($info.DprPath, $enc)
    )

    # --- Detect framework (VCL vs FMX) ---
    $isFmx = $content -match '\bFMX\b' -or $content -match 'FMX\.Forms'
    $hookUnit = if ($isFmx) { 'DeepBase.AutoFix.FmxHook' } else { 'DeepBase.AutoFix.VclHook' }
    $hookClass = if ($isFmx) { 'TAutoFixFmxHook' } else { 'TAutoFixVclHook' }

    # --- Find uses clause end (strip inline comments before checking ;) ---
    $usesEndIdx = -1
    $inUses = $false
    for ($i = 0; $i -lt $lines.Count; $i++) {
        $trimmed = $lines[$i].Trim()
        if ($trimmed -match '^\s*uses\b') { $inUses = $true }
        if (-not $inUses) { continue }
        # Strip trailing // comment to check the real terminator
        $noComment = $trimmed -replace '//.*$', ''
        $noComment = $noComment.TrimEnd()
        if ($noComment.EndsWith(';')) {
            $usesEndIdx = $i
            break
        }
    }

    if ($usesEndIdx -eq -1) {
        Write-Host "Error: Could not find 'uses' clause end (;) in $($info.MainSource)"
        exit $AutoFixExit_BadParams
    }

    # --- Find begin (search only after uses clause to avoid false match) ---
    $beginIdx = -1
    for ($i = $usesEndIdx; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -match '^\s*begin\b') {
            $beginIdx = $i
            break
        }
    }

    if ($beginIdx -eq -1) {
        Write-Host "Error: Could not find 'begin' after uses clause in $($info.MainSource)"
        exit $AutoFixExit_BadParams
    }

    # --- Modify uses clause (preserve original leading whitespace) ---
    $usesLine = $lines[$usesEndIdx]
    $trimmed = $usesLine.TrimEnd()
    # Strip inline comment, preserve indent prefix
    $indent = $usesLine.Substring(0, [Math]::Max(0, $usesLine.Length - $usesLine.TrimStart().Length))
    if ([string]::IsNullOrWhiteSpace($indent)) { $indent = '  ' }
    $noComment = ($trimmed -replace '//.*$', '').TrimEnd()
    if ($noComment.EndsWith(';')) {
        $lines[$usesEndIdx] = $noComment.Substring(0, $noComment.Length - 1) + ','
    }

    # Insert the two units (last one gets ;)
    $lines.Insert($usesEndIdx + 1, "$indent DeepBase.AutoFix,")
    $lines.Insert($usesEndIdx + 2, "$indent $hookUnit;")

    # --- Re-find begin (shifted by 2 inserts, search after usesEndIdx) ---
    $beginIdx = -1
    for ($i = $usesEndIdx; $i -lt $lines.Count; $i++) {
        if ($lines[$i].Trim() -match '^\s*begin\b') {
            $beginIdx = $i
            break
        }
    }

    # --- Insert Install calls after begin ---
    $ins = $beginIdx + 1
    $lines.Insert($ins,     '  AutoFix.Install;')
    $lines.Insert($ins + 1, "  $hookClass.Install;")

    # --- Write back ---
    if ($dryRun) {
        Write-Host "(dry-run) Would write the following changes:"
        $diffLines = New-Object System.Collections.Generic.List[string]
        for ($i = 0; $i -lt $lines.Count; $i++) {
            $diffLines.Add($lines[$i]) | Out-Null
        }
        # Show inserted lines with + prefix
        Write-Host ""
        $added = @(
            @($usesEndIdx + 1, "$indent DeepBase.AutoFix,"),
            @($usesEndIdx + 2, "$indent $hookUnit;"),
            @($ins, '  AutoFix.Install;'),
            @($ins + 1, "  $hookClass.Install;")
        )
        foreach ($line in $lines) {
            $marked = $false
            foreach ($a in $added) {
                if ($line -eq $a[1]) { Write-Host "+ $line"; $marked = $true; break }
            }
            if (-not $marked) { Write-Host "  $line" }
        }
        Write-Host ""
        Write-Host "(dry-run) No files were modified."
        return
    }

    [System.IO.File]::WriteAllLines($info.DprPath, $lines, $enc)

    Write-Host "Wired: $($info.MainSource)"
    Write-Host ""
    Write-Host "  Framework: $(if ($isFmx) { 'FMX' } else { 'VCL' })"
    Write-Host "  Added to uses:"
    Write-Host "    DeepBase.AutoFix, $hookUnit"
    Write-Host "  Added after begin:"
    Write-Host "    AutoFix.Install;"
    Write-Host "    $hookClass.Install;"
    Write-Host ""
    Write-Host "  You still need to add manually:"
    Write-Host "    AutoFix.RegisterScenario('smoke', procedure begin ... end);"
    Write-Host "    AutoFix.NotifyShellShown;  // in main form DoShow"
}

# =============================================================================
# Command: scenarios
# =============================================================================

function Invoke-AutoFixScenarios {
    param([string[]]$CmdArgs)

    $dproj = Get-PositionalArg -ArgList $CmdArgs -Index 0
    if ([string]::IsNullOrEmpty($dproj)) {
        Write-Host "Usage: autofix scenarios <project.dproj>"
        exit $AutoFixExit_BadParams
    }

    $info = Resolve-ProjectInfo -DprojPath $dproj
    if (-not (Test-Path -LiteralPath $info.DprPath -PathType Leaf)) {
        Write-Host "Error: .dpr not found: $($info.DprPath)"
        exit $AutoFixExit_BadParams
    }

    Write-Host "AutoFix Scenarios: $($info.Stem)"
    Write-Host ('=' * 60)

    $enc = [System.Text.UTF8Encoding]::new($false)
    $content = [System.IO.File]::ReadAllText($info.DprPath, $enc)

    # Extract RegisterScenario('name', ...) calls
    $scenarioMatches = [regex]::Matches($content,
        "RegisterScenario\s*\(\s*'([^']+)'",
        [System.Text.RegularExpressions.RegexOptions]::IgnoreCase)

    if ($scenarioMatches.Count -eq 0) {
        Write-Host "No scenarios registered in $($info.MainSource)."
        Write-Host "Add one with: AutoFix.RegisterScenario('smoke', procedure begin ... end);"
        exit 0
    }

    Write-Host "Registered scenarios ($($scenarioMatches.Count)):"
    foreach ($m in $scenarioMatches) {
        Write-Host "  - $($m.Groups[1].Value)"
    }
}

# =============================================================================
# Command: clean
# =============================================================================

function Invoke-AutoFixClean {
    param([string[]]$CmdArgs)

    $outDir = Get-PositionalArg -ArgList $CmdArgs -Index 0
    if ([string]::IsNullOrEmpty($outDir)) { $outDir = 'autofix-output' }

    $dryRun = Test-SwitchArg -ArgList $CmdArgs -Name 'dry-run'

    Write-Host "AutoFix Clean$(if ($dryRun) { ' (dry-run)' })"
    Write-Host ('=' * 60)

    # --- Remove output directory ---
    if (Test-Path -LiteralPath $outDir) {
        $resolved = (Resolve-Path -LiteralPath $outDir).Path
        if ($dryRun) {
            Write-Host "  Would remove: $resolved"
        } else {
            Remove-Item -LiteralPath $resolved -Recurse -Force
            Write-Host "  Removed output: $resolved"
        }
    } else {
        Write-Host "  Output directory not found: $outDir"
    }

    # --- Clean up orphaned autofix/* branches ---
    if ($null -ne (Get-Command git -ErrorAction SilentlyContinue)) {
        git rev-parse --git-dir 2>$null | Out-Null
        if ($LASTEXITCODE -ne 0) {
            Write-Host "  Not a git repository — skipping branch/worktree cleanup."
        } else {
        $branches = @(git branch --list 'autofix/*' 2>$null)
        if ($branches.Count -gt 0) {
            foreach ($br in ($branches | ForEach-Object { $_.Trim() })) {
                if ($dryRun) {
                    Write-Host "  Would delete branch: $br"
                } else {
                    git branch -D $br 2>$null | Out-Null
                    Write-Host "  Deleted branch: $br"
                }
            }
        } else {
            Write-Host "  No autofix/* branches found."
        }

        # --- Prune worktrees (parse porcelain output) ---
        # git worktree list --porcelain outputs: "worktree /path\nHEAD ...\nbranch ...\n\n"
        $wtLines = @(git worktree list --porcelain 2>$null)
        if ($LASTEXITCODE -eq 0 -and $wtLines.Count -gt 0) {
            # Extract worktree paths (lines starting with "worktree ")
            $afWtPaths = @($wtLines | Where-Object { $_ -match '^worktree .+' } |
                ForEach-Object { ($_ -replace '^worktree ', '').Trim() } |
                Where-Object { $_ -match 'autofix' })
            foreach ($wtPath in $afWtPaths) {
                if (-not (Test-Path -LiteralPath $wtPath -PathType Container)) { continue }
                if ($dryRun) {
                    Write-Host "  Would remove worktree: $wtPath"
                } else {
                    git worktree remove --force $wtPath 2>$null | Out-Null
                    Write-Host "  Removed worktree: $wtPath"
                }
            }
            if ($afWtPaths.Count -eq 0) {
                Write-Host "  No autofix worktrees found."
            }
        }
        } # else (is git repo)
    } # if git available

    if ($dryRun) { Write-Host "Dry-run complete. No changes made." }
}

# =============================================================================
# Command: detect
# =============================================================================

function Invoke-AutoFixDetect {
    param([string[]]$CmdArgs)

    $jsonMode  = Test-SwitchArg -ArgList $CmdArgs -Name 'json'
    $force     = Test-SwitchArg -ArgList $CmdArgs -Name 'force'
    $delphiVer = Get-NamedArg  -ArgList $CmdArgs -Name 'delphi-version'
    $envBat    = Get-NamedArg  -ArgList $CmdArgs -Name 'env-bat'

    if (-not $jsonMode) {
        Write-Host "AutoFix Delphi Environment Detection"
        Write-Host ('=' * 60)
    }

    try {
        # List all installed versions first
        $installed = @(Get-InstalledDelphiVersions)

        if (-not $jsonMode) {
            if ($installed.Count -eq 0) {
                Write-Host "  No Delphi installations found in Windows registry."
                Write-Host ""
                Write-Host "  Checked:"
                Write-Host "    HKLM:\SOFTWARE\Embarcadero\BDS"
                Write-Host "    HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS"
                Write-Host ""
                Write-Host "  Provide --env-bat <path> or set AUTOFIX_DELPHI_ENV_BAT."
                exit $AutoFixExit_BdsFailed
            }

            Write-Host "  Installed Delphi versions:"
            foreach ($inst in $installed) {
                $rsvars = if ($inst.HasRsvarsBat) { 'rsvars.bat OK' } else { 'no rsvars.bat' }
                Write-Host "    $($inst.BdsVersion)  $($inst.FriendlyName)  (ProductVersion $($inst.ProductVersion))  [$rsvars]"
            }
            Write-Host ""
        }

        # Now run detection
        $env = Find-DelphiEnvironment -Override $envBat -DelphiVersion $delphiVer -Force:$force

        if (-not $jsonMode) {
            Write-Host "  Selected: $($env.FriendlyName) (BDS $($env.BdsVersion))"
            Write-Host "  Source:   $($env.Source)"
            Write-Host "  RootDir:  $($env.RootDir)"
            Write-Host "  Env Bat:  $($env.EnvBatPath)"
            Write-Host ""
            Write-Host "  Validation:"
            if (Test-Path -LiteralPath $env.EnvBatPath -PathType Leaf) {
                Write-Host "    [OK] Env bat exists"
            } else {
                Write-Host "    [FAIL] Env bat missing: $($env.EnvBatPath)"
            }
        } else {
            $output = [ordered]@{
                ok            = $true
                installed     = @($installed | ForEach-Object {
                    [ordered]@{
                        bds_version     = $_.BdsVersion
                        product_version = $_.ProductVersion
                        friendly_name   = $_.FriendlyName
                        root_dir        = $_.RootDir
                        has_rsvars_bat  = $_.HasRsvarsBat
                    }
                })
                selected      = [ordered]@{
                    bds_version   = $env.BdsVersion
                    friendly_name = $env.FriendlyName
                    root_dir      = $env.RootDir
                    env_bat_path  = $env.EnvBatPath
                    source        = $env.Source
                }
            }
            [Console]::Out.WriteLine(($output | ConvertTo-Json -Depth 6 -Compress:$false))
        }

        exit 0
    } catch {
        if ($jsonMode) {
            [Console]::Out.WriteLine((ConvertTo-Json -Compress -Depth 4 ([pscustomobject]@{
                ok = $false; error = $_.Exception.Message
            })))
        } else {
            Write-Host "  Error: $($_.Exception.Message)"
        }
        exit $AutoFixExit_BdsFailed
    }
}

# =============================================================================
# Command: help
# =============================================================================

function Write-AutoFixHelp {
    Write-Host "DeepBase AutoFix CLI"
    Write-Host ""
    Write-Host "Usage: autofix <command> [options]"
    Write-Host ""
    Write-Host "Commands:"
    Write-Host "  init      <project.dproj> [--force]       Generate boundary.json + wiring guide"
    Write-Host "  wire      <project.dproj> [--dry-run]     Auto-inject AutoFix into .dpr"
    Write-Host "  scenarios <project.dproj>                 List registered scenarios"
    Write-Host "  run       <project.dproj> -s <scenarios>  Run AI fix loop"
    Write-Host "            [-n 10] [-b cli] [--timeout 600] [--output dir]"
    Write-Host "  check     <project.dproj> [-s <scenarios>]  Compile + optional scenario run"
    Write-Host "  detect    [--delphi-version <ver>]         Detect Delphi environment (M14)"
    Write-Host "            [--env-bat <path>] [--force] [--json]"
    Write-Host "  status    [output-dir]                    Show results from last run"
    Write-Host "  clean     [output-dir] [--dry-run]        Remove output, branches, worktrees"
    Write-Host ""
    Write-Host "Options:"
    Write-Host "  -s, --scenario <names>        Comma-separated scenario names"
    Write-Host "  -n, --max-iter <N>            Max iterations (default: 10)"
    Write-Host "  -b, --backend <type>          AI backend: cli (default)"
    Write-Host "      --timeout <sec>           Scenario timeout (default: 600)"
    Write-Host "      --output <dir>            Output directory (default: autofix-output)"
    Write-Host "      --exe <path>              Override EXE path (run/check)"
    Write-Host "      --delphi-version <ver>    Delphi version: 37, 13.1, florence, etc."
    Write-Host "      --env-bat <path>          Direct path to env bat (bypass detection)"
    Write-Host "      --startup-timeout <sec>   Override startup timeout (run)"
    Write-Host "      --oscillation-window <N>  Oscillation window (run)"
    Write-Host "      --oscillation-threshold <N> Oscillation threshold (run)"
    Write-Host "      --skip-lint               Skip lint gate (run)"
    Write-Host "      --force                   Overwrite existing files (init)"
    Write-Host "                                Force re-detection (detect)"
    Write-Host ""
    Write-Host "Examples:"
    Write-Host "  pwsh autofix-cli.ps1 init      MyProject.dproj"
    Write-Host "  pwsh autofix-cli.ps1 wire      MyProject.dproj"
    Write-Host "  pwsh autofix-cli.ps1 scenarios MyProject.dproj"
    Write-Host "  pwsh autofix-cli.ps1 run       MyProject.dproj -s smoke -n 5"
    Write-Host "  pwsh autofix-cli.ps1 check     MyProject.dproj"
    Write-Host "  pwsh autofix-cli.ps1 detect"
    Write-Host "  pwsh autofix-cli.ps1 detect    --delphi-version 13.1 --json"
    Write-Host "  pwsh autofix-cli.ps1 status"
    Write-Host "  pwsh autofix-cli.ps1 clean     --dry-run"
}

# =============================================================================
# Dispatch
# =============================================================================

switch ($Command) {
    'init'        { Invoke-AutoFixInit       -CmdArgs $CmdArgs }
    'wire'        { Invoke-AutoFixWire       -CmdArgs $CmdArgs }
    'scenarios'   { Invoke-AutoFixScenarios  -CmdArgs $CmdArgs }
    'run'         { Invoke-AutoFixRun        -CmdArgs $CmdArgs }
    'check'       { Invoke-AutoFixCheck      -CmdArgs $CmdArgs }
    'status'      { Invoke-AutoFixStatus     -CmdArgs $CmdArgs }
    'clean'       { Invoke-AutoFixClean      -CmdArgs $CmdArgs }
    'detect'      { Invoke-AutoFixDetect     -CmdArgs $CmdArgs }
    ''            { Write-AutoFixHelp; exit 0 }
    '--help'      { Write-AutoFixHelp; exit 0 }
    '-h'          { Write-AutoFixHelp; exit 0 }
    '-help'       { Write-AutoFixHelp; exit 0 }
    'help'        { Write-AutoFixHelp; exit 0 }
    default  {
        Write-Host "Unknown command: $Command"
        Write-Host ""
        Write-AutoFixHelp
        exit $AutoFixExit_BadParams
    }
}
