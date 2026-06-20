{ ============================================================================
  Test.DeepBase.AutoFix.HealthSignal

  DUnitX property-based tests for HealthSignal.

  Properties covered:
    P7 : HealthSignal field completeness + run_id consistency (Req 3.1)

  Each property test runs >= 100 random iterations.
  ============================================================================ }

unit Test.DeepBase.AutoFix.HealthSignal;

interface

uses
  System.SysUtils,
  System.IOUtils,
  Winapi.Windows,
  DUnitX.TestFramework,
  DeepBase.AutoFix.ErrorRecorder,
  DeepBase.AutoFix.HealthSignal;

type
  [TestFixture]
  [Category('PBT')]
  TAutoFixHealthSignalPropertyTests = class
  strict private
    function NewTestDir: string;
    function ExtractJsonString(const AJson, AField: string): string;
    function ExtractJsonNumber(const AJson, AField: string): Int64;
    function JsonHasField(const AJson, AField: string): Boolean;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Property7_FieldsCompleteAndRunIdMatches;
  end;

implementation

{ TAutoFixHealthSignalPropertyTests }

procedure TAutoFixHealthSignalPropertyTests.Setup;
begin
  Randomize;
end;

procedure TAutoFixHealthSignalPropertyTests.TearDown;
begin
  TAutoFixErrorRecorder.ResetForTest;
end;

function TAutoFixHealthSignalPropertyTests.NewTestDir: string;
begin
  var LGuid: TGUID;
  CreateGUID(LGuid);
  Result := TPath.Combine(TPath.GetTempPath,
    'autofix-health-' + GUIDToString(LGuid).Trim(['{', '}']).ToLower);
  ForceDirectories(Result);
end;

function TAutoFixHealthSignalPropertyTests.JsonHasField(
  const AJson, AField: string): Boolean;
begin
  Result := AJson.Contains('"' + AField + '"');
end;

function TAutoFixHealthSignalPropertyTests.ExtractJsonString(
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

function TAutoFixHealthSignalPropertyTests.ExtractJsonNumber(
  const AJson, AField: string): Int64;
begin
  Result := -1;
  var LKey := '"' + AField + '":';
  var LIdx := AJson.IndexOf(LKey);
  if LIdx < 0 then Exit;
  var LStart := LIdx + LKey.Length;
  var LEnd := LStart;
  while (LEnd < AJson.Length) and CharInSet(AJson.Chars[LEnd], ['0'..'9']) do
    Inc(LEnd);
  if LEnd > LStart then
    Result := StrToInt64Def(AJson.Substring(LStart, LEnd - LStart), -1);
end;

// Feature: autofix-runtime-errors, Property 7: HealthSignal 字段完整 + RunId 一致
procedure TAutoFixHealthSignalPropertyTests.Property7_FieldsCompleteAndRunIdMatches;
const
  CRequiredFields: array[0..6] of string = (
    'run_id', 'ready', 'pid', 'timestamp', 'version',
    'autofix_mode', 'scenarios');
begin
  for var I := 1 to 100 do
  begin
    var LDir := NewTestDir;
    try
      // Each iteration gets a fresh activation so RunId rotates and we can
      // verify cross-Emit consistency with the recorder.
      TAutoFixErrorRecorder.ActivateForTest('', LDir, I);
      var LExpectedRunId := TAutoFixErrorRecorder.RunId;

      TAutoFixHealthSignal.Emit;

      var LPath := TPath.Combine(LDir, 'health-signal.json');
      Assert.IsTrue(TFile.Exists(LPath),
        Format('Iter %d: health-signal.json not written', [I]));

      var LJson := TFile.ReadAllText(LPath, TEncoding.UTF8);

      for var LField in CRequiredFields do
        Assert.IsTrue(JsonHasField(LJson, LField),
          Format('Iter %d: missing field "%s" in: %s', [I, LField, LJson]));

      Assert.AreEqual(LExpectedRunId, ExtractJsonString(LJson, 'run_id'),
        Format('Iter %d: run_id mismatch with ErrorRecorder', [I]));

      Assert.AreEqual<Int64>(GetCurrentProcessId,
        ExtractJsonNumber(LJson, 'pid'),
        Format('Iter %d: pid mismatch', [I]));

      // ready and autofix_mode are JSON booleans -- check by substring.
      Assert.IsTrue(LJson.Contains('"ready":true'),
        Format('Iter %d: ready != true', [I]));
      Assert.IsTrue(LJson.Contains('"autofix_mode":true'),
        Format('Iter %d: autofix_mode != true', [I]));

      // version must be present and non-empty (may be 'unknown' on the test
      // EXE; either is acceptable as long as the field exists with a value).
      Assert.IsNotEmpty(ExtractJsonString(LJson, 'version'),
        Format('Iter %d: version is empty', [I]));
    finally
      TAutoFixErrorRecorder.ResetForTest;
      if TDirectory.Exists(LDir) then
        try TDirectory.Delete(LDir, True); except end;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TAutoFixHealthSignalPropertyTests);

end.
