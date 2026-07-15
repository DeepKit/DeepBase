{ ============================================================================
  DeepBase.LLM.Types - Unified LLM Type Definitions

  Contains all type definitions for both the Core (L2) and Proxy (L3)
  LLM architectures:
    - L2/Core: TLLMProvider, TLLMConfig, TLLMMessage, TLLMChatResponse,
               TLLMPromptTemplate, ILLMStorage, etc.
    - L3/Proxy: TModelTier, TChatMessage, TChatResult, TProviderConfig,
                TModelInfo, etc.
  ============================================================================ }

unit DeepBase.LLM.Types;

interface

uses
  System.SysUtils,
  System.Classes,
  System.JSON,
  Data.DB,
  System.Generics.Collections,
  System.DateUtils;

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

/// <summary>Convert provider enum to string</summary>
function LLMProviderToStr(Provider: TLLMProvider): string;

/// <summary>Convert string to provider enum</summary>
function StrToLLMProvider(const S: string): TLLMProvider;

// ============================================================================
// L3/Proxy types — Model tiers, chat messages, provider config
// ============================================================================

type
  // 模型层级 (type string 可扩展，内置五个常量)
  TModelTier = type string;

  TModelTierHelper = record helper for TModelTier
    function DisplayName: string;
  end;

const
  TierSmart          : TModelTier = 'smart';
  TierBalanced       : TModelTier = 'balanced';
  TierFast           : TModelTier = 'fast';
  TierImageGen       : TModelTier = 'image_gen';

  // Backward-compatible alias for older downstream code.
  TierVision         : TModelTier = 'vision';
  TierImageFallback  : TModelTier = 'vision_fallback';
  TierVisionFallback : TModelTier = 'vision_fallback';

type
  TChatMessage = record
    Role: string;     // 'system' | 'user' | 'assistant'
    Content: string;

    class function System(const AContent: string): TChatMessage; static;
    class function User(const AContent: string): TChatMessage; static;
    class function Assistant(const AContent: string): TChatMessage; static;
  end;

  TChatResult = record
    Success: Boolean;
    Content: string;
    ReasoningContent: string;
    FinishReason: string;
    ModelUsed: string;
    PromptTokens: Integer;
    CompletionTokens: Integer;
    TotalTokens: Integer;
    DurationMs: Integer;
    ErrorCode: string;
    ErrorMessage: string;
  end;

  TImageGenerationResult = record
    Success: Boolean;
    ImageUrl: string;
    ImageBase64: string;
    MimeType: string;
    ModelUsed: string;
    ProviderUsed: string;
    DurationMs: Integer;
    ErrorCode: string;
    ErrorMessage: string;
  end;

  TProviderConfig = record
    Name: string;       // 'ModelScope' / 'OpenAI' / ...
    Endpoint: string;   // 'https://api-inference.modelscope.cn/v1'
    ApiFormat: string;  // 'openai' | 'anthropic'
    Priority: Integer;  // 0 = highest priority
  end;

  TModelInfo = record
    ModelId: string;
    Tier: TModelTier;
    MaxTokens: Integer;
    Temperature: Double;
    SupportsThinking: Boolean;
    SupportsVision: Boolean;
  end;

implementation

uses
  System.Variants;

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

{ TLLMStorageParam }

class function TLLMStorageParam.Create(const AName: string;
  const AValue: Variant): TLLMStorageParam;
begin
  Result.Name := AName;
  Result.Value := AValue;
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

{ TModelTierHelper }

function TModelTierHelper.DisplayName: string;
begin
  if Self = TierSmart then Result := 'Smart'
  else if Self = TierBalanced then Result := 'Balanced'
  else if Self = TierFast then Result := 'Fast'
  else if Self = TierImageGen then Result := 'Image Generation'
  else if Self = TierVision then Result := 'Vision'
  else if Self = TierVisionFallback then Result := 'Image Fallback'
  else Result := string(Self);
end;

{ TChatMessage (L3) }

class function TChatMessage.System(const AContent: string): TChatMessage;
begin
  Result.Role := 'system';
  Result.Content := AContent;
end;

class function TChatMessage.User(const AContent: string): TChatMessage;
begin
  Result.Role := 'user';
  Result.Content := AContent;
end;

class function TChatMessage.Assistant(const AContent: string): TChatMessage;
begin
  Result.Role := 'assistant';
  Result.Content := AContent;
end;

end.
