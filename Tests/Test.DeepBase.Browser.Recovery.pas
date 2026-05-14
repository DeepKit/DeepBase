unit Test.DeepBase.Browser.Recovery;

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Recovery;

type
  [TestFixture]
  TBrowserRecoveryTests = class
  public
    [Test]
    procedure Test_DefaultConfig_Values;

    [Test]
    procedure Test_SaveAndGetSnapshot;

    [Test]
    procedure Test_GetSnapshot_NotFound_ReturnsDefault;

    [Test]
    procedure Test_RecordHeartbeat;

    [Test]
    procedure Test_IsUnresponsive_NoHeartbeat_ReturnsFalse;

    [Test]
    procedure Test_GetHealthStatus_Unknown_IsHealthy;

    [Test]
    procedure Test_UpdateHealthStatus_SetsStatus;

    [Test]
    procedure Test_RetryCount_InitialZero;

    [Test]
    procedure Test_ResetRetryCount;

    [Test]
    procedure Test_ClearSnapshot;

    [Test]
    procedure Test_DetermineRecoveryStrategy_Crashed;
  end;

implementation

{ TBrowserRecoveryTests }

procedure TBrowserRecoveryTests.Test_DefaultConfig_Values;
var
  LConfig: TBrowserRecoveryConfig;
begin
  LConfig := TBrowserRecoveryConfig.Default;
  Assert.AreEqual(3, LConfig.MaxRetries);
  Assert.AreEqual(2000, LConfig.RetryDelayMs);
  Assert.IsTrue(LConfig.AutoRecoveryEnabled);
end;

procedure TBrowserRecoveryTests.Test_SaveAndGetSnapshot;
var
  LMgr: TBrowserRecoveryManager;
  LSnapshot: TBrowserSnapshot;
  LRetrieved: TBrowserSnapshot;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    LSnapshot := TBrowserSnapshot.Create('sess-1',
      'https://example.com', 100);
    LMgr.SaveSnapshot(LSnapshot);

    LRetrieved := LMgr.GetSnapshot('sess-1');
    Assert.AreEqual('sess-1', LRetrieved.SessionId);
    Assert.AreEqual('https://example.com', LRetrieved.Url);
    Assert.AreEqual(100, LRetrieved.ScrollPosition);
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_GetSnapshot_NotFound_ReturnsDefault;
var
  LMgr: TBrowserRecoveryManager;
  LRetrieved: TBrowserSnapshot;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    LRetrieved := LMgr.GetSnapshot('nonexistent');
    Assert.AreEqual('nonexistent', LRetrieved.SessionId);
    Assert.AreEqual('', LRetrieved.Url);
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_RecordHeartbeat;
var
  LMgr: TBrowserRecoveryManager;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    LMgr.RecordHeartbeat('sess-hb');
    // Should not be unresponsive right after heartbeat
    Assert.IsFalse(LMgr.IsUnresponsive('sess-hb'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_IsUnresponsive_NoHeartbeat_ReturnsFalse;
var
  LMgr: TBrowserRecoveryManager;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    Assert.IsFalse(LMgr.IsUnresponsive('no-session'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_GetHealthStatus_Unknown_IsHealthy;
var
  LMgr: TBrowserRecoveryManager;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    Assert.AreEqual(bhsHealthy,
      LMgr.GetHealthStatus('unknown'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_UpdateHealthStatus_SetsStatus;
var
  LMgr: TBrowserRecoveryManager;
  LConfig: TBrowserRecoveryConfig;
begin
  LConfig := TBrowserRecoveryConfig.Default;
  LConfig.AutoRecoveryEnabled := False;
  LMgr := TBrowserRecoveryManager.Create(LConfig);
  try
    LMgr.UpdateHealthStatus('sess-status', bhsNetworkError);
    Assert.AreEqual(bhsNetworkError,
      LMgr.GetHealthStatus('sess-status'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_RetryCount_InitialZero;
var
  LMgr: TBrowserRecoveryManager;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    Assert.AreEqual(0, LMgr.GetRetryCount('new-session'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_ResetRetryCount;
var
  LMgr: TBrowserRecoveryManager;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    LMgr.ResetRetryCount('sess-retry');
    Assert.AreEqual(0, LMgr.GetRetryCount('sess-retry'));
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_ClearSnapshot;
var
  LMgr: TBrowserRecoveryManager;
  LSnapshot: TBrowserSnapshot;
  LRetrieved: TBrowserSnapshot;
begin
  LMgr := TBrowserRecoveryManager.Create(
    TBrowserRecoveryConfig.Default);
  try
    LSnapshot := TBrowserSnapshot.Create('sess-clear',
      'https://example.com');
    LMgr.SaveSnapshot(LSnapshot);
    LMgr.ClearSnapshot('sess-clear');

    LRetrieved := LMgr.GetSnapshot('sess-clear');
    Assert.AreEqual('', LRetrieved.Url);
  finally
    LMgr.Free;
  end;
end;

procedure TBrowserRecoveryTests.Test_DetermineRecoveryStrategy_Crashed;
var
  LMgr: TBrowserRecoveryManager;
  LConfig: TBrowserRecoveryConfig;
begin
  LConfig := TBrowserRecoveryConfig.Default;
  LConfig.AutoRecoveryEnabled := False;
  LMgr := TBrowserRecoveryManager.Create(LConfig);
  try
    // Direct update to crashed status
    LMgr.UpdateHealthStatus('sess-strat', bhsNetworkError);
    Assert.AreEqual(bhsNetworkError,
      LMgr.GetHealthStatus('sess-strat'));
  finally
    LMgr.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserRecoveryTests);

end.
