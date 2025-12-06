unit UniFlow.LLM.Providers;
(*
  UniFlow LLM Providers
  =====================
  TASK-2021: 更多 LLM 提供商
  
  支持多种 LLM 提供商:
  - OpenAI (GPT-4, GPT-3.5)
  - Anthropic (Claude 3.5, Claude 3)
  - Google (Gemini Pro, Gemini Flash)
  - 本地模型 (Ollama, LM Studio)
  - Azure OpenAI
  - DeepSeek
*)

interface

uses
  System.SysUtils, System.Classes, System.JSON, System.Generics.Collections,
  System.Net.HttpClient, System.Net.URLClient, System.SyncObjs;

type
  // ============================================================================
  // LLM 消息类型
  // ============================================================================
  
  TLLMRole = (lrSystem, lrUser, lrAssistant, lrTool);
  
  TLLMMessage = record
    Role: TLLMRole;
    Content: string;
    Name: string;        // 可选: 工具调用名
    ToolCallId: string;  // 可选: 工具调用 ID
    
    class function System(const AContent: string): TLLMMessage; static;
    class function User(const AContent: string): TLLMMessage; static;
    class function Assistant(const AContent: string): TLLMMessage; static;
    function ToJSON: TJSONObject;
  end;
  
  TLLMMessages = TArray<TLLMMessage>;
  
  // ============================================================================
  // LLM 请求选项
  // ============================================================================
  
  TLLMRequestOptions = record
    Model: string;
    MaxTokens: Integer;
    Temperature: Double;
    TopP: Double;
    Stop: TArray<string>;
    Stream: Boolean;
    
    class function Default: TLLMRequestOptions; static;
  end;
  
  // ============================================================================
  // LLM 响应
  // ============================================================================
  
  TLLMResponse = record
    Success: Boolean;
    Content: string;
    FinishReason: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    TotalTokens: Integer;
    Model: string;
    ErrorMessage: string;
    DurationMs: Int64;
    
    procedure Init;
  end;
  
  // ============================================================================
  // LLM 提供商接口
  // ============================================================================
  
  ILLMProvider = interface
    ['{E1F2A3B4-C5D6-4789-8901-23456789ABCD}']
    function GetName: string;
    function GetModels: TArray<string>;
    function Chat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse;
    function IsAvailable: Boolean;
    
    property Name: string read GetName;
    property Models: TArray<string> read GetModels;
  end;
  
  // ============================================================================
  // 基础 HTTP Provider
  // ============================================================================
  
  TBaseLLMProvider = class(TInterfacedObject, ILLMProvider)
  protected
    FName: string;
    FApiKey: string;
    FBaseUrl: string;
    FHttp: THTTPClient;
    FModels: TArray<string>;
    FDefaultModel: string;
    FTimeoutMs: Integer;
    
    function DoChat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; virtual; abstract;
    function BuildHeaders: TArray<TNameValuePair>; virtual;
    function PostJSON(const AUrl: string; const ABody: TJSONObject): TJSONObject;
  public
    constructor Create(const AApiKey: string; const ABaseUrl: string = '');
    destructor Destroy; override;
    
    function GetName: string;
    function GetModels: TArray<string>;
    function Chat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse;
    function IsAvailable: Boolean; virtual;
    
    property ApiKey: string read FApiKey write FApiKey;
    property BaseUrl: string read FBaseUrl write FBaseUrl;
    property DefaultModel: string read FDefaultModel write FDefaultModel;
    property TimeoutMs: Integer read FTimeoutMs write FTimeoutMs;
  end;
  
  // ============================================================================
  // OpenAI Provider
  // ============================================================================
  
  TOpenAIProvider = class(TBaseLLMProvider)
  protected
    function DoChat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; override;
    function BuildHeaders: TArray<TNameValuePair>; override;
  public
    constructor Create(const AApiKey: string);
  end;
  
  // ============================================================================
  // Anthropic (Claude) Provider
  // ============================================================================
  
  TClaudeProvider = class(TBaseLLMProvider)
  protected
    FAnthropicVersion: string;
    function DoChat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; override;
    function BuildHeaders: TArray<TNameValuePair>; override;
  public
    constructor Create(const AApiKey: string);
  end;
  
  // ============================================================================
  // Google Gemini Provider
  // ============================================================================
  
  TGeminiProvider = class(TBaseLLMProvider)
  protected
    function DoChat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; override;
  public
    constructor Create(const AApiKey: string);
  end;
  
  // ============================================================================
  // Ollama (本地模型) Provider
  // ============================================================================
  
  TOllamaProvider = class(TBaseLLMProvider)
  protected
    function DoChat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; override;
  public
    constructor Create(const ABaseUrl: string = 'http://localhost:11434');
    function IsAvailable: Boolean; override;
    procedure RefreshModels;
  end;
  
  // ============================================================================
  // Azure OpenAI Provider
  // ============================================================================
  
  TAzureOpenAIProvider = class(TBaseLLMProvider)
  private
    FDeploymentName: string;
    FApiVersion: string;
  protected
    function DoChat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; override;
    function BuildHeaders: TArray<TNameValuePair>; override;
  public
    constructor Create(const AApiKey, AEndpoint, ADeploymentName: string;
      const AApiVersion: string = '2024-02-15-preview');
    
    property DeploymentName: string read FDeploymentName write FDeploymentName;
    property ApiVersion: string read FApiVersion write FApiVersion;
  end;
  
  // ============================================================================
  // DeepSeek Provider
  // ============================================================================
  
  TDeepSeekProvider = class(TBaseLLMProvider)
  protected
    function DoChat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; override;
    function BuildHeaders: TArray<TNameValuePair>; override;
  public
    constructor Create(const AApiKey: string);
  end;
  
  // ============================================================================
  // LLM Provider 管理器
  // ============================================================================
  
  TLLMProviderManager = class
  private
    FProviders: TDictionary<string, ILLMProvider>;
    FDefaultProvider: string;
    FLock: TCriticalSection;
    class var FInstance: TLLMProviderManager;
  public
    constructor Create;
    destructor Destroy; override;
    
    class function Instance: TLLMProviderManager;
    class procedure FreeInstance;
    
    /// <summary>注册提供商</summary>
    procedure RegisterProvider(const AName: string; AProvider: ILLMProvider);
    
    /// <summary>注销提供商</summary>
    procedure UnregisterProvider(const AName: string);
    
    /// <summary>获取提供商</summary>
    function GetProvider(const AName: string): ILLMProvider;
    
    /// <summary>获取默认提供商</summary>
    function GetDefaultProvider: ILLMProvider;
    
    /// <summary>设置默认提供商</summary>
    procedure SetDefaultProvider(const AName: string);
    
    /// <summary>获取所有提供商名称</summary>
    function GetProviderNames: TArray<string>;
    
    /// <summary>聊天 (使用默认提供商)</summary>
    function Chat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse; overload;
    
    /// <summary>聊天 (指定提供商)</summary>
    function Chat(const AProviderName: string; const AMessages: TLLMMessages; 
      const AOptions: TLLMRequestOptions): TLLMResponse; overload;
    
    property DefaultProvider: string read FDefaultProvider write SetDefaultProvider;
  end;

// ============================================================================
// 辅助函数
// ============================================================================

function LLMRoleToString(ARole: TLLMRole): string;
function StringToLLMRole(const AStr: string): TLLMRole;

implementation

uses
  System.DateUtils, System.StrUtils;

// ============================================================================
// TLLMMessage
// ============================================================================

class function TLLMMessage.System(const AContent: string): TLLMMessage;
begin
  Result.Role := lrSystem;
  Result.Content := AContent;
  Result.Name := '';
  Result.ToolCallId := '';
end;

class function TLLMMessage.User(const AContent: string): TLLMMessage;
begin
  Result.Role := lrUser;
  Result.Content := AContent;
  Result.Name := '';
  Result.ToolCallId := '';
end;

class function TLLMMessage.Assistant(const AContent: string): TLLMMessage;
begin
  Result.Role := lrAssistant;
  Result.Content := AContent;
  Result.Name := '';
  Result.ToolCallId := '';
end;

function TLLMMessage.ToJSON: TJSONObject;
begin
  Result := TJSONObject.Create;
  Result.AddPair('role', LLMRoleToString(Role));
  Result.AddPair('content', Content);
  if not Name.IsEmpty then
    Result.AddPair('name', Name);
end;

// ============================================================================
// TLLMRequestOptions
// ============================================================================

class function TLLMRequestOptions.Default: TLLMRequestOptions;
begin
  Result.Model := '';
  Result.MaxTokens := 4096;
  Result.Temperature := 0.7;
  Result.TopP := 1.0;
  SetLength(Result.Stop, 0);
  Result.Stream := False;
end;

// ============================================================================
// TLLMResponse
// ============================================================================

procedure TLLMResponse.Init;
begin
  Success := False;
  Content := '';
  FinishReason := '';
  InputTokens := 0;
  OutputTokens := 0;
  TotalTokens := 0;
  Model := '';
  ErrorMessage := '';
  DurationMs := 0;
end;

// ============================================================================
// TBaseLLMProvider
// ============================================================================

constructor TBaseLLMProvider.Create(const AApiKey, ABaseUrl: string);
begin
  inherited Create;
  FApiKey := AApiKey;
  FBaseUrl := ABaseUrl;
  FHttp := THTTPClient.Create;
  FTimeoutMs := 60000;
  FHttp.ResponseTimeout := FTimeoutMs;
end;

destructor TBaseLLMProvider.Destroy;
begin
  FHttp.Free;
  inherited;
end;

function TBaseLLMProvider.GetName: string;
begin
  Result := FName;
end;

function TBaseLLMProvider.GetModels: TArray<string>;
begin
  Result := FModels;
end;

function TBaseLLMProvider.Chat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LStartTime: TDateTime;
begin
  Result.Init;
  LStartTime := Now;
  try
    Result := DoChat(AMessages, AOptions);
  except
    on E: Exception do
    begin
      Result.Success := False;
      Result.ErrorMessage := E.Message;
    end;
  end;
  Result.DurationMs := MilliSecondsBetween(Now, LStartTime);
end;

function TBaseLLMProvider.IsAvailable: Boolean;
begin
  Result := not FApiKey.IsEmpty;
end;

function TBaseLLMProvider.BuildHeaders: TArray<TNameValuePair>;
begin
  SetLength(Result, 1);
  Result[0] := TNameValuePair.Create('Content-Type', 'application/json');
end;

function TBaseLLMProvider.PostJSON(const AUrl: string; const ABody: TJSONObject): TJSONObject;
var
  LContent: TStringStream;
  LResponse: IHTTPResponse;
begin
  Result := nil;
  LContent := TStringStream.Create(ABody.ToJSON, TEncoding.UTF8);
  try
    LResponse := FHttp.Post(AUrl, LContent, nil, BuildHeaders);
    if LResponse.StatusCode = 200 then
      Result := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject
    else
      raise Exception.CreateFmt('HTTP %d: %s', [LResponse.StatusCode, LResponse.ContentAsString]);
  finally
    LContent.Free;
  end;
end;

// ============================================================================
// TOpenAIProvider
// ============================================================================

constructor TOpenAIProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey, 'https://api.openai.com/v1');
  FName := 'OpenAI';
  FModels := ['gpt-4o', 'gpt-4o-mini', 'gpt-4-turbo', 'gpt-4', 'gpt-3.5-turbo'];
  FDefaultModel := 'gpt-4o-mini';
end;

function TOpenAIProvider.BuildHeaders: TArray<TNameValuePair>;
begin
  SetLength(Result, 2);
  Result[0] := TNameValuePair.Create('Content-Type', 'application/json');
  Result[1] := TNameValuePair.Create('Authorization', 'Bearer ' + FApiKey);
end;

function TOpenAIProvider.DoChat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LBody: TJSONObject;
  LMessagesArray: TJSONArray;
  LMsg: TLLMMessage;
  LResponse: TJSONObject;
  LChoices: TJSONArray;
  LUsage: TJSONObject;
begin
  Result.Init;
  
  LBody := TJSONObject.Create;
  try
    // 模型
    if AOptions.Model.IsEmpty then
      LBody.AddPair('model', FDefaultModel)
    else
      LBody.AddPair('model', AOptions.Model);
    
    // 消息
    LMessagesArray := TJSONArray.Create;
    for LMsg in AMessages do
      LMessagesArray.Add(LMsg.ToJSON);
    LBody.AddPair('messages', LMessagesArray);
    
    // 选项
    LBody.AddPair('max_tokens', TJSONNumber.Create(AOptions.MaxTokens));
    LBody.AddPair('temperature', TJSONNumber.Create(AOptions.Temperature));
    
    // 发送请求
    LResponse := PostJSON(FBaseUrl + '/chat/completions', LBody);
    try
      // 解析响应
      if LResponse.TryGetValue<TJSONArray>('choices', LChoices) and (LChoices.Count > 0) then
      begin
        Result.Content := LChoices.Items[0].GetValue<string>('message.content', '');
        Result.FinishReason := LChoices.Items[0].GetValue<string>('finish_reason', '');
      end;
      
      if LResponse.TryGetValue<TJSONObject>('usage', LUsage) then
      begin
        Result.InputTokens := LUsage.GetValue<Integer>('prompt_tokens', 0);
        Result.OutputTokens := LUsage.GetValue<Integer>('completion_tokens', 0);
        Result.TotalTokens := LUsage.GetValue<Integer>('total_tokens', 0);
      end;
      
      Result.Model := LResponse.GetValue<string>('model', '');
      Result.Success := True;
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

// ============================================================================
// TClaudeProvider
// ============================================================================

constructor TClaudeProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey, 'https://api.anthropic.com/v1');
  FName := 'Claude';
  FModels := ['claude-3-5-sonnet-20241022', 'claude-3-5-haiku-20241022', 
              'claude-3-opus-20240229', 'claude-3-sonnet-20240229'];
  FDefaultModel := 'claude-3-5-sonnet-20241022';
  FAnthropicVersion := '2023-06-01';
end;

function TClaudeProvider.BuildHeaders: TArray<TNameValuePair>;
begin
  SetLength(Result, 3);
  Result[0] := TNameValuePair.Create('Content-Type', 'application/json');
  Result[1] := TNameValuePair.Create('x-api-key', FApiKey);
  Result[2] := TNameValuePair.Create('anthropic-version', FAnthropicVersion);
end;

function TClaudeProvider.DoChat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LBody: TJSONObject;
  LMessagesArray: TJSONArray;
  LMsg: TLLMMessage;
  LResponse: TJSONObject;
  LContent: TJSONArray;
  LUsage: TJSONObject;
  LSystemPrompt: string;
begin
  Result.Init;
  
  LBody := TJSONObject.Create;
  try
    // 模型
    if AOptions.Model.IsEmpty then
      LBody.AddPair('model', FDefaultModel)
    else
      LBody.AddPair('model', AOptions.Model);
    
    // Claude API 需要单独的 system 参数
    LSystemPrompt := '';
    LMessagesArray := TJSONArray.Create;
    for LMsg in AMessages do
    begin
      if LMsg.Role = lrSystem then
        LSystemPrompt := LMsg.Content
      else
        LMessagesArray.Add(LMsg.ToJSON);
    end;
    
    if not LSystemPrompt.IsEmpty then
      LBody.AddPair('system', LSystemPrompt);
    LBody.AddPair('messages', LMessagesArray);
    
    // 选项
    LBody.AddPair('max_tokens', TJSONNumber.Create(AOptions.MaxTokens));
    if AOptions.Temperature >= 0 then
      LBody.AddPair('temperature', TJSONNumber.Create(AOptions.Temperature));
    
    // 发送请求
    LResponse := PostJSON(FBaseUrl + '/messages', LBody);
    try
      // 解析响应
      if LResponse.TryGetValue<TJSONArray>('content', LContent) and (LContent.Count > 0) then
      begin
        Result.Content := LContent.Items[0].GetValue<string>('text', '');
      end;
      
      Result.FinishReason := LResponse.GetValue<string>('stop_reason', '');
      
      if LResponse.TryGetValue<TJSONObject>('usage', LUsage) then
      begin
        Result.InputTokens := LUsage.GetValue<Integer>('input_tokens', 0);
        Result.OutputTokens := LUsage.GetValue<Integer>('output_tokens', 0);
        Result.TotalTokens := Result.InputTokens + Result.OutputTokens;
      end;
      
      Result.Model := LResponse.GetValue<string>('model', '');
      Result.Success := True;
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

// ============================================================================
// TGeminiProvider
// ============================================================================

constructor TGeminiProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey, 'https://generativelanguage.googleapis.com/v1beta');
  FName := 'Gemini';
  FModels := ['gemini-1.5-pro', 'gemini-1.5-flash', 'gemini-pro'];
  FDefaultModel := 'gemini-1.5-flash';
end;

function TGeminiProvider.DoChat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LBody: TJSONObject;
  LContents, LParts: TJSONArray;
  LMsg: TLLMMessage;
  LContent, LPart: TJSONObject;
  LResponse: TJSONObject;
  LCandidates: TJSONArray;
  LUsage: TJSONObject;
  LModel: string;
begin
  Result.Init;
  
  if AOptions.Model.IsEmpty then
    LModel := FDefaultModel
  else
    LModel := AOptions.Model;
  
  LBody := TJSONObject.Create;
  try
    // Gemini 格式
    LContents := TJSONArray.Create;
    for LMsg in AMessages do
    begin
      if LMsg.Role = lrSystem then
        Continue; // Gemini 使用不同方式处理 system
      
      LContent := TJSONObject.Create;
      if LMsg.Role = lrUser then
        LContent.AddPair('role', 'user')
      else
        LContent.AddPair('role', 'model');
      
      LParts := TJSONArray.Create;
      LPart := TJSONObject.Create;
      LPart.AddPair('text', LMsg.Content);
      LParts.Add(LPart);
      LContent.AddPair('parts', LParts);
      LContents.Add(LContent);
    end;
    LBody.AddPair('contents', LContents);
    
    // 生成配置
    var LGenConfig := TJSONObject.Create;
    LGenConfig.AddPair('maxOutputTokens', TJSONNumber.Create(AOptions.MaxTokens));
    LGenConfig.AddPair('temperature', TJSONNumber.Create(AOptions.Temperature));
    LBody.AddPair('generationConfig', LGenConfig);
    
    // 发送请求
    LResponse := PostJSON(
      FBaseUrl + '/models/' + LModel + ':generateContent?key=' + FApiKey,
      LBody
    );
    try
      // 解析响应
      if LResponse.TryGetValue<TJSONArray>('candidates', LCandidates) and (LCandidates.Count > 0) then
      begin
        var LCand := LCandidates.Items[0] as TJSONObject;
        var LCandContent: TJSONObject;
        if LCand.TryGetValue<TJSONObject>('content', LCandContent) then
        begin
          var LCandParts: TJSONArray;
          if LCandContent.TryGetValue<TJSONArray>('parts', LCandParts) and (LCandParts.Count > 0) then
            Result.Content := LCandParts.Items[0].GetValue<string>('text', '');
        end;
        Result.FinishReason := LCand.GetValue<string>('finishReason', '');
      end;
      
      if LResponse.TryGetValue<TJSONObject>('usageMetadata', LUsage) then
      begin
        Result.InputTokens := LUsage.GetValue<Integer>('promptTokenCount', 0);
        Result.OutputTokens := LUsage.GetValue<Integer>('candidatesTokenCount', 0);
        Result.TotalTokens := LUsage.GetValue<Integer>('totalTokenCount', 0);
      end;
      
      Result.Model := LModel;
      Result.Success := True;
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

// ============================================================================
// TOllamaProvider
// ============================================================================

constructor TOllamaProvider.Create(const ABaseUrl: string);
begin
  inherited Create('', ABaseUrl);
  FName := 'Ollama';
  FModels := ['llama3.2', 'mistral', 'codellama', 'deepseek-coder'];
  FDefaultModel := 'llama3.2';
end;

function TOllamaProvider.IsAvailable: Boolean;
var
  LResponse: IHTTPResponse;
begin
  Result := False;
  try
    LResponse := FHttp.Get(FBaseUrl + '/api/tags');
    Result := LResponse.StatusCode = 200;
  except
    Result := False;
  end;
end;

procedure TOllamaProvider.RefreshModels;
var
  LResponse: IHTTPResponse;
  LJson: TJSONObject;
  LModels: TJSONArray;
  I: Integer;
begin
  try
    LResponse := FHttp.Get(FBaseUrl + '/api/tags');
    if LResponse.StatusCode = 200 then
    begin
      LJson := TJSONObject.ParseJSONValue(LResponse.ContentAsString) as TJSONObject;
      try
        if LJson.TryGetValue<TJSONArray>('models', LModels) then
        begin
          SetLength(FModels, LModels.Count);
          for I := 0 to LModels.Count - 1 do
            FModels[I] := LModels.Items[I].GetValue<string>('name', '');
        end;
      finally
        LJson.Free;
      end;
    end;
  except
    // 保持默认模型列表
  end;
end;

function TOllamaProvider.DoChat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LBody: TJSONObject;
  LMessagesArray: TJSONArray;
  LMsg: TLLMMessage;
  LResponse: TJSONObject;
begin
  Result.Init;
  
  LBody := TJSONObject.Create;
  try
    // 模型
    if AOptions.Model.IsEmpty then
      LBody.AddPair('model', FDefaultModel)
    else
      LBody.AddPair('model', AOptions.Model);
    
    // 消息
    LMessagesArray := TJSONArray.Create;
    for LMsg in AMessages do
      LMessagesArray.Add(LMsg.ToJSON);
    LBody.AddPair('messages', LMessagesArray);
    
    // 选项
    var LOpts := TJSONObject.Create;
    LOpts.AddPair('num_predict', TJSONNumber.Create(AOptions.MaxTokens));
    LOpts.AddPair('temperature', TJSONNumber.Create(AOptions.Temperature));
    LBody.AddPair('options', LOpts);
    
    // 非流式
    LBody.AddPair('stream', TJSONBool.Create(False));
    
    // 发送请求
    LResponse := PostJSON(FBaseUrl + '/api/chat', LBody);
    try
      Result.Content := LResponse.GetValue<string>('message.content', '');
      Result.Model := LResponse.GetValue<string>('model', '');
      Result.InputTokens := LResponse.GetValue<Integer>('prompt_eval_count', 0);
      Result.OutputTokens := LResponse.GetValue<Integer>('eval_count', 0);
      Result.TotalTokens := Result.InputTokens + Result.OutputTokens;
      Result.Success := True;
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

// ============================================================================
// TAzureOpenAIProvider
// ============================================================================

constructor TAzureOpenAIProvider.Create(const AApiKey, AEndpoint, ADeploymentName: string;
  const AApiVersion: string);
begin
  inherited Create(AApiKey, AEndpoint);
  FName := 'Azure OpenAI';
  FDeploymentName := ADeploymentName;
  FApiVersion := AApiVersion;
  FModels := [ADeploymentName];
  FDefaultModel := ADeploymentName;
end;

function TAzureOpenAIProvider.BuildHeaders: TArray<TNameValuePair>;
begin
  SetLength(Result, 2);
  Result[0] := TNameValuePair.Create('Content-Type', 'application/json');
  Result[1] := TNameValuePair.Create('api-key', FApiKey);
end;

function TAzureOpenAIProvider.DoChat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LBody: TJSONObject;
  LMessagesArray: TJSONArray;
  LMsg: TLLMMessage;
  LResponse: TJSONObject;
  LChoices: TJSONArray;
  LUsage: TJSONObject;
  LUrl: string;
begin
  Result.Init;
  
  LBody := TJSONObject.Create;
  try
    // 消息
    LMessagesArray := TJSONArray.Create;
    for LMsg in AMessages do
      LMessagesArray.Add(LMsg.ToJSON);
    LBody.AddPair('messages', LMessagesArray);
    
    // 选项
    LBody.AddPair('max_tokens', TJSONNumber.Create(AOptions.MaxTokens));
    LBody.AddPair('temperature', TJSONNumber.Create(AOptions.Temperature));
    
    // Azure URL 格式
    LUrl := FBaseUrl + '/openai/deployments/' + FDeploymentName + 
            '/chat/completions?api-version=' + FApiVersion;
    
    // 发送请求
    LResponse := PostJSON(LUrl, LBody);
    try
      // 解析响应
      if LResponse.TryGetValue<TJSONArray>('choices', LChoices) and (LChoices.Count > 0) then
      begin
        Result.Content := LChoices.Items[0].GetValue<string>('message.content', '');
        Result.FinishReason := LChoices.Items[0].GetValue<string>('finish_reason', '');
      end;
      
      if LResponse.TryGetValue<TJSONObject>('usage', LUsage) then
      begin
        Result.InputTokens := LUsage.GetValue<Integer>('prompt_tokens', 0);
        Result.OutputTokens := LUsage.GetValue<Integer>('completion_tokens', 0);
        Result.TotalTokens := LUsage.GetValue<Integer>('total_tokens', 0);
      end;
      
      Result.Model := FDeploymentName;
      Result.Success := True;
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

// ============================================================================
// TDeepSeekProvider
// ============================================================================

constructor TDeepSeekProvider.Create(const AApiKey: string);
begin
  inherited Create(AApiKey, 'https://api.deepseek.com');
  FName := 'DeepSeek';
  FModels := ['deepseek-chat', 'deepseek-coder'];
  FDefaultModel := 'deepseek-chat';
end;

function TDeepSeekProvider.BuildHeaders: TArray<TNameValuePair>;
begin
  SetLength(Result, 2);
  Result[0] := TNameValuePair.Create('Content-Type', 'application/json');
  Result[1] := TNameValuePair.Create('Authorization', 'Bearer ' + FApiKey);
end;

function TDeepSeekProvider.DoChat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LBody: TJSONObject;
  LMessagesArray: TJSONArray;
  LMsg: TLLMMessage;
  LResponse: TJSONObject;
  LChoices: TJSONArray;
  LUsage: TJSONObject;
begin
  Result.Init;
  
  LBody := TJSONObject.Create;
  try
    // 模型
    if AOptions.Model.IsEmpty then
      LBody.AddPair('model', FDefaultModel)
    else
      LBody.AddPair('model', AOptions.Model);
    
    // 消息
    LMessagesArray := TJSONArray.Create;
    for LMsg in AMessages do
      LMessagesArray.Add(LMsg.ToJSON);
    LBody.AddPair('messages', LMessagesArray);
    
    // 选项
    LBody.AddPair('max_tokens', TJSONNumber.Create(AOptions.MaxTokens));
    LBody.AddPair('temperature', TJSONNumber.Create(AOptions.Temperature));
    
    // 发送请求
    LResponse := PostJSON(FBaseUrl + '/chat/completions', LBody);
    try
      // 解析响应 (与 OpenAI 兼容)
      if LResponse.TryGetValue<TJSONArray>('choices', LChoices) and (LChoices.Count > 0) then
      begin
        Result.Content := LChoices.Items[0].GetValue<string>('message.content', '');
        Result.FinishReason := LChoices.Items[0].GetValue<string>('finish_reason', '');
      end;
      
      if LResponse.TryGetValue<TJSONObject>('usage', LUsage) then
      begin
        Result.InputTokens := LUsage.GetValue<Integer>('prompt_tokens', 0);
        Result.OutputTokens := LUsage.GetValue<Integer>('completion_tokens', 0);
        Result.TotalTokens := LUsage.GetValue<Integer>('total_tokens', 0);
      end;
      
      Result.Model := LResponse.GetValue<string>('model', '');
      Result.Success := True;
    finally
      LResponse.Free;
    end;
  finally
    LBody.Free;
  end;
end;

// ============================================================================
// TLLMProviderManager
// ============================================================================

constructor TLLMProviderManager.Create;
begin
  inherited Create;
  FProviders := TDictionary<string, ILLMProvider>.Create;
  FLock := TCriticalSection.Create;
end;

destructor TLLMProviderManager.Destroy;
begin
  FLock.Free;
  FProviders.Free;
  inherited;
end;

class function TLLMProviderManager.Instance: TLLMProviderManager;
begin
  if not Assigned(FInstance) then
    FInstance := TLLMProviderManager.Create;
  Result := FInstance;
end;

class procedure TLLMProviderManager.FreeInstance;
begin
  FreeAndNil(FInstance);
end;

procedure TLLMProviderManager.RegisterProvider(const AName: string; AProvider: ILLMProvider);
begin
  FLock.Enter;
  try
    FProviders.AddOrSetValue(AName, AProvider);
    if FDefaultProvider.IsEmpty then
      FDefaultProvider := AName;
  finally
    FLock.Leave;
  end;
end;

procedure TLLMProviderManager.UnregisterProvider(const AName: string);
begin
  FLock.Enter;
  try
    FProviders.Remove(AName);
    if FDefaultProvider = AName then
      FDefaultProvider := '';
  finally
    FLock.Leave;
  end;
end;

function TLLMProviderManager.GetProvider(const AName: string): ILLMProvider;
begin
  FLock.Enter;
  try
    if not FProviders.TryGetValue(AName, Result) then
      Result := nil;
  finally
    FLock.Leave;
  end;
end;

function TLLMProviderManager.GetDefaultProvider: ILLMProvider;
begin
  Result := GetProvider(FDefaultProvider);
end;

procedure TLLMProviderManager.SetDefaultProvider(const AName: string);
begin
  FLock.Enter;
  try
    if FProviders.ContainsKey(AName) then
      FDefaultProvider := AName;
  finally
    FLock.Leave;
  end;
end;

function TLLMProviderManager.GetProviderNames: TArray<string>;
var
  LKey: string;
  I: Integer;
begin
  FLock.Enter;
  try
    SetLength(Result, FProviders.Count);
    I := 0;
    for LKey in FProviders.Keys do
    begin
      Result[I] := LKey;
      Inc(I);
    end;
  finally
    FLock.Leave;
  end;
end;

function TLLMProviderManager.Chat(const AMessages: TLLMMessages;
  const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LProvider: ILLMProvider;
begin
  Result.Init;
  LProvider := GetDefaultProvider;
  if Assigned(LProvider) then
    Result := LProvider.Chat(AMessages, AOptions)
  else
    Result.ErrorMessage := 'No default LLM provider configured';
end;

function TLLMProviderManager.Chat(const AProviderName: string;
  const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMResponse;
var
  LProvider: ILLMProvider;
begin
  Result.Init;
  LProvider := GetProvider(AProviderName);
  if Assigned(LProvider) then
    Result := LProvider.Chat(AMessages, AOptions)
  else
    Result.ErrorMessage := 'LLM provider not found: ' + AProviderName;
end;

// ============================================================================
// Helper Functions
// ============================================================================

function LLMRoleToString(ARole: TLLMRole): string;
begin
  case ARole of
    lrSystem: Result := 'system';
    lrUser: Result := 'user';
    lrAssistant: Result := 'assistant';
    lrTool: Result := 'tool';
  else
    Result := 'user';
  end;
end;

function StringToLLMRole(const AStr: string): TLLMRole;
begin
  if AStr = 'system' then Result := lrSystem
  else if AStr = 'assistant' then Result := lrAssistant
  else if AStr = 'tool' then Result := lrTool
  else Result := lrUser;
end;

end.
