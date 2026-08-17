{ ============================================================================
  DeepBase.Speech.Registry
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : Backend registry for Speech capabilities. Each backend
                self-registers during unit initialization. Consumers discover
                available backends through this registry.
  Thread Safety: All public methods are thread-safe (TMonitor on FLock).
  ============================================================================ }

unit DeepBase.Speech.Registry;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  System.Generics.Defaults,
  DeepBase.Speech.Types;

type
  TSpeechBackendKind = (sbkASR, sbkTTS, sbkWakeWord, sbkVoiceprint, sbkIntent);

  TSpeechBackendInfo = record
    Kind: TSpeechBackendKind;
    Name: string;           // e.g. 'SAPI', 'Baidu', 'WinRT', 'Whisper'
    IsCloud: Boolean;
    RequiresMic: Boolean;
    SupportsBatch: Boolean;
    SupportsStreaming: Boolean;
    SupportsGrammar: Boolean;
    IsAvailableFunc: TFunc<Boolean>;
    Enabled: Boolean;
    Priority: Integer;      // lower = higher priority
    // Backend instance factories. The closure is created inside each
    // backend's own unit (where it can see its own constructor), so the
    // registry stores only the pointer — no cross-package uses, no break
    // of the Core→ASR/TTS one-way package dependency. WireFromRegistry
    // calls the field matching the backend's Kind to obtain the instance.
    // nil = backend cannot be auto-instantiated (e.g. needs explicit config
    // like an API key); consumer must call the matching TSpeechService.Register*.
    // AudioCapture has no factory here — WinMM is lazily instantiated by
    // WireFromRegistry on Windows (capture backends don't self-register).
    ASRFactory: TFunc<ISpeechRecognizerEx>;
    TTSFactory: TFunc<ITTSBackend>;
  end;

  TSpeechRegistry = class
  private
    class var FLock: TObject;
    class var FBackends: TList<TSpeechBackendInfo>;
    class procedure EnsureInit;
  public
    class procedure Register(const AInfo: TSpeechBackendInfo);
    class procedure Disable(const AName: string; AKind: TSpeechBackendKind);
    class procedure Enable(const AName: string; AKind: TSpeechBackendKind);
    class procedure SetPriority(const AName: string; AKind: TSpeechBackendKind; APriority: Integer);

    class function Discover(AKind: TSpeechBackendKind; AOnlyAvailable: Boolean = True): TArray<TSpeechBackendInfo>;
    class function FindBest(AKind: TSpeechBackendKind): TSpeechBackendInfo;
    class function IsRegistered(const AName: string; AKind: TSpeechBackendKind): Boolean;
    class function Count(AKind: TSpeechBackendKind): Integer;
  end;

implementation

class procedure TSpeechRegistry.EnsureInit;
begin
  // Atomic lazy initialization of FLock via CompareExchange
  if FLock = nil then
  begin
    var LNewLock := TObject.Create;
    if TInterlocked.CompareExchange(Pointer(FLock), Pointer(LNewLock), nil) <> nil then
      LNewLock.Free;
  end;
  // FBackends initialized under FLock once FLock is guaranteed non-nil
  if FBackends = nil then
  begin
    TMonitor.Enter(FLock);
    try
      if FBackends = nil then
        FBackends := TList<TSpeechBackendInfo>.Create;
    finally
      TMonitor.Exit(FLock);
    end;
  end;
end;

class procedure TSpeechRegistry.Register(const AInfo: TSpeechBackendInfo);
var
  I: Integer;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    // Replace if already registered (same name + kind)
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AInfo.Name) and (FBackends[I].Kind = AInfo.Kind) then
      begin
        FBackends[I] := AInfo;
        Exit;
      end;
    FBackends.Add(AInfo);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechRegistry.Disable(const AName: string; AKind: TSpeechBackendKind);
var
  I: Integer;
  LInfo: TSpeechBackendInfo;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AName) and (FBackends[I].Kind = AKind) then
      begin
        LInfo := FBackends[I];
        LInfo.Enabled := False;
        FBackends[I] := LInfo;
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechRegistry.Enable(const AName: string; AKind: TSpeechBackendKind);
var
  I: Integer;
  LInfo: TSpeechBackendInfo;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AName) and (FBackends[I].Kind = AKind) then
      begin
        LInfo := FBackends[I];
        LInfo.Enabled := True;
        FBackends[I] := LInfo;
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechRegistry.SetPriority(const AName: string;
  AKind: TSpeechBackendKind; APriority: Integer);
var
  I: Integer;
  LInfo: TSpeechBackendInfo;
begin
  EnsureInit;
  TMonitor.Enter(FLock);
  try
    for I := 0 to FBackends.Count - 1 do
      if (FBackends[I].Name = AName) and (FBackends[I].Kind = AKind) then
      begin
        LInfo := FBackends[I];
        LInfo.Priority := APriority;
        FBackends[I] := LInfo;
        Exit;
      end;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechRegistry.Discover(AKind: TSpeechBackendKind;
  AOnlyAvailable: Boolean): TArray<TSpeechBackendInfo>;
var
  LResult: TList<TSpeechBackendInfo>;
  LInfo: TSpeechBackendInfo;
begin
  EnsureInit;
  LResult := TList<TSpeechBackendInfo>.Create;
  try
    TMonitor.Enter(FLock);
    try
      for LInfo in FBackends do
      begin
        if LInfo.Kind <> AKind then Continue;
        if not LInfo.Enabled then Continue;
        if AOnlyAvailable and Assigned(LInfo.IsAvailableFunc) then
        begin
          // A backend's availability probe must never crash the whole
          // discovery loop. SAPI/COM-backed probes can raise access violations
          // in headless CI (no audio devices / no SCOM objects instantiated);
          // treat a raising probe as "not available" and skip it.
          try
            if not LInfo.IsAvailableFunc() then Continue;
          except
            Continue;
          end;
        end;
        LResult.Add(LInfo);
      end;
    finally
      TMonitor.Exit(FLock);
    end;
    // Sort by priority (lower = better)
    LResult.Sort(TComparer<TSpeechBackendInfo>.Construct(
      function(const L, R: TSpeechBackendInfo): Integer
      begin
        Result := L.Priority - R.Priority;
      end));
    Result := LResult.ToArray;
  finally
    LResult.Free;
  end;
end;

class function TSpeechRegistry.FindBest(AKind: TSpeechBackendKind): TSpeechBackendInfo;
var
  LAll: TArray<TSpeechBackendInfo>;
begin
  LAll := Discover(AKind, True);
  if Length(LAll) > 0 then
    Result := LAll[0]
  else
  begin
    Result := Default(TSpeechBackendInfo);
    Result.Name := '';
    Result.Enabled := False;
  end;
end;

class function TSpeechRegistry.IsRegistered(const AName: string;
  AKind: TSpeechBackendKind): Boolean;
var
  LInfo: TSpeechBackendInfo;
begin
  EnsureInit;
  Result := False;
  TMonitor.Enter(FLock);
  try
    for LInfo in FBackends do
      if (LInfo.Name = AName) and (LInfo.Kind = AKind) then
        Exit(True);
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechRegistry.Count(AKind: TSpeechBackendKind): Integer;
var
  LInfo: TSpeechBackendInfo;
begin
  EnsureInit;
  Result := 0;
  TMonitor.Enter(FLock);
  try
    for LInfo in FBackends do
      if LInfo.Kind = AKind then
        Inc(Result);
  finally
    TMonitor.Exit(FLock);
  end;
end;

initialization
  TSpeechRegistry.EnsureInit;

finalization
  FreeAndNil(TSpeechRegistry.FBackends);
  FreeAndNil(TSpeechRegistry.FLock);

end.
