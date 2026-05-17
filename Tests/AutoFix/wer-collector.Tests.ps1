#requires -Version 7.0
# Feature: autofix-runtime-errors, Property 17: WER/合成记录保底
#
# Pester 5 is required. If Get-Module -ListAvailable Pester reports < 5, run:
#     Install-Module Pester -MinimumVersion 5.0.0 -Force -SkipPublisherCheck
#
# Run with:
#     Invoke-Pester -Path Tests/AutoFix/wer-collector.Tests.ps1
#
# Validates Requirements 13.1, 13.3 — design v2.0 §5.1 Property 17.
#
# NOTE: cdb.exe is mocked by passing -CdbPath pointing at a fake script that
# emits the canonical '!analyze -v' fields. CrashDumps directory is also
# pointed at a fixture path so no real WER state is touched.

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

BeforeAll {
    $script:RepoRoot   = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot '..\..')).Path
    $script:ScriptPath = Join-Path $script:RepoRoot 'scripts\autofix\wer-collector.ps1'
    if (-not (Test-Path -LiteralPath $script:ScriptPath -PathType Leaf)) {
        throw "wer-collector.ps1 not found at: $script:ScriptPath"
    }

    $script:TmpRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("autofix-wer-" + [guid]::NewGuid().ToString('N').Substring(0, 8))
    New-Item -ItemType Directory -Path $script:TmpRoot -Force | Out-Null

    function script:New-FakeCdb {
        <#
        .SYNOPSIS
            Build a fake cdb.exe replacement (a .cmd batch) that prints the
            !analyze -v fields wer-collector.ps1 expects to extract. The
            generated script always exits 0.
        #>
        param([Parameter(Mandatory)][string]$Dir, [Parameter(Mandatory)][string]$ExceptionCode, [Parameter(Mandatory)][string]$ExceptionAddr, [Parameter(Mandatory)][string]$ModuleName)
        $batPath = Join-Path $Dir ("fake-cdb-" + [guid]::NewGuid().ToString('N').Substring(0,6) + ".cmd")
        $body = @(
            '@echo off',
            ('echo ExceptionCode: '    + $ExceptionCode),
            ('echo ExceptionAddress: ' + $ExceptionAddr),
            ('echo MODULE_NAME: '      + $ModuleName),
            'echo FAULTING_IP:',
            'echo Module!Func     0x00401234 Module!Func+0x10',
            'exit /b 0'
        ) -join [Environment]::NewLine
        $enc = [System.Text.UTF8Encoding]::new($false)
        [System.IO.File]::WriteAllText($batPath, $body, $enc)
        return $batPath
    }

    function script:New-FakeDump {
        <#
        .SYNOPSIS
            Touch a zero-byte .dmp at the documented location so the
            collector's discovery logic finds it.
        #>
        param([string]$Dir, [string]$ExeName, [int]$ProcId)
        New-Item -ItemType Directory -Path $Dir -Force | Out-Null
        $stem = if ($ExeName.ToLowerInvariant().EndsWith('.exe')) { $ExeName.Substring(0, $ExeName.Length - 4) } else { $ExeName }
        $dump = Join-Path $Dir ("$stem.$ProcId.dmp")
        Set-Content -LiteralPath $dump -Value '' -Encoding utf8 -NoNewline
        return $dump
    }

    function script:Invoke-Wer {
        param(
            [Parameter(Mandatory)][string]$ExeName,
            [Parameter(Mandatory)][int]$ProcessId,
            [Parameter(Mandatory)][int]$ExitCode,
            [Parameter(Mandatory)][string]$RunId,
            [Parameter(Mandatory)][string]$OutputDir,
            [Parameter(Mandatory)][string]$DumpsDir,
            [string]$CdbPath,
            [string]$Scenario = 'scan'
        )
        $args = @(
            '-ExeName', $ExeName,
            '-ProcessId', $ProcessId,
            '-ExitCode', $ExitCode,
            '-RunId', $RunId,
            '-OutputDir', $OutputDir,
            '-DumpsDir', $DumpsDir,
            '-Scenario', $Scenario
        )
        if ($CdbPath) { $args += @('-CdbPath', $CdbPath) }
        $null = & pwsh -NoProfile -NoLogo -NonInteractive -File $script:ScriptPath @args 2>$null
        return $LASTEXITCODE
    }
}

AfterAll {
    if ($script:TmpRoot -and (Test-Path -LiteralPath $script:TmpRoot)) {
        Remove-Item -LiteralPath $script:TmpRoot -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Describe 'wer-collector.ps1 — synthetic record fallback' {

    Context 'Property 17: at least one record always lands in jsonl' {

        It 'emits a HardCrash or WerExtracted record across 100 random scenarios' {
            $iterations = 100
            $rng = [System.Random]::new(424242)
            $exitCodes = @(-1, -1073741819, -1073740940, 1, 2, 3, 7, 137)

            for ($i = 0; $i -lt $iterations; $i++) {
                $scenarioName = ('scen' + ($rng.Next(1, 9999)))
                $exeName  = ('Harness-{0}.exe' -f $i)
                $procId   = $rng.Next(1000, 99999)
                $exitCode = $exitCodes[$rng.Next(0, $exitCodes.Count)]
                $runId    = ([guid]::NewGuid().ToString())

                $iterDir   = Join-Path $script:TmpRoot ("iter-{0}" -f $i)
                $outDir    = Join-Path $iterDir 'out'
                $dumpsDir  = Join-Path $iterDir 'dumps'
                New-Item -ItemType Directory -Path $outDir -Force | Out-Null
                New-Item -ItemType Directory -Path $dumpsDir -Force | Out-Null

                # Coin-flip: with probability 0.5 we plant a fake dump, and
                # half of those iterations also wire up a fake cdb.exe so the
                # WerExtracted code path is exercised.
                $hasDump = ($rng.Next(0, 2) -eq 1)
                $cdb     = $null
                if ($hasDump) {
                    $null = New-FakeDump -Dir $dumpsDir -ExeName $exeName -ProcId $procId
                    if ($rng.Next(0, 2) -eq 1) {
                        $cdb = New-FakeCdb -Dir $iterDir `
                            -ExceptionCode '0xC0000005' `
                            -ExceptionAddr '0x00007FFE12345678' `
                            -ModuleName    $exeName
                    }
                }

                $rc = Invoke-Wer -ExeName $exeName -ProcessId $procId -ExitCode $exitCode `
                    -RunId $runId -OutputDir $outDir -DumpsDir $dumpsDir -CdbPath $cdb `
                    -Scenario $scenarioName
                $rc | Should -Be 0

                $jsonl = Join-Path $outDir 'runtime-errors.jsonl'
                Test-Path -LiteralPath $jsonl -PathType Leaf | Should -BeTrue
                $rows = @(Get-Content -LiteralPath $jsonl -Encoding utf8 |
                          Where-Object { $_.Trim() } |
                          ForEach-Object { $_ | ConvertFrom-Json -Depth 12 })
                $rows.Count | Should -BeGreaterOrEqual 1

                $rec = $rows[0]
                # class ∈ {HardCrash, WerExtracted}
                [string]$rec.'class' | Should -BeIn @('HardCrash', 'WerExtracted')
                # exit_code matches what we passed in
                [int]$rec.exit_code  | Should -Be $exitCode
                # run_id matches
                [string]$rec.run_id  | Should -Be $runId
                # scenario propagated
                [string]$rec.scenario | Should -Be $scenarioName
                # required fields present
                foreach ($f in @('ts','level','class','msg','module_name','module_base','rva','stack','dedup_key','exit_code','run_id','scenario')) {
                    $rec.PSObject.Properties[$f] | Should -Not -BeNullOrEmpty
                }
            }
        }
    }
}
