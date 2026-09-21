# R5-M2 UBS2 migration drill
#
# Rehearses the v1 -> v2 secret-envelope migration end to end with real v1 bytes:
# executes the migration cases on the unified test runner and archives the raw
# console output. Run with -DryRun to only print what would be executed.
#
# Build the exe first with Scripts/run_tests.ps1 (single compile entry); this script
# only filters cases, it never compiles.
#
# The per-record re-encryption itself lives in TUBS2Migrator.Reencrypt
# (Core/DeepBase.Security.UBS2.Migration.pas); the store-wide sweep lives in
# TDeepBaseSecurity.MigrateLegacyUBS2Secrets (macOS/Linux).
param(
    [switch]$DryRun
)

$ErrorActionPreference = 'Stop'
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

$repo = Split-Path -Parent $PSScriptRoot
$exe = Join-Path $repo 'Tests\DeepBaseTests.exe'
$rawLog = Join-Path $repo 'TestResults\20260920-AUDIT-M2-migration-drill.log'
$cases = @(
    'Test.DeepBase.Security.UBS2.TTestUBS2Envelope.Test_Reencrypt_LegacyV1_BecomesReadableV2',
    'Test.DeepBase.Security.UBS2.TTestUBS2Envelope.Test_Reencrypt_WrongLegacyPassphrase_LeavesRecordUntouched',
    'Test.DeepBase.Security.UBS2.TTestUBS2Envelope.Test_NeedsMigration_ClassifiesRecords',
    'Test.DeepBase.Security.UBS2.TTestUBS2Envelope.Test_Unprotect_ForeignFormatVersion_RaisesMigrationHint'
)

New-Item -ItemType Directory -Force -Path (Split-Path -Parent $rawLog) | Out-Null

if ($DryRun) {
    Write-Output "DRY-RUN: would execute against $exe"
    $cases | ForEach-Object { Write-Output "  case: $_" }
    exit 0
}

if (-not (Test-Path $exe)) {
    throw "Test runner not built: $exe"
}

& $exe "-run:$($cases -join ',')" | Tee-Object -FilePath $rawLog
$code = $LASTEXITCODE
Write-Output "drill_exit=$code"
Write-Output "raw_output=$rawLog"
exit $code
