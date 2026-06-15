#requires -Version 7.0
<#
.SYNOPSIS
    Stub ai-call.ps1 for E2E integration tests.

.DESCRIPTION
    Writes a minimal valid unified diff file and prints its path on stdout.

    Env vars:
        STUB_AI_FAIL  : 'true' to simulate AI failure (exit 103).
#>
param(
    [string]$Backend = 'cli',
    [string]$ErrorJson = '',
    [string]$ContextDir = '',
    [string]$AllowedPaths = '',
    [string]$BlockedPaths = '',
    [string]$OutputDir = '',
    [int]$MaxTokens = 8192,
    [switch]$AllowExternalAi
)

if ($env:STUB_AI_FAIL -eq 'true') {
    [Console]::Error.WriteLine('stub-ai-call: simulating failure')
    exit 103
}

if (-not $OutputDir) { $OutputDir = (Get-Location).Path }

$aiDir = Join-Path $OutputDir '.ai-output'
if (-not (Test-Path -LiteralPath $aiDir)) {
    New-Item -ItemType Directory -Path $aiDir -Force | Out-Null
}

$diffFile = Join-Path $aiDir "stub-fix-$(Get-Date -Format 'HHmmss').diff"
$diff = @"
diff --git a/Src/TestUnit.pas b/Src/TestUnit.pas
--- a/Src/TestUnit.pas
+++ b/Src/TestUnit.pas
@@ -1,3 +1,4 @@
 unit TestUnit;
 interface
+// stub AI fix
 implementation
"@

[System.IO.File]::WriteAllText($diffFile, $diff, [System.Text.UTF8Encoding]::new($false))
Write-Output $diffFile
exit 0
