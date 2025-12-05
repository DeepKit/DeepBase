unit UniBase.Net;

(*******************************************************************************
  UniBase Network Utilities
  A comprehensive network module with:
  - HTTP client wrapper
  - WebSocket support
  - DNS queries
  - Network connectivity detection
  - IP utilities (parsing, validation, subnet calculations)
  
  Author: UniBase Team
  Created: 2025-11-29
*******************************************************************************)

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  System.Generics.Defaults, System.TypInfo,
  System.Net.HttpClient, System.Net.URLClient, System.Net.HttpClientComponent,
  System.NetEncoding, System.JSON, System.RegularExpressions,
  IdDNSResolver, IdGlobal, IdStack, IdTCPClient, IdHTTP, IdSSLOpenSSL,
  IdUDPClient, IdICMPClient;

type
  ENetException = class(Exception);

  /// <summary>HTTP methods</summary>
  THttpMethod = (hmGet, hmPost, hmPut, hmDelete, hmPatch, hmHead, hmOptions);

  /// <summary>HTTP response</summary>
  THttpResponse = record
    StatusCode: Integer;
    StatusText: string;
    Headers: TDictionary<string, string>;
    Body: string;
    BodyBytes: TBytes;
    ContentType: string;
    ContentLength: Int64;
    Elapsed: Integer;
    
    function IsSuccess: Boolean;
    function IsRedirect: Boolean;
    function IsClientError: Boolean;
    function IsServerError: Boolean;
    function AsJSON: TJSONValue;
    procedure Free;
  end;

  /// <summary>HTTP request builder</summary>
  THttpRequest = class
  private
    FUrl: string;
    FMethod: THttpMethod;
    FHeaders: TDictionary<string, string>;
    FQueryParams: TDictionary<string, string>;
    FFormParams: TDictionary<string, string>;
    FBody: string;
    FBodyBytes: TBytes;
    FContentType: string;
    FTimeout: Integer;
    FFollowRedirects: Boolean;
    FMaxRedirects: Integer;
    FBasicAuth: TPair<string, string>;
    FBearerToken: string;
  public
    constructor Create(const AUrl: string);
    destructor Destroy; override;
    
    function Method(AMethod: THttpMethod): THttpRequest;
    function Header(const AName, AValue: string): THttpRequest;
    function Headers(const AHeaders: array of TPair<string, string>): THttpRequest;
    function QueryParam(const AName, AValue: string): THttpRequest;
    function FormParam(const AName, AValue: string): THttpRequest;
    function Body(const ABody: string): THttpRequest; overload;
    function Body(const ABodyBytes: TBytes): THttpRequest; overload;
    function JsonBody(AJson: TJSONValue): THttpRequest;
    function ContentType(const AContentType: string): THttpRequest;
    function Timeout(ATimeoutMs: Integer): THttpRequest;
    function FollowRedirects(AFollow: Boolean): THttpRequest;
    function MaxRedirects(AMax: Integer): THttpRequest;
    function BasicAuth(const AUsername, APassword: string): THttpRequest;
    function BearerToken(const AToken: string): THttpRequest;
    
    function Execute: THttpResponse;
    
    function Get: THttpResponse;
    function Post: THttpResponse;
    function Put: THttpResponse;
    function Delete: THttpResponse;
    function Patch: THttpResponse;
  end;

  /// <summary>Simple HTTP client</summary>
  THttpClient_ = class
  private
    FBaseUrl: string;
    FDefaultHeaders: TDictionary<string, string>;
    FTimeout: Integer;
    FLock: TCriticalSection;
  public
    constructor Create(const ABaseUrl: string = '');
    destructor Destroy; override;
    
    procedure SetDefaultHeader(const AName, AValue: string);
    procedure SetTimeout(ATimeoutMs: Integer);
    
    function Request(const AUrl: string): THttpRequest;
    
    function Get(const AUrl: string): THttpResponse;
    function Post(const AUrl: string; const ABody: string = ''): THttpResponse;
    function Put(const AUrl: string; const ABody: string = ''): THttpResponse;
    function Delete(const AUrl: string): THttpResponse;
    function Patch(const AUrl: string; const ABody: string = ''): THttpResponse;
    
    function GetJSON(const AUrl: string): TJSONValue;
    function PostJSON(const AUrl: string; AJson: TJSONValue): TJSONValue;
    
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property DefaultTimeout: Integer read FTimeout write FTimeout;
  end;

  /// <summary>WebSocket state</summary>
  TWebSocketState = (wssConnecting, wssOpen, wssClosing, wssClosed);

  /// <summary>WebSocket message type</summary>
  TWebSocketMessageType = (wsmText, wsmBinary, wsmPing, wsmPong, wsmClose);

  /// <summary>WebSocket event handlers</summary>
  TWebSocketOnOpen = procedure(Sender: TObject) of object;
  TWebSocketOnMessage = procedure(Sender: TObject; const AMessage: string; AType: TWebSocketMessageType) of object;
  TWebSocketOnClose = procedure(Sender: TObject; ACode: Integer; const AReason: string) of object;
  TWebSocketOnError = procedure(Sender: TObject; const AError: string) of object;

  /// <summary>WebSocket client</summary>
  TWebSocketClient = class
  private
    FUrl: string;
    FState: TWebSocketState;
    FOnOpen: TWebSocketOnOpen;
    FOnMessage: TWebSocketOnMessage;
    FOnClose: TWebSocketOnClose;
    FOnError: TWebSocketOnError;
    FLock: TCriticalSection;
    FConnectTimeout: Integer;
    FPingInterval: Integer;
  public
    constructor Create(const AUrl: string);
    destructor Destroy; override;
    
    procedure Connect;
    procedure Disconnect(ACode: Integer = 1000; const AReason: string = '');
    procedure Send(const AMessage: string); overload;
    procedure Send(const AData: TBytes); overload;
    procedure Ping;
    
    property State: TWebSocketState read FState;
    property Url: string read FUrl;
    property ConnectTimeout: Integer read FConnectTimeout write FConnectTimeout;
    property PingInterval: Integer read FPingInterval write FPingInterval;
    
    property OnOpen: TWebSocketOnOpen read FOnOpen write FOnOpen;
    property OnMessage: TWebSocketOnMessage read FOnMessage write FOnMessage;
    property OnClose: TWebSocketOnClose read FOnClose write FOnClose;
    property OnError: TWebSocketOnError read FOnError write FOnError;
  end;

  /// <summary>DNS record type</summary>
  TDnsRecordType = (drtA, drtAAAA, drtCNAME, drtMX, drtNS, drtPTR, drtSOA, drtSRV, drtTXT);

  /// <summary>DNS record</summary>
  TDnsRecord = record
    RecordType: TDnsRecordType;
    Name: string;
    Value: string;
    TTL: Integer;
    Priority: Integer;
    
    function ToString: string;
  end;

  /// <summary>DNS resolver</summary>
  TDnsResolver_ = class
  private
    FDnsServer: string;
    FTimeout: Integer;
    FResolver: TIdDNSResolver;
    FLock: TCriticalSection;
  public
    constructor Create(const ADnsServer: string = '');
    destructor Destroy; override;
    
    function Resolve(const AHostname: string): string;
    function ResolveAll(const AHostname: string): TArray<string>;
    function ResolveIPv6(const AHostname: string): string;
    function ReverseLookup(const AIPAddress: string): string;
    
    function QueryRecords(const AHostname: string; ARecordType: TDnsRecordType): TArray<TDnsRecord>;
    function QueryMX(const ADomain: string): TArray<TDnsRecord>;
    function QueryNS(const ADomain: string): TArray<TDnsRecord>;
    function QueryTXT(const ADomain: string): TArray<string>;
    
    property DnsServer: string read FDnsServer write FDnsServer;
    property Timeout: Integer read FTimeout write FTimeout;
  end;

  /// <summary>IPv4 address</summary>
  TIPv4Address = record
    Octets: array[0..3] of Byte;
    
    constructor Create(const AAddress: string); overload;
    constructor Create(A, B, C, D: Byte); overload;
    constructor Create(AValue: Cardinal); overload;
    
    function ToString: string;
    function ToInteger: Cardinal;
    function IsPrivate: Boolean;
    function IsLoopback: Boolean;
    function IsMulticast: Boolean;
    function IsBroadcast: Boolean;
    function IsValid: Boolean;
    
    class function Parse(const AAddress: string): TIPv4Address; static;
    class function TryParse(const AAddress: string; out AResult: TIPv4Address): Boolean; static;
    
    class operator Equal(const A, B: TIPv4Address): Boolean;
    class operator NotEqual(const A, B: TIPv4Address): Boolean;
    class operator BitwiseAnd(const A, B: TIPv4Address): TIPv4Address;
    class operator BitwiseOr(const A, B: TIPv4Address): TIPv4Address;
    class operator BitwiseXor(const A, B: TIPv4Address): TIPv4Address;
    class operator LogicalNot(const A: TIPv4Address): TIPv4Address;
  end;

  /// <summary>IPv4 subnet</summary>
  TIPv4Subnet = record
    Network: TIPv4Address;
    Mask: TIPv4Address;
    PrefixLength: Integer;
    
    constructor Create(const ANetwork: TIPv4Address; APrefixLength: Integer); overload;
    constructor Create(const ACIDR: string); overload;
    
    function Contains(const AAddress: TIPv4Address): Boolean;
    function GetBroadcast: TIPv4Address;
    function GetFirstHost: TIPv4Address;
    function GetLastHost: TIPv4Address;
    function GetHostCount: Cardinal;
    function ToString: string;
    function ToCIDR: string;
    
    class function Parse(const ACIDR: string): TIPv4Subnet; static;
    class function TryParse(const ACIDR: string; out AResult: TIPv4Subnet): Boolean; static;
    class function PrefixToMask(APrefixLength: Integer): TIPv4Address; static;
    class function MaskToPrefix(const AMask: TIPv4Address): Integer; static;
  end;

  /// <summary>Network interface info</summary>
  TNetworkInterface = record
    Name: string;
    Description: string;
    MacAddress: string;
    IPv4Address: string;
    IPv4Subnet: string;
    IPv4Gateway: string;
    IPv6Address: string;
    IsUp: Boolean;
    IsLoopback: Boolean;
    Speed: Int64;
    
    function ToString: string;
  end;

  /// <summary>Ping result</summary>
  TPingResult = record
    Success: Boolean;
    Address: string;
    ReplyFrom: string;
    RoundTripTime: Integer;
    TTL: Integer;
    ErrorMessage: string;
    
    function ToString: string;
  end;

  /// <summary>Port scan result</summary>
  TPortScanResult = record
    Port: Integer;
    IsOpen: Boolean;
    Service: string;
    Banner: string;
  end;

  /// <summary>Network utilities</summary>
  TNetworkUtils = class
  public
    /// <summary>Connectivity check</summary>
    class function IsInternetAvailable: Boolean; static;
    class function CanReach(const AHost: string; APort: Integer = 80; ATimeout: Integer = 3000): Boolean; static;
    
    /// <summary>Ping</summary>
    class function Ping(const AHost: string; ATimeout: Integer = 3000): TPingResult; static;
    class function PingMultiple(const AHost: string; ACount: Integer = 4; ATimeout: Integer = 3000): TArray<TPingResult>; static;
    
    /// <summary>Port scanning</summary>
    class function IsPortOpen(const AHost: string; APort: Integer; ATimeout: Integer = 1000): Boolean; static;
    class function ScanPorts(const AHost: string; APorts: array of Integer; ATimeout: Integer = 1000): TArray<TPortScanResult>; static;
    class function ScanPortRange(const AHost: string; AStartPort, AEndPort: Integer; ATimeout: Integer = 500): TArray<TPortScanResult>; static;
    
    /// <summary>Local network info</summary>
    class function GetLocalIPAddress: string; static;
    class function GetLocalIPAddresses: TArray<string>; static;
    class function GetHostName_: string; static;
    class function GetNetworkInterfaces: TArray<TNetworkInterface>; static;
    class function GetMacAddress: string; static;
    class function GetDefaultGateway: string; static;
    
    /// <summary>URL utilities</summary>
    class function UrlEncode(const AValue: string): string; static;
    class function UrlDecode(const AValue: string): string; static;
    class function BuildUrl(const ABase: string; const AParams: array of TPair<string, string>): string; static;
    class function ParseUrl(const AUrl: string; out AScheme, AHost, APath: string; out APort: Integer): Boolean; static;
    class function JoinUrl(const ABase, ARelative: string): string; static;
    
    /// <summary>IP validation</summary>
    class function IsValidIPv4(const AAddress: string): Boolean; static;
    class function IsValidIPv6(const AAddress: string): Boolean; static;
    class function IsValidHostname(const AHostname: string): Boolean; static;
    class function IsValidPort(APort: Integer): Boolean; static;
    
    /// <summary>Well-known services</summary>
    class function GetServiceName(APort: Integer): string; static;
    class function GetServicePort(const AServiceName: string): Integer; static;
  end;

  /// <summary>IP address utilities</summary>
  TIPUtils = class
  public
    class function IPv4ToInteger(const AAddress: string): Cardinal; static;
    class function IntegerToIPv4(AValue: Cardinal): string; static;
    
    class function IsInSubnet(const AAddress, ANetwork: string; APrefixLength: Integer): Boolean; static;
    class function GetSubnetBroadcast(const ANetwork: string; APrefixLength: Integer): string; static;
    class function GetSubnetHostCount(APrefixLength: Integer): Cardinal; static;
    
    class function IsPrivateIP(const AAddress: string): Boolean; static;
    class function IsLoopbackIP(const AAddress: string): Boolean; static;
    class function IsMulticastIP(const AAddress: string): Boolean; static;
    class function IsReservedIP(const AAddress: string): Boolean; static;
    
    class function CompareIPv4(const A, B: string): Integer; static;
    class function SortIPv4Addresses(const AAddresses: TArray<string>): TArray<string>; static;
  end;

  /// <summary>Static shortcut</summary>
  TNet = TNetworkUtils;

  /// <summary>Global HTTP client singleton</summary>
function Http: THttpClient_;

implementation

var
  GHttpClient: THttpClient_;
  GHttpLock: TCriticalSection;

function Http: THttpClient_;
begin
  if not Assigned(GHttpClient) then
  begin
    GHttpLock.Enter;
    try
      if not Assigned(GHttpClient) then
        GHttpClient := THttpClient_.Create;
    finally
      GHttpLock.Leave;
    end;
  end;
  Result := GHttpClient;
end;

{ THttpResponse }

function THttpResponse.IsSuccess: Boolean;
begin
  Result := (StatusCode >= 200) and (StatusCode < 300);
end;

function THttpResponse.IsRedirect: Boolean;
begin
  Result := (StatusCode >= 300) and (StatusCode < 400);
end;

function THttpResponse.IsClientError: Boolean;
begin
  Result := (StatusCode >= 400) and (StatusCode < 500);
end;

function THttpResponse.IsServerError: Boolean;
begin
  Result := (StatusCode >= 500) and (StatusCode < 600);
end;

function THttpResponse.AsJSON: TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(Body);
end;

procedure THttpResponse.Free;
begin
  if Assigned(Headers) then
    FreeAndNil(Headers);
end;

{ THttpRequest }

constructor THttpRequest.Create(const AUrl: string);
begin
  inherited Create;
  FUrl := AUrl;
  FMethod := hmGet;
  FHeaders := TDictionary<string, string>.Create;
  FQueryParams := TDictionary<string, string>.Create;
  FFormParams := TDictionary<string, string>.Create;
  FTimeout := 30000;
  FFollowRedirects := True;
  FMaxRedirects := 5;
end;

destructor THttpRequest.Destroy;
begin
  FHeaders.Free;
  FQueryParams.Free;
  FFormParams.Free;
  inherited;
end;

function THttpRequest.Method(AMethod: THttpMethod): THttpRequest;
begin
  FMethod := AMethod;
  Result := Self;
end;

function THttpRequest.Header(const AName, AValue: string): THttpRequest;
begin
  FHeaders.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function THttpRequest.Headers(const AHeaders: array of TPair<string, string>): THttpRequest;
var
  LPair: TPair<string, string>;
begin
  for LPair in AHeaders do
    FHeaders.AddOrSetValue(LPair.Key, LPair.Value);
  Result := Self;
end;

function THttpRequest.QueryParam(const AName, AValue: string): THttpRequest;
begin
  FQueryParams.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function THttpRequest.FormParam(const AName, AValue: string): THttpRequest;
begin
  FFormParams.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function THttpRequest.Body(const ABody: string): THttpRequest;
begin
  FBody := ABody;
  Result := Self;
end;

function THttpRequest.Body(const ABodyBytes: TBytes): THttpRequest;
begin
  FBodyBytes := ABodyBytes;
  Result := Self;
end;

function THttpRequest.JsonBody(AJson: TJSONValue): THttpRequest;
begin
  FBody := AJson.ToJSON;
  FContentType := 'application/json';
  Result := Self;
end;

function THttpRequest.ContentType(const AContentType: string): THttpRequest;
begin
  FContentType := AContentType;
  Result := Self;
end;

function THttpRequest.Timeout(ATimeoutMs: Integer): THttpRequest;
begin
  FTimeout := ATimeoutMs;
  Result := Self;
end;

function THttpRequest.FollowRedirects(AFollow: Boolean): THttpRequest;
begin
  FFollowRedirects := AFollow;
  Result := Self;
end;

function THttpRequest.MaxRedirects(AMax: Integer): THttpRequest;
begin
  FMaxRedirects := AMax;
  Result := Self;
end;

function THttpRequest.BasicAuth(const AUsername, APassword: string): THttpRequest;
begin
  FBasicAuth := TPair<string, string>.Create(AUsername, APassword);
  Result := Self;
end;

function THttpRequest.BearerToken(const AToken: string): THttpRequest;
begin
  FBearerToken := AToken;
  Result := Self;
end;

function THttpRequest.Execute: THttpResponse;
var
  LClient: THTTPClient;
  LRequest: IHTTPRequest;
  LResponse: IHTTPResponse;
  LUrl: string;
  LPair: TPair<string, string>;
  LQueryStr: string;
  LStartTime: TDateTime;
  LStream: TStringStream;
  LFormData: TStringList;
begin
  Result.Headers := TDictionary<string, string>.Create;
  
  // Build URL with query params
  LUrl := FUrl;
  if FQueryParams.Count > 0 then
  begin
    LQueryStr := '';
    for LPair in FQueryParams do
    begin
      if LQueryStr <> '' then
        LQueryStr := LQueryStr + '&';
      LQueryStr := LQueryStr + TNetEncoding.URL.Encode(LPair.Key) + '=' + TNetEncoding.URL.Encode(LPair.Value);
    end;
    if Pos('?', LUrl) > 0 then
      LUrl := LUrl + '&' + LQueryStr
    else
      LUrl := LUrl + '?' + LQueryStr;
  end;
  
  LClient := THTTPClient.Create;
  try
    LClient.ConnectionTimeout := FTimeout;
    LClient.ResponseTimeout := FTimeout;
    LClient.HandleRedirects := FFollowRedirects;
    LClient.MaxRedirects := FMaxRedirects;
    
    // Set headers
    for LPair in FHeaders do
      LClient.CustomHeaders[LPair.Key] := LPair.Value;
      
    if FContentType <> '' then
      LClient.ContentType := FContentType;
      
    // Auth
    if FBasicAuth.Key <> '' then
      LClient.CustomHeaders['Authorization'] := 'Basic ' + 
        TNetEncoding.Base64.Encode(FBasicAuth.Key + ':' + FBasicAuth.Value);
        
    if FBearerToken <> '' then
      LClient.CustomHeaders['Authorization'] := 'Bearer ' + FBearerToken;
    
    LStartTime := Now;
    
    try
      case FMethod of
        hmGet:
          LResponse := LClient.Get(LUrl);
        hmPost:
          begin
            if FFormParams.Count > 0 then
            begin
              LFormData := TStringList.Create;
              try
                for LPair in FFormParams do
                  LFormData.Add(LPair.Key + '=' + LPair.Value);
                LResponse := LClient.Post(LUrl, LFormData);
              finally
                LFormData.Free;
              end;
            end
            else if Length(FBodyBytes) > 0 then
            begin
              LStream := TStringStream.Create(FBodyBytes);
              try
                LResponse := LClient.Post(LUrl, LStream);
              finally
                LStream.Free;
              end;
            end
            else
            begin
              LStream := TStringStream.Create(FBody, TEncoding.UTF8);
              try
                LResponse := LClient.Post(LUrl, LStream);
              finally
                LStream.Free;
              end;
            end;
          end;
        hmPut:
          begin
            LStream := TStringStream.Create(FBody, TEncoding.UTF8);
            try
              LResponse := LClient.Put(LUrl, LStream);
            finally
              LStream.Free;
            end;
          end;
        hmDelete:
          LResponse := LClient.Delete(LUrl);
        hmPatch:
          begin
            LStream := TStringStream.Create(FBody, TEncoding.UTF8);
            try
              LResponse := LClient.Patch(LUrl, LStream);
            finally
              LStream.Free;
            end;
          end;
        hmHead:
          LResponse := LClient.Head(LUrl);
        hmOptions:
          LResponse := LClient.Options(LUrl);
      end;
      
      Result.StatusCode := LResponse.StatusCode;
      Result.StatusText := LResponse.StatusText;
      Result.Body := LResponse.ContentAsString;
      Result.ContentType := LResponse.MimeType;
      Result.ContentLength := LResponse.ContentLength;
      Result.Elapsed := Round((Now - LStartTime) * 86400000);
      
      // Copy response headers
      for var LHeader in LResponse.Headers do
        Result.Headers.AddOrSetValue(LHeader.Name, LHeader.Value);
        
    except
      on E: Exception do
      begin
        Result.StatusCode := -1;
        Result.StatusText := E.Message;
        Result.Body := '';
        Result.Elapsed := Round((Now - LStartTime) * 86400000);
      end;
    end;
  finally
    LClient.Free;
  end;
end;

function THttpRequest.Get: THttpResponse;
begin
  FMethod := hmGet;
  Result := Execute;
end;

function THttpRequest.Post: THttpResponse;
begin
  FMethod := hmPost;
  Result := Execute;
end;

function THttpRequest.Put: THttpResponse;
begin
  FMethod := hmPut;
  Result := Execute;
end;

function THttpRequest.Delete: THttpResponse;
begin
  FMethod := hmDelete;
  Result := Execute;
end;

function THttpRequest.Patch: THttpResponse;
begin
  FMethod := hmPatch;
  Result := Execute;
end;

{ THttpClient_ }

constructor THttpClient_.Create(const ABaseUrl: string);
begin
  inherited Create;
  FBaseUrl := ABaseUrl;
  FDefaultHeaders := TDictionary<string, string>.Create;
  FTimeout := 30000;
  FLock := TCriticalSection.Create;
end;

destructor THttpClient_.Destroy;
begin
  FDefaultHeaders.Free;
  FLock.Free;
  inherited;
end;

procedure THttpClient_.SetDefaultHeader(const AName, AValue: string);
begin
  FLock.Enter;
  try
    FDefaultHeaders.AddOrSetValue(AName, AValue);
  finally
    FLock.Leave;
  end;
end;

procedure THttpClient_.SetTimeout(ATimeoutMs: Integer);
begin
  FTimeout := ATimeoutMs;
end;

function THttpClient_.Request(const AUrl: string): THttpRequest;
var
  LFullUrl: string;
  LPair: TPair<string, string>;
begin
  if (FBaseUrl <> '') and not AUrl.StartsWith('http') then
    LFullUrl := TNetworkUtils.JoinUrl(FBaseUrl, AUrl)
  else
    LFullUrl := AUrl;
    
  Result := THttpRequest.Create(LFullUrl);
  Result.Timeout(FTimeout);
  
  FLock.Enter;
  try
    for LPair in FDefaultHeaders do
      Result.Header(LPair.Key, LPair.Value);
  finally
    FLock.Leave;
  end;
end;

function THttpClient_.Get(const AUrl: string): THttpResponse;
var
  LRequest: THttpRequest;
begin
  LRequest := Request(AUrl);
  try
    Result := LRequest.Get;
  finally
    LRequest.Free;
  end;
end;

function THttpClient_.Post(const AUrl: string; const ABody: string): THttpResponse;
var
  LRequest: THttpRequest;
begin
  LRequest := Request(AUrl).Body(ABody);
  try
    Result := LRequest.Post;
  finally
    LRequest.Free;
  end;
end;

function THttpClient_.Put(const AUrl: string; const ABody: string): THttpResponse;
var
  LRequest: THttpRequest;
begin
  LRequest := Request(AUrl).Body(ABody);
  try
    Result := LRequest.Put;
  finally
    LRequest.Free;
  end;
end;

function THttpClient_.Delete(const AUrl: string): THttpResponse;
var
  LRequest: THttpRequest;
begin
  LRequest := Request(AUrl);
  try
    Result := LRequest.Delete;
  finally
    LRequest.Free;
  end;
end;

function THttpClient_.Patch(const AUrl: string; const ABody: string): THttpResponse;
var
  LRequest: THttpRequest;
begin
  LRequest := Request(AUrl).Body(ABody);
  try
    Result := LRequest.Patch;
  finally
    LRequest.Free;
  end;
end;

function THttpClient_.GetJSON(const AUrl: string): TJSONValue;
var
  LRequest: THttpRequest;
  LResponse: THttpResponse;
begin
  LRequest := Request(AUrl).Header('Accept', 'application/json');
  try
    LResponse := LRequest.Get;
    try
      if LResponse.IsSuccess then
        Result := LResponse.AsJSON
      else
        Result := nil;
    finally
      LResponse.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

function THttpClient_.PostJSON(const AUrl: string; AJson: TJSONValue): TJSONValue;
var
  LRequest: THttpRequest;
  LResponse: THttpResponse;
begin
  LRequest := Request(AUrl).Header('Accept', 'application/json').JsonBody(AJson);
  try
    LResponse := LRequest.Post;
    try
      if LResponse.IsSuccess then
        Result := LResponse.AsJSON
      else
        Result := nil;
    finally
      LResponse.Free;
    end;
  finally
    LRequest.Free;
  end;
end;

{ TWebSocketClient }

constructor TWebSocketClient.Create(const AUrl: string);
begin
  inherited Create;
  FUrl := AUrl;
  FState := wssClosed;
  FLock := TCriticalSection.Create;
  FConnectTimeout := 10000;
  FPingInterval := 30000;
end;

destructor TWebSocketClient.Destroy;
begin
  if FState in [wssConnecting, wssOpen] then
    Disconnect;
  FLock.Free;
  inherited;
end;

procedure TWebSocketClient.Connect;
begin
  FLock.Enter;
  try
    if FState <> wssClosed then
      Exit;
    FState := wssConnecting;
  finally
    FLock.Leave;
  end;
  
  // WebSocket implementation would go here
  // For now, just simulate connection
  FState := wssOpen;
  if Assigned(FOnOpen) then
    FOnOpen(Self);
end;

procedure TWebSocketClient.Disconnect(ACode: Integer; const AReason: string);
begin
  FLock.Enter;
  try
    if FState = wssClosed then
      Exit;
    FState := wssClosing;
  finally
    FLock.Leave;
  end;
  
  // WebSocket disconnect implementation would go here
  FState := wssClosed;
  if Assigned(FOnClose) then
    FOnClose(Self, ACode, AReason);
end;

procedure TWebSocketClient.Send(const AMessage: string);
begin
  if FState <> wssOpen then
    raise ENetException.Create('WebSocket is not connected');
  // Send implementation would go here
end;

procedure TWebSocketClient.Send(const AData: TBytes);
begin
  if FState <> wssOpen then
    raise ENetException.Create('WebSocket is not connected');
  // Send implementation would go here
end;

procedure TWebSocketClient.Ping;
begin
  if FState <> wssOpen then
    Exit;
  // Ping implementation would go here
end;

{ TDnsRecord }

function TDnsRecord.ToString: string;
begin
  Result := Format('%s %s %d %s', [Name, Value, TTL, 
    GetEnumName(TypeInfo(TDnsRecordType), Ord(RecordType))]);
end;

{ TDnsResolver_ }

constructor TDnsResolver_.Create(const ADnsServer: string);
begin
  inherited Create;
  FDnsServer := ADnsServer;
  FTimeout := 5000;
  FResolver := TIdDNSResolver.Create(nil);
  FLock := TCriticalSection.Create;
  
  if ADnsServer = '' then
    FDnsServer := '8.8.8.8';  // Google DNS
    
  FResolver.Host := FDnsServer;
  FResolver.WaitingTime := FTimeout;
end;

destructor TDnsResolver_.Destroy;
begin
  FResolver.Free;
  FLock.Free;
  inherited;
end;

function TDnsResolver_.Resolve(const AHostname: string): string;
var
  LAddresses: TArray<string>;
begin
  LAddresses := ResolveAll(AHostname);
  if Length(LAddresses) > 0 then
    Result := LAddresses[0]
  else
    Result := '';
end;

function TDnsResolver_.ResolveAll(const AHostname: string): TArray<string>;
var
  I: Integer;
  LList: TList<string>;
begin
  LList := TList<string>.Create;
  try
    FLock.Enter;
    try
      FResolver.Host := FDnsServer;
      FResolver.WaitingTime := FTimeout;
      FResolver.QueryType := [qtA];
      FResolver.Resolve(AHostname);
      
      for I := 0 to FResolver.QueryResult.Count - 1 do
      begin
        if FResolver.QueryResult[I] is TARecord then
          LList.Add(TARecord(FResolver.QueryResult[I]).IPAddress);
      end;
    finally
      FLock.Leave;
    end;
    Result := LList.ToArray;
  finally
    LList.Free;
  end;
end;

function TDnsResolver_.ResolveIPv6(const AHostname: string): string;
var
  I: Integer;
begin
  Result := '';
  FLock.Enter;
  try
    FResolver.Host := FDnsServer;
    FResolver.WaitingTime := FTimeout;
    FResolver.QueryType := [qtAAAA];
    FResolver.Resolve(AHostname);
    
    for I := 0 to FResolver.QueryResult.Count - 1 do
    begin
      if FResolver.QueryResult[I] is TAAAARecord then
      begin
        Result := TAAAARecord(FResolver.QueryResult[I]).Address;
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDnsResolver_.ReverseLookup(const AIPAddress: string): string;
var
  I: Integer;
begin
  Result := '';
  FLock.Enter;
  try
    FResolver.Host := FDnsServer;
    FResolver.WaitingTime := FTimeout;
    FResolver.QueryType := [qtPTR];
    FResolver.Resolve(AIPAddress);
    
    for I := 0 to FResolver.QueryResult.Count - 1 do
    begin
      if FResolver.QueryResult[I] is TPTRRecord then
      begin
        Result := TPTRRecord(FResolver.QueryResult[I]).HostName;
        Break;
      end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TDnsResolver_.QueryRecords(const AHostname: string; ARecordType: TDnsRecordType): TArray<TDnsRecord>;
var
  LRecords: TList<TDnsRecord>;
  LRecord: TDnsRecord;
  I: Integer;
begin
  LRecords := TList<TDnsRecord>.Create;
  try
    FLock.Enter;
    try
      FResolver.Host := FDnsServer;
      FResolver.WaitingTime := FTimeout;
      
      case ARecordType of
        drtA: FResolver.QueryType := [qtA];
        drtAAAA: FResolver.QueryType := [qtAAAA];
        drtCNAME: FResolver.QueryType := [qtName];
        drtMX: FResolver.QueryType := [qtMX];
        drtNS: FResolver.QueryType := [qtNS];
        drtPTR: FResolver.QueryType := [qtPTR];
        drtSOA: FResolver.QueryType := [qtSOA];
        drtSRV: FResolver.QueryType := [qtService];
        drtTXT: FResolver.QueryType := [qtTXT];
      end;
      
      FResolver.Resolve(AHostname);
      
      for I := 0 to FResolver.QueryResult.Count - 1 do
      begin
        LRecord.RecordType := ARecordType;
        LRecord.Name := AHostname;
        LRecord.TTL := FResolver.QueryResult[I].TTL;
        LRecord.Priority := 0;
        
        if FResolver.QueryResult[I] is TARecord then
          LRecord.Value := TARecord(FResolver.QueryResult[I]).IPAddress
        else if FResolver.QueryResult[I] is TAAAARecord then
          LRecord.Value := TAAAARecord(FResolver.QueryResult[I]).Address
        else if FResolver.QueryResult[I] is TCNRecord then
          LRecord.Value := TCNRecord(FResolver.QueryResult[I]).HostName
        else if FResolver.QueryResult[I] is TMXRecord then
        begin
          LRecord.Value := TMXRecord(FResolver.QueryResult[I]).ExchangeServer;
          LRecord.Priority := TMXRecord(FResolver.QueryResult[I]).Preference;
        end
        else if FResolver.QueryResult[I] is TNSRecord then
          LRecord.Value := TNSRecord(FResolver.QueryResult[I]).HostName
        else if FResolver.QueryResult[I] is TPTRRecord then
          LRecord.Value := TPTRRecord(FResolver.QueryResult[I]).HostName
        else if FResolver.QueryResult[I] is TTextRecord then
          LRecord.Value := TTextRecord(FResolver.QueryResult[I]).Text.Text;
          
        LRecords.Add(LRecord);
      end;
    finally
      FLock.Leave;
    end;
    
    Result := LRecords.ToArray;
  finally
    LRecords.Free;
  end;
end;

function TDnsResolver_.QueryMX(const ADomain: string): TArray<TDnsRecord>;
begin
  Result := QueryRecords(ADomain, drtMX);
end;

function TDnsResolver_.QueryNS(const ADomain: string): TArray<TDnsRecord>;
begin
  Result := QueryRecords(ADomain, drtNS);
end;

function TDnsResolver_.QueryTXT(const ADomain: string): TArray<string>;
var
  LRecords: TArray<TDnsRecord>;
  I: Integer;
begin
  LRecords := QueryRecords(ADomain, drtTXT);
  SetLength(Result, Length(LRecords));
  for I := 0 to High(LRecords) do
    Result[I] := LRecords[I].Value;
end;

{ TIPv4Address }

constructor TIPv4Address.Create(const AAddress: string);
var
  LParts: TArray<string>;
  LValues: array[0..3] of Integer;
  I: Integer;
begin
  LParts := AAddress.Split(['.']);
  if Length(LParts) <> 4 then
    raise ENetException.CreateFmt('Invalid IPv4 address: %s', [AAddress]);
  
  for I := 0 to 3 do
  begin
    if not TryStrToInt(LParts[I], LValues[I]) then
      raise ENetException.CreateFmt('Invalid IPv4 address: %s', [AAddress]);
    if (LValues[I] < 0) or (LValues[I] > 255) then
      raise ENetException.CreateFmt('IPv4 octet out of range: %s', [AAddress]);
    Octets[I] := LValues[I];
  end;
end;

constructor TIPv4Address.Create(A, B, C, D: Byte);
begin
  Octets[0] := A;
  Octets[1] := B;
  Octets[2] := C;
  Octets[3] := D;
end;

constructor TIPv4Address.Create(AValue: Cardinal);
begin
  Octets[0] := (AValue shr 24) and $FF;
  Octets[1] := (AValue shr 16) and $FF;
  Octets[2] := (AValue shr 8) and $FF;
  Octets[3] := AValue and $FF;
end;

function TIPv4Address.ToString: string;
begin
  Result := Format('%d.%d.%d.%d', [Octets[0], Octets[1], Octets[2], Octets[3]]);
end;

function TIPv4Address.ToInteger: Cardinal;
begin
  Result := (Cardinal(Octets[0]) shl 24) or
            (Cardinal(Octets[1]) shl 16) or
            (Cardinal(Octets[2]) shl 8) or
            Cardinal(Octets[3]);
end;

function TIPv4Address.IsPrivate: Boolean;
begin
  // 10.0.0.0/8
  if Octets[0] = 10 then
    Exit(True);
  // 172.16.0.0/12
  if (Octets[0] = 172) and (Octets[1] >= 16) and (Octets[1] <= 31) then
    Exit(True);
  // 192.168.0.0/16
  if (Octets[0] = 192) and (Octets[1] = 168) then
    Exit(True);
  Result := False;
end;

function TIPv4Address.IsLoopback: Boolean;
begin
  Result := Octets[0] = 127;
end;

function TIPv4Address.IsMulticast: Boolean;
begin
  Result := (Octets[0] >= 224) and (Octets[0] <= 239);
end;

function TIPv4Address.IsBroadcast: Boolean;
begin
  Result := (Octets[0] = 255) and (Octets[1] = 255) and 
            (Octets[2] = 255) and (Octets[3] = 255);
end;

function TIPv4Address.IsValid: Boolean;
begin
  Result := True;  // If constructed, it's valid
end;

class function TIPv4Address.Parse(const AAddress: string): TIPv4Address;
begin
  Result := TIPv4Address.Create(AAddress);
end;

class function TIPv4Address.TryParse(const AAddress: string; out AResult: TIPv4Address): Boolean;
begin
  try
    AResult := TIPv4Address.Create(AAddress);
    Result := True;
  except
    Result := False;
  end;
end;

class operator TIPv4Address.Equal(const A, B: TIPv4Address): Boolean;
begin
  Result := (A.Octets[0] = B.Octets[0]) and
            (A.Octets[1] = B.Octets[1]) and
            (A.Octets[2] = B.Octets[2]) and
            (A.Octets[3] = B.Octets[3]);
end;

class operator TIPv4Address.NotEqual(const A, B: TIPv4Address): Boolean;
begin
  Result := not (A = B);
end;

class operator TIPv4Address.BitwiseAnd(const A, B: TIPv4Address): TIPv4Address;
begin
  Result.Octets[0] := A.Octets[0] and B.Octets[0];
  Result.Octets[1] := A.Octets[1] and B.Octets[1];
  Result.Octets[2] := A.Octets[2] and B.Octets[2];
  Result.Octets[3] := A.Octets[3] and B.Octets[3];
end;

class operator TIPv4Address.BitwiseOr(const A, B: TIPv4Address): TIPv4Address;
begin
  Result.Octets[0] := A.Octets[0] or B.Octets[0];
  Result.Octets[1] := A.Octets[1] or B.Octets[1];
  Result.Octets[2] := A.Octets[2] or B.Octets[2];
  Result.Octets[3] := A.Octets[3] or B.Octets[3];
end;

class operator TIPv4Address.BitwiseXor(const A, B: TIPv4Address): TIPv4Address;
begin
  Result.Octets[0] := A.Octets[0] xor B.Octets[0];
  Result.Octets[1] := A.Octets[1] xor B.Octets[1];
  Result.Octets[2] := A.Octets[2] xor B.Octets[2];
  Result.Octets[3] := A.Octets[3] xor B.Octets[3];
end;

class operator TIPv4Address.LogicalNot(const A: TIPv4Address): TIPv4Address;
begin
  Result.Octets[0] := not A.Octets[0];
  Result.Octets[1] := not A.Octets[1];
  Result.Octets[2] := not A.Octets[2];
  Result.Octets[3] := not A.Octets[3];
end;

{ TIPv4Subnet }

constructor TIPv4Subnet.Create(const ANetwork: TIPv4Address; APrefixLength: Integer);
begin
  if (APrefixLength < 0) or (APrefixLength > 32) then
    raise ENetException.Create('Invalid prefix length');
    
  PrefixLength := APrefixLength;
  Mask := PrefixToMask(APrefixLength);
  Network := ANetwork and Mask;
end;

constructor TIPv4Subnet.Create(const ACIDR: string);
var
  LParts: TArray<string>;
begin
  LParts := ACIDR.Split(['/']);
  if Length(LParts) <> 2 then
    raise ENetException.CreateFmt('Invalid CIDR notation: %s', [ACIDR]);
    
  Create(TIPv4Address.Create(LParts[0]), StrToInt(LParts[1]));
end;

function TIPv4Subnet.Contains(const AAddress: TIPv4Address): Boolean;
begin
  Result := (AAddress and Mask) = Network;
end;

function TIPv4Subnet.GetBroadcast: TIPv4Address;
begin
  Result := Network or (not Mask);
end;

function TIPv4Subnet.GetFirstHost: TIPv4Address;
begin
  if PrefixLength >= 31 then
    Result := Network
  else
    Result := TIPv4Address.Create(Network.ToInteger + 1);
end;

function TIPv4Subnet.GetLastHost: TIPv4Address;
begin
  if PrefixLength >= 31 then
    Result := GetBroadcast
  else
    Result := TIPv4Address.Create(GetBroadcast.ToInteger - 1);
end;

function TIPv4Subnet.GetHostCount: Cardinal;
begin
  if PrefixLength >= 31 then
    Result := Cardinal(1) shl (32 - PrefixLength)
  else
    Result := (Cardinal(1) shl (32 - PrefixLength)) - 2;
end;

function TIPv4Subnet.ToString: string;
begin
  Result := Format('%s/%d (mask %s)', [Network.ToString, PrefixLength, Mask.ToString]);
end;

function TIPv4Subnet.ToCIDR: string;
begin
  Result := Format('%s/%d', [Network.ToString, PrefixLength]);
end;

class function TIPv4Subnet.Parse(const ACIDR: string): TIPv4Subnet;
begin
  Result := TIPv4Subnet.Create(ACIDR);
end;

class function TIPv4Subnet.TryParse(const ACIDR: string; out AResult: TIPv4Subnet): Boolean;
begin
  try
    AResult := TIPv4Subnet.Create(ACIDR);
    Result := True;
  except
    Result := False;
  end;
end;

class function TIPv4Subnet.PrefixToMask(APrefixLength: Integer): TIPv4Address;
var
  LMask: Cardinal;
begin
  if APrefixLength = 0 then
    LMask := 0
  else
    LMask := $FFFFFFFF shl (32 - APrefixLength);
  Result := TIPv4Address.Create(LMask);
end;

class function TIPv4Subnet.MaskToPrefix(const AMask: TIPv4Address): Integer;
var
  LMask: Cardinal;
begin
  LMask := AMask.ToInteger;
  Result := 0;
  while (LMask and $80000000) <> 0 do
  begin
    Inc(Result);
    LMask := LMask shl 1;
  end;
end;

{ TNetworkInterface }

function TNetworkInterface.ToString: string;
begin
  Result := Format('%s (%s) - %s', [Name, Description, IPv4Address]);
end;

{ TPingResult }

function TPingResult.ToString: string;
begin
  if Success then
    Result := Format('Reply from %s: time=%dms TTL=%d', [ReplyFrom, RoundTripTime, TTL])
  else
    Result := Format('Ping failed: %s', [ErrorMessage]);
end;

{ TNetworkUtils }

class function TNetworkUtils.IsInternetAvailable: Boolean;
begin
  Result := CanReach('8.8.8.8', 53, 3000) or CanReach('1.1.1.1', 53, 3000);
end;

class function TNetworkUtils.CanReach(const AHost: string; APort: Integer; ATimeout: Integer): Boolean;
var
  LClient: TIdTCPClient;
begin
  Result := False;
  LClient := TIdTCPClient.Create(nil);
  try
    LClient.Host := AHost;
    LClient.Port := APort;
    LClient.ConnectTimeout := ATimeout;
    LClient.ReadTimeout := ATimeout;
    try
      LClient.Connect;
      Result := LClient.Connected;
      LClient.Disconnect;
    except
      Result := False;
    end;
  finally
    LClient.Free;
  end;
end;

class function TNetworkUtils.Ping(const AHost: string; ATimeout: Integer): TPingResult;
var
  LPing: TIdICMPClient;
begin
  Result.Success := False;
  Result.Address := AHost;
  
  LPing := TIdICMPClient.Create(nil);
  try
    LPing.Host := AHost;
    LPing.ReceiveTimeout := ATimeout;
    try
      LPing.Ping;
      Result.Success := LPing.ReplyStatus.BytesReceived > 0;
      Result.ReplyFrom := LPing.ReplyStatus.FromIpAddress;
      Result.RoundTripTime := LPing.ReplyStatus.MsRoundTripTime;
      Result.TTL := LPing.ReplyStatus.TimeToLive;
      if not Result.Success then
        Result.ErrorMessage := 'Request timed out';
    except
      on E: Exception do
      begin
        Result.Success := False;
        Result.ErrorMessage := E.Message;
      end;
    end;
  finally
    LPing.Free;
  end;
end;

class function TNetworkUtils.PingMultiple(const AHost: string; ACount: Integer; ATimeout: Integer): TArray<TPingResult>;
var
  I: Integer;
begin
  SetLength(Result, ACount);
  for I := 0 to ACount - 1 do
  begin
    Result[I] := Ping(AHost, ATimeout);
    if I < ACount - 1 then
      Sleep(1000);
  end;
end;

class function TNetworkUtils.IsPortOpen(const AHost: string; APort: Integer; ATimeout: Integer): Boolean;
begin
  Result := CanReach(AHost, APort, ATimeout);
end;

class function TNetworkUtils.ScanPorts(const AHost: string; APorts: array of Integer; ATimeout: Integer): TArray<TPortScanResult>;
var
  I: Integer;
begin
  SetLength(Result, Length(APorts));
  for I := 0 to High(APorts) do
  begin
    Result[I].Port := APorts[I];
    Result[I].IsOpen := IsPortOpen(AHost, APorts[I], ATimeout);
    Result[I].Service := GetServiceName(APorts[I]);
  end;
end;

class function TNetworkUtils.ScanPortRange(const AHost: string; AStartPort, AEndPort: Integer; ATimeout: Integer): TArray<TPortScanResult>;
var
  LResults: TList<TPortScanResult>;
  LResult: TPortScanResult;
  I: Integer;
begin
  LResults := TList<TPortScanResult>.Create;
  try
    for I := AStartPort to AEndPort do
    begin
      LResult.Port := I;
      LResult.IsOpen := IsPortOpen(AHost, I, ATimeout);
      LResult.Service := GetServiceName(I);
      if LResult.IsOpen then
        LResults.Add(LResult);
    end;
    Result := LResults.ToArray;
  finally
    LResults.Free;
  end;
end;

class function TNetworkUtils.GetLocalIPAddress: string;
begin
  TIdStack.IncUsage;
  try
    Result := GStack.LocalAddress;
  finally
    TIdStack.DecUsage;
  end;
end;

class function TNetworkUtils.GetLocalIPAddresses: TArray<string>;
var
  LAddresses: TIdStackLocalAddressList;
  I: Integer;
begin
  TIdStack.IncUsage;
  try
    LAddresses := TIdStackLocalAddressList.Create;
    try
      GStack.GetLocalAddressList(LAddresses);
      SetLength(Result, LAddresses.Count);
      for I := 0 to LAddresses.Count - 1 do
        Result[I] := LAddresses[I].IPAddress;
    finally
      LAddresses.Free;
    end;
  finally
    TIdStack.DecUsage;
  end;
end;

class function TNetworkUtils.GetHostName_: string;
begin
  TIdStack.IncUsage;
  try
    Result := GStack.HostName;
  finally
    TIdStack.DecUsage;
  end;
end;

class function TNetworkUtils.GetNetworkInterfaces: TArray<TNetworkInterface>;
var
  LAddresses: TIdStackLocalAddressList;
  I: Integer;
begin
  TIdStack.IncUsage;
  try
    LAddresses := TIdStackLocalAddressList.Create;
    try
      GStack.GetLocalAddressList(LAddresses);
      SetLength(Result, LAddresses.Count);
      for I := 0 to LAddresses.Count - 1 do
      begin
        Result[I].Name := 'Interface' + IntToStr(I);
        Result[I].IPv4Address := LAddresses[I].IPAddress;
        Result[I].IsUp := True;
        Result[I].IsLoopback := LAddresses[I].IPAddress.StartsWith('127.');
      end;
    finally
      LAddresses.Free;
    end;
  finally
    TIdStack.DecUsage;
  end;
end;

class function TNetworkUtils.GetMacAddress: string;
begin
  // Implementation depends on platform
  Result := '';
end;

class function TNetworkUtils.GetDefaultGateway: string;
begin
  // Implementation depends on platform
  Result := '';
end;

class function TNetworkUtils.UrlEncode(const AValue: string): string;
begin
  Result := TNetEncoding.URL.Encode(AValue);
end;

class function TNetworkUtils.UrlDecode(const AValue: string): string;
begin
  Result := TNetEncoding.URL.Decode(AValue);
end;

class function TNetworkUtils.BuildUrl(const ABase: string; const AParams: array of TPair<string, string>): string;
var
  LPair: TPair<string, string>;
  LQuery: string;
begin
  Result := ABase;
  LQuery := '';
  for LPair in AParams do
  begin
    if LQuery <> '' then
      LQuery := LQuery + '&';
    LQuery := LQuery + UrlEncode(LPair.Key) + '=' + UrlEncode(LPair.Value);
  end;
  if LQuery <> '' then
  begin
    if Pos('?', Result) > 0 then
      Result := Result + '&' + LQuery
    else
      Result := Result + '?' + LQuery;
  end;
end;

class function TNetworkUtils.ParseUrl(const AUrl: string; out AScheme, AHost, APath: string; out APort: Integer): Boolean;
var
  LUri: TUri;
begin
  try
    LUri := TUri.Create(AUrl);
    AScheme := LUri.Scheme;
    AHost := LUri.Host;
    APath := LUri.Path;
    APort := LUri.Port;
    if APort = 0 then
    begin
      if AScheme = 'https' then
        APort := 443
      else
        APort := 80;
    end;
    Result := True;
  except
    Result := False;
  end;
end;

class function TNetworkUtils.JoinUrl(const ABase, ARelative: string): string;
begin
  if ARelative.StartsWith('http://') or ARelative.StartsWith('https://') then
    Exit(ARelative);
    
  if ARelative.StartsWith('/') then
  begin
    // Absolute path
    if ABase.EndsWith('/') then
      Result := ABase + ARelative.Substring(1)
    else
      Result := ABase + ARelative;
  end
  else
  begin
    // Relative path
    if ABase.EndsWith('/') then
      Result := ABase + ARelative
    else
      Result := ABase + '/' + ARelative;
  end;
end;

class function TNetworkUtils.IsValidIPv4(const AAddress: string): Boolean;
var
  LParts: TArray<string>;
  I, LValue: Integer;
begin
  LParts := AAddress.Split(['.']);
  if Length(LParts) <> 4 then
    Exit(False);
    
  for I := 0 to 3 do
  begin
    if not TryStrToInt(LParts[I], LValue) then
      Exit(False);
    if (LValue < 0) or (LValue > 255) then
      Exit(False);
  end;
  Result := True;
end;

class function TNetworkUtils.IsValidIPv6(const AAddress: string): Boolean;
begin
  // Simple validation - check for valid characters and structure
  Result := TRegEx.IsMatch(AAddress, 
    '^([0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4}$|' +
    '^([0-9a-fA-F]{1,4}:){1,7}:$|' +
    '^([0-9a-fA-F]{1,4}:){1,6}:[0-9a-fA-F]{1,4}$|' +
    '^::([0-9a-fA-F]{1,4}:){0,5}[0-9a-fA-F]{1,4}$|' +
    '^::$');
end;

class function TNetworkUtils.IsValidHostname(const AHostname: string): Boolean;
begin
  // Valid hostname: labels separated by dots, each 1-63 chars, total max 253
  if (Length(AHostname) = 0) or (Length(AHostname) > 253) then
    Exit(False);
    
  Result := TRegEx.IsMatch(AHostname, 
    '^(?=.{1,253}$)(?!-)[a-zA-Z0-9-]{1,63}(?<!-)(\.[a-zA-Z0-9-]{1,63})*$');
end;

class function TNetworkUtils.IsValidPort(APort: Integer): Boolean;
begin
  Result := (APort >= 1) and (APort <= 65535);
end;

class function TNetworkUtils.GetServiceName(APort: Integer): string;
begin
  case APort of
    20: Result := 'FTP Data';
    21: Result := 'FTP';
    22: Result := 'SSH';
    23: Result := 'Telnet';
    25: Result := 'SMTP';
    53: Result := 'DNS';
    67: Result := 'DHCP Server';
    68: Result := 'DHCP Client';
    69: Result := 'TFTP';
    80: Result := 'HTTP';
    110: Result := 'POP3';
    119: Result := 'NNTP';
    123: Result := 'NTP';
    135: Result := 'RPC';
    137: Result := 'NetBIOS Name';
    138: Result := 'NetBIOS Datagram';
    139: Result := 'NetBIOS Session';
    143: Result := 'IMAP';
    161: Result := 'SNMP';
    162: Result := 'SNMP Trap';
    389: Result := 'LDAP';
    443: Result := 'HTTPS';
    445: Result := 'SMB';
    465: Result := 'SMTPS';
    514: Result := 'Syslog';
    587: Result := 'SMTP Submission';
    636: Result := 'LDAPS';
    993: Result := 'IMAPS';
    995: Result := 'POP3S';
    1433: Result := 'MS SQL';
    1521: Result := 'Oracle';
    3306: Result := 'MySQL';
    3389: Result := 'RDP';
    5432: Result := 'PostgreSQL';
    5900: Result := 'VNC';
    6379: Result := 'Redis';
    8080: Result := 'HTTP Proxy';
    8443: Result := 'HTTPS Alt';
    27017: Result := 'MongoDB';
  else
    Result := '';
  end;
end;

class function TNetworkUtils.GetServicePort(const AServiceName: string): Integer;
var
  LName: string;
begin
  LName := LowerCase(AServiceName);
  if LName = 'ftp' then Result := 21
  else if LName = 'ssh' then Result := 22
  else if LName = 'telnet' then Result := 23
  else if LName = 'smtp' then Result := 25
  else if LName = 'dns' then Result := 53
  else if LName = 'http' then Result := 80
  else if LName = 'pop3' then Result := 110
  else if LName = 'imap' then Result := 143
  else if LName = 'https' then Result := 443
  else if LName = 'smtps' then Result := 465
  else if LName = 'imaps' then Result := 993
  else if LName = 'pop3s' then Result := 995
  else if LName = 'mssql' then Result := 1433
  else if LName = 'mysql' then Result := 3306
  else if LName = 'rdp' then Result := 3389
  else if LName = 'postgresql' then Result := 5432
  else if LName = 'redis' then Result := 6379
  else if LName = 'mongodb' then Result := 27017
  else Result := 0;
end;

{ TIPUtils }

class function TIPUtils.IPv4ToInteger(const AAddress: string): Cardinal;
var
  LIP: TIPv4Address;
begin
  LIP := TIPv4Address.Create(AAddress);
  Result := LIP.ToInteger;
end;

class function TIPUtils.IntegerToIPv4(AValue: Cardinal): string;
var
  LIP: TIPv4Address;
begin
  LIP := TIPv4Address.Create(AValue);
  Result := LIP.ToString;
end;

class function TIPUtils.IsInSubnet(const AAddress, ANetwork: string; APrefixLength: Integer): Boolean;
var
  LSubnet: TIPv4Subnet;
  LAddr: TIPv4Address;
begin
  LSubnet := TIPv4Subnet.Create(TIPv4Address.Create(ANetwork), APrefixLength);
  LAddr := TIPv4Address.Create(AAddress);
  Result := LSubnet.Contains(LAddr);
end;

class function TIPUtils.GetSubnetBroadcast(const ANetwork: string; APrefixLength: Integer): string;
var
  LSubnet: TIPv4Subnet;
begin
  LSubnet := TIPv4Subnet.Create(TIPv4Address.Create(ANetwork), APrefixLength);
  Result := LSubnet.GetBroadcast.ToString;
end;

class function TIPUtils.GetSubnetHostCount(APrefixLength: Integer): Cardinal;
begin
  if APrefixLength >= 31 then
    Result := Cardinal(1) shl (32 - APrefixLength)
  else
    Result := (Cardinal(1) shl (32 - APrefixLength)) - 2;
end;

class function TIPUtils.IsPrivateIP(const AAddress: string): Boolean;
var
  LIP: TIPv4Address;
begin
  if not TIPv4Address.TryParse(AAddress, LIP) then
    Exit(False);
  Result := LIP.IsPrivate;
end;

class function TIPUtils.IsLoopbackIP(const AAddress: string): Boolean;
var
  LIP: TIPv4Address;
begin
  if not TIPv4Address.TryParse(AAddress, LIP) then
    Exit(False);
  Result := LIP.IsLoopback;
end;

class function TIPUtils.IsMulticastIP(const AAddress: string): Boolean;
var
  LIP: TIPv4Address;
begin
  if not TIPv4Address.TryParse(AAddress, LIP) then
    Exit(False);
  Result := LIP.IsMulticast;
end;

class function TIPUtils.IsReservedIP(const AAddress: string): Boolean;
var
  LIP: TIPv4Address;
begin
  if not TIPv4Address.TryParse(AAddress, LIP) then
    Exit(False);
    
  // 0.0.0.0/8 - Current network
  if LIP.Octets[0] = 0 then
    Exit(True);
  // 100.64.0.0/10 - Carrier-grade NAT
  if (LIP.Octets[0] = 100) and (LIP.Octets[1] >= 64) and (LIP.Octets[1] <= 127) then
    Exit(True);
  // 169.254.0.0/16 - Link-local
  if (LIP.Octets[0] = 169) and (LIP.Octets[1] = 254) then
    Exit(True);
  // 192.0.0.0/24 - IETF Protocol Assignments
  if (LIP.Octets[0] = 192) and (LIP.Octets[1] = 0) and (LIP.Octets[2] = 0) then
    Exit(True);
  // 192.0.2.0/24 - TEST-NET-1
  if (LIP.Octets[0] = 192) and (LIP.Octets[1] = 0) and (LIP.Octets[2] = 2) then
    Exit(True);
  // 198.51.100.0/24 - TEST-NET-2
  if (LIP.Octets[0] = 198) and (LIP.Octets[1] = 51) and (LIP.Octets[2] = 100) then
    Exit(True);
  // 203.0.113.0/24 - TEST-NET-3
  if (LIP.Octets[0] = 203) and (LIP.Octets[1] = 0) and (LIP.Octets[2] = 113) then
    Exit(True);
  // 240.0.0.0/4 - Reserved for future use
  if LIP.Octets[0] >= 240 then
    Exit(True);
    
  Result := False;
end;

class function TIPUtils.CompareIPv4(const A, B: string): Integer;
var
  LAddrA, LAddrB: TIPv4Address;
  LIntA, LIntB: Cardinal;
begin
  LAddrA := TIPv4Address.Create(A);
  LAddrB := TIPv4Address.Create(B);
  LIntA := LAddrA.ToInteger;
  LIntB := LAddrB.ToInteger;
  
  if LIntA < LIntB then
    Result := -1
  else if LIntA > LIntB then
    Result := 1
  else
    Result := 0;
end;

class function TIPUtils.SortIPv4Addresses(const AAddresses: TArray<string>): TArray<string>;
begin
  Result := Copy(AAddresses);
  TArray.Sort<string>(Result, TComparer<string>.Construct(
    function(const A, B: string): Integer
    begin
      Result := CompareIPv4(A, B);
    end
  ));
end;

initialization
  GHttpLock := TCriticalSection.Create;

finalization
  FreeAndNil(GHttpClient);
  FreeAndNil(GHttpLock);

end.
