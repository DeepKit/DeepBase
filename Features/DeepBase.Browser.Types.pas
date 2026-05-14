{ ============================================================================
  DeepBase.Browser.Types
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Type definitions for the DeepBase Browser Automation framework.
                Pure type declarations -- interfaces, records, enums, exceptions.
                No implementation logic beyond record helpers.
  ============================================================================ }

unit DeepBase.Browser.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Threading;

const
  BROWSER_API_LEVEL = 1;

type
  { --- Exceptions ---------------------------------------------------------- }

  EBrowserError = class(Exception);
  EBrowserSessionError = class(EBrowserError);
  EBrowserRecoveryError = class(EBrowserError);
  EBrowserTimeoutError = class(EBrowserSessionError);

  // BUG-173: forward declaration so IBrowserSession.AsAutomationSession can
  // return IBrowserAutomationSession before the latter is fully declared
  // below. Same Delphi rule as in DeepShell.MainForm: an interface field /
  // method-result type must be visible (forward or full) by the time it is
  // referenced.
  IBrowserAutomationSession = interface;

  { --- Opaque session handle ----------------------------------------------- }

  TBrowserSessionId = type string;

  { --- Session lifecycle enums --------------------------------------------- }

  TBrowserSessionState = (
    bssUninitialized,
    bssInitializing,
    bssReady,
    bssBusy,
    bssUnresponsive,
    bssRecovering,
    bssCrashed,
    bssDisposed
  );

  TBrowserSessionTrigger = (
    bstInitialize,
    bstReady,
    bstNavigate,
    bstComplete,
    bstError,
    bstUnresponsive,
    bstRecoverStart,
    bstRecoverSuccess,
    bstRecoverFail,
    bstCrash,
    bstDispose
  );

  { --- Health & recovery -------------------------------------------------- }

  TBrowserHealthStatus = (
    bhsHealthy,
    bhsUnresponsive,
    bhsCrashed,
    bhsNetworkError,
    bhsRecovering
  );

  TBrowserRecoveryStrategy = (
    brsNone,
    brsReload,
    brsRestart,
    brsRecreate
  );

  TBrowserRecoveryConfig = record
    MaxRetries: Integer;
    RetryDelayMs: Integer;
    HealthCheckIntervalMs: Integer;
    UnresponsiveThresholdMs: Integer;
    AutoRecoveryEnabled: Boolean;
    class function Default: TBrowserRecoveryConfig; static;
  end;

  TBrowserSnapshot = record
    SessionId: TBrowserSessionId;
    Url: string;
    ScrollPosition: Integer;
    ExtraData: string;
    Timestamp: TDateTime;
    class function Create(const ASessionId: TBrowserSessionId;
      const AUrl: string = ''; AScrollPosition: Integer = 0;
      const AExtraData: string = ''): TBrowserSnapshot; static;
  end;

  TRecoveryEvent = procedure(const ASessionId: TBrowserSessionId;
    AStrategy: TBrowserRecoveryStrategy; AAttempt: Integer;
    ASuccess: Boolean) of object;

  { --- Response waiting --------------------------------------------------- }

  TBrowserWaitResult = (
    bwrSuccess,
    bwrTimeout,
    bwrError,
    bwrCancelled
  );

  TBrowserWaitConfig = record
    ResponseSelector: string;
    LoadingSelector: string;
    TimeoutMs: Integer;
    StableMs: Integer;
    class function Default: TBrowserWaitConfig; static;
  end;

  { --- Events ------------------------------------------------------------- }

  TBrowserEventType = (
    betNavigationCompleted,
    betNavigationFailed,
    betScriptExecuted,
    betScriptFailed,
    betCrashed,
    betRecovered,
    betHealthChanged,
    betResponseReceived,
    betResponseTimeout,
    betWindowOpened,
    betWindowClosed,
    // M7 fix: distinguish "released back to pool" from "actually closed".
    // Window pool emits betWindowReleased on Release(); only ShutdownAll
    // (or hard close) emits betWindowClosed.
    betWindowReleased,
    betWindowAcquired
  );

  TBrowserEvent = record
    EventType: TBrowserEventType;
    SessionId: TBrowserSessionId;
    Timestamp: TDateTime;
    Data: string;
    class function Create(AEventType: TBrowserEventType;
      const ASessionId: TBrowserSessionId;
      const AData: string = ''): TBrowserEvent; static;
  end;

  { --- Callback types ----------------------------------------------------- }

  TCDPCallback = reference to procedure(ASuccess: Boolean;
    const AResult: string);

  TCDPCDEventCallback = reference to procedure(const AMethod: string;
    const AParams: string);

  { --- Selector management ------------------------------------------------ }

  TBrowserSelectorInfo = record
    Name: string;
    Selector: string;
    FallbackSelector: string;
    IsValid: Boolean;
    LastValidatedAt: TDateTime;
  end;

  { --- Interfaces --------------------------------------------------------- }

  IBrowserSession = interface
    ['{C4E2D1A0-3B5F-4A7E-8C9D-0E1F2A3B4C5D}']
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

    // BUG-BA-024 fix: returns the typed IBrowserAutomationSession (declared
    // below in this same unit so we can avoid the old IInterface cast).
    function AsAutomationSession: IBrowserAutomationSession;
  end;

  // BUG-BA-024 fix: relocated from DeepBase.BrowserAutomation so IBrowserSession
  // can return it without a circular dependency. The Phase 1 Runner / Action
  // / Scripts logic stays in DeepBase.BrowserAutomation; only the interface
  // declaration moved here.
  IBrowserAutomationSession = interface
    ['{AF65E2C4-7181-42D6-95D9-D52D246C68D2}']
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
  end;

  IBrowserSessionAsync = interface
    ['{D5F3E2B1-4C6A-5B8F-9D0E-1F2A3B4C5D6E}']
    function NavigateAsync(const AUrl: string; ATimeoutMs: Integer;
      ACallback: TProc<Boolean, string>): ITask;
    function ExecuteScriptAsync(const AScript: string;
      ACallback: TProc<Boolean, string>): ITask;
    function EvaluateScriptAsync(const AScript: string; ATimeoutMs: Integer;
      ACallback: TProc<Boolean, string, string>): ITask;
    function CaptureScreenshotAsync(
      ACallback: TProc<Boolean, TBytes, string>): ITask;
  end;

  // C6 fix: capability interface for receiving JS-side
  // window.chrome.webview.postMessage() payloads. Browser implementations
  // that support inbound messages from JS implement this; consumers detect
  // support via Supports().
  IBrowserMessageReceiver = interface
    ['{2F8D6C5B-4A3E-91D7-B2C0-3E4F5A6B7C8D}']
    procedure SetMessageHandler(AHandler: TProc<string>);
    procedure ClearMessageHandler;
  end;

  IBrowserRecovery = interface
    ['{E6A4F3C2-5D7B-6C9A-0E1F-2A3B4C5D6E7F}']
    procedure SaveSnapshot(const ASnapshot: TBrowserSnapshot);
    function GetSnapshot(
      const ASessionId: TBrowserSessionId): TBrowserSnapshot;
    procedure ClearSnapshot(const ASessionId: TBrowserSessionId);  // M3 fix
    procedure UpdateHealthStatus(const ASessionId: TBrowserSessionId;
      AStatus: TBrowserHealthStatus);
    function GetHealthStatus(
      const ASessionId: TBrowserSessionId): TBrowserHealthStatus;
    procedure RecordHeartbeat(const ASessionId: TBrowserSessionId);
    function IsUnresponsive(
      const ASessionId: TBrowserSessionId): Boolean;
    procedure TriggerRecovery(const ASessionId: TBrowserSessionId;
      AStrategy: TBrowserRecoveryStrategy);
    procedure ResetRetryCount(const ASessionId: TBrowserSessionId);
    function GetRetryCount(const ASessionId: TBrowserSessionId): Integer;
    procedure StartHealthMonitor;
    procedure StopHealthMonitor;
  end;

  // BUG-BA-025 fix: factory abstraction so Recovery can actually rebuild
  // sessions, not just notify.
  IBrowserSessionFactory = interface
    ['{1A2B3C4D-5E6F-7A8B-9C0D-1E2F3A4B5C6D}']
    /// <summary>Create a fresh session, optionally inheriting AHintId.
    /// Must return a usable IBrowserSession or raise EBrowserError.</summary>
    function CreateSession(
      const AHintId: TBrowserSessionId = ''): IBrowserSession;

    /// <summary>Dispose the supplied session and release its OS-level
    /// resources (windows, COM objects). Idempotent.</summary>
    procedure DisposeSession(const ASession: IBrowserSession);
  end;

  // BUG-BA-025 fix: notification fired after Recovery rebuilds a session.
  // Subscribers (Service / Pool / app code) must replace their references
  // to AOldSessionId with ANewSession.
  TSessionRebuiltEvent = reference to procedure(
    const AOldSessionId: TBrowserSessionId;
    const ANewSession: IBrowserSession);

  IResponseWaiter = interface
    ['{F7B5A4D3-6E8C-7D0B-1F2A-3B4C5D6E7F80}']
    function StartWaiting(const AResponseSelector,
      ALoadingSelector: string): Boolean;
    procedure CancelWaiting;
    function GetWaiterJS(const AResponseSelector,
      ALoadingSelector: string; ATimeoutMs,
      AStableMs: Integer): string;
    procedure HandleWaitResult(const AResult: string;
      const AResponse: string; ADurationMs: Int64);
    function GetWaiting: Boolean;
    function GetTimeoutMs: Integer;
    procedure SetTimeoutMs(AValue: Integer);
    function GetStableMs: Integer;
    procedure SetStableMs(AValue: Integer);

    property Waiting: Boolean read GetWaiting;
    property TimeoutMs: Integer read GetTimeoutMs write SetTimeoutMs;
    property StableMs: Integer read GetStableMs write SetStableMs;
  end;

{ --- Helper functions ----------------------------------------------------- }

function BrowserSessionStateToString(
  AValue: TBrowserSessionState): string;
function BrowserHealthStatusToString(
  AValue: TBrowserHealthStatus): string;
function BrowserRecoveryStrategyToString(
  AValue: TBrowserRecoveryStrategy): string;
function BrowserWaitResultToString(AValue: TBrowserWaitResult): string;
function BrowserEventTypeToString(AValue: TBrowserEventType): string;

// C3/C4 fix: leak-free JS string literal builder.
// Wraps AValue in TJSONString and disposes it after rendering, returning
// a properly escaped JS string literal (e.g. "hello \"world\"").
function JsStringLiteral(const AValue: string): string;

// H7 fix: locale-independent float-to-JSON conversion.
// Always emits '.' as decimal separator regardless of OS locale.
function JsFloat(const AValue: Double): string;

implementation

uses
  System.JSON;

{ --- Record factory methods ----------------------------------------------- }

class function TBrowserRecoveryConfig.Default: TBrowserRecoveryConfig;
begin
  Result.MaxRetries := 3;
  Result.RetryDelayMs := 2000;
  Result.HealthCheckIntervalMs := 5000;
  Result.UnresponsiveThresholdMs := 30000;
  Result.AutoRecoveryEnabled := True;
end;

class function TBrowserSnapshot.Create(const ASessionId: TBrowserSessionId;
  const AUrl: string; AScrollPosition: Integer;
  const AExtraData: string): TBrowserSnapshot;
begin
  Result := Default(TBrowserSnapshot);
  Result.SessionId := ASessionId;
  Result.Url := AUrl;
  Result.ScrollPosition := AScrollPosition;
  Result.ExtraData := AExtraData;
  Result.Timestamp := Now;
end;

class function TBrowserWaitConfig.Default: TBrowserWaitConfig;
begin
  Result.ResponseSelector := '';
  Result.LoadingSelector := '';
  Result.TimeoutMs := 120000;
  Result.StableMs := 3000;
end;

class function TBrowserEvent.Create(AEventType: TBrowserEventType;
  const ASessionId: TBrowserSessionId;
  const AData: string): TBrowserEvent;
begin
  Result := Default(TBrowserEvent);
  Result.EventType := AEventType;
  Result.SessionId := ASessionId;
  Result.Data := AData;
  Result.Timestamp := Now;
end;

{ --- String helpers ------------------------------------------------------- }

function BrowserSessionStateToString(
  AValue: TBrowserSessionState): string;
begin
  case AValue of
    bssUninitialized: Result := 'uninitialized';
    bssInitializing: Result := 'initializing';
    bssReady: Result := 'ready';
    bssBusy: Result := 'busy';
    bssUnresponsive: Result := 'unresponsive';
    bssRecovering: Result := 'recovering';
    bssCrashed: Result := 'crashed';
    bssDisposed: Result := 'disposed';
  else
    Result := 'unknown';
  end;
end;

function BrowserHealthStatusToString(
  AValue: TBrowserHealthStatus): string;
begin
  case AValue of
    bhsHealthy: Result := 'healthy';
    bhsUnresponsive: Result := 'unresponsive';
    bhsCrashed: Result := 'crashed';
    bhsNetworkError: Result := 'network_error';
    bhsRecovering: Result := 'recovering';
  else
    Result := 'unknown';
  end;
end;

function BrowserRecoveryStrategyToString(
  AValue: TBrowserRecoveryStrategy): string;
begin
  case AValue of
    brsNone: Result := 'none';
    brsReload: Result := 'reload';
    brsRestart: Result := 'restart';
    brsRecreate: Result := 'recreate';
  else
    Result := 'unknown';
  end;
end;

function BrowserWaitResultToString(AValue: TBrowserWaitResult): string;
begin
  case AValue of
    bwrSuccess: Result := 'success';
    bwrTimeout: Result := 'timeout';
    bwrError: Result := 'error';
    bwrCancelled: Result := 'cancelled';
  else
    Result := 'unknown';
  end;
end;

function BrowserEventTypeToString(AValue: TBrowserEventType): string;
begin
  case AValue of
    betNavigationCompleted: Result := 'navigation_completed';
    betNavigationFailed: Result := 'navigation_failed';
    betScriptExecuted: Result := 'script_executed';
    betScriptFailed: Result := 'script_failed';
    betCrashed: Result := 'crashed';
    betRecovered: Result := 'recovered';
    betHealthChanged: Result := 'health_changed';
    betResponseReceived: Result := 'response_received';
    betResponseTimeout: Result := 'response_timeout';
    betWindowOpened: Result := 'window_opened';
    betWindowClosed: Result := 'window_closed';
    betWindowReleased: Result := 'window_released';
    betWindowAcquired: Result := 'window_acquired';
  else
    Result := 'unknown';
  end;
end;

function JsStringLiteral(const AValue: string): string;
var
  LJson: TJSONString;
begin
  // C3/C4 fix: leak-free wrapper around TJSONString.ToJSON.
  LJson := TJSONString.Create(AValue);
  try
    Result := LJson.ToJSON;
  finally
    LJson.Free;
  end;
end;

function JsFloat(const AValue: Double): string;
var
  LFmt: TFormatSettings;
begin
  // H7 fix: invariant locale ('.' decimal separator) so generated JSON
  // is always parseable regardless of OS locale (e.g. de-DE, fr-FR).
  LFmt := TFormatSettings.Invariant;
  Result := FloatToStr(AValue, LFmt);
end;

end.
