# DeepBase Test Runner Script
# Usage: .\run_tests.ps1 [-Type Unit|Integration|All] [-CI] [-AllowFilteredCI] [-Report] [-Run "Fixture[.Test]"] [-RunList path] [-Module LLM,ORM] [-FromUnit DeepBase.LLM] [-FromGitChanged] [-GitRef HEAD] [-ListModules] [-CoverageThreshold 70] [-CoverageFailOnLow]

param(
    [ValidateSet('Unit', 'Integration', 'All')]
    [string]$Type = 'All',

    [ValidateSet('Win32', 'Win64')]
    [string]$Platform = 'Win64',
    
    [switch]$CI,

    [switch]$AllowFilteredCI,
    
    [switch]$Report,
    
    [string]$OutputDir = "TestResults",
    
    [switch]$Coverage,
    
    [string]$CoverageToolPath,

    [int]$CoverageThreshold = 70,

    [int]$CoverageWarningThreshold = 80,

    [switch]$CoverageFailOnLow,

    [string]$Run,

    [string]$RunList,

    [string[]]$Module,

    [switch]$ListModules,

    [string[]]$FromUnit,

    [switch]$FromGitChanged,

    [string]$GitRef = "HEAD",

    [string[]]$IncludeCategory,

    [string[]]$ExcludeCategory,

    [switch]$SkipCompile,

    [switch]$NoRebuild
)

$ErrorActionPreference = "Stop"

if ($CI -and $SkipCompile) {
    throw "-SkipCompile is not allowed with -CI because it can run a stale test executable."
}

# Configuration
$BaseDir = Split-Path -Parent $PSScriptRoot
$TestsDir = Join-Path $BaseDir "Tests"
$IntegrationDir = Join-Path $TestsDir "Integration"
$OutputPath = Join-Path $BaseDir $OutputDir
$BuildOutputDir = Join-Path $OutputPath "build"
$DcuOutputDir = Join-Path $BuildOutputDir "dcu\$Platform"
$BdsRoot = if ($env:BDS) { $env:BDS } else { "D:\Program Files (x86)\Embarcadero\Studio\37.0" }
$Dcc32 = Join-Path $BdsRoot "bin\dcc32.exe"
$Dcc64 = Join-Path $BdsRoot "bin\dcc64.exe"
$TestRunTimeoutMs = if ($env:DEEPBASE_TEST_RUN_TIMEOUT_MS) { [int]$env:DEEPBASE_TEST_RUN_TIMEOUT_MS } else { 300000 }

# Module aliases for fast targeted regression
$ModuleRunMap = [ordered]@{
    "LLM"        = "Test.DeepBase.LLM,Test.DeepBase.LLM.Manager,Test.DeepBase.LLM.PromptTemplate,Test.DeepBase.LLM.ImportExport,Test.DeepBase.LLM.BillingClient"
    "ORM"        = "Test.DeepBase.ORM,Test.DeepBase.ORM.Mapping,Test.DeepBase.TestHelper"
    "DB"         = "Test.DeepBase.DB.Factory,Test.DeepBase.DB.Pool,Test.DeepBase.DB.Migrations,Test.DeepBase.DB.ConnectionPool,Test.DeepBase.DB.AutoRefreshConfig,Test.DeepBase.DB.JobQueue,Test.DeepBase.DB.StatusMachine,Test.DeepBase.DB.DoQry,Test.DeepBase.SQLLogger"
    "CONFIG"     = "Test.DeepBase.Config,Test.DeepBase.Configuration,Test.DeepBase.PublishConfig"
    "FORMSTATE"  = "Test.DeepBase.FormState"
    "I18N"       = "Test.DeepBase.i18n,Test.DeepBase.i18n.Plural,Test.DeepBase.i18n.Gender"
    "HOTKEYS"    = "Test.DeepBase.Hotkeys"
    "THEME"      = "Test.DeepBase.Theme"
    "SECURITY"   = "Test.DeepBase.Security,Test.DeepBase.Protection,Test.DeepBase.KeyManager,Test.DeepBase.Authorization,Test.DeepBase.License"
    "LOGGING"    = "Test.DeepBase.Logging,Test.DeepBase.LogAggregator"
    "MANAGER"    = "Test.DeepBase.Manager,Test.DeepBase.Persistence.RuntimeRegistration"
    "SERVICES"   = "Test.DeepBase.Services.HealthCheck,Test.DeepBase.Services.Protection,Test.DeepBase.Services.Registration"
    "NET"        = "Test.WebService"
    "RESILIENCE" = "Test.DeepBase.Resilience,Test.DeepBase.RateLimiter"
    "PERF"       = "Test.DeepBase.Benchmark,Test.DeepBase.Performance,Test.DeepBase.PerformanceSuite,Test.DeepBase.LockContention"
}

function Show-ModuleAliases {
    Write-Host "Available module aliases:"
    foreach ($entry in $ModuleRunMap.GetEnumerator()) {
        Write-Host ("  {0,-10} -> {1}" -f $entry.Key, $entry.Value)
    }
}

function Resolve-TestUnitFile {
    param(
        [string]$TestUnit
    )

    $testFileName = "$TestUnit.pas"
    $unitCandidate = Join-Path $TestsDir $testFileName
    $integrationCandidate = Join-Path $IntegrationDir $testFileName

    if (Test-Path $unitCandidate) {
        return $unitCandidate
    }

    if (Test-Path $integrationCandidate) {
        return $integrationCandidate
    }

    return $null
}

function Resolve-TestUnitFixtureFilters {
    param(
        [string]$TestUnit,
        [string]$TestFile
    )

    if ([string]::IsNullOrWhiteSpace($TestFile) -or -not (Test-Path $TestFile)) {
        return @()
    }

    $source = Get-Content -Path $TestFile -Raw
    $fixtures = [regex]::Matches(
        $source,
        'TDUnitX\.RegisterTestFixture\(\s*([A-Za-z_][A-Za-z0-9_]*)\s*\)'
    ) | ForEach-Object { $_.Groups[1].Value } | Select-Object -Unique

    return @($fixtures | ForEach-Object { "$TestUnit.$_" })
}

function Get-ActiveProjectTestUnits {
    $projectFiles = @()

    if ($Type -eq 'Unit' -or $Type -eq 'All') {
        $projectFiles += (Join-Path $TestsDir "DeepBaseTests.dpr")
    }

    if ($Type -eq 'Integration' -or $Type -eq 'All') {
        $projectFiles += (Join-Path $IntegrationDir "DeepBaseIntegrationTests.dpr")
    }

    $units = @()
    foreach ($projectFile in $projectFiles) {
        if (-not (Test-Path $projectFile)) {
            continue
        }

        $projectSource = Get-Content -Path $projectFile -Raw
        $units += [regex]::Matches(
            $projectSource,
            "(?m)^\s*([A-Za-z_][A-Za-z0-9_.]*)\s+in\s+'[^']+\.pas'"
        ) | ForEach-Object { $_.Groups[1].Value }
    }

    return @($units | Select-Object -Unique)
}

function Test-ActiveProjectReferencesUnit {
    param(
        [string]$TestUnit
    )

    $activeUnits = Get-ActiveProjectTestUnits
    return [bool]($activeUnits | Where-Object { $_ -ieq $TestUnit } | Select-Object -First 1)
}

function Resolve-ModuleRunFilter {
    param(
        [string[]]$ModuleNames
    )

    $resolved = @()
    $missingFixtures = @()
    $missingProjectRefs = @()

    foreach ($moduleArg in $ModuleNames) {
        if ([string]::IsNullOrWhiteSpace($moduleArg)) {
            continue
        }

        $tokens = $moduleArg -split "[,;]" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        foreach ($token in $tokens) {
            $key = $token.ToUpperInvariant()
            if (-not $ModuleRunMap.Contains($key)) {
                throw "Unknown -Module alias '$token'. Use -ListModules to view supported aliases."
            }
            $moduleUnits = $ModuleRunMap[$key] -split "," | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
            foreach ($testUnit in $moduleUnits) {
                $testFile = Resolve-TestUnitFile -TestUnit $testUnit
                if (-not $testFile) {
                    throw "Cannot map -Module alias '$token' entry '$testUnit' to an existing test unit."
                }

                if (-not (Test-ActiveProjectReferencesUnit -TestUnit $testUnit)) {
                    $missingProjectRefs += $testUnit
                    continue
                }

                $fixtureFilters = Resolve-TestUnitFixtureFilters -TestUnit $testUnit -TestFile $testFile
                if ($fixtureFilters.Count -gt 0) {
                    $resolved += $fixtureFilters
                } else {
                    $missingFixtures += $testUnit
                }
            }
        }
    }

    if ($missingFixtures.Count -gt 0) {
        $missingUnique = $missingFixtures | Select-Object -Unique
        Write-Host "Skipped test units with no registered DUnitX fixtures: $($missingUnique -join ', ')" -ForegroundColor Yellow
    }

    if ($missingProjectRefs.Count -gt 0) {
        $missingUnique = $missingProjectRefs | Select-Object -Unique
        Write-Host "Skipped test units not referenced by active test project: $($missingUnique -join ', ')" -ForegroundColor Yellow
    }

    $unique = $resolved | Select-Object -Unique
    if (-not $unique -or $unique.Count -eq 0) {
        throw "No registered DUnitX fixtures found for -Module '$($ModuleNames -join ',')'."
    }

    return ($unique -join ",")
}

function Resolve-UnitRunFilter {
    param(
        [string[]]$UnitTokens,
        [switch]$IgnoreMissing
    )

    $resolved = @()
    $missing = @()

    foreach ($unitArg in $UnitTokens) {
        if ([string]::IsNullOrWhiteSpace($unitArg)) {
            continue
        }

        $tokens = $unitArg -split "[,;]" | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
        foreach ($token in $tokens) {
            $name = $token

            if ($name.IndexOfAny(@([char]'\', [char]'/')) -ge 0) {
                $name = [System.IO.Path]::GetFileNameWithoutExtension($name)
            } elseif ($name.ToLowerInvariant().EndsWith('.pas')) {
                $name = [System.IO.Path]::GetFileNameWithoutExtension($name)
            }

            if ([string]::IsNullOrWhiteSpace($name)) {
                continue
            }

            if ($name.StartsWith('Test.', [System.StringComparison]::OrdinalIgnoreCase)) {
                $testUnit = $name
            } else {
                $testUnit = "Test.$name"
            }

            $testFile = Resolve-TestUnitFile -TestUnit $testUnit

            if ($testFile) {
                if (-not (Test-ActiveProjectReferencesUnit -TestUnit $testUnit)) {
                    if ($IgnoreMissing) {
                        $missing += $token
                        continue
                    }

                    throw "Test unit '$testUnit' is not referenced by the active test project for -Type $Type."
                }

                $fixtureFilters = Resolve-TestUnitFixtureFilters -TestUnit $testUnit -TestFile $testFile
                if ($fixtureFilters.Count -gt 0) {
                    $resolved += $fixtureFilters
                } elseif ($IgnoreMissing) {
                    $missing += $token
                } else {
                    throw "Test unit '$testUnit' has no TDUnitX.RegisterTestFixture registrations for the default CI runner."
                }
            } else {
                if ($IgnoreMissing) {
                    $missing += $token
                } else {
                    throw "Cannot map -FromUnit token '$token' to an existing test unit ($testUnit)."
                }
            }
        }
    }

    if ($IgnoreMissing -and $missing.Count -gt 0) {
        $missingUnique = $missing | Select-Object -Unique
        $previewCount = [Math]::Min(12, $missingUnique.Count)
        $preview = ($missingUnique | Select-Object -First $previewCount) -join ', '
        if ($missingUnique.Count -gt $previewCount) {
            Write-Host "Skipped unmapped changed units ($($missingUnique.Count)): $preview ..." -ForegroundColor Yellow
        } else {
            Write-Host "Skipped unmapped changed units ($($missingUnique.Count)): $preview" -ForegroundColor Yellow
        }
    }

    $unique = $resolved | Select-Object -Unique
    return ($unique -join ",")
}

function Get-GitChangedUnitTokens {
    param(
        [string]$Reference = "HEAD"
    )

    $inside = (& git -C $BaseDir rev-parse --is-inside-work-tree 2>$null)
    if ($LASTEXITCODE -ne 0 -or ($inside -ne 'true')) {
        throw "Current workspace is not a git repository: $BaseDir"
    }

    $paths = @()

    if (-not [string]::IsNullOrWhiteSpace($Reference)) {
        $diffPaths = & git -C $BaseDir diff --name-only --diff-filter=ACMRTUXB $Reference -- 2>$null
        if ($LASTEXITCODE -ne 0) {
            throw "Invalid -GitRef '$Reference' or git diff failed."
        }
        if ($diffPaths) {
            $paths += $diffPaths
        }
    }

    $statusLines = & git -C $BaseDir status --porcelain 2>$null
    if ($LASTEXITCODE -ne 0) {
        throw "git status failed in $BaseDir"
    }

    foreach ($line in $statusLines) {
        if ([string]::IsNullOrWhiteSpace($line) -or $line.Length -lt 4) {
            continue
        }

        $pathPart = $line.Substring(3).Trim()
        $renameIndex = $pathPart.IndexOf(" -> ")
        if ($renameIndex -ge 0) {
            $pathPart = $pathPart.Substring($renameIndex + 4).Trim()
        }

        if (-not [string]::IsNullOrWhiteSpace($pathPart)) {
            $paths += $pathPart
        }
    }

    $units = @()
    $uniquePaths = $paths | Where-Object { -not [string]::IsNullOrWhiteSpace($_) } | Select-Object -Unique
    foreach ($path in $uniquePaths) {
        if ([System.IO.Path]::GetExtension($path).ToLowerInvariant() -ne '.pas') {
            continue
        }

        $unitName = [System.IO.Path]::GetFileNameWithoutExtension($path)
        if (-not [string]::IsNullOrWhiteSpace($unitName)) {
            $units += $unitName
        }
    }

    return ($units | Select-Object -Unique)
}

if ($ListModules) {
    Show-ModuleAliases
    exit 0
}

if ($Module -and $Module.Length -gt 0) {
    if ($RunList) {
        throw "Cannot combine -Module with -RunList. Use one filter source only."
    }

    $moduleRun = Resolve-ModuleRunFilter -ModuleNames $Module
    if ($moduleRun) {
        if ($Run) {
            $Run = "$Run,$moduleRun"
        } else {
            $Run = $moduleRun
        }
    }
}

if ($FromUnit -and $FromUnit.Length -gt 0) {
    if ($RunList) {
        throw "Cannot combine -FromUnit with -RunList. Use one filter source only."
    }

    $unitRun = Resolve-UnitRunFilter -UnitTokens $FromUnit
    if ($unitRun) {
        if ($Run) {
            $Run = "$Run,$unitRun"
        } else {
            $Run = $unitRun
        }
    }
}

if ($FromGitChanged) {
    if ($RunList) {
        throw "Cannot combine -FromGitChanged with -RunList. Use one filter source only."
    }

    $changedUnits = Get-GitChangedUnitTokens -Reference $GitRef
    if (-not $changedUnits -or $changedUnits.Count -eq 0) {
        throw "No changed Pascal units found from git status/diff."
    }

    $gitRun = Resolve-UnitRunFilter -UnitTokens $changedUnits -IgnoreMissing
    if ([string]::IsNullOrWhiteSpace($gitRun)) {
        throw "No test units mapped from changed Pascal units."
    }

    if ($Run) {
        $Run = "$Run,$gitRun"
    } else {
        $Run = $gitRun
    }
}

$hasFilteredRun = -not [string]::IsNullOrWhiteSpace($Run) -or
                  -not [string]::IsNullOrWhiteSpace($RunList) -or
                  ($IncludeCategory -and $IncludeCategory.Length -gt 0) -or
                  ($ExcludeCategory -and $ExcludeCategory.Length -gt 0)

if ($CI -and $hasFilteredRun -and -not $AllowFilteredCI) {
    throw "CI full gate does not allow filtered test runs. Use -AllowFilteredCI only for explicit targeted CI jobs."
}

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
Write-Host "        DeepBase Test Runner"
Write-Host "=============================================="
Write-Host ""
Write-Host "Base Directory: $BaseDir"
Write-Host "Test Type: $Type"
Write-Host "Platform: $Platform"
Write-Host "CI Mode: $CI"
Write-Host "Skip Compile: $SkipCompile"
Write-Host "No Rebuild: $NoRebuild"
if ($Run) { Write-Host "Run Filter: $Run" }
if ($RunList) { Write-Host "RunList: $RunList" }
if ($Module) { Write-Host "Module Aliases: $($Module -join ',')" }
if ($FromUnit) { Write-Host "From Unit: $($FromUnit -join ',')" }
if ($FromGitChanged) { Write-Host "From Git Changed: True (Ref: $GitRef)" }
if ($IncludeCategory) { Write-Host "Include Categories: $($IncludeCategory -join ',')" }
if ($ExcludeCategory) { Write-Host "Exclude Categories: $($ExcludeCategory -join ',')" }
if ($Coverage) {
    Write-Host "Coverage Threshold: $CoverageThreshold%"
    Write-Host "Coverage Warning:   $CoverageWarningThreshold%"
    Write-Host "Coverage Fail-Low: $($CoverageFailOnLow -or $CI -or ($env:DEEPBASE_COVERAGE_FAIL_ON_LOW -eq '1'))"
}
Write-Host "Output: $OutputPath"
Write-Host "DCU Output: $DcuOutputDir"
Write-Host ""

# Build flags
$BuildFlags = @()
if ($CI) {
    $BuildFlags += "-DCI"
} else {
    # 非 CI 构建启用 DEBUG，让 Test DPR 能打开 ReportMemoryLeaksOnShutdown
    # 检测业务代码的进程退出泄漏。CI 构建不启用：DUnitX 框架自身保留部分
    # 缓存（Assert.OnAssert 匿名方法、RunResults JSON 元数据），
    # 这些是框架泄漏而非业务代码泄漏，详见 BUG-285。
    $BuildFlags += "-DDEBUG"
}

function Get-CommonTestArgs {
    $args = @()
    if ($Run) {
        $args += "--run:$Run"
    }
    if ($RunList) {
        $args += "--runlist:$RunList"
    }
    if ($IncludeCategory -and $IncludeCategory.Length -gt 0) {
        $args += "--include:$($IncludeCategory -join ',')"
    }
    if ($ExcludeCategory -and $ExcludeCategory.Length -gt 0) {
        $args += "--exclude:$($ExcludeCategory -join ',')"
    }
    return $args
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
    "$BaseDir\Tools\CLI",
    "$BaseDir\Tools\WebService",
    "$TestsDir",
    "$IntegrationDir",
    "D:\ProgramData\delphi\DUnitX\Source\"
)
$SearchPath = $UnitPaths -join ";"

# Unit directories for code coverage (只统计 DeepBase 源码，不用测试代码稀释覆盖率)
$CoverageUnitDirs = @(
    "$BaseDir\Core",
    "$BaseDir\Features",
    "$BaseDir\Persistence",
    "$BaseDir\VCL",
    "$BaseDir\FMX",
    "$BaseDir\ThirdParty\Payment",
    "$BaseDir\ThirdParty\Social",
    "$BaseDir\Tools\CLI",
    "$BaseDir\Tools\WebService"
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

    # BUG-285: dcc64 在解析 .dproj 的 DCC_DcuOutput 时,偶尔会把早期依赖的 DCU 写到源目录。
    # 构建前清理源目录中的残留 DCU,避免架构测试(源目录不得包含 DCU 产物)误报。
    if (-not $script:SourceCodeDirs) {
        $script:SourceCodeDirs = @("$BaseDir\Core", "$BaseDir\Features", "$BaseDir\Persistence", "$BaseDir\VCL", "$BaseDir\FMX")
    }
    foreach ($srcDir in $script:SourceCodeDirs) {
        if (Test-Path $srcDir) {
            Get-ChildItem -Path $srcDir -Filter "*.dcu" -File -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
        }
    }

    $args = @(
        "-U$SearchPath",
        "-N0$projectDcuDir",
        "-Q",
        "--codepage:65001"   # Source files are UTF-8; force dcc64 to honor that (BUG-276)
    )

    if (-not $NoRebuild) {
        $args += "-B"
    }

    if ($Coverage) {
        # 生成详细 MAP 文件,供覆盖率工具使用
        $args += "-GD"
    }

    $args += $BuildFlags
    $args += $ProjectFile

    $projectDir = Split-Path -Parent $ProjectFile
    
    $process = Start-Process -FilePath $DelphiCompiler -ArgumentList $args -Wait -PassThru -NoNewWindow -WorkingDirectory $projectDir
    
    if ($process.ExitCode -ne 0) {
        Write-Host "ERROR: Failed to compile $ProjectName" -ForegroundColor Red
        return $false
    }

    # BUG-285: 构建后再次清理源目录残留 DCU(dcc64 即使指定 -N0,也可能将 DCU 落在源目录)。
    foreach ($srcDir in $script:SourceCodeDirs) {
        if (Test-Path $srcDir) {
            $leftover = Get-ChildItem -Path $srcDir -Filter "*.dcu" -File -ErrorAction SilentlyContinue
            if ($leftover) {
                Write-Host ("BUG-285: removing {0} stale DCU(s) from {1}" -f $leftover.Count, $srcDir) -ForegroundColor Yellow
                $leftover | Remove-Item -Force -ErrorAction SilentlyContinue
            }
        }
    }

    Write-Host "SUCCESS: $ProjectName compiled" -ForegroundColor Green
    return $true
}

function Run-TestProject {
    param(
        [string]$ExePath,
        [string]$TestName,
        [string]$XmlOutput,
        [int]$MinimumTests = 1,
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
    $args += Get-CommonTestArgs

    if ($ExtraArgs -and $ExtraArgs.Length -gt 0) {
        $args += $ExtraArgs
    }
    
    $process = Start-Process -FilePath $ExePath -ArgumentList $args -PassThru -NoNewWindow -Wait
    # -Wait populates ExitCode reliably; without it, ExitCode stays null and
    # every passing test is mis-reported as FAILED (BUG-285 follow-up).
    $exitCode = $process.ExitCode
    if ($exitCode -eq $null) { $exitCode = 0 }
    $process.Dispose()

    Write-Host ""

    if ($exitCode -eq 0) {
        if ($XmlOutput -and -not (Test-XmlHasExecutedTests -Path $XmlOutput -MinimumTests $MinimumTests)) {
            Write-Host "FAILED: $TestName produced fewer than $MinimumTests executed tests in $XmlOutput" -ForegroundColor Red
            return $false
        }

        Write-Host "SUCCESS: All $TestName tests passed" -ForegroundColor Green

        if ($Coverage) {
            Run-CodeCoverage -ExePath $ExePath -CoverageName $TestName
        }

        return $true
    } else {
        Write-Host "FAILED: Some $TestName tests failed (Exit code: $exitCode)" -ForegroundColor Red
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

function Test-XmlHasExecutedTests {
    param(
        [string]$Path,
        [int]$MinimumTests = 1
    )

    if (-not (Test-Path $Path)) {
        Write-Host "ERROR: Test XML not found: $Path" -ForegroundColor Red
        return $false
    }

    try {
        [xml]$xml = Get-Content -Path $Path -Raw
        $totalAttr = $xml.DocumentElement.GetAttribute('total')
        if (-not [string]::IsNullOrWhiteSpace($totalAttr)) {
            $total = [int]$totalAttr
            if ($total -lt $MinimumTests) {
                Write-Host "ERROR: Test XML reports only $total executed tests; minimum is $MinimumTests." -ForegroundColor Red
                return $false
            }
            return $true
        }

        $caseCount = @($xml.SelectNodes('//test-case')).Count
        if ($caseCount -lt $MinimumTests) {
            Write-Host "ERROR: Test XML contains only $caseCount test-case nodes; minimum is $MinimumTests." -ForegroundColor Red
            return $false
        }
        return $true
    } catch {
        Write-Host "ERROR: Failed to parse test XML $Path : $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-HasRunFilter {
    return -not [string]::IsNullOrWhiteSpace($Run) -or
           -not [string]::IsNullOrWhiteSpace($RunList)
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
    $compilerRoot = Split-Path -Parent $compilerDir
    $candidatePaths = @(
        (Join-Path $TargetDir "sqlite3.dll"),
        (Join-Path $TestsDir "sqlite3.dll"),
        (Join-Path $BaseDir "sqlite3.dll"),
        (Join-Path $compilerRoot "bin64\sqlite3.dll"),
        (Join-Path $compilerRoot "bin\windows\lldb\sqlite3.dll"),
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
    
    $unitProject = Join-Path $TestsDir "DeepBaseTests.dpr"
    $unitExe = Join-Path $TestsDir "DeepBaseTests.exe"
    $unitXml = Join-Path $OutputPath "UnitTestResults.xml"
    
    if (Test-Path $unitProject) {
        $canRunUnit = $true
        if (-not $SkipCompile) {
            $canRunUnit = Compile-TestProject -ProjectFile $unitProject -ProjectName "Unit Tests"
        } elseif (-not (Test-Path $unitExe)) {
            Write-Host "ERROR: Unit test executable not found (use without -SkipCompile first): $unitExe" -ForegroundColor Red
            $canRunUnit = $false
        }

        if ($canRunUnit) {
            $sqliteCopied = Ensure-SqliteDll -TargetDir $TestsDir
            $sqliteInTests = Join-Path $TestsDir "sqlite3.dll"
            try {
                $unitMinimumTests = 3000
                if (Test-HasRunFilter) {
                    $unitMinimumTests = 1
                }
                $Results.UnitTests = Run-TestProject -ExePath $unitExe -TestName "Unit Tests" -XmlOutput $unitXml -MinimumTests $unitMinimumTests
            } finally {
                if ($sqliteCopied -and (Test-Path $sqliteInTests)) {
                    Remove-Item -Path $sqliteInTests -Force -ErrorAction SilentlyContinue
                    Write-Host "Temporary sqlite3.dll removed from Tests directory."
                }
            }
        } else {
            $Results.UnitTests = $false
        }
    } else {
        Write-Host "ERROR: Required unit test project not found at $unitProject" -ForegroundColor Red
        $Results.UnitTests = $false
    }
}

# Run Integration Tests
if ($Type -eq 'Integration' -or $Type -eq 'All') {
    Write-Host ""
    Write-Host "=============================================="
    Write-Host "        Integration Tests"
    Write-Host "=============================================="
    
    $intProject = Join-Path $IntegrationDir "DeepBaseIntegrationTests.dpr"
    $intExe = Join-Path $IntegrationDir "DeepBaseIntegrationTests.exe"
    $intXml = Join-Path $OutputPath "IntegrationTestResults.xml"
    
    if (Test-Path $intProject) {
        $canRunIntegration = $true
        if (-not $SkipCompile) {
            $canRunIntegration = Compile-TestProject -ProjectFile $intProject -ProjectName "Integration Tests"
        } elseif (-not (Test-Path $intExe)) {
            Write-Host "ERROR: Integration test executable not found (use without -SkipCompile first): $intExe" -ForegroundColor Red
            $canRunIntegration = $false
        }

        if ($canRunIntegration) {
            $sqliteCopied = Ensure-SqliteDll -TargetDir $IntegrationDir
            $sqliteInIntegration = Join-Path $IntegrationDir "sqlite3.dll"

            # 默认排除需要数据库环境的集成测试,除非显式设置 DEEPBASE_RUN_DB_INTEGRATION=1
            $extraArgs = @()
            if ($env:DEEPBASE_RUN_DB_INTEGRATION -ne '1') {
                # DUnitX uses --exclude:<Category> to exclude categories
                $extraArgs += "--exclude:DBEnv"
            }

            # 集成测试会访问本地回环地址（127.0.0.1），显式开启本地URL白名单
            $oldAllowLocalhost = $env:DEEPBASE_ALLOW_LOCALHOST_HTTP
            $env:DEEPBASE_ALLOW_LOCALHOST_HTTP = '1'
            try {
                $integrationMinimumTests = 5
                if (Test-HasRunFilter) {
                    $integrationMinimumTests = 1
                }
                $Results.IntegrationTests = Run-TestProject -ExePath $intExe -TestName "Integration Tests" -XmlOutput $intXml -MinimumTests $integrationMinimumTests -ExtraArgs $extraArgs
            } finally {
                if ($null -eq $oldAllowLocalhost) {
                    Remove-Item Env:\DEEPBASE_ALLOW_LOCALHOST_HTTP -ErrorAction SilentlyContinue
                } else {
                    $env:DEEPBASE_ALLOW_LOCALHOST_HTTP = $oldAllowLocalhost
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
        Write-Host "ERROR: Required integration test project not found at $intProject" -ForegroundColor Red
        $Results.IntegrationTests = $false
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
    <title>DeepBase Test Report</title>
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
    <h1>DeepBase Test Report</h1>
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

if ($Coverage -and $allPassed) {
    $coverageScript = Join-Path $PSScriptRoot "coverage_check.ps1"
    $coverageDir = Join-Path $OutputDir "coverage"
    $shouldFailOnLow = $CoverageFailOnLow -or $CI -or ($env:DEEPBASE_COVERAGE_FAIL_ON_LOW -eq '1')

    Write-Host ""
    Write-Host "Coverage Gate: running threshold check..."
    if (Test-Path $coverageScript) {
        $coverageArgs = @(
            "-CoverageDir", $coverageDir,
            "-Threshold", $CoverageThreshold,
            "-WarningThreshold", $CoverageWarningThreshold
        )
        if ($shouldFailOnLow) {
            $coverageArgs += "-FailOnLow"
        }

        & $coverageScript @coverageArgs
        if ($LASTEXITCODE -ne 0) {
            $allPassed = $false
            Write-Host "Coverage Gate: FAILED" -ForegroundColor Red
        } else {
            Write-Host "Coverage Gate: PASSED" -ForegroundColor Green
        }
    } else {
        Write-Host "WARNING: coverage_check.ps1 not found: $coverageScript" -ForegroundColor Yellow
        if ($shouldFailOnLow) {
            $allPassed = $false
            Write-Host "Coverage Gate: FAILED (missing checker script)" -ForegroundColor Red
        }
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
