{ ============================================================================
  Test.DeepBase.IntentClarification.Integration - Integration Test Skeleton

  DUnitX test class that verifies the full IntentClarification module
  integration with DeepBase infrastructure:
    - Engine creation via IoC container
    - Full session lifecycle (start -> submit x3 -> cancel)
    - State machine transitions
    - Metrics recording
    - Feature config
    - Template validation

  Phase 2 Task 29: Integration Tests
  Requirements: 29.1, 29.2
  ============================================================================ }

unit Test.DeepBase.IntentClarification.Integration;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.IoC,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.IntentClarification.Engine,
  DeepBase.IntentClarification.IoC,
  DeepBase.IntentClarification.SessionFSM,
  DeepBase.IntentClarification.LLMResilience,
  DeepBase.IntentClarification.Metrics,
  DeepBase.IntentClarification.FeatureConfig,
  DeepBase.IntentClarification.Validation,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types;

type
  /// <summary>
  /// Mock LLM client for integration testing.
  /// Can be configured to succeed, fail, or timeout.
  /// </summary>
  TMockLLMClient = class(TInterfacedObject, ILLMClient)
  private
    FCallCount: Integer;
    FShouldFail: Boolean;
    FFailAfterN: Integer;
    FDelayMs: Integer;
  public
    constructor Create;

    // ILLMClient
    function Chat(const ATier: TModelTier; const AUserPrompt: string): TChatResult; overload;
    function Chat(const ATier: TModelTier; const ASystemPrompt, AUserPrompt: string): TChatResult; overload;
    function ChatWithHistory(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    procedure ChatStream(const ATier: TModelTier;
      const AMessages: TArray<TChatMessage>;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
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

    property MockCallCount: Integer read FCallCount;
    property ShouldFail: Boolean read FShouldFail write FShouldFail;
    property FailAfterN: Integer read FFailAfterN write FFailAfterN;
    property DelayMs: Integer read FDelayMs write FDelayMs;
  end;

  [TestFixture]
  TICIntegrationTest = class
  private
    FContainer: TIoCContainer;
    FEngine: IClarificationEngine;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_IoC_CreatesEngine;

    [Test]
    procedure Test_FullSessionLifecycle;

    [Test]
    procedure Test_SessionStateTransitions;

    [Test]
    procedure Test_MultipleSubmits;

    [Test]
    procedure Test_CancelSession;

    [Test]
    procedure Test_MetricsRecorded;

    [Test]
    procedure Test_FeatureConfig_DisablesLevels;

    [Test]
    procedure Test_TemplateValidation;

    [Test]
    procedure Test_DomainAdapterPresetSlotsReachL1Provider;

    [Test]
    procedure Test_L4_AllFailures_ReturnsDegradedFailure;
  end;

  [TestFixture]
  TICResilienceIntegrationTest = class
  private
    FMockLLM: TMockLLMClient;
    FWrapper: TResilientLLMWrapper;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_RetryOnFailure;

    [Test]
    procedure Test_CircuitBreakerOpens;

    [Test]
    procedure Test_CircuitBreakerRecovery;
  end;

  [TestFixture]
  TICSessionFSMTest = class
  public
    [Test]
    procedure Test_ValidTransitions;

    [Test]
    procedure Test_InvalidTransition;

    [Test]
    procedure Test_SubmitIsInternal;

    [Test]
    procedure Test_TimeoutSuspends;
  end;

implementation

uses
  DeepBase.IntentClarification,
  DeepBase.IntentClarification.Provider.L4;

type
  TSlotDomainAdapter = class(TInterfacedObject, IDomainAdapter)
  public
    function GetDomainName: string;
    function GetMaxLevel: TClarificationLevel;
    function GetContextForSession(const ASessionId: string): TDomainContext;
    function GetDomainKnowledge(const ATopic: string): string;
    function GetPresetSlots(const AIntentName: string): TArray<TIntentClarificationSlot>;
  end;

  TSlotSpyProvider = class(TInterfacedObject, ILevelProvider)
  private
    FCapturedSlotCount: Integer;
    FCapturedSlotName: string;
    FCapturedSlotDisplayName: string;
    FCapturedSlotQuestion: string;
    FCapturedSlotRequired: Boolean;
  public
    function GetLevel: TClarificationLevel;
    function CanHandle(const AContext: TProcessingContext): Boolean;
    function Process(const AContext: TProcessingContext): TProviderResult;
    function RequiresLLM: Boolean;

    property CapturedSlotCount: Integer read FCapturedSlotCount;
    property CapturedSlotName: string read FCapturedSlotName;
    property CapturedSlotDisplayName: string read FCapturedSlotDisplayName;
    property CapturedSlotQuestion: string read FCapturedSlotQuestion;
    property CapturedSlotRequired: Boolean read FCapturedSlotRequired;
  end;

{ TSlotDomainAdapter }

function TSlotDomainAdapter.GetDomainName: string;
begin
  Result := 'slot-test-domain';
end;

function TSlotDomainAdapter.GetMaxLevel: TClarificationLevel;
begin
  Result := clL1;
end;

function TSlotDomainAdapter.GetContextForSession(
  const ASessionId: string): TDomainContext;
begin
  Result := Default(TDomainContext);
  Result.DomainName := GetDomainName;
  Result.SessionId := ASessionId;
  Result.ActiveIntent := 'launch-report';
  Result.ContextSummary := 'Slot injection regression context';
end;

function TSlotDomainAdapter.GetDomainKnowledge(const ATopic: string): string;
begin
  Result := '';
end;

function TSlotDomainAdapter.GetPresetSlots(
  const AIntentName: string): TArray<TIntentClarificationSlot>;
begin
  if AIntentName <> 'launch-report' then
    Exit(nil);

  SetLength(Result, 1);
  Result[0].Init;
  Result[0].Name := 'target';
  Result[0].DisplayName := 'Target';
  Result[0].Required := True;
  Result[0].Question := 'Which report target should be used?';
end;

{ TSlotSpyProvider }

function TSlotSpyProvider.GetLevel: TClarificationLevel;
begin
  Result := clL1;
end;

function TSlotSpyProvider.CanHandle(const AContext: TProcessingContext): Boolean;
begin
  Result := True;
end;

function TSlotSpyProvider.Process(const AContext: TProcessingContext): TProviderResult;
begin
  FCapturedSlotCount := Length(AContext.PresetSlots);
  if FCapturedSlotCount > 0 then
  begin
    FCapturedSlotName := AContext.PresetSlots[0].Name;
    FCapturedSlotDisplayName := AContext.PresetSlots[0].DisplayName;
    FCapturedSlotQuestion := AContext.PresetSlots[0].Question;
    FCapturedSlotRequired := AContext.PresetSlots[0].Required;
  end;

  Result := Default(TProviderResult);
  Result.Success := True;
  Result.Question := 'slot spy handled';
  Result.Source := 'rule';
end;

function TSlotSpyProvider.RequiresLLM: Boolean;
begin
  Result := False;
end;

{ TMockLLMClient }

constructor TMockLLMClient.Create;
begin
  inherited Create;
  FCallCount := 0;
  FShouldFail := False;
  FFailAfterN := 0;
  FDelayMs := 0;
end;

function TMockLLMClient.Chat(const ATier: TModelTier;
  const AUserPrompt: string): TChatResult;
begin
  Inc(FCallCount);
  Result := Default(TChatResult);

  if FDelayMs > 0 then
    Sleep(FDelayMs);

  if FShouldFail or ((FFailAfterN > 0) and (FCallCount > FFailAfterN)) then
  begin
    Result.Success := False;
    Result.Content := '';
    Result.FinishReason := 'mock_failure';
  end
  else
  begin
    Result.Success := True;
    Result.Content := Format('Mock response #%d to: %s', [FCallCount, AUserPrompt]);
    Result.FinishReason := 'stop';
    Result.PromptTokens := 10;
    Result.CompletionTokens := 20;
    Result.TotalTokens := 30;
  end;
end;

function TMockLLMClient.Chat(const ATier: TModelTier;
  const ASystemPrompt, AUserPrompt: string): TChatResult;
begin
  Result := Chat(ATier, AUserPrompt);
end;

function TMockLLMClient.ChatWithHistory(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>;
  AMaxTokens: Integer; ATemperature: Double): TChatResult;
begin
  Result := Chat(ATier, 'history-call');
end;

procedure TMockLLMClient.ChatStream(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>;
  AOnChunk: TProc<string>; AOnError: TProc<string>;
  AMaxTokens: Integer);
begin
  Inc(FCallCount);
  if FShouldFail then
  begin
    if Assigned(AOnError) then
      AOnError('Mock stream failure');
  end
  else
  begin
    if Assigned(AOnChunk) then
      AOnChunk('Mock stream chunk');
  end;
end;

function TMockLLMClient.ChatVision(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt: string;
  const ASystemPrompt: string): TChatResult;
begin
  Result := Chat(ATier, AUserPrompt);
end;

function TMockLLMClient.GenerateImage(const APrompt: string;
  const ASize: string): TImageGenerationResult;
begin
  Result := Default(TImageGenerationResult);
  Result.Success := not FShouldFail;
end;

procedure TMockLLMClient.GenerateImageStream(const APrompt: string;
  const AOnProgress: TImageProgressCallback;
  const AOnResult: TProc<TImageGenerationResult>;
  const AOnError: TProc<string>;
  const ASize: string);
var
  LResult: TImageGenerationResult;
begin
  Inc(FCallCount);
  if FShouldFail then
  begin
    if Assigned(AOnError) then
      AOnError('Mock image generation failure');
    Exit;
  end;

  if Assigned(AOnProgress) then
    AOnProgress(1.0, 'complete', True);

  LResult := Default(TImageGenerationResult);
  LResult.Success := True;
  if Assigned(AOnResult) then
    AOnResult(LResult);
end;

procedure TMockLLMClient.ChatVisionStream(const ATier: TModelTier;
  const AImageBase64, AImageMimeType, AUserPrompt, ASystemPrompt: string;
  AOnChunk: TProc<string>; AOnError: TProc<string>;
  AMaxTokens: Integer);
begin
  ChatStream(ATier, nil, AOnChunk, AOnError, AMaxTokens);
end;

function TMockLLMClient.GetModelForTier(const ATier: TModelTier): string;
begin
  Result := 'mock-model';
end;

function TMockLLMClient.CallCount: Integer;
begin
  Result := FCallCount;
end;

function TMockLLMClient.LastDurationMs: Integer;
begin
  Result := 0;
end;

{ TICIntegrationTest }

procedure TICIntegrationTest.Setup;
begin
  FContainer := TIoCContainer.Create;
  TICIoCRegistration.RegisterAll(FContainer);
  FEngine := TICIoCRegistration.CreateEngineFromContainer(FContainer);
end;

procedure TICIntegrationTest.TearDown;
begin
  FEngine := nil;
  FreeAndNil(FContainer);
end;

procedure TICIntegrationTest.Test_IoC_CreatesEngine;
begin
  Assert.IsNotNull(FEngine);
end;

procedure TICIntegrationTest.Test_FullSessionLifecycle;
var
  LRequest: TClarificationStartRequest;
  LHandle: TSessionHandle;
  LResult: TTurnResult;
  LCancelResult: TCancelResult;
  I: Integer;
begin
  // Start session
  LRequest := Default(TClarificationStartRequest);
  LRequest.UserId := 'test-user';
  LRequest.DomainName := 'test-domain';
  LRequest.IntentName := 'test-intent';

  LHandle := FEngine.StartSession(LRequest);
  Assert.IsNotEmpty(LHandle.Id);

  // Submit 3 inputs
  for I := 1 to 3 do
  begin
    LResult := FEngine.SubmitInput(LHandle, Format('test input %d', [I]));
    Assert.AreEqual('', LResult.ErrorCode);
    Assert.AreEqual(I, LResult.TurnNumber);
    Assert.AreEqual(Ord(ssActive), Ord(LResult.Status));
  end;

  // Cancel
  LCancelResult := FEngine.CancelSession(LHandle);
  Assert.IsTrue(LCancelResult.Success);

  // Verify state is completed
  var LState := FEngine.GetSessionState(LHandle);
  Assert.AreEqual(Ord(ssCompleted), Ord(LState.Status));
end;

procedure TICIntegrationTest.Test_SessionStateTransitions;
var
  LRequest: TClarificationStartRequest;
  LHandle: TSessionHandle;
  LState: TSessionState;
  LSuspendResult: TSuspendResult;
  LResumeResult: TResumeResult;
begin
  LRequest := Default(TClarificationStartRequest);
  LRequest.UserId := 'user-fsm';
  LRequest.DomainName := 'domain';

  LHandle := FEngine.StartSession(LRequest);

  // Verify initial state is Active
  LState := FEngine.GetSessionState(LHandle);
  Assert.AreEqual(Ord(ssActive), Ord(LState.Status));

  // Active -> Suspended
  LSuspendResult := FEngine.SuspendSession(LHandle);
  Assert.IsTrue(LSuspendResult.Success);
  LState := FEngine.GetSessionState(LHandle);
  Assert.AreEqual(Ord(ssSuspended), Ord(LState.Status));

  // Suspended -> Active (Resume)
  LResumeResult := FEngine.ResumeSession(LHandle);
  Assert.IsTrue(LResumeResult.Success);
  LState := FEngine.GetSessionState(LHandle);
  Assert.AreEqual(Ord(ssActive), Ord(LState.Status));
end;

procedure TICIntegrationTest.Test_MultipleSubmits;
var
  LRequest: TClarificationStartRequest;
  LHandle: TSessionHandle;
  LResult: TTurnResult;
begin
  LRequest := Default(TClarificationStartRequest);
  LRequest.UserId := 'user-multi';
  LRequest.DomainName := 'domain';

  LHandle := FEngine.StartSession(LRequest);

  LResult := FEngine.SubmitInput(LHandle, 'first');
  Assert.AreEqual(1, LResult.TurnNumber);

  LResult := FEngine.SubmitInput(LHandle, 'second');
  Assert.AreEqual(2, LResult.TurnNumber);

  LResult := FEngine.SubmitInput(LHandle, 'third');
  Assert.AreEqual(3, LResult.TurnNumber);
end;

procedure TICIntegrationTest.Test_CancelSession;
var
  LRequest: TClarificationStartRequest;
  LHandle: TSessionHandle;
  LResult: TTurnResult;
begin
  LRequest := Default(TClarificationStartRequest);
  LRequest.UserId := 'user-cancel';
  LRequest.DomainName := 'domain';

  LHandle := FEngine.StartSession(LRequest);

  // Input "0" triggers exit (Property 4)
  LResult := FEngine.SubmitInput(LHandle, '0');
  Assert.AreEqual(Ord(ssCompleted), Ord(LResult.Status));
end;

procedure TICIntegrationTest.Test_MetricsRecorded;
var
  LMetrics: TICMetrics;
begin
  LMetrics := TICMetrics.Create;
  try
    Assert.AreEqual(Int64(0), LMetrics.TurnCount);

    LMetrics.RecordTurn(50, clL1, posClarifying, 100);
    Assert.AreEqual(Int64(1), LMetrics.TurnCount);
    Assert.AreEqual(Int64(100), LMetrics.TotalTokensUsed);

    LMetrics.RecordTurn(120, clL2, posExploring, 250);
    Assert.AreEqual(Int64(2), LMetrics.TurnCount);
    Assert.AreEqual(Int64(350), LMetrics.TotalTokensUsed);
    Assert.AreEqual(Int64(120), LMetrics.MaxLatencyMs);

    LMetrics.RecordSessionCompleted('user_cancel');
    Assert.AreEqual(Int64(1), LMetrics.SessionsCompleted);

    // Average latency
    Assert.IsTrue(LMetrics.AverageLatencyMs > 0);
  finally
    LMetrics.Free;
  end;
end;

procedure TICIntegrationTest.Test_FeatureConfig_DisablesLevels;
var
  LConfig: TICFeatureConfig;
begin
  LConfig := TICFeatureConfig.Create;
  try
    // Default: all enabled
    Assert.IsTrue(LConfig.IsLevelEnabled(clL0));
    Assert.IsTrue(LConfig.IsLevelEnabled(clL1));
    Assert.IsTrue(LConfig.IsLevelEnabled(clL2));
    Assert.IsTrue(LConfig.IsLevelEnabled(clL3));
    Assert.IsTrue(LConfig.IsLevelEnabled(clL4));
    Assert.AreEqual(Ord(clL4), Ord(LConfig.GetEffectiveMaxLevel));

    // Disable L4
    LConfig.EnableL4 := False;
    Assert.IsFalse(LConfig.IsLevelEnabled(clL4));
    Assert.IsTrue(LConfig.IsLevelEnabled(clL3));
    Assert.AreEqual(Ord(clL3), Ord(LConfig.GetEffectiveMaxLevel));

    // Disable L3 too
    LConfig.EnableL3 := False;
    Assert.IsFalse(LConfig.IsLevelEnabled(clL3));
    Assert.AreEqual(Ord(clL2), Ord(LConfig.GetEffectiveMaxLevel));

    // L0-L2 always enabled regardless
    Assert.IsTrue(LConfig.IsLevelEnabled(clL0));
    Assert.IsTrue(LConfig.IsLevelEnabled(clL1));
    Assert.IsTrue(LConfig.IsLevelEnabled(clL2));
  finally
    LConfig.Free;
  end;
end;

procedure TICIntegrationTest.Test_TemplateValidation;
var
  LValidator: TICTemplateValidator;
  LTemplate: TPresetTemplate;
  LResult: TICValidationResult;
  LFields: TArray<string>;
begin
  LValidator := TICTemplateValidator.Create;
  try
    // Valid template should pass
    LTemplate := TPresetTemplate.ToolCommand;
    LResult := LValidator.Validate(LTemplate);
    Assert.IsTrue(LResult.IsValid, 'ToolCommand template should be valid');

    LTemplate := TPresetTemplate.CreativeAssistant;
    LResult := LValidator.Validate(LTemplate);
    Assert.IsTrue(LResult.IsValid, 'CreativeAssistant template should be valid');

    LTemplate := TPresetTemplate.DecisionAdvisor;
    LResult := LValidator.Validate(LTemplate);
    Assert.IsTrue(LResult.IsValid, 'DecisionAdvisor template should be valid');

    // Invalid template (empty fields)
    LTemplate := Default(TPresetTemplate);
    LTemplate.Name := '';
    LTemplate.Style := '';
    LTemplate.BudgetConfig.MaxTurns := 0;
    LTemplate.BudgetConfig.MaxTimeSeconds := 0;
    LResult := LValidator.Validate(LTemplate);
    Assert.IsFalse(LResult.IsValid);

    // Check field names are reported
    LFields := LResult.GetMissingFields;
    Assert.IsTrue(Length(LFields) >= 3, 'Should report at least 3 invalid fields');
  finally
    LValidator.Free;
  end;
end;

procedure TICIntegrationTest.Test_DomainAdapterPresetSlotsReachL1Provider;
var
  LEngine: IClarificationEngine;
  LAdapter: IDomainAdapter;
  LProvider: ILevelProvider;
  LSpy: TSlotSpyProvider;
  LRequest: TClarificationStartRequest;
  LHandle: TSessionHandle;
  LTurn: TTurnResult;
begin
  LEngine := TClarificationEngine.Create;
  LAdapter := TSlotDomainAdapter.Create;
  LSpy := TSlotSpyProvider.Create;
  LProvider := LSpy;

  LEngine.SetDomainAdapter(LAdapter);
  LEngine.RegisterProvider(LProvider);

  LRequest := Default(TClarificationStartRequest);
  LRequest.UserId := 'slot-user';
  LRequest.DomainName := 'slot-test-domain';
  LRequest.IntentName := 'launch-report';

  LHandle := LEngine.StartSession(LRequest);
  LTurn := LEngine.SubmitInput(LHandle, 'please build the report');

  Assert.AreEqual('', LTurn.ErrorCode);
  Assert.AreEqual(1, LTurn.TurnNumber);
  Assert.AreEqual(1, LSpy.CapturedSlotCount);
  Assert.AreEqual('target', LSpy.CapturedSlotName);
  Assert.AreEqual('Target', LSpy.CapturedSlotDisplayName);
  Assert.AreEqual('Which report target should be used?', LSpy.CapturedSlotQuestion);
  Assert.IsTrue(LSpy.CapturedSlotRequired);
end;

procedure TICIntegrationTest.Test_L4_AllFailures_ReturnsDegradedFailure;
var
  LMockLLM: TMockLLMClient;
  LLLM: ILLMClient;
  LProvider: ILevelProvider;
  LContext: TProcessingContext;
  LResult: TProviderResult;
begin
  LMockLLM := TMockLLMClient.Create;
  LMockLLM.ShouldFail := True;
  LLLM := LMockLLM;
  LProvider := TL4RoundtableProvider.Create(LLLM, nil);

  LContext := Default(TProcessingContext);
  LContext.SessionId := 'l4-fail-session';
  LContext.UserInput := 'Compare the execution risks for this decision.';
  LContext.Level := clL4;
  LContext.Posture := posAdvisory;
  LContext.Depth := 0.9;
  LContext.DomainContext.DomainName := 'decision';
  LContext.DomainContext.ActiveIntent := 'roundtable';

  LResult := LProvider.Process(LContext);

  Assert.IsFalse(LResult.Success);
  Assert.IsTrue(LResult.ErrorMessage <> '');
  Assert.IsTrue(Pos('all ', LResult.ErrorMessage) > 0);
  Assert.IsTrue(LResult.Question <> '');
  Assert.AreEqual<Integer>(1, Length(LResult.Options));
  Assert.AreEqual<Integer>(1, LResult.RecommendedOption);
end;

{ TICResilienceIntegrationTest }

procedure TICResilienceIntegrationTest.Setup;
var
  LIntf: ILLMClient;
begin
  FMockLLM := TMockLLMClient.Create;
  LIntf := FMockLLM;
  FWrapper := TResilientLLMWrapper.Create(LIntf);
end;

procedure TICResilienceIntegrationTest.TearDown;
begin
  FreeAndNil(FWrapper);
  // FMockLLM prevented from double-free by interface ref
end;

procedure TICResilienceIntegrationTest.Test_RetryOnFailure;
var
  LResponse: TChatResult;
  LConfig: TLLMResilienceConfig;
begin
  // Configure: all calls fail
  FMockLLM.ShouldFail := True;

  LConfig := TLLMResilienceConfig.Default;
  LConfig.MaxRetries := 2;
  FWrapper.Config := LConfig;

  LResponse := FWrapper.Chat(TierBalanced, 'test prompt');

  // All 3 attempts should fail (1 + 2 retries)
  Assert.IsFalse(LResponse.Success);
  Assert.AreEqual(3, FMockLLM.MockCallCount);
end;

procedure TICResilienceIntegrationTest.Test_CircuitBreakerOpens;
var
  LResponse: TChatResult;
  LConfig: TLLMResilienceConfig;
  I: Integer;
begin
  FMockLLM.ShouldFail := True;

  LConfig := TLLMResilienceConfig.Default;
  LConfig.MaxRetries := 0; // No retries, just 1 attempt per call
  LConfig.CircuitBreakerThreshold := 3;
  FWrapper.Config := LConfig;

  // Make 3 failing calls to trip the circuit breaker
  for I := 1 to 3 do
    FWrapper.Chat(TierBalanced, 'fail');

  Assert.AreEqual(Ord(csOpen), Ord(FWrapper.GetCircuitState));

  // Next call should be rejected immediately without calling mock
  var LCallsBefore := FMockLLM.MockCallCount;
  LResponse := FWrapper.Chat(TierBalanced, 'should be rejected');
  Assert.IsFalse(LResponse.Success);
  Assert.AreEqual(LCallsBefore, FMockLLM.MockCallCount); // No new call made
end;

procedure TICResilienceIntegrationTest.Test_CircuitBreakerRecovery;
var
  LConfig: TLLMResilienceConfig;
  LResponse: TChatResult;
begin
  FMockLLM.ShouldFail := True;

  LConfig := TLLMResilienceConfig.Default;
  LConfig.MaxRetries := 0;
  LConfig.CircuitBreakerThreshold := 2;
  LConfig.CircuitBreakerCooldownMs := 100; // Very short for testing
  FWrapper.Config := LConfig;

  // Trip the breaker
  FWrapper.Chat(TierBalanced, 'fail1');
  FWrapper.Chat(TierBalanced, 'fail2');
  Assert.AreEqual(Ord(csOpen), Ord(FWrapper.GetCircuitState));

  // Manual reset simulates cooldown elapsed
  FWrapper.ResetCircuit;
  Assert.AreEqual(Ord(csClosed), Ord(FWrapper.GetCircuitState));

  // Now succeed
  FMockLLM.ShouldFail := False;
  LResponse := FWrapper.Chat(TierBalanced, 'should succeed');
  Assert.IsTrue(LResponse.Success);
  Assert.AreEqual(0, FWrapper.GetConsecutiveFailures);
end;

{ TICSessionFSMTest }

procedure TICSessionFSMTest.Test_ValidTransitions;
var
  LFSM: TSessionFSM;
begin
  LFSM := TSessionFSMFactory.CreateForSession('test-session');
  try
    // Start in Active
    Assert.AreEqual(Ord(ssActive), Ord(LFSM.CurrentState));

    // Active -> Suspended
    Assert.IsTrue(LFSM.CanFire(sfSuspend));
    LFSM.Fire(sfSuspend);
    Assert.AreEqual(Ord(ssSuspended), Ord(LFSM.CurrentState));

    // Suspended -> Active
    Assert.IsTrue(LFSM.CanFire(sfResume));
    LFSM.Fire(sfResume);
    Assert.AreEqual(Ord(ssActive), Ord(LFSM.CurrentState));

    // Active -> Completed
    Assert.IsTrue(LFSM.CanFire(sfComplete));
    LFSM.Fire(sfComplete);
    Assert.AreEqual(Ord(ssCompleted), Ord(LFSM.CurrentState));
  finally
    LFSM.Free;
  end;
end;

procedure TICSessionFSMTest.Test_InvalidTransition;
var
  LFSM: TSessionFSM;
begin
  LFSM := TSessionFSMFactory.CreateForSession('test-invalid');
  try
    // Active state: cannot Resume (already active)
    Assert.IsFalse(LFSM.CanFire(sfResume));

    // Completed state: no transitions out
    LFSM.Fire(sfComplete);
    Assert.AreEqual(Ord(ssCompleted), Ord(LFSM.CurrentState));
    Assert.IsFalse(LFSM.CanFire(sfSuspend));
    Assert.IsFalse(LFSM.CanFire(sfResume));
    Assert.IsFalse(LFSM.CanFire(sfSubmit));
  finally
    LFSM.Free;
  end;
end;

procedure TICSessionFSMTest.Test_SubmitIsInternal;
var
  LFSM: TSessionFSM;
begin
  LFSM := TSessionFSMFactory.CreateForSession('test-submit');
  try
    // Submit should be an internal transition (stays Active)
    Assert.IsTrue(LFSM.CanFire(sfSubmit));
    LFSM.Fire(sfSubmit);
    Assert.AreEqual(Ord(ssActive), Ord(LFSM.CurrentState));

    // Can submit multiple times
    LFSM.Fire(sfSubmit);
    LFSM.Fire(sfSubmit);
    Assert.AreEqual(Ord(ssActive), Ord(LFSM.CurrentState));
  finally
    LFSM.Free;
  end;
end;

procedure TICSessionFSMTest.Test_TimeoutSuspends;
var
  LFSM: TSessionFSM;
begin
  LFSM := TSessionFSMFactory.CreateForSession('test-timeout');
  try
    // Timeout trigger should move Active -> Suspended
    Assert.IsTrue(LFSM.CanFire(sfTimeout));
    LFSM.Fire(sfTimeout);
    Assert.AreEqual(Ord(ssSuspended), Ord(LFSM.CurrentState));
  finally
    LFSM.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TICIntegrationTest);
  TDUnitX.RegisterTestFixture(TICResilienceIntegrationTest);
  TDUnitX.RegisterTestFixture(TICSessionFSMTest);

end.
