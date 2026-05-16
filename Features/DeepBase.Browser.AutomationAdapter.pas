{ ============================================================================
  DeepBase.Browser.AutomationAdapter
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Engine-agnostic adapter that bridges any IBrowserSession
                (Browser.Types) onto the Phase 1 IBrowserAutomationSession
                used by the legacy TBrowserAutomationRunner.

  M1 fix: previously this adapter lived inside DeepBase.Browser.Engine.WebView2
  and was unreachable by other backends (CEF, mock, etc.). Lifted into a
  dedicated unit so any IBrowserSession can be wrapped with a one-liner:

    LRunner := TBrowserAutomationRunner.Create(
                 TBrowserSession2AutomationAdapter.Create(LSession));
  ============================================================================ }

unit DeepBase.Browser.AutomationAdapter;

interface

uses
  System.SysUtils,
  System.Classes,
  DeepBase.Browser.Types,
  DeepBase.BrowserAutomation;

type
  /// <summary>
  /// Wraps an IBrowserSession (newer Phase 2+ interface) so it can be
  /// driven by the Phase 1 TBrowserAutomationRunner. All calls forward
  /// 1:1; no behavior change beyond mapping IBrowserSession.GetState to
  /// IBrowserAutomationSession.IsReady.
  /// </summary>
  TBrowserSession2AutomationAdapter = class(TInterfacedObject,
    IBrowserAutomationSession)
  private
    FSession: IBrowserSession;
  public
    constructor Create(const ASession: IBrowserSession);

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

    property Session: IBrowserSession read FSession;
  end;

implementation

constructor TBrowserSession2AutomationAdapter.Create(
  const ASession: IBrowserSession);
begin
  inherited Create;
  FSession := ASession;
end;

function TBrowserSession2AutomationAdapter.IsReady: Boolean;
begin
  Result := (FSession <> nil) and
    (FSession.GetState in [bssReady, bssBusy]);
end;

function TBrowserSession2AutomationAdapter.GetCurrentUrl: string;
begin
  if FSession <> nil then
    Result := FSession.GetCurrentUrl
  else
    Result := '';
end;

function TBrowserSession2AutomationAdapter.GetLastError: string;
begin
  if FSession <> nil then
    Result := FSession.GetLastError
  else
    Result := 'No session';
end;

function TBrowserSession2AutomationAdapter.Navigate(
  const AUrl: string; ATimeoutMs: Integer;
  out AError: string): Boolean;
begin
  if FSession = nil then
  begin
    AError := 'No session';
    Exit(False);
  end;
  Result := FSession.Navigate(AUrl, ATimeoutMs, AError);
end;

function TBrowserSession2AutomationAdapter.ExecuteScript(
  const AScript: string; out AError: string): Boolean;
begin
  if FSession = nil then
  begin
    AError := 'No session';
    Exit(False);
  end;
  Result := FSession.ExecuteScript(AScript, AError);
end;

function TBrowserSession2AutomationAdapter.EvaluateScript(
  const AScript: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  if FSession = nil then
  begin
    AJsonResult := '';
    AError := 'No session';
    Exit(False);
  end;
  Result := FSession.EvaluateScript(AScript, ATimeoutMs,
    AJsonResult, AError);
end;

function TBrowserSession2AutomationAdapter.CallDevToolsProtocol(
  const AMethod, AParams: string; ATimeoutMs: Integer;
  out AJsonResult, AError: string): Boolean;
begin
  if FSession = nil then
  begin
    AJsonResult := '';
    AError := 'No session';
    Exit(False);
  end;
  Result := FSession.CallDevToolsProtocol(AMethod, AParams,
    ATimeoutMs, AJsonResult, AError);
end;

function TBrowserSession2AutomationAdapter.CaptureScreenshot(
  out AImage: TBytes; out AError: string): Boolean;
begin
  if FSession = nil then
  begin
    AImage := nil;
    AError := 'No session';
    Exit(False);
  end;
  Result := FSession.CaptureScreenshot(AImage, AError);
end;

end.
