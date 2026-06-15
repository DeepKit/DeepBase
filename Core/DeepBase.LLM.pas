{ ============================================================================
  DeepBase.LLM - LLM Integration Module
  
  Version: 1.0
  Description: Provides unified LLM API integration with multiple providers
  Features:
    - Multiple providers: OpenAI, Anthropic, Azure, LiteLLM, Ollama, Custom
    - Configuration management via database
    - Async and sync chat methods
    - Call hiDeepStory tracking and cost estimation
    - Prompt template support
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
  DeepBase.Types;

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
    ApiKey: string;         // Runtime API key; persisted as a Credential Manager reference
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
  /// Callback for HTTP POST requests. Injected to replace the built-in
  /// TNetHTTPClient with a custom transport (e.g. IDeepBaseHttpTransport).
  /// AHeaders are name=value pairs. Returns True on HTTP 2xx.
  /// </summary>
  TLLMHttpPostProc = reference to function(const AUrl, ABody: string;
    const AHeaders: TArray<TPair<string, string>>;
    out AResponse: string; ATimeoutMs: Integer): Boolean;

  /// <summary>
  /// LLM Call record for hiDeepStory
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
  /// LLM Request options for provider calls
  /// </summary>
  TLLMRequestOptions = record
    Model: string;
    MaxTokens: Integer;
    Temperature: Double;
    TopP: Double;
    Stop: TArray<string>;
    Stream: Boolean;
    
    class function Default: TLLMRequestOptions; static;
    class function FromConfig(const AConfig: TLLMConfig): TLLMRequestOptions; static;
  end;

  /// <summary>
  /// Unified LLM Provider interface for extensibility
  /// Allows custom providers to be registered without modifying core code
  /// </summary>
  ILLMProvider = interface
    ['{A1B2C3D4-E5F6-4789-8901-ABCDEF012345}']
    /// <summary>Get provider display name (e.g., 'OpenAI', 'Claude')</summary>
    function GetName: string;
    /// <summary>Get list of available models</summary>
    function GetModels: TArray<string>;
    /// <summary>Execute chat completion</summary>
    function Chat(const AMessages: TLLMMessages; const AOptions: TLLMRequestOptions): TLLMChatResponse;
    /// <summary>Check if provider is available (API key set, server reachable)</summary>
    function IsAvailable: Boolean;
    
    property Name: string read GetName;
    property Models: TArray<string> read GetModels;
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
    procedure Clear;
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

  TDeepBaseLLM = class;

  /// <summary>
  /// Streaming chunk callback
  /// </summary>
  TLLMStreamCallback = reference to procedure(const Chunk: string; IsDone: Boolean);

  /// <summary>
  /// Named SQL parameter for LLM storage operations.
  /// </summary>
  TLLMStorageParam = record
    Name: string;
    Value: Variant;
    class function Create(const AName: string;
      const AValue: Variant): TLLMStorageParam; static;
  end;
  TLLMStorageParams = TArray<TLLMStorageParam>;

  /// <summary>
  /// Abstract storage contract for LLM module (ARCH-039).
  /// FireDAC implementation should live in Persistence/.
  /// </summary>
  ILLMStorage = interface
    ['{63C2F028-8E99-41C2-83E8-8F5316A6B03E}']
    function IsConnected: Boolean;
    function TableExists(const TableName: string): Boolean;
    function TableHasColumn(const TableName, ColumnName: string): Boolean;
    function OpenDataSet(const SQL: string;
      const Params: array of TLLMStorageParam): TDataSet;
    function Execute(const SQL: string;
      const Params: array of TLLMStorageParam): Integer;
    function ExecuteScalar(const SQL: string;
      const Params: array of TLLMStorageParam): Variant;
    function IsPostgreSQL: Boolean;
  end;

  /// <summary>
  /// DeepBase LLM Manager Class
  /// </summary>
  TDeepBaseLLM = class
  private
    FConnection: TObject;
    FStorage: ILLMStorage;
    FConfigCache: TDictionary<string, TLLMConfig>;
    FCacheLock: TCriticalSection;
    FHttpClient: TNetHTTPClient;
    FHttpTransport: TLLMHttpPostProc;
    FDefaultTimeout: Integer;
    class var FConnectionStorageFactory: TFunc<TObject, ILLMStorage>;

    class function CreateStorageFromConnection(
      AConnection: TObject): ILLMStorage; static;
    function GetStorage: ILLMStorage;
    function GetDefaultBaseUrl(Provider: TLLMProvider): string;
    function BuildRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
    function BuildAnthropicRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
    function ParseOpenAIResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
    function ParseAnthropicResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
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
  System.Variants,
  System.NetEncoding,
  System.RegularExpressions,
  System.StrUtils
  {$IFDEF MSWINDOWS}
  , DeepBase.Security.DPAPI
  {$ENDIF};

const
  DEFAULT_TIMEOUT = 60000; // 60 seconds
  TEST_PROMPT = 'Reply with exactly: OK';
  LLM_CREDENTIAL_REF_PREFIX = 'credman:';
  LLM_CREDENTIAL_TARGET_PREFIX = 'DeepBase_LLM_';
  LLM_CREDENTIAL_TARGET_SUFFIX = '_ApiKey';
  
  URL_OPENAI = 'https://api.openai.com/v1';
  URL_ANTHROPIC = 'https://api.anthropic.com/v1';

{ Helper Functions }

class function TLLMStorageParam.Create(const AName: string;
  const AValue: Variant): TLLMStorageParam;
begin
  Result.Name := AName;
  Result.Value := AValue;
end;

function LLMParam(const AName: string; const AValue: Variant): TLLMStorageParam;
begin
  Result := TLLMStorageParam.Create(AName, AValue);
end;

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

function DeepBaseTableExists(const Storage: ILLMStorage;
  const TableName: string): Boolean;
begin
  Result := Assigned(Storage) and Storage.TableExists(TableName);
end;

function DeepBaseTableHasColumn(const Storage: ILLMStorage;
  const TableName, ColumnName: string): Boolean;
begin
  Result := Assigned(Storage) and Storage.TableHasColumn(TableName, ColumnName);
end;

function QueryFieldString(Query: TDataSet; const FieldName: string; const DefaultValue: string = ''): string;
var
  Field: TField;
begin
  Result := DefaultValue;
  Field := Query.FindField(FieldName);
  if Assigned(Field) and not Field.IsNull then
    Result := Field.AsString;
end;

function QueryFieldInteger(Query: TDataSet; const FieldName: string; DefaultValue: Integer = 0): Integer;
var
  Field: TField;
begin
  Result := DefaultValue;
  Field := Query.FindField(FieldName);
  if Assigned(Field) and not Field.IsNull then
    Result := Field.AsInteger;
end;

function QueryFieldBoolean(Query: TDataSet; const FieldName: string; DefaultValue: Boolean = False): Boolean;
var
  Field: TField;
  Value: string;
begin
  Result := DefaultValue;
  Field := Query.FindField(FieldName);
  if not Assigned(Field) or Field.IsNull then
    Exit;

  try
    Result := Field.AsBoolean;
    Exit;
  except
    // Some SQLite/FireDAC field mappings reject AsBoolean for INTEGER/TEXT.
  end;

  try
    Result := Field.AsInteger <> 0;
    Exit;
  except
    Value := Trim(Field.AsString);
  end;

  Result := SameText(Value, 'true') or SameText(Value, 'yes') or
    SameText(Value, 'y') or SameText(Value, 'on') or (Value = '1');
end;

function QueryFieldFloat(Query: TDataSet; const FieldName: string; DefaultValue: Double = 0): Double;
var
  Field: TField;
begin
  Result := DefaultValue;
  Field := Query.FindField(FieldName);
  if Assigned(Field) and not Field.IsNull then
    Result := Field.AsFloat;
end;

function QueryFieldDateTime(Query: TDataSet; const FieldName: string): TDateTime;
var
  Field: TField;
begin
  Result := 0;
  Field := Query.FindField(FieldName);
  if Assigned(Field) and not Field.IsNull then
  begin
    try
      Result := Field.AsDateTime;
    except
      Result := 0;
    end;
  end;
end;

function GetLLMConfigTableName(const Storage: ILLMStorage): string;
begin
  if DeepBaseTableExists(Storage, 'LLMConfig') then
    Result := 'LLMConfig'
  else if DeepBaseTableExists(Storage, 'LLMConfiguration') then
    Result := 'LLMConfiguration'
  else
    Result := 'LLMConfig';
end;

function GetLLMCallsSelectSQL(const Storage: ILLMStorage; const ConfigName: string): string;
var
  HasCanonicalProvider: Boolean;
begin
  HasCanonicalProvider := DeepBaseTableHasColumn(Storage, 'LLMCalls', 'ProviderCode');
  if HasCanonicalProvider then
  begin
    Result :=
      'SELECT Id, ConfigName, ProviderCode AS Provider, ModelId AS Model, ' +
      'UserPrompt AS Prompt, AssistantResponse AS Response, InputTokens, OutputTokens, ' +
      'TotalTokens, EstimatedCost, DurationMs, Success, ErrorCode, ErrorMessage, CallTime ' +
      'FROM LLMCalls';
  end
  else
  begin
    Result :=
      'SELECT Id, ConfigName, Provider, Model, Prompt, Response, InputTokens, OutputTokens, ' +
      'TotalTokens, EstimatedCost, DurationMs, Success, ErrorCode, ErrorMessage, CallTime ' +
      'FROM LLMCalls';
  end;

  if ConfigName <> '' then
    Result := Result + ' WHERE ConfigName = :ConfigName';
  Result := Result + ' ORDER BY CallTime DESC LIMIT :Limit';
end;

function IsLLMCredentialRef(const Value: string): Boolean;
begin
  Result := StartsText(LLM_CREDENTIAL_REF_PREFIX, Trim(Value));
end;

function ExtractLLMCredentialTarget(const CredentialRef: string): string;
begin
  Result := '';
  if IsLLMCredentialRef(CredentialRef) then
    Result := Copy(Trim(CredentialRef), Length(LLM_CREDENTIAL_REF_PREFIX) + 1, MaxInt);
end;

function BuildLLMCredentialRef(const TargetName: string): string;
begin
  if TargetName = '' then
    Result := ''
  else
    Result := LLM_CREDENTIAL_REF_PREFIX + TargetName;
end;

function SanitizeCredentialTargetPart(const Value: string): string;
const
  INVALID_TARGET_CHARS: array[0..8] of Char = ('\', '/', ':', '*', '?', '"', '<', '>', '|');
var
  C: Char;
begin
  Result := Trim(Value);
  for C in INVALID_TARGET_CHARS do
    Result := StringReplace(Result, string(C), '_', [rfReplaceAll]);
  if Result = '' then
    Result := 'Default';
end;

function MakeLLMApiKeyCredentialTarget(const ConfigName: string): string;
begin
  Result := LLM_CREDENTIAL_TARGET_PREFIX +
    SanitizeCredentialTargetPart(ConfigName) +
    LLM_CREDENTIAL_TARGET_SUFFIX;
end;

function ResolveLLMCredentialOrRaw(const StoredValue: string): string;
var
  TargetName: string;
begin
  Result := StoredValue;
  TargetName := ExtractLLMCredentialTarget(StoredValue);
  if TargetName = '' then
    Exit;

  {$IFDEF MSWINDOWS}
  Result := TCredentialManager.GetCredential(TargetName, '');
  {$ELSE}
  Result := '';
  {$ENDIF}
end;

procedure DeleteLLMCredentialRef(const StoredValue: string);
var
  TargetName: string;
begin
  TargetName := ExtractLLMCredentialTarget(StoredValue);
  if TargetName = '' then
    Exit;

  {$IFDEF MSWINDOWS}
  TCredentialManager.DeleteCredential(TargetName);
  {$ENDIF}
end;

function TryLoadLLMApiKeyByName(const Storage: ILLMStorage; const ApiKeyName: string;
  out ApiKey: string): Boolean;
var
  Query: TDataSet;
  StoredApiKey: string;
begin
  Result := False;
  ApiKey := '';
  if (ApiKeyName = '') or not Assigned(Storage) or not Storage.IsConnected or
    not DeepBaseTableExists(Storage, 'LLMApiKeys') then
    Exit;

  Query := Storage.OpenDataSet(
    'SELECT ApiKey FROM LLMApiKeys ' +
    'WHERE Name = :Name AND IsEnabled ' + IfThen(Storage.IsPostgreSQL, '= TRUE', '= 1') + ' ' +
    'ORDER BY IsDefault DESC, Id LIMIT 1',
    [LLMParam('Name', ApiKeyName)]);
  try
    if not Query.Eof then
    begin
      StoredApiKey := QueryFieldString(Query, 'ApiKey', '');
      ApiKey := ResolveLLMCredentialOrRaw(StoredApiKey);
      Result := True;
    end;
  finally
    Query.Free;
  end;
end;

function ResolveLLMApiKey(const Storage: ILLMStorage; const ConfigName,
  StoredValue: string): string;
begin
  Result := '';
  if StoredValue = '' then
    Exit;

  if IsLLMCredentialRef(StoredValue) then
    Exit(ResolveLLMCredentialOrRaw(StoredValue));

  if TryLoadLLMApiKeyByName(Storage, StoredValue, Result) then
    Exit;

  // Backward compatibility: older databases wrote the real key directly into
  // LLMConfig.ApiKeyRef or LLMConfiguration.ApiKey.
  Result := StoredValue;
end;

function ReadStoredApiKeyRefFromConfig(const Storage: ILLMStorage;
  const ConfigTable, ConfigName: string): string;
var
  Query: TDataSet;
begin
  Result := '';
  if not Assigned(Storage) or not Storage.IsConnected or
    not DeepBaseTableExists(Storage, ConfigTable) then
    Exit;

  Query := Storage.OpenDataSet(
    Format('SELECT * FROM %s WHERE Name = :Name', [ConfigTable]),
    [LLMParam('Name', ConfigName)]);
  try
    if not Query.Eof then
      Result := QueryFieldString(Query, 'ApiKeyRef',
        QueryFieldString(Query, 'ApiKey', ''));
  finally
    Query.Free;
  end;
end;

function PersistLLMApiKey(const Storage: ILLMStorage;
  const ConfigTable, ConfigName, ApiKey: string): string;
var
  ExistingRef: string;
  ReferencedApiKey: string;
  TargetName: string;
begin
  ExistingRef := ReadStoredApiKeyRefFromConfig(Storage, ConfigTable, ConfigName);

  if ApiKey = '' then
  begin
    DeleteLLMCredentialRef(ExistingRef);
    DeleteLLMCredentialRef(BuildLLMCredentialRef(MakeLLMApiKeyCredentialTarget(ConfigName)));
    Exit('');
  end;

  if IsLLMCredentialRef(ApiKey) then
    Exit(Trim(ApiKey));

  ReferencedApiKey := '';
  if TryLoadLLMApiKeyByName(Storage, ApiKey, ReferencedApiKey) then
    Exit(ApiKey);

  {$IFDEF MSWINDOWS}
  TargetName := MakeLLMApiKeyCredentialTarget(ConfigName);
  TCredentialManager.SaveCredential(TargetName, '', ApiKey);
  Result := BuildLLMCredentialRef(TargetName);
  if IsLLMCredentialRef(ExistingRef) and
     not SameText(Trim(ExistingRef), Result) then
    DeleteLLMCredentialRef(ExistingRef);
  {$ELSE}
  Result := ApiKey;
  {$ENDIF}
end;

procedure LoadConfigFromQuery(Query: TDataSet; const Storage: ILLMStorage;
  var Config: TLLMConfig);
var
  InputPricePer1M: Double;
  OutputPricePer1M: Double;
  StoredApiKey: string;
begin
  Config.Init;
  Config.Name := QueryFieldString(Query, 'Name', Config.Name);
  Config.Provider := TLLMConfig.StrToProvider(
    QueryFieldString(Query, 'ProviderCode',
      QueryFieldString(Query, 'Provider', Config.ProviderToStr)));
  Config.BaseUrl := QueryFieldString(Query, 'BaseUrl',
    QueryFieldString(Query, 'ApiUrl', Config.BaseUrl));
  StoredApiKey := QueryFieldString(Query, 'ApiKeyRef',
    QueryFieldString(Query, 'ApiKey', Config.ApiKey));
  Config.ApiKey := ResolveLLMApiKey(Storage, Config.Name, StoredApiKey);
  Config.Model := QueryFieldString(Query, 'ModelId',
    QueryFieldString(Query, 'Model', Config.Model));
  Config.MaxTokens := QueryFieldInteger(Query, 'MaxTokens', Config.MaxTokens);
  Config.Temperature := QueryFieldFloat(Query, 'Temperature', Config.Temperature);
  Config.SystemPrompt := QueryFieldString(Query, 'SystemPrompt', Config.SystemPrompt);
  Config.IsEnabled := QueryFieldBoolean(Query, 'IsEnabled', Config.IsEnabled);
  Config.IsDefault := QueryFieldBoolean(Query, 'IsDefault', Config.IsDefault);

  Config.InputTokenPrice := QueryFieldFloat(Query, 'InputTokenPrice', Config.InputTokenPrice);
  Config.OutputTokenPrice := QueryFieldFloat(Query, 'OutputTokenPrice', Config.OutputTokenPrice);

  InputPricePer1M := QueryFieldFloat(Query, 'InputPricePer1M', -1);
  OutputPricePer1M := QueryFieldFloat(Query, 'OutputPricePer1M', -1);
  if InputPricePer1M >= 0 then
    Config.InputTokenPrice := InputPricePer1M / 1000.0;
  if OutputPricePer1M >= 0 then
    Config.OutputTokenPrice := OutputPricePer1M / 1000.0;
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

{ TLLMRequestOptions }

class function TLLMRequestOptions.Default: TLLMRequestOptions;
begin
  Result.Model := '';
  Result.MaxTokens := 4096;
  Result.Temperature := 0.7;
  Result.TopP := 1.0;
  SetLength(Result.Stop, 0);
  Result.Stream := False;
end;

class function TLLMRequestOptions.FromConfig(const AConfig: TLLMConfig): TLLMRequestOptions;
begin
  Result.Model := AConfig.Model;
  Result.MaxTokens := AConfig.MaxTokens;
  Result.Temperature := AConfig.Temperature;
  Result.TopP := 1.0;
  SetLength(Result.Stop, 0);
  Result.Stream := False;
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

procedure TLLMPromptTemplate.Clear;
begin
  if Assigned(DefaultValues) then
    FreeAndNil(DefaultValues);
  Init;
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

{ TDeepBaseLLM }

constructor TDeepBaseLLM.Create(AConnection: TObject);
begin
  Create(CreateStorageFromConnection(AConnection));
  FConnection := AConnection;
end;

constructor TDeepBaseLLM.Create(const AStorage: ILLMStorage);
begin
  inherited Create;
  FConnection := nil;
  FStorage := AStorage;
  FConfigCache := TDictionary<string, TLLMConfig>.Create;
  FCacheLock := TCriticalSection.Create;
  FHttpClient := TNetHTTPClient.Create(nil);
  FHttpClient.ConnectionTimeout := DEFAULT_TIMEOUT;
  FHttpClient.ResponseTimeout := DEFAULT_TIMEOUT;
  FDefaultTimeout := DEFAULT_TIMEOUT;
  
  RefreshConfigCache;
end;

class procedure TDeepBaseLLM.SetStorageFactory(
  const AFactory: TFunc<TObject, ILLMStorage>);
begin
  FConnectionStorageFactory := AFactory;
end;

procedure TDeepBaseLLM.SetHttpTransport(const ATransport: TLLMHttpPostProc);
begin
  FHttpTransport := ATransport;
end;

class function TDeepBaseLLM.CreateStorageFromConnection(
  AConnection: TObject): ILLMStorage;
begin
  Result := nil;
  if Assigned(AConnection) and Supports(AConnection, ILLMStorage, Result) then
    Exit;

  if Assigned(AConnection) and Assigned(FConnectionStorageFactory) then
    Result := FConnectionStorageFactory(AConnection);

  if (Result = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No LLM storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.LLM.FireDAC.');
end;

function TDeepBaseLLM.GetStorage: ILLMStorage;
begin
  Result := FStorage;
end;

destructor TDeepBaseLLM.Destroy;
begin
  FreeAndNil(FHttpClient);
  FreeAndNil(FCacheLock);
  FreeAndNil(FConfigCache);
  inherited;
end;

function TDeepBaseLLM.GetDefaultBaseUrl(Provider: TLLMProvider): string;
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

function TDeepBaseLLM.BuildRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
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

function TDeepBaseLLM.BuildAnthropicRequestBody(const Config: TLLMConfig; const Messages: TLLMMessages): string;
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

function TDeepBaseLLM.ParseOpenAIResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
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

function TDeepBaseLLM.ParseAnthropicResponse(const JsonResponse: string; out Response: TLLMChatResponse): Boolean;
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

function TDeepBaseLLM.ChatAsync(const Prompt: string; OnComplete: TLLMCompleteEvent; const ConfigName: string): ITask;
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

function TDeepBaseLLM.ChatStream(const Prompt: string; OnChunk: TLLMStreamCallback; const ConfigName: string): Boolean;
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

procedure LoadTemplateFromQuery(Query: TDataSet; var Template: TLLMPromptTemplate);
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
  Template.IsEnabled := QueryFieldBoolean(Query, 'IsEnabled', Template.IsEnabled);
  Template.IsBuiltIn := QueryFieldBoolean(Query, 'IsBuiltIn', Template.IsBuiltIn);
  Template.SortOrder := Query.FieldByName('SortOrder').AsInteger;
  
  // Parse Variables JSON array
  VarJson := nil;
  try
    try
      VarJson := TJSONObject.ParseJSONValue(Query.FieldByName('Variables').AsString);
      if VarJson is TJSONArray then
      begin
        SetLength(Template.Variables, TJSONArray(VarJson).Count);
        for I := 0 to TJSONArray(VarJson).Count - 1 do
          Template.Variables[I] := TJSONArray(VarJson).Items[I].Value;
      end;
    except
      SetLength(Template.Variables, 0);
    end;
  finally
    VarJson.Free;
  end;
  
  // Parse DefaultValues JSON object
  DefJson := nil;
  try
    try
      DefJson := TJSONObject.ParseJSONValue(Query.FieldByName('DefaultValues').AsString);
      if DefJson is TJSONObject then
      begin
        Template.DefaultValues := TDictionary<string, string>.Create;
        for Pair in TJSONObject(DefJson) do
          Template.DefaultValues.Add(Pair.JsonString.Value, Pair.JsonValue.Value);
      end;
    except
      FreeAndNil(Template.DefaultValues);
    end;
  finally
    DefJson.Free;
  end;
  
  // Parse IncludeTemplates JSON array
  IncJson := nil;
  try
    try
      IncJson := TJSONObject.ParseJSONValue(Query.FieldByName('IncludeTemplates').AsString);
      if IncJson is TJSONArray then
      begin
        SetLength(Template.IncludeTemplates, TJSONArray(IncJson).Count);
        for I := 0 to TJSONArray(IncJson).Count - 1 do
          Template.IncludeTemplates[I] := TJSONArray(IncJson).Items[I].Value;
      end;
    except
      SetLength(Template.IncludeTemplates, 0);
    end;
  finally
    IncJson.Free;
  end;
end;

function TDeepBaseLLM.GetTemplate(const TemplateName: string): TLLMPromptTemplate;
var
  Storage: ILLMStorage;
  Query: TDataSet;
begin
  Result.Init;
  
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  Query := Storage.OpenDataSet(
    'SELECT * FROM LLMPromptTemplates WHERE Name = :Name AND IsEnabled ' + IfThen(Storage.IsPostgreSQL, '= TRUE', '= 1'),
    [LLMParam('Name', TemplateName)]);
  try
    if not Query.Eof then
      LoadTemplateFromQuery(Query, Result);
  finally
    Query.Free;
  end;
end;

function TDeepBaseLLM.GetAllTemplates: TLLMPromptTemplateArray;
var
  Storage: ILLMStorage;
  Query: TDataSet;
  List: TList<TLLMPromptTemplate>;
  Template: TLLMPromptTemplate;
begin
  SetLength(Result, 0);
  
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;
    
  List := TList<TLLMPromptTemplate>.Create;
  try
    Query := Storage.OpenDataSet(
      'SELECT * FROM LLMPromptTemplates WHERE IsEnabled ' + IfThen(Storage.IsPostgreSQL, '= TRUE', '= 1') + ' ORDER BY SortOrder, Name',
      []);
    try
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

function TDeepBaseLLM.GetTemplatesByCategory(const Category: string): TLLMPromptTemplateArray;
var
  Storage: ILLMStorage;
  Query: TDataSet;
  List: TList<TLLMPromptTemplate>;
  Template: TLLMPromptTemplate;
begin
  SetLength(Result, 0);
  
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;
    
  List := TList<TLLMPromptTemplate>.Create;
  try
    Query := Storage.OpenDataSet(
      'SELECT * FROM LLMPromptTemplates WHERE Category = :Category AND IsEnabled ' + IfThen(Storage.IsPostgreSQL, '= TRUE', '= 1') + ' ORDER BY SortOrder, Name',
      [LLMParam('Category', Category)]);
    try
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

function TDeepBaseLLM.ExecuteTemplate(const TemplateName: string;
  const Variables: TDictionary<string, string>; out Response: string): Boolean;
var
  Template: TLLMPromptTemplate;
  Config: TLLMConfig;
  Prompt: string;
  ChatResponse: TLLMChatResponse;
begin
  Response := '';
  
  Template := GetTemplate(TemplateName);
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
  
  // ʹ�ò�������ʽ���� FireDAC ��� datetime('now')
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
    // ʹ�ò�������ʽ���� FireDAC ��� datetime('now')
    CutoffDate := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now - DaysToKeep);
    Storage.Execute(
      'DELETE FROM LLMCalls WHERE CallTime < :CutoffDate',
      [LLMParam('CutoffDate', CutoffDate)]);
  end;
end;

{ Template CRUD Methods }

procedure TDeepBaseLLM.SaveTemplate(const Template: TLLMPromptTemplate);
var
  Storage: ILLMStorage;
  VarsJson, IncJson: TJSONArray;
  DefsJson: TJSONObject;
  I: Integer;
  Key: string;
  NowStr: string;
  ExistingId: Variant;
begin
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
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

        ExistingId := Storage.ExecuteScalar(
          'SELECT Id FROM LLMPromptTemplates WHERE Name = :Name',
          [LLMParam('Name', Template.Name)]);

        if VarIsNull(ExistingId) then
        begin
          Storage.Execute(
            'INSERT INTO LLMPromptTemplates (Name, Category, Description, SystemPrompt, ' +
            'UserPromptTemplate, Variables, DefaultValues, ParentTemplate, IncludeTemplates, ' +
            'OutputFormat, ValidationRegex, Examples, RecommendedConfig, RecommendedModel, ' +
            'MaxTokens, Temperature, IsEnabled, IsBuiltIn, SortOrder, CreatedAt, UpdatedAt) ' +
            'VALUES (:Name, :Category, :Description, :SystemPrompt, :UserPromptTemplate, ' +
            ':Variables, :DefaultValues, :ParentTemplate, :IncludeTemplates, :OutputFormat, ' +
            ':ValidationRegex, :Examples, :RecommendedConfig, :RecommendedModel, :MaxTokens, ' +
            ':Temperature, :IsEnabled, :IsBuiltIn, :SortOrder, :CreatedAt, :UpdatedAt)',
            [
              LLMParam('Name', Template.Name),
              LLMParam('Category', Template.Category),
              LLMParam('Description', Template.Description),
              LLMParam('SystemPrompt', Template.SystemPrompt),
              LLMParam('UserPromptTemplate', Template.UserPromptTemplate),
              LLMParam('Variables', VarsJson.ToString),
              LLMParam('DefaultValues', DefsJson.ToString),
              LLMParam('ParentTemplate', Template.ParentTemplate),
              LLMParam('IncludeTemplates', IncJson.ToString),
              LLMParam('OutputFormat', Template.OutputFormat),
              LLMParam('ValidationRegex', Template.ValidationRegex),
              LLMParam('Examples', Template.Examples),
              LLMParam('RecommendedConfig', Template.RecommendedConfig),
              LLMParam('RecommendedModel', Template.RecommendedModel),
              LLMParam('MaxTokens', Template.MaxTokens),
              LLMParam('Temperature', Template.Temperature),
              LLMParam('IsEnabled', Template.IsEnabled),
              LLMParam('IsBuiltIn', Template.IsBuiltIn),
              LLMParam('SortOrder', Template.SortOrder),
              LLMParam('CreatedAt', NowStr),
              LLMParam('UpdatedAt', NowStr)
            ]);
        end
        else
        begin
          Storage.Execute(
            'UPDATE LLMPromptTemplates SET Category = :Category, Description = :Description, ' +
            'SystemPrompt = :SystemPrompt, UserPromptTemplate = :UserPromptTemplate, ' +
            'Variables = :Variables, DefaultValues = :DefaultValues, ParentTemplate = :ParentTemplate, ' +
            'IncludeTemplates = :IncludeTemplates, OutputFormat = :OutputFormat, ' +
            'ValidationRegex = :ValidationRegex, Examples = :Examples, ' +
            'RecommendedConfig = :RecommendedConfig, RecommendedModel = :RecommendedModel, ' +
            'MaxTokens = :MaxTokens, Temperature = :Temperature, IsEnabled = :IsEnabled, ' +
            'SortOrder = :SortOrder, UpdatedAt = :UpdatedAt WHERE Name = :Name',
            [
              LLMParam('Name', Template.Name),
              LLMParam('Category', Template.Category),
              LLMParam('Description', Template.Description),
              LLMParam('SystemPrompt', Template.SystemPrompt),
              LLMParam('UserPromptTemplate', Template.UserPromptTemplate),
              LLMParam('Variables', VarsJson.ToString),
              LLMParam('DefaultValues', DefsJson.ToString),
              LLMParam('ParentTemplate', Template.ParentTemplate),
              LLMParam('IncludeTemplates', IncJson.ToString),
              LLMParam('OutputFormat', Template.OutputFormat),
              LLMParam('ValidationRegex', Template.ValidationRegex),
              LLMParam('Examples', Template.Examples),
              LLMParam('RecommendedConfig', Template.RecommendedConfig),
              LLMParam('RecommendedModel', Template.RecommendedModel),
              LLMParam('MaxTokens', Template.MaxTokens),
              LLMParam('Temperature', Template.Temperature),
              LLMParam('IsEnabled', Template.IsEnabled),
              LLMParam('SortOrder', Template.SortOrder),
              LLMParam('UpdatedAt', NowStr)
            ]);
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

procedure TDeepBaseLLM.DeleteTemplate(const TemplateName: string);
var
  Storage: ILLMStorage;
begin
  Storage := GetStorage;
  if not Assigned(Storage) or not Storage.IsConnected then
    Exit;

  Storage.Execute(
    'DELETE FROM LLMPromptTemplates WHERE Name = :Name AND IsBuiltIn ' + IfThen(Storage.IsPostgreSQL, '= FALSE', '= 0'),
    [LLMParam('Name', TemplateName)]);
end;

function TDeepBaseLLM.CopyTemplate(const SourceName, NewName: string): Boolean;
var
  Source: TLLMPromptTemplate;
  NewTemplate: TLLMPromptTemplate;
begin
  Result := False;
  
  Source := GetTemplate(SourceName);
  try
    if Source.Name = '' then
      Exit;
      
    NewTemplate := Source.Clone;
    try
      NewTemplate.Name := NewName;
      NewTemplate.IsBuiltIn := False;
      
      try
        SaveTemplate(NewTemplate);
        Result := True;
      except
        Result := False;
      end;
    finally
      NewTemplate.Clear;
    end;
  finally
    Source.Clear;
  end;
end;

function TDeepBaseLLM.ValidateTemplate(const Template: TLLMPromptTemplate): TTemplateValidation;
var
  VarPattern: string;
  Match: TMatch;
  FoundVars: TList<string>;
  V: string;
  I: Integer;
  Depth: Integer;
  Parent: TLLMPromptTemplate;
  ParentName: string;
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
      ParentName := Template.ParentTemplate;
      while (ParentName <> '') and (Depth < 5) do
      begin
        Parent.Init;
        try
          Parent := GetTemplate(ParentName);
          if Parent.Name = '' then
            Break;
          if Parent.Name = Template.Name then
          begin
            Result.IsValid := False;
            SetLength(Result.Errors, Length(Result.Errors) + 1);
            Result.Errors[High(Result.Errors)] := 'Circular inheritance detected: ' + Template.Name;
            Break;
          end;
          ParentName := Parent.ParentTemplate;
        finally
          Parent.Clear;
        end;
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

function TDeepBaseLLM.RenderWithInheritance(const TemplateName: string;
  const Variables: TDictionary<string, string>): string;
var
  Template, Parent: TLLMPromptTemplate;
  MergedVars: TDictionary<string, string>;
  Depth: Integer;
  Key, Val: string;
  IncludeName, IncludeContent: string;
  IncTemplate: TLLMPromptTemplate;
  ParentName: string;
  I: Integer;
begin
  Result := '';
  
  Template := GetTemplate(TemplateName);
  try
    if Template.Name = '' then
      Exit;
    
    // Merge variables with defaults from inheritance chain
    MergedVars := TDictionary<string, string>.Create;
    try
      // Start with provided variables
      if Assigned(Variables) then
        for Key in Variables.Keys do
          MergedVars.AddOrSetValue(Key, Variables[Key]);
      
      // Add defaults from this template (don't overwrite)
      if Assigned(Template.DefaultValues) then
      begin
        for Key in Template.DefaultValues.Keys do
        begin
          if not MergedVars.ContainsKey(Key) then
            MergedVars.Add(Key, Template.DefaultValues[Key]);
        end;
      end;

      // Walk up inheritance chain and add missing defaults
      Depth := 0;
      ParentName := Template.ParentTemplate;
      while (ParentName <> '') and (Depth < 5) do
      begin
        Parent.Init;
        try
          Parent := GetTemplate(ParentName);
          if Parent.Name = '' then
            Break;

          if Assigned(Parent.DefaultValues) then
          begin
            for Key in Parent.DefaultValues.Keys do
            begin
              if not MergedVars.ContainsKey(Key) then
                MergedVars.Add(Key, Parent.DefaultValues[Key]);
            end;
          end;

          ParentName := Parent.ParentTemplate;
        finally
          Parent.Clear;
        end;
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
        IncTemplate.Init;
        try
          IncTemplate := GetTemplate(IncludeName);
          if IncTemplate.Name <> '' then
          begin
            IncludeContent := RenderWithInheritance(IncludeName, MergedVars);
            Result := StringReplace(Result, '{{include:' + IncludeName + '}}', IncludeContent, [rfReplaceAll]);
          end;
        finally
          IncTemplate.Clear;
        end;
      end;
    finally
      MergedVars.Free;
    end;
  finally
    Template.Clear;
  end;
end;

procedure ClearPromptTemplates(var Templates: TLLMPromptTemplateArray);
var
  I: Integer;
begin
  for I := 0 to High(Templates) do
    Templates[I].Clear;
  SetLength(Templates, 0);
end;

function TDeepBaseLLM.ExportTemplates: string;
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
  try
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
  finally
    ClearPromptTemplates(Templates);
  end;
end;

function TDeepBaseLLM.ImportTemplates(const Json: string; OverwriteExisting: Boolean): Integer;
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
      try
        Template.Name := JsonObj.GetValue<string>('name', '');
        if Template.Name = '' then
          Continue;
        
        // Check if exists
        if not OverwriteExisting then
        begin
          Existing.Init;
          try
            Existing := GetTemplate(Template.Name);
            if Existing.Name <> '' then
              Continue;
          finally
            Existing.Clear;
          end;
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
      finally
        Template.Clear;
      end;
    end;
  finally
    JsonArr.Free;
  end;
end;

end.
