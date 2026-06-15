#requires -Version 7.0
<#
.SYNOPSIS
    Stub fix-cache.ps1 for E2E integration tests.

.DESCRIPTION
    Always reports 'miss' on lookup, exits 0 on store.
#>
param(
    [Parameter(Mandatory)][string]$Action,
    [string]$Key = '',
    [string]$DiffPatch = '',
    [string]$PreimageFiles = '',
    [string]$AiBackend = '',
    [int]$IterationSolved = 0,
    [string]$OutputDir = '',
    [string]$RepoRoot = ''
)

switch ($Action) {
    'lookup' {
        Write-Output 'miss'
        exit 0
    }
    'store' {
        exit 0
    }
    default {
        [Console]::Error.WriteLine("stub fix-cache: unknown action '$Action'")
        exit 1
    }
}
