# DeepBase Win64 package build gate
# Usage:
#   .\build_packages_win64.ps1 -Profile Runtime
#   .\build_packages_win64.ps1 -Profile All

param(
    [ValidateSet('Minimal', 'Runtime', 'All')]
    [string]$Profile = 'Runtime',

    [switch]$SkipDcuSourceCheck
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$Dcc64Path = 'd:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc64.exe'
$RsVarsBat = 'd:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'

$OutputRoot = Join-Path $RepoRoot 'TestResults'
$DcuOutputPath = Join-Path $OutputRoot 'dcu64'
$BplOutputPath = Join-Path $OutputRoot 'bpl64'
$DcpOutputPath = Join-Path $OutputRoot 'dcp64'

foreach ($path in @($OutputRoot, $DcuOutputPath, $BplOutputPath, $DcpOutputPath)) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

# Keep source tree clean from stale DCU artifacts before package builds.
$AllSourceRoots = @('Core', 'Persistence', 'Features', 'Tests', 'VCL', 'FMX', 'ThirdParty', 'Tools')

foreach ($root in $AllSourceRoots) {
    $rootPath = Join-Path $RepoRoot $root
    if (Test-Path $rootPath) {
        Get-ChildItem -Path $rootPath -Recurse -Filter *.dcu -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

$SourceRoots = @($AllSourceRoots | Where-Object { Test-Path (Join-Path $RepoRoot $_) })
$SourceSearchPath = ($SourceRoots | ForEach-Object { Join-Path $RepoRoot $_ }) -join ';'

if (-not (Test-Path $Dcc64Path)) {
    throw "Win64 compiler not found: $Dcc64Path"
}

if (-not (Test-Path $RsVarsBat)) {
    throw "rsvars.bat not found: $RsVarsBat"
}

$RenameCheckScript = Join-Path $RepoRoot 'Scripts\check_rename_residue.ps1'
if (Test-Path $RenameCheckScript) {
    Write-Host "Running rename residue check ..."
    & $RenameCheckScript
    if ($LASTEXITCODE -ne 0) {
        throw "Rename residue check failed"
    }
}

$MinimalPackages = @(
    'DeepBaseCore.dpk',
    'DeepBaseServices.dpk',
    'DeepBasePersistence.dpk'
)

$RuntimePackages = @(
    'DeepBaseCore.dpk',
    'DeepBaseServices.dpk',
    'DeepBasePersistence.dpk',
    'DeepBaseFeatures.dpk'
)

$UiPackages = @()
if (Test-Path (Join-Path $RepoRoot 'FMX')) {
    $UiPackages += 'DeepBaseFMX.dpk'
}
if (Test-Path (Join-Path $RepoRoot 'VCL')) {
    $UiPackages += 'DeepBaseVCL.dpk'
} else {
    Write-Host "VCL source directory not found; DeepBaseVCL.dpk is excluded from this gate." -ForegroundColor Yellow
}

function Invoke-PackageCompile {
    param(
        [Parameter(Mandatory = $true)]
        [string]$PackagePath,

        [switch]$BuildAll
    )

    if (-not (Test-Path $PackagePath)) {
        throw "Package file not found: $PackagePath"
    }

    Write-Host "Compiling $(Split-Path $PackagePath -Leaf) ..."

    $buildFlag = if ($BuildAll) { '-B' } else { '-M' }
    $cmd = "call ""$RsVarsBat"" && dcc64 $buildFlag -Q -U""$SourceSearchPath"" -I""$SourceSearchPath"" -N0""$DcuOutputPath"" -LE""$BplOutputPath"" -LN""$DcpOutputPath"" ""$PackagePath"""
    $process = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $cmd -Wait -PassThru -NoNewWindow -WorkingDirectory $RepoRoot
    if ($process.ExitCode -ne 0) {
        throw "Package compile failed: $(Split-Path $PackagePath -Leaf), exit code: $($process.ExitCode)"
    }

    foreach ($root in $SourceRoots) {
        $rootPath = Join-Path $RepoRoot $root
        if (Test-Path $rootPath) {
            Get-ChildItem -Path $rootPath -Recurse -Filter *.dcu -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "=============================================="
Write-Host "      DeepBase Win64 Package Build Gate"
Write-Host "=============================================="
Write-Host "Profile: $Profile"
Write-Host "Repo: $RepoRoot"
Write-Host "DCU output: $DcuOutputPath"
Write-Host ""

switch ($Profile) {
    'Minimal' {
        foreach ($package in $MinimalPackages) {
            Invoke-PackageCompile -PackagePath (Join-Path $RepoRoot $package) -BuildAll
        }
    }
    'Runtime' {
        foreach ($package in $RuntimePackages) {
            Invoke-PackageCompile -PackagePath (Join-Path $RepoRoot $package) -BuildAll
        }
    }
    'All' {
        foreach ($package in $RuntimePackages) {
            Invoke-PackageCompile -PackagePath (Join-Path $RepoRoot $package) -BuildAll
        }
        foreach ($package in $UiPackages) {
            # Compile UI packages in make mode to avoid rebuilding (and locking)
            # already built runtime dependencies within the same gate run.
            Invoke-PackageCompile -PackagePath (Join-Path $RepoRoot $package)
        }
    }
}

if (-not $SkipDcuSourceCheck) {
    Write-Host ""
    Write-Host "Checking source directories for leaked .dcu ..."
    $leaked = & rg --files -g '*.dcu' @SourceRoots
    if ($LASTEXITCODE -gt 1) {
        throw 'Failed to run rg for DCU source check'
    }

    if ($leaked) {
        Write-Host $leaked
        throw 'Found leaked .dcu files in source directories'
    }
}

Write-Host ""
Write-Host "Win64 package build gate passed." -ForegroundColor Green
exit 0
