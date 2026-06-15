#requires -Version 7.0

# =============================================================================
# DeepBase AutoFix - Delphi Environment Auto-Detection (M14)
# =============================================================================
# Provides:
#   - Registry-based Delphi version discovery (HKLM + WOW6432Node)
#   - Dynamic env bat generation from rsvars.bat template
#   - Cache file in $env:TEMP to avoid repeated registry lookups
#   - Support for side-by-side Delphi installations
#   - -DelphiVersion parameter for explicit version selection
#
# Registry layout (verified on this machine):
#   HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS\<BdsVersion>\
#     App         = ...\<BdsVersion>\bin\bds.exe
#     RootDir     = ...\<BdsVersion>\
#     ProductVersion = <integer compiler version>
#   Note: 64-bit PowerShell reads WOW6432Node transparently for 32-bit installs.
#
# Version mapping (BDS key -> Product name):
#   23.0 = Delphi 12.x Athens       (ProductVersion 29)
#   37.0 = Delphi 13.x Florence     (ProductVersion 37)
# =============================================================================

# Known BDS version -> human-friendly name (for logging / display)
$Script:DelphiVersionMap = @{
    '23.0' = 'Delphi 12 Athens'
    '37.0' = 'Delphi 13 Florence'
}

# Cache file lives next to autofix output; keyed by machine + user to avoid
# cross-user collisions on shared machines.
$Script:DelphiEnvCacheFileName = "delphi-env-cache-$($env:COMPUTERNAME)-$($env:USERNAME).json"

# -----------------------------------------------------------------------------
# Internal: enumerate installed Delphi versions from registry
# -----------------------------------------------------------------------------
function Get-InstalledDelphiVersions {
    <#
    .SYNOPSIS
        Scan the Windows registry for all installed Delphi/BDS versions.
        Returns an array of objects sorted newest-first by ProductVersion.
    #>
    [CmdletBinding()]
    param()

    $results = New-Object System.Collections.Generic.List[object]

    # On 64-bit Windows, Embarcadero BDS registers under WOW6432Node.
    # PowerShell's HKLM: drive transparently redirects depending on process bitness,
    # but we explicitly check both paths for robustness.
    $registryPaths = @(
        'HKLM:\SOFTWARE\Embarcadero\BDS',
        'HKLM:\SOFTWARE\WOW6432Node\Embarcadero\BDS'
    )

    $seen = New-Object System.Collections.Generic.HashSet[string]([System.StringComparer]::OrdinalIgnoreCase)

    foreach ($regPath in $registryPaths) {
        $bdsRoot = Get-Item -LiteralPath $regPath -ErrorAction SilentlyContinue
        if ($null -eq $bdsRoot) { continue }

        foreach ($subkey in $bdsRoot.GetSubKeyNames()) {
            if ($seen.Contains($subkey)) { continue }
            [void]$seen.Add($subkey)

            $fullPath = Join-Path $regPath $subkey
            try {
                $props = Get-ItemProperty -LiteralPath $fullPath -ErrorAction Stop
            } catch {
                continue
            }

            $rootDir  = if ($props.RootDir)  { [string]$props.RootDir.TrimEnd('\') } else { '' }
            $app      = if ($props.App)       { [string]$props.App } else { '' }
            $prodVer  = if ($props.ProductVersion) { [int]$props.ProductVersion } else { 0 }

            # Validate: RootDir must exist on disk
            if ([string]::IsNullOrEmpty($rootDir) -or -not (Test-Path -LiteralPath $rootDir -PathType Container)) {
                continue
            }

            $friendlyName = if ($Script:DelphiVersionMap[$subkey]) {
                $Script:DelphiVersionMap[$subkey]
            } else {
                "BDS $subkey"
            }

            # Derive rsvars.bat path
            $rsvarsPath = Join-Path $rootDir 'bin\rsvars.bat'

            # Derive MSBuild path (Delphi ships its own msbuild, but .NET Framework one also works)
            $msbuildPath = Join-Path $rootDir 'bin\msbuild.exe'

            $results.Add([pscustomobject]@{
                BdsVersion     = $subkey
                ProductVersion = $prodVer
                FriendlyName   = $friendlyName
                RootDir        = $rootDir
                AppPath        = $app
                RsvarsBatPath  = $rsvarsPath
                MsbuildPath    = $msbuildPath
                HasRsvarsBat   = (Test-Path -LiteralPath $rsvarsPath -PathType Leaf)
            }) | Out-Null
        }
    }

    # Sort by ProductVersion descending (newest first).
    # Return plain array -- do NOT comma-wrap.  The previous ,@(...) caused
    # callers using $arr = @(Get-InstalledDelphiVersions) to get a nested array
    # where $arr[0] was the entire inner array instead of a single BDS object.
    return @($results | Sort-Object -Property ProductVersion -Descending)
}

# -----------------------------------------------------------------------------
# Internal: resolve a user-supplied version specifier to a BdsVersion string
# -----------------------------------------------------------------------------
function Resolve-DelphiVersionSpecifier {
    <#
    .SYNOPSIS
        Accept flexible version input and return the matching BdsVersion string.
        Supports: "37", "37.0", "13", "13.1", "delphi-13", "florence", etc.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Spec,
        [Parameter(Mandatory)][object[]]$Installed
    )

    $normalized = $Spec.Trim().ToLowerInvariant()

    # Direct match: "23.0", "37.0"
    foreach ($inst in $Installed) {
        if ($inst.BdsVersion -eq $normalized) { return $inst.BdsVersion }
    }

    # Major-only: "37" -> "37.0", "23" -> "23.0"
    if ($normalized -match '^\d+$') {
        foreach ($inst in $Installed) {
            if ($inst.BdsVersion.StartsWith("$normalized.")) { return $inst.BdsVersion }
        }
    }

    # Delphi product version: "13" or "13.1" -> ProductVersion 37 (from known map)
    # We maintain a reverse lookup: product name version -> BdsVersion
    $productNameToBds = @{
        '12'  = '23.0'; '12.0' = '23.0'; '12.1' = '23.0'; '12.2' = '23.0'
        '13'  = '37.0'; '13.0' = '37.0'; '13.1' = '37.0'
    }
    if ($productNameToBds.ContainsKey($normalized)) {
        $target = $productNameToBds[$normalized]
        foreach ($inst in $Installed) {
            if ($inst.BdsVersion -eq $target) { return $inst.BdsVersion }
        }
    }

    # Friendly name match: "florence" -> Delphi 13 Florence -> 37.0
    foreach ($inst in $Installed) {
        $friendly = if ($inst.FriendlyName) { $inst.FriendlyName.ToLowerInvariant() } else { '' }
        if ($friendly -and $friendly.Contains($normalized)) { return $inst.BdsVersion }
    }

    return $null
}

# -----------------------------------------------------------------------------
# Internal: generate an env bat dynamically from registry + rsvars.bat template
# -----------------------------------------------------------------------------
function New-DelphiEnvBat {
    <#
    .SYNOPSIS
        Generate a temporary .bat file that sets BDS environment variables,
        either by copying the installed rsvars.bat or by synthesizing from
        registry data.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$DelphiInstall
    )

    $targetPath = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        "autofix-delphi-env-$($DelphiInstall.BdsVersion).bat"
    )

    # Strategy 1: Copy rsvars.bat if it exists (canonical, always correct)
    if ($DelphiInstall.HasRsvarsBat) {
        # Check if our cached copy is still valid (compare timestamps)
        $sourcePath = $DelphiInstall.RsvarsBatPath
        if (Test-Path -LiteralPath $targetPath -PathType Leaf) {
            $srcInfo = Get-Item -LiteralPath $sourcePath
            $dstInfo = Get-Item -LiteralPath $targetPath
            if ($dstInfo.LastWriteTimeUtc -ge $srcInfo.LastWriteTimeUtc) {
                return $targetPath  # Cached copy is fresh
            }
        }
        Copy-Item -LiteralPath $sourcePath -Destination $targetPath -Force
        return $targetPath
    }

    # Strategy 2: Synthesize from registry data
    $rootDir = $DelphiInstall.RootDir
    $bdsCommon = "C:\Users\Public\Documents\Embarcadero\Studio\$($DelphiInstall.BdsVersion)"

    $content = @"
@SET BDS=$rootDir
@SET BDSINCLUDE=$rootDir\include
@SET BDSCOMMONDIR=$bdsCommon
@SET FrameworkDir=C:\Windows\Microsoft.NET\Framework\v4.0.30319
@SET FrameworkVersion=v4.5
@SET FrameworkSDKDir=
@SET PATH=%FrameworkDir%;%FrameworkSDKDir%;$rootDir\bin;$rootDir\bin64;$rootDir\cmake;%PATH%
@SET LANGDIR=EN
@SET PLATFORM=
@SET PlatformSDK=
"@
    $enc = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText($targetPath, $content.Replace("`n", "`r`n"), $enc)
    return $targetPath
}

# -----------------------------------------------------------------------------
# Cache: persist detection results to avoid repeated registry scans
# -----------------------------------------------------------------------------
function Get-DelphiEnvCache {
    <#
    .SYNOPSIS
        Read the cached Delphi environment detection result. Returns $null if
        cache is missing, stale (> 24h), or invalid.
    #>
    [CmdletBinding()]
    param()

    $cachePath = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        $Script:DelphiEnvCacheFileName
    )

    if (-not (Test-Path -LiteralPath $cachePath -PathType Leaf)) { return $null }

    try {
        $raw = [System.IO.File]::ReadAllText($cachePath, [System.Text.UTF8Encoding]::new($false))
        $obj = $raw | ConvertFrom-Json -Depth 8 -DateKind String

        # Stale check: older than 24 hours
        if ($obj.PSObject.Properties['cached_at']) {
            $cachedAt = [datetime]::Parse($obj.cached_at)
            if (((Get-Date) - $cachedAt).TotalHours -gt 24) { return $null }
        } else {
            return $null  # Malformed cache
        }

        # Validate the cached env bat still exists
        $cachedBatPath = if ($obj.PSObject.Properties['env_bat_path']) { [string]$obj.env_bat_path } else { '' }
        if ([string]::IsNullOrEmpty($cachedBatPath) -or -not (Test-Path -LiteralPath $cachedBatPath -PathType Leaf)) {
            return $null
        }

        # Normalize cache object to match the PascalCase shape that callers expect
        return [pscustomobject]@{
            BdsVersion     = if ($obj.PSObject.Properties['bds_version'])     { [string]$obj.bds_version }     else { '' }
            ProductVersion = if ($obj.PSObject.Properties['product_version']) { [int]$obj.product_version }     else { 0 }
            FriendlyName   = if ($obj.PSObject.Properties['friendly_name'])   { [string]$obj.friendly_name }    else { '' }
            RootDir        = if ($obj.PSObject.Properties['root_dir'])        { [string]$obj.root_dir }         else { '' }
            EnvBatPath     = $cachedBatPath
        }
    } catch {
        return $null
    }
}

function Set-DelphiEnvCache {
    <#
    .SYNOPSIS
        Write the detection result to the cache file.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][object]$DelphiInstall,
        [Parameter(Mandatory)][string]$EnvBatPath
    )

    $cachePath = [System.IO.Path]::Combine(
        [System.IO.Path]::GetTempPath(),
        $Script:DelphiEnvCacheFileName
    )

    $payload = [pscustomobject]@{
        cached_at       = (Get-Date -Format 'yyyy-MM-ddTHH:mm:ss.fffzzz')
        bds_version     = $DelphiInstall.BdsVersion
        product_version = $DelphiInstall.ProductVersion
        friendly_name   = $DelphiInstall.FriendlyName
        root_dir        = $DelphiInstall.RootDir
        env_bat_path    = $EnvBatPath
    }

    $enc = [System.Text.UTF8Encoding]::new($false)
    [System.IO.File]::WriteAllText(
        $cachePath,
        ($payload | ConvertTo-Json -Depth 4 -Compress),
        $enc
    )
}

# -----------------------------------------------------------------------------
# Public API
# -----------------------------------------------------------------------------
function Find-DelphiEnvironment {
    <#
    .SYNOPSIS
        Main entry point for Delphi environment auto-detection.

        Resolution order:
          1. Explicit override (-Override / $env:AUTOFIX_DELPHI_ENV_BAT)
          2. Explicit version (-DelphiVersion)
          3. Cached detection result (< 24h old)
          4. Registry scan: pick the newest installed version

        Returns a pscustomobject with:
          BdsVersion, ProductVersion, FriendlyName, RootDir,
          EnvBatPath (path to the generated/located .bat)

    .PARAMETER Override
        Direct path to an env bat file. Bypasses all detection.

    .PARAMETER DelphiVersion
        Version specifier to select among installed versions.
        Accepts: "37", "37.0", "13", "13.1", "florence", etc.

    .PARAMETER Force
        Ignore cache and force a fresh registry scan.
    #>
    [CmdletBinding()]
    param(
        [string]$Override,
        [string]$DelphiVersion,
        [switch]$Force
    )

    # --- 1. Explicit override ---
    if ($Override) {
        if (-not (Test-Path -LiteralPath $Override -PathType Leaf)) {
            throw "Specified env bat not found: $Override"
        }
        return [pscustomobject]@{
            BdsVersion     = 'override'
            ProductVersion = 0
            FriendlyName   = 'Override'
            RootDir        = ''
            EnvBatPath     = (Resolve-Path -LiteralPath $Override).Path
            Source         = 'override'
        }
    }

    if ($env:AUTOFIX_DELPHI_ENV_BAT) {
        if (-not (Test-Path -LiteralPath $env:AUTOFIX_DELPHI_ENV_BAT -PathType Leaf)) {
            throw "AUTOFIX_DELPHI_ENV_BAT points to missing file: $env:AUTOFIX_DELPHI_ENV_BAT"
        }
        return [pscustomobject]@{
            BdsVersion     = 'env-var'
            ProductVersion = 0
            FriendlyName   = 'EnvVar'
            RootDir        = ''
            EnvBatPath     = (Resolve-Path -LiteralPath $env:AUTOFIX_DELPHI_ENV_BAT).Path
            Source         = 'env-var'
        }
    }

    # --- 2. Explicit version selector ---
    if (-not [string]::IsNullOrWhiteSpace($DelphiVersion)) {
        $installed = @(Get-InstalledDelphiVersions)
        if ($installed.Count -eq 0) {
            throw "No Delphi installations found in the Windows registry. Install Delphi or provide -EnvBat."
        }
        $matched = Resolve-DelphiVersionSpecifier -Spec $DelphiVersion -Installed $installed
        if ($null -eq $matched) {
            $available = ($installed | ForEach-Object { "$($_.BdsVersion) ($($_.FriendlyName))" }) -join ', '
            throw "Delphi version '$DelphiVersion' not found. Available: $available"
        }
        $chosen = $installed | Where-Object { $_.BdsVersion -eq $matched } | Select-Object -First 1
        $envBatPath = New-DelphiEnvBat -DelphiInstall $chosen
        # Do NOT write cache for explicit version selection -- only auto-detect results are cached.
        $chosen | Add-Member -NotePropertyName 'EnvBatPath' -NotePropertyValue $envBatPath -Force
        $chosen | Add-Member -NotePropertyName 'Source' -NotePropertyValue 'version-selector' -Force
        return $chosen
    }

    # --- 3. Cache lookup ---
    if (-not $Force) {
        $cached = Get-DelphiEnvCache
        if ($null -ne $cached) {
            # Get-DelphiEnvCache returns a clean PascalCase PSCustomObject.
            $cached | Add-Member -NotePropertyName 'Source' -NotePropertyValue 'cache' -Force
            return $cached
        }
    }

    # --- 4. Registry scan: newest first ---
    $installed = @(Get-InstalledDelphiVersions)
    if ($installed.Count -eq 0) {
        throw "No Delphi installations found in the Windows registry. Install Delphi or provide -EnvBat."
    }

    $chosen = $installed[0]  # Newest (sorted descending by ProductVersion)

    # Validate: rsvars.bat or synthesizable
    $envBatPath = New-DelphiEnvBat -DelphiInstall $chosen
    Set-DelphiEnvCache -DelphiInstall $chosen -EnvBatPath $envBatPath

    $chosen | Add-Member -NotePropertyName 'EnvBatPath' -NotePropertyValue $envBatPath -Force
    $chosen | Add-Member -NotePropertyName 'Source' -NotePropertyValue 'registry-autodetect' -Force
    return $chosen
}

# -----------------------------------------------------------------------------
# All functions are available in caller scope via dot-sourcing.
# No Export-ModuleMember needed (this file is not a .psm1 module).
# -----------------------------------------------------------------------------
