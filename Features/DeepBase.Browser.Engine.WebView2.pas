{ ============================================================================
  DeepBase.Browser.Engine.WebView2
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : WebView2 default engine implementation for the Browser
                Automation framework. Wraps WebView4Delphi's TWVBrowser
                and implements IBrowserSession + IBrowserSessionAsync.
                Requires WebView4Delphi package and Microsoft Edge WebView2
                Runtime to be installed.
  ============================================================================ }

unit DeepBase.Browser.Engine.WebView2;

{$IFDEF USE_WEBVIEW2}

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  System.Threading,
  System.JSON,
  Vcl.Controls,
  Vcl.Forms,
  Vcl.ExtCtrls,
  DeepBase.Browser.Types,
  DeepBase.BrowserAutomation,
  uWVBrowser,
  uWVWinControl,
  uWVWindowParent,
  uWVTypes,
  uWVConstants,
  uWVTypeLibrary,
  uWVLoader,
  uWVInterfaces,
  uWVCoreWebView2Args,
  uWVBrowserBase;

type
  TWebView2BrowserSession = class(TInterfacedObject,
    IBrowserSession, IBrowserSessionAsync, IBrowserMessageReceiver)
  private
    FBrowser: TWVBrowser;
    FWindowParent: TWVWindowParent;
    FOwner: TWinControl;
    FReady: Boolean;
    FLastError: string;
    FCurrentUrl: string;
    FSessionId: TBrowserSessionId;

    // BUG-BA-014 fix: per-call CDP routing instead of shared instance fields.
    FCDPCalls: TDictionary<Integer, TObject>;  // Integer -> TPendingCDPCall
    FCDPCallsLock: TCriticalSection;
    FNextCallId: Integer;

    FNavigationEvent: TEvent;  // BUG-BA-021 fix: real wait for navigation completion
    FNavigationOk: Boolean;
    // H3 fix: serialize concurrent Navigate calls (shared FNavigationEvent).
    FNavigateMutex: TCriticalSection;

    FScreenshotStream: TMemoryStream;
    FScreenshotReady: Boolean;
    FScreenshotEvent: TEvent;
    // H4 fix: serialize concurrent Screenshot calls (shared FScreenshotStream).
    FScreenshotMutex: TCriticalSection;

    // C6 fix: callback for window.chrome.webview.postMessage payloads.
    // Wired by ResponseWaiter et al. to receive JS-side notifications.
    FOnWebMessage: TProc<string>;

    procedure BrowserAfterCreated(Sender: TObject;
      AWebView: ICoreWebView2);
    procedure BrowserNavigationCompleted(Sender: TObject;
      const AWebView: ICoreWebView2;
      const AArgs: ICoreWebView2NavigationCompletedEventArgs);
    procedure BrowserInitializationError(Sender: TObject;
      AErrorCode: HResult; const AErrorMessage: wvstring);
    procedure BrowserCapturePreviewCompleted(Sender: TObject;
      ARestult: HResult);
    procedure BrowserCallDevToolsProtocolMethodCompleted(
      Sender: TObject; AResult: HResult;
      const AResultObjectAsJson: wvstring;
      AExecutionId: Integer);
    procedure BrowserWebMessageReceived(Sender: TObject;
      const AWebView: ICoreWebView2;
      const AArgs: ICoreWebView2WebMessageReceivedEventArgs);

    // C7 fix: marshal a COM call to the main (STA) thread.
    procedure OnMainThread(AProc: TThreadProcedure);
    // C7 fix: pump messages while waiting if called from main thread,
    // simple WaitFor otherwise.
    function WaitForEventSafe(AEvent: TEvent;
      ATimeoutMs: Cardinal): TWaitResult;

    function CallCDPSync(const AMethod, AParams: string;
      ATimeoutMs: Integer): string;
    function WaitForReady(ATimeoutMs: Integer): Boolean;
  public
    constructor Create(AOwner: TWinControl);
    destructor Destroy; override;

    { IBrowserSession }
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

    { IBrowserSessionAsync }
    function NavigateAsync(const AUrl: string; ATimeoutMs: Integer;
      ACallback: TProc<Boolean, string>): ITask;
    function ExecuteScriptAsync(const AScript: string;
      ACallback: TProc<Boolean, string>): ITask;
    function EvaluateScriptAsync(const AScript: string;
      ATimeoutMs: Integer;
      ACallback: TProc<Boolean, string, string>): ITask;
    function CaptureScreenshotAsync(
      ACallback: TProc<Boolean, TBytes, string>): ITask;

    { IBrowserMessageReceiver }
    procedure SetMessageHandler(AHandler: TProc<string>);
    procedure ClearMessageHandler;

    property Browser: TWVBrowser read FBrowser;
    property WindowParent: TWVWindowParent read FWindowParent;
    property Ready: Boolean read FReady;
    // C6 fix: assign to receive postMessage(json) from JS.
    property OnWebMessage: TProc<string> read FOnWebMessage write FOnWebMessage;
  end;

  TBrowserAutomationSessionAdapter = class(TInterfacedObject,
    IBrowserAutomationSession)
  private
    FSession: IBrowserSession;
  public
    constructor Create(ASession: IBrowserSession);
    function IsReady: Boolean;
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
  end;

procedure InitializeWebView2(
  const AUserDataFolder: string = '');

// C5 fix: register a function that yields the TWinControl host owner.
// Called by the registry-driven factory at session-creation time.
procedure SetWebView2OwnerProvider(AProvider: TFunc<TWinControl>);

implementation

uses
  System.Generics.Collections,
  DeepBase.Browser.Registry,
  DeepBase.Logging;

type
  // BUG-BA-014 fix: per-call CDP state. Each CallCDPSync allocates one.
  TPendingCDPCall = class
    Event: TEvent;
    ResultJson: string;
    Success: Boolean;
    constructor Create;
    destructor Destroy; override;
  end;

constructor TPendingCDPCall.Create;
begin
  inherited Create;
  Event := TEvent.Create(nil, True, False, '');
  Success := False;
end;

destructor TPendingCDPCall.Destroy;
begin
  Event.Free;
  inherited;
end;

var
  GWebView2Initialized: Boolean = False;
  GWebView2OwnerProvider: TFunc<TWinControl> = nil;

procedure SetWebView2OwnerProvider(AProvider: TFunc<TWinControl>);
begin
  GWebView2OwnerProvider := AProvider;
end;

procedure InitializeWebView2(const AUserDataFolder: string);
var
  LFolder: string;
begin
  if GWebView2Initialized then
    Exit;

  if GlobalWebView2Loader = nil then
  begin
    if AUserDataFolder <> '' then
      LFolder := AUserDataFolder
    else
      LFolder := ExtractFilePath(ParamStr(0)) + 'Data\Browser';

    GlobalWebView2Loader := TWVLoader.Create(nil);
    GlobalWebView2Loader.UserDataFolder := LFolder;
  end;

  GWebView2Initialized := True;
end;

{ TBrowserAutomationSessionAdapter }

constructor TBrowserAutomationSessionAdapter.Create(
  ASession: IBrowserSession);
begin
  inherited Create;
  FSession := ASession;
end;

function TBrowserAutomationSessionAdapter.IsReady: Boolean;
begin
  Result := (FSession <> nil) and
    (FSession.GetState in [bssReady, bssBusy]);
end;

function TBrowserAutomationSessionAdapter.GetCurrentUrl: string;
begin
  if FSession <> nil then
    Result := FSession.GetCurrentUrl
  else
    Result := '';
end;

function TBrowserAutomationSessionAdapter.GetLastError: string;
begin
  if FSession <> nil then
    Result := FSession.GetLastError
  else
    Result := 'No session';
end;

function TBrowserAutomationSessionAdapter.Navigate(
  const AUrl: string; ATimeoutMs: Integer;
  out AError: string): Boolean;
begin
  Result := FSession.Navigate(AUrl, ATimeoutMs, AError);
end;

function TBrowserAutomationSessionAdapter.ExecuteScript(
  const AScript: string; out AError: string): Boolean;
begin
  Result := FSession.ExecuteScript(AScript, AError);
end;

function TBrowserAutomationSessionAdapter.EvaluateScript(
  const AScript: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  Result := FSession.EvaluateScript(AScript, ATimeoutMs,
    AJsonResult, AError);
end;

function TBrowserAutomationSessionAdapter.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  Result := FSession.CallDevToolsProtocol(AMethod, AParams,
    ATimeoutMs, AJsonResult, AError);
end;

function TBrowserAutomationSessionAdapter.CaptureScreenshot(
  out AImage: TBytes; out AError: string): Boolean;
begin
  Result := FSession.CaptureScreenshot(AImage, AError);
end;

{ TWebView2BrowserSession }

constructor TWebView2BrowserSession.Create(AOwner: TWinControl);
begin
  inherited Create;
  FOwner := AOwner;
  FReady := False;
  FSessionId := TGUID.NewGuid.ToString;

  // BUG-BA-014 fix: dictionary of in-flight CDP calls
  FCDPCalls := TDictionary<Integer, TObject>.Create;
  FCDPCallsLock := TCriticalSection.Create;
  FNextCallId := 0;

  // BUG-BA-021 fix: navigation completion event
  FNavigationEvent := TEvent.Create(nil, True, False, '');
  FNavigateMutex := TCriticalSection.Create;       // H3 fix
  FScreenshotMutex := TCriticalSection.Create;     // H4 fix

  FScreenshotEvent := TEvent.Create(nil, True, False, '');
  FScreenshotStream := TMemoryStream.Create;

  FWindowParent := TWVWindowParent.Create(AOwner);
  FWindowParent.Align := alClient;
  if AOwner <> nil then
    FWindowParent.Parent := AOwner;

  FBrowser := TWVBrowser.Create(AOwner);
  FBrowser.WindowParent := FWindowParent;
  FBrowser.OnAfterCreated := BrowserAfterCreated;
  FBrowser.OnNavigationCompleted := BrowserNavigationCompleted;
  FBrowser.OnInitializationError := BrowserInitializationError;
  FBrowser.OnCapturePreviewCompleted :=
    BrowserCapturePreviewCompleted;
  FBrowser.OnCallDevToolsProtocolMethodCompleted :=
    BrowserCallDevToolsProtocolMethodCompleted;
  // C6 fix: subscribe to JS-side window.chrome.webview.postMessage
  FBrowser.OnWebMessageReceived := BrowserWebMessageReceived;

  InitializeWebView2;
  if GlobalWebView2Loader.Initialized then
    FBrowser.CreateBrowser(AOwner.Handle)
  else
    Logger.Warn('WebView2 loader not yet initialized',
      'TWebView2BrowserSession');
end;

destructor TWebView2BrowserSession.Destroy;
var
  LObj: TObject;
begin
  FBrowser.Stop;
  FBrowser.Free;
  FWindowParent.Free;
  FScreenshotStream.Free;
  FScreenshotEvent.Free;
  FNavigationEvent.Free;
  FNavigateMutex.Free;
  FScreenshotMutex.Free;

  // BUG-BA-014 fix: drain any leftover CDP entries
  for LObj in FCDPCalls.Values do
    LObj.Free;
  FCDPCalls.Free;
  FCDPCallsLock.Free;

  inherited;
end;

procedure TWebView2BrowserSession.BrowserAfterCreated(
  Sender: TObject; AWebView: ICoreWebView2);
begin
  FReady := True;
  FBrowser.DefaultWebViewSettings.IsScriptEnabled := True;
  FBrowser.DefaultWebViewSettings.AreDefaultScriptDialogsEnabled :=
    True;
  Logger.InfoFmt('WebView2 session created: %s',
    [FSessionId], 'TWebView2BrowserSession');
end;

procedure TWebView2BrowserSession.BrowserNavigationCompleted(
  Sender: TObject; const AWebView: ICoreWebView2;
  const AArgs: ICoreWebView2NavigationCompletedEventArgs);
var
  LIsSuccess: Integer;
begin
  FCurrentUrl := FBrowser.Source;
  // BUG-BA-021 fix: signal Navigate's WaitFor
  if AArgs.Get_IsSuccess(LIsSuccess) = S_OK then
    FNavigationOk := LIsSuccess <> 0
  else
    FNavigationOk := True;
  FNavigationEvent.SetEvent;
end;

procedure TWebView2BrowserSession.BrowserInitializationError(
  Sender: TObject; AErrorCode: HResult;
  const AErrorMessage: wvstring);
begin
  FLastError := string(AErrorMessage);
  Logger.ErrorFmt('WebView2 init error: %s (%d)',
    [FLastError, AErrorCode], 'TWebView2BrowserSession');
end;

procedure TWebView2BrowserSession.BrowserCapturePreviewCompleted(
  Sender: TObject; ARestult: HResult);
begin
  FScreenshotReady := (ARestult = S_OK);
  FScreenshotEvent.SetEvent;
end;

procedure TWebView2BrowserSession.
  BrowserCallDevToolsProtocolMethodCompleted(
  Sender: TObject; AResult: HResult;
  const AResultObjectAsJson: wvstring;
  AExecutionId: Integer);
var
  LObj: TObject;
  LCall: TPendingCDPCall;
begin
  // BUG-BA-014 fix: route by AExecutionId, no shared state
  FCDPCallsLock.Enter;
  try
    if not FCDPCalls.TryGetValue(AExecutionId, LObj) then
      Exit;
  finally
    FCDPCallsLock.Leave;
  end;

  LCall := LObj as TPendingCDPCall;
  if AResult = S_OK then
  begin
    LCall.ResultJson := string(AResultObjectAsJson);
    LCall.Success := True;
  end
  else
  begin
    LCall.ResultJson := '';
    LCall.Success := False;
  end;
  LCall.Event.SetEvent;
end;

procedure TWebView2BrowserSession.BrowserWebMessageReceived(
  Sender: TObject; const AWebView: ICoreWebView2;
  const AArgs: ICoreWebView2WebMessageReceivedEventArgs);
var
  LJson: wvstring;
  LHandler: TProc<string>;
begin
  // C6 fix: dispatch JS postMessage payloads to a registered handler.
  // The handler runs on the main (UI) thread, same as this event.
  if AArgs.Get_WebMessageAsJson(LJson) <> S_OK then Exit;
  LHandler := FOnWebMessage;
  if Assigned(LHandler) then
  try
    LHandler(string(LJson));
  except
    on E: Exception do
      Logger.ErrorFmt('OnWebMessage handler raised: %s',
        [E.Message], 'TWebView2BrowserSession');
  end;
end;

procedure TWebView2BrowserSession.OnMainThread(AProc: TThreadProcedure);
begin
  // C7 fix: WebView2 COM objects are STA-bound to the thread that created
  // them (the main thread). Worker threads must marshal calls.
  if (MainThreadID = TThread.CurrentThread.ThreadID) then
    AProc()
  else
    TThread.Synchronize(nil, AProc);
end;

function TWebView2BrowserSession.WaitForEventSafe(AEvent: TEvent;
  ATimeoutMs: Cardinal): TWaitResult;
var
  LElapsed: Cardinal;
  LStep: Cardinal;
begin
  // C7 fix: if called from main thread, plain WaitFor would block the
  // message pump and prevent WebView2 callbacks from running -> deadlock.
  // Pump messages periodically while waiting.
  if MainThreadID <> TThread.CurrentThread.ThreadID then
  begin
    Result := AEvent.WaitFor(ATimeoutMs);
    Exit;
  end;

  LElapsed := 0;
  LStep := 50;
  while True do
  begin
    Result := AEvent.WaitFor(LStep);
    if Result = wrSignaled then Exit;
    Inc(LElapsed, LStep);
    if (ATimeoutMs <> INFINITE) and (LElapsed >= ATimeoutMs) then
    begin
      Result := wrTimeout;
      Exit;
    end;
    Application.ProcessMessages;
  end;
end;

function TWebView2BrowserSession.CallCDPSync(
  const AMethod, AParams: string;
  ATimeoutMs: Integer): string;
var
  LCall: TPendingCDPCall;
  LId: Integer;
  LWaitResult: TWaitResult;
begin
  LCall := TPendingCDPCall.Create;
  try
    FCDPCallsLock.Enter;
    try
      Inc(FNextCallId);
      if FNextCallId <= 0 then
        FNextCallId := 1;  // skip 0 to avoid colliding with default
      LId := FNextCallId;
      FCDPCalls.Add(LId, LCall);
    finally
      FCDPCallsLock.Leave;
    end;

    try
      // C7 fix: COM call must be on main thread
      OnMainThread(procedure
      begin
        FBrowser.CallDevToolsProtocolMethod(AMethod, AParams, LId);
      end);

      LWaitResult := WaitForEventSafe(LCall.Event, Cardinal(ATimeoutMs));

      if LWaitResult <> wrSignaled then
      begin
        FLastError := 'CDP timeout';
        Exit('');
      end;

      if not LCall.Success then
      begin
        FLastError := 'CDP failed';
        Exit('');
      end;

      Result := LCall.ResultJson;
    finally
      FCDPCallsLock.Enter;
      try
        FCDPCalls.Remove(LId);
      finally
        FCDPCallsLock.Leave;
      end;
    end;
  finally
    LCall.Free;
  end;
end;

function TWebView2BrowserSession.WaitForReady(
  ATimeoutMs: Integer): Boolean;
var
  LTimer: TStopwatch;
begin
  LTimer := TStopwatch.StartNew;
  while not FReady do
  begin
    if LTimer.ElapsedMilliseconds >= ATimeoutMs then
      Exit(False);
    Sleep(50);
    Application.ProcessMessages;
  end;
  Result := True;
end;

{ IBrowserSession }

function TWebView2BrowserSession.GetSessionId: TBrowserSessionId;
begin
  Result := FSessionId;
end;

function TWebView2BrowserSession.GetState: TBrowserSessionState;
begin
  if not FReady then
    Exit(bssInitializing);
  Result := bssReady;
end;

function TWebView2BrowserSession.GetCurrentUrl: string;
begin
  Result := FCurrentUrl;
end;

function TWebView2BrowserSession.GetLastError: string;
begin
  Result := FLastError;
end;

function TWebView2BrowserSession.Navigate(
  const AUrl: string; ATimeoutMs: Integer;
  out AError: string): Boolean;
var
  LWaitResult: TWaitResult;
  LWaitMs: Cardinal;
begin
  AError := '';
  if not FReady then
  begin
    AError := 'Browser not ready';
    Exit(False);
  end;

  // H3 fix: serialize concurrent Navigate calls (we share FNavigationEvent
  // / FNavigationOk so they would otherwise race).
  FNavigateMutex.Enter;
  try
    // BUG-BA-021 fix: actually wait for NavigationCompleted before returning
    FNavigationEvent.ResetEvent;
    FNavigationOk := False;
    // C7 fix: COM call must be on main thread
    OnMainThread(procedure
    begin
      FBrowser.Navigate(AUrl);
    end);

    if ATimeoutMs <= 0 then
      LWaitMs := 30000  // sane default for navigation
    else
      LWaitMs := Cardinal(ATimeoutMs);

    LWaitResult := WaitForEventSafe(FNavigationEvent, LWaitMs);
    if LWaitResult <> wrSignaled then
    begin
      AError := 'Navigation timeout';
      Exit(False);
    end;

    if not FNavigationOk then
    begin
      AError := 'Navigation failed';
      Exit(False);
    end;

    Result := True;
  finally
    FNavigateMutex.Leave;
  end;
end;

function TWebView2BrowserSession.ExecuteScript(
  const AScript: string; out AError: string): Boolean;
begin
  AError := '';
  if not FReady then
  begin
    AError := 'Browser not ready';
    Exit(False);
  end;
  // C7 fix: COM call on main thread
  OnMainThread(procedure
  begin
    FBrowser.ExecuteScript(AScript);
  end);
  Result := True;
end;

function TWebView2BrowserSession.EvaluateScript(
  const AScript: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
var
  LResult: string;
begin
  AError := '';
  AJsonResult := '';
  if not FReady then
  begin
    AError := 'Browser not ready';
    Exit(False);
  end;

  LResult := CallCDPSync('Runtime.evaluate',
    '{"expression":' + JsStringLiteral(AScript) +
    ',"returnByValue":true}',
    ATimeoutMs);

  if LResult = '' then
  begin
    AError := FLastError;
    Exit(False);
  end;

  AJsonResult := LResult;
  Result := True;
end;

function TWebView2BrowserSession.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
var
  LResult: string;
begin
  AError := '';
  AJsonResult := '';
  if not FReady then
  begin
    AError := 'Browser not ready';
    Exit(False);
  end;

  LResult := CallCDPSync(AMethod, AParams, ATimeoutMs);

  if LResult = '' then
  begin
    AError := FLastError;
    Exit(False);
  end;

  AJsonResult := LResult;
  Result := True;
end;

function TWebView2BrowserSession.CaptureScreenshot(
  out AImage: TBytes; out AError: string): Boolean;
var
  LWaitResult: TWaitResult;
begin
  AError := '';
  if not FReady then
  begin
    AError := 'Browser not ready';
    Exit(False);
  end;

  // H4 fix: serialize concurrent screenshots (shared FScreenshotStream)
  FScreenshotMutex.Enter;
  try
    FScreenshotReady := False;
    FScreenshotStream.Clear;
    FScreenshotEvent.ResetEvent;

    // C7 fix: COM call on main thread
    OnMainThread(procedure
    begin
      FBrowser.CapturePreview(
        COREWEBVIEW2_CAPTURE_PREVIEW_IMAGE_FORMAT_PNG,
        FScreenshotStream);
    end);

    LWaitResult := WaitForEventSafe(FScreenshotEvent, 5000);
    if LWaitResult <> wrSignaled then
    begin
      AError := 'Screenshot timeout';
      Exit(False);
    end;

    if not FScreenshotReady then
    begin
      AError := 'Screenshot failed';
      Exit(False);
    end;

    SetLength(AImage, FScreenshotStream.Size);
    if FScreenshotStream.Size > 0 then
    begin
      FScreenshotStream.Position := 0;
      FScreenshotStream.Read(AImage[0], FScreenshotStream.Size);
    end;

    Result := True;
  finally
    FScreenshotMutex.Leave;
  end;
end;

function TWebView2BrowserSession.AsAutomationSession: IBrowserAutomationSession;
begin
  Result := TBrowserAutomationSessionAdapter.Create(Self);
end;

{ IBrowserMessageReceiver }

procedure TWebView2BrowserSession.SetMessageHandler(
  AHandler: TProc<string>);
begin
  // Field assignment is atomic for reference types; no lock needed for
  // this swap, but readers grab a local copy before invoking (see
  // BrowserWebMessageReceived).
  FOnWebMessage := AHandler;
end;

procedure TWebView2BrowserSession.ClearMessageHandler;
begin
  FOnWebMessage := nil;
end;

{ IBrowserSessionAsync }

function TWebView2BrowserSession.NavigateAsync(
  const AUrl: string; ATimeoutMs: Integer;
  ACallback: TProc<Boolean, string>): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      LError: string;
      LSuccess: Boolean;
    begin
      LSuccess := Navigate(AUrl, ATimeoutMs, LError);
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(ACallback) then
            ACallback(LSuccess, LError);
        end);
    end);
end;

function TWebView2BrowserSession.ExecuteScriptAsync(
  const AScript: string;
  ACallback: TProc<Boolean, string>): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      LError: string;
      LSuccess: Boolean;
    begin
      LSuccess := ExecuteScript(AScript, LError);
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(ACallback) then
            ACallback(LSuccess, LError);
        end);
    end);
end;

function TWebView2BrowserSession.EvaluateScriptAsync(
  const AScript: string; ATimeoutMs: Integer;
  ACallback: TProc<Boolean, string, string>): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      LResult, LError: string;
      LSuccess: Boolean;
    begin
      LSuccess := EvaluateScript(AScript, ATimeoutMs,
        LResult, LError);
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(ACallback) then
            ACallback(LSuccess, LResult, LError);
        end);
    end);
end;

function TWebView2BrowserSession.CaptureScreenshotAsync(
  ACallback: TProc<Boolean, TBytes, string>): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      LImage: TBytes;
      LError: string;
      LSuccess: Boolean;
    begin
      LSuccess := CaptureScreenshot(LImage, LError);
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(ACallback) then
            ACallback(LSuccess, LImage, LError);
        end);
    end);
end;

{ Self-registration }

procedure RegisterWebView2Backend;
var
  LInfo: TBrowserBackendInfo;
begin
  LInfo := Default(TBrowserBackendInfo);
  LInfo.Kind := bbkWebView2;
  LInfo.Name := 'WebView2';
  LInfo.Enabled := True;
  LInfo.Priority := 0;
  LInfo.IsAvailableFunc :=
    function: Boolean
    begin
      Result := GWebView2Initialized and
        (GlobalWebView2Loader <> nil) and
        GlobalWebView2Loader.Initialized;
    end;
  // C5 fix: provide a real FactoryFunc that pulls the host TWinControl from
  // the user-registered owner provider. Without a provider, the factory
  // raises a clear error rather than returning nil.
  LInfo.FactoryFunc :=
    function: IBrowserSession
    var
      LOwner: TWinControl;
    begin
      if not Assigned(GWebView2OwnerProvider) then
        raise EBrowserError.Create(
          'WebView2 backend has no owner provider; ' +
          'call SetWebView2OwnerProvider(...) before requesting a session');
      LOwner := GWebView2OwnerProvider();
      if LOwner = nil then
        raise EBrowserError.Create(
          'WebView2 owner provider returned nil');
      Result := TWebView2BrowserSession.Create(LOwner);
    end;
  TBrowserRegistry.Register(LInfo);
end;

initialization
  RegisterWebView2Backend;

finalization
  // H8 fix: release the global WebView2 loader on shutdown so the WebView2
  // host process and its lock files exit cleanly.
  GWebView2OwnerProvider := nil;
  if GlobalWebView2Loader <> nil then
  begin
    GlobalWebView2Loader.Free;
    GlobalWebView2Loader := nil;
  end;
  GWebView2Initialized := False;

{$ENDIF USE_WEBVIEW2}

end.
