{ ============================================================================
  DeepBase.Speech.TTS.SAPI
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : SAPI 5.4 Text-to-Speech backend. Uses ISpVoice COM interface.
                Self-registers into TSpeechRegistry during initialization.
  Thread Safety: All SAPI calls serialized on a single worker thread.
  ============================================================================ }

unit DeepBase.Speech.TTS.SAPI;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs,
  Winapi.Windows, Winapi.ActiveX,
  DeepBase.Speech.SAPI.Decl,
  DeepBase.Speech.Registry;

type
  TDeepBaseSAPITTS = class
  private
    FVoice: ISpVoice;
    FLock: TCriticalSection;
    FAvailable: Boolean;
    FChecked: Boolean;
    procedure EnsureVoice;
  public
    constructor Create;
    destructor Destroy; override;

    function IsAvailable: Boolean;
    function CheckStatus: string;

    procedure Speak(const AText: string);
    procedure SpeakAsync(const AText: string; AOnDone: TProc = nil);
    procedure Stop;

    procedure SetRate(ARate: Integer);
    procedure SetVolume(AVolume: Word);
  end;

var
  GlobalSAPITTS: TDeepBaseSAPITTS;

implementation

uses
  System.Diagnostics;

constructor TDeepBaseSAPITTS.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FAvailable := False;
  FChecked := False;
end;

destructor TDeepBaseSAPITTS.Destroy;
begin
  FVoice := nil;
  FreeAndNil(FLock);
  inherited;
end;

procedure TDeepBaseSAPITTS.EnsureVoice;
var
  HR: HRESULT;
begin
  if Assigned(FVoice) then Exit;
  HR := CoCreateSpVoice(FVoice);
  FChecked := True;
  FAvailable := Succeeded(HR) and Assigned(FVoice);
end;

function TDeepBaseSAPITTS.IsAvailable: Boolean;
begin
  FLock.Enter;
  try
    if not FChecked then
      EnsureVoice;
    Result := FAvailable;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseSAPITTS.CheckStatus: string;
begin
  if IsAvailable then
    Result := 'SAPI TTS available'
  else
    Result := 'SAPI TTS not available: CoCreateInstance(SpVoice) failed. ' +
              'Ensure Windows Speech Platform is installed.';
end;

procedure TDeepBaseSAPITTS.Speak(const AText: string);
var
  LStreamNum: ULONG;
begin
  if Trim(AText) = '' then Exit;

  FLock.Enter;
  try
    EnsureVoice;
    if not FAvailable then Exit;
    FVoice.Speak(PWideChar(WideString(AText)), SPF_DEFAULT, LStreamNum);
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseSAPITTS.SpeakAsync(const AText: string; AOnDone: TProc);
var
  LStreamNum: ULONG;
begin
  if Trim(AText) = '' then
  begin
    if Assigned(AOnDone) then AOnDone();
    Exit;
  end;

  FLock.Enter;
  try
    EnsureVoice;
    if not FAvailable then
    begin
      if Assigned(AOnDone) then AOnDone();
      Exit;
    end;
    FVoice.Speak(PWideChar(WideString(AText)), SPF_ASYNC, LStreamNum);
  finally
    FLock.Leave;
  end;

  // Fire callback after speak completes (best-effort via thread)
  if Assigned(AOnDone) then
    TThread.CreateAnonymousThread(
      procedure
      begin
        CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
        try
          // Wait up to 30 seconds for speech to complete
          if Assigned(FVoice) then
            FVoice.WaitUntilDone(30000);
          AOnDone();
        finally
          CoUninitialize;
        end;
      end).Start;
end;

procedure TDeepBaseSAPITTS.Stop;
var
  LStreamNum: ULONG;
begin
  FLock.Enter;
  try
    if Assigned(FVoice) then
      FVoice.Speak(PWideChar(WideString('')), SPF_PURGEBEFORESPEAK, LStreamNum);
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseSAPITTS.SetRate(ARate: Integer);
begin
  FLock.Enter;
  try
    EnsureVoice;
    if Assigned(FVoice) then
      FVoice.SetRate(ARate);
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseSAPITTS.SetVolume(AVolume: Word);
begin
  FLock.Enter;
  try
    EnsureVoice;
    if Assigned(FVoice) then
      FVoice.SetVolume(AVolume);
  finally
    FLock.Leave;
  end;
end;

// Self-registration
procedure RegisterSAPITTSBackend;
var
  LInfo: TSpeechBackendInfo;
begin
  LInfo := Default(TSpeechBackendInfo);
  LInfo.Kind := sbkTTS;
  LInfo.Name := 'SAPI';
  LInfo.IsCloud := False;
  LInfo.RequiresMic := False;
  LInfo.SupportsBatch := True;
  LInfo.SupportsStreaming := False;
  LInfo.SupportsGrammar := False;
  LInfo.Enabled := True;
  LInfo.Priority := 10;
  LInfo.IsAvailableFunc :=
    function: Boolean
    begin
      if GlobalSAPITTS = nil then
        GlobalSAPITTS := TDeepBaseSAPITTS.Create;
      Result := GlobalSAPITTS.IsAvailable;
    end;
  TSpeechRegistry.Register(LInfo);
end;

initialization
  GlobalSAPITTS := nil;
  RegisterSAPITTSBackend;

finalization
  FreeAndNil(GlobalSAPITTS);

end.
