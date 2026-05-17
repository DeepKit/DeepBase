#requires -Version 7.0
# Feature: autofix-runtime-errors, Property 12: Fix_Cache 失败即作废
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/fix-cache.Tests.ps1
#
# Validates Requirements 9.1, 9.2, 9.3, 9.4, 9.5 — design v2.0 §5.1 Property 12.
#
# NOTE: Each iteration uses a fresh temp git repo as -RepoRoot so 'git apply --check'
# can validate stored patches against a real index. The test never touches the
# host repository.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts\autofix\fix-cache.ps1'
    $script:CommonPath = Join-Path $script:RepoRoot 'scripts\autofix\_common.ps1'
    if (-not (Test-Path -LiteralPath $script:ScriptPath -PathType Leaf)) {
        throw "fix-cache.ps1 not found at: $script:ScriptPath"
    }
    . $script:CommonPath

    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-fc-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    function script:Invoke-Git {
        param([string]$Cwd, [string[]]$ChildArgs)
        $oldLoc = (Get-Location).Path
        try {
            Set-Location -LiteralPath $Cwd
            $null = & git @ChildArgs 2>&1
            return $LASTEXITCODE
        } finally {
            Set-Location -LiteralPath $oldLoc
        }
    }

    function script:New-FixtureRepo {
        <#
        .SYNOPSIS
            Build an isolated git repo containing a single .pas file with two
            functions, then craft a one-line patch that adds a comment and the
            ground-truth pre-image SHA. Returns paths the test will need.
        #>
        param([int]$Seed)

        $rng = [System.Random]::new($Seed)
        $repoDir = Join-Path $script:TmpRoot ("repo-{0}" -f $Seed)
        New-Item -ItemType Directory -Path $repoDir -Force | Out-Null

        # Initialise the repo (quiet) and force a known identity so that
        # future commits do not need user-level git config.
        Invoke-Git -Cwd $repoDir -ChildArgs @('init', '-q', '-b', 'main') | Out-Null
        Invoke-Git -Cwd $repoDir -ChildArgs @('config', 'user.email', 'autofix@test.local') | Out-Null
        Invoke-Git -Cwd $repoDir -ChildArgs @('config', 'user.name',  'AutoFix Test') | Out-Null
        Invoke-Git -Cwd $repoDir -ChildArgs @('config', 'core.autocrlf', 'false') | Out-Null

        $rel = ('src/sample-{0}.pas' -f $Seed)
        $abs = Join-Path $repoDir $rel
        New-Item -ItemType Directory -Path (Split-Path -Parent $abs) -Force | Out-Null

        $payload = ("unit Sample{0};" + [Environment]::NewLine + `
                    "interface" + [Environment]::NewLine + `
                    "implementation" + [Environment]::NewLine + `
                    "// original line" + [Environment]::NewLine + `
                    "end." + [Environment]::NewLine) -f $Seed
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($abs, $payload, $enc)

        Invoke-Git -Cwd $repoDir -ChildArgs @('add', $rel) | Out-Null
        Invoke-Git -Cwd $repoDir -ChildArgs @('commit', '-q', '-m', 'init') | Out-Null

        # Build a deterministic minimal unified diff that 'git apply --check'
        # will accept against the freshly-committed file.
        $relForGit = $rel.Replace('\', '/')
        $diffText = ("diff --git a/{0} b/{0}" + [Environment]::NewLine + `
                     "--- a/{0}" + [Environment]::NewLine + `
                     "+++ b/{0}" + [Environment]::NewLine + `
                     "@@ -2,3 +2,4 @@" + [Environment]::NewLine + `
                     " interface" + [Environment]::NewLine + `
                     " implementation" + [Environment]::NewLine + `
                     "+// patched line" + [Environment]::NewLine + `
                     " // original line" + [Environment]::NewLine) -f $relForGit

        $patchPath = Join-Path $repoDir ("patch-{0}.diff" -f $Seed)
        [System.IO.File]::WriteAllText($patchPath, $diffText, $enc)

        return @{
            RepoDir       = $repoDir
            RelPath       = $rel
            AbsPath       = $abs
            DiffPath      = $patchPath
            OutputDir     = (Join-Path $repoDir 'autofix-output')
            Key           = ('test-key-{0}' -f $Seed)
            OriginalText  = $payload
        }
    }

    function script:Invoke-Cache {
        param([string[]]$ChildArgs)
        $stdout = & pwsh -NoProfile -NoLogo -NonInteractive -File $script:ScriptPath @ChildArgs 2>$null
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Stdout   = ($stdout | Out-String).Trim()
        }
    }

    function script:Get-CacheEntryPath {
        param([string]$OutputDir, [string]$Key)
        $hash = Get-Sha1Hex -Text $Key
        return (Join-Path $OutputDir ('.fix-cache/' + $hash + '.json'))
    }
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'fix-cache.ps1 — fail-closed lookup invalidation' {

    Context 'Property 12: lookup miss + entry deletion under each failure mode' {

        It 'invalidates entries when preimage drifts, expires, or git apply --check fails' {
            $iterations = 100
            $rng = [System.Random]::new(91138)
            for ($i = 0; $i -lt $iterations; $i++) {
                $fx = New-FixtureRepo -Seed ($i + 1)

                # Store the entry — happy path baseline.
                $store = Invoke-Cache -ChildArgs @(
                    '-Action', 'store',
                    '-Key', $fx.Key,
                    '-DiffPatch', $fx.DiffPath,
                    '-PreimageFiles', $fx.RelPath,
                    '-OutputDir', $fx.OutputDir,
                    '-RepoRoot', $fx.RepoDir
                )
                $store.ExitCode | Should -Be 0
                $entryPath = Get-CacheEntryPath -OutputDir $fx.OutputDir -Key $fx.Key
                Test-Path -LiteralPath $entryPath -PathType Leaf | Should -BeTrue

                # Pick one of three failure modes for this iteration.
                $mode = $rng.Next(0, 3)
                switch ($mode) {
                    0 {
                        # (a) Mutate the pre-image file → SHA mismatch
                        $enc = [System.Text.UTF8Encoding]::new($false)
                        [System.IO.File]::WriteAllText($fx.AbsPath, $fx.OriginalText + "// drift" + [Environment]::NewLine, $enc)
                    }
                    1 {
                        # (b) Backdate 'created' to 8 days ago → expiry
                        $entry = Get-Content -LiteralPath $entryPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 32
                        $entry.metadata.created = (Get-Date).AddDays(-8).ToString('o')
                        $entry | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $entryPath -Encoding utf8
                    }
                    2 {
                        # (c) Corrupt the stored patch text → git apply --check rejects
                        $entry = Get-Content -LiteralPath $entryPath -Raw -Encoding utf8 | ConvertFrom-Json -Depth 32
                        $entry.diff_patch = "diff --git a/garbage b/garbage`n--- a/garbage`n+++ b/garbage`n@@ -1,1 +1,1 @@`n-no such line`n+replacement`n"
                        $entry | ConvertTo-Json -Depth 32 | Set-Content -LiteralPath $entryPath -Encoding utf8
                    }
                }

                # Lookup must report miss + the entry must have been removed.
                $look = Invoke-Cache -ChildArgs @(
                    '-Action', 'lookup',
                    '-Key', $fx.Key,
                    '-OutputDir', $fx.OutputDir,
                    '-RepoRoot', $fx.RepoDir
                )
                $look.ExitCode | Should -Be 0
                $look.Stdout   | Should -Be 'miss'
                Test-Path -LiteralPath $entryPath -PathType Leaf | Should -BeFalse

                # Subsequent lookup is also a miss (idempotent failure).
                $look2 = Invoke-Cache -ChildArgs @(
                    '-Action', 'lookup',
                    '-Key', $fx.Key,
                    '-OutputDir', $fx.OutputDir,
                    '-RepoRoot', $fx.RepoDir
                )
                $look2.ExitCode | Should -Be 0
                $look2.Stdout   | Should -Be 'miss'
            }
        }
    }
}
