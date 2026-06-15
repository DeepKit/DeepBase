#requires -Version 7.0
<#
.SYNOPSIS
    Stub diff-guard.ps1 for E2E integration tests.

.DESCRIPTION
    Always accepts the diff (exits 0).
#>
param(
    [string]$DiffFile = '',
    [string]$OutputDir = '',
    [int]$MaxDiffLines = 200,
    [int]$MaxChangedFiles = 0,
    [string]$AllowedPaths = '',
    [string]$AllowedPathsFile = '',
    [string]$BlockedPaths = '',
    [string]$BlockedPathsFile = ''
)
exit 0
