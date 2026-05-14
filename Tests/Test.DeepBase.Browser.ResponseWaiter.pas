unit Test.DeepBase.Browser.ResponseWaiter;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Browser.Types,
  DeepBase.Browser.ResponseWaiter;

type
  [TestFixture]
  TBrowserResponseWaiterTests = class
  public
    [Test]
    procedure Test_GetWaiterJS_ContainsMutationObserver;

    [Test]
    procedure Test_GetWaiterJS_ContainsWebView2PostMessage;

    [Test]
    procedure Test_GetWaiterJS_ContainsSelectors;

    [Test]
    procedure Test_GetWaiterJS_ContainsTimeoutAndStable;

    [Test]
    procedure Test_HandleWaitResult_Success;

    [Test]
    procedure Test_HandleWaitResult_Timeout;

    [Test]
    procedure Test_HandleWaitResult_Error;

    [Test]
    procedure Test_HandleWaitResult_Cancelled;

    [Test]
    procedure Test_DefaultTimeoutAndStable;
  end;

implementation

uses
  DeepBase.BrowserAutomation;

type
  TFakeBrowserSession = class(TInterfacedObject, IBrowserSession)
  public
    function GetSessionId: TBrowserSessionId;
    function GetState: TBrowserSessionState;
    function GetCurrentUrl: string;
    function GetLastError: string;
    function Navigate(const AUrl: string; ATimeoutMs: Integer;
      out AError: string): Boolean;
    function ExecuteScript(const AScript: string;
      out AError: string): Boolean;
    function EvaluateScript(const AScript: string;
      ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
    function CallDevToolsProtocol(const AMethod, AParams: string;
      ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
    function CaptureScreenshot(out AImage: TBytes;
      out AError: string): Boolean;
    function AsAutomationSession: IBrowserAutomationSession;
  end;

{ TFakeBrowserSession }

function TFakeBrowserSession.GetSessionId: TBrowserSessionId;
begin
  Result := 'fake-session';
end;

function TFakeBrowserSession.GetState: TBrowserSessionState;
begin
  Result := bssReady;
end;

function TFakeBrowserSession.GetCurrentUrl: string;
begin
  Result := 'about:blank';
end;

function TFakeBrowserSession.GetLastError: string;
begin
  Result := '';
end;

function TFakeBrowserSession.Navigate(const AUrl: string;
  ATimeoutMs: Integer; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.ExecuteScript(
  const AScript: string; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.EvaluateScript(
  const AScript: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := 'true';
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := '{"ok":true}';
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.CaptureScreenshot(
  out AImage: TBytes; out AError: string): Boolean;
begin
  AImage := [];
  AError := '';
  Result := True;
end;

function TFakeBrowserSession.AsAutomationSession: IBrowserAutomationSession;
begin
  Result := nil;
end;

{ TBrowserResponseWaiterTests }

procedure TBrowserResponseWaiterTests.Test_GetWaiterJS_ContainsMutationObserver;
var
  LJS: string;
begin
  LJS := TBrowserResponseWaiter.BuildWaiterJS(
    '.response', '.loading', 30000, 3000);
  Assert.IsTrue(Pos('MutationObserver', LJS) > 0,
    'JS should contain MutationObserver');
end;

procedure TBrowserResponseWaiterTests.Test_GetWaiterJS_ContainsWebView2PostMessage;
var
  LJS: string;
begin
  LJS := TBrowserResponseWaiter.BuildWaiterJS(
    '.response', '.loading', 30000, 3000);
  Assert.IsTrue(
    Pos('window.chrome.webview.postMessage', LJS) > 0,
    'JS should use WebView2 postMessage');
end;

procedure TBrowserResponseWaiterTests.Test_GetWaiterJS_ContainsSelectors;
var
  LJS: string;
begin
  LJS := TBrowserResponseWaiter.BuildWaiterJS(
    '.assistant-msg', '.loading-spinner', 30000, 3000);
  Assert.IsTrue(Pos('.assistant-msg', LJS) > 0,
    'JS should contain response selector');
  Assert.IsTrue(Pos('.loading-spinner', LJS) > 0,
    'JS should contain loading selector');
end;

procedure TBrowserResponseWaiterTests.Test_GetWaiterJS_ContainsTimeoutAndStable;
var
  LJS: string;
begin
  LJS := TBrowserResponseWaiter.BuildWaiterJS(
    '.response', '.loading', 60000, 5000);
  Assert.IsTrue(Pos('60000', LJS) > 0,
    'JS should contain timeout value');
  Assert.IsTrue(Pos('5000', LJS) > 0,
    'JS should contain stable value');
end;

procedure TBrowserResponseWaiterTests.Test_HandleWaitResult_Success;
var
  LSession: TFakeBrowserSession;
  LWaiter: TBrowserResponseWaiter;
  LResult: TBrowserWaitResult;
  LResponse: string;
  LDuration: Int64;
begin
  LSession := TFakeBrowserSession.Create;
  LWaiter := TBrowserResponseWaiter.Create(LSession);
  try
    LWaiter.OnResult :=
      procedure(AResult: TBrowserWaitResult;
        const AResponse: string; ADurationMs: Int64)
      begin
        LResult := AResult;
        LResponse := AResponse;
        LDuration := ADurationMs;
      end;

    LWaiter.HandleWaitResult('success', 'Hello world', 1500);
    Assert.AreEqual(bwrSuccess, LResult);
    Assert.AreEqual('Hello world', LResponse);
    Assert.AreEqual(Int64(1500), LDuration);
  finally
    LWaiter.Free;
  end;
end;

procedure TBrowserResponseWaiterTests.Test_HandleWaitResult_Timeout;
var
  LSession: TFakeBrowserSession;
  LWaiter: TBrowserResponseWaiter;
  LResult: TBrowserWaitResult;
begin
  LSession := TFakeBrowserSession.Create;
  LWaiter := TBrowserResponseWaiter.Create(LSession);
  try
    LWaiter.OnResult :=
      procedure(AResult: TBrowserWaitResult;
        const AResponse: string; ADurationMs: Int64)
      begin
        LResult := AResult;
      end;

    LWaiter.HandleWaitResult('timeout', '', 120000);
    Assert.AreEqual(bwrTimeout, LResult);
  finally
    LWaiter.Free;
  end;
end;

procedure TBrowserResponseWaiterTests.Test_HandleWaitResult_Error;
var
  LSession: TFakeBrowserSession;
  LWaiter: TBrowserResponseWaiter;
  LResult: TBrowserWaitResult;
begin
  LSession := TFakeBrowserSession.Create;
  LWaiter := TBrowserResponseWaiter.Create(LSession);
  try
    LWaiter.OnResult :=
      procedure(AResult: TBrowserWaitResult;
        const AResponse: string; ADurationMs: Int64)
      begin
        LResult := AResult;
      end;

    LWaiter.HandleWaitResult('something_wrong', '', 0);
    Assert.AreEqual(bwrError, LResult);
  finally
    LWaiter.Free;
  end;
end;

procedure TBrowserResponseWaiterTests.Test_HandleWaitResult_Cancelled;
var
  LSession: TFakeBrowserSession;
  LWaiter: TBrowserResponseWaiter;
  LResult: TBrowserWaitResult;
begin
  LSession := TFakeBrowserSession.Create;
  LWaiter := TBrowserResponseWaiter.Create(LSession);
  try
    LWaiter.OnResult :=
      procedure(AResult: TBrowserWaitResult;
        const AResponse: string; ADurationMs: Int64)
      begin
        LResult := AResult;
      end;

    LWaiter.HandleWaitResult('cancelled', '', 0);
    Assert.AreEqual(bwrCancelled, LResult);
  finally
    LWaiter.Free;
  end;
end;

procedure TBrowserResponseWaiterTests.Test_DefaultTimeoutAndStable;
var
  LSession: TFakeBrowserSession;
  LWaiter: TBrowserResponseWaiter;
begin
  LSession := TFakeBrowserSession.Create;
  LWaiter := TBrowserResponseWaiter.Create(LSession);
  try
    Assert.AreEqual(120000, LWaiter.TimeoutMs);
    Assert.AreEqual(3000, LWaiter.StableMs);
  finally
    LWaiter.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBrowserResponseWaiterTests);

end.
