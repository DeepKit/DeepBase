{ ============================================================================
  DeepBase.LLM.Config - LLM Configuration Management

  Contains configuration management for both Core (L2) and Proxy (L3)
  architectures:
    - L2/Core: Credential helpers, DB config loaders, API key persistence
    - L3/Proxy: TLLMConfigStore with tier-based provider management
  ============================================================================ }

unit DeepBase.LLM.Config;

interface

uses
  System.SysUtils,
  System.JSON,
  System.Generics.Collections,
  Data.DB,
  DeepBase.LLM.Types;

// ============================================================================
// L2/Core config helpers — credential management, DB helpers
// ============================================================================

const
  LLM_CREDENTIAL_REF_PREFIX = 'credman:';
  LLM_CREDENTIAL_TARGET_PREFIX = 'DeepBase_LLM_';
  LLM_CREDENTIAL_TARGET_SUFFIX = '_ApiKey';

function IsLLMCredentialRef(const Value: string): Boolean;
function ExtractLLMCredentialTarget(const CredentialRef: string): string;
function BuildLLMCredentialRef(const TargetName: string): string;
function SanitizeCredentialTargetPart(const Value: string): string;
function MakeLLMApiKeyCredentialTarget(const ConfigName: string): string;
function ResolveLLMCredentialOrRaw(const StoredValue: string): string;
procedure DeleteLLMCredentialRef(const StoredValue: string);

function TryLoadLLMApiKeyByName(const Storage: ILLMStorage;
  const ApiKeyName: string; out ApiKey: string): Boolean;
function ResolveLLMApiKey(const Storage: ILLMStorage;
  const ConfigName, StoredValue: string): string;
function ReadStoredApiKeyRefFromConfig(const Storage: ILLMStorage;
  const ConfigTable, ConfigName: string): string;
function PersistLLMApiKey(const Storage: ILLMStorage;
  const ConfigTable, ConfigName, ApiKey: string): string;

// DB helper functions
function LLMParam(const AName: string; const AValue: Variant): TLLMStorageParam;
function DeepBaseTableExists(const Storage: ILLMStorage;
  const TableName: string): Boolean;
function DeepBaseTableHasColumn(const Storage: ILLMStorage;
  const TableName, ColumnName: string): Boolean;
function QueryFieldString(Query: TDataSet; const FieldName: string;
  const DefaultValue: string = ''): string;
function QueryFieldInteger(Query: TDataSet; const FieldName: string;
  DefaultValue: Integer = 0): Integer;
function QueryFieldBoolean(Query: TDataSet; const FieldName: string;
  DefaultValue: Boolean = False): Boolean;
function QueryFieldFloat(Query: TDataSet; const FieldName: string;
  DefaultValue: Double = 0): Double;
function QueryFieldDateTime(Query: TDataSet; const FieldName: string): TDateTime;
function GetLLMConfigTableName(const Storage: ILLMStorage): string;
function GetLLMCallsSelectSQL(const Storage: ILLMStorage;
  const ConfigName: string): string;
procedure LoadConfigFromQuery(Query: TDataSet; const Storage: ILLMStorage;
  var Config: TLLMConfig);

// ============================================================================
// L3/Proxy config — TLLMConfigStore
// ============================================================================

type
  TLLMConfigStore = class
  private
    FProviders: TList<TProviderConfig>;
    FTierModels: TDictionary<string, TArray<string>>; // tier string -> model IDs
    FKeys: TDictionary<string, string>;               // provider name -> encrypted key

    function DecryptKey(const AEncrypted: string): string;
    function EncryptKey(const APlain: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    class function BuiltInTiers: TArray<TModelTier>; static;
    class function NormalizeTier(const ATier: string): string; static;

    // Provider management
    procedure AddProvider(const AConfig: TProviderConfig; const AApiKey: string);
    procedure RemoveProvider(const AName: string);
    procedure SetProviderKey(const AName, AApiKey: string);
    function GetProvider(const AName: string; out AConfig: TProviderConfig): Boolean;
    function GetApiKey(const AProviderName: string): string;
    function GetAllProviders: TArray<TProviderConfig>;

    // Tier model management
    procedure SetTierModels(const ATier: string; const AModels: TArray<string>);
    function GetTierModels(const ATier: string): TArray<string>;
    procedure LoadTierModelsJson(const ATiersJson: string);

    // Persistence via DeepBase.Config
    procedure Save;
    procedure Load;
    function IsConfigured: Boolean;
    function IsFullyConfigured: Boolean;
  end;

implementation

uses
  System.Variants,
  System.StrUtils,
  DeepBase.Config,
  DeepBase.Crypto
  {$IFDEF MSWINDOWS}
  , DeepBase.Security.DPAPI
  {$ENDIF};

// ============================================================================
// L2/Core config helpers — implementation
// ============================================================================

function LLMParam(const AName: string; const AValue: Variant): TLLMStorageParam;
begin
  Result := TLLMStorageParam.Create(AName, AValue);
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

function QueryFieldString(Query: TDataSet; const FieldName: string;
  const DefaultValue: string): string;
var
  Field: TField;
begin
  Result := DefaultValue;
  Field := Query.FindField(FieldName);
  if Assigned(Field) and not Field.IsNull then
    Result := Field.AsString;
end;

function QueryFieldInteger(Query: TDataSet; const FieldName: string;
  DefaultValue: Integer): Integer;
var
  Field: TField;
begin
  Result := DefaultValue;
  Field := Query.FindField(FieldName);
  if Assigned(Field) and not Field.IsNull then
    Result := Field.AsInteger;
end;

function QueryFieldBoolean(Query: TDataSet; const FieldName: string;
  DefaultValue: Boolean): Boolean;
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

function QueryFieldFloat(Query: TDataSet; const FieldName: string;
  DefaultValue: Double): Double;
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

function GetLLMCallsSelectSQL(const Storage: ILLMStorage;
  const ConfigName: string): string;
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

function TryLoadLLMApiKeyByName(const Storage: ILLMStorage;
  const ApiKeyName: string; out ApiKey: string): Boolean;
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

function ResolveLLMApiKey(const Storage: ILLMStorage;
  const ConfigName, StoredValue: string): string;
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

// ============================================================================
// L3/Proxy TLLMConfigStore — implementation
// ============================================================================

constructor TLLMConfigStore.Create;
begin
  inherited Create;
  FProviders := TList<TProviderConfig>.Create;
  FTierModels := TDictionary<string, TArray<string>>.Create;
  FKeys := TDictionary<string, string>.Create;
end;

destructor TLLMConfigStore.Destroy;
begin
  FreeAndNil(FProviders);
  FreeAndNil(FTierModels);
  FreeAndNil(FKeys);
  inherited;
end;

function TLLMConfigStore.DecryptKey(const AEncrypted: string): string;
begin
  // FR-002 fix: previously decrypted with a hardcoded password
  // ('@DeepBase.LLM.Key'), which gave anyone with the binary the ability
  // to recover stored API keys. Now use Windows DPAPI (per-user scope) on
  // Windows; on non-Windows return empty so callers explicitly fall back
  // to a runtime-provided key. Fail-closed: a corrupted ciphertext or
  // missing DPAPI returns '' rather than logging spurious "decrypt ok".
  if AEncrypted = '' then Exit('');
  try
    {$IFDEF MSWINDOWS}
    Result := TDPAPIHelper.UnprotectString(AEncrypted);
    {$ELSE}
    Result := '';
    {$ENDIF}
  except
    Result := '';
  end;
end;

function TLLMConfigStore.EncryptKey(const APlain: string): string;
begin
  if APlain = '' then Exit('');
  {$IFDEF MSWINDOWS}
  Result := TDPAPIHelper.ProtectString(APlain);
  {$ELSE}
  // Non-Windows: callers must supply their own secret store; fail-closed.
  Result := '';
  {$ENDIF}
end;

class function TLLMConfigStore.BuiltInTiers: TArray<TModelTier>;
begin
  Result := [TierSmart, TierBalanced, TierFast, TierImageGen, TierImageFallback];
end;

class function TLLMConfigStore.NormalizeTier(const ATier: string): string;
begin
  Result := LowerCase(Trim(ATier));
  if Result = string(TierVision) then
    Result := string(TierImageGen);
end;

procedure TLLMConfigStore.AddProvider(const AConfig: TProviderConfig; const AApiKey: string);
begin
  // Replace if exists
  for var I := 0 to FProviders.Count - 1 do
    if FProviders[I].Name = AConfig.Name then
    begin
      FProviders[I] := AConfig;
      FKeys.AddOrSetValue(AConfig.Name, EncryptKey(AApiKey));
      Exit;
    end;

  FProviders.Add(AConfig);
  FKeys.AddOrSetValue(AConfig.Name, EncryptKey(AApiKey));
end;

procedure TLLMConfigStore.RemoveProvider(const AName: string);
begin
  for var I := FProviders.Count - 1 downto 0 do
    if FProviders[I].Name = AName then
      FProviders.Delete(I);
  FKeys.Remove(AName);
end;

procedure TLLMConfigStore.SetProviderKey(const AName, AApiKey: string);
begin
  FKeys.AddOrSetValue(AName, EncryptKey(AApiKey));
end;

function TLLMConfigStore.GetProvider(const AName: string; out AConfig: TProviderConfig): Boolean;
begin
  for var P in FProviders do
    if P.Name = AName then
    begin
      AConfig := P;
      Exit(True);
    end;
  Result := False;
end;

function TLLMConfigStore.GetApiKey(const AProviderName: string): string;
begin
  if not FKeys.TryGetValue(AProviderName, Result) then
    Result := '';
  Result := DecryptKey(Result);
end;

function TLLMConfigStore.GetAllProviders: TArray<TProviderConfig>;
begin
  Result := FProviders.ToArray;
end;

procedure TLLMConfigStore.SetTierModels(const ATier: string; const AModels: TArray<string>);
begin
  FTierModels.AddOrSetValue(NormalizeTier(ATier), AModels);
end;

function TLLMConfigStore.GetTierModels(const ATier: string): TArray<string>;
begin
  if not FTierModels.TryGetValue(NormalizeTier(ATier), Result) then
    SetLength(Result, 0);
end;

procedure TLLMConfigStore.LoadTierModelsJson(const ATiersJson: string);
var
  JSON: TJSONObject;
  ModelsArr: TJSONArray;
  Models: TArray<string>;
  TierKey, RawTierKey: string;
begin
  if ATiersJson = '' then
    Exit;

  JSON := TJSONObject.ParseJSONValue(ATiersJson) as TJSONObject;
  if JSON = nil then
    Exit;
  try
    for var Pair in JSON do
    begin
      ModelsArr := Pair.JsonValue as TJSONArray;
      if ModelsArr = nil then
        Continue;

      SetLength(Models, ModelsArr.Count);
      for var I := 0 to ModelsArr.Count - 1 do
        Models[I] := ModelsArr.Items[I].Value;

      RawTierKey := Pair.JsonString.Value;
      TierKey := NormalizeTier(RawTierKey);
      if SameText(RawTierKey, string(TierVision)) and
         FTierModels.ContainsKey(TierKey) then
        Continue;
      FTierModels.AddOrSetValue(TierKey, Models);
    end;
  finally
    JSON.Free;
  end;
end;

function ProviderCanRunWithoutKey(const AProvider: TProviderConfig): Boolean;
var
  LName: string;
  LFormat: string;
  LEndpoint: string;
begin
  LName := LowerCase(Trim(AProvider.Name));
  LFormat := LowerCase(Trim(AProvider.ApiFormat));
  LEndpoint := LowerCase(Trim(AProvider.Endpoint));

  Result := (LName = 'ollama') or (LFormat = 'ollama') or
    (Pos('localhost', LEndpoint) > 0) or
    (Pos('127.0.0.1', LEndpoint) > 0) or
    (Pos('[::1]', LEndpoint) > 0);
end;

function TLLMConfigStore.IsConfigured: Boolean;
var
  HasCallableProvider: Boolean;
begin
  Result := False;

  // At least one callable provider is required. Local providers such as
  // Ollama may intentionally run without an API key.
  if FProviders.Count = 0 then
    Exit;

  HasCallableProvider := False;
  for var P in FProviders do
    if (Trim(P.Endpoint) <> '') and
       ((GetApiKey(P.Name) <> '') or ProviderCanRunWithoutKey(P)) then
    begin
      HasCallableProvider := True;
      Break;
    end;
  if not HasCallableProvider then
    Exit;

  // Text tiers (smart, balanced, fast) are mandatory
  for var Tier in ['smart', 'balanced', 'fast'] do
    if Length(GetTierModels(Tier)) = 0 then
      Exit;

  Result := True;
end;

function TLLMConfigStore.IsFullyConfigured: Boolean;
begin
  Result := IsConfigured;
  if not Result then
    Exit;

  // Full desktop launch profile requires all five downstream UI slots:
  // smart, balanced, fast, image generation, and image fallback.
  for var Tier in BuiltInTiers do
    if Length(GetTierModels(string(Tier))) = 0 then
      Exit(False);
end;

procedure TLLMConfigStore.Save;
var
  JSON, ProvObj: TJSONObject;
  ProvArr, ModelsArr: TJSONArray;
begin
  // Save providers as JSON array
  JSON := TJSONObject.Create;
  try
    ProvArr := TJSONArray.Create;
    for var P in FProviders do
    begin
      ProvObj := TJSONObject.Create;
      ProvObj.AddPair('name', P.Name);
      ProvObj.AddPair('endpoint', P.Endpoint);
      ProvObj.AddPair('format', P.ApiFormat);
      ProvObj.AddPair('priority', TJSONNumber.Create(P.Priority));
      ProvArr.AddElement(ProvObj);
    end;
    JSON.AddPair('providers', ProvArr);
    SetConfig('LLM.Providers', JSON.ToJSON);
  finally
    JSON.Free;
  end;

  // Save tier models as JSON
  JSON := TJSONObject.Create;
  try
    for var Pair in FTierModels do
    begin
      ModelsArr := TJSONArray.Create;
      for var M in Pair.Value do
        ModelsArr.Add(M);
      JSON.AddPair(Pair.Key, ModelsArr);
    end;
    SetConfig('LLM.Tiers', JSON.ToJSON);
  finally
    JSON.Free;
  end;

  // Save API keys encrypted
  JSON := TJSONObject.Create;
  try
    for var Pair in FKeys do
      JSON.AddPair(Pair.Key, Pair.Value);
    SetConfig('LLM.Keys', JSON.ToJSON);
  finally
    JSON.Free;
  end;
end;

procedure TLLMConfigStore.Load;
var
  JSON, ProvObj: TJSONObject;
  ProvArr: TJSONArray;
  KeysObj: TJSONObject;
  ProviderStr, TiersStr, KeysStr: string;
begin
  FProviders.Clear;
  FTierModels.Clear;
  FKeys.Clear;

  // Load providers
  ProviderStr := GetConfig('LLM.Providers', '');
  if ProviderStr <> '' then
  begin
    JSON := TJSONObject.ParseJSONValue(ProviderStr) as TJSONObject;
    if JSON <> nil then
    try
      if JSON.TryGetValue<TJSONArray>('providers', ProvArr) then
        for var I := 0 to ProvArr.Count - 1 do
        begin
          ProvObj := ProvArr.Items[I] as TJSONObject;
          var P: TProviderConfig;
          P.Name := ProvObj.GetValue('name', '');
          P.Endpoint := ProvObj.GetValue('endpoint', '');
          P.ApiFormat := ProvObj.GetValue('format', 'openai');
          P.Priority := ProvObj.GetValue<Integer>('priority', 0);
          if P.Name <> '' then
            FProviders.Add(P);
        end;
    finally
      JSON.Free;
    end;
  end;

  // Load tier models
  TiersStr := GetConfig('LLM.Tiers', '');
  if TiersStr <> '' then
    LoadTierModelsJson(TiersStr);

  // Load encrypted keys
  KeysStr := GetConfig('LLM.Keys', '');
  if KeysStr <> '' then
  begin
    KeysObj := TJSONObject.ParseJSONValue(KeysStr) as TJSONObject;
    if KeysObj <> nil then
    try
      for var Pair in KeysObj do
        FKeys.AddOrSetValue(Pair.JsonString.Value, Pair.JsonValue.Value);
    finally
      KeysObj.Free;
    end;
  end;
end;

end.
