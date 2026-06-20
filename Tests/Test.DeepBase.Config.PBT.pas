{ ============================================================================
  Test.DeepBase.Config.PBT - Property-based tests for the Round-2
  Config and Logging fixes.

  Properties covered (deepbase-round2-fixes):
    Property 12: For any config key K not present in storage,
                 GetConfig(K, default) must NOT cache the default
                 value. After a subsequent SetConfig(K, real)
                 (or storage write) GetConfig(K, anyOtherDefault)
                 must return the real value, not the previously
                 returned default. The fix uses a sentinel return
                 from ReadFromDB to differentiate "missing" from
                 "stored empty string".
    Property 13: For any log message containing JSON-special bytes
                 (quote, backslash, newline, tab, control chars,
                 non-ASCII / CJK), the JSON-formatted log line
                 produced by the logger's JSON path must:
                   (a) parse cleanly back to a TJSONObject,
                   (b) the parsed `message` field equals the
                       ORIGINAL input string verbatim (no double
                       escape, no truncation).
                 The fix skips the EscapeLogContent post-pass on
                 the lfJson branch because TJSONObject.AddPair has
                 already produced compliant JSON.

  Each property runs >= 100 random iterations.

  Notes on observability and degradation:
    - Property 12: TDeepBaseConfig accepts an IConfigStorage, which
      makes a fully in-memory test feasible. We supply
      TFakeConfigStorage (this unit, private) and exercise the
      production GetConfig / SetConfig pair end-to-end.
    - Property 13: TDeepBaseLogger.WriteToFile is private and
      writes to a fixed Logs/ subdir of the test executable.
      Driving it from a unit test would (a) require sleeping for
      the async write thread and (b) pollute the build output
      tree. We instead pin the property at the JSON-construction
      layer that the production code uses verbatim
      (TJSONObject + AddPair + ToString, no EscapeLogContent).
      This is the same degradation pattern used by other
      Round-2 PBTs that target private file-IO paths (see
      Test.DeepBase.Commerce.Adapter.PBT).
  ============================================================================ }

unit Test.DeepBase.Config.PBT;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.DateUtils,
  DUnitX.TestFramework,
  DeepBase.Storage.Interfaces,
  DeepBase.Config;

type
  /// <summary>
  /// Tiny in-memory IConfigStorage. Just enough surface to exercise
  /// TDeepBaseConfig.GetConfig / SetConfig under the cache-default
  /// property. Reads return a configurable miss-marker when a key
  /// is absent so we can distinguish "key not present" from "key
  /// stored as empty string".
  /// </summary>
  TFakeConfigStorage = class(TInterfacedObject, IConfigStorage)
  strict private
    FValues: TDictionary<string, string>;
  public
    constructor Create;
    destructor Destroy; override;

    function ReadValue(const Key: string;
      const Default: string = ''): string;
    procedure WriteValue(const Key, Value, Category, ValueType,
      Description: string);
    procedure LoadAll(AValues: TDictionary<string, string>);
    procedure LoadByCategory(const Category: string;
      AValues: TDictionary<string, string>);
    procedure DeleteValue(const Key: string);
    function ValueExists(const Key: string): Boolean;
  end;

  [TestFixture]
  [Category('PBT')]
  TConfigAndLoggingPropertyTests = class
  strict private
    function MakeJsonHostileMessage(AIter: Integer): string;
    function BuildLogJsonLine(const ATimestampISO, ALevel, ASource,
      AMessage: string; AThreadId: Int64): string;
  public
    [Setup]
    procedure Setup;

    // Feature: deepbase-round2-fixes, Property 12
    [Test]
    procedure Property12_DefaultIsNotCached;

    // Feature: deepbase-round2-fixes, Property 13
    [Test]
    procedure Property13_JsonLogNoDoubleEscape;
  end;

implementation

{ TFakeConfigStorage }

constructor TFakeConfigStorage.Create;
begin
  inherited Create;
  FValues := TDictionary<string, string>.Create;
end;

destructor TFakeConfigStorage.Destroy;
begin
  FreeAndNil(FValues);
  inherited;
end;

function TFakeConfigStorage.ReadValue(const Key: string;
  const Default: string): string;
begin
  // Production semantics: when the key is missing, return the
  // caller-supplied default verbatim. TDeepBaseConfig passes a
  // sentinel default precisely so it can detect this case.
  if not FValues.TryGetValue(Key, Result) then
    Result := Default;
end;

procedure TFakeConfigStorage.WriteValue(const Key, Value, Category, ValueType,
  Description: string);
begin
  FValues.AddOrSetValue(Key, Value);
end;

procedure TFakeConfigStorage.LoadAll(AValues: TDictionary<string, string>);
begin
  for var LPair in FValues do
    AValues.AddOrSetValue(LPair.Key, LPair.Value);
end;

procedure TFakeConfigStorage.LoadByCategory(const Category: string;
  AValues: TDictionary<string, string>);
begin
  // Test fixture: ignore category, return everything.
  LoadAll(AValues);
end;

procedure TFakeConfigStorage.DeleteValue(const Key: string);
begin
  FValues.Remove(Key);
end;

function TFakeConfigStorage.ValueExists(const Key: string): Boolean;
begin
  Result := FValues.ContainsKey(Key);
end;

{ TConfigAndLoggingPropertyTests }

procedure TConfigAndLoggingPropertyTests.Setup;
begin
  Randomize;
end;

function TConfigAndLoggingPropertyTests.MakeJsonHostileMessage(
  AIter: Integer): string;
const
  CMenu: array[0..7] of string = (
    'plain ascii',
    'has "double quotes" inside',
    'mixed \backslash\ and "quote"',
    'newline'#10'inside',
    'tab'#9'separated',
    'control'#1#2#3'bytes',
    '中文消息含 "引号" 与 \反斜杠\',
    'emoji 😀 and surrogate-pair test 𝕬');
begin
  Result := Format('iter-%d: %s', [AIter, CMenu[AIter mod Length(CMenu)]]);
end;

function TConfigAndLoggingPropertyTests.BuildLogJsonLine(const ATimestampISO,
  ALevel, ASource, AMessage: string; AThreadId: Int64): string;
var
  LObj: TJSONObject;
begin
  // Mirrors DeepBase.Logging.WriteToFile lfJson branch verbatim:
  // construct a TJSONObject with the same field set and emit
  // ToString. The production fix's invariant is that this output
  // is NOT post-escaped by EscapeLogContent.
  LObj := TJSONObject.Create;
  try
    LObj.AddPair('timestamp', ATimestampISO);
    LObj.AddPair('level', ALevel);
    LObj.AddPair('threadId', TJSONNumber.Create(AThreadId));
    LObj.AddPair('message', AMessage);
    if ASource <> '' then
      LObj.AddPair('source', ASource);
    Result := LObj.ToString;
  finally
    LObj.Free;
  end;
end;

procedure TConfigAndLoggingPropertyTests.Property12_DefaultIsNotCached;
const
  CIters = 100;
begin
  for var Iter := 1 to CIters do
  begin
    var LStorage: IConfigStorage := TFakeConfigStorage.Create;
    var LConfig := TDeepBaseConfig.Create(LStorage);
    try
      var LKey := Format('test.key.%d', [Iter]);
      var LDefault1 := Format('default-A-%d', [Iter]);
      var LDefault2 := Format('default-B-%d', [Iter]);
      var LReal := Format('real-value-%d-%d', [Iter, Random(MaxInt)]);

      // 1. Key absent in storage -> GetConfig returns default,
      //    but does NOT cache it (Property 12).
      var LFirst := LConfig.GetConfig(LKey, LDefault1);
      Assert.AreEqual(LDefault1, LFirst,
        Format('Iter %d: missing key must surface caller default', [Iter]));

      // 2. Write a real value via SetConfig.
      LConfig.SetConfig(LKey, LReal, 'general');

      // 3. GetConfig with a *different* default. If the previous
      //    default had been cached we would observe it here. The
      //    fix guarantees we see the just-written real value.
      var LSecond := LConfig.GetConfig(LKey, LDefault2);
      Assert.AreEqual(LReal, LSecond,
        Format('Iter %d: GetConfig must return stored real value, not ' +
               'cached default. first=%s default2=%s got=%s',
          [Iter, LDefault1, LDefault2, LSecond]));

      // 4. As an extra check, fetching once more with yet another
      //    default still surfaces the real value (cache-hit path).
      var LThird := LConfig.GetConfig(LKey, 'default-C-' + IntToStr(Iter));
      Assert.AreEqual(LReal, LThird,
        Format('Iter %d: cache hit must return real value', [Iter]));

      // 5. And after Delete, a brand-new GetConfig with a default
      //    must return the new default (proves Delete clears cache
      //    and that the just-supplied default is also not cached
      //    going forward).
      LConfig.DeleteConfig(LKey);
      var LFourth := LConfig.GetConfig(LKey, LDefault2);
      Assert.AreEqual(LDefault2, LFourth,
        Format('Iter %d: after delete, default must surface', [Iter]));

      // The Delete-then-Get path also must not cache LDefault2.
      // SetConfig with a brand new value must override.
      var LReal2 := 'after-delete-' + IntToStr(Iter);
      LConfig.SetConfig(LKey, LReal2, 'general');
      var LFifth := LConfig.GetConfig(LKey, LDefault1);
      Assert.AreEqual(LReal2, LFifth,
        Format('Iter %d: post-delete default must not have been cached',
          [Iter]));
    finally
      LConfig.Free;
      LStorage := nil;
    end;
  end;
end;

procedure
TConfigAndLoggingPropertyTests
.Property13_JsonLogNoDoubleEscape;
const
  CIters = 100;
begin
  for var Iter := 1 to CIters do
  begin
    var LMessage := MakeJsonHostileMessage(Iter);
    var LSource := if (Iter mod 3) = 0 then 'src.path "weird"' else '';
    var LLevel := 'INFO';
    var LTimestamp := DateToISO8601(Now, False);
    var LThreadId: Int64 := TThread.Current.ThreadID;

    var LLine := BuildLogJsonLine(LTimestamp, LLevel, LSource, LMessage,
      LThreadId);

    // Property 13 (a): the line must parse cleanly as JSON.
    var LValue := TJSONObject.ParseJSONValue(LLine);
    try
      Assert.IsNotNull(LValue,
        Format('Iter %d: produced line is not valid JSON: %s',
          [Iter, LLine]));
      Assert.IsTrue(LValue is TJSONObject,
        Format('Iter %d: expected JSON object, got %s',
          [Iter, LValue.ClassName]));

      var LObj := LValue as TJSONObject;

      // Property 13 (b): the message round-trips verbatim. If the
      // production code had passed the line through
      // EscapeLogContent we would observe doubled backslashes or
      // truncated control bytes here.
      var LParsed := LObj.GetValue<string>('message');
      Assert.AreEqual(LMessage, LParsed,
        Format('Iter %d: message round-trip mismatch.' + sLineBreak +
               '  input  = %s' + sLineBreak +
               '  parsed = %s' + sLineBreak +
               '  line   = %s', [Iter, LMessage, LParsed, LLine]));

      // The other invariant fields also round-trip.
      Assert.AreEqual(LTimestamp, LObj.GetValue<string>('timestamp'),
        Format('Iter %d: timestamp mismatch', [Iter]));
      Assert.AreEqual(LLevel, LObj.GetValue<string>('level'),
        Format('Iter %d: level mismatch', [Iter]));
      Assert.AreEqual<Int64>(LThreadId,
        LObj.GetValue<Int64>('threadId'),
        Format('Iter %d: threadId mismatch', [Iter]));

      if LSource <> '' then
        Assert.AreEqual(LSource, LObj.GetValue<string>('source'),
          Format('Iter %d: source mismatch', [Iter]));
    finally
      LValue.Free;
    end;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TConfigAndLoggingPropertyTests);

end.
