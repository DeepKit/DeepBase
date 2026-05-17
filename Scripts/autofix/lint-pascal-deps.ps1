<#
.SYNOPSIS
    Static lint: ensure AutoFix Pascal units depend on neither JCL nor MadExcept.

.DESCRIPTION
    Scans the `uses` clauses of:
        Core/DeepBase.AutoFix.*.pas
        VCL/DeepBase.AutoFix.VclHook.pas
    and rejects any unit identifier that starts with `Jcl` or `MadExcept`
    (case-insensitive).

    Comments are ignored — both line comments (`// ...`), curly-brace
    blocks (`{ ... }`), and parenthesis-asterisk blocks (`(* ... *)`) — so
    that a sentence like "No JCL / MadExcept" inside a docstring does not
    trigger a false positive.

    Exit codes:
        0  — clean
        1  — at least one offending dependency was found

.NOTES
    Validates Requirement 1.6 (statically). Companion to design §7.7.
#>
[CmdletBinding()]
param(
    [string]$Root = '.',

    [string[]]$Patterns = @(
        'Core/DeepBase.AutoFix.*.pas',
        'VCL/DeepBase.AutoFix.VclHook.pas'
    )
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Remove-PascalComments {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Source)

    # Strip in this order: line comments, brace blocks, paren-star blocks.
    # Multiline-aware. We don't try to be 100% lexer-correct (no string
    # awareness) — close enough for `uses` clause inspection.
    $s = $Source
    $s = [regex]::Replace($s, '//[^\r\n]*', '')
    $s = [regex]::Replace($s, '\{[^}]*\}', ' ', 'Singleline')
    $s = [regex]::Replace($s, '\(\*.*?\*\)', ' ', 'Singleline')
    return $s
}

function Get-UsesClauses {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Source)
    $clean = Remove-PascalComments -Source $Source
    $regex = [regex]'(?is)\buses\b\s*(.*?);'
    $list = New-Object System.Collections.Generic.List[string]
    foreach ($m in $regex.Matches($clean)) {
        $list.Add($m.Groups[1].Value) | Out-Null
    }
    return ,@($list.ToArray())
}

function Get-UnitsFromClause {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Clause)
    # Each unit may carry an "in '<path>'" suffix. We only want the identifier.
    $tokens = $Clause -split '[,\r\n]'
    $units = New-Object System.Collections.Generic.List[string]
    foreach ($raw in $tokens) {
        $t = $raw.Trim()
        if (-not $t) { continue }
        # Strip "in '...'" form
        $idx = $t.ToLowerInvariant().IndexOf(' in ')
        if ($idx -ge 0) { $t = $t.Substring(0, $idx) }
        $t = $t.Trim()
        if ($t) { $units.Add($t) | Out-Null }
    }
    return ,@($units.ToArray())
}

function Test-ForbiddenUnit {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Unit)
    $u = $Unit.ToLowerInvariant()
    return ($u.StartsWith('jcl') -or $u.StartsWith('madexcept'))
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    $rootResolved = (Resolve-Path -LiteralPath $Root).Path
    $files = New-Object System.Collections.Generic.List[string]
    foreach ($pat in $Patterns) {
        $matches = Get-ChildItem -Path (Join-Path $rootResolved $pat) -File -ErrorAction SilentlyContinue
        foreach ($m in @($matches)) { $files.Add($m.FullName) | Out-Null }
    }

    if ($files.Count -eq 0) {
        Write-AutoFixLog -Level warn -Msg 'lint-pascal-deps: no files matched' -Ctx @{ root = $rootResolved; patterns = $Patterns }
        # Treat "no input" as success — there is nothing to violate.
        exit $Script:AutoFixExit_Ok
    }

    $violations = New-Object System.Collections.Generic.List[object]
    foreach ($f in $files) {
        $text = [System.IO.File]::ReadAllText($f, [System.Text.UTF8Encoding]::new($false))
        foreach ($clause in (Get-UsesClauses -Source $text)) {
            foreach ($u in (Get-UnitsFromClause -Clause $clause)) {
                if (Test-ForbiddenUnit -Unit $u) {
                    $violations.Add([pscustomobject]@{
                        file = $f
                        unit = $u
                    }) | Out-Null
                }
            }
        }
    }

    if ($violations.Count -gt 0) {
        foreach ($v in $violations) {
            [Console]::Error.WriteLine(("lint-pascal-deps: forbidden dependency '{0}' in {1}" -f $v.unit, $v.file))
        }
        Write-AutoFixLog -Level error -Msg 'forbidden Pascal dependency detected' -Ctx @{ count = $violations.Count }
        exit $Script:AutoFixExit_Generic
    }

    Write-AutoFixLog -Level info -Msg 'lint-pascal-deps: clean' -Ctx @{ files = $files.Count }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'lint-pascal-deps.ps1' }
    exit $Script:AutoFixExit_Generic
}
