unit DeepBase.Speech.Service;

interface

uses
  System.SysUtils,
  DeepBase.Permissions.Contract,
  DeepBase.Speech.ASR.Baidu,
  DeepBase.Speech.Registry,
  DeepBase.Speech.Types,
  DeepBase.Speech.VAD;

type
  TSpeechServiceOptions = record
    Recognition: TSpeechRecognitionOptions;
    AutoStopSilence: Boolean;
    SilenceThresholdDb: Double;
    SilenceSeconds: Double;
    MaxRecordSeconds: Integer;
    class function Default: TSpeechServiceOptions; static;
  end;

  TDeepBaseSpeechService = class
  private
    FCapture: ISpeechAudioCapture;
    FRecognizer: ISpeechRecognizer;
    FVAD: TDeepBaseSpeechVAD;
    FOwnsVAD: Boolean;
    FOptions: TSpeechServiceOptions;
    FRecordingStartTime: TDateTime;
    // REVIEW5-FEAT-010: Use abstract IPermissionClient instead of concrete
    // TDeepBasePermissionClient to decouple Speech from Commerce. Held weakly:
    // the caller owns the client instance (e.g. the app's global permission
    // client). A strong interface ref here would bump the refcount, so
    // Service.Free would release the client before the caller's own .Free ran
    // — a double-free (BUG: Invalid pointer operation in the permission-quota
    // test). [weak] keeps Service a non-owning consumer of the interface.
    [weak] FPermissionClient: IPermissionClient;
    FPermissionFeatureCode: string;
    // Task 22.2: cursor into the capture buffer marking how much has
    // already been fed through the VAD. ShouldAutoStop only re-runs VAD
    // over [FAutoStopCursor..current], so polling cost is O(delta) per
    // call instead of O(audio_length).
    FAutoStopCursor: Integer;
    procedure SetOptions(const AOptions: TSpeechServiceOptions);
  public
    constructor Create(const ARecognizer: ISpeechRecognizer;
      const ACapture: ISpeechAudioCapture = nil;
      AVAD: TDeepBaseSpeechVAD = nil);
    destructor Destroy; override;

    class function CreateBaidu(const AConfig: TSpeechBaiduConfig): TDeepBaseSpeechService; static;

    function CheckStatus(out AError: string): Boolean;
    function StartRecording: Boolean;
    procedure StopRecording;
    function ShouldAutoStop: Boolean;
    function RecognizeCaptured: TSpeechRecognitionResult;
    function StopAndRecognize: TSpeechRecognitionResult;

    property Capture: ISpeechAudioCapture read FCapture;
    property Recognizer: ISpeechRecognizer read FRecognizer;
    property Options: TSpeechServiceOptions read FOptions write SetOptions;
    property PermissionClient: IPermissionClient read FPermissionClient
      write FPermissionClient;
    property PermissionFeatureCode: string read FPermissionFeatureCode
      write FPermissionFeatureCode;
  end;

  /// <summary>
  /// Static facade for Speech capabilities. Provides convenient access to
  /// registered backends via TSpeechRegistry. Thread-safe.
  /// </summary>
  TSpeechService = class
  private
    class var FASR: ISpeechRecognizerEx;
    class var FTTS: ITTSBackend;
    class var FWakeWord: IWakeWordDetector;
    class var FVoiceprint: IVoiceprint;
    class var FIntentParser: IIntentParser;
    class var FAudioCapture: ISpeechAudioCapture;
    class var FLock: TObject;
    class constructor Create;
    class destructor Destroy;
  public
    // Backend registration (called by downstream or initialization sections)
    class procedure RegisterASRBackend(const ABackend: ISpeechRecognizerEx);
    class procedure RegisterTTSBackend(const ABackend: ITTSBackend);
    class procedure RegisterWakeWordDetector(const ADetector: IWakeWordDetector);
    class procedure RegisterVoiceprint(const AVoiceprint: IVoiceprint);
    class procedure RegisterIntentParser(const AParser: IIntentParser);
    class procedure RegisterAudioCapture(const ACapture: ISpeechAudioCapture);

    // One-call wiring from TSpeechRegistry. For each capability (ASR/TTS/
    // AudioCapture), discover the best available backend via the registry and
    // instantiate it through that backend's stored Factory closure (the closure
    // is created inside the backend's own unit, so this avoids cross-package
    // uses and the Core→ASR/TTS one-way package dependency stays intact).
    // Backends whose Factory is nil (e.g. ones needing explicit config like an
    // API key) are skipped — the consumer must call the matching Register*.
    // Idempotent: re-running replaces the active backend with the current best.
    class procedure WireFromRegistry;
    // Accessors
    class function ASR: ISpeechRecognizerEx;
    class function TTS: ITTSBackend;
    class function WakeWord: IWakeWordDetector;
    class function Voiceprint: IVoiceprint;
    class function IntentParser: IIntentParser;
    class function AudioCapture: ISpeechAudioCapture;

    // Convenience methods
    class function TranscribeFromMic(const ALanguage: string = 'zh-CN';
      AMaxSeconds: Integer = 30;
      ASilenceTimeoutMs: Integer = 3000): TSpeechRecognitionResult;
    class procedure Speak(const AText: string; const ALanguage: string = '');
  end;

implementation

uses
  System.Classes,
  System.Math,
  DeepBase.Speech.Audio.WinMM;

class function TSpeechServiceOptions.Default: TSpeechServiceOptions;
begin
  Result.Recognition := TSpeechRecognitionOptions.Default;
  Result.AutoStopSilence := True;
  Result.SilenceThresholdDb := -40;
  Result.SilenceSeconds := 1.5;
  Result.MaxRecordSeconds := 60;
end;

constructor TDeepBaseSpeechService.Create(const ARecognizer: ISpeechRecognizer;
  const ACapture: ISpeechAudioCapture; AVAD: TDeepBaseSpeechVAD);
begin
  inherited Create;
  FRecognizer := ARecognizer;
  if FRecognizer = nil then
    raise EDeepBaseSpeechProviderError.Create('Speech recognizer is required');

  FCapture := ACapture;
  if FCapture = nil then
    FCapture := TDeepBaseWinMMAudioCapture.Create;

  FOptions := TSpeechServiceOptions.Default;
  FPermissionClient := nil;
  FPermissionFeatureCode := 'speech.asr';
  FVAD := AVAD;
  FOwnsVAD := FVAD = nil;
  if FVAD = nil then
    FVAD := TDeepBaseSpeechVAD.Create(FOptions.SilenceThresholdDb, 100,
      FCapture.SampleRate, FOptions.SilenceSeconds);
  FRecordingStartTime := 0;
  FAutoStopCursor := 0;
end;

destructor TDeepBaseSpeechService.Destroy;
begin
  if FOwnsVAD then
    FVAD.Free;
  inherited;
end;

procedure TDeepBaseSpeechService.SetOptions(const AOptions: TSpeechServiceOptions);
begin
  FOptions := AOptions;
  if FOwnsVAD then
  begin
    FreeAndNil(FVAD);
    FVAD := TDeepBaseSpeechVAD.Create(FOptions.SilenceThresholdDb, 100,
      FCapture.SampleRate, FOptions.SilenceSeconds);
  end;
  FAutoStopCursor := 0;
end;

class function TDeepBaseSpeechService.CreateBaidu(
  const AConfig: TSpeechBaiduConfig): TDeepBaseSpeechService;
begin
  Result := TDeepBaseSpeechService.Create(
    TDeepBaseBaiduSpeechRecognizer.Create(AConfig));
end;

function TDeepBaseSpeechService.CheckStatus(out AError: string): Boolean;
begin
  Result := FRecognizer.CheckStatus(AError);
end;

function TDeepBaseSpeechService.StartRecording: Boolean;
begin
  FVAD.Reset;
  FAutoStopCursor := 0;
  FRecordingStartTime := Now;
  Result := FCapture.StartRecording;
  if not Result then
    FRecordingStartTime := 0;
end;

procedure TDeepBaseSpeechService.StopRecording;
begin
  if FCapture.IsRecording then
    FCapture.StopRecording;
end;

function TDeepBaseSpeechService.ShouldAutoStop: Boolean;
var
  ElapsedSeconds: Double;
  Samples: TArray<Single>;
  TotalCount, ChunkSize, Offset: Integer;
begin
  Result := False;
  if not FCapture.IsRecording then
    Exit;

  if FOptions.MaxRecordSeconds > 0 then
  begin
    ElapsedSeconds := (Now - FRecordingStartTime) * 24 * 3600;
    if ElapsedSeconds >= FOptions.MaxRecordSeconds then
      Exit(True);
  end;

  if FOptions.AutoStopSilence then
  begin
    // Task 22.2: incremental VAD. Feed only NEW samples (since the last
    // poll) through ProcessFrame so per-call cost is O(delta) instead of
    // ProcessAll's O(audio_length). VAD state (FTriggered/FSilenceFrames)
    // accumulates across calls so silence is detected exactly once.
    Samples := FCapture.GetFloatSamples;
    TotalCount := Length(Samples);
    if TotalCount <= FAutoStopCursor then
      Exit;

    Offset := FAutoStopCursor;
    while Offset < TotalCount do
    begin
      ChunkSize := Min(FVAD.FrameSize, TotalCount - Offset);
      // Wait until a full VAD frame is available before consuming the
      // tail of the buffer. Partial frames stay queued for the next poll.
      if ChunkSize < FVAD.FrameSize then
        Break;

      if FVAD.ProcessFrame(@Samples[Offset], ChunkSize) then
      begin
        FAutoStopCursor := Offset + ChunkSize;
        Exit(True);
      end;
      Inc(Offset, ChunkSize);
    end;
    FAutoStopCursor := Offset;
  end;
end;

function TDeepBaseSpeechService.RecognizeCaptured: TSpeechRecognitionResult;
begin
  if Assigned(FPermissionClient) then
    FPermissionClient.RequireFeature(FPermissionFeatureCode);

  Result := FRecognizer.Recognize(FCapture.GetAudioData, FOptions.Recognition);

  if Result.Success and Assigned(FPermissionClient) then
    FPermissionClient.ConsumeQuota(FPermissionFeatureCode, 1);
end;

function TDeepBaseSpeechService.StopAndRecognize: TSpeechRecognitionResult;
begin
  StopRecording;
  Result := RecognizeCaptured;
end;

{ TSpeechService }

class constructor TSpeechService.Create;
begin
  FLock := TObject.Create;
end;

class destructor TSpeechService.Destroy;
begin
  FreeAndNil(FLock);
end;

class procedure TSpeechService.RegisterASRBackend(const ABackend: ISpeechRecognizerEx);
begin
  TMonitor.Enter(FLock);
  try
    FASR := ABackend;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechService.RegisterTTSBackend(const ABackend: ITTSBackend);
begin
  TMonitor.Enter(FLock);
  try
    FTTS := ABackend;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechService.RegisterWakeWordDetector(const ADetector: IWakeWordDetector);
begin
  TMonitor.Enter(FLock);
  try
    FWakeWord := ADetector;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechService.RegisterVoiceprint(const AVoiceprint: IVoiceprint);
begin
  TMonitor.Enter(FLock);
  try
    FVoiceprint := AVoiceprint;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechService.RegisterIntentParser(const AParser: IIntentParser);
begin
  TMonitor.Enter(FLock);
  try
    FIntentParser := AParser;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechService.RegisterAudioCapture(const ACapture: ISpeechAudioCapture);
begin
  TMonitor.Enter(FLock);
  try
    FAudioCapture := ACapture;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class procedure TSpeechService.WireFromRegistry;

  // Discover returns backends sorted by Priority (lower=better), filtered to
  // those currently Enabled and (when IsAvailableFunc is set) reporting
  // available. The first backend whose typed Factory closure is non-nil wins;
  // the closure runs inside the backend's own unit so no cross-package uses is
  // needed here. nil factory = backend needs explicit config (e.g. API key) and
  // is skipped — consumer must call the matching Register* for those.

  function PickASR: ISpeechRecognizerEx;
  var
    LAll: TArray<TSpeechBackendInfo>;
    LInfo: TSpeechBackendInfo;
  begin
    Result := nil;
    LAll := TSpeechRegistry.Discover(sbkASR, True);
    for LInfo in LAll do
      if Assigned(LInfo.ASRFactory) then
        Exit(LInfo.ASRFactory());
  end;

  function PickTTS: ITTSBackend;
  var
    LAll: TArray<TSpeechBackendInfo>;
    LInfo: TSpeechBackendInfo;
  begin
    Result := nil;
    LAll := TSpeechRegistry.Discover(sbkTTS, True);
    for LInfo in LAll do
      if Assigned(LInfo.TTSFactory) then
        Exit(LInfo.TTSFactory());
  end;

  function PickAudioCapture: ISpeechAudioCapture;
  begin
    Result := nil;
    // AudioCapture backends do NOT self-register to TSpeechRegistry (only
    // ASR/TTS/Wake/Voiceprint/Intent kinds do). WinMM is the platform capture
    // and is the sensible default on Windows, so lazily instantiate it here.
    // On non-Windows there is no default capture; consumer must register one.
    {$IFDEF MSWINDOWS}
    Result := TDeepBaseWinMMAudioCapture.CreateLowLatency;
    {$ENDIF}
  end;

var
  LASR: ISpeechRecognizerEx;
  LTTS: ITTSBackend;
  LCap: ISpeechAudioCapture;
begin
  LASR := PickASR;
  LTTS := PickTTS;
  LCap := PickAudioCapture;
  TMonitor.Enter(FLock);
  try
    if LASR <> nil then FASR := LASR;
    if LTTS <> nil then FTTS := LTTS;
    if LCap <> nil then FAudioCapture := LCap;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechService.ASR: ISpeechRecognizerEx;
begin
  TMonitor.Enter(FLock);
  try
    Result := FASR;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechService.TTS: ITTSBackend;
begin
  TMonitor.Enter(FLock);
  try
    Result := FTTS;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechService.WakeWord: IWakeWordDetector;
begin
  TMonitor.Enter(FLock);
  try
    Result := FWakeWord;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechService.Voiceprint: IVoiceprint;
begin
  TMonitor.Enter(FLock);
  try
    Result := FVoiceprint;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechService.IntentParser: IIntentParser;
begin
  TMonitor.Enter(FLock);
  try
    Result := FIntentParser;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechService.AudioCapture: ISpeechAudioCapture;
begin
  TMonitor.Enter(FLock);
  try
    Result := FAudioCapture;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TSpeechService.TranscribeFromMic(const ALanguage: string;
  AMaxSeconds: Integer; ASilenceTimeoutMs: Integer): TSpeechRecognitionResult;
begin
  // Convenience: uses registered ASR + AudioCapture for a simple record-and-recognize flow.
  // Full streaming implementation is in M2. This is a batch fallback.
  if not Assigned(FASR) then
  begin
    Result := TSpeechRecognitionResult.Failed(srsProviderNotReady, 'NO_ASR',
      'No ASR backend registered');
    Exit;
  end;

  if not FASR.IsAvailable then
  begin
    Result := TSpeechRecognitionResult.Failed(srsProviderNotReady, 'ASR_UNAVAILABLE',
      'ASR backend not available');
    Exit;
  end;

  // For batch mode, delegate to the recognizer's Recognize method with captured audio.
  // Streaming (IASRStream) is the preferred path once M2 is complete.
  if Assigned(FAudioCapture) then
  begin
    if not FAudioCapture.StartRecording then
    begin
      Result := TSpeechRecognitionResult.Failed(srsInternalError, 'MIC_FAIL',
        'Failed to start microphone capture');
      Exit;
    end;
    // BUG EXP-P1-005 FIX: poll in short slices so the capture can be stopped
    // early by an external `StopRecording` call (e.g. user push-to-talk
    // release, VAD, UI stop button). Honours the documented AMaxSeconds
    // (default 30s) instead of the previously hard-capped 5 s. Real usage
    // should still prefer the streaming IASRStream path once M2 lands.
    var StopAtMs := Int64(Max(0, AMaxSeconds)) * 1000;
    var StartedMs := TThread.GetTickCount;
    while (TThread.GetTickCount - StartedMs) < UInt64(StopAtMs) do
    begin
      Sleep(100);
      if not FAudioCapture.IsRecording then
        Break;
    end;
    if FAudioCapture.IsRecording then
      FAudioCapture.StopRecording;
    Result := FASR.Recognize(FAudioCapture.GetAudioData,
      TSpeechRecognitionOptions.Default);
  end
  else
    Result := TSpeechRecognitionResult.Failed(srsInternalError, 'NO_CAPTURE',
      'No audio capture registered');
end;

class procedure TSpeechService.Speak(const AText: string; const ALanguage: string);
var
  LOpts: TTTSOptions;
begin
  if not Assigned(FTTS) then Exit;
  if not FTTS.IsAvailable then Exit;
  if AText = '' then Exit;

  LOpts := TTTSOptions.Default;
  if ALanguage <> '' then
    LOpts.Language := ALanguage;
  FTTS.Speak(AText, LOpts);
end;

end.
