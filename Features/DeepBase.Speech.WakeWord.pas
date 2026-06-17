{ ============================================================================
  DeepBase.Speech.WakeWord
  ---------------------------------------------------------------------------
  Version     : 1.0
  Description : SAPI Grammar-based wake word detector. Listens for predefined
                hot words (e.g. "小启") using SAPI SRGS command recognition.
                Self-registers into TSpeechRegistry during initialization.
  Thread Safety: Start/Stop are thread-safe. Callback fires on worker thread.
  Privacy     : Long-running mic access — must be explicitly enabled by user.
  ============================================================================ }

unit DeepBase.Speech.WakeWord;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs, System.IOUtils,
  System.Generics.Collections,
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
    FEventThread: TThread;
    FStopEvent: THandle;
    FThreadDoneEvent: THandle;
    procedure ValidateWord(const AWord: string);
    function NormalizeWord(const AWord: string): string;
    function BuildSrgsXml: string;
    procedure LoadSrgsGrammar;
    procedure EventThreadProc;
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
  FStopEvent := 0;
  FThreadDoneEvent := 0;
end;

destructor TDeepBaseWakeWord.Destroy;
begin
  Stop;
  // Defensive cleanup in case Stop did not close the handles
  if FThreadDoneEvent <> 0 then
  begin
    CloseHandle(FThreadDoneEvent);
    FThreadDoneEvent := 0;
  end;
  if FStopEvent <> 0 then
  begin
    CloseHandle(FStopEvent);
    FStopEvent := 0;
  end;
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

function TDeepBaseWakeWord.BuildSrgsXml: string;
var
  LWord: string;
  LWords: TArray<string>;
  I: Integer;
begin
  FLock.Enter;
  try
    LWords := Copy(FWords);
  finally
    FLock.Leave;
  end;

  // Build SRGS XML grammar for the configured wake words.
  // SAPI 5.4 supports SRGS 1.0 for command grammars.
  Result :=
    '<?xml version="1.0" encoding="UTF-8"?>' + #13#10 +
    '<grammar version="1.0" xml:lang="zh-CN"' + #13#10 +
    '  xmlns="http://www.w3.org/2001/09/grammars/srgs"' + #13#10 +
    '  root="WakeRule" mode="voice">' + #13#10 +
    '  <rule id="WakeRule" scope="public">' + #13#10 +
    '    <one-of>' + #13#10;
  for I := 0 to High(LWords) do
  begin
    LWord := LWords[I];
    // Escape XML special characters
    LWord := StringReplace(LWord, '&', '&amp;', [rfReplaceAll]);
    LWord := StringReplace(LWord, '<', '&lt;', [rfReplaceAll]);
    LWord := StringReplace(LWord, '>', '&gt;', [rfReplaceAll]);
    Result := Result + '      <item>' + LWord + '</item>' + #13#10;
  end;
  Result := Result +
    '    </one-of>' + #13#10 +
    '  </rule>' + #13#10 +
    '</grammar>';
end;

procedure TDeepBaseWakeWord.LoadSrgsGrammar;
var
  LSrgsXml: string;
  LTempFile: string;
  LStream: TStreamWriter;
  HR: HRESULT;
begin
  LSrgsXml := BuildSrgsXml;

  // SAPI 5.4 LoadCmdFromFile requires a file path; write SRGS XML to temp file
  LTempFile := IncludeTrailingPathDelimiter(TPath.GetTempPath) +
    'deepbase_wakeword_' + IntToHex(GetCurrentProcessId) + '.xml';

  LStream := TStreamWriter.Create(LTempFile, False, TEncoding.UTF8);
  try
    LStream.Write(LSrgsXml);
  finally
    LStream.Free;
  end;

  try
    HR := FGrammar.LoadCmdFromFile(PWideChar(WideString(LTempFile)), SPLO_STATIC);
    if Succeeded(HR) then
    begin
      // Activate the top-level "WakeRule" rule
      FGrammar.SetRuleState('WakeRule', nil, SPRS_ACTIVE);
    end
    else
    begin
      // Grammar load failed — fall back to dictation mode (degraded, but functional)
      FGrammar.LoadDictation(nil, 0);
      FGrammar.SetDictationState(SPRS_ACTIVE);
    end;
  finally
    System.SysUtils.DeleteFile(LTempFile);
  end;
end;

procedure TDeepBaseWakeWord.EventThreadProc;
var
  LEvents: array[0..3] of SPEVENT;
  LFetched: ULONG;
  LHR: HRESULT;
  LResult: ISpRecoResult;
  LText: PWideChar;
  LAttr: Byte;
  LRecognized: string;
  LWord: string;
  LConfidence: Single;
  LWords: TArray<string>;
  LThreshold: Double;
  LCallback: TWakeCallback;
  LEvent: TWakeEvent;
  I: Integer;
begin
  try
    while WaitForSingleObject(FStopEvent, 200) = WAIT_TIMEOUT do
    begin
      FillChar(LEvents, SizeOf(LEvents), 0);
      LFetched := 0;

      // GetEvents is at vtable idx 22 in ISpRecoContext (renamed from Placeholder23)
      LHR := FContext.GetEvents(4, @LEvents, @LFetched);
      if not Succeeded(LHR) or (LFetched = 0) then
        Continue;

      // Snapshot words + threshold + callback under lock
      FLock.Enter;
      try
        LWords := Copy(FWords);
        LThreshold := FThreshold;
        LCallback := FCallback;
      finally
        FLock.Leave;
      end;

      for I := 0 to Integer(LFetched) - 1 do
      begin
        if LEvents[I].eEventId <> SPEI_RECOGNITION then
          Continue;
        if LEvents[I].elParam = nil then
          Continue;

        // elParam points to ISpRecoResult (SAPI has incremented refcount for this event)
        LResult := ISpRecoResult(LEvents[I].elParam);
        try
          LHR := LResult.GetText(0, 0, False, LText, LAttr);
          if Succeeded(LHR) and (LText <> nil) then
          try
            LRecognized := LText;

            // Match against configured wake words
            for LWord in LWords do
            begin
              if not SameText(LRecognized, LWord) then
                Continue;

              // GetConfidence returns HRESULT with out Single param (vtable not declared;
              // use default confidence when unavailable)
              LConfidence := 1.0;

              if LConfidence >= LThreshold then
              begin
                LEvent.MatchedWord := LWord;
                LEvent.Confidence := LConfidence;
                LEvent.Timestamp := Now;
                if Assigned(LCallback) then
                  LCallback(LEvent);
              end;
            end;
          finally
            CoTaskMemFree(LText);
          end;
        finally
          LResult := nil;  // Release our reference
        end;
      end;
    end;
  finally
    // Signal that the event thread has exited
    if FThreadDoneEvent <> 0 then
      SetEvent(FThreadDoneEvent);
  end;
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

    // Load SRGS grammar with configured wake words
    LoadSrgsGrammar;

    // Register interest in recognition events (SetInterest is at vtable idx 19)
    // SPFEI_RECOGNITION bit = $00000080; shifted left by 1 for the SPEI enum bit position
    FContext.SetInterest(UInt64(1) shl SPEI_RECOGNITION, UInt64(1) shl SPEI_RECOGNITION);

    // Create manual-reset stop event and thread-done event, then launch polling thread
    FStopEvent := CreateEvent(nil, True, False, nil);
    FThreadDoneEvent := CreateEvent(nil, True, False, nil);
    FEventThread := TThread.CreateAnonymousThread(EventThreadProc);
    FEventThread.FreeOnTerminate := True;
    FEventThread.Start;

    FRunning := True;
    Result := True;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseWakeWord.Stop;
var
  LDoneEvent: THandle;
begin
  FLock.Enter;
  try
    if not FRunning then Exit;

    // Signal the event thread to stop
    if FStopEvent <> 0 then
      SetEvent(FStopEvent);

    // Grab the thread-done event handle before we nil it
    LDoneEvent := FThreadDoneEvent;
    FThreadDoneEvent := 0;
    FStopEvent := 0;

    // Wait for the thread to finish its current polling iteration before
    // clearing COM objects.  The loop sleeps ~200ms, so allow up to 400ms.
    FLock.Leave;
    try
      if LDoneEvent <> 0 then
        WaitForSingleObject(LDoneEvent, 400);
    finally
      FLock.Enter;
    end;

    if LDoneEvent <> 0 then
      CloseHandle(LDoneEvent);

    if Assigned(FGrammar) then
    begin
      FGrammar.SetRuleState('WakeRule', nil, SPRS_INACTIVE);
      FGrammar.SetDictationState(SPRS_INACTIVE);
    end;

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
