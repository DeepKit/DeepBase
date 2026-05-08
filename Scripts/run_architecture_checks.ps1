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

$RsVarsBat = 'd:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'
$Dcc64 = 'd:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc64.exe'

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
exit 0
