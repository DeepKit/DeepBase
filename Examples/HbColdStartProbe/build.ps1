# Build HbColdStartProbe (Win64) for Gate #1
$ErrorActionPreference = 'Stop'
$Root = Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
if (-not (Test-Path (Join-Path $Root 'Core'))) {
    $Root = 'D:\_Progs\02Business\DeepBase'
}
$Dcc = 'D:\Program Files (x86)\Embarcadero\Studio\37.0\bin\dcc64.exe'
$OutDir = Join-Path $PSScriptRoot 'Win64'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null
$UnitPaths = @(
    (Join-Path $Root 'Core'),
    (Join-Path $Root 'VCL'),
    (Join-Path $Root 'Persistence'),
    (Join-Path $Root 'Features'),
    'D:\ProgramData\delphi\DUnitX\Source'
) -join ';'

Push-Location $PSScriptRoot
try {
    & $Dcc '-B' 'HbColdStartProbe.dpr' "-U$UnitPaths" "-NSSystem;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Vcl" "-E$OutDir" '-N0.' '-Q'
    if ($LASTEXITCODE -ne 0) { throw "dcc64 failed: $LASTEXITCODE" }
    Write-Host "OK: $(Join-Path $OutDir 'HbColdStartProbe.exe')"
}
finally {
    Pop-Location
}
