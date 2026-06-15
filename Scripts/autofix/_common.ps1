#requires -Version 7.0

# =============================================================================
# DeepBase AutoFix - Common Helpers
# =============================================================================
# 用法: 所有 scripts/autofix/*.ps1 第一行 dot-source:
#       . "$PSScriptRoot/_common.ps1"
#
# 提供:
#   - StrictMode + ErrorActionPreference
#   - Read-JsonFile / Write-JsonFile / Read-Jsonl / Write-Jsonl
#   - Write-AutoFixLog
#   - Get-AutoFixTimestamp / New-AutoFixRunId
#   - Get-Sha256File / Get-Sha1Hex
#   - Invoke-NativeCheck (检查 $LASTEXITCODE 非零即 throw)
#   - 退出码常量 ($AutoFixExit_*)
# =============================================================================

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'
$ProgressPreference = 'SilentlyContinue'

# Set $Script:AutoFixLogFile = 'path/to/log.jsonl' before calling Write-AutoFixLog
# to mirror all log entries to a structured JSONL file.
$Script:AutoFixLogFile = $null

# -----------------------------------------------------------------------------
# Exit code constants (design §4.8)
# -----------------------------------------------------------------------------
$Script:AutoFixExit_Ok           = 0
$Script:AutoFixExit_Generic      = 1
$Script:AutoFixExit_BadParams    = 100
$Script:AutoFixExit_GitFailed    = 101
$Script:AutoFixExit_BdsFailed    = 102
$Script:AutoFixExit_AiFailed     = 103
$Script:AutoFixExit_MaxIter      = 110
$Script:AutoFixExit_Oscillation  = 111
$Script:AutoFixExit_Interrupted  = 130

# -----------------------------------------------------------------------------
# Timestamp / RunId
# -----------------------------------------------------------------------------
function Get-AutoFixTimestamp {
    [CmdletBinding()]
    param()
    return (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz')
}

function New-AutoFixRunId {
    [CmdletBinding()]
    param()
    return [guid]::NewGuid().ToString()
}

# -----------------------------------------------------------------------------
# Hashing
# -----------------------------------------------------------------------------
function Get-Sha256File {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Get-Sha256File: file not found: $Path"
    }
    return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash.ToLowerInvariant()
}

function Get-Sha1Hex {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Text
    )
    $sha1 = [System.Security.Cryptography.SHA1]::Create()
    try {
        $bytes = [System.Text.Encoding]::UTF8.GetBytes($Text)
        $h = $sha1.ComputeHash($bytes)
        return ([System.BitConverter]::ToString($h)).Replace('-', '').ToLowerInvariant()
    }
    finally {
        $sha1.Dispose()
    }
}

# -----------------------------------------------------------------------------
# JSON IO (UTF-8 no BOM)
# -----------------------------------------------------------------------------
function Write-Utf8NoBom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $enc = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($Path, $Content, $enc)
}

function Append-Utf8NoBom {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Content
    )
    $dir = Split-Path -Parent $Path
    if ($dir -and -not (Test-Path -LiteralPath $dir)) {
        New-Item -ItemType Directory -Path $dir -Force | Out-Null
    }
    $enc = [System.Text.UTF8Encoding]::new($false)
    if (-not (Test-Path -LiteralPath $Path)) {
        [System.IO.File]::WriteAllText($Path, $Content, $enc)
    } else {
        [System.IO.File]::AppendAllText($Path, $Content, $enc)
    }
}

function Read-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Depth = 32
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        throw "Read-JsonFile: file not found: $Path"
    }
    $raw = [System.IO.File]::ReadAllText($Path, [System.Text.UTF8Encoding]::new($false))
    if ([string]::IsNullOrWhiteSpace($raw)) { return $null }
    return ($raw | ConvertFrom-Json -Depth $Depth -DateKind String)
}

function Write-JsonFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowNull()]$Object,
        [int]$Depth = 32
    )
    $json = if ($null -eq $Object) {
        'null'
    } else {
        ($Object | ConvertTo-Json -Depth $Depth -Compress:$false)
    }
    Write-Utf8NoBom -Path $Path -Content $json
}

function Read-Jsonl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [int]$Depth = 32
    )
    if (-not (Test-Path -LiteralPath $Path -PathType Leaf)) {
        $Script:LastJsonlParseErrors = 0
        return @()
    }
    $lines = [System.IO.File]::ReadAllLines($Path, [System.Text.UTF8Encoding]::new($false))
    $result = New-Object System.Collections.Generic.List[object]
    $parseErrors = 0
    foreach ($line in $lines) {
        $trim = $line.Trim()
        if ($trim -eq '') { continue }
        try {
            $obj = $trim | ConvertFrom-Json -Depth $Depth -DateKind String
            $result.Add($obj) | Out-Null
        } catch {
            $parseErrors++
            Write-AutoFixLog -Level 'warn' -Msg 'skipping malformed jsonl line' -Ctx @{ path = $Path; line = $trim.Substring(0, [Math]::Min(80, $trim.Length)) }
        }
    }
    $Script:LastJsonlParseErrors = $parseErrors
    if ($parseErrors -gt 0) {
        Write-AutoFixLog -Level 'warn' -Msg 'jsonl parse summary' -Ctx @{ path = $Path; parsed = $result.Count; errors = $parseErrors }
    }
    return ,$result.ToArray()
}

function Write-Jsonl {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][AllowNull()]$Object,
        [int]$Depth = 32,
        [switch]$Append
    )
    $json = ($Object | ConvertTo-Json -Depth $Depth -Compress)
    $line = $json + [Environment]::NewLine
    if ($Append) {
        Append-Utf8NoBom -Path $Path -Content $line
    } else {
        Write-Utf8NoBom -Path $Path -Content $line
    }
}

# -----------------------------------------------------------------------------
# Logging
# -----------------------------------------------------------------------------
function Write-AutoFixLog {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('debug', 'info', 'warn', 'error')]
        [string]$Level,

        [Parameter(Mandatory)]
        [string]$Msg,

        [Parameter()]
        $Ctx = $null
    )

    $ts = Get-AutoFixTimestamp
    $ctxText = ''
    if ($null -ne $Ctx) {
        try {
            $ctxText = ($Ctx | ConvertTo-Json -Depth 6 -Compress)
        } catch {
            $ctxText = $Ctx.ToString()
        }
    }

    $line = "[$ts] [$($Level.ToUpper())] $Msg"
    if ($ctxText) { $line = "$line $ctxText" }

    switch ($Level) {
        'error' { [Console]::Error.WriteLine($line) }
        'warn'  { [Console]::Error.WriteLine($line) }
        default { [Console]::Out.WriteLine($line) }
    }

    if ($Script:AutoFixLogFile) {
        try {
            $rec = [pscustomobject]@{
                ts    = $ts
                level = $Level
                msg   = $Msg
                ctx   = $Ctx
            }
            $jsonLine = ($rec | ConvertTo-Json -Depth 6 -Compress)
            [System.IO.File]::AppendAllText($Script:AutoFixLogFile,
                $jsonLine + [Environment]::NewLine,
                [System.Text.UTF8Encoding]::new($false))
        } catch {}
    }
}

# -----------------------------------------------------------------------------
# External command helpers
# -----------------------------------------------------------------------------
function Invoke-NativeCheck {
    <#
    .SYNOPSIS
        After invoking a native command, validate $LASTEXITCODE; throw on non-zero.
    .EXAMPLE
        & git status
        Invoke-NativeCheck -Cmd 'git status'
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Cmd,
        [int]$Allowed = 0
    )
    if ($LASTEXITCODE -ne $Allowed) {
        throw "external command failed: $Cmd (exit=$LASTEXITCODE)"
    }
}

function Resolve-OutputDir {
    <#
    .SYNOPSIS
        Resolve an OutputDir parameter: create if missing, return absolute path.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Path
    )
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $Path).Path
}

# -----------------------------------------------------------------------------
# Glob matching (used by diff-guard.ps1 and friends)
# -----------------------------------------------------------------------------
function ConvertTo-NormalizedPath {
    [CmdletBinding()]
    param([Parameter(Mandatory)][AllowEmptyString()][string]$Path)
    if ([string]::IsNullOrEmpty($Path)) { return '' }
    $p = $Path.Replace('\', '/')
    if ($p.StartsWith('./')) { $p = $p.Substring(2) }
    return $p
}

function ConvertTo-RegexFromGlob {
    <#
    .SYNOPSIS
        Translate a forward-slash glob into a .NET regex pattern.
        Supports ** (any path segments), * (any chars except /), ? (one char except /).
    .NOTES
        ** semantics (gitignore-style):
          - '**/' at start  → zero or more leading directories: (.+/)?
          - '/**/' in middle → zero or more middle directories: /(.+/)?
          - '/**' at end     → any subtree under the prefix:     /.*
          - standalone '**'  → match anything:                  .*
    #>
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Glob)

    $g = (ConvertTo-NormalizedPath -Path $Glob)
    $sb = [System.Text.StringBuilder]::new()
    [void]$sb.Append('^')
    $i = 0
    while ($i -lt $g.Length) {
        $c = $g[$i]

        if ($c -eq '*' -and $i + 1 -lt $g.Length -and $g[$i + 1] -eq '*') {
            $afterStar = $i + 2
            $atStart   = ($i -eq 0)
            $atEnd     = ($afterStar -ge $g.Length)
            $hasSlashAft = (-not $atEnd -and $g[$afterStar] -eq '/')
            $hasSlashBef = (-not $atStart -and $g[$i - 1] -eq '/')

            if ($atStart -and $hasSlashAft) {
                # **/ at start → zero or more leading dir segments
                [void]$sb.Append('(.+/)?')
                $i = $afterStar + 1
            }
            elseif ($hasSlashBef -and $hasSlashAft) {
                # /**/ in middle → replace the already-emitted \/ with a
                # segment-flexible pattern that allows zero or more middle dirs.
                if ($sb.Length -ge 2 -and $sb.ToString($sb.Length - 2, 2) -eq '\/') {
                    $sb.Length -= 2
                }
                [void]$sb.Append('(.+/)?')
                $i = $afterStar + 1
            }
            elseif ($hasSlashBef -and $atEnd) {
                # /** at end → keep the already-emitted / then match anything
                [void]$sb.Append('.*')
                $i = $afterStar
            }
            else {
                # standalone ** (no surrounding /)
                [void]$sb.Append('.*')
                $i = $afterStar
            }
        }
        elseif ($c -eq '*') {
            [void]$sb.Append('[^/]*')
            $i++
        }
        elseif ($c -eq '?') {
            [void]$sb.Append('[^/]')
            $i++
        }
        elseif ('.+(){}[]|^$\'.IndexOf($c) -ge 0) {
            [void]$sb.Append('\').Append($c)
            $i++
        }
        else {
            [void]$sb.Append($c)
            $i++
        }
    }
    [void]$sb.Append('$')
    return $sb.ToString()
}

function Test-PathGlob {
    <#
    .SYNOPSIS
        Test whether a path matches any glob in a list.
    .DESCRIPTION
        Path comparison is done using forward-slash, case-insensitive.
        Supports * / ** / ? glob syntax.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowEmptyString()][string]$Path,
        [Parameter(Mandatory)][AllowEmptyCollection()][string[]]$Globs
    )
    if ([string]::IsNullOrEmpty($Path) -or $null -eq $Globs -or $Globs.Count -eq 0) { return $false }
    $norm = ConvertTo-NormalizedPath -Path $Path
    foreach ($g in $Globs) {
        if ([string]::IsNullOrEmpty($g)) { continue }
        $re = ConvertTo-RegexFromGlob -Glob $g
        if ([System.Text.RegularExpressions.Regex]::IsMatch($norm, $re, 'IgnoreCase')) {
            return $true
        }
    }
    return $false
}

# -----------------------------------------------------------------------------
# Default Blocked / Allowed paths (design §3.8.6)
# -----------------------------------------------------------------------------
$Script:AutoFixDefaultBlockedPaths = @(
    'Core/DeepBase.AutoFix.*.pas',
    'scripts/autofix/**',
    '.kiro/**',
    '*.dpk',
    '*.dproj',
    '*.res',
    '*.bdsproj'
)

function Get-AutoFixDefaultBlockedPaths {
    [CmdletBinding()]
    param()
    # Comma-wrap so that a single-element list is not auto-unwrapped to a
    # scalar by PowerShell's function-output pipeline.
    return ,@($Script:AutoFixDefaultBlockedPaths)
}

# -----------------------------------------------------------------------------
# Environment resolution (design §3.8.1 / M14 auto-detection)
# -----------------------------------------------------------------------------
# Dot-source the Delphi environment auto-detection module.
. "$PSScriptRoot/delphi-env.ps1"

function Resolve-DelphiEnvBat {
    <#
    .SYNOPSIS
        Resolve the path to the Delphi environment batch file.
        Now uses auto-detection (M14) instead of a hardcoded path.
    #>
    [CmdletBinding()]
    param(
        [string]$Override,
        [string]$DelphiVersion,
        [switch]$ForceDetect
    )
    $env = Find-DelphiEnvironment -Override $Override -DelphiVersion $DelphiVersion -Force:$ForceDetect
    return $env.EnvBatPath
}

function Resolve-Pwsh {
    <#
    .SYNOPSIS
        Resolve the path to PowerShell 7 (pwsh). Throws if not found.
    #>
    [CmdletBinding()]
    param()
    $cmd = Get-Command -Name 'pwsh' -ErrorAction SilentlyContinue
    if ($null -eq $cmd) {
        throw 'pwsh (PowerShell 7) not found on PATH. Install PowerShell 7 or add it to PATH.'
    }
    return $cmd.Source
}
