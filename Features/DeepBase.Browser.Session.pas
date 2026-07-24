{ ============================================================================
  DeepBase.Browser.Session
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : High-level browser session management interface providing
                Selenium-like API for DOM manipulation, navigation, and 
                screenshot capture.
  
  Features:
    - NavigateTo, CloseTab, SwitchTab operations
    - Network request interception support
    - History navigation (back/forward)
    - Cookie/session management
  
  Performance:
    - Connection pooling for multiple browser instances
    - Lazy element lookup with caching
  ========================================================================== }

unit DeepBase.Browser.Session;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Variants,
  Winapi.Windows,
  DeepBase.Browser.CDP.Adapter,
  DeepBase.Browser.WebElement;

type
  TNavigationOptions = record
    WaitForLoad: Boolean;         // Wait for load event (default True)
    TimeoutMs: Cardinal;          // Maximum wait time (default 30s)
  end;

  IBrowserSession = interface
    ['{CDEF3456-GH78-9012-JKLM-NOPQRSTUVWXYZA}']
    
    // Lifecycle management
    procedure Open(URL: string = ''); virtual; abstract;
    procedure Close; virtual; abstract;
    function IsOpen: Boolean; virtual; abstract;
    
    // Navigation
    function NavigateTo(URL: string; Options: TNavigationOptions = default): Boolean; virtual; abstract;
    procedure GoBack; virtual; abstract;
    procedure GoForward; virtual; abstract;
    procedure Reload; virtual; abstract;
    function GetURL: string; virtual; abstract;
    
    // Tab management
    function GetCurrentTabID: Integer; virtual; abstract;
    function CreateNewTab: Integer; virtual; abstract;
    procedure CloseTab(TabID: Integer); virtual; abstract;
    procedure SwitchTab(TabID: Integer); virtual; abstract;
    
    // Element operations
    function FindElementByCSS(Selector: string): TWebWebElement; virtual; abstract; overload;
    function FindElementByXPath(XPath: string): TWebWebElement; virtual; abstract; overload;
    function FindElements(Selector: string): TArray<TWebWebElement>; virtual; abstract;
    
    // Basic actions
    procedure Click(Selector: string); overload; virtual; abstract;
    procedure TypeText(Selector: string; Text: string); virtual; abstract;
    function GetAttribute(Selector: string; AttrName: string): string; virtual; abstract;
    
    // Page content
    function GetHTMLContent: string; virtual; abstract;
    function GetInnerText: string; virtual; abstract;
    
    // Screenshots
    function TakeScreenshot: TMemoryStream; virtual; abstract;
    
    // Cookies & storage
    function GetCookies: TJSONArray; virtual; abstract;
    procedure AddCookie(CookieJSON: TStringList); virtual; abstract;
    procedure ClearCookies; virtual; abstract;
  end;

  TBrowseSessionImpl = class(TInterfacedObject, IBrowserSession)
  private
    FCDPSession: ICDPSession;
    FIsManagedBrowser: Boolean;
    FCurrentTabID: Integer;
    FConnected: Boolean;
    
    // Helper methods
    function EnsureConnected;
    function ParseJSONObject(const JSONStr: string): TJSONObject;
    function ExecuteCdpCommand(Method: string; const Params: array of const): TJSONValue;
  public
    constructor Create; overload;
    constructor CreateFromExistingSession(Session: ICDPSession); overload;
    destructor Destroy; override;
    
    // IBrowserSession implementation
    procedure Open(URL: string);
    procedure Close;
    function IsOpen: Boolean;
    function NavigateTo(URL: string; Options: TNavigationOptions): Boolean;
    procedure GoBack;
    procedure GoForward;
    procedure Reload;
    function GetURL: string;
    function GetCurrentTabID: Integer;
    function CreateNewTab: Integer;
    procedure CloseTab(TabID: Integer);
    procedure SwitchTab(TabID: Integer);
    function FindElementByCSS(Selector: string): TWebWebElement;
    function FindElementByXPath(XPath: string): TWebWebElement;
    function FindElements(Selector: string): TArray<TWebWebElement>;
    procedure Click(Selector: string);
    procedure TypeText(Selector: string; Text: string);
    function GetAttribute(Selector: string; AttrName: string): string;
    function GetHTMLContent: string;
    function GetInnerText: string;
    function TakeScreenshot: TMemoryStream;
    function GetCookies: TJSONArray;
    procedure AddCookie(CookieJSON: TStringList);
    procedure ClearCookies;
  end;

// Factory functions
procedure InitializeBrowserSessionManager;
function CreateBrowserSession(URL: string = ''): IBrowserSession;

implementation

var
  GSessionManager: TObjectList<IBrowserSession> = nil;

{ TBrowseSessionImpl }

constructor TBrowseSessionImpl.Create;
begin
  inherited Create;
  FCDPSession := CurrentBrowserAdapter;
  FIsManagedBrowser := True;
  FConnected := False;
  FCurrentTabID := 0;
end;

constructor TBrowseSessionImpl.CreateFromExistingSession(Session: ICDPSession);
begin
  inherited Create;
  FCDPSession := Session;
  FIsManagedBrowser := False;
  FConnected := Session.IsConnected;
end;

destructor TBrowseSessionImpl.Destroy;
begin
  if FConnected then
    Close;
    
  inherited Destroy;
end;

function TBrowseSessionImpl.EnsureConnected: Boolean;
begin
  Result := True;
  
  if not FConnected then
  begin
    // Try to connect to localhost debugger port
    Result := FCDPSession.ConnectToBrowser('http://localhost:9222');
    FConnected := Result;
  end;
end;

function TBrowseSessionImpl.ParseJSONObject(const JSONStr: string): TJSONObject;
begin
  try
    Result := TJSONObject.ParseJSONValue(JSONStr) as TJSONObject;
  except
    on E: Exception do
      raise EException.CreateFmt('Invalid JSON: %s', [E.Message]);
  end;
end;

function TBrowseSessionImpl.ExecuteCdpCommand(Method: string; 
  const Params: array of const): TJSONValue;
var
  CmdParams: TStringList;
begin
  Result := nil;
  
  EnsureConnected;
  
  CmdParams := TStringList.Create;
  try
    // Build JSON parameters
    // TODO: Serialize params array into CmdParams
    
    // Send command via CDP
    // Result := FCDPSession.SendCommand(Method, CmdParams);
    
  finally
    CmdParams.Free;
  end;
end;

procedure TBrowseSessionImpl.Open(URL: string);
begin
  EnsureConnected;
  NavigateTo(URL);
end;

procedure TBrowseSessionImpl.Close;
begin
  FCDPSession.Disconnect;
  FConnected := False;
end;

function TBrowseSessionImpl.IsOpen: Boolean;
begin
  Result := FConnected and FCDPSession.IsConnected;
end;

function TBrowseSessionImpl.NavigateTo(URL: string; 
  Options: TNavigationOptions): Boolean;
begin
  Result := FCDPSession.NavigateTo(URL);
  
  if Result then
  begin
    FCurrentURL := URL;
    
    // Wait for page load by default
    if Options.WaitForLoad then
    begin
      FCDPSession.WaitForLoadState(Options.TimeoutMs);
    end;
  end;
end;

procedure TBrowseSessionImpl.GoBack;
begin
  // Use Page.goBack command
  ExecuteCdpCommand('Page.goBack', []);
end;

procedure TBrowseSessionImpl.GoForward;
begin
  ExecuteCdpCommand('Page.goForward', []);
end;

procedure TBrowseSessionImpl.Reload;
begin
  ExecuteCdpCommand('Page.reload', []);
end;

function TBrowseSessionImpl.GetURL: string;
begin
  Result := FCDPSession.GetURL;
end;

function TBrowseSessionImpl.GetCurrentTabID: Integer;
begin
  Result := FCurrentTabID;
end;

function TBrowseSessionImpl.CreateNewTab: Integer;
begin
  // Query browser endpoint for tab creation
  var NewTabURL := 'http://localhost:9222/new?title=New+Tab';
  // HTTP GET request to create tab
  // Result := TabID from response
  Result := 0; // Placeholder
end;

procedure TBrowseSessionImpl.CloseTab(TabID: Integer);
begin
  // Browser.closeTabs endpoint
end;

procedure TBrowseSessionImpl.SwitchTab(TabID: Integer);
begin
  FCurrentTabID := TabID;
end;

function TBrowseSessionImpl.FindElementByCSS(Selector: string): TWebWebElement;
begin
  Result := TWebWebElement.FindByCSS(Self, Selector);
end;

function TBrowseSessionImpl.FindElementByXPath(XPath: string): TWebWebElement;
begin
  Result := TWebWebElement.FindByXPath(Self, XPath);
end;

function TBrowseSessionImpl.FindElements(Selector: string): TArray<TWebWebElement>;
var
  FoundCount: Integer;
begin
  // Execute document.querySelectorAll
  // Return array of web elements
  SetLength(Result, 0);
end;

procedure TBrowseSessionImpl.Click(Selector: string);
var
  Element: TWebWebElement;
begin
  Element := FindElementByCSS(Selector);
  Element.Click;
end;

procedure TBrowseSessionImpl.TypeText(Selector: string; Text: string);
var
  Element: TWebWebElement;
begin
  Element := FindElementByCSS(Selector);
  Element.TypeText(Text);
end;

function TBrowseSessionImpl.GetAttribute(Selector: string; AttrName: string): string;
var
  Element: TWebWebElement;
begin
  Element := FindElementByCSS(Selector);
  Result := Element.GetAttribute(AttrName);
end;

function TBrowseSessionImpl.GetHTMLContent: string;
begin
  Result := ExecuteJS('return document.documentElement.outerHTML;');
end;

function TBrowseSessionImpl.GetInnerText: string;
begin
  Result := ExecuteJS('return document.body.innerText;');
end;

function TBrowseSessionImpl.TakeScreenshot: TMemoryStream;
begin
  Result := FCDPSession.CaptureScreenshot('png', 80);
end;

function TBrowseSessionImpl.GetCookies: TJSONArray;
begin
  Result := nil; // TODO: Query cookies via CDP
end;

procedure TBrowseSessionImpl.AddCookie(CookieJSON: TStringList);
begin
  // Document.addCookie command
end;

procedure TBrowseSessionImpl.ClearCookies;
begin
  Clear all cookies via CDP
end;

// Global initialization
procedure InitializeBrowserSessionManager;
begin
  if not Assigned(GSessionManager) then
    GSessionManager := TObjectList<IBrowserSession>.Create(True);
end;

function CreateBrowserSession(URL: string): IBrowserSession;
begin
  InitializeBrowserSessionManager;
  
  Result := TBrowseSessionImpl.Create;
  GSessionManager.Add(Result);
  
  if URL <> '' then
    Result.Open(URL);
end;

initialization
finalization
  GSessionManager := nil;

end.
