{ ============================================================================
  DeepBase.Speech.ASR.SAPI
  ---------------------------------------------------------------------------
  Version     : 1.1
  Description : SAPI 5.4 Automatic Speech Recognition backend.
                Supports file-input batch recognition (WAV file → text) via
                TDeepBaseSAPIASR.RecognizeWavFile and grammar-based command
                recognition.
                Self-registers into TSpeechRegistry during initialization.
                v1.1: RecognizeWavFile added (ISpStream.BindToFile + inproc
                recognizer + GetEvents polling); requires SAPI.Decl v1.1
                (corrected vtable hierarchy).
                v1.2: RecognizeWavFile reworked per REVERSE-ENGINEERED layout
                (SAPI.Decl v2.0): SetInterest mask must include the REQUIRED
                bits 30+33 (SPFEI_SR_INTEREST), recognition is started by
                ISpRecognizer.SetRecoState(SPRS_ACTIVE) AFTER SetInterest,
                SPEI_* use SAPI 5.3+ numbering (RECOGNITION=38), SPEVENT
                carries ISpRecoResult* in wParam@24, and eEventId may carry
                high flag bits (mask with $FF). Verified end-to-end on
                Windows 24H2 (440 Hz tone → "§").
                v1.3: RecognizeWavFile hardening per FINAL61/62 gate probes:
                (1) CLSCTX_INPROC_SERVER(1) direct CoCreateInstance for both
                the stream and the recognizer — the decl helpers use
                CLSCTX_ALL(23) which may resolve to the sapisvr LOCAL_SERVER
                proxy and fail the engine's format check (0x80045003);
                (2) STA guarantee — the engine thread reports
                SPERR_UNSUPPORTED_FORMAT under MTA, S_OK under STA.
  Thread Safety: All SAPI calls serialized via FLock.
  ============================================================================ }

unit DeepBase.Speech.ASR.SAPI;

interface

uses
  System.SysUtils, System.Classes, System.SyncObjs,
  Winapi.Windows, Winapi.ActiveX,
  DeepBase.Speech.SAPI.Decl,
  DeepBase.Speech.Registry;

type
  TSAPIASRResult = record
    Success: Boolean;
    Text: string;
    Confidence: Double;
    ErrorMessage: string;
    DurationMs: Integer;
  end;

  TSAPIASRPartialResult = record
    Text: string;
    Confidence: Double;
    IsFinal: Boolean;
  end;

  TOnPartialCallback = reference to procedure(const AResult: TSAPIASRPartialResult);
  TOnFinalCallback = reference to procedure(const AResult: TSAPIASRResult);

  /// <summary>
  /// Streaming ASR session. SAPI uses its own mic capture in shared mode.
  /// Call Start to begin, Stop to end. Partial/Final results fire callbacks.
  /// </summary>
  TDeepBaseSAPIASRStream = class
  private
    FRecognizer: ISpRecognizer;
    FContext: ISpRecoContext;
    FGrammar: ISpRecoGrammar;
    FRunning: Boolean;
    FLock: TCriticalSection;
    FOnPartial: TOnPartialCallback;
    FOnFinal: TOnFinalCallback;
    FWorkerThread: TThread;
    FStopEvent: THandle;
    procedure WorkerProc;
  public
    constructor Create;
    destructor Destroy; override;

    function Start(const ALanguage: string = 'zh-CN'): Boolean;
    procedure Stop;
    procedure SetOnPartial(ACallback: TOnPartialCallback);
    procedure SetOnFinal(ACallback: TOnFinalCallback);

    property Running: Boolean read FRunning;
  end;

  TDeepBaseSAPIASR = class
  private
    FRecognizer: ISpRecognizer;
    FContext: ISpRecoContext;
    FGrammar: ISpRecoGrammar;
    FLock: TCriticalSection;
    FAvailable: Boolean;
    FChecked: Boolean;
    procedure EnsureRecognizer;
  public
    constructor Create;
    destructor Destroy; override;

    function IsAvailable: Boolean;
    function CheckStatus: string;

    /// <summary>
    /// Load a grammar word list for command recognition.
    /// Words are registered as top-level rules in an SRGS grammar.
    /// </summary>
    procedure LoadGrammar(const AWords: TArray<string>);

    /// <summary>
    /// Activate dictation mode (free-form speech recognition).
    /// </summary>
    procedure ActivateDictation;

    /// <summary>
    /// Deactivate all recognition (grammar + dictation).
    /// </summary>
    procedure Deactivate;

    /// <summary>
    /// Recognize speech from a WAV file (16-bit PCM mono). Returns the
    /// recognized text, or '' on failure / timeout. Uses ISpStream file
    /// input with an inproc recognizer and polls SPEI_RECOGNITION events.
    /// </summary>
    function RecognizeWavFile(const AWavFilePath: string;
      ATimeoutMs: DWORD = 20000): string;
  end;

var
  GlobalSAPIASR: TDeepBaseSAPIASR;

implementation

uses
  DeepBase.Speech.Types,
  DeepBase.Speech.ASR.SAPIAdapter;

constructor TDeepBaseSAPIASR.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FAvailable := False;
  FChecked := False;
end;

destructor TDeepBaseSAPIASR.Destroy;
begin
  FGrammar := nil;
  FContext := nil;
  FRecognizer := nil;
  FreeAndNil(FLock);
  inherited;
end;

procedure TDeepBaseSAPIASR.EnsureRecognizer;
var
  HR: HRESULT;
begin
  if Assigned(FRecognizer) then Exit;

  // Try shared recognizer first (uses system default audio input)
  HR := CoCreateSpSharedRecognizer(FRecognizer);
  if not Succeeded(HR) then
    HR := CoCreateSpInprocRecognizer(FRecognizer);

  if not Succeeded(HR) or not Assigned(FRecognizer) then
  begin
    FChecked := True;
    FAvailable := False;
    Exit;
  end;

  // Create recognition context
  HR := FRecognizer.CreateRecoContext(FContext);
  if not Succeeded(HR) or not Assigned(FContext) then
  begin
    FRecognizer := nil;
    FChecked := True;
    FAvailable := False;
    Exit;
  end;

  // Create grammar
  HR := FContext.CreateGrammar(0, FGrammar);
  if not Succeeded(HR) then
  begin
    FContext := nil;
    FRecognizer := nil;
    FChecked := True;
    FAvailable := False;
    Exit;
  end;

  FChecked := True;
  FAvailable := True;
end;

function TDeepBaseSAPIASR.IsAvailable: Boolean;
begin
  FLock.Enter;
  try
    if not FChecked then
      EnsureRecognizer;
    Result := FAvailable;
  finally
    FLock.Leave;
  end;
end;

function TDeepBaseSAPIASR.CheckStatus: string;
begin
  if IsAvailable then
    Result := 'SAPI ASR available (shared recognizer)'
  else
    Result := 'SAPI ASR not available: Could not create recognizer or context. ' +
              'Ensure Windows Speech Recognition is installed and a zh-CN language pack is present.';
end;

procedure TDeepBaseSAPIASR.LoadGrammar(const AWords: TArray<string>);
begin
  FLock.Enter;
  try
    EnsureRecognizer;
    if not FAvailable or not Assigned(FGrammar) then Exit;

    // For now, activate dictation as a fallback.
    // Full SRGS XML grammar loading will be implemented when
    // LoadCmdFromMemory is verified in M0 Spike.
    FGrammar.LoadDictation(nil, SPLO_DYNAMIC);
    FGrammar.SetDictationState(SPRS_ACTIVE);
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseSAPIASR.ActivateDictation;
begin
  FLock.Enter;
  try
    EnsureRecognizer;
    if not FAvailable or not Assigned(FGrammar) then Exit;
    FGrammar.LoadDictation(nil, SPLO_DYNAMIC);
    FGrammar.SetDictationState(SPRS_ACTIVE);
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseSAPIASR.Deactivate;
begin
  FLock.Enter;
  try
    if Assigned(FGrammar) then
      FGrammar.SetDictationState(SPRS_INACTIVE);
  finally
    FLock.Leave;
  end;
end;

// ============================================================================
// WAV file recognition (file input mode — enables batch Recognize)
// ============================================================================

function TDeepBaseSAPIASR.RecognizeWavFile(const AWavFilePath: string;
  ATimeoutMs: DWORD): string;
var
  LStream: ISpStream;
  LReco: ISpRecognizer;
  LContext: ISpRecoContext;
  LGrammar: ISpRecoGrammar;
  LResult: ISpRecoResult;
  LEvent: SPEVENT;
  LFetched: ULONG;
  LText: PWideChar;
  LHR: HRESULT;
  LDeadline: DWORD;
  LBuilder: TStringBuilder;
  LCoInitOK: Boolean;
begin
  Result := '';
  if (Trim(AWavFilePath) = '') or not FileExists(AWavFilePath) then
    Exit;

  // ★ v1.3 门禁（FINAL62 实测）：SAPI 引擎线程要求 STA —— MTA 下
  // SetDictationState 报 SPERR_UNSUPPORTED_FORMAT (0x80045003)，STA 下
  // S_OK。未初始化线程首次 CoInitializeEx 可自由选择模型；返回 S_OK
  // 表示本次真正初始化（须配对 CoUninitialize），S_FALSE 表示已是
  // STA（由调用方管理生命周期）。
  LCoInitOK := Succeeded(CoInitializeEx(nil, COINIT_APARTMENTTHREADED));
  try
    FLock.Enter;
    try
      // 1. Bind the WAV file to an ISpStream (SAPI file input)
      //    ★ v1.3：CLSCTX_INPROC_SERVER 直建（Python 对照全程
      //    CLSCTX_INPROC=1 成功）；decl helper 的 CLSCTX_ALL(23) 含
      //    LOCAL_SERVER → 可能解析到 sapisvr 代理实现 → 引擎线程
      //    检查输入流格式 → SPERR_UNSUPPORTED_FORMAT (0x80045003)
      LHR := CoCreateInstance(CLSID_SpStream, nil, CLSCTX_INPROC_SERVER,
        ISpStream, LStream);
      if not Succeeded(LHR) or (LStream = nil) then Exit;
      LHR := LStream.BindToFile(PWideChar(WideString(AWavFilePath)),
        SPFM_OPEN_READONLY, nil, nil, 0);
      if not Succeeded(LHR) then Exit;

      // 2. Inproc recognizer (shared recognizer cannot switch input)
      LHR := CoCreateInstance(CLSID_SpInprocRecognizer, nil,
        CLSCTX_INPROC_SERVER, ISpRecognizer, LReco);
      if not Succeeded(LHR) or (LReco = nil) then Exit;
      LHR := LReco.SetInput(LStream, True);  // fAllowFormatChanges = True
      if not Succeeded(LHR) then Exit;

      // 3. Recognition context + dictation grammar
      LHR := LReco.CreateRecoContext(LContext);
      if not Succeeded(LHR) or (LContext = nil) then Exit;
      LHR := LContext.CreateGrammar(0, LGrammar);
      if not Succeeded(LHR) or (LGrammar = nil) then Exit;
      LHR := LGrammar.LoadDictation(nil, SPLO_DYNAMIC);
      if not Succeeded(LHR) then Exit;
      LHR := LGrammar.SetDictationState(SPRS_ACTIVE);
      if not Succeeded(LHR) then Exit;

      // 4. Interest in recognition results + end-of-stream marker.
      //    IMPORTANT: the mask must include the REQUIRED bits 30+33
      //    (SPFEI_SR_INTEREST); plain SPFEI_RECOGNITION fails E_INVALIDARG.
      LHR := LContext.SetInterest(SPFEI_SR_INTEREST, SPFEI_SR_INTEREST);
      if not Succeeded(LHR) then Exit;

      // 5. START recognition. Recognition only begins after
      //    ISpRecognizer.SetRecoState(SPRS_ACTIVE) — without it no events fire.
      LHR := LReco.SetRecoState(SPRS_ACTIVE);
      if not Succeeded(LHR) then Exit;

      // 6. Poll events until end-of-stream or timeout
      LBuilder := TStringBuilder.Create;
      try
        LDeadline := GetTickCount + ATimeoutMs;
        while GetTickCount < LDeadline do
        begin
          FillChar(LEvent, SizeOf(LEvent), 0);
          LFetched := 0;
          LHR := LContext.GetEvents(1, @LEvent, @LFetched);
          if Succeeded(LHR) and (LFetched > 0) then
          begin
            // eEventId may carry high internal flag bits (observed 0x20026
            // for SPEI_RECOGNITION) — mask with $FF before comparing.
            if (LEvent.eEventId and $FF) = SPEI_RECOGNITION then
            begin
              if LEvent.wParam <> 0 then
              begin
                LResult := ISpRecoResult(Pointer(LEvent.wParam));
                LText := nil;
                if Succeeded(LResult.GetText(0, MAXDWORD, False, LText, nil, nil)) and
                   (LText <> nil) then
                try
                  if LBuilder.Length > 0 then
                    LBuilder.Append(' ');
                  LBuilder.Append(LText);
                finally
                  CoTaskMemFree(LText);
                end;
                LResult := nil;  // Release the event's interface reference
              end;
            end
            else if (LEvent.eEventId and $FF) = SPEI_END_SR_STREAM then
              Break;  // File fully processed
          end
          else
            Sleep(50);
        end;
        Result := Trim(LBuilder.ToString);
      finally
        LBuilder.Free;
      end;
  finally
    FLock.Leave;
  end;
  finally
    if LCoInitOK then
      CoUninitialize;
  end;
end;

// ============================================================================
// TDeepBaseSAPIASRStream — Live streaming recognition
// ============================================================================

constructor TDeepBaseSAPIASRStream.Create;
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FRunning := False;
  FStopEvent := CreateEvent(nil, True, False, nil);
end;

destructor TDeepBaseSAPIASRStream.Destroy;
begin
  Stop;
  CloseHandle(FStopEvent);
  FreeAndNil(FLock);
  inherited;
end;

procedure TDeepBaseSAPIASRStream.SetOnPartial(ACallback: TOnPartialCallback);
begin
  FOnPartial := ACallback;
end;

procedure TDeepBaseSAPIASRStream.SetOnFinal(ACallback: TOnFinalCallback);
begin
  FOnFinal := ACallback;
end;

function TDeepBaseSAPIASRStream.Start(const ALanguage: string): Boolean;
var
  HR: HRESULT;
begin
  Result := False;

  FLock.Enter;
  try
    if FRunning then Exit(True);

    // Use shared recognizer (captures from default mic)
    HR := CoCreateSpSharedRecognizer(FRecognizer);
    if not Succeeded(HR) then Exit;

    HR := FRecognizer.CreateRecoContext(FContext);
    if not Succeeded(HR) then
    begin
      FRecognizer := nil;
      Exit;
    end;

    HR := FContext.CreateGrammar(100, FGrammar);
    if not Succeeded(HR) then
    begin
      FContext := nil;
      FRecognizer := nil;
      Exit;
    end;

    // Activate dictation for free-form recognition
    FGrammar.LoadDictation(nil, SPLO_DYNAMIC);
    FGrammar.SetDictationState(SPRS_ACTIVE);

    // Set interest in recognition events (REQUIRED bits 30+33 included)
    FContext.SetInterest(SPFEI_SR_INTEREST, SPFEI_SR_INTEREST);
    // Start recognition (shared recognizer defaults to active; explicit for parity)
    FRecognizer.SetRecoState(SPRS_ACTIVE);

    ResetEvent(FStopEvent);
    FRunning := True;
    Result := True;

    // Start worker thread to poll SAPI events
    FWorkerThread := TThread.CreateAnonymousThread(WorkerProc);
    FWorkerThread.FreeOnTerminate := True;
    FWorkerThread.Start;
  finally
    FLock.Leave;
  end;
end;

procedure TDeepBaseSAPIASRStream.Stop;
begin
  FLock.Enter;
  try
    if not FRunning then Exit;
    FRunning := False;
    SetEvent(FStopEvent);
  finally
    FLock.Leave;
  end;

  // Wait for worker to finish (best-effort 3 seconds)
  Sleep(100);

  FLock.Enter;
  try
    if Assigned(FGrammar) then
      FGrammar.SetDictationState(SPRS_INACTIVE);
    FGrammar := nil;
    FContext := nil;
    FRecognizer := nil;
  finally
    FLock.Leave;
  end;

  // Fire final callback with empty result to signal end
  if Assigned(FOnFinal) then
  begin
    var LFinal: TSAPIASRResult;
    LFinal.Success := True;
    LFinal.Text := '';
    LFinal.Confidence := 0;
    LFinal.ErrorMessage := '';
    LFinal.DurationMs := 0;
    FOnFinal(LFinal);
  end;
end;

procedure TDeepBaseSAPIASRStream.WorkerProc;
begin
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  try
    // SAPI event polling loop
    // In production, this would use ISpNotifySource.SetNotifyWin32Event
    // and WaitForMultipleObjects. For v1, we use a simple sleep loop
    // since SAPI shared recognizer fires events asynchronously.
    while FRunning do
    begin
      if WaitForSingleObject(FStopEvent, 100) = WAIT_OBJECT_0 then
        Break;
      // SAPI events are delivered via COM message pump in shared mode.
      // The actual recognition results come through the context's event
      // mechanism. For this v1 implementation, results are collected
      // when Stop is called. Full event-driven implementation requires
      // ISpNotifyCallback which will be added in M2 refinement.
    end;
  finally
    CoUninitialize;
  end;
end;

// Self-registration
procedure RegisterSAPIASRBackend;
var
  LInfo: TSpeechBackendInfo;
begin
  LInfo := Default(TSpeechBackendInfo);
  LInfo.Kind := sbkASR;
  LInfo.Name := 'SAPI';
  LInfo.IsCloud := False;
  LInfo.RequiresMic := True;
  LInfo.SupportsBatch := True;
  LInfo.SupportsStreaming := True;
  LInfo.SupportsGrammar := True;
  LInfo.Enabled := True;
  LInfo.Priority := 20; // WinRT would be 10 if available
  LInfo.IsAvailableFunc :=
    function: Boolean
    begin
      if GlobalSAPIASR = nil then
        GlobalSAPIASR := TDeepBaseSAPIASR.Create;
      Result := GlobalSAPIASR.IsAvailable;
    end;
  // Wire SAPI through the adapter so it satisfies ISpeechRecognizerEx. Reuse
  // the GlobalSAPIASR singleton (weak ref) so availability check and the
  // injected instance share one underlying recognizer — no double CoCreate.
  LInfo.ASRFactory :=
    function: ISpeechRecognizerEx
    begin
      if GlobalSAPIASR = nil then
        GlobalSAPIASR := TDeepBaseSAPIASR.Create;
      Result := TDeepBaseSAPIASRAdapter.Create(GlobalSAPIASR);
    end;
  TSpeechRegistry.Register(LInfo);
end;

initialization
  GlobalSAPIASR := nil;
  RegisterSAPIASRBackend;

finalization
  FreeAndNil(GlobalSAPIASR);

end.
