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

implementation

uses
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

end.
