#requires -Version 7.0
<#
.SYNOPSIS
    Stub git-checkpoint.ps1 for E2E integration tests.

.DESCRIPTION
    Simulates worktree operations without touching real git.

    On 'create', if STUB_GIT_REPO_ROOT is set, copies tracked files from the
    repo root into the worktree so that project paths resolve correctly.

    Actions:
        create  : Creates the worktree directory, copies repo files, prints path on stdout.
        commit  : Writes a marker file in the worktree. Exits 0.
        discard : Removes the worktree directory. Exits 0.
        cleanup : Removes the worktree directory. Exits 0.

    Env vars:
        STUB_GIT_REPO_ROOT : Path to the test git repo whose files should be
                              mirrored into the worktree.
#>
param(
    [Parameter(Mandatory)][string]$Action,
    [string]$Branch = '',
    [string]$WorktreePath = '',
    [string]$Message = ''
)

switch ($Action) {
    'create' {
        $wt = $WorktreePath
        if (-not $wt) {
            $wt = Join-Path ([System.IO.Path]::GetTempPath()) ("stub-wt-" + [guid]::NewGuid().ToString('N').Substring(0,8))
        }
        if (-not (Test-Path -LiteralPath $wt)) {
            New-Item -ItemType Directory -Path $wt -Force | Out-Null
        }

        # Mirror files from the repo root so project paths resolve in the worktree
        $repoRoot = $env:STUB_GIT_REPO_ROOT
        if ($repoRoot -and (Test-Path -LiteralPath $repoRoot -PathType Container)) {
            # Copy all files (including subdirectories) except .git
            Get-ChildItem -LiteralPath $repoRoot -Recurse -File | Where-Object {
                $_.FullName -notmatch '[\\/]\.git([\\/]|$)'
            } | ForEach-Object {
                $rel = $_.FullName.Substring($repoRoot.Length).TrimStart('\', '/')
                $dest = Join-Path $wt $rel
                $destDir = Split-Path -Parent $dest
                if ($destDir -and -not (Test-Path -LiteralPath $destDir)) {
                    New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                }
                Copy-Item -LiteralPath $_.FullName -Destination $dest -Force
            }
        }

        Write-Output $wt
        exit 0
    }
    'commit' {
        if ($WorktreePath -and (Test-Path -LiteralPath $WorktreePath -PathType Container)) {
            $marker = Join-Path $WorktreePath '.stub-commit'
            Set-Content -LiteralPath $marker -Value $Message -Encoding UTF8
        }
        exit 0
    }
    { $_ -in 'discard', 'cleanup' } {
        if ($WorktreePath -and (Test-Path -LiteralPath $WorktreePath -PathType Container)) {
            Remove-Item -LiteralPath $WorktreePath -Recurse -Force -ErrorAction SilentlyContinue
        }
        exit 0
    }
    default {
        [Console]::Error.WriteLine("stub git-checkpoint: unknown action '$Action'")
        exit 1
    }
}
