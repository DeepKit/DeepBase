<#
.SYNOPSIS
    AutoFix AI backend: OpenAI HTTP API (placeholder).

.DESCRIPTION
    Reserved for a future direct HTTP integration with the OpenAI Chat
    Completions / Responses API. Reads $env:AUTOFIX_AI_KEY and
    $env:AUTOFIX_AI_ENDPOINT. Until implemented, calling this backend raises
    an error so ai-call.ps1 returns 103. Use the 'cli' backend with
    AUTOFIX_AI_CLI pointing at any OpenAI-compatible CLI as a stop-gap.
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
    throw 'ai-call.openai backend is not implemented yet; use -Backend cli with an OpenAI-compatible CLI'
}
