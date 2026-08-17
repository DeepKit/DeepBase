<#
.SYNOPSIS
    Encoding gate: enforces UTF-8 + BOM policy across source and docs.
.DESCRIPTION
    Scans runtime sources (Core/Features/FMX/VCL/Persistence) and docs
    (README.md, docs/, bugfix.md, tasks.md, history.md, CLAUDE.md,
    ARCH-QUICKSTART.md, CHANGELOG.md, WARP.md, Migrations/):

      - .pas / .dpr / .dpk / .dfm / .fmx files:
          * MUST be valid UTF-8.
          * MUST have UTF-8 BOM (per .editorconfig).
          * MUST NOT contain mojibake patterns (e.g. double-encoded UTF-8
            that got misread as Latin-1).

      - .md files:
          * MUST be valid UTF-8.
          * MUST NOT have UTF-8 BOM.
          * MUST NOT contain mojibake patterns.

      - SQL migration files (Migrations/**/*.sql):
          * Same rules as .md (valid UTF-8, no BOM, no mojibake).

    Any violation fails the gate when -FailOnViolation is passed.
    The script always writes a JSON report (default:
    TestResults/encoding-gate.json) so CI can archive it as an artifact.

    Added for BUG-276 / REVIEW-P0-001.
.NOTES
    Mojibake patterns detected:
      - UTF-8 BOM bytes (EF BB BF) misread as Latin-1 chars: "ï»¿" / "Ã¯Â»Â¿".
      - Common double-encoded CJK fragments: "ç¡®å®" (确定), "å³é" (取消),
        "ä¿å­" (保存), "å³é" (关闭), "éè¯¯" (错误).
      - Runs of Latin-1 high bytes that look like re-encoded UTF-8: e.g.
        "Ã" followed by another high-byte char (Ã¶ Ã¼ Ã¤ etc. are the classic
        signature of UTF-8 reinterpreted as CP1252).
#>

[CmdletBinding()]
param(
    [string]$SourcePath,
    [string]$ReportPath,
    [switch]$FailOnViolation,
    # Soft checks (BOM presence/absence) produce WARN but do not fail the
    # gate even under -FailOnViolation. Hard checks (invalid UTF-8, mojibake)
    # always fail the gate under -FailOnViolation.
    [switch]$Strict,
    # Optional newline-separated allow-list of paths (slash-normalized,
    # repo-relative) whose hard violations are reported but do not fail
    # the gate. Used to acknowledge known-broken legacy files while still
    # blocking new regressions.
    [string]$AllowlistPath
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
if ([string]::IsNullOrWhiteSpace($SourcePath)) {
    $SourcePath = $RepoRoot
}
else {
    $SourcePath = (Resolve-Path -LiteralPath $SourcePath).Path
}

if ([string]::IsNullOrWhiteSpace($ReportPath)) {
    $ReportPath = Join-Path $RepoRoot 'TestResults\encoding-gate.json'
}

# ---------------------------------------------------------------------------
# Scopes
# ---------------------------------------------------------------------------

# Runtime source dirs that must use UTF-8 with BOM (.pas/.dpr/.dpk/.dfm/.fmx).
$SourceDirs = @('Core', 'Features', 'FMX', 'VCL', 'Persistence')

# Docs: markdown files at root + docs/ subtree.
$DocRoots = @('docs')
$DocRootMarkdown = @('README.md', 'bugfix.md', 'tasks.md', 'history.md',
    'CLAUDE.md', 'ARCH-QUICKSTART.md', 'CHANGELOG.md', 'WARP.md')

# Migration scripts.
$MigrationRoots = @('Migrations')

# Explicit exclusions (dirs that may contain fixtures/legacy encodings).
$ExcludeDirNames = @(
    '.git', 'TestResults', 'Build', 'bin', 'obj',
    'node_modules', 'packages', 'third_party'
)

# ---------------------------------------------------------------------------
# Mojibake patterns
# ---------------------------------------------------------------------------

$MojibakePatterns = @(
    # UTF-8 BOM misread as Latin-1 (either byte-for-byte or double-encoded)
    [regex]::new('ï»¿'),
    [regex]::new('Ã¯Â»Â¿'),
    # Common GBK/UTF-8 mojibake CJK fragments observed in BUG-276.
    # Each is a short 3+ CJK char sequence whose UTF-8 bytes, when
    # misread as Latin-1, produce the displayed Latin-1 string.
    [regex]::new('ç¡®å®'),     # 确定
    [regex]::new('å³é'),       # 取消 (å³­é)
    [regex]::new('ä¿å­'),     # 保存 (ä¿å­)
    [regex]::new('å³³é'),     # 关闭
    [regex]::new('éè¯¯'),     # 错误
    [regex]::new('ç¡®è®¤'),  # 确认
    # Generic CP1252-as-UTF-8 signature: "Ã" followed by another high char
    # (but not "Ã©" etc. used legitimately in French/Spanish source comments).
    # Conservative: require 3+ such pairs in a run.
    [regex]::new('(?:Ã[\x80-\xBF]){3,}')
)

# ---------------------------------------------------------------------------
# UTF-8 byte-level validator
# ---------------------------------------------------------------------------

# Strict RFC-3629 validator. Returns $true iff $bytes is valid UTF-8.
# Rejects overlong encodings, surrogates (U+D800..U+DFFF), and codepoints
# above U+10FFFF.
function Test-Utf8Valid {
    param([byte[]]$Bytes)

    $i = 0
    $n = $Bytes.Length
    while ($i -lt $n) {
        $b = $Bytes[$i]
        if ($b -lt 0x80) {
            $needed = 0
        }
        elseif ($b -lt 0xC2) {
            # 0x80..0xBF are stray continuation bytes; 0xC0..0xC1 are overlong.
            return $false
        }
        elseif ($b -lt 0xE0) { $needed = 1 }
        elseif ($b -lt 0xF0) {
            $needed = 2
            if ($b -eq 0xE0 -and $i + 1 -lt $n -and $Bytes[$i + 1] -lt 0xA0) {
                return $false   # overlong 3-byte
            }
            if ($b -eq 0xED -and $i + 1 -lt $n -and $Bytes[$i + 1] -ge 0xA0) {
                return $false   # surrogate half
            }
        }
        elseif ($b -lt 0xF5) {
            $needed = 3
            if ($b -eq 0xF0 -and $i + 1 -lt $n -and $Bytes[$i + 1] -lt 0x90) {
                return $false   # overlong 4-byte
            }
            if ($b -eq 0xF4 -and $i + 1 -lt $n -and $Bytes[$i + 1] -ge 0x90) {
                return $false   # above U+10FFFF
            }
        }
        else {
            return $false
        }

        $i++
        for ($j = 0; $j -lt $needed; $j++) {
            if ($i -ge $n) { return $false }
            $c = $Bytes[$i]
            if ($c -lt 0x80 -or $c -ge 0xC0) { return $false }
            $i++
        }
    }
    return $true
}

function Get-RelativePath {
    param([string]$Base, [string]$FullPath)
    $rel = $FullPath
    if ($rel.StartsWith($Base, [StringComparison]::OrdinalIgnoreCase)) {
        $rel = $rel.Substring($Base.Length)
    }
    $rel = $rel.TrimStart([char[]]@('\', '/'))
    return $rel.Replace('\', '/')
}

function Scan-File {
    param(
        [string]$FullPath,
        [string]$ExpectedBom,   # 'yes' | 'no'
        [string]$Category       # 'source' | 'doc' | 'migration'
    )

    $bytes = [System.IO.File]::ReadAllBytes($FullPath)
    $hasBom = ($bytes.Length -ge 3) -and
              ($bytes[0] -eq 0xEF) -and
              ($bytes[1] -eq 0xBB) -and
              ($bytes[2] -eq 0xBF)

    $rel = Get-RelativePath -Base $SourcePath -FullPath $FullPath
    $violations = @()

    if ($ExpectedBom -eq 'yes' -and -not $hasBom) {
        $violations += @{
            Kind = 'MissingBom'
            Message = 'UTF-8 source must have BOM per .editorconfig'
        }
    }
    elseif ($ExpectedBom -eq 'no' -and $hasBom) {
        $violations += @{
            Kind = 'UnexpectedBom'
            Message = 'Docs/migrations must not have UTF-8 BOM'
        }
    }

    $payload = if ($hasBom) { $bytes[3..($bytes.Length - 1)] } else { $bytes }
    if (-not (Test-Utf8Valid -Bytes $payload)) {
        $violations += @{
            Kind = 'InvalidUtf8'
            Message = 'File contains bytes that are not valid UTF-8'
        }
    }

    # Mojibake scan (line by line, so we can point to a line number).
    $text = if ($hasBom) {
        [System.Text.Encoding]::UTF8.GetString($bytes, 3, $bytes.Length - 3)
    }
    else {
        [System.Text.Encoding]::UTF8.GetString($bytes)
    }
    $lines = $text -split "`n"
    for ($ln = 0; $ln -lt $lines.Length; $ln++) {
        $line = $lines[$ln]
        foreach ($rx in $MojibakePatterns) {
            $m = $rx.Match($line)
            if ($m.Success) {
                $violations += @{
                    Kind = 'Mojibake'
                    Line = ($ln + 1)
                    Pattern = $rx.ToString()
                    Match = $m.Value
                    Message = "Mojibake pattern matched at line $($ln + 1)"
                }
                break   # one mojibake report per line is enough
            }
        }
    }

    return @{
        Path = $rel
        Category = $Category
        Violations = $violations
    }
}

# ---------------------------------------------------------------------------
# File enumeration
# ---------------------------------------------------------------------------

function Should-SkipDir {
    param([string]$DirName)
    foreach ($ex in $ExcludeDirNames) {
        if ([string]::Equals($DirName, $ex, [StringComparison]::OrdinalIgnoreCase)) {
            return $true
        }
    }
    return $false
}

function Enum-Files {
    param(
        [string]$Root,
        [string[]]$Extensions,
        [switch]$Recurse
    )

    if (-not (Test-Path -LiteralPath $Root)) { return @() }
    $out = [System.Collections.Generic.List[string]]::new()
    $stack = [System.Collections.Generic.Stack[string]]::new()
    $stack.Push((Resolve-Path -LiteralPath $Root).Path)
    while ($stack.Count -gt 0) {
        $dir = $stack.Pop()
        foreach ($sub in [System.IO.Directory]::GetDirectories($dir)) {
            $name = [System.IO.Path]::GetFileName($sub)
            if (-not (Should-SkipDir -DirName $name)) {
                $stack.Push($sub)
            }
        }
        foreach ($ext in $Extensions) {
            foreach ($f in [System.IO.Directory]::GetFiles($dir, "*$ext",
                [System.IO.SearchOption]::TopDirectoryOnly)) {
                $out.Add($f)
            }
        }
    }
    return $out.ToArray()
}

$allFiles = [System.Collections.Generic.List[psobject]]::new()

foreach ($d in $SourceDirs) {
    $root = Join-Path $SourcePath $d
    foreach ($f in (Enum-Files -Root $root -Extensions @('.pas', '.dpr', '.dpk', '.dfm', '.fmx') -Recurse)) {
        $allFiles.Add([pscustomobject]@{ Path = $f; Bom = 'yes'; Category = 'source' })
    }
}

foreach ($d in $DocRoots) {
    $root = Join-Path $SourcePath $d
    foreach ($f in (Enum-Files -Root $root -Extensions @('.md') -Recurse)) {
        $allFiles.Add([pscustomobject]@{ Path = $f; Bom = 'no'; Category = 'doc' })
    }
}
foreach ($md in $DocRootMarkdown) {
    $p = Join-Path $SourcePath $md
    if (Test-Path -LiteralPath $p) {
        $allFiles.Add([pscustomobject]@{ Path = $p; Bom = 'no'; Category = 'doc' })
    }
}

foreach ($d in $MigrationRoots) {
    $root = Join-Path $SourcePath $d
    foreach ($f in (Enum-Files -Root $root -Extensions @('.sql') -Recurse)) {
        $allFiles.Add([pscustomobject]@{ Path = $f; Bom = 'no'; Category = 'migration' })
    }
}

# ---------------------------------------------------------------------------
# Scan
# ---------------------------------------------------------------------------

$results = [System.Collections.Generic.List[psobject]]::new()
$violationCount = 0
$filesMissingBom = 0
$filesWithUnexpectedBom = 0
$filesInvalidUtf8 = 0
$filesWithMojibake = 0

foreach ($entry in $allFiles) {
    $r = Scan-File -FullPath $entry.Path -ExpectedBom $entry.Bom -Category $entry.Category
    $results.Add($r)
    $kinds = @{}
    foreach ($v in $r.Violations) {
        $kinds[$v.Kind] = $true
    }
    if ($kinds.ContainsKey('MissingBom'))       { $filesMissingBom++ }
    if ($kinds.ContainsKey('UnexpectedBom'))    { $filesWithUnexpectedBom++ }
    if ($kinds.ContainsKey('InvalidUtf8'))      { $filesInvalidUtf8++ }
    if ($kinds.ContainsKey('Mojibake'))         { $filesWithMojibake++ }
    $violationCount += $r.Violations.Count
}

# ---------------------------------------------------------------------------
# Report
# ---------------------------------------------------------------------------

$null = New-Item -ItemType Directory -Force -Path `
    (Split-Path -Parent $ReportPath) | Out-Null

# Classify violations: hard (InvalidUtf8 / Mojibake) vs soft (BOM policy).
$allHardViolations = [System.Collections.Generic.List[psobject]]::new()
foreach ($r in $results) {
    foreach ($v in $r.Violations) {
        if ($v.Kind -in 'InvalidUtf8', 'Mojibake') {
            $allHardViolations.Add([pscustomobject]@{
                Path = $r.Path
                Kind = $v.Kind
                Violation = $v
            })
        }
    }
}

# Load allow-list (paths whose hard violations are downgraded to warnings).
$allowSet = [System.Collections.Generic.HashSet[string]]::new(
    [System.StringComparer]::OrdinalIgnoreCase)
if (-not [string]::IsNullOrWhiteSpace($AllowlistPath)) {
    $fullAllow = if ([System.IO.Path]::IsPathRooted($AllowlistPath)) {
        $AllowlistPath
    } else {
        Join-Path $RepoRoot $AllowlistPath
    }
    if (Test-Path -LiteralPath $fullAllow) {
        foreach ($line in (Get-Content -LiteralPath $fullAllow)) {
            $t = $line.Trim()
            if ($t.Length -eq 0 -or $t.StartsWith('#')) { continue }
            $norm = $t.Replace('\', '/')
            $null = $allowSet.Add($norm)
        }
    }
}

$hardViolations = [System.Collections.Generic.List[psobject]]::new()
$allowlistedHardViolations = [System.Collections.Generic.List[psobject]]::new()
foreach ($hv in $allHardViolations) {
    if ($allowSet.Contains($hv.Path)) {
        $allowlistedHardViolations.Add($hv)
    } else {
        $hardViolations.Add($hv)
    }
}

$hardCount = $hardViolations.Count
$allowlistedHardCount = $allowlistedHardViolations.Count
$softViolations = @($results | ForEach-Object {
    $_.Violations | Where-Object { $_.Kind -in 'MissingBom', 'UnexpectedBom' }
})
$softCount = $softViolations.Count

$report = [ordered]@{
    scanned_files = $results.Count
    total_violations = $violationCount
    hard_violations = $hardCount
    allowlisted_hard_violations = $allowlistedHardCount
    soft_violations = $softCount
    files_missing_bom = $filesMissingBom
    files_with_unexpected_bom = $filesWithUnexpectedBom
    files_invalid_utf8 = $filesInvalidUtf8
    files_with_mojibake = $filesWithMojibake
    strict_mode = [bool]$Strict
    allowlist_path = if ([string]::IsNullOrWhiteSpace($AllowlistPath)) { $null } else { $AllowlistPath }
    violations = @(
        foreach ($r in $results) {
            foreach ($v in $r.Violations) {
                $isHard = $v.Kind -in 'InvalidUtf8', 'Mojibake'
                $isAllowlisted = $isHard -and $allowSet.Contains($r.Path)
                [ordered]@{
                    path = $r.Path
                    category = $r.Category
                    kind = $v.Kind
                    severity = if ($isHard -and -not $isAllowlisted) { 'error' } else { 'warning' }
                    line = if ($v.ContainsKey('Line')) { $v.Line } else { $null }
                    match = if ($v.ContainsKey('Match')) { $v.Match } else { $null }
                    pattern = if ($v.ContainsKey('Pattern')) { $v.Pattern } else { $null }
                    message = $v.Message
                }
            }
        }
    )
}

$json = $report | ConvertTo-Json -Depth 8
# Write with explicit UTF-8 (no BOM) so the report itself is clean.
$utf8NoBom = New-Object System.Text.UTF8Encoding($false)
[System.IO.File]::WriteAllText($ReportPath, $json, $utf8NoBom)

# ---------------------------------------------------------------------------
# Console summary
# ---------------------------------------------------------------------------

Write-Host ""
Write-Host "Encoding Gate"
Write-Host "-------------"
Write-Host ("  Files scanned             : {0}" -f $results.Count)
Write-Host ("  Hard violations (errors)  : {0}" -f $hardCount)
Write-Host ("  Hard violations (allowlisted/downgraded): {0}" -f $allowlistedHardCount)
Write-Host ("    invalid UTF-8           : {0}" -f $filesInvalidUtf8)
Write-Host ("    mojibake patterns       : {0}" -f $filesWithMojibake)
Write-Host ("  Soft violations (warnings): {0}" -f $softCount)
Write-Host ("    missing BOM        : {0}  (.pas/.dpr/.dpk/.dfm/.fmx)" -f $filesMissingBom)
Write-Host ("    unexpected BOM     : {0}  (.md/.sql)" -f $filesWithUnexpectedBom)
Write-Host ("  Report                    : {0}" -f $ReportPath)

if ($hardCount -gt 0) {
    Write-Host ""
    Write-Host "Hard violations:"
    foreach ($hv in $hardViolations) {
        $lineInfo = if ($hv.Violation.ContainsKey('Line')) { ":$($hv.Violation.Line)" } else { '' }
        Write-Host ("  [{0}] {1}{2}  -- {3}" -f $hv.Kind, $hv.Path, $lineInfo, $hv.Violation.Message) -ForegroundColor Red
    }
}
if ($allowlistedHardCount -gt 0) {
    Write-Host ""
    Write-Host "Allowlisted (downgraded to warnings):"
    foreach ($hv in $allowlistedHardViolations) {
        Write-Host ("  [{0}] {1}" -f $hv.Kind, $hv.Path) -ForegroundColor Yellow
    }
}
elseif ($softCount -gt 0) {
    Write-Host ""
    Write-Host "Top soft warnings (up to 10):"
    $shown = 0
    foreach ($r in $results) {
        foreach ($v in $r.Violations) {
            if ($shown -ge 10) { break }
            $lineInfo = if ($v.ContainsKey('Line')) { ":$($v.Line)" } else { '' }
            Write-Host ("  [{0}] {1}{2}  -- {3}" -f $v.Kind, $r.Path, $lineInfo, $v.Message) -ForegroundColor Yellow
            $shown++
        }
        if ($shown -ge 10) { break }
    }
}

if ($FailOnViolation) {
    $failCount = if ($Strict) { $violationCount } else { $hardCount }
    if ($failCount -gt 0) {
        Write-Host ""
        if ($Strict) {
            Write-Host "Encoding Gate: FAILED ($failCount violations, strict)" -ForegroundColor Red
        } else {
            $fmt = "Encoding Gate: FAILED ({0} hard violations; {1} soft/BOM violations reported as warnings)" -f $hardCount, $softCount
            Write-Host $fmt -ForegroundColor Red
        }
        exit 1
    }
}

Write-Host ""
if ($hardCount -eq 0 -and $softCount -eq 0) {
    Write-Host "Encoding Gate: PASSED" -ForegroundColor Green
} elseif ($hardCount -eq 0) {
    $msg = "Encoding Gate: PASSED ({0} soft/BOM warnings, non-fatal)" -f $softCount
    Write-Host $msg -ForegroundColor Green
} else {
    $msg = "Encoding Gate: WARN ({0} hard, {1} soft violations)" -f $hardCount, $softCount
    Write-Host $msg -ForegroundColor Yellow
}
exit 0
