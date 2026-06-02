<#
.SYNOPSIS
    AutoFix patch cache with preimage-hash validation and git apply --check.

.DESCRIPTION
    Stores and looks up successful patch fixes keyed by error fingerprint.
    Cache entries live under <OutputDir>/.fix-cache/<sha1(key)>.json with
    schema (design §3.8.7):

        {
          "key": "...",
          "diff_patch": "<git unified diff text>",
          "preimage_files": [
              { "path": "src/foo.pas", "preimage_hash": "sha256:..." }
          ],
          "metadata": {
              "created":           "2025-...",
              "ai_backend":        "claude|openai|cli",
              "iteration_solved":  3,
              "version_solved":    "DeepBase 2.0.5"
          }
        }

    Sub-actions (Req 9.1-9.5):
        store   -Key -DiffPatch <path> -PreimageFiles <csv> -Metadata <json>
        lookup  -Key
        prune
        clear

    'lookup' is fail-closed: any of the following ⇒ entry is deleted
    and miss is returned (Property 12):
        a) created < now - MaxAgeDays (default 7)
        b) any preimage file's current SHA-256 differs from the recorded value
        c) 'git apply --check' on the stored diff fails

    On hit, the absolute path of the patch file (extracted from the cache
    entry) is written to stdout. On miss, only the literal token 'miss' is
    written.

.NOTES
    Validates Requirements 9.1, 9.2, 9.3, 9.4, 9.5 (Property 12).
#>
[CmdletBinding()]
param(
    [Parameter(Mandatory)]
    [ValidateSet('store', 'lookup', 'prune', 'clear')]
    [string]$Action,

    [string]$Key,

    [string]$DiffPatch,

    [string]$PreimageFiles,

    [string]$Metadata,

    [string]$AiBackend = 'unknown',

    [int]$IterationSolved = 0,

    [string]$VersionSolved = 'unknown',

    [string]$OutputDir = 'autofix-output',

    [int]$MaxAgeDays = 7,

    [string]$RepoRoot
)

. "$PSScriptRoot/_common.ps1"

# -----------------------------------------------------------------------------
# Helpers
# -----------------------------------------------------------------------------
function Get-CacheRoot {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Output)
    $root = Join-Path $Output '.fix-cache'
    if (-not (Test-Path -LiteralPath $root)) {
        New-Item -ItemType Directory -Path $root -Force | Out-Null
    }
    return (Resolve-Path -LiteralPath $root).Path
}

function Get-EntryPath {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$CacheRoot,
        [Parameter(Mandatory)][string]$KeyText
    )
    $hash = Get-Sha1Hex -Text $KeyText
    return (Join-Path $CacheRoot ($hash + '.json'))
}

function Assert-Param {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][AllowEmptyString()][string]$Value
    )
    if ([string]::IsNullOrWhiteSpace($Value)) {
        Write-AutoFixLog -Level error -Msg "missing required parameter -$Name" -Ctx @{ action = $Action }
        exit $Script:AutoFixExit_BadParams
    }
}

function Read-Entry {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    return (Read-JsonFile -Path $Path)
}

function Remove-Entry {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Path)
    if (Test-Path -LiteralPath $Path -PathType Leaf) {
        Remove-Item -LiteralPath $Path -Force -ErrorAction SilentlyContinue
    }
}

function Test-EntryAge {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][AllowNull()][AllowEmptyString()][string]$Created,
        [int]$MaxDays
    )
    if ([string]::IsNullOrWhiteSpace($Created)) { return $false }
    [datetime]$dt = [datetime]::MinValue
    if (-not [datetime]::TryParse($Created, [ref]$dt)) { return $false }
    return ((Get-Date) - $dt).TotalDays -lt $MaxDays
}

function Test-PreimageHashes {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]$Entry,
        [string]$Root
    )
    if (-not $Entry.PSObject.Properties['preimage_files']) { return $true }
    $files = $Entry.preimage_files
    if ($null -eq $files) { return $true }
    foreach ($f in @($files)) {
        if ($null -eq $f) { continue }
        $rel = [string]$f.path
        $stored = [string]$f.preimage_hash
        $kind = if ($f.PSObject.Properties['kind']) { [string]$f.kind } else { 'existing' }
        if ([string]::IsNullOrWhiteSpace($rel) -or [string]::IsNullOrWhiteSpace($stored)) { return $false }
        $abs = if ($Root) { Join-Path $Root $rel } else { $rel }
        if ($kind -eq 'new_file') {
            if (Test-Path -LiteralPath $abs -PathType Leaf) {
                Write-AutoFixLog -Level debug -Msg 'new-file preimage now exists' -Ctx @{ path = $abs }
                return $false
            }
            continue
        }
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            Write-AutoFixLog -Level debug -Msg 'preimage missing' -Ctx @{ path = $abs }
            return $false
        }
        $cur = 'sha256:' + (Get-Sha256File -Path $abs)
        if ($cur -ne $stored) {
            Write-AutoFixLog -Level debug -Msg 'preimage hash mismatch' -Ctx @{ path = $abs; expected = $stored; actual = $cur }
            return $false
        }
    }
    return $true
}

function Test-PatchApplies {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$PatchFile,
        [string]$Root
    )
    if (-not (Test-Path -LiteralPath $PatchFile -PathType Leaf)) { return $false }
    $oldLoc = (Get-Location).Path
    try {
        if ($Root) { Set-Location -LiteralPath $Root }
        $null = & git apply --check $PatchFile 2>&1
        return ($LASTEXITCODE -eq 0)
    }
    catch {
        return $false
    }
    finally {
        Set-Location -LiteralPath $oldLoc
    }
}

# -----------------------------------------------------------------------------
# Action handlers
# -----------------------------------------------------------------------------
function Invoke-StoreAction {
    Assert-Param -Name 'Key'        -Value $Key
    Assert-Param -Name 'DiffPatch'  -Value $DiffPatch

    if (-not (Test-Path -LiteralPath $DiffPatch -PathType Leaf)) {
        throw "diff patch file not found: $DiffPatch"
    }

    # Parse preimage list (semicolon or comma separated relative paths)
    $rawList = @()
    if ($PreimageFiles) {
        $rawList = $PreimageFiles -split '[;,]' | ForEach-Object { $_.Trim() } | Where-Object { $_ }
    }

    $cacheRoot = Get-CacheRoot -Output (Resolve-OutputDir -Path $OutputDir)
    $entryPath = Get-EntryPath -CacheRoot $cacheRoot -KeyText $Key

    $resolvedRoot = if ($RepoRoot) { (Resolve-Path -LiteralPath $RepoRoot).Path } else { (Get-Location).Path }
    $preimage = New-Object System.Collections.Generic.List[object]
    foreach ($rel in $rawList) {
        $abs = if ([System.IO.Path]::IsPathRooted($rel)) { $rel } else { Join-Path $resolvedRoot $rel }
        if (-not (Test-Path -LiteralPath $abs -PathType Leaf)) {
            $preimage.Add([pscustomobject]@{
                path          = $rel
                kind          = 'new_file'
                preimage_hash = 'absent'
            }) | Out-Null
            continue
        }
        $preimage.Add([pscustomobject]@{
            path          = $rel
            kind          = 'existing'
            preimage_hash = 'sha256:' + (Get-Sha256File -Path $abs)
        }) | Out-Null
    }

    # Copy the patch text into the entry so the cache is self-contained.
    $patchText = [System.IO.File]::ReadAllText($DiffPatch, [System.Text.UTF8Encoding]::new($false))

    # Allow caller-supplied JSON metadata to override the structured fields.
    $metaObj = [pscustomobject]@{
        created          = Get-AutoFixTimestamp
        ai_backend       = $AiBackend
        iteration_solved = $IterationSolved
        version_solved   = $VersionSolved
    }
    if ($Metadata) {
        try {
            $extra = $Metadata | ConvertFrom-Json -Depth 16 -DateKind String
            foreach ($prop in $extra.PSObject.Properties) {
                $metaObj | Add-Member -NotePropertyName $prop.Name -NotePropertyValue $prop.Value -Force
            }
        } catch {
            Write-AutoFixLog -Level warn -Msg 'failed to parse -Metadata, using defaults' -Ctx @{ error = $_.Exception.Message }
        }
    }

    $entry = [pscustomobject]@{
        key            = $Key
        diff_patch     = $patchText
        preimage_files = @($preimage.ToArray())
        metadata       = $metaObj
    }
    Write-JsonFile -Path $entryPath -Object $entry
    Write-AutoFixLog -Level info -Msg 'stored cache entry' -Ctx @{ path = $entryPath; preimages = $preimage.Count }
    [Console]::Out.WriteLine($entryPath)
}

function Invoke-LookupAction {
    Assert-Param -Name 'Key' -Value $Key

    $cacheRoot = Get-CacheRoot -Output (Resolve-OutputDir -Path $OutputDir)
    $entryPath = Get-EntryPath -CacheRoot $cacheRoot -KeyText $Key

    if (-not (Test-Path -LiteralPath $entryPath -PathType Leaf)) {
        Write-AutoFixLog -Level debug -Msg 'lookup miss (no entry)' -Ctx @{ key = $Key }
        [Console]::Out.WriteLine('miss')
        exit $Script:AutoFixExit_Ok
    }

    $entry = Read-Entry -Path $entryPath

    # (a) age check
    $created = if ($entry.metadata -and $entry.metadata.PSObject.Properties['created']) { [string]$entry.metadata.created } else { '' }
    if (-not (Test-EntryAge -Created $created -MaxDays $MaxAgeDays)) {
        Remove-Entry -Path $entryPath
        Write-AutoFixLog -Level info -Msg 'lookup miss (expired)' -Ctx @{ key = $Key; created = $created }
        [Console]::Out.WriteLine('miss')
        exit $Script:AutoFixExit_Ok
    }

    $resolvedRoot = if ($RepoRoot) { (Resolve-Path -LiteralPath $RepoRoot).Path } else { (Get-Location).Path }

    # (b) preimage hash check
    if (-not (Test-PreimageHashes -Entry $entry -Root $resolvedRoot)) {
        Remove-Entry -Path $entryPath
        Write-AutoFixLog -Level info -Msg 'lookup miss (preimage drift)' -Ctx @{ key = $Key }
        [Console]::Out.WriteLine('miss')
        exit $Script:AutoFixExit_Ok
    }

    # (c) git apply --check — write patch to a sidecar file and verify
    $patchSidecar = [System.IO.Path]::ChangeExtension($entryPath, '.patch')
    Write-Utf8NoBom -Path $patchSidecar -Content ([string]$entry.diff_patch)
    if (-not (Test-PatchApplies -PatchFile $patchSidecar -Root $resolvedRoot)) {
        Remove-Entry -Path $entryPath
        Remove-Item -LiteralPath $patchSidecar -Force -ErrorAction SilentlyContinue
        Write-AutoFixLog -Level info -Msg 'lookup miss (git apply --check failed)' -Ctx @{ key = $Key }
        [Console]::Out.WriteLine('miss')
        exit $Script:AutoFixExit_Ok
    }

    Write-AutoFixLog -Level info -Msg 'lookup hit' -Ctx @{ key = $Key; patch = $patchSidecar }
    [Console]::Out.WriteLine($patchSidecar)
}

function Invoke-PruneAction {
    $outDir = Resolve-OutputDir -Path $OutputDir
    $cacheRoot = Get-CacheRoot -Output $outDir
    $entries = Get-ChildItem -LiteralPath $cacheRoot -Filter '*.json' -File -ErrorAction SilentlyContinue
    $removed = 0
    foreach ($file in $entries) {
        try {
            $entry = Read-Entry -Path $file.FullName
            $created = if ($entry.metadata -and $entry.metadata.PSObject.Properties['created']) { [string]$entry.metadata.created } else { '' }
            if (-not (Test-EntryAge -Created $created -MaxDays $MaxAgeDays)) {
                Remove-Entry -Path $file.FullName
                $sidecar = [System.IO.Path]::ChangeExtension($file.FullName, '.patch')
                Remove-Item -LiteralPath $sidecar -Force -ErrorAction SilentlyContinue
                $removed++
            }
        } catch {
            Write-AutoFixLog -Level warn -Msg 'failed reading entry; removing' -Ctx @{ path = $file.FullName; error = $_.Exception.Message }
            Remove-Entry -Path $file.FullName
            $removed++
        }
    }
    Write-AutoFixLog -Level info -Msg 'cache pruned' -Ctx @{ removed = $removed; root = $cacheRoot }
    [Console]::Out.WriteLine("pruned=$removed")
}

function Invoke-ClearAction {
    $outDir = Resolve-OutputDir -Path $OutputDir
    $cacheRoot = Join-Path $outDir '.fix-cache'
    if (Test-Path -LiteralPath $cacheRoot) {
        Remove-Item -LiteralPath $cacheRoot -Recurse -Force
        Write-AutoFixLog -Level info -Msg 'cache cleared' -Ctx @{ root = $cacheRoot }
    }
    [Console]::Out.WriteLine('cleared')
}

# -----------------------------------------------------------------------------
# Main
# -----------------------------------------------------------------------------
try {
    switch ($Action) {
        'store'  { Invoke-StoreAction }
        'lookup' { Invoke-LookupAction }
        'prune'  { Invoke-PruneAction }
        'clear'  { Invoke-ClearAction }
    }
    exit $Script:AutoFixExit_Ok
}
catch {
    Write-AutoFixLog -Level error -Msg $_.Exception.Message -Ctx @{ script = 'fix-cache.ps1'; action = $Action }
    exit $Script:AutoFixExit_Generic
}
