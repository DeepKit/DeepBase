<#
.SYNOPSIS
    Validate a unified diff against allowed/blocked path globs and change budgets.

.DESCRIPTION
    Inspects a candidate unified diff before it is applied. Rejects the diff
    if any of the following holds (design §3.8.6, Req 8.1-8.5):

      1. A touched file matches any glob in BlockedPaths
      2. A touched file does NOT match any glob in AllowedPaths
      3. The total +/- line count exceeds MaxDiffLines
      4. The touched file count exceeds MaxChangedFiles
      5. A new binary file is being introduced

    Touched files are extracted from '+++ b/<path>' headers (additions and
    edits) and '--- a/<path>' headers when the new side is /dev/null
    (deletions).

    On rejection: exit 1 and append a violation record to
    autofix-output/diff-violations.jsonl. On success: exit 0.

.PARAMETER DiffFile
    Path to a unified-diff text file (UTF-8).

.PARAMETER AllowedPathsFile
    Optional file containing allowed glob patterns (one per line, '#' comments).
    May be empty/absent — in that case the diff is rejected unless every file
    is also explicitly NOT blocked AND -AllowAnyPath is set.

.PARAMETER BlockedPathsFile
    Optional file containing blocked glob patterns. When absent the built-in
    default (design §3.8.6) is used.

.PARAMETER AllowedPaths
    Inline allowed globs (semicolon-separated). Combined with file content.

.PARAMETER BlockedPaths
    Inline blocked globs (semicolon-separated). Combined with file content.

.PARAMETER MaxDiffLines
    Total +/- line cap. Default 200.

.PARAMETER MaxChangedFiles
    Touched file count cap. Default 0 means no file-count cap.

.PARAMETER OutputDir
    Output directory for the violations log. Default 'autofix-output'.

.PARAMETER AllowAnyPath
    When set, an empty allowed list is treated as 'everything allowed'
    (still subject to BlockedPaths).

.NOTES
    Validates Requirements 8.1, 8.2, 8.3, 8.4, 8.5 (Property 11).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$DiffFile,

    [string]$AllowedPathsFile,
    [string]$BlockedPathsFile,
    [string]$AllowedPaths,
    [string]$BlockedPaths,

    [int]$MaxDiffLines = 200,

    [int]$MaxChangedFiles = 0,

    [string]$OutputDir = 'autofix-output',

    [switch]$AllowAnyPath
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Read-GlobList {
    [CmdletBinding()]
    param(
        [string]$File,
        [string]$Inline
    )
    $list = New-Object System.Collections.Generic.List[string]
    if ($File -and (Test-Path -LiteralPath $File -PathType Leaf)) {
        foreach ($line in [System.IO.File]::ReadAllLines($File, [System.Text.UTF8Encoding]::new($false))) {
            $t = $line.Trim()
            if ($t -eq '' -or $t.StartsWith('#')) { continue }
            $list.Add($t) | Out-Null
        }
    }
    if ($Inline) {
        foreach ($p in $Inline -split ';') {
            $t = $p.Trim()
            if ($t) { $list.Add($t) | Out-Null }
        }
    }
    # Comma-wrap so that a single-element glob list is not auto-unwrapped
    # to a scalar string by PowerShell's function-output pipeline.
    return ,@($list.ToArray())
}

function ConvertFrom-DiffHeaderPath {
    <#
    .SYNOPSIS
        Strip 'a/' or 'b/' prefix and quoted-path syntax from a diff path token.
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Raw)
    $p = $Raw.Trim()
    # git can quote paths with embedded specials: "path with space"
    if ($p.StartsWith('"') -and $p.EndsWith('"') -and $p.Length -ge 2) {
        $p = $p.Substring(1, $p.Length - 2)
    }
    if ($p -eq '/dev/null') { return $null }
    if ($p.Length -ge 2 -and ($p.StartsWith('a/') -or $p.StartsWith('b/'))) {
        $p = $p.Substring(2)
    }
    return $p
}

function Read-DiffSummary {
    <#
    .SYNOPSIS
        Walk a unified diff once and return touched files + +/- line totals.
    .OUTPUTS
        @{ Files = [string[]]; Plus = int; Minus = int; Binary = bool }
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)

    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "diff file not found: $Path"
    }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false))

    $files = New-Object System.Collections.Generic.HashSet[string]
    $plus = 0
    $minus = 0
    $binary = $false
    $oldSide = $null   # '--- a/...'
    $inHunk = $false

    foreach ($raw in $lines) {
        if ($null -eq $raw) { continue }

        if ($raw.StartsWith('Binary files ')) {
            $binary = $true
            continue
        }

        if ($raw.StartsWith('--- ')) {
            $oldSide = ConvertFrom-DiffHeaderPath -Raw ($raw.Substring(4))
            $inHunk = $false
            continue
        }
        if ($raw.StartsWith('+++ ')) {
            $newSide = ConvertFrom-DiffHeaderPath -Raw ($raw.Substring(4))
            $touched = if ($newSide) { $newSide } elseif ($oldSide) { $oldSide } else { $null }
            if ($touched) { [void]$files.Add((ConvertTo-NormalizedPath -Path $touched)) }
            $inHunk = $false
            continue
        }
        if ($raw.StartsWith('@@')) {
            $inHunk = $true
            continue
        }

        if ($inHunk) {
            if ($raw.Length -ge 1) {
                $c = $raw[0]
                if ($c -eq '+') { $plus++ }
                elseif ($c -eq '-') { $minus++ }
            }
        }
    }

    return @{
        Files  = @($files)
        Plus   = $plus
        Minus  = $minus
        Binary = $binary
    }
}

function Write-Violation {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Reason,
        [string[]]$Files = @(),
        [int]$Lines = 0,
        [string]$Detail = ''
    )
    $outDir = Resolve-OutputDir -Path $OutputDir
    $logPath = Join-Path $outDir 'diff-violations.jsonl'
    $rec = [pscustomobject]@{
        ts        = Get-AutoFixTimestamp
        reason    = $Reason
        files     = @($Files)
        lines     = $Lines
        diff_file = $DiffFile
        detail    = $Detail
    }
    Write-Jsonl -Path $logPath -Object $rec -Append
    Write-AutoFixLog -Level warn -Msg "diff rejected: $Reason" -Ctx @{ files = $Files; lines = $Lines; detail = $Detail }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    if (-not (Test-Path -LiteralPath $DiffFile -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'diff file not found' -Ctx @{ path = $DiffFile }
        exit $Script:AutoFixExit_BadParams
    }

    $allowed = Read-GlobList -File $AllowedPathsFile -Inline $AllowedPaths
    $blocked = Read-GlobList -File $BlockedPathsFile -Inline $BlockedPaths

    # Always layer in the built-in default block list — caller cannot opt out of
    # the framework-protection paths even by omitting the file (design §3.8.6).
    $defaultBlocked = Get-AutoFixDefaultBlockedPaths
    $blockedAll = New-Object System.Collections.Generic.List[string]
    foreach ($g in $defaultBlocked) { $blockedAll.Add($g) | Out-Null }
    foreach ($g in $blocked)        { $blockedAll.Add($g) | Out-Null }
    $blocked = @($blockedAll.ToArray())

    $summary = Read-DiffSummary -Path $DiffFile

    if ($summary.Binary) {
        Write-Violation -Reason 'binary_file' -Files $summary.Files -Detail 'binary diff section detected'
        exit $Script:AutoFixExit_Generic
    }

    $totalLines = [int]$summary.Plus + [int]$summary.Minus
    if ($totalLines -gt $MaxDiffLines) {
        Write-Violation -Reason 'max_lines_exceeded' -Files $summary.Files -Lines $totalLines `
            -Detail "lines=$totalLines, cap=$MaxDiffLines"
        exit $Script:AutoFixExit_Generic
    }

    if ($summary.Files.Count -eq 0) {
        Write-Violation -Reason 'no_files_touched' -Detail 'diff parsed without any touched files'
        exit $Script:AutoFixExit_Generic
    }

    if ($MaxChangedFiles -gt 0 -and $summary.Files.Count -gt $MaxChangedFiles) {
        Write-Violation -Reason 'max_changed_files_exceeded' -Files $summary.Files -Lines $totalLines `
            -Detail "files=$($summary.Files.Count), cap=$MaxChangedFiles"
        exit $Script:AutoFixExit_Generic
    }

    $blockedHits = New-Object System.Collections.Generic.List[string]
    $notAllowed  = New-Object System.Collections.Generic.List[string]
    foreach ($f in $summary.Files) {
        if (Test-PathGlob -Path $f -Globs $blocked) {
            $blockedHits.Add($f) | Out-Null
            continue
        }
        if ($allowed.Count -eq 0) {
            if (-not $AllowAnyPath) { $notAllowed.Add($f) | Out-Null }
            continue
        }
        if (-not (Test-PathGlob -Path $f -Globs $allowed)) {
            $notAllowed.Add($f) | Out-Null
        }
    }

    if ($blockedHits.Count -gt 0) {
        Write-Violation -Reason 'blocked_path' -Files (@($blockedHits.ToArray())) -Lines $totalLines
        exit $Script:AutoFixExit_Generic
    }
    if ($notAllowed.Count -gt 0) {
        Write-Violation -Reason 'not_in_allowed' -Files (@($notAllowed.ToArray())) -Lines $totalLines
        exit $Script:AutoFixExit_Generic
    }

    Write-AutoFixLog -Level info -Msg 'diff accepted' -Ctx @{
        files = $summary.Files
        file_count = $summary.Files.Count
        plus  = $summary.Plus
        minus = $summary.Minus
    }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'diff-guard.ps1' }
    exit $Script:AutoFixExit_Generic
}
