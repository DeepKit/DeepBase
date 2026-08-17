unit DeepBase.Browser.Session;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Variants,
  System.Generics.Collections,
  Winapi.Windows,
  DeepBase.Browser.CDP.Adapter,
  DeepBase.Browser.WebElement;

type
  TNavigationOptions = record
    WaitForLoad: Boolean;         // Wait for load event (default True)
    TimeoutMs: Cardinal;          // Maximum wait time (default 30s)
  end;

  IBrowserSession = interface
    ['{CDEF3456-0123-4567-89AB-CDEF01234567}']
    
    // Lifecycle management
    procedure Open(URL: string = '');
    procedure Close;
    function IsOpen: Boolean;
    
    // Navigation
    function NavigateTo(URL: string; Options: TNavigationOptions): Boolean;
    procedure GoBack;
    procedure GoForward;
    procedure Reload;
    function GetURL: string;
    
    // Tab management
    function GetCurrentTabID: Integer;
    function CreateNewTab: Integer;
    procedure CloseTab(TabID: Integer);
    procedure SwitchTab(TabID: Integer);
    
    // Element operations
    function FindElementByCSS(Selector: string): TWebWebElement;
    function FindElementByXPath(XPath: string): TWebWebElement;
    function FindElements(Selector: string): TArray<TWebWebElement>;
    
    // Basic actions
    procedure Click(Selector: string);
    procedure TypeText(Selector: string; Text: string);
    function GetAttribute(Selector: string; AttrName: string): string;
    
    // Page content
    function GetHTMLContent: string;
    function GetInnerText: string;
    
    // Screenshots
    function TakeScreenshot: TMemoryStream;
    
    // Cookies & storage
    function GetCookies: TJSONArray;
    procedure AddCookie(CookieJSON: TStringList);
    procedure ClearCookies;
  end;

  TBrowseSessionImpl = class(TInterfacedObject, IBrowserSession)
  private
    FCDPSession: ICDPSession;
    FIsManagedBrowser: Boolean;
    FCurrentTabID: Integer;
    FConnected: Boolean;
    
    // Helper methods
    function EnsureConnected: Boolean;
    function ParseJSONObject(const JSONStr: string): TJSONObject;
    function ExecuteCdpCommand(Method: string; const Params: array of const): TJSONValue;
  public
    constructor Create; overload;
    constructor CreateFromExistingSession(Session: ICDPSession); overload;
    destructor Destroy; override;
    
    // IBrowserSession implementation
    procedure Open(URL: string = '');
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
  GSessionManager: TList<IBrowserSession> = nil;

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
      raise Exception.CreateFmt('Invalid JSON: %s', [E.Message]);
  end;
end;

function TBrowseSessionImpl.ExecuteCdpCommand(Method: string; 
  const Params: array of const): TJSONValue;
begin
  Result := nil;
  EnsureConnected;
end;

procedure TBrowseSessionImpl.Open(URL: string);
var
  Opt: TNavigationOptions;
begin
  EnsureConnected;
  Opt.WaitForLoad := True;
  Opt.TimeoutMs := 30000;
  NavigateTo(URL, Opt);
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
  if Result and Options.WaitForLoad then
    FCDPSession.WaitForLoadState(Options.TimeoutMs);
end;

procedure TBrowseSessionImpl.GoBack;
begin
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
  Result := 0;
end;

procedure TBrowseSessionImpl.CloseTab(TabID: Integer);
begin
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
begin
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
  Result := '';
end;

function TBrowseSessionImpl.GetInnerText: string;
begin
  Result := '';
end;

function TBrowseSessionImpl.TakeScreenshot: TMemoryStream;
begin
  Result := FCDPSession.CaptureScreenshot('png', 80);
end;

function TBrowseSessionImpl.GetCookies: TJSONArray;
begin
  Result := nil;
end;

procedure TBrowseSessionImpl.AddCookie(CookieJSON: TStringList);
begin
end;

procedure TBrowseSessionImpl.ClearCookies;
begin
end;

// Global initialization
procedure InitializeBrowserSessionManager;
begin
  if not Assigned(GSessionManager) then
    GSessionManager := TList<IBrowserSession>.Create;
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
  if Assigned(GSessionManager) then
    FreeAndNil(GSessionManager);

end.
