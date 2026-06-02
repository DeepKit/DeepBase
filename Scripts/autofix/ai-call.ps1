<#
.SYNOPSIS
    AutoFix AI orchestrator: build prompt, dispatch to a pluggable backend,
    return a unified-diff file path.

.DESCRIPTION
    ai-call.ps1 is the single entry point that the main loop uses to ask an
    AI for a candidate fix. It is intentionally thin (design §3.8.10):

      1. Read the dedup-grouped error record(s) from -ErrorJson.
      2. Compose a system prompt that:
            * describes the error structurally (class, msg, module, rva, scenario,
              top stack frames)
            * states the AllowedPaths and the default BlockedPaths verbatim
            * instructs the model to emit ONLY a unified diff (no prose,
              no fenced code block)
      3. Dot-source the backend submodule: ai-call.<Backend>.ps1.
         The submodule must expose a function:
              Invoke-AutoFixAiBackend -SystemPrompt <string>
                                      -UserPrompt   <string>
                                      -ErrorJson    <path>
                                      -ContextDir   <path>
                                      -OutputDir    <path>
                                      -MaxTokens    <int>
              -> writes a unified-diff text file under <OutputDir>/.ai-output/
                 and returns the absolute path of that file.
      4. On success print the diff path on stdout and exit 0.
         On any failure (backend missing, network/API error, malformed
         output, no diff produced) exit 103 (AutoFix_AiFailed).

    Secrets:
        Backends MUST read API keys from the environment, never from
        command-line parameters or files. The well-known env names are
            AUTOFIX_AI_KEY        – API token / bearer
            AUTOFIX_AI_ENDPOINT   – API base URL (optional)
            AUTOFIX_AI_MODEL      – model name override (optional)

.PARAMETER Backend
    One of 'claude' | 'openai' | 'cli'. Selects which submodule is loaded.

.PARAMETER ErrorJson
    Path to a JSON file containing the dedup-grouped error record (or an
    array). Backends are free to use either the structured object or the
    rendered system prompt.

.PARAMETER ContextDir
    Directory the backend may read from for additional source context (e.g.
    the worktree root). Backends should restrict reads to AllowedPaths.

.PARAMETER AllowedPaths
    Comma- or semicolon-separated allowlist of glob patterns. Echoed verbatim
    into the system prompt so the model knows where it is allowed to write.

.PARAMETER OutputDir
    AutoFix output directory. The diff is written under
    <OutputDir>/.ai-output/<sha1(errorJson)>.diff.

.PARAMETER MaxTokens
    Max-tokens hint passed to the backend. Default 8192.

.NOTES
    Validates Requirement 8.5.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('claude', 'openai', 'cli')]
    [string]$Backend,

    [Parameter(Mandatory)]
    [string]$ErrorJson,

    [string]$ContextDir = '.',

    [string]$AllowedPaths = '',

    [string]$BlockedPaths = '',

    [string]$OutputDir = 'autofix-output',

    [switch]$AllowExternalAi,

    [int]$MaxTokens = 8192
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Prompt assembly
# -----------------------------------------------------------------------------
function Format-StackForPrompt {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowNull()]$Stack)
    if ($null -eq $Stack) { return '(empty)' }
    $arr = @($Stack)
    if ($arr.Count -eq 0) { return '(empty)' }
    $top = [Math]::Min($arr.Count, 8)
    $sb = [System.Text.StringBuilder]::new()
    for ($i = 0; $i -lt $top; $i++) {
        $f = $arr[$i]
        if ($null -eq $f) { continue }
        $mn = if ($f.PSObject.Properties['module_name']) { [string]$f.module_name } else { '?' }
        $mb = if ($f.PSObject.Properties['module_base']) { [string]$f.module_base } else { '$00000000' }
        $rv = if ($f.PSObject.Properties['rva']) { [string]$f.rva } else { '$00000000' }
        [void]$sb.AppendLine(("  #{0,-2} {1,-32} base={2} rva={3}" -f $i, $mn, $mb, $rv))
    }
    if ($arr.Count -gt $top) {
        [void]$sb.AppendLine(("  ... ({0} more frames)" -f ($arr.Count - $top)))
    }
    return $sb.ToString().TrimEnd()
}

function Build-Prompts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$ErrorObj,
        [Parameter(Mandatory)][string[]]$AllowedGlobs,
        [Parameter(Mandatory)][string[]]$BlockedGlobs,
        [string]$ContextRoot = '.'
    )

    # The structured error may be a single record or a dedup group.
    $rep = $ErrorObj
    if ($ErrorObj.PSObject.Properties['representative']) {
        $rep = $ErrorObj.representative
    }

    $cls   = if ($rep.PSObject.Properties['class'])      { [string]$rep.'class' }      else { '' }
    $msg   = if ($rep.PSObject.Properties['msg'])        { [string]$rep.msg }          else { '' }
    $mod   = if ($rep.PSObject.Properties['module_name']){ [string]$rep.module_name }  else { '' }
    $rva   = if ($rep.PSObject.Properties['rva'])        { [string]$rep.rva }          else { '' }
    $ctx   = if ($rep.PSObject.Properties['context'])    { [string]$rep.context }      else { '' }
    $scn   = if ($rep.PSObject.Properties['scenario'])   { [string]$rep.scenario }     else { '' }
    $stack = if ($rep.PSObject.Properties['stack'])      { $rep.stack }                else { @() }
    $count = if ($ErrorObj.PSObject.Properties['count']) { [int]$ErrorObj.count }      else { 1 }

    $allowedText = if ($AllowedGlobs.Count -gt 0) { ($AllowedGlobs -join ', ') } else { '(none — caller forgot to set AllowedPaths!)' }
    $blockedText = ($BlockedGlobs -join ', ')

    $sysPrompt = @"
You are an automated code-fix assistant for the DeepBase Delphi 13.1 codebase.
Your single output must be a valid unified-diff (git format) and NOTHING ELSE.

Hard rules:
  1. Output ONLY the diff. No prose, no markdown fences, no commentary.
  2. Patch must apply with `git apply` from the repository root.
  3. Modify ONLY files matching the AllowedPaths globs below.
  4. NEVER touch files matching the BlockedPaths globs.
  5. Total +/- lines must be small (<= 200). Prefer the minimal change.
  6. Do not introduce ``with`` statements or ANSI encodings.
  7. Use Delphi 13.1 syntax where natural (inline ``var``, conditional expressions).

AllowedPaths:
  $allowedText

BlockedPaths (built-in, always blocked):
  $blockedText

Context root (read-only): $ContextRoot
"@

    $userPrompt = @"
Runtime error to fix:

  class      : $cls
  message    : $msg
  module     : $mod
  rva        : $rva
  context    : $ctx
  scenario   : $scn
  occurrences: $count

Top stack frames (RVA-based; resolve against build's .map if available):
$(Format-StackForPrompt -Stack $stack)

Produce a unified diff that fixes the root cause. Stop after the diff.
"@

    return [pscustomobject]@{
        System = $sysPrompt
        User   = $userPrompt
    }
}

function Resolve-AiOutputPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$OutDir,
        [Parameter(Mandatory)][string]$ErrorJsonPath
    )
    $base = Join-Path $OutDir '.ai-output'
    if (-not (Test-Path -LiteralPath $base)) {
        New-Item -ItemType Directory -Path $base -Force | Out-Null
    }
    $stem = Get-Sha1Hex -Text $ErrorJsonPath
    return (Join-Path $base ("$stem.diff"))
}

function Split-Csv {
    [CmdletBinding()]
    param([AllowEmptyString()][string]$Csv)
    if ([string]::IsNullOrWhiteSpace($Csv)) { return @() }
    return @($Csv -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ })
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    $externalAiAllowed = $AllowExternalAi -or ($env:AUTOFIX_ALLOW_EXTERNAL_AI -eq 'true')
    if ($Backend -in @('cli', 'claude', 'openai') -and -not $externalAiAllowed) {
        Write-AutoFixLog -Level error -Msg 'external AI backend requires explicit opt-in' -Ctx @{ backend = $Backend; hint = 'pass --allow-external-ai or set AUTOFIX_ALLOW_EXTERNAL_AI=true' }
        exit $Script:AutoFixExit_AiFailed
    }

    if (-not (Test-Path -LiteralPath $ErrorJson -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'ErrorJson not found' -Ctx @{ path = $ErrorJson }
        exit $Script:AutoFixExit_AiFailed
    }

    $errorObj = Read-JsonFile -Path $ErrorJson
    if ($null -eq $errorObj) {
        Write-AutoFixLog -Level error -Msg 'ErrorJson is empty / malformed' -Ctx @{ path = $ErrorJson }
        exit $Script:AutoFixExit_AiFailed
    }

    # If the file is an array (multi-group), pick the first group as the
    # primary target — the loop already sorted by severity.
    if ($errorObj -is [System.Collections.IEnumerable] -and -not ($errorObj -is [string])) {
        $arr = @($errorObj)
        if ($arr.Count -eq 0) {
            Write-AutoFixLog -Level error -Msg 'ErrorJson contains no records' -Ctx @{ path = $ErrorJson }
            exit $Script:AutoFixExit_AiFailed
        }
        $errorObj = $arr[0]
    }

    $allowed = Split-Csv -Csv $AllowedPaths
    $blocked = @(Get-AutoFixDefaultBlockedPaths) + @(Split-Csv -Csv $BlockedPaths)

    $prompts = Build-Prompts -ErrorObj $errorObj -AllowedGlobs $allowed `
        -BlockedGlobs $blocked -ContextRoot $ContextDir

    $outDir = Resolve-OutputDir -Path $OutputDir
    $diffPath = Resolve-AiOutputPath -OutDir $outDir -ErrorJsonPath (Resolve-Path -LiteralPath $ErrorJson).Path

    # Dispatch via dot-source so backends are pluggable without touching this file.
    $backendScript = Join-Path $PSScriptRoot ("ai-call.$Backend.ps1")
    if (-not (Test-Path -LiteralPath $backendScript -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'backend module not found' -Ctx @{ path = $backendScript }
        exit $Script:AutoFixExit_AiFailed
    }
    Write-AutoFixLog -Level info -Msg 'dispatching to AI backend' -Ctx @{
        backend = $Backend; module = $backendScript
    }
    . $backendScript

    if (-not (Get-Command -Name 'Invoke-AutoFixAiBackend' -CommandType Function -ErrorAction SilentlyContinue)) {
        Write-AutoFixLog -Level error -Msg 'backend module did not export Invoke-AutoFixAiBackend' -Ctx @{ backend = $Backend }
        exit $Script:AutoFixExit_AiFailed
    }

    $produced = Invoke-AutoFixAiBackend `
        -SystemPrompt $prompts.System `
        -UserPrompt   $prompts.User `
        -ErrorJson    (Resolve-Path -LiteralPath $ErrorJson).Path `
        -ContextDir   (Resolve-Path -LiteralPath $ContextDir).Path `
        -OutputDir    $outDir `
        -DiffPath     $diffPath `
        -MaxTokens    $MaxTokens

    if (-not $produced) {
        Write-AutoFixLog -Level error -Msg 'backend returned no diff path' -Ctx @{ backend = $Backend }
        exit $Script:AutoFixExit_AiFailed
    }
    if (-not (Test-Path -LiteralPath $produced -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'backend reported a diff path that does not exist' -Ctx @{ path = $produced }
        exit $Script:AutoFixExit_AiFailed
    }
    $sz = (Get-Item -LiteralPath $produced).Length
    if ($sz -le 0) {
        Write-AutoFixLog -Level error -Msg 'backend produced an empty diff file' -Ctx @{ path = $produced }
        exit $Script:AutoFixExit_AiFailed
    }

    Write-AutoFixLog -Level info -Msg 'AI backend produced diff' -Ctx @{
        backend = $Backend; path = $produced; bytes = $sz
    }
    [Console]::Out.WriteLine($produced)
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'ai-call.ps1'; backend = $Backend }
    exit $Script:AutoFixExit_AiFailed
}
