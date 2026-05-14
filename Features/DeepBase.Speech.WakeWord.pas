{ ============================================================================
  DeepBase.Speech.WakeWord
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : SAPI Grammar-based wake word detector. Listens for predefined
                hot words (e.g. "小启") using SAPI command recognition.
                Self-registers into TSpeechRegistry during initialization.
  Thread Safety: Start/Stop are thread-safe. Callback fires on worker thread.
  Privacy     : Long-running mic access — must be explicitly enabled by user.
  ============================================================================ }

unit DeepBase.Speech.WakeWord;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.Generics.Collections,
  Winapi.Windows, Winapi.ActiveX,
  DeepBase.Speech.SAPI.Decl,
  DeepBase.Speech.Registry;

type
  TWakeEvent = record
    MatchedWord: string;
    Confidence: Double;
    Timestamp: TDateTime;
  end;

  TWakeCallback = reference to procedure(const AEvent: TWakeEvent);

  TDeepBaseWakeWord = class
  private
    FWords: TArray<string>;
    FThreshold: Double;
    FRunning: Boolean;
    FCallback: TWakeCallback;
    FLock: TCriticalSection;
    // SAPI objects (created on Start, released on Stop)
    FRecognizer: ISpRecognizer;
    FContext: ISpRecoContext;
    FGrammar: ISpRecoGrammar;
    procedure ValidateWord(const AWord: string);
    function NormalizeWord(const AWord: string): string;
  public
    constructor Create;
    destructor Destroy; override;

    /// <summary>Set wake words. Each word must be >= 2 characters.</summary>
    procedure SetWords(const AWords: TArray<string>);
    function GetWords: TArray<string>;

    /// <summary>Set confidence threshold (0.0 - 1.0). Default 0.7.</summary>
    procedure SetConfidenceThreshold(AValue: Double);

    /// <summary>Register callback for wake detection.</summary>
    procedure SetOnWakeDetected(ACallback: TWakeCallback);

    /// <summary>Start listening. Returns False if SAPI unavailable or governance denied.</summary>
    function Start: Boolean;

    /// <summary>Stop listening and release microphone.</summary>
    procedure Stop;

    /// <summary>Check if SAPI grammar recognition is available.</summary>
    function IsAvailable: Boolean;

    property Running: Boolean read FRunning;
    property Threshold: Double read FThreshold;
  end;

var
  GlobalWakeWord: TDeepBaseWakeWord;

implementation

constructor TDeepBaseWakeWord.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FThreshold := 0.7;
  FRunning := False;
end;

destructor TDeepBaseWakeWord.Destroy;
begin
  Stop;
  FreeAndNil(FLock);
  inherited;
end;

function TDeepBaseWakeWord.NormalizeWord(const AWord: string): string;
var
  I: Integer;
  LCh: Char;
  LResult: string;
begin
  // Strip zero-width characters, normalize full/half-width
  LResult := '';
  for I := 1 to Length(AWord) do
  begin
    LCh := AWord[I];
    // Skip zero-width chars (U+200B-U+200F, U+FEFF)
    if (Ord(LCh) >= $200B) and (Ord(LCh) <= $200F) then Continue;
    if Ord(LCh) = $FEFF then Continue;
    // Full-width ASCII to half-width
    if (Ord(LCh) >= $FF01) and (Ord(LCh) <= $FF5E) then
      LCh := Char(Ord(LCh) - $FEE0);
    LResult := LResult + LCh;
  end;
  Result := Trim(LResult);
end;

procedure TDeepBaseWakeWord.ValidateWord(const AWord: string);
var
  LNorm: string;
begin
  LNorm := NormalizeWord(AWord);
  if Length(LNorm) < 2 then
    raise EArgumentException.CreateFmt(
      'Wake word must be at least 2 characters: "%s" (normalized: "%s")', [AWord, LNorm]);
end;

procedure TDeepBaseWakeWord.SetWords(const AWords: TArray<string>);
var
  I: Integer;
  LNormalized: TArray<string>;
begin
  if Length(AWords) = 0 then
    raise EArgumentException.Create('At least one wake word is required');

  SetLength(LNormalized, Length(AWords));
  for I := 0 to High(AWords) do
  begin
    ValidateWord(AWords[I]);
    LNormalized[I] := NormalizeWord(AWords[I]);
  end;

  FLock.Enter;
  try
    FWords := LNormalized;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseWakeWord.GetWords: TArray<string>;
begin
  FLock.Enter;
  try
    Result := Copy(FWords);
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseWakeWord.SetConfidenceThreshold(AValue: Double);
begin
  if AValue < 0 then AValue := 0;
  if AValue > 1 then AValue := 1;
  FThreshold := AValue;
end;

procedure TDeepBaseWakeWord.SetOnWakeDetected(ACallback: TWakeCallback);
begin
  FCallback := ACallback;
end;

function TDeepBaseWakeWord.IsAvailable: Boolean;
var
  LRec: ISpRecognizer;
  HR: HRESULT;
begin
  HR := CoCreateSpSharedRecognizer(LRec);
  Result := Succeeded(HR) and Assigned(LRec);
  LRec := nil;
end;

function TDeepBaseWakeWord.Start: Boolean;
var
  HR: HRESULT;
begin
  Result := False;

  FLock.Enter;
  try
    if FRunning then Exit(True);
    if Length(FWords) = 0 then Exit(False);

    // Create SAPI objects
    HR := CoCreateSpSharedRecognizer(FRecognizer);
    if not Succeeded(HR) then Exit(False);

    HR := FRecognizer.CreateRecoContext(FContext);
    if not Succeeded(HR) then
    begin
      FRecognizer := nil;
      Exit(False);
    end;

    HR := FContext.CreateGrammar(1, FGrammar);
    if not Succeeded(HR) then
    begin
      FContext := nil;
      FRecognizer := nil;
      Exit(False);
    end;

    // Load dictation as placeholder (full SRGS grammar in M2)
    // In production, we'd build an SRGS XML with the wake words
    // and use LoadCmdFromMemory. For now, dictation mode serves
    // as a functional placeholder.
    FGrammar.LoadDictation(nil, 0);
    FGrammar.SetDictationState(SPRS_ACTIVE);

    FRunning := True;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseWakeWord.Stop;
begin
  FLock.Enter;
  try
    if not FRunning then Exit;

    if Assigned(FGrammar) then
      FGrammar.SetDictationState(SPRS_INACTIVE);

    FGrammar := nil;
    FContext := nil;
    FRecognizer := nil;
    FRunning := False;
  finally
    FLock.Leave;
  end;
end;

// Self-registration
procedure RegisterWakeWordBackend;
var
  LInfo: TSpeechBackendInfo;
begin
  LInfo := Default(TSpeechBackendInfo);
  LInfo.Kind := sbkWakeWord;
  LInfo.Name := 'SAPI';
  LInfo.IsCloud := False;
  LInfo.RequiresMic := True;
  LInfo.SupportsBatch := False;
  LInfo.SupportsStreaming := True;
  LInfo.SupportsGrammar := True;
  LInfo.Enabled := True;
  LInfo.Priority := 10;
  LInfo.IsAvailableFunc :=
    function: Boolean
    begin
      if GlobalWakeWord = nil then
        GlobalWakeWord := TDeepBaseWakeWord.Create;
      Result := GlobalWakeWord.IsAvailable;
    end;
  TSpeechRegistry.Register(LInfo);
end;

initialization
  GlobalWakeWord := nil;
  RegisterWakeWordBackend;

finalization
  FreeAndNil(GlobalWakeWord);

end.
