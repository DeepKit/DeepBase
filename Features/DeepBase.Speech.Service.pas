unit DeepBase.Speech.Service;

interface

uses
  System.SysUtils,
  DeepBase.Commerce.Permissions,
  DeepBase.Speech.ASR.Baidu,
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
    FPermissionClient: TDeepKitPermissionClient;
    FPermissionFeatureCode: string;
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
    property PermissionClient: TDeepKitPermissionClient read FPermissionClient
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
    Samples := FCapture.GetFloatSamples;
    if Length(Samples) >= FVAD.FrameSize then
      Result := FVAD.ProcessAll(@Samples[0], Length(Samples));
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
    // Simple timed capture (blocking). Real usage should use streaming.
    Sleep(Min(AMaxSeconds * 1000, 5000));
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
