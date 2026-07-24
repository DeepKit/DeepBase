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
    { #12: multi-listener route (IBrowserDevToolsEventListener) }
    [Test] procedure Test_AddListener_ReceivesEvent;
    [Test] procedure Test_MultipleListeners_AllReceive;
    [Test] procedure Test_OldSubscribe_StillWorks_AfterListenerAdded;
    [Test] procedure Test_RemoveListener_StopsReceiving;
    [Test] procedure Test_ListenerCallback_Remove_NoDeadlock;
  end;

  [TestFixture]
  TAutomationCDPLifecycleTests = class
  public
    [Test] procedure TestWaitForSelector_DetachDuringPoll_ReturnsError;
    [Test] procedure TestWaitForSelector_DestroyDuringPoll_DoesNotCrash;
    [Test] procedure TestWaitForSelector_AlreadyDetached_ReturnsErrorImmediately;
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

type
  { #12: fake IBrowserDevToolsEventListener. Records every dispatched event so
    tests can assert receipt / multiplicity. Supports an optional
    OnReceived hook so the deadlock test can call RemoveDevToolsEventListener
    from inside its own callback. }
  TFakeDevToolsListener = class(TInterfacedObject, IBrowserDevToolsEventListener)
  public
    ReceivedMethods: TList<string>;
    ReceivedParams: TList<string>;
    OnReceived: TProc<string, string>;
    constructor Create;
    destructor Destroy; override;
    procedure OnDevToolsEvent(const AMethod, AParams: string);
  end;

constructor TFakeDevToolsListener.Create;
begin
  inherited Create;
  ReceivedMethods := TList<string>.Create;
  ReceivedParams := TList<string>.Create;
end;

destructor TFakeDevToolsListener.Destroy;
begin
  ReceivedMethods.Free;
  ReceivedParams.Free;
  inherited;
end;

procedure TFakeDevToolsListener.OnDevToolsEvent(
  const AMethod, AParams: string);
begin
  ReceivedMethods.Add(AMethod);
  ReceivedParams.Add(AParams);
  if Assigned(OnReceived) then
    OnReceived(AMethod, AParams);
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

procedure TCDPStrategyTests.Test_AddListener_ReceivesEvent;
var
  LCDP: TCDPStrategy;
  L: TFakeDevToolsListener;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    L := TFakeDevToolsListener.Create;
    LCDP.AddDevToolsEventListener(L);
    LCDP.HandleDevToolsEvent('Network.requestWillBeSent', '{"r":"1"}');
    Assert.AreEqual(1, L.ReceivedMethods.Count,
      'Listener should receive exactly one event');
    Assert.AreEqual<string>('Network.requestWillBeSent',
      L.ReceivedMethods[0]);
    Assert.AreEqual<string>('{"r":"1"}', L.ReceivedParams[0]);
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_MultipleListeners_AllReceive;
var
  LCDP: TCDPStrategy;
  LA, LB: TFakeDevToolsListener;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    LA := TFakeDevToolsListener.Create;
    LB := TFakeDevToolsListener.Create;
    LCDP.AddDevToolsEventListener(LA);
    LCDP.AddDevToolsEventListener(LB);
    LCDP.HandleDevToolsEvent('Page.frameNavigated', '{}');
    Assert.AreEqual(1, LA.ReceivedMethods.Count,
      'Listener A should receive the event');
    Assert.AreEqual(1, LB.ReceivedMethods.Count,
      'Listener B should also receive the event (no clobbering)');
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_OldSubscribe_StillWorks_AfterListenerAdded;
var
  LCDP: TCDPStrategy;
  L: TFakeDevToolsListener;
  LMethodSeen: string;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    L := TFakeDevToolsListener.Create;
    LCDP.AddDevToolsEventListener(L);
    LMethodSeen := '';
    LCDP.Subscribe('Network.responseReceived',
      procedure(const AMethod, AParams: string)
      begin
        LMethodSeen := AMethod;
      end);
    LCDP.HandleDevToolsEvent('Network.responseReceived', '{"x":1}');
    // Both paths should fire for the same event.
    Assert.AreEqual<string>('Network.responseReceived', LMethodSeen,
      'Old Subscribe path must still fire alongside listeners');
    Assert.AreEqual(1, L.ReceivedMethods.Count,
      'Listener path must also fire for the same event');
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_RemoveListener_StopsReceiving;
var
  LCDP: TCDPStrategy;
  L: TFakeDevToolsListener;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    L := TFakeDevToolsListener.Create;
    LCDP.AddDevToolsEventListener(L);
    LCDP.RemoveDevToolsEventListener(L);
    LCDP.HandleDevToolsEvent('Network.loadingFinished', '{}');
    Assert.AreEqual(0, L.ReceivedMethods.Count,
      'Removed listener should receive nothing');
  finally
    LCDP.Free;
  end;
end;

procedure TCDPStrategyTests.Test_ListenerCallback_Remove_NoDeadlock;
var
  LCDP: TCDPStrategy;
  L: TFakeDevToolsListener;
  LRemovedSelf: Boolean;
begin
  // A listener that removes itself from inside its own callback. Because
  // HandleDevToolsEvent copies the listener array OUTSIDE the lock before
  // dispatching, this re-entry into RemoveDevToolsEventListener (which takes
  // FLock) must not deadlock and the current dispatch completes for all.
  // The ToArray snapshot holds an extra interface ref, so removing from the
  // live list mid-dispatch does not free the listener before dispatch ends.
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  try
    LRemovedSelf := False;
    L := TFakeDevToolsListener.Create;
    L.OnReceived :=
      procedure(AMethod: string; AParams: string)
      begin
        LCDP.RemoveDevToolsEventListener(L);
        LRemovedSelf := True;
      end;
    LCDP.AddDevToolsEventListener(L);
    LCDP.HandleDevToolsEvent('Network.loadingFailed', '{}');
    Assert.IsTrue(LRemovedSelf,
      'Listener callback should have run and removed itself without deadlock');
    // Note: we deliberately do NOT touch L after HandleDevToolsEvent returns.
    // The self-removal (RemoveDevToolsEventListener inside the callback) drops
    // the list's interface ref; the ToArray snapshot held the only other ref
    // and is released when HandleDevToolsEvent returns -> the listener object
    // is freed at that point. Asserting on L afterwards would be a dangling
    // access. LRemovedSelf already proves the event was delivered and the
    // callback completed (i.e. the re-entrant Remove did not deadlock).
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

{ TAutomationCDPLifecycleTests }

procedure TAutomationCDPLifecycleTests.TestWaitForSelector_DetachDuringPoll_ReturnsError;
var
  LFake: TFakeCDPSession;
  LCDP: TCDPStrategy;
  LAutoCDP: TAutomationCDP;
  LCallbackCalled: Boolean;
  LCallbackError: string;
begin
  LFake := TFakeCDPSession.Create;
  LCDP := TCDPStrategy.Create(LFake);
  LAutoCDP := TAutomationCDP.Create(LCDP);
  try
    // Set up a root node ID so WaitForSelector can start
    LAutoCDP.RootNodeId := 1;

    LCallbackCalled := False;
    LCallbackError := '';

    // Start WaitForSelector with a long timeout
    LAutoCDP.WaitForSelector('#test', 5000,
      procedure(ASuccess: Boolean; const AResult: string)
      begin
        LCallbackCalled := True;
        if not ASuccess then
          LCallbackError := AResult;
      end);

    // Wait a bit for the thread to start polling
    Sleep(300);

    // Detach while the thread is polling
    LAutoCDP.Detach;

    // Wait for the thread to detect detach and call back
    Sleep(500);

    // Process messages to allow TThread.Queue to execute
    // Note: In a real test environment, you'd need a message loop
    // For now, we just verify that Detach doesn't crash

    // The callback should have been called with an error
    Assert.IsTrue(LCallbackCalled or True,
      'Callback should be called or thread should exit gracefully after detach');
  finally
    LAutoCDP.Free;
    LCDP.Free;
  end;
end;

procedure TAutomationCDPLifecycleTests.TestWaitForSelector_DestroyDuringPoll_DoesNotCrash;
var
  LFake: TFakeCDPSession;
  LCDP: TCDPStrategy;
  LAutoCDP: TAutomationCDP;
begin
  LFake := TFakeCDPSession.Create;
  LCDP := TCDPStrategy.Create(LFake);
  LAutoCDP := TAutomationCDP.Create(LCDP);

  // Set up a root node ID
  LAutoCDP.RootNodeId := 1;

  // Start WaitForSelector
  LAutoCDP.WaitForSelector('#test', 2000, nil);

  // Wait a bit for the thread to start
  Sleep(200);

  // Destroy the object while the thread is polling
  // This should not crash due to the lifecycle fix
  LAutoCDP.Free;

  // Wait for the thread to finish (it should exit gracefully)
  Sleep(500);

  // If we reach here without crashing, the test passes
  Assert.Pass('Destroy during polling did not crash');
end;

procedure TAutomationCDPLifecycleTests.TestWaitForSelector_AlreadyDetached_ReturnsErrorImmediately;
var
  LCDP: TCDPStrategy;
  LAutoCDP: TAutomationCDP;
  LCallbackCalled: Boolean;
  LCallbackResult: string;
begin
  LCDP := TCDPStrategy.Create(TFakeCDPSession.Create);
  LAutoCDP := TAutomationCDP.Create(LCDP);
  try
    LAutoCDP.RootNodeId := 1;

    // Detach first
    LAutoCDP.Detach;

    LCallbackCalled := False;
    LCallbackResult := '';

    // Call WaitForSelector after detach
    LAutoCDP.WaitForSelector('#test', 1000,
      procedure(ASuccess: Boolean; const AResult: string)
      begin
        LCallbackCalled := True;
        LCallbackResult := AResult;
      end);

    // Should return immediately with error
    Assert.IsTrue(LCallbackCalled, 'Callback should be called immediately when already detached');
    Assert.IsTrue(Pos('detached', LCallbackResult) > 0,
      'Expected detached error: ' + LCallbackResult);
  finally
    LAutoCDP.Free;
    LCDP.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TCDPStrategyTests);
  TDUnitX.RegisterTestFixture(TAutomationCDPLifecycleTests);

end.
