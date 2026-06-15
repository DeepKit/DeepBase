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
    $ReportPath = Join-Path $RepoRoot 'TestResults\security-pattern-report.json'
}

$ScanRoots = @(
    'Core',
    'Persistence',
    'Features',
    'VCL',
    'FMX',
    'Scripts',
    'Tools',
    'Examples'
)

$ScanExtensions = @('.pas', '.dpr', '.inc', '.ps1', '.cmd', '.bat', '.json', '.ini', '.env')

$KnownSqlDebt = @(
    'Persistence\DeepBase.DB.AutoRefreshConfig.pas',
    'Persistence\DeepBase.DB.StatusMachine.pas',
    'Persistence\DeepBase.Persistence.Diagnose.FireDAC.pas',
    'Persistence\DeepBase.Persistence.Manager.FireDAC.pas',
    'Persistence\DeepBase.Persistence.Security.FireDAC.pas',
    'Persistence\DeepBase.DB.Guardian.pas',
    'Persistence\DeepBase.DB.Migrations.pas',
    'Features\DeepBase.AntiTamper.pas',
    'Core\DeepBase.ORM.pas',
    'Core\DeepBase.LLM.pas',
    'Persistence\DeepBase.Persistence.FormState.FireDAC.pas',
    'VCL\DeepBase.VCL.LogListView.pas',
    'FMX\DeepBase.FMX.LogListView.pas'
) | ForEach-Object { $_.ToLowerInvariant() }

$SecretValueAllowlist = @(
    'test',
    'unit-test',
    'dummy',
    'sample',
    'example',
    'placeholder',
    'changeme',
    'change-me',
    'your-',
    'mock',
    'demo',
    'localhost',
    'token123',
    'api_key',
    'secret_key',
    'client-secret',
    'test-secret'
)

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

function Get-RelativePath {
    param([Parameter(Mandatory = $true)][string]$Path)
    $Root = [System.IO.Path]::GetFullPath($SourcePath)
    if (-not $Root.EndsWith([System.IO.Path]::DirectorySeparatorChar)) {
        $Root += [System.IO.Path]::DirectorySeparatorChar
    }

    $RootUri = [System.Uri]::new($Root)
    $PathUri = [System.Uri]::new([System.IO.Path]::GetFullPath($Path))
    return [System.Uri]::UnescapeDataString(
        $RootUri.MakeRelativeUri($PathUri).ToString()).Replace('/', '\')
}

function Test-AllowlistedSecretValue {
    param([string]$Value)

    $Lower = $Value.ToLowerInvariant()
    foreach ($Token in $SecretValueAllowlist) {
        if ($Lower.Contains($Token)) {
            return $true
        }
    }

    if ($Lower -match '^[x\*_\-]+$') {
        return $true
    }

    return $false
}

function Get-ScanFiles {
    foreach ($Root in $ScanRoots) {
        $FullRoot = Join-Path $SourcePath $Root
        if (-not (Test-Path -LiteralPath $FullRoot)) {
            continue
        }

        Get-ChildItem -LiteralPath $FullRoot -File -Recurse | Where-Object {
            $ScanExtensions -contains $_.Extension.ToLowerInvariant()
        }
    }
}

function Test-SecretPatterns {
    param(
        [string]$RelativePath,
        [string]$Text
    )

    if ($RelativePath -match '^(?i)Tests\\') {
        return
    }

    $Lines = $Text -split "\r?\n"
    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        $Line = $Lines[$Index]
        $LineNo = $Index + 1
        $Subject = "${RelativePath}:$LineNo"

        if ($Line -match '-----BEGIN (RSA |EC |OPENSSH |DSA )?PRIVATE KEY-----') {
            Add-Violation 'Error' 'SecretPrivateKey' $Subject 'Private key material must not be committed.'
        }

        if ($Line -match '\bAKIA[0-9A-Z]{16}\b') {
            Add-Violation 'Error' 'SecretAwsAccessKey' $Subject 'AWS access key-like literal found.'
        }

        if ($Line -match '\bsk-[A-Za-z0-9_-]{20,}\b') {
            Add-Violation 'Error' 'SecretOpenAIStyleKey' $Subject 'OpenAI-style secret key literal found.'
        }

        if ($Line -match '\bxox[baprs]-[A-Za-z0-9-]{10,}\b') {
            Add-Violation 'Error' 'SecretSlackToken' $Subject 'Slack token-like literal found.'
        }

        if ($Line -match '\bBearer\s+[A-Za-z0-9._~+/-]{20,}\b') {
            Add-Violation 'Error' 'SecretBearerToken' $Subject 'Bearer token-like literal found.'
        }

        $AssignmentMatches = [regex]::Matches(
            $Line,
            '\b(api[_-]?key|appsecret|clientsecret|secret|password|token)\b\s*(:=|=|:)\s*[''"]([^''"]{12,})[''"]',
            'IgnoreCase')
        foreach ($Match in $AssignmentMatches) {
            $Value = $Match.Groups[3].Value
            if (-not (Test-AllowlistedSecretValue $Value)) {
                Add-Violation 'Warning' 'SecretSensitiveLiteral' $Subject "Sensitive-looking literal assigned to $($Match.Groups[1].Value)."
            }
        }
    }
}

function Test-SqlPatterns {
    param(
        [string]$RelativePath,
        [string]$Text
    )

    $NormalizedPath = $RelativePath.ToLowerInvariant()
    $IsKnownDebt = $KnownSqlDebt -contains $NormalizedPath
    if ($IsKnownDebt -and (-not $IncludeKnownDebt)) {
        return
    }

    $Severity = if ($IsKnownDebt) { 'Warning' } else { 'Error' }
    $Lines = $Text -split "\r?\n"

    for ($Index = 0; $Index -lt $Lines.Count; $Index++) {
        $Line = $Lines[$Index]
        $LineNo = $Index + 1
        $Subject = "${RelativePath}:$LineNo"

        if ($Line -match '(?i)(SQL\.Text\s*:=|ExecSQL\s*\()\s*Format\s*\(') {
            Add-Violation $Severity 'SqlDynamicFormat' $Subject 'Dynamic SQL via Format must validate identifiers and keep values parameterized.'
        }

        if ($Line -match '(?i)(SQL\.Text\s*:=|ExecSQL\s*\().*\+\s*[A-Za-z_][A-Za-z0-9_\.]*') {
            Add-Violation $Severity 'SqlStringConcatenation' $Subject 'Dynamic SQL concatenation must be limited to validated identifiers, never values.'
        }

        if (($Line -match '(?i)\bDELETE\s+FROM\b') -and ($Line -notmatch '(?i)\bWHERE\b')) {
            Add-Violation $Severity 'SqlDeleteWithoutWhere' $Subject 'DELETE FROM without a WHERE clause must be intentional and reviewed.'
        }

        if ($Line -match '(?i)(SQL\.Text\s*:=|ExecSQL\s*\(|ExecuteSQL\s*\(|ExecuteStatement\s*\().*\bDROP\s+TABLE\b.*\+') {
            Add-Violation $Severity 'SqlDynamicDropTable' $Subject 'Dynamic DROP TABLE requires explicit schema/identifier validation.'
        }

        if ($Line -match '(?i)(SQL\.Text\s*:=|ExecSQL\s*\(|ExecuteSQL\s*\(|ExecuteStatement\s*\().*\bALTER\s+TABLE\b.*\+') {
            Add-Violation $Severity 'SqlDynamicAlterTable' $Subject 'Dynamic ALTER TABLE requires explicit schema/identifier validation.'
        }
    }
}

foreach ($File in Get-ScanFiles) {
    $RelativePath = Get-RelativePath $File.FullName
    $Text = Read-Text $File.FullName
    if ($File.Extension.Equals('.pas', [System.StringComparison]::OrdinalIgnoreCase) -or
        $File.Extension.Equals('.dpr', [System.StringComparison]::OrdinalIgnoreCase) -or
        $File.Extension.Equals('.inc', [System.StringComparison]::OrdinalIgnoreCase)) {
        $Text = Remove-PascalComments $Text
    }

    Test-SecretPatterns $RelativePath $Text
    if ($RelativePath -match '^(?i)(Core|Persistence|Features|VCL|FMX)\\') {
        Test-SqlPatterns $RelativePath $Text
    }
}

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

Write-Host 'DeepBase security pattern checks'
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
