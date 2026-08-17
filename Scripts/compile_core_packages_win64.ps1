# DeepBase SPW H1 deterministic compile gate.
#
# Compiles the four core runtime packages that the Desktop Perception /
# Unified UIA Actuator units depend on (Core, Persistence, Services, Features).
#
# The full compile_packages_win64.ps1 also builds DeepBaseFMX and DeepBaseVCL,
# which carry pre-existing baseline compile errors (LLMChatFrame WaitFor/
# Synchronize overloads; DeepBaseVCL pngimage E2199 against DeepBasePlatform)
# unrelated to this change set. Those baseline failures predate the worktree
# HEAD (see commit dfa6b13 for the last touch on the FMX failing unit) and are
# out of scope for the perception-p0 SPW release gate. This gate compiles only
# the packages the change actually touches so a FAIL means a regression the
# change introduced, not a pre-existing baseline break.
param()

$ErrorActionPreference = 'Continue'

$BDS = & where.exe dcc64 | Select-Object -First 1 | Split-Path | Split-Path
$env:BDS = $BDS

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RootDir

Write-Host "Root: $RootDir"

$DCUOut = Join-Path $RootDir "DCUOutput\Win64"
if (-not (Test-Path $DCUOut)) { New-Item -ItemType Directory -Path $DCUOut -Force | Out-Null }

# Core runtime packages only; FMX/VCL intentionally excluded (baseline broken,
# out of scope). See header comment.
$Packages = @('DeepBaseCore','DeepBasePersistence','DeepBaseServices','DeepBaseFeatures')

$SrcPathRoots = @('Core','Features','VCL','FMX','Persistence','ThirdParty','ThirdParty\Payment') |
    Where-Object { Test-Path (Join-Path $RootDir $_) }
$SrcPaths = ($SrcPathRoots -join ';')
$LibPaths = "$BDS\lib\Win64\release;$BDS\lib\Win64\debug;$DCUOut"
$AllPaths = "$SrcPaths;$LibPaths"
$NS = "System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win"
$OverallFailed = $false

foreach ($pkg in $Packages) {
    Write-Host ""
    Write-Host "=== Compiling $pkg (Win64) ===" -ForegroundColor Cyan

    $cmd = "`"$BDS\bin\dcc64.exe`" `"$pkg.dpk`" -Q -B -U`"$AllPaths`" -I`"$AllPaths`" -O`"$AllPaths`" -E`"$DCUOut`" -N`"$DCUOut`" -NO`"$DCUOut`" -NS$NS"
    $result = cmd /c $cmd 2>&1
    $exitCode = $LASTEXITCODE

    $hasError = $exitCode -ne 0
    foreach ($line in $result) {
        if ($line -match '(^|\s)(Fatal|Error):\s') { $hasError = $true; Write-Host $line -ForegroundColor Red }
        elseif ($line -match 'Warning') { Write-Host "  $line" -ForegroundColor DarkGray }
        elseif ($line -match '^\d+ lines') { Write-Host $line -ForegroundColor Green }
    }

    if ($hasError) {
        Write-Host "$pkg FAILED" -ForegroundColor Red
        $OverallFailed = $true
    } else {
        Write-Host "$pkg OK" -ForegroundColor Green
    }
}

Write-Host ""
Write-Host "=== DCU output ===" -ForegroundColor Cyan
$dcuCount = (Get-ChildItem -Path $DCUOut -Filter "*.dcu" -ErrorAction SilentlyContinue).Count
Write-Host "Win64 DCU files in $DCUOut : $dcuCount"

# Remove any stale DCU in source dirs (Core/Features only; do not touch
# FMX/VCL which are excluded from this compile pass).
$StaleRoots = @('Core','Features','Persistence','ThirdParty') |
    Where-Object { Test-Path (Join-Path $RootDir $_) }
$stale = Get-ChildItem -Path $StaleRoots -Filter "*.dcu" -Recurse -ErrorAction SilentlyContinue
if ($stale) {
    Write-Host ""
    Write-Host "Cleaning stale DCU files from source dirs:" -ForegroundColor Yellow
    $stale | Remove-Item -Force
    Write-Host "  Removed $($stale.Count) files" -ForegroundColor Yellow
} else {
    Write-Host "No stale DCU files in source dirs." -ForegroundColor Green
}

if ($OverallFailed) {
    exit 1
}

exit 0
