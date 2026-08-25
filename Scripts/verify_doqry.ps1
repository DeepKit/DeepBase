# verify_doqry.ps1 - doQry 单元独立编译验证 (无需完整 IDE / MIDAS)
# 用法: powershell -File Scripts\verify_doqry.ps1
# 依赖: Tools\DBClientStub\DBClient.pas (编译专用桩, 替代缺失的 DBClient.dcu)

$ErrorActionPreference = 'Stop'
$BdsRoot = 'D:\Program Files (x86)\Embarcadero\Studio\37.0'
$Repo    = Split-Path -Parent $PSScriptRoot
$OutDir  = Join-Path $env:TEMP 'doqry_verify_dcu'
New-Item -ItemType Directory -Force -Path $OutDir | Out-Null

& (Join-Path $BdsRoot 'bin\rsvars.bat') | Out-Null

$Units = @('doQry/src/uDoQry.pas', 'doQry/uDoQryLegacy.pas')
$Failed = $false
foreach ($U in $Units) {
    $args = @(
        '-B', '-Q', '--codepage:65001',
        '-NSSystem;Winapi;Vcl;Data;Data.Win',
        "-U""$Repo\Core;$Repo\Tools\DBClientStub;$BdsRoot\lib\win64\release""",
        "-I""$Repo\Tools\DBClientStub""",
        "-N0""$OutDir""",
        (Join-Path $Repo $U)
    )
    Write-Host "Compiling $U ..."
    $out = cmd /c "`"$BdsRoot\bin\dcc64.exe`" $($args -join ' ') 2>&1"
    $errs = $out | Select-String 'Error|Fatal'
    if ($errs) { $Failed = $true; $errs | ForEach-Object { Write-Host $_ } }
    else { Write-Host "  OK" }
}
if ($Failed) { exit 1 } else { Write-Host 'ALL PASS' }
