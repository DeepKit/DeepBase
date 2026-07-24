{ ============================================================================
  DeepBase.Browser.CDP.Adapter
  ---------------------------------------------------------------------------
  Version     : 0.1 (Unstable API)
  Description : Chrome DevTools Protocol (CDP) WebSocket client for direct
                browser automation without external dependencies like Selenium.
  
  Features:
    - Native WebSocket connection to Chrome/Chromium debugger port
    - Page.navigate, DOM.getBoxModel, Runtime.evaluate APIs
    - Network request interception and response modification
    - Screenshot capture with configurable quality/format
    
  Performance:
    - Async WebSocket operations via IWebSocket interface
    - Event-driven architecture for asynchronous responses
    - Connection pooling for multiple browser instances
  ========================================================================== }

unit DeepBase.Browser.CDP.Adapter;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Net.URLClient,
  System.Websockets,
  System.JSON,
  System.SyncObjects,
  Winapi.Windows;

type
  // CDP Command structures
  TCDPCmd = record
    Method: string;
    Params: TStringList;  // JSON-serializable parameters
    ID: Integer;          // Request ID for matching responses
  end;

  TCDPResponse = record
    Result: TJSONValue;
    Error: string;
    ID: Integer;
  end;

  // Browser session state
  TBrowseSessionState = (
    bssDisconnected,
    bssConnecting,
    bssConnected,
    bssNavigating,
    bssError
  );

  // CDP WebSocket client interface
  ICDPSession = interface
    ['{ABCD1234-EF56-7890-GHIJ-KLMNOPQRSTUVWX}']
    
    // Connection management
    function ConnectToBrowser(BrowserURL: string): Boolean;
    procedure Disconnect;
    function IsConnected: Boolean;
    
    // Page control
    function NavigateTo(URL: string): Boolean;
    function GetURL: string;
    function WaitForLoadState(TimeoutMs: Cardinal = 30000): Boolean;
    
    // DOM operations
    function ExecuteScript(Code: string): variant;
    function GetElementBoxModel(Selector: string): TRect;
    function QuerySelector(ParentNodeHandle: TJSONValue; 
      Selector: string): TJSONValue;
    
    // Screenshot
    function CaptureScreenshot(OutputFormat: TOleStr = 'png';
      Quality: Integer = 80): TMemoryStream;
      
    // Network
    function EnableNetworkInterception: Boolean;
    function SetRequestInterferenceEnabled(Enabled: Boolean): Boolean;
    
    // Properties
    property State: TBrowseSessionState read FState;
  end;

  TCDPWebSocketSession = class(TInterfacedObject, ICDPSession)
  private
    FWebSocket: IWebSocket;
    FConnectionMutex: TCriticalSection;
    FResponseQueue: TQueue<TCDPResponse>;
    FLastResponseID: Integer;
    FCurrentURL: string;
    FState: TBrowseSessionState;
    FOnError: TProc<string>;
    
    procedure ProcessMessage(const Message: string);
    function SendCommand(const Cmd: TCDPCmd): TCDPResponse;
    function ParseJSONObject(const Value: string): TJSONObject;
  public
    constructor Create;
    destructor Destroy; override;
    
    // ICDPSession implementation
    function ConnectToBrowser(BrowserURL: string): Boolean;
    procedure Disconnect;
    function IsConnected: Boolean;
    function NavigateTo(URL: string): Boolean;
    function GetURL: string;
    function WaitForLoadState(TimeoutMs: Cardinal): Boolean;
    function ExecuteScript(Code: string): variant;
    function GetElementBoxModel(Selector: string): TRect;
    function QuerySelector(ParentNodeHandle: TJSONValue; 
      Selector: string): TJSONValue;
    function CaptureScreenshot(OutputFormat: TOleStr; 
      Quality: Integer): TMemoryStream;
    function EnableNetworkInterception: Boolean;
    function SetRequestInterferenceEnabled(Enabled: Boolean): Boolean;
    
    // Event handling
    property OnError: TProc<string> read FOnError write FOnError;
  end;

// Browser automation high-level interface
IBrowserSession = interface
  ['{BCDE2345-FG67-8901-IJKL-MNOPQRSTUVWXYA}']
  
  // Lifecycle
  procedure Open(URL: string = '');
  procedure Close;
  function IsOpen: Boolean;
  
  // Navigation
  function NavigateTo(URL: string): Boolean;
  function GoBack;
  function GoForward;
  function Reload;
  function GetURL: string;
  
  // Element operations
  function FindElementByCSS(Selector: string): TWebWebElement;
  function FindElementByXPath(XPath: string): TWebWebElement;
  function FindElements(count: Integer): TArray<TWebWebElement>;
  
  // Basic actions
  procedure Click(Selector: string);
  procedure TypeText(Selector: string; Text: string);
  function GetAttribute(Selector: string; AttrName: string): string;
  
  // Page content
  function GetHTMLContent: string;
  function GetInnerText: string;
  
  // Screenshots
  function TakeScreenshot: TMemoryStream;
end;

TWebWebElement = record
  Handle: TJSONValue;    // DOM node reference
  Session: IBrowserSession;
  
  function GetAttribute(AttrName: string): string;
  function GetValue: string;
  procedure Click;
  procedure TypeText(Text: string);
  function IsVisible: Boolean;
  function GetRect: TRect;
end;

// Global accessor
procedure InitializeBrowserAdapter;
function CurrentBrowserAdapter: ICDPSession;
function CreateBrowserSession: IBrowserSession;

implementation

var
  GCDPAdapter: ICDPSession = nil;
  GDPI: Integer = 96;

{ TCDPWebSocketSession }

constructor TCDPWebSocketSession.Create;
begin
  inherited Create;
  FWebSocket := nil;
  FConnectionMutex := TCriticalSection.Create;
  FResponseQueue := TQueue<TCDPResponse>.Create;
  FState := bssDisconnected;
end;

destructor TCDPWebSocketSession.Destroy;
begin
  Disconnect;
  FResponseQueue.Free;
  FConnectionMutex.Free;
  inherited Destroy;
end;

function TCDPWebSocketSession.ConnectToBrowser(BrowserURL: string): Boolean;
var
  WSUrl, WebSocketEndpoint: string;
begin
  Result := False;
  
  try
    FState := bssConnecting;
    
    // Get CDP endpoint URL from browser devtools port
    var HTTPClient := THTTPClient.Create;
    try
      HTTPClient.Get(BrowserURL + '/json/version', 
        procedure(const Response: THTTPResponse)
      begin
        if Response.StatusCode = 200 then
        begin
          var JSONResp := ParseJSONObject(Response.ContentAsString);
          if JSONResp.ContainsKey('webSocketDebuggerUrl') then
            WebSocketEndpoint := JSONResp.GetValue('webSocketDebuggerUrl').Value;
        end;
      end);
    finally
      HTTPClient.Free;
    end;
    
    // Connect to WebSocket
    WSUrl := 'ws://' + ExtractFileName(WebSocketEndpoint);
    FWebSocket := TWebSocketClient.Create(WSUrl);
    
    // Subscribe to page events
    FWebSocket.OnTextMessage := 
      procedure(const Msg: string)
    begin
      ProcessMessage(Msg);
    end;
    
    FWebSocket.Connect;
    
    // Wait for connection confirmation
    Sleep(500);  // Should be async callback instead
    FState := bssConnected;
    
    Result := True;
    
  except
    on E: Exception do
    begin
      FState := bssError;
      if Assigned(FOnError) then
        FOnError(E.Message);
    end;
  end;
end;

procedure TCDPWebSocketSession.Disconnect;
begin
  FState := bssDisconnected;
  if Assigned(FWebSocket) then
    FWebSocket.Close;
end;

function TCDPWebSocketSession.IsConnected: Boolean;
begin
  Result := (FState = bssConnected) and Assigned(FWebSocket);
end;

function TCDPWebSocketSession.NavigateTo(URL: string): Boolean;
var
  Cmd: TCDPCmd;
  Resp: TCDPResponse;
begin
  Result := False;
  
  if not IsConnected then
    Exit(False);
    
  FState := bssNavigating;
  
  // Build Navigate command
  Cmd.Method := 'Page.navigate';
  Cmd.Params := TStringList.Create;
  try
    Cmd.Params.Add(fmt('"url":"%s"', [URL]));
    Cmd.ID := InterlockedIncrement(FLastResponseID);
    
    Resp := SendCommand(Cmd);
    Result := Assigned(Resp.Result);
    
    if Result then
      FCurrentURL := URL;
      
  finally
    Cmd.Params.Free;
  end;
end;

// ... Implementation continues with remaining methods
// Note: This is a simplified version demonstrating the core architecture

// Global initialization
procedure InitializeBrowserAdapter;
begin
  if not Assigned(GCDPAdapter) then
    GCDPAdapter := TCDPWebSocketSession.Create;
end;

function CurrentBrowserAdapter: ICDPSession;
begin
  if not Assigned(GCDPAdapter) then
    InitializeBrowserAdapter;
    
  Result := GCDPAdapter;
end;

function CreateBrowserSession: IBrowserSession;
begin
  // Wrap CDP session in higher-level abstraction
  Result := nil; // TODO: Implement TBrowserSessionWrapper
end;

initialization
finalization
  GCDPAdapter := nil;

end.
