{ ============================================================================
  DeepBase.Speech.ASR.SenseVoice
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : SenseVoice offline ASR backend. Loads the SenseVoice ONNX model
                via DeepBase.Inference and performs:
                  PCM16 → FBank 80-dim → LFR stacking (7/6 → 560-dim)
                  → CMVN normalization → ONNX inference → CTC greedy decode
                Supports batch recognition and simulated streaming (partial
                decode every configurable interval).
  Model       : model.int8.onnx + tokens.txt (sherpa-onnx format)
  Languages   : zh / en / yue / ja / ko / auto
  ============================================================================ }

unit DeepBase.Speech.ASR.SenseVoice;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Math,
  DeepBase.Inference.Types,
  DeepBase.Speech.Types,
  DeepBase.Speech.FBank;

type
  TDeepBaseSenseVoiceASR = class(TInterfacedObject, ISpeechRecognizerEx)
  private
    FFBank: TFBankExtractor;
    FSession: IInferenceSession;
    FModelDir: string;
    FTokens: TArray<string>;
    FNegMean: TArray<Single>;
    FInvStddev: TArray<Single>;
    FAvailable: Boolean;
    FStatusError: string;
    FLanguage: string;
    FUseITN: Boolean;

    procedure EnsureInitialized;
    function FindModelDir: string;
    procedure LoadTokens;
    procedure ParseCMVN;
    function LanguageToInt(const ALanguage: string): Integer;
    function ExtractFeatures(const APCM16: TBytes): TArray<TArray<Single>>;
    function ApplyLFR(const AFrames: TArray<TArray<Single>>): TArray<TArray<Single>>;
    procedure ApplyCMVN(var AFeatures: TArray<TArray<Single>>);
    function RunInference(const AFeatures: TArray<TArray<Single>>;
      ALanguage: Integer): TArray<Single>;
    function DecodeCTC(const ALogits: TArray<Single>;
      ATimeSteps, AVocabSize: Integer): string;
    function RecognizeInternal(const APCM16: TBytes): string;
  public
    constructor Create;
    destructor Destroy; override;

    { ISpeechRecognizer }
    function CheckStatus(out AError: string): Boolean;
    function Recognize(const AAudio: TSpeechAudioData;
      const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;

    { ISpeechRecognizerEx }
    function IsAvailable: Boolean;
    function Kind: TASRBackendKind;
    function SupportsBatch: Boolean;
    function SupportsStreaming: Boolean;
    procedure LoadGrammar(const AWords: TArray<string>);

    property ModelDir: string read FModelDir write FModelDir;
  end;

  TDeepBaseSenseVoiceStream = class(TInterfacedObject, IASRStream)
  private
    FOwner: TDeepBaseSenseVoiceASR;
    FBuffer: TBytes;
    FOnPartial: TProc<TASRPartialResult>;
    FOnFinal: TProc<TSpeechRecognitionResult>;
    FRunning: Boolean;
    FStopEvent: TEvent;
    FWorker: TThread;
    FIntervalMs: Integer;
    procedure DoWork;
  public
    constructor Create(AOwner: TDeepBaseSenseVoiceASR;
      AIntervalMs: Integer = 500);
    destructor Destroy; override;

    procedure FeedAudio(const AChunk: TBytes);
    procedure SetOnPartial(ACallback: TProc<TASRPartialResult>);
    procedure SetOnFinal(ACallback: TProc<TSpeechRecognitionResult>);
    procedure Stop;
    function Running: Boolean;
  end;

var
  GlobalSenseVoiceASR: TDeepBaseSenseVoiceASR = nil;

implementation

uses
  DeepBase.Inference.Session,
  DeepBase.Inference.Service,
  DeepBase.Speech.Config,
  DeepBase.Speech.Registry,
  DeepBase.Config,
  DeepBase.Logging;

const
  LFR_WINDOW_SIZE  = 7;
  LFR_WINDOW_SHIFT = 6;
  SENSEVOICE_FBANK_DIM  = 80;
  SENSEVOICE_FEATURE_DIM = SENSEVOICE_FBANK_DIM * LFR_WINDOW_SIZE; // 560
  SENSEVOICE_VOCAB_SIZE  = 25055;
  BLANK_TOKEN = '<blank>';

{ --- Helper: Comma-separated CSV parser ----------------------------------- }

function ParseCommaList(const AText: string): TArray<string>;
var
  LStart, LPos: Integer;
  LList: TArray<string>;
  LCount: Integer;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  LCount := 0;
  SetLength(LList, Length(AText));
  LStart := 1;
  for LPos := 1 to Length(AText) do
  begin
    if AText[LPos] = ',' then
    begin
      LList[LCount] := Copy(AText, LStart, LPos - LStart);
      Inc(LCount);
      LStart := LPos + 1;
    end;
  end;
  LList[LCount] := Copy(AText, LStart, Length(AText) - LStart + 1);
  Inc(LCount);
  SetLength(Result, LCount);
  Move(LList[0], Result[0], LCount * SizeOf(string));
end;

{ --- TDeepBaseSenseVoiceASR ----------------------------------------------- }

constructor TDeepBaseSenseVoiceASR.Create;
begin
  inherited Create;
  FFBank := TFBankExtractor.Create(16000, SENSEVOICE_FBANK_DIM);
  FSession := nil;
  FTokens := nil;
  FNegMean := nil;
  FInvStddev := nil;
  FAvailable := False;
  FStatusError := 'Not initialized';
  FLanguage := SPEECH_DEFAULT_SV_LANGUAGE;
  FUseITN := SPEECH_DEFAULT_SV_USE_ITN = '1';
  FModelDir := '';
end;

destructor TDeepBaseSenseVoiceASR.Destroy;
begin
  if FSession <> nil then
    FSession.Dispose;
  FSession := nil;
  FreeAndNil(FFBank);
  inherited;
end;

procedure TDeepBaseSenseVoiceASR.EnsureInitialized;
var
  LModelPath: string;
begin
  if FAvailable then Exit;

  if FModelDir = '' then
    FModelDir := FindModelDir;
  if FModelDir = '' then
  begin
    FStatusError := 'SenseVoice model directory not found. ' +
      'Configure speech.sensevoice.model_dir or place model at D:\ProgramData\SenseVoice';
    Exit;
  end;

  LModelPath := IncludeTrailingPathDelimiter(FModelDir) + 'model.int8.onnx';
  if not FileExists(LModelPath) then
  begin
    FStatusError := 'SenseVoice model not found: ' + LModelPath;
    Exit;
  end;

  try
    if not TInferenceService.IsReady then
    begin
      FStatusError := 'Inference service not initialized';
      Exit;
    end;

    FSession := TInferenceService.CreateSession(LModelPath);
    LoadTokens;
    ParseCMVN;

    FAvailable := (FSession <> nil) and (Length(FTokens) > 0)
      and (Length(FNegMean) = SENSEVOICE_FEATURE_DIM);

    if FAvailable then
      FStatusError := ''
    else
      FStatusError := 'SenseVoice initialization incomplete';
  except
    on E: Exception do
    begin
      FAvailable := False;
      FStatusError := 'SenseVoice init failed: ' + E.Message;
      Logger.ErrorFmt('SenseVoice: init failed: %s', [E.Message], 'Speech');
    end;
  end;
end;

function TDeepBaseSenseVoiceASR.FindModelDir: string;
var
  LConfigDir: string;
begin
  // 1. ConfigDB override
  LConfigDir := GetConfig(SPEECH_CFG_SV_MODEL_DIR, SPEECH_DEFAULT_SV_MODEL_DIR);
  if LConfigDir <> '' then
  begin
    if DirectoryExists(LConfigDir) then
      Exit(LConfigDir);
  end;

  // 2. Default location
  if DirectoryExists('D:\ProgramData\SenseVoice') then
    Exit('D:\ProgramData\SenseVoice');

  Result := '';
end;

procedure TDeepBaseSenseVoiceASR.LoadTokens;
var
  LTokenPath: string;
  LLines: TStringList;
  I: Integer;
begin
  LTokenPath := IncludeTrailingPathDelimiter(FModelDir) + 'tokens.txt';
  if not FileExists(LTokenPath) then
  begin
    SetLength(FTokens, 0);
    Exit;
  end;

  LLines := TStringList.Create;
  try
    LLines.LoadFromFile(LTokenPath, TEncoding.UTF8);
    SetLength(FTokens, LLines.Count);
    for I := 0 to LLines.Count - 1 do
      FTokens[I] := LLines[I];
  finally
    LLines.Free;
  end;
end;

procedure TDeepBaseSenseVoiceASR.ParseCMVN;
var
  LRaw: string;
  LParts: TArray<string>;
  I: Integer;
begin
  if FSession = nil then Exit;

  LRaw := FSession.GetCustomMetadata('neg_mean');
  if LRaw <> '' then
  begin
    LParts := ParseCommaList(LRaw);
    SetLength(FNegMean, Length(LParts));
    for I := 0 to High(LParts) do
      FNegMean[I] := StrToFloatDef(LParts[I], 0);
  end;

  LRaw := FSession.GetCustomMetadata('inv_stddev');
  if LRaw <> '' then
  begin
    LParts := ParseCommaList(LRaw);
    SetLength(FInvStddev, Length(LParts));
    for I := 0 to High(LParts) do
      FInvStddev[I] := StrToFloatDef(LParts[I], 1);
  end;
end;

function TDeepBaseSenseVoiceASR.LanguageToInt(
  const ALanguage: string): Integer;
var
  LLower: string;
begin
  LLower := LowerCase(ALanguage);
  if (LLower = 'auto') or (LLower = '') then
    Result := 0
  else if (LLower = 'zh') or (LLower = 'zh-cn') then
    Result := 3
  else if (LLower = 'en') or (LLower = 'en-us') then
    Result := 4
  else if (LLower = 'yue') then
    Result := 7
  else if (LLower = 'ja') or (LLower = 'ja-jp') then
    Result := 11
  else if (LLower = 'ko') or (LLower = 'ko-kr') then
    Result := 12
  else
    Result := 0;
end;

function TDeepBaseSenseVoiceASR.ExtractFeatures(
  const APCM16: TBytes): TArray<TArray<Single>>;
var
  LFBankFrames: TArray<TArray<Single>>;
begin
  LFBankFrames := FFBank.Extract(APCM16);
  if Length(LFBankFrames) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  Result := ApplyLFR(LFBankFrames);
  ApplyCMVN(Result);
end;

function TDeepBaseSenseVoiceASR.ApplyLFR(
  const AFrames: TArray<TArray<Single>>): TArray<TArray<Single>>;
var
  LNumFrames, LOutFrames, I, J, K, LStart: Integer;
begin
  LNumFrames := Length(AFrames);
  if LNumFrames < LFR_WINDOW_SIZE then
  begin
    // Pad with zeros if too short
    SetLength(Result, 1);
    SetLength(Result[0], SENSEVOICE_FEATURE_DIM);
    for J := 0 to SENSEVOICE_FEATURE_DIM - 1 do
    begin
      K := J div SENSEVOICE_FBANK_DIM;
      I := J mod SENSEVOICE_FBANK_DIM;
      if K < LNumFrames then
        Result[0][J] := AFrames[K][I]
      else
        Result[0][J] := 0;
    end;
    Exit;
  end;

  LOutFrames := (LNumFrames - LFR_WINDOW_SIZE) div LFR_WINDOW_SHIFT + 1;
  SetLength(Result, LOutFrames);

  for I := 0 to LOutFrames - 1 do
  begin
    SetLength(Result[I], SENSEVOICE_FEATURE_DIM);
    LStart := I * LFR_WINDOW_SHIFT;
    for J := 0 to LFR_WINDOW_SIZE - 1 do
      for K := 0 to SENSEVOICE_FBANK_DIM - 1 do
        Result[I][J * SENSEVOICE_FBANK_DIM + K] := AFrames[LStart + J][K];
  end;
end;

procedure TDeepBaseSenseVoiceASR.ApplyCMVN(
  var AFeatures: TArray<TArray<Single>>);
var
  I, J: Integer;
begin
  if Length(FNegMean) <> SENSEVOICE_FEATURE_DIM then Exit;
  if Length(FInvStddev) <> SENSEVOICE_FEATURE_DIM then Exit;

  for I := 0 to High(AFeatures) do
    for J := 0 to SENSEVOICE_FEATURE_DIM - 1 do
      AFeatures[I][J] := (AFeatures[I][J] - FNegMean[J]) * FInvStddev[J];
end;

function TDeepBaseSenseVoiceASR.RunInference(
  const AFeatures: TArray<TArray<Single>>;
  ALanguage: Integer): TArray<Single>;
var
  LNumFrames: Integer;
  LFlatData: TArray<Single>;
  LInputs: TArray<TInferenceInput>;
  LOutput: TInferenceOutput;
  LLogits: TArray<Single>;
  LShape: TArray<Int64>;
  I, J: Integer;
  LTimeSteps: Int64;
begin
  LNumFrames := Length(AFeatures);
  if LNumFrames = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // Flatten features to [1, T, 560]
  SetLength(LFlatData, LNumFrames * SENSEVOICE_FEATURE_DIM);
  for I := 0 to LNumFrames - 1 do
    for J := 0 to SENSEVOICE_FEATURE_DIM - 1 do
      LFlatData[I * SENSEVOICE_FEATURE_DIM + J] := AFeatures[I][J];

  SetLength(LInputs, 4);

  // x: [1, T, 560] float32
  LInputs[0] := TInferenceInput.Float('x', LFlatData,
    TArray<Int64>.Create(1, LNumFrames, SENSEVOICE_FEATURE_DIM));

  // x_length: [1] int32
  LInputs[1] := TInferenceInput.Int32('x_length', LNumFrames,
    TArray<Int64>.Create(1));

  // language: [1] int32
  LInputs[2] := TInferenceInput.Int32('language', ALanguage,
    TArray<Int64>.Create(1));

  // text_norm: [1] int32 (14 = with_itn, 15 = without_itn)
  if FUseITN then
    LInputs[3] := TInferenceInput.Int32('text_norm', 14,
      TArray<Int64>.Create(1))
  else
    LInputs[3] := TInferenceInput.Int32('text_norm', 15,
      TArray<Int64>.Create(1));

  LOutput := (FSession as TInferenceSession).RunTyped(LInputs);

  if not LOutput.Success then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // Find the logits output
  for I := 0 to High(LOutput.OutputNames) do
  begin
    if LOutput.OutputNames[I] = 'logits' then
    begin
      LShape := LOutput.OutputShapes[I];
      LTimeSteps := 1;
      for J := 0 to High(LShape) - 1 do
        LTimeSteps := LTimeSteps * LShape[J];
      LTimeSteps := LTimeSteps div SENSEVOICE_VOCAB_SIZE;

      // Copy float data
      SetLength(LLogits, Length(LOutput.OutputData[I]) div SizeOf(Single));
      if Length(LLogits) > 0 then
        Move(LOutput.OutputData[I][0], LLogits[0], Length(LLogits) * SizeOf(Single));
      Result := LLogits;
      Exit;
    end;
  end;

  SetLength(Result, 0);
end;

function TDeepBaseSenseVoiceASR.DecodeCTC(const ALogits: TArray<Single>;
  ATimeSteps, AVocabSize: Integer): string;
var
  I, T: Integer;
  LMaxIdx, LPrevIdx: Integer;
  LMaxVal: Single;
  LTokenIds: TArray<Integer>;
  LCount: Integer;
  LToken: string;
  LSB: TStringBuilder;
begin
  Result := '';
  if (ATimeSteps <= 0) or (AVocabSize <= 0) then Exit;
  if Length(ALogits) < ATimeSteps * AVocabSize then Exit;

  // Greedy: argmax per timestep
  SetLength(LTokenIds, ATimeSteps);
  for T := 0 to ATimeSteps - 1 do
  begin
    LMaxIdx := 0;
    LMaxVal := ALogits[T * AVocabSize];
    for I := 1 to AVocabSize - 1 do
    begin
      if ALogits[T * AVocabSize + I] > LMaxVal then
      begin
        LMaxVal := ALogits[T * AVocabSize + I];
        LMaxIdx := I;
      end;
    end;
    LTokenIds[T] := LMaxIdx;
  end;

  // CTC collapse: remove blanks and consecutive duplicates
  LPrevIdx := -1;
  LCount := 0;
  SetLength(LTokenIds, ATimeSteps); // reuse as collapsed output
  // First pass: count valid tokens
  var LValid: TArray<Integer>;
  SetLength(LValid, ATimeSteps);
  for T := 0 to ATimeSteps - 1 do
  begin
    if (LTokenIds[T] = LPrevIdx) then
    begin
      // duplicate, skip
    end
    else
    begin
      LValid[LCount] := LTokenIds[T];
      Inc(LCount);
      LPrevIdx := LTokenIds[T];
    end;
  end;

  // Build string, skipping blank token
  LSB := TStringBuilder.Create;
  try
    for T := 0 to LCount - 1 do
    begin
      if (LValid[T] >= 0) and (LValid[T] < Length(FTokens)) then
      begin
        LToken := FTokens[LValid[T]];
        if (LToken <> BLANK_TOKEN) and
           (LToken <> '<s>') and (LToken <> '</s>') and
           (LToken <> '<unk>') then
          LSB.Append(LToken);
      end;
    end;
    Result := LSB.ToString;
  finally
    LSB.Free;
  end;
end;

function TDeepBaseSenseVoiceASR.RecognizeInternal(
  const APCM16: TBytes): string;
var
  LFeatures: TArray<TArray<Single>>;
  LLogits: TArray<Single>;
  LTimeSteps: Integer;
  LLangInt: Integer;
begin
  Result := '';
  EnsureInitialized;
  if not FAvailable then Exit;

  LFeatures := ExtractFeatures(APCM16);
  if Length(LFeatures) = 0 then Exit;

  LLangInt := LanguageToInt(FLanguage);
  LLogits := RunInference(LFeatures, LLangInt);
  if Length(LLogits) = 0 then Exit;

  LTimeSteps := Length(LFeatures);
  Result := DecodeCTC(LLogits, LTimeSteps, SENSEVOICE_VOCAB_SIZE);
end;

{ --- ISpeechRecognizer ---------------------------------------------------- }

function TDeepBaseSenseVoiceASR.CheckStatus(out AError: string): Boolean;
begin
  EnsureInitialized;
  AError := FStatusError;
  Result := FAvailable;
end;

function TDeepBaseSenseVoiceASR.Recognize(const AAudio: TSpeechAudioData;
  const AOptions: TSpeechRecognitionOptions): TSpeechRecognitionResult;
var
  LText: string;
begin
  if AAudio.IsEmpty then
    Exit(TSpeechRecognitionResult.Failed(srsEmptyAudio, 'EMPTY',
      'No audio data provided'));

  EnsureInitialized;
  if not FAvailable then
    Exit(TSpeechRecognitionResult.Failed(srsProviderNotReady, 'NOT_READY',
      FStatusError));

  try
    LText := RecognizeInternal(AAudio.PCMData);
    Result := TSpeechRecognitionResult.Succeeded(LText, '');
  except
    on E: Exception do
      Result := TSpeechRecognitionResult.Failed(srsInternalError, 'INFERENCE_ERROR',
        E.Message);
  end;
end;

{ --- ISpeechRecognizerEx -------------------------------------------------- }

function TDeepBaseSenseVoiceASR.IsAvailable: Boolean;
begin
  EnsureInitialized;
  Result := FAvailable;
end;

function TDeepBaseSenseVoiceASR.Kind: TASRBackendKind;
begin
  Result := abkSenseVoice;
end;

function TDeepBaseSenseVoiceASR.SupportsBatch: Boolean;
begin
  Result := True;
end;

function TDeepBaseSenseVoiceASR.SupportsStreaming: Boolean;
begin
  Result := True;
end;

procedure TDeepBaseSenseVoiceASR.LoadGrammar(const AWords: TArray<string>);
begin
  // SenseVoice does not support grammar mode; silent no-op
end;

{ --- TDeepBaseSenseVoiceStream --------------------------------------------- }

constructor TDeepBaseSenseVoiceStream.Create(
  AOwner: TDeepBaseSenseVoiceASR; AIntervalMs: Integer);
begin
  inherited Create;
  FOwner := AOwner;
  FIntervalMs := AIntervalMs;
  FRunning := True;
  FStopEvent := TEvent.Create(nil, True, False, '');
  SetLength(FBuffer, 0);

  FWorker := TThread.CreateAnonymousThread(
    procedure
    begin
      DoWork;
    end);
  FWorker.FreeOnTerminate := False;
  FWorker.Start;
end;

destructor TDeepBaseSenseVoiceStream.Destroy;
begin
  if FRunning then
    Stop;
  FWorker.WaitFor;
  FreeAndNil(FWorker);
  FreeAndNil(FStopEvent);
  inherited;
end;

procedure TDeepBaseSenseVoiceStream.DoWork;
var
  LWaitResult: TWaitResult;
  LText: string;
  LPartial: TASRPartialResult;
begin
  while FRunning do
  begin
    LWaitResult := FStopEvent.WaitFor(FIntervalMs);
    if LWaitResult = wrSignaled then
      Break;

    if not FRunning then Break;

    // Partial decode
    if (Length(FBuffer) > 0) and Assigned(FOnPartial) then
    begin
      try
        LText := FOwner.RecognizeInternal(Copy(FBuffer));
        LPartial.Text := LText;
        LPartial.Confidence := 0.8;
        LPartial.IsFinal := False;
        TThread.Synchronize(nil,
          procedure
          begin
            if Assigned(FOnPartial) then
              FOnPartial(LPartial);
          end);
      except
        // Partial decode failure is non-critical
      end;
    end;
  end;
end;

procedure TDeepBaseSenseVoiceStream.FeedAudio(const AChunk: TBytes);
var
  LOldLen: Integer;
begin
  if not FRunning then Exit;
  LOldLen := Length(FBuffer);
  SetLength(FBuffer, LOldLen + Length(AChunk));
  if Length(AChunk) > 0 then
    Move(AChunk[0], FBuffer[LOldLen], Length(AChunk));
end;

procedure TDeepBaseSenseVoiceStream.SetOnPartial(
  ACallback: TProc<TASRPartialResult>);
begin
  FOnPartial := ACallback;
end;

procedure TDeepBaseSenseVoiceStream.SetOnFinal(
  ACallback: TProc<TSpeechRecognitionResult>);
begin
  FOnFinal := ACallback;
end;

procedure TDeepBaseSenseVoiceStream.Stop;
var
  LText: string;
  LResult: TSpeechRecognitionResult;
begin
  if not FRunning then Exit;
  FRunning := False;
  FStopEvent.SetEvent;

  // Final decode on accumulated buffer
  if Assigned(FOnFinal) and (Length(FBuffer) > 0) then
  begin
    try
      LText := FOwner.RecognizeInternal(Copy(FBuffer));
      LResult := TSpeechRecognitionResult.Succeeded(LText, '');
    except
      on E: Exception do
        LResult := TSpeechRecognitionResult.Failed(srsInternalError,
          'INFERENCE_ERROR', E.Message);
    end;
    TThread.Synchronize(nil,
      procedure
      begin
        if Assigned(FOnFinal) then
          FOnFinal(LResult);
      end);
  end;

  // Clear buffer
  SetLength(FBuffer, 0);
end;

function TDeepBaseSenseVoiceStream.Running: Boolean;
begin
  Result := FRunning;
end;

{ --- Registration ---------------------------------------------------------- }

procedure RegisterSenseVoiceBackend;
var
  LInfo: TSpeechBackendInfo;
begin
  FillChar(LInfo, SizeOf(LInfo), 0);
  LInfo.Kind := sbkASR;
  LInfo.Name := 'SenseVoice';
  LInfo.IsCloud := False;
  LInfo.RequiresMic := True;
  LInfo.SupportsBatch := True;
  LInfo.SupportsStreaming := True;
  LInfo.SupportsGrammar := False;
  LInfo.Enabled := True;
  LInfo.Priority := 5;
  LInfo.IsAvailableFunc :=
    function: Boolean
    begin
      if GlobalSenseVoiceASR = nil then
        GlobalSenseVoiceASR := TDeepBaseSenseVoiceASR.Create;
      Result := GlobalSenseVoiceASR.IsAvailable;
    end;
  TSpeechRegistry.Register(LInfo);
end;

initialization
  RegisterSenseVoiceBackend;
  GlobalSenseVoiceASR := TDeepBaseSenseVoiceASR.Create;

finalization
  FreeAndNil(GlobalSenseVoiceASR);

end.
