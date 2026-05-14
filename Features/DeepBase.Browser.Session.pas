{ ============================================================================
  DeepBase.Browser.Session
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Browser session lifecycle manager using a finite state machine.
                Wraps an IBrowserSession and adds state transitions, recovery
                integration, and event publishing on state changes.
  ============================================================================ }

unit DeepBase.Browser.Session;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DeepBase.StateMachine,
  DeepBase.Browser.Types;

type
  TBrowserSessionManager = class
  private
    FSession: IBrowserSession;
    FRecovery: IBrowserRecovery;
    FStateMachine: TStateMachine<TBrowserSessionState, TBrowserSessionTrigger>;
    FLock: TCriticalSection;

    procedure ConfigureStateMachine;
    procedure PublishStateChange(
      const AFrom, ATo: TBrowserSessionState;
      const ATrigger: TBrowserSessionTrigger);
    procedure HandleStateChanged(Sender: TObject;
      const AOldState, ANewState: TBrowserSessionState;
      const ATrigger: TBrowserSessionTrigger);
  public
    constructor Create(ASession: IBrowserSession;
      ARecovery: IBrowserRecovery = nil);
    destructor Destroy; override;

    function Initialize: Boolean;
    procedure Dispose;
    procedure NotifyReady;
    procedure NotifyBusy;
    procedure NotifyComplete;
    procedure NotifyError;
    procedure NotifyCrashed;

    function GetCurrentState: TBrowserSessionState;
    function CanFire(
      ATrigger: TBrowserSessionTrigger): Boolean;
    function GetPermittedTriggers:
      TArray<TBrowserSessionTrigger>;

    property Session: IBrowserSession read FSession;
    property StateMachine:
      TStateMachine<TBrowserSessionState, TBrowserSessionTrigger>
      read FStateMachine;
    property Recovery: IBrowserRecovery read FRecovery;
  end;

implementation

uses
  DeepBase.Logging,
  DeepBase.Browser.Events;

function BrowserSessionTriggerToString(
  ATrigger: TBrowserSessionTrigger): string;
begin
  case ATrigger of
    bstInitialize: Result := 'initialize';
    bstReady: Result := 'ready';
    bstNavigate: Result := 'navigate';
    bstComplete: Result := 'complete';
    bstError: Result := 'error';
    bstUnresponsive: Result := 'unresponsive';
    bstRecoverStart: Result := 'recover_start';
    bstRecoverSuccess: Result := 'recover_success';
    bstRecoverFail: Result := 'recover_fail';
    bstCrash: Result := 'crash';
    bstDispose: Result := 'dispose';
  else
    Result := IntToStr(Integer(ATrigger));
  end;
end;

{ TBrowserSessionManager }

constructor TBrowserSessionManager.Create(ASession: IBrowserSession;
  ARecovery: IBrowserRecovery);
begin
  inherited Create;
  FSession := ASession;
  FRecovery := ARecovery;
  FLock := TCriticalSection.Create;

  FStateMachine :=
    TStateMachine<TBrowserSessionState,
      TBrowserSessionTrigger>.Create(bssUninitialized);
  FStateMachine.ThrowOnUnhandledTrigger := False;
  ConfigureStateMachine;
  FStateMachine.Start;
end;

destructor TBrowserSessionManager.Destroy;
begin
  FStateMachine.Free;
  FLock.Free;
  inherited;
end;

procedure TBrowserSessionManager.ConfigureStateMachine;
begin
  // bssUninitialized
  FStateMachine.Configure(bssUninitialized)
    .Permit(bstInitialize, bssInitializing)
    .Permit(bstDispose, bssDisposed)
    .OnTransition(bstInitialize,
      procedure(const AFrom, ATo: TBrowserSessionState;
        const ATrigger: TBrowserSessionTrigger;
        const AContext: TObject)
      begin
        PublishStateChange(AFrom, ATo, ATrigger);
      end);

  // bssInitializing
  FStateMachine.Configure(bssInitializing)
    .Permit(bstReady, bssReady)
    .Permit(bstError, bssCrashed)
    .Permit(bstDispose, bssDisposed)
    .OnTransition(bstReady,
      procedure(const AFrom, ATo: TBrowserSessionState;
        const ATrigger: TBrowserSessionTrigger;
        const AContext: TObject)
      begin
        PublishStateChange(AFrom, ATo, ATrigger);
        if FRecovery <> nil then
          FRecovery.RecordHeartbeat(FSession.GetSessionId);
      end)
    .OnTransition(bstError,
      procedure(const AFrom, ATo: TBrowserSessionState;
        const ATrigger: TBrowserSessionTrigger;
        const AContext: TObject)
      begin
        PublishStateChange(AFrom, ATo, ATrigger);
      end);

  // bssReady
  FStateMachine.Configure(bssReady)
    .Permit(bstNavigate, bssBusy)
    .Permit(bstError, bssUnresponsive)
    .Permit(bstCrash, bssCrashed)
    .Permit(bstDispose, bssDisposed)
    .OnTransition(bstNavigate,
      procedure(const AFrom, ATo: TBrowserSessionState;
        const ATrigger: TBrowserSessionTrigger;
        const AContext: TObject)
      begin
        PublishStateChange(AFrom, ATo, ATrigger);
      end);

  // bssBusy
  FStateMachine.Configure(bssBusy)
    .Permit(bstComplete, bssReady)
    .Permit(bstError, bssUnresponsive)
    .Permit(bstCrash, bssCrashed)
    .Permit(bstDispose, bssDisposed)
    .OnTransition(bstComplete,
      procedure(const AFrom, ATo: TBrowserSessionState;
        const ATrigger: TBrowserSessionTrigger;
        const AContext: TObject)
      begin
        PublishStateChange(AFrom, ATo, ATrigger);
        if FRecovery <> nil then
          FRecovery.RecordHeartbeat(FSession.GetSessionId);
      end);

  // bssUnresponsive
  FStateMachine.Configure(bssUnresponsive)
    .Permit(bstRecoverStart, bssRecovering)
    .Permit(bstCrash, bssCrashed)
    .Permit(bstDispose, bssDisposed)
    .OnTransition(bstRecoverStart,
      procedure(const AFrom, ATo: TBrowserSessionState;
        const ATrigger: TBrowserSessionTrigger;
        const AContext: TObject)
      begin
        PublishStateChange(AFrom, ATo, ATrigger);
        if FRecovery <> nil then
          FRecovery.TriggerRecovery(FSession.GetSessionId, brsReload);
      end);

  // bssRecovering
  FStateMachine.Configure(bssRecovering)
    .Permit(bstRecoverSuccess, bssReady)
    .Permit(bstRecoverFail, bssCrashed)
    .Permit(bstCrash, bssCrashed)         // BUG-BA-022 fix
    .Permit(bstError, bssCrashed)         // BUG-BA-022 fix
    .Permit(bstDispose, bssDisposed)
    .OnTransition(bstRecoverSuccess,
      procedure(const AFrom, ATo: TBrowserSessionState;
        const ATrigger: TBrowserSessionTrigger;
        const AContext: TObject)
      begin
        PublishStateChange(AFrom, ATo, ATrigger);
        if FRecovery <> nil then
        begin
          FRecovery.ResetRetryCount(FSession.GetSessionId);
          FRecovery.RecordHeartbeat(FSession.GetSessionId);
        end;
      end);

  // bssCrashed
  FStateMachine.Configure(bssCrashed)
    .Permit(bstInitialize, bssInitializing)
    .Permit(bstDispose, bssDisposed)
    .OnEntry(
      procedure(const AContext: TObject)
      begin
        if FRecovery <> nil then
          FRecovery.UpdateHealthStatus(
            FSession.GetSessionId, bhsCrashed);
      end);

  // bssDisposed (terminal) - no outgoing transitions to configure
  FStateMachine.Configure(bssDisposed);

  // BUG-BA-023 fix: publish bssDisposed entry via OnStateChanged so we
  // capture the actual AFrom state (instead of bssDisposed -> bssDisposed
  // that the old OnEntry produced).

  // State change logging + bssDisposed publishing (BUG-BA-023 fix)
  FStateMachine.OnStateChanged := HandleStateChanged;
end;

procedure TBrowserSessionManager.HandleStateChanged(Sender: TObject;
  const AOldState, ANewState: TBrowserSessionState;
  const ATrigger: TBrowserSessionTrigger);
begin
  Logger.DebugFmt('Browser session %s: %s -> %s [%s]',
    [FSession.GetSessionId,
     BrowserSessionStateToString(AOldState),
     BrowserSessionStateToString(ANewState),
     BrowserSessionTriggerToString(ATrigger)],
    'TBrowserSessionManager');

  // BUG-BA-023 fix: capture AOldState here, since OnEntry would have
  // shown the new state for both AFrom and ATo.
  if ANewState = bssDisposed then
    PublishStateChange(AOldState, ANewState, ATrigger);
end;

procedure TBrowserSessionManager.PublishStateChange(
  const AFrom, ATo: TBrowserSessionState;
  const ATrigger: TBrowserSessionTrigger);
var
  LEventType: TBrowserEventType;
begin
  case ATrigger of
    bstReady, bstComplete:
      LEventType := betNavigationCompleted;
    bstError:
      LEventType := betNavigationFailed;
    bstCrash:
      LEventType := betCrashed;
    bstRecoverSuccess:
      LEventType := betRecovered;
  else
    LEventType := betHealthChanged;
  end;

  TBrowserEvents.Publish(LEventType,
    FSession.GetSessionId,
    '{"from":"' + BrowserSessionStateToString(AFrom) + '",' +
    '"to":"' + BrowserSessionStateToString(ATo) + '",' +
    '"trigger":"' + BrowserSessionTriggerToString(ATrigger) + '"}');
end;

function TBrowserSessionManager.Initialize: Boolean;
var
  LResult: TTransitionResult<TBrowserSessionState,
    TBrowserSessionTrigger>;
begin
  FLock.Enter;
  try
    LResult := FStateMachine.Fire(bstInitialize);
    Result := LResult.Success;
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSessionManager.Dispose;
begin
  FLock.Enter;
  try
    FStateMachine.Fire(bstDispose);
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSessionManager.NotifyReady;
begin
  FLock.Enter;
  try
    FStateMachine.Fire(bstReady);
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSessionManager.NotifyBusy;
begin
  FLock.Enter;
  try
    FStateMachine.Fire(bstNavigate);
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSessionManager.NotifyComplete;
begin
  FLock.Enter;
  try
    FStateMachine.Fire(bstComplete);
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSessionManager.NotifyError;
begin
  FLock.Enter;
  try
    if FStateMachine.CanFire(bstError) then
      FStateMachine.Fire(bstError)
    else if FStateMachine.CanFire(bstCrash) then
      FStateMachine.Fire(bstCrash);
  finally
    FLock.Leave;
  end;
end;

procedure TBrowserSessionManager.NotifyCrashed;
begin
  FLock.Enter;
  try
    FStateMachine.Fire(bstCrash);
  finally
    FLock.Leave;
  end;
end;

function TBrowserSessionManager.GetCurrentState:
  TBrowserSessionState;
begin
  Result := FStateMachine.CurrentState;
end;

function TBrowserSessionManager.CanFire(
  ATrigger: TBrowserSessionTrigger): Boolean;
begin
  Result := FStateMachine.CanFire(ATrigger);
end;

function TBrowserSessionManager.GetPermittedTriggers:
  TArray<TBrowserSessionTrigger>;
begin
  Result := FStateMachine.GetPermittedTriggers;
end;

end.
