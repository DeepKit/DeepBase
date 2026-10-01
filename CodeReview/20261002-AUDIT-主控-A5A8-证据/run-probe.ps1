# MC3 项1 · A5/A8 零信任复跑驱动（不入库，产物落 D:/_ProgData/DeepBase-MC3-A5A8/）
# 用法: powershell -NoProfile -File run-probe.ps1 -Root <隔离树> -Out <输出目录>
param(
  [Parameter(Mandatory=$true)][string]$Root,
  [Parameter(Mandatory=$true)][string]$Out,
  [Parameter(Mandatory=$true)][string]$Label
)
$ErrorActionPreference = 'Continue'
$BDS = 'D:\Program Files (x86)\Embarcadero\Studio\37.0'
$DCC = "$BDS\bin\dcc64.exe"
$DUNITX = 'D:/ProgramData/delphi/DUnitX/Source'
$U = @("$Root\Core","$Root\Features","$Root\Persistence","$Root\VCL","$Root\FMX","$Root\Governance",
       "$Root\Tests","$Root\Tests\Regression","$Root\Tests\Integration","$Root\DeepFlow\Source",
       "$Root\DeepFlow\Source\Core","$Root\DeepFlow\Source\Workflow","$Root\doQry","$Root\ThirdParty",
       "$BDS\lib\Win64\release",$DUNITX) -join ';'
$NS = 'System;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Shell;Data;FireDAC;FireDAC.Comp;FireDAC.DApt;FireDAC.Stan;Xml;Web;Soap;Winapi;System.Win'
# A5 交付件随仓入库，读自交付树本体（零信任：不从主树取附件）
$TPL = "$Root\CodeReview\20260925-AUDIT-甲-A5-证据\附件"
$B2TPL = "$Root\CodeReview\20260925-AUDIT-乙-B2-证据\附件\B2FixtureRunner.dpr.template"

$Probes = @(
  @{ Name='R01-A5R01Verify';      Tpl="$TPL\A5R01Verify.dpr.template" },
  @{ Name='R02-A5R0102Baseline';  Tpl="$TPL\A5R0102Baseline.dpr.template" },
  @{ Name='R03-A5R03Verify';      Tpl="$TPL\A5R03Verify.dpr.template" },
  @{ Name='R03w-A5R03Wide';       Tpl="$TPL\A5R03Wide.dpr.template" },
  @{ Name='R04-A5R04Verify';      Tpl="$TPL\A5R04Verify.dpr.template" },
  @{ Name='R04b-A5R04Broad';      Tpl="$TPL\A5R04Broad.dpr.template" },
  @{ Name='R05-A5R05Verify';      Tpl="$TPL\A5R05Verify.dpr.template" },
  @{ Name='R05b-A5R05Broad';      Tpl="$TPL\A5R05Broad.dpr.template" },
  @{ Name='R06-A5R06Verify';      Tpl="$TPL\A5R06Verify.dpr.template" },
  @{ Name='R07-A5R07Export';      Tpl="$TPL\A5R07Export.dpr.template" },
  @{ Name='R08-A5R08Docx';        Tpl="$TPL\A5R08Docx.dpr.template" },
  @{ Name='R09-A5R09Verify';      Tpl="$TPL\A5R09Verify.dpr.template" }
)

New-Item -ItemType Directory -Force -Path $Out | Out-Null
$summary = @()
foreach ($p in $Probes) {
  if (-not (Test-Path -LiteralPath $p.Tpl)) { $summary += "$($p.Name)`tSKIP`t模板不存在: $($p.Tpl)"; continue }
  $dir = "$Out\$($p.Name)"
  if (Test-Path $dir) { Remove-Item -Recurse -Force $dir }
  New-Item -ItemType Directory -Force -Path $dir | Out-Null
  $dpr = "$dir\$($p.Name).dpr"
  Copy-Item -LiteralPath $p.Tpl -Destination $dpr -Force
  $log = "$dir\compile.log"
  Push-Location $Root
  & $DCC -B $dpr "-NU$dir" "-N0$dir" "-E$dir" "-U$U" "-NS$NS" -DDEBUG *> $log
  $rc = $LASTEXITCODE
  Pop-Location
  $exe = "$dir\$($p.Name).exe"
  if ($rc -ne 0) { $summary += "$($p.Name)`tBUILD_EXIT=$rc`t未出 exe=$([bool](Test-Path $exe))"; continue }
  $lines = (Get-Content -LiteralPath $log | Where-Object { $_ -match '^\s*\d+ lines,' } | Select-Object -Last 1)
  $hints = @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'Hint:' }).Count
  $warns = @(Get-Content -LiteralPath $log | Where-Object { $_ -match 'Warning:' }).Count
  $run = "$dir\run.log"
  Push-Location $dir
  & $exe '--exitbehavior:Continue' '--hidebanner' *> $run
  $rrc = $LASTEXITCODE
  Pop-Location
  $r = Get-Content -LiteralPath $run
  $found  = ($r | Select-String -Pattern 'Tests Found\s*:').Line
  $passed = ($r | Select-String -Pattern 'Tests Passed\s*:').Line
  $failed = ($r | Select-String -Pattern 'Tests Failed\s*:').Line
  $errd   = ($r | Select-String -Pattern 'Tests Errored\s*:').Line
  $leak   = ($r | Select-String -Pattern 'Tests Leaked\s*:').Line
  $summary += "$($p.Name)`tBUILD_EXIT=0($lines Hint=$hints Warn=$warns)`tRUN_EXIT=$rrc`t$found`t$passed`t$failed`t$errd`t$leak"
}
$summary | Set-Content -LiteralPath "$Out\_summary-$Label.txt" -Encoding UTF8
$summary | ForEach-Object { Write-Output $_ }

# ---- A8 一次性 fixture runner（B2 模板，仓内 fail-closed 三道）----
$a8Dir = "$Out\A8-LicenseSecret"
if (Test-Path $a8Dir) { Remove-Item -Recurse -Force $a8Dir }
New-Item -ItemType Directory -Force -Path $a8Dir | Out-Null
$a8dpr = "$a8Dir\B2FixtureRunner.dpr"
(Get-Content -LiteralPath $B2TPL -Raw) -replace '__UNIT__','Test.DeepBase.LicenseSecret' | Set-Content -LiteralPath $a8dpr -NoNewline
Push-Location $Root
& $DCC -B $a8dpr "-NU$a8Dir" "-N0$a8Dir" "-E$a8Dir" "-U$U" "-NS$NS" -DDEBUG *> "$a8Dir\compile.log"
$arc = $LASTEXITCODE
Pop-Location
$a8log = "$a8Dir\run.log"
Push-Location $a8Dir
& "$a8Dir\B2FixtureRunner.exe" '--exitbehavior:Continue' '--hidebanner' *> $a8log
$arrc = $LASTEXITCODE
Pop-Location
$al = Get-Content -LiteralPath $a8log
$a8sum = @("A8-LicenseSecret","BUILD_EXIT=$arc","RUN_EXIT=$arrc") +
        @($al | Select-String -Pattern 'RUNNER_STATS|RUNNER_VERDICT|Tests Found|Tests Passed|Tests Failed|Tests Errored|No Test Fixtures found' | ForEach-Object { $_.Line.Trim() })
$a8sum | Set-Content -LiteralPath "$a8Dir\_summary.txt" -Encoding UTF8
$a8sum | ForEach-Object { Write-Output $_ }