# UniBase Stress Test Runner
# PowerShell script for running automated stress tests
#
# Usage:
#   .\run_stress_tests.ps1 -TestType all
#   .\run_stress_tests.ps1 -TestType quick
#   .\run_stress_tests.ps1 -TestType memory48h
#   .\run_stress_tests.ps1 -TestType eventbus -DurationSec 300 -ThreadCount 10 -VerboseOutput

param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("all", "quick", "memory48h", "eventbus", "concurrency", "connectionpool", "stability")]
    [string]$TestType = "quick",

    [Parameter(Mandatory=$false)]
    [int]$DurationSec = 60,

    [Parameter(Mandatory=$false)]
    [int]$ThreadCount = 8,

    [Parameter(Mandatory=$false)]
    [string]$OutputDir = ".\StressTestResults",

    [Parameter(Mandatory=$false)]
    [switch]$GenerateReport,

    [Parameter(Mandatory=$false)]
    [switch]$VerboseOutput
)

# Configuration
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = (Resolve-Path (Join-Path $ScriptDir "..\..")).Path
$TestExeCandidates = @(
    (Join-Path $ScriptDir "UniBaseStressTests.exe"),
    (Join-Path $ProjectRoot "Tests\Win64\Debug\UniBaseStressTests.exe"),
    (Join-Path $ProjectRoot "Tests\Stress\Win64\Debug\UniBaseStressTests.exe")
)
$TestExe = $TestExeCandidates | Where-Object { Test-Path $_ } | Select-Object -First 1
$ResultsDir = Join-Path $ProjectRoot $OutputDir
$Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"

# Colors for output
function Write-Info { param($msg) Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Write-Success { param($msg) Write-Host "[OK] $msg" -ForegroundColor Green }
function Write-Warning { param($msg) Write-Host "[WARN] $msg" -ForegroundColor Yellow }
function Write-Error { param($msg) Write-Host "[ERROR] $msg" -ForegroundColor Red }

# Ensure output directory exists
function Ensure-OutputDir {
    if (-not (Test-Path $ResultsDir)) {
        New-Item -ItemType Directory -Path $ResultsDir -Force | Out-Null
        Write-Info "Created output directory: $ResultsDir"
    }
}

# Check if test executable exists
function Check-TestExecutable {
    if (-not $TestExe) {
        Write-Error "Test executable not found. Checked:"
        foreach ($Candidate in $TestExeCandidates) {
            Write-Error "  $Candidate"
        }
        Write-Info "Please build the test project first:"
        Write-Info "  cd Tests\Stress"
        Write-Info "  dcc64 -B -U..\..\Core;..\..\Persistence;..\..\ThirdParty\Payment;..\..\ThirdParty\DB UniBaseStressTests.dpr"
        exit 1
    }
}

# Run stress test with specified parameters
function Run-StressTest {
    param(
        [string]$TestName,
        [int]$Duration,
        [int]$Threads,
        [string]$OutputFile
    )

    Write-Info "Starting stress test: $TestName"
    Write-Info "  Duration: $Duration seconds"
    Write-Info "  Threads: $Threads"
    Write-Info "  Output: $OutputFile"

    $StartTime = Get-Date

    $Arguments = @(
        "-suite=$TestName",
        "-duration=$Duration",
        "-threads=$Threads",
        "-output=$OutputFile",
        "-format=json"
    )

    if ($VerboseOutput) {
        $Arguments += "-verbose"
    }

    try {
        $Process = Start-Process -FilePath $TestExe -ArgumentList $Arguments -NoNewWindow -PassThru -Wait
        $EndTime = Get-Date
        $Elapsed = $EndTime - $StartTime

        if ($Process.ExitCode -eq 0) {
            Write-Success "Test completed successfully in $($Elapsed.TotalSeconds.ToString('F2')) seconds"
            return $true
        } else {
            Write-Error "Test failed with exit code: $($Process.ExitCode)"
            return $false
        }
    } catch {
        Write-Error "Failed to run test: $_"
        return $false
    }
}

# Generate HTML report from JSON results
function Generate-HtmlReport {
    param([string]$JsonFile, [string]$HtmlFile)

    if (-not (Test-Path $JsonFile)) {
        Write-Warning "JSON results file not found: $JsonFile"
        return
    }

    try {
        $Results = Get-Content $JsonFile | ConvertFrom-Json

        $Html = @"
<!DOCTYPE html>
<html>
<head>
    <title>UniBase Stress Test Report - $Timestamp</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 4px rgba(0,0,0,0.1); }
        h1 { color: #333; border-bottom: 2px solid #4CAF50; padding-bottom: 10px; }
        h2 { color: #555; margin-top: 30px; }
        .summary { display: grid; grid-template-columns: repeat(4, 1fr); gap: 15px; margin: 20px 0; }
        .card { background: #f9f9f9; padding: 15px; border-radius: 5px; text-align: center; }
        .card.success { border-left: 4px solid #4CAF50; }
        .card.warning { border-left: 4px solid #FF9800; }
        .card.error { border-left: 4px solid #f44336; }
        .card .value { font-size: 24px; font-weight: bold; color: #333; }
        .card .label { font-size: 12px; color: #666; }
        table { width: 100%; border-collapse: collapse; margin: 20px 0; }
        th, td { padding: 12px; text-align: left; border-bottom: 1px solid #ddd; }
        th { background: #4CAF50; color: white; }
        tr:hover { background: #f5f5f5; }
        .pass { color: #4CAF50; font-weight: bold; }
        .fail { color: #f44336; font-weight: bold; }
        .metrics { margin: 20px 0; }
        .metric-row { display: flex; justify-content: space-between; padding: 8px 0; border-bottom: 1px solid #eee; }
        .metric-name { color: #555; }
        .metric-value { font-weight: bold; }
    </style>
</head>
<body>
    <div class="container">
        <h1>UniBase Stress Test Report</h1>
        <p>Generated: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")</p>

        <div class="summary">
            <div class="card success">
                <div class="value">$($Results.TotalTests)</div>
                <div class="label">Total Tests</div>
            </div>
            <div class="card success">
                <div class="value">$($Results.PassedTests)</div>
                <div class="label">Passed</div>
            </div>
            <div class="card $(if($Results.FailedTests -gt 0){'error'}else{'success'})">
                <div class="value">$($Results.FailedTests)</div>
                <div class="label">Failed</div>
            </div>
            <div class="card">
                <div class="value">$($Results.DurationSec)s</div>
                <div class="label">Duration</div>
            </div>
        </div>

        <h2>Test Results</h2>
        <table>
            <tr>
                <th>Test Name</th>
                <th>Status</th>
                <th>Operations</th>
                <th>Errors</th>
                <th>Avg Latency (ms)</th>
                <th>P99 Latency (ms)</th>
            </tr>
"@

        foreach ($Test in $Results.Tests) {
            $StatusClass = if ($Test.Status -eq "Pass") { "pass" } else { "fail" }
            $Html += @"
            <tr>
                <td>$($Test.Name)</td>
                <td class="$StatusClass">$($Test.Status)</td>
                <td>$($Test.TotalOps)</td>
                <td>$($Test.Errors)</td>
                <td>$($Test.AvgLatencyMs.ToString('F2'))</td>
                <td>$($Test.P99LatencyMs.ToString('F2'))</td>
            </tr>
"@
        }

        $Html += @"
        </table>

        <h2>System Metrics</h2>
        <div class="metrics">
            <div class="metric-row">
                <span class="metric-name">Peak Memory Usage</span>
                <span class="metric-value">$($Results.PeakMemoryMB.ToString('F2')) MB</span>
            </div>
            <div class="metric-row">
                <span class="metric-name">Average CPU Usage</span>
                <span class="metric-value">$($Results.AvgCpuPercent.ToString('F1'))%</span>
            </div>
            <div class="metric-row">
                <span class="metric-name">Total Operations</span>
                <span class="metric-value">$($Results.TotalOperations)</span>
            </div>
            <div class="metric-row">
                <span class="metric-name">Operations/Second</span>
                <span class="metric-value">$($Results.OpsPerSecond.ToString('F0'))</span>
            </div>
        </div>
    </div>
</body>
</html>
"@

        $Html | Out-File -FilePath $HtmlFile -Encoding UTF8
        Write-Success "HTML report generated: $HtmlFile"
    } catch {
        Write-Error "Failed to generate HTML report: $_"
    }
}

# Main execution
Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  UniBase Stress Test Runner" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

Ensure-OutputDir
Check-TestExecutable

$ResultFile = Join-Path $ResultsDir "stress_test_$Timestamp.json"
$ReportFile = Join-Path $ResultsDir "stress_test_$Timestamp.html"
$Success = $true

switch ($TestType) {
    "quick" {
        Write-Info "Running quick stress test suite (60 seconds each)"
        $Success = Run-StressTest -TestName "quick" -Duration 60 -Threads $ThreadCount -OutputFile $ResultFile
    }

    "all" {
        Write-Info "Running all stress tests"
        $Success = Run-StressTest -TestName "all" -Duration $DurationSec -Threads $ThreadCount -OutputFile $ResultFile
    }

    "memory48h" {
        Write-Info "Running 48-hour memory leak test"
        Write-Warning "This test will run for 48 hours!"
        $48Hours = 48 * 60 * 60
        $Success = Run-StressTest -TestName "memory48h" -Duration $48Hours -Threads $ThreadCount -OutputFile $ResultFile
    }

    "eventbus" {
        Write-Info "Running EventBus stress tests"
        $Success = Run-StressTest -TestName "eventbus" -Duration $DurationSec -Threads $ThreadCount -OutputFile $ResultFile
    }

    "concurrency" {
        Write-Info "Running concurrency stress tests"
        $Success = Run-StressTest -TestName "concurrency" -Duration $DurationSec -Threads $ThreadCount -OutputFile $ResultFile
    }

    "connectionpool" {
        Write-Info "Running connection pool stress tests"
        $Success = Run-StressTest -TestName "connectionpool" -Duration $DurationSec -Threads $ThreadCount -OutputFile $ResultFile
    }

    "stability" {
        Write-Info "Running stability stress tests"
        $Success = Run-StressTest -TestName "stability" -Duration $DurationSec -Threads $ThreadCount -OutputFile $ResultFile
    }
}

if ($GenerateReport -and (Test-Path $ResultFile)) {
    Generate-HtmlReport -JsonFile $ResultFile -HtmlFile $ReportFile
}

Write-Host ""
if ($Success) {
    Write-Success "All stress tests completed successfully!"
    Write-Info "Results saved to: $ResultFile"
    if ($GenerateReport) {
        Write-Info "Report saved to: $ReportFile"
    }
    exit 0
} else {
    Write-Error "Some stress tests failed!"
    exit 1
}
