<#
.SYNOPSIS
    Scans runtime source (Core/Features/FMX/VCL/Persistence) for TODO/FIXME/STUB
    markers and for runtime API stubs that silently succeed.
.DESCRIPTION
    Acceptance gate: any remaining TODO must be annotated with a task id
    (e.g. TODO(BUG-281) or TODO #JIRA-123) and a short owner hint.
    Unannotated TODOs cause the check to fail.
    Optionally (-IncludeStubApis) also flags public methods whose body
    is essentially a silent fallback (Result := Default/False/0/'') with
    a leading // STUB comment.
.NOTES
    Added for BUG-281 (REVIEW-P1-004).
#>

param(
    [string]$SourcePath,
    [string]$ReportPath,
    [switch]$FailOnViolation,
    [switch]$IncludeStubApis
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
    $ReportPath = Join-Path $RepoRoot 'TestResults\runtime-todo-report.json'
}

# Runtime source roots that are subject to the gate.
$RuntimeRoots = @('Core', 'Features', 'FMX', 'VCL', 'Persistence')

# Explicit opt-outs: test/example/demo dirs that may contain TODOs freely.
$ExcludeDirs = @(
    'Tests',
    'Test',
    'Examples',
    'Demos',
    'ThirdParty',
    'ThirdParty.Vendor',
    '.git',
    'TestResults',
    'Build',
    'docs'
)

# Annotated TODO pattern -- must include a task id in parens.
# Accepts:
#   TODO(BUG-281)
#   TODO(BUG-281): ...
#   TODO #JIRA-123 ...
#   TODO [JIRA-123] ...
#   FIXME(BUG-281)
#   STUB(BUG-281)
$AnnotatedTodoRegex = [regex]::new(
    '(?i)\b(TODO|FIXME|STUB)\s*[\(\[\{]?\s*(BUG-\d+|JIRA-\w+|GH-\w+|DL-P0-\w+|REVIEW-\w+|DATA-P\w+|QA-P\w+|OPS-P\w+|UPD-P\w+|COM-P\w+|SPEECH-\w+)[\)\]\}]?',
    'IgnoreCase'
)

# Unannotated TODO marker -- any bare TODO/FIXME/STUB.
$UnannotatedTodoRegex = [regex]::new(
    '(?i)//\s*(TODO|FIXME|STUB)\b(?!\s*[\(\[\{])',
    'IgnoreCase'
)

# Public method stub pattern: function header + body that is just a silent fallback.
# Conservative -- only flag lines literally annotated with "// STUB" / "// STUB API".
$StubApiMarkerRegex = [regex]::new(
    '(?i)//\s*STUB\b',
    'IgnoreCase'
)

function Read-Text {
    param([string]$Path)
    return [System.IO.File]::ReadAllText($Path, [System.Text.Encoding]::UTF8)
}

function Is-Excluded {
    param([string]$RelativePath)
    $Normalized = $RelativePath.Replace('/', '\')
    foreach ($Dir in $ExcludeDirs) {
        if ($Normalized -match "(?i)(^|\\)$Dir(\\|$)") {
            return $true
        }
    }
    return $false
}

$Violations = New-Object System.Collections.Generic.List[object]

function Add-Violation {
    param(
        [ValidateSet('Error', 'Warning', 'Info')]
        [string]$Severity,
        [string]$Rule,
        [string]$Subject,
        [int]$Line,
        [string]$Message
    )
    $v = New-Object PSObject
    $v | Add-Member -NotePropertyName Severity -NotePropertyValue $Severity
    $v | Add-Member -NotePropertyName Rule     -NotePropertyValue $Rule
    $v | Add-Member -NotePropertyName Subject  -NotePropertyValue $Subject
    $v | Add-Member -NotePropertyName Line     -NotePropertyValue $Line
    $v | Add-Member -NotePropertyName Message  -NotePropertyValue $Message
    $Violations.Add($v)
}

$TotalFiles = 0
$TotalTodos = 0
$AnnotatedCount = 0
$UnannotatedCount = 0
$StubApiCount = 0

foreach ($Root in $RuntimeRoots) {
    $Dir = Join-Path $SourcePath $Root
    if (-not (Test-Path -LiteralPath $Dir)) { continue }

    Get-ChildItem -LiteralPath $Dir -Filter '*.pas' -Recurse | ForEach-Object {
        $FullPath = $_.FullName
        $RelativePath = (Resolve-Path -LiteralPath $FullPath -Relative).TrimStart('.\')

        if (Is-Excluded $RelativePath) { return }

        $TotalFiles++
        $Lines = Read-Text $FullPath
        $LineList = $Lines -split '\r?\n'

        $lineNum = 0
        foreach ($Line in $LineList) {
            $lineNum++

            # Annotated TODO -- fine, count but do not report.
            $m = $AnnotatedTodoRegex.Match($Line)
            if ($m.Success) {
                $TotalTodos++
                $AnnotatedCount++
                continue
            }

            # Unannotated TODO -- hard error.
            $m = $UnannotatedTodoRegex.Match($Line)
            if ($m.Success) {
                $TotalTodos++
                $UnannotatedCount++
                Add-Violation 'Error' 'RuntimeUnannotatedTodo' $RelativePath $lineNum `
                    ("Unannotated TODO -- annotate with task id: " + $Line.Trim())
                continue
            }

            # STUB API marker -- only flagged when -IncludeStubApis.
            if ($IncludeStubApis) {
                $m = $StubApiMarkerRegex.Match($Line)
                if ($m.Success) {
                    $StubApiCount++
                    Add-Violation 'Warning' 'RuntimeStubApiMarker' $RelativePath $lineNum `
                        ("STUB marker without task id -- annotate or implement: " + $Line.Trim())
                }
            }
        }
    }
}

$Varr = [object[]]$Violations
$Report = @{
    GeneratedAt   = (Get-Date -Format 'o')
    SourcePath    = $SourcePath
    TotalFiles    = $TotalFiles
    TotalTodos    = $TotalTodos
    Annotated     = $AnnotatedCount
    Unannotated   = $UnannotatedCount
    StubApis      = $StubApiCount
    Violations    = $Varr
}

$ReportDir = Split-Path -Parent $ReportPath
if ($ReportDir -and -not (Test-Path -LiteralPath $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}
$Report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

$ErrorCount = @($Violations | Where-Object { $_.Severity -eq 'Error' }).Length
$WarningCount = @($Violations | Where-Object { $_.Severity -eq 'Warning' }).Length

Write-Host ''
Write-Host "=== Runtime TODO/Stub Gate ==="
Write-Host "Files scanned: $TotalFiles"
Write-Host "TODOs total:   $TotalTodos (annotated $AnnotatedCount / unannotated $UnannotatedCount)"
if ($IncludeStubApis) {
    Write-Host "STUB markers:  $StubApiCount"
}
Write-Host "Errors:        $ErrorCount"
Write-Host "Warnings:      $WarningCount"
Write-Host "Report:        $ReportPath"

foreach ($v in $Violations) {
    $tag = switch ($v.Severity) {
        'Error'   { '[Error]' }
        'Warning' { '[Warning]' }
        default   { '[Info]' }
    }
    Write-Host "$tag $($v.Rule) $($v.Subject):$($v.Line) -- $($v.Message)"
}

if ($FailOnViolation -and $ErrorCount -gt 0) {
    exit 1
}
exit 0
