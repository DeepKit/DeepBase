{*******************************************************}
{                                                       }
{       DeepBase Framework                               }
{       Web API Core                                    }
{                                                       }
{       版权所有 (C) 2025                               }
{                                                       }
{*******************************************************}

unit DeepBase.WebAPI.Core;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.NetEncoding,
  System.SyncObjs,
  System.DateUtils,
  System.Hash,
  System.RegularExpressions,
  System.Rtti,
  IdHTTPServer,
  IdContext,
  IdCustomHTTPServer,
  IdSSLOpenSSL,
  IdGlobal;

type
  // HTTP 方法枚举
  THttpMethod = (hmGet, hmPost, hmPut, hmPatch, hmDelete, hmOptions, hmHead);
  THttpMethods = set of THttpMethod;

  // HTTP 状态码
  THttpStatus = class
  public
    const OK = 200;
    const Created = 201;
    const Accepted = 202;
    const NoContent = 204;
    const MovedPermanently = 301;
    const Found = 302;
    const NotModified = 304;
    const BadRequest = 400;
    const Unauthorized = 401;
    const Forbidden = 403;
    const NotFound = 404;
    const MethodNotAllowed = 405;
    const Conflict = 409;
    const Gone = 410;
    const UnprocessableEntity = 422;
    const TooManyRequests = 429;
    const InternalServerError = 500;
    const NotImplemented = 501;
    const BadGateway = 502;
    const ServiceUnavailable = 503;
  end;

  // 内容类型
  TContentType = class
  public
    const JSON = 'application/json';
    const XML = 'application/xml';
    const HTML = 'text/html';
    const Plain = 'text/plain';
    const FormUrlEncoded = 'application/x-www-form-urlencoded';
    const MultipartFormData = 'multipart/form-data';
    const OctetStream = 'application/octet-stream';
    const CSS = 'text/css';
    const JavaScript = 'application/javascript';
    const PNG = 'image/png';
    const JPEG = 'image/jpeg';
    const GIF = 'image/gif';
    const SVG = 'image/svg+xml';
    const PDF = 'application/pdf';
  end;

  // 前置声明
  TApiRequest = class;
  TApiResponse = class;
  TApiContext = class;
  TApiRouter = class;
  TApiServer = class;

  // 路由参数
  TRouteParams = TDictionary<string, string>;
  TQueryParams = TDictionary<string, string>;
  THeaders = TDictionary<string, string>;

  // 中间件处理函数
  TMiddlewareFunc = reference to procedure(AContext: TApiContext; ANext: TProc);
  TRouteHandler = reference to procedure(AContext: TApiContext);
  TExceptionHandler = reference to procedure(AContext: TApiContext; E: Exception);

  // 上传文件信息
  TUploadedFile = class
  private
    FFieldName: string;
    FFileName: string;
    FContentType: string;
    FData: TBytes;
    FSize: Int64;
  public
    property FieldName: string read FFieldName write FFieldName;
    property FileName: string read FFileName write FFileName;
    property ContentType: string read FContentType write FContentType;
    property Data: TBytes read FData write FData;
    property Size: Int64 read FSize write FSize;

    procedure SaveToFile(const APath: string);
    function SaveToStream(AStream: TStream): Int64;
  end;

  // API 请求
  TApiRequest = class
  private
    FMethod: THttpMethod;
    FPath: string;
    FRawPath: string;
    FQueryString: string;
    FHeaders: THeaders;
    FRouteParams: TRouteParams;
    FQueryParams: TQueryParams;
    FBody: TBytes;
    FContentType: string;
    FRemoteIP: string;
    FFiles: TObjectList<TUploadedFile>;
    FFormFields: TDictionary<string, string>;
    FStartTime: TDateTime;
    FRequestId: string;

    function GetBodyAsString: string;
    function GetBodyAsJSON: TJSONValue;
    procedure ParseQueryString;
    procedure ParseFormData;
    procedure ParseMultipartData(const ABoundary: string);
  public
    constructor Create;
    destructor Destroy; override;

    property Method: THttpMethod read FMethod write FMethod;
    property Path: string read FPath write FPath;
    property RawPath: string read FRawPath write FRawPath;
    property QueryString: string read FQueryString write FQueryString;
    property Headers: THeaders read FHeaders;
    property RouteParams: TRouteParams read FRouteParams;
    property QueryParams: TQueryParams read FQueryParams;
    property Body: TBytes read FBody write FBody;
    property BodyAsString: string read GetBodyAsString;
    property BodyAsJSON: TJSONValue read GetBodyAsJSON;
    property ContentType: string read FContentType write FContentType;
    property RemoteIP: string read FRemoteIP write FRemoteIP;
    property Files: TObjectList<TUploadedFile> read FFiles;
    property FormFields: TDictionary<string, string> read FFormFields;
    property StartTime: TDateTime read FStartTime write FStartTime;
    property RequestId: string read FRequestId write FRequestId;

    function GetHeader(const AName: string; const ADefault: string = ''): string;
    function GetRouteParam(const AName: string; const ADefault: string = ''): string;
    function GetQueryParam(const AName: string; const ADefault: string = ''): string;
    function GetFormField(const AName: string; const ADefault: string = ''): string;
    function GetFile(const AFieldName: string): TUploadedFile;
    function HasHeader(const AName: string): Boolean;
    function HasQueryParam(const AName: string): Boolean;
    function IsJSON: Boolean;
    function IsFormData: Boolean;
    function IsMultipart: Boolean;

    procedure Initialize;
  end;

  // API 响应
  TApiResponse = class
  private
    FStatusCode: Integer;
    FStatusText: string;
    FHeaders: THeaders;
    FBody: TBytes;
    FContentType: string;
    FSent: Boolean;
    FCookies: TStringList;

    procedure SetStatusCode(const Value: Integer);
    function GetBodyAsString: string;
    procedure SetBodyAsString(const Value: string);
    function SendErrorResponse(AStatusCode: Integer; const AMessage: string): TApiResponse;
  public
    constructor Create;
    destructor Destroy; override;

    property StatusCode: Integer read FStatusCode write SetStatusCode;
    property StatusText: string read FStatusText write FStatusText;
    property Headers: THeaders read FHeaders;
    property Body: TBytes read FBody write FBody;
    property BodyAsString: string read GetBodyAsString write SetBodyAsString;
    property ContentType: string read FContentType write FContentType;
    property Sent: Boolean read FSent write FSent;
    property Cookies: TStringList read FCookies;

    // 设置头部
    function SetHeader(const AName, AValue: string): TApiResponse;
    function SetCookie(const AName, AValue: string;
      AExpires: TDateTime = 0; const APath: string = '/';
      AHttpOnly: Boolean = True; ASecure: Boolean = False): TApiResponse;

    // 发送响应
    function Send(const ABody: string = ''): TApiResponse; overload;
    function Send(const ABody: TBytes): TApiResponse; overload;
    function SendJSON(AValue: TJSONValue; AOwnsValue: Boolean = True): TApiResponse;
    function SendFile(const AFilePath: string): TApiResponse;
    function SendStream(AStream: TStream; const AContentType: string = ''): TApiResponse;

    // 快捷方法
    function OK(const ABody: string = ''): TApiResponse;
    function Created(const ALocation: string = ''): TApiResponse;
    function NoContent: TApiResponse;
    function BadRequest(const AMessage: string = 'Bad Request'): TApiResponse;
    function Unauthorized(const AMessage: string = 'Unauthorized'): TApiResponse;
    function Forbidden(const AMessage: string = 'Forbidden'): TApiResponse;
    function NotFound(const AMessage: string = 'Not Found'): TApiResponse;
    function Conflict(const AMessage: string = 'Conflict'): TApiResponse;
    function InternalError(const AMessage: string = 'Internal Server Error'): TApiResponse;
    function TooManyRequests(const AMessage: string = 'Too Many Requests'): TApiResponse;

    // JSON 响应
    function JSON(AObj: TObject; AOwns: Boolean = False): TApiResponse; overload;
    function JSON(const AData: string): TApiResponse; overload;

    // 重定向
    function Redirect(const AURL: string; APermanent: Boolean = False): TApiResponse;
  end;

  // API 上下文
  TApiContext = class
  private
    FRequest: TApiRequest;
    FResponse: TApiResponse;
    FItems: TDictionary<string, TValue>;
    FServer: TApiServer;
    FAborted: Boolean;
  public
    constructor Create(AServer: TApiServer);
    destructor Destroy; override;

    property Request: TApiRequest read FRequest;
    property Response: TApiResponse read FResponse;
    property Items: TDictionary<string, TValue> read FItems;
    property Server: TApiServer read FServer;
    property Aborted: Boolean read FAborted write FAborted;

    // 上下文数据存取
    procedure SetItem(const AKey: string; const AValue: TValue);
    function GetItem(const AKey: string): TValue;
    function GetItemOrDefault<T>(const AKey: string; const ADefault: T): T;
    function TryGetItem(const AKey: string; out AValue: TValue): Boolean;
    function HasItem(const AKey: string): Boolean;

    // 中止请求处理
    procedure Abort;
  end;

  // 路由定义
  TRouteDefinition = class
  private
    FPattern: string;
    FRegexPattern: string;
    FCompiledRegex: TRegEx;
    FMethods: THttpMethods;
    FHandler: TRouteHandler;
    FMiddlewares: TList<TMiddlewareFunc>;
    FParamNames: TStringList;
    FName: string;
    FDescription: string;
    FTags: TStringList;

    procedure CompilePattern;
  public
    constructor Create(const APattern: string; AMethods: THttpMethods;
      AHandler: TRouteHandler);
    destructor Destroy; override;

    property Pattern: string read FPattern;
    property RegexPattern: string read FRegexPattern;
    property Methods: THttpMethods read FMethods;
    property Handler: TRouteHandler read FHandler;
    property Middlewares: TList<TMiddlewareFunc> read FMiddlewares;
    property ParamNames: TStringList read FParamNames;
    property Name: string read FName write FName;
    property Description: string read FDescription write FDescription;
    property Tags: TStringList read FTags;

    function Match(const APath: string; AParams: TRouteParams): Boolean;
    function Use(AMiddleware: TMiddlewareFunc): TRouteDefinition;
    function Named(const AName: string): TRouteDefinition;
    function Describe(const ADescription: string): TRouteDefinition;
    function Tag(const ATag: string): TRouteDefinition;
  end;

  // 路由组
  TRouteGroup = class
  private
    FPrefix: string;
    FRouter: TApiRouter;
    FMiddlewares: TList<TMiddlewareFunc>;
  public
    constructor Create(ARouter: TApiRouter; const APrefix: string);
    destructor Destroy; override;

    property Prefix: string read FPrefix;

    function Use(AMiddleware: TMiddlewareFunc): TRouteGroup;
    function Get(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Post(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Put(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Patch(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Delete(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Route(const APath: string; AMethods: THttpMethods;
      AHandler: TRouteHandler): TRouteDefinition;
    function Group(const APrefix: string): TRouteGroup;
  end;

  // 路由器
  TApiRouter = class
  private
    FRoutes: TObjectList<TRouteDefinition>;
    FGroups: TObjectList<TRouteGroup>;
    FMiddlewares: TList<TMiddlewareFunc>;
    FNotFoundHandler: TRouteHandler;
    FMethodNotAllowedHandler: TRouteHandler;
  public
    constructor Create;
    destructor Destroy; override;

    property Routes: TObjectList<TRouteDefinition> read FRoutes;
    property Middlewares: TList<TMiddlewareFunc> read FMiddlewares;
    property NotFoundHandler: TRouteHandler read FNotFoundHandler write FNotFoundHandler;
    property MethodNotAllowedHandler: TRouteHandler
      read FMethodNotAllowedHandler write FMethodNotAllowedHandler;

    // 路由注册
    function Get(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Post(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Put(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Patch(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Delete(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Options(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Head(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Route(const APath: string; AMethods: THttpMethods;
      AHandler: TRouteHandler): TRouteDefinition;
    function Any(const APath: string; AHandler: TRouteHandler): TRouteDefinition;

    // 路由组
    function Group(const APrefix: string): TRouteGroup;

    // 中间件
    function Use(AMiddleware: TMiddlewareFunc): TApiRouter;

    // 路由匹配
    function Match(const AMethod: THttpMethod; const APath: string;
      AParams: TRouteParams): TRouteDefinition;
    function FindAllowedMethods(const APath: string): THttpMethods;
  end;

  // 服务器配置
  TApiServerConfig = class
  private
    FHost: string;
    FPort: Integer;
    FSSLEnabled: Boolean;
    FSSLCertFile: string;
    FSSLKeyFile: string;
    FMaxConnections: Integer;
    FReadTimeout: Integer;
    FWriteTimeout: Integer;
    FMaxRequestSize: Int64;
    FCORSEnabled: Boolean;
    FCORSOrigins: string;
    FCORSMethods: string;
    FCORSHeaders: string;
    FCompressResponse: Boolean;
    FLogRequests: Boolean;
  public
    constructor Create;

    property Host: string read FHost write FHost;
    property Port: Integer read FPort write FPort;
    property SSLEnabled: Boolean read FSSLEnabled write FSSLEnabled;
    property SSLCertFile: string read FSSLCertFile write FSSLCertFile;
    property SSLKeyFile: string read FSSLKeyFile write FSSLKeyFile;
    property MaxConnections: Integer read FMaxConnections write FMaxConnections;
    property ReadTimeout: Integer read FReadTimeout write FReadTimeout;
    property WriteTimeout: Integer read FWriteTimeout write FWriteTimeout;
    property MaxRequestSize: Int64 read FMaxRequestSize write FMaxRequestSize;
    property CORSEnabled: Boolean read FCORSEnabled write FCORSEnabled;
    property CORSOrigins: string read FCORSOrigins write FCORSOrigins;
    property CORSMethods: string read FCORSMethods write FCORSMethods;
    property CORSHeaders: string read FCORSHeaders write FCORSHeaders;
    property CompressResponse: Boolean read FCompressResponse write FCompressResponse;
    property LogRequests: Boolean read FLogRequests write FLogRequests;
  end;

  // 请求日志记录
  TRequestLogEntry = record
    RequestId: string;
    Timestamp: TDateTime;
    Method: string;
    Path: string;
    StatusCode: Integer;
    Duration: Double;  // 毫秒
    RemoteIP: string;
    UserAgent: string;
    RequestSize: Int64;
    ResponseSize: Int64;
  end;

  TOnRequestLog = reference to procedure(const AEntry: TRequestLogEntry);

  // API 服务器
  TApiServer = class
  private
    FHttpServer: TIdHTTPServer;
    FSSLHandler: TIdServerIOHandlerSSLOpenSSL;
    FRouter: TApiRouter;
    FConfig: TApiServerConfig;
    FExceptionHandler: TExceptionHandler;
    FOnRequestLog: TOnRequestLog;
    FRunning: Boolean;
    FLock: TCriticalSection;
    FActiveConnections: Integer;

    procedure DoCommandGet(AContext: TIdContext;
      ARequestInfo: TIdHTTPRequestInfo;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure DoConnect(AContext: TIdContext);
    procedure DoDisconnect(AContext: TIdContext);

    procedure HandleRequest(AContext: TApiContext);
    procedure ExecuteMiddlewares(AContext: TApiContext;
      AMiddlewares: TList<TMiddlewareFunc>; AIndex: Integer; AFinal: TProc);
    procedure SendResponse(AContext: TApiContext;
      AResponseInfo: TIdHTTPResponseInfo);
    procedure LogRequest(AContext: TApiContext);
    procedure SetupSSL;
    procedure HandleCORS(AContext: TApiContext);

    function ParseHttpMethod(const AMethod: string): THttpMethod;
  public
    constructor Create; overload;
    constructor Create(AConfig: TApiServerConfig); overload;
    destructor Destroy; override;

    property Router: TApiRouter read FRouter;
    property Config: TApiServerConfig read FConfig;
    property Running: Boolean read FRunning;
    property ActiveConnections: Integer read FActiveConnections;
    property ExceptionHandler: TExceptionHandler read FExceptionHandler
      write FExceptionHandler;
    property OnRequestLog: TOnRequestLog read FOnRequestLog write FOnRequestLog;

    // 服务器控制
    procedure Start;
    procedure Stop;
    procedure Restart;

    // 快捷路由方法
    function Get(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Post(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Put(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Patch(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Delete(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
    function Use(AMiddleware: TMiddlewareFunc): TApiServer;
    function Group(const APrefix: string): TRouteGroup;
  end;

  // 辅助函数
  function HttpMethodToStr(AMethod: THttpMethod): string;
  function StrToHttpMethod(const AStr: string): THttpMethod;
  function StatusCodeToText(ACode: Integer): string;
  function GetMimeType(const AExtension: string): string;
  function GenerateRequestId: string;

implementation

uses
  System.IOUtils,
  System.TypInfo;

{ 辅助函数 }

function HttpMethodToStr(AMethod: THttpMethod): string;
begin
  case AMethod of
    hmGet: Result := 'GET';
    hmPost: Result := 'POST';
    hmPut: Result := 'PUT';
    hmPatch: Result := 'PATCH';
    hmDelete: Result := 'DELETE';
    hmOptions: Result := 'OPTIONS';
    hmHead: Result := 'HEAD';
  else
    Result := 'UNKNOWN';
  end;
end;

function StrToHttpMethod(const AStr: string): THttpMethod;
var
  LUpper: string;
begin
  LUpper := UpperCase(AStr);
  if LUpper = 'GET' then
    Result := hmGet
  else if LUpper = 'POST' then
    Result := hmPost
  else if LUpper = 'PUT' then
    Result := hmPut
  else if LUpper = 'PATCH' then
    Result := hmPatch
  else if LUpper = 'DELETE' then
    Result := hmDelete
  else if LUpper = 'OPTIONS' then
    Result := hmOptions
  else if LUpper = 'HEAD' then
    Result := hmHead
  else
    Result := hmGet;
end;

function StatusCodeToText(ACode: Integer): string;
begin
  case ACode of
    200: Result := 'OK';
    201: Result := 'Created';
    202: Result := 'Accepted';
    204: Result := 'No Content';
    301: Result := 'Moved Permanently';
    302: Result := 'Found';
    304: Result := 'Not Modified';
    400: Result := 'Bad Request';
    401: Result := 'Unauthorized';
    403: Result := 'Forbidden';
    404: Result := 'Not Found';
    405: Result := 'Method Not Allowed';
    409: Result := 'Conflict';
    410: Result := 'Gone';
    422: Result := 'Unprocessable Entity';
    429: Result := 'Too Many Requests';
    500: Result := 'Internal Server Error';
    501: Result := 'Not Implemented';
    502: Result := 'Bad Gateway';
    503: Result := 'Service Unavailable';
  else
    Result := 'Unknown';
  end;
end;

function GetMimeType(const AExtension: string): string;
var
  LExt: string;
begin
  LExt := LowerCase(AExtension);
  if LExt.StartsWith('.') then
    LExt := Copy(LExt, 2, Length(LExt));

  if LExt = 'html' then Result := TContentType.HTML
  else if LExt = 'htm' then Result := TContentType.HTML
  else if LExt = 'css' then Result := TContentType.CSS
  else if LExt = 'js' then Result := TContentType.JavaScript
  else if LExt = 'json' then Result := TContentType.JSON
  else if LExt = 'xml' then Result := TContentType.XML
  else if LExt = 'txt' then Result := TContentType.Plain
  else if LExt = 'png' then Result := TContentType.PNG
  else if LExt = 'jpg' then Result := TContentType.JPEG
  else if LExt = 'jpeg' then Result := TContentType.JPEG
  else if LExt = 'gif' then Result := TContentType.GIF
  else if LExt = 'svg' then Result := TContentType.SVG
  else if LExt = 'pdf' then Result := TContentType.PDF
  else if LExt = 'ico' then Result := 'image/x-icon'
  else if LExt = 'woff' then Result := 'font/woff'
  else if LExt = 'woff2' then Result := 'font/woff2'
  else if LExt = 'ttf' then Result := 'font/ttf'
  else if LExt = 'eot' then Result := 'application/vnd.ms-fontobject'
  else Result := TContentType.OctetStream;
end;

function GenerateRequestId: string;
var
  LGUID: TGUID;
begin
  CreateGUID(LGUID);
  Result := GUIDToString(LGUID).Replace('{', '').Replace('}', '').Replace('-', '');
end;

{ TUploadedFile }

procedure TUploadedFile.SaveToFile(const APath: string);
var
  LStream: TFileStream;
begin
  LStream := TFileStream.Create(APath, fmCreate);
  try
    LStream.WriteBuffer(FData[0], Length(FData));
  finally
    LStream.Free;
  end;
end;

function TUploadedFile.SaveToStream(AStream: TStream): Int64;
begin
  Result := AStream.Write(FData[0], Length(FData));
end;

{ TApiRequest }

constructor TApiRequest.Create;
begin
  inherited;
  FHeaders := THeaders.Create;
  FRouteParams := TRouteParams.Create;
  FQueryParams := TQueryParams.Create;
  FFiles := TObjectList<TUploadedFile>.Create(True);
  FFormFields := TDictionary<string, string>.Create;
  FStartTime := Now;
  FRequestId := GenerateRequestId;
end;

destructor TApiRequest.Destroy;
begin
  FHeaders.Free;
  FRouteParams.Free;
  FQueryParams.Free;
  FFiles.Free;
  FFormFields.Free;
  inherited;
end;

function TApiRequest.GetBodyAsString: string;
begin
  Result := TEncoding.UTF8.GetString(FBody);
end;

function TApiRequest.GetBodyAsJSON: TJSONValue;
begin
  Result := TJSONObject.ParseJSONValue(GetBodyAsString);
end;

procedure TApiRequest.ParseQueryString;
var
  LPairs: TArray<string>;
  LPair: string;
  LParts: TArray<string>;
begin
  if FQueryString = '' then
    Exit;

  LPairs := FQueryString.Split(['&']);
  for LPair in LPairs do
  begin
    LParts := LPair.Split(['=']);
    if Length(LParts) >= 2 then
      FQueryParams.AddOrSetValue(
        TNetEncoding.URL.Decode(LParts[0]),
        TNetEncoding.URL.Decode(LParts[1])
      )
    else if Length(LParts) = 1 then
      FQueryParams.AddOrSetValue(TNetEncoding.URL.Decode(LParts[0]), '');
  end;
end;

procedure TApiRequest.ParseFormData;
var
  LBody: string;
  LPairs: TArray<string>;
  LPair: string;
  LParts: TArray<string>;
begin
  LBody := GetBodyAsString;
  LPairs := LBody.Split(['&']);
  for LPair in LPairs do
  begin
    LParts := LPair.Split(['=']);
    if Length(LParts) >= 2 then
      FFormFields.AddOrSetValue(
        TNetEncoding.URL.Decode(LParts[0]),
        TNetEncoding.URL.Decode(LParts[1])
      )
    else if Length(LParts) = 1 then
      FFormFields.AddOrSetValue(TNetEncoding.URL.Decode(LParts[0]), '');
  end;
end;

procedure TApiRequest.ParseMultipartData(const ABoundary: string);
var
  LBodyStr: string;
  LParts: TArray<string>;
  LPart: string;
  LHeaderEnd: Integer;
  LHeaders: string;
  LContent: string;
  LFieldName: string;
  LFileName: string;
  LPartContentType: string;
  LFile: TUploadedFile;
  LRegex: TRegEx;
  LMatch: TMatch;
begin
  LBodyStr := GetBodyAsString;
  LParts := LBodyStr.Split(['--' + ABoundary]);

  for LPart in LParts do
  begin
    if (LPart = '') or (LPart = '--') or (LPart.StartsWith('--')) then
      Continue;

    // 找到头部和内容的分隔
    LHeaderEnd := Pos(#13#10#13#10, LPart);
    if LHeaderEnd = 0 then
      Continue;

    LHeaders := Copy(LPart, 1, LHeaderEnd - 1);
    LContent := Copy(LPart, LHeaderEnd + 4, Length(LPart) - LHeaderEnd - 5);  // -5 去掉末尾的 CRLF

    // 解析 Content-Disposition
    LRegex := TRegEx.Create('Content-Disposition:\s*form-data;\s*name="([^"]*)"(?:;\s*filename="([^"]*)")?',
      [roIgnoreCase]);
    LMatch := LRegex.Match(LHeaders);
    if not LMatch.Success then
      Continue;

    LFieldName := LMatch.Groups[1].Value;
    if LMatch.Groups.Count > 2 then
      LFileName := LMatch.Groups[2].Value
    else
      LFileName := '';

    // 解析 Content-Type
    LRegex := TRegEx.Create('Content-Type:\s*([^\r\n]+)', [roIgnoreCase]);
    LMatch := LRegex.Match(LHeaders);
    if LMatch.Success then
      LPartContentType := LMatch.Groups[1].Value
    else
      LPartContentType := '';

    if LFileName <> '' then
    begin
      // 文件上传
      LFile := TUploadedFile.Create;
      LFile.FieldName := LFieldName;
      LFile.FileName := LFileName;
      LFile.ContentType := LPartContentType;
      LFile.Data := TEncoding.UTF8.GetBytes(LContent);
      LFile.Size := Length(LFile.Data);
      FFiles.Add(LFile);
    end
    else
    begin
      // 普通表单字段
      FFormFields.AddOrSetValue(LFieldName, LContent);
    end;
  end;
end;

procedure TApiRequest.Initialize;
var
  LBoundary: string;
  LPos: Integer;
begin
  // 解析查询字符串
  ParseQueryString;

  // 解析请求体
  if IsFormData then
    ParseFormData
  else if IsMultipart then
  begin
    // 提取 boundary
    LPos := Pos('boundary=', FContentType);
    if LPos > 0 then
    begin
      LBoundary := Copy(FContentType, LPos + 9, Length(FContentType));
      LPos := Pos(';', LBoundary);
      if LPos > 0 then
        LBoundary := Copy(LBoundary, 1, LPos - 1);
      ParseMultipartData(LBoundary);
    end;
  end;
end;

function TApiRequest.GetHeader(const AName: string; const ADefault: string): string;
begin
  if not FHeaders.TryGetValue(LowerCase(AName), Result) then
    Result := ADefault;
end;

function TApiRequest.GetRouteParam(const AName: string; const ADefault: string): string;
begin
  if not FRouteParams.TryGetValue(AName, Result) then
    Result := ADefault;
end;

function TApiRequest.GetQueryParam(const AName: string; const ADefault: string): string;
begin
  if not FQueryParams.TryGetValue(AName, Result) then
    Result := ADefault;
end;

function TApiRequest.GetFormField(const AName: string; const ADefault: string): string;
begin
  if not FFormFields.TryGetValue(AName, Result) then
    Result := ADefault;
end;

function TApiRequest.GetFile(const AFieldName: string): TUploadedFile;
var
  LFile: TUploadedFile;
begin
  Result := nil;
  for LFile in FFiles do
    if LFile.FieldName = AFieldName then
      Exit(LFile);
end;

function TApiRequest.HasHeader(const AName: string): Boolean;
begin
  Result := FHeaders.ContainsKey(LowerCase(AName));
end;

function TApiRequest.HasQueryParam(const AName: string): Boolean;
begin
  Result := FQueryParams.ContainsKey(AName);
end;

function TApiRequest.IsJSON: Boolean;
begin
  Result := FContentType.Contains('application/json');
end;

function TApiRequest.IsFormData: Boolean;
begin
  Result := FContentType.Contains('application/x-www-form-urlencoded');
end;

function TApiRequest.IsMultipart: Boolean;
begin
  Result := FContentType.Contains('multipart/form-data');
end;

{ TApiResponse }

constructor TApiResponse.Create;
begin
  inherited;
  FHeaders := THeaders.Create;
  FCookies := TStringList.Create;
  FStatusCode := THttpStatus.OK;
  FStatusText := 'OK';
  FContentType := TContentType.JSON;
  FSent := False;
end;

destructor TApiResponse.Destroy;
begin
  FHeaders.Free;
  FCookies.Free;
  inherited;
end;

procedure TApiResponse.SetStatusCode(const Value: Integer);
begin
  FStatusCode := Value;
  FStatusText := StatusCodeToText(Value);
end;

function TApiResponse.GetBodyAsString: string;
begin
  Result := TEncoding.UTF8.GetString(FBody);
end;

procedure TApiResponse.SetBodyAsString(const Value: string);
begin
  FBody := TEncoding.UTF8.GetBytes(Value);
end;

function TApiResponse.SendErrorResponse(AStatusCode: Integer;
  const AMessage: string): TApiResponse;
var
  LJson: TJSONObject;
begin
  StatusCode := AStatusCode;
  FContentType := TContentType.JSON;

  LJson := TJSONObject.Create;
  try
    LJson.AddPair('error', AMessage);
    LJson.AddPair('code', TJSONNumber.Create(AStatusCode));
    Result := SendJSON(LJson, True);
  except
    LJson.Free;
    raise;
  end;
end;

function TApiResponse.SetHeader(const AName, AValue: string): TApiResponse;
begin
  FHeaders.AddOrSetValue(AName, AValue);
  Result := Self;
end;

function TApiResponse.SetCookie(const AName, AValue: string;
  AExpires: TDateTime; const APath: string;
  AHttpOnly, ASecure: Boolean): TApiResponse;
var
  LCookie: string;
begin
  LCookie := AName + '=' + TNetEncoding.URL.Encode(AValue);
  if AExpires > 0 then
    LCookie := LCookie + '; Expires=' + FormatDateTime('ddd, dd mmm yyyy hh:nn:ss', AExpires) + ' GMT';
  LCookie := LCookie + '; Path=' + APath;
  if AHttpOnly then
    LCookie := LCookie + '; HttpOnly';
  if ASecure then
    LCookie := LCookie + '; Secure';
  FCookies.Add(LCookie);
  Result := Self;
end;

function TApiResponse.Send(const ABody: string): TApiResponse;
begin
  if ABody <> '' then
    FBody := TEncoding.UTF8.GetBytes(ABody);
  FSent := True;
  Result := Self;
end;

function TApiResponse.Send(const ABody: TBytes): TApiResponse;
begin
  FBody := ABody;
  FSent := True;
  Result := Self;
end;

function TApiResponse.SendJSON(AValue: TJSONValue; AOwnsValue: Boolean): TApiResponse;
begin
  FContentType := TContentType.JSON;
  if AValue <> nil then
    FBody := TEncoding.UTF8.GetBytes(AValue.ToJSON);
  FSent := True;
  if AOwnsValue and (AValue <> nil) then
    AValue.Free;
  Result := Self;
end;

function TApiResponse.SendFile(const AFilePath: string): TApiResponse;
begin
  if not TFile.Exists(AFilePath) then
  begin
    FStatusCode := THttpStatus.NotFound;
    FBody := TEncoding.UTF8.GetBytes('{"error":"File not found"}');
  end
  else
  begin
    FBody := TFile.ReadAllBytes(AFilePath);
    FContentType := GetMimeType(TPath.GetExtension(AFilePath));
  end;
  FSent := True;
  Result := Self;
end;

function TApiResponse.SendStream(AStream: TStream; const AContentType: string): TApiResponse;
begin
  SetLength(FBody, AStream.Size);
  AStream.Position := 0;
  AStream.ReadBuffer(FBody[0], AStream.Size);
  if AContentType <> '' then
    FContentType := AContentType;
  FSent := True;
  Result := Self;
end;

function TApiResponse.OK(const ABody: string): TApiResponse;
begin
  FStatusCode := THttpStatus.OK;
  Result := Send(ABody);
end;

function TApiResponse.Created(const ALocation: string): TApiResponse;
begin
  FStatusCode := THttpStatus.Created;
  if ALocation <> '' then
    SetHeader('Location', ALocation);
  FSent := True;
  Result := Self;
end;

function TApiResponse.NoContent: TApiResponse;
begin
  FStatusCode := THttpStatus.NoContent;
  FSent := True;
  Result := Self;
end;

function TApiResponse.BadRequest(const AMessage: string): TApiResponse;
begin
  Result := SendErrorResponse(THttpStatus.BadRequest, AMessage);
end;

function TApiResponse.Unauthorized(const AMessage: string): TApiResponse;
begin
  Result := SendErrorResponse(THttpStatus.Unauthorized, AMessage);
end;

function TApiResponse.Forbidden(const AMessage: string): TApiResponse;
begin
  Result := SendErrorResponse(THttpStatus.Forbidden, AMessage);
end;

function TApiResponse.NotFound(const AMessage: string): TApiResponse;
begin
  Result := SendErrorResponse(THttpStatus.NotFound, AMessage);
end;

function TApiResponse.Conflict(const AMessage: string): TApiResponse;
begin
  Result := SendErrorResponse(THttpStatus.Conflict, AMessage);
end;

function TApiResponse.InternalError(const AMessage: string): TApiResponse;
begin
  Result := SendErrorResponse(THttpStatus.InternalServerError, AMessage);
end;

function TApiResponse.TooManyRequests(const AMessage: string): TApiResponse;
begin
  Result := SendErrorResponse(THttpStatus.TooManyRequests, AMessage);
end;

function TApiResponse.JSON(AObj: TObject; AOwns: Boolean): TApiResponse;
var
  LContext: TRttiContext;
  LType: TRttiType;
  LProp: TRttiProperty;
  LJson: TJSONObject;
begin
  LJson := TJSONObject.Create;
  try
    LContext := TRttiContext.Create;
    try
      LType := LContext.GetType(AObj.ClassType);
      for LProp in LType.GetProperties do
      begin
        if LProp.Visibility = mvPublished then
        begin
          case LProp.PropertyType.TypeKind of
            tkInteger, tkInt64:
              LJson.AddPair(LProp.Name, TJSONNumber.Create(LProp.GetValue(AObj).AsInt64));
            tkFloat:
              LJson.AddPair(LProp.Name, TJSONNumber.Create(LProp.GetValue(AObj).AsExtended));
            tkString, tkLString, tkWString, tkUString:
              LJson.AddPair(LProp.Name, LProp.GetValue(AObj).AsString);
            tkEnumeration:
              if LProp.PropertyType.Handle = TypeInfo(Boolean) then
                LJson.AddPair(LProp.Name, TJSONBool.Create(LProp.GetValue(AObj).AsBoolean))
              else
                LJson.AddPair(LProp.Name, LProp.GetValue(AObj).ToString);
          end;
        end;
      end;
    finally
      LContext.Free;
    end;
    Result := SendJSON(LJson, True);
  except
    LJson.Free;
    raise;
  end;
  if AOwns then
    AObj.Free;
end;

function TApiResponse.JSON(const AData: string): TApiResponse;
begin
  FContentType := TContentType.JSON;
  Result := Send(AData);
end;

function TApiResponse.Redirect(const AURL: string; APermanent: Boolean): TApiResponse;
begin
  if APermanent then
    FStatusCode := THttpStatus.MovedPermanently
  else
    FStatusCode := THttpStatus.Found;
  SetHeader('Location', AURL);
  FSent := True;
  Result := Self;
end;

{ TApiContext }

constructor TApiContext.Create(AServer: TApiServer);
begin
  inherited Create;
  FRequest := TApiRequest.Create;
  FResponse := TApiResponse.Create;
  FItems := TDictionary<string, TValue>.Create;
  FServer := AServer;
  FAborted := False;
end;

destructor TApiContext.Destroy;
begin
  FRequest.Free;
  FResponse.Free;
  FItems.Free;
  inherited;
end;

procedure TApiContext.SetItem(const AKey: string; const AValue: TValue);
begin
  FItems.AddOrSetValue(AKey, AValue);
end;

function TApiContext.GetItem(const AKey: string): TValue;
begin
  FItems.TryGetValue(AKey, Result);
end;

function TApiContext.GetItemOrDefault<T>(const AKey: string; const ADefault: T): T;
var
  LValue: TValue;
begin
  if FItems.TryGetValue(AKey, LValue) then
    Result := LValue.AsType<T>
  else
    Result := ADefault;
end;

function TApiContext.TryGetItem(const AKey: string; out AValue: TValue): Boolean;
begin
  Result := FItems.TryGetValue(AKey, AValue);
end;

function TApiContext.HasItem(const AKey: string): Boolean;
begin
  Result := FItems.ContainsKey(AKey);
end;

procedure TApiContext.Abort;
begin
  FAborted := True;
end;

{ TRouteDefinition }

constructor TRouteDefinition.Create(const APattern: string; AMethods: THttpMethods;
  AHandler: TRouteHandler);
begin
  inherited Create;
  FPattern := APattern;
  FMethods := AMethods;
  FHandler := AHandler;
  FMiddlewares := TList<TMiddlewareFunc>.Create;
  FParamNames := TStringList.Create;
  FTags := TStringList.Create;
  CompilePattern;
end;

destructor TRouteDefinition.Destroy;
begin
  FMiddlewares.Free;
  FParamNames.Free;
  FTags.Free;
  inherited;
end;

procedure TRouteDefinition.CompilePattern;
var
  LRegex: TRegEx;
  LMatches: TMatchCollection;
  LMatch: TMatch;
  LPattern: string;
begin
  // 提取参数名称
  LRegex := TRegEx.Create(':([a-zA-Z_][a-zA-Z0-9_]*)');
  LMatches := LRegex.Matches(FPattern);
  for LMatch in LMatches do
    FParamNames.Add(LMatch.Groups[1].Value);

  // 转换为正则表达式
  LPattern := FPattern;
  // 转义特殊字符
  LPattern := TRegEx.Replace(LPattern, '[\.\+\*\?\^\$\{\}\[\]\(\)\|\\]', '\$0');
  // 替换路由参数
  LPattern := TRegEx.Replace(LPattern, ':([a-zA-Z_][a-zA-Z0-9_]*)', '([^/]+)');
  // 处理可选尾部斜杠
  if not LPattern.EndsWith('/') then
    LPattern := LPattern + '/?';
  FRegexPattern := '^' + LPattern + '$';
  FCompiledRegex := TRegEx.Create(FRegexPattern, [roIgnoreCase]);
end;

function TRouteDefinition.Match(const APath: string; AParams: TRouteParams): Boolean;
var
  LMatch: TMatch;
  I: Integer;
begin
  LMatch := FCompiledRegex.Match(APath);
  Result := LMatch.Success;
  if Result and (AParams <> nil) then
  begin
    for I := 0 to FParamNames.Count - 1 do
    begin
      if I + 1 < LMatch.Groups.Count then
        AParams.AddOrSetValue(FParamNames[I], LMatch.Groups[I + 1].Value);
    end;
  end;
end;

function TRouteDefinition.Use(AMiddleware: TMiddlewareFunc): TRouteDefinition;
begin
  FMiddlewares.Add(AMiddleware);
  Result := Self;
end;

function TRouteDefinition.Named(const AName: string): TRouteDefinition;
begin
  FName := AName;
  Result := Self;
end;

function TRouteDefinition.Describe(const ADescription: string): TRouteDefinition;
begin
  FDescription := ADescription;
  Result := Self;
end;

function TRouteDefinition.Tag(const ATag: string): TRouteDefinition;
begin
  FTags.Add(ATag);
  Result := Self;
end;

{ TRouteGroup }

constructor TRouteGroup.Create(ARouter: TApiRouter; const APrefix: string);
begin
  inherited Create;
  FRouter := ARouter;
  FPrefix := APrefix;
  FMiddlewares := TList<TMiddlewareFunc>.Create;
end;

destructor TRouteGroup.Destroy;
begin
  FMiddlewares.Free;
  inherited;
end;

function TRouteGroup.Use(AMiddleware: TMiddlewareFunc): TRouteGroup;
begin
  FMiddlewares.Add(AMiddleware);
  Result := Self;
end;

function TRouteGroup.Get(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmGet], AHandler);
end;

function TRouteGroup.Post(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmPost], AHandler);
end;

function TRouteGroup.Put(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmPut], AHandler);
end;

function TRouteGroup.Patch(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmPatch], AHandler);
end;

function TRouteGroup.Delete(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmDelete], AHandler);
end;

function TRouteGroup.Route(const APath: string; AMethods: THttpMethods;
  AHandler: TRouteHandler): TRouteDefinition;
var
  LMiddleware: TMiddlewareFunc;
begin
  Result := FRouter.Route(FPrefix + APath, AMethods, AHandler);
  // 应用组中间件
  for LMiddleware in FMiddlewares do
    Result.Use(LMiddleware);
end;

function TRouteGroup.Group(const APrefix: string): TRouteGroup;
begin
  Result := TRouteGroup.Create(FRouter, FPrefix + APrefix);
  Result.FMiddlewares.AddRange(FMiddlewares);
  FRouter.FGroups.Add(Result);
end;

{ TApiRouter }

constructor TApiRouter.Create;
begin
  inherited;
  FRoutes := TObjectList<TRouteDefinition>.Create(True);
  FGroups := TObjectList<TRouteGroup>.Create(True);
  FMiddlewares := TList<TMiddlewareFunc>.Create;
end;

destructor TApiRouter.Destroy;
begin
  FRoutes.Free;
  FGroups.Free;
  FMiddlewares.Free;
  inherited;
end;

function TApiRouter.Get(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmGet], AHandler);
end;

function TApiRouter.Post(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmPost], AHandler);
end;

function TApiRouter.Put(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmPut], AHandler);
end;

function TApiRouter.Patch(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmPatch], AHandler);
end;

function TApiRouter.Delete(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmDelete], AHandler);
end;

function TApiRouter.Options(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmOptions], AHandler);
end;

function TApiRouter.Head(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmHead], AHandler);
end;

function TApiRouter.Route(const APath: string; AMethods: THttpMethods;
  AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := TRouteDefinition.Create(APath, AMethods, AHandler);
  FRoutes.Add(Result);
end;

function TApiRouter.Any(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := Route(APath, [hmGet, hmPost, hmPut, hmPatch, hmDelete, hmOptions, hmHead],
    AHandler);
end;

function TApiRouter.Group(const APrefix: string): TRouteGroup;
begin
  Result := TRouteGroup.Create(Self, APrefix);
  FGroups.Add(Result);
end;

function TApiRouter.Use(AMiddleware: TMiddlewareFunc): TApiRouter;
begin
  FMiddlewares.Add(AMiddleware);
  Result := Self;
end;

function TApiRouter.Match(const AMethod: THttpMethod; const APath: string;
  AParams: TRouteParams): TRouteDefinition;
var
  LRoute: TRouteDefinition;
begin
  for LRoute in FRoutes do
  begin
    if (AMethod in LRoute.Methods) and LRoute.Match(APath, AParams) then
      Exit(LRoute);
  end;
  Result := nil;
end;

function TApiRouter.FindAllowedMethods(const APath: string): THttpMethods;
var
  LRoute: TRouteDefinition;
begin
  Result := [];
  for LRoute in FRoutes do
    if LRoute.Match(APath, nil) then
      Result := Result + LRoute.Methods;
end;

{ TApiServerConfig }

constructor TApiServerConfig.Create;
begin
  inherited;
  FHost := '0.0.0.0';
  FPort := 8080;
  FSSLEnabled := False;
  FMaxConnections := 1000;
  FReadTimeout := 30000;
  FWriteTimeout := 30000;
  FMaxRequestSize := 10 * 1024 * 1024;  // 10 MB
  FCORSEnabled := False;
  FCORSOrigins := '';
  FCORSMethods := 'GET, POST, PUT, PATCH, DELETE, OPTIONS';
  FCORSHeaders := 'Content-Type, Authorization, X-Requested-With';
  FCompressResponse := True;
  FLogRequests := True;
end;

{ TApiServer }

constructor TApiServer.Create;
begin
  Create(TApiServerConfig.Create);
end;

constructor TApiServer.Create(AConfig: TApiServerConfig);
begin
  inherited Create;
  FConfig := AConfig;
  FRouter := TApiRouter.Create;
  FHttpServer := TIdHTTPServer.Create(nil);
  FLock := TCriticalSection.Create;
  FRunning := False;
  FActiveConnections := 0;

  FHttpServer.OnCommandGet := DoCommandGet;
  FHttpServer.OnCommandOther := DoCommandGet;
  FHttpServer.OnConnect := DoConnect;
  FHttpServer.OnDisconnect := DoDisconnect;
end;

destructor TApiServer.Destroy;
begin
  Stop;
  FHttpServer.Free;
  FSSLHandler.Free;
  FRouter.Free;
  FConfig.Free;
  FLock.Free;
  inherited;
end;

procedure TApiServer.DoCommandGet(AContext: TIdContext;
  ARequestInfo: TIdHTTPRequestInfo;
  AResponseInfo: TIdHTTPResponseInfo);
var
  LContext: TApiContext;
  LHeader: string;
  LPos: Integer;
  LLastHeaderName: string;
  LLastHeaderValue: string;
begin
  LContext := TApiContext.Create(Self);
  try
    // 解析请求
    LContext.Request.Method := ParseHttpMethod(ARequestInfo.Command);

    // 使用 Indy 的 Document / UnparsedParams 来获得路径和查询字符串，
    // 避免依赖 URI 是否包含 '?' 的差异，实现更稳定的解析行为。
    LContext.Request.RawPath := ARequestInfo.Document;
    LContext.Request.Path := ARequestInfo.Document;
    LContext.Request.QueryString := ARequestInfo.UnparsedParams;
    if (LContext.Request.QueryString <> '') and
       (LContext.Request.QueryString[1] = '?') then
      LContext.Request.QueryString := Copy(LContext.Request.QueryString, 2, MaxInt);

    // 复制头部（支持折行 Header continuation lines）
    // 说明：某些客户端/编码实现可能会对超长 header 值进行折行（obs-fold），
    // 此处将以空白开头的行拼接到上一条 header 值，避免 JWT 等值被截断。
    LLastHeaderName := '';
    LLastHeaderValue := '';

    for LHeader in ARequestInfo.RawHeaders do
    begin
      if LHeader = '' then
        Continue;

      // Header continuation line (line starts with space or tab)
      if ((LHeader[1] = ' ') or (LHeader[1] = #9)) and (LLastHeaderName <> '') then
      begin
        LLastHeaderValue := LLastHeaderValue + ' ' + Trim(LHeader);
        LContext.Request.Headers.AddOrSetValue(LLastHeaderName, LLastHeaderValue);
        Continue;
      end;

      LPos := Pos(':', LHeader);
      if LPos > 0 then
      begin
        LLastHeaderName := LowerCase(Trim(Copy(LHeader, 1, LPos - 1)));
        LLastHeaderValue := Trim(Copy(LHeader, LPos + 1, Length(LHeader)));
        LContext.Request.Headers.AddOrSetValue(LLastHeaderName, LLastHeaderValue);
      end;
    end;

    // 读取请求体
    if ARequestInfo.PostStream <> nil then
    begin
      SetLength(LContext.Request.FBody, ARequestInfo.PostStream.Size);
      ARequestInfo.PostStream.Position := 0;
      ARequestInfo.PostStream.ReadBuffer(LContext.Request.FBody[0],
        ARequestInfo.PostStream.Size);
    end;

    LContext.Request.ContentType := ARequestInfo.ContentType;
    LContext.Request.RemoteIP := AContext.Binding.PeerIP;

    // 初始化请求（解析表单等）
    LContext.Request.Initialize;

    // 处理请求
    HandleRequest(LContext);

    // 发送响应
    SendResponse(LContext, AResponseInfo);

    // 记录请求日志
    if FConfig.LogRequests then
      LogRequest(LContext);
  finally
    LContext.Free;
  end;
end;

procedure TApiServer.DoConnect(AContext: TIdContext);
begin
  FLock.Enter;
  try
    Inc(FActiveConnections);
  finally
    FLock.Leave;
  end;
end;

procedure TApiServer.DoDisconnect(AContext: TIdContext);
begin
  FLock.Enter;
  try
    Dec(FActiveConnections);
  finally
    FLock.Leave;
  end;
end;

procedure TApiServer.HandleRequest(AContext: TApiContext);
var
  LRoute: TRouteDefinition;
  LAllMiddlewares: TList<TMiddlewareFunc>;
  LAllowedMethods: THttpMethods;
begin
  try
    // 处理 CORS 预检
    if FConfig.CORSEnabled then
      HandleCORS(AContext);

    // OPTIONS 请求直接返回
    if AContext.Request.Method = hmOptions then
    begin
      AContext.Response.OK;
      Exit;
    end;

    // 查找路由
    LRoute := FRouter.Match(AContext.Request.Method, AContext.Request.Path,
      AContext.Request.RouteParams);

    if LRoute = nil then
    begin
      // 检查是否有其他方法匹配
      LAllowedMethods := FRouter.FindAllowedMethods(AContext.Request.Path);
      if LAllowedMethods <> [] then
      begin
        if Assigned(FRouter.MethodNotAllowedHandler) then
          FRouter.MethodNotAllowedHandler(AContext)
        else
        begin
          AContext.Response.StatusCode := THttpStatus.MethodNotAllowed;
          AContext.Response.SetHeader('Allow', 'OPTIONS');
          AContext.Response.Send('{"error":"Method Not Allowed"}');
        end;
      end
      else
      begin
        if Assigned(FRouter.NotFoundHandler) then
          FRouter.NotFoundHandler(AContext)
        else
          AContext.Response.NotFound;
      end;
      Exit;
    end;

    // 合并中间件
    LAllMiddlewares := TList<TMiddlewareFunc>.Create;
    try
      LAllMiddlewares.AddRange(FRouter.Middlewares);
      LAllMiddlewares.AddRange(LRoute.Middlewares);

      // 执行中间件链
      ExecuteMiddlewares(AContext, LAllMiddlewares, 0,
        procedure
        begin
          if not AContext.Aborted then
            LRoute.Handler(AContext);
        end
      );
    finally
      LAllMiddlewares.Free;
    end;
  except
    on E: Exception do
    begin
      if Assigned(FExceptionHandler) then
        FExceptionHandler(AContext, E)
      else
        AContext.Response.InternalError;
    end;
  end;
end;

procedure TApiServer.ExecuteMiddlewares(AContext: TApiContext;
  AMiddlewares: TList<TMiddlewareFunc>; AIndex: Integer; AFinal: TProc);
begin
  if AContext.Aborted then
    Exit;

  if AIndex >= AMiddlewares.Count then
  begin
    AFinal();
    Exit;
  end;

  AMiddlewares[AIndex](AContext,
    procedure
    begin
      ExecuteMiddlewares(AContext, AMiddlewares, AIndex + 1, AFinal);
    end
  );
end;

procedure TApiServer.SendResponse(AContext: TApiContext;
  AResponseInfo: TIdHTTPResponseInfo);
var
  LHeader: TPair<string, string>;
  LCookie: string;
begin
  AResponseInfo.ResponseNo := AContext.Response.StatusCode;
  AResponseInfo.ResponseText := AContext.Response.StatusText;
  AResponseInfo.ContentType := AContext.Response.ContentType;

  // 设置头部
  for LHeader in AContext.Response.Headers do
    AResponseInfo.CustomHeaders.AddValue(LHeader.Key, LHeader.Value);

  // 设置 Cookie
  for LCookie in AContext.Response.Cookies do
    AResponseInfo.CustomHeaders.AddValue('Set-Cookie', LCookie);

  // 设置响应体
  if Length(AContext.Response.Body) > 0 then
  begin
    AResponseInfo.ContentStream := TMemoryStream.Create;
    AResponseInfo.ContentStream.WriteBuffer(AContext.Response.Body[0],
      Length(AContext.Response.Body));
    AResponseInfo.ContentStream.Position := 0;
    AResponseInfo.FreeContentStream := True;
  end;
end;

procedure TApiServer.LogRequest(AContext: TApiContext);
var
  LEntry: TRequestLogEntry;
begin
  if Assigned(FOnRequestLog) then
  begin
    LEntry.RequestId := AContext.Request.RequestId;
    LEntry.Timestamp := AContext.Request.StartTime;
    LEntry.Method := HttpMethodToStr(AContext.Request.Method);
    LEntry.Path := AContext.Request.Path;
    LEntry.StatusCode := AContext.Response.StatusCode;
    LEntry.Duration := MilliSecondsBetween(Now, AContext.Request.StartTime);
    LEntry.RemoteIP := AContext.Request.RemoteIP;
    LEntry.UserAgent := AContext.Request.GetHeader('user-agent');
    LEntry.RequestSize := Length(AContext.Request.Body);
    LEntry.ResponseSize := Length(AContext.Response.Body);
    FOnRequestLog(LEntry);
  end;
end;

procedure TApiServer.SetupSSL;
begin
  if FConfig.SSLEnabled then
  begin
    FSSLHandler := TIdServerIOHandlerSSLOpenSSL.Create(FHttpServer);
    FSSLHandler.SSLOptions.CertFile := FConfig.SSLCertFile;
    FSSLHandler.SSLOptions.KeyFile := FConfig.SSLKeyFile;
    // BUG-041 FIX: 优先使用 TLS 1.3，回退到 TLS 1.2。
    // 不同 Indy 版本枚举项不同，编译期按可用符号适配。
    {$IF Declared(sslvTLSv1_3)}
    FSSLHandler.SSLOptions.SSLVersions := [sslvTLSv1_2, sslvTLSv1_3];
    {$ELSE}
    FSSLHandler.SSLOptions.SSLVersions := [sslvTLSv1_2];
    {$IFEND}
    FSSLHandler.SSLOptions.Mode := sslmServer;
    // 添加安全头部配置
    FSSLHandler.SSLOptions.VerifyMode := [];
    FSSLHandler.SSLOptions.VerifyDepth := 2;
    FHttpServer.IOHandler := FSSLHandler;
  end;
end;

procedure TApiServer.HandleCORS(AContext: TApiContext);
begin
  if Trim(FConfig.CORSOrigins) = '' then
    Exit;

  AContext.Response.SetHeader('Access-Control-Allow-Origin', FConfig.CORSOrigins);
  AContext.Response.SetHeader('Access-Control-Allow-Methods', FConfig.CORSMethods);
  AContext.Response.SetHeader('Access-Control-Allow-Headers', FConfig.CORSHeaders);
  AContext.Response.SetHeader('Access-Control-Max-Age', '86400');
end;

function TApiServer.ParseHttpMethod(const AMethod: string): THttpMethod;
begin
  Result := StrToHttpMethod(AMethod);
end;


procedure TApiServer.Start;
begin
  if FRunning then
    Exit;

  SetupSSL;
  FHttpServer.DefaultPort := FConfig.Port;
  FHttpServer.Bindings.Clear;
  FHttpServer.Bindings.Add.IP := FConfig.Host;
  FHttpServer.Bindings.Items[0].Port := FConfig.Port;
  FHttpServer.MaxConnections := FConfig.MaxConnections;

  FHttpServer.Active := True;
  FRunning := True;
end;

procedure TApiServer.Stop;
begin
  if not FRunning then
    Exit;

  FHttpServer.Active := False;
  FRunning := False;
end;

procedure TApiServer.Restart;
begin
  Stop;
  Start;
end;

function TApiServer.Get(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := FRouter.Get(APath, AHandler);
end;

function TApiServer.Post(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := FRouter.Post(APath, AHandler);
end;

function TApiServer.Put(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := FRouter.Put(APath, AHandler);
end;

function TApiServer.Patch(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := FRouter.Patch(APath, AHandler);
end;

function TApiServer.Delete(const APath: string; AHandler: TRouteHandler): TRouteDefinition;
begin
  Result := FRouter.Delete(APath, AHandler);
end;

function TApiServer.Use(AMiddleware: TMiddlewareFunc): TApiServer;
begin
  FRouter.Use(AMiddleware);
  Result := Self;
end;

function TApiServer.Group(const APrefix: string): TRouteGroup;
begin
  Result := FRouter.Group(APrefix);
end;

end.
