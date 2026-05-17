<#
.SYNOPSIS
    Static lint: every AutoFix PowerShell script must enable strict mode.

.DESCRIPTION
    For every `scripts/autofix/*.ps1` file (excluding `_common.ps1` and any
    file whose name starts with `_`), the script must satisfy at least one
    of:
        (a) Its first executable statement is a dot-source of
            `_common.ps1`     —— common path; `_common.ps1` itself sets
            StrictMode + ErrorActionPreference Stop for the caller.
        (b) Among its first 5 executable statements, both
                Set-StrictMode -Version Latest
                $ErrorActionPreference = 'Stop'
            appear.

    The PowerShell AST is used so that comment-only header blocks,
    `[CmdletBinding()]` decorations, and `param(...)` blocks do not count
    against the "first N statements" budget — they are not statements at
    the AST level.

    Exit codes:
        0  — every script in scope is compliant
        1  — at least one violator (printed to stderr)

.NOTES
    Validates Requirement 12.1 (statically). Companion to design §7.7.
#>
[CmdletBinding()]
param(
    [string]$Root = (Join-Path $PSScriptRoot ''),

    [int]$LookaheadStatements = 5
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Get-TopLevelStatements {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    $tokens = $null
    $errs = $null
    $ast = [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errs)
    if ($null -eq $ast -or $null -eq $ast.EndBlock) { return @() }
    return ,@($ast.EndBlock.Statements)
}

function Test-DotSourceCommon {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Statement)

    if ($Statement -isnot [System.Management.Automation.Language.PipelineAst]) { return $false }
    foreach ($pe in $Statement.PipelineElements) {
        if ($pe -isnot [System.Management.Automation.Language.CommandAst]) { continue }
        # Dot-source: token kind 'Dot' on the first command element.
        if ($pe.InvocationOperator -ne [System.Management.Automation.Language.TokenKind]::Dot) { continue }
        $text = $pe.Extent.Text
        if ($text -match '_common\.ps1') { return $true }
    }
    return $false
}

function Test-StrictModeStmt {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Statement)
    $t = $Statement.Extent.Text
    return ($t -match '(?i)\bSet-StrictMode\b\s+-Version\s+Latest\b')
}

function Test-StopPrefStmt {
    [CmdletBinding()]
    param([Parameter(Mandatory)]$Statement)
    $t = $Statement.Extent.Text
    return ($t -match '\$ErrorActionPreference\s*=\s*[''"]Stop[''"]')
}

function Get-FilesInScope {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Dir)

    $files = Get-ChildItem -LiteralPath $Dir -Filter '*.ps1' -File -ErrorAction SilentlyContinue
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($f in @($files)) {
        $name = $f.Name
        if ($name -eq '_common.ps1') { continue }
        if ($name.StartsWith('_')) { continue }
        $list.Add($f.FullName) | Out-Null
    }
    return ,@($list.ToArray())
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    $dir = if ([string]::IsNullOrWhiteSpace($Root)) { $PSScriptRoot } else { (Resolve-Path -LiteralPath $Root).Path }
    $files = Get-FilesInScope -Dir $dir

    if ($files.Count -eq 0) {
        Write-AutoFixLog -Level warn -Msg 'lint-powershell-strict: no files in scope' -Ctx @{ dir = $dir }
        exit $Script:AutoFixExit_Ok
    }

    $violations = New-Object System.Collections.Generic.List[object]
    foreach ($f in $files) {
        $stmts = Get-TopLevelStatements -Path $f
        if ($stmts.Count -eq 0) {
            $violations.Add([pscustomobject]@{
                file   = $f
                reason = 'no top-level statements (parse failure or empty file)'
            }) | Out-Null
            continue
        }

        # Rule (a): first statement is dot-source of _common.ps1
        if (Test-DotSourceCommon -Statement $stmts[0]) { continue }

        # Rule (b): first N statements include both StrictMode and Stop pref
        $window = $stmts | Select-Object -First $LookaheadStatements
        $hasStrict = $false
        $hasStop = $false
        foreach ($s in @($window)) {
            if (Test-StrictModeStmt -Statement $s) { $hasStrict = $true }
            if (Test-StopPrefStmt   -Statement $s) { $hasStop   = $true }
        }
        if ($hasStrict -and $hasStop) { continue }

        $violations.Add([pscustomobject]@{
            file   = $f
            reason = "first statement is not '. _common.ps1' and StrictMode/StopPref not both present in first $LookaheadStatements statements"
        }) | Out-Null
    }

    if ($violations.Count -gt 0) {
        foreach ($v in $violations) {
            [Console]::Error.WriteLine(("lint-powershell-strict: {0} -- {1}" -f $v.file, $v.reason))
        }
        Write-AutoFixLog -Level error -Msg 'PowerShell scripts missing strict-mode preamble' -Ctx @{ count = $violations.Count }
        exit $Script:AutoFixExit_Generic
    }

    Write-AutoFixLog -Level info -Msg 'lint-powershell-strict: clean' -Ctx @{ files = $files.Count }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'lint-powershell-strict.ps1' }
    exit $Script:AutoFixExit_Generic
}
