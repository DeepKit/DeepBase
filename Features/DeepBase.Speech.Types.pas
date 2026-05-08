unit DeepBase.Speech.Types;

interface

uses
  System.SysUtils;

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

  ISpeechRecognizer = interface
    ['{7B6B7E6C-0A88-4D7B-8D96-7303FE7F0470}']
    function CheckStatus(out AError: string): Boolean;
    function Recognize(const AAudio: TSpeechAudioData;
      const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
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
  end;

function SpeechRecognitionStatusToString(AStatus: TSpeechRecognitionStatus): string;

implementation

{$POINTERMATH ON}

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
