#requires -Version 7.0
<#
.SYNOPSIS
    Stub compiler.ps1 for E2E integration tests.

.DESCRIPTION
    Writes a valid compile-errors.json with success=true/false based on
    the STUB_COMPILER_FAIL environment variable.

    Env vars:
        STUB_COMPILER_FAIL  : 'true' to report compile failure (default: 'false')
#>
param(
    [Parameter(Mandatory)][string]$Project,
    [string]$OutputJson,
    [string]$LogFile,
    [string]$Config = 'Debug',
    [string]$Platform = 'Win64'
)

if (-not $OutputJson) { $OutputJson = Join-Path (Get-Location).Path 'compile-errors.json' }
if (-not $LogFile)    { $LogFile    = [System.IO.Path]::ChangeExtension($OutputJson, '.log') }

$fail = $env:STUB_COMPILER_FAIL -eq 'true'

$result = [pscustomobject]@{
    ts            = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz')
    success       = (-not $fail)
    duration_sec  = 1
    msbuild_exit  = if ($fail) { 1 } else { 0 }
    project       = $Project
    config        = $Config
    platform      = $Platform
    errors        = @()
    warnings      = @()
    log_path      = $LogFile
}

$json = ($result | ConvertTo-Json -Depth 10)
$dir = Split-Path -Parent $OutputJson
if ($dir -and -not (Test-Path -LiteralPath $dir)) {
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}
[System.IO.File]::WriteAllText($OutputJson, $json, [System.Text.UTF8Encoding]::new($false))

$logContent = if ($fail) { "stub compiler: BUILD FAILED`n" } else { "stub compiler: BUILD SUCCESS`n" }
[System.IO.File]::WriteAllText($LogFile, $logContent, [System.Text.UTF8Encoding]::new($false))

# Create a stub EXE at the expected path so autofix.ps1 can find it
if (-not $fail) {
    $projectDir = Split-Path -Parent $Project
    $stem = [System.IO.Path]::GetFileNameWithoutExtension($Project)
    $exeDir = Join-Path $projectDir (Join-Path $Platform (Join-Path $Config ''))
    if (-not (Test-Path -LiteralPath $exeDir)) {
        New-Item -ItemType Directory -Path $exeDir -Force | Out-Null
    }
    $stubExe = Join-Path $exeDir "$stem.exe"
    if (-not (Test-Path -LiteralPath $stubExe)) {
        [System.IO.File]::WriteAllBytes($stubExe, [byte[]]::new(2))
    }
    # Also create a stub .map file
    $stubMap = [System.IO.Path]::ChangeExtension($stubExe, '.map')
    if (-not (Test-Path -LiteralPath $stubMap)) {
        [System.IO.File]::WriteAllText($stubMap, "stub map`n", [System.Text.UTF8Encoding]::new($false))
    }
}

if ($fail) { exit 1 }
exit 0
