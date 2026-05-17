{ ============================================================================
  Test.DeepBase.AutoFix.ScenarioRunner

  DUnitX property-based tests for ScenarioRunner.

  Properties covered:
    P8 : Scenario execution order + result recording (Req 4.1, 4.2, 4.4)

  Each property test runs >= 100 random iterations.

  Note: TAutoFixScenarioRunner.Run halts the process at the end. Tests use
  the test-only RunForTest entry point that performs the same iteration
  without calling Halt.
  ============================================================================ }

unit Test.DeepBase.AutoFix.ScenarioRunner;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Math,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.ScenarioRunner;

type
  [TestFixture]
  TAutoFixScenarioRunnerPropertyTests = class
  strict private
    function NewTestDir: string;
    function ReadAllJsonlLines(const APath: string): TArray<string>;
    function ExtractJsonString(const AJson, AField: string): string;
    function RandomScenarioPlan(out AThrowFlags: TArray<Boolean>): TArray<string>;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Property8_ScenarioOrderAndStatus;
  end;

implementation

{ TAutoFixScenarioRunnerPropertyTests }

procedure TAutoFixScenarioRunnerPropertyTests.Setup;
begin
  Randomize;
end;

procedure TAutoFixScenarioRunnerPropertyTests.TearDown;
begin
  TAutoFixErrorRecorder.ResetForTest;
end;

function TAutoFixScenarioRunnerPropertyTests.NewTestDir: string;
begin
  var LGuid: TGUID;
  CreateGUID(LGuid);
  Result := TPath.Combine(TPath.GetTempPath,
    'autofix-scen-' + GUIDToString(LGuid).Trim(['{', '}']).ToLower);
  ForceDirectories(Result);
end;

function TAutoFixScenarioRunnerPropertyTests.ReadAllJsonlLines(
  const APath: string): TArray<string>;
begin
  Result := nil;
  if not TFile.Exists(APath) then Exit;
  for var LLine in TFile.ReadAllLines(APath, TEncoding.UTF8) do
    if Trim(LLine) <> '' then
      Result := Result + [LLine];
end;

function TAutoFixScenarioRunnerPropertyTests.ExtractJsonString(
  const AJson, AField: string): string;
begin
  Result := '';
  var LKey := '"' + AField + '":"';
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

function TAutoFixScenarioRunnerPropertyTests.RandomScenarioPlan(
  out AThrowFlags: TArray<Boolean>): TArray<string>;
begin
  // Pick 1..6 distinct scenario names from a small pool, in random order
  // and decide independently whether each callback raises.
  var LPool: TArray<string> := ['scan', 'reload', 'backup', 'export', 'sync', 'probe'];
  Result := nil;
  AThrowFlags := nil;
  var LCount := RandomRange(1, 7);
  // Random subset preserving uniqueness.
  var LBag := TList<string>.Create;
  try
    for var LName in LPool do LBag.Add(LName);
    for var I := 0 to LCount - 1 do
    begin
      if LBag.Count = 0 then Break;
      var LIdx := Random(LBag.Count);
      Result := Result + [LBag[LIdx]];
      AThrowFlags := AThrowFlags + [Random(2) = 0];
      LBag.Delete(LIdx);
    end;
  finally
    LBag.Free;
  end;
end;

// Feature: autofix-runtime-errors, Property 8: ScenarioRunner 顺序与结果记录
procedure TAutoFixScenarioRunnerPropertyTests.Property8_ScenarioOrderAndStatus;
begin
  for var I := 1 to 100 do
  begin
    var LDir := NewTestDir;
    try
      TAutoFixErrorRecorder.ActivateForTest('', LDir, I);

      var LThrowFlags: TArray<Boolean>;
      var LPlan := RandomScenarioPlan(LThrowFlags);

      TAutoFixScenarioRunner.ResetForTest(LPlan);

      var LCallOrder := TList<string>.Create;
      try
        // Snapshot throw flags into local closures.
        for var J := 0 to High(LPlan) do
        begin
          var LName := LPlan[J];
          var LShouldThrow := LThrowFlags[J];
          TAutoFixScenarioRunner.RegisterScenario(LName,
            procedure
            begin
              LCallOrder.Add(LName);
              if LShouldThrow then
                raise EConvertError.CreateFmt('boom in %s', [LName]);
            end);
        end;

        var LExecuted := TAutoFixScenarioRunner.RunForTest;

        // Order: callbacks invoked in the requested order.
        Assert.AreEqual(Length(LPlan), LCallOrder.Count,
          Format('Iter %d: callback count mismatch', [I]));
        for var J := 0 to High(LPlan) do
          Assert.AreEqual(LPlan[J], LCallOrder[J],
            Format('Iter %d step %d: order mismatch', [I, J]));

        // Same order as the executed name list returned by RunForTest.
        Assert.AreEqual(Length(LPlan), Length(LExecuted),
          Format('Iter %d: executed list length mismatch', [I]));
        for var J := 0 to High(LPlan) do
          Assert.AreEqual(LPlan[J], LExecuted[J],
            Format('Iter %d step %d: executed order mismatch', [I, J]));

        // scenario-results.jsonl: terminal records (pass / fail) match plan.
        var LLines := ReadAllJsonlLines(
          TPath.Combine(LDir, 'scenario-results.jsonl'));
        Assert.IsTrue(Length(LLines) >= Length(LPlan),
          Format('Iter %d: not enough jsonl lines', [I]));

        // Walk lines in order, collecting the last terminal record per name.
        // RunForTest writes "running" then either "pass" or "fail" per scenario;
        // we keep the last record observed per name and compare to plan.
        var LFinal := TDictionary<string, string>.Create;
        try
          for var LLine in LLines do
          begin
            var LName := ExtractJsonString(LLine, 'name');
            var LStatus := ExtractJsonString(LLine, 'status');
            if (LStatus = 'pass') or (LStatus = 'fail') then
              LFinal.AddOrSetValue(LName, LLine);
          end;

          for var J := 0 to High(LPlan) do
          begin
            var LName := LPlan[J];
            Assert.IsTrue(LFinal.ContainsKey(LName),
              Format('Iter %d: no terminal record for "%s"', [I, LName]));
            var LLine := LFinal[LName];
            var LExpectedStatus := if LThrowFlags[J] then 'fail' else 'pass';
            Assert.AreEqual(LExpectedStatus,
              ExtractJsonString(LLine, 'status'),
              Format('Iter %d "%s": status mismatch', [I, LName]));

            if LThrowFlags[J] then
              Assert.AreEqual('EConvertError',
                ExtractJsonString(LLine, 'error_class'),
                Format('Iter %d "%s": error_class mismatch', [I, LName]));
          end;
        finally
          LFinal.Free;
        end;
      finally
        LCallOrder.Free;
      end;
    finally
      TAutoFixErrorRecorder.ResetForTest;
      if TDirectory.Exists(LDir) then
        try TDirectory.Delete(LDir, True); except end;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAutoFixScenarioRunnerPropertyTests);

end.
