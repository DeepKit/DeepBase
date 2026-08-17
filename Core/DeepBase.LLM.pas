{ ============================================================================
  DeepBase.LLM - LLM Integration Module (Facade)

  Version: 1.0
  Description: Provides unified LLM API integration with multiple providers
  Features:
    - Multiple providers: OpenAI, Anthropic, Azure, LiteLLM, Ollama, Custom
    - Configuration management via database
    - Async and sync chat methods
    - Call hiDeepStory tracking and cost estimation
    - Prompt template support

  This unit is the facade for the LLM module. All types are defined in
  DeepBase.LLM.Types, config helpers in DeepBase.LLM.Config, and provider
  logic in DeepBase.LLM.Providers.
  ============================================================================ }

unit DeepBase.LLM;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Data.DB,
  System.Net.HttpClient,
  System.Net.HttpClientComponent,
  System.Net.URLClient,
  System.Threading,
  System.Generics.Collections,
  System.DateUtils,
  System.SyncObjs,
  DeepBase.Types,
  DeepBase.LLM.Types,
  DeepBase.LLM.Config,
  DeepBase.LLM.Providers,
  DeepBase.LLM.PromptTemplateManager,
  DeepBase.StorageFactory;

// Re-export all types for backward compatibility
// Consumers can continue to use "DeepBase.LLM" and get all types

type
  // Exception
  ELLMException = DeepBase.LLM.Types.ELLMException;

  // Provider enum
  TLLMProvider = DeepBase.LLM.Types.TLLMProvider;

  // Config record
  TLLMConfig = DeepBase.LLM.Types.TLLMConfig;
  TLLMConfigArray = DeepBase.LLM.Types.TLLMConfigArray;

  // HTTP callback
  TLLMHttpPostProc = DeepBase.LLM.Types.TLLMHttpPostProc;

  // Call record
  TLLMCallRecord = DeepBase.LLM.Types.TLLMCallRecord;
  TLLMCallRecordArray = DeepBase.LLM.Types.TLLMCallRecordArray;

  // Message types
  TLLMMessage = DeepBase.LLM.Types.TLLMMessage;
  TLLMMessages = DeepBase.LLM.Types.TLLMMessages;

  // Chat response
  TLLMChatResponse = DeepBase.LLM.Types.TLLMChatResponse;

  // Request options
  TLLMRequestOptions = DeepBase.LLM.Types.TLLMRequestOptions;

  // Provider interface
  ILLMProvider = DeepBase.LLM.Types.ILLMProvider;

  // Template types
  TLLMTemplateExample = DeepBase.LLM.Types.TLLMTemplateExample;
  TLLMPromptTemplate = DeepBase.LLM.Types.TLLMPromptTemplate;
  TLLMPromptTemplateArray = DeepBase.LLM.Types.TLLMPromptTemplateArray;
  TTemplateValidation = DeepBase.LLM.Types.TTemplateValidation;

  // Streaming callback
  TLLMStreamCallback = DeepBase.LLM.Types.TLLMStreamCallback;

  // Storage types
  TLLMStorageParam = DeepBase.LLM.Types.TLLMStorageParam;
  TLLMStorageParams = DeepBase.LLM.Types.TLLMStorageParams;
  ILLMStorage = DeepBase.LLM.Types.ILLMStorage;

  /// <summary>
  /// DeepBase LLM Manager Class
  /// </summary>
  TDeepBaseLLM = class
  private
    FConnection: TObject;
    FStorage: ILLMStorage;
    FConfigCache: TDictionary<string, TLLMConfig>;
    FCacheLock: TCriticalSection;
    // BIZ2-001 fix: track all ChatAsync tasks so Destroy can wait for them
    // before freeing fields the closures still reference (FHttpClient,
    // FConfigCache). Without this, destroying TDeepBaseLLM while a ChatAsync
    // task is still running yields a use-after-free when the queued
    // OnComplete callback fires on the main thread after the instance is
    // gone.
    FActiveTasks: TList<ITask>;
    FActiveTasksLock: TCriticalSection;
    FHttpClient: TNetHTTPClient;
    FHttpTransport: TLLMHttpPostProc;
    FDefaultTimeout: Integer;
    // OPT-REFACTOR-001: template management extracted to its own class. The
    // facade keeps the 10 public template methods as thin delegates so
    // callers (Studio.PromptTemplateFrame, Test.DeepBase.LLM.PromptTemplate)
    // are unchanged.
    FPromptTemplateMgr: TLLMPromptTemplateManager;

    function GetStorage: ILLMStorage;
    function DoHttpRequest(const Url, Body: string; const Config: TLLMConfig; out Response: string; out DurationMs: Int64): Boolean;
    procedure RecordCall(const Config: TLLMConfig; const Prompt: string; const Response: TLLMChatResponse; const CallerModule, CallerFunc: string);
    function EstimateCost(const Config: TLLMConfig; InputTokens, OutputTokens: Integer): Double;

  public
    constructor Create(AConnection: TObject); overload;
    constructor Create(const AStorage: ILLMStorage); overload;
    destructor Destroy; override;

    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, ILLMStorage>); static;

    /// <summary>Inject custom HTTP transport. When set, DoHttpRequest uses this
    /// instead of the built-in TNetHTTPClient.</summary>
    procedure SetHttpTransport(const ATransport: TLLMHttpPostProc);

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

    /// <summary>Multi-turn chat with message hiDeepStory</summary>
    function ChatWithMessages(const Messages: TLLMMessages; out Response: TLLMChatResponse; const ConfigName: string = 'Default'): Boolean;

    /// <summary>Async chat</summary>
    function ChatAsync(const Prompt: string; OnComplete: TLLMCompleteEvent; const ConfigName: string = 'Default'): ITask;

    /// <summary>Streaming chat — NOTE: the current Core implementation degrades
    /// to a synchronous `Chat` call and fires `OnChunk` once with the full
    /// content. This violates the streaming contract; callers that require
    /// true token-by-token streaming should use the L3 ProxyLLMClient
    /// (`Features\DeepBase.LLM.Proxy.pas`) whose `ChatStream` performs real
    /// SSE parsing over `TStreamReader`, or await a future Core rework.</summary>
    /// <remarks>BUG EXP-P1-002: see tasks.md for the remediation plan.</remarks>
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

    /// <summary>Get call hiDeepStory</summary>
    function GetCallHistory(ALimit: Integer = 50; const ConfigName: string = ''): TLLMCallRecordArray;

    /// <summary>Get usage statistics</summary>
    procedure GetUsageStats(const ConfigName: string; DaysBack: Integer;
      out TotalCalls: Integer; out TotalTokens: Integer; out TotalCost: Double);

    /// <summary>Clear old call records</summary>
    procedure ClearOldCalls(DaysToKeep: Integer);

    // ========================================================================
    // Properties
    // ========================================================================

    property Connection: TObject read FConnection;
    property DefaultTimeout: Integer read FDefaultTimeout write FDefaultTimeout;
  end;

/// <summary>Convert provider enum to string</summary>
function LLMProviderToStr(Provider: TLLMProvider): string;

/// <summary>Convert string to provider enum</summary>
function StrToLLMProvider(const S: string): TLLMProvider;

implementation

uses
  System.StrUtils;

const
  DEFAULT_TIMEOUT = 60000; // 60 seconds
  TEST_PROMPT = 'Reply with exactly: OK';

// Re-export helper functions from DeepBase.LLM.Types
function LLMProviderToStr(Provider: TLLMProvider): string;
begin
  Result := DeepBase.LLM.Types.LLMProviderToStr(Provider);
end;

function StrToLLMProvider(const S: string): TLLMProvider;
begin
  Result := DeepBase.LLM.Types.StrToLLMProvider(S);
end;

{ TDeepBaseLLM }

constructor TDeepBaseLLM.Create(AConnection: TObject);
var
  LStorage: ILLMStorage;
begin
  LStorage := nil;
  if Supports(AConnection, ILLMStorage, LStorage) then
  else
    LStorage := TConnectionStorageFactory<ILLMStorage>.Create(AConnection);
  if (LStorage = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No LLM storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.LLM.FireDAC.');
  Create(LStorage);
  FConnection := AConnection;
end;

constructor TDeepBaseLLM.Create(const AStorage: ILLMStorage);
begin
  inherited Create;
  FConnection := nil;
  FStorage := AStorage;
  FConfigCache := TDictionary<string, TLLMConfig>.Create;
  FCacheLock := TCriticalSection.Create;
  FActiveTasks := TList<ITask>.Create;
  FActiveTasksLock := TCriticalSection.Create;
  FHttpClient := TNetHTTPClient.Create(nil);
  FHttpClient.ConnectionTimeout := DEFAULT_TIMEOUT;
  FHttpClient.ResponseTimeout := DEFAULT_TIMEOUT;
  FDefaultTimeout := DEFAULT_TIMEOUT;
  // OPT-REFACTOR-001: template manager shares the storage reference.
  FPromptTemplateMgr := TLLMPromptTemplateManager.Create(FStorage);

  RefreshConfigCache;
end;

class procedure TDeepBaseLLM.SetStorageFactory(
  const AFactory: TFunc<TObject, ILLMStorage>);
begin
  TConnectionStorageFactory<ILLMStorage>.SetFactory(AFactory);
end;

procedure TDeepBaseLLM.SetHttpTransport(const ATransport: TLLMHttpPostProc);
begin
  FHttpTransport := ATransport;
end;

function TDeepBaseLLM.GetStorage: ILLMStorage;
begin
  Result := FStorage;
end;

destructor TDeepBaseLLM.Destroy;
var
  LocalTasks: TArray<ITask>;
  T: ITask;
begin
  // BIZ2-001 fix: wait for any pending ChatAsync tasks before freeing the
  // fields their closures reference. Tasks are copied out under the lock,
  // then awaited without holding it so a slow task cannot deadlock the
  // destructor.
  if Assigned(FActiveTasks) then
  begin
    FActiveTasksLock.Enter;
    try
      LocalTasks := FActiveTasks.ToArray;
      FActiveTasks.Clear;
    finally
      FActiveTasksLock.Leave;
    end;
    for T in LocalTasks do
    begin
      if Assigned(T) then
        T.Wait(5000);
    end;
  end;
  FreeAndNil(FActiveTasks);
  FreeAndNil(FActiveTasksLock);
  FreeAndNil(FHttpClient);
  FreeAndNil(FCacheLock);
  FreeAndNil(FConfigCache);
  FreeAndNil(FPromptTemplateMgr);
  inherited;
end;

procedure TDeepBaseLLM.RefreshConfigCache;
var
  Storage: ILLMStorage;
  Query: TDataSet;
  Config: TLLMConfig;
  ConfigTable: string;
begin
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  FCacheLock.Enter;
  try
    FConfigCache.Clear;
    ConfigTable := GetLLMConfigTableName(Storage);
    if not DeepBaseTableExists(Storage, ConfigTable) then
      Exit;

    Query := Storage.OpenDataSet(
      Format('SELECT * FROM %s WHERE IsEnabled ' + IfThen(Storage.IsPostgreSQL, '= TRUE', '= 1'), [ConfigTable]),
      []);
    try
      while not Query.Eof do
      begin
        LoadConfigFromQuery(Query, Storage, Config);
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

function TDeepBaseLLM.GetConfig(const AConfigName: string): TLLMConfig;
begin
  Result.Init;
  Result.Name := AConfigName;

  FCacheLock.Enter;
  try
    if FConfigCache.TryGetValue(AConfigName, Result) then
      Exit;
  finally
    FCacheLock.Leave;
  end;

  // BIZ2-002 fix: cache miss path. RefreshConfigCache reloads the full
  // config table from the DB; after it returns we re-check the cache under
  // the lock. This narrows the TOCTOU window from "between any two
  // GetConfig calls" to "only the tiny gap after RefreshConfigCache
  // returns", where the worst case is returning a default Config that
  // self-heals on the next call. The previous code did the same re-check,
  // but the cache was only reloaded under lock; concurrent GetConfig calls
  // could race RefreshConfigCache and read partially populated state.
  RefreshConfigCache;

  FCacheLock.Enter;
  try
    if not FConfigCache.TryGetValue(AConfigName, Result) then
    begin
      // Return default
      Result.Name := AConfigName;
    end;
  finally
    FCacheLock.Leave;
  end;
end;

function TDeepBaseLLM.GetAllConfigs: TLLMConfigArray;
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

procedure TDeepBaseLLM.SaveConfig(const AConfig: TLLMConfig);
var
  Storage: ILLMStorage;
  NowStr: string;
  ConfigTable: string;
  StoredApiKey: string;
  CachedConfig: TLLMConfig;
begin
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);

  ConfigTable := GetLLMConfigTableName(Storage);
  StoredApiKey := PersistLLMApiKey(Storage, ConfigTable, AConfig.Name, AConfig.ApiKey);
  if SameText(ConfigTable, 'LLMConfig') then
  begin
    if Storage.IsPostgreSQL then
      Storage.Execute(
        'INSERT INTO LLMConfig ' +
        '(Name, Description, ProviderCode, ModelId, BaseUrl, ApiKeyRef, MaxTokens, Temperature, ' +
        'SystemPrompt, IsEnabled, IsDefault, UpdatedAt) ' +
        'VALUES (:Name, :Description, :ProviderCode, :ModelId, :BaseUrl, :ApiKeyRef, :MaxTokens, :Temperature, ' +
        ':SystemPrompt, :IsEnabled, :IsDefault, :UpdatedAt) ' +
        'ON CONFLICT (Name) DO UPDATE SET ' +
        'Description=EXCLUDED.Description, ProviderCode=EXCLUDED.ProviderCode, ModelId=EXCLUDED.ModelId, ' +
        'BaseUrl=EXCLUDED.BaseUrl, ApiKeyRef=EXCLUDED.ApiKeyRef, MaxTokens=EXCLUDED.MaxTokens, ' +
        'Temperature=EXCLUDED.Temperature, SystemPrompt=EXCLUDED.SystemPrompt, ' +
        'IsEnabled=EXCLUDED.IsEnabled, IsDefault=EXCLUDED.IsDefault, UpdatedAt=EXCLUDED.UpdatedAt',
        [
          LLMParam('Name', AConfig.Name),
          LLMParam('Description', ''),
          LLMParam('ProviderCode', AConfig.ProviderToStr),
          LLMParam('ModelId', AConfig.Model),
          LLMParam('BaseUrl', AConfig.BaseUrl),
          LLMParam('ApiKeyRef', StoredApiKey),
          LLMParam('MaxTokens', AConfig.MaxTokens),
          LLMParam('Temperature', AConfig.Temperature),
          LLMParam('SystemPrompt', AConfig.SystemPrompt),
          LLMParam('IsEnabled', AConfig.IsEnabled),
          LLMParam('IsDefault', AConfig.IsDefault),
          LLMParam('UpdatedAt', NowStr)
        ])
    else
      Storage.Execute(
        'INSERT OR REPLACE INTO LLMConfig ' +
        '(Name, Description, ProviderCode, ModelId, BaseUrl, ApiKeyRef, MaxTokens, Temperature, ' +
        'SystemPrompt, IsEnabled, IsDefault, UpdatedAt) ' +
        'VALUES (:Name, :Description, :ProviderCode, :ModelId, :BaseUrl, :ApiKeyRef, :MaxTokens, :Temperature, ' +
        ':SystemPrompt, :IsEnabled, :IsDefault, :UpdatedAt)',
        [
          LLMParam('Name', AConfig.Name),
          LLMParam('Description', ''),
          LLMParam('ProviderCode', AConfig.ProviderToStr),
          LLMParam('ModelId', AConfig.Model),
          LLMParam('BaseUrl', AConfig.BaseUrl),
          LLMParam('ApiKeyRef', StoredApiKey),
          LLMParam('MaxTokens', AConfig.MaxTokens),
          LLMParam('Temperature', AConfig.Temperature),
          LLMParam('SystemPrompt', AConfig.SystemPrompt),
          LLMParam('IsEnabled', AConfig.IsEnabled),
          LLMParam('IsDefault', AConfig.IsDefault),
          LLMParam('UpdatedAt', NowStr)
        ]);
  end
  else
  begin
    if Storage.IsPostgreSQL then
      Storage.Execute(
        'INSERT INTO LLMConfiguration ' +
        '(Name, Provider, BaseUrl, ApiKey, Model, MaxTokens, Temperature, ' +
        'SystemPrompt, InputTokenPrice, OutputTokenPrice, IsEnabled, IsDefault, UpdatedAt) ' +
        'VALUES (:Name, :Provider, :BaseUrl, :ApiKey, :Model, :MaxTokens, :Temperature, ' +
        ':SystemPrompt, :InputTokenPrice, :OutputTokenPrice, :IsEnabled, :IsDefault, :UpdatedAt) ' +
        'ON CONFLICT (Name) DO UPDATE SET ' +
        'Provider=EXCLUDED.Provider, BaseUrl=EXCLUDED.BaseUrl, ApiKey=EXCLUDED.ApiKey, ' +
        'Model=EXCLUDED.Model, MaxTokens=EXCLUDED.MaxTokens, Temperature=EXCLUDED.Temperature, ' +
        'SystemPrompt=EXCLUDED.SystemPrompt, InputTokenPrice=EXCLUDED.InputTokenPrice, ' +
        'OutputTokenPrice=EXCLUDED.OutputTokenPrice, IsEnabled=EXCLUDED.IsEnabled, ' +
        'IsDefault=EXCLUDED.IsDefault, UpdatedAt=EXCLUDED.UpdatedAt',
        [
          LLMParam('Name', AConfig.Name),
          LLMParam('Provider', AConfig.ProviderToStr),
          LLMParam('BaseUrl', AConfig.BaseUrl),
          LLMParam('ApiKey', StoredApiKey),
          LLMParam('Model', AConfig.Model),
          LLMParam('MaxTokens', AConfig.MaxTokens),
          LLMParam('Temperature', AConfig.Temperature),
          LLMParam('SystemPrompt', AConfig.SystemPrompt),
          LLMParam('InputTokenPrice', AConfig.InputTokenPrice),
          LLMParam('OutputTokenPrice', AConfig.OutputTokenPrice),
          LLMParam('IsEnabled', AConfig.IsEnabled),
          LLMParam('IsDefault', AConfig.IsDefault),
          LLMParam('UpdatedAt', NowStr)
        ])
    else
      Storage.Execute(
        'INSERT OR REPLACE INTO LLMConfiguration ' +
        '(Name, Provider, BaseUrl, ApiKey, Model, MaxTokens, Temperature, ' +
        'SystemPrompt, InputTokenPrice, OutputTokenPrice, IsEnabled, IsDefault, UpdatedAt) ' +
        'VALUES (:Name, :Provider, :BaseUrl, :ApiKey, :Model, :MaxTokens, :Temperature, ' +
        ':SystemPrompt, :InputTokenPrice, :OutputTokenPrice, :IsEnabled, :IsDefault, :UpdatedAt)',
        [
          LLMParam('Name', AConfig.Name),
          LLMParam('Provider', AConfig.ProviderToStr),
          LLMParam('BaseUrl', AConfig.BaseUrl),
          LLMParam('ApiKey', StoredApiKey),
          LLMParam('Model', AConfig.Model),
          LLMParam('MaxTokens', AConfig.MaxTokens),
          LLMParam('Temperature', AConfig.Temperature),
          LLMParam('SystemPrompt', AConfig.SystemPrompt),
          LLMParam('InputTokenPrice', AConfig.InputTokenPrice),
          LLMParam('OutputTokenPrice', AConfig.OutputTokenPrice),
          LLMParam('IsEnabled', AConfig.IsEnabled),
          LLMParam('IsDefault', AConfig.IsDefault),
          LLMParam('UpdatedAt', NowStr)
        ]);
  end;

  CachedConfig := AConfig;
  CachedConfig.ApiKey := ResolveLLMApiKey(Storage, AConfig.Name, StoredApiKey);

  // Update cache
  FCacheLock.Enter;
  try
    FConfigCache.AddOrSetValue(AConfig.Name, CachedConfig);
  finally
    FCacheLock.Leave;
  end;
end;

procedure TDeepBaseLLM.DeleteConfig(const AConfigName: string);
var
  Storage: ILLMStorage;
  ConfigTable: string;
  StoredApiKey: string;
begin
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  ConfigTable := GetLLMConfigTableName(Storage);
  StoredApiKey := ReadStoredApiKeyRefFromConfig(Storage, ConfigTable, AConfigName);
  DeleteLLMCredentialRef(StoredApiKey);
  DeleteLLMCredentialRef(BuildLLMCredentialRef(MakeLLMApiKeyCredentialTarget(AConfigName)));

  Storage.Execute(
    Format('DELETE FROM %s WHERE Name = :Name', [ConfigTable]),
    [LLMParam('Name', AConfigName)]);

  FCacheLock.Enter;
  try
    FConfigCache.Remove(AConfigName);
  finally
    FCacheLock.Leave;
  end;
end;

function TDeepBaseLLM.TestConnection(const AConfigName: string; out DurationMs: Int64; out ErrorMsg: string): Boolean;
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

function TDeepBaseLLM.DoHttpRequest(const Url, Body: string; const Config: TLLMConfig;
  out Response: string; out DurationMs: Int64): Boolean;
var
  HttpResponse: IHTTPResponse;
  RequestContent: TStringStream;
  StartTime: TDateTime;
  Headers: TArray<TNameValuePair>;
  PairHeaders: TArray<TPair<string, string>>;
begin
  Result := False;
  Response := '';
  StartTime := Now;

  // Build headers based on provider
  case Config.Provider of
    lpAnthropic:
      begin
        Headers := [
          TNameValuePair.Create('Content-Type', 'application/json'),
          TNameValuePair.Create('x-api-key', Config.ApiKey),
          TNameValuePair.Create('anthropic-version', '2023-06-01')
        ];
        PairHeaders := [
          TPair<string, string>.Create('Content-Type', 'application/json'),
          TPair<string, string>.Create('x-api-key', Config.ApiKey),
          TPair<string, string>.Create('anthropic-version', '2023-06-01')
        ];
      end;
  else
    begin
      Headers := [
        TNameValuePair.Create('Content-Type', 'application/json'),
        TNameValuePair.Create('Authorization', 'Bearer ' + Config.ApiKey)
      ];
      PairHeaders := [
        TPair<string, string>.Create('Content-Type', 'application/json'),
        TPair<string, string>.Create('Authorization', 'Bearer ' + Config.ApiKey)
      ];
    end;
  end;

  // Use injected transport when available
  if Assigned(FHttpTransport) then
  begin
    try
      Result := FHttpTransport(Url, Body, PairHeaders, Response, FDefaultTimeout);
      DurationMs := MilliSecondsBetween(Now, StartTime);
    except
      on E: Exception do
      begin
        DurationMs := MilliSecondsBetween(Now, StartTime);
        Response := '{"error": {"message": "' + StringReplace(E.Message, '"', '\"', [rfReplaceAll]) + '"}}';
        Result := False;
      end;
    end;
    Exit;
  end;

  // Fallback: built-in TNetHTTPClient
  RequestContent := TStringStream.Create(Body, TEncoding.UTF8);
  try
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

function TDeepBaseLLM.EstimateCost(const Config: TLLMConfig; InputTokens, OutputTokens: Integer): Double;
begin
  Result := (InputTokens / 1000.0 * Config.InputTokenPrice) +
            (OutputTokens / 1000.0 * Config.OutputTokenPrice);
end;

procedure TDeepBaseLLM.RecordCall(const Config: TLLMConfig; const Prompt: string;
  const Response: TLLMChatResponse; const CallerModule, CallerFunc: string);
var
  Storage: ILLMStorage;
  Cost: Double;
  NowStr: string;
begin
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  Cost := EstimateCost(Config, Response.InputTokens, Response.OutputTokens);
  NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);

  if DeepBaseTableHasColumn(Storage, 'LLMCalls', 'ProviderCode') then
  begin
    Storage.Execute(
      'INSERT INTO LLMCalls (ConfigName, ProviderCode, ModelId, SystemPrompt, UserPrompt, AssistantResponse, ' +
      'FinishReason, InputTokens, OutputTokens, TotalTokens, EstimatedCost, DurationMs, ' +
      'Success, ErrorCode, ErrorMessage, CallerModule, CallerFunction, CallTime) ' +
      'VALUES (:ConfigName, :Provider, :Model, :SystemPrompt, :Prompt, :Response, ' +
      ':FinishReason, :InputTokens, :OutputTokens, :TotalTokens, :EstimatedCost, :DurationMs, ' +
      ':Success, :ErrorCode, :ErrorMessage, :CallerModule, :CallerFunction, :CallTime)',
      [
        LLMParam('ConfigName', Config.Name),
        LLMParam('Provider', Config.ProviderToStr),
        LLMParam('Model', Config.Model),
        LLMParam('SystemPrompt', Config.SystemPrompt),
        LLMParam('Prompt', Prompt),
        LLMParam('Response', Response.Content),
        LLMParam('FinishReason', Response.FinishReason),
        LLMParam('InputTokens', Response.InputTokens),
        LLMParam('OutputTokens', Response.OutputTokens),
        LLMParam('TotalTokens', Response.TotalTokens),
        LLMParam('EstimatedCost', Cost),
        LLMParam('DurationMs', Response.DurationMs),
        LLMParam('Success', Response.Success),
        LLMParam('ErrorCode', Response.ErrorCode),
        LLMParam('ErrorMessage', Response.ErrorMessage),
        LLMParam('CallerModule', CallerModule),
        LLMParam('CallerFunction', CallerFunc),
        LLMParam('CallTime', NowStr)
      ]);
  end
  else
  begin
    Storage.Execute(
      'INSERT INTO LLMCalls (ConfigName, Provider, Model, Prompt, Response, ' +
      'InputTokens, OutputTokens, TotalTokens, EstimatedCost, DurationMs, ' +
      'Success, ErrorCode, ErrorMessage, FinishReason, CallerModule, CallerFunction, CallTime) ' +
      'VALUES (:ConfigName, :Provider, :Model, :Prompt, :Response, ' +
      ':InputTokens, :OutputTokens, :TotalTokens, :EstimatedCost, :DurationMs, ' +
      ':Success, :ErrorCode, :ErrorMessage, :FinishReason, :CallerModule, :CallerFunction, :CallTime)',
      [
        LLMParam('ConfigName', Config.Name),
        LLMParam('Provider', Config.ProviderToStr),
        LLMParam('Model', Config.Model),
        LLMParam('Prompt', Prompt),
        LLMParam('Response', Response.Content),
        LLMParam('InputTokens', Response.InputTokens),
        LLMParam('OutputTokens', Response.OutputTokens),
        LLMParam('TotalTokens', Response.TotalTokens),
        LLMParam('EstimatedCost', Cost),
        LLMParam('DurationMs', Response.DurationMs),
        LLMParam('Success', Response.Success),
        LLMParam('ErrorCode', Response.ErrorCode),
        LLMParam('ErrorMessage', Response.ErrorMessage),
        LLMParam('FinishReason', Response.FinishReason),
        LLMParam('CallerModule', CallerModule),
        LLMParam('CallerFunction', CallerFunc),
        LLMParam('CallTime', NowStr)
      ]);
  end;
end;

function TDeepBaseLLM.Chat(const Prompt: string; out Response: string; const ConfigName: string): Boolean;
var
  ChatResponse: TLLMChatResponse;
begin
  Result := Chat(Prompt, ChatResponse, ConfigName);
  Response := ChatResponse.Content;
end;

function TDeepBaseLLM.Chat(const Prompt: string; out Response: TLLMChatResponse; const ConfigName: string): Boolean;
var
  Messages: TLLMMessages;
begin
  SetLength(Messages, 1);
  Messages[0] := TLLMMessage.User(Prompt);
  Result := ChatWithMessages(Messages, Response, ConfigName);
end;

function TDeepBaseLLM.ChatWithMessages(const Messages: TLLMMessages; out Response: TLLMChatResponse;
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
      RequestBody := BuildOpenAIRequestBody(Config, Messages);
    end;
  else
    begin
      Endpoint := BaseUrl + '/chat/completions';
      RequestBody := BuildOpenAIRequestBody(Config, Messages);
    end;
  end;

  // Execute request
  Result := DoHttpRequest(Endpoint, RequestBody, Config, HttpResponse, Response.DurationMs);

  // BIZ-R3-005: only parse response if HTTP request succeeded. Otherwise the
  // ParseXxxResponse call would overwrite the False result from DoHttpRequest
  // with its own parse result — if the error response body happens to contain
  // parseable JSON with "choices", it could be misjudged as Success=True,
  // silently discarding the actual HTTP error.
  if Result then
  begin
    // Parse response
    if Config.Provider = lpAnthropic then
      Result := ParseAnthropicResponse(HttpResponse, Response)
    else
      Result := ParseOpenAIResponse(HttpResponse, Response);
  end
  else
  begin
    // HTTP request failed — record the error body for diagnostics
    Response.ErrorMessage := 'HTTP request failed: ' + HttpResponse;
  end;

  // Record call
  if Length(Messages) > 0 then
    RecordCall(Config, Messages[High(Messages)].Content, Response, '', '');
end;

function TDeepBaseLLM.ChatAsync(const Prompt: string; OnComplete: TLLMCompleteEvent; const ConfigName: string): ITask;
var
  LTask: ITask;
begin
  // BIZ2-001 fix: register the task with FActiveTasks so Destroy can wait for
  // it before freeing FHttpClient/FConfigCache. Without this, ChatAsync could
  // be in flight when the instance is freed, and the queued OnComplete
  // callback would dereference a dangling Self.
  LTask := TTask.Run(
    procedure
    var
      Response: TLLMChatResponse;
      Success: Boolean;
    begin
      try
        Success := Chat(Prompt, Response, ConfigName);

        TThread.Queue(nil,
          procedure
          begin
            if Assigned(OnComplete) then
              OnComplete(Self, Success, Response.Content, Response.ErrorMessage);
          end);
      finally
        // Always remove ourselves from the active-tasks list so Destroy
        // doesn't wait on a finished task, and so the ITask reference held
        // by the list is released.
        FActiveTasksLock.Enter;
        try
          FActiveTasks.Remove(LTask);
        finally
          FActiveTasksLock.Leave;
        end;
      end;
    end);
  FActiveTasksLock.Enter;
  try
    FActiveTasks.Add(LTask);
  finally
    FActiveTasksLock.Leave;
  end;
  Result := LTask;
end;

// ----------------------------------------------------------------------------
// BUG EXP-P1-002: This method is declared as streaming but the current
// implementation synchronously invokes `Chat` and then emits the full content
// as a single OnChunk callback. True token-by-token streaming requires an
// SSE-aware HTTP path that the Core layer does not yet provide; callers that
// need genuine streaming should use L3 ProxyLLMClient.ChatStream instead.
// ----------------------------------------------------------------------------
function TDeepBaseLLM.ChatStream(const Prompt: string; OnChunk: TLLMStreamCallback; const ConfigName: string): Boolean;
var
  Response: TLLMChatResponse;
begin
  // Synchronous fallback — see class-level doc comment for migration guidance.
  Response.Init;
  Result := Chat(Prompt, Response, ConfigName);

  if Assigned(OnChunk) then
  begin
    if Result then
      OnChunk(Response.Content, True)
    else
      OnChunk(Response.ErrorMessage, True);
  end;
end;

function TDeepBaseLLM.GetTemplate(const TemplateName: string): TLLMPromptTemplate;
begin
  Result := FPromptTemplateMgr.GetTemplate(TemplateName);
end;

function TDeepBaseLLM.GetAllTemplates: TLLMPromptTemplateArray;
begin
  Result := FPromptTemplateMgr.GetAllTemplates;
end;

function TDeepBaseLLM.GetTemplatesByCategory(const Category: string): TLLMPromptTemplateArray;
begin
  Result := FPromptTemplateMgr.GetTemplatesByCategory(Category);
end;

function TDeepBaseLLM.ExecuteTemplate(const TemplateName: string;
  const Variables: TDictionary<string, string>; out Response: string): Boolean;
var
  Template: TLLMPromptTemplate;
  Config: TLLMConfig;
  Prompt: string;
  ChatResponse: TLLMChatResponse;
begin
  Response := '';

  Template := FPromptTemplateMgr.GetTemplate(TemplateName);
  try
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
  finally
    Template.Clear;
  end;
end;

function TDeepBaseLLM.GetCallHistory(ALimit: Integer; const ConfigName: string): TLLMCallRecordArray;
var
  Storage: ILLMStorage;
  Query: TDataSet;
  List: TList<TLLMCallRecord>;
  Rec: TLLMCallRecord;
begin
  SetLength(Result, 0);

  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  List := TList<TLLMCallRecord>.Create;
  try
    if ConfigName <> '' then
      Query := Storage.OpenDataSet(
        GetLLMCallsSelectSQL(Storage, ConfigName),
        [LLMParam('ConfigName', ConfigName), LLMParam('Limit', ALimit)])
    else
      Query := Storage.OpenDataSet(
        GetLLMCallsSelectSQL(Storage, ''),
        [LLMParam('Limit', ALimit)]);
    try
      while not Query.Eof do
      begin
        Rec.Id := QueryFieldInteger(Query, 'Id');
        Rec.ConfigName := QueryFieldString(Query, 'ConfigName');
        Rec.Provider := QueryFieldString(Query, 'Provider');
        Rec.Model := QueryFieldString(Query, 'Model');
        Rec.Prompt := QueryFieldString(Query, 'Prompt');
        Rec.Response := QueryFieldString(Query, 'Response');
        Rec.InputTokens := QueryFieldInteger(Query, 'InputTokens');
        Rec.OutputTokens := QueryFieldInteger(Query, 'OutputTokens');
        Rec.TotalTokens := QueryFieldInteger(Query, 'TotalTokens');
        Rec.EstimatedCost := QueryFieldFloat(Query, 'EstimatedCost');
        Rec.DurationMs := QueryFieldInteger(Query, 'DurationMs');
        Rec.Success := QueryFieldBoolean(Query, 'Success', Rec.Success);
        Rec.ErrorCode := QueryFieldString(Query, 'ErrorCode');
        Rec.ErrorMessage := QueryFieldString(Query, 'ErrorMessage');
        Rec.CallTime := QueryFieldDateTime(Query, 'CallTime');

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

procedure TDeepBaseLLM.GetUsageStats(const ConfigName: string; DaysBack: Integer;
  out TotalCalls: Integer; out TotalTokens: Integer; out TotalCost: Double);
var
  Storage: ILLMStorage;
  Query: TDataSet;
  CutoffDate: string;
begin
  TotalCalls := 0;
  TotalTokens := 0;
  TotalCost := 0;

  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  // 使用参数化格式避免 FireDAC 解析 datetime('now')
  CutoffDate := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now - DaysBack);

  if ConfigName <> '' then
    Query := Storage.OpenDataSet(
      'SELECT COUNT(*) AS Calls, COALESCE(SUM(TotalTokens), 0) AS Tokens, ' +
      'COALESCE(SUM(EstimatedCost), 0) AS Cost FROM LLMCalls ' +
      'WHERE ConfigName = :ConfigName AND CallTime >= :CutoffDate',
      [LLMParam('ConfigName', ConfigName), LLMParam('CutoffDate', CutoffDate)])
  else
    Query := Storage.OpenDataSet(
      'SELECT COUNT(*) AS Calls, COALESCE(SUM(TotalTokens), 0) AS Tokens, ' +
      'COALESCE(SUM(EstimatedCost), 0) AS Cost FROM LLMCalls ' +
      'WHERE CallTime >= :CutoffDate',
      [LLMParam('CutoffDate', CutoffDate)]);
  try
    TotalCalls := Query.FieldByName('Calls').AsInteger;
    TotalTokens := Query.FieldByName('Tokens').AsInteger;
    TotalCost := Query.FieldByName('Cost').AsFloat;
  finally
    Query.Free;
  end;
end;

procedure TDeepBaseLLM.ClearOldCalls(DaysToKeep: Integer);
var
  Storage: ILLMStorage;
  CutoffDate: string;
begin
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  if DaysToKeep <= 0 then
    Storage.Execute('DELETE FROM LLMCalls', [])
  else
  begin
    // 使用参数化格式避免 FireDAC 解析 datetime('now')
    CutoffDate := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now - DaysToKeep);
    Storage.Execute(
      'DELETE FROM LLMCalls WHERE CallTime < :CutoffDate',
      [LLMParam('CutoffDate', CutoffDate)]);
  end;
end;

{ Template CRUD Methods }

procedure TDeepBaseLLM.SaveTemplate(const Template: TLLMPromptTemplate);
begin
  FPromptTemplateMgr.SaveTemplate(Template);
end;

procedure TDeepBaseLLM.DeleteTemplate(const TemplateName: string);
begin
  FPromptTemplateMgr.DeleteTemplate(TemplateName);
end;

function TDeepBaseLLM.CopyTemplate(const SourceName, NewName: string): Boolean;
begin
  Result := FPromptTemplateMgr.CopyTemplate(SourceName, NewName);
end;

function TDeepBaseLLM.ValidateTemplate(const Template: TLLMPromptTemplate): TTemplateValidation;
begin
  Result := FPromptTemplateMgr.ValidateTemplate(Template);
end;

function TDeepBaseLLM.RenderWithInheritance(const TemplateName: string;
  const Variables: TDictionary<string, string>): string;
begin
  Result := FPromptTemplateMgr.RenderWithInheritance(TemplateName, Variables);
end;

function TDeepBaseLLM.ExportTemplates: string;
begin
  Result := FPromptTemplateMgr.ExportTemplates;
end;

function TDeepBaseLLM.ImportTemplates(const Json: string; OverwriteExisting: Boolean): Integer;
begin
  Result := FPromptTemplateMgr.ImportTemplates(Json, OverwriteExisting);
end;

end.
