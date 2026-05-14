{ ============================================================================
  DeepBase.Browser.Recovery
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Browser health monitoring and automatic recovery manager.
                Generalized from DeepCompare.BrowserRecovery (Phase 12.3.1).
                Monitors browser health via heartbeat tracking, detects
                unresponsive/crashed sessions, and triggers recovery strategies.
  Thread Safety: All public methods are thread-safe via FLock.
  ============================================================================ }

unit DeepBase.Browser.Recovery;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Generics.Collections,
  DeepBase.Browser.Types;

type
  TBrowserRecoveryManager = class(TInterfacedObject, IBrowserRecovery)
  private
    FConfig: TBrowserRecoveryConfig;
    FSnapshots: TDictionary<TBrowserSessionId, TBrowserSnapshot>;
    FHealthStatus: TDictionary<TBrowserSessionId, TBrowserHealthStatus>;
    FRetryCount: TDictionary<TBrowserSessionId, Integer>;
    FLastHeartbeat: TDictionary<TBrowserSessionId, TDateTime>;
    FLock: TCriticalSection;
    FOnRecovery: TRecoveryEvent;
    FHealthMonitorThread: TThread;
    FHealthMonitorStop: TEvent;

    // BUG-BA-025 fix: factory + rebuilt event close the recovery loop.
    FSessionFactory: IBrowserSessionFactory;
    FOnSessionRebuilt: TSessionRebuiltEvent;

    procedure HealthMonitorLoop;
    procedure RunHealthCheck;
    function DetermineRecoveryStrategy(
      const ASessionId: TBrowserSessionId;
      AStatus: TBrowserHealthStatus): TBrowserRecoveryStrategy;
    procedure DoRecovery(const ASessionId: TBrowserSessionId;
      AStrategy: TBrowserRecoveryStrategy);

    // C1/C2 fix: lock-free internal helpers; callers MUST hold FLock.
    function InternalGetRetryCount(
      const ASessionId: TBrowserSessionId): Integer;
    function InternalGetHealthStatus(
      const ASessionId: TBrowserSessionId): TBrowserHealthStatus;
  public
    constructor Create(
      const AConfig: TBrowserRecoveryConfig);
    destructor Destroy; override;

    procedure SaveSnapshot(const ASnapshot: TBrowserSnapshot);
    function GetSnapshot(
      const ASessionId: TBrowserSessionId): TBrowserSnapshot;
    procedure ClearSnapshot(const ASessionId: TBrowserSessionId);
    procedure UpdateHealthStatus(
      const ASessionId: TBrowserSessionId;
      AStatus: TBrowserHealthStatus);
    function GetHealthStatus(
      const ASessionId: TBrowserSessionId): TBrowserHealthStatus;
    procedure RecordHeartbeat(
      const ASessionId: TBrowserSessionId);
    function IsUnresponsive(
      const ASessionId: TBrowserSessionId): Boolean;
    procedure TriggerRecovery(
      const ASessionId: TBrowserSessionId;
      AStrategy: TBrowserRecoveryStrategy);
    procedure ResetRetryCount(
      const ASessionId: TBrowserSessionId);
    function GetRetryCount(
      const ASessionId: TBrowserSessionId): Integer;
    procedure StartHealthMonitor;
    procedure StopHealthMonitor;

    property OnRecovery: TRecoveryEvent
      read FOnRecovery write FOnRecovery;
    property OnSessionRebuilt: TSessionRebuiltEvent
      read FOnSessionRebuilt write FOnSessionRebuilt;
    property SessionFactory: IBrowserSessionFactory
      read FSessionFactory write FSessionFactory;
    property Config: TBrowserRecoveryConfig
      read FConfig write FConfig;
  end;

function BrowserRecovery: IBrowserRecovery;

implementation

uses
  System.DateUtils,
  DeepBase.Logging;

var
  GRecovery: IBrowserRecovery = nil;
  GRecoveryLock: TCriticalSection = nil;

function BrowserRecovery: IBrowserRecovery;
begin
  if GRecovery = nil then
  begin
    GRecoveryLock.Enter;
    try
      if GRecovery = nil then
        GRecovery := TBrowserRecoveryManager.Create(
          TBrowserRecoveryConfig.Default);
    finally
      GRecoveryLock.Leave;
    end;
  end;
  Result := GRecovery;
end;

{ TBrowserRecoveryManager }

constructor TBrowserRecoveryManager.Create(
  const AConfig: TBrowserRecoveryConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FSnapshots :=
    TDictionary<TBrowserSessionId, TBrowserSnapshot>.Create;
  FHealthStatus :=
    TDictionary<TBrowserSessionId, TBrowserHealthStatus>.Create;
  FRetryCount :=
    TDictionary<TBrowserSessionId, Integer>.Create;
  FLastHeartbeat :=
    TDictionary<TBrowserSessionId, TDateTime>.Create;
  FLock := TCriticalSection.Create;
  FHealthMonitorStop := TEvent.Create(nil, True, False, '');
  FHealthMonitorThread := nil;
end;

destructor TBrowserRecoveryManager.Destroy;
begin
  StopHealthMonitor;
  FHealthMonitorStop.Free;
  FLock.Free;
  FLastHeartbeat.Free;
  FRetryCount.Free;
  FHealthStatus.Free;
  FSnapshots.Free;
  inherited;
end;

procedure TBrowserRecoveryManager.SaveSnapshot(
  const ASnapshot: TBrowserSnapshot);
begin
  FLock.Enter;
  try
    FSnapshots.AddOrSetValue(ASnapshot.SessionId, ASnapshot);
    Logger.InfoFmt('Browser snapshot saved: %s',
      [ASnapshot.SessionId], 'TBrowserRecoveryManager');
  finally
    FLock.Leave;
  end;
end;

function TBrowserRecoveryManager.GetSnapshot(
  const ASessionId: TBrowserSessionId): TBrowserSnapshot;
begin
  FLock.Enter;
  try
    if not FSnapshots.TryGetValue(ASessionId, Result) then
      Result := TBrowserSnapshot.Create(ASessionId);
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserRecoveryManager.ClearSnapshot(
  const ASessionId: TBrowserSessionId);
begin
  FLock.Enter;
  try
    FSnapshots.Remove(ASessionId);
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserRecoveryManager.UpdateHealthStatus(
  const ASessionId: TBrowserSessionId;
  AStatus: TBrowserHealthStatus);
var
  OldStatus: TBrowserHealthStatus;
  Strategy: TBrowserRecoveryStrategy;
  StatusChanged: Boolean;
begin
  // BUG-BA-013 fix: split decision (locked) from execution (unlocked).
  // Old code held FLock through DoRecovery -> Sleep(2000) -> OnRecovery
  // callback, which blocked all other readers/writers for seconds.
  Strategy := brsNone;
  StatusChanged := False;

  FLock.Enter;
  try
    if not FHealthStatus.TryGetValue(ASessionId, OldStatus) then
      OldStatus := bhsHealthy;

    FHealthStatus.AddOrSetValue(ASessionId, AStatus);

    if OldStatus <> AStatus then
    begin
      StatusChanged := True;
      if (AStatus in [bhsCrashed, bhsNetworkError]) and
        FConfig.AutoRecoveryEnabled then
        Strategy := DetermineRecoveryStrategy(ASessionId, AStatus);
    end;
  finally
    FLock.Leave;
  end;

  if StatusChanged then
    Logger.InfoFmt('Health changed: %s %s -> %s',
      [ASessionId,
       BrowserHealthStatusToString(OldStatus),
       BrowserHealthStatusToString(AStatus)],
      'TBrowserRecoveryManager');

  if Strategy <> brsNone then
    DoRecovery(ASessionId, Strategy);
end;

function TBrowserRecoveryManager.GetHealthStatus(
  const ASessionId: TBrowserSessionId): TBrowserHealthStatus;
begin
  FLock.Enter;
  try
    if not FHealthStatus.TryGetValue(ASessionId, Result) then
      Result := bhsHealthy;
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserRecoveryManager.RecordHeartbeat(
  const ASessionId: TBrowserSessionId);
var
  LWasUnresponsive: Boolean;
begin
  // C1 fix: do all dictionary work inside one lock acquisition.
  // Use InternalGetHealthStatus (no-lock) to avoid re-entering FLock.
  LWasUnresponsive := False;
  FLock.Enter;
  try
    FLastHeartbeat.AddOrSetValue(ASessionId, Now);

    if InternalGetHealthStatus(ASessionId) = bhsUnresponsive then
    begin
      FHealthStatus.AddOrSetValue(ASessionId, bhsHealthy);
      LWasUnresponsive := True;
    end;
  finally
    FLock.Leave;
  end;

  if LWasUnresponsive then
    Logger.InfoFmt('Recovered from unresponsive: %s',
      [ASessionId], 'TBrowserRecoveryManager');
end;

function TBrowserRecoveryManager.IsUnresponsive(
  const ASessionId: TBrowserSessionId): Boolean;
var
  LastTime: TDateTime;
begin
  FLock.Enter;
  try
    if FLastHeartbeat.TryGetValue(ASessionId, LastTime) then
      Result := MilliSecondsBetween(Now, LastTime) >
        FConfig.UnresponsiveThresholdMs
    else
      Result := False;
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserRecoveryManager.TriggerRecovery(
  const ASessionId: TBrowserSessionId;
  AStrategy: TBrowserRecoveryStrategy);
begin
  DoRecovery(ASessionId, AStrategy);
end;

procedure TBrowserRecoveryManager.ResetRetryCount(
  const ASessionId: TBrowserSessionId);
begin
  FLock.Enter;
  try
    FRetryCount.AddOrSetValue(ASessionId, 0);
  finally
    FLock.Leave;
  end;
end;

function TBrowserRecoveryManager.GetRetryCount(
  const ASessionId: TBrowserSessionId): Integer;
begin
  FLock.Enter;
  try
    Result := InternalGetRetryCount(ASessionId);
  finally
    FLock.Leave;
  end;
end;

function TBrowserRecoveryManager.InternalGetRetryCount(
  const ASessionId: TBrowserSessionId): Integer;
begin
  // C2 fix: lock-free; caller must hold FLock.
  if not FRetryCount.TryGetValue(ASessionId, Result) then
    Result := 0;
end;

function TBrowserRecoveryManager.InternalGetHealthStatus(
  const ASessionId: TBrowserSessionId): TBrowserHealthStatus;
begin
  // C1 fix: lock-free; caller must hold FLock.
  if not FHealthStatus.TryGetValue(ASessionId, Result) then
    Result := bhsHealthy;
end;

procedure TBrowserRecoveryManager.StartHealthMonitor;
begin
  FLock.Enter;
  try
    if FHealthMonitorThread <> nil then
      Exit;

    FHealthMonitorStop.ResetEvent;
    FHealthMonitorThread := TThread.CreateAnonymousThread(HealthMonitorLoop);
    FHealthMonitorThread.FreeOnTerminate := False;
    FHealthMonitorThread.Start;
  finally
    FLock.Leave;
  end;

  Logger.Info('Browser health monitor started',
    'TBrowserRecoveryManager');
end;

procedure TBrowserRecoveryManager.StopHealthMonitor;
var
  LThread: TThread;
begin
  LThread := nil;

  FLock.Enter;
  try
    if FHealthMonitorThread <> nil then
    begin
      LThread := FHealthMonitorThread;
      FHealthMonitorThread := nil;
      FHealthMonitorStop.SetEvent;
      LThread.Terminate;
    end;
  finally
    FLock.Leave;
  end;

  if LThread <> nil then
  begin
    LThread.WaitFor;
    LThread.Free;
  end;

  Logger.Info('Browser health monitor stopped',
    'TBrowserRecoveryManager');
end;

procedure TBrowserRecoveryManager.HealthMonitorLoop;
begin
  while FHealthMonitorStop.WaitFor(
    Cardinal(FConfig.HealthCheckIntervalMs)) = wrTimeout do
  begin
    if TThread.CurrentThread.CheckTerminated then
      Break;
    RunHealthCheck;
  end;
end;

procedure TBrowserRecoveryManager.RunHealthCheck;
var
  SessionId: TBrowserSessionId;
  Sessions: TArray<TBrowserSessionId>;
begin
  FLock.Enter;
  try
    Sessions := FLastHeartbeat.Keys.ToArray;
  finally
    FLock.Leave;
  end;

  for SessionId in Sessions do
  begin
    if IsUnresponsive(SessionId) then
    begin
      Logger.WarnFmt('Unresponsive detected: %s',
        [SessionId], 'TBrowserRecoveryManager');
      UpdateHealthStatus(SessionId, bhsUnresponsive);

      if FConfig.AutoRecoveryEnabled then
        TriggerRecovery(SessionId, brsReload);
    end;
  end;
end;

function TBrowserRecoveryManager.DetermineRecoveryStrategy(
  const ASessionId: TBrowserSessionId;
  AStatus: TBrowserHealthStatus): TBrowserRecoveryStrategy;
var
  LRetryCount: Integer;
begin
  // C2 fix: caller (UpdateHealthStatus / RunHealthCheck) holds FLock.
  // Use no-lock helper to avoid re-entry.
  LRetryCount := InternalGetRetryCount(ASessionId);

  if LRetryCount >= FConfig.MaxRetries then
  begin
    Logger.WarnFmt('Max retries exceeded: %s',
      [ASessionId], 'TBrowserRecoveryManager');
    Exit(brsNone);
  end;

  case AStatus of
    bhsUnresponsive: Result := brsReload;
    bhsNetworkError: Result := brsReload;
    bhsCrashed:
      if LRetryCount < 2 then
        Result := brsRestart
      else
        Result := brsRecreate;
  else
    Result := brsNone;
  end;
end;

procedure TBrowserRecoveryManager.DoRecovery(
  const ASessionId: TBrowserSessionId;
  AStrategy: TBrowserRecoveryStrategy);
var
  LRetryCount: Integer;
  LFactorySuccess: Boolean;
  LFactoryAttempted: Boolean;
  LCallbackOk: Boolean;
  LFinalSuccess: Boolean;
  LNewSession: IBrowserSession;
begin
  if AStrategy = brsNone then
    Exit;

  // C2 fix: increment retry counter and pre-set status under lock; everything
  // else (Sleep, factory, callback) runs lock-free.
  FLock.Enter;
  try
    LRetryCount := InternalGetRetryCount(ASessionId) + 1;
    FRetryCount.AddOrSetValue(ASessionId, LRetryCount);
    FHealthStatus.AddOrSetValue(ASessionId, bhsRecovering);
  finally
    FLock.Leave;
  end;

  Logger.InfoFmt('Recovery started: %s, strategy=%s, attempt=%d',
    [ASessionId,
     BrowserRecoveryStrategyToString(AStrategy),
     LRetryCount],
    'TBrowserRecoveryManager');

  Sleep(FConfig.RetryDelayMs);

  LFactorySuccess := False;
  LFactoryAttempted := False;
  LCallbackOk := True;  // assume true if no callback assigned
  LNewSession := nil;

  // BUG-BA-025 + H1 fix: brsRecreate path; track factory outcome explicitly.
  if (AStrategy = brsRecreate) and (FSessionFactory <> nil) then
  begin
    LFactoryAttempted := True;
    try
      LNewSession := FSessionFactory.CreateSession(ASessionId);
      LFactorySuccess := LNewSession <> nil;
      if LFactorySuccess and Assigned(FOnSessionRebuilt) then
        FOnSessionRebuilt(ASessionId, LNewSession);
    except
      on E: Exception do
      begin
        Logger.ErrorFmt('Recovery factory failed: %s - %s',
          [ASessionId, E.Message], 'TBrowserRecoveryManager');
        LFactorySuccess := False;
      end;
    end;
  end;

  // H1 fix: do NOT mask callback failures. Only assume "user handled it"
  // when the callback both ran AND completed without raising.
  if Assigned(FOnRecovery) then
  begin
    LCallbackOk := False;
    try
      // Pass the actual factory outcome (or False if factory wasn't invoked)
      FOnRecovery(ASessionId, AStrategy, LRetryCount,
        LFactoryAttempted and LFactorySuccess);
      LCallbackOk := True;
    except
      on E: Exception do
        Logger.ErrorFmt('Recovery callback failed: %s - %s',
          [ASessionId, E.Message], 'TBrowserRecoveryManager');
    end;
  end;

  // Final success rule:
  //   - If factory was attempted: success iff factory created a session
  //   - Else: success iff a callback ran without raising
  if LFactoryAttempted then
    LFinalSuccess := LFactorySuccess
  else
    LFinalSuccess := LCallbackOk and Assigned(FOnRecovery);

  FLock.Enter;
  try
    if LFinalSuccess then
    begin
      FHealthStatus.AddOrSetValue(ASessionId, bhsHealthy);
      FRetryCount.AddOrSetValue(ASessionId, 0);  // reset, no helper call
      Logger.InfoFmt('Recovery successful: %s',
        [ASessionId], 'TBrowserRecoveryManager');
    end
    else
    begin
      if InternalGetRetryCount(ASessionId) >= FConfig.MaxRetries then
        FHealthStatus.AddOrSetValue(ASessionId, bhsCrashed)
      else
        FHealthStatus.AddOrSetValue(ASessionId, bhsUnresponsive);
    end;
  finally
    FLock.Leave;
  end;
end;

initialization
  GRecoveryLock := TCriticalSection.Create;

finalization
  GRecovery := nil;
  FreeAndNil(GRecoveryLock);

end.
