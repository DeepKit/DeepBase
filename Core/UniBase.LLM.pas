{ ============================================================================
  UniBase.LLM - LLM Integration Module
  
  Version: 1.0
  Description: Provides unified LLM API integration with multiple providers
  Features:
    - Multiple providers: OpenAI, Anthropic, Azure, LiteLLM, Ollama, Custom
    - Configuration management via database
    - Async and sync chat methods
    - Call history tracking and cost estimation
    - Prompt template support
  ============================================================================ }

unit UniBase.LLM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.Net.URLClient,
  System.Threading,
  System.Generics.Collections,
  System.DateUtils,
  System.SyncObjs,
  FireDAC.Comp.Client,
  UniBase.Types;

type
  ELLMException = class(Exception);

  /// <summary>
  /// LLM Provider types
  /// </summary>
  TLLMProvider = (
    lpOpenAI,     // OpenAI API
    lpAnthropic,  // Anthropic Claude
    lpAzure,      // Azure OpenAI
    lpLiteLLM,    // LiteLLM proxy
    lpOllama,     // Ollama local
    lpCustom      // Custom endpoint
  );

  /// <summary>
  /// LLM Configuration record
  /// </summary>
  TLLMConfig = record
    Name: string;           // Config name (Default, Translation, CodeGen)
    Provider: TLLMProvider;
    BaseUrl: string;        // API base URL
    ApiKey: string;         // API key
    Model: string;          // Model name
    MaxTokens: Integer;     // Max output tokens
    Temperature: Double;    // Temperature (0.0-2.0)
    SystemPrompt: string;   // System prompt
    InputTokenPrice: Double;  // Price per 1K input tokens (USD)
    OutputTokenPrice: Double; // Price per 1K output tokens (USD)
    IsEnabled: Boolean;
    IsDefault: Boolean;
    
    procedure Init;
    function ProviderToStr: string;
    class function StrToProvider(const S: string): TLLMProvider; static;
  end;
  TLLMConfigArray = TArray<TLLMConfig>;

  /// <summary>
  /// LLM Call record for history
  /// </summary>
  TLLMCallRecord = record
    Id: Integer;
    ConfigName: string;
    Provider: string;
    Model: string;
    Prompt: string;
    Response: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    TotalTokens: Integer;
    EstimatedCost: Double;
    DurationMs: Integer;
    Success: Boolean;
    ErrorCode: string;
    ErrorMessage: string;
    CallTime: TDateTime;
  end;
  TLLMCallRecordArray = TArray<TLLMCallRecord>;

  /// <summary>
  /// Chat message for multi-turn conversations
  /// </summary>
  TLLMMessage = record
    Role: string;    // 'system', 'user', 'assistant'
    Content: string;
    
    class function System(const AContent: string): TLLMMessage; static;
    class function User(const AContent: string): TLLMMessage; static;
    class function Assistant(const AContent: string): TLLMMessage; static;
  end;
  TLLMMessages = TArray<TLLMMessage>;

  /// <summary>
  /// Chat response
  /// </summary>
  TLLMChatResponse = record
    Success: Boolean;
    Content: string;
    FinishReason: string;
    InputTokens: Integer;
    OutputTokens: Integer;
    TotalTokens: Integer;
    DurationMs: Int64;
    ErrorCode: string;
    ErrorMessage: string;
    
    procedure Init;
  end;

  /// <summary>
  /// Prompt template example (input/output pair)
  /// </summary>
  TLLMTemplateExample = record
    Input: TDictionary<string, string>;
    Output: string;
  end;

  /// <summary>
  /// Prompt template with inheritance support
  /// </summary>
  TLLMPromptTemplate = record
    Id: Integer;              // DB ID (0 for new)
    Name: string;             // Unique name
    Category: string;         // Category for grouping
    Description: string;      // Human-readable description
    SystemPrompt: string;     // System prompt
    UserPromptTemplate: string; // User prompt with {{variables}}
    Variables: TArray<string>;  // Variable names
    DefaultValues: TDictionary<string, string>; // Default variable values
    // Inheritance
    ParentTemplate: string;   // Parent template name (empty if none)
    IncludeTemplates: TArray<string>; // Templates to include
    // Output control
    OutputFormat: string;     // text/json/markdown
    ValidationRegex: string;  // Output validation regex
    Examples: string;         // Examples JSON
    // Recommended settings
    RecommendedConfig: string; // Recommended LLM config name
    RecommendedModel: string;  // Recommended model
    MaxTokens: Integer;        // Recommended max tokens
    Temperature: Double;       // Recommended temperature
    // Status
    IsEnabled: Boolean;
    IsBuiltIn: Boolean;
    SortOrder: Integer;
    
    procedure Init;
    function RenderUserPrompt(const Values: TDictionary<string, string>): string;
    function Clone: TLLMPromptTemplate;
  end;
  TLLMPromptTemplateArray = TArray<TLLMPromptTemplate>;

  /// <summary>
  /// Template validation result
  /// </summary>
  TTemplateValidation = record
    IsValid: Boolean;
    Errors: TArray<string>;
    MissingVariables: TArray<string>;
  end;

  TUniBaseLLM = class;

  /// <summary>
  /// Streaming chunk callback
  /// </summary>
  TLLMStreamCallback = reference to procedure(const Chunk: string; IsDone: Boolean);

  /// <summary>
  /// UniBase LLM Manager Class
  /// </summary>
  TUniBaseLLM = class
  private
    FConnection: TFDConnection;
    FConfigCache: TDictionary<string, TLLMConfig>;
    FCacheLock: TCriticalSection;
    FHttpClient: TNetHTTPClient;
    FDefaultTimeout: Integer;
    
    function GetDefaultBaseUrl(Provider: TLLMProvider): string;
    function BuildRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
    function BuildAnthropicRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
    function ParseOpenAIResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
    function ParseAnthropicResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
    function DoHttpRequest(const Url, Body: string; const Config: TLLMConfig; out Response: string; out DurationMs: Int64): Boolean;
    procedure RecordCall(const Config: TLLMConfig; const Prompt: string; const Response: TLLMChatResponse; const CallerModule, CallerFunc: string);
    function EstimateCost(const Config: TLLMConfig; InputTokens, OutputTokens: Integer): Double;
    
  public
    constructor Create(AConnection: TFDConnection);
    destructor Destroy; override;
    
    // ========================================================================
    // Configuration Management
    // ========================================================================
    
    /// <summary>Get configuration by name (from cache or DB)</summary>
    function GetConfig(const AConfigName: string = 'Default'): TLLMConfig;
    
    /// <summary>Get all configurations</summary>
    function GetAllConfigs: TLLMConfigArray;
    
    /// <summary>Save configuration to database</summary>
    procedure SaveConfig(const AConfig: TLLMConfig);
    
    /// <summary>Delete configuration</summary>
    procedure DeleteConfig(const AConfigName: string);
    
    /// <summary>Refresh configuration cache from database</summary>
    procedure RefreshConfigCache;
    
    /// <summary>Test LLM connection</summary>
    function TestConnection(const AConfigName: string; out DurationMs: Int64; out ErrorMsg: string): Boolean;
    
    // ========================================================================
    // Chat Methods
    // ========================================================================
    
    /// <summary>Simple chat (single prompt)</summary>
    function Chat(const Prompt: string; out Response: string; const ConfigName: string = 'Default'): Boolean; overload;
    
    /// <summary>Chat with full response details</summary>
    function Chat(const Prompt: string; out Response: TLLMChatResponse; const ConfigName: string = 'Default'): Boolean; overload;
    
    /// <summary>Multi-turn chat with message history</summary>
    function ChatWithMessages(const Messages: TLLMMessages; out Response: TLLMChatResponse; const ConfigName: string = 'Default'): Boolean;
    
    /// <summary>Async chat</summary>
    function ChatAsync(const Prompt: string; OnComplete: TLLMCompleteEvent; const ConfigName: string = 'Default'): ITask;
    
    /// <summary>Streaming chat</summary>
    function ChatStream(const Prompt: string; OnChunk: TLLMStreamCallback; const ConfigName: string = 'Default'): Boolean;
    
    // ========================================================================
    // Template Methods
    // ========================================================================
    
    /// <summary>Get prompt template by name</summary>
    function GetTemplate(const TemplateName: string): TLLMPromptTemplate;
    
    /// <summary>Get all templates</summary>
    function GetAllTemplates: TLLMPromptTemplateArray;
    
    /// <summary>Get templates by category</summary>
    function GetTemplatesByCategory(const Category: string): TLLMPromptTemplateArray;
    
    /// <summary>Save or update template</summary>
    procedure SaveTemplate(const Template: TLLMPromptTemplate);
    
    /// <summary>Delete template by name</summary>
    procedure DeleteTemplate(const TemplateName: string);
    
    /// <summary>Copy template with new name</summary>
    function CopyTemplate(const SourceName, NewName: string): Boolean;
    
    /// <summary>Validate template format and variables</summary>
    function ValidateTemplate(const Template: TLLMPromptTemplate): TTemplateValidation;
    
    /// <summary>Render template with inheritance support</summary>
    function RenderWithInheritance(const TemplateName: string; 
      const Variables: TDictionary<string, string>): string;
    
    /// <summary>Execute template with variables</summary>
    function ExecuteTemplate(const TemplateName: string; const Variables: TDictionary<string, string>;
      out Response: string): Boolean;
    
    /// <summary>Export all templates to JSON</summary>
    function ExportTemplates: string;
    
    /// <summary>Import templates from JSON</summary>
    function ImportTemplates(const Json: string; OverwriteExisting: Boolean = False): Integer;
    
    // ========================================================================
    // History Methods
    // ========================================================================
    
    /// <summary>Get call history</summary>
    function GetCallHistory(ALimit: Integer = 50; const ConfigName: string = ''): TLLMCallRecordArray;
    
    /// <summary>Get usage statistics</summary>
    procedure GetUsageStats(const ConfigName: string; DaysBack: Integer;
      out TotalCalls: Integer; out TotalTokens: Integer; out TotalCost: Double);
    
    /// <summary>Clear old call records</summary>
    procedure ClearOldCalls(DaysToKeep: Integer);
    
    // ========================================================================
    // Properties
    // ========================================================================
    
    property Connection: TFDConnection read FConnection;
    property DefaultTimeout: Integer read FDefaultTimeout write FDefaultTimeout;
  end;

/// <summary>Convert provider enum to string</summary>
function LLMProviderToStr(Provider: TLLMProvider): string;

/// <summary>Convert string to provider enum</summary>
function StrToLLMProvider(const S: string): TLLMProvider;

implementation

uses
  System.NetEncoding,
  System.RegularExpressions,
  System.StrUtils;

const
  DEFAULT_TIMEOUT = 60000; // 60 seconds
  TEST_PROMPT = 'Reply with exactly: OK';
  
  URL_OPENAI = 'https://api.openai.com/v1';
  URL_ANTHROPIC = 'https://api.anthropic.com/v1';

{ Helper Functions }

function LLMProviderToStr(Provider: TLLMProvider): string;
begin
  case Provider of
    lpOpenAI:    Result := 'openai';
    lpAnthropic: Result := 'anthropic';
    lpAzure:     Result := 'azure';
    lpLiteLLM:   Result := 'litellm';
    lpOllama:    Result := 'ollama';
    lpCustom:    Result := 'custom';
  else
    Result := 'openai';
  end;
end;

function StrToLLMProvider(const S: string): TLLMProvider;
var
  Lower: string;
begin
  Lower := LowerCase(Trim(S));
  if Lower = 'openai' then Result := lpOpenAI
  else if Lower = 'anthropic' then Result := lpAnthropic
  else if Lower = 'azure' then Result := lpAzure
  else if Lower = 'litellm' then Result := lpLiteLLM
  else if Lower = 'ollama' then Result := lpOllama
  else if Lower = 'custom' then Result := lpCustom
  else Result := lpOpenAI;
end;

{ TLLMConfig }

procedure TLLMConfig.Init;
begin
  Name := 'Default';
  Provider := lpOpenAI;
  BaseUrl := '';
  ApiKey := '';
  Model := 'gpt-4o-mini';
  MaxTokens := 4096;
  Temperature := 0.7;
  SystemPrompt := '';
  InputTokenPrice := 0.00015;
  OutputTokenPrice := 0.0006;
  IsEnabled := True;
  IsDefault := False;
end;

function TLLMConfig.ProviderToStr: string;
begin
  Result := LLMProviderToStr(Provider);
end;

class function TLLMConfig.StrToProvider(const S: string): TLLMProvider;
begin
  Result := StrToLLMProvider(S);
end;

{ TLLMMessage }

class function TLLMMessage.System(const AContent: string): TLLMMessage;
begin
  Result.Role := 'system';
  Result.Content := AContent;
end;

class function TLLMMessage.User(const AContent: string): TLLMMessage;
begin
  Result.Role := 'user';
  Result.Content := AContent;
end;

class function TLLMMessage.Assistant(const AContent: string): TLLMMessage;
begin
  Result.Role := 'assistant';
  Result.Content := AContent;
end;

{ TLLMChatResponse }

procedure TLLMChatResponse.Init;
begin
  Success := False;
  Content := '';
  FinishReason := '';
  InputTokens := 0;
  OutputTokens := 0;
  TotalTokens := 0;
  DurationMs := 0;
  ErrorCode := '';
  ErrorMessage := '';
end;

{ TLLMPromptTemplate }

procedure TLLMPromptTemplate.Init;
begin
  Id := 0;
  Name := '';
  Category := 'General';
  Description := '';
  SystemPrompt := '';
  UserPromptTemplate := '';
  SetLength(Variables, 0);
  DefaultValues := nil;
  ParentTemplate := '';
  SetLength(IncludeTemplates, 0);
  OutputFormat := 'text';
  ValidationRegex := '';
  Examples := '';
  RecommendedConfig := '';
  RecommendedModel := '';
  MaxTokens := 0;
  Temperature := 0.7;
  IsEnabled := True;
  IsBuiltIn := False;
  SortOrder := 0;
end;

function TLLMPromptTemplate.RenderUserPrompt(const Values: TDictionary<string, string>): string;
var
  Key, Val: string;
begin
  Result := UserPromptTemplate;
  for Key in Variables do
  begin
    if Values.TryGetValue(Key, Val) then
      Result := StringReplace(Result, '{{' + Key + '}}', Val, [rfReplaceAll])
    else if Assigned(DefaultValues) and DefaultValues.TryGetValue(Key, Val) then
      Result := StringReplace(Result, '{{' + Key + '}}', Val, [rfReplaceAll]);
  end;
end;

function TLLMPromptTemplate.Clone: TLLMPromptTemplate;
var
  I: Integer;
  Key: string;
begin
  Result.Id := 0; // New template
  Result.Name := Name + '_copy';
  Result.Category := Category;
  Result.Description := Description;
  Result.SystemPrompt := SystemPrompt;
  Result.UserPromptTemplate := UserPromptTemplate;
  // Copy variables array
  SetLength(Result.Variables, Length(Variables));
  for I := 0 to High(Variables) do
    Result.Variables[I] := Variables[I];
  // Copy default values
  if Assigned(DefaultValues) then
  begin
    Result.DefaultValues := TDictionary<string, string>.Create;
    for Key in DefaultValues.Keys do
      Result.DefaultValues.Add(Key, DefaultValues[Key]);
  end
  else
    Result.DefaultValues := nil;
  Result.ParentTemplate := ParentTemplate;
  SetLength(Result.IncludeTemplates, Length(IncludeTemplates));
  for I := 0 to High(IncludeTemplates) do
    Result.IncludeTemplates[I] := IncludeTemplates[I];
  Result.OutputFormat := OutputFormat;
  Result.ValidationRegex := ValidationRegex;
  Result.Examples := Examples;
  Result.RecommendedConfig := RecommendedConfig;
  Result.RecommendedModel := RecommendedModel;
  Result.MaxTokens := MaxTokens;
  Result.Temperature := Temperature;
  Result.IsEnabled := IsEnabled;
  Result.IsBuiltIn := False; // Copy is never built-in
  Result.SortOrder := SortOrder;
end;

{ TUniBaseLLM }

constructor TUniBaseLLM.Create(AConnection: TFDConnection);
begin
  inherited Create;
  FConnection := AConnection;
  FConfigCache := TDictionary<string, TLLMConfig>.Create;
  FCacheLock := TCriticalSection.Create;
  FHttpClient := TNetHTTPClient.Create(nil);
  FHttpClient.ConnectionTimeout := DEFAULT_TIMEOUT;
  FHttpClient.ResponseTimeout := DEFAULT_TIMEOUT;
  FDefaultTimeout := DEFAULT_TIMEOUT;
  
  RefreshConfigCache;
end;

destructor TUniBaseLLM.Destroy;
begin
  FHttpClient.Free;
  FCacheLock.Free;
  FConfigCache.Free;
  inherited;
end;

function TUniBaseLLM.GetDefaultBaseUrl(Provider: TLLMProvider): string;
begin
  case Provider of
    lpOpenAI:    Result := URL_OPENAI;
    lpAnthropic: Result := URL_ANTHROPIC;
    lpAzure:     Result := ''; // Must be configured
    lpLiteLLM:   Result := 'http://localhost:4000';
    lpOllama:    Result := 'http://localhost:11434';
    lpCustom:    Result := '';
  else
    Result := URL_OPENAI;
  end;
end;

procedure TUniBaseLLM.RefreshConfigCache;
var
  Query: TFDQuery;
  Config: TLLMConfig;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  FCacheLock.Enter;
  try
    FConfigCache.Clear;
    
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT * FROM LLMConfiguration WHERE IsEnabled = 1';
      Query.Open;
      
      while not Query.Eof do
      begin
        Config.Init;
        Config.Name := Query.FieldByName('Name').AsString;
        Config.Provider := TLLMConfig.StrToProvider(Query.FieldByName('Provider').AsString);
        Config.BaseUrl := Query.FieldByName('BaseUrl').AsString;
        Config.ApiKey := Query.FieldByName('ApiKey').AsString;
        Config.Model := Query.FieldByName('Model').AsString;
        Config.MaxTokens := Query.FieldByName('MaxTokens').AsInteger;
        Config.Temperature := Query.FieldByName('Temperature').AsFloat;
        Config.SystemPrompt := Query.FieldByName('SystemPrompt').AsString;
        Config.InputTokenPrice := Query.FieldByName('InputTokenPrice').AsFloat;
        Config.OutputTokenPrice := Query.FieldByName('OutputTokenPrice').AsFloat;
        Config.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
        Config.IsDefault := Query.FieldByName('IsDefault').AsInteger = 1;
        
        FConfigCache.AddOrSetValue(Config.Name, Config);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
  finally
    FCacheLock.Leave;
  end;
end;

function TUniBaseLLM.GetConfig(const AConfigName: string): TLLMConfig;
begin
  Result.Init;
  Result.Name := AConfigName;
  
  FCacheLock.Enter;
  try
    if not FConfigCache.TryGetValue(AConfigName, Result) then
    begin
      // Try to load from DB
      RefreshConfigCache;
      if not FConfigCache.TryGetValue(AConfigName, Result) then
      begin
        // Return default
        Result.Name := AConfigName;
      end;
    end;
  finally
    FCacheLock.Leave;
  end;
end;

function TUniBaseLLM.GetAllConfigs: TLLMConfigArray;
var
  Pair: TPair<string, TLLMConfig>;
  I: Integer;
begin
  FCacheLock.Enter;
  try
    SetLength(Result, FConfigCache.Count);
    I := 0;
    for Pair in FConfigCache do
    begin
      Result[I] := Pair.Value;
      Inc(I);
    end;
  finally
    FCacheLock.Leave;
  end;
end;

procedure TUniBaseLLM.SaveConfig(const AConfig: TLLMConfig);
var
  Query: TFDQuery;
  NowStr: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT OR REPLACE INTO LLMConfiguration ' +
      '(Name, Provider, BaseUrl, ApiKey, Model, MaxTokens, Temperature, ' +
      'SystemPrompt, InputTokenPrice, OutputTokenPrice, IsEnabled, IsDefault, UpdatedAt) ' +
      'VALUES (:Name, :Provider, :BaseUrl, :ApiKey, :Model, :MaxTokens, :Temperature, ' +
      ':SystemPrompt, :InputTokenPrice, :OutputTokenPrice, :IsEnabled, :IsDefault, :UpdatedAt)';
    
    Query.ParamByName('Name').AsString := AConfig.Name;
    Query.ParamByName('Provider').AsString := AConfig.ProviderToStr;
    Query.ParamByName('BaseUrl').AsString := AConfig.BaseUrl;
    Query.ParamByName('ApiKey').AsString := AConfig.ApiKey;
    Query.ParamByName('Model').AsString := AConfig.Model;
    Query.ParamByName('MaxTokens').AsInteger := AConfig.MaxTokens;
    Query.ParamByName('Temperature').AsFloat := AConfig.Temperature;
    Query.ParamByName('SystemPrompt').AsString := AConfig.SystemPrompt;
    Query.ParamByName('InputTokenPrice').AsFloat := AConfig.InputTokenPrice;
    Query.ParamByName('OutputTokenPrice').AsFloat := AConfig.OutputTokenPrice;
    Query.ParamByName('IsEnabled').AsInteger := Ord(AConfig.IsEnabled);
    Query.ParamByName('IsDefault').AsInteger := Ord(AConfig.IsDefault);
    Query.ParamByName('UpdatedAt').AsString := NowStr;
    
    Query.ExecSQL;
    
    // Update cache
    FCacheLock.Enter;
    try
      FConfigCache.AddOrSetValue(AConfig.Name, AConfig);
    finally
      FCacheLock.Leave;
    end;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseLLM.DeleteConfig(const AConfigName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM LLMConfiguration WHERE Name = :Name';
    Query.ParamByName('Name').AsString := AConfigName;
    Query.ExecSQL;
    
    FCacheLock.Enter;
    try
      FConfigCache.Remove(AConfigName);
    finally
      FCacheLock.Leave;
    end;
  finally
    Query.Free;
  end;
end;

function TUniBaseLLM.TestConnection(const AConfigName: string; out DurationMs: Int64; out ErrorMsg: string): Boolean;
var
  Response: TLLMChatResponse;
begin
  DurationMs := 0;
  ErrorMsg := '';
  
  Result := Chat(TEST_PROMPT, Response, AConfigName);
  DurationMs := Response.DurationMs;
  
  if not Result then
    ErrorMsg := Response.ErrorMessage;
end;

function TUniBaseLLM.BuildRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
var
  JsonObj, MsgObj: TJSONObject;
  MsgArray: TJSONArray;
  Msg: TLLMMessage;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('model', Config.Model);
    JsonObj.AddPair('max_tokens', TJSONNumber.Create(Config.MaxTokens));
    JsonObj.AddPair('temperature', TJSONNumber.Create(Config.Temperature));
    
    MsgArray := TJSONArray.Create;
    
    // Add system prompt if exists
    if Config.SystemPrompt <> '' then
    begin
      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', 'system');
      MsgObj.AddPair('content', Config.SystemPrompt);
      MsgArray.Add(MsgObj);
    end;
    
    // Add messages
    for Msg in Messages do
    begin
      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', Msg.Role);
      MsgObj.AddPair('content', Msg.Content);
      MsgArray.Add(MsgObj);
    end;
    
    JsonObj.AddPair('messages', MsgArray);
    
    Result := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
end;

function TUniBaseLLM.BuildAnthropicRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
var
  JsonObj, MsgObj: TJSONObject;
  MsgArray: TJSONArray;
  Msg: TLLMMessage;
begin
  JsonObj := TJSONObject.Create;
  try
    JsonObj.AddPair('model', Config.Model);
    JsonObj.AddPair('max_tokens', TJSONNumber.Create(Config.MaxTokens));
    
    if Config.Temperature >= 0 then
      JsonObj.AddPair('temperature', TJSONNumber.Create(Config.Temperature));
    
    // Anthropic uses system as a separate field
    if Config.SystemPrompt <> '' then
      JsonObj.AddPair('system', Config.SystemPrompt);
    
    MsgArray := TJSONArray.Create;
    
    for Msg in Messages do
    begin
      // Skip system messages for Anthropic (handled above)
      if Msg.Role = 'system' then
        Continue;
        
      MsgObj := TJSONObject.Create;
      MsgObj.AddPair('role', Msg.Role);
      MsgObj.AddPair('content', Msg.Content);
      MsgArray.Add(MsgObj);
    end;
    
    JsonObj.AddPair('messages', MsgArray);
    
    Result := JsonObj.ToJSON;
  finally
    JsonObj.Free;
  end;
end;

function TUniBaseLLM.DoHttpRequest(const Url, Body: string; const Config: TLLMConfig;
  out Response: string; out DurationMs: Int64): Boolean;
var
  HttpResponse: IHTTPResponse;
  RequestContent: TStringStream;
  StartTime: TDateTime;
  Headers: TArray<TNameValuePair>;
begin
  Result := False;
  Response := '';
  StartTime := Now;
  
  RequestContent := TStringStream.Create(Body, TEncoding.UTF8);
  try
    // Set headers based on provider
    case Config.Provider of
      lpAnthropic:
        Headers := [
          TNameValuePair.Create('Content-Type', 'application/json'),
          TNameValuePair.Create('x-api-key', Config.ApiKey),
          TNameValuePair.Create('anthropic-version', '2023-06-01')
        ];
    else
      Headers := [
        TNameValuePair.Create('Content-Type', 'application/json'),
        TNameValuePair.Create('Authorization', 'Bearer ' + Config.ApiKey)
      ];
    end;
    
    try
      HttpResponse := FHttpClient.Post(Url, RequestContent, nil, Headers);
      DurationMs := MilliSecondsBetween(Now, StartTime);
      
      Response := HttpResponse.ContentAsString(TEncoding.UTF8);
      Result := (HttpResponse.StatusCode >= 200) and (HttpResponse.StatusCode < 300);
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);
        Response := '{"error": {"message": "' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}}';
        Result := False;
      end;
    end;
  finally
    RequestContent.Free;
  end;
end;

function TUniBaseLLM.ParseOpenAIResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
var
  JsonObj, ChoiceObj, MsgObj, UsageObj, ErrorObj: TJSONObject;
  ChoicesArray: TJSONArray;
begin
  Result := False;
  Response.Init;
  
  try
    JsonObj := TJSONObject.ParseJSONValue(JsonResponse) as TJSONObject;
    if JsonObj = nil then
    begin
      Response.ErrorMessage := 'Invalid JSON response';
      Exit;
    end;
    
    try
      // Check for error
      if JsonObj.TryGetValue<TJSONObject>('error', ErrorObj) then
      begin
        Response.ErrorMessage := ErrorObj.GetValue<string>('message', 'Unknown error');
        Response.ErrorCode := ErrorObj.GetValue<string>('type', '');
        Exit;
      end;
      
      // Parse choices
      if not JsonObj.TryGetValue<TJSONArray>('choices', ChoicesArray) then
      begin
        Response.ErrorMessage := 'No choices in response';
        Exit;
      end;
      
      if ChoicesArray.Count = 0 then
      begin
        Response.ErrorMessage := 'Empty choices array';
        Exit;
      end;
      
      ChoiceObj := ChoicesArray.Items[0] as TJSONObject;
      Response.FinishReason := ChoiceObj.GetValue<string>('finish_reason', '');
      
      if ChoiceObj.TryGetValue<TJSONObject>('message', MsgObj) then
        Response.Content := MsgObj.GetValue<string>('content', '');
      
      // Parse usage
      if JsonObj.TryGetValue<TJSONObject>('usage', UsageObj) then
      begin
        Response.InputTokens := UsageObj.GetValue<Integer>('prompt_tokens', 0);
        Response.OutputTokens := UsageObj.GetValue<Integer>('completion_tokens', 0);
        Response.TotalTokens := UsageObj.GetValue<Integer>('total_tokens', 0);
      end;
      
      Response.Success := True;
      Result := True;
    finally
      JsonObj.Free;
    end;
  except
    on E: Exception do
    begin
      Response.ErrorMessage := 'Parse error: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TUniBaseLLM.ParseAnthropicResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
var
  JsonObj, ContentObj, UsageObj, ErrorObj: TJSONObject;
  ContentArray: TJSONArray;
begin
  Result := False;
  Response.Init;
  
  try
    JsonObj := TJSONObject.ParseJSONValue(JsonResponse) as TJSONObject;
    if JsonObj = nil then
    begin
      Response.ErrorMessage := 'Invalid JSON response';
      Exit;
    end;
    
    try
      // Check for error
      if JsonObj.TryGetValue<TJSONObject>('error', ErrorObj) then
      begin
        Response.ErrorMessage := ErrorObj.GetValue<string>('message', 'Unknown error');
        Response.ErrorCode := ErrorObj.GetValue<string>('type', '');
        Exit;
      end;
      
      // Parse content
      if JsonObj.TryGetValue<TJSONArray>('content', ContentArray) and (ContentArray.Count > 0) then
      begin
        ContentObj := ContentArray.Items[0] as TJSONObject;
        Response.Content := ContentObj.GetValue<string>('text', '');
      end;
      
      Response.FinishReason := JsonObj.GetValue<string>('stop_reason', '');
      
      // Parse usage
      if JsonObj.TryGetValue<TJSONObject>('usage', UsageObj) then
      begin
        Response.InputTokens := UsageObj.GetValue<Integer>('input_tokens', 0);
        Response.OutputTokens := UsageObj.GetValue<Integer>('output_tokens', 0);
        Response.TotalTokens := Response.InputTokens + Response.OutputTokens;
      end;
      
      Response.Success := True;
      Result := True;
    finally
      JsonObj.Free;
    end;
  except
    on E: Exception do
    begin
      Response.ErrorMessage := 'Parse error: ' + E.Message;
      Result := False;
    end;
  end;
end;

function TUniBaseLLM.EstimateCost(const Config: TLLMConfig; InputTokens, OutputTokens: Integer): Double;
begin
  Result := (InputTokens / 1000.0 * Config.InputTokenPrice) +
            (OutputTokens / 1000.0 * Config.OutputTokenPrice);
end;

procedure TUniBaseLLM.RecordCall(const Config: TLLMConfig; const Prompt: string;
  const Response: TLLMChatResponse; const CallerModule, CallerFunc: string);
var
  Query: TFDQuery;
  Cost: Double;
  NowStr: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Cost := EstimateCost(Config, Response.InputTokens, Response.OutputTokens);
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
  
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text :=
      'INSERT INTO LLMCalls (ConfigName, Provider, Model, Prompt, Response, ' +
      'InputTokens, OutputTokens, TotalTokens, EstimatedCost, DurationMs, ' +
      'Success, ErrorCode, ErrorMessage, FinishReason, CallerModule, CallerFunction, CallTime) ' +
      'VALUES (:ConfigName, :Provider, :Model, :Prompt, :Response, ' +
      ':InputTokens, :OutputTokens, :TotalTokens, :EstimatedCost, :DurationMs, ' +
      ':Success, :ErrorCode, :ErrorMessage, :FinishReason, :CallerModule, :CallerFunction, :CallTime)';
    
    Query.ParamByName('ConfigName').AsString := Config.Name;
    Query.ParamByName('Provider').AsString := Config.ProviderToStr;
    Query.ParamByName('Model').AsString := Config.Model;
    Query.ParamByName('Prompt').AsString := Prompt;
    Query.ParamByName('Response').AsString := Response.Content;
    Query.ParamByName('InputTokens').AsInteger := Response.InputTokens;
    Query.ParamByName('OutputTokens').AsInteger := Response.OutputTokens;
    Query.ParamByName('TotalTokens').AsInteger := Response.TotalTokens;
    Query.ParamByName('EstimatedCost').AsFloat := Cost;
    Query.ParamByName('DurationMs').AsInteger := Response.DurationMs;
    Query.ParamByName('Success').AsInteger := Ord(Response.Success);
    Query.ParamByName('ErrorCode').AsString := Response.ErrorCode;
    Query.ParamByName('ErrorMessage').AsString := Response.ErrorMessage;
    Query.ParamByName('FinishReason').AsString := Response.FinishReason;
    Query.ParamByName('CallerModule').AsString := CallerModule;
    Query.ParamByName('CallerFunction').AsString := CallerFunc;
    Query.ParamByName('CallTime').AsString := NowStr;
    
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TUniBaseLLM.Chat(const Prompt: string; out Response: string; const ConfigName: string): Boolean;
var
  ChatResponse: TLLMChatResponse;
begin
  Result := Chat(Prompt, ChatResponse, ConfigName);
  Response := ChatResponse.Content;
end;

function TUniBaseLLM.Chat(const Prompt: string; out Response: TLLMChatResponse; const ConfigName: string): Boolean;
var
  Messages: TLLMMessages;
begin
  SetLength(Messages, 1);
  Messages[0] := TLLMMessage.User(Prompt);
  Result := ChatWithMessages(Messages, Response, ConfigName);
end;

function TUniBaseLLM.ChatWithMessages(const Messages: TLLMMessages; out Response: TLLMChatResponse;
  const ConfigName: string): Boolean;
var
  Config: TLLMConfig;
  BaseUrl, Endpoint, RequestBody, HttpResponse: string;
begin
  Response.Init;
  Config := GetConfig(ConfigName);
  
  // Determine base URL
  BaseUrl := Config.BaseUrl;
  if BaseUrl = '' then
    BaseUrl := GetDefaultBaseUrl(Config.Provider);
  
  // Determine endpoint and build request
  case Config.Provider of
    lpAnthropic:
    begin
      Endpoint := BaseUrl + '/messages';
      RequestBody := BuildAnthropicRequestBody(Config, Messages);
    end;
    lpOllama:
    begin
      Endpoint := BaseUrl + '/api/chat';
      RequestBody := BuildRequestBody(Config, Messages);
    end;
  else
    begin
      Endpoint := BaseUrl + '/chat/completions';
      RequestBody := BuildRequestBody(Config, Messages);
    end;
  end;
  
  // Execute request
  Result := DoHttpRequest(Endpoint, RequestBody, Config, HttpResponse, Response.DurationMs);
  
  // Parse response
  if Config.Provider = lpAnthropic then
    Result := ParseAnthropicResponse(HttpResponse, Response)
  else
    Result := ParseOpenAIResponse(HttpResponse, Response);
  
  // Record call
  if Length(Messages) > 0 then
    RecordCall(Config, Messages[High(Messages)].Content, Response, '', '');
end;

function TUniBaseLLM.ChatAsync(const Prompt: string; OnComplete: TLLMCompleteEvent; const ConfigName: string): ITask;
begin
  Result := TTask.Run(
    procedure
    var
      Response: TLLMChatResponse;
      Success: Boolean;
    begin
      Success := Chat(Prompt, Response, ConfigName);
      
      TThread.Queue(nil,
        procedure
        begin
          if Assigned(OnComplete) then
            OnComplete(Self, Success, Response.Content, Response.ErrorMessage);
        end);
    end);
end;

function TUniBaseLLM.ChatStream(const Prompt: string; OnChunk: TLLMStreamCallback; const ConfigName: string): Boolean;
begin
  // Basic implementation - streaming not fully supported yet
  // Fall back to regular chat
  var Response: TLLMChatResponse;
  Result := Chat(Prompt, Response, ConfigName);
  
  if Assigned(OnChunk) then
  begin
    if Result then
      OnChunk(Response.Content, True)
    else
      OnChunk(Response.ErrorMessage, True);
  end;
end;

procedure LoadTemplateFromQuery(Query: TFDQuery; var Template: TLLMPromptTemplate);
var
  VarJson, IncJson, DefJson: TJSONValue;
  I: Integer;
  Pair: TJSONPair;
begin
  Template.Init;
  Template.Id := Query.FieldByName('Id').AsInteger;
  Template.Name := Query.FieldByName('Name').AsString;
  Template.Category := Query.FieldByName('Category').AsString;
  Template.Description := Query.FieldByName('Description').AsString;
  Template.SystemPrompt := Query.FieldByName('SystemPrompt').AsString;
  Template.UserPromptTemplate := Query.FieldByName('UserPromptTemplate').AsString;
  Template.RecommendedConfig := Query.FieldByName('RecommendedConfig').AsString;
  Template.RecommendedModel := Query.FieldByName('RecommendedModel').AsString;
  Template.MaxTokens := Query.FieldByName('MaxTokens').AsInteger;
  Template.Temperature := Query.FieldByName('Temperature').AsFloat;
  Template.ParentTemplate := Query.FieldByName('ParentTemplate').AsString;
  Template.OutputFormat := Query.FieldByName('OutputFormat').AsString;
  Template.ValidationRegex := Query.FieldByName('ValidationRegex').AsString;
  Template.Examples := Query.FieldByName('Examples').AsString;
  Template.IsEnabled := Query.FieldByName('IsEnabled').AsInteger = 1;
  Template.IsBuiltIn := Query.FieldByName('IsBuiltIn').AsInteger = 1;
  Template.SortOrder := Query.FieldByName('SortOrder').AsInteger;
  
  // Parse Variables JSON array
  try
    VarJson := TJSONObject.ParseJSONValue(Query.FieldByName('Variables').AsString);
    if Assigned(VarJson) and (VarJson is TJSONArray) then
    try
      SetLength(Template.Variables, TJSONArray(VarJson).Count);
      for I := 0 to TJSONArray(VarJson).Count - 1 do
        Template.Variables[I] := TJSONArray(VarJson).Items[I].Value;
    finally
      VarJson.Free;
    end;
  except
    SetLength(Template.Variables, 0);
  end;
  
  // Parse DefaultValues JSON object
  try
    DefJson := TJSONObject.ParseJSONValue(Query.FieldByName('DefaultValues').AsString);
    if Assigned(DefJson) and (DefJson is TJSONObject) then
    try
      Template.DefaultValues := TDictionary<string, string>.Create;
      for Pair in TJSONObject(DefJson) do
        Template.DefaultValues.Add(Pair.JsonString.Value, Pair.JsonValue.Value);
    finally
      DefJson.Free;
    end;
  except
    Template.DefaultValues := nil;
  end;
  
  // Parse IncludeTemplates JSON array
  try
    IncJson := TJSONObject.ParseJSONValue(Query.FieldByName('IncludeTemplates').AsString);
    if Assigned(IncJson) and (IncJson is TJSONArray) then
    try
      SetLength(Template.IncludeTemplates, TJSONArray(IncJson).Count);
      for I := 0 to TJSONArray(IncJson).Count - 1 do
        Template.IncludeTemplates[I] := TJSONArray(IncJson).Items[I].Value;
    finally
      IncJson.Free;
    end;
  except
    SetLength(Template.IncludeTemplates, 0);
  end;
end;

function TUniBaseLLM.GetTemplate(const TemplateName: string): TLLMPromptTemplate;
var
  Query: TFDQuery;
begin
  Result.Init;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'SELECT * FROM LLMPromptTemplates WHERE Name = :Name AND IsEnabled = 1';
    Query.ParamByName('Name').AsString := TemplateName;
    Query.Open;
    
    if not Query.Eof then
      LoadTemplateFromQuery(Query, Result);
  finally
    Query.Free;
  end;
end;

function TUniBaseLLM.GetAllTemplates: TLLMPromptTemplateArray;
var
  Query: TFDQuery;
  List: TList<TLLMPromptTemplate>;
  Template: TLLMPromptTemplate;
begin
  SetLength(Result, 0);
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  List := TList<TLLMPromptTemplate>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT * FROM LLMPromptTemplates WHERE IsEnabled = 1 ORDER BY SortOrder, Name';
      Query.Open;
      
      while not Query.Eof do
      begin
        LoadTemplateFromQuery(Query, Template);
        List.Add(Template);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TUniBaseLLM.GetTemplatesByCategory(const Category: string): TLLMPromptTemplateArray;
var
  Query: TFDQuery;
  List: TList<TLLMPromptTemplate>;
  Template: TLLMPromptTemplate;
begin
  SetLength(Result, 0);
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  List := TList<TLLMPromptTemplate>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      Query.SQL.Text := 'SELECT * FROM LLMPromptTemplates WHERE Category = :Category AND IsEnabled = 1 ORDER BY SortOrder, Name';
      Query.ParamByName('Category').AsString := Category;
      Query.Open;
      
      while not Query.Eof do
      begin
        LoadTemplateFromQuery(Query, Template);
        List.Add(Template);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

function TUniBaseLLM.ExecuteTemplate(const TemplateName: string;
  const Variables: TDictionary<string, string>; out Response: string): Boolean;
var
  Template: TLLMPromptTemplate;
  Config: TLLMConfig;
  Prompt: string;
  ChatResponse: TLLMChatResponse;
begin
  Response := '';
  
  Template := GetTemplate(TemplateName);
  if Template.Name = '' then
  begin
    Response := 'Template not found: ' + TemplateName;
    Exit(False);
  end;
  
  // Render prompt
  Prompt := Template.RenderUserPrompt(Variables);
  
  // Get config (use recommended or default)
  if Template.RecommendedConfig <> '' then
    Config := GetConfig(Template.RecommendedConfig)
  else
    Config := GetConfig('Default');
  
  // Override system prompt and temperature from template
  if Template.SystemPrompt <> '' then
    Config.SystemPrompt := Template.SystemPrompt;
  if Template.Temperature > 0 then
    Config.Temperature := Template.Temperature;
  
  // Execute chat
  Result := Chat(Prompt, ChatResponse, Config.Name);
  Response := ChatResponse.Content;
end;

function TUniBaseLLM.GetCallHistory(ALimit: Integer; const ConfigName: string): TLLMCallRecordArray;
var
  Query: TFDQuery;
  List: TList<TLLMCallRecord>;
  Rec: TLLMCallRecord;
begin
  SetLength(Result, 0);
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  List := TList<TLLMCallRecord>.Create;
  try
    Query := TFDQuery.Create(nil);
    try
      Query.Connection := FConnection;
      
      if ConfigName <> '' then
      begin
        Query.SQL.Text := 'SELECT * FROM LLMCalls WHERE ConfigName = :ConfigName ORDER BY CallTime DESC LIMIT :Limit';
        Query.ParamByName('ConfigName').AsString := ConfigName;
      end
      else
        Query.SQL.Text := 'SELECT * FROM LLMCalls ORDER BY CallTime DESC LIMIT :Limit';
      
      Query.ParamByName('Limit').AsInteger := ALimit;
      Query.Open;
      
      while not Query.Eof do
      begin
        Rec.Id := Query.FieldByName('Id').AsInteger;
        Rec.ConfigName := Query.FieldByName('ConfigName').AsString;
        Rec.Provider := Query.FieldByName('Provider').AsString;
        Rec.Model := Query.FieldByName('Model').AsString;
        Rec.Prompt := Query.FieldByName('Prompt').AsString;
        Rec.Response := Query.FieldByName('Response').AsString;
        Rec.InputTokens := Query.FieldByName('InputTokens').AsInteger;
        Rec.OutputTokens := Query.FieldByName('OutputTokens').AsInteger;
        Rec.TotalTokens := Query.FieldByName('TotalTokens').AsInteger;
        Rec.EstimatedCost := Query.FieldByName('EstimatedCost').AsFloat;
        Rec.DurationMs := Query.FieldByName('DurationMs').AsInteger;
        Rec.Success := Query.FieldByName('Success').AsInteger = 1;
        Rec.ErrorCode := Query.FieldByName('ErrorCode').AsString;
        Rec.ErrorMessage := Query.FieldByName('ErrorMessage').AsString;
        Rec.CallTime := Query.FieldByName('CallTime').AsDateTime;
        
        List.Add(Rec);
        Query.Next;
      end;
    finally
      Query.Free;
    end;
    
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

procedure TUniBaseLLM.GetUsageStats(const ConfigName: string; DaysBack: Integer;
  out TotalCalls: Integer; out TotalTokens: Integer; out TotalCost: Double);
var
  Query: TFDQuery;
  CutoffDate: string;
begin
  TotalCalls := 0;
  TotalTokens := 0;
  TotalCost := 0;
  
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  
  // 使用参数化方式避免 FireDAC 误解 datetime('now')
  CutoffDate := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now - DaysBack);
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    if ConfigName <> '' then
    begin
      Query.SQL.Text :=
        'SELECT COUNT(*) AS Calls, COALESCE(SUM(TotalTokens), 0) AS Tokens, ' +
        'COALESCE(SUM(EstimatedCost), 0) AS Cost FROM LLMCalls ' +
        'WHERE ConfigName = :ConfigName AND CallTime >= :CutoffDate';
      Query.ParamByName('ConfigName').AsString := ConfigName;
    end
    else
    begin
      Query.SQL.Text :=
        'SELECT COUNT(*) AS Calls, COALESCE(SUM(TotalTokens), 0) AS Tokens, ' +
        'COALESCE(SUM(EstimatedCost), 0) AS Cost FROM LLMCalls ' +
        'WHERE CallTime >= :CutoffDate';
    end;
    
    Query.ParamByName('CutoffDate').AsString := CutoffDate;
    Query.Open;
    
    TotalCalls := Query.FieldByName('Calls').AsInteger;
    TotalTokens := Query.FieldByName('Tokens').AsInteger;
    TotalCost := Query.FieldByName('Cost').AsFloat;
  finally
    Query.Free;
  end;
end;

procedure TUniBaseLLM.ClearOldCalls(DaysToKeep: Integer);
var
  Query: TFDQuery;
  CutoffDate: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    
    if DaysToKeep <= 0 then
      Query.SQL.Text := 'DELETE FROM LLMCalls'
    else
    begin
      // 使用参数化方式避免 FireDAC 误解 datetime('now')
      CutoffDate := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now - DaysToKeep);
      Query.SQL.Text := 'DELETE FROM LLMCalls WHERE CallTime < :CutoffDate';
      Query.ParamByName('CutoffDate').AsString := CutoffDate;
    end;
    
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

{ Template CRUD Methods }

procedure TUniBaseLLM.SaveTemplate(const Template: TLLMPromptTemplate);
var
  Query: TFDQuery;
  VarsJson, IncJson: TJSONArray;
  DefsJson: TJSONObject;
  I: Integer;
  Key: string;
  NowStr: string;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
  if Template.Name = '' then
    raise ELLMException.Create('Template name cannot be empty');
    
  NowStr := FormatDateTime('yyyy-mm-dd hh:nn:ss', Now);
  
  // Build Variables JSON array
  VarsJson := TJSONArray.Create;
  try
    for I := 0 to High(Template.Variables) do
      VarsJson.Add(Template.Variables[I]);
    
    // Build IncludeTemplates JSON array
    IncJson := TJSONArray.Create;
    try
      for I := 0 to High(Template.IncludeTemplates) do
        IncJson.Add(Template.IncludeTemplates[I]);
      
      // Build DefaultValues JSON object
      DefsJson := TJSONObject.Create;
      try
        if Assigned(Template.DefaultValues) then
          for Key in Template.DefaultValues.Keys do
            DefsJson.AddPair(Key, Template.DefaultValues[Key]);
        
        Query := TFDQuery.Create(nil);
        try
          Query.Connection := FConnection;
          
          // Check if exists
          Query.SQL.Text := 'SELECT Id FROM LLMPromptTemplates WHERE Name = :Name';
          Query.ParamByName('Name').AsString := Template.Name;
          Query.Open;
          
          if Query.Eof then
          begin
            // Insert
            Query.SQL.Text := 
              'INSERT INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, ' +
              'UserPromptTemplate, Variables, DefaultValues, ParentTemplate, IncludeTemplates, ' +
              'OutputFormat, ValidationRegex, Examples, RecommendedConfig, RecommendedModel, ' +
              'MaxTokens, Temperature, IsEnabled, IsBuiltIn, SortOrder, CreatedAt, UpdatedAt) ' +
              'VALUES (:Name, :Category, :Description, :SystemPrompt, :UserPromptTemplate, ' +
              ':Variables, :DefaultValues, :ParentTemplate, :IncludeTemplates, :OutputFormat, ' +
              ':ValidationRegex, :Examples, :RecommendedConfig, :RecommendedModel, :MaxTokens, ' +
              ':Temperature, :IsEnabled, :IsBuiltIn, :SortOrder, :CreatedAt, :UpdatedAt)';
          end
          else
          begin
            // Update
            Query.SQL.Text := 
              'UPDATE LLMPromptTemplates SET Category = :Category, Description = :Description, ' +
              'SystemPrompt = :SystemPrompt, UserPromptTemplate = :UserPromptTemplate, ' +
              'Variables = :Variables, DefaultValues = :DefaultValues, ParentTemplate = :ParentTemplate, ' +
              'IncludeTemplates = :IncludeTemplates, OutputFormat = :OutputFormat, ' +
              'ValidationRegex = :ValidationRegex, Examples = :Examples, ' +
              'RecommendedConfig = :RecommendedConfig, RecommendedModel = :RecommendedModel, ' +
              'MaxTokens = :MaxTokens, Temperature = :Temperature, IsEnabled = :IsEnabled, ' +
              'SortOrder = :SortOrder, UpdatedAt = :UpdatedAt WHERE Name = :Name';
          end;
          
          Query.ParamByName('Name').AsString := Template.Name;
          Query.ParamByName('Category').AsString := Template.Category;
          Query.ParamByName('Description').AsString := Template.Description;
          Query.ParamByName('SystemPrompt').AsString := Template.SystemPrompt;
          Query.ParamByName('UserPromptTemplate').AsString := Template.UserPromptTemplate;
          Query.ParamByName('Variables').AsString := VarsJson.ToString;
          Query.ParamByName('DefaultValues').AsString := DefsJson.ToString;
          Query.ParamByName('ParentTemplate').AsString := Template.ParentTemplate;
          Query.ParamByName('IncludeTemplates').AsString := IncJson.ToString;
          Query.ParamByName('OutputFormat').AsString := Template.OutputFormat;
          Query.ParamByName('ValidationRegex').AsString := Template.ValidationRegex;
          Query.ParamByName('Examples').AsString := Template.Examples;
          Query.ParamByName('RecommendedConfig').AsString := Template.RecommendedConfig;
          Query.ParamByName('RecommendedModel').AsString := Template.RecommendedModel;
          Query.ParamByName('MaxTokens').AsInteger := Template.MaxTokens;
          Query.ParamByName('Temperature').AsFloat := Template.Temperature;
          Query.ParamByName('IsEnabled').AsInteger := Ord(Template.IsEnabled);
          Query.ParamByName('SortOrder').AsInteger := Template.SortOrder;
          Query.ParamByName('UpdatedAt').AsString := NowStr;
          
          if Query.Params.FindParam('IsBuiltIn') <> nil then
            Query.ParamByName('IsBuiltIn').AsInteger := Ord(Template.IsBuiltIn);
          if Query.Params.FindParam('CreatedAt') <> nil then
            Query.ParamByName('CreatedAt').AsString := NowStr;
          
          Query.ExecSQL;
        finally
          Query.Free;
        end;
      finally
        DefsJson.Free;
      end;
    finally
      IncJson.Free;
    end;
  finally
    VarsJson.Free;
  end;
end;

procedure TUniBaseLLM.DeleteTemplate(const TemplateName: string);
var
  Query: TFDQuery;
begin
  if not Assigned(FConnection) or not FConnection.Connected then
    Exit;
    
  Query := TFDQuery.Create(nil);
  try
    Query.Connection := FConnection;
    Query.SQL.Text := 'DELETE FROM LLMPromptTemplates WHERE Name = :Name AND IsBuiltIn = 0';
    Query.ParamByName('Name').AsString := TemplateName;
    Query.ExecSQL;
  finally
    Query.Free;
  end;
end;

function TUniBaseLLM.CopyTemplate(const SourceName, NewName: string): Boolean;
var
  Source: TLLMPromptTemplate;
  NewTemplate: TLLMPromptTemplate;
begin
  Result := False;
  
  Source := GetTemplate(SourceName);
  if Source.Name = '' then
    Exit;
    
  NewTemplate := Source.Clone;
  NewTemplate.Name := NewName;
  NewTemplate.IsBuiltIn := False;
  
  try
    SaveTemplate(NewTemplate);
    Result := True;
  except
    Result := False;
  end;
end;

function TUniBaseLLM.ValidateTemplate(const Template: TLLMPromptTemplate): TTemplateValidation;
var
  VarPattern: string;
  Match: TMatch;
  FoundVars: TList<string>;
  V: string;
  I: Integer;
  Depth: Integer;
  Parent: TLLMPromptTemplate;
begin
  Result.IsValid := True;
  SetLength(Result.Errors, 0);
  SetLength(Result.MissingVariables, 0);
  
  FoundVars := TList<string>.Create;
  try
    // Check required fields
    if Template.Name = '' then
    begin
      Result.IsValid := False;
      SetLength(Result.Errors, Length(Result.Errors) + 1);
      Result.Errors[High(Result.Errors)] := 'Template name is required';
    end;
    
    if Template.UserPromptTemplate = '' then
    begin
      Result.IsValid := False;
      SetLength(Result.Errors, Length(Result.Errors) + 1);
      Result.Errors[High(Result.Errors)] := 'UserPromptTemplate is required';
    end;
    
    // Extract variables from template
    VarPattern := '\{\{([^}]+)\}\}';
    for Match in TRegEx.Matches(Template.UserPromptTemplate, VarPattern) do
    begin
      V := Match.Groups[1].Value;
      if not FoundVars.Contains(V) then
        FoundVars.Add(V);
    end;
    
    // Check if all found variables are declared
    for I := 0 to FoundVars.Count - 1 do
    begin
      V := FoundVars[I];
      if not V.StartsWith('include:') then // Skip include directives
      begin
        // Check if variable is in declared list
        if IndexStr(V, Template.Variables) < 0 then
        begin
          SetLength(Result.MissingVariables, Length(Result.MissingVariables) + 1);
          Result.MissingVariables[High(Result.MissingVariables)] := V;
        end;
      end;
    end;
    
    // Check circular inheritance (max 5 levels)
    if Template.ParentTemplate <> '' then
    begin
      Depth := 0;
      Parent := GetTemplate(Template.ParentTemplate);
      while (Parent.Name <> '') and (Depth < 5) do
      begin
        if Parent.Name = Template.Name then
        begin
          Result.IsValid := False;
          SetLength(Result.Errors, Length(Result.Errors) + 1);
          Result.Errors[High(Result.Errors)] := 'Circular inheritance detected: ' + Template.Name;
          Break;
        end;
        Parent := GetTemplate(Parent.ParentTemplate);
        Inc(Depth);
      end;
      
      if Depth >= 5 then
      begin
        Result.IsValid := False;
        SetLength(Result.Errors, Length(Result.Errors) + 1);
        Result.Errors[High(Result.Errors)] := 'Inheritance depth exceeds maximum (5)';
      end;
    end;
  finally
    FoundVars.Free;
  end;
end;

function TUniBaseLLM.RenderWithInheritance(const TemplateName: string;
  const Variables: TDictionary<string, string>): string;
var
  Template, Parent: TLLMPromptTemplate;
  MergedVars: TDictionary<string, string>;
  Depth: Integer;
  Key, Val: string;
  IncludeName, IncludeContent: string;
  IncTemplate: TLLMPromptTemplate;
  I: Integer;
begin
  Result := '';
  
  Template := GetTemplate(TemplateName);
  if Template.Name = '' then
    Exit;
  
  // Merge variables with defaults from inheritance chain
  MergedVars := TDictionary<string, string>.Create;
  try
    // Start with provided variables
    for Key in Variables.Keys do
      MergedVars.AddOrSetValue(Key, Variables[Key]);
    
    // Walk up inheritance chain and add missing defaults
    Depth := 0;
    Parent := Template;
    while (Parent.Name <> '') and (Depth < 5) do
    begin
      // Add defaults from this level (don't overwrite)
      if Assigned(Parent.DefaultValues) then
      begin
        for Key in Parent.DefaultValues.Keys do
        begin
          if not MergedVars.ContainsKey(Key) then
            MergedVars.Add(Key, Parent.DefaultValues[Key]);
        end;
      end;
      
      // Move to parent
      if Parent.ParentTemplate <> '' then
        Parent := GetTemplate(Parent.ParentTemplate)
      else
        Break;
      Inc(Depth);
    end;
    
    // Render template
    Result := Template.UserPromptTemplate;
    
    // Replace variables
    for Key in MergedVars.Keys do
    begin
      if MergedVars.TryGetValue(Key, Val) then
        Result := StringReplace(Result, '{{' + Key + '}}', Val, [rfReplaceAll]);
    end;
    
    // Process includes {{include:template_name}}
    for I := 0 to High(Template.IncludeTemplates) do
    begin
      IncludeName := Template.IncludeTemplates[I];
      IncTemplate := GetTemplate(IncludeName);
      if IncTemplate.Name <> '' then
      begin
        IncludeContent := RenderWithInheritance(IncludeName, MergedVars);
        Result := StringReplace(Result, '{{include:' + IncludeName + '}}', IncludeContent, [rfReplaceAll]);
      end;
    end;
  finally
    MergedVars.Free;
  end;
end;

function TUniBaseLLM.ExportTemplates: string;
var
  Templates: TLLMPromptTemplateArray;
  JsonArr: TJSONArray;
  JsonObj: TJSONObject;
  VarsArr, IncArr: TJSONArray;
  DefsObj: TJSONObject;
  T: TLLMPromptTemplate;
  I: Integer;
  Key: string;
begin
  Templates := GetAllTemplates;
  
  JsonArr := TJSONArray.Create;
  try
    for T in Templates do
    begin
      JsonObj := TJSONObject.Create;
      JsonObj.AddPair('name', T.Name);
      JsonObj.AddPair('category', T.Category);
      JsonObj.AddPair('description', T.Description);
      JsonObj.AddPair('systemPrompt', T.SystemPrompt);
      JsonObj.AddPair('userPromptTemplate', T.UserPromptTemplate);
      JsonObj.AddPair('parentTemplate', T.ParentTemplate);
      JsonObj.AddPair('outputFormat', T.OutputFormat);
      JsonObj.AddPair('validationRegex', T.ValidationRegex);
      JsonObj.AddPair('examples', T.Examples);
      JsonObj.AddPair('recommendedConfig', T.RecommendedConfig);
      JsonObj.AddPair('recommendedModel', T.RecommendedModel);
      JsonObj.AddPair('maxTokens', TJSONNumber.Create(T.MaxTokens));
      JsonObj.AddPair('temperature', TJSONNumber.Create(T.Temperature));
      JsonObj.AddPair('isEnabled', TJSONBool.Create(T.IsEnabled));
      JsonObj.AddPair('isBuiltIn', TJSONBool.Create(T.IsBuiltIn));
      JsonObj.AddPair('sortOrder', TJSONNumber.Create(T.SortOrder));
      
      // Variables array
      VarsArr := TJSONArray.Create;
      for I := 0 to High(T.Variables) do
        VarsArr.Add(T.Variables[I]);
      JsonObj.AddPair('variables', VarsArr);
      
      // Include templates array
      IncArr := TJSONArray.Create;
      for I := 0 to High(T.IncludeTemplates) do
        IncArr.Add(T.IncludeTemplates[I]);
      JsonObj.AddPair('includeTemplates', IncArr);
      
      // Default values object
      DefsObj := TJSONObject.Create;
      if Assigned(T.DefaultValues) then
        for Key in T.DefaultValues.Keys do
          DefsObj.AddPair(Key, T.DefaultValues[Key]);
      JsonObj.AddPair('defaultValues', DefsObj);
      
      JsonArr.Add(JsonObj);
    end;
    
    Result := JsonArr.Format(2);
  finally
    JsonArr.Free;
  end;
end;

function TUniBaseLLM.ImportTemplates(const Json: string; OverwriteExisting: Boolean): Integer;
var
  JsonArr: TJSONArray;
  JsonObj: TJSONObject;
  Template: TLLMPromptTemplate;
  VarsArr, IncArr: TJSONArray;
  DefsObj: TJSONObject;
  I, J: Integer;
  Pair: TJSONPair;
  Existing: TLLMPromptTemplate;
begin
  Result := 0;
  
  JsonArr := TJSONObject.ParseJSONValue(Json) as TJSONArray;
  if not Assigned(JsonArr) then
    Exit;
    
  try
    for I := 0 to JsonArr.Count - 1 do
    begin
      JsonObj := JsonArr.Items[I] as TJSONObject;
      
      Template.Init;
      Template.Name := JsonObj.GetValue<string>('name', '');
      if Template.Name = '' then
        Continue;
      
      // Check if exists
      if not OverwriteExisting then
      begin
        Existing := GetTemplate(Template.Name);
        if Existing.Name <> '' then
          Continue;
      end;
      
      Template.Category := JsonObj.GetValue<string>('category', 'General');
      Template.Description := JsonObj.GetValue<string>('description', '');
      Template.SystemPrompt := JsonObj.GetValue<string>('systemPrompt', '');
      Template.UserPromptTemplate := JsonObj.GetValue<string>('userPromptTemplate', '');
      Template.ParentTemplate := JsonObj.GetValue<string>('parentTemplate', '');
      Template.OutputFormat := JsonObj.GetValue<string>('outputFormat', 'text');
      Template.ValidationRegex := JsonObj.GetValue<string>('validationRegex', '');
      Template.Examples := JsonObj.GetValue<string>('examples', '');
      Template.RecommendedConfig := JsonObj.GetValue<string>('recommendedConfig', '');
      Template.RecommendedModel := JsonObj.GetValue<string>('recommendedModel', '');
      Template.MaxTokens := JsonObj.GetValue<Integer>('maxTokens', 0);
      Template.Temperature := JsonObj.GetValue<Double>('temperature', 0.7);
      Template.IsEnabled := JsonObj.GetValue<Boolean>('isEnabled', True);
      Template.IsBuiltIn := False; // Imported templates are never built-in
      Template.SortOrder := JsonObj.GetValue<Integer>('sortOrder', 0);
      
      // Variables array
      VarsArr := JsonObj.GetValue<TJSONArray>('variables');
      if Assigned(VarsArr) then
      begin
        SetLength(Template.Variables, VarsArr.Count);
        for J := 0 to VarsArr.Count - 1 do
          Template.Variables[J] := VarsArr.Items[J].Value;
      end;
      
      // Include templates array
      IncArr := JsonObj.GetValue<TJSONArray>('includeTemplates');
      if Assigned(IncArr) then
      begin
        SetLength(Template.IncludeTemplates, IncArr.Count);
        for J := 0 to IncArr.Count - 1 do
          Template.IncludeTemplates[J] := IncArr.Items[J].Value;
      end;
      
      // Default values object
      DefsObj := JsonObj.GetValue<TJSONObject>('defaultValues');
      if Assigned(DefsObj) then
      begin
        Template.DefaultValues := TDictionary<string, string>.Create;
        for Pair in DefsObj do
          Template.DefaultValues.Add(Pair.JsonString.Value, Pair.JsonValue.Value);
      end;
      
      try
        SaveTemplate(Template);
        Inc(Result);
      except
        // Skip failed imports
      end;
    end;
  finally
    JsonArr.Free;
  end;
end;

end.
