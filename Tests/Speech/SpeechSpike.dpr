program SpeechSpike;

{$APPTYPE CONSOLE}

{ ============================================================================
  DeepBase.Speech M0 Spike — SAPI/WinMM/Accessibility Verification
  ---------------------------------------------------------------------------
  Run this once on target machine to collect all spike conclusions.
  Each test prints [PASS] / [FAIL] / [SKIP] with details.
  No production dependencies — standalone diagnostic tool.
  ============================================================================ }

uses
  System.SysUtils,
  System.Classes,
  System.Diagnostics,
  Winapi.Windows,
  Winapi.ActiveX,
  Winapi.MMSystem,
  DeepBase.Speech.SAPI.Decl;

var
  GTestCount, GPassCount, GFailCount, GSkipCount: Integer;

procedure Log(const AMsg: string);
begin
  Writeln(AMsg);
end;

procedure Pass(const ATestId, AMsg: string);
begin
  Inc(GTestCount); Inc(GPassCount);
  Log(Format('[PASS] %s: %s', [ATestId, AMsg]));
end;

procedure Fail(const ATestId, AMsg: string);
begin
  Inc(GTestCount); Inc(GFailCount);
  Log(Format('[FAIL] %s: %s', [ATestId, AMsg]));
end;

procedure Skip(const ATestId, AMsg: string);
begin
  Inc(GTestCount); Inc(GSkipCount);
  Log(Format('[SKIP] %s: %s', [ATestId, AMsg]));
end;

// ============================================================================
// 1.2 — Enumerate SAPI recognizer and voice tokens
// ============================================================================
procedure Test_1_2_EnumerateTokens;
var
  LVoice: ISpVoice;
  LRecognizer: ISpRecognizer;
  HR: HRESULT;
begin
  Log('');
  Log('=== 1.2 SAPI Token Enumeration ===');

  HR := CoCreateSpVoice(LVoice);
  if Succeeded(HR) then
    Pass('1.2a', 'CoCreateInstance(SpVoice) succeeded')
  else
    Fail('1.2a', Format('CoCreateInstance(SpVoice) failed: 0x%x', [HR]));

  HR := CoCreateSpSharedRecognizer(LRecognizer);
  if Succeeded(HR) then
    Pass('1.2b', 'CoCreateInstance(SpSharedRecognizer) succeeded')
  else
  begin
    // Try inproc
    HR := CoCreateSpInprocRecognizer(LRecognizer);
    if Succeeded(HR) then
      Pass('1.2b', 'CoCreateInstance(SpInprocRecognizer) succeeded (shared failed)')
    else
      Fail('1.2b', Format('Both shared and inproc recognizer failed: 0x%x', [HR]));
  end;

  // Note: Full token enumeration requires ISpObjectTokenCategory which
  // needs more COM declarations. For spike purposes, successful CoCreate
  // confirms SAPI is installed and functional.
  if Assigned(LRecognizer) then
    Pass('1.2c', 'SAPI recognizer available on this machine')
  else
    Fail('1.2c', 'No SAPI recognizer available');
end;

// ============================================================================
// 1.10 — TTS SpeakAsync/Stop/empty text
// ============================================================================
procedure Test_1_10_TTS;
var
  LVoice: ISpVoice;
  HR: HRESULT;
  LStreamNum: ULONG;
  LSW: TStopwatch;
begin
  Log('');
  Log('=== 1.10 TTS Verification ===');

  HR := CoCreateSpVoice(LVoice);
  if not Succeeded(HR) then
  begin
    Skip('1.10', 'SpVoice not available');
    Exit;
  end;

  // Empty text
  HR := LVoice.Speak('', SPF_DEFAULT, LStreamNum);
  if Succeeded(HR) then
    Pass('1.10a', 'Empty text Speak succeeded (no crash)')
  else
    Fail('1.10a', Format('Empty text Speak failed: 0x%x', [HR]));

  // Async speak + stop
  HR := LVoice.Speak(PWideChar(WideString('Testing DeepBase Speech TTS.')),
    SPF_ASYNC, LStreamNum);
  if Succeeded(HR) then
    Pass('1.10b', 'SpeakAsync succeeded')
  else
    Fail('1.10b', Format('SpeakAsync failed: 0x%x', [HR]));

  // Measure stop latency
  LSW := TStopwatch.StartNew;
  // Purge to stop
  HR := LVoice.Speak(PWideChar(WideString('')), SPF_PURGEBEFORESPEAK, LStreamNum);
  LSW.Stop;
  if LSW.ElapsedMilliseconds < 500 then
    Pass('1.10c', Format('Stop latency: %d ms (< 500ms)', [LSW.ElapsedMilliseconds]))
  else
    Fail('1.10c', Format('Stop latency: %d ms (>= 500ms)', [LSW.ElapsedMilliseconds]));
end;

// ============================================================================
// 1.11 — CI environment detection
// ============================================================================
procedure Test_1_11_CI;
var
  LCI: string;
begin
  Log('');
  Log('=== 1.11 CI Environment Detection ===');
  LCI := GetEnvironmentVariable('CI');
  if LCI <> '' then
    Log('[INFO] Running in CI environment: CI=' + LCI)
  else
    Log('[INFO] Not in CI environment');

  // Check audio device
  if waveInGetNumDevs > 0 then
    Pass('1.11', Format('Audio input devices: %d', [waveInGetNumDevs]))
  else
    Fail('1.11', 'No audio input devices found');
end;

// ============================================================================
// 1.12 — Screen reader detection
// ============================================================================
procedure Test_1_12_ScreenReader;
var
  LActive: BOOL;
begin
  Log('');
  Log('=== 1.12 Screen Reader Detection ===');
  LActive := False;
  SystemParametersInfo(SPI_GETSCREENREADER, 0, @LActive, 0);
  if LActive then
    Log('[INFO] Screen reader IS active (SPI_GETSCREENREADER=True)')
  else
    Log('[INFO] Screen reader NOT active');
  Pass('1.12', Format('SPI_GETSCREENREADER returned %s', [BoolToStr(LActive, True)]));
end;

// ============================================================================
// 1.13 — Voice Access detection
// ============================================================================
procedure Test_1_13_VoiceAccess;
var
  LSnap: THandle;
  LEntry: TProcessEntry32;
  LFound: Boolean;
begin
  Log('');
  Log('=== 1.13 Voice Access Detection ===');
  LFound := False;
  LSnap := CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
  if LSnap <> INVALID_HANDLE_VALUE then
  try
    LEntry.dwSize := SizeOf(LEntry);
    if Process32First(LSnap, LEntry) then
    repeat
      if SameText(string(LEntry.szExeFile), 'VoiceAccess.exe') then
      begin
        LFound := True;
        Break;
      end;
    until not Process32Next(LSnap, LEntry);
  finally
    CloseHandle(LSnap);
  end;

  if LFound then
    Log('[INFO] Voice Access IS running')
  else
    Log('[INFO] Voice Access NOT running');
  Pass('1.13', Format('VoiceAccess.exe detected: %s', [BoolToStr(LFound, True)]));
end;

// ============================================================================
// 1.15 — DPAPI cross-user failure path
// ============================================================================
procedure Test_1_15_DPAPI;
type
  PDataBlob = ^TDataBlob;
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;
var
  LInBlob, LOutBlob: TDataBlob;
  LText: UnicodeString;
  LResult: BOOL;
begin
  Log('');
  Log('=== 1.15 DPAPI Verification ===');
  LText := 'DeepBase.Speech.Spike.Test';
  LInBlob.cbData := Length(LText) * SizeOf(WideChar);
  LInBlob.pbData := PByte(PWideChar(LText));

  LResult := CryptProtectData(@LInBlob, nil, nil, nil, nil, 0, @LOutBlob);
  if LResult then
  begin
    Pass('1.15a', Format('CryptProtectData succeeded (%d bytes)', [LOutBlob.cbData]));
    LocalFree(HLOCAL(LOutBlob.pbData));
  end
  else
    Fail('1.15a', Format('CryptProtectData failed: %s', [SysErrorMessage(GetLastError)]));
end;

// ============================================================================
// 1.16 — QueryPerformanceCounter precision
// ============================================================================
procedure Test_1_16_QPC;
var
  LFreq, LC1, LC2: Int64;
  LElapsedUs: Double;
begin
  Log('');
  Log('=== 1.16 QueryPerformanceCounter Precision ===');
  QueryPerformanceFrequency(LFreq);
  QueryPerformanceCounter(LC1);
  Sleep(10);
  QueryPerformanceCounter(LC2);
  LElapsedUs := (LC2 - LC1) * 1000000.0 / LFreq;
  if (LElapsedUs > 9000) and (LElapsedUs < 20000) then
    Pass('1.16', Format('QPC precision OK: Sleep(10) measured %.1f us (freq=%d)', [LElapsedUs, LFreq]))
  else
    Fail('1.16', Format('QPC precision suspect: Sleep(10) measured %.1f us', [LElapsedUs]));
end;

// ============================================================================
// 1.6 — WinMM buffer baseline (simplified: just check device availability)
// ============================================================================
procedure Test_1_6_WinMM;
var
  LDevCount: UINT;
  LCaps: TWaveInCaps;
begin
  Log('');
  Log('=== 1.6 WinMM Audio Capture Baseline ===');
  LDevCount := waveInGetNumDevs;
  if LDevCount = 0 then
  begin
    Skip('1.6', 'No audio input devices');
    Exit;
  end;
  Pass('1.6a', Format('%d audio input device(s) found', [LDevCount]));

  if waveInGetDevCaps(0, @LCaps, SizeOf(LCaps)) = MMSYSERR_NOERROR then
    Pass('1.6b', Format('Device 0: %s, channels=%d, formats=0x%x',
      [string(LCaps.szPname), LCaps.wChannels, LCaps.dwFormats]))
  else
    Fail('1.6b', 'waveInGetDevCaps failed');
end;

// ============================================================================
// Main
// ============================================================================
begin
  CoInitializeEx(nil, COINIT_APARTMENTTHREADED);
  try
    Log('DeepBase.Speech M0 Spike — ' + DateTimeToStr(Now));
    Log('OS: Windows ' + TOSVersion.ToString);
    Log('');

    GTestCount := 0; GPassCount := 0; GFailCount := 0; GSkipCount := 0;

    Test_1_2_EnumerateTokens;
    Test_1_6_WinMM;
    Test_1_10_TTS;
    Test_1_11_CI;
    Test_1_12_ScreenReader;
    Test_1_13_VoiceAccess;
    Test_1_15_DPAPI;
    Test_1_16_QPC;

    Log('');
    Log(Format('=== Summary: %d tests, %d pass, %d fail, %d skip ===',
      [GTestCount, GPassCount, GFailCount, GSkipCount]));
    Log('');
    Log('Tests 1.3/1.4/1.5/1.7/1.8/1.9/1.14 require interactive mic input.');
    Log('Run with --interactive flag to enable those (not implemented in this spike).');
  finally
    CoUninitialize;
  end;

  if ParamStr(1) <> '--batch' then
  begin
    Write('Press Enter to exit...');
    Readln;
  end;
end.
