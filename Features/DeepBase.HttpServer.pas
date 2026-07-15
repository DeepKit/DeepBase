{ ============================================================================
  DeepBase.HttpServer - Lightweight HTTP Server
  
  A lightweight HTTP server with routing and middleware support.
  
  Features:
  - HTTP/1.1 server using Indy components
  - Fluent route definition (GET, POST, PUT, DELETE, etc.)
  - Middleware pipeline (logging, auth, CORS, etc.)
  - Request/Response abstractions
  - JSON response helpers
  - Path parameters and query string parsing
  - Static file serving
  - WebSocket support (basic)
  
  Usage:
    var Server := THttpServer.Create;
    Server
      .Use(TLoggingMiddleware.Create)
      .Use(TCorsMiddleware.Create)
      .Get('/api/users', 
        procedure(const Ctx: THttpContext)
        begin
          Ctx.Response.Json([User1, User2]);
        end)
      .Get('/api/users/:id',
        procedure(const Ctx: THttpContext)
        begin
          var Id := Ctx.Request.Param['id'];
          Ctx.Response.Json(GetUser(Id));
        end)
      .Post('/api/users',
        procedure(const Ctx: THttpContext)
        begin
          var User := Ctx.Request.BodyAs<TUser>;
          Ctx.Response.Status(201).Json(User);
        end)
      .Listen(8080);
  ============================================================================ }

unit DeepBase.HttpServer;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Rtti,
  System.JSON,
  System.NetEncoding,
  DeepBase.Exceptions,
  System.RegularExpressions,
  System.SyncObjs,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,
  IdGlobal,
  IdURI;

type
  THttpContext = class;
  THttpRequest = class;
  THttpResponse = class;
  THttpServer = class;
  
  // ============================================================================
  // HTTP Method
  // ============================================================================
  
  THttpMethod = (hmGet, hmPost, hmPut, hmDelete, hmPatch, hmHead, hmOptions, hmAny);
  
  THttpMethodHelper = record helper for THttpMethod
    function ToString: string;
    class function FromString(const S: string): THttpMethod; static;
  end;
  
  // ============================================================================
  // Request Handler
  // ============================================================================
  
  THttpHandler = reference to procedure(const Ctx: THttpContext);
  TMiddlewareHandler = reference to procedure(const Ctx: THttpContext; Next: TProc);
  
  // ============================================================================
  // HTTP Request
  // ============================================================================
  
  THttpRequest = class
  private
    FMethod: THttpMethod;
    FPath: string;
    FRawPath: string;
    FQuery: TDictionary<string, string>;
    FParams: TDictionary<string, string>;
    FHeaders: TDictionary<string, string>;
    FBody: string;
    FContentType: string;
    FRemoteIP: string;
    FJsonBody: TJSONValue;
    function GetHeader(const Name: string): string;
    function GetParam(const Name: string): string;
    function GetQuery(const Name: string): string;
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure ParseQuery(const QueryString: string);
    function BodyAsJson: TJSONValue;
    function BodyAs<T: class, constructor>: T;
    
    property Method: THttpMethod read FMethod write FMethod;
    property Path: string read FPath write FPath;
    property RawPath: string read FRawPath write FRawPath;
    property Query[const Name: string]: string read GetQuery;
    property Params[const Name: string]: string read GetParam;
    property Headers[const Name: string]: string read GetHeader;
    property Body: string read FBody write FBody;
    property ContentType: string read FContentType write FContentType;
    property RemoteIP: string read FRemoteIP write FRemoteIP;
    property QueryDict: TDictionary<string, string> read FQuery;
    property ParamsDict: TDictionary<string, string> read FParams;
    property HeadersDict: TDictionary<string, string> read FHeaders;
  end;
  
  // ============================================================================
  // HTTP Response
  // ============================================================================
  
  THttpResponse = class
  private
    FStatusCode: Integer;
    FStatusText: string;
    FHeaders: TDictionary<string, string>;
    FBody: string;
    FBodyBytes: TBytes;  // BUG-049 FIX: Add binary body support
    FContentType: string;
    FSent: Boolean;
    FIsBinary: Boolean;  // BUG-049 FIX: Flag to indicate binary response
  public
    constructor Create;
    destructor Destroy; override;
    
    function Status(Code: Integer; const Text: string = ''): THttpResponse;
    function Header(const Name, Value: string): THttpResponse;
    function ContentType(const AType: string): THttpResponse;
    
    // Response methods
    function Text(const Content: string): THttpResponse;
    function Html(const Content: string): THttpResponse;
    function Json(const Data: TJSONValue; OwnsData: Boolean = False): THttpResponse; overload;
    function Json(const Data: string): THttpResponse; overload;
    function Bytes(const ABytes: TBytes): THttpResponse;  // BUG-049 FIX: Binary response method
    function Redirect(const Url: string; Permanent: Boolean = False): THttpResponse;
    function NotFound(const Message: string = 'Not Found'): THttpResponse;
    function BadRequest(const Message: string = 'Bad Request'): THttpResponse;
    function Unauthorized(const Message: string = 'Unauthorized'): THttpResponse;
    function Forbidden(const Message: string = 'Forbidden'): THttpResponse;
    function InternalError(const Message: string = 'Internal Server Error'): THttpResponse;
    
    property StatusCode: Integer read FStatusCode;
    property StatusText: string read FStatusText;
    property HeadersDict: TDictionary<string, string> read FHeaders;
    property BodyContent: string read FBody;
    property BodyBytesContent: TBytes read FBodyBytes;  // BUG-049 FIX
    property ContentTypeValue: string read FContentType;
    property Sent: Boolean read FSent write FSent;
    property IsBinary: Boolean read FIsBinary;  // BUG-049 FIX
  end;
  
  // ============================================================================
  // HTTP Context
  // ============================================================================
  
  THttpContext = class
  private
    FRequest: THttpRequest;
    FResponse: THttpResponse;
    FData: TDictionary<string, TValue>;
    FServer: THttpServer;
  public
    constructor Create(AServer: THttpServer);
    destructor Destroy; override;
    
    procedure SetData(const Key: string; const Value: TValue);
    function GetData(const Key: string): TValue;
    function TryGetData(const Key: string; out Value: TValue): Boolean;
    
    property Request: THttpRequest read FRequest;
    property Response: THttpResponse read FResponse;
    property Server: THttpServer read FServer;
    property Data: TDictionary<string, TValue> read FData;
  end;
  
  // ============================================================================
  // Route
  // ============================================================================
  
  TRoute = class
  private
    FMethod: THttpMethod;
    FPattern: string;
    FHandler: THttpHandler;
    FRegex: TRegEx;
    FParamNames: TList<string>;
    procedure CompilePattern;
  public
    constructor Create(AMethod: THttpMethod; const APattern: string; AHandler: THttpHandler);
    destructor Destroy; override;
    
    function Match(const Path: string; Params: TDictionary<string, string>): Boolean;
    
    property Method: THttpMethod read FMethod;
    property Pattern: string read FPattern;
    property Handler: THttpHandler read FHandler;
  end;
  
  // ============================================================================
  // Middleware
  // ============================================================================
  
  IMiddleware = interface
    ['{E8A5C8F0-1234-4567-89AB-CDEF01234567}']
    procedure Execute(const Ctx: THttpContext; Next: TProc);
  end;
  
  TMiddlewareFunc = class(TInterfacedObject, IMiddleware)
  private
    FHandler: TMiddlewareHandler;
  public
    constructor Create(AHandler: TMiddlewareHandler);
    procedure Execute(const Ctx: THttpContext; Next: TProc);
  end;
  
  // ============================================================================
  // Built-in Middleware
  // ============================================================================
  
  /// <summary>Logging middleware</summary>
  TLoggingMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FOnLog: TProc<string>;
  public
    constructor Create(AOnLog: TProc<string> = nil);
    procedure Execute(const Ctx: THttpContext; Next: TProc);
  end;
  
  /// <summary>CORS middleware</summary>
  TCorsMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FAllowOrigin: string;
    FAllowMethods: string;
    FAllowHeaders: string;
    FAllowCredentials: Boolean;
    FMaxAge: Integer;
  public
    constructor Create(const AAllowOrigin: string = '');
    
    function AllowMethods(const Value: string): TCorsMiddleware;
    function AllowHeaders(const Value: string): TCorsMiddleware;
    function AllowCredentials(Value: Boolean): TCorsMiddleware;
    function MaxAge(Value: Integer): TCorsMiddleware;
    
    procedure Execute(const Ctx: THttpContext; Next: TProc);
  end;
  
  /// <summary>Basic auth middleware</summary>
  TBasicAuthMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FRealm: string;
    FValidator: TFunc<string, string, Boolean>;
  public
    constructor Create(const ARealm: string; AValidator: TFunc<string, string, Boolean>);
    procedure Execute(const Ctx: THttpContext; Next: TProc);
  end;
  
  /// <summary>Static file middleware</summary>
  TStaticFileMiddleware = class(TInterfacedObject, IMiddleware)
  private
    FRootPath: string;
    FUrlPrefix: string;
    FMimeTypes: TDictionary<string, string>;
    procedure InitMimeTypes;
    function GetMimeType(const FileName: string): string;
  public
    constructor Create(const ARootPath: string; const AUrlPrefix: string = '/static');
    destructor Destroy; override;
    procedure Execute(const Ctx: THttpContext; Next: TProc);
  end;
  
  // ============================================================================
  // Router
  // ============================================================================
  
  TRouter = class
  private
    FRoutes: TObjectList<TRoute>;
    FPrefix: string;
  public
    constructor Create(const APrefix: string = '');
    destructor Destroy; override;
    
    function Route(Method: THttpMethod; const Pattern: string; Handler: THttpHandler): TRouter;
    function Get(const Pattern: string; Handler: THttpHandler): TRouter;
    function Post(const Pattern: string; Handler: THttpHandler): TRouter;
    function Put(const Pattern: string; Handler: THttpHandler): TRouter;
    function Delete(const Pattern: string; Handler: THttpHandler): TRouter;
    function Patch(const Pattern: string; Handler: THttpHandler): TRouter;
    function Options(const Pattern: string; Handler: THttpHandler): TRouter;
    function Any(const Pattern: string; Handler: THttpHandler): TRouter;
    
    function Match(Method: THttpMethod; const Path: string;
      out Handler: THttpHandler; Params: TDictionary<string, string>): Boolean;
    
    property Prefix: string read FPrefix;
    property Routes: TObjectList<TRoute> read FRoutes;
  end;
  
  // ============================================================================
  // HTTP Server
  // ============================================================================
  
  TServerEvent = reference to procedure(Server: THttpServer);
  TErrorHandler = reference to procedure(const Ctx: THttpContext; E: Exception);
  
  THttpServer = class
  private
    FIdServer: TIdHTTPServer;
    FRouter: TRouter;
    FMiddlewares: TList<IMiddleware>;
    FOnStart: TServerEvent;
    FOnStop: TServerEvent;
    FErrorHandler: TErrorHandler;
    FPort: Integer;
    FActive: Boolean;
    FLock: TCriticalSection;
    FMaxRequestBodySize: Int64;
    
    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure ProcessRequest(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
    procedure RunMiddlewareChain(const Ctx: THttpContext; Index: Integer; FinalHandler: TProc);
  public
    constructor Create;
    destructor Destroy; override;
    
    // Middleware
    function Use(Middleware: IMiddleware): THttpServer; overload;
    function Use(Handler: TMiddlewareHandler): THttpServer; overload;
    
    // Mount sub-router
    function Mount(const Prefix: string; Router: TRouter): THttpServer;
    
    // Route definition
    function Route(Method: THttpMethod; const Pattern: string; Handler: THttpHandler): THttpServer;
    function Get(const Pattern: string; Handler: THttpHandler): THttpServer;
    function Post(const Pattern: string; Handler: THttpHandler): THttpServer;
    function Put(const Pattern: string; Handler: THttpHandler): THttpServer;
    function Delete(const Pattern: string; Handler: THttpHandler): THttpServer;
    function Patch(const Pattern: string; Handler: THttpHandler): THttpServer;
    function Options(const Pattern: string; Handler: THttpHandler): THttpServer;
    function Any(const Pattern: string; Handler: THttpHandler): THttpServer;
    
    // Events
    function OnStart(Handler: TServerEvent): THttpServer;
    function OnStop(Handler: TServerEvent): THttpServer;
    function OnError(Handler: TErrorHandler): THttpServer;
    
    // Server control
    procedure Listen(APort: Integer; const AHost: string = '0.0.0.0');
    procedure Stop;
    
    property Port: Integer read FPort;
    property Active: Boolean read FActive;
    property Router: TRouter read FRouter;
    /// <summary>Maximum allowed request body size in bytes (default 10 MB).</summary>
    property MaxRequestBodySize: Int64 read FMaxRequestBodySize write FMaxRequestBodySize;
  end;

// Helper function to create JSON response
function JsonResponse(const Pairs: array of const): TJSONObject;

implementation

uses
  System.IOUtils,
  REST.Json;

function JsonResponse(const Pairs: array of const): TJSONObject;
var
  I: Integer;
  Key: string;
begin
  Result := TJSONObject.Create;
  I := 0;
  while I < Length(Pairs) - 1 do
  begin
    case Pairs[I].VType of
      vtString: Key := string(Pairs[I].VString^);
      vtAnsiString: Key := string(AnsiString(Pairs[I].VAnsiString));
      vtWideString: Key := WideString(Pairs[I].VWideString);
      vtUnicodeString: Key := string(Pairs[I].VUnicodeString);
    else
      Inc(I, 2);
      Continue;
    end;
    
    case Pairs[I+1].VType of
      vtInteger:
        Result.AddPair(Key, TJSONNumber.Create(Pairs[I+1].VInteger));
      vtBoolean:
        Result.AddPair(Key, TJSONBool.Create(Pairs[I+1].VBoolean));
      vtString:
        Result.AddPair(Key, string(Pairs[I+1].VString^));
      vtAnsiString:
        Result.AddPair(Key, string(AnsiString(Pairs[I+1].VAnsiString)));
      vtWideString:
        Result.AddPair(Key, WideString(Pairs[I+1].VWideString));
      vtUnicodeString:
        Result.AddPair(Key, string(Pairs[I+1].VUnicodeString));
      vtExtended:
        Result.AddPair(Key, TJSONNumber.Create(Pairs[I+1].VExtended^));
      vtInt64:
        Result.AddPair(Key, TJSONNumber.Create(Pairs[I+1].VInt64^));
    end;
    
    Inc(I, 2);
  end;
end;

// ============================================================================
// THttpMethodHelper
// ============================================================================

function THttpMethodHelper.ToString: string;
const
  Names: array[THttpMethod] of string = ('GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'HEAD', 'OPTIONS', '*');
begin
  Result := Names[Self];
end;

class function THttpMethodHelper.FromString(const S: string): THttpMethod;
var
  Upper: string;
begin
  Upper := UpperCase(S);
  if Upper = 'GET' then Result := hmGet
  else if Upper = 'POST' then Result := hmPost
  else if Upper = 'PUT' then Result := hmPut
  else if Upper = 'DELETE' then Result := hmDelete
  else if Upper = 'PATCH' then Result := hmPatch
  else if Upper = 'HEAD' then Result := hmHead
  else if Upper = 'OPTIONS' then Result := hmOptions
  else Result := hmAny;
end;

// ============================================================================
// THttpRequest
// ============================================================================

constructor THttpRequest.Create;
begin
  inherited Create;
  FQuery := TDictionary<string, string>.Create;
  FParams := TDictionary<string, string>.Create;
  FHeaders := TDictionary<string, string>.Create;
end;

destructor THttpRequest.Destroy;
begin
  FreeAndNil(FQuery);
  FreeAndNil(FParams);
  FreeAndNil(FHeaders);
  FreeAndNil(FJsonBody);
  inherited;
end;

function THttpRequest.GetHeader(const Name: string): string;
begin
  if not FHeaders.TryGetValue(LowerCase(Name), Result) then
    Result := '';
end;

function THttpRequest.GetParam(const Name: string): string;
begin
  if not FParams.TryGetValue(Name, Result) then
    Result := '';
end;

function THttpRequest.GetQuery(const Name: string): string;
begin
  if not FQuery.TryGetValue(Name, Result) then
    Result := '';
end;

procedure THttpRequest.ParseQuery(const QueryString: string);
var
  Pairs: TArray<string>;
  Pair: string;
  Pos: Integer;
  Key, Value: string;
begin
  FQuery.Clear;
  if QueryString = '' then Exit;
  
  Pairs := QueryString.Split(['&']);
  for Pair in Pairs do
  begin
    Pos := System.Pos('=', Pair);
    if Pos > 0 then
    begin
      Key := TNetEncoding.URL.Decode(Copy(Pair, 1, Pos - 1));
      Value := TNetEncoding.URL.Decode(Copy(Pair, Pos + 1, MaxInt));
      FQuery.AddOrSetValue(Key, Value);
    end
    else
      FQuery.AddOrSetValue(TNetEncoding.URL.Decode(Pair), '');
  end;
end;

function THttpRequest.BodyAsJson: TJSONValue;
begin
  if not Assigned(FJsonBody) and (FBody <> '') then
    FJsonBody := TJSONObject.ParseJSONValue(FBody);
  Result := FJsonBody;
end;

function THttpRequest.BodyAs<T>: T;
begin
  Result := TJson.JsonToObject<T>(FBody);
end;

// ============================================================================
// THttpResponse
// ============================================================================

constructor THttpResponse.Create;
begin
  inherited Create;
  FStatusCode := 200;
  FStatusText := 'OK';
  FHeaders := TDictionary<string, string>.Create;
  FContentType := 'text/html; charset=utf-8';
end;

destructor THttpResponse.Destroy;
begin
  FreeAndNil(FHeaders);
  inherited;
end;

function THttpResponse.Status(Code: Integer; const Text: string): THttpResponse;
begin
  FStatusCode := Code;
  if Text <> '' then
    FStatusText := Text
  else
    case Code of
      200: FStatusText := 'OK';
      201: FStatusText := 'Created';
      204: FStatusText := 'No Content';
      301: FStatusText := 'Moved Permanently';
      302: FStatusText := 'Found';
      304: FStatusText := 'Not Modified';
      400: FStatusText := 'Bad Request';
      401: FStatusText := 'Unauthorized';
      403: FStatusText := 'Forbidden';
      404: FStatusText := 'Not Found';
      405: FStatusText := 'Method Not Allowed';
      500: FStatusText := 'Internal Server Error';
      502: FStatusText := 'Bad Gateway';
      503: FStatusText := 'Service Unavailable';
    else
      FStatusText := 'Unknown';
    end;
  Result := Self;
end;

function THttpResponse.Header(const Name, Value: string): THttpResponse;
begin
  FHeaders.AddOrSetValue(Name, Value);
  Result := Self;
end;

function THttpResponse.ContentType(const AType: string): THttpResponse;
begin
  FContentType := AType;
  Result := Self;
end;

function THttpResponse.Text(const Content: string): THttpResponse;
begin
  FContentType := 'text/plain; charset=utf-8';
  FBody := Content;
  Result := Self;
end;

function THttpResponse.Html(const Content: string): THttpResponse;
begin
  FContentType := 'text/html; charset=utf-8';
  FBody := Content;
  Result := Self;
end;

function THttpResponse.Json(const Data: TJSONValue; OwnsData: Boolean): THttpResponse;
begin
  FContentType := 'application/json; charset=utf-8';
  FBody := Data.ToJSON;
  if OwnsData then
    Data.Free;
  Result := Self;
end;

function THttpResponse.Json(const Data: string): THttpResponse;
begin
  FContentType := 'application/json; charset=utf-8';
  FBody := Data;
  Result := Self;
end;

// BUG-049 FIX: Binary response method for static files
function THttpResponse.Bytes(const ABytes: TBytes): THttpResponse;
begin
  FBodyBytes := ABytes;
  FIsBinary := True;
  Result := Self;
end;

function THttpResponse.Redirect(const Url: string; Permanent: Boolean): THttpResponse;
begin
  if Permanent then
    Status(301)
  else
    Status(302);
  Header('Location', Url);
  Result := Self;
end;

function THttpResponse.NotFound(const Message: string): THttpResponse;
begin
  Status(404);
  Json(TJSONObject.Create.AddPair('error', Message), True);
  Result := Self;
end;

function THttpResponse.BadRequest(const Message: string): THttpResponse;
begin
  Status(400);
  Json(TJSONObject.Create.AddPair('error', Message), True);
  Result := Self;
end;

function THttpResponse.Unauthorized(const Message: string): THttpResponse;
begin
  Status(401);
  Json(TJSONObject.Create.AddPair('error', Message), True);
  Result := Self;
end;

function THttpResponse.Forbidden(const Message: string): THttpResponse;
begin
  Status(403);
  Json(TJSONObject.Create.AddPair('error', Message), True);
  Result := Self;
end;

function THttpResponse.InternalError(const Message: string): THttpResponse;
begin
  Status(500);
  Json(TJSONObject.Create.AddPair('error', Message), True);
  Result := Self;
end;

// ============================================================================
// THttpContext
// ============================================================================

constructor THttpContext.Create(AServer: THttpServer);
begin
  inherited Create;
  FServer := AServer;
  FRequest := THttpRequest.Create;
  FResponse := THttpResponse.Create;
  FData := TDictionary<string, TValue>.Create;
end;

destructor THttpContext.Destroy;
begin
  FreeAndNil(FRequest);
  FreeAndNil(FResponse);
  FreeAndNil(FData);
  inherited;
end;

procedure THttpContext.SetData(const Key: string; const Value: TValue);
begin
  FData.AddOrSetValue(Key, Value);
end;

function THttpContext.GetData(const Key: string): TValue;
begin
  if not FData.TryGetValue(Key, Result) then
    Result := TValue.Empty;
end;

function THttpContext.TryGetData(const Key: string; out Value: TValue): Boolean;
begin
  Result := FData.TryGetValue(Key, Value);
end;

// ============================================================================
// TRoute
// ============================================================================

constructor TRoute.Create(AMethod: THttpMethod; const APattern: string; AHandler: THttpHandler);
begin
  inherited Create;
  FMethod := AMethod;
  FPattern := APattern;
  FHandler := AHandler;
  FParamNames := TList<string>.Create;
  CompilePattern;
end;

destructor TRoute.Destroy;
begin
  FreeAndNil(FParamNames);
  inherited;
end;

procedure TRoute.CompilePattern;
var
  RegexPattern: string;
  Match: TMatch;
begin
  // Convert route pattern to regex
  // :param becomes named group
  RegexPattern := FPattern;
  
  // Find all :param patterns
  Match := TRegEx.Match(FPattern, ':([a-zA-Z_][a-zA-Z0-9_]*)');
  while Match.Success do
  begin
    FParamNames.Add(Match.Groups[1].Value);
    Match := Match.NextMatch;
  end;
  
  // Escape special chars and convert params
  RegexPattern := TRegEx.Replace(RegexPattern, '[\.\+\*\?\^\$\{\}\[\]\|\\]', '\$0');
  RegexPattern := TRegEx.Replace(RegexPattern, ':([a-zA-Z_][a-zA-Z0-9_]*)', '([^/]+)');
  RegexPattern := '^' + RegexPattern + '$';
  
  FRegex := TRegEx.Create(RegexPattern, [roIgnoreCase]);
end;

function TRoute.Match(const Path: string; Params: TDictionary<string, string>): Boolean;
var
  M: TMatch;
  I: Integer;
begin
  M := FRegex.Match(Path);
  Result := M.Success;
  
  if Result and (M.Groups.Count > 1) then
  begin
    for I := 0 to FParamNames.Count - 1 do
    begin
      if I + 1 < M.Groups.Count then
        Params.AddOrSetValue(FParamNames[I], M.Groups[I + 1].Value);
    end;
  end;
end;

// ============================================================================
// TMiddlewareFunc
// ============================================================================

constructor TMiddlewareFunc.Create(AHandler: TMiddlewareHandler);
begin
  inherited Create;
  FHandler := AHandler;
end;

procedure TMiddlewareFunc.Execute(const Ctx: THttpContext; Next: TProc);
begin
  if Assigned(FHandler) then
    FHandler(Ctx, Next)
  else
    Next();
end;

// ============================================================================
// TLoggingMiddleware
// ============================================================================

constructor TLoggingMiddleware.Create(AOnLog: TProc<string>);
begin
  inherited Create;
  FOnLog := AOnLog;
end;

procedure TLoggingMiddleware.Execute(const Ctx: THttpContext; Next: TProc);
var
  StartTime: TDateTime;
  Elapsed: Integer;
  LogMsg: string;
begin
  StartTime := Now;
  
  Next();
  
  Elapsed := Round((Now - StartTime) * 24 * 60 * 60 * 1000);
  LogMsg := Format('[%s] %s %s %d - %dms',
    [FormatDateTime('yyyy-mm-dd hh:nn:ss', Now),
     Ctx.Request.Method.ToString,
     Ctx.Request.Path,
     Ctx.Response.StatusCode,
     Elapsed]);
  
  if Assigned(FOnLog) then
    FOnLog(LogMsg)
  else
    WriteLn(LogMsg);
end;

// ============================================================================
// TCorsMiddleware
// ============================================================================

constructor TCorsMiddleware.Create(const AAllowOrigin: string);
begin
  inherited Create;
  FAllowOrigin := AAllowOrigin;
  FAllowMethods := 'GET, POST, PUT, DELETE, PATCH, OPTIONS';
  FAllowHeaders := 'Content-Type, Authorization, X-Requested-With';
  FAllowCredentials := False;
  FMaxAge := 86400;
end;

function TCorsMiddleware.AllowMethods(const Value: string): TCorsMiddleware;
begin
  FAllowMethods := Value;
  Result := Self;
end;

function TCorsMiddleware.AllowHeaders(const Value: string): TCorsMiddleware;
begin
  FAllowHeaders := Value;
  Result := Self;
end;

function TCorsMiddleware.AllowCredentials(Value: Boolean): TCorsMiddleware;
begin
  FAllowCredentials := Value;
  Result := Self;
end;

function TCorsMiddleware.MaxAge(Value: Integer): TCorsMiddleware;
begin
  FMaxAge := Value;
  Result := Self;
end;

procedure TCorsMiddleware.Execute(const Ctx: THttpContext; Next: TProc);
begin
  if FAllowOrigin <> '' then
  begin
    Ctx.Response.Header('Access-Control-Allow-Origin', FAllowOrigin);
    Ctx.Response.Header('Access-Control-Allow-Methods', FAllowMethods);
    Ctx.Response.Header('Access-Control-Allow-Headers', FAllowHeaders);

    if FAllowCredentials then
      Ctx.Response.Header('Access-Control-Allow-Credentials', 'true');

    Ctx.Response.Header('Access-Control-Max-Age', IntToStr(FMaxAge));
  end;
  
  // Handle preflight
  if Ctx.Request.Method = hmOptions then
  begin
    Ctx.Response.Status(204);
    Exit;
  end;
  
  Next();
end;

// ============================================================================
// TBasicAuthMiddleware
// ============================================================================

constructor TBasicAuthMiddleware.Create(const ARealm: string;
  AValidator: TFunc<string, string, Boolean>);
begin
  inherited Create;
  FRealm := ARealm;
  FValidator := AValidator;
end;

procedure TBasicAuthMiddleware.Execute(const Ctx: THttpContext; Next: TProc);
var
  AuthHeader: string;
  Decoded: string;
  Parts: TArray<string>;
  Username, Password: string;
begin
  AuthHeader := Ctx.Request.Headers['Authorization'];
  
  if AuthHeader.StartsWith('Basic ', True) then
  begin
    Decoded := TNetEncoding.Base64.Decode(Copy(AuthHeader, 7, MaxInt));
    Parts := Decoded.Split([':'], 2);
    
    if Length(Parts) = 2 then
    begin
      Username := Parts[0];
      Password := Parts[1];
      
      if Assigned(FValidator) and FValidator(Username, Password) then
      begin
        Ctx.SetData('auth.username', TValue.From<string>(Username));
        Next();
        Exit;
      end;
    end;
  end;
  
  Ctx.Response
    .Status(401)
    .Header('WWW-Authenticate', Format('Basic realm="%s"', [FRealm]))
    .Json('{"error":"Unauthorized"}');
end;

// ============================================================================
// TStaticFileMiddleware
// ============================================================================

constructor TStaticFileMiddleware.Create(const ARootPath: string; const AUrlPrefix: string);
begin
  inherited Create;
  FRootPath := ARootPath;
  FUrlPrefix := AUrlPrefix;
  FMimeTypes := TDictionary<string, string>.Create;
  InitMimeTypes;
end;

destructor TStaticFileMiddleware.Destroy;
begin
  FreeAndNil(FMimeTypes);
  inherited;
end;

procedure TStaticFileMiddleware.InitMimeTypes;
begin
  FMimeTypes.Add('.html', 'text/html');
  FMimeTypes.Add('.htm', 'text/html');
  FMimeTypes.Add('.css', 'text/css');
  FMimeTypes.Add('.js', 'application/javascript');
  FMimeTypes.Add('.json', 'application/json');
  FMimeTypes.Add('.xml', 'application/xml');
  FMimeTypes.Add('.txt', 'text/plain');
  FMimeTypes.Add('.png', 'image/png');
  FMimeTypes.Add('.jpg', 'image/jpeg');
  FMimeTypes.Add('.jpeg', 'image/jpeg');
  FMimeTypes.Add('.gif', 'image/gif');
  FMimeTypes.Add('.svg', 'image/svg+xml');
  FMimeTypes.Add('.ico', 'image/x-icon');
  FMimeTypes.Add('.woff', 'font/woff');
  FMimeTypes.Add('.woff2', 'font/woff2');
  FMimeTypes.Add('.ttf', 'font/ttf');
  FMimeTypes.Add('.pdf', 'application/pdf');
  FMimeTypes.Add('.zip', 'application/zip');
end;

function TStaticFileMiddleware.GetMimeType(const FileName: string): string;
var
  Ext: string;
begin
  Ext := LowerCase(ExtractFileExt(FileName));
  if not FMimeTypes.TryGetValue(Ext, Result) then
    Result := 'application/octet-stream';
end;

procedure TStaticFileMiddleware.Execute(const Ctx: THttpContext; Next: TProc);
var
  Path, FilePath, RelPath, RootPath: string;
  MimeType: string;
  Bytes: TBytes;
begin
  Path := Ctx.Request.Path;
  
  if not Path.StartsWith(FUrlPrefix) then
  begin
    Next();
    Exit;
  end;
  
  RelPath := Copy(Path, Length(FUrlPrefix) + 1, MaxInt);
  if RelPath.StartsWith('/') then
    RelPath := Copy(RelPath, 2, MaxInt);

  RelPath := TNetEncoding.URL.Decode(RelPath);
  if (RelPath = '') or TPath.IsPathRooted(RelPath) or RelPath.Contains('\') then
  begin
    Ctx.Response.Status(403).Json('{"error":"Forbidden"}');
    Exit;
  end;

  RootPath := TPath.GetFullPath(FRootPath);
  FilePath := TPath.GetFullPath(TPath.Combine(RootPath, RelPath));
  if not RootPath.EndsWith(TPath.DirectorySeparatorChar) then
    RootPath := RootPath + TPath.DirectorySeparatorChar;

  if not FilePath.StartsWith(RootPath, True) then
  begin
    Ctx.Response.Status(403).Json('{"error":"Forbidden"}');
    Exit;
  end;
  
  if TFile.Exists(FilePath) then
  begin
    try
      MimeType := GetMimeType(FilePath);
      // BUG-049 FIX: Use binary read for all files to prevent corruption
      Bytes := TFile.ReadAllBytes(FilePath);
      Ctx.Response
        .ContentType(MimeType)
        .Bytes(Bytes);
    except
      on E: Exception do
        Ctx.Response.InternalError('Failed to read file');
    end;
  end
  else
    Next();
end;

// ============================================================================
// TRouter
// ============================================================================

constructor TRouter.Create(const APrefix: string);
begin
  inherited Create;
  FPrefix := APrefix;
  FRoutes := TObjectList<TRoute>.Create(True);
end;

destructor TRouter.Destroy;
begin
  FreeAndNil(FRoutes);
  inherited;
end;

function TRouter.Route(Method: THttpMethod; const Pattern: string;
  Handler: THttpHandler): TRouter;
begin
  FRoutes.Add(TRoute.Create(Method, FPrefix + Pattern, Handler));
  Result := Self;
end;

function TRouter.Get(const Pattern: string; Handler: THttpHandler): TRouter;
begin
  Result := Route(hmGet, Pattern, Handler);
end;

function TRouter.Post(const Pattern: string; Handler: THttpHandler): TRouter;
begin
  Result := Route(hmPost, Pattern, Handler);
end;

function TRouter.Put(const Pattern: string; Handler: THttpHandler): TRouter;
begin
  Result := Route(hmPut, Pattern, Handler);
end;

function TRouter.Delete(const Pattern: string; Handler: THttpHandler): TRouter;
begin
  Result := Route(hmDelete, Pattern, Handler);
end;

function TRouter.Patch(const Pattern: string; Handler: THttpHandler): TRouter;
begin
  Result := Route(hmPatch, Pattern, Handler);
end;

function TRouter.Options(const Pattern: string; Handler: THttpHandler): TRouter;
begin
  Result := Route(hmOptions, Pattern, Handler);
end;

function TRouter.Any(const Pattern: string; Handler: THttpHandler): TRouter;
begin
  Result := Route(hmAny, Pattern, Handler);
end;

function TRouter.Match(Method: THttpMethod; const Path: string;
  out Handler: THttpHandler; Params: TDictionary<string, string>): Boolean;
var
  R: TRoute;
begin
  Result := False;
  Handler := nil;
  
  for R in FRoutes do
  begin
    if ((R.Method = Method) or (R.Method = hmAny)) and R.Match(Path, Params) then
    begin
      Handler := R.Handler;
      Exit(True);
    end;
  end;
end;

// ============================================================================
// THttpServer
// ============================================================================

constructor THttpServer.Create;
begin
  inherited Create;
  FRouter := TRouter.Create;
  FMiddlewares := TList<IMiddleware>.Create;
  FLock := TCriticalSection.Create;
  FMaxRequestBodySize := 10 * 1024 * 1024; // 10 MB default

  FIdServer := TIdHTTPServer.Create(nil);
  FIdServer.OnCommandGet := DoCommandGet;
  FIdServer.OnCommandOther := DoCommandGet;
end;

destructor THttpServer.Destroy;
begin
  Stop;
  FreeAndNil(FIdServer);
  FreeAndNil(FRouter);
  FreeAndNil(FMiddlewares);
  FreeAndNil(FLock);
  inherited;
end;

function THttpServer.Use(Middleware: IMiddleware): THttpServer;
begin
  FMiddlewares.Add(Middleware);
  Result := Self;
end;

function THttpServer.Use(Handler: TMiddlewareHandler): THttpServer;
begin
  Result := Use(TMiddlewareFunc.Create(Handler));
end;

function THttpServer.Mount(const Prefix: string; Router: TRouter): THttpServer;
var
  R: TRoute;
begin
  for R in Router.Routes do
    FRouter.Route(R.Method, Prefix + R.Pattern, R.Handler);
  Result := Self;
end;

function THttpServer.Route(Method: THttpMethod; const Pattern: string;
  Handler: THttpHandler): THttpServer;
begin
  FRouter.Route(Method, Pattern, Handler);
  Result := Self;
end;

function THttpServer.Get(const Pattern: string; Handler: THttpHandler): THttpServer;
begin
  Result := Route(hmGet, Pattern, Handler);
end;

function THttpServer.Post(const Pattern: string; Handler: THttpHandler): THttpServer;
begin
  Result := Route(hmPost, Pattern, Handler);
end;

function THttpServer.Put(const Pattern: string; Handler: THttpHandler): THttpServer;
begin
  Result := Route(hmPut, Pattern, Handler);
end;

function THttpServer.Delete(const Pattern: string; Handler: THttpHandler): THttpServer;
begin
  Result := Route(hmDelete, Pattern, Handler);
end;

function THttpServer.Patch(const Pattern: string; Handler: THttpHandler): THttpServer;
begin
  Result := Route(hmPatch, Pattern, Handler);
end;

function THttpServer.Options(const Pattern: string; Handler: THttpHandler): THttpServer;
begin
  Result := Route(hmOptions, Pattern, Handler);
end;

function THttpServer.Any(const Pattern: string; Handler: THttpHandler): THttpServer;
begin
  Result := Route(hmAny, Pattern, Handler);
end;

function THttpServer.OnStart(Handler: TServerEvent): THttpServer;
begin
  FOnStart := Handler;
  Result := Self;
end;

function THttpServer.OnStop(Handler: TServerEvent): THttpServer;
begin
  FOnStop := Handler;
  Result := Self;
end;

function THttpServer.OnError(Handler: TErrorHandler): THttpServer;
begin
  FErrorHandler := Handler;
  Result := Self;
end;

procedure THttpServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
begin
  ProcessRequest(AContext, ARequestInfo, AResponseInfo);
end;

procedure THttpServer.ProcessRequest(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo; AResponseInfo: TIdHTTPResponseInfo);
var
  Ctx: THttpContext;
  Handler: THttpHandler;
  I: Integer;
  QueryStr: string;
  Uri: TIdURI;
  Pair: TPair<string, string>;
begin
  Ctx := THttpContext.Create(Self);
  try
    // Parse request
    Ctx.Request.Method := THttpMethod.FromString(ARequestInfo.Command);
    Ctx.Request.RawPath := ARequestInfo.Document;
    Ctx.Request.RemoteIP := AContext.Binding.PeerIP;
    
    // Parse URI
    Uri := TIdURI.Create(ARequestInfo.URI);
    try
      Ctx.Request.Path := Uri.Document;
      if Uri.Params <> '' then
        Ctx.Request.ParseQuery(Copy(Uri.Params, 2, MaxInt)); // Remove leading ?
    finally
      Uri.Free;
    end;
    
    // Copy headers
    for I := 0 to ARequestInfo.RawHeaders.Count - 1 do
    begin
      var Pos := System.Pos(':', ARequestInfo.RawHeaders[I]);
      if Pos > 0 then
      begin
        var Key := LowerCase(Trim(Copy(ARequestInfo.RawHeaders[I], 1, Pos - 1)));
        var Value := Trim(Copy(ARequestInfo.RawHeaders[I], Pos + 1, MaxInt));
        Ctx.Request.HeadersDict.AddOrSetValue(Key, Value);
      end;
    end;

    // Enforce request body size limit (HTTP 413 Payload Too Large)
    if (FMaxRequestBodySize > 0) and (ARequestInfo.ContentLength > FMaxRequestBodySize) then
    begin
      AResponseInfo.ResponseNo := 413;
      AResponseInfo.ResponseText := 'Payload Too Large';
      AResponseInfo.ContentType := 'application/json; charset=utf-8';
      AResponseInfo.ContentText :=
        '{"error":"Request body exceeds maximum allowed size"}';
      Exit;
    end;

    // Read body
    if Assigned(ARequestInfo.PostStream) then
    begin
      var SS := TStringStream.Create('', TEncoding.UTF8);
      try
        SS.CopyFrom(ARequestInfo.PostStream, 0);
        Ctx.Request.Body := SS.DataString;
      finally
        SS.Free;
      end;
    end;
    
    Ctx.Request.ContentType := ARequestInfo.ContentType;
    
    // Find matching route
    if FRouter.Match(Ctx.Request.Method, Ctx.Request.Path, Handler, Ctx.Request.ParamsDict) then
    begin
      // Run middleware chain
      RunMiddlewareChain(Ctx, 0,
        procedure
        begin
          try
            Handler(Ctx);
          except
            on E: Exception do
            begin
              if Assigned(FErrorHandler) then
                FErrorHandler(Ctx, E)
              else
                Ctx.Response.InternalError;
            end;
          end;
        end);
    end
    else
      Ctx.Response.NotFound('Route not found: ' + Ctx.Request.Path);
    
    // Write response
    AResponseInfo.ResponseNo := Ctx.Response.StatusCode;
    AResponseInfo.ResponseText := Ctx.Response.StatusText;
    AResponseInfo.ContentType := Ctx.Response.ContentTypeValue;
    
    // BUG-049 FIX: Handle binary responses properly
    if Ctx.Response.IsBinary then
    begin
      AResponseInfo.ContentStream := TMemoryStream.Create;
      AResponseInfo.ContentStream.Write(Ctx.Response.BodyBytesContent[0], Length(Ctx.Response.BodyBytesContent));
      AResponseInfo.ContentStream.Position := 0;
      AResponseInfo.FreeContentStream := True;
    end
    else
      AResponseInfo.ContentText := Ctx.Response.BodyContent;
    
    for Pair in Ctx.Response.HeadersDict do
      AResponseInfo.CustomHeaders.AddValue(Pair.Key, Pair.Value);
  finally
    Ctx.Free;
  end;
end;

procedure THttpServer.RunMiddlewareChain(const Ctx: THttpContext; Index: Integer;
  FinalHandler: TProc);
begin
  if Index >= FMiddlewares.Count then
    FinalHandler()
  else
    FMiddlewares[Index].Execute(Ctx,
      procedure
      begin
        RunMiddlewareChain(Ctx, Index + 1, FinalHandler);
      end);
end;

procedure THttpServer.Listen(APort: Integer; const AHost: string);
begin
  FLock.Enter;
  try
    if FActive then
      raise EServerAlreadyRunningException.Create('Server is already running');
    
    FPort := APort;
    FIdServer.DefaultPort := APort;
    FIdServer.Active := True;
    FActive := True;
    
    if Assigned(FOnStart) then
      FOnStart(Self);
  finally
    FLock.Leave;
  end;
end;

procedure THttpServer.Stop;
begin
  FLock.Enter;
  try
    if not FActive then Exit;
    
    FIdServer.Active := False;
    FActive := False;
    
    if Assigned(FOnStop) then
      FOnStop(Self);
  finally
    FLock.Leave;
  end;
end;

end.
