<#
.SYNOPSIS
    AutoFix AI backend: Anthropic Claude HTTP API (placeholder).

.DESCRIPTION
    Reserved for a future direct HTTP integration with the Anthropic Messages
    API (https://docs.anthropic.com/). Reads $env:AUTOFIX_AI_KEY and
    $env:AUTOFIX_AI_ENDPOINT. Until implemented, calling this backend raises
    an error so ai-call.ps1 returns 103. Use the 'cli' backend with
    AUTOFIX_AI_CLI=claude as a stop-gap.
#>

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Invoke-AutoFixAiBackend {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$SystemPrompt,
        [Parameter(Mandatory)][string]$UserPrompt,
        [Parameter(Mandatory)][string]$ErrorJson,
        [Parameter(Mandatory)][string]$ContextDir,
        [Parameter(Mandatory)][string]$OutputDir,
        [Parameter(Mandatory)][string]$DiffPath,
        [int]$MaxTokens = 8192
    )
    throw 'ai-call.claude backend is not implemented yet; use -Backend cli with $env:AUTOFIX_AI_CLI=claude'
}
