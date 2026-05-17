<#
.SYNOPSIS
    Static lint: only `git-checkpoint.ps1` may invoke `git reset --hard`.

.DESCRIPTION
    Scans every `scripts/autofix/*.ps1` for the literal token sequence
    `git reset --hard`. The only file in which this sequence is permitted
    is `git-checkpoint.ps1` (its `discard` action runs `git reset --hard
    HEAD` against the worktree path it created — never against the main
    working tree).

    Comments are stripped before scanning so that an English description
    of the rule (e.g. "do not run git reset --hard on the main tree") in
    a docstring does not trigger a violation.

    Exit codes:
        0  — clean
        1  — at least one violator (printed to stderr)

.NOTES
    Validates Requirement 7.1 (statically). Companion to design §7.7.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot ''),

    [string[]]$AllowedFiles = @('git-checkpoint.ps1')
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Remove-PowerShellNoise {
    <#
    .SYNOPSIS
        Strip comments AND string-literal contents so a literal mention in
        a docstring or error message does not look like real code.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Source)

    $tokens = $null
    $errs = $null
    $null = [System.Management.Automation.Language.Parser]::ParseInput($Source, [ref]$tokens, [ref]$errs)
    if ($null -eq $tokens) { return $Source }

    $sb = [System.Text.StringBuilder]::new($Source)
    $tk = [System.Management.Automation.Language.TokenKind]
    $stripKinds = @(
        $tk::Comment,
        $tk::StringLiteral,
        $tk::StringExpandable,
        $tk::HereStringLiteral,
        $tk::HereStringExpandable
    )
    foreach ($tok in @($tokens)) {
        if ($stripKinds -notcontains $tok.Kind) { continue }
        $start = $tok.Extent.StartOffset
        $len   = $tok.Extent.EndOffset - $start
        for ($i = 0; $i -lt $len; $i++) {
            $ch = $sb[$start + $i]
            if ($ch -ne "`n" -and $ch -ne "`r") {
                $sb[$start + $i] = ' '
            }
        }
    }
    return $sb.ToString()
}

function Get-FilesInScope {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Dir)
    $files = Get-ChildItem -LiteralPath $Dir -Filter '*.ps1' -File -ErrorAction SilentlyContinue
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($files)) { $list.Add($f.FullName) | Out-Null }
    return ,@($list.ToArray())
}

function Test-IsAllowed {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$FilePath,
        [Parameter(Mandatory)][string[]]$Allowed
    )
    $name = [System.IO.Path]::GetFileName($FilePath)
    foreach ($a in $Allowed) {
        if ([string]::IsNullOrWhiteSpace($a)) { continue }
        if ($a -ieq $name) { return $true }
    }
    return $false
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    $dir = if ([string]::IsNullOrWhiteSpace($Root)) { $PSScriptRoot } else { (Resolve-Path -LiteralPath $Root).Path }
    $files = Get-FilesInScope -Dir $dir

    if ($files.Count -eq 0) {
        Write-AutoFixLog -Level warn -Msg 'lint-no-reset-hard: no files in scope' -Ctx @{ dir = $dir }
        exit $Script:AutoFixExit_Ok
    }

    # Build the needle from concatenated fragments so this very file does
    # not contain the literal forbidden phrase as a single source token.
    $forbiddenWord = 'reset'
    $forbiddenFlag = '--' + 'hard'
    $needle = [regex]('(?i)\bgit\s+' + $forbiddenWord + '\s+' + [regex]::Escape($forbiddenFlag) + '\b')
    $forbiddenDisplay = 'git ' + $forbiddenWord + ' ' + $forbiddenFlag

    $violations = New-Object System.Collections.Generic.List[object]

    foreach ($f in $files) {
        if (Test-IsAllowed -FilePath $f -Allowed $AllowedFiles) { continue }
        $text = [System.IO.File]::ReadAllText($f, [System.Text.UTF8Encoding]::new($false))
        $stripped = Remove-PowerShellNoise -Source $text
        $hits = $needle.Matches($stripped)
        if ($hits.Count -gt 0) {
            $lineNos = New-Object System.Collections.Generic.List[int]
            foreach ($m in $hits) {
                $prefix = $stripped.Substring(0, $m.Index)
                $lineNo = ($prefix -split "`n").Length
                $lineNos.Add($lineNo) | Out-Null
            }
            $violations.Add([pscustomobject]@{
                file  = $f
                lines = @($lineNos.ToArray())
            }) | Out-Null
        }
    }

    if ($violations.Count -gt 0) {
        foreach ($v in $violations) {
            [Console]::Error.WriteLine(("lint-no-reset-hard: '{0}' contains forbidden '{1}' at line(s) {2}" -f $v.file, $forbiddenDisplay, ($v.lines -join ',')))
        }
        Write-AutoFixLog -Level error -Msg 'unauthorized destructive git command usage' -Ctx @{ count = $violations.Count }
        exit $Script:AutoFixExit_Generic
    }

    Write-AutoFixLog -Level info -Msg 'lint-no-reset-hard: clean' -Ctx @{ files = $files.Count; allowed = $AllowedFiles }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'lint-no-reset-hard.ps1' }
    exit $Script:AutoFixExit_Generic
}
