#!/usr/bin/env python3
# -*- coding: utf-8 -*-
# WO-20261003-MC-甲-ORPHANREG 判据8: negative controls (ASCII evidence only).
#
# Each control materializes a dpr into a scratch dir OUTSIDE the repo, then compiles it with the
# same dcc64 recipe as the 22-unit probes. A control that stays green proves the registration
# mechanism does NOT guard what the work order assumed - reported honestly, not hidden.
#
#   NC1  misspelled unit name in `uses`                     -> expect BUILD_EXIT!=0
#   NC2  `uses` line WITHOUT the `in 'Regression\X.pas'` clause, compiled with the DPROJ search
#        path (DeepBaseTests.dproj DCC_UnitSearchPath has no Tests\Regression) -> expect red
#   NC3  same dpr as NC2 but compiled with the run_tests.ps1 search path (-U DOES include
#        Tests\Regression) -> documented honestly: GREEN, the `in` clause is redundant there
#   NC4  `in 'Regression/Test.X.pas'`  (forward slash instead of backslash)
#   NC5  `in 'Test.X.pas'`             (Tests\ prefix dropped)
import os, subprocess, sys, io

ROOT = r'D:\_ProgData\DeepBase-ORPHANREG\wt-orphanreg'
OUT = r'D:\_ProgData\DeepBase-ORPHANREG\nc'
BDS = r'D:\Program Files (x86)\Embarcadero\Studio\37.0'
DCC = os.path.join(BDS, 'bin', 'dcc64.exe')
DUNITX = 'D:/ProgramData/delphi/DUnitX/Source'
BS = chr(92)
NL = chr(13) + chr(10)
UNIT = 'Test.Regression.BUG033_WeakEncryption'

U_DPROJ = ';'.join([ROOT + BS + 'Persistence', ROOT + BS + 'Core', ROOT + BS + 'Features',
                    ROOT + BS + 'Governance', ROOT + BS + 'VCL', ROOT + BS + 'FMX',
                    ROOT + BS + 'ThirdParty' + BS + 'Social', ROOT + BS + 'ThirdParty' + BS + 'Payment',
                    ROOT + BS + 'Tools' + BS + 'CLI', ROOT + BS + 'Tools' + BS + 'WebService',
                    ROOT + BS + 'DeepFlow' + BS + 'Source' + BS + 'Core',
                    ROOT + BS + 'DeepFlow' + BS + 'Source' + BS + 'Roles',
                    ROOT + BS + 'DeepFlow' + BS + 'Source' + BS + 'Workflow',
                    ROOT + BS + 'DeepFlow' + BS + 'Source' + BS + 'AI',
                    ROOT + BS + 'doQry', BDS + BS + 'lib' + BS + 'Win64' + BS + 'release', DUNITX])
U_RUNNER = ';'.join([ROOT + BS + 'Core', ROOT + BS + 'Features', ROOT + BS + 'Persistence',
                     ROOT + BS + 'VCL', ROOT + BS + 'FMX', ROOT + BS + 'Governance',
                     ROOT + BS + 'doQry', ROOT + BS + 'ThirdParty' + BS + 'Payment',
                     ROOT + BS + 'ThirdParty' + BS + 'Social', ROOT + BS + 'Tools' + BS + 'CLI',
                     ROOT + BS + 'Tools' + BS + 'WebService', ROOT + BS + 'Tests',
                     ROOT + BS + 'Tests' + BS + 'Regression', ROOT + BS + 'Tests' + BS + 'Integration',
                     BDS + BS + 'lib' + BS + 'Win64' + BS + 'release', DUNITX])
NS = ';'.join(['System', 'Vcl', 'Vcl.Imaging', 'Vcl.Touch', 'Vcl.Shell', 'Data', 'FireDAC',
               'FireDAC.Comp', 'FireDAC.DApt', 'FireDAC.Stan', 'Xml', 'Web', 'Soap', 'Winapi',
               'System.Win'])

TPL = NL.join([
    'program NCCtl;',
    '',
    '{$APPTYPE CONSOLE}',
    '',
    'uses',
    '  System.SysUtils,',
    '  DUnitX.TestFramework,',
    '  DUnitX.Loggers.Console,',
    '  __USES__;',
    '',
    'begin',
    '  ReportMemoryLeaksOnShutdown := False;',
    '  TDUnitX.CheckCommandLine;',
    '  var LRunner := TDUnitX.CreateRunner;',
    '  LRunner.UseRTTI := True;',
    '  LRunner.FailsOnNoAsserts := False;',
    '  LRunner.AddLogger(TDUnitXConsoleLogger.Create(True));',
    '  var LResults := LRunner.Execute;',
    '  Writeln(Format(' + chr(39) + 'RUNNER_STATS found=%d pass=%d fail=%d err=%d' + chr(39) + ',',
    '    [LResults.TestCount, LResults.PassCount, LResults.FailureCount, LResults.ErrorCount]));',
    '  if LResults.TestCount = 0 then begin Writeln(' + chr(39) + 'RUNNER_VERDICT: NO_TEST_EXECUTED' + chr(39) + '); System.ExitCode := 2; Exit; end;',
    '  if not LResults.AllPassed then begin Writeln(' + chr(39) + 'RUNNER_VERDICT: FAILED' + chr(39) + '); System.ExitCode := 1; Exit; end;',
    '  Writeln(' + chr(39) + 'RUNNER_VERDICT: PASSED' + chr(39) + ');',
    'end.',
    '',
])

PASFILE = 'Test.' + UNIT.split('Test.', 1)[1] + '.pas'  # Test.Regression.BUG033_... .pas

CASES = [
    # name, uses-line, search-path key, expectation note
    ('NC1_typo_unit_name', UNIT[:-1] + " in 'Regression" + BS + PASFILE + "'", 'runner',
     'misspelled unit name (last char dropped)'),
    ('NC2_no_in_clause_dproj_path', UNIT, 'dproj',
     "no `in 'Regression\\X.pas'` clause + dproj search path (no Tests\\Regression)"),
    ('NC3_no_in_clause_runner_path', UNIT, 'runner',
     "no `in 'Regression\\X.pas'` clause + run_tests.ps1 search path (has Tests\\Regression)"),
    ('NC4_forward_slash_sep', UNIT + " in 'Regression/" + PASFILE + "'", 'runner',
     "in-clause path separator is '/'"),
    ('NC5_tests_prefix_dropped', UNIT + " in '" + PASFILE + "'", 'runner',
     "in-clause dropped the 'Regression" + BS + "' prefix"),
    ('NC6_forward_slash_dproj_path', UNIT + " in 'Regression/" + PASFILE + "'", 'dproj',
     "in-clause separator '/' + dproj search path (no Tests\Regression)"),
    ('NC7_tests_prefix_dropped_dproj_path', UNIT + " in '" + PASFILE + "'", 'dproj',
     "in-clause dropped 'Regression\' prefix + dproj search path"),
]

env = dict(os.environ)
env['MSYS_NO_PATHCONV'] = '1'
env['MSYS2_ARG_CONV_EXCL'] = '*'

rows = []
for name, uses, spkey, note in CASES:
    d = os.path.join(OUT, name)
    os.makedirs(d, exist_ok=True)
    dpr = os.path.join(d, 'NCCtl.dpr')
    os.makedirs(os.path.join(d, 'dcu'), exist_ok=True)
    with io.open(dpr, 'wb') as fh:
        fh.write(TPL.replace('__USES__', uses).encode('utf-8'))
    u = U_DPROJ if spkey == 'dproj' else U_RUNNER
    clog = os.path.join(d, 'compile.log')
    with io.open(clog, 'wb') as out:
        p = subprocess.Popen([DCC, '-U' + u, '-NS' + NS, '-N0' + os.path.join(d, 'dcu'),
                              '-Q', '-B', '-DDEBUG', dpr],
                             cwd=os.path.join(ROOT, 'Tests'), stdout=out, stderr=subprocess.STDOUT,
                             env=env, shell=False)
        p.wait()
    rc = p.returncode
    log = io.open(clog, encoding='utf-8', errors='replace').read()
    errs = [l.strip() for l in log.splitlines() if ('Error' in l or 'Fatal' in l) and 'Hint' not in l]
    exepath = os.path.join(d, 'NCCtl.exe')  # dcc64 writes the exe next to the dpr
    runrc = ''
    if rc == 0 and os.path.isfile(exepath):
        rlog = os.path.join(d, 'run.log')
        with io.open(rlog, 'wb') as out:
            p2 = subprocess.Popen([exepath, '--exitbehavior:Continue'], cwd=os.path.join(ROOT, 'Tests'),
                                  stdout=out, stderr=subprocess.STDOUT, env=env, shell=False)
            p2.wait()
        runrc = p2.returncode
    rows.append((name, spkey, rc, runrc, note, '; '.join(errs)[:200]))

with io.open(os.path.join(OUT, '_nc-summary.tsv'), 'w', encoding='utf-8', newline='\n') as fh:
    fh.write('control\tsearch_path\tBUILD_EXIT\tRUN_EXIT\tnote\tfirst_error\n')
    for r in rows:
        fh.write('\t'.join(str(x) for x in r) + '\n')
for r in rows:
    print('%-30s sp=%-7s BUILD_EXIT=%-4s RUN_EXIT=%-5s %s' % (r[0], r[1], r[2], r[3] or '-', r[5][:110]))
