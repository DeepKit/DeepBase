param(
    [string]$Path = "ARCH-QUICKSTART.md"
)

$ErrorActionPreference = "Stop"

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$target = Join-Path $repoRoot $Path

if (-not (Test-Path -LiteralPath $target)) {
    Write-Error "Markdown file not found: $Path"
}

$content = Get-Content -LiteralPath $target -Raw -Encoding UTF8
$targetDir = Split-Path -Parent (Resolve-Path -LiteralPath $target).Path
$candidates = New-Object System.Collections.Generic.List[object]

[regex]::Matches($content, '\[[^\]]+\]\(([^)#?]+)') | ForEach-Object {
    $link = $_.Groups[1].Value.Trim()
    if ($link -and -not ($link -match '^[a-z]+://')) {
        $candidates.Add([pscustomobject]@{ Link = $link; Base = $targetDir })
    }
}

[regex]::Matches($content, '`([^`]+\.(md|pas|dpk|dproj|ps1|bat|sql))`') | ForEach-Object {
    $link = $_.Groups[1].Value.Trim()
    if ($link -and -not ($link.Contains('*'))) {
        $base = if ($link.Contains("/") -or $link.Contains("\")) { $repoRoot } else { $targetDir }
        $candidates.Add([pscustomobject]@{ Link = $link; Base = $base })
    }
}

$missing = @()
foreach ($candidateInfo in ($candidates | Sort-Object Link,Base -Unique)) {
    $candidate = $candidateInfo.Link
    # Windows filename-illegal characters: the table had < > * : { } but not | or ".
    # Markdown table/link escaping (`dpr`\|`.dproj`, [x](a\|b)) feeds | into a
    # candidate, which then reaches GetFullPath and throws ArgumentException,
    # aborting the whole script so the document gets zero link checking.
    # (WO-20261001-MC-MC1 item 2)
    if ($candidate.Contains("<") -or $candidate.Contains(">") -or
        $candidate.Contains("*") -or $candidate.Contains(":") -or
        $candidate.Contains("{") -or $candidate.Contains("}") -or
        $candidate.Contains("|") -or $candidate.Contains('"')) {
        continue
    }

    $hasPathSeparator = $candidate.Contains("/") -or $candidate.Contains("\")
    if (-not $hasPathSeparator -and ([IO.Path]::GetExtension($candidate) -eq ".pas")) {
        continue
    }

    $normalized = $candidate.Replace('\', [string][IO.Path]::DirectorySeparatorChar)
    $basePath = $candidateInfo.Base
    try {
        $fullPath = [IO.Path]::GetFullPath((Join-Path $basePath $normalized))
    } catch {
        # Forms outside the list above (control characters, ...) must not abort the
        # whole script either: record as a broken reference so the exit code matches
        # the facts.
        $missing += $candidate
        continue
    }
    if (-not $fullPath.StartsWith($repoRoot, [System.StringComparison]::OrdinalIgnoreCase)) {
        continue
    }
    try {
        $exists = Test-Path -LiteralPath $fullPath
    } catch {
        $missing += $candidate
        continue
    }

    if (-not $exists) {
        $missing += $candidate
    }
}

if ($missing.Count -gt 0) {
    Write-Host "Broken document references in ${Path}:"
    $missing | Sort-Object | ForEach-Object { Write-Host "  $_" }
    exit 1
}

Write-Host "Document references OK: $Path"
