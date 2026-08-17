unit Test.DeepBase.IntentClarification;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.IntentClarification,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types;

type
  [TestFixture]
  TIntentClarificationTests = class
  public
    [Test]
    procedure Test_Rule_MissingRequiredSlot_AsksQuestionWithOptions;

    [Test]
    procedure Test_Rule_AllRequiredSlotsFilled_IsReady;

    [Test]
    procedure Test_ApplyOptionAnswer_FillsSlotValue;

    [Test]
    procedure Test_LLM_JsonClarification_IsParsed;

    [Test]
    procedure Test_LLM_BadJson_FallsBackToRules;
  end;

implementation

type
  TFakeClarificationLLM = class(TInterfacedObject, ILLMClient)
  public
    Response: TChatResult;
    LastTier: TModelTier;
    LastSystemPrompt: string;
    LastUserPrompt: string;
    Calls: Integer;

    function Chat(const ATier: TModelTier;
      const AUserPrompt: string): TChatResult; overload;
    function Chat(const ATier: TModelTier;
      const ASystemPrompt, AUserPrompt: string): TChatResult; overload;
    function ChatWithHistory(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    function ChatWithHistoryByProvider(const AProviderName, AModelId: string;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    procedure ChatStream(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>; AOnChunk: TProc<string>;
      AOnError: TProc<string>; AMaxTokens: Integer = 0);
    function ChatVision(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string = ''): TChatResult;
    function GenerateImage(const APrompt: string;
      const ASize: string = '1024x1024'): TImageGenerationResult;
    procedure GenerateImageStream(const APrompt: string;
      const AOnProgress: TImageProgressCallback;
      const AOnResult: TProc<TImageGenerationResult>;
      const AOnError: TProc<string>;
      const ASize: string = '1024x1024');
    procedure ChatVisionStream(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
    function GetModelForTier(const ATier: TModelTier): string;
    function CallCount: Integer;
    function LastDurationMs: Integer;
  end;

function BuildPlanningRequest: TIntentClarificationRequest;
begin
  Result.Init;
  Result.IntentName := 'create_plan';
  Result.UserText := 'Help me plan tomorrow';

  SetLength(Result.Slots, 2);
  Result.Slots[0].Init;
  Result.Slots[0].Name := 'time_range';
  Result.Slots[0].DisplayName := 'time range';
  Result.Slots[0].Required := True;
  Result.Slots[0].Question := 'Which time range should the plan cover?';
  Result.Slots[0].Options := [
    TIntentClarificationOption.Create('A', 'Morning', 'morning'),
    TIntentClarificationOption.Create('B', 'Afternoon', 'afternoon')
  ];

  Result.Slots[1].Init;
  Result.Slots[1].Name := 'topic';
  Result.Slots[1].DisplayName := 'topic';
  Result.Slots[1].Required := True;
  Result.Slots[1].Value := 'work';
  Result.Slots[1].Confidence := 0.9;
end;

{ TFakeClarificationLLM }

function TFakeClarificationLLM.Chat(const ATier: TModelTier;
  const AUserPrompt: string): TChatResult;
begin
  Result := Chat(ATier, '', AUserPrompt);
end;

function TFakeClarificationLLM.Chat(const ATier: TModelTier;
  const ASystemPrompt, AUserPrompt: string): TChatResult;
begin
  Inc(Calls);
  LastTier := ATier;
  LastSystemPrompt := ASystemPrompt;
  LastUserPrompt := AUserPrompt;
  Result := Response;
end;

function TFakeClarificationLLM.ChatWithHistory(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double): TChatResult;
begin
  Inc(Calls);
  LastTier := ATier;
  Result := Response;
end;

function TFakeClarificationLLM.ChatWithHistoryByProvider(
  const AProviderName, AModelId: string;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double): TChatResult;
begin
  Inc(Calls);
  Result := Response;
end;

procedure TFakeClarificationLLM.ChatStream(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>; AOnChunk, AOnError: TProc<string>;
  AMaxTokens: Integer);
begin
end;

function TFakeClarificationLLM.ChatVision(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt,
  ASystemPrompt: string): TChatResult;
begin
  Inc(Calls);
  LastTier := ATier;
  Result := Response;
end;

function TFakeClarificationLLM.GenerateImage(const APrompt,
  ASize: string): TImageGenerationResult;
begin
  Result := Default(TImageGenerationResult);
end;

procedure TFakeClarificationLLM.GenerateImageStream(const APrompt: string;
  const AOnProgress: TImageProgressCallback;
  const AOnResult: TProc<TImageGenerationResult>;
  const AOnError: TProc<string>;
  const ASize: string);
var
  LResult: TImageGenerationResult;
begin
  Inc(Calls);
  if Assigned(AOnProgress) then
    AOnProgress(1.0, 'complete', True);

  LResult := GenerateImage(APrompt, ASize);
  if Assigned(AOnResult) then
    AOnResult(LResult);
end;

procedure TFakeClarificationLLM.ChatVisionStream(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt, ASystemPrompt: string;
  AOnChunk, AOnError: TProc<string>; AMaxTokens: Integer);
begin
end;

function TFakeClarificationLLM.GetModelForTier(
  const ATier: TModelTier): string;
begin
  Result := string(ATier);
end;

function TFakeClarificationLLM.CallCount: Integer;
begin
  Result := Calls;
end;

function TFakeClarificationLLM.LastDurationMs: Integer;
begin
  Result := Response.DurationMs;
end;

{ TIntentClarificationTests }

procedure TIntentClarificationTests.Test_Rule_MissingRequiredSlot_AsksQuestionWithOptions;
var
  Clarifier: TIntentClarifier;
  Policy: TIntentClarificationPolicy;
  Request: TIntentClarificationRequest;
  Clarification: TIntentClarificationResult;
begin
  Request := BuildPlanningRequest;
  Clarifier := TIntentClarifier.Create;
  try
    Policy := Clarifier.Policy;
    Policy.UseLLM := False;
    Clarifier.Policy := Policy;

    Clarification := Clarifier.Clarify(Request);

    Assert.AreEqual<Integer>(Ord(icsNeedsClarification),
      Ord(Clarification.Status));
    Assert.AreEqual('time_range', Clarification.MissingSlots[0]);
    Assert.AreEqual('Which time range should the plan cover?',
      Clarification.Question);
    Assert.AreEqual<Integer>(2, Length(Clarification.Options));
    Assert.AreEqual('morning', Clarification.Options[0].Value);
    Assert.AreEqual<Integer>(Ord(csmSingleChoice),
      Ord(Clarification.SelectionMode));
    Assert.AreEqual('rule', Clarification.Source);
  finally
    Clarifier.Free;
  end;
end;

procedure TIntentClarificationTests.Test_Rule_AllRequiredSlotsFilled_IsReady;
var
  Clarifier: TIntentClarifier;
  Policy: TIntentClarificationPolicy;
  Request: TIntentClarificationRequest;
  Clarification: TIntentClarificationResult;
begin
  Request := BuildPlanningRequest;
  Request.Slots[0].Value := 'morning';
  Request.Slots[0].Confidence := 0.8;

  Clarifier := TIntentClarifier.Create;
  try
    Policy := Clarifier.Policy;
    Policy.UseLLM := False;
    Clarifier.Policy := Policy;

    Clarification := Clarifier.Clarify(Request);

    Assert.AreEqual<Integer>(Ord(icsReady), Ord(Clarification.Status));
    Assert.IsTrue(Clarification.IsReady);
    Assert.AreEqual<Integer>(0, Length(Clarification.MissingSlots));
    Assert.IsTrue(Clarification.Confidence >= 0.8);
  finally
    Clarifier.Free;
  end;
end;

procedure TIntentClarificationTests.Test_ApplyOptionAnswer_FillsSlotValue;
var
  Request: TIntentClarificationRequest;
  Updated: TIntentClarificationRequest;
begin
  Request := BuildPlanningRequest;

  Assert.IsTrue(TIntentClarifier.ApplyOptionAnswer(Request, 'time_range',
    'B', Updated));
  Assert.AreEqual('afternoon', Updated.Slots[0].Value);
  Assert.AreEqual(1.0, Updated.Slots[0].Confidence, 0.0001);
  Assert.AreEqual('', Request.Slots[0].Value,
    'ApplyOptionAnswer must not mutate the original request');
end;

procedure TIntentClarificationTests.Test_LLM_JsonClarification_IsParsed;
var
  Fake: TFakeClarificationLLM;
  Client: ILLMClient;
  Clarifier: TIntentClarifier;
  Request: TIntentClarificationRequest;
  Clarification: TIntentClarificationResult;
begin
  Fake := TFakeClarificationLLM.Create;
  Fake.Response.Success := True;
  Fake.Response.Content :=
    '{"intent":"create_plan","confidence":0.82,' +
    '"needs_clarification":true,' +
    '"question":"Do you mean morning or afternoon?",' +
    '"selection_mode":"single_choice",' +
    '"missing_slots":["time_range"],' +
    '"options":[{"code":"A","text":"Morning","value":"morning"}],' +
    '"slots":[{"name":"topic","value":"work","confidence":0.9}]}';
  Client := Fake as ILLMClient;

  Request := BuildPlanningRequest;
  Clarifier := TIntentClarifier.Create(Client);
  try
    Clarification := Clarifier.Clarify(Request);

    Assert.AreEqual<Integer>(1, Fake.Calls);
    Assert.AreEqual(string(TierFast), string(Fake.LastTier));
    Assert.AreEqual<Integer>(Ord(icsNeedsClarification),
      Ord(Clarification.Status));
    Assert.AreEqual('llm', Clarification.Source);
    Assert.AreEqual('Do you mean morning or afternoon?',
      Clarification.Question);
    Assert.AreEqual<Integer>(1, Length(Clarification.Options));
    Assert.AreEqual('morning', Clarification.Options[0].Value);
  finally
    Clarifier.Free;
  end;
end;

procedure TIntentClarificationTests.Test_LLM_BadJson_FallsBackToRules;
var
  Fake: TFakeClarificationLLM;
  Client: ILLMClient;
  Clarifier: TIntentClarifier;
  Request: TIntentClarificationRequest;
  Clarification: TIntentClarificationResult;
begin
  Fake := TFakeClarificationLLM.Create;
  Fake.Response.Success := True;
  Fake.Response.Content := 'not json';
  Client := Fake as ILLMClient;

  Request := BuildPlanningRequest;
  Clarifier := TIntentClarifier.Create(Client);
  try
    Clarification := Clarifier.Clarify(Request);

    Assert.AreEqual<Integer>(Ord(icsNeedsClarification),
      Ord(Clarification.Status));
    Assert.AreEqual('rule_fallback', Clarification.Source);
    Assert.AreEqual('bad_llm_json', Clarification.ErrorCode);
    Assert.AreEqual('Which time range should the plan cover?',
      Clarification.Question);
  finally
    Clarifier.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TIntentClarificationTests);

end.
