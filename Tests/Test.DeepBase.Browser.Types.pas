unit Test.DeepBase.Browser.Types;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.Types;

type
  [TestFixture]
  TBrowserTypesTests = class
  public
    [Test]
    procedure Test_RecoveryConfig_Default;

    [Test]
    procedure Test_WaitConfig_Default;

    [Test]
    procedure Test_Snapshot_Create;

    [Test]
    procedure Test_BrowserEvent_Create;

    [Test]
    procedure Test_SessionStateToString;

    [Test]
    procedure Test_HealthStatusToString;

    [Test]
    procedure Test_RecoveryStrategyToString;

    [Test]
    procedure Test_WaitResultToString;

    [Test]
    procedure Test_EventTypeToString;
  end;

implementation

{ TBrowserTypesTests }

procedure TBrowserTypesTests.Test_RecoveryConfig_Default;
var
  LConfig: TBrowserRecoveryConfig;
begin
  LConfig := TBrowserRecoveryConfig.Default;
  Assert.AreEqual(3, LConfig.MaxRetries);
  Assert.AreEqual(2000, LConfig.RetryDelayMs);
  Assert.AreEqual(5000, LConfig.HealthCheckIntervalMs);
  Assert.AreEqual(30000, LConfig.UnresponsiveThresholdMs);
  Assert.IsTrue(LConfig.AutoRecoveryEnabled);
end;

procedure TBrowserTypesTests.Test_WaitConfig_Default;
var
  LConfig: TBrowserWaitConfig;
begin
  LConfig := TBrowserWaitConfig.Default;
  Assert.AreEqual(120000, LConfig.TimeoutMs);
  Assert.AreEqual(3000, LConfig.StableMs);
  Assert.AreEqual('', LConfig.ResponseSelector);
  Assert.AreEqual('', LConfig.LoadingSelector);
end;

procedure TBrowserTypesTests.Test_Snapshot_Create;
var
  LSnapshot: TBrowserSnapshot;
begin
  LSnapshot := TBrowserSnapshot.Create('session-1',
    'https://example.com', 42, '{"key":"val"}');
  Assert.AreEqual('session-1', LSnapshot.SessionId);
  Assert.AreEqual('https://example.com', LSnapshot.Url);
  Assert.AreEqual(42, LSnapshot.ScrollPosition);
  Assert.AreEqual('{"key":"val"}', LSnapshot.ExtraData);
  Assert.IsTrue(LSnapshot.Timestamp > 0);
end;

procedure TBrowserTypesTests.Test_BrowserEvent_Create;
var
  LEvent: TBrowserEvent;
begin
  LEvent := TBrowserEvent.Create(betNavigationCompleted,
    'session-1', '{"url":"https://example.com"}');
  Assert.AreEqual(betNavigationCompleted, LEvent.EventType);
  Assert.AreEqual('session-1', LEvent.SessionId);
  Assert.AreEqual('{"url":"https://example.com"}', LEvent.Data);
  Assert.IsTrue(LEvent.Timestamp > 0);
end;

procedure TBrowserTypesTests.Test_SessionStateToString;
begin
  Assert.AreEqual('uninitialized',
    BrowserSessionStateToString(bssUninitialized));
  Assert.AreEqual('ready',
    BrowserSessionStateToString(bssReady));
  Assert.AreEqual('crashed',
    BrowserSessionStateToString(bssCrashed));
  Assert.AreEqual('unknown',
    BrowserSessionStateToString(
      TBrowserSessionState(99)));
end;

procedure TBrowserTypesTests.Test_HealthStatusToString;
begin
  Assert.AreEqual('healthy',
    BrowserHealthStatusToString(bhsHealthy));
  Assert.AreEqual('unresponsive',
    BrowserHealthStatusToString(bhsUnresponsive));
end;

procedure TBrowserTypesTests.Test_RecoveryStrategyToString;
begin
  Assert.AreEqual('none',
    BrowserRecoveryStrategyToString(brsNone));
  Assert.AreEqual('reload',
    BrowserRecoveryStrategyToString(brsReload));
  Assert.AreEqual('restart',
    BrowserRecoveryStrategyToString(brsRestart));
  Assert.AreEqual('recreate',
    BrowserRecoveryStrategyToString(brsRecreate));
end;

procedure TBrowserTypesTests.Test_WaitResultToString;
begin
  Assert.AreEqual('success',
    BrowserWaitResultToString(bwrSuccess));
  Assert.AreEqual('timeout',
    BrowserWaitResultToString(bwrTimeout));
  Assert.AreEqual('error',
    BrowserWaitResultToString(bwrError));
  Assert.AreEqual('cancelled',
    BrowserWaitResultToString(bwrCancelled));
end;

procedure TBrowserTypesTests.Test_EventTypeToString;
begin
  Assert.AreEqual('navigation_completed',
    BrowserEventTypeToString(betNavigationCompleted));
  Assert.AreEqual('crashed',
    BrowserEventTypeToString(betCrashed));
  Assert.AreEqual('response_received',
    BrowserEventTypeToString(betResponseReceived));
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserTypesTests);

end.
