unit DeepBase.LLM.Config;

{ DeepBase LLM Config �� DeepBase.Config ���� + API Key ��ȫ�洢 }

interface

uses
  System.SysUtils, System.JSON, System.Generics.Collections,
  DeepBase.LLM.Types;

type
  TLLMConfigStore = class
  private
    FProviders: TList<TProviderConfig>;
    FTierModels: TDictionary<string, TArray<string>>; // tier string �� model IDs
    FKeys: TDictionary<string, string>;               // provider name �� encrypted key

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
  DeepBase.Config, DeepBase.Crypto;

{ TLLMConfigStore }

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
  if AEncrypted = '' then Exit('');
  try
    Result := TSimpleCrypto.Decrypt(AEncrypted, '@DeepBase.LLM.Key');
  except
    Result := '';
  end;
end;

function TLLMConfigStore.EncryptKey(const APlain: string): string;
begin
  if APlain = '' then Exit('');
  Result := TSimpleCrypto.Encrypt(APlain, '@DeepBase.LLM.Key');
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

function TLLMConfigStore.IsConfigured: Boolean;
begin
  Result := False;

  // At least one provider with API key is required
  if FProviders.Count = 0 then Exit;
  var HasKey := False;
  for var P in FProviders do
    if GetApiKey(P.Name) <> '' then
    begin
      HasKey := True;
      Break;
    end;
  if not HasKey then Exit;

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

    // Save tier models as JSON
    JSON := TJSONObject.Create;
    for var Pair in FTierModels do
    begin
      ModelsArr := TJSONArray.Create;
      for var M in Pair.Value do
        ModelsArr.Add(M);
      JSON.AddPair(Pair.Key, ModelsArr);
    end;
    SetConfig('LLM.Tiers', JSON.ToJSON);

    // Save API keys encrypted
    JSON := TJSONObject.Create;
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
