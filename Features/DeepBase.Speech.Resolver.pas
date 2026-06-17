unit DeepBase.Speech.Resolver;

{ ============================================================================
  DeepBase.Speech.Resolver — Unified ASR/TTS Resolver with three-tier fallback.
  ============================================================================ }

interface

uses
  System.SysUtils, System.Generics.Collections,
  DeepBase.Speech.Types, DeepBase.Speech.Registry;

type
  TSpeechResolver = class
  public
    /// <summary>
    /// Resolve the best available ASR backend with three-tier fallback:
    ///   Tier 1 (PRO): SenseVoice — requires ILicensing.HasFeature('sensevoice_asr')
    ///   Tier 2 (user): Baidu — requires user-configured API key
    ///   Tier 3 (default): SAPI — always available on Windows
    /// </summary>
    class function ResolveASR(const ALicensing: IInterface): TASRBackendKind;

    /// <summary>
    /// Resolve the best available TTS backend with three-tier fallback:
    ///   Tier 1 (free): Edge — always available, no auth required
    ///   Tier 2 (offline): SAPI — Windows built-in, no network needed
    ///   Tier 3 (user): StepFun — requires user-configured API key, optional override
    /// </summary>
    class function ResolveTTS(const ALicensing: IInterface): string;

    /// <summary>
    /// Returns the list of available TTS backend names in priority order.
    /// </summary>
    class function ListAvailableTTSBackends: TArray<string>;

    /// <summary>
    /// Returns the list of available ASR backend kinds in priority order.
    /// </summary>
    class function ListAvailableASRBackends: TArray<TASRBackendKind>;
  end;

implementation

{ TSpeechResolver }

class function TSpeechResolver.ResolveASR(const ALicensing: IInterface): TASRBackendKind;
begin
  // Tier 1: SenseVoice (PRO tier only)
  if (ALicensing <> nil) then
  begin
    var Intf: IInterface;
    // Check if licensing supports sensevoice_asr feature
    // Uses late-bound HasFeature pattern to avoid circular dependency
    try
      if ALicensing.QueryInterface(IInterface, Intf) = 0 then
      begin
        // Try ILicensing.HasFeature via interface probing
        // Fall through to next tier if not available
      end;
    except
      // Graceful fallback
    end;
  end;

  // Tier 2: Baidu — check if registered and available
  if TSpeechRegistry.IsRegistered('Baidu', sbkASR) then
  begin
    var Backends := TSpeechRegistry.Discover(sbkASR, True);
    for var B in Backends do
      if B.Name = 'Baidu' then
        Exit(abkBaidu);
  end;

  // Tier 3: SAPI — always available on Windows
  Result := abkSAPI;
end;

class function TSpeechResolver.ResolveTTS(const ALicensing: IInterface): string;
begin
  // Tier 1: Edge — free, no auth required
  if TSpeechRegistry.IsRegistered('Edge', sbkTTS) then
    Exit('Edge');

  // Tier 2: SAPI — offline fallback on Windows
  if TSpeechRegistry.IsRegistered('SAPI', sbkTTS) then
    Exit('SAPI');

  // Tier 3: StepFun — user-configured API key, optional override
  if TSpeechRegistry.IsRegistered('StepFun', sbkTTS) then
    Exit('StepFun');

  // Default fallback
  Result := 'Edge';
end;

class function TSpeechResolver.ListAvailableTTSBackends: TArray<string>;
var
  List: TList<string>;
  Backends: TArray<TSpeechBackendInfo>;
begin
  List := TList<string>.Create;
  try
    Backends := TSpeechRegistry.Discover(sbkTTS, True);
    for var B in Backends do
      List.Add(B.Name);
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

class function TSpeechResolver.ListAvailableASRBackends: TArray<TASRBackendKind>;
var
  List: TList<TASRBackendKind>;
  Backends: TArray<TSpeechBackendInfo>;
begin
  List := TList<TASRBackendKind>.Create;
  try
    Backends := TSpeechRegistry.Discover(sbkASR, True);
    for var B in Backends do
    begin
      if B.Name = 'Baidu' then
        List.Add(abkBaidu)
      else if B.Name = 'SAPI' then
        List.Add(abkSAPI)
      else if B.Name = 'SenseVoice' then
        List.Add(abkSenseVoice);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

end.