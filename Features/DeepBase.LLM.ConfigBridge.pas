unit DeepBase.LLM.ConfigBridge;

interface

uses
  System.SysUtils,
  DeepBase.LLM,
  DeepBase.LLM.Types,
  DeepBase.LLM.Config;

type
  TLLMConfigBridge = class
  public
    class function ConfigToProvider(const AConfig: TLLMConfig): TProviderConfig;
    class procedure ImportConfigs(AStore: TLLMConfigStore;
      const AConfigs: TLLMConfigArray; const ATier: string = 'smart');
  end;

implementation

class function TLLMConfigBridge.ConfigToProvider(const AConfig: TLLMConfig): TProviderConfig;
begin
  Result.Name := AConfig.Name;
  Result.Endpoint := AConfig.BaseUrl;
  if AConfig.Provider = lpAnthropic then
    Result.ApiFormat := 'anthropic'
  else if AConfig.Provider = lpOllama then
    Result.ApiFormat := 'ollama'
  else
    Result.ApiFormat := 'openai';
  Result.Priority := 0;
end;

class procedure TLLMConfigBridge.ImportConfigs(AStore: TLLMConfigStore;
  const AConfigs: TLLMConfigArray; const ATier: string);
var
  LProv: TProviderConfig;
  LModels: TArray<string>;
begin
  if AStore = nil then
    Exit;
  for var C in AConfigs do
  begin
    if not C.IsEnabled then
      Continue;
    LProv := ConfigToProvider(C);
    AStore.AddProvider(LProv, C.ApiKey);
    if C.Model <> '' then
    begin
      SetLength(LModels, 1);
      LModels[0] := C.Model;
      AStore.SetTierModels(ATier, LModels);
    end;
  end;
end;

end.
