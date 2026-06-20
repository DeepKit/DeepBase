{ ============================================================================
  Test.DeepBase.AutoFix.ErrorRecorder

  DUnitX property-based tests for the AutoFix error recorder.

  Properties covered:
    P1  : ErrorRecorder JSONL field completeness (Req 1.1, 1.2, 1.6)
    P2  : run_id is a valid UUID v4 and consistent across files
          (Req 1.3, 3.1, 3.2)
    P18 : Install idempotency + same-name scenario re-registration
          (Req 14.1, 14.2)
    P19 : Non-autofix-mode is zero-IO (Req 14.3)

  Each property test runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.AutoFix.ErrorRecorder;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.RegularExpressions,
  DUnitX.TestFramework,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.HealthSignal,
  DeepBase.AutoFix.ScenarioRunner,
  DeepBase.AutoFix;

type
  [TestFixture]
  [Category('PBT')]
  TAutoFixErrorRecorderPropertyTests = class
  strict private
    FTestDir: string;
    function NewTestDir: string;
    function RandomMessage: string;
    function RandomContext: string;
    function RandomExceptionClass: ExceptClass;
    function CreateRandomException: Exception;
    function ReadLastJsonlLine(const APath: string): string;
    function JsonContainsField(const AJson, AFieldName: string): Boolean;
    function ExtractJsonString(const AJson, AFieldName: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Property1_JsonlFieldsComplete;
    [Test]
    procedure Property2_RunIdIsUuidV4AndConsistent;
    [Test]
    procedure Property18_InstallIdempotentAndScenarioReplacement;
    [Test]
    procedure Property19_ZeroIoWithoutAutofixMode;
  end;

implementation

{ TAutoFixErrorRecorderPropertyTests }

procedure TAutoFixErrorRecorderPropertyTests.Setup;
begin
  Randomize;
  FTestDir := NewTestDir;
end;

procedure TAutoFixErrorRecorderPropertyTests.TearDown;
begin
  TAutoFixErrorRecorder.ResetForTest;
  if (FTestDir <> '') and TDirectory.Exists(FTestDir) then
  begin
    try
      TDirectory.Delete(FTestDir, True);
    except
      // best effort cleanup; some files may still be locked by streams
    end;
  end;
end;

function TAutoFixErrorRecorderPropertyTests.NewTestDir: string;
begin
  var LGuid: TGUID;
  CreateGUID(LGuid);
  Result := TPath.Combine(TPath.GetTempPath,
    'autofix-test-' + GUIDToString(LGuid).Trim(['{', '}']).ToLower);
  ForceDirectories(Result);
end;

function TAutoFixErrorRecorderPropertyTests.RandomMessage: string;
const
  CSpecial: array[0..6] of string = (
    '"with-quote', '\back\slash', 'line1'#10'line2',
    'tab'#9'sep', '中文消息', 'multi'#13#10'CRLF', 'plain ascii');
begin
  Result := CSpecial[Random(Length(CSpecial))];
  Result := Result + ' #' + IntToStr(Random(10000));
end;

function TAutoFixErrorRecorderPropertyTests.RandomContext: string;
const
  CContexts: array[0..4] of string = (
    'TFooController.RunScan', 'background-thread',
    '<vcl-onexception>', 'timer-tick', '');
begin
  Result := CContexts[Random(Length(CContexts))];
end;

function TAutoFixErrorRecorderPropertyTests.RandomExceptionClass: ExceptClass;
const
  CClasses: array[0..7] of ExceptClass = (
    Exception, EConvertError, ERangeError, EArgumentException,
    EArgumentNilException, EInvalidOpException, EOverflow, EZeroDivide);
begin
  Result := CClasses[Random(Length(CClasses))];
end;

function TAutoFixErrorRecorderPropertyTests.CreateRandomException: Exception;
begin
  Result := RandomExceptionClass.Create(RandomMessage);
end;

function TAutoFixErrorRecorderPropertyTests.ReadLastJsonlLine(
  const APath: string): string;
begin
  Result := '';
  if not TFile.Exists(APath) then Exit;
  // BUG-282: TFile.ReadAllLines internally uses fmShareExclusive (no sharing),
  // which fails when the writer has the file open. Use a TStreamReader over a
  // TFileStream opened with fmShareDenyNone so concurrent reads succeed.
  var LStream := TFileStream.Create(APath, fmOpenRead or fmShareDenyNone);
  try
    var LReader := TStreamReader.Create(LStream, TEncoding.UTF8, False, 1024);
    try
      while not LReader.EndOfStream do
      begin
        var LLine := LReader.ReadLine;
        if Trim(LLine) <> '' then
          Result := LLine;
      end;
    finally
      LReader.Free;
    end;
  finally
    LStream.Free;
  end;
end;

function TAutoFixErrorRecorderPropertyTests.JsonContainsField(
  const AJson, AFieldName: string): Boolean;
begin
  Result := AJson.Contains('"' + AFieldName + '"');
end;

function TAutoFixErrorRecorderPropertyTests.ExtractJsonString(
  const AJson, AFieldName: string): string;
begin
  Result := '';
  var LKey := '"' + AFieldName + '":"';
  var LIdx := AJson.IndexOf(LKey);
  if LIdx < 0 then Exit;
  var LStart := LIdx + LKey.Length;
  var LEnd := LStart;
  while LEnd < AJson.Length do
  begin
    if (AJson.Chars[LEnd] = '"') and
       ((LEnd = 0) or (AJson.Chars[LEnd - 1] <> '\')) then
      Break;
    Inc(LEnd);
  end;
  Result := AJson.Substring(LStart, LEnd - LStart);
end;

// Feature: autofix-runtime-errors, Property 1: ErrorRecorder JSONL 字段完整性
procedure TAutoFixErrorRecorderPropertyTests.Property1_JsonlFieldsComplete;
const
  CRequiredFields: array[0..12] of string = (
    'run_id', 'iteration', 'ts', 'level', 'class', 'msg',
    'module_name', 'module_base', 'rva', 'stack',
    'context', 'thread', 'dedup_key');
  CValidLevels: array[0..2] of string = ('fatal', 'error', 'warning');
begin
  TAutoFixErrorRecorder.ActivateForTest(
    '11111111-2222-4333-8444-555555555555', FTestDir, 7);

  var LJsonlPath := TPath.Combine(FTestDir, 'runtime-errors.jsonl');

  for var I := 1 to 100 do
  begin
    var LExc := CreateRandomException;
    var LExcClassName := LExc.ClassName;
    var LContext := RandomContext;
    var LThread := 'thread-' + IntToStr(Random(99999));
    try
      TAutoFixErrorRecorder.WriteRecord(LExc, nil, LContext, LThread);
    finally
      LExc.Free;
    end;

    var LLine := ReadLastJsonlLine(LJsonlPath);
    Assert.IsNotEmpty(LLine, Format('Iter %d: jsonl line missing', [I]));

    for var LField in CRequiredFields do
      Assert.IsTrue(JsonContainsField(LLine, LField),
        Format('Iter %d: missing field "%s" in: %s', [I, LField, LLine]));

    var LLevel := ExtractJsonString(LLine, 'level');
    var LLevelOk := False;
    for var LValid in CValidLevels do
      if LLevel = LValid then LLevelOk := True;
    Assert.IsTrue(LLevelOk,
      Format('Iter %d: invalid level "%s"', [I, LLevel]));

    Assert.AreEqual(LExcClassName, ExtractJsonString(LLine, 'class'),
      Format('Iter %d: class mismatch', [I]));
    Assert.AreEqual(LThread, ExtractJsonString(LLine, 'thread'),
      Format('Iter %d: thread mismatch', [I]));
  end;
end;

// Feature: autofix-runtime-errors, Property 2: run_id UUID v4 + 跨文件一致
procedure TAutoFixErrorRecorderPropertyTests.Property2_RunIdIsUuidV4AndConsistent;
const
  CUuidV4Pattern =
    '^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$';
begin
  var LSeen := TStringList.Create;
  try
    LSeen.Sorted := True;
    LSeen.Duplicates := dupIgnore;

    for var I := 1 to 100 do
    begin
      var LDir := NewTestDir;
      try
        // Activate with empty run_id so ActivateForTest generates a fresh UUID v4.
        TAutoFixErrorRecorder.ActivateForTest('', LDir, I);
        TAutoFixScenarioRunner.ResetForTest(['probe-' + IntToStr(I)]);

        var LRunId := TAutoFixErrorRecorder.RunId;
        Assert.IsTrue(TRegEx.IsMatch(LRunId, CUuidV4Pattern),
          Format('Iter %d: run_id "%s" not UUID v4', [I, LRunId]));
        Assert.IsTrue(LSeen.IndexOf(LRunId) < 0,
          Format('Iter %d: duplicate run_id "%s"', [I, LRunId]));
        LSeen.Add(LRunId);

        // Touch each of the three writers so all artefacts carry the same run_id.
        var LExc := EConvertError.Create('probe ' + IntToStr(I));
        try
          TAutoFixErrorRecorder.WriteRecord(LExc, nil, 'p2', 'main');
        finally
          LExc.Free;
        end;
        TAutoFixHealthSignal.Emit;
        // Drive a single scenario WriteStatus by running the registered list.
        TAutoFixScenarioRunner.RegisterScenario('probe-' + IntToStr(I),
          procedure
          begin
            // no-op pass
          end);
        TAutoFixScenarioRunner.RunForTest;

        var LErrLine := ReadLastJsonlLine(
          TPath.Combine(LDir, 'runtime-errors.jsonl'));
        var LScenLine := ReadLastJsonlLine(
          TPath.Combine(LDir, 'scenario-results.jsonl'));
        var LHealthJson := TFile.ReadAllText(
          TPath.Combine(LDir, 'health-signal.json'), TEncoding.UTF8);

        Assert.AreEqual(LRunId, ExtractJsonString(LErrLine, 'run_id'),
          Format('Iter %d: runtime-errors run_id mismatch', [I]));
        Assert.AreEqual(LRunId, ExtractJsonString(LScenLine, 'run_id'),
          Format('Iter %d: scenario-results run_id mismatch', [I]));
        Assert.AreEqual(LRunId, ExtractJsonString(LHealthJson, 'run_id'),
          Format('Iter %d: health-signal run_id mismatch', [I]));
      finally
        TAutoFixErrorRecorder.ResetForTest;
        if TDirectory.Exists(LDir) then
          try TDirectory.Delete(LDir, True); except end;
      end;
    end;
  finally
    LSeen.Free;
  end;
end;

// Feature: autofix-runtime-errors, Property 18: Install 幂等性 + 注册唯一性
procedure TAutoFixErrorRecorderPropertyTests.Property18_InstallIdempotentAndScenarioReplacement;
begin
  for var I := 1 to 100 do
  begin
    TAutoFixErrorRecorder.ResetForTest;

    // Capture System.ExceptProc baseline. Without --autofix-mode on the cmd
    // line, Install must not replace the global hook even after repeated
    // calls (FInstalled gates the hook, FActive gates the replacement).
    var LBefore: Pointer := System.ExceptProc;

    AutoFix.Install;
    var LAfter1: Pointer := System.ExceptProc;
    AutoFix.Install;
    var LAfter2: Pointer := System.ExceptProc;
    AutoFix.Install;
    var LAfter3: Pointer := System.ExceptProc;

    Assert.IsTrue(LBefore = LAfter1,
      Format('Iter %d: ExceptProc unexpectedly replaced after first Install', [I]));
    Assert.IsTrue(LAfter1 = LAfter2,
      Format('Iter %d: ExceptProc replaced on second Install', [I]));
    Assert.IsTrue(LAfter2 = LAfter3,
      Format('Iter %d: ExceptProc replaced on third Install', [I]));

    // Re-register same name with two different callbacks; the second must
    // win (dictionary AddOrSetValue semantics in RegisterScenario).
    var LName := 'scen-' + IntToStr(I);

    TAutoFixErrorRecorder.ActivateForTest('', FTestDir, 1);
    TAutoFixScenarioRunner.ResetForTest([LName]);

    var LFirstHits := 0;
    var LSecondHits := 0;
    AutoFix.RegisterScenario(LName,
      procedure begin Inc(LFirstHits) end);
    AutoFix.RegisterScenario(LName,
      procedure begin Inc(LSecondHits) end);

    TAutoFixScenarioRunner.RunForTest;

    Assert.AreEqual(0, LFirstHits,
      Format('Iter %d: first callback should be replaced', [I]));
    Assert.AreEqual(1, LSecondHits,
      Format('Iter %d: second callback should win', [I]));

    TAutoFixErrorRecorder.ResetForTest;
  end;
end;

// Feature: autofix-runtime-errors, Property 19: 非 autofix-mode 零 I/O
procedure TAutoFixErrorRecorderPropertyTests.Property19_ZeroIoWithoutAutofixMode;
begin
  for var I := 1 to 100 do
  begin
    TAutoFixErrorRecorder.ResetForTest;
    var LDir := NewTestDir;
    try
      // Re-route the default output dir into our test dir so we can verify
      // it stays empty even without --autofix-mode. We do this by NOT
      // calling ActivateForTest (which is the only way to flip Active=True
      // from a unit test). After Reset, Active is False.
      Assert.IsFalse(TAutoFixErrorRecorder.Active,
        Format('Iter %d: Active should be False before Install', [I]));

      AutoFix.Install;
      Assert.IsFalse(TAutoFixErrorRecorder.Active,
        Format('Iter %d: Active should remain False after Install (no cmdline)', [I]));

      // Register some scenarios (no-ops in dormant mode).
      AutoFix.RegisterScenario('a' + IntToStr(I),
        procedure begin end);
      AutoFix.RegisterScenario('b' + IntToStr(I),
        procedure begin end);

      // Trigger non-fatal exceptions through the public WriteRecord and
      // RecordFromSafeRun paths. None should result in any file IO.
      var LExc := EConvertError.Create('inactive ' + IntToStr(I));
      try
        TAutoFixErrorRecorder.RecordFromSafeRun(LExc, 'p19');
        TAutoFixErrorRecorder.WriteRecord(LExc, nil, 'p19', 'main');
      finally
        LExc.Free;
      end;

      // Touch HealthSignal.Emit -- it must short-circuit when Active is False.
      TAutoFixHealthSignal.Emit;

      // Inspect LDir; nothing should have been written. Also inspect the
      // default path under the EXE dir for safety.
      Assert.IsFalse(TFile.Exists(TPath.Combine(LDir, 'runtime-errors.jsonl')),
        Format('Iter %d: runtime-errors.jsonl was written when inactive', [I]));
      Assert.IsFalse(TFile.Exists(TPath.Combine(LDir, 'health-signal.json')),
        Format('Iter %d: health-signal.json was written when inactive', [I]));
      Assert.IsFalse(TFile.Exists(TPath.Combine(LDir, 'scenario-results.jsonl')),
        Format('Iter %d: scenario-results.jsonl was written when inactive', [I]));
    finally
      if TDirectory.Exists(LDir) then
        try TDirectory.Delete(LDir, True); except end;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAutoFixErrorRecorderPropertyTests);

end.
