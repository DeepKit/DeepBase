# DeepBase Win64 examples build gate
# Usage:
#   .\Scripts\build_examples_win64.ps1
#   .\Scripts\build_examples_win64.ps1 -IncludeOptional

param(
    [ValidateSet('Debug', 'Release')]
    [string]$Config = 'Debug',

    [ValidateSet('Win32', 'Win64')]
    [string]$Platform = 'Win64',

    [switch]$IncludeOptional
)

$ErrorActionPreference = 'Stop'

$RepoRoot = Split-Path -Parent $PSScriptRoot
$RsVarsBat = 'd:\Program Files (x86)\Embarcadero\Studio\23.0\bin\rsvars.bat'

$OutputRoot = Join-Path $RepoRoot 'TestResults'
$ExampleOutputRoot = Join-Path $OutputRoot 'Examples'
$DcuOutputPath = Join-Path $ExampleOutputRoot 'dcu'
$ExeOutputPath = Join-Path $ExampleOutputRoot 'bin'
$TextReportPath = Join-Path $OutputRoot 'ExampleBuildResults.txt'
$XmlReportPath = Join-Path $OutputRoot 'ExampleBuildResults.xml'

foreach ($path in @($OutputRoot, $ExampleOutputRoot, $DcuOutputPath, $ExeOutputPath)) {
    if (-not (Test-Path $path)) {
        New-Item -ItemType Directory -Path $path -Force | Out-Null
    }
}

if (-not (Test-Path $RsVarsBat)) {
    throw "rsvars.bat not found: $RsVarsBat"
}

$SourceRoots = @(
    'Core',
    'Persistence',
    'Features',
    'VCL',
    'FMX',
    'ThirdParty',
    'ThirdParty\Payment',
    'ThirdParty\Social',
    'Tools',
    'Libs'
)

$SearchDirs = New-Object System.Collections.Generic.List[string]
foreach ($root in $SourceRoots) {
    $full = Join-Path $RepoRoot $root
    if (Test-Path $full) {
        $SearchDirs.Add($full)
    }
}

$ExamplesRoot = Join-Path $RepoRoot 'Examples'
if (Test-Path $ExamplesRoot) {
    $SearchDirs.Add($ExamplesRoot)
    Get-ChildItem -Path $ExamplesRoot -Directory -Recurse -ErrorAction SilentlyContinue |
        ForEach-Object { $SearchDirs.Add($_.FullName) }
}

$UnitSearchPath = (($SearchDirs | Select-Object -Unique) -join ';')
$MsBuildUnitSearchPath = $UnitSearchPath + ';$(DCC_UnitSearchPath)'
$Namespaces = 'System;Xml;Data;Datasnap;Web;Soap;Winapi;System.Win;Vcl;Vcl.Imaging;Vcl.Touch;Vcl.Samples;Vcl.Shell;FMX;FMX.Types;FMX.Controls;FMX.Forms;FMX.Dialogs;FMX.StdCtrls;FMX.Layouts;FMX.ListView;FMX.Platform;FireDAC;FireDAC.Comp;FireDAC.Stan;FireDAC.DApt;FireDAC.Phys;FireDAC.Phys.SQLite;FireDAC.UI.Intf;FireDAC.VCLUI'

$HasVclSources = Test-Path (Join-Path $RepoRoot 'VCL')
$RequiredExamples = @()
if ($HasVclSources) {
    $RequiredExamples += [pscustomobject]@{ Name = 'Phase0Demo'; Path = 'Examples\Phase0Demo\Phase0Demo.dproj'; Type = 'MSBuild'; Required = $true; Notes = 'VCL phase 0 demo' }
    $RequiredExamples += [pscustomobject]@{ Name = 'Phase1Demo'; Path = 'Examples\Phase1Demo\Phase1Demo.dpr'; Type = 'DCC'; Required = $true; Notes = 'VCL phase 1 demo' }
    $RequiredExamples += [pscustomobject]@{ Name = 'FullDemo'; Path = 'Examples\FullDemo\FullDemo.dproj'; Type = 'MSBuild'; Required = $true; Notes = 'Full VCL demo' }
} else {
    Write-Host "VCL source directory not found; VCL examples are excluded from required gate." -ForegroundColor Yellow
}
$RequiredExamples += [pscustomobject]@{ Name = 'FMXPlatformDemo'; Path = 'Examples\FMXDemo\FMXPlatformDemo.dpr'; Type = 'DCC'; Required = $true; Notes = 'FMX platform demo' }
$RequiredExamples += [pscustomobject]@{ Name = 'CommerceE2EDemo'; Path = 'Examples\CommerceE2EDemo\CommerceE2EDemo.pas'; Type = 'DCC'; Required = $true; Notes = 'Console commerce E2E demo' }

$OptionalExamples = @(
    [pscustomobject]@{ Name = 'DataBindingDemo'; Path = 'Examples\DataBindingDemo\DataBindingDemo.dpr'; Type = 'DCC'; Required = $false; Notes = 'Additional VCL demo' },
    [pscustomobject]@{ Name = 'MultiLanguageDemo'; Path = 'Examples\MultiLanguageDemo\MultiLanguageDemo.dpr'; Type = 'DCC'; Required = $false; Notes = 'Additional VCL demo' },
    [pscustomobject]@{ Name = 'MVVMDemo'; Path = 'Examples\MVVMDemo\MVVMDemo.dpr'; Type = 'DCC'; Required = $false; Notes = 'Additional VCL demo' },
    [pscustomobject]@{ Name = 'MicroserviceClientDemo'; Path = 'Examples\MicroserviceClientDemo\MicroserviceClientDemo.dpr'; Type = 'DCC'; Required = $false; Notes = 'Requires service endpoint for runtime use' },
    [pscustomobject]@{ Name = 'TemplateCRUDApp'; Path = 'Examples\Templates\CRUDApp\CRUDApp.dpr'; Type = 'DCC'; Required = $false; Notes = 'Template project' },
    [pscustomobject]@{ Name = 'TemplateDocManager'; Path = 'Examples\Templates\DocManager\DocManager.dpr'; Type = 'DCC'; Required = $false; Notes = 'Template project' },
    [pscustomobject]@{ Name = 'TemplateDataAnalyzer'; Path = 'Examples\Templates\DataAnalyzer\DataAnalyzer.dpr'; Type = 'DCC'; Required = $false; Notes = 'Template project' }
)

function Invoke-CmdCapture {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Command,

        [Parameter(Mandatory = $true)]
        [string]$WorkingDirectory
    )

    Push-Location $WorkingDirectory
    try {
        $output = & cmd.exe /c $Command 2>&1
        $exitCode = $LASTEXITCODE
        return [pscustomobject]@{
            ExitCode = $exitCode
            Output = ($output -join [Environment]::NewLine)
        }
    }
    finally {
        Pop-Location
    }
}

function Invoke-ExampleBuild {
    param(
        [Parameter(Mandatory = $true)]
        [pscustomobject]$Example
    )

    $sourcePath = Join-Path $RepoRoot $Example.Path
    $workDir = Split-Path -Parent $sourcePath
    $start = Get-Date

    if (-not (Test-Path $sourcePath)) {
        return [pscustomobject]@{
            Name = $Example.Name
            Path = $Example.Path
            Required = $Example.Required
            Status = 'Failed'
            ExitCode = 1
            DurationMs = 0
            Notes = $Example.Notes
            Output = "Source not found: $sourcePath"
        }
    }

    if ($Example.Type -eq 'MSBuild') {
        $cmd = "call ""$RsVarsBat"" && msbuild ""$sourcePath"" /t:Build /p:Config=$Config /p:Platform=$Platform /p:DCC_UnitSearchPath=""$MsBuildUnitSearchPath"" /p:DCC_ExeOutput=""$ExeOutputPath"" /p:DCC_DcuOutput=""$DcuOutputPath"" /v:minimal"
    }
    else {
        $cmd = "call ""$RsVarsBat"" && dcc64 -B -Q -U""$UnitSearchPath"" -I""$UnitSearchPath"" -N0""$DcuOutputPath"" -E""$ExeOutputPath"" -NS$Namespaces ""$sourcePath"""
    }

    $result = Invoke-CmdCapture -Command $cmd -WorkingDirectory $workDir
    $elapsed = [int]((Get-Date) - $start).TotalMilliseconds
    $status = if ($result.ExitCode -eq 0) { 'Passed' } else { 'Failed' }

    [pscustomobject]@{
        Name = $Example.Name
        Path = $Example.Path
        Required = $Example.Required
        Status = $status
        ExitCode = $result.ExitCode
        DurationMs = $elapsed
        Notes = $Example.Notes
        Output = $result.Output
    }
}

function ConvertTo-XmlText {
    param([AllowNull()][string]$Value)
    if ($null -eq $Value) { return '' }
    return [System.Security.SecurityElement]::Escape($Value)
}

Write-Host "=============================================="
Write-Host "        DeepBase Examples Build Gate"
Write-Host "=============================================="
Write-Host "Config: $Config"
Write-Host "Platform: $Platform"
Write-Host "Include optional: $IncludeOptional"
Write-Host "Output: $OutputRoot"
Write-Host ""

$examples = New-Object System.Collections.Generic.List[object]
$RequiredExamples | ForEach-Object { $examples.Add($_) }
if ($IncludeOptional) {
    $OptionalExamples | ForEach-Object { $examples.Add($_) }
}

$results = New-Object System.Collections.Generic.List[object]
foreach ($example in $examples) {
    Write-Host "Building $($example.Name) ..."
    $result = Invoke-ExampleBuild -Example $example
    $results.Add($result)

    if ($result.Status -eq 'Passed') {
        Write-Host "  PASSED ($($result.DurationMs) ms)" -ForegroundColor Green
    }
    else {
        Write-Host "  FAILED (exit $($result.ExitCode))" -ForegroundColor Red
    }
}

$requiredFailures = @($results | Where-Object { $_.Required -and $_.Status -ne 'Passed' })
$failures = @($results | Where-Object { $_.Status -ne 'Passed' })
$skippedOptional = if ($IncludeOptional) { @() } else { @($OptionalExamples) }

$text = New-Object System.Collections.Generic.List[string]
$text.Add("DeepBase Examples Build Results")
$text.Add("GeneratedAt: $((Get-Date).ToString('yyyy-MM-dd HH:mm:ss'))")
$text.Add("Config: $Config")
$text.Add("Platform: $Platform")
$text.Add("")
foreach ($result in $results) {
    $kind = if ($result.Required) { 'required' } else { 'optional' }
    $text.Add("[$($result.Status)] $($result.Name) ($kind) - $($result.Path) - $($result.DurationMs) ms")
    if ($result.Status -ne 'Passed') {
        $tail = ($result.Output -split [Environment]::NewLine | Select-Object -Last 20) -join [Environment]::NewLine
        $text.Add($tail)
    }
}
if ($skippedOptional.Count -gt 0) {
    $text.Add("")
    $text.Add("Skipped optional examples:")
    foreach ($example in $skippedOptional) {
        $text.Add("[Skipped] $($example.Name) - $($example.Path) - $($example.Notes)")
    }
}
$text | Set-Content -Path $TextReportPath -Encoding UTF8

$testCount = $results.Count + $skippedOptional.Count
$failureCount = $failures.Count
$skipCount = $skippedOptional.Count
$xml = New-Object System.Collections.Generic.List[string]
$xml.Add('<?xml version="1.0" encoding="utf-8"?>')
$xml.Add("<testsuite name=""DeepBaseExamples"" tests=""$testCount"" failures=""$failureCount"" skipped=""$skipCount"">")
foreach ($result in $results) {
    $name = ConvertTo-XmlText $result.Name
    $path = ConvertTo-XmlText $result.Path
    $time = [Math]::Round($result.DurationMs / 1000.0, 3).ToString([Globalization.CultureInfo]::InvariantCulture)
    $xml.Add("  <testcase classname=""Examples"" name=""$name"" file=""$path"" time=""$time"">")
    if ($result.Status -ne 'Passed') {
        $message = ConvertTo-XmlText ("exit code $($result.ExitCode)")
        $output = ConvertTo-XmlText $result.Output
        $xml.Add("    <failure message=""$message"">$output</failure>")
    }
    $xml.Add('  </testcase>')
}
foreach ($example in $skippedOptional) {
    $name = ConvertTo-XmlText $example.Name
    $path = ConvertTo-XmlText $example.Path
    $notes = ConvertTo-XmlText $example.Notes
    $xml.Add("  <testcase classname=""Examples"" name=""$name"" file=""$path"" time=""0"">")
    $xml.Add("    <skipped message=""optional"">$notes</skipped>")
    $xml.Add('  </testcase>')
}
$xml.Add('</testsuite>')
$xml | Set-Content -Path $XmlReportPath -Encoding UTF8

Write-Host ""
Write-Host "Text report: $TextReportPath"
Write-Host "XML report:  $XmlReportPath"

if ($requiredFailures.Count -gt 0) {
    Write-Host ""
    Write-Host "Required example build failures:" -ForegroundColor Red
    $requiredFailures | ForEach-Object {
        Write-Host "  $($_.Name): $($_.Path)" -ForegroundColor Red
    }
    exit 1
}

Write-Host ""
Write-Host "Examples build gate passed." -ForegroundColor Green
exit 0
