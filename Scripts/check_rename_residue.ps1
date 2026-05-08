param()

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot

$Targets = @()
$Targets += Get-ChildItem -Path $RepoRoot -Filter 'DeepBase*.dpk' -File -ErrorAction SilentlyContinue
$Targets += Get-ChildItem -Path $RepoRoot -Filter 'dclDeepBase*.dpk' -File -ErrorAction SilentlyContinue

$ScriptsPath = Join-Path $RepoRoot 'Scripts'
if (Test-Path $ScriptsPath) {
    $Targets += Get-ChildItem -Path $ScriptsPath -Filter '*.ps1' -File -ErrorAction SilentlyContinue
}

$TestsPath = Join-Path $RepoRoot 'Tests'
if (Test-Path $TestsPath) {
    $Targets += Get-ChildItem -Path $TestsPath -Recurse -Filter '*.dpr' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'DeepBase*' }
}

$ToolsPath = Join-Path $RepoRoot 'Tools'
if (Test-Path $ToolsPath) {
    $Targets += Get-ChildItem -Path $ToolsPath -Recurse -Filter '*.dpr' -File -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -like 'DeepBase*' }
}

$Targets = $Targets | Sort-Object -Property FullName -Unique
$Targets = $Targets | Where-Object { $_.FullName -ne $PSCommandPath }

Write-Host "Checking rename residue in $($Targets.Count) files ..."

$ViolationPattern = '\bDeepBase\b'
$Violations = New-Object System.Collections.Generic.List[string]

foreach ($file in $Targets) {
    $matches = Select-String -Path $file.FullName -Pattern $ViolationPattern -AllMatches -ErrorAction SilentlyContinue
    foreach ($m in $matches) {
        $relative = $file.FullName.Substring($RepoRoot.Length + 1)
        $Violations.Add("${relative}:$($m.LineNumber): $($m.Line.Trim())")
    }
}

if ($Violations.Count -gt 0) {
    Write-Host ""
    Write-Host "Rename residue detected (DeepBase keyword):" -ForegroundColor Red
    foreach ($line in $Violations) {
        Write-Host "  $line" -ForegroundColor Red
    }
    exit 1
}

Write-Host "No DeepBase rename residue found in guarded files." -ForegroundColor Green
exit 0
