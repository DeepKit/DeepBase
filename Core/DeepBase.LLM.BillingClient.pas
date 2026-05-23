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
  System.Generics.Collections, System.SyncObjs;

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
    FTimeout: Integer;
    FMaxRetries: Integer;
    FModel: string;
    FMaxTokens: Integer;
    FTemperature: Double;
    FCancelled: Boolean;
    FLock: TCriticalSection;
    
    procedure SetupHeaders;
    function BuildRequestBody(const AMessages: TChatMessages; AStream: Boolean): string;
    procedure HandleHttpError(StatusCode: Integer; const ResponseBody: string);
    function ParseResponse(const AJson: string): TChatResponse;
    function ParseStreamChunk(const ALine: string; out AContent: string; out ADone: Boolean): Boolean;
    function DoRequest(const AMessages: TChatMessages): TChatResponse;
    function DoStreamRequest(const AMessages: TChatMessages; AOnChunk: TStreamChunkCallback): Boolean;
    
  public
    constructor Create(const ABaseURL, AApiKey, ATenantId: string);
    destructor Destroy; override;
    
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
  System.DateUtils, System.StrUtils;

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
  FreeAndNil(FHttpClient);
  FreeAndNil(FLock);
  inherited;
end;

procedure TBillingClient.SetupHeaders;
begin
  FHttpClient.CustomHeaders['Authorization'] := 'Bearer ' + FApiKey;
  FHttpClient.CustomHeaders['X-Tenant-Id'] := FTenantId;
end;

function TBillingClient.BuildRequestBody(const AMessages: TChatMessages; AStream: Boolean): string;
var
  JsonObj, MsgObj: TJSONObject;
  MsgArray: TJSONArray;
  Msg: TChatMessage;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('model', FModel);
    JsonObj.AddPair('max_tokens', TJSONNumber.Create(FMaxTokens));
    JsonObj.AddPair('temperature', TJSONNumber.Create(FTemperature));
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

procedure TBillingClient.HandleHttpError(StatusCode: Integer; const ResponseBody: string);
var
  JsonObj, ErrorObj: TJSONObject;
  ErrorMsg, ErrorCode: string;
begin
  ErrorMsg := 'HTTP Error ' + IntToStr(StatusCode);
  ErrorCode := '';
  
  // Try to parse error response
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
      raise EBillingAuthError.Create('��֤ʧ��: ' + ErrorMsg, StatusCode, ErrorCode);
    402:
      raise EBillingBalanceError.Create('����: ' + ErrorMsg, StatusCode, ErrorCode);
    429:
      raise EBillingRateLimitError.Create('�������Ƶ��: ' + ErrorMsg, StatusCode, ErrorCode);
    500..599:
      raise EBillingServerError.Create('����������: ' + ErrorMsg, StatusCode, ErrorCode);
  else
    raise EBillingError.Create(ErrorMsg, StatusCode, ErrorCode);
  end;
end;

function TBillingClient.ParseResponse(const AJson: string): TChatResponse;
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
    // Parse model
    Result.Model := JsonObj.GetValue<string>('model', '');
    
    // Parse choices
    if JsonObj.TryGetValue<TJSONArray>('choices', ChoicesArray) and (ChoicesArray.Count > 0) then
    begin
      ChoiceObj := ChoicesArray.Items[0] as TJSONObject;
      Result.FinishReason := ChoiceObj.GetValue<string>('finish_reason', '');
      
      if ChoiceObj.TryGetValue<TJSONObject>('message', MsgObj) then
        Result.Content := MsgObj.GetValue<string>('content', '');
    end;
    
    // Parse usage
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
  RequestStream: TStringStream;
  Response: IHTTPResponse;
  StartTime: TDateTime;
begin
  Result.Init;
  ResetCancel;
  StartTime := Now;
  
  RequestBody := BuildRequestBody(AMessages, False);
  RequestStream := TStringStream.Create(RequestBody, TEncoding.UTF8);
  try
    SetupHeaders;
    // ע��: ��� BaseURL �Ѱ��� /v1����ֱ���� /chat/completions
    // ��� BaseURL �Ǹ�·�������� /v1/chat/completions
    if FBaseURL.EndsWith('/v1') or FBaseURL.EndsWith('/v1/') then
      Response := FHttpClient.Post(FBaseURL.TrimRight(['/']) + '/chat/completions', RequestStream)
    else
      Response := FHttpClient.Post(FBaseURL + '/v1/chat/completions', RequestStream);
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
var
  RequestBody: string;
  RequestStream: TStringStream;
  Response: IHTTPResponse;
  ResponseStr, Line, Content: string;
  Lines: TArray<string>;
  I: Integer;
  Done: Boolean;
begin
  Result := False;
  ResetCancel;

  RequestBody := BuildRequestBody(AMessages, True);
  RequestStream := TStringStream.Create(RequestBody, TEncoding.UTF8);
  try
    SetupHeaders;
    FHttpClient.CustomHeaders['Accept'] := 'text/event-stream';
    
    // ע��: ��� BaseURL �Ѱ��� /v1����ֱ���� /chat/completions
    if FBaseURL.EndsWith('/v1') or FBaseURL.EndsWith('/v1/') then
      Response := FHttpClient.Post(FBaseURL.TrimRight(['/']) + '/chat/completions', RequestStream)
    else
      Response := FHttpClient.Post(FBaseURL + '/v1/chat/completions', RequestStream);
    
    if (Response.StatusCode < 200) or (Response.StatusCode >= 300) then
      HandleHttpError(Response.StatusCode, Response.ContentAsString(TEncoding.UTF8));
    
    ResponseStr := Response.ContentAsString(TEncoding.UTF8);
    Lines := ResponseStr.Split([#10]);
    
    for I := 0 to High(Lines) do
    begin
      if IsCancelled then
        Exit(False);
        
      Line := Lines[I];
      if ParseStreamChunk(Line, Content, Done) then
      begin
        if Done then
        begin
          if Assigned(AOnChunk) then
            AOnChunk('', True);
          Result := True;
          Break;
        end
        else if Content <> '' then
        begin
          if Assigned(AOnChunk) then
          begin
            if not AOnChunk(Content, False) then
            begin
              Cancel;
              Exit(False);
            end;
          end;
        end;
      end;
    end;
  finally
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
  Client: TBillingClient;
begin
  // ���Ʋ����Ա���հ���������
  MsgCopy := Copy(AMessages);
  Callback := AOnComplete;
  Client := Self;
  
  Result := TTask.Run(
    procedure
    var
      Response: TChatResponse;
      RespCopy: TChatResponse;
    begin
      try
        Response := Client.DoRequest(MsgCopy);
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
        TThread.Queue(nil,
          procedure
          begin
            Callback(RespCopy);
          end);
      end;
    end);
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
          // Exponential backoff: 1s, 2s, 4s...
          DelayMs := 1000 * (1 shl (I - 1));
          Sleep(DelayMs);
        end;
      end;
      on E: EBillingServerError do
      begin
        LastError := E.Message;
        if I < Retries then
          Sleep(1000 * I);
      end;
      on E: EBillingAuthError do
        raise; // Don't retry auth errors
      on E: EBillingBalanceError do
        raise; // Don't retry balance errors
      on E: Exception do
        raise;
    end;
  end;
  
  raise EBillingError.Create('���� ' + IntToStr(Retries) + ' �κ�ʧ��: ' + LastError);
end;

procedure TBillingClient.Cancel;
begin
  FLock.Enter;
  try
    FCancelled := True;
  finally
    FLock.Leave;
  end;
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
