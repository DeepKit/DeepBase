{ ============================================================================
  M11 fix: integration tests covering Recovery's actual recovery execution
  paths: factory-driven recreate, OnRecovery callback, and best-effort
  fallback. The original Test.DeepBase.Browser.Recovery suite only exercised
  bookkeeping (snapshots/heartbeat/status) — the DoRecovery / TriggerRecovery
  / StartHealthMonitor execution paths were never run.
  ============================================================================ }

unit Test.DeepBase.Browser.Recovery.Integration;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Recovery;

type
  /// <summary>
  /// Minimal stub IBrowserSession used as the "rebuilt" session returned
  /// by a recovery factory. None of the methods need real behavior — the
  /// factory only needs to hand back a non-nil interface for the recovery
  /// loop to consider the rebuild a success.
  /// </summary>
  TFakeRecoverySession = class(TInterfacedObject, IBrowserSession)
  private
    FId: TBrowserSessionId;
  public
    constructor Create(const AId: TBrowserSessionId);
    function GetSessionId: TBrowserSessionId;
    function GetState: TBrowserSessionState;
    function IsReady: Boolean;
    function GetCurrentUrl: string;
    function GetLastError: string;
    function Navigate(const AUrl: string; ATimeoutMs: Integer;
      out AError: string): Boolean;
    function ExecuteScript(const AScript: string;
      out AError: string): Boolean;
    function EvaluateScript(const AScript: string; ATimeoutMs: Integer;
      out AJsonResult, AError: string): Boolean;
    function CallDevToolsProtocol(const AMethod, AParams: string;
      ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
    function CaptureScreenshot(out AImage: TBytes;
      out AError: string): Boolean;
    function AsAutomationSession: IBrowserAutomationSession;
  end;

  /// <summary>
  /// Controllable IBrowserSessionFactory: callers configure whether the
  /// next CreateSession returns a fresh fake session (success) or nil
  /// (factory-side failure path).
  /// </summary>
  TFakeSessionFactory = class(TInterfacedObject, IBrowserSessionFactory)
  private
    FSucceed: Boolean;
    FCallCount: Integer;
    FDisposeCount: Integer;
  public
    constructor Create(ASucceed: Boolean);
    function CreateSession(const AHintId: TBrowserSessionId): IBrowserSession;
    procedure DisposeSession(const ASession: IBrowserSession);
    property CallCount: Integer read FCallCount;
    property DisposeCount: Integer read FDisposeCount;
  end;

  /// <summary>
  /// Recovery event holder — TRecoveryEvent is a `procedure ... of object`
  /// so we need a real class instance to point at.
  /// </summary>
  TRecoveryCallbackHolder = class
  private
    FCalled: Boolean;
    FRaiseOnCall: Boolean;
    FLastSuccessFlag: Boolean;
  public
    procedure HandleRecovery(const ASessionId: TBrowserSessionId;
      AStrategy: TBrowserRecoveryStrategy; AAttempt: Integer;
      ASuccess: Boolean);
    property Called: Boolean read FCalled write FCalled;
    property RaiseOnCall: Boolean read FRaiseOnCall write FRaiseOnCall;
    property LastSuccessFlag: Boolean read FLastSuccessFlag;
  end;

  [TestFixture]
  TRecoveryIntegrationTests = class
  public
    [Test] procedure Test_DoRecovery_FactoryAttempted_Success;
    [Test] procedure Test_DoRecovery_FactoryAttempted_Failure;
    [Test] procedure Test_DoRecovery_OnRecoveryCallback_Success;
    [Test] procedure Test_DoRecovery_OnRecoveryCallback_Failure;
    [Test] procedure Test_DoRecovery_NoFactoryNoCallback_BestEffort;
    [Test] procedure Test_TriggerRecovery_IncrementsRetryCount;
    [Test] procedure Test_StartStopHealthMonitor_NoLeak;
  end;

implementation

{ TFakeRecoverySession }

constructor TFakeRecoverySession.Create(const AId: TBrowserSessionId);
begin
  inherited Create;
  FId := AId;
end;

function TFakeRecoverySession.GetSessionId: TBrowserSessionId;
begin
  Result := FId;
end;

function TFakeRecoverySession.GetState: TBrowserSessionState;
begin
  Result := bssReady;
end;

function TFakeRecoverySession.IsReady: Boolean;
begin
  Result := True;
end;

function TFakeRecoverySession.GetCurrentUrl: string;
begin
  Result := 'about:blank';
end;

function TFakeRecoverySession.GetLastError: string;
begin
  Result := '';
end;

function TFakeRecoverySession.Navigate(const AUrl: string;
  ATimeoutMs: Integer; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeRecoverySession.ExecuteScript(const AScript: string;
  out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeRecoverySession.EvaluateScript(const AScript: string;
  ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := 'null';
  AError := '';
  Result := True;
end;

function TFakeRecoverySession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := '{}';
  AError := '';
  Result := True;
end;

function TFakeRecoverySession.CaptureScreenshot(out AImage: TBytes;
  out AError: string): Boolean;
begin
  AImage := nil;
  AError := '';
  Result := True;
end;

function TFakeRecoverySession.AsAutomationSession: IBrowserAutomationSession;
begin
  Result := nil;
end;

{ TFakeSessionFactory }

constructor TFakeSessionFactory.Create(ASucceed: Boolean);
begin
  inherited Create;
  FSucceed := ASucceed;
  FCallCount := 0;
  FDisposeCount := 0;
end;

function TFakeSessionFactory.CreateSession(
  const AHintId: TBrowserSessionId): IBrowserSession;
begin
  Inc(FCallCount);
  if FSucceed then
    Result := TFakeRecoverySession.Create(AHintId + '-rebuilt')
  else
    Result := nil;
end;

procedure TFakeSessionFactory.DisposeSession(
  const ASession: IBrowserSession);
begin
  Inc(FDisposeCount);
  // No-op for fake; real factory would release OS resources.
end;

{ TRecoveryCallbackHolder }

procedure TRecoveryCallbackHolder.HandleRecovery(
  const ASessionId: TBrowserSessionId;
  AStrategy: TBrowserRecoveryStrategy; AAttempt: Integer;
  ASuccess: Boolean);
begin
  FCalled := True;
  FLastSuccessFlag := ASuccess;
  if FRaiseOnCall then
    raise Exception.Create('callback test failure');
end;

{ ----------------------------------------------------------------------
  Helper: build a config with tiny RetryDelayMs to keep tests fast.
  ---------------------------------------------------------------------- }

function FastRecoveryConfig: TBrowserRecoveryConfig;
begin
  Result := TBrowserRecoveryConfig.Default;
  Result.RetryDelayMs := 1;
  Result.AutoRecoveryEnabled := False;
end;

{ TRecoveryIntegrationTests }

procedure TRecoveryIntegrationTests.Test_DoRecovery_FactoryAttempted_Success;
var
  LMgr: TBrowserRecoveryManager;
  LFactory: TFakeSessionFactory;
  LFactoryIntf: IBrowserSessionFactory;
  LRebuiltSeen: Boolean;
  LSessionId: TBrowserSessionId;
begin
  LSessionId := 'sess-recreate-ok';
  LRebuiltSeen := False;
  LFactory := TFakeSessionFactory.Create(True);
  LFactoryIntf := LFactory;

  LMgr := TBrowserRecoveryManager.Create(FastRecoveryConfig);
  try
    LMgr.SessionFactory := LFactoryIntf;
    LMgr.OnSessionRebuilt :=
      procedure(const AOldSessionId: TBrowserSessionId;
        const ANewSession: IBrowserSession)
      begin
        LRebuiltSeen := (AOldSessionId = LSessionId) and
                         (ANewSession <> nil);
      end;

    LMgr.TriggerRecovery(LSessionId, brsRecreate);

    Assert.AreEqual(1, LFactory.CallCount,
      'factory should have been invoked exactly once');
    Assert.IsTrue(LRebuiltSeen,
      'OnSessionRebuilt should fire with non-nil new session');
    // Final-success path resets retry counter to 0
    Assert.AreEqual(0, LMgr.GetRetryCount(LSessionId),
      'retry counter resets on success');
    Assert.AreEqual(Ord(bhsHealthy), Ord(LMgr.GetHealthStatus(LSessionId)),
      'status returns to healthy on success');
  finally
    LMgr.Free;
  end;
end;

procedure TRecoveryIntegrationTests.Test_DoRecovery_FactoryAttempted_Failure;
var
  LMgr: TBrowserRecoveryManager;
  LFactory: TFakeSessionFactory;
  LFactoryIntf: IBrowserSessionFactory;
  LSessionId: TBrowserSessionId;
begin
  LSessionId := 'sess-recreate-fail';
  LFactory := TFakeSessionFactory.Create(False); // returns nil
  LFactoryIntf := LFactory;

  LMgr := TBrowserRecoveryManager.Create(FastRecoveryConfig);
  try
    LMgr.SessionFactory := LFactoryIntf;
    LMgr.TriggerRecovery(LSessionId, brsRecreate);

    Assert.AreEqual(1, LFactory.CallCount,
      'factory was attempted');
    Assert.AreNotEqual(0, LMgr.GetRetryCount(LSessionId),
      'retry counter should have been incremented and not reset');
    Assert.AreNotEqual(Ord(bhsHealthy),
      Ord(LMgr.GetHealthStatus(LSessionId)),
      'status must NOT be healthy after factory failure');
  finally
    LMgr.Free;
  end;
end;

procedure TRecoveryIntegrationTests.Test_DoRecovery_OnRecoveryCallback_Success;
var
  LMgr: TBrowserRecoveryManager;
  LHolder: TRecoveryCallbackHolder;
  LSessionId: TBrowserSessionId;
begin
  LSessionId := 'sess-cb-ok';
  LHolder := TRecoveryCallbackHolder.Create;
  try
    LMgr := TBrowserRecoveryManager.Create(FastRecoveryConfig);
    try
      LMgr.OnRecovery := LHolder.HandleRecovery;
      LMgr.TriggerRecovery(LSessionId, brsReload);

      Assert.IsTrue(LHolder.Called, 'callback should have run');
      Assert.AreEqual(0, LMgr.GetRetryCount(LSessionId),
        'retry counter resets on success');
      Assert.AreEqual(Ord(bhsHealthy),
        Ord(LMgr.GetHealthStatus(LSessionId)),
        'status returns to healthy on success');
    finally
      LMgr.Free;
    end;
  finally
    LHolder.Free;
  end;
end;

procedure TRecoveryIntegrationTests.Test_DoRecovery_OnRecoveryCallback_Failure;
var
  LMgr: TBrowserRecoveryManager;
  LHolder: TRecoveryCallbackHolder;
  LSessionId: TBrowserSessionId;
begin
  LSessionId := 'sess-cb-fail';
  LHolder := TRecoveryCallbackHolder.Create;
  LHolder.RaiseOnCall := True;
  try
    LMgr := TBrowserRecoveryManager.Create(FastRecoveryConfig);
    try
      LMgr.OnRecovery := LHolder.HandleRecovery;
      LMgr.TriggerRecovery(LSessionId, brsReload);

      Assert.IsTrue(LHolder.Called, 'callback was attempted');
      Assert.AreNotEqual(Ord(bhsHealthy),
        Ord(LMgr.GetHealthStatus(LSessionId)),
        'callback that raised must NOT be treated as success (H1 fix)');
    finally
      LMgr.Free;
    end;
  finally
    LHolder.Free;
  end;
end;

procedure TRecoveryIntegrationTests.Test_DoRecovery_NoFactoryNoCallback_BestEffort;
var
  LMgr: TBrowserRecoveryManager;
  LSessionId: TBrowserSessionId;
begin
  // H7 fix: brsReload / brsRestart with no factory and no callback
  // should be treated as best-effort success (logs a warning).
  LSessionId := 'sess-best-effort';
  LMgr := TBrowserRecoveryManager.Create(FastRecoveryConfig);
  try
    LMgr.TriggerRecovery(LSessionId, brsReload);
    Assert.AreEqual(0, LMgr.GetRetryCount(LSessionId),
      'best-effort recovery resets the retry counter');
    Assert.AreEqual(Ord(bhsHealthy),
      Ord(LMgr.GetHealthStatus(LSessionId)),
      'best-effort recovery returns status to healthy');
  finally
    LMgr.Free;
  end;
end;

procedure TRecoveryIntegrationTests.Test_TriggerRecovery_IncrementsRetryCount;
var
  LMgr: TBrowserRecoveryManager;
  LFactory: TFakeSessionFactory;
  LFactoryIntf: IBrowserSessionFactory;
  LSessionId: TBrowserSessionId;
begin
  LSessionId := 'sess-multi';
  LFactory := TFakeSessionFactory.Create(False); // always fail
  LFactoryIntf := LFactory;

  LMgr := TBrowserRecoveryManager.Create(FastRecoveryConfig);
  try
    LMgr.SessionFactory := LFactoryIntf;
    LMgr.TriggerRecovery(LSessionId, brsRecreate);
    Assert.AreEqual(1, LMgr.GetRetryCount(LSessionId),
      'first failure leaves retry=1');
    LMgr.TriggerRecovery(LSessionId, brsRecreate);
    Assert.AreEqual(2, LMgr.GetRetryCount(LSessionId),
      'second failure leaves retry=2');
  finally
    LMgr.Free;
  end;
end;

procedure TRecoveryIntegrationTests.Test_StartStopHealthMonitor_NoLeak;
var
  LMgr: TBrowserRecoveryManager;
  LConfig: TBrowserRecoveryConfig;
begin
  LConfig := FastRecoveryConfig;
  LConfig.HealthCheckIntervalMs := 50; // fast loop for the test
  LMgr := TBrowserRecoveryManager.Create(LConfig);
  try
    LMgr.StartHealthMonitor;
    Sleep(60); // give the loop one tick
    LMgr.StopHealthMonitor;
    // If StopHealthMonitor returns cleanly, the thread joined without leak.
    Assert.Pass('start/stop cycle completed without hang');
  finally
    LMgr.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TRecoveryIntegrationTests);

end.
