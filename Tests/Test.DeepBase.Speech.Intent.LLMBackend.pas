{ ============================================================================
  Test.DeepBase.Speech.Intent.LLMBackend - Tests for the LLM adapter layer
  ============================================================================ }

unit Test.DeepBase.Speech.Intent.LLMBackend;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.Speech.Intent,
  DeepBase.Speech.Intent.LLMBackend;

type
  [TestFixture]
  TTestIntentLLMBackend = class
  private
    FParser: TDeepBaseIntentParser;
    /// <summary>Helper: build a JSON intent response string matching the
    /// contract that TDeepBaseIntentParser.Parse expects.</summary>
    function JsonIntent(const AIntent: string; AConf: Double;
      const AReason: string = ''): string;
  public
    [Setup]    procedure Setup;
    [TearDown] procedure TearDown;

    // Factory
    [Test] procedure Test_CreateBackend_NilChatFunc_Raises;
    [Test] procedure Test_CreateBackend_ValidChatFunc_ReturnsBackend;

    // Prompt construction
    [Test] procedure Test_BuildIntentPrompt_ContainsAllFields;
    [Test] procedure Test_BuildIntentPrompt_EmptyIntents_ContainsNone;

    // Backend delegation
    [Test] procedure Test_Backend_CallsChatFunc_WithCorrectTimeout;
    [Test] procedure Test_Backend_ReturnsChatFuncResponse_Verbatim;
    [Test] procedure Test_Backend_ChatFuncRaises_ExceptionPropagates;

    // Integration with TDeepBaseIntentParser
    [Test] procedure Test_Backend_IntegrationWithParser_LLMSource;
    [Test] procedure Test_Backend_IntegrationWithParser_InvalidJSON;
  end;

implementation

uses
  System.Math;

{ TTestIntentLLMBackend }

procedure TTestIntentLLMBackend.Setup;
begin
  FParser := TDeepBaseIntentParser.Create;
  // Reset global state from prior tests
  TDeepBaseIntentParser.RegisterGlobalLLMBackend(nil);
end;

procedure TTestIntentLLMBackend.TearDown;
begin
  TDeepBaseIntentParser.RegisterGlobalLLMBackend(nil);
  FreeAndNil(FParser);
end;

function TTestIntentLLMBackend.JsonIntent(const AIntent: string; AConf: Double;
  const AReason: string): string;
begin
  Result := Format('{"intent":"%s","confidence":%s,"reason":"%s"}',
    [AIntent, FloatToStr(AConf, TFormatSettings.Invariant), AReason]);
end;

// ---------------------------------------------------------------------------
// Factory tests
// ---------------------------------------------------------------------------

procedure TTestIntentLLMBackend.Test_CreateBackend_NilChatFunc_Raises;
begin
  Assert.WillRaise(
    procedure
    begin
      CreateIntentLLMBackend(nil);
    end,
    EArgumentException,
    'nil AChatFunc should raise EArgumentException');
end;

procedure TTestIntentLLMBackend.Test_CreateBackend_ValidChatFunc_ReturnsBackend;
var
  LBackend: TIntentLLMBackend;
  LChatFunc: TIntentChatFunc;
begin
  LChatFunc :=
    function(const APrompt: string; ATimeoutMs: Integer): string
    begin
      Result := '{}';
    end;
  LBackend := CreateIntentLLMBackend(LChatFunc);
  Assert.IsTrue(Assigned(LBackend),
    'CreateIntentLLMBackend with valid chat func must return a non-nil backend');
end;

// ---------------------------------------------------------------------------
// Prompt construction tests
// ---------------------------------------------------------------------------

procedure TTestIntentLLMBackend.Test_BuildIntentPrompt_ContainsAllFields;
var
  LPrompt: string;
  LIntents: TArray<string>;
begin
  LIntents := TArray<string>.Create('book_flight', 'play_music', 'set_alarm');
  LPrompt := BuildIntentPrompt('播放音乐', 'zh-CN', LIntents);

  // User text appears
  Assert.IsTrue(Pos('播放音乐', LPrompt) > 0,
    'Prompt must contain the user text');
  // Locale appears
  Assert.IsTrue(Pos('zh-CN', LPrompt) > 0,
    'Prompt must contain the locale');
  // All intents appear
  Assert.IsTrue(Pos('book_flight', LPrompt) > 0,
    'Prompt must contain intent "book_flight"');
  Assert.IsTrue(Pos('play_music', LPrompt) > 0,
    'Prompt must contain intent "play_music"');
  Assert.IsTrue(Pos('set_alarm', LPrompt) > 0,
    'Prompt must contain intent "set_alarm"');
  // JSON format instruction is present
  Assert.IsTrue(Pos('intent', LPrompt) > 0,
    'Prompt must mention "intent" key');
  Assert.IsTrue(Pos('confidence', LPrompt) > 0,
    'Prompt must mention "confidence" key');
end;

procedure TTestIntentLLMBackend.Test_BuildIntentPrompt_EmptyIntents_ContainsNone;
var
  LPrompt: string;
  LIntents: TArray<string>;
begin
  SetLength(LIntents, 0);
  LPrompt := BuildIntentPrompt('hello', 'en-US', LIntents);

  // Empty intent list should be rendered as "none"
  Assert.IsTrue(Pos('Available intents: none', LPrompt) > 0,
    'Empty intents list should produce "Available intents: none"');
end;

// ---------------------------------------------------------------------------
// Backend delegation tests
// ---------------------------------------------------------------------------

procedure TTestIntentLLMBackend.Test_Backend_CallsChatFunc_WithCorrectTimeout;
var
  LBackend: TIntentLLMBackend;
  LCapturedTimeout: Integer;
  LCapturedPrompt: string;
  LChatFunc: TIntentChatFunc;
  LResult: string;
begin
  LCapturedTimeout := -1;
  LCapturedPrompt := '';
  LChatFunc :=
    function(const APrompt: string; ATimeoutMs: Integer): string
    begin
      LCapturedTimeout := ATimeoutMs;
      LCapturedPrompt := APrompt;
      Result := '{}';
    end;
  LBackend := CreateIntentLLMBackend(LChatFunc);
  LResult := LBackend('hello', 'en-US', 3000,
    TArray<string>.Create('test_intent'));

  Assert.AreEqual<Integer>(3000, LCapturedTimeout,
    'Chat function should receive the timeout passed to the backend');
  Assert.IsTrue(LCapturedPrompt <> '',
    'Chat function should receive a non-empty prompt');
  // The prompt should contain the user text "hello"
  Assert.IsTrue(Pos('hello', LCapturedPrompt) > 0,
    'Prompt passed to chat func should contain the user text');
end;

procedure TTestIntentLLMBackend.Test_Backend_ReturnsChatFuncResponse_Verbatim;
var
  LBackend: TIntentLLMBackend;
  LExpectedJson: string;
  LChatFunc: TIntentChatFunc;
  LResult: string;
begin
  LExpectedJson := JsonIntent('book_flight', 0.95, 'user wants to book');
  LChatFunc :=
    function(const APrompt: string; ATimeoutMs: Integer): string
    begin
      Result := LExpectedJson;
    end;
  LBackend := CreateIntentLLMBackend(LChatFunc);
  LResult := LBackend('book a flight', 'en-US', 5000,
    TArray<string>.Create('book_flight'));

  Assert.AreEqual(LExpectedJson, LResult,
    'Backend must return the chat function response verbatim');
end;

procedure TTestIntentLLMBackend.Test_Backend_ChatFuncRaises_ExceptionPropagates;
var
  LBackend: TIntentLLMBackend;
  LChatFunc: TIntentChatFunc;
begin
  LChatFunc :=
    function(const APrompt: string; ATimeoutMs: Integer): string
    begin
      raise EAbort.Create('LLM service unavailable');
    end;
  LBackend := CreateIntentLLMBackend(LChatFunc);

  Assert.WillRaise(
    procedure
    begin
      LBackend('test', 'en-US', 5000, TArray<string>.Create('x'));
    end,
    EAbort);
end;

// ---------------------------------------------------------------------------
// Integration tests with TDeepBaseIntentParser
// ---------------------------------------------------------------------------

procedure TTestIntentLLMBackend.Test_Backend_IntegrationWithParser_LLMSource;
var
  LBackend: TIntentLLMBackend;
  LChatFunc: TIntentChatFunc;
  LResult: TIntentResult;
  LJson: string;
begin
  // Build a valid JSON response
  LJson := JsonIntent('book_flight', 0.9, 'user wants to book a flight');
  LChatFunc :=
    function(const APrompt: string; ATimeoutMs: Integer): string
    begin
      Result := LJson;
    end;
  LBackend := CreateIntentLLMBackend(LChatFunc);

  // Register as instance backend and enable LLM
  FParser.RegisterLLMBackend(LBackend);
  FParser.LLMEnabled := True;

  // No rule should match, so parser falls through to LLM
  LResult := FParser.Parse('I want to book a flight to Tokyo', 'en-US');

  Assert.AreEqual('llm', LResult.Source,
    'Parser should use LLM source when no rule matches and backend is registered');
  Assert.AreEqual('book_flight', LResult.Intent,
    'Intent should match the JSON response from the LLM');
  Assert.AreEqual<string>(FloatToStr(0.9, TFormatSettings.Invariant),
    FloatToStr(LResult.Confidence, TFormatSettings.Invariant),
    'Confidence should match the JSON response');
end;

procedure TTestIntentLLMBackend.Test_Backend_IntegrationWithParser_InvalidJSON;
var
  LBackend: TIntentLLMBackend;
  LChatFunc: TIntentChatFunc;
  LResult: TIntentResult;
begin
  LChatFunc :=
    function(const APrompt: string; ATimeoutMs: Integer): string
    begin
      Result := 'not json';
    end;
  LBackend := CreateIntentLLMBackend(LChatFunc);

  FParser.RegisterLLMBackend(LBackend);
  FParser.LLMEnabled := True;

  LResult := FParser.Parse('random text', 'en-US');

  // TDeepBaseIntentParser.Parse treats unparseable JSON as intent='unknown'
  Assert.AreEqual('unknown', LResult.Intent,
    'Invalid JSON from LLM should result in intent="unknown"');
  Assert.AreEqual('llm', LResult.Source,
    'Source should still be "llm" (backend was invoked)');
end;

end.
