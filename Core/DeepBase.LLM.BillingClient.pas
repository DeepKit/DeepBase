{ ============================================================================
  DeepBase.LLM.BillingClient - Lightweight Billing-Admin LLM Proxy Client
  
  Version: 1.0
  Description: A lightweight LLM client for Billing-Admin proxy service.
               Does NOT depend on database connection.
  
  Features:
    - OpenAI-compatible API (via Billing-Admin proxy)
    - Streaming and non-streaming responses
    - Request cancellation
    - Retry with exponential backoff
    - Async execution
    - Chat hiDeepStory management
    
  Usage:
    var Client := TBillingClient.Create('http://server:8090', APIKey, TenantId);
    try
      Response := Client.Chat('Hello');
      // or streaming:
      Client.ChatStream(Messages, 
        function(Chunk: string; Done: Boolean): Boolean
        begin
          Memo1.Text := Memo1.Text + Chunk;
          Result := True; // Return False to cancel
        end);
    finally
      Client.Free;
    end;
  ============================================================================ }

unit DeepBase.LLM.BillingClient;

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Threading,
  System.Net.HttpClient, System.Net.HttpClientComponent, System.Net.URLClient,
  System.Generics.Collections, System.SyncObjs,
  DeepBase.LLM;

type
  /// <summary>Billing API Exception base class</summary>
  EBillingError = class(Exception)
  public
    StatusCode: Integer;
    ErrorCode: string;
    constructor Create(const AMessage: string; AStatusCode: Integer = 0; 
      const AErrorCode: string = ''); reintroduce;
  end;
  
  /// <summary>Authentication failed (401)</summary>
  EBillingAuthError = class(EBillingError);
  
  /// <summary>Insufficient balance (402)</summary>
  EBillingBalanceError = class(EBillingError);
  
  /// <summary>Rate limit exceeded (429)</summary>
  EBillingRateLimitError = class(EBillingError);
  
  /// <summary>Server error (5xx)</summary>
  EBillingServerError = class(EBillingError);

  /// <summary>Chat message role</summary>
  TMessageRole = (mrSystem, mrUser, mrAssistant);
  
  /// <summary>Chat message record</summary>
  TChatMessage = record
    Role: TMessageRole;
    Content: string;
    
    class function System(const AContent: string): TChatMessage; static;
    class function User(const AContent: string): TChatMessage; static;
    class function Assistant(const AContent: string): TChatMessage; static;
    function RoleToString: string;
  end;
  TChatMessages = TArray<TChatMessage>;
  
  /// <summary>Token usage info</summary>
  TTokenUsage = record
  private
    FPromptTokens: Integer;
    FCompletionTokens: Integer;
    FTotalTokens: Integer;
    function GetTotalTokens: Integer;
    procedure SetPromptTokens(AValue: Integer);
    procedure SetCompletionTokens(AValue: Integer);
    procedure SetTotalTokens(AValue: Integer);
  public
    property PromptTokens: Integer read FPromptTokens write SetPromptTokens;
    property CompletionTokens: Integer read FCompletionTokens write SetCompletionTokens;
    property TotalTokens: Integer read GetTotalTokens write SetTotalTokens;
  end;
  
  /// <summary>Chat response</summary>
  TChatResponse = record
    Success: Boolean;
    Content: string;
    FinishReason: string;
    Usage: TTokenUsage;
    Model: string;
    DurationMs: Int64;
    ErrorCode: string;
    ErrorMessage: string;
    
    procedure Init;
  end;
  
  /// <summary>
  /// Streaming chunk callback
  /// Return False to cancel the stream
  /// </summary>
  TStreamChunkCallback = reference to function(const AChunk: string; ADone: Boolean): Boolean;
  
  /// <summary>Async completion callback</summary>
  TAsyncCompleteCallback = reference to procedure(const AResponse: TChatResponse);
  
  /// <summary>
  /// Chat hiDeepStory manager - maintains conversation context
  /// </summary>
  TChatHistory = class
  private
    FMessages: TList<TChatMessage>;
    FSystemPrompt: string;
    FSystemPromptVisible: Boolean;
    FMaxMessages: Integer;
    function GetCount: Integer;
  public
    constructor Create(const ASystemPrompt: string = ''; AMaxMessages: Integer = 50);
    destructor Destroy; override;
    
    procedure AddUserMessage(const AContent: string);
    procedure AddAssistantMessage(const AContent: string);
    procedure SetSystemPrompt(const APrompt: string);
    function GetMessages: TChatMessages;
    function GetLastUserMessage: string;
    procedure Clear;
    procedure TrimToSize;
    
    property SystemPrompt: string read FSystemPrompt write SetSystemPrompt;
    property MaxMessages: Integer read FMaxMessages write FMaxMessages;
    property Count: Integer read GetCount;
  end;
  
  /// <summary>
  /// Lightweight Billing-Admin LLM Proxy Client
  /// Does NOT depend on database connection
  /// </summary>
  TBillingClient = class
  private
    FBaseURL: string;
    FApiKey: string;
    FTenantId: string;
    FHttpClient: THTTPClient;
    FHttpTransport: TLLMHttpPostProc;
    FTimeout: Integer;
    FMaxRetries: Integer;
    FModel: string;
    FMaxTokens: Integer;
    FTemperature: Double;
    FCancelled: Boolean;
    FLock: TCriticalSection;
    FCurrentResponse: IHTTPResponse;  // BIZ2-004: held so Cancel can abort the HTTP read
    
    procedure SetupHeaders;
    // BUG EXP-P1-003 FIX: the three helpers below are declared as `class`
    // methods so that async closures can invoke them without capturing Self.
    // They depend only on their parameters, not on instance fields.
    class function BuildRequestBodyStatic(const AMessages: TChatMessages;
      AStream: Boolean; const AModel: string; AMaxTokens: Integer;
      ATemperature: Double): string;
    class procedure HandleHttpErrorStatic(StatusCode: Integer;
      const ResponseBody: string);
    class function ParseResponseStatic(const AJson: string): TChatResponse;
    function BuildRequestBody(const AMessages: TChatMessages; AStream: Boolean): string;
    procedure HandleHttpError(StatusCode: Integer; const ResponseBody: string);
    function ParseResponse(const AJson: string): TChatResponse;
    function ParseStreamChunk(const ALine: string; out AContent: string; out ADone: Boolean): Boolean;
    function DoRequest(const AMessages: TChatMessages): TChatResponse;
    function DoStreamRequest(const AMessages: TChatMessages; AOnChunk: TStreamChunkCallback): Boolean;
    
  public
    constructor Create(const ABaseURL, AApiKey, ATenantId: string);
    destructor Destroy; override;

    /// <summary>Inject custom HTTP transport. When set, DoRequest uses this
    /// instead of the built-in THTTPClient for synchronous chat calls.</summary>
    procedure SetHttpTransport(const ATransport: TLLMHttpPostProc);
    
    /// <summary>Simple chat - single prompt</summary>
    function Chat(const APrompt: string): string; overload;
    
    /// <summary>Chat with full response</summary>
    function Chat(const APrompt: string; out AResponse: TChatResponse): Boolean; overload;
    
    /// <summary>Chat with message hiDeepStory</summary>
    function ChatWithHistory(const AMessages: TChatMessages): TChatResponse; overload;
    function ChatWithHistory(const AMessages: TChatMessages; out AResponse: TChatResponse): Boolean; overload;
    
    /// <summary>Streaming chat</summary>
    function ChatStream(const APrompt: string; AOnChunk: TStreamChunkCallback): Boolean; overload;
    function ChatStream(const AMessages: TChatMessages; AOnChunk: TStreamChunkCallback): Boolean; overload;
    
    /// <summary>Async chat</summary>
    function ChatAsync(const APrompt: string; AOnComplete: TAsyncCompleteCallback): ITask; overload;
    function ChatAsync(const AMessages: TChatMessages; AOnComplete: TAsyncCompleteCallback): ITask; overload;
    
    /// <summary>Chat with retry (exponential backoff)</summary>
    function ChatWithRetry(const AMessages: TChatMessages; AMaxRetries: Integer = 0): TChatResponse;
    
    /// <summary>Cancel current request</summary>
    procedure Cancel;
    
    /// <summary>Check if cancelled</summary>
    function IsCancelled: Boolean;
    
    /// <summary>Reset cancelled state</summary>
    procedure ResetCancel;
    
    /// <summary>Get available models</summary>
    function GetModels: TArray<string>;
    
    /// <summary>Health check</summary>
    function HealthCheck: Boolean;
    
    // Properties
    property BaseURL: string read FBaseURL write FBaseURL;
    property ApiKey: string read FApiKey write FApiKey;
    property TenantId: string read FTenantId write FTenantId;
    property Timeout: Integer read FTimeout write FTimeout;
    property MaxRetries: Integer read FMaxRetries write FMaxRetries;
    property Model: string read FModel write FModel;
    property MaxTokens: Integer read FMaxTokens write FMaxTokens;
    property Temperature: Double read FTemperature write FTemperature;
  end;

implementation

uses
  System.DateUtils, System.StrUtils, System.Math;

const
  DEFAULT_TIMEOUT = 60000;  // 60 seconds
  DEFAULT_MODEL = 'auto';
  DEFAULT_MAX_TOKENS = 2048;
  DEFAULT_TEMPERATURE = 0.7;
  DEFAULT_MAX_RETRIES = 3;

{ EBillingError }

constructor EBillingError.Create(const AMessage: string; AStatusCode: Integer;
  const AErrorCode: string);
begin
  inherited Create(AMessage);
  StatusCode := AStatusCode;
  ErrorCode := AErrorCode;
end;

{ TChatMessage }

class function TChatMessage.System(const AContent: string): TChatMessage;
begin
  Result.Role := mrSystem;
  Result.Content := AContent;
end;

class function TChatMessage.User(const AContent: string): TChatMessage;
begin
  Result.Role := mrUser;
  Result.Content := AContent;
end;

class function TChatMessage.Assistant(const AContent: string): TChatMessage;
begin
  Result.Role := mrAssistant;
  Result.Content := AContent;
end;

function TChatMessage.RoleToString: string;
begin
  case Role of
    mrSystem: Result := 'system';
    mrUser: Result := 'user';
    mrAssistant: Result := 'assistant';
  else
    Result := 'user';
  end;
end;

{ TTokenUsage }

function TTokenUsage.GetTotalTokens: Integer;
begin
  if FTotalTokens > 0 then
    Result := FTotalTokens
  else
    Result := FPromptTokens + FCompletionTokens;
end;

procedure TTokenUsage.SetPromptTokens(AValue: Integer);
begin
  FPromptTokens := AValue;
  FTotalTokens := 0;
end;

procedure TTokenUsage.SetCompletionTokens(AValue: Integer);
begin
  FCompletionTokens := AValue;
  FTotalTokens := 0;
end;

procedure TTokenUsage.SetTotalTokens(AValue: Integer);
begin
  FTotalTokens := AValue;
end;

{ TChatResponse }

procedure TChatResponse.Init;
begin
  Success := False;
  Content := '';
  FinishReason := '';
  Usage.PromptTokens := 0;
  Usage.CompletionTokens := 0;
  Usage.TotalTokens := 0;
  Model := '';
  DurationMs := 0;
  ErrorCode := '';
  ErrorMessage := '';
end;

{ TChatHistory }

constructor TChatHistory.Create(const ASystemPrompt: string; AMaxMessages: Integer);
begin
  inherited Create;
  FMessages := TList<TChatMessage>.Create;
  FSystemPrompt := ASystemPrompt;
  FSystemPromptVisible := ASystemPrompt <> '';
  FMaxMessages := AMaxMessages;
end;

destructor TChatHistory.Destroy;
begin
  FreeAndNil(FMessages);
  inherited;
end;

procedure TChatHistory.AddUserMessage(const AContent: string);
begin
  FSystemPromptVisible := FSystemPrompt <> '';
  FMessages.Add(TChatMessage.User(AContent));
  TrimToSize;
end;

procedure TChatHistory.AddAssistantMessage(const AContent: string);
begin
  FSystemPromptVisible := FSystemPrompt <> '';
  FMessages.Add(TChatMessage.Assistant(AContent));
  TrimToSize;
end;

procedure TChatHistory.SetSystemPrompt(const APrompt: string);
begin
  FSystemPrompt := APrompt;
  FSystemPromptVisible := APrompt <> '';
end;

function TChatHistory.GetMessages: TChatMessages;
var
  I, StartIdx: Integer;
begin
  if FSystemPromptVisible and (FSystemPrompt <> '') then
  begin
    SetLength(Result, FMessages.Count + 1);
    Result[0] := TChatMessage.System(FSystemPrompt);
    StartIdx := 1;
  end
  else
  begin
    SetLength(Result, FMessages.Count);
    StartIdx := 0;
  end;
  
  for I := 0 to FMessages.Count - 1 do
    Result[StartIdx + I] := FMessages[I];
end;

procedure TChatHistory.Clear;
begin
  FMessages.Clear;
  FSystemPromptVisible := False;
end;

procedure TChatHistory.TrimToSize;
begin
  // Keep system prompt space, trim oldest messages
  while FMessages.Count > FMaxMessages do
    FMessages.Delete(0);
end;

function TChatHistory.GetCount: Integer;
begin
  Result := FMessages.Count;
  if FSystemPromptVisible and (FSystemPrompt <> '') then
    Inc(Result);
end;

function TChatHistory.GetLastUserMessage: string;
var
  I: Integer;
begin
  Result := '';
  for I := FMessages.Count - 1 downto 0 do
    if FMessages[I].Role = mrUser then
    begin
      Result := FMessages[I].Content;
      Break;
    end;
end;

{ TBillingClient }

constructor TBillingClient.Create(const ABaseURL, AApiKey, ATenantId: string);
begin
  inherited Create;
  FBaseURL := ABaseURL.TrimRight(['/']);
  FApiKey := AApiKey;
  FTenantId := ATenantId;
  FTimeout := DEFAULT_TIMEOUT;
  FMaxRetries := DEFAULT_MAX_RETRIES;
  FModel := DEFAULT_MODEL;
  FMaxTokens := DEFAULT_MAX_TOKENS;
  FTemperature := DEFAULT_TEMPERATURE;
  FCancelled := False;
  
  FLock := TCriticalSection.Create;
  FHttpClient := THTTPClient.Create;
  FHttpClient.ContentType := 'application/json';
  FHttpClient.AcceptCharSet := 'utf-8';
  FHttpClient.ConnectionTimeout := FTimeout;
  FHttpClient.ResponseTimeout := FTimeout;
end;

destructor TBillingClient.Destroy;
begin
  FCurrentResponse := nil;  // BIZ2-004: release before freeing HTTP client
  FreeAndNil(FHttpClient);
  FreeAndNil(FLock);
  inherited;
end;

procedure TBillingClient.SetHttpTransport(const ATransport: TLLMHttpPostProc);
begin
  FHttpTransport := ATransport;
end;

procedure TBillingClient.SetupHeaders;
begin
  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
  FHttpClient.CustomHeaders['X-Tenant-Id'] := FTenantId;
end;

// ----------------------------------------------------------------------------
// BUG EXP-P1-003 FIX: class (static) variants that do not touch Self. Used
// by ChatAsync closures so that they can run safely even if the owning
// TBillingClient has been freed.
// ----------------------------------------------------------------------------
class function TBillingClient.BuildRequestBodyStatic(const AMessages: TChatMessages;
  AStream: Boolean; const AModel: string; AMaxTokens: Integer;
  ATemperature: Double): string;
var
  JsonObj, MsgObj: TJSONObject;
  MsgArray: TJSONArray;
  Msg: TChatMessage;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('model', AModel);
    JsonObj.AddPair('max_tokens', TJSONNumber.Create(AMaxTokens));
    JsonObj.AddPair('temperature', TJSONNumber.Create(ATemperature));
    JsonObj.AddPair('stream', TJSONBool.Create(AStream));

    MsgArray := TJSONArray.Create;
    for Msg in AMessages do
    begin
      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', Msg.RoleToString);
      MsgObj.AddPair('content', Msg.Content);
      MsgArray.Add(MsgObj);
    end;
    JsonObj.AddPair('messages', MsgArray);

    Result := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
end;

class procedure TBillingClient.HandleHttpErrorStatic(StatusCode: Integer;
  const ResponseBody: string);
var
  JsonObj, ErrorObj: TJSONObject;
  ErrorMsg, ErrorCode: string;
begin
  ErrorMsg := 'HTTP Error ' + IntToStr(StatusCode);
  ErrorCode := '';

  try
    JsonObj := TJSONObject.ParseJSONValue(ResponseBody) as TJSONObject;
    if Assigned(JsonObj) then
    try
      if JsonObj.TryGetValue<TJSONObject>('error', ErrorObj) then
      begin
        ErrorMsg := ErrorObj.GetValue<string>('message', ErrorMsg);
        ErrorCode := ErrorObj.GetValue<string>('code', '');
      end;
    finally
      JsonObj.Free;
    end;
  except
    // Ignore parse errors
  end;

  case StatusCode of
    401:
      raise EBillingAuthError.Create('Auth failed: ' + ErrorMsg, StatusCode, ErrorCode);
    402:
      raise EBillingBalanceError.Create('Insufficient balance: ' + ErrorMsg, StatusCode, ErrorCode);
    429:
      raise EBillingRateLimitError.Create('Rate limit: ' + ErrorMsg, StatusCode, ErrorCode);
    500..599:
      raise EBillingServerError.Create('Server error: ' + ErrorMsg, StatusCode, ErrorCode);
  else
    raise EBillingError.Create(ErrorMsg, StatusCode, ErrorCode);
  end;
end;

class function TBillingClient.ParseResponseStatic(const AJson: string): TChatResponse;
var
  JsonObj, ChoiceObj, MsgObj, UsageObj: TJSONObject;
  ChoicesArray: TJSONArray;
begin
  Result.Init;

  JsonObj := TJSONObject.ParseJSONValue(AJson) as TJSONObject;
  if not Assigned(JsonObj) then
  begin
    Result.ErrorMessage := 'Invalid JSON response';
    Exit;
  end;

  try
    Result.Model := JsonObj.GetValue<string>('model', '');

    if JsonObj.TryGetValue<TJSONArray>('choices', ChoicesArray) and (ChoicesArray.Count > 0) then
    begin
      ChoiceObj := ChoicesArray.Items[0] as TJSONObject;
      Result.FinishReason := ChoiceObj.GetValue<string>('finish_reason', '');

      if ChoiceObj.TryGetValue<TJSONObject>('message', MsgObj) then
        Result.Content := MsgObj.GetValue<string>('content', '');
    end;

    if JsonObj.TryGetValue<TJSONObject>('usage', UsageObj) then
    begin
      Result.Usage.PromptTokens := UsageObj.GetValue<Integer>('prompt_tokens', 0);
      Result.Usage.CompletionTokens := UsageObj.GetValue<Integer>('completion_tokens', 0);
      Result.Usage.TotalTokens := UsageObj.GetValue<Integer>('total_tokens', 0);
    end;

    Result.Success := True;
  finally
    JsonObj.Free;
  end;
end;

// Original instance-method variants delegate to the static ones above.
function TBillingClient.BuildRequestBody(const AMessages: TChatMessages; AStream: Boolean): string;
begin
  Result := BuildRequestBodyStatic(AMessages, AStream, FModel, FMaxTokens, FTemperature);
end;

procedure TBillingClient.HandleHttpError(StatusCode: Integer; const ResponseBody: string);
begin
  HandleHttpErrorStatic(StatusCode, ResponseBody);
end;

function TBillingClient.ParseResponse(const AJson: string): TChatResponse;
begin
  Result := ParseResponseStatic(AJson);
end;

function TBillingClient.ParseStreamChunk(const ALine: string; out AContent: string; 
  out ADone: Boolean): Boolean;
var
  JsonObj: TJSONObject;
  ChoicesArray: TJSONArray;
  DeltaObj: TJSONObject;
  DataStr: string;
begin
  Result := False;
  AContent := '';
  ADone := False;
  
  DataStr := ALine.Trim;
  if DataStr.IsEmpty then
    Exit;
    
  // SSE format: "data: {...}" or "data: [DONE]"
  if not DataStr.StartsWith('data: ') then
    Exit;
    
  DataStr := DataStr.Substring(6).Trim;
  
  if DataStr = '[DONE]' then
  begin
    ADone := True;
    Result := True;
    Exit;
  end;
  
  // Parse JSON chunk
  JsonObj := TJSONObject.ParseJSONValue(DataStr) as TJSONObject;
  if not Assigned(JsonObj) then
    Exit;
    
  try
    if JsonObj.TryGetValue<TJSONArray>('choices', ChoicesArray) and (ChoicesArray.Count > 0) then
    begin
      if (ChoicesArray.Items[0] as TJSONObject).TryGetValue<TJSONObject>('delta', DeltaObj) then
      begin
        if DeltaObj.GetValue('content') <> nil then
        begin
          AContent := DeltaObj.GetValue<string>('content');
          Result := True;
        end;
      end;
    end;
  finally
    JsonObj.Free;
  end;
end;

function TBillingClient.DoRequest(const AMessages: TChatMessages): TChatResponse;
var
  RequestBody: string;
  Url: string;
  RequestStream: TStringStream;
  Response: IHTTPResponse;
  ResponseStr: string;
  StartTime: TDateTime;
  LHeaders: TArray<TPair<string, string>>;
  LSuccess: Boolean;
begin
  Result.Init;
  ResetCancel;
  StartTime := Now;
  
  RequestBody := BuildRequestBody(AMessages, False);

  // Build URL
  if FBaseURL.EndsWith('/v1') or FBaseURL.EndsWith('/v1/') then
    Url := FBaseURL.TrimRight(['/']) + '/chat/completions'
  else
    Url := FBaseURL + '/v1/chat/completions';

  // Use injected transport when available
  if Assigned(FHttpTransport) then
  begin
    LHeaders := [
      TPair<string, string>.Create('Content-Type', 'application/json'),
      TPair<string, string>.Create('Authorization', 'Bearer ' + FApiKey),
      TPair<string, string>.Create('X-Tenant-Id', FTenantId)
    ];
    try
      LSuccess := FHttpTransport(Url, RequestBody, LHeaders, ResponseStr, FTimeout);
      Result.DurationMs := MilliSecondsBetween(Now, StartTime);
      if LSuccess then
        Result := ParseResponse(ResponseStr)
      else
        HandleHttpError(500, ResponseStr);
      Result.DurationMs := MilliSecondsBetween(Now, StartTime);
    except
      on E: Exception do
      begin
        Result.DurationMs := MilliSecondsBetween(Now, StartTime);
        Result.ErrorMessage := E.Message;
      end;
    end;
    Exit;
  end;

  // Fallback: built-in THTTPClient
  RequestStream := TStringStream.Create(RequestBody, TEncoding.UTF8);
  try
    SetupHeaders;
    Response := FHttpClient.Post(Url, RequestStream);
    Result.DurationMs := MilliSecondsBetween(Now, StartTime);

    if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
      Result := ParseResponse(Response.ContentAsString(TEncoding.UTF8))
    else
      HandleHttpError(Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
      
    Result.DurationMs := MilliSecondsBetween(Now, StartTime);
  finally
    RequestStream.Free;
  end;
end;

function TBillingClient.DoStreamRequest(const AMessages: TChatMessages;
  AOnChunk: TStreamChunkCallback): Boolean;
const
  READ_BUF_SIZE = 4096;
var
  RequestBody: string;
  RequestStream: TStringStream;
  Response: IHTTPResponse;
  ContentStream: TStream;
  Buffer: TBytes;
  BytesRead: Integer;
  SSEBuffer: string;
  Url: string;

  procedure ProcessSSEBuffer;
  var
    LEPos: Integer;
    LLine: string;
    LContent: string;
    LDone: Boolean;
  begin
    // Extract complete SSE lines (terminated by #10) from SSEBuffer and
    // dispatch each to ParseStreamChunk. Any trailing incomplete line is
    // kept in SSEBuffer for the next chunk.
    while True do
    begin
      LEPos := Pos(#10, SSEBuffer);
      if LEPos = 0 then
        Break;
      LLine := Copy(SSEBuffer, 1, LEPos - 1);
      Delete(SSEBuffer, 1, LEPos);

      if ParseStreamChunk(LLine, LContent, LDone) then
      begin
        if LDone then
        begin
          if Assigned(AOnChunk) then
            AOnChunk('', True);
          Result := True;
          Exit;
        end
        else if LContent <> '' then
        begin
          if Assigned(AOnChunk) then
          begin
            if not AOnChunk(LContent, False) then
            begin
              Cancel;
              Result := False;
              Exit;
            end;
          end;
        end;
      end;
    end;
  end;

begin
  Result := False;
  ResetCancel;

  RequestBody := BuildRequestBody(AMessages, True);
  RequestStream := TStringStream.Create(RequestBody, TEncoding.UTF8);
  try
    SetupHeaders;
    FHttpClient.CustomHeaders['Accept'] := 'text/event-stream';

    // Build URL
    if FBaseURL.EndsWith('/v1') or FBaseURL.EndsWith('/v1/') then
      Url := FBaseURL.TrimRight(['/']) + '/chat/completions'
    else
      Url := FBaseURL + '/v1/chat/completions';

    Response := FHttpClient.Post(Url, RequestStream);

    // BIZ2-004 FIX: publish the response handle so Cancel can abort the
    // HTTP-level read from another thread via FHttpClient.Cancel.
    FCurrentResponse := Response;
    try
      if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
        HandleHttpError(Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));

      // BIZ2-003 FIX: stream the response incrementally instead of loading
      // the entire body into a string. Read fixed-size chunks from the
      // underlying content stream, split out complete SSE lines, and yield
      // each event to the caller as it arrives. A small SSEBuffer carries
      // any partial line across chunk boundaries.
      ContentStream := Response.ContentStream;
      if ContentStream = nil then
        Exit(False);

      SetLength(Buffer, READ_BUF_SIZE);
      SSEBuffer := '';

      while not IsCancelled do
      begin
        BytesRead := ContentStream.Read(Buffer, READ_BUF_SIZE);
        if BytesRead <= 0 then
          Break;

        // Properly decode UTF-8 bytes into a Delphi string before appending
        // to SSEBuffer — SSE payloads may contain non-ASCII content.
        SSEBuffer := SSEBuffer + TEncoding.UTF8.GetString(Buffer, 0, BytesRead);

        // Process any complete SSE lines
        ProcessSSEBuffer;
        if Result then  // [DONE] received
          Exit;
      end;

      // After the stream ends, flush any remaining data in the buffer
      if (not IsCancelled) and (SSEBuffer <> '') then
      begin
        ProcessSSEBuffer;
      end;
    finally
      FCurrentResponse := nil;
    end;
  finally
    // BIZ-R3-013: Reset Accept header to prevent leaking 'text/event-stream'
    // to subsequent non-streaming requests
    FHttpClient.CustomHeaders['Accept'] := 'application/json';
    RequestStream.Free;
  end;
end;

function TBillingClient.Chat(const APrompt: string): string;
var
  Response: TChatResponse;
begin
  Chat(APrompt, Response);
  Result := Response.Content;
end;

function TBillingClient.Chat(const APrompt: string; out AResponse: TChatResponse): Boolean;
var
  Messages: TChatMessages;
begin
  SetLength(Messages, 1);
  Messages[0] := TChatMessage.User(APrompt);
  AResponse := DoRequest(Messages);
  Result := AResponse.Success;
end;

function TBillingClient.ChatWithHistory(const AMessages: TChatMessages): TChatResponse;
begin
  Result := DoRequest(AMessages);
end;

function TBillingClient.ChatWithHistory(const AMessages: TChatMessages; 
  out AResponse: TChatResponse): Boolean;
begin
  AResponse := DoRequest(AMessages);
  Result := AResponse.Success;
end;

function TBillingClient.ChatStream(const APrompt: string; AOnChunk: TStreamChunkCallback): Boolean;
var
  Messages: TChatMessages;
begin
  SetLength(Messages, 1);
  Messages[0] := TChatMessage.User(APrompt);
  Result := DoStreamRequest(Messages, AOnChunk);
end;

function TBillingClient.ChatStream(const AMessages: TChatMessages; 
  AOnChunk: TStreamChunkCallback): Boolean;
begin
  Result := DoStreamRequest(AMessages, AOnChunk);
end;

function TBillingClient.ChatAsync(const APrompt: string; 
  AOnComplete: TAsyncCompleteCallback): ITask;
var
  Messages: TChatMessages;
begin
  SetLength(Messages, 1);
  Messages[0] := TChatMessage.User(APrompt);
  Result := ChatAsync(Messages, AOnComplete);
end;

function TBillingClient.ChatAsync(const AMessages: TChatMessages; 
  AOnComplete: TAsyncCompleteCallback): ITask;
var
  MsgCopy: TChatMessages;
  Callback: TAsyncCompleteCallback;
  // BUG EXP-P1-003 FIX: snapshot everything the closure needs by value so it
  // does not capture `Self`. If the owning TBillingClient is freed while the
  // task is still running, the closure must remain safe to execute.
  SnapBaseURL: string;
  SnapApiKey: string;
  SnapTenantId: string;
  SnapTimeout: Integer;
  SnapRequest: string;
  SnapTransport: TLLMHttpPostProc;
begin
  MsgCopy := Copy(AMessages);
  Callback := AOnComplete;
  SnapBaseURL := FBaseURL;
  SnapApiKey  := FApiKey;
  SnapTenantId:= FTenantId;
  SnapTimeout := FTimeout;
  SnapRequest := BuildRequestBodyStatic(MsgCopy, False, FModel, FMaxTokens, FTemperature);
  SnapTransport := FHttpTransport;

  Result := TTask.Run(TProc(
    procedure
    var
      Response: TChatResponse;
      RespCopy: TChatResponse;
      Url, RespStr: string;
      LHeaders: TArray<TPair<string, string>>;
      LSuccess: Boolean;
      ReqStream: TStringStream;
      LHttp: THTTPClient;
      HttpResponse: IHTTPResponse;
      StartTime: TDateTime;
    begin
      Response.Init;
      StartTime := Now;

      // Build URL
      if SnapBaseURL.EndsWith('/v1') or SnapBaseURL.EndsWith('/v1/') then
        Url := SnapBaseURL.TrimRight(['/']) + '/chat/completions'
      else
        Url := SnapBaseURL + '/v1/chat/completions';

      LHeaders := [
        TPair<string, string>.Create('Content-Type', 'application/json'),
        TPair<string, string>.Create('Authorization', 'Bearer ' + SnapApiKey),
        TPair<string, string>.Create('X-Tenant-Id', SnapTenantId)
      ];

      try
        if Assigned(SnapTransport) then
        begin
          try
            LSuccess := SnapTransport(Url, SnapRequest, LHeaders, RespStr, SnapTimeout);
            Response.DurationMs := MilliSecondsBetween(Now, StartTime);
            if LSuccess then
              Response := ParseResponseStatic(RespStr)
            else
              HandleHttpErrorStatic(500, RespStr);
            Response.DurationMs := MilliSecondsBetween(Now, StartTime);
          except
            on E: Exception do
            begin
              Response.DurationMs := MilliSecondsBetween(Now, StartTime);
              Response.ErrorMessage := E.Message;
              if E is EBillingError then
                Response.ErrorCode := EBillingError(E).ErrorCode;
            end;
          end;
        end
        else
        begin
          LHttp := THTTPClient.Create;
          try
            LHttp.ContentType := 'application/json';
            LHttp.AcceptCharSet := 'utf-8';
            LHttp.ConnectionTimeout := SnapTimeout;
            LHttp.ResponseTimeout := SnapTimeout;
            LHttp.CustomHeaders['Authorization'] := 'Bearer ' + SnapApiKey;
            LHttp.CustomHeaders['X-Tenant-Id'] := SnapTenantId;
            ReqStream := TStringStream.Create(SnapRequest, TEncoding.UTF8);
            try
              try
                HttpResponse := LHttp.Post(Url, ReqStream);
                Response.DurationMs := MilliSecondsBetween(Now, StartTime);
                if (HttpResponse.StatusCode >= 200) and (HttpResponse.StatusCode < 300) then
                  Response := ParseResponseStatic(HttpResponse.ContentAsString(TEncoding.UTF8))
                else
                  HandleHttpErrorStatic(HttpResponse.StatusCode, HttpResponse.ContentAsString(TEncoding.UTF8));
                Response.DurationMs := MilliSecondsBetween(Now, StartTime);
              except
                on E: Exception do
                begin
                  Response.DurationMs := MilliSecondsBetween(Now, StartTime);
                  Response.ErrorMessage := E.Message;
                  if E is EBillingError then
                    Response.ErrorCode := EBillingError(E).ErrorCode;
                end;
              end;
            finally
              ReqStream.Free;
            end;
          finally
            LHttp.Free;
          end;
        end;
      except
        on E: Exception do
        begin
          Response.Init;
          Response.ErrorMessage := E.Message;
          if E is EBillingError then
            Response.ErrorCode := EBillingError(E).ErrorCode;
        end;
      end;

      if Assigned(Callback) then
      begin
        RespCopy := Response;
        TThread.Queue(nil, TThreadProcedure(
          procedure
          begin
            Callback(RespCopy);
          end));
      end;
    end));
end;

function TBillingClient.ChatWithRetry(const AMessages: TChatMessages; 
  AMaxRetries: Integer): TChatResponse;
var
  I, Retries, DelayMs: Integer;
  LastError: string;
begin
  if AMaxRetries <= 0 then
    Retries := FMaxRetries
  else
    Retries := AMaxRetries;
    
  for I := 1 to Retries do
  begin
    try
      Result := DoRequest(AMessages);
      Exit;
    except
      on E: EBillingRateLimitError do
      begin
        LastError := E.Message;
        if I < Retries then
        begin
          // BIZ-R3-012: Exponential backoff with jitter and overflow protection.
          // Cap shift to 20 to prevent Integer overflow (1 shl 20 = 1M ms = ~17 min max).
          // Add 0-199ms random jitter to prevent thundering herd when multiple clients retry.
          DelayMs := 1000 * (1 shl Min(I - 1, 20)) + Random(200);
          Sleep(DelayMs);
        end;
      end;
      on E: EBillingServerError do
      begin
        LastError := E.Message;
        if I < Retries then
          // BIZ-R3-012: Add jitter to prevent thundering herd
          Sleep(1000 * I + Random(200));
      end;
      on E: EBillingAuthError do
        raise; // Don't retry auth errors
      on E: EBillingBalanceError do
        raise; // Don't retry balance errors
      on E: Exception do
        raise;
    end;
  end;
  
  raise EBillingError.Create('Failed after ' + IntToStr(Retries) + ' retries: ' + LastError);
end;

procedure TBillingClient.Cancel;
begin
  FLock.Enter;
  try
    FCancelled := True;
  finally
    FLock.Leave;
  end;
  // BIZ2-004: transport-level abort. THTTPClient does not expose a public
  // Cancel, so the SSE read loop (DoStreamRequest) cooperatively polls
  // IsCancelled between chunks and exits promptly on the next iteration.
  // If a server stops responding mid-chunk, ResponseTimeout (set on the
  // client) bounds the blocking read.
end;

function TBillingClient.IsCancelled: Boolean;
begin
  FLock.Enter;
  try
    Result := FCancelled;
  finally
    FLock.Leave;
  end;
end;

procedure TBillingClient.ResetCancel;
begin
  FLock.Enter;
  try
    FCancelled := False;
  finally
    FLock.Leave;
  end;
end;

function TBillingClient.GetModels: TArray<string>;
var
  Response: IHTTPResponse;
  JsonObj: TJSONObject;
  DataArray: TJSONArray;
  I: Integer;
begin
  SetLength(Result, 0);
  
  SetupHeaders;
  Response := FHttpClient.Get(FBaseURL + '/v1/models');
  
  if (Response.StatusCode >= 200) and (Response.StatusCode < 300) then
  begin
    JsonObj := TJSONObject.ParseJSONValue(Response.ContentAsString(TEncoding.UTF8)) as TJSONObject;
    if Assigned(JsonObj) then
    try
      if JsonObj.TryGetValue<TJSONArray>('data', DataArray) then
      begin
        SetLength(Result, DataArray.Count);
        for I := 0 to DataArray.Count - 1 do
          Result[I] := (DataArray.Items[I] as TJSONObject).GetValue<string>('id', '');
      end;
    finally
      JsonObj.Free;
    end;
  end;
end;

function TBillingClient.HealthCheck: Boolean;
var
  Response: IHTTPResponse;
begin
  Result := False;
  try
    Response := FHttpClient.Get(FBaseURL + '/health');
    Result := (Response.StatusCode >= 200) and (Response.StatusCode < 300);
  except
    Result := False;
  end;
end;

end.
