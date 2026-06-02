<#
.SYNOPSIS
    AutoFix AI backend: dispatch to an external CLI tool (claude / cursor /
    aider / any LLM CLI that accepts a prompt and emits a diff).

.DESCRIPTION
    This module is dot-sourced by ai-call.ps1. It must export exactly one
    function:

        Invoke-AutoFixAiBackend
            -SystemPrompt -UserPrompt
            -ErrorJson -ContextDir -OutputDir -DiffPath
            -MaxTokens

    and return the absolute path of a unified-diff file (the same value
    passed in as -DiffPath) on success, or throw on failure.

    Tool selection (in order):
        1. $env:AUTOFIX_AI_CLI            — exact command name
        2. claude                         — anthropic CLI
        3. cursor                         — cursor CLI
        4. aider                          — aider CLI
        5. ollama                         — local model

    Argument shape:
        - First positional argument is the combined prompt
          (system + '\n\n---\n\n' + user) written to a temp file
        - Tool stdout is captured and treated as the unified diff

    The tool MUST be on PATH already; this module does not install anything.
    Any non-zero exit, missing tool, or empty stdout raises an error so the
    caller (ai-call.ps1) returns 103.

.NOTES
    Loaded by ai-call.ps1 only. Not run directly.
#>

# Make sure strict-mode + stop-on-error are active even if dot-source happens
# from a host that didn't already configure them.
Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Resolve-AutoFixCliTool {
    [CmdletBinding()]
    param()
    $candidates = @()
    if ($env:AUTOFIX_AI_CLI) { $candidates += $env:AUTOFIX_AI_CLI }
    $candidates += @('claude', 'cursor', 'aider', 'ollama')

    foreach ($name in $candidates) {
        if ([string]::IsNullOrWhiteSpace($name)) { continue }
        $cmd = Get-Command -Name $name -ErrorAction SilentlyContinue
        if ($cmd) { return $cmd.Source }
    }
    return $null
}

function Get-AutoFixCliExtraArgs {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$ToolName)

    # Tool-specific argument shapes. Users can override entirely via
    # $env:AUTOFIX_AI_CLI_ARGS (semicolon-separated arg list, '{prompt}' is
    # substituted with the temp file path containing the combined prompt).
    if ($env:AUTOFIX_AI_CLI_ARGS) {
        return @($env:AUTOFIX_AI_CLI_ARGS -split ';' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
    }

    $base = [System.IO.Path]::GetFileNameWithoutExtension($ToolName).ToLowerInvariant()
    switch ($base) {
        'claude' { return @('-p', '{prompt}', '--output-format', 'text') }
        'cursor' { return @('agent', '--prompt-file', '{prompt}') }
        'aider'  { return @('--message-file', '{prompt}', '--no-auto-commits', '--yes-always') }
        'ollama' { return @('run', ($env:AUTOFIX_AI_MODEL ? $env:AUTOFIX_AI_MODEL : 'llama3'), '{prompt}') }
        default  { return @('{prompt}') }
    }
}

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

    $tool = Resolve-AutoFixCliTool
    if (-not $tool) {
        throw 'no AI CLI tool found on PATH (set $env:AUTOFIX_AI_CLI to override; tried: claude, cursor, aider, ollama)'
    }

    # Combined prompt -> temp file (avoids command-line length limits)
    $promptFile = [System.IO.Path]::Combine($OutputDir, '.ai-output', 'prompt.txt')
    $promptDir  = Split-Path -Parent $promptFile
    if (-not (Test-Path -LiteralPath $promptDir)) {
        New-Item -ItemType Directory -Path $promptDir -Force | Out-Null
    }
    $combined = $SystemPrompt + [Environment]::NewLine + [Environment]::NewLine + '---' + [Environment]::NewLine + [Environment]::NewLine + $UserPrompt
    [System.IO.File]::WriteAllText($promptFile, $combined, [System.Text.UTF8Encoding]::new($false))

    $rawArgs = Get-AutoFixCliExtraArgs -ToolName $tool
    $resolvedArgs = New-Object System.Collections.Generic.List[string]
    foreach ($a in $rawArgs) {
        if ($a -eq '{prompt}') {
            $resolvedArgs.Add($promptFile) | Out-Null
        } else {
            $resolvedArgs.Add($a) | Out-Null
        }
    }

    $oldLoc = (Get-Location).Path
    try {
        if (Test-Path -LiteralPath $ContextDir) {
            Set-Location -LiteralPath $ContextDir
        }
        $tmpStdout = [System.IO.Path]::GetTempFileName()
        $tmpStderr = [System.IO.Path]::GetTempFileName()
        try {
            $aiTimeoutMs = 300000  # 5 minutes — prevents a hanging AI CLI from stalling the loop
            $proc = Start-Process -FilePath $tool -ArgumentList @($resolvedArgs.ToArray()) `
                -NoNewWindow -PassThru -RedirectStandardOutput $tmpStdout -RedirectStandardError $tmpStderr
            $exited = $proc.WaitForExit($aiTimeoutMs)
            if (-not $exited) {
                try { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue } catch {}
                try { $null = $proc.WaitForExit(5000) } catch {}
                throw "AI CLI '$tool' timed out after $($aiTimeoutMs / 1000)s"
            }
            $rc = $proc.ExitCode
            $text = [System.IO.File]::ReadAllText($tmpStdout, [System.Text.Encoding]::UTF8)
            $stderr = [System.IO.File]::ReadAllText($tmpStderr, [System.Text.Encoding]::UTF8)
        } finally {
            Remove-Item $tmpStdout -Force -ErrorAction SilentlyContinue
            Remove-Item $tmpStderr -Force -ErrorAction SilentlyContinue
        }
        if ($stderr.Trim() -ne '') {
            Write-AutoFixLog -Level warn -Msg 'AI CLI stderr' -Ctx @{ tool = $tool; stderr_head = $stderr.Substring(0, [Math]::Min(500, $stderr.Length)) }
        }
        if ($rc -ne 0) {
            $head = ($text + "`n" + $stderr).Trim()
            throw "AI CLI '$tool' exited $rc; output head: $($head.Substring(0, [Math]::Min(200, $head.Length)))"
        }
        if ([string]::IsNullOrWhiteSpace($text)) {
            throw "AI CLI '$tool' produced empty stdout"
        }

        # Many CLIs wrap diffs in markdown fences, sometimes with prose around them.
        $cleaned = $text
        $fenceRe = [regex]'(?ms)```(?:diff|patch)?\s*\r?\n(.+?)\r?\n```'
        $m = $fenceRe.Match($cleaned)
        if ($m.Success) {
            $cleaned = $m.Groups[1].Value
        }

        # Normalize line endings to \n so git apply is happy.
        $cleaned = $cleaned -replace "`r`n", "`n"
        if (-not $cleaned.EndsWith("`n")) { $cleaned = $cleaned + "`n" }

        [System.IO.File]::WriteAllText($DiffPath, $cleaned, [System.Text.UTF8Encoding]::new($false))
        return $DiffPath
    }
    finally {
        Set-Location -LiteralPath $oldLoc
    }
}
