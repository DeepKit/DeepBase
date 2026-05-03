# UniBase Test Runner Script
# Usage: .\run_tests.ps1 [-Type Unit|Integration|All] [-CI] [-Report]

param(
    [ValidateSet('Unit', 'Integration', 'All')]
    [string]$Type = 'All',

    [ValidateSet('Win32', 'Win64')]
    [string]$Platform = 'Win64',
    
    [switch]$CI,
    
    [switch]$Report,
    
    [string]$OutputDir = "TestResults",
    
    [switch]$Coverage,
    
    [string]$CoverageToolPath
)

$ErrorActionPreference = "Stop"

# Configuration
$BaseDir = Split-Path -Parent $PSScriptRoot
$TestsDir = Join-Path $BaseDir "Tests"
$IntegrationDir = Join-Path $TestsDir "Integration"
$OutputPath = Join-Path $BaseDir $OutputDir
$BuildOutputDir = Join-Path $OutputPath "build"
$DcuOutputDir = Join-Path $BuildOutputDir "dcu\$Platform"
$Dcc32 = "d:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc32.exe"
$Dcc64 = "d:\Program Files (x86)\Embarcadero\Studio\23.0\bin\dcc64.exe"

if ($Platform -eq 'Win64') {
    $DelphiCompiler = $Dcc64
} else {
    $DelphiCompiler = $Dcc32
}

if (-not (Test-Path $DelphiCompiler)) {
    throw "Delphi compiler not found: $DelphiCompiler"
}

# Resolve coverage tool path (if requested)
if (-not $CoverageToolPath) {
    if ($env:DELPHI_COVERAGE_TOOL) {
        $CoverageToolPath = $env:DELPHI_COVERAGE_TOOL
    } else {
        $CoverageToolPath = "CodeCoverage.exe"
    }
}
$CoverageOutputDir = Join-Path $OutputPath "coverage"

# Ensure output directory exists
if (-not (Test-Path $OutputPath)) {
    New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
}

if ($Coverage -and -not (Test-Path $CoverageOutputDir)) {
    New-Item -ItemType Directory -Path $CoverageOutputDir -Force | Out-Null
}

if (-not (Test-Path $DcuOutputDir)) {
    New-Item -ItemType Directory -Path $DcuOutputDir -Force | Out-Null
}

Write-Host "=============================================="
Write-Host "        UniBase Test Runner"
Write-Host "=============================================="
Write-Host ""
Write-Host "Base Directory: $BaseDir"
Write-Host "Test Type: $Type"
Write-Host "Platform: $Platform"
Write-Host "CI Mode: $CI"
Write-Host "Output: $OutputPath"
Write-Host "DCU Output: $DcuOutputDir"
Write-Host ""

# Build flags
$BuildFlags = @()
if ($CI) {
    $BuildFlags += "-DCI"
}

# Unit paths
$UnitPaths = @(
    "$BaseDir\Core",
    "$BaseDir\Features",
    "$BaseDir\Persistence",
    "$BaseDir\VCL",
    "$BaseDir\FMX",
    "$BaseDir\ThirdParty\Payment",
    "$BaseDir\ThirdParty\Social",
    "$BaseDir\Tools\WebService",
    "$TestsDir",
    "$IntegrationDir",
    "D:\ProgramData\delphi\DUnitX\Source\"
)
$SearchPath = $UnitPaths -join ";"

# Unit directories for code coverage (只统计 UniBase 自身及测试代码)
$CoverageUnitDirs = @(
    "$BaseDir\Core",
    "$BaseDir\VCL",
    "$BaseDir\FMX",
    "$TestsDir"
)
$CoverageUnitParam = $CoverageUnitDirs -join ";"

function Compile-TestProject {
    param(
        [string]$ProjectFile,
        [string]$ProjectName
    )
    
    Write-Host "Compiling $ProjectName..."

    $safeProjectName = ($ProjectName -replace '[^A-Za-z0-9_-]', '_')
    $projectDcuDir = Join-Path $DcuOutputDir $safeProjectName
    if (-not (Test-Path $projectDcuDir)) {
        New-Item -ItemType Directory -Path $projectDcuDir -Force | Out-Null
    }
    
    $args = @(
        "-U$SearchPath",
        "-N0$projectDcuDir",
        "-Q",
        "-B"
    )

    if ($Coverage) {
        # 生成详细 MAP 文件,供覆盖率工具使用
        $args += "-GD"
    }

    $args += $BuildFlags
    $args += $ProjectFile
    
    $process = Start-Process -FilePath $DelphiCompiler -ArgumentList $args -Wait -PassThru -NoNewWindow
    
    if ($process.ExitCode -ne 0) {
        Write-Host "ERROR: Failed to compile $ProjectName" -ForegroundColor Red
        return $false
    }
    
    Write-Host "SUCCESS: $ProjectName compiled" -ForegroundColor Green
    return $true
}

function Run-TestProject {
    param(
        [string]$ExePath,
        [string]$TestName,
        [string]$XmlOutput,
        [string[]]$ExtraArgs = @()
    )
    
    Write-Host ""
    Write-Host "Running $TestName..."
    Write-Host "----------------------------------------------"
    
    $args = @()
    if ($XmlOutput) {
        # DUnitX expects --xmlfile or -xml, not --xmloutput
        $args += "--xmlfile:$XmlOutput"
    }
    $args += "--exitbehavior:Continue"

    if ($ExtraArgs -and $ExtraArgs.Length -gt 0) {
        $args += $ExtraArgs
    }
    
    $process = Start-Process -FilePath $ExePath -ArgumentList $args -Wait -PassThru -NoNewWindow
    
    Write-Host ""
    
    if ($process.ExitCode -eq 0) {
        Write-Host "SUCCESS: All $TestName tests passed" -ForegroundColor Green

        if ($Coverage) {
            Run-CodeCoverage -ExePath $ExePath -CoverageName $TestName
        }

        return $true
    } else {
        Write-Host "FAILED: Some $TestName tests failed (Exit code: $($process.ExitCode))" -ForegroundColor Red
        return $false
    }
}

function Run-CodeCoverage {
    param(
        [string]$ExePath,
        [string]$CoverageName
    )

    if (-not $Coverage) {
        return
    }

    if (-not (Test-Path $CoverageToolPath)) {
        Write-Host "WARNING: Coverage requested but tool not found at $CoverageToolPath" -ForegroundColor Yellow
        return
    }

    $mapPath = [System.IO.Path]::ChangeExtension($ExePath, ".map")
    if (-not (Test-Path $mapPath)) {
        Write-Host "WARNING: MAP file not found for coverage: $mapPath" -ForegroundColor Yellow
        return
    }

    $outDir = Join-Path $CoverageOutputDir $CoverageName
    if (-not (Test-Path $outDir)) {
        New-Item -ItemType Directory -Path $outDir -Force | Out-Null
    }

    Write-Host "Running code coverage for $CoverageName..."

    $args = @(
        "-e", "`"$ExePath`"",
        "-m", "`"$mapPath`"",
        "-u", "`"$CoverageUnitParam`"",
        "-od", "`"$outDir`"",
        "-html",
        "-xml"
    )

    $process = Start-Process -FilePath $CoverageToolPath -ArgumentList $args -Wait -PassThru -NoNewWindow
    if ($process.ExitCode -ne 0) {
        Write-Host "WARNING: Coverage tool exited with code $($process.ExitCode) for $CoverageName" -ForegroundColor Yellow
    } else {
        Write-Host "Coverage report generated at $outDir" -ForegroundColor Green
    }
}

function Get-PeMachine {
    param(
        [string]$Path
    )
    try {
        $bytes = [System.IO.File]::ReadAllBytes($Path)
        $peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
        return [BitConverter]::ToUInt16($bytes, $peOffset + 4)
    } catch {
        return 0
    }
}

function Test-BitnessMatch {
    param(
        [string]$Path,
        [string]$TargetPlatform
    )
    $machine = Get-PeMachine -Path $Path
    if ($TargetPlatform -eq 'Win64') {
        return $machine -eq 0x8664
    }
    return $machine -eq 0x14C
}

function Ensure-SqliteDll {
    param(
        [string]$TargetDir
    )

    $targetDll = Join-Path $TargetDir "sqlite3.dll"
    if (Test-Path $targetDll) {
        if (Test-BitnessMatch -Path $targetDll -TargetPlatform $Platform) {
            return $false
        }
        Remove-Item -Force $targetDll
    }

    $compilerDir = Split-Path -Parent $DelphiCompiler
    $candidatePaths = @(
        (Join-Path $TargetDir "sqlite3.dll"),
        (Join-Path $TestsDir "sqlite3.dll"),
        (Join-Path $BaseDir "sqlite3.dll"),
        (Join-Path $compilerDir "sqlite3.dll"),
        "D:\UserData\Administrator\AppData\Local\Programs\Python\Python311\DLLs\sqlite3.dll",
        "D:\ProgramData\Python313\DLLs\sqlite3.dll",
        "D:\ProgramData\anaconda3\Library\bin\sqlite3.dll"
    )

    foreach ($candidate in $candidatePaths) {
        if ((Test-Path $candidate) -and (Test-BitnessMatch -Path $candidate -TargetPlatform $Platform)) {
            Copy-Item -Path $candidate -Destination $targetDll -Force
            Write-Host "SQLite vendor copied: $candidate -> $targetDll"
            return $true
        }
    }

    Write-Host "WARNING: sqlite3.dll ($Platform) not found for $TargetDir" -ForegroundColor Yellow
    return $false
}

$Results = @{
    UnitTests = $null
    IntegrationTests = $null
}

# Run Unit Tests
if ($Type -eq 'Unit' -or $Type -eq 'All') {
    Write-Host ""
    Write-Host "=============================================="
    Write-Host "           Unit Tests"
    Write-Host "=============================================="
    
    $unitProject = Join-Path $TestsDir "UniBaseTests.dpr"
    $unitExe = Join-Path $TestsDir "UniBaseTests.exe"
    $unitXml = Join-Path $OutputPath "UnitTestResults.xml"
    
    if (Test-Path $unitProject) {
        if (Compile-TestProject -ProjectFile $unitProject -ProjectName "Unit Tests") {
            $Results.UnitTests = Run-TestProject -ExePath $unitExe -TestName "Unit Tests" -XmlOutput $unitXml
        } else {
            $Results.UnitTests = $false
        }
    } else {
        Write-Host "WARNING: Unit test project not found at $unitProject" -ForegroundColor Yellow
    }
}

# Run Integration Tests
if ($Type -eq 'Integration' -or $Type -eq 'All') {
    Write-Host ""
    Write-Host "=============================================="
    Write-Host "        Integration Tests"
    Write-Host "=============================================="
    
    $intProject = Join-Path $IntegrationDir "UniBaseIntegrationTests.dpr"
    $intExe = Join-Path $IntegrationDir "UniBaseIntegrationTests.exe"
    $intXml = Join-Path $OutputPath "IntegrationTestResults.xml"
    
    if (Test-Path $intProject) {
        if (Compile-TestProject -ProjectFile $intProject -ProjectName "Integration Tests") {
            $sqliteCopied = Ensure-SqliteDll -TargetDir $IntegrationDir
            $sqliteInIntegration = Join-Path $IntegrationDir "sqlite3.dll"

            # 默认排除需要数据库环境的集成测试,除非显式设置 UNIBASE_RUN_DB_INTEGRATION=1
            $extraArgs = @()
            if ($env:UNIBASE_RUN_DB_INTEGRATION -ne '1') {
                # DUnitX uses --exclude:<Category> to exclude categories
                $extraArgs += "--exclude:DBEnv"
            }

            # 集成测试会访问本地回环地址（127.0.0.1），显式开启本地URL白名单
            $oldAllowLocalhost = $env:UNIBASE_ALLOW_LOCALHOST_HTTP
            $env:UNIBASE_ALLOW_LOCALHOST_HTTP = '1'
            try {
                $Results.IntegrationTests = Run-TestProject -ExePath $intExe -TestName "Integration Tests" -XmlOutput $intXml -ExtraArgs $extraArgs
            } finally {
                if ($null -eq $oldAllowLocalhost) {
                    Remove-Item Env:\UNIBASE_ALLOW_LOCALHOST_HTTP -ErrorAction SilentlyContinue
                } else {
                    $env:UNIBASE_ALLOW_LOCALHOST_HTTP = $oldAllowLocalhost
                }

                if ($sqliteCopied -and (Test-Path $sqliteInIntegration)) {
                    Remove-Item -Path $sqliteInIntegration -Force -ErrorAction SilentlyContinue
                    Write-Host "Temporary sqlite3.dll removed from Integration directory."
                }
            }
        } else {
            $Results.IntegrationTests = $false
        }
    } else {
        Write-Host "WARNING: Integration test project not found at $intProject" -ForegroundColor Yellow
    }
}

# Generate HTML Report
if ($Report) {
    Write-Host ""
    Write-Host "Generating test report..."
    
    $reportFile = Join-Path $OutputPath "TestReport_$(Get-Date -Format 'yyyyMMdd_HHmmss').html"
    
    # Simple HTML report generation
    $html = @"
<!DOCTYPE html>
<html>
<head>
    <title>UniBase Test Report</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        h1 { color: #333; }
        .summary { margin: 20px 0; padding: 15px; background: #f5f5f5; border-radius: 8px; }
        .pass { color: #28a745; }
        .fail { color: #dc3545; }
        .skip { color: #ffc107; }
    </style>
</head>
<body>
    <h1>UniBase Test Report</h1>
    <p>Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')</p>
    
    <div class="summary">
        <h2>Summary</h2>
        <p>Unit Tests: $(if ($Results.UnitTests -eq $null) { 'Not Run' } elseif ($Results.UnitTests) { '<span class="pass">PASSED</span>' } else { '<span class="fail">FAILED</span>' })</p>
        <p>Integration Tests: $(if ($Results.IntegrationTests -eq $null) { 'Not Run' } elseif ($Results.IntegrationTests) { '<span class="pass">PASSED</span>' } else { '<span class="fail">FAILED</span>' })</p>
    </div>
    
    <h2>Test Result Files</h2>
    <ul>
"@
    
    Get-ChildItem -Path $OutputPath -Filter "*.xml" | ForEach-Object {
        $html += "        <li><a href=`"$($_.Name)`">$($_.Name)</a></li>`n"
    }
    
    $html += @"
    </ul>
</body>
</html>
"@
    
    $html | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Host "Report saved to: $reportFile"
}

# Final Summary
Write-Host ""
Write-Host "=============================================="
Write-Host "           Final Summary"
Write-Host "=============================================="

$allPassed = $true

if ($Results.UnitTests -ne $null) {
    if ($Results.UnitTests) {
        Write-Host "Unit Tests:        PASSED" -ForegroundColor Green
    } else {
        Write-Host "Unit Tests:        FAILED" -ForegroundColor Red
        $allPassed = $false
    }
}

if ($Results.IntegrationTests -ne $null) {
    if ($Results.IntegrationTests) {
        Write-Host "Integration Tests: PASSED" -ForegroundColor Green
    } else {
        Write-Host "Integration Tests: FAILED" -ForegroundColor Red
        $allPassed = $false
    }
}

Write-Host "=============================================="
Write-Host ""

if ($allPassed) {
    Write-Host "All tests passed!" -ForegroundColor Green
    exit 0
} else {
    Write-Host "Some tests failed!" -ForegroundColor Red
    exit 1
}
