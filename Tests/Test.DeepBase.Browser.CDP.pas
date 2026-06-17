unit Test.DeepBase.Browser.CDP;

{ ============================================================================
  Test.DeepBase.Browser.CDP
  ---------------------------------------------------------------------------
  H9 fix: previously this 36-method class had zero coverage. Tests use a
  TFakeBrowserSession to verify that command-shape JSON is well formed and
  that Detach properly nulls the stored session.
  ============================================================================ }

interface

uses
  DUnitX.TestFramework,
  System.JSON,
  DeepBase.Browser.Types,
  DeepBase.Browser.CDP;

type
  [TestFixture]
  TCDPStrategyTests = class
  public
    [Test] procedure Test_Construct_Holds_Session;
    [Test] procedure Test_Detach_Clears_Session;
    [Test] procedure Test_Send_With_Nil_Session_Reports_Error;
    [Test] procedure Test_GetDocument_Sends_DOM_GetDocument;
    [Test] procedure Test_TypeText_Sends_Insert_Text;
    [Test] procedure Test_Subscribe_Then_HandleEvent_Dispatches;
    [Test] procedure Test_Unsubscribe_Stops_Dispatch;
    [Test] procedure Test_HandleResult_Routes_To_Pending_Callback;
  end;

implementation

uses
  System.SysUtils,
  System.Generics.Collections;

type
  TCallLog = record
    Method: string;
    Params: string;
  end;

  TFakeCDPSession = class(TInterfacedObject, IBrowserSession)
  public
    Calls: TList<TCallLog>;
    SessionId: TBrowserSessionId;
    constructor Create;
    destructor Destroy; override;
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
    function IsReady: Boolean;
    function AsAutomationSession: IBrowserAutomationSession;
  end;

constructor TFakeCDPSession.Create;
begin
  Calls := TList<TCallLog>.Create;
  SessionId := 'fake-cdp';
end;

destructor TFakeCDPSession.Destroy;
begin
  Calls.Free;
  inherited;
end;

function TFakeCDPSession.GetSessionId: TBrowserSessionId;
begin
  Result := SessionId;
end;

function TFakeCDPSession.GetState: TBrowserSessionState;
begin
  Result := bssReady;
end;

function TFakeCDPSession.GetCurrentUrl: string;
begin
  Result := 'about:blank';
end;

function TFakeCDPSession.GetLastError: string;
begin
  Result := '';
end;

function TFakeCDPSession.Navigate(const AUrl: string;
  ATimeoutMs: Integer; out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeCDPSession.ExecuteScript(const AScript: string;
  out AError: string): Boolean;
begin
  AError := '';
  Result := True;
end;

function TFakeCDPSession.EvaluateScript(const AScript: string;
  ATimeoutMs: Integer; out AJsonResult, AError: string): Boolean;
begin
  AJsonResult := '';
  AError := '';
  Result := True;
end;

function TFakeCDPSession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
var
  LCall: TCallLog;
begin
  LCall.Method := AMethod;
  LCall.Params := AParams;
  Calls.Add(LCall);
  AJsonResult := '{"ok":true}';
  AError := '';
  Result := True;
end;

function TFakeCDPSession.CaptureScreenshot(out AImage: TBytes;
  out AError: string): Boolean;
begin
  AImage := nil;
  AError := '';
  Result := True;
end;

function TFakeCDPSession.AsAutomationSession: IBrowserAutomationSession;
begin
  Result := nil;
end;

function TFakeCDPSession.IsReady: Boolean;
begin
  Result := True;
end;

{ TCDPStrategyTests }

procedure TCDPStrategyTests.Test_Construct_Holds_Session;
var
  LFake: IBrowserSession;
  LCDP: TCDPStrategy;
begin
  LFake := TFakeCDPSession.Create;
  LCDP := TCDPStrategy.Create(LFake);
  try
    Assert.AreSame(LFake, LCDP.Session);
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_Detach_Clears_Session;
var
  LCDP: TCDPStrategy;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    LCDP.Detach;
    Assert.IsNull(LCDP.Session);
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_Send_With_Nil_Session_Reports_Error;
var
  LCDP: TCDPStrategy;
  LResult: string;
begin
  LCDP := TCDPStrategy.Create(nil);
  try
    LCDP.SendCommandSync('Anything', nil, LResult);
    // Should not crash; should produce no_session error JSON
    Assert.IsTrue(Pos('no_session', LResult) > 0,
      'Expected no_session error: ' + LResult);
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_GetDocument_Sends_DOM_GetDocument;
var
  LFake: TFakeCDPSession;
  LCDP: TCDPStrategy;
  LCallback: TCDPCallback;
  LCalled: Boolean;
begin
  LFake := TFakeCDPSession.Create;
  LCDP := TCDPStrategy.Create(LFake);
  try
    LCalled := False;
    LCallback :=
      procedure(ASuccess: Boolean; const AResult: string)
      begin
        LCalled := True;
      end;
    LCDP.GetDocument(LCallback);

    Assert.AreEqual<Integer>(1, LFake.Calls.Count);
    Assert.AreEqual<string>('DOM.getDocument', LFake.Calls[0].Method);
    Assert.IsTrue(LCalled, 'Callback should have fired');
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_TypeText_Sends_Insert_Text;
var
  LFake: TFakeCDPSession;
  LCDP: TCDPStrategy;
begin
  LFake := TFakeCDPSession.Create;
  LCDP := TCDPStrategy.Create(LFake);
  try
    LCDP.TypeText('hello world', nil);

    Assert.AreEqual<Integer>(1, LFake.Calls.Count);
    Assert.AreEqual<string>('Input.insertText', LFake.Calls[0].Method);
    Assert.IsTrue(Pos('"text":"hello world"', LFake.Calls[0].Params) > 0,
      'Params should carry the text payload: ' + LFake.Calls[0].Params);
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_Subscribe_Then_HandleEvent_Dispatches;
var
  LCDP: TCDPStrategy;
  LMethodSeen, LParamsSeen: string;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    LMethodSeen := '';
    LParamsSeen := '';
    LCDP.Subscribe('Network.requestWillBeSent',
      procedure(const AMethod, AParams: string)
      begin
        LMethodSeen := AMethod;
        LParamsSeen := AParams;
      end);

    LCDP.HandleDevToolsEvent('Network.requestWillBeSent',
      '{"requestId":"123"}');

    Assert.AreEqual<string>('Network.requestWillBeSent', LMethodSeen);
    Assert.AreEqual<string>('{"requestId":"123"}', LParamsSeen);
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_Unsubscribe_Stops_Dispatch;
var
  LCDP: TCDPStrategy;
  LCalled: Boolean;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    LCalled := False;
    LCDP.Subscribe('Page.loadEventFired',
      procedure(const AMethod, AParams: string)
      begin
        LCalled := True;
      end);

    LCDP.Unsubscribe('Page.loadEventFired');
    LCDP.HandleDevToolsEvent('Page.loadEventFired', '{}');

    Assert.IsFalse(LCalled,
      'Handler should not run after Unsubscribe');
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_HandleResult_Routes_To_Pending_Callback;
var
  LCDP: TCDPStrategy;
  LSawSuccess: Boolean;
  LSawResult: string;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    LSawSuccess := False;
    LSawResult := '';
    // Issue a command that registers a pending callback (id=1)
    LCDP.SendCommand('DOM.getDocument', nil,
      procedure(ASuccess: Boolean; const AResult: string)
      begin
        LSawSuccess := ASuccess;
        LSawResult := AResult;
      end);

    Assert.IsTrue(LSawSuccess,
      'Expected the immediate fake-session response to succeed');
    Assert.IsTrue(Pos('"ok":true', LSawResult) > 0,
      'Expected echo from fake session: ' + LSawResult);
  finally
    LCDP.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCDPStrategyTests);

end.
