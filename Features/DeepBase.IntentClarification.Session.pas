{ ============================================================================
  DeepBase.IntentClarification.Session - Session Lifecycle Manager

  Manages session state transitions, idle timeout detection, and checkpoint
  serialization/deserialization. Thread-safe via TCriticalSection.

  Phase 2 Integration:
    - DeepBase.StateMachine: replaces hand-written IsValidTransition
    - DeepBase.Logging: structured logging for state transitions

  Valid state transitions (defined via TStateMachine):
    Active    -> Suspended (stSuspend), Completed (stComplete)
    Suspended -> Active (stResume), Archived (stArchive)
    Completed -> Archived (stArchive)
    Archived  -> (terminal, no transitions)

  Design Properties:
    - Property 1: Session IDs are unique (GUID-based)
    - Property 2: New sessions start Active with TurnCount=0
    - Property 5: Suspend then Resume restores equivalent state

  Requirements: 1.2, 1.4-1.6, 16.1-16.2
  ============================================================================ }

unit DeepBase.IntentClarification.Session;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils,
  DeepBase.IntentClarification.Types,
  DeepBase.IntentClarification.Interfaces,
  DeepBase.StateMachine,
  DeepBase.Logging,
  DeepBase.IntentClarification.Logging;

type
  /// <summary>Session state transition triggers</summary>
  TSessionTrigger = (
    stSuspend,
    stResume,
    stComplete,
    stArchive
  );

  /// <summary>
  /// Manages session lifecycle, state transitions, idle timeout detection,
  /// and checkpoint save/restore. Thread-safe.
  /// Phase 2: Uses TStateMachine for validated state transitions.
  /// </summary>
  TSessionManager = class
  private
    FSessions: TDictionary<string, TSessionState>;
    FCheckpoints: TDictionary<string, TSessionCheckpoint>;
    FLock: TCriticalSection;
    FIdleTimeoutSeconds: Integer;

    /// <summary>Creates a configured state machine for session lifecycle</summary>
    function CreateStateMachine(AInitialState: TSessionStatus): TStateMachine<TSessionStatus, TSessionTrigger>;

    /// <summary>Maps a target status to the appropriate trigger</summary>
    function StatusToTrigger(ATarget: TSessionStatus): TSessionTrigger;
  public
    constructor Create(AIdleTimeoutSeconds: Integer = 300);
    destructor Destroy; override;

    /// <summary>
    /// Create a new session from a start request.
    /// Returns initialized TSessionState with Status=ssActive, TurnCount=0.
    /// Requirements: 1.2
    /// </summary>
    function CreateSession(const ARequest: TClarificationStartRequest): TSessionState;

    /// <summary>
    /// Update an existing session's state. Persists state changes in memory.
    /// </summary>
    procedure UpdateSession(const AState: TSessionState);

    /// <summary>
    /// Retrieve a session by ID. Raises EArgumentException if not found.
    /// </summary>
    function GetSession(const ASessionId: string): TSessionState;

    /// <summary>
    /// Try to retrieve a session by ID. Returns False if not found.
    /// </summary>
    function TryGetSession(const ASessionId: string; out AState: TSessionState): Boolean;

    /// <summary>
    /// Validate and execute a state transition using TStateMachine.
    /// Returns True if transition was valid and applied.
    /// Requirements: 1.4-1.5
    /// </summary>
    function TransitionTo(const ASessionId: string; ANewStatus: TSessionStatus): Boolean;

    /// <summary>
    /// Check if a session has exceeded the configured idle timeout.
    /// Returns True if (Now - LastActiveAt) > IdleTimeoutSeconds.
    /// Requirements: 1.5
    /// </summary>
    function CheckIdleTimeout(const ASessionId: string): Boolean;

    /// <summary>
    /// Serialize current session state into a checkpoint.
    /// Requirements: 16.1
    /// </summary>
    function SaveCheckpoint(const ASessionId: string): TSessionCheckpoint;

    /// <summary>
    /// Restore a session from a previously saved checkpoint.
    /// Returns the restored TSessionState with Status=ssActive.
    /// Requirements: 16.2
    /// </summary>
    function RestoreCheckpoint(const ACheckpoint: TSessionCheckpoint): TSessionState;

    /// <summary>
    /// Remove a session and its checkpoint from memory.
    /// </summary>
    procedure RemoveSession(const ASessionId: string);

    /// <summary>
    /// Check all active sessions for idle timeout and auto-suspend those
    /// that have exceeded the threshold. Returns list of suspended session IDs.
    /// </summary>
    function SuspendIdleSessions: TArray<string>;

    /// <summary>Number of sessions currently managed</summary>
    function SessionCount: Integer;

    /// <summary>Configurable idle timeout in seconds</summary>
    property IdleTimeoutSeconds: Integer read FIdleTimeoutSeconds write FIdleTimeoutSeconds;
  end;

implementation

const
  IC_STATUS_COMPLETED = TSessionStatus(2);
  IC_STATUS_ARCHIVED = TSessionStatus(3);

{ TSessionManager }

constructor TSessionManager.Create(AIdleTimeoutSeconds: Integer);
begin
  inherited Create;
  FSessions := TDictionary<string, TSessionState>.Create;
  FCheckpoints := TDictionary<string, TSessionCheckpoint>.Create;
  FLock := TCriticalSection.Create;
  FIdleTimeoutSeconds := AIdleTimeoutSeconds;
  Log(ltDebug, 'IC: SessionManager created');
end;

destructor TSessionManager.Destroy;
begin
  FLock.Free;
  FCheckpoints.Free;
  FSessions.Free;
  inherited;
end;

function TSessionManager.CreateStateMachine(
  AInitialState: TSessionStatus): TStateMachine<TSessionStatus, TSessionTrigger>;
begin
  Result := TStateMachine<TSessionStatus, TSessionTrigger>.Create(AInitialState);
  Result.Configure(ssActive)
    .Permit(stSuspend, ssSuspended)
    .Permit(stComplete, IC_STATUS_COMPLETED);
  Result.Configure(ssSuspended)
    .Permit(stResume, ssActive)
    .Permit(stArchive, IC_STATUS_ARCHIVED);
  Result.Configure(IC_STATUS_COMPLETED)
    .Permit(stArchive, IC_STATUS_ARCHIVED);
  // ssArchived is terminal - no transitions configured
end;

function TSessionManager.StatusToTrigger(ATarget: TSessionStatus): TSessionTrigger;
begin
  case ATarget of
    ssActive:    Result := stResume;
    ssSuspended: Result := stSuspend;
    IC_STATUS_COMPLETED: Result := stComplete;
    IC_STATUS_ARCHIVED:  Result := stArchive;
  else
    Result := stComplete; // fallback
  end;
end;

function TSessionManager.CreateSession(
  const ARequest: TClarificationStartRequest): TSessionState;
var
  LGuid: TGUID;
begin
  Result := Default(TSessionState);

  // Generate unique session ID
  CreateGUID(LGuid);
  Result.SessionId := GUIDToString(LGuid);

  // Initialize as Active with TurnCount=0 (Property 2, Requirement 1.2)
  Result.Status := ssActive;
  Result.CurrentPosture := posClarifying;
  Result.CurrentDepth := 0.3;
  Result.CurrentLevel := clL1;
  Result.TurnCount := 0;
  Result.CreatedAt := Now;
  Result.LastActiveAt := Now;
  Result.UserId := ARequest.UserId;
  Result.DomainName := ARequest.DomainName;
  Result.IntentName := ARequest.IntentName;
  Result.Hypotheses := nil;
  Result.Signals := nil;
  Result.CheckpointJson := '';

  FLock.Enter;
  try
    FSessions.Add(Result.SessionId, Result);
  finally
    FLock.Leave;
  end;

  Log(ltInfo, Format('IC: Session created id=%s, user=%s',
    [Result.SessionId, ARequest.UserId]));
end;

procedure TSessionManager.UpdateSession(const AState: TSessionState);
begin
  FLock.Enter;
  try
    if not FSessions.ContainsKey(AState.SessionId) then
      raise EArgumentException.CreateFmt('Session "%s" not found', [AState.SessionId]);
    FSessions.AddOrSetValue(AState.SessionId, AState);
  finally
    FLock.Leave;
  end;
end;

function TSessionManager.GetSession(const ASessionId: string): TSessionState;
begin
  FLock.Enter;
  try
    if not FSessions.TryGetValue(ASessionId, Result) then
      raise EArgumentException.CreateFmt('Session "%s" not found', [ASessionId]);
  finally
    FLock.Leave;
  end;
end;

function TSessionManager.TryGetSession(const ASessionId: string;
  out AState: TSessionState): Boolean;
begin
  FLock.Enter;
  try
    Result := FSessions.TryGetValue(ASessionId, AState);
  finally
    FLock.Leave;
  end;
end;

function TSessionManager.TransitionTo(const ASessionId: string;
  ANewStatus: TSessionStatus): Boolean;
var
  LState: TSessionState;
  LSM: TStateMachine<TSessionStatus, TSessionTrigger>;
  LTrigger: TSessionTrigger;
begin
  FLock.Enter;
  try
    if not FSessions.TryGetValue(ASessionId, LState) then
    begin
      Result := False;
      Exit;
    end;

    // Use StateMachine to validate and execute transition
    LSM := CreateStateMachine(LState.Status);
    try
      LTrigger := StatusToTrigger(ANewStatus);
      if not LSM.CanFire(LTrigger) then
      begin
        Log(ltWarning, Format('IC: Invalid transition for session %s: %d -> %d',
          [ASessionId, Ord(LState.Status), Ord(ANewStatus)]));
        Result := False;
        Exit;
      end;

      LSM.Fire(LTrigger);

      LState.Status := ANewStatus;
      LState.LastActiveAt := Now;
      FSessions.AddOrSetValue(ASessionId, LState);
      Result := True;

      Log(ltDebug, Format('IC: Session %s transitioned to status %d',
        [ASessionId, Ord(ANewStatus)]));
    finally
      LSM.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

function TSessionManager.CheckIdleTimeout(const ASessionId: string): Boolean;
var
  LState: TSessionState;
  LElapsedSeconds: Int64;
begin
  FLock.Enter;
  try
    if not FSessions.TryGetValue(ASessionId, LState) then
    begin
      Result := False;
      Exit;
    end;

    // Only active sessions can time out
    if LState.Status <> ssActive then
    begin
      Result := False;
      Exit;
    end;

    LElapsedSeconds := SecondsBetween(Now, LState.LastActiveAt);
    Result := LElapsedSeconds >= FIdleTimeoutSeconds;
  finally
    FLock.Leave;
  end;
end;

function TSessionManager.SaveCheckpoint(const ASessionId: string): TSessionCheckpoint;
var
  LState: TSessionState;
begin
  FLock.Enter;
  try
    if not FSessions.TryGetValue(ASessionId, LState) then
      raise EArgumentException.CreateFmt('Session "%s" not found', [ASessionId]);

    Result := Default(TSessionCheckpoint);
    Result.Version := 1;
    Result.SessionState := LState;
    Result.RapportSnapshot := Default(TRapportProfile);
    Result.RapportSnapshot.UserId := LState.UserId;
    Result.TurnHistory := nil;
    Result.OpenQuestions := nil;
    Result.ResumeHint := Format('Session was at turn %d, level %d. Resume to continue.',
      [LState.TurnCount, Ord(LState.CurrentLevel)]);
    Result.SerializedAt := Now;

    // Store checkpoint and update session's CheckpointJson
    FCheckpoints.AddOrSetValue(ASessionId, Result);
    LState.CheckpointJson := Result.ToJson;
    FSessions.AddOrSetValue(ASessionId, LState);
  finally
    FLock.Leave;
  end;

  Log(ltDebug, Format('IC: Checkpoint saved for session %s', [ASessionId]));
end;

function TSessionManager.RestoreCheckpoint(
  const ACheckpoint: TSessionCheckpoint): TSessionState;
var
  LState: TSessionState;
begin
  LState := ACheckpoint.SessionState;

  // Restored sessions become Active (Requirement 1.6)
  LState.Status := ssActive;
  LState.LastActiveAt := Now;

  FLock.Enter;
  try
    FSessions.AddOrSetValue(LState.SessionId, LState);
    FCheckpoints.AddOrSetValue(LState.SessionId, ACheckpoint);
  finally
    FLock.Leave;
  end;

  Log(ltInfo, Format('IC: Checkpoint restored for session %s, turn %d',
    [LState.SessionId, LState.TurnCount]));
  Result := LState;
end;

procedure TSessionManager.RemoveSession(const ASessionId: string);
begin
  FLock.Enter;
  try
    FSessions.Remove(ASessionId);
    FCheckpoints.Remove(ASessionId);
  finally
    FLock.Leave;
  end;
  Log(ltDebug, Format('IC: Session %s removed', [ASessionId]));
end;

function TSessionManager.SuspendIdleSessions: TArray<string>;
var
  LPair: TPair<string, TSessionState>;
  LElapsedSeconds: Int64;
  LState: TSessionState;
  LSuspended: TList<string>;
  LKeys: TList<string>;
  LKey: string;
begin
  LSuspended := TList<string>.Create;
  LKeys := TList<string>.Create;
  try
    // IC-004: Collect candidate keys under the lock without mutating the
    // dictionary inside the iterator, then update each key in a separate pass.
    FLock.Enter;
    try
      for LPair in FSessions do
      begin
        if LPair.Value.Status = ssActive then
        begin
          LElapsedSeconds := SecondsBetween(Now, LPair.Value.LastActiveAt);
          if LElapsedSeconds >= FIdleTimeoutSeconds then
            LKeys.Add(LPair.Key);
        end;
      end;
    finally
      FLock.Leave;
    end;

    for LKey in LKeys do
    begin
      FLock.Enter;
      try
        if FSessions.TryGetValue(LKey, LState) and (LState.Status = ssActive) then
        begin
          LState.Status := ssSuspended;
          LState.LastActiveAt := Now;
          FSessions.AddOrSetValue(LKey, LState);
          LSuspended.Add(LKey);
        end;
      finally
        FLock.Leave;
      end;
    end;

    if LSuspended.Count > 0 then
      Log(ltInfo, Format('IC: Auto-suspended %d idle sessions', [LSuspended.Count]));

    Result := LSuspended.ToArray;
  finally
    LSuspended.Free;
    LKeys.Free;
  end;
end;

function TSessionManager.SessionCount: Integer;
begin
  FLock.Enter;
  try
    Result := FSessions.Count;
  finally
    FLock.Leave;
  end;
end;

end.
