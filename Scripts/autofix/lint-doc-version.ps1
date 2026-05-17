<#
.SYNOPSIS
    Static lint: design.md must declare the current spec version and a
    populated Changelog section.

.DESCRIPTION
    Validates `.kiro/specs/autofix-runtime-errors/design.md`:

      (1) The header section contains a line matching:
              **版本**: v2.0       (':' may be ASCII or fullwidth '：')
      (2) A '## Changelog' section header is present.
      (3) The Changelog section contains at least 2 data rows
          (rows beginning with '| v', i.e. '| v1.0 | ...' and newer).

    These three checks are the static counterpart to Requirement 15:
    documents must remain self-consistent when the spec version bumps.

    Exit codes:
        0  — every check passed
        1  — at least one check failed (each violation printed to stderr)

.PARAMETER Path
    Path to design.md. Defaults to the spec under .kiro/specs.

.NOTES
    Validates Requirements 15.1, 15.2, 15.3.
#>
[CmdletBinding()]
param(
    [string]$Path = (Join-Path $PSScriptRoot '..\..\.kiro\specs\autofix-runtime-errors\design.md')
)

. "$PSScriptRoot/_common.ps1"

try {
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        [Console]::Error.WriteLine("lint-doc-version: design.md not found at '$Path'")
        Write-AutoFixLog -Level error -Msg 'design.md not found' -Ctx @{ path = $Path }
        exit $Script:AutoFixExit_Generic
    }

    $resolved = (Resolve-Path -LiteralPath $Path).Path
    $content = [System.IO.File]::ReadAllText($resolved, [System.Text.UTF8Encoding]::new($false))

    $violations = New-Object System.Collections.Generic.List[string]

    # (1) Version header
    if ($content -notmatch '\*\*版本\*\*\s*[:：]\s*v2\.0\b') {
        $violations.Add("missing or wrong version header (expected '**版本**: v2.0')") | Out-Null
    }

    # (2) Changelog section
    if ($content -notmatch '(?m)^\s*##\s+Changelog\s*$') {
        $violations.Add("missing '## Changelog' section header") | Out-Null
    }

    # (3) Changelog table data rows ('| vX.Y |' style). Walk the file
    # line-by-line so the count is bounded to the Changelog section only:
    # rows in any later table (e.g. file-layout tables) must not inflate
    # the count.
    $lines = $content -split "`r?`n"
    $inChangelog = $false
    $rowCount = 0
    foreach ($line in $lines) {
        if ($line -match '^\s*##\s+Changelog\s*$') {
            $inChangelog = $true
            continue
        }
        if ($inChangelog -and $line -match '^\s*##\s+\S') {
            break
        }
        if ($inChangelog -and $line -match '^\|\s*v\d') {
            $rowCount++
        }
    }
    if ($rowCount -lt 2) {
        $violations.Add("changelog table has $rowCount data row(s); need >= 2 (v1.0 + v2.0)") | Out-Null
    }

    if ($violations.Count -gt 0) {
        foreach ($v in $violations) {
            [Console]::Error.WriteLine("lint-doc-version: $v")
        }
        Write-AutoFixLog -Level error -Msg 'doc version lint failed' -Ctx @{
            path = $resolved; violations = $violations.Count
        }
        exit $Script:AutoFixExit_Generic
    }

    Write-AutoFixLog -Level info -Msg 'lint-doc-version: clean' -Ctx @{
        path = $resolved; changelog_rows = $rowCount
    }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'lint-doc-version.ps1' }
    exit $Script:AutoFixExit_Generic
}
