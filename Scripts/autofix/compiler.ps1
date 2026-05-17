<#
.SYNOPSIS
    Wrapper around MSBuild that produces structured compile-errors.json.

.DESCRIPTION
    Loads the BDS 37.0 environment (delphi-13.1.bat by default) then invokes
    msbuild on the supplied .dproj. stdout + stderr are scanned with a regex
    that captures Delphi-style messages of the form:

        <file>(<line>,<col>) <Severity> <Code>: <message>

    where <Severity> is one of Error / Fatal / Warning / Hint and <Code> matches
    /^[EFWH]\d+/.

    Output schema (design §4.6):
        {
          "ts": "...",
          "success": <bool>,
          "duration_sec": <int>,
          "errors":   [ { file, line, column, code, message }, ... ],
          "warnings": [ { file, line, column, code, message }, ... ]
        }

.PARAMETER Project
    Path to the .dproj file to compile.

.PARAMETER Config
    Build configuration (default: Debug).

.PARAMETER Platform
    Target platform (default: Win64).

.PARAMETER OutputJson
    Path to write the structured result. Default: ./compile-errors.json.

.PARAMETER LogFile
    Optional path to dump the raw msbuild output. Default: alongside OutputJson.

.PARAMETER EnvBat
    Path to the BDS environment batch file. Defaults to
    D:\_Progs\02Business\scripts\env\delphi-13.1.bat (the shared entry point).
    Can be overridden via the AUTOFIX_DELPHI_ENV_BAT environment variable.

.PARAMETER MSBuildArgs
    Extra arguments passed verbatim to msbuild.

.OUTPUTS
    Exit codes:
       0  compile success
       1  compile failure (compile-errors.json contains the errors)
     102  BDS environment unavailable (env bat missing)

.EXAMPLE
    pwsh -File compiler.ps1 -Project Tests/DeepBaseTests.dproj

.NOTES
    Validates Requirements 10.1, 10.2, 10.3.
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [string]$Project,

    [string]$Config = 'Debug',

    [string]$Platform = 'Win64',

    [string]$OutputJson,

    [string]$LogFile,

    [string]$EnvBat,

    [string[]]$MSBuildArgs = @()
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Resolve-EnvBat {
    [CmdletBinding()]
    param([string]$Override)
    if ($Override) { return $Override }
    if ($env:AUTOFIX_DELPHI_ENV_BAT) { return $env:AUTOFIX_DELPHI_ENV_BAT }
    return 'D:\_Progs\02Business\scripts\env\delphi-13.1.bat'
}

function Parse-CompileLine {
    <#
    .SYNOPSIS
        Parse a single msbuild output line into a structured record (or $null).
    #>
    [CmdletBinding()]
    param([string]$Line)

    if ([string]::IsNullOrWhiteSpace($Line)) { return $null }

    # Anchored regex per design §3.8.4 / §4.6 / Property 13:
    #   <file>(<line>,<col>) <Severity> <Code>: <message>
    # Severity in: Error|Fatal|Warning|Hint
    # Code in   : ^[EFWH]\d+
    $pattern = '^(.+?)\((\d+),(\d+)\)\s+(Error|Fatal|Warning|Hint)\s+([EFWH]\d+):\s+(.+?)\s*$'
    $m = [regex]::Match($Line, $pattern)
    if (-not $m.Success) { return $null }

    $sev = $m.Groups[4].Value
    $kind = if ($sev -in @('Error', 'Fatal')) { 'error' } else { 'warning' }
    return [pscustomobject]@{
        kind     = $kind
        severity = $sev
        file     = $m.Groups[1].Value.Trim()
        line     = [int]$m.Groups[2].Value
        column   = [int]$m.Groups[3].Value
        code     = $m.Groups[5].Value
        message  = $m.Groups[6].Value.Trim()
    }
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
$started = Get-Date
$ts      = Get-AutoFixTimestamp

if (-not $OutputJson) { $OutputJson = Join-Path (Get-Location).Path 'compile-errors.json' }
if (-not $LogFile)    { $LogFile    = [System.IO.Path]::ChangeExtension($OutputJson, '.log') }

try {
    if (-not (Test-Path -LiteralPath $Project -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'project file not found' -Ctx @{ project = $Project }
        Write-JsonFile -Path $OutputJson -Object ([pscustomobject]@{
            ts = $ts; success = $false; duration_sec = 0; reason = 'project_not_found'
            errors = @(); warnings = @()
        })
        exit $Script:AutoFixExit_BadParams
    }

    $bat = Resolve-EnvBat -Override $EnvBat
    if (-not (Test-Path -LiteralPath $bat -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'BDS environment batch missing' -Ctx @{ env_bat = $bat }
        Write-JsonFile -Path $OutputJson -Object ([pscustomobject]@{
            ts = $ts; success = $false; duration_sec = 0; reason = 'env_bat_missing'
            env_bat = $bat; errors = @(); warnings = @()
        })
        exit $Script:AutoFixExit_BdsFailed
    }

    # Build cmd.exe command: load env then invoke msbuild
    $extra = if ($MSBuildArgs) { ' ' + ($MSBuildArgs -join ' ') } else { '' }
    $cmdLine = ('"{0}" && msbuild "{1}" /t:Build /p:Config={2} /p:Platform={3} /v:normal{4}' -f `
        $bat, $Project, $Config, $Platform, $extra)

    Write-AutoFixLog -Level info -Msg 'invoking msbuild' -Ctx @{ project = $Project; config = $Config; platform = $Platform }

    $rawOutput = & cmd.exe /c $cmdLine 2>&1
    $msbuildExit = $LASTEXITCODE
    $duration = [int]((Get-Date) - $started).TotalSeconds

    # Persist raw log
    Write-Utf8NoBom -Path $LogFile -Content (($rawOutput | Out-String).TrimEnd() + [Environment]::NewLine)

    # Parse
    $errors   = New-Object System.Collections.Generic.List[object]
    $warnings = New-Object System.Collections.Generic.List[object]
    foreach ($line in $rawOutput) {
        $s = if ($null -eq $line) { '' } else { [string]$line }
        $rec = Parse-CompileLine -Line $s
        if ($null -eq $rec) { continue }
        $emit = [pscustomobject]@{
            file    = $rec.file
            line    = $rec.line
            column  = $rec.column
            code    = $rec.code
            message = $rec.message
        }
        if ($rec.kind -eq 'error') { $errors.Add($emit) | Out-Null }
        else                       { $warnings.Add($emit) | Out-Null }
    }

    $success = ($msbuildExit -eq 0) -and ($errors.Count -eq 0)
    $result = [pscustomobject]@{
        ts            = $ts
        success       = $success
        duration_sec  = $duration
        msbuild_exit  = $msbuildExit
        project       = $Project
        config        = $Config
        platform      = $Platform
        errors        = @($errors.ToArray())
        warnings      = @($warnings.ToArray())
        log_path      = $LogFile
    }
    Write-JsonFile -Path $OutputJson -Object $result

    Write-AutoFixLog -Level info -Msg 'compile finished' -Ctx @{
        success = $success; errors = $errors.Count; warnings = $warnings.Count; duration_sec = $duration
    }

    if ($success) { exit $Script:AutoFixExit_Ok }
    exit $Script:AutoFixExit_Generic
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'compiler.ps1' }
    Write-JsonFile -Path $OutputJson -Object ([pscustomobject]@{
        ts = $ts; success = $false; duration_sec = ([int]((Get-Date) - $started).TotalSeconds)
        reason = 'exception'; error_message = $_.Exception.Message
        errors = @(); warnings = @()
    })
    exit $Script:AutoFixExit_Generic
}
