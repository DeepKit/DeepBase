unit UniBase.LLM.Service;

{ UniBase LLM Service — ILLMClient + ILLMAdmin 实现 + LLM() 全局函数
  消费程序 uses 此单元后直接调用 LLM.Chat('smart', 'question') }

interface

uses
  UniBase.LLM.Client, UniBase.LLM.Types;

function LLM: ILLMClient;
function LLMAdmin: ILLMAdmin;

implementation

uses
  System.SysUtils, System.Generics.Collections,
  UniBase.LLM.HTTP, UniBase.LLM.Config;

type
  TLLMService = class(TInterfacedObject, ILLMClient, ILLMAdmin)
  private
    FHttpClient: TLLMHttpClient;
    FConfig: TLLMConfigStore;
    FCallCount: Integer;
    FLastDurationMs: Integer;
    FLoaded: Boolean;

    procedure EnsureLoaded;
    function FindProviderForModel(const AModelId: string; out AEndpoint, AApiKey, AApiFormat: string): Boolean;
    function TryCall(const AModelId: string; const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer; ATemperature: Double): TChatResult;
    function CallWithFallback(const ATier: TModelTier; const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer; ATemperature: Double): TChatResult;

    // ILLMClient
    function Chat(const ATier: TModelTier; const AUserPrompt: string): TChatResult; overload;
    function Chat(const ATier: TModelTier; const ASystemPrompt, AUserPrompt: string): TChatResult; overload;
    function ChatWithHistory(const ATier: TModelTier; const AMessages: TArray<TChatMessage>;
      AMaxTokens: Integer = 0; ATemperature: Double = -1): TChatResult;
    procedure ChatStream(const ATier: TModelTier; const AMessages: TArray<TChatMessage>;
      AOnChunk: TProc<string>; AOnError: TProc<string>; AMaxTokens: Integer = 0);
    function ChatVision(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string = ''): TChatResult;
    procedure ChatVisionStream(const ATier: TModelTier;
      const AImageBase64: string; const AImageMimeType: string;
      const AUserPrompt: string; const ASystemPrompt: string;
      AOnChunk: TProc<string>; AOnError: TProc<string>;
      AMaxTokens: Integer = 0);
    function GetModelForTier(const ATier: TModelTier): string;
    function CallCount: Integer;
    function LastDurationMs: Integer;

    // ILLMAdmin
    procedure AddProvider(const AName, AEndpoint, AApiKey, AApiFormat: string; APriority: Integer = 0);
    procedure RemoveProvider(const AName: string);
    procedure SetProviderKey(const AName, AApiKey: string);
    procedure SetTierModels(const ATier: TModelTier; const AModels: TArray<string>);
    function GetTierModels(const ATier: TModelTier): TArray<string>;
    function GetProviders: TArray<TProviderConfig>;
    function GetAvailableModels(const AProviderName: string): TArray<string>;
    function TestConnection(const AProviderName, AModelId: string;
      out ADurationMs: Integer; out AErrorMsg: string): Boolean;
    function IsConfigured: Boolean;
    procedure Save;
    procedure Load;
  public
    constructor Create;
    destructor Destroy; override;
  end;

var
  GLLMService: TLLMService = nil;

function LLM: ILLMClient;
begin
  if GLLMService = nil then
    GLLMService := TLLMService.Create;
  Result := GLLMService;
end;

function LLMAdmin: ILLMAdmin;
begin
  if GLLMService = nil then
    GLLMService := TLLMService.Create;
  Result := GLLMService;
end;

{ TLLMService }

constructor TLLMService.Create;
begin
  inherited Create;
  FHttpClient := TLLMHttpClient.Create;
  FConfig := TLLMConfigStore.Create;
  FCallCount := 0;
  FLoaded := False;
end;

destructor TLLMService.Destroy;
begin
  FreeAndNil(FHttpClient);
  FreeAndNil(FConfig);
  inherited;
end;

procedure TLLMService.EnsureLoaded;
begin
  if not FLoaded then
  begin
    FConfig.Load;
    FLoaded := True;
  end;
end;

// ---- Provider Resolution ----

function TLLMService.FindProviderForModel(const AModelId: string;
  out AEndpoint, AApiKey, AApiFormat: string): Boolean;
begin
  // Search across all providers — the model might be on any provider
  for var P in FConfig.GetAllProviders do
  begin
    AEndpoint := P.Endpoint;
    AApiKey := FConfig.GetApiKey(P.Name);
    AApiFormat := P.ApiFormat;
    Exit(True);
  end;

  // Fallback: use first provider with API key
  for var P in FConfig.GetAllProviders do
  begin
    var Key := FConfig.GetApiKey(P.Name);
    if Key <> '' then
    begin
      AEndpoint := P.Endpoint;
      AApiKey := Key;
      AApiFormat := P.ApiFormat;
      Exit(True);
    end;
  end;

  Result := False;
end;

// ---- Core Call Logic ----

function TLLMService.TryCall(const AModelId: string; const AMessages: TArray<TChatMessage>;
  AMaxTokens: Integer; ATemperature: Double): TChatResult;
var
  EP, Key, Fmt: string;
begin
  if not FindProviderForModel(AModelId, EP, Key, Fmt) then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.ErrorCode := 'NO_PROVIDER';
    Result.ErrorMessage := 'No provider configured for model: ' + AModelId;
    Exit;
  end;

  FHttpClient.Send(EP, Key, Fmt, AModelId, AMessages, AMaxTokens, ATemperature, Result);
  Inc(FCallCount);
  FLastDurationMs := Result.DurationMs;
end;

function TLLMService.CallWithFallback(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double): TChatResult;
var
  Models: TArray<string>;
  TierStr: string;
begin
  TierStr := string(ATier);
  Models := FConfig.GetTierModels(TierStr);

  if Length(Models) = 0 then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.ErrorCode := 'NO_MODEL';
    Result.ErrorMessage := Format('No models configured for tier "%s"', [TierStr]);
    Exit;
  end;

  // Try primary, then fallback models
  for var I := 0 to High(Models) do
  begin
    Result := TryCall(Models[I], AMessages, AMaxTokens, ATemperature);
    if Result.Success then
      Exit;
    // Continue to next fallback model
  end;
end;

// ---- ILLMClient ----

function TLLMService.Chat(const ATier: TModelTier; const AUserPrompt: string): TChatResult;
begin
  Result := Chat(ATier, '', AUserPrompt);
end;

function TLLMService.Chat(const ATier: TModelTier; const ASystemPrompt, AUserPrompt: string): TChatResult;
var
  Messages: TArray<TChatMessage>;
  Idx: Integer;
begin
  EnsureLoaded;
  Idx := 0;
  if ASystemPrompt <> '' then
  begin
    SetLength(Messages, 2);
    Messages[0] := TChatMessage.System(ASystemPrompt);
    Messages[1] := TChatMessage.User(AUserPrompt);
  end
  else
  begin
    SetLength(Messages, 1);
    Messages[0] := TChatMessage.User(AUserPrompt);
  end;

  // Use tier-driven defaults
  var MaxTok := 4000;
  var Temp := 0.2;
  if ATier = TierFast then
  begin
    MaxTok := 2048;
    Temp := 0.0;
  end
  else if ATier = TierBalanced then
  begin
    MaxTok := 4096;
    Temp := 0.1;
  end
  else if ATier = TierVision then
  begin
    MaxTok := 4096;
    Temp := 0.2;
  end
  else if ATier = TierVisionFallback then
  begin
    MaxTok := 2048;
    Temp := 0.1;
  end;

  Result := CallWithFallback(ATier, Messages, MaxTok, Temp);
end;

function TLLMService.ChatWithHistory(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>; AMaxTokens: Integer;
  ATemperature: Double): TChatResult;
begin
  EnsureLoaded;
  if AMaxTokens <= 0 then
  begin
    if ATier = TierFast then AMaxTokens := 2048
    else if ATier = TierBalanced then AMaxTokens := 4096
    else AMaxTokens := 4000;
  end;
  if ATemperature < 0 then
  begin
    if ATier = TierFast then ATemperature := 0.0
    else if ATier = TierBalanced then ATemperature := 0.1
    else ATemperature := 0.2;
  end;
  Result := CallWithFallback(ATier, AMessages, AMaxTokens, ATemperature);
end;

procedure TLLMService.ChatStream(const ATier: TModelTier;
  const AMessages: TArray<TChatMessage>; AOnChunk: TProc<string>;
  AOnError: TProc<string>; AMaxTokens: Integer);
var
  Models: TArray<string>;
  TierStr: string;
  EP, Key, Fmt: string;
  R: TChatResult;
  StreamSuccess: Boolean;
begin
  EnsureLoaded;
  TierStr := string(ATier);
  Models := FConfig.GetTierModels(TierStr);

  if Length(Models) = 0 then
  begin
    if Assigned(AOnError) then
      AOnError(Format('No models configured for tier "%s"', [TierStr]));
    Exit;
  end;

  // Set streaming defaults
  if AMaxTokens <= 0 then
  begin
    if ATier = TierFast then AMaxTokens := 2048
    else if ATier = TierBalanced then AMaxTokens := 4096
    else if ATier = TierVision then AMaxTokens := 4096
    else if ATier = TierVisionFallback then AMaxTokens := 2048
    else AMaxTokens := 4000;
  end;

  var Temp := 0.2;
  if ATier = TierFast then Temp := 0.0
  else if ATier = TierBalanced then Temp := 0.1;

  // Try each model in tier (first success wins)
  for var I := 0 to High(Models) do
  begin
    if not FindProviderForModel(Models[I], EP, Key, Fmt) then
      Continue;

    StreamSuccess := FHttpClient.SendStream(EP, Key, Fmt, Models[I],
      AMessages, AMaxTokens, Temp, AOnChunk, AOnError, R);

    Inc(FCallCount);
    FLastDurationMs := R.DurationMs;
    if StreamSuccess then Exit;
  end;

  // All models failed
  if Assigned(AOnError) then
    AOnError('All models failed for streaming');
end;

function TLLMService.ChatVision(const ATier: TModelTier;
  const AImageBase64: string; const AImageMimeType: string;
  const AUserPrompt: string; const ASystemPrompt: string): TChatResult;
var
  Models: TArray<string>;
  TierStr: string;
  EP, Key, Fmt: string;
begin
  EnsureLoaded;
  TierStr := string(ATier);
  Models := FConfig.GetTierModels(TierStr);

  if Length(Models) = 0 then
  begin
    FillChar(Result, SizeOf(Result), 0);
    Result.ErrorCode := 'NO_VISION_MODEL';
    Result.ErrorMessage := Format('No models configured for vision tier "%s"', [TierStr]);
    Exit;
  end;

  // Set vision defaults
  var MaxTok := 4096;
  var Temp := 0.2;
  if ATier = TierVisionFallback then
  begin
    MaxTok := 2048;
    Temp := 0.1;
  end;

  // Try each model in tier order (primary first, then fallback)
  for var I := 0 to High(Models) do
  begin
    if not FindProviderForModel(Models[I], EP, Key, Fmt) then
      Continue;

    FHttpClient.SendVision(EP, Key, Fmt, Models[I], AImageBase64, AImageMimeType,
      ASystemPrompt, AUserPrompt, MaxTok, Temp, Result);
    Inc(FCallCount);
    FLastDurationMs := Result.DurationMs;
    if Result.Success then
      Exit;
  end;

  // All models failed
  if not Result.Success then
  begin
    Result.ErrorCode := 'ALL_VISION_FAILED';
    if Result.ErrorMessage = '' then
      Result.ErrorMessage := Format('All vision models failed for tier "%s"', [TierStr]);
  end;
end;

procedure TLLMService.ChatVisionStream(const ATier: TModelTier;
  const AImageBase64: string; const AImageMimeType: string;
  const AUserPrompt: string; const ASystemPrompt: string;
  AOnChunk: TProc<string>; AOnError: TProc<string>;
  AMaxTokens: Integer);
var
  Models: TArray<string>;
  TierStr, EP, Key, Fmt: string;
  R: TChatResult;
begin
  EnsureLoaded;
  TierStr := string(ATier);
  Models := FConfig.GetTierModels(TierStr);

  if Length(Models) = 0 then
  begin
    if Assigned(AOnError) then
      AOnError(Format('No models configured for vision tier "%s"', [TierStr]));
    Exit;
  end;

  // Set vision streaming defaults
  if AMaxTokens <= 0 then
  begin
    if ATier = TierVisionFallback then AMaxTokens := 2048
    else AMaxTokens := 4096;
  end;

  var Temp := 0.2;
  if ATier = TierVisionFallback then Temp := 0.1;

  // Build messages manually for vision content
  for var I := 0 to High(Models) do
  begin
    if not FindProviderForModel(Models[I], EP, Key, Fmt) then
      Continue;

    // Vision streaming: build messages with image content
    var Messages: TArray<TChatMessage>;
    if ASystemPrompt <> '' then
    begin
      SetLength(Messages, 2);
      Messages[0] := TChatMessage.System(ASystemPrompt);
      Messages[1] := TChatMessage.User(
        Format('data:%s;base64,%s|%s', [AImageMimeType, AImageBase64, AUserPrompt]));
    end
    else
    begin
      SetLength(Messages, 1);
      Messages[0] := TChatMessage.User(
        Format('data:%s;base64,%s|%s', [AImageMimeType, AImageBase64, AUserPrompt]));
    end;

    if FHttpClient.SendStream(EP, Key, Fmt, Models[I], Messages, AMaxTokens, Temp,
      AOnChunk, AOnError, R) then
    begin
      Inc(FCallCount);
      FLastDurationMs := R.DurationMs;
      Exit;
    end;
  end;

  if Assigned(AOnError) then
    AOnError(Format('All vision models failed for streaming tier "%s"', [TierStr]));
end;

function TLLMService.GetModelForTier(const ATier: TModelTier): string;
var
  Models: TArray<string>;
begin
  EnsureLoaded;
  Models := FConfig.GetTierModels(string(ATier));
  if Length(Models) > 0 then
    Result := Models[0]
  else
    Result := '';
end;

function TLLMService.CallCount: Integer;
begin
  Result := FCallCount;
end;

function TLLMService.LastDurationMs: Integer;
begin
  Result := FLastDurationMs;
end;

// ---- ILLMAdmin ----

procedure TLLMService.AddProvider(const AName, AEndpoint, AApiKey, AApiFormat: string;
  APriority: Integer);
var
  P: TProviderConfig;
begin
  P.Name := AName;
  P.Endpoint := AEndpoint;
  P.ApiFormat := AApiFormat;
  P.Priority := APriority;
  FConfig.AddProvider(P, AApiKey);
end;

procedure TLLMService.RemoveProvider(const AName: string);
begin
  FConfig.RemoveProvider(AName);
end;

procedure TLLMService.SetProviderKey(const AName, AApiKey: string);
begin
  FConfig.SetProviderKey(AName, AApiKey);
end;

procedure TLLMService.SetTierModels(const ATier: TModelTier; const AModels: TArray<string>);
begin
  FConfig.SetTierModels(string(ATier), AModels);
end;

function TLLMService.GetTierModels(const ATier: TModelTier): TArray<string>;
begin
  Result := FConfig.GetTierModels(string(ATier));
end;

function TLLMService.GetProviders: TArray<TProviderConfig>;
begin
  Result := FConfig.GetAllProviders;
end;

function TLLMService.GetAvailableModels(const AProviderName: string): TArray<string>;
var
  P: TProviderConfig;
begin
  if FConfig.GetProvider(AProviderName, P) then
    Result := FHttpClient.FetchModels(P.Endpoint, FConfig.GetApiKey(P.Name), P.ApiFormat)
  else
    SetLength(Result, 0);
end;

function TLLMService.TestConnection(const AProviderName, AModelId: string;
  out ADurationMs: Integer; out AErrorMsg: string): Boolean;
var
  P: TProviderConfig;
  Messages: TArray<TChatMessage>;
  R: TChatResult;
begin
  if not FConfig.GetProvider(AProviderName, P) then
  begin
    AErrorMsg := 'Provider not found: ' + AProviderName;
    ADurationMs := 0;
    Exit(False);
  end;

  SetLength(Messages, 1);
  Messages[0] := TChatMessage.User('ping');

  var Model := AModelId;
  if Model = '' then
  begin
    var Models := GetAvailableModels(AProviderName);
    if Length(Models) > 0 then
      Model := Models[0]
    else
    begin
      AErrorMsg := 'No models available';
      ADurationMs := 0;
      Exit(False);
    end;
  end;

  Result := FHttpClient.Send(P.Endpoint, FConfig.GetApiKey(P.Name), P.ApiFormat,
    Model, Messages, 10, 0.0, R);
  ADurationMs := R.DurationMs;
  if not Result then
    AErrorMsg := R.ErrorMessage;
end;

function TLLMService.IsConfigured: Boolean;
begin
  EnsureLoaded;
  Result := FConfig.IsConfigured;
end;

procedure TLLMService.Save;
begin
  FConfig.Save;
end;

procedure TLLMService.Load;
begin
  FConfig.Load;
  FLoaded := True;
end;

initialization

finalization
  if GLLMService <> nil then
  begin
    GLLMService.Free;
    GLLMService := nil;
  end;

end.
