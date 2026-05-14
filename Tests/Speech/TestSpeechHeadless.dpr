program TestSpeechHeadless;

{$APPTYPE CONSOLE}

{ ============================================================================
  DeepBase.Speech Headless Unit Tests
  ---------------------------------------------------------------------------
  No microphone / no SAPI runtime required. Tests pure logic:
  - Config BCP-47 normalization
  - Registry register/discover/disable
  - Runtime AudioSession state machine
  - MFCC determinism + basic properties
  - DTW symmetry + non-negativity + self-distance
  - WakeWord word validation
  - Intent parser rule matching
  - Voiceprint enrollment validation
  ============================================================================ }

uses
  System.SysUtils,
  System.Math,
  DeepBase.Speech.Config,
  DeepBase.Speech.Registry,
  DeepBase.Speech.Runtime,
  DeepBase.Speech.MFCC,
  DeepBase.Speech.DTW,
  DeepBase.Speech.WakeWord,
  DeepBase.Speech.Intent,
  DeepBase.Speech.Voiceprint,
  DeepBase.Speech.Policy;

var
  GTotal, GPass, GFail: Integer;

procedure Check(ACondition: Boolean; const ATestName: string);
begin
  Inc(GTotal);
  if ACondition then
  begin
    Inc(GPass);
    Writeln('[PASS] ', ATestName);
  end
  else
  begin
    Inc(GFail);
    Writeln('[FAIL] ', ATestName);
  end;
end;

// ============================================================================
// Config Tests
// ============================================================================
procedure TestConfig;
begin
  Writeln(''); Writeln('=== Config BCP-47 ===');
  Check(TSpeechLangHelper.Normalize('zh-CN') = 'zh-CN', 'zh-CN passthrough');
  Check(TSpeechLangHelper.Normalize('zh_CN') = 'zh-CN', 'zh_CN underscore');
  Check(TSpeechLangHelper.Normalize('zh-Hans-CN') = 'zh-CN', 'zh-Hans-CN strip script');
  Check(TSpeechLangHelper.Normalize('en-US') = 'en-US', 'en-US passthrough');
  Check(TSpeechLangHelper.Normalize('en_us') = 'en-US', 'en_us lowercase+underscore');
  Check(not TSpeechLangHelper.IsValid('zh'), 'bare zh rejected');
  Check(not TSpeechLangHelper.IsValid(''), 'empty rejected');
  Check(TSpeechLangHelper.PrimaryLanguage('zh-CN') = 'zh', 'primary zh');
  Check(TSpeechLangHelper.Region('zh-CN') = 'CN', 'region CN');
end;

// ============================================================================
// Registry Tests
// ============================================================================
procedure TestRegistry;
var
  LInfo: TSpeechBackendInfo;
  LAll: TArray<TSpeechBackendInfo>;
begin
  Writeln(''); Writeln('=== Registry ===');

  LInfo := Default(TSpeechBackendInfo);
  LInfo.Kind := sbkASR;
  LInfo.Name := 'TestBackend';
  LInfo.Enabled := True;
  LInfo.Priority := 50;
  LInfo.IsAvailableFunc := function: Boolean begin Result := True; end;
  TSpeechRegistry.Register(LInfo);

  Check(TSpeechRegistry.IsRegistered('TestBackend', sbkASR), 'Register + IsRegistered');
  Check(TSpeechRegistry.Count(sbkASR) >= 1, 'Count >= 1');

  LAll := TSpeechRegistry.Discover(sbkASR, True);
  Check(Length(LAll) >= 1, 'Discover returns >= 1');

  TSpeechRegistry.Disable('TestBackend', sbkASR);
  LAll := TSpeechRegistry.Discover(sbkASR, True);
  // Disabled backends should not appear
  Check(not TSpeechRegistry.FindBest(sbkASR).Enabled or
        (TSpeechRegistry.FindBest(sbkASR).Name <> 'TestBackend'), 'Disable hides from Discover');

  TSpeechRegistry.Enable('TestBackend', sbkASR);
  Check(TSpeechRegistry.FindBest(sbkASR).Name <> '', 'Enable restores');
end;

// ============================================================================
// Runtime AudioSession Tests
// ============================================================================
procedure TestRuntime;
var
  LRT: TSpeechRuntime;
begin
  Writeln(''); Writeln('=== Runtime AudioSession ===');
  LRT := TSpeechRuntime.Create;
  try
    Check(LRT.State = assIdle, 'Initial state = Idle');

    Check(LRT.RequestMic(assPushToTalk, 'test'), 'Request PTT from Idle');
    Check(LRT.State = assPushToTalk, 'State = PTT');

    // Cannot request another PTT while active
    Check(not LRT.RequestMic(assDictationStreaming, 'test2'), 'Deny Dictation during PTT');

    LRT.ReleaseMic('done');
    Check(LRT.State = assIdle, 'Release returns to Idle');

    // TTS can be interrupted by PTT
    Check(LRT.RequestMic(assTTSPlaying, 'speak'), 'Request TTS from Idle');
    Check(LRT.State = assTTSPlaying, 'State = TTS');
    Check(LRT.RequestMic(assPushToTalk, 'interrupt'), 'PTT interrupts TTS');
    Check(LRT.State = assPushToTalk, 'State = PTT after interrupt');

    LRT.ForceStop('abort');
    Check(LRT.State = assIdle, 'ForceStop returns to Idle');

    // WakeWord auto-restore: WakeListening → PTT → Release → WakeListening
    Check(LRT.RequestMic(assWakeListening, 'wake'), 'Request WakeListening');
    Check(LRT.State = assWakeListening, 'State = WakeListening');
    Check(LRT.RequestMic(assPushToTalk, 'ptt'), 'PTT preempts WakeWord');
    Check(LRT.State = assPushToTalk, 'State = PTT after preempt');
    LRT.ReleaseMic('ptt done');
    Check(LRT.State = assWakeListening, 'WakeWord auto-restored after PTT');

    // TTS during WakeListening → Release → WakeListening
    Check(LRT.RequestMic(assTTSPlaying, 'feedback'), 'TTS from WakeListening');
    Check(LRT.State = assTTSPlaying, 'State = TTS');
    LRT.ReleaseMic('tts done');
    Check(LRT.State = assWakeListening, 'WakeWord auto-restored after TTS');

    // ForceStop clears WakeWord memory
    Check(LRT.RequestMic(assPushToTalk, 'ptt2'), 'PTT from WakeListening');
    LRT.ForceStop('user abort');
    Check(LRT.State = assIdle, 'ForceStop → Idle (no restore)');
  finally
    LRT.Free;
  end;
end;

// ============================================================================
// MFCC Tests
// ============================================================================
procedure TestMFCC;
var
  LExtractor: TMFCCExtractor;
  LPCM: TBytes;
  LFeatures1, LFeatures2: TMFCCFeatures;
  LMean: TMFCCFrame;
  I: Integer;
begin
  Writeln(''); Writeln('=== MFCC ===');
  LExtractor := TMFCCExtractor.Create(16000);
  try
    // Generate 1 second of 16kHz PCM16 sine wave (440 Hz)
    SetLength(LPCM, 16000 * 2); // 1 sec @ 16kHz, 2 bytes/sample
    for I := 0 to 15999 do
    begin
      var LSample := Round(Sin(2 * Pi * 440 * I / 16000) * 16000);
      LPCM[I * 2] := Byte(LSample and $FF);
      LPCM[I * 2 + 1] := Byte((LSample shr 8) and $FF);
    end;

    LFeatures1 := LExtractor.Extract(LPCM);
    Check(Length(LFeatures1) > 0, 'Extract produces frames');
    Check(Length(LFeatures1) > 50, Format('Enough frames: %d > 50', [Length(LFeatures1)]));

    // Determinism: same input → same output
    LFeatures2 := LExtractor.Extract(LPCM);
    Check(Length(LFeatures1) = Length(LFeatures2), 'Determinism: same frame count');
    if (Length(LFeatures1) > 0) and (Length(LFeatures2) > 0) then
      Check(Abs(LFeatures1[0][0] - LFeatures2[0][0]) < 1e-6, 'Determinism: same values');

    // Mean vector
    LMean := TMFCCExtractor.MeanVector(LFeatures1);
    Check(not IsNan(LMean[0]), 'Mean vector not NaN');

    // Empty input
    LFeatures1 := LExtractor.Extract(nil);
    Check(Length(LFeatures1) = 0, 'Empty input → empty features');

    // Too short input (< 1 frame = 25ms = 800 bytes)
    SetLength(LPCM, 100);
    LFeatures1 := LExtractor.Extract(LPCM);
    Check(Length(LFeatures1) = 0, 'Short input → empty features');
  finally
    LExtractor.Free;
  end;
end;

// ============================================================================
// DTW Tests
// ============================================================================
procedure TestDTW;
var
  LSeqX, LSeqY: TMFCCFeatures;
  LResult: TDTWResult;
  I, J: Integer;
begin
  Writeln(''); Writeln('=== DTW ===');

  // Create two simple sequences
  SetLength(LSeqX, 10);
  SetLength(LSeqY, 10);
  for I := 0 to 9 do
    for J := 0 to 12 do
    begin
      LSeqX[I][J] := I * 0.1 + J * 0.01;
      LSeqY[I][J] := I * 0.1 + J * 0.01 + 0.001; // slightly different
    end;

  // Self-distance = 0
  LResult := TDTW.Compute(LSeqX, LSeqX);
  Check(LResult.Distance < 1e-6, Format('Self-distance ≈ 0: %.6f', [LResult.Distance]));

  // Non-negativity
  LResult := TDTW.Compute(LSeqX, LSeqY);
  Check(LResult.Distance >= 0, 'Non-negative distance');

  // Symmetry
  var LResultYX := TDTW.Compute(LSeqY, LSeqX);
  Check(Abs(LResult.Distance - LResultYX.Distance) < 1e-9,
    Format('Symmetry: |%.9f - %.9f| < 1e-9', [LResult.Distance, LResultYX.Distance]));

  // Empty sequences
  LResult := TDTW.Compute(nil, LSeqY);
  Check(LResult.Distance = 0, 'Empty X → distance 0');
end;

// ============================================================================
// WakeWord Tests
// ============================================================================
procedure TestWakeWord;
var
  LWW: TDeepBaseWakeWord;
  LRaised: Boolean;
begin
  Writeln(''); Writeln('=== WakeWord ===');
  LWW := TDeepBaseWakeWord.Create;
  try
    // Valid words
    LWW.SetWords(['小启', '深启开始']);
    Check(Length(LWW.GetWords) = 2, 'SetWords accepts valid words');

    // Short word rejected
    LRaised := False;
    try
      LWW.SetWords(['X']); // 1 char
    except
      on E: EArgumentException do LRaised := True;
    end;
    Check(LRaised, 'Short word (1 char) raises exception');

    // Empty array rejected
    LRaised := False;
    try
      LWW.SetWords([]);
    except
      on E: EArgumentException do LRaised := True;
    end;
    Check(LRaised, 'Empty word array raises exception');

    // Zero-width characters stripped
    LWW.SetWords([#$200B + '小启' + #$200B]); // zero-width space around
    Check(LWW.GetWords[0] = '小启', 'Zero-width chars stripped');

    // Threshold bounds
    LWW.SetConfidenceThreshold(1.5);
    Check(LWW.Threshold = 1.0, 'Threshold clamped to 1.0');
    LWW.SetConfidenceThreshold(-0.5);
    Check(LWW.Threshold = 0.0, 'Threshold clamped to 0.0');
  finally
    LWW.Free;
  end;
end;

// ============================================================================
// Intent Tests
// ============================================================================
procedure TestIntent;
var
  LParser: TDeepBaseIntentParser;
  LResult: TIntentResult;
begin
  Writeln(''); Writeln('=== Intent ===');
  LParser := TDeepBaseIntentParser.Create;
  try
    LParser.RegisterRule('打开(.+)', 'open_app',
      function(const AText: string): TArray<TIntentSlot>
      var LSlot: TIntentSlot;
      begin
        LSlot.Name := 'app_name';
        LSlot.Value := Copy(AText, 3, MaxInt); // after "打开"
        Result := [LSlot];
      end);

    LParser.RegisterRule('播放(.+)的歌', 'play_music');
    LParser.RegisterRule('锁屏', 'lock_screen');

    // Rule match
    LResult := LParser.Parse('打开计算器');
    Check(LResult.Intent = 'open_app', 'Match: open_app');
    Check(LResult.Confidence >= 0.9, 'Confidence >= 0.9');
    Check(LResult.Source = 'rule', 'Source = rule');
    Check(Length(LResult.Slots) > 0, 'Slots extracted');

    // Another match
    LResult := LParser.Parse('锁屏');
    Check(LResult.Intent = 'lock_screen', 'Match: lock_screen');

    // No match
    LResult := LParser.Parse('今天天气怎么样');
    Check(LResult.Intent = 'unknown', 'No match → unknown');
    Check(LResult.Confidence = 0, 'No match → confidence 0');

    // Empty text
    LResult := LParser.Parse('');
    Check(LResult.Intent = 'unknown', 'Empty → unknown');

    // Rule count
    Check(LParser.RuleCount = 3, 'RuleCount = 3');

    // Idempotence: same input → same output
    var LR1 := LParser.Parse('打开微信');
    var LR2 := LParser.Parse('打开微信');
    Check((LR1.Intent = LR2.Intent) and (LR1.Confidence = LR2.Confidence), 'Idempotent');
  finally
    LParser.Free;
  end;
end;

// ============================================================================
// Voiceprint Tests
// ============================================================================
procedure TestVoiceprint;
var
  LVP: TDeepBaseVoiceprint;
  LSamples: TArray<TBytes>;
  LId: TVoiceProfileId;
  LResult: TVerifyResult;
  LRaised: Boolean;
  I, J: Integer;
begin
  Writeln(''); Writeln('=== Voiceprint ===');
  LVP := TDeepBaseVoiceprint.Create;
  try
    // Generate 3 fake audio samples (1 sec each, 16kHz PCM16 sine)
    SetLength(LSamples, 3);
    for I := 0 to 2 do
    begin
      SetLength(LSamples[I], 16000 * 2);
      for J := 0 to 15999 do
      begin
        var LSample := Round(Sin(2 * Pi * (440 + I * 10) * J / 16000) * 16000);
        LSamples[I][J * 2] := Byte(LSample and $FF);
        LSamples[I][J * 2 + 1] := Byte((LSample shr 8) and $FF);
      end;
    end;

    // Enroll
    LId := LVP.EnrollProfile('TestUser', 'wake_word', 'TestApp', LSamples, 500.0);
    Check(LId <> '', 'EnrollProfile returns non-empty ID');

    // List
    var LList := LVP.ListProfiles('TestApp');
    Check(Length(LList) = 1, 'ListProfiles returns 1');
    Check(LList[0].UserLabel = 'TestUser', 'Profile label correct');

    // Verify with same audio → should match (distance ≈ 0)
    LResult := LVP.Verify(LSamples[0], LId);
    Check(LResult.Match, 'Verify same audio → Match');
    Check(LResult.Distance < 500.0, Format('Distance %.2f < threshold 500', [LResult.Distance]));

    // Verify determinism
    var LR2 := LVP.Verify(LSamples[0], LId);
    Check(Abs(LResult.Distance - LR2.Distance) < 1e-6, 'Verify deterministic');

    // Identify
    var LIdentified := LVP.Identify(LSamples[1]);
    Check(LIdentified = LId, 'Identify returns enrolled profile');

    // Delete
    Check(LVP.DeleteProfile(LId), 'DeleteProfile returns True');
    Check(Length(LVP.ListProfiles('TestApp')) = 0, 'After delete, list empty');

    // Enrollment with < 3 samples fails
    LRaised := False;
    try
      LVP.EnrollProfile('X', 'test', 'App', [LSamples[0], LSamples[1]]);
    except
      on E: EArgumentException do LRaised := True;
    end;
    Check(LRaised, 'Enroll with < 3 samples raises');
  finally
    LVP.Free;
  end;
end;

// ============================================================================
// Policy Tests
// ============================================================================
procedure TestPolicy;
begin
  Writeln(''); Writeln('=== Policy ===');
  Check(TSpeechPolicy.IsAllowed(SPEECH_GATE_ASR), 'ASR allowed (local)');
  Check(TSpeechPolicy.IsAllowed(SPEECH_GATE_TTS), 'TTS allowed (local)');
  Check(TSpeechPolicy.IsAllowed(SPEECH_GATE_WAKE), 'WakeWord allowed (local)');
  Check(not TSpeechPolicy.IsAllowed(SPEECH_GATE_INTENT_LLM), 'Intent LLM denied by default');
end;

// ============================================================================
// Main
// ============================================================================
begin
  GTotal := 0; GPass := 0; GFail := 0;

  Writeln('DeepBase.Speech Headless Tests — ', DateTimeToStr(Now));

  TestConfig;
  TestRegistry;
  TestRuntime;
  TestMFCC;
  TestDTW;
  TestWakeWord;
  TestIntent;
  TestVoiceprint;
  TestPolicy;

  Writeln('');
  Writeln(Format('=== Results: %d total, %d pass, %d fail ===', [GTotal, GPass, GFail]));
  if GFail > 0 then
    ExitCode := 1
  else
    ExitCode := 0;

  if ParamStr(1) <> '--batch' then
  begin
    Write('Press Enter...');
    Readln;
  end;
end.
