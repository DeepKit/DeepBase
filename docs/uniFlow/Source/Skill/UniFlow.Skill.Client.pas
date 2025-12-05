{******************************************************************************}
{                                                                              }
{  UniFlow Skill Client                                                        }
{  HTTP client for communicating with Python Skill service                     }
{                                                                              }
{  Features:                                                                   }
{  - Synchronous and asynchronous HTTP calls                                   }
{  - Connection pooling and retry logic                                        }
{  - Timeout handling                                                          }
{  - Health check support                                                      }
{                                                                              }
{******************************************************************************}

unit UniFlow.Skill.Client;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.JSON,
  System.Net.HttpClient,
  System.Net.URLClient,
  System.Threading,
  UniFlow.Skill.Types;

type
  //----------------------------------------------------------------------------
  // TSkillClientConfig - Client configuration
  //----------------------------------------------------------------------------

  TSkillClientConfig = class
  private
    FBaseURL: string;
    FTimeoutMs: Integer;
    FMaxRetries: Integer;
    FRetryDelayMs: Integer;
    FConnectTimeoutMs: Integer;
  public
    constructor Create;

    property BaseURL: string read FBaseURL write FBaseURL;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
    property RetryDelayMs: Integer read FRetryDelayMs write FRetryDelayMs;
    property ConnectTimeoutMs: Integer read FConnectTimeoutMs write FConnectTimeoutMs;
  end;

  //----------------------------------------------------------------------------
  // TSkillClient - HTTP client for Skill service
  //----------------------------------------------------------------------------

  TSkillClientCallback = reference to procedure(const AResponse: TSkillResponse);
  TLLMClientCallback = reference to procedure(const AResponse: TLLMResponse);
  THealthCallback = reference to procedure(const AResponse: THealthResponse);
  TErrorCallback = reference to procedure(const AError: string);

  TSkillClient = class
  private
    FConfig: TSkillClientConfig;
    FHttpClient: THTTPClient;
    FOwnsConfig: Boolean;

    function BuildURL(const AEndpoint: string): string;
    function DoRequest(const AMethod, AEndpoint: string;
      const ABody: TJSONObject = nil): TJSONObject;
    procedure DoRequestAsync(const AMethod, AEndpoint: string;
      const ABody: TJSONObject;
      const AOnSuccess: TProc<TJSONObject>;
      const AOnError: TErrorCallback);

    function ParseSkillResponse(const AJSON: TJSONObject): TSkillResponse;
    function ParseLLMResponse(const AJSON: TJSONObject): TLLMResponse;
    function ParseHealthResponse(const AJSON: TJSONObject): THealthResponse;
  public
    constructor Create(const ABaseURL: string); overload;
    constructor Create(AConfig: TSkillClientConfig; AOwnsConfig: Boolean = True); overload;
    destructor Destroy; override;

    //--------------------------------------------------------------------------
    // Health Check
    //--------------------------------------------------------------------------

    /// <summary>Check service health (sync)</summary>
    function CheckHealth: THealthResponse;

    /// <summary>Check service health (async)</summary>
    procedure CheckHealthAsync(const AOnSuccess: THealthCallback;
      const AOnError: TErrorCallback);

    /// <summary>Check if service is available</summary>
    function IsAvailable: Boolean;

    //--------------------------------------------------------------------------
    // Skill Operations
    //--------------------------------------------------------------------------

    /// <summary>List all available Skills (sync)</summary>
    function ListSkills: TObjectList<TSkillInfo>;

    /// <summary>Get Skill info by name (sync)</summary>
    function GetSkill(const ASkillName: string): TSkillInfo;

    /// <summary>Execute a Skill (sync)</summary>
    function ExecuteSkill(const ARequest: TSkillRequest): TSkillResponse; overload;
    function ExecuteSkill(const ASkillName: string;
      const AParams: TJSONObject = nil): TSkillResponse; overload;

    /// <summary>Execute a Skill (async)</summary>
    procedure ExecuteSkillAsync(const ARequest: TSkillRequest;
      const AOnSuccess: TSkillClientCallback;
      const AOnError: TErrorCallback); overload;
    procedure ExecuteSkillAsync(const ASkillName: string;
      const AParams: TJSONObject;
      const AOnSuccess: TSkillClientCallback;
      const AOnError: TErrorCallback); overload;

    //--------------------------------------------------------------------------
    // LLM Operations
    //--------------------------------------------------------------------------

    /// <summary>Chat completion (sync)</summary>
    function Chat(const ARequest: TLLMRequest): TLLMResponse; overload;
    function Chat(const AMessages: array of TLLMMessage;
      const AModel: string = ''): TLLMResponse; overload;

    /// <summary>Simple chat with single message (sync)</summary>
    function SimpleChat(const AUserMessage: string;
      const ASystemPrompt: string = '';
      const AModel: string = ''): string;

    /// <summary>Chat completion (async)</summary>
    procedure ChatAsync(const ARequest: TLLMRequest;
      const AOnSuccess: TLLMClientCallback;
      const AOnError: TErrorCallback);

    //--------------------------------------------------------------------------
    // Properties
    //--------------------------------------------------------------------------

    property Config: TSkillClientConfig read FConfig;
  end;

  //----------------------------------------------------------------------------
  // TSkillClientPool - Connection pool for multiple clients
  //----------------------------------------------------------------------------

  TSkillClientPool = class
  private
    FClients: TObjectList<TSkillClient>;
    FConfig: TSkillClientConfig;
    FPoolSize: Integer;
    FCurrentIndex: Integer;
    FLock: TObject;

    function GetClient: TSkillClient;
  public
    constructor Create(const ABaseURL: string; APoolSize: Integer = 4);
    destructor Destroy; override;

    /// <summary>Execute with pooled client</summary>
    function Execute(const ARequest: TSkillRequest): TSkillResponse;

    property PoolSize: Integer read FPoolSize;
  end;

implementation

uses
  System.DateUtils,
  System.NetEncoding;

//------------------------------------------------------------------------------
// TSkillClientConfig
//------------------------------------------------------------------------------

constructor TSkillClientConfig.Create;
begin
  inherited Create;
  FBaseURL := 'http://localhost:8000';
  FTimeoutMs := 30000;
  FMaxRetries := 3;
  FRetryDelayMs := 1000;
  FConnectTimeoutMs := 5000;
end;

//------------------------------------------------------------------------------
// TSkillClient
//------------------------------------------------------------------------------

constructor TSkillClient.Create(const ABaseURL: string);
begin
  FConfig := TSkillClientConfig.Create;
  FConfig.BaseURL := ABaseURL;
  FOwnsConfig := True;
  Create(FConfig, True);
end;

constructor TSkillClient.Create(AConfig: TSkillClientConfig; AOwnsConfig: Boolean);
begin
  inherited Create;
  FConfig := AConfig;
  FOwnsConfig := AOwnsConfig;

  FHttpClient := THTTPClient.Create;
  FHttpClient.ContentType := 'application/json';
  FHttpClient.Accept := 'application/json';
  FHttpClient.ResponseTimeout := FConfig.TimeoutMs;
  FHttpClient.ConnectionTimeout := FConfig.ConnectTimeoutMs;
end;

destructor TSkillClient.Destroy;
begin
  FHttpClient.Free;
  if FOwnsConfig then
    FConfig.Free;
  inherited Destroy;
end;

function TSkillClient.BuildURL(const AEndpoint: string): string;
begin
  Result := FConfig.BaseURL;
  if not Result.EndsWith('/') then
    Result := Result + '/';
  if AEndpoint.StartsWith('/') then
    Result := Result + AEndpoint.Substring(1)
  else
    Result := Result + AEndpoint;
end;

function TSkillClient.DoRequest(const AMethod, AEndpoint: string;
  const ABody: TJSONObject): TJSONObject;
var
  URL: string;
  Response: IHTTPResponse;
  RequestStream: TStringStream;
  ResponseStr: string;
  Attempt: Integer;
  LastError: string;
begin
  Result := nil;
  URL := BuildURL(AEndpoint);
  LastError := '';

  for Attempt := 1 to FConfig.MaxRetries do
  begin
    try
      RequestStream := nil;
      try
        if Assigned(ABody) then
          RequestStream := TStringStream.Create(ABody.ToString, TEncoding.UTF8);

        if SameText(AMethod, 'GET') then
          Response := FHttpClient.Get(URL)
        else if SameText(AMethod, 'POST') then
          Response := FHttpClient.Post(URL, RequestStream)
        else if SameText(AMethod, 'PUT') then
          Response := FHttpClient.Put(URL, RequestStream)
        else if SameText(AMethod, 'DELETE') then
          Response := FHttpClient.Delete(URL)
        else
          raise ESkillException.CreateFmt('Unsupported HTTP method: %s', [AMethod]);

        if Response.StatusCode >= 200 then
        begin
          if Response.StatusCode < 300 then
          begin
            ResponseStr := Response.ContentAsString(TEncoding.UTF8);
            if ResponseStr <> '' then
              Result := TJSONObject.ParseJSONValue(ResponseStr) as TJSONObject
            else
              Result := TJSONObject.Create;
            Exit;
          end
          else if Response.StatusCode = 404 then
            raise ESkillNotFound.CreateFmt('Resource not found: %s', [AEndpoint])
          else if Response.StatusCode >= 500 then
            LastError := Format('Server error: %d - %s',
              [Response.StatusCode, Response.StatusText])
          else
            raise ESkillException.CreateFmt('HTTP error: %d - %s',
              [Response.StatusCode, Response.StatusText]);
        end;

      finally
        RequestStream.Free;
      end;

    except
      on E: ESkillNotFound do
        raise;
      on E: Exception do
      begin
        LastError := E.Message;
        if Attempt < FConfig.MaxRetries then
          Sleep(FConfig.RetryDelayMs * Attempt);
      end;
    end;
  end;

  raise ESkillConnectionError.CreateFmt('Request failed after %d attempts: %s',
    [FConfig.MaxRetries, LastError]);
end;

procedure TSkillClient.DoRequestAsync(const AMethod, AEndpoint: string;
  const ABody: TJSONObject;
  const AOnSuccess: TProc<TJSONObject>;
  const AOnError: TErrorCallback);
begin
  TTask.Run(
    procedure
    var
      Response: TJSONObject;
    begin
      try
        Response := DoRequest(AMethod, AEndpoint, ABody);
        TThread.Synchronize(nil,
          procedure
          begin
            if Assigned(AOnSuccess) then
              AOnSuccess(Response);
          end);
      except
        on E: Exception do
        begin
          TThread.Synchronize(nil,
            procedure
            begin
              if Assigned(AOnError) then
                AOnError(E.Message);
            end);
        end;
      end;
    end);
end;

function TSkillClient.ParseSkillResponse(const AJSON: TJSONObject): TSkillResponse;
begin
  Result := TSkillResponse.FromJSON(AJSON);
end;

function TSkillClient.ParseLLMResponse(const AJSON: TJSONObject): TLLMResponse;
begin
  Result := TLLMResponse.FromJSON(AJSON);
end;

function TSkillClient.ParseHealthResponse(const AJSON: TJSONObject): THealthResponse;
begin
  Result := THealthResponse.FromJSON(AJSON);
end;

//------------------------------------------------------------------------------
// Health Check
//------------------------------------------------------------------------------

function TSkillClient.CheckHealth: THealthResponse;
var
  ResponseJSON: TJSONObject;
begin
  ResponseJSON := DoRequest('GET', '/health');
  try
    Result := ParseHealthResponse(ResponseJSON);
  finally
    ResponseJSON.Free;
  end;
end;

procedure TSkillClient.CheckHealthAsync(const AOnSuccess: THealthCallback;
  const AOnError: TErrorCallback);
begin
  DoRequestAsync('GET', '/health', nil,
    procedure(Response: TJSONObject)
    var
      HealthResponse: THealthResponse;
    begin
      try
        HealthResponse := ParseHealthResponse(Response);
        if Assigned(AOnSuccess) then
          AOnSuccess(HealthResponse);
      finally
        Response.Free;
        HealthResponse.Free;
      end;
    end,
    AOnError);
end;

function TSkillClient.IsAvailable: Boolean;
var
  Health: THealthResponse;
begin
  try
    Health := CheckHealth;
    try
      Result := Health.IsHealthy;
    finally
      Health.Free;
    end;
  except
    Result := False;
  end;
end;

//------------------------------------------------------------------------------
// Skill Operations
//------------------------------------------------------------------------------

function TSkillClient.ListSkills: TObjectList<TSkillInfo>;
var
  ResponseJSON: TJSONObject;
  SkillsArray: TJSONArray;
  I: Integer;
begin
  Result := TObjectList<TSkillInfo>.Create(True);
  try
    // The endpoint returns an array directly
    ResponseJSON := DoRequest('GET', '/skills');
    try
      if ResponseJSON is TJSONArray then
      begin
        SkillsArray := ResponseJSON as TJSONArray;
        for I := 0 to SkillsArray.Count - 1 do
          Result.Add(TSkillInfo.FromJSON(SkillsArray.Items[I] as TJSONObject));
      end;
    finally
      ResponseJSON.Free;
    end;
  except
    Result.Free;
    raise;
  end;
end;

function TSkillClient.GetSkill(const ASkillName: string): TSkillInfo;
var
  ResponseJSON: TJSONObject;
begin
  ResponseJSON := DoRequest('GET', '/skills/' + TNetEncoding.URL.Encode(ASkillName));
  try
    Result := TSkillInfo.FromJSON(ResponseJSON);
  finally
    ResponseJSON.Free;
  end;
end;

function TSkillClient.ExecuteSkill(const ARequest: TSkillRequest): TSkillResponse;
var
  RequestJSON, ResponseJSON: TJSONObject;
begin
  RequestJSON := ARequest.ToJSON;
  try
    ResponseJSON := DoRequest('POST', '/skills/execute', RequestJSON);
    try
      Result := ParseSkillResponse(ResponseJSON);
    finally
      ResponseJSON.Free;
    end;
  finally
    RequestJSON.Free;
  end;
end;

function TSkillClient.ExecuteSkill(const ASkillName: string;
  const AParams: TJSONObject): TSkillResponse;
var
  Request: TSkillRequest;
begin
  Request := TSkillRequest.Create;
  try
    Request.SkillName := ASkillName;
    if Assigned(AParams) then
    begin
      Request.FParams.Free;
      Request.FParams := AParams.Clone as TJSONObject;
    end;
    Result := ExecuteSkill(Request);
  finally
    Request.Free;
  end;
end;

procedure TSkillClient.ExecuteSkillAsync(const ARequest: TSkillRequest;
  const AOnSuccess: TSkillClientCallback;
  const AOnError: TErrorCallback);
var
  RequestJSON: TJSONObject;
begin
  RequestJSON := ARequest.ToJSON;
  DoRequestAsync('POST', '/skills/execute', RequestJSON,
    procedure(Response: TJSONObject)
    var
      SkillResponse: TSkillResponse;
    begin
      RequestJSON.Free;
      try
        SkillResponse := ParseSkillResponse(Response);
        if Assigned(AOnSuccess) then
          AOnSuccess(SkillResponse);
      finally
        Response.Free;
        SkillResponse.Free;
      end;
    end,
    procedure(const Error: string)
    begin
      RequestJSON.Free;
      if Assigned(AOnError) then
        AOnError(Error);
    end);
end;

procedure TSkillClient.ExecuteSkillAsync(const ASkillName: string;
  const AParams: TJSONObject;
  const AOnSuccess: TSkillClientCallback;
  const AOnError: TErrorCallback);
var
  Request: TSkillRequest;
begin
  Request := TSkillRequest.Create;
  Request.SkillName := ASkillName;
  if Assigned(AParams) then
  begin
    Request.FParams.Free;
    Request.FParams := AParams.Clone as TJSONObject;
  end;

  ExecuteSkillAsync(Request,
    procedure(const Response: TSkillResponse)
    begin
      Request.Free;
      if Assigned(AOnSuccess) then
        AOnSuccess(Response);
    end,
    procedure(const Error: string)
    begin
      Request.Free;
      if Assigned(AOnError) then
        AOnError(Error);
    end);
end;

//------------------------------------------------------------------------------
// LLM Operations
//------------------------------------------------------------------------------

function TSkillClient.Chat(const ARequest: TLLMRequest): TLLMResponse;
var
  RequestJSON, ResponseJSON: TJSONObject;
begin
  RequestJSON := ARequest.ToJSON;
  try
    ResponseJSON := DoRequest('POST', '/llm/chat', RequestJSON);
    try
      Result := ParseLLMResponse(ResponseJSON);
    finally
      ResponseJSON.Free;
    end;
  finally
    RequestJSON.Free;
  end;
end;

function TSkillClient.Chat(const AMessages: array of TLLMMessage;
  const AModel: string): TLLMResponse;
var
  Request: TLLMRequest;
  Msg: TLLMMessage;
begin
  Request := TLLMRequest.Create;
  try
    if AModel <> '' then
      Request.Model := AModel;

    for Msg in AMessages do
      Request.Messages.Add(TLLMMessage.Create(Msg.Role, Msg.Content));

    Result := Chat(Request);
  finally
    Request.Free;
  end;
end;

function TSkillClient.SimpleChat(const AUserMessage: string;
  const ASystemPrompt: string;
  const AModel: string): string;
var
  Request: TLLMRequest;
  Response: TLLMResponse;
begin
  Request := TLLMRequest.Create;
  try
    if AModel <> '' then
      Request.Model := AModel;

    if ASystemPrompt <> '' then
      Request.AddSystemMessage(ASystemPrompt);

    Request.AddUserMessage(AUserMessage);

    Response := Chat(Request);
    try
      Result := Response.Content;
    finally
      Response.Free;
    end;
  finally
    Request.Free;
  end;
end;

procedure TSkillClient.ChatAsync(const ARequest: TLLMRequest;
  const AOnSuccess: TLLMClientCallback;
  const AOnError: TErrorCallback);
var
  RequestJSON: TJSONObject;
begin
  RequestJSON := ARequest.ToJSON;
  DoRequestAsync('POST', '/llm/chat', RequestJSON,
    procedure(Response: TJSONObject)
    var
      LLMResponse: TLLMResponse;
    begin
      RequestJSON.Free;
      try
        LLMResponse := ParseLLMResponse(Response);
        if Assigned(AOnSuccess) then
          AOnSuccess(LLMResponse);
      finally
        Response.Free;
        LLMResponse.Free;
      end;
    end,
    procedure(const Error: string)
    begin
      RequestJSON.Free;
      if Assigned(AOnError) then
        AOnError(Error);
    end);
end;

//------------------------------------------------------------------------------
// TSkillClientPool
//------------------------------------------------------------------------------

constructor TSkillClientPool.Create(const ABaseURL: string; APoolSize: Integer);
var
  I: Integer;
begin
  inherited Create;
  FLock := TObject.Create;
  FPoolSize := APoolSize;
  FCurrentIndex := 0;

  FConfig := TSkillClientConfig.Create;
  FConfig.BaseURL := ABaseURL;

  FClients := TObjectList<TSkillClient>.Create(True);
  for I := 1 to FPoolSize do
    FClients.Add(TSkillClient.Create(FConfig, False));
end;

destructor TSkillClientPool.Destroy;
begin
  FClients.Free;
  FConfig.Free;
  FLock.Free;
  inherited Destroy;
end;

function TSkillClientPool.GetClient: TSkillClient;
begin
  TMonitor.Enter(FLock);
  try
    Result := FClients[FCurrentIndex];
    FCurrentIndex := (FCurrentIndex + 1) mod FPoolSize;
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TSkillClientPool.Execute(const ARequest: TSkillRequest): TSkillResponse;
var
  Client: TSkillClient;
begin
  Client := GetClient;
  Result := Client.ExecuteSkill(ARequest);
end;

end.
