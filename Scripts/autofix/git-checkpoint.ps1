<#
.SYNOPSIS
    Git worktree-based isolation for AutoFix iterations.

.DESCRIPTION
    Creates and manages an isolated git worktree so that failed AutoFix
    attempts never touch the main working tree. All mutations are scoped to
    the worktree path; the main tree is only touched by 'merge-back'
    (and only via fast-forward).

    Sub-actions (design §3.8.5, Req 7.1-7.5):
        -Action create     -Branch <name> [-WorktreePath <path>]
        -Action commit     -WorktreePath <path> -Message <msg>
        -Action discard    -WorktreePath <path>
        -Action merge-back -Branch <name>
        -Action cleanup    -WorktreePath <path> -Branch <name>

    Each action validates its required parameters before invoking git.
    Any git failure exits with code 101.

.OUTPUTS
    On 'create' the absolute worktree path is written to stdout.
    Other actions print a short status line and exit 0.

.NOTES
    The script never invokes 'git reset --hard' or 'git clean' on the
    main working tree. Verified statically by lint-no-reset-hard.ps1.

    Validates Requirements 7.1, 7.2, 7.3, 7.4, 7.5.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('create', 'commit', 'discard', 'merge-back', 'cleanup')]
    [string]$Action,

    [string]$Branch,

    [string]$WorktreePath,

    [string]$Message,

    [string]$BaseRef = 'HEAD'
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Invoke-Git {
    <#
    .SYNOPSIS
        Run git with explicit args, capture stdout+stderr, raise on failure.
    .NOTES
        Uses an array of args (no string interpolation) so values containing
        spaces or special characters are safe.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string[]]$Arguments,
        [string]$WorkDir
    )
    $oldLocation = $null
    if ($WorkDir) {
        if (-not (Test-Path -LiteralPath $WorkDir -PathType Container)) {
            throw "git workdir not found: $WorkDir"
        }
        $oldLocation = (Get-Location).Path
        Set-Location -LiteralPath $WorkDir
    }
    try {
        $out = & git @Arguments 2>&1
        $code = $LASTEXITCODE
        $text = ($out | Out-String).TrimEnd()
        if ($code -ne 0) {
            throw "git $($Arguments -join ' ') failed (exit=$code): $text"
        }
        return $text
    }
    finally {
        if ($oldLocation) { Set-Location -LiteralPath $oldLocation }
    }
}

function Assert-Param {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-AutoFixLog -Level error -Msg "missing required parameter -$Name" -Ctx @{ action = $Action }
        exit $Script:AutoFixExit_BadParams
    }
}

function Get-DefaultWorktreePath {
    [CmdletBinding()]
    param([string]$BranchName)
    $stamp = (Get-Date -Format 'yyyyMMdd-HHmmss')
    $slug = ($BranchName -replace '[^A-Za-z0-9._-]', '-')
    return (Join-Path ([System.IO.Path]::GetTempPath()) "autofix-wt-$slug-$stamp")
}

# -----------------------------------------------------------------------------
# Action handlers
# -----------------------------------------------------------------------------
function Invoke-CreateAction {
    Assert-Param -Name 'Branch' -Value $Branch
    if (-not $WorktreePath) {
        $WorktreePath = Get-DefaultWorktreePath -BranchName $Branch
    }
    if (Test-Path -LiteralPath $WorktreePath) {
        throw "worktree path already exists: $WorktreePath"
    }
    Write-AutoFixLog -Level info -Msg 'creating worktree' -Ctx @{ branch = $Branch; path = $WorktreePath; base = $BaseRef }
    [void](Invoke-Git -Arguments @('worktree', 'add', '-b', $Branch, $WorktreePath, $BaseRef))
    $abs = (Resolve-Path -LiteralPath $WorktreePath).Path
    [Console]::Out.WriteLine($abs)
}

function Invoke-CommitAction {
    Assert-Param -Name 'WorktreePath' -Value $WorktreePath
    Assert-Param -Name 'Message' -Value $Message
    if (-not (Test-Path -LiteralPath $WorktreePath -PathType Container)) {
        throw "worktree path not found: $WorktreePath"
    }
    Write-AutoFixLog -Level info -Msg 'committing in worktree' -Ctx @{ path = $WorktreePath }
    [void](Invoke-Git -Arguments @('add', '-A') -WorkDir $WorktreePath)
    # Allow empty? No — bail loudly so caller can branch on this.
    [void](Invoke-Git -Arguments @('commit', '-m', $Message) -WorkDir $WorktreePath)
    [Console]::Out.WriteLine('committed')
}

function Invoke-DiscardAction {
    # NOTE: This is the ONLY action that calls 'reset --hard' / 'clean'.
    # It is hard-bound to the worktree directory; the main working tree is never touched.
    # Validated statically by lint-no-reset-hard.ps1.
    Assert-Param -Name 'WorktreePath' -Value $WorktreePath
    if (-not (Test-Path -LiteralPath $WorktreePath -PathType Container)) {
        throw "worktree path not found: $WorktreePath"
    }
    Write-AutoFixLog -Level info -Msg 'discarding worktree changes' -Ctx @{ path = $WorktreePath }
    [void](Invoke-Git -Arguments @('reset', '--hard', 'HEAD') -WorkDir $WorktreePath)
    [void](Invoke-Git -Arguments @('clean', '-fd') -WorkDir $WorktreePath)
    [Console]::Out.WriteLine('discarded')
}

function Invoke-MergeBackAction {
    Assert-Param -Name 'Branch' -Value $Branch
    Write-AutoFixLog -Level info -Msg 'merging fix branch back' -Ctx @{ branch = $Branch }
    # Fast-forward only — never rewrites the main tree on conflicts
    [void](Invoke-Git -Arguments @('merge', '--ff-only', $Branch))
    [Console]::Out.WriteLine('merged')
}

function Invoke-CleanupAction {
    Assert-Param -Name 'WorktreePath' -Value $WorktreePath
    Assert-Param -Name 'Branch' -Value $Branch
    Write-AutoFixLog -Level info -Msg 'removing worktree' -Ctx @{ path = $WorktreePath; branch = $Branch }
    if (Test-Path -LiteralPath $WorktreePath) {
        [void](Invoke-Git -Arguments @('worktree', 'remove', $WorktreePath, '--force'))
    } else {
        # Worktree dir already gone — prune metadata so git stays consistent
        [void](Invoke-Git -Arguments @('worktree', 'prune'))
    }
    # Use -D so cleanup succeeds even if branch was not merged back
    [void](Invoke-Git -Arguments @('branch', '-D', $Branch))
    [Console]::Out.WriteLine('cleaned')
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    switch ($Action) {
        'create'     { Invoke-CreateAction }
        'commit'     { Invoke-CommitAction }
        'discard'    { Invoke-DiscardAction }
        'merge-back' { Invoke-MergeBackAction }
        'cleanup'    { Invoke-CleanupAction }
    }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'git-checkpoint.ps1'; action = $Action }
    exit $Script:AutoFixExit_GitFailed
}
