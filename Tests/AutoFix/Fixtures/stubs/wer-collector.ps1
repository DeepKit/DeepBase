#requires -Version 7.0
<#
.SYNOPSIS
    Stub wer-collector.ps1 for E2E integration tests.

.DESCRIPTION
    No-op stub. The runner stub already writes runtime-errors.jsonl.
    Accepts the same parameters as the real wer-collector.ps1.
#>
param(
    [Parameter(Mandatory)][string]$ExeName,
    [Parameter(Mandatory)][int]$ProcessId,
    [Parameter(Mandatory)][int]$ExitCode,
    [Parameter(Mandatory)][string]$RunId,
    [string]$OutputDir = '',
    [string]$StartedAt = '',
    [string]$DumpsDir = '',
    [string]$CdbPath = '',
    [int]$Iteration = 0,
    [string]$Scenario = ''
)
exit 0
