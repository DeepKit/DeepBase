#requires -Version 7.0
<#
.SYNOPSIS
    Mock AI CLI tool for ai-call.cli.ps1 e2e testing.

.DESCRIPTION
    Simulates an external AI CLI (claude, cursor, aider, etc.) by reading
    the prompt file passed as its first positional argument and writing a
    predefined unified diff to stdout.

    Controlled via environment variables:

      MOCK_AI_DIFF_FILE   : Path to a .diff file whose content is echoed
                             to stdout. If not set, a minimal one-line
                             patch to src/mock-fix.pas is generated.

      MOCK_AI_EXIT_CODE   : Exit code for the mock tool. Default: 0.
                             Set to non-zero to simulate AI backend failure.

      MOCK_AI_WRAP_FENCES : If 'true', wraps the diff in markdown
                             ```diff ... ``` fences to test the fence-
                             stripping logic in ai-call.cli.ps1.

      MOCK_AI_EMPTY       : If 'true', produces empty stdout (no diff).

    Usage:
        pwsh -File mock-ai-backend.ps1 <prompt-file-path>

    The prompt-file-path is passed via the '{prompt}' placeholder in
    AUTOFIX_AI_CLI_ARGS. The mock reads it (to validate the contract)
    but the output depends only on the env vars above.
#>
param([Parameter(Position = 0)][string]$PromptFile)

$exitCode = if ($env:MOCK_AI_EXIT_CODE) { [int]$env:MOCK_AI_EXIT_CODE } else { 0 }

if ($exitCode -ne 0) {
    [Console]::Error.WriteLine("mock-ai-backend: simulating failure with exit $exitCode")
    exit $exitCode
}

# Validate that the prompt file exists and has content (contract check)
if ($PromptFile -and (Test-Path -LiteralPath $PromptFile -PathType Leaf)) {
    $promptContent = [System.IO.File]::ReadAllText($PromptFile, [System.Text.Encoding]::UTF8)
    if ([string]::IsNullOrWhiteSpace($promptContent)) {
        [Console]::Error.WriteLine('mock-ai-backend: prompt file is empty')
        exit 1
    }
}

# Produce output
if ($env:MOCK_AI_EMPTY -eq 'true') {
    # Empty stdout -- tests the "produced empty stdout" path
    exit 0
}

$diff = $null
if ($env:MOCK_AI_DIFF_FILE -and (Test-Path -LiteralPath $env:MOCK_AI_DIFF_FILE -PathType Leaf)) {
    $diff = [System.IO.File]::ReadAllText($env:MOCK_AI_DIFF_FILE, [System.Text.Encoding]::UTF8)
}

if (-not $diff) {
    # Default minimal diff -- adds a single comment line
    $diff = @"
diff --git a/src/mock-fix.pas b/src/mock-fix.pas
--- a/src/mock-fix.pas
+++ b/src/mock-fix.pas
@@ -1,3 +1,4 @@
 unit MockFix;
 interface
+// AI-applied fix
 implementation
"@
}

if ($env:MOCK_AI_WRAP_FENCES -eq 'true') {
    $fence = '```'
    $output = "$fence`diff`n$diff`n$fence"
} else {
    $output = $diff
}

[Console]::Out.WriteLine($output)
exit 0
