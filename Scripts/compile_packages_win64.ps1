param()

$ErrorActionPreference = 'Continue'

$BDS = & where.exe dcc64 | Select-Object -First 1 | Split-Path | Split-Path
$env:BDS = $BDS

$RootDir = Split-Path -Parent (Split-Path -Parent $MyInvocation.MyCommand.Path)
Set-Location $RootDir

Write-Host "Root: $RootDir"

# Create DCU output directory
$DCUOut = Join-Path $RootDir "DCUOutput\Win64"
if (-not (Test-Path $DCUOut)) { New-Item -ItemType Directory -Path $DCUOut -Force | Out-Null }

$Packages = @('DeepBaseCore','DeepBasePersistence','DeepBaseServices','DeepBaseFeatures')
if (Test-Path (Join-Path $RootDir 'FMX')) {
    $Packages += 'DeepBaseFMX'
}
if (Test-Path (Join-Path $RootDir 'VCL')) {
    $Packages += 'DeepBaseVCL'
} else {
    Write-Host "VCL source directory not found; DeepBaseVCL is excluded from this compile pass." -ForegroundColor Yellow
}

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

    # Use cmd /c to avoid PowerShell parameter parsing issues with dcc64
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

# Remove any stale DCU in source dirs
$StaleRoots = @('Core','Features','VCL','FMX','Persistence','ThirdParty') |
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
