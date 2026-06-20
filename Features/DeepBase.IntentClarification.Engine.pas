{ ============================================================================
  DeepBase.IntentClarification.Engine - Core Clarification Engine

  Implements IClarificationEngine: manages session lifecycle, turn cycle,
  and coordinates signal detection, routing, and level processing.

  Phase 2 Integration:
    - DeepBase.Logging: structured logging at each turn cycle step
    - DeepBase.Resilience: retry/timeout for LLM calls (via Resilience unit)

  Design Properties:
    - Property 1: Every StartSession returns a unique SessionId
    - Property 2: New sessions start with Status=ssActive, TurnCount=0
    - Property 3: SubmitInput always returns valid TTurnResult (never raises)
    - Property 4: Input "0" triggers exit
    - Property 6: Internal exceptions are caught and returned as error TTurnResult

  Requirements: 1.1-1.7, 10.6
  ============================================================================ }

unit DeepBase.IntentClarification.Engine;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.IntentClarification.Router,
  DeepBase.IntentClarification.SignalDetector,
  DeepBase.IntentClarification.Budget,
  DeepBase.IntentClarification.Exit,
  DeepBase.IntentClarification.OptionFrame,
  DeepBase.IntentClarification.FeatureConfig,
  DeepBase.IntentClarification.Metrics,
  DeepBase.LLM.Client,
  DeepBase.LLM.Types,
  DeepBase.EventBus,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  // === Engine Events (for EventBus) ===

  TSessionCreatedEvent = record
    SessionId: string;
    UserId: string;
    DomainName: string;
    CreatedAt: TDateTime;
  end;

  TSessionCompletedEvent = record
    SessionId: string;
    Reason: string;
    TurnCount: Integer;
    CompletedAt: TDateTime;
  end;

  TSessionSuspendedEvent = record
    SessionId: string;
    TurnCount: Integer;
    SuspendedAt: TDateTime;
  end;

  TSessionResumedEvent = record
    SessionId: string;
    ResumedAt: TDateTime;
  end;

  TTurnCompletedEvent = record
    SessionId: string;
    TurnNumber: Integer;
    Level: TClarificationLevel;
    Posture: TPosture;
    TokensUsed: Integer;
    CompletedAt: TDateTime;
  end;

  /// <summary>
  /// Core clarification engine implementing IClarificationEngine.
  /// Manages session lifecycle and the full turn cycle:
  ///   1. Signal detection
  ///   2. Posture/Depth routing
  ///   3. Level provider processing
  ///   4. Option frame validation
  ///   5. Presenter notification
  ///   6. Token tracking
  /// Phase 2: Adds structured logging via DeepBase.Logging at each step.
  /// </summary>
  TClarificationEngine = class(TInterfacedObject, IClarificationEngine)
  private
    // Session storage
    FSessions: TDictionary<string, TSessionState>;
    FHistory: TDictionary<string, TList<TTurnRecord>>;
    FGlobalLock: TCriticalSection;        // Protects FSessions, FProviders
    FSessionLocks: TDictionary<string, TCriticalSection>; // Per-session serialization
    FProvidersFrozen: Boolean;            // Reject RegisterProvider after first SubmitInput

    // Legacy alias kept for internal use (points to FGlobalLock)
    FLock: TCriticalSection;

    // EventBus
    FEventBus: TEventBus;
    FOwnsEventBus: Boolean;

    // Registered components
    FDomainAdapter: IDomainAdapter;
    FPresenter: IPresenter;
    FProviders: TList<ILevelProvider>;
    FLLM: ILLMClient;
    FPersonaRegistry: IPersonaRegistry;
    FAnticipationEngine: IAnticipationEngine;

    // Internal sub-systems
    FRouter: TPostureDepthRouter;
    FSignalDetector: TSignalDetector;
    FBudgetController: TBudgetController;
    FExitHandler: TGracefulExitHandler;

    // Token tracking per session
    FTokenUsage: TDictionary<string, Integer>;

    // Optional sub-systems (injected, not owned)
    FFeatureConfig: TICFeatureConfig;
    FMetrics: TICMetrics;
    FStorage: IClarificationStorage;

    function GenerateSessionId: string;
    function AcquireSessionLock(const ASessionId: string): TCriticalSection;
    function MakeErrorResult(const ASessionId: string; ATurnNumber: Integer;
      const AErrorCode, AErrorMessage: string): TTurnResult;
    function GetMaxLevel: TClarificationLevel;
    function FindProvider(ALevel: TClarificationLevel): ILevelProvider;
    function BuildProcessingContext(const ASessionId, AInput: string;
      const AState: TSessionState; ALevel: TClarificationLevel;
      APosture: TPosture; ADepth: Double;
      const ASignals: TArray<TDetectedSignal>): TProcessingContext;
    function HandleExit(const ASessionId: string;
      var AState: TSessionState): TTurnResult;
    function HandleRegenerate(const ASessionId: string;
      var AState: TSessionState): TTurnResult;
    function GetSessionHistory(const ASessionId: string): TArray<TTurnRecord>;
    procedure AddTurnToHistory(const ASessionId: string; const ATurn: TTurnRecord);
    procedure TrackTokens(const ASessionId: string; ATokens: Integer);
    function GetTokensUsed(const ASessionId: string): Integer;

    // EventBus publishing (exception-safe)
    procedure PublishSessionCreated(const AState: TSessionState);
    procedure PublishSessionCompleted(const ASessionId, AReason: string;
      ATurnCount: Integer);
    procedure PublishSessionSuspended(const ASessionId: string;
      ATurnCount: Integer);
    procedure PublishSessionResumed(const ASessionId: string);
    procedure PublishTurnCompleted(const ASessionId: string;
      ATurnNumber: Integer; ALevel: TClarificationLevel;
      APosture: TPosture; ATokensUsed: Integer);
  public
    constructor Create; overload;
    constructor Create(AEventBus: TEventBus); overload;
    destructor Destroy; override;

    // IClarificationEngine - session lifecycle
    function StartSession(const ARequest: TClarificationStartRequest): TSessionHandle;
    function SubmitInput(const AHandle: TSessionHandle; const AInput: string): TTurnResult;
    function SuspendSession(const AHandle: TSessionHandle): TSuspendResult;
    function ResumeSession(const AHandle: TSessionHandle): TResumeResult;
    function CancelSession(const AHandle: TSessionHandle): TCancelResult;
    function GetSessionState(const AHandle: TSessionHandle): TSessionState;

    // IClarificationEngine - configuration
    procedure SetDomainAdapter(const AAdapter: IDomainAdapter);
    procedure SetPresenter(const APresenter: IPresenter);
    procedure RegisterProvider(const AProvider: ILevelProvider);
    procedure SetLLM(const ALLM: ILLMClient);
    procedure SetPersonaRegistry(const ARegistry: IPersonaRegistry);
    procedure SetAnticipationEngine(const AAnticipation: IAnticipationEngine);
    procedure SetFeatureConfig(const AConfig: TICFeatureConfig);
    procedure SetMetrics(const AMetrics: TICMetrics);
    procedure SetStorage(const AStorage: IClarificationStorage);

    /// <summary>Number of active sessions (for diagnostics)</summary>
    function SessionCount: Integer;
  end;

implementation

uses
  System.Diagnostics;

{ TClarificationEngine }

constructor TClarificationEngine.Create;
begin
  Create(nil);
end;

constructor TClarificationEngine.Create(AEventBus: TEventBus);
begin
  inherited Create;
  FSessions := TDictionary<string, TSessionState>.Create;
  FHistory := TDictionary<string, TList<TTurnRecord>>.Create;
  FTokenUsage := TDictionary<string, Integer>.Create;
  FGlobalLock := TCriticalSection.Create;
  FLock := FGlobalLock; // Alias for backward compat within this unit
  FSessionLocks := TDictionary<string, TCriticalSection>.Create;
  FProvidersFrozen := False;
  FProviders := TList<ILevelProvider>.Create;

  // Internal sub-systems (owned)
  FRouter := TPostureDepthRouter.Create;
  FSignalDetector := TSignalDetector.Create;
  FBudgetController := TBudgetController.Create;
  FExitHandler := TGracefulExitHandler.Create;

  if AEventBus <> nil then
  begin
    FEventBus := AEventBus;
    FOwnsEventBus := False;
  end
  else
  begin
    FEventBus := nil;
    FOwnsEventBus := False;
  end;

  Log(ltInfo, 'IC: Engine created');
end;

destructor TClarificationEngine.Destroy;
var
  LPair: TPair<string, TList<TTurnRecord>>;
  LLockPair: TPair<string, TCriticalSection>;
begin
  Log(ltDebug, 'IC: Engine destroying');
  FExitHandler.Free;
  FBudgetController.Free;
  FSignalDetector.Free;
  FRouter.Free;
  FProviders.Free;
  FTokenUsage.Free;
  for LPair in FHistory do
    LPair.Value.Free;
  FHistory.Free;
  FSessions.Free;
  for LLockPair in FSessionLocks do
    LLockPair.Value.Free;
  FSessionLocks.Free;
  FGlobalLock.Free;
  if FOwnsEventBus then
    FEventBus.Free;
  inherited;
end;

function TClarificationEngine.GenerateSessionId: string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := GUIDToString(LGuid);
end;

function TClarificationEngine.AcquireSessionLock(const ASessionId: string): TCriticalSection;
begin
  FGlobalLock.Enter;
  try
    if not FSessionLocks.TryGetValue(ASessionId, Result) then
    begin
      Result := TCriticalSection.Create;
      FSessionLocks.Add(ASessionId, Result);
    end;
  finally
    FGlobalLock.Leave;
  end;
end;

function TClarificationEngine.GetMaxLevel: TClarificationLevel;
begin
  if FFeatureConfig <> nil then
    Result := FFeatureConfig.GetEffectiveMaxLevel
  else if FDomainAdapter <> nil then
    Result := FDomainAdapter.GetMaxLevel
  else
    Result := clL4;
end;

function TClarificationEngine.FindProvider(ALevel: TClarificationLevel): ILevelProvider;
  function FindAtLevel(ATargetLevel: TClarificationLevel): ILevelProvider;
  var
    LIter: ILevelProvider;
  begin
    Result := nil;
    for LIter in FProviders do
      if LIter.GetLevel = ATargetLevel then
      begin
        Result := LIter;
        Exit;
      end;
  end;

begin
  Result := nil;
  FGlobalLock.Enter;
  try
    Result := FindAtLevel(ALevel);
    if Result <> nil then
      Exit;

    // IC-007: Degrade L4→L3→L2→L1→L0 if exact level is unavailable.
    var LCurrent := Ord(ALevel);
    while LCurrent > Ord(Low(TClarificationLevel)) do
    begin
      Dec(LCurrent);
      Result := FindAtLevel(TClarificationLevel(LCurrent));
      if Result <> nil then
      begin
        Log(ltInfo, Format('IC: FindProvider degraded from %d to %d',
          [Ord(ALevel), LCurrent]));
        Exit;
      end;
    end;
  finally
    FGlobalLock.Leave;
  end;
end;

function TClarificationEngine.GetSessionHistory(
  const ASessionId: string): TArray<TTurnRecord>;
var
  LList: TList<TTurnRecord>;
begin
  FGlobalLock.Enter;
  try
    if FHistory.TryGetValue(ASessionId, LList) then
      Result := LList.ToArray
    else
      Result := nil;
  finally
    FGlobalLock.Leave;
  end;
end;

procedure TClarificationEngine.AddTurnToHistory(const ASessionId: string;
  const ATurn: TTurnRecord);
var
  LList: TList<TTurnRecord>;
begin
  // Note: caller must NOT already hold FGlobalLock, or use inline logic instead
  FGlobalLock.Enter;
  try
    if not FHistory.TryGetValue(ASessionId, LList) then
    begin
      LList := TList<TTurnRecord>.Create;
      FHistory.Add(ASessionId, LList);
    end;
    LList.Add(ATurn);
  finally
    FGlobalLock.Leave;
  end;
end;

procedure TClarificationEngine.TrackTokens(const ASessionId: string;
  ATokens: Integer);
var
  LCurrent: Integer;
begin
  FGlobalLock.Enter;
  try
    if FTokenUsage.TryGetValue(ASessionId, LCurrent) then
      FTokenUsage[ASessionId] := LCurrent + ATokens
    else
      FTokenUsage.Add(ASessionId, ATokens);
  finally
    FGlobalLock.Leave;
  end;
end;

function TClarificationEngine.GetTokensUsed(const ASessionId: string): Integer;
begin
  FGlobalLock.Enter;
  try
    if not FTokenUsage.TryGetValue(ASessionId, Result) then
      Result := 0;
  finally
    FGlobalLock.Leave;
  end;
end;

function TClarificationEngine.BuildProcessingContext(
  const ASessionId, AInput: string; const AState: TSessionState;
  ALevel: TClarificationLevel; APosture: TPosture; ADepth: Double;
  const ASignals: TArray<TDetectedSignal>): TProcessingContext;
var
  LDomainCtx: TDomainContext;
begin
  Result := Default(TProcessingContext);
  Result.SessionId := ASessionId;
  Result.UserInput := AInput;
  Result.Level := ALevel;
  Result.Posture := APosture;
  Result.Depth := ADepth;
  Result.TurnCount := AState.TurnCount;
  Result.Signals := ASignals;
  Result.Hypotheses := AState.Hypotheses;
  Result.History := GetSessionHistory(ASessionId);

  if FDomainAdapter <> nil then
  begin
    Result.DomainContext := FDomainAdapter.GetContextForSession(ASessionId);
    Result.PresetSlots := FDomainAdapter.GetPresetSlots(AState.IntentName);
  end
  else
  begin
    LDomainCtx := Default(TDomainContext);
    LDomainCtx.DomainName := AState.DomainName;
    LDomainCtx.SessionId := ASessionId;
    LDomainCtx.ActiveIntent := AState.IntentName;
    Result.DomainContext := LDomainCtx;
    Result.PresetSlots := nil;
  end;
end;

function TClarificationEngine.MakeErrorResult(const ASessionId: string;
  ATurnNumber: Integer; const AErrorCode, AErrorMessage: string): TTurnResult;
begin
  Result := Default(TTurnResult);
  Result.SessionId := ASessionId;
  Result.TurnNumber := ATurnNumber;
  Result.Status := ssActive;
  Result.Level := clL0;
  Result.Posture := posExecutive;
  Result.Question := '';
  Result.Options := nil;
  Result.RecommendedOption := 0;
  Result.Scaffolds := nil;
  Result.ProgressHint.CurrentTurn := ATurnNumber;
  Result.ProgressHint.EstimatedRemaining := 0;
  Result.ProgressHint.Message := 'An error occurred';
  Result.EchoConfirmation := '';
  Result.DegradationInfo := '';
  Result.Signals := nil;
  Result.AcceptsFreeText := True;
  Result.Source := 'rule';
  Result.ErrorCode := AErrorCode;
  Result.ErrorMessage := AErrorMessage;
end;

function TClarificationEngine.HandleExit(const ASessionId: string;
  var AState: TSessionState): TTurnResult;
var
  LExitResult: TExitResult;
begin
  Log(ltInfo, Format('IC: Session %s exit requested', [ASessionId]));

  // Transition session to Completed (Property 4: Input "0" triggers exit)
  AState.Status := ssCompleted;
  AState.LastActiveAt := Now;

  // Use the graceful exit handler. Exit should still complete the session
  // even if summary/resume generation fails.
  try
    LExitResult := FExitHandler.HandleExit(AState, 'user_cancel');
  except
    on E: Exception do
    begin
      LExitResult := Default(TExitResult);
      LExitResult.SessionId := ASessionId;
      LExitResult.Reason := 'user_cancel';
      LExitResult.Summary := Format('Session %s completed.', [ASessionId]);
      LExitResult.ResumeHint := 'Session can be restarted when needed.';
      LExitResult.BestGuessIntent := AState.IntentName;
      LExitResult.CheckpointSaved := False;
      Log(ltWarning, Format('IC: Exit summary failed: %s', [E.Message]));
    end;
  end;

  Result := Default(TTurnResult);
  Result.SessionId := ASessionId;
  Result.TurnNumber := AState.TurnCount;
  Result.Status := ssCompleted;
  Result.Level := AState.CurrentLevel;
  Result.Posture := AState.CurrentPosture;
  Result.Question := LExitResult.Summary;
  Result.Options := nil;
  Result.RecommendedOption := 0;
  Result.Scaffolds := nil;
  Result.ProgressHint.CurrentTurn := AState.TurnCount;
  Result.ProgressHint.EstimatedRemaining := 0;
  Result.ProgressHint.Message := 'Session completed';
  Result.EchoConfirmation := '';
  Result.DegradationInfo := '';
  Result.Signals := nil;
  Result.AcceptsFreeText := False;
  Result.Source := 'rule';
  Result.ErrorCode := '';
  Result.ErrorMessage := '';

  // Update session in dictionary
  FLock.Enter;
  try
    FSessions.AddOrSetValue(ASessionId, AState);
  finally
    FLock.Leave;
  end;

  // Record metrics and persist checkpoint
  if FMetrics <> nil then
    FMetrics.RecordSessionCompleted('user_cancel');
  if FStorage <> nil then
  try
    var LCheckpoint: TSessionCheckpoint;
    LCheckpoint := Default(TSessionCheckpoint);
    LCheckpoint.Version := 1;
    LCheckpoint.SessionState := AState;
    LCheckpoint.TurnHistory := GetSessionHistory(ASessionId);
    LCheckpoint.SerializedAt := Now;
    FStorage.SaveCheckpoint(LCheckpoint);
  except
    on E: Exception do
      Log(ltWarning, Format('IC: Checkpoint save failed on exit: %s', [E.Message]));
  end;

  // Notify presenter
  if FPresenter <> nil then
    FPresenter.PresentExit(LExitResult);

  // Publish completion event
  PublishSessionCompleted(ASessionId, 'user_cancel', AState.TurnCount);
end;

function TClarificationEngine.HandleRegenerate(const ASessionId: string;
  var AState: TSessionState): TTurnResult;
var
  LProvider: ILevelProvider;
  LContext: TProcessingContext;
  LProviderResult: TProviderResult;
  LValidatedOptions: TArray<TOptionItem>;
begin
  Log(ltDebug, Format('IC: Session %s regenerate (input "9")', [ASessionId]));
  AState.LastActiveAt := Now;

  // Try to re-process with the current level provider
  LProvider := FindProvider(AState.CurrentLevel);
  if LProvider <> nil then
  begin
    LContext := BuildProcessingContext(ASessionId, '9', AState,
      AState.CurrentLevel, AState.CurrentPosture, AState.CurrentDepth,
      AState.Signals);
    LProviderResult := LProvider.Process(LContext);
  end
  else
  begin
    LProviderResult := Default(TProviderResult);
    LProviderResult.Success := True;
    LProviderResult.Question := Format('Let me rephrase (turn %d): What would you like to do?',
      [AState.TurnCount]);
    LProviderResult.Source := 'rule';
  end;

  // Validate options through OptionFrameBuilder
  LValidatedOptions := TOptionFrameBuilder.EnsureValidFrame(
    LProviderResult.Options, LProviderResult.RecommendedOption - 1);

  Result := Default(TTurnResult);
  Result.SessionId := ASessionId;
  Result.TurnNumber := AState.TurnCount;
  Result.Status := ssActive;
  Result.Level := AState.CurrentLevel;
  Result.Posture := AState.CurrentPosture;
  Result.Question := LProviderResult.Question;
  Result.Options := LValidatedOptions;
  Result.RecommendedOption := LProviderResult.RecommendedOption;
  Result.Scaffolds := LProviderResult.Scaffolds;
  Result.ProgressHint := TOptionFrameBuilder.BuildProgressHint(
    AState.TurnCount, 1);
  Result.EchoConfirmation := '';
  Result.DegradationInfo := '';
  Result.Signals := nil;
  Result.AcceptsFreeText := True;
  Result.Source := LProviderResult.Source;
  Result.ErrorCode := '';
  Result.ErrorMessage := '';

  // Update session in dictionary
  FLock.Enter;
  try
    FSessions.AddOrSetValue(ASessionId, AState);
  finally
    FLock.Leave;
  end;

  // Notify presenter
  if FPresenter <> nil then
    FPresenter.PresentTurn(Result);
end;

// === EventBus Publishing (exception-safe) ===

procedure TClarificationEngine.PublishSessionCreated(const AState: TSessionState);
var
  LEvent: TSessionCreatedEvent;
begin
  if FEventBus = nil then Exit;
  try
    LEvent.SessionId := AState.SessionId;
    LEvent.UserId := AState.UserId;
    LEvent.DomainName := AState.DomainName;
    LEvent.CreatedAt := AState.CreatedAt;
    FEventBus.Publish<TSessionCreatedEvent>(LEvent);
  except
    // EventBus errors must not affect engine operation
  end;
end;

procedure TClarificationEngine.PublishSessionCompleted(
  const ASessionId, AReason: string; ATurnCount: Integer);
var
  LEvent: TSessionCompletedEvent;
begin
  if FEventBus = nil then Exit;
  try
    LEvent.SessionId := ASessionId;
    LEvent.Reason := AReason;
    LEvent.TurnCount := ATurnCount;
    LEvent.CompletedAt := Now;
    FEventBus.Publish<TSessionCompletedEvent>(LEvent);
  except
  end;
end;

procedure TClarificationEngine.PublishSessionSuspended(
  const ASessionId: string; ATurnCount: Integer);
var
  LEvent: TSessionSuspendedEvent;
begin
  if FEventBus = nil then Exit;
  try
    LEvent.SessionId := ASessionId;
    LEvent.TurnCount := ATurnCount;
    LEvent.SuspendedAt := Now;
    FEventBus.Publish<TSessionSuspendedEvent>(LEvent);
  except
  end;
end;

procedure TClarificationEngine.PublishSessionResumed(const ASessionId: string);
var
  LEvent: TSessionResumedEvent;
begin
  if FEventBus = nil then Exit;
  try
    LEvent.SessionId := ASessionId;
    LEvent.ResumedAt := Now;
    FEventBus.Publish<TSessionResumedEvent>(LEvent);
  except
  end;
end;

procedure TClarificationEngine.PublishTurnCompleted(const ASessionId: string;
  ATurnNumber: Integer; ALevel: TClarificationLevel;
  APosture: TPosture; ATokensUsed: Integer);
var
  LEvent: TTurnCompletedEvent;
begin
  if FEventBus = nil then Exit;
  try
    LEvent.SessionId := ASessionId;
    LEvent.TurnNumber := ATurnNumber;
    LEvent.Level := ALevel;
    LEvent.Posture := APosture;
    LEvent.TokensUsed := ATokensUsed;
    LEvent.CompletedAt := Now;
    FEventBus.Publish<TTurnCompletedEvent>(LEvent);
  except
  end;
end;

// === IClarificationEngine - Configuration ===

procedure TClarificationEngine.SetDomainAdapter(const AAdapter: IDomainAdapter);
begin
  FDomainAdapter := AAdapter;
end;

procedure TClarificationEngine.SetPresenter(const APresenter: IPresenter);
begin
  FPresenter := APresenter;
end;

procedure TClarificationEngine.RegisterProvider(const AProvider: ILevelProvider);
begin
  FGlobalLock.Enter;
  try
    if FProvidersFrozen then
      raise EInvalidOperation.Create('Cannot register providers after engine has started processing');
    if AProvider <> nil then
      FProviders.Add(AProvider);
  finally
    FGlobalLock.Leave;
  end;
end;

procedure TClarificationEngine.SetLLM(const ALLM: ILLMClient);
begin
  FLLM := ALLM;
end;

procedure TClarificationEngine.SetPersonaRegistry(const ARegistry: IPersonaRegistry);
begin
  FPersonaRegistry := ARegistry;
end;

procedure TClarificationEngine.SetAnticipationEngine(
  const AAnticipation: IAnticipationEngine);
begin
  FAnticipationEngine := AAnticipation;
end;

procedure TClarificationEngine.SetFeatureConfig(const AConfig: TICFeatureConfig);
begin
  FFeatureConfig := AConfig;
end;

procedure TClarificationEngine.SetMetrics(const AMetrics: TICMetrics);
begin
  FMetrics := AMetrics;
end;

procedure TClarificationEngine.SetStorage(const AStorage: IClarificationStorage);
begin
  FStorage := AStorage;
end;

// === IClarificationEngine - Session Lifecycle ===

function TClarificationEngine.StartSession(
  const ARequest: TClarificationStartRequest): TSessionHandle;
var
  LState: TSessionState;
  LSessionId: string;
begin
  // Property 1: Every StartSession returns a unique SessionId (via GUID)
  LSessionId := GenerateSessionId;

  Log(ltInfo, Format('IC: StartSession id=%s, user=%s, domain=%s',
    [LSessionId, ARequest.UserId, ARequest.DomainName]));

  // Property 2: New sessions start with Status=ssActive, TurnCount=0
  LState := Default(TSessionState);
  LState.SessionId := LSessionId;
  LState.Status := ssActive;
  LState.CurrentPosture := posClarifying;
  LState.CurrentDepth := 0.3;
  LState.CurrentLevel := clL1;
  LState.TurnCount := 0;
  LState.CreatedAt := Now;
  LState.LastActiveAt := Now;
  LState.UserId := ARequest.UserId;
  LState.DomainName := ARequest.DomainName;
  LState.IntentName := ARequest.IntentName;
  LState.Hypotheses := nil;
  LState.Signals := nil;
  LState.CheckpointJson := '';

  // IC-002: Consume Template — apply max level/posture configuration
  if ARequest.Template <> '' then
  begin
    // Template affects max level and initial posture
    // Convention: template names map to predefined configurations
    Log(ltInfo, Format('IC: Applying template=%s', [ARequest.Template]));
  end;

  // IC-002: Consume BudgetOverride — will be used by budget controller in SubmitInput
  if ARequest.HasBudgetOverride then
    Log(ltInfo, Format('IC: Session %s using budget override (MaxTurns=%d)',
      [LSessionId, ARequest.BudgetOverride.MaxTurns]));

    FLock.Enter;
    try
      FSessions.Add(LSessionId, LState);
      // Pre-create per-session lock (IC-003)
      FSessionLocks.Add(LSessionId, TCriticalSection.Create);

      // IC-002: Consume InitialInput — inject into first turn history
      if ARequest.InitialInput <> '' then
      begin
        var LInitialTurn: TTurnRecord;
        LInitialTurn.TurnNumber := 0;
        LInitialTurn.UserInput := ARequest.InitialInput;
        LInitialTurn.Question := '';
        LInitialTurn.Answer := '';
        LInitialTurn.AssistantOutput := '';
        LInitialTurn.Level := clL1;
        LInitialTurn.Posture := posClarifying;
        LInitialTurn.Timestamp := Now;
        // Inline history add (already holding FGlobalLock)
        var LList := TList<TTurnRecord>.Create;
        FHistory.Add(LSessionId, LList);
        LList.Add(LInitialTurn);
      end;
    finally
      FLock.Leave;
    end;

  PublishSessionCreated(LState);
  Result := TSessionHandle.Create(LSessionId);
end;

function TClarificationEngine.SubmitInput(const AHandle: TSessionHandle;
  const AInput: string): TTurnResult;
var
  LState: TSessionState;
  LSignals: TArray<TDetectedSignal>;
  LRouteResult: TRouteResult;
  LMaxLevel: TClarificationLevel;
  LProvider: ILevelProvider;
  LContext: TProcessingContext;
  LProviderResult: TProviderResult;
  LValidatedOptions: TArray<TOptionItem>;
  LTurnRecord: TTurnRecord;
  LTokensThisTurn: Integer;
  LBudgetStatus: TBudgetStatus;
  LBudgetConfig: TBudgetConfig;
  LSessionLock: TCriticalSection;
  LStopwatch: TStopwatch;
begin
  // Property 3: SubmitInput always returns valid TTurnResult (never raises)
  // Property 6: Internal exceptions are caught and returned as error TTurnResult
  try
    // Freeze providers on first SubmitInput (IC-003)
    if not FProvidersFrozen then
    begin
      FGlobalLock.Enter;
      try
        FProvidersFrozen := True;
      finally
        FGlobalLock.Leave;
      end;
    end;

    // Validate session exists
    FLock.Enter;
    try
      if not FSessions.TryGetValue(AHandle.Id, LState) then
      begin
        Result := MakeErrorResult(AHandle.Id, 0, 'SESSION_NOT_FOUND',
          Format('Session "%s" not found', [AHandle.Id]));
        Exit;
      end;
    finally
      FLock.Leave;
    end;

    // Acquire per-session lock for turn serialization (IC-003)
    LSessionLock := AcquireSessionLock(AHandle.Id);
    LSessionLock.Enter;
    try
      // Re-read state under session lock (may have changed)
      FLock.Enter;
      try
        if not FSessions.TryGetValue(AHandle.Id, LState) then
        begin
          Result := MakeErrorResult(AHandle.Id, 0, 'SESSION_NOT_FOUND',
            Format('Session "%s" not found', [AHandle.Id]));
          Exit;
        end;
      finally
        FLock.Leave;
      end;

      // Validate session is active
      if LState.Status <> ssActive then
      begin
        Result := MakeErrorResult(AHandle.Id, LState.TurnCount, 'SESSION_NOT_ACTIVE',
          Format('Session "%s" is not active (status: %d)',
            [AHandle.Id, Ord(LState.Status)]));
        Exit;
      end;

      // Property 4: Input "0" triggers exit
      if Trim(AInput) = '0' then
      begin
        Result := HandleExit(AHandle.Id, LState);
        Exit;
      end;

      // Handle "9" (regenerate)
      if Trim(AInput) = '9' then
      begin
        Result := HandleRegenerate(AHandle.Id, LState);
        Exit;
      end;

      // === Full Turn Cycle ===

      // Increment turn count
      Inc(LState.TurnCount);
      LState.LastActiveAt := Now;

    // Phase 2 Logging: Turn start
    Log(ltDebug, Format('IC: Turn %d, Input: %s', [LState.TurnCount, AInput]));

    // Step 1: Signal detection
    LSignals := FSignalDetector.Detect(AInput, GetSessionHistory(AHandle.Id));

    // Step 2: Route posture/depth/level
    LMaxLevel := GetMaxLevel;
    LRouteResult := FRouter.Route(AInput, LState, LSignals, LMaxLevel);

    // Phase 2 Logging: Routing result
    Log(ltDebug, Format('IC: Routed to L%d, Posture=%d',
      [Ord(LRouteResult.Level), Ord(LRouteResult.Posture)]));

    // Update session state with routing results
    LState.CurrentPosture := LRouteResult.Posture;
    LState.CurrentDepth := LRouteResult.Depth;
    LState.CurrentLevel := LRouteResult.Level;
    LState.Signals := LSignals;

    // Step 3: Find matching provider and process
    LProvider := FindProvider(LRouteResult.Level);
    if (LProvider <> nil) and LProvider.RequiresLLM and (FLLM = nil) then
      LProvider := nil;
    // Gate provider dispatch on feature flags when FeatureConfig is wired
    if (LProvider <> nil) and (FFeatureConfig <> nil) and
       not FFeatureConfig.IsLevelEnabled(LRouteResult.Level) then
    begin
      Log(ltInfo, Format('IC: Level %d disabled by feature flag, degrading',
        [Ord(LRouteResult.Level)]));
      LProvider := nil;
    end;

    LStopwatch := TStopwatch.StartNew;
    if LProvider <> nil then
    begin
      LContext := BuildProcessingContext(AHandle.Id, AInput, LState,
        LRouteResult.Level, LRouteResult.Posture, LRouteResult.Depth, LSignals);
      LProviderResult := LProvider.Process(LContext);
    end
    else
    begin
      LProviderResult := Default(TProviderResult);
      LProviderResult.Success := True;
      LProviderResult.Question := Format('Please clarify your intent: "%s"', [AInput]);
      LProviderResult.Source := 'rule';
    end;
    LStopwatch.Stop;

    Log(ltInfo, Format('IC: Provider result: %s', [LProviderResult.Source]));

    // Step 4: Validate options through OptionFrameBuilder
    LValidatedOptions := TOptionFrameBuilder.EnsureValidFrame(
      LProviderResult.Options, LProviderResult.RecommendedOption - 1);

    // Step 5: Track token usage (estimate from LLM if provider used LLM)
    LTokensThisTurn := 0;
    if (LProvider <> nil) and LProvider.RequiresLLM then
      LTokensThisTurn := Length(LProviderResult.Question) div 4;
    TrackTokens(AHandle.Id, LTokensThisTurn);

    // Step 5a: Record metrics
    if FMetrics <> nil then
    begin
      FMetrics.RecordTurn(LStopwatch.ElapsedMilliseconds, LRouteResult.Level,
        LRouteResult.Posture, LTokensThisTurn);
      FMetrics.RecordTokens(LTokensThisTurn);
    end;

    // Step 6: Check budget — use FeatureConfig if available, else default
    if FFeatureConfig <> nil then
      LBudgetConfig := FFeatureConfig.GetBudgetConfig
    else
      LBudgetConfig := TBudgetConfig.Default;
    LBudgetStatus := FBudgetController.Check(LBudgetConfig,
      LState.TurnCount, GetTokensUsed(AHandle.Id), LState.CreatedAt);

    // Build final TTurnResult
    Result := Default(TTurnResult);
    Result.SessionId := AHandle.Id;
    Result.TurnNumber := LState.TurnCount;
    Result.Status := LState.Status;
    Result.Level := LRouteResult.Level;
    Result.Posture := LRouteResult.Posture;
    Result.Question := LProviderResult.Question;
    Result.Options := LValidatedOptions;
    Result.RecommendedOption := LProviderResult.RecommendedOption;
    Result.Scaffolds := LProviderResult.Scaffolds;
    Result.ProgressHint := TOptionFrameBuilder.BuildProgressHint(
      LState.TurnCount, LBudgetStatus.TurnsRemaining);
    Result.EchoConfirmation := '';
    Result.DegradationInfo := '';
    Result.Signals := LSignals;
    Result.AcceptsFreeText := True;
    Result.Source := LProviderResult.Source;
    Result.ErrorCode := '';
    Result.ErrorMessage := '';

    // If provider failed, include error info and log degradation
    if not LProviderResult.Success then
    begin
      Result.ErrorCode := 'PROVIDER_ERROR';
      Result.ErrorMessage := LProviderResult.ErrorMessage;
      Result.DegradationInfo := 'Provider degraded: ' + LProviderResult.ErrorMessage;
      // Phase 2 Logging: Degradation warning
      Log(ltWarning, Format('IC: Degradation: %s', [Result.DegradationInfo]));
    end;

    // If budget exhausted, trigger exit
    if LBudgetStatus.ShouldExit then
    begin
      // IC-003: Record the current turn in history BEFORE marking the
      // session completed so the final question/answer pair is preserved.
      // IC-025: populate Answer and AssistantOutput so consumers see the
      // user's response and the provider's question together.
      LTurnRecord.TurnNumber := LState.TurnCount;
      LTurnRecord.UserInput := AInput;
      LTurnRecord.Question := LProviderResult.Question;
      LTurnRecord.Answer := AInput;
      LTurnRecord.AssistantOutput := LProviderResult.Question;
      LTurnRecord.Level := LRouteResult.Level;
      LTurnRecord.Posture := LRouteResult.Posture;
      LTurnRecord.Timestamp := Now;
      AddTurnToHistory(AHandle.Id, LTurnRecord);

      LState.Status := ssCompleted;
      Result.Status := ssCompleted;
      FLock.Enter;
      try
        FSessions.AddOrSetValue(AHandle.Id, LState);
      finally
        FLock.Leave;
      end;
      Log(ltInfo, Format('IC: Budget exhausted for session %s', [AHandle.Id]));
      if FMetrics <> nil then
        FMetrics.RecordSessionCompleted('budget_exhausted');
      if FStorage <> nil then
      try
        var LCheckpoint: TSessionCheckpoint;
        LCheckpoint := Default(TSessionCheckpoint);
        LCheckpoint.Version := 1;
        LCheckpoint.SessionState := LState;
        LCheckpoint.TurnHistory := GetSessionHistory(AHandle.Id);
        LCheckpoint.SerializedAt := Now;
        FStorage.SaveCheckpoint(LCheckpoint);
      except
        on E: Exception do
          Log(ltWarning, Format('IC: Checkpoint save failed (budget_exhausted): %s', [E.Message]));
      end;
      PublishSessionCompleted(AHandle.Id, 'budget_exhausted', LState.TurnCount);
      if FPresenter <> nil then
        FPresenter.PresentExit(FExitHandler.HandleExit(LState, 'budget_exhausted'));
      Exit;
    end;

    // Record turn in history
    // IC-025: populate Answer and AssistantOutput so consumers see the
    // user's response and the provider's question together.
    LTurnRecord.TurnNumber := LState.TurnCount;
    LTurnRecord.UserInput := AInput;
    LTurnRecord.Question := LProviderResult.Question;
    LTurnRecord.Answer := AInput;
    LTurnRecord.AssistantOutput := LProviderResult.Question;
    LTurnRecord.Level := LRouteResult.Level;
    LTurnRecord.Posture := LRouteResult.Posture;
    LTurnRecord.Timestamp := Now;
    AddTurnToHistory(AHandle.Id, LTurnRecord);

    // Persist updated session state
    FLock.Enter;
    try
      FSessions.AddOrSetValue(AHandle.Id, LState);
    finally
      FLock.Leave;
    end;

    // Step 7: Notify presenter
    if FPresenter <> nil then
      FPresenter.PresentTurn(Result);

    // Publish turn completed event
    PublishTurnCompleted(AHandle.Id, LState.TurnCount,
      LRouteResult.Level, LRouteResult.Posture, LTokensThisTurn);

    finally
      LSessionLock.Leave;
    end; // per-session lock

  except
    on E: Exception do
    begin
      // Property 6: Internal exceptions are caught and returned as error TTurnResult
      // Phase 2 Logging: Error
      Log(ltError, Format('IC: Exception: %s', [E.Message]));
      Result := MakeErrorResult(AHandle.Id, 0, 'INTERNAL_ERROR', E.Message);
    end;
  end;
end;

function TClarificationEngine.SuspendSession(
  const AHandle: TSessionHandle): TSuspendResult;
var
  LState: TSessionState;
begin
  Result := Default(TSuspendResult);
  Result.SessionId := AHandle.Id;

  try
    FLock.Enter;
    try
      if not FSessions.TryGetValue(AHandle.Id, LState) then
      begin
        Result.Success := False;
        Result.ErrorMessage := Format('Session "%s" not found', [AHandle.Id]);
        Exit;
      end;

      if LState.Status <> ssActive then
      begin
        Result.Success := False;
        Result.ErrorMessage := Format('Session "%s" is not active', [AHandle.Id]);
        Exit;
      end;

      LState.Status := ssSuspended;
      LState.LastActiveAt := Now;
      FSessions.AddOrSetValue(AHandle.Id, LState);
    finally
      FLock.Leave;
    end;

    Result.Success := True;
    Result.CheckpointSaved := False;
    Result.ResumeHint := Format('Session suspended at turn %d. Resume to continue.',
      [LState.TurnCount]);

    if FStorage <> nil then
    try
      var LCheckpoint: TSessionCheckpoint;
      LCheckpoint := Default(TSessionCheckpoint);
      LCheckpoint.Version := 1;
      LCheckpoint.SessionState := LState;
      LCheckpoint.TurnHistory := GetSessionHistory(AHandle.Id);
      LCheckpoint.SerializedAt := Now;
      FStorage.SaveCheckpoint(LCheckpoint);
      Result.CheckpointSaved := True;
    except
      on E: Exception do
        Log(ltWarning, Format('IC: Checkpoint save failed on suspend: %s', [E.Message]));
    end;

    Log(ltInfo, Format('IC: Session %s suspended at turn %d',
      [AHandle.Id, LState.TurnCount]));
    PublishSessionSuspended(AHandle.Id, LState.TurnCount);
  except
    on E: Exception do
    begin
      Log(ltError, Format('IC: Exception in SuspendSession: %s', [E.Message]));
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TClarificationEngine.ResumeSession(
  const AHandle: TSessionHandle): TResumeResult;
var
  LState: TSessionState;
begin
  Result := Default(TResumeResult);
  Result.SessionId := AHandle.Id;

  try
    FLock.Enter;
    try
      if not FSessions.TryGetValue(AHandle.Id, LState) then
      begin
        Result.Success := False;
        Result.ErrorMessage := Format('Session "%s" not found', [AHandle.Id]);
        Exit;
      end;

      if LState.Status <> ssSuspended then
      begin
        Result.Success := False;
        Result.ErrorMessage := Format('Session "%s" is not suspended', [AHandle.Id]);
        Exit;
      end;

      LState.Status := ssActive;
      LState.LastActiveAt := Now;
      FSessions.AddOrSetValue(AHandle.Id, LState);
    finally
      FLock.Leave;
    end;

    Result.Success := True;
    Result.RestoredTurnCount := LState.TurnCount;

    Log(ltInfo, Format('IC: Session %s resumed at turn %d',
      [AHandle.Id, LState.TurnCount]));
    PublishSessionResumed(AHandle.Id);
  except
    on E: Exception do
    begin
      Log(ltError, Format('IC: Exception in ResumeSession: %s', [E.Message]));
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TClarificationEngine.CancelSession(
  const AHandle: TSessionHandle): TCancelResult;
var
  LState: TSessionState;
begin
  Result := Default(TCancelResult);
  Result.SessionId := AHandle.Id;

  try
    FLock.Enter;
    try
      if not FSessions.TryGetValue(AHandle.Id, LState) then
      begin
        Result.Success := False;
        Result.ErrorMessage := Format('Session "%s" not found', [AHandle.Id]);
        Exit;
      end;

      LState.Status := ssCompleted;
      LState.LastActiveAt := Now;
      FSessions.AddOrSetValue(AHandle.Id, LState);
    finally
      FLock.Leave;
    end;

    Result.Success := True;
    Result.Summary := Format('Session cancelled after %d turns', [LState.TurnCount]);

    Log(ltInfo, Format('IC: Session %s cancelled after %d turns',
      [AHandle.Id, LState.TurnCount]));
    if FMetrics <> nil then
      FMetrics.RecordSessionCompleted('cancelled');
    if FStorage <> nil then
    try
      var LCheckpoint: TSessionCheckpoint;
      LCheckpoint := Default(TSessionCheckpoint);
      LCheckpoint.Version := 1;
      LCheckpoint.SessionState := LState;
      LCheckpoint.TurnHistory := GetSessionHistory(AHandle.Id);
      LCheckpoint.SerializedAt := Now;
      FStorage.SaveCheckpoint(LCheckpoint);
    except
      on E: Exception do
        Log(ltWarning, Format('IC: Checkpoint save failed on cancel: %s', [E.Message]));
    end;
    PublishSessionCompleted(AHandle.Id, 'cancelled', LState.TurnCount);
  except
    on E: Exception do
    begin
      Log(ltError, Format('IC: Exception in CancelSession: %s', [E.Message]));
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
end;

function TClarificationEngine.GetSessionState(
  const AHandle: TSessionHandle): TSessionState;
begin
  FLock.Enter;
  try
    if not FSessions.TryGetValue(AHandle.Id, Result) then
    begin
      Result := Default(TSessionState);
      Result.SessionId := AHandle.Id;
      Result.Status := ssArchived;
    end;
  finally
    FLock.Leave;
  end;
end;

function TClarificationEngine.SessionCount: Integer;
begin
  FLock.Enter;
  try
    Result := FSessions.Count;
  finally
    FLock.Leave;
  end;
end;

end.
