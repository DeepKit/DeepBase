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
    Path to the BDS environment batch file. When omitted, auto-detection
    (M14) scans the Windows registry for the newest installed Delphi version.
    Can also be set via the AUTOFIX_DELPHI_ENV_BAT environment variable.

.PARAMETER DelphiVersion
    Explicit Delphi version selector (e.g. "37", "13.1", "florence").
    Only used when -EnvBat is not provided. Triggers registry-based lookup.

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

    [string]$DelphiVersion,

    [string[]]$MSBuildArgs = @()
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
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
    $pattern = '^(.+)\((\d+),(\d+)\)\s+(Error|Fatal|Warning|Hint)\s+([EFWH]\d+):\s+(.+?)\s*$'
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

    $bat = Resolve-DelphiEnvBat -Override $EnvBat -DelphiVersion $DelphiVersion
    if (-not (Test-Path -LiteralPath $bat -PathType Leaf)) {
        Write-AutoFixLog -Level error -Msg 'BDS environment batch missing' -Ctx @{ env_bat = $bat }
        Write-JsonFile -Path $OutputJson -Object ([pscustomobject]@{
            ts = $ts; success = $false; duration_sec = 0; reason = 'env_bat_missing'
            env_bat = $bat; errors = @(); warnings = @()
        })
        exit $Script:AutoFixExit_BdsFailed
    }

    # Write a temporary .cmd that loads env then invokes msbuild.
    # This avoids string interpolation into cmd.exe /c (shell injection).
    $tmpCmd = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.cmd'
    $extra = if ($MSBuildArgs) { ' ' + ($MSBuildArgs -join ' ') } else { '' }
    $cmdContent = @"
@echo off
call "$bat"
if errorlevel 1 exit /b 102
msbuild "$Project" /t:Build /p:Config=$Config /p:Platform=$Platform /v:normal$extra
"@
    [System.IO.File]::WriteAllText($tmpCmd, $cmdContent, [System.Text.UTF8Encoding]::new($false))

    Write-AutoFixLog -Level info -Msg 'invoking msbuild' -Ctx @{ project = $Project; config = $Config; platform = $Platform }

    # Use Start-Process with timeout so a hanging compiler cannot stall
    # the autofix loop indefinitely.
    $tmpOut  = [System.IO.Path]::GetTempFileName()
    $tmpErr  = [System.IO.Path]::GetTempFileName()
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName               = 'cmd.exe'
        $psi.Arguments              = "/c `"$tmpCmd`""
        $psi.RedirectStandardOutput = $true
        $psi.RedirectStandardError  = $true
        $psi.UseShellExecute        = $false
        $psi.CreateNoWindow         = $true
        $psi.StandardOutputEncoding = [System.Text.Encoding]::UTF8
        $psi.StandardErrorEncoding  = [System.Text.Encoding]::UTF8

        $proc = [System.Diagnostics.Process]::Start($psi)
        $stdoutTask = $proc.StandardOutput.ReadToEndAsync()
        $stderrTask = $proc.StandardError.ReadToEndAsync()

        $timeoutMs = 300000  # 5 minutes
        if (-not $proc.WaitForExit($timeoutMs)) {
            try { $proc.Kill($true) } catch { try { $proc.Kill() } catch {} }
            try { [void]$proc.WaitForExit(5000) } catch {}
            Write-AutoFixLog -Level error -Msg 'msbuild timed out' -Ctx @{ timeout_ms = $timeoutMs }
            $msbuildExit = 99
        } else {
            $msbuildExit = $proc.ExitCode
        }

        $outStd = ''
        $outErr = ''
        try {
            if (-not $stdoutTask.Wait(5000)) { Write-AutoFixLog -Level warn -Msg 'stdout read timed out after msbuild exit' -Ctx @{} }
            elseif ($stdoutTask.IsCompletedSuccessfully) { $outStd = $stdoutTask.Result }
        } catch {
            Write-AutoFixLog -Level warn -Msg 'stdout read failed' -Ctx @{ error = $_.Exception.Message }
        }
        try {
            if (-not $stderrTask.Wait(5000)) { Write-AutoFixLog -Level warn -Msg 'stderr read timed out after msbuild exit' -Ctx @{} }
            elseif ($stderrTask.IsCompletedSuccessfully) { $outErr = $stderrTask.Result }
        } catch {
            Write-AutoFixLog -Level warn -Msg 'stderr read failed' -Ctx @{ error = $_.Exception.Message }
        }

        [System.IO.File]::WriteAllText($tmpOut, $outStd, [System.Text.Encoding]::UTF8)
        [System.IO.File]::WriteAllText($tmpErr, $outErr, [System.Text.Encoding]::UTF8)
        $rawOutput = $outStd -split "`r?`n"
        if ($outErr.Trim() -ne '') {
            $rawOutput = @($rawOutput) + @($outErr -split "`r?`n")
        }
    } finally {
        if ($null -ne $proc) { try { $proc.Dispose() } catch {} }
        Remove-Item $tmpOut -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpErr -Force -ErrorAction SilentlyContinue
        Remove-Item $tmpCmd -Force -ErrorAction SilentlyContinue
    }
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
