unit DeepBase.Speech.Types;

interface

uses
  System.SysUtils;

const
  /// <summary>API level for this Speech module version.</summary>
  SPEECH_API_LEVEL = 1;

type
  EDeepBaseSpeechError = class(Exception);
  EDeepBaseSpeechProviderError = class(EDeepBaseSpeechError);
  EDeepBaseSpeechAudioError = class(EDeepBaseSpeechError);

  TSpeechAudioEncoding = (
    saePCM16
  );

  TSpeechRecognitionStatus = (
    srsSuccess,
    srsEmptyAudio,
    srsProviderNotReady,
    srsHttpError,
    srsParseError,
    srsServiceError,
    srsInternalError
  );

  // --- ASR extended types ---

  TASRMode = (asrDictation, asrGrammar, asrCommand);

  TASRBackendKind = (abkAuto, abkSAPI, abkWinRT, abkBaidu, abkWhisper, abkAzure);

  TASROptions = record
    Language: string;
    Mode: TASRMode;
    MaxSeconds: Integer;
    SilenceTimeoutMs: Integer;
    class function Create(const ALang: string; AMode: TASRMode = asrDictation;
      AMaxSec: Integer = 30; ASilenceMs: Integer = 3000): TASROptions; static;
  end;

  TASRPartialResult = record
    Text: string;
    Confidence: Double;
    IsFinal: Boolean;
  end;

  // --- TTS types ---

  TTTSVoice = record
    Id: string;
    Name: string;
    Language: string;
    Gender: string;  // 'male' / 'female' / 'neutral'
  end;

  TTTSOptions = record
    VoiceId: string;
    Language: string;
    Rate: Integer;     // -10..10, 0=normal
    Volume: Integer;   // 0..100
    class function Default: TTTSOptions; static;
  end;

  // --- WakeWord types ---

  TWakeEvent = record
    MatchedWord: string;
    Confidence: Double;
    Timestamp: TDateTime;
    AudioSnippet: TBytes;  // PCM16 snippet for voiceprint verification
  end;

  // --- Voiceprint types ---

  TVoiceProfileId = string;

  TVoiceProfileInfo = record
    ProfileId: TVoiceProfileId;
    UserLabel: string;
    Purpose: string;
    SampleCount: Integer;
    OwnerApp: string;
    CreatedAt: TDateTime;
    Enabled: Boolean;
  end;

  TVoiceFeatures = TArray<TArray<Single>>;  // MFCC frames

  TVerifyResult = record
    Match: Boolean;
    Distance: Double;
    Threshold: Double;
  end;

  // --- Intent types ---

  TIntentSlot = record
    Name: string;
    Value: string;
  end;

  TIntentResult = record
    Intent: string;
    Confidence: Double;
    Slots: TArray<TIntentSlot>;
    Source: string;  // 'rule' / 'llm' / 'unknown'
  end;

  // --- Original types (unchanged signatures) ---

  TSpeechAudioFormat = record
    Encoding: TSpeechAudioEncoding;
    SampleRate: Integer;
    Channels: Integer;
    BitsPerSample: Integer;
    class function PCM16Mono(ASampleRate: Integer = 16000): TSpeechAudioFormat; static;
  end;

  TSpeechAudioData = record
    Format: TSpeechAudioFormat;
    PCMData: TBytes;
    class function FromPCM16(const APCMData: TBytes;
      ASampleRate: Integer = 16000): TSpeechAudioData; static;
    function IsEmpty: Boolean;
    function DurationMs: Integer;
  end;

  TSpeechRecognitionOptions = record
    Language: string;
    Cuid: string;
    class function Default: TSpeechRecognitionOptions; static;
  end;

  TSpeechRecognitionResult = record
    Success: Boolean;
    Text: string;
    Status: TSpeechRecognitionStatus;
    ErrorCode: string;
    ErrorMessage: string;
    RawResponse: string;
    class function Succeeded(const AText, ARawResponse: string): TSpeechRecognitionResult; static;
    class function Failed(AStatus: TSpeechRecognitionStatus; const ACode,
      AMessage: string; const ARawResponse: string = ''): TSpeechRecognitionResult; static;
  end;

  // --- Interfaces ---

  ISpeechRecognizer = interface
    ['{7B6B7E6C-0A88-4D7B-8D96-7303FE7F0470}']
    function CheckStatus(out AError: string): Boolean;
    function Recognize(const AAudio: TSpeechAudioData;
      const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
  end;

  ISpeechRecognizerEx = interface(ISpeechRecognizer)
    ['{A1C2D3E4-F5A6-47B8-9C0D-1E2F3A4B5C6D}']
    function IsAvailable: Boolean;
    function Kind: TASRBackendKind;
    function SupportsBatch: Boolean;
    function SupportsStreaming: Boolean;
    procedure LoadGrammar(const AWords: TArray<string>);
  end;

  IASRStream = interface
    ['{B2D3E4F5-A6B7-48C9-0D1E-2F3A4B5C6D7E}']
    procedure FeedAudio(const AChunk: TBytes);
    procedure SetOnPartial(ACallback: TProc<TASRPartialResult>);
    procedure SetOnFinal(ACallback: TProc<TSpeechRecognitionResult>);
    procedure Stop;
    function Running: Boolean;
  end;

  ITTSBackend = interface
    ['{C3E4F5A6-B7C8-49D0-1E2F-3A4B5C6D7E8F}']
    function IsAvailable: Boolean;
    function SupportedVoices(const ALanguage: string): TArray<TTTSVoice>;
    procedure Speak(const AText: string; const AOptions: TTTSOptions);
    procedure SpeakAsync(const AText: string; const AOptions: TTTSOptions;
      AOnDone: TProc);
    procedure Stop;
  end;

  IWakeWordDetector = interface
    ['{D4F5A6B7-C8D9-4AE0-2F3A-4B5C6D7E8F90}']
    function IsAvailable: Boolean;
    procedure SetWords(const AWords: TArray<string>);
    function GetWords: TArray<string>;
    procedure SetConfidenceThreshold(AValue: Double);
    function Start: Boolean;
    procedure Stop;
    procedure SetOnWakeDetected(ACallback: TProc<TWakeEvent>);
  end;

  IVoiceprint = interface
    ['{E5A6B7C8-D9E0-4BF1-3A4B-5C6D7E8F9001}']
    function EnrollProfile(const AUserLabel, APurpose, AOwnerApp: string;
      const ASamples: TArray<TBytes>; AThreshold: Double = 15.0): TVoiceProfileId;
    function DeleteProfile(const AId: TVoiceProfileId): Boolean;
    function ListProfiles(const AOwnerApp: string = ''): TArray<TVoiceProfileInfo>;
    function Verify(const AAudio: TBytes; const AProfileId: TVoiceProfileId): TVerifyResult;
    function Identify(const AAudio: TBytes): TVoiceProfileId;
  end;

  IIntentParser = interface
    ['{F6B7C8D9-E0F1-4C02-4B5C-6D7E8F900112}']
    function Parse(const AText: string; const ALocale: string = 'zh-CN'): TIntentResult;
    function RuleCount: Integer;
  end;

  ISpeechAudioCapture = interface
    ['{08E3B02D-10F5-4427-80B4-7A26336779D4}']
    function StartRecording: Boolean;
    procedure StopRecording;
    function GetAudioData: TSpeechAudioData;
    function GetPCMData: TBytes;
    function GetFloatSamples: TArray<Single>;
    function IsRecording: Boolean;
    function LastError: string;
    function SampleRate: Integer;
  end;

  TSpeechAudioUtils = record
    class function PCM16ToFloat(const APCMData: TBytes): TArray<Single>; static;
    class function FloatToPCM16(const AFloats: TArray<Single>): TBytes; static;
  end;

function SpeechRecognitionStatusToString(AStatus: TSpeechRecognitionStatus): string;

implementation

{$POINTERMATH ON}

{ TASROptions }

class function TASROptions.Create(const ALang: string; AMode: TASRMode;
  AMaxSec: Integer; ASilenceMs: Integer): TASROptions;
begin
  Result.Language := ALang;
  Result.Mode := AMode;
  Result.MaxSeconds := AMaxSec;
  Result.SilenceTimeoutMs := ASilenceMs;
end;

{ TTTSOptions }

class function TTTSOptions.Default: TTTSOptions;
begin
  Result.VoiceId := '';
  Result.Language := 'zh-CN';
  Result.Rate := 0;
  Result.Volume := 100;
end;

class function TSpeechAudioFormat.PCM16Mono(
  ASampleRate: Integer): TSpeechAudioFormat;
begin
  Result.Encoding := saePCM16;
  Result.SampleRate := ASampleRate;
  Result.Channels := 1;
  Result.BitsPerSample := 16;
end;

class function TSpeechAudioData.FromPCM16(const APCMData: TBytes;
  ASampleRate: Integer): TSpeechAudioData;
begin
  Result.Format := TSpeechAudioFormat.PCM16Mono(ASampleRate);
  Result.PCMData := Copy(APCMData);
end;

function TSpeechAudioData.IsEmpty: Boolean;
begin
  Result := Length(PCMData) = 0;
end;

function TSpeechAudioData.DurationMs: Integer;
var
  BytesPerSecond: Integer;
begin
  BytesPerSecond := Format.SampleRate * Format.Channels *
    (Format.BitsPerSample div 8);
  if BytesPerSecond <= 0 then
    Exit(0);
  Result := Round(Length(PCMData) * 1000.0 / BytesPerSecond);
end;

class function TSpeechRecognitionOptions.Default: TSpeechRecognitionOptions;
begin
  Result.Language := 'zh';
  Result.Cuid := 'DeepBase';
end;

class function TSpeechRecognitionResult.Succeeded(const AText,
  ARawResponse: string): TSpeechRecognitionResult;
begin
  Result.Success := True;
  Result.Text := AText;
  Result.Status := srsSuccess;
  Result.ErrorCode := '';
  Result.ErrorMessage := '';
  Result.RawResponse := ARawResponse;
end;

class function TSpeechRecognitionResult.Failed(AStatus: TSpeechRecognitionStatus;
  const ACode, AMessage, ARawResponse: string): TSpeechRecognitionResult;
begin
  Result.Success := False;
  Result.Text := '';
  Result.Status := AStatus;
  Result.ErrorCode := ACode;
  Result.ErrorMessage := AMessage;
  Result.RawResponse := ARawResponse;
end;

class function TSpeechAudioUtils.PCM16ToFloat(
  const APCMData: TBytes): TArray<Single>;
var
  I: Integer;
  SampleCount: Integer;
  Samples: PSmallInt;
begin
  SampleCount := Length(APCMData) div SizeOf(SmallInt);
  SetLength(Result, SampleCount);
  if SampleCount = 0 then
    Exit;

  Samples := PSmallInt(@APCMData[0]);
  for I := 0 to SampleCount - 1 do
    Result[I] := Samples[I] / 32768.0;
end;

class function TSpeechAudioUtils.FloatToPCM16(
  const AFloats: TArray<Single>): TBytes;
var
  I: Integer;
  LSample: Integer;
  LOut: PSmallInt;
begin
  SetLength(Result, Length(AFloats) * SizeOf(SmallInt));
  if Length(AFloats) = 0 then
    Exit;

  LOut := PSmallInt(@Result[0]);
  for I := 0 to High(AFloats) do
  begin
    LSample := Round(AFloats[I] * 32768.0);
    if LSample > 32767 then LSample := 32767
    else if LSample < -32768 then LSample := -32768;
    LOut[I] := SmallInt(LSample);
  end;
end;

function SpeechRecognitionStatusToString(
  AStatus: TSpeechRecognitionStatus): string;
begin
  case AStatus of
    srsSuccess: Result := 'success';
    srsEmptyAudio: Result := 'empty_audio';
    srsProviderNotReady: Result := 'provider_not_ready';
    srsHttpError: Result := 'http_error';
    srsParseError: Result := 'parse_error';
    srsServiceError: Result := 'service_error';
  else
    Result := 'internal_error';
  end;
end;

end.
