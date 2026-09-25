unit Test.DeepBase.AutoFixSelfTermination;

{*******************************************************************************
  A2-03 regression: TAutoFixSelfTerminator.HandleFatal must not terminate the
  process on the --autofix-mode command-line flag alone. Termination requires
  the second condition - an explicit host-code confirmation source:
    - flag only: HandleFatal returns, host process keeps running (exit 0),
      no exit-reason.json is written;
    - confirmed: full chain runs (scenario marked fatal, exit-reason.json,
      error log closed) and the host exits with code 2.
  Host-level cases spawn the AutoFixHarness fixture (compiled next to the
  test runner) because the confirmed path calls Halt.
*******************************************************************************}

interface

uses
  Winapi.Windows,
  System.SysUtils, System.IOUtils,
  DUnitX.TestFramework,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.SelfTerminator;

type
  [TestFixture]
  TTestAutoFixSelfTerminationGate = class
  private
    FOutRoot: string;
    FHarnessExe: string;
    function HarnessAvailable: Boolean;
    function SpawnHarness(const AScenario, AOutputDir: string;
      out AExitCode: Cardinal): Boolean;
    function RunIdString: string;
  public
    [Setup]
    procedure SetUp;
    [TearDown]
    procedure TearDown;

    /// <summary>Blank confirmation sources are rejected (they must not arm the gate)</summary>
    [Test]
    procedure Test_BlankConfirmation_Rejected;

    /// <summary>Recorder active (flag path) but unconfirmed: HandleFatal returns
    /// and writes no exit-reason.json - reaching the asserts proves no Halt happened</summary>
    [Test]
    procedure Test_FlagOnly_HandleFatalReturns;

    /// <summary>Host process run with --autofix-mode only: fatal scenario
    /// completes, exit code is 0 (continues), no exit-reason.json</summary>
    [Test]
    procedure Test_FlagOnly_Harness_ContinuesWithExit0;

    /// <summary>Host process run with --autofix-mode AND host confirmation:
    /// exits 2 and exit-reason.json carries the fatal class (full cleanup path)</summary>
    [Test]
    procedure Test_Confirmed_Harness_Exits2_WithExitReason;
  end;

implementation

const
  CSpawnTimeoutMs = 30000;

{ TTestAutoFixSelfTerminationGate }

function TTestAutoFixSelfTerminationGate.RunIdString: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := LowerCase(GUIDToString(LGuid).Trim(['{', '}']));
end;

function TTestAutoFixSelfTerminationGate.HarnessAvailable: Boolean;
begin
  Result := (FHarnessExe <> '') and TFile.Exists(FHarnessExe);
end;

function TTestAutoFixSelfTerminationGate.SpawnHarness(const AScenario,
  AOutputDir: string; out AExitCode: Cardinal): Boolean;
var
  LSI: TStartupInfo;
  LPI: TProcessInformation;
  LCmdLine: string;
  LBuffer: array of WideChar;
  LWait: DWORD;
begin
  AExitCode := High(Cardinal);
  ForceDirectories(AOutputDir);

  LCmdLine := Format('"%s" --autofix-mode --autofix-run-id=%s --autofix-iteration=1 ' +
    '--autofix-scenario=%s --autofix-output=%s',
    [FHarnessExe, RunIdString, AScenario, AOutputDir]);

  SetLength(LBuffer, Length(LCmdLine) + 1);
  StrPCopy(@LBuffer[0], LCmdLine);

  ZeroMemory(@LSI, SizeOf(LSI));
  LSI.cb := SizeOf(LSI);
  LSI.dwFlags := STARTF_USESHOWWINDOW;
  LSI.wShowWindow := SW_HIDE;
  ZeroMemory(@LPI, SizeOf(LPI));

  if not CreateProcessW(nil, @LBuffer[0], nil, nil, False,
                        CREATE_NO_WINDOW, nil, nil, LSI, LPI) then
    Exit(False);

  try
    LWait := WaitForSingleObject(LPI.hProcess, CSpawnTimeoutMs);
    if LWait <> WAIT_OBJECT_0 then
    begin
      TerminateProcess(LPI.hProcess, $DEAD);
      Exit(False);
    end;
    Result := GetExitCodeProcess(LPI.hProcess, DWORD(AExitCode));
  finally
    CloseHandle(LPI.hThread);
    CloseHandle(LPI.hProcess);
  end;
end;

procedure TTestAutoFixSelfTerminationGate.SetUp;
begin
  FHarnessExe := TPath.Combine(TPath.GetDirectoryName(ParamStr(0)),
    'AutoFixHarness.exe');
  FOutRoot := TPath.Combine(TPath.GetTempPath, 'a203_selfterm_' + RunIdString);
  ForceDirectories(FOutRoot);
end;

procedure TTestAutoFixSelfTerminationGate.TearDown;
begin
  TAutoFixErrorRecorder.ResetForTest;
  if (FOutRoot <> '') and TDirectory.Exists(FOutRoot) then
  begin
    try
      TDirectory.Delete(FOutRoot, True);
    except
      // best-effort cleanup; leave artefacts for inspection on failure
    end;
  end;
end;

procedure TTestAutoFixSelfTerminationGate.Test_BlankConfirmation_Rejected;
begin
  Assert.WillRaise(
    procedure begin TAutoFixSelfTerminator.ConfirmTermination(''); end,
    EArgumentException);
  Assert.WillRaise(
    procedure begin TAutoFixSelfTerminator.ConfirmTermination('   '); end,
    EArgumentException);
  // Rejected calls must not have armed the gate
  Assert.IsFalse(TAutoFixSelfTerminator.TerminationConfirmed,
    'Blank confirmation must not arm the self-termination gate');
end;

procedure TTestAutoFixSelfTerminationGate.Test_FlagOnly_HandleFatalReturns;
var
  LFault: EAccessViolation;
  LExitReasonPath: string;
begin
  Assert.IsFalse(TAutoFixSelfTerminator.TerminationConfirmed,
    'Gate must start unconfirmed in this process');
  TAutoFixErrorRecorder.ActivateForTest(RunIdString, FOutRoot);

  LFault := EAccessViolation.Create('a203 probe fault');
  try
    // If the flag alone could trigger Halt, the runner dies right here and
    // the assertions below never execute.
    TAutoFixSelfTerminator.HandleFatal(LFault, nil);
  finally
    LFault.Free;
  end;

  LExitReasonPath := TPath.Combine(FOutRoot, 'exit-reason.json');
  Assert.IsFalse(TFile.Exists(LExitReasonPath),
    'Unconfirmed HandleFatal must not write exit-reason.json');
end;

procedure TTestAutoFixSelfTerminationGate.Test_FlagOnly_Harness_ContinuesWithExit0;
var
  LExitCode: Cardinal;
  LOut: string;
  LResults: string;
begin
  if not HarnessAvailable then
  begin
    Status('AutoFixHarness.exe not found next to the runner; compile ' +
      'Tests\AutoFix\Fixtures\AutoFixHarness.dpr into the runner output ' +
      'directory to enable this case. Skipping.');
    Assert.IsFalse(HarnessAvailable, 'fixture-skipped');
    Exit;
  end;

  LOut := TPath.Combine(FOutRoot, 'unconfirmed');
  Assert.IsTrue(SpawnHarness('fatal-unconfirmed', LOut, LExitCode),
    'spawn failed (unconfirmed)');
  Assert.AreEqual<Cardinal>(0, LExitCode,
    'Flag-only fatal scenario must keep the host alive and exit 0');
  Assert.IsFalse(TFile.Exists(TPath.Combine(LOut, 'exit-reason.json')),
    'Flag-only fatal scenario must not write exit-reason.json');

  LResults := TFile.ReadAllText(TPath.Combine(LOut, 'scenario-results.jsonl'));
  Assert.IsTrue(LResults.Contains('"status":"pass"'),
    'Scenario must run to completion after HandleFatal returns');
end;

procedure TTestAutoFixSelfTerminationGate.Test_Confirmed_Harness_Exits2_WithExitReason;
var
  LExitCode: Cardinal;
  LOut, LReasonPath, LContent: string;
begin
  if not HarnessAvailable then
  begin
    Status('AutoFixHarness.exe not found next to the runner; compile ' +
      'Tests\AutoFix\Fixtures\AutoFixHarness.dpr into the runner output ' +
      'directory to enable this case. Skipping.');
    Assert.IsFalse(HarnessAvailable, 'fixture-skipped');
    Exit;
  end;

  LOut := TPath.Combine(FOutRoot, 'confirmed');
  Assert.IsTrue(SpawnHarness('fatal', LOut, LExitCode),
    'spawn failed (confirmed)');
  Assert.AreEqual<Cardinal>(2, LExitCode,
    'Confirmed fatal scenario must terminate with exit code 2');

  LReasonPath := TPath.Combine(LOut, 'exit-reason.json');
  Assert.IsTrue(TFile.Exists(LReasonPath),
    'Confirmed fatal scenario must write exit-reason.json');
  LContent := TFile.ReadAllText(LReasonPath, TEncoding.UTF8);
  Assert.IsTrue(LContent.Contains('"fatal_class":"EAccessViolation"'),
    'exit-reason.json must carry the fatal class');
  Assert.IsTrue(LContent.Contains('"exit_code":2'),
    'exit-reason.json must declare exit_code 2');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAutoFixSelfTerminationGate);

end.
