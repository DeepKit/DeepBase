param(
    [ValidateSet('Win64')]
    [string]$Platform = 'Win64',
    [switch]$SkipCompile
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$TestsDir = Join-Path $RepoRoot 'Tests\Architecture'
$ProjectFile = Join-Path $TestsDir 'DeepBaseArchitectureTests.dpr'
$ExeFile = Join-Path $TestsDir 'DeepBaseArchitectureTests.exe'
$ResultDir = Join-Path $RepoRoot 'TestResults'
$XmlFile = Join-Path $ResultDir 'ArchitectureTestResults.xml'
$DcuOutput = Join-Path $ResultDir "build\dcu\$Platform"

$BdsRoot = if ($env:BDS) { $env:BDS } else { 'D:\Program Files (x86)\Embarcadero\Studio\37.0' }
$RsVarsBat = Join-Path $BdsRoot 'bin\rsvars.bat'
$Dcc64 = Join-Path $BdsRoot 'bin\dcc64.exe'

function Test-XmlHasExecutedTests {
    param([Parameter(Mandatory = $true)][string]$Path)

    if (-not (Test-Path $Path)) {
        return $false
    }

    [xml]$xml = Get-Content -Path $Path -Raw
    $totalAttr = $xml.DocumentElement.GetAttribute('total')
    if (-not [string]::IsNullOrWhiteSpace($totalAttr)) {
        return ([int]$totalAttr -gt 0)
    }

    return (@($xml.SelectNodes('//test-case')).Count -gt 0)
}

if (-not (Test-Path $ProjectFile)) {
    throw "Architecture test project not found: $ProjectFile"
}

if (-not (Test-Path $RsVarsBat)) {
    throw "rsvars.bat not found: $RsVarsBat"
}

if (-not (Test-Path $Dcc64)) {
    throw "Delphi Win64 compiler not found: $Dcc64"
}

if (-not (Test-Path $ResultDir)) {
    New-Item -ItemType Directory -Path $ResultDir -Force | Out-Null
}

if (-not (Test-Path $DcuOutput)) {
    New-Item -ItemType Directory -Path $DcuOutput -Force | Out-Null
}

if (-not $SkipCompile) {
    Write-Host 'Compiling architecture test project...'
    $compileCmd = 'call "{0}" && dcc64 -B -Q -N0"{1}" -E"{2}" "{3}"' -f $RsVarsBat, $DcuOutput, $TestsDir, $ProjectFile
    $compileProc = Start-Process -FilePath 'cmd.exe' -ArgumentList '/c', $compileCmd -Wait -PassThru -NoNewWindow -WorkingDirectory $RepoRoot
    if ($compileProc.ExitCode -ne 0) {
        throw "Architecture test compile failed with exit code $($compileProc.ExitCode)"
    }
}

if (-not (Test-Path $ExeFile)) {
    throw "Architecture test executable not found: $ExeFile"
}

if (Test-Path $XmlFile) {
    Remove-Item -Path $XmlFile -Force -ErrorAction SilentlyContinue
}

# Clean any stale .dcu artifacts from source directories BEFORE running tests
# (the architecture test itself checks for .dcu leakage).
$AllSourceRoots = @('Core', 'Persistence', 'Features', 'Tests', 'VCL', 'FMX', 'ThirdParty', 'Tools')
foreach ($root in $AllSourceRoots) {
    $rootPath = Join-Path $RepoRoot $root
    if (Test-Path $rootPath) {
        Get-ChildItem -Path $rootPath -Recurse -Filter *.dcu -File -ErrorAction SilentlyContinue |
            Remove-Item -Force -ErrorAction SilentlyContinue
    }
}

Write-Host 'Running architecture checks...'
$runArgs = @(
    "--xmlfile:$XmlFile",
    '--exitbehavior:Continue',
    '--include:Architecture'
)
$runProc = Start-Process -FilePath $ExeFile -ArgumentList $runArgs -Wait -PassThru -NoNewWindow -WorkingDirectory $RepoRoot

if ($runProc.ExitCode -ne 0) {
    throw "Architecture checks failed with exit code $($runProc.ExitCode)"
}

if (-not (Test-XmlHasExecutedTests -Path $XmlFile)) {
    throw "Architecture checks produced no executed tests: $XmlFile"
}

Write-Host 'Architecture checks passed.' -ForegroundColor Green

$LayerScript = Join-Path $RepoRoot 'Scripts\check-layer-violations.ps1'
$LayerReport = Join-Path $ResultDir 'architecture-layer-report.json'
if (-not (Test-Path $LayerScript)) {
    throw "Layer violation script not found: $LayerScript"
}

Write-Host 'Running layer violation checks...'
& $LayerScript -SourcePath $RepoRoot -ReportPath $LayerReport -FailOnViolation -IncludeKnownDebt
if ($LASTEXITCODE -ne 0) {
    throw "Layer violation checks failed with exit code $LASTEXITCODE"
}

$SecurityScript = Join-Path $RepoRoot 'Scripts\check-security-patterns.ps1'
$SecurityReport = Join-Path $ResultDir 'security-pattern-report.json'
if (-not (Test-Path $SecurityScript)) {
    throw "Security pattern script not found: $SecurityScript"
}

Write-Host 'Running security pattern checks...'
& $SecurityScript -SourcePath $RepoRoot -ReportPath $SecurityReport -FailOnViolation -IncludeKnownDebt
if ($LASTEXITCODE -ne 0) {
    throw "Security pattern checks failed with exit code $LASTEXITCODE"
}

Write-Host 'Architecture gate passed.' -ForegroundColor Green
exit 0
