{ ============================================================================
  DeepBase.Browser.ResponseWaiter
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : MutationObserver-based response stability detection.
                Injects a JS waiter that monitors DOM mutations, waits for
                content to stabilize (no changes for StableMs milliseconds),
                then reports completion.
                Generalized from DeepCompare.ResponseWaiter.
                Replaces CEF cefQuery with WebView2 postMessage.
  ============================================================================ }

unit DeepBase.Browser.ResponseWaiter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.SyncObjs,
  DeepBase.Browser.Types;

type
  // BUG-BA-027 fix: reference-to-procedure allows assignment from both
  // anonymous methods (matching the IntentClarification接入指南 style) and
  // method-of-class (via wrapping). of-object was too restrictive.
  TResponseWaiterEvent = reference to procedure(
    AResult: TBrowserWaitResult;
    const AResponse: string; ADurationMs: Int64);

  TBrowserResponseWaiter = class(TInterfacedObject, IResponseWaiter)
  private
    FSession: IBrowserSession;
    FWaitingFlag: Integer;  // M9 fix: atomic int for cross-thread reads
    FTimeoutMs: Integer;
    FStableMs: Integer;
    FOnResult: TResponseWaiterEvent;

    procedure InjectScript(const AScript: string);
    procedure DispatchPostMessage(const AJson: string);
    function GetWaitingFlag: Boolean;
    procedure SetWaitingFlag(AValue: Boolean);
  public
    constructor Create(ASession: IBrowserSession);
    destructor Destroy; override;

    function StartWaiting(const AResponseSelector,
      ALoadingSelector: string): Boolean;
    procedure CancelWaiting;
    function GetWaiterJS(const AResponseSelector,
      ALoadingSelector: string; ATimeoutMs,
      AStableMs: Integer): string;
    procedure HandleWaitResult(const AResult: string;
      const AResponse: string; ADurationMs: Int64);

    // BUG-BA-018 fix: pure-functional template builder, callable without instance
    class function BuildWaiterJS(const AResponseSelector,
      ALoadingSelector: string; ATimeoutMs,
      AStableMs: Integer): string; static;

    function GetWaiting: Boolean;
    function GetTimeoutMs: Integer;
    procedure SetTimeoutMs(AValue: Integer);
    function GetStableMs: Integer;
    procedure SetStableMs(AValue: Integer);

    property Waiting: Boolean read GetWaiting;
    property TimeoutMs: Integer read GetTimeoutMs write SetTimeoutMs;
    property StableMs: Integer read GetStableMs write SetStableMs;
    property OnResult: TResponseWaiterEvent read FOnResult write FOnResult;
  end;

implementation

uses
  System.JSON,
  DeepBase.Browser.ScriptStore;

const
  // JS body uses {{name}} placeholders rendered via TJSTemplate.Render
  // (JSON-string-safe substitution; eliminates the BUG-BA-010 QuotedStr issue).
  WAITER_JS_TEMPLATE =
    '(function() {' +
    '  if (window.__dbWaiter) {' +
    '    window.__dbWaiter.cancel();' +
    '  }' +
    '  var responseSel = {{response_selector}};' +
    '  var loadingSel = {{loading_selector}};' +
    '  var timeoutMs = {{timeout_ms}};' +
    '  var stableMs = {{stable_ms}};' +
    '  window.__dbWaiter = {' +
    '    observer: null,' +
    '    timeoutTimer: null,' +
    '    stableTimer: null,' +
    '    startTime: Date.now(),' +
    '    lastContent: "",' +
    '    cancelled: false,' +
    '    start: function() {' +
    '      var self = this;' +
    '      this.timeoutTimer = setTimeout(function() {' +
    '        self.finish("timeout", self.getLatestResponse());' +
    '      }, timeoutMs);' +
    '      this.observer = new MutationObserver(function() {' +
    '        if (self.cancelled) return;' +
    '        if (loadingSel) {' +
    '          var loading = document.querySelector(loadingSel);' +
    '          if (loading) {' +
    '            clearTimeout(self.stableTimer);' +
    '            return;' +
    '          }' +
    '        }' +
    '        var content = self.getLatestResponse();' +
    '        if (content !== self.lastContent) {' +
    '          self.lastContent = content;' +
    '          clearTimeout(self.stableTimer);' +
    '          self.stableTimer = setTimeout(function() {' +
    '            self.finish("success", content);' +
    '          }, stableMs);' +
    '        }' +
    '      });' +
    '      this.observer.observe(document.body, {' +
    '        childList: true,' +
    '        subtree: true,' +
    '        characterData: true' +
    '      });' +
    '      var initial = this.getLatestResponse();' +
    '      if (initial) {' +
    '        this.lastContent = initial;' +
    '        this.stableTimer = setTimeout(function() {' +
    '          self.finish("success", initial);' +
    '        }, stableMs);' +
    '      }' +
    '    },' +
    '    getLatestResponse: function() {' +
    '      if (!responseSel) return "";' +
    '      var els = document.querySelectorAll(responseSel);' +
    '      if (els.length === 0) return "";' +
    '      var last = els[els.length - 1];' +
    '      return last.innerText || last.textContent || "";' +
    '    },' +
    '    finish: function(result, response) {' +
    '      if (this.cancelled) return;' +
    '      this.cancel();' +
    '      var duration = Date.now() - this.startTime;' +
    '      var msg = JSON.stringify({' +
    '        type: "db_response_waiter",' +
    '        result: result,' +
    '        response: response,' +
    '        durationMs: duration' +
    '      });' +
    '      if (window.chrome && window.chrome.webview) {' +
    '        window.chrome.webview.postMessage(msg);' +
    '      }' +
    '    },' +
    '    cancel: function() {' +
    '      this.cancelled = true;' +
    '      if (this.observer) {' +
    '        this.observer.disconnect();' +
    '        this.observer = null;' +
    '      }' +
    '      clearTimeout(this.timeoutTimer);' +
    '      clearTimeout(this.stableTimer);' +
    '    }' +
    '  };' +
    '  window.__dbWaiter.start();' +
    '})();';

  WAITER_CANCEL_JS =
    'if (window.__dbWaiter) {' +
    '  window.__dbWaiter.cancel();' +
    '  delete window.__dbWaiter;' +
    '}';

{ TBrowserResponseWaiter }

constructor TBrowserResponseWaiter.Create(ASession: IBrowserSession);
begin
  inherited Create;
  FSession := ASession;
  FWaitingFlag := 0;
  FTimeoutMs := 120000;
  FStableMs := 3000;
end;

destructor TBrowserResponseWaiter.Destroy;
begin
  if GetWaitingFlag then
    CancelWaiting;
  inherited;
end;

function TBrowserResponseWaiter.GetWaitingFlag: Boolean;
begin
  // M9 fix: atomic read across threads
  Result := TInterlocked.Read(FWaitingFlag) <> 0;
end;

procedure TBrowserResponseWaiter.SetWaitingFlag(AValue: Boolean);
begin
  // M9 fix: atomic write across threads
  if AValue then
    TInterlocked.Exchange(FWaitingFlag, 1)
  else
    TInterlocked.Exchange(FWaitingFlag, 0);
end;

procedure TBrowserResponseWaiter.InjectScript(const AScript: string);
var
  LError: string;
begin
  if FSession <> nil then
    FSession.ExecuteScript(AScript, LError);
end;

procedure TBrowserResponseWaiter.DispatchPostMessage(const AJson: string);
var
  LValue: TJSONValue;
  LObj: TJSONObject;
  LType, LResult, LResponse: string;
  LDurationMs: Int64;
  LDurNum: TJSONNumber;
begin
  // C6 fix: parse the JS-side payload and route to HandleWaitResult.
  // Shape: {"type":"db_response_waiter","result":"success",
  //         "response":"...","durationMs":1234}
  LValue := TJSONObject.ParseJSONValue(AJson);
  if LValue = nil then Exit;
  try
    if not (LValue is TJSONObject) then Exit;
    LObj := LValue as TJSONObject;
    LType := LObj.GetValue<string>('type', '');
    if LType <> 'db_response_waiter' then Exit;

    LResult := LObj.GetValue<string>('result', '');
    LResponse := LObj.GetValue<string>('response', '');
    LDurNum := LObj.GetValue('durationMs') as TJSONNumber;
    if LDurNum <> nil then
      LDurationMs := LDurNum.AsInt64
    else
      LDurationMs := 0;

    HandleWaitResult(LResult, LResponse, LDurationMs);
  finally
    LValue.Free;
  end;
end;

function TBrowserResponseWaiter.StartWaiting(
  const AResponseSelector, ALoadingSelector: string): Boolean;
var
  LJS: string;
  LError: string;
  LStore: IJSScriptStore;
  LReceiver: IBrowserMessageReceiver;
begin
  if FSession = nil then
    Exit(False);

  // C6 fix: subscribe to JS postMessage callbacks BEFORE injecting the
  // waiter, so we don't miss an early "success" event.
  if Supports(FSession, IBrowserMessageReceiver, LReceiver) then
    LReceiver.SetMessageHandler(
      procedure(const AJson: string)
      begin
        DispatchPostMessage(AJson);
      end);

  // ISSUE-BA-101: prefer the DB-backed template; fall back to the embedded
  // default if ScriptStore isn't initialized (e.g., test environment).
  LStore := ScriptStore;
  if (LStore <> nil) and LStore.HasScript(JSCRIPT_RESPONSE_WAITER) then
    LJS := LStore.Render(JSCRIPT_RESPONSE_WAITER, [
      'response_selector', AResponseSelector,
      'loading_selector', ALoadingSelector,
      'timeout_ms', FTimeoutMs,
      'stable_ms', FStableMs])
  else
    LJS := BuildWaiterJS(AResponseSelector, ALoadingSelector,
      FTimeoutMs, FStableMs);

  Result := FSession.ExecuteScript(LJS, LError);
  if Result then
    SetWaitingFlag(True);
end;

procedure TBrowserResponseWaiter.CancelWaiting;
var
  LStore: IJSScriptStore;
  LJS: string;
  LReceiver: IBrowserMessageReceiver;
begin
  SetWaitingFlag(False);

  // C6 fix: detach message handler to prevent stale callbacks
  if Supports(FSession, IBrowserMessageReceiver, LReceiver) then
    LReceiver.ClearMessageHandler;

  LStore := ScriptStore;
  if (LStore <> nil) and LStore.HasScript(JSCRIPT_WAITER_CANCEL) then
    LJS := LStore.Render(JSCRIPT_WAITER_CANCEL, [])
  else
    LJS := WAITER_CANCEL_JS;
  InjectScript(LJS);
end;

function TBrowserResponseWaiter.GetWaiterJS(
  const AResponseSelector, ALoadingSelector: string;
  ATimeoutMs, AStableMs: Integer): string;
begin
  Result := BuildWaiterJS(AResponseSelector, ALoadingSelector,
    ATimeoutMs, AStableMs);
end;

class function TBrowserResponseWaiter.BuildWaiterJS(
  const AResponseSelector, ALoadingSelector: string;
  ATimeoutMs, AStableMs: Integer): string;
begin
  // BUG-BA-010 fix: TJSTemplate.Render uses TJSONString to wrap string
  // values, producing valid JS string literals. Selectors containing
  // single/double quotes or Unicode characters are safe.
  Result := TJSTemplate.Render(WAITER_JS_TEMPLATE, [
    'response_selector', AResponseSelector,
    'loading_selector', ALoadingSelector,
    'timeout_ms', ATimeoutMs,
    'stable_ms', AStableMs]);
end;

procedure TBrowserResponseWaiter.HandleWaitResult(const AResult: string;
  const AResponse: string; ADurationMs: Int64);
var
  LResult: TBrowserWaitResult;
begin
  SetWaitingFlag(False);

  if AResult = 'success' then
    LResult := bwrSuccess
  else if AResult = 'timeout' then
    LResult := bwrTimeout
  else if AResult = 'cancelled' then
    LResult := bwrCancelled
  else
    LResult := bwrError;

  if Assigned(FOnResult) then
    FOnResult(LResult, AResponse, ADurationMs);
end;

function TBrowserResponseWaiter.GetWaiting: Boolean;
begin
  Result := GetWaitingFlag;
end;

function TBrowserResponseWaiter.GetTimeoutMs: Integer;
begin
  Result := FTimeoutMs;
end;

procedure TBrowserResponseWaiter.SetTimeoutMs(AValue: Integer);
begin
  FTimeoutMs := AValue;
end;

function TBrowserResponseWaiter.GetStableMs: Integer;
begin
  Result := FStableMs;
end;

procedure TBrowserResponseWaiter.SetStableMs(AValue: Integer);
begin
  FStableMs := AValue;
end;

end.
