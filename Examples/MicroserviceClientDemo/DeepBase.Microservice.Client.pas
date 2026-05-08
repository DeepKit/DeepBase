{ ============================================================================
  DeepBase.Microservice.Client - REST API Client with Resilience Patterns
  
  Version: 0.3
  Description: Demonstrates microservice client patterns including:
               - REST API calls with JSON serialization
               - Retry with exponential backoff
               - Circuit breaker pattern
               - Request/response logging
               - Service discovery (simulated)
  
  Usage:
    var Client := TMicroserviceClient.Create('https://api.example.com');
    try
      Client.SetBearerToken('your-token');
      var Response := Client.Get<TUserDto>('/users/1');
      if Response.Success then
        ShowMessage(Response.Data.Name);
    finally
      Client.Free;
    end;
  ============================================================================ }

unit DeepBase.Microservice.Client;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Net.Mime,
  System.NetEncoding,
  System.SyncObjs,
  System.DateUtils,
  System.Rtti,
  DeepBase.Exceptions;

type
  // ============================================================================
  // Response Types
  // ============================================================================
  
  /// <summary>
  /// API response wrapper
  /// </summary>
  TApiResponse<T> = record
    Success: Boolean;
    StatusCode: Integer;
    Data: T;
    ErrorMessage: string;
    ErrorCode: string;
    RequestId: string;
    ResponseTime: Integer;  // milliseconds
    
    class function OK(const AData: T; AStatusCode: Integer = 200): TApiResponse<T>; static;
    class function Error(const AMessage: string; AStatusCode: Integer = 500;
      const AErrorCode: string = ''): TApiResponse<T>; static;
  end;
  
  /// <summary>
  /// Paginated response
  /// </summary>
  TPagedResponse<T> = record
    Items: TArray<T>;
    Page: Integer;
    PageSize: Integer;
    TotalCount: Integer;
    TotalPages: Integer;
    HasNextPage: Boolean;
    HasPreviousPage: Boolean;
  end;
  
  // ============================================================================
  // Circuit Breaker
  // ============================================================================
  
  TCircuitState = (csClose, csOpen, csHalfOpen);
  
  /// <summary>
  /// Circuit breaker for fault tolerance
  /// </summary>
  TCircuitBreaker = class
  private
    FState: TCircuitState;
    FFailureCount: Integer;
    FSuccessCount: Integer;
    FFailureThreshold: Integer;
    FSuccessThreshold: Integer;
    FOpenTimeout: TDateTime;
    FLastFailureTime: TDateTime;
    FLock: TCriticalSection;
  public
    constructor Create(FailureThreshold: Integer = 5; 
      SuccessThreshold: Integer = 2; OpenTimeoutSeconds: Integer = 30);
    destructor Destroy; override;
    
    function CanExecute: Boolean;
    procedure RecordSuccess;
    procedure RecordFailure;
    procedure Reset;
    
    property State: TCircuitState read FState;
    property FailureCount: Integer read FFailureCount;
  end;
  
  // ============================================================================
  // Retry Policy
  // ============================================================================
  
  TRetryPolicy = record
    MaxRetries: Integer;
    InitialDelayMs: Integer;
    MaxDelayMs: Integer;
    ExponentialBackoff: Boolean;
    RetryOnStatusCodes: TArray<Integer>;
    
    class function Default: TRetryPolicy; static;
    class function NoRetry: TRetryPolicy; static;
    function ShouldRetry(StatusCode: Integer; Attempt: Integer): Boolean;
    function GetDelay(Attempt: Integer): Integer;
  end;
  
  // ============================================================================
  // Request Options
  // ============================================================================
  
  TRequestOptions = record
    Timeout: Integer;          // milliseconds
    RetryPolicy: TRetryPolicy;
    UseCircuitBreaker: Boolean;
    Headers: TArray<TPair<string, string>>;
    QueryParams: TArray<TPair<string, string>>;
    
    class function Default: TRequestOptions; static;
  end;
  
  // ============================================================================
  // Event Types
  // ============================================================================
  
  TRequestLogEvent = procedure(Sender: TObject; const Method, Url: string;
    const Headers: TStrings; const Body: string) of object;
    
  TResponseLogEvent = procedure(Sender: TObject; StatusCode: Integer;
    const Body: string; ResponseTimeMs: Integer) of object;
  
  // ============================================================================
  // Microservice Client
  // ============================================================================
  
  /// <summary>
  /// REST API client with resilience patterns
  /// </summary>
  TMicroserviceClient = class
  private
    FBaseUrl: string;
    FHttpClient: THTTPClient;
    FDefaultHeaders: TDictionary<string, string>;
    FCircuitBreaker: TCircuitBreaker;
    FDefaultTimeout: Integer;
    FDefaultRetryPolicy: TRetryPolicy;
    FOnRequestLog: TRequestLogEvent;
    FOnResponseLog: TResponseLogEvent;
    FLock: TCriticalSection;
    
    function BuildUrl(const Endpoint: string; 
      const QueryParams: TArray<TPair<string, string>>): string;
    function SerializeToJson<T>(const Value: T): string;
    function DeserializeFromJson<T>(const JSON: string): T;
    procedure ApplyHeaders(const Request: IHTTPRequest;
      const AdditionalHeaders: TArray<TPair<string, string>>);
    function ExecuteWithRetry(const Method, Url: string;
      const Body: string; const Options: TRequestOptions): IHTTPResponse;
    procedure LogRequest(const Method, Url: string; const Headers: TStrings;
      const Body: string);
    procedure LogResponse(StatusCode: Integer; const Body: string;
      ResponseTimeMs: Integer);
  public
    constructor Create(const BaseUrl: string);
    destructor Destroy; override;
    
    // ========================================================================
    // Configuration
    // ========================================================================
    
    /// <summary>Set bearer token for authentication</summary>
    procedure SetBearerToken(const Token: string);
    
    /// <summary>Set API key header</summary>
    procedure SetApiKey(const Key: string; const HeaderName: string = 'X-API-Key');
    
    /// <summary>Set basic authentication</summary>
    procedure SetBasicAuth(const Username, Password: string);
    
    /// <summary>Add default header</summary>
    procedure AddDefaultHeader(const Name, Value: string);
    
    /// <summary>Remove default header</summary>
    procedure RemoveDefaultHeader(const Name: string);
    
    /// <summary>Configure circuit breaker</summary>
    procedure ConfigureCircuitBreaker(FailureThreshold, SuccessThreshold: Integer;
      OpenTimeoutSeconds: Integer);
    
    // ========================================================================
    // HTTP Methods
    // ========================================================================
    
    /// <summary>GET request</summary>
    function Get<T>(const Endpoint: string;
      const Options: TRequestOptions): TApiResponse<T>; overload;
    function Get<T>(const Endpoint: string): TApiResponse<T>; overload;
    
    /// <summary>POST request</summary>
    function Post<TRequest, TResponse>(const Endpoint: string;
      const Data: TRequest; const Options: TRequestOptions): TApiResponse<TResponse>; overload;
    function Post<TRequest, TResponse>(const Endpoint: string;
      const Data: TRequest): TApiResponse<TResponse>; overload;
    
    /// <summary>PUT request</summary>
    function Put<TRequest, TResponse>(const Endpoint: string;
      const Data: TRequest; const Options: TRequestOptions): TApiResponse<TResponse>; overload;
    function Put<TRequest, TResponse>(const Endpoint: string;
      const Data: TRequest): TApiResponse<TResponse>; overload;
    
    /// <summary>PATCH request</summary>
    function Patch<TRequest, TResponse>(const Endpoint: string;
      const Data: TRequest; const Options: TRequestOptions): TApiResponse<TResponse>; overload;
    function Patch<TRequest, TResponse>(const Endpoint: string;
      const Data: TRequest): TApiResponse<TResponse>; overload;
    
    /// <summary>DELETE request</summary>
    function Delete(const Endpoint: string;
      const Options: TRequestOptions): TApiResponse<Boolean>; overload;
    function Delete(const Endpoint: string): TApiResponse<Boolean>; overload;
    
    /// <summary>Raw GET returning string</summary>
    function GetRaw(const Endpoint: string; const Options: TRequestOptions): TApiResponse<string>;
    
    /// <summary>Raw POST with string body</summary>
    function PostRaw(const Endpoint: string; const Body: string;
      const Options: TRequestOptions): TApiResponse<string>;
    
    // ========================================================================
    // Batch Operations
    // ========================================================================
    
    /// <summary>Execute multiple requests in parallel</summary>
    procedure BatchGet<T>(const Endpoints: TArray<string>;
      Callback: TProc<string, TApiResponse<T>>);
    
    // ========================================================================
    // Health Check
    // ========================================================================
    
    /// <summary>Check if service is healthy</summary>
    function HealthCheck(const Endpoint: string = '/health'): Boolean;
    
    // ========================================================================
    // Properties
    // ========================================================================
    
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property DefaultTimeout: Integer read FDefaultTimeout write FDefaultTimeout;
    property DefaultRetryPolicy: TRetryPolicy read FDefaultRetryPolicy write FDefaultRetryPolicy;
    property CircuitBreaker: TCircuitBreaker read FCircuitBreaker;
    property OnRequestLog: TRequestLogEvent read FOnRequestLog write FOnRequestLog;
    property OnResponseLog: TResponseLogEvent read FOnResponseLog write FOnResponseLog;
  end;

  // ============================================================================
  // Service Discovery (Simulated)
  // ============================================================================
  
  TServiceEndpoint = record
    Name: string;
    Url: string;
    Weight: Integer;
    IsHealthy: Boolean;
  end;
  
  /// <summary>
  /// Simple service discovery with load balancing
  /// </summary>
  TServiceDiscovery = class
  private
    FServices: TDictionary<string, TList<TServiceEndpoint>>;
    FLock: TCriticalSection;
    FRoundRobinIndex: TDictionary<string, Integer>;
  public
    constructor Create;
    destructor Destroy; override;
    
    /// <summary>Register a service endpoint</summary>
    procedure RegisterService(const ServiceName, Url: string; Weight: Integer = 1);
    
    /// <summary>Unregister a service endpoint</summary>
    procedure UnregisterService(const ServiceName, Url: string);
    
    /// <summary>Get next endpoint (round-robin)</summary>
    function GetEndpoint(const ServiceName: string): string;
    
    /// <summary>Get all endpoints for service</summary>
    function GetAllEndpoints(const ServiceName: string): TArray<TServiceEndpoint>;
    
    /// <summary>Mark endpoint as unhealthy</summary>
    procedure MarkUnhealthy(const ServiceName, Url: string);
    
    /// <summary>Mark endpoint as healthy</summary>
    procedure MarkHealthy(const ServiceName, Url: string);
  end;

implementation

uses
  System.Threading;

// ============================================================================
// TApiResponse<T>
// ============================================================================

class function TApiResponse<T>.OK(const AData: T; AStatusCode: Integer): TApiResponse<T>;
begin
  Result.Success := True;
  Result.StatusCode := AStatusCode;
  Result.Data := AData;
  Result.ErrorMessage := '';
  Result.ErrorCode := '';
end;

class function TApiResponse<T>.Error(const AMessage: string; AStatusCode: Integer;
  const AErrorCode: string): TApiResponse<T>;
begin
  Result.Success := False;
  Result.StatusCode := AStatusCode;
  Result.ErrorMessage := AMessage;
  Result.ErrorCode := AErrorCode;
end;

// ============================================================================
// TCircuitBreaker
// ============================================================================

constructor TCircuitBreaker.Create(FailureThreshold, SuccessThreshold: Integer;
  OpenTimeoutSeconds: Integer);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FState := csClose;
  FFailureCount := 0;
  FSuccessCount := 0;
  FFailureThreshold := FailureThreshold;
  FSuccessThreshold := SuccessThreshold;
  FOpenTimeout := OpenTimeoutSeconds / SecsPerDay;
end;

destructor TCircuitBreaker.Destroy;
begin
  FLock.Free;
  inherited;
end;

function TCircuitBreaker.CanExecute: Boolean;
begin
  FLock.Enter;
  try
    case FState of
      csClose:
        Result := True;
      csOpen:
        begin
          // Check if timeout has passed
          if Now - FLastFailureTime >= FOpenTimeout then
          begin
            FState := csHalfOpen;
            Result := True;
          end
          else
            Result := False;
        end;
      csHalfOpen:
        Result := True;
    else
      Result := False;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.RecordSuccess;
begin
  FLock.Enter;
  try
    case FState of
      csClose:
        FFailureCount := 0;
      csHalfOpen:
        begin
          Inc(FSuccessCount);
          if FSuccessCount >= FSuccessThreshold then
          begin
            FState := csClose;
            FFailureCount := 0;
            FSuccessCount := 0;
          end;
        end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.RecordFailure;
begin
  FLock.Enter;
  try
    FLastFailureTime := Now;
    case FState of
      csClose:
        begin
          Inc(FFailureCount);
          if FFailureCount >= FFailureThreshold then
          begin
            FState := csOpen;
          end;
        end;
      csHalfOpen:
        begin
          FState := csOpen;
          FSuccessCount := 0;
        end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TCircuitBreaker.Reset;
begin
  FLock.Enter;
  try
    FState := csClose;
    FFailureCount := 0;
    FSuccessCount := 0;
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// TRetryPolicy
// ============================================================================

class function TRetryPolicy.Default: TRetryPolicy;
begin
  Result.MaxRetries := 3;
  Result.InitialDelayMs := 100;
  Result.MaxDelayMs := 5000;
  Result.ExponentialBackoff := True;
  Result.RetryOnStatusCodes := [408, 429, 500, 502, 503, 504];
end;

class function TRetryPolicy.NoRetry: TRetryPolicy;
begin
  Result.MaxRetries := 0;
  Result.InitialDelayMs := 0;
  Result.MaxDelayMs := 0;
  Result.ExponentialBackoff := False;
  Result.RetryOnStatusCodes := [];
end;

function TRetryPolicy.ShouldRetry(StatusCode: Integer; Attempt: Integer): Boolean;
var
  Code: Integer;
begin
  if Attempt >= MaxRetries then
    Exit(False);
  
  for Code in RetryOnStatusCodes do
    if Code = StatusCode then
      Exit(True);
  
  Result := False;
end;

function TRetryPolicy.GetDelay(Attempt: Integer): Integer;
begin
  if ExponentialBackoff then
    Result := Min(InitialDelayMs * (1 shl Attempt), MaxDelayMs)
  else
    Result := InitialDelayMs;
end;

// ============================================================================
// TRequestOptions
// ============================================================================

class function TRequestOptions.Default: TRequestOptions;
begin
  Result.Timeout := 30000;  // 30 seconds
  Result.RetryPolicy := TRetryPolicy.Default;
  Result.UseCircuitBreaker := True;
  Result.Headers := nil;
  Result.QueryParams := nil;
end;

// ============================================================================
// TMicroserviceClient
// ============================================================================

constructor TMicroserviceClient.Create(const BaseUrl: string);
begin
  inherited Create;
  FBaseUrl := BaseUrl.TrimRight(['/']);
  FHttpClient := THTTPClient.Create;
  FHttpClient.UserAgent := 'DeepBase-MicroserviceClient/1.0';
  FHttpClient.ContentType := 'application/json';
  FDefaultHeaders := TDictionary<string, string>.Create;
  FCircuitBreaker := TCircuitBreaker.Create;
  FLock := TCriticalSection.Create;
  FDefaultTimeout := 30000;
  FDefaultRetryPolicy := TRetryPolicy.Default;
  
  // Default headers
  FDefaultHeaders.Add('Accept', 'application/json');
end;

destructor TMicroserviceClient.Destroy;
begin
  FLock.Free;
  FCircuitBreaker.Free;
  FDefaultHeaders.Free;
  FHttpClient.Free;
  inherited;
end;

function TMicroserviceClient.BuildUrl(const Endpoint: string;
  const QueryParams: TArray<TPair<string, string>>): string;
var
  Param: TPair<string, string>;
  Sep: string;
begin
  if Endpoint.StartsWith('/') then
    Result := FBaseUrl + Endpoint
  else
    Result := FBaseUrl + '/' + Endpoint;
  
  if Length(QueryParams) > 0 then
  begin
    Sep := '?';
    for Param in QueryParams do
    begin
      Result := Result + Sep + TNetEncoding.URL.Encode(Param.Key) + '=' +
        TNetEncoding.URL.Encode(Param.Value);
      Sep := '&';
    end;
  end;
end;

function TMicroserviceClient.SerializeToJson<T>(const Value: T): string;
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  JSON: TJSONObject;
  Field: TRttiField;
  FieldValue: TValue;
begin
  // Simple serialization - in production use a proper JSON serializer
  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(TypeInfo(T));
    if RttiType = nil then
      Exit('{}');
    
    JSON := TJSONObject.Create;
    try
      if RttiType.IsRecord then
      begin
        for Field in RttiType.GetFields do
        begin
          FieldValue := Field.GetValue(@Value);
          case FieldValue.Kind of
            tkInteger, tkInt64:
              JSON.AddPair(Field.Name, TJSONNumber.Create(FieldValue.AsInt64));
            tkFloat:
              JSON.AddPair(Field.Name, TJSONNumber.Create(FieldValue.AsExtended));
            tkString, tkLString, tkWString, tkUString:
              JSON.AddPair(Field.Name, FieldValue.AsString);
            tkEnumeration:
              if FieldValue.TypeInfo = TypeInfo(Boolean) then
                JSON.AddPair(Field.Name, TJSONBool.Create(FieldValue.AsBoolean))
              else
                JSON.AddPair(Field.Name, TJSONNumber.Create(FieldValue.AsOrdinal));
          end;
        end;
      end;
      Result := JSON.ToString;
    finally
      JSON.Free;
    end;
  finally
    Ctx.Free;
  end;
end;

function TMicroserviceClient.DeserializeFromJson<T>(const JSON: string): T;
var
  Ctx: TRttiContext;
  RttiType: TRttiType;
  JSONObj: TJSONObject;
  Field: TRttiField;
  JSONValue: TJSONValue;
  FieldValue: TValue;
begin
  Result := Default(T);
  
  if JSON = '' then
    Exit;
  
  Ctx := TRttiContext.Create;
  try
    RttiType := Ctx.GetType(TypeInfo(T));
    if RttiType = nil then
      Exit;
    
    JSONObj := TJSONObject.ParseJSONValue(JSON) as TJSONObject;
    if JSONObj = nil then
      Exit;
    
    try
      if RttiType.IsRecord then
      begin
        for Field in RttiType.GetFields do
        begin
          JSONValue := JSONObj.GetValue(Field.Name);
          if JSONValue = nil then
            Continue;
          
          case Field.FieldType.TypeKind of
            tkInteger:
              begin
                FieldValue := TValue.From<Integer>((JSONValue as TJSONNumber).AsInt);
                Field.SetValue(@Result, FieldValue);
              end;
            tkInt64:
              begin
                FieldValue := TValue.From<Int64>((JSONValue as TJSONNumber).AsInt64);
                Field.SetValue(@Result, FieldValue);
              end;
            tkFloat:
              begin
                FieldValue := TValue.From<Double>((JSONValue as TJSONNumber).AsDouble);
                Field.SetValue(@Result, FieldValue);
              end;
            tkString, tkLString, tkWString, tkUString:
              begin
                FieldValue := TValue.From<string>(JSONValue.Value);
                Field.SetValue(@Result, FieldValue);
              end;
            tkEnumeration:
              if Field.FieldType.Handle = TypeInfo(Boolean) then
              begin
                FieldValue := TValue.From<Boolean>((JSONValue as TJSONBool).AsBoolean);
                Field.SetValue(@Result, FieldValue);
              end;
          end;
        end;
      end;
    finally
      JSONObj.Free;
    end;
  finally
    Ctx.Free;
  end;
end;

procedure TMicroserviceClient.ApplyHeaders(const Request: IHTTPRequest;
  const AdditionalHeaders: TArray<TPair<string, string>>);
var
  Header: TPair<string, string>;
begin
  // Apply default headers
  for Header in FDefaultHeaders do
    Request.AddHeader(Header.Key, Header.Value);
  
  // Apply additional headers
  for Header in AdditionalHeaders do
    Request.AddHeader(Header.Key, Header.Value);
end;

function TMicroserviceClient.ExecuteWithRetry(const Method, Url: string;
  const Body: string; const Options: TRequestOptions): IHTTPResponse;
var
  Attempt: Integer;
  Delay: Integer;
  Request: IHTTPRequest;
  BodyStream: TStringStream;
  StartTime: TDateTime;
begin
  Result := nil;
  Attempt := 0;
  
  // Check circuit breaker
  if Options.UseCircuitBreaker and not FCircuitBreaker.CanExecute then
    raise ECircuitBreakerException.Create('Circuit breaker is open');
  
  while True do
  begin
    StartTime := Now;
    BodyStream := nil;
    
    try
      if Body <> '' then
      begin
        BodyStream := TStringStream.Create(Body, TEncoding.UTF8);
        Result := FHttpClient.Execute(Method, Url, BodyStream);
      end
      else
        Result := FHttpClient.Execute(Method, Url);
      
      // Log response
      LogResponse(Result.StatusCode, Result.ContentAsString,
        MilliSecondsBetween(Now, StartTime));
      
      // Check for success
      if (Result.StatusCode >= 200) and (Result.StatusCode < 300) then
      begin
        if Options.UseCircuitBreaker then
          FCircuitBreaker.RecordSuccess;
        Exit;
      end;
      
      // Check if should retry
      if not Options.RetryPolicy.ShouldRetry(Result.StatusCode, Attempt) then
      begin
        if Options.UseCircuitBreaker then
          FCircuitBreaker.RecordFailure;
        Exit;
      end;
      
      Inc(Attempt);
      Delay := Options.RetryPolicy.GetDelay(Attempt);
      Sleep(Delay);
      
    finally
      BodyStream.Free;
    end;
  end;
end;

procedure TMicroserviceClient.LogRequest(const Method, Url: string;
  const Headers: TStrings; const Body: string);
begin
  if Assigned(FOnRequestLog) then
    FOnRequestLog(Self, Method, Url, Headers, Body);
end;

procedure TMicroserviceClient.LogResponse(StatusCode: Integer;
  const Body: string; ResponseTimeMs: Integer);
begin
  if Assigned(FOnResponseLog) then
    FOnResponseLog(Self, StatusCode, Body, ResponseTimeMs);
end;

// ========================================================================
// Configuration
// ========================================================================

procedure TMicroserviceClient.SetBearerToken(const Token: string);
begin
  FDefaultHeaders.AddOrSetValue('Authorization', 'Bearer ' + Token);
end;

procedure TMicroserviceClient.SetApiKey(const Key: string; const HeaderName: string);
begin
  FDefaultHeaders.AddOrSetValue(HeaderName, Key);
end;

procedure TMicroserviceClient.SetBasicAuth(const Username, Password: string);
var
  Credentials: string;
begin
  Credentials := TNetEncoding.Base64.Encode(Username + ':' + Password);
  FDefaultHeaders.AddOrSetValue('Authorization', 'Basic ' + Credentials);
end;

procedure TMicroserviceClient.AddDefaultHeader(const Name, Value: string);
begin
  FDefaultHeaders.AddOrSetValue(Name, Value);
end;

procedure TMicroserviceClient.RemoveDefaultHeader(const Name: string);
begin
  FDefaultHeaders.Remove(Name);
end;

procedure TMicroserviceClient.ConfigureCircuitBreaker(FailureThreshold,
  SuccessThreshold, OpenTimeoutSeconds: Integer);
begin
  FCircuitBreaker.Free;
  FCircuitBreaker := TCircuitBreaker.Create(FailureThreshold, SuccessThreshold,
    OpenTimeoutSeconds);
end;

// ========================================================================
// HTTP Methods
// ========================================================================

function TMicroserviceClient.Get<T>(const Endpoint: string;
  const Options: TRequestOptions): TApiResponse<T>;
var
  Url: string;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  StartTime := Now;
  Url := BuildUrl(Endpoint, Options.QueryParams);
  
  try
    Response := ExecuteWithRetry('GET', Url, '', Options);
    
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
    begin
      Result := TApiResponse<T>.OK(
        DeserializeFromJson<T>(Response.ContentAsString),
        Response.StatusCode);
    end
    else
    begin
      Result := TApiResponse<T>.Error(
        Response.ContentAsString,
        Response.StatusCode);
    end;
  except
    on E: Exception do
      Result := TApiResponse<T>.Error(E.Message, 0);
  end;
  
  Result.ResponseTime := MilliSecondsBetween(Now, StartTime);
end;

function TMicroserviceClient.Get<T>(const Endpoint: string): TApiResponse<T>;
begin
  Result := Get<T>(Endpoint, TRequestOptions.Default);
end;

function TMicroserviceClient.Post<TRequest, TResponse>(const Endpoint: string;
  const Data: TRequest; const Options: TRequestOptions): TApiResponse<TResponse>;
var
  Url, Body: string;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  StartTime := Now;
  Url := BuildUrl(Endpoint, Options.QueryParams);
  Body := SerializeToJson<TRequest>(Data);
  
  LogRequest('POST', Url, nil, Body);
  
  try
    Response := ExecuteWithRetry('POST', Url, Body, Options);
    
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
    begin
      Result := TApiResponse<TResponse>.OK(
        DeserializeFromJson<TResponse>(Response.ContentAsString),
        Response.StatusCode);
    end
    else
    begin
      Result := TApiResponse<TResponse>.Error(
        Response.ContentAsString,
        Response.StatusCode);
    end;
  except
    on E: Exception do
      Result := TApiResponse<TResponse>.Error(E.Message, 0);
  end;
  
  Result.ResponseTime := MilliSecondsBetween(Now, StartTime);
end;

function TMicroserviceClient.Post<TRequest, TResponse>(const Endpoint: string;
  const Data: TRequest): TApiResponse<TResponse>;
begin
  Result := Post<TRequest, TResponse>(Endpoint, Data, TRequestOptions.Default);
end;

function TMicroserviceClient.Put<TRequest, TResponse>(const Endpoint: string;
  const Data: TRequest; const Options: TRequestOptions): TApiResponse<TResponse>;
var
  Url, Body: string;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  StartTime := Now;
  Url := BuildUrl(Endpoint, Options.QueryParams);
  Body := SerializeToJson<TRequest>(Data);
  
  try
    Response := ExecuteWithRetry('PUT', Url, Body, Options);
    
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
    begin
      Result := TApiResponse<TResponse>.OK(
        DeserializeFromJson<TResponse>(Response.ContentAsString),
        Response.StatusCode);
    end
    else
    begin
      Result := TApiResponse<TResponse>.Error(
        Response.ContentAsString,
        Response.StatusCode);
    end;
  except
    on E: Exception do
      Result := TApiResponse<TResponse>.Error(E.Message, 0);
  end;
  
  Result.ResponseTime := MilliSecondsBetween(Now, StartTime);
end;

function TMicroserviceClient.Put<TRequest, TResponse>(const Endpoint: string;
  const Data: TRequest): TApiResponse<TResponse>;
begin
  Result := Put<TRequest, TResponse>(Endpoint, Data, TRequestOptions.Default);
end;

function TMicroserviceClient.Patch<TRequest, TResponse>(const Endpoint: string;
  const Data: TRequest; const Options: TRequestOptions): TApiResponse<TResponse>;
var
  Url, Body: string;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  StartTime := Now;
  Url := BuildUrl(Endpoint, Options.QueryParams);
  Body := SerializeToJson<TRequest>(Data);
  
  try
    Response := ExecuteWithRetry('PATCH', Url, Body, Options);
    
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
    begin
      Result := TApiResponse<TResponse>.OK(
        DeserializeFromJson<TResponse>(Response.ContentAsString),
        Response.StatusCode);
    end
    else
    begin
      Result := TApiResponse<TResponse>.Error(
        Response.ContentAsString,
        Response.StatusCode);
    end;
  except
    on E: Exception do
      Result := TApiResponse<TResponse>.Error(E.Message, 0);
  end;
  
  Result.ResponseTime := MilliSecondsBetween(Now, StartTime);
end;

function TMicroserviceClient.Patch<TRequest, TResponse>(const Endpoint: string;
  const Data: TRequest): TApiResponse<TResponse>;
begin
  Result := Patch<TRequest, TResponse>(Endpoint, Data, TRequestOptions.Default);
end;

function TMicroserviceClient.Delete(const Endpoint: string;
  const Options: TRequestOptions): TApiResponse<Boolean>;
var
  Url: string;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  StartTime := Now;
  Url := BuildUrl(Endpoint, Options.QueryParams);
  
  try
    Response := ExecuteWithRetry('DELETE', Url, '', Options);
    
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
      Result := TApiResponse<Boolean>.OK(True, Response.StatusCode)
    else
      Result := TApiResponse<Boolean>.Error(Response.ContentAsString, Response.StatusCode);
  except
    on E: Exception do
      Result := TApiResponse<Boolean>.Error(E.Message, 0);
  end;
  
  Result.ResponseTime := MilliSecondsBetween(Now, StartTime);
end;

function TMicroserviceClient.Delete(const Endpoint: string): TApiResponse<Boolean>;
begin
  Result := Delete(Endpoint, TRequestOptions.Default);
end;

function TMicroserviceClient.GetRaw(const Endpoint: string;
  const Options: TRequestOptions): TApiResponse<string>;
var
  Url: string;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  StartTime := Now;
  Url := BuildUrl(Endpoint, Options.QueryParams);
  
  try
    Response := ExecuteWithRetry('GET', Url, '', Options);
    
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
      Result := TApiResponse<string>.OK(Response.ContentAsString, Response.StatusCode)
    else
      Result := TApiResponse<string>.Error(Response.ContentAsString, Response.StatusCode);
  except
    on E: Exception do
      Result := TApiResponse<string>.Error(E.Message, 0);
  end;
  
  Result.ResponseTime := MilliSecondsBetween(Now, StartTime);
end;

function TMicroserviceClient.PostRaw(const Endpoint: string; const Body: string;
  const Options: TRequestOptions): TApiResponse<string>;
var
  Url: string;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  StartTime := Now;
  Url := BuildUrl(Endpoint, Options.QueryParams);
  
  try
    Response := ExecuteWithRetry('POST', Url, Body, Options);
    
    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
      Result := TApiResponse<string>.OK(Response.ContentAsString, Response.StatusCode)
    else
      Result := TApiResponse<string>.Error(Response.ContentAsString, Response.StatusCode);
  except
    on E: Exception do
      Result := TApiResponse<string>.Error(E.Message, 0);
  end;
  
  Result.ResponseTime := MilliSecondsBetween(Now, StartTime);
end;

procedure TMicroserviceClient.BatchGet<T>(const Endpoints: TArray<string>;
  Callback: TProc<string, TApiResponse<T>>);
var
  Tasks: TArray<ITask>;
  I: Integer;
begin
  SetLength(Tasks, Length(Endpoints));
  
  for I := 0 to High(Endpoints) do
  begin
    var Endpoint := Endpoints[I];
    Tasks[I] := TTask.Run(
      procedure
      var
        Response: TApiResponse<T>;
      begin
        Response := Get<T>(Endpoint);
        TThread.Queue(nil,
          procedure
          begin
            Callback(Endpoint, Response);
          end);
      end);
  end;
  
  TTask.WaitForAll(Tasks);
end;

function TMicroserviceClient.HealthCheck(const Endpoint: string): Boolean;
var
  Response: TApiResponse<string>;
  Options: TRequestOptions;
begin
  Options := TRequestOptions.Default;
  Options.Timeout := 5000;
  Options.RetryPolicy := TRetryPolicy.NoRetry;
  Options.UseCircuitBreaker := False;
  
  Response := GetRaw(Endpoint, Options);
  Result := Response.Success and (Response.StatusCode = 200);
end;

// ============================================================================
// TServiceDiscovery
// ============================================================================

constructor TServiceDiscovery.Create;
begin
  inherited Create;
  FServices := TDictionary<string, TList<TServiceEndpoint>>.Create;
  FRoundRobinIndex := TDictionary<string, Integer>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TServiceDiscovery.Destroy;
var
  List: TList<TServiceEndpoint>;
begin
  for List in FServices.Values do
    List.Free;
  FServices.Free;
  FRoundRobinIndex.Free;
  FLock.Free;
  inherited;
end;

procedure TServiceDiscovery.RegisterService(const ServiceName, Url: string;
  Weight: Integer);
var
  Endpoint: TServiceEndpoint;
  List: TList<TServiceEndpoint>;
begin
  FLock.Enter;
  try
    if not FServices.TryGetValue(ServiceName, List) then
    begin
      List := TList<TServiceEndpoint>.Create;
      FServices.Add(ServiceName, List);
      FRoundRobinIndex.Add(ServiceName, 0);
    end;
    
    Endpoint.Name := ServiceName;
    Endpoint.Url := Url;
    Endpoint.Weight := Weight;
    Endpoint.IsHealthy := True;
    List.Add(Endpoint);
  finally
    FLock.Leave;
  end;
end;

procedure TServiceDiscovery.UnregisterService(const ServiceName, Url: string);
var
  List: TList<TServiceEndpoint>;
  I: Integer;
begin
  FLock.Enter;
  try
    if FServices.TryGetValue(ServiceName, List) then
    begin
      for I := List.Count - 1 downto 0 do
        if List[I].Url = Url then
        begin
          List.Delete(I);
          Break;
        end;
    end;
  finally
    FLock.Leave;
  end;
end;

function TServiceDiscovery.GetEndpoint(const ServiceName: string): string;
var
  List: TList<TServiceEndpoint>;
  Idx, StartIdx: Integer;
begin
  Result := '';
  
  FLock.Enter;
  try
    if not FServices.TryGetValue(ServiceName, List) then
      Exit;
    
    if List.Count = 0 then
      Exit;
    
    Idx := FRoundRobinIndex[ServiceName];
    StartIdx := Idx;
    
    repeat
      if List[Idx].IsHealthy then
      begin
        Result := List[Idx].Url;
        FRoundRobinIndex[ServiceName] := (Idx + 1) mod List.Count;
        Exit;
      end;
      Idx := (Idx + 1) mod List.Count;
    until Idx = StartIdx;
    
    // All unhealthy, return first one anyway
    Result := List[0].Url;
  finally
    FLock.Leave;
  end;
end;

function TServiceDiscovery.GetAllEndpoints(const ServiceName: string): TArray<TServiceEndpoint>;
var
  List: TList<TServiceEndpoint>;
begin
  FLock.Enter;
  try
    if FServices.TryGetValue(ServiceName, List) then
      Result := List.ToArray
    else
      SetLength(Result, 0);
  finally
    FLock.Leave;
  end;
end;

procedure TServiceDiscovery.MarkUnhealthy(const ServiceName, Url: string);
var
  List: TList<TServiceEndpoint>;
  I: Integer;
  Endpoint: TServiceEndpoint;
begin
  FLock.Enter;
  try
    if FServices.TryGetValue(ServiceName, List) then
    begin
      for I := 0 to List.Count - 1 do
        if List[I].Url = Url then
        begin
          Endpoint := List[I];
          Endpoint.IsHealthy := False;
          List[I] := Endpoint;
          Break;
        end;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TServiceDiscovery.MarkHealthy(const ServiceName, Url: string);
var
  List: TList<TServiceEndpoint>;
  I: Integer;
  Endpoint: TServiceEndpoint;
begin
  FLock.Enter;
  try
    if FServices.TryGetValue(ServiceName, List) then
    begin
      for I := 0 to List.Count - 1 do
        if List[I].Url = Url then
        begin
          Endpoint := List[I];
          Endpoint.IsHealthy := True;
          List[I] := Endpoint;
          Break;
        end;
    end;
  finally
    FLock.Leave;
  end;
end;

end.
