unit Test.DeepBase.Browser.Service;

{ ============================================================================
  Test.DeepBase.Browser.Service
  ---------------------------------------------------------------------------
  Headless tests for the Browser facade. Uses a TFakeBrowserSession to
  exercise the singleton accessors and recovery wiring without a real
  browser engine.
  H10 fix: previously this entry-point had zero coverage.
  ============================================================================ }

interface

uses
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.Service;

type
  [TestFixture]
  TBrowserServiceTests = class
  public
    [Setup] procedure SetUp;
    [TearDown] procedure TearDown;

    [Test] procedure Test_Default_Session_Is_Nil_After_Shutdown;
    [Test] procedure Test_SetDefaultSession_Stored_And_Returned;
    [Test] procedure Test_Reset_Clears_Default_Session;
    [Test] procedure Test_IsReady_False_Without_Session;
    [Test] procedure Test_IsReady_True_With_Session;
    [Test] procedure Test_SetRecovery_Stored_And_Returned;
    [Test] procedure Test_Recovery_Lazy_Falls_Back_To_Singleton;
  end;

implementation

uses
  System.SysUtils,
  DeepBase.Browser.Recovery;

type
  TFakeServiceSession = class(TInterfacedObject, IBrowserSession)
  private
    FSessionId: TBrowserSessionId;
  public
    constructor Create(const AId: TBrowserSessionId);
    function GetSessionId: TBrowserSessionId;
    function GetState: TBrowserSessionState;
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

constructor TFakeServiceSession.Create(const AId: TBrowserSessionId);
begin
  FSessionId := AId;
end;

function TFakeServiceSession.GetSessionId: TBrowserSessionId;
begin
  Result := FSessionId;
end;

function TFakeServiceSession.GetState: TBrowserSessionState;
begin
  Result := bssReady;
end;

function TFakeServiceSession.GetCurrentUrl: string;
begin
  Result := 'about:blank';
end;

function TFakeServiceSession.GetLastError: string;
begin
  Result := '';
end;

function TFakeServiceSession.Navigate(const AUrl: string;
  ATimeoutMs: Integer; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeServiceSession.ExecuteScript(const AScript: string;
  out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeServiceSession.EvaluateScript(const AScript: string;
  ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := 'true';
  AError := '';
  Result := True;
end;

function TFakeServiceSession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := '{}';
  AError := '';
  Result := True;
end;

function TFakeServiceSession.CaptureScreenshot(out AImage: TBytes;
  out AError: string): Boolean;
begin
  AImage := nil;
  AError := '';
  Result := True;
end;

function TFakeServiceSession.AsAutomationSession: IBrowserAutomationSession;
begin
  Result := nil;
end;

{ TBrowserServiceTests }

procedure TBrowserServiceTests.SetUp;
begin
  TBrowserService.Shutdown;
end;

procedure TBrowserServiceTests.TearDown;
begin
  TBrowserService.Shutdown;
end;

procedure TBrowserServiceTests.Test_Default_Session_Is_Nil_After_Shutdown;
begin
  Assert.IsNull(TBrowserService.Session);
end;

procedure TBrowserServiceTests.Test_SetDefaultSession_Stored_And_Returned;
var
  LSession: IBrowserSession;
begin
  LSession := TFakeServiceSession.Create('s-1');
  TBrowserService.SetDefaultSession(LSession);
  Assert.AreSame(LSession, TBrowserService.Session);
  Assert.AreEqual<string>('s-1', TBrowserService.Session.GetSessionId);
end;

procedure TBrowserServiceTests.Test_Reset_Clears_Default_Session;
begin
  TBrowserService.SetDefaultSession(TFakeServiceSession.Create('s-2'));
  TBrowserService.Shutdown;
  Assert.IsNull(TBrowserService.Session);
end;

procedure TBrowserServiceTests.Test_IsReady_False_Without_Session;
begin
  Assert.IsFalse(TBrowserService.IsReady);
end;

procedure TBrowserServiceTests.Test_IsReady_True_With_Session;
begin
  TBrowserService.SetDefaultSession(TFakeServiceSession.Create('s-3'));
  Assert.IsTrue(TBrowserService.IsReady);
end;

procedure TBrowserServiceTests.Test_SetRecovery_Stored_And_Returned;
var
  LRec: IBrowserRecovery;
begin
  LRec := TBrowserRecoveryManager.Create(TBrowserRecoveryConfig.Default);
  TBrowserService.SetRecovery(LRec);
  Assert.AreSame(LRec, TBrowserService.Recovery);
end;

procedure TBrowserServiceTests.Test_Recovery_Lazy_Falls_Back_To_Singleton;
var
  LRec: IBrowserRecovery;
begin
  // After Shutdown, FRecovery is nil; first read should lazily resolve to
  // the BrowserRecovery singleton.
  TBrowserService.Shutdown;
  LRec := TBrowserService.Recovery;
  Assert.IsNotNull(LRec);
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserServiceTests);

end.
