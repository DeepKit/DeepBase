# DeepBase Coverage Check Script
# Usage: .\coverage_check.ps1 [-CoverageDir <path>] [-Threshold <percent>] [-FailOnLow]
#
# This script parses code coverage reports and checks against thresholds.
# It supports both XML and HTML coverage reports from Delphi Code Coverage tool.
#
# Examples:
#   .\coverage_check.ps1                           # Check with default 70% threshold
#   .\coverage_check.ps1 -Threshold 80 -FailOnLow  # Fail if coverage < 80%
#   .\coverage_check.ps1 -ShowDetails              # Show per-unit coverage details

param(
    [string]$CoverageDir = "TestResults\coverage",
    
    [int]$Threshold = 70,
    
    [int]$WarningThreshold = 80,
    
    [switch]$FailOnLow,
    
    [switch]$ShowDetails,
    
    [string]$HistoryFile = "TestResults\coverage_history.json",
    
    [switch]$SaveHistory
)

$ErrorActionPreference = "Stop"

$BaseDir = Split-Path -Parent $PSScriptRoot
$CoveragePath = Join-Path $BaseDir $CoverageDir
$EffectiveFailOnLow = $FailOnLow -or ($env:DEEPBASE_COVERAGE_FAIL_ON_LOW -eq '1') -or ($env:CI -eq 'true')

Write-Host "=============================================="
Write-Host "        DeepBase Coverage Check"
Write-Host "=============================================="
Write-Host ""
Write-Host "Coverage Directory: $CoveragePath"
Write-Host "Minimum Threshold:  $Threshold%"
Write-Host "Warning Threshold:  $WarningThreshold%"
Write-Host "Fail On Low:        $EffectiveFailOnLow"
Write-Host ""

# Check if coverage directory exists
if (-not (Test-Path $CoveragePath)) {
    Write-Host "ERROR: Coverage directory not found: $CoveragePath" -ForegroundColor Red
    Write-Host "Run tests with -Coverage flag first: .\run_tests.ps1 -Coverage"
    exit 1
}

# Find coverage XML files
$coverageFiles = Get-ChildItem -Path $CoveragePath -Filter "*.xml" -Recurse

if ($coverageFiles.Count -eq 0) {
    Write-Host "ERROR: No coverage XML files found in $CoveragePath" -ForegroundColor Red
    exit 1
}

Write-Host "Found $($coverageFiles.Count) coverage report(s)"
Write-Host ""

# Parse coverage data
$totalCoveredLines = 0
$totalLines = 0
$unitCoverage = @{}

foreach ($file in $coverageFiles) {
    Write-Host "Parsing: $($file.Name)"
    
    try {
        [xml]$xml = Get-Content $file.FullName
        
        # Parse Delphi Code Coverage XML format
        $units = $xml.SelectNodes("//srcfile")
        
        foreach ($unit in $units) {
            $unitName = $unit.name
            $covered = 0
            $total = 0
            
            $lines = $unit.SelectNodes("linecoverage/line")
            foreach ($line in $lines) {
                $total++
                if ($line.covered -eq "true" -or $line.covered -eq "1") {
                    $covered++
                }
            }
            
            if ($total -gt 0) {
                $unitCoverage[$unitName] = @{
                    Covered = $covered
                    Total = $total
                    Percent = [math]::Round(($covered / $total) * 100, 2)
                }
                
                $totalCoveredLines += $covered
                $totalLines += $total
            }
        }
    }
    catch {
        Write-Host "WARNING: Failed to parse $($file.Name): $_" -ForegroundColor Yellow
    }
}

# Calculate overall coverage
if ($totalLines -eq 0) {
    Write-Host ""
    Write-Host "WARNING: No coverage data found in reports" -ForegroundColor Yellow
    exit 0
}

$overallCoverage = [math]::Round(($totalCoveredLines / $totalLines) * 100, 2)

Write-Host ""
Write-Host "=============================================="
Write-Host "           Coverage Summary"
Write-Host "=============================================="
Write-Host ""
Write-Host "Total Lines:    $totalLines"
Write-Host "Covered Lines:  $totalCoveredLines"
Write-Host ""

# Display overall coverage with color
if ($overallCoverage -ge $WarningThreshold) {
    Write-Host "Overall Coverage: $overallCoverage%" -ForegroundColor Green
} elseif ($overallCoverage -ge $Threshold) {
    Write-Host "Overall Coverage: $overallCoverage%" -ForegroundColor Yellow
} else {
    Write-Host "Overall Coverage: $overallCoverage%" -ForegroundColor Red
}

Write-Host ""

# Show per-unit details if requested
if ($ShowDetails) {
    Write-Host "=============================================="
    Write-Host "           Per-Unit Coverage"
    Write-Host "=============================================="
    Write-Host ""
    
    # Sort by coverage percentage (ascending to show worst first)
    $sortedUnits = $unitCoverage.GetEnumerator() | Sort-Object { $_.Value.Percent }
    
    foreach ($unit in $sortedUnits) {
        $pct = $unit.Value.Percent
        $name = $unit.Key
        
        if ($pct -ge $WarningThreshold) {
            $color = "Green"
        } elseif ($pct -ge $Threshold) {
            $color = "Yellow"
        } else {
            $color = "Red"
        }
        
        Write-Host ("{0,6:N1}% - {1}" -f $pct, $name) -ForegroundColor $color
    }
    
    Write-Host ""
}

# Find units below threshold
$lowCoverageUnits = $unitCoverage.GetEnumerator() | Where-Object { $_.Value.Percent -lt $Threshold }

if ($lowCoverageUnits.Count -gt 0) {
    Write-Host "=============================================="
    Write-Host "    Units Below Threshold ($Threshold%)"
    Write-Host "=============================================="
    Write-Host ""
    
    foreach ($unit in $lowCoverageUnits) {
        Write-Host ("{0,6:N1}% - {1}" -f $unit.Value.Percent, $unit.Key) -ForegroundColor Red
    }
    
    Write-Host ""
    Write-Host "Total units below threshold: $($lowCoverageUnits.Count)" -ForegroundColor Red
    Write-Host ""
}

# Save history if requested
if ($SaveHistory) {
    $historyPath = Join-Path $BaseDir $HistoryFile
    $historyDir = Split-Path $historyPath -Parent
    
    if (-not (Test-Path $historyDir)) {
        New-Item -ItemType Directory -Path $historyDir -Force | Out-Null
    }
    
    # Load existing history
    $history = @()
    if (Test-Path $historyPath) {
        try {
            $history = Get-Content $historyPath | ConvertFrom-Json
            if ($history -isnot [array]) {
                $history = @($history)
            }
        }
        catch {
            $history = @()
        }
    }
    
    # Add new entry
    $entry = @{
        Date = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
        Coverage = $overallCoverage
        TotalLines = $totalLines
        CoveredLines = $totalCoveredLines
        UnitsCount = $unitCoverage.Count
        BelowThreshold = $lowCoverageUnits.Count
    }
    
    $history += $entry
    
    # Keep last 100 entries
    if ($history.Count -gt 100) {
        $history = $history[-100..-1]
    }
    
    # Save
    $history | ConvertTo-Json -Depth 3 | Out-File $historyPath -Encoding UTF8
    Write-Host "Coverage history saved to: $historyPath"
    Write-Host ""
}

# Final result
Write-Host "=============================================="
Write-Host "           Result"
Write-Host "=============================================="
Write-Host ""

if ($overallCoverage -ge $Threshold) {
    if ($overallCoverage -ge $WarningThreshold) {
        Write-Host "PASSED: Coverage ($overallCoverage%) meets target ($WarningThreshold%)" -ForegroundColor Green
    } else {
        Write-Host "PASSED: Coverage ($overallCoverage%) meets minimum ($Threshold%)" -ForegroundColor Yellow
        Write-Host "Consider improving coverage to reach $WarningThreshold%" -ForegroundColor Yellow
    }
    exit 0
} else {
    Write-Host "FAILED: Coverage ($overallCoverage%) is below minimum ($Threshold%)" -ForegroundColor Red
    
    if ($EffectiveFailOnLow) {
        Write-Host ""
        Write-Host "Build failed due to low coverage!" -ForegroundColor Red
        exit 1
    } else {
        Write-Host ""
        Write-Host "Warning: Coverage is low but not blocking build" -ForegroundColor Yellow
        exit 0
    }
}
