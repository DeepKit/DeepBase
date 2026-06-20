{ ============================================================================
  Test.DeepBase.Speech.Intent - Unit tests for intent parser + LLM fallback
  ============================================================================ }

unit Test.DeepBase.Speech.Intent;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils, System.Classes, System.SyncObjs, System.Threading,
  System.RegularExpressions,
  System.Generics.Collections,
  DeepBase.Speech.Intent;

type
  [TestFixture]
  TTestIntentParser = class
  private
    FParser: TDeepBaseIntentParser;
    function JsonIntent(const AIntent: string; AConf: Double = 0.8;
      const AReason: string = ''): string;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    // Rule matching
    [Test] procedure Test_Parse_EmptyReturnsUnknown;
    [Test] procedure Test_Parse_RuleMatch_ReturnsRule;
    [Test] procedure Test_Parse_NoRuleNoLLM_ReturnsUnknown;
    [Test] procedure Test_Parse_RulePriority;
    [Test] procedure Test_Parse_SlotExtractorInvoked;
    [Test] procedure Test_ClearRules_ResetsCount;

    // LLM fallback (new in v1.1)
    [Test] procedure Test_LLM_NotEnabled_RuleMiss_ReturnsUnknown;
    [Test] procedure Test_LLM_EnabledNoBackend_ReturnsUnsupported;
    [Test] procedure Test_LLM_BackendSuccess_ReturnsLLM;
    [Test] procedure Test_LLM_BackendRaises_ReturnsUnavailable;
    [Test] procedure Test_LLM_BackendReturnsInvalidJson_IntentIsUnknown;
    [Test] procedure Test_LLM_ConfidenceClampedTo01;
    [Test] procedure Test_LLM_TimeoutAndIntentsPassedToBackend;
    [Test] procedure Test_LLM_GlobalBackendUsedWhenInstanceHasNone;
    [Test] procedure Test_LLM_InstanceBackendOverridesGlobal;

    // Concurrency
    [Test] procedure Test_ConcurrentRegisterAndParse;
  end;

implementation

uses
  System.Math;

type
  TIntentSlotArray = TArray<TIntentSlot>;

{ TTestIntentParser }

procedure TTestIntentParser.Setup;
begin
  FParser := TDeepBaseIntentParser.Create;
  // Reset any global state from prior tests
  TDeepBaseIntentParser.RegisterGlobalLLMBackend(nil);
end;

procedure TTestIntentParser.TearDown;
begin
  TDeepBaseIntentParser.RegisterGlobalLLMBackend(nil);
  FreeAndNil(FParser);
end;

function TTestIntentParser.JsonIntent(const AIntent: string; AConf: Double;
  const AReason: string): string;
begin
  Result := Format('{"intent":"%s","confidence":%s,"reason":"%s"}',
    [AIntent, FloatToStr(AConf, TFormatSettings.Invariant), AReason]);
end;

procedure TTestIntentParser.Test_Parse_EmptyReturnsUnknown;
var R: TIntentResult;
begin
  R := FParser.Parse('');
  Assert.AreEqual<string>('unknown', R.Intent);
  Assert.AreEqual<string>('', R.Source);
end;

procedure TTestIntentParser.Test_Parse_RuleMatch_ReturnsRule;
var R: TIntentResult;
begin
  FParser.RegisterRule('open (\w+)', 'open_app');
  R := FParser.Parse('open chrome');
  Assert.AreEqual<string>('open_app', R.Intent);
  Assert.AreEqual<string>('rule', R.Source);
  Assert.IsTrue(R.Confidence > 0.8);
end;

procedure TTestIntentParser.Test_Parse_NoRuleNoLLM_ReturnsUnknown;
var R: TIntentResult;
begin
  R := FParser.Parse('something completely different');
  Assert.AreEqual<string>('unknown', R.Intent);
  Assert.AreEqual<string>('', R.Source);
end;

procedure TTestIntentParser.Test_Parse_RulePriority;
var R: TIntentResult;
begin
  FParser.RegisterRule('play', 'play_generic', nil, 100);
  FParser.RegisterRule('play music', 'play_music', nil, 10);
  R := FParser.Parse('play music now');
  Assert.AreEqual<string>('play_music', R.Intent);
end;

procedure TTestIntentParser.Test_Parse_SlotExtractorInvoked;
var
  R: TIntentResult;
begin
  FParser.RegisterRule('set timer (\d+) seconds', 'set_timer',
    function(const T: string): TIntentSlotArray
    var M: TMatch;
    begin
      M := TRegEx.Match(T, '(\d+)');
      if M.Success then
      begin
        SetLength(Result, 1);
        Result[0].Name := 'seconds';
        Result[0].Value := M.Groups[1].Value;
      end
      else Result := nil;
    end);
  R := FParser.Parse('set timer 30 seconds');
  Assert.AreEqual<string>('set_timer', R.Intent);
  Assert.AreEqual<Integer>(1, Length(R.Slots));
  Assert.AreEqual<string>('seconds', R.Slots[0].Name);
  Assert.AreEqual<string>('30', R.Slots[0].Value);
end;

procedure TTestIntentParser.Test_ClearRules_ResetsCount;
begin
  FParser.RegisterRule('a', 'x');
  FParser.RegisterRule('b', 'y');
  Assert.AreEqual<Integer>(2, FParser.RuleCount);
  FParser.ClearRules;
  Assert.AreEqual<Integer>(0, FParser.RuleCount);
end;

procedure TTestIntentParser.Test_LLM_NotEnabled_RuleMiss_ReturnsUnknown;
var R: TIntentResult;
begin
  FParser.LLMEnabled := False;
  R := FParser.Parse('something wild');
  Assert.AreEqual<string>('unknown', R.Intent);
  Assert.AreEqual<string>('', R.Source);
end;

procedure TTestIntentParser.Test_LLM_EnabledNoBackend_ReturnsUnsupported;
var R: TIntentResult;
begin
  FParser.LLMEnabled := True;
  Assert.IsFalse(FParser.HasLLMBackend);
  R := FParser.Parse('something wild');
  Assert.AreEqual<string>('unknown', R.Intent);
  Assert.AreEqual<string>('llm_unsupported', R.Source);
end;

procedure TTestIntentParser.Test_LLM_BackendSuccess_ReturnsLLM;
var R: TIntentResult;
begin
  FParser.LLMEnabled := True;
  FParser.RegisterLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      Result := '{"intent":"book_flight","confidence":0.87,"reason":"user asked to fly"}';
    end);
  Assert.IsTrue(FParser.HasLLMBackend);
  R := FParser.Parse('book a flight to Tokyo');
  Assert.AreEqual<string>('book_flight', R.Intent);
  Assert.AreEqual<string>('llm', R.Source);
  Assert.AreEqual<string>(FloatToStr(0.87, TFormatSettings.Invariant),
    FloatToStr(R.Confidence, TFormatSettings.Invariant), 'confidence');
  Assert.AreEqual<string>('user asked to fly', R.Reason);
end;

procedure TTestIntentParser.Test_LLM_BackendRaises_ReturnsUnavailable;
var R: TIntentResult;
begin
  FParser.LLMEnabled := True;
  FParser.RegisterLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      raise EAbort.Create('simulated timeout');
    end);
  R := FParser.Parse('something');
  Assert.AreEqual<string>('unknown', R.Intent);
  Assert.AreEqual<string>('llm_unavailable', R.Source);
  Assert.IsTrue(Pos('simulated timeout', R.Reason) > 0,
    'Reason should carry backend exception message');
end;

procedure TTestIntentParser.Test_LLM_BackendReturnsInvalidJson_IntentIsUnknown;
var R: TIntentResult;
begin
  FParser.LLMEnabled := True;
  FParser.RegisterLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      Result := 'this is not json';
    end);
  R := FParser.Parse('xyz');
  Assert.AreEqual<string>('llm', R.Source);
  Assert.AreEqual<string>('unknown', R.Intent,
    'Missing "intent" in JSON → default to unknown');
end;

procedure TTestIntentParser.Test_LLM_ConfidenceClampedTo01;
var R: TIntentResult;
begin
  FParser.LLMEnabled := True;
  FParser.RegisterLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      Result := '{"intent":"x","confidence":1.7}';
    end);
  R := FParser.Parse('abc');
  Assert.AreEqual<string>(FloatToStr(1.0, TFormatSettings.Invariant),
    FloatToStr(R.Confidence, TFormatSettings.Invariant),
    'Over 1.0 clamped to 1.0');

  FParser.RegisterLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      Result := '{"intent":"x","confidence":-0.3}';
    end);
  R := FParser.Parse('abc');
  Assert.AreEqual<string>(FloatToStr(0.0, TFormatSettings.Invariant),
    FloatToStr(R.Confidence, TFormatSettings.Invariant),
    'Under 0.0 clamped to 0.0');
end;

procedure TTestIntentParser.Test_LLM_TimeoutAndIntentsPassedToBackend;
var
  CapturedTimeout: Integer;
  CapturedIntents: TArray<string>;
  CapturedLocale: string;
  R: TIntentResult;
begin
  FParser.LLMEnabled := True;
  FParser.LLMTimeoutMs := 2500;
  FParser.RegisterRule('hi', 'greet', nil, 10);
  FParser.RegisterRule('bye', 'farewell', nil, 20);
  FParser.RegisterLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      CapturedTimeout := TMs;
      CapturedLocale := L;
      CapturedIntents := Copy(RI);
      Result := '{"intent":"other","confidence":0.5}';
    end);
  R := FParser.Parse('howdy partner', 'en-US');
  Assert.AreEqual<string>('llm', R.Source);
  Assert.AreEqual<Integer>(2500, CapturedTimeout, 'timeout forwarded');
  Assert.AreEqual<string>('en-US', CapturedLocale, 'locale forwarded');
  Assert.AreEqual<Integer>(2, Length(CapturedIntents), 'rule intents hinted');
  // Intents list should contain 'greet' and 'farewell' in priority order
  Assert.AreEqual<string>('greet', CapturedIntents[0]);
  Assert.AreEqual<string>('farewell', CapturedIntents[1]);
end;

procedure TTestIntentParser.Test_LLM_GlobalBackendUsedWhenInstanceHasNone;
var R: TIntentResult;
begin
  TDeepBaseIntentParser.RegisterGlobalLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      Result := '{"intent":"from_global","confidence":0.7}';
    end);
  FParser.LLMEnabled := True;
  Assert.IsTrue(FParser.HasLLMBackend, 'global backend visible');
  R := FParser.Parse('whatever');
  Assert.AreEqual<string>('from_global', R.Intent);
  Assert.AreEqual<string>('llm', R.Source);
end;

procedure TTestIntentParser.Test_LLM_InstanceBackendOverridesGlobal;
var R: TIntentResult;
begin
  TDeepBaseIntentParser.RegisterGlobalLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      Result := '{"intent":"global","confidence":0.3}';
    end);
  FParser.LLMEnabled := True;
  FParser.RegisterLLMBackend(
    function(const T, L: string; TMs: Integer; const RI: TArray<string>): string
    begin
      Result := '{"intent":"instance","confidence":0.99}';
    end);
  R := FParser.Parse('whatever');
  Assert.AreEqual<string>('instance', R.Intent,
    'Instance backend must override global');
end;

procedure TTestIntentParser.Test_ConcurrentRegisterAndParse;
const
  CThreads = 8;
  CIters = 200;
type
  TWorkerProc = reference to procedure(AIdx: Integer; AErrors: TStringList; ALock: TCriticalSection);
var
  Tasks: array[0..CThreads - 1] of ITask;
  Errors: TStringList;
  Lock: TCriticalSection;
  I, Idx: Integer;
  Worker: TWorkerProc;
begin
  Worker := procedure(AIdx: Integer; AErrors: TStringList; ALock: TCriticalSection)
  var J: Integer; R: TIntentResult;
  begin
    for J := 0 to CIters - 1 do
    begin
      try
        if J mod 3 = 0 then
          FParser.RegisterRule(Format('pat_%d_%d', [AIdx, J]),
            Format('intent_%d', [AIdx]))
        else
        begin
          R := FParser.Parse(Format('pat_%d_%d text', [AIdx, J]));
          if (R.Source <> 'rule') and (R.Source <> '') and
             (R.Source <> 'llm_unsupported') and (R.Intent = '') then
          begin
            ALock.Enter;
            try
              AErrors.Add(Format('T%d iter %d: invalid state Source=%s Intent=%s',
                [AIdx, J, R.Source, R.Intent]));
            finally
              ALock.Leave;
            end;
          end;
        end;
      except
        on E: Exception do
        begin
          ALock.Enter;
          try
            AErrors.Add(Format('T%d iter %d: %s: %s',
              [AIdx, J, E.ClassName, E.Message]));
          finally
            ALock.Leave;
          end;
        end;
      end;
    end;
  end;

  Lock := TCriticalSection.Create;
  Errors := TStringList.Create;
  try
    for I := 0 to CThreads - 1 do
    begin
      Idx := I;
      Tasks[I] := TTask.Run(
        procedure
        begin
          Worker(Idx, Errors, Lock);
        end);
    end;
    TTask.WaitForAll(Tasks);
    Assert.AreEqual<Integer>(0, Errors.Count,
      'No exceptions or invalid state under concurrency: ' + Errors.Text);
  finally
    Errors.Free;
    Lock.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTestIntentParser);

end.
