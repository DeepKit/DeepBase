param(
    [string]$SourcePath,
    [string]$ReportPath,
    [switch]$FailOnViolation,
    [switch]$IncludeKnownDebt
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
    $ReportPath = Join-Path $RepoRoot 'TestResults\architecture-layer-report.json'
}

$PackageFiles = @(
    'DeepBaseCore.dpk',
    'DeepBaseServices.dpk',
    'DeepBasePersistence.dpk',
    'DeepBaseFeatures.dpk',
    'DeepBaseVCL.dpk',
    'DeepBaseFMX.dpk'
)

$ProjectFiles = @(
    'DeepBaseCore.dproj',
    'DeepBaseServices.dproj',
    'DeepBasePersistence.dproj',
    'DeepBaseFeatures.dproj',
    'DeepBaseVCL.dproj',
    'DeepBaseFMX.dproj'
)

$HardPackageRequires = @{
    'DeepBaseCore.dpk' = @(
        '\bvcl\b',
        '\bfmx\b',
        '\bdesignide\b',
        '\bdbrtl\b',
        '\bfiredac\b',
        '\bfiredaccommondriver\b',
        '\bfiredacsqlitedriver\b',
        '\bfiredacpgdriver\b',
        '\bdeepbasefeatures\b',
        '\bdeepbasepersistence\b',
        '\bdeepbasevcl\b',
        '\bdeepbasefmx\b'
    )
    'DeepBaseServices.dpk' = @(
        '\bvcl\b',
        '\bfmx\b',
        '\bdesignide\b',
        '\bdbrtl\b',
        '\bfiredac\b',
        '\bfiredaccommondriver\b',
        '\bfiredacsqlitedriver\b',
        '\bfiredacpgdriver\b',
        '\bdeepbasefeatures\b',
        '\bdeepbasepersistence\b',
        '\bdeepbasevcl\b',
        '\bdeepbasefmx\b'
    )
    'DeepBasePersistence.dpk' = @(
        '\bvcl\b',
        '\bfmx\b',
        '\bdesignide\b',
        '\bdeepbasefeatures\b',
        '\bdeepbasevcl\b',
        '\bdeepbasefmx\b'
    )
    'DeepBaseFeatures.dpk' = @(
        '\bvcl\b',
        '\bfmx\b',
        '\bdesignide\b',
        '\bfiredac\b',
        '\bfiredaccommondriver\b',
        '\bfiredacsqlitedriver\b',
        '\bfiredacpgdriver\b',
        '\bdeepbasepersistence\b',
        '\bdeepbasevcl\b',
        '\bdeepbasefmx\b'
    )
}

$HardProjectReferences = $HardPackageRequires.Clone()

$KnownDebtRequires = @{
    'DeepBaseFeatures.dpk' = @()
}

$KnownDebtProjectReferences = $KnownDebtRequires.Clone()

$KnownFireDacOutsidePersistence = @() | ForEach-Object { $_.ToLowerInvariant() }

$RuntimePackages = @(
    'DeepBaseCore.dpk',
    'DeepBaseServices.dpk',
    'DeepBasePersistence.dpk',
    'DeepBaseFeatures.dpk',
    'DeepBaseVCL.dpk',
    'DeepBaseFMX.dpk'
)

$CoreUiAllowlist = @(
    'DeepBase.Exception.pas',
    'DeepBase.Export.pas',
    'DeepBase.SingleInstance.pas',
    'DeepBase.SplashScreen.pas',
    'DeepBase.TestHelper.pas',
    # BUG-280 known debt: VCL/FMX units still referenced from Core.
    # Tracked for eventual move to DeepBaseVCL/DeepBaseFMX.
    'DeepBase.AIErrorHandler.pas',
    'DeepBase.UITest.FmxProbe.pas',
    'DeepBase.VirtualScroll.pas'
) | ForEach-Object { $_.ToLowerInvariant() }

$CoreDbAllowlist = @(
    'DeepBase.Manager.pas',
    'DeepBase.Config.pas',
    'DeepBase.i18n.pas',
    'DeepBase.FormState.pas',
    'DeepBase.MRU.pas',
    'DeepBase.Hotkeys.pas',
    'DeepBase.Theme.pas',
    'DeepBase.Diagnose.pas',
    'DeepBase.Security.pas',
    # BUG-280 known debt: Data.DB references in Core surface.
    'DeepBase.Export.pas',
    'DeepBase.LLM.pas',
    'DeepBase.LLM.Manager.pas'
) | ForEach-Object { $_.ToLowerInvariant() }

$Violations = New-Object System.Collections.Generic.List[object]

function Add-Violation {
    param(
        [ValidateSet('Error', 'Warning')]
        [string]$Severity,
        [string]$Rule,
        [string]$Subject,
        [string]$Message
    )

    $Violations.Add([pscustomobject]@{
        Severity = $Severity
        Rule = $Rule
        Subject = $Subject
        Message = $Message
    })
}

function Read-Text {
    param([Parameter(Mandatory = $true)][string]$Path)
    return Get-Content -LiteralPath $Path -Raw -ErrorAction Stop
}

function Remove-PascalComments {
    param([string]$Text)
    $Text = [regex]::Replace($Text, '\(\*.*?\*\)', '', 'Singleline')
    $Text = [regex]::Replace($Text, '\{.*?\}', '', 'Singleline')
    $Text = [regex]::Replace($Text, '//.*', '')
    return $Text
}

function Remove-PascalStringLiterals {
    param([string]$Text)
    return [regex]::Replace($Text, "'(?:''|[^'])*'", "''", 'Singleline')
}

function Get-PackageRequiresText {
    param([string]$Text)
    $Match = [regex]::Match($Text, '(?is)\brequires\b(.*?);')
    if (-not $Match.Success) {
        return ''
    }
    return $Match.Groups[1].Value.ToLowerInvariant()
}

function Get-PackageSourceEntries {
    param([string]$Text)
    $Matches = [regex]::Matches($Text, "\bin\s+'([^']+\.pas)'", 'IgnoreCase')
    $Items = New-Object System.Collections.Generic.List[string]
    foreach ($Match in $Matches) {
        $Items.Add($Match.Groups[1].Value)
    }
    return $Items
}

function Get-ProjectReferencesText {
    param([string]$Text)
    $Items = New-Object System.Collections.Generic.List[string]

    $ReferenceMatches = [regex]::Matches($Text, '<DCCReference\s+Include="([^"]+)"', 'IgnoreCase')
    foreach ($Match in $ReferenceMatches) {
        $Items.Add($Match.Groups[1].Value)
    }

    $NamespaceMatches = [regex]::Matches($Text, '<DCC_Namespace>(.*?)</DCC_Namespace>', 'IgnoreCase,Singleline')
    foreach ($Match in $NamespaceMatches) {
        $Items.Add($Match.Groups[1].Value)
    }

    $FrameworkMatches = [regex]::Matches($Text, '<FrameworkType>(.*?)</FrameworkType>', 'IgnoreCase,Singleline')
    foreach ($Match in $FrameworkMatches) {
        $Items.Add($Match.Groups[1].Value)
    }

    return ($Items -join "`n").ToLowerInvariant()
}

function Get-ProjectSourceEntries {
    param([string]$Text)
    $Matches = [regex]::Matches($Text, '<DCCReference\s+Include="([^"]+\.pas)"', 'IgnoreCase')
    $Items = New-Object System.Collections.Generic.List[string]
    foreach ($Match in $Matches) {
        $Items.Add($Match.Groups[1].Value)
    }
    return $Items
}

function Test-AnyRegex {
    param([string]$Text, [string[]]$Patterns)
    foreach ($Pattern in $Patterns) {
        if ([regex]::IsMatch($Text, $Pattern, 'IgnoreCase')) {
            return $Pattern
        }
    }
    return $null
}

function Test-ProjectReferences {
    param(
        [string]$ProjectName,
        [string]$ReferencesText
    )

    $PackageKey = [System.IO.Path]::ChangeExtension($ProjectName, '.dpk')
    if ($HardProjectReferences.ContainsKey($PackageKey)) {
        foreach ($Pattern in $HardProjectReferences[$PackageKey]) {
            if ([regex]::IsMatch($ReferencesText, $Pattern, 'IgnoreCase')) {
                Add-Violation 'Error' 'ProjectReferences' $ProjectName "Forbidden project dependency matches $Pattern"
            }
        }
    }

    if ($IncludeKnownDebt -and $KnownDebtProjectReferences.ContainsKey($PackageKey)) {
        foreach ($Pattern in $KnownDebtProjectReferences[$PackageKey]) {
            if ([regex]::IsMatch($ReferencesText, $Pattern, 'IgnoreCase')) {
                Add-Violation 'Warning' 'KnownProjectDebt' $ProjectName "Known optional-package split debt matches $Pattern"
            }
        }
    }
}

function Test-PackageRequires {
    param(
        [string]$PackageName,
        [string]$RequiresText
    )

    if ($HardPackageRequires.ContainsKey($PackageName)) {
        foreach ($Pattern in $HardPackageRequires[$PackageName]) {
            if ([regex]::IsMatch($RequiresText, $Pattern, 'IgnoreCase')) {
                Add-Violation 'Error' 'PackageRequires' $PackageName "Forbidden package dependency matches $Pattern"
            }
        }
    }

    if ($IncludeKnownDebt -and $KnownDebtRequires.ContainsKey($PackageName)) {
        foreach ($Pattern in $KnownDebtRequires[$PackageName]) {
            if ([regex]::IsMatch($RequiresText, $Pattern, 'IgnoreCase')) {
                Add-Violation 'Warning' 'KnownPackageDebt' $PackageName "Known optional-package split debt matches $Pattern"
            }
        }
    }
}

function Test-RuntimeSources {
    param(
        [string]$PackageName,
        [string[]]$SourceEntries
    )

    foreach ($Entry in $SourceEntries) {
        $Normalized = $Entry.Replace('/', '\')
        $FileName = [System.IO.Path]::GetFileName($Normalized)

        if ($FileName -match '(?i)(^Test\.|\.Test\.|TestHelper)') {
            Add-Violation 'Error' 'RuntimeNoTestUnits' $PackageName "Runtime package contains test helper/source: $Entry"
        }

        if (($PackageName -eq 'DeepBaseCore.dpk') -and ($Normalized -notmatch '^(?i)Core\\')) {
            Add-Violation 'Error' 'CoreSourceRoot' $PackageName "Core package source must stay under Core: $Entry"
        }

        if (($PackageName -eq 'DeepBaseServices.dpk') -and ($Normalized -match '^(?i)Features\\')) {
            Add-Violation 'Error' 'ServicesNoFeatureSource' $PackageName "Services package must not include Features source: $Entry"
        }

        if (($PackageName -eq 'DeepBasePersistence.dpk') -and ($Normalized -match '^(?i)(VCL|FMX|Features)\\')) {
            Add-Violation 'Error' 'PersistenceSourceRoot' $PackageName "Persistence package must not include UI or feature source: $Entry"
        }

        if (($PackageName -eq 'DeepBaseFeatures.dpk') -and ($Normalized -match '^(?i)(VCL|FMX)\\')) {
            Add-Violation 'Error' 'FeaturesNoUiSource' $PackageName "Features package must not include UI source: $Entry"
        }
    }
}

function Test-SourceDependencies {
    param(
        [string]$RelativeDir,
        [string[]]$ForbiddenPatterns,
        [string[]]$Allowlist,
        [string]$RuleName,
        [ValidateSet('Error', 'Warning')]
        [string]$Severity = 'Error'
    )

    $Dir = Join-Path $SourcePath $RelativeDir
    if (-not (Test-Path -LiteralPath $Dir)) {
        return
    }

    Get-ChildItem -LiteralPath $Dir -Filter '*.pas' -Recurse | ForEach-Object {
        $FileName = $_.Name.ToLowerInvariant()
        if ($Allowlist -contains $FileName) {
            return
        }

        $Text = Remove-PascalStringLiterals (Remove-PascalComments (Read-Text $_.FullName))
        $Match = Test-AnyRegex $Text $ForbiddenPatterns
        if ($null -ne $Match) {
            $RelativePath = Resolve-Path -LiteralPath $_.FullName -Relative
            Add-Violation $Severity $RuleName $RelativePath "Forbidden source dependency matches $Match"
        }
    }
}

function Test-PackageSourceDependencies {
    param(
        [string]$PackageName,
        [string[]]$SourceEntries,
        [string[]]$ForbiddenPatterns,
        [string[]]$Allowlist,
        [string]$RuleName,
        [ValidateSet('Error', 'Warning')]
        [string]$Severity = 'Error'
    )

    $Seen = New-Object 'System.Collections.Generic.HashSet[string]'
    foreach ($Entry in $SourceEntries) {
        $Normalized = $Entry.Replace('/', '\')
        if (-not $Seen.Add($Normalized.ToLowerInvariant())) {
            continue
        }

        $FullPath = Join-Path $SourcePath $Normalized
        if (-not (Test-Path -LiteralPath $FullPath)) {
            continue
        }

        $FileName = [System.IO.Path]::GetFileName($Normalized).ToLowerInvariant()
        if ($Allowlist -contains $FileName) {
            continue
        }

        $Text = Remove-PascalStringLiterals (Remove-PascalComments (Read-Text $FullPath))
        $Match = Test-AnyRegex $Text $ForbiddenPatterns
        if ($null -ne $Match) {
            Add-Violation $Severity $RuleName $Normalized "Package $PackageName source dependency matches $Match"
        }
    }
}

function Test-FireDacOutsidePersistence {
    $ForbiddenPatterns = @(
        '\bFireDAC\.',
        '\bTFDConnection\b',
        '\bTFDQuery\b',
        '\bData\.DB\b'
    )

    foreach ($RelativeDir in @('Features', 'VCL', 'FMX')) {
        $Dir = Join-Path $SourcePath $RelativeDir
        if (-not (Test-Path -LiteralPath $Dir)) {
            continue
        }

        Get-ChildItem -LiteralPath $Dir -Filter '*.pas' -Recurse | ForEach-Object {
            $FullPath = $_.FullName
            $RelativePath = (Resolve-Path -LiteralPath $FullPath -Relative).TrimStart('.\')
            $NormalizedPath = $RelativePath.Replace('/', '\').ToLowerInvariant()

            $Text = Remove-PascalStringLiterals (Remove-PascalComments (Read-Text $FullPath))
            $Match = Test-AnyRegex $Text $ForbiddenPatterns
            if ($null -eq $Match) {
                return
            }

            if ($KnownFireDacOutsidePersistence -contains $NormalizedPath) {
                if ($IncludeKnownDebt) {
                    Add-Violation 'Warning' 'FireDacOutsidePersistenceDebt' $RelativePath "Known FireDAC adapter debt outside Persistence matches $Match"
                }
            }
            else {
                Add-Violation 'Error' 'FireDacOutsidePersistence' $RelativePath "FireDAC/Data.DB dependency must live behind Persistence adapters; matched $Match"
            }
        }
    }
}

$PackageSourceEntries = @{}
foreach ($PackageFile in $PackageFiles) {
    $FullPath = Join-Path $SourcePath $PackageFile
    if (-not (Test-Path -LiteralPath $FullPath)) {
        Add-Violation 'Error' 'MissingPackage' $PackageFile "Package file not found"
        continue
    }

    $Text = Remove-PascalComments (Read-Text $FullPath)
    $RequiresText = Get-PackageRequiresText $Text
    $SourceEntries = @(Get-PackageSourceEntries $Text)
    $PackageSourceEntries[$PackageFile] = $SourceEntries

    Test-PackageRequires $PackageFile $RequiresText

    if ($RuntimePackages -contains $PackageFile) {
        Test-RuntimeSources $PackageFile $SourceEntries
    }
}

foreach ($ProjectFile in $ProjectFiles) {
    $FullPath = Join-Path $SourcePath $ProjectFile
    if (-not (Test-Path -LiteralPath $FullPath)) {
        Add-Violation 'Error' 'MissingProject' $ProjectFile "Project file not found"
        continue
    }

    $Text = Read-Text $FullPath
    $ReferencesText = Get-ProjectReferencesText $Text
    $SourceEntries = @(Get-ProjectSourceEntries $Text)

    Test-ProjectReferences $ProjectFile $ReferencesText

    $PackageName = [System.IO.Path]::ChangeExtension($ProjectFile, '.dpk')
    if ($PackageSourceEntries.ContainsKey($PackageName)) {
        $PackageSourceEntries[$PackageName] = @($PackageSourceEntries[$PackageName] + $SourceEntries)
    }
    else {
        $PackageSourceEntries[$PackageName] = $SourceEntries
    }

    if ($RuntimePackages -contains $PackageName) {
        Test-RuntimeSources $PackageName $SourceEntries
    }
}

Test-SourceDependencies 'Core' @(
    '\bVcl\.',
    '\bFMX\.',
    '\bDesignIntf\b',
    '\bDesignEditors\b'
) $CoreUiAllowlist 'CoreNoUiSourceDependency' 'Error'

Test-SourceDependencies 'Core' @(
    '\bFireDAC\.',
    '\bTFDConnection\b',
    '\bTFDQuery\b',
    '\bData\.DB\b'
) $CoreDbAllowlist 'CoreNoDbDriverDependency' 'Warning'

Test-SourceDependencies 'Core' @(
    '\bDeepBase\.Commerce\.',
    '\bDeepBase\.Speech\.',
    '\bDeepBase\.Updater\b',
    '\bDeepBase\.AutoUpdate\b',
    '\bDeepBase\.Browser',
    '\bDeepBase\.IntentClarification'
) @() 'CoreNoOptionalFeatureDependency' 'Error'

Test-SourceDependencies 'Core' @(
    '\bSystem\.Net\.HttpClient\b',
    '\bIdHTTP\b',
    '\bREST\.Client\b'
) @(
    'DeepBase.Net.pas',
    'DeepBase.LLM.pas',
    'DeepBase.LLM.BillingClient.pas',
    'DeepBase.AIErrorHandler.LLMBridge.pas',
    'DeepBase.Feedback.pas'
) 'CoreHttpDependencyAllowlist' 'Warning'

Test-SourceDependencies 'Core' @(
    '\bTThread\.Create\b',
    '\bTThread\.CreateAnonymousThread\b',
    '\bTTask\.Run\b'
) @(
    'DeepBase.Scheduler.pas',
    'DeepBase.WorkerQueue.pas',
    'DeepBase.FileWatcher.pas',
    'DeepBase.SingleInstance.pas',
    'DeepBase.AutoFix.SelfTerminator.pas'
) 'CoreBackgroundThreadAllowlist' 'Warning'

Test-PackageSourceDependencies 'DeepBaseServices.dpk' @($PackageSourceEntries['DeepBaseServices.dpk']) @(
    '\bVcl\.',
    '\bFMX\.',
    '\bDesignIntf\b',
    '\bDesignEditors\b',
    '\bFireDAC\.',
    '\bTFDConnection\b',
    '\bTFDQuery\b',
    '\bData\.DB\b',
    '\bDeepBase\.Persistence\.',
    '\bDeepBase\.DB\.',
    '\bDeepBase\.Commerce\.',
    '\bDeepBase\.Speech\.',
    '\bDeepBase\.Updater\b',
    '\bDeepBase\.AutoUpdate\b',
    '\bDeepBase\.Browser',
    '\bDeepBase\.IntentClarification'
) @() 'ServicesNoUiDbFeatureSourceDependency' 'Error'

Test-FireDacOutsidePersistence

$ReportDir = Split-Path -Parent $ReportPath
if (-not [string]::IsNullOrWhiteSpace($ReportDir) -and -not (Test-Path -LiteralPath $ReportDir)) {
    New-Item -ItemType Directory -Path $ReportDir -Force | Out-Null
}

$ErrorCount = @($Violations | Where-Object { $_.Severity -eq 'Error' }).Count
$WarningCount = @($Violations | Where-Object { $_.Severity -eq 'Warning' }).Count

$Report = [pscustomobject]@{
    Timestamp = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'
    SourcePath = $SourcePath
    ErrorCount = $ErrorCount
    WarningCount = $WarningCount
    Violations = $Violations
}

$Report | ConvertTo-Json -Depth 6 | Set-Content -LiteralPath $ReportPath -Encoding UTF8

Write-Host 'DeepBase layer checks'
Write-Host "SourcePath: $SourcePath"
Write-Host "ReportPath: $ReportPath"
Write-Host "Errors: $ErrorCount"
Write-Host "Warnings: $WarningCount"

foreach ($Violation in $Violations) {
    $Color = if ($Violation.Severity -eq 'Error') { 'Red' } else { 'Yellow' }
    Write-Host ("[{0}] {1} {2}: {3}" -f $Violation.Severity, $Violation.Rule, $Violation.Subject, $Violation.Message) -ForegroundColor $Color
}

if ($FailOnViolation -and $ErrorCount -gt 0) {
    exit 1
}

exit 0
