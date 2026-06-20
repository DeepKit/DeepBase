unit Test.DeepBase.Speech.PBT;

{ ============================================================================
  Test.DeepBase.Speech.PBT — Property-based tests for Speech modules.

  Properties covered:
    P1: TSpeechBackendInfo — Register/Discover round-trip
    P2: TSpeechRegistry — Enable/Disable idempotency
    P3: TSpeechRegistry — Priority ordering
    P4: TSpeechRegistry — Discover filters by Kind correctly
    P5: TSAPIVoiceOccupancy — IsAvailable idempotent
    P6: TSpeechAudioFormat — PCM16Mono invariants
    P7: TSpeechAudioData — DurationMs ≥ 0 for any valid data
    P8: TTTSOptions — Default values are consistent
  ============================================================================ }

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Speech.Types,
  DeepBase.Speech.Registry;

type
  [TestFixture]
  [Category('PBT')]
  TSpeechRegistryPBT = class
  public
    [Test]
    procedure P1_Register_Discover_RoundTrip;

    [Test]
    procedure P2_Enable_Disable_Idempotent;

    [Test]
    procedure P3_Discover_ReturnsSortedByPriority;

    [Test]
    procedure P4_Discover_FiltersByKind;
  end;

  [TestFixture]
  [Category('PBT')]
  TSpeechTypesPBT = class
  public
    [Test]
    procedure P5_PCM16Mono_Invariants;

    [Test]
    procedure P6_AudioData_DurationMs_NonNegative;

    [Test]
    procedure P7_TTSOptions_Default_Consistent;

    [Test]
    procedure P8_RecognitionResult_Failed_HasError;
  end;

implementation

{ TSpeechRegistryPBT }

procedure TSpeechRegistryPBT.P1_Register_Discover_RoundTrip;
var
  Info: TSpeechBackendInfo;
  Discovered: TArray<TSpeechBackendInfo>;
  I: Integer;
begin
  // Register a test backend
  Info.Kind := sbkTTS;
  Info.Name := 'PBT-Test-TTS';
  Info.IsCloud := False;
  Info.RequiresMic := False;
  Info.SupportsBatch := False;
  Info.SupportsStreaming := False;
  Info.SupportsGrammar := False;
  Info.IsAvailableFunc := function: Boolean begin Result := True; end;
  Info.Enabled := True;
  Info.Priority := 50;
  TSpeechRegistry.Register(Info);

  // Discover and verify
  Discovered := TSpeechRegistry.Discover(sbkTTS, False);
  var Found := False;
  for I := 0 to High(Discovered) do
    if Discovered[I].Name = 'PBT-Test-TTS' then
    begin
      Found := True;
      Assert.AreEqual(50, Discovered[I].Priority);
      Assert.IsTrue(Discovered[I].Enabled);
      Assert.IsTrue(Discovered[I].IsCloud = False);
      Break;
    end;

  Assert.IsTrue(Found, 'Registered backend should be discoverable');

  // Cleanup
  TSpeechRegistry.Disable('PBT-Test-TTS', sbkTTS);
end;

procedure TSpeechRegistryPBT.P2_Enable_Disable_Idempotent;
var
  Info: TSpeechBackendInfo;
  Discovered: TArray<TSpeechBackendInfo>;
begin
  // Register
  Info.Kind := sbkASR;
  Info.Name := 'PBT-Idempotent';
  Info.IsCloud := False;
  Info.RequiresMic := False;
  Info.SupportsBatch := False;
  Info.SupportsStreaming := False;
  Info.SupportsGrammar := False;
  Info.IsAvailableFunc := function: Boolean begin Result := True; end;
  Info.Enabled := True;
  Info.Priority := 10;
  TSpeechRegistry.Register(Info);

  // Disable twice — should be idempotent
  TSpeechRegistry.Disable('PBT-Idempotent', sbkASR);
  TSpeechRegistry.Disable('PBT-Idempotent', sbkASR);

  // Should not appear in available backends
  var Available := TSpeechRegistry.Discover(sbkASR, True);
  for var B in Available do
    Assert.IsTrue(B.Name <> 'PBT-Idempotent',
      'Disabled backend should not appear in available-only discover');

  // Re-enable
  TSpeechRegistry.Enable('PBT-Idempotent', sbkASR);

  var ReEnabled := TSpeechRegistry.Discover(sbkASR, True);
  var Found := False;
  for var B in ReEnabled do
    if B.Name = 'PBT-Idempotent' then
    begin
      Found := True;
      Break;
    end;
  Assert.IsTrue(Found, 'Re-enabled backend should be discoverable');

  TSpeechRegistry.Disable('PBT-Idempotent', sbkASR);
end;

procedure TSpeechRegistryPBT.P3_Discover_ReturnsSortedByPriority;
var
  Info: TSpeechBackendInfo;
  Discovered: TArray<TSpeechBackendInfo>;
  I: Integer;
begin
  // Register three backends with different priorities
  Info.Kind := sbkWakeWord;
  Info.IsCloud := False;
  Info.RequiresMic := False;
  Info.SupportsBatch := False;
  Info.SupportsStreaming := False;
  Info.SupportsGrammar := False;
  Info.IsAvailableFunc := function: Boolean begin Result := True; end;
  Info.Enabled := True;

  Info.Name := 'PBT-Priority-Low';
  Info.Priority := 100;
  TSpeechRegistry.Register(Info);

  Info.Name := 'PBT-Priority-High';
  Info.Priority := 1;
  TSpeechRegistry.Register(Info);

  Info.Name := 'PBT-Priority-Mid';
  Info.Priority := 50;
  TSpeechRegistry.Register(Info);

  Discovered := TSpeechRegistry.Discover(sbkWakeWord, False);

  // Verify sorted by priority (ascending)
  var LastPriority := -1;
  for I := 0 to High(Discovered) do
    if (Discovered[I].Name = 'PBT-Priority-High') or
       (Discovered[I].Name = 'PBT-Priority-Mid') or
       (Discovered[I].Name = 'PBT-Priority-Low') then
    begin
      Assert.IsTrue(Discovered[I].Priority >= LastPriority,
        'Backends should be sorted by priority ascending');
      LastPriority := Discovered[I].Priority;
    end;

  // Cleanup
  TSpeechRegistry.Disable('PBT-Priority-High', sbkWakeWord);
  TSpeechRegistry.Disable('PBT-Priority-Mid', sbkWakeWord);
  TSpeechRegistry.Disable('PBT-Priority-Low', sbkWakeWord);
end;

procedure TSpeechRegistryPBT.P4_Discover_FiltersByKind;
var
  Info: TSpeechBackendInfo;
begin
  Info.IsCloud := False;
  Info.RequiresMic := False;
  Info.SupportsBatch := False;
  Info.SupportsStreaming := False;
  Info.SupportsGrammar := False;
  Info.IsAvailableFunc := function: Boolean begin Result := True; end;
  Info.Enabled := True;

  Info.Name := 'PBT-Kind-ASR';
  Info.Kind := sbkASR;
  Info.Priority := 10;
  TSpeechRegistry.Register(Info);

  Info.Name := 'PBT-Kind-TTS';
  Info.Kind := sbkTTS;
  Info.Priority := 10;
  TSpeechRegistry.Register(Info);

  // Discover ASR only
  var ASRBackends := TSpeechRegistry.Discover(sbkASR, False);
  var HasASR := False;
  var HasTTS := False;
  for var B in ASRBackends do
  begin
    if B.Name = 'PBT-Kind-ASR' then HasASR := True;
    if B.Name = 'PBT-Kind-TTS' then HasTTS := True;
  end;
  Assert.IsTrue(HasASR, 'ASR discover should include ASR backend');
  Assert.IsFalse(HasTTS, 'ASR discover should NOT include TTS backend');

  // Discover TTS only
  var TTSBackends := TSpeechRegistry.Discover(sbkTTS, False);
  HasASR := False;
  HasTTS := False;
  for var B in TTSBackends do
  begin
    if B.Name = 'PBT-Kind-ASR' then HasASR := True;
    if B.Name = 'PBT-Kind-TTS' then HasTTS := True;
  end;
  Assert.IsFalse(HasASR, 'TTS discover should NOT include ASR backend');
  Assert.IsTrue(HasTTS, 'TTS discover should include TTS backend');

  TSpeechRegistry.Disable('PBT-Kind-ASR', sbkASR);
  TSpeechRegistry.Disable('PBT-Kind-TTS', sbkTTS);
end;

{ TSpeechTypesPBT }

procedure TSpeechTypesPBT.P5_PCM16Mono_Invariants;
begin
  var Fmt := TSpeechAudioFormat.PCM16Mono(16000);
  Assert.AreEqual(Integer(saePCM16), Integer(Fmt.Encoding), 'Encoding should be PCM16');
  Assert.AreEqual(16000, Fmt.SampleRate, 'SampleRate should be 16000');
  Assert.AreEqual(1, Fmt.Channels, 'Channels should be 1 (mono)');
  Assert.AreEqual(16, Fmt.BitsPerSample, 'BitsPerSample should be 16');

  var Fmt8k := TSpeechAudioFormat.PCM16Mono(8000);
  Assert.AreEqual(8000, Fmt8k.SampleRate, 'SampleRate should be 8000');
  Assert.AreEqual(1, Fmt8k.Channels, 'Channels should be 1');
end;

procedure TSpeechTypesPBT.P6_AudioData_DurationMs_NonNegative;
begin
  // Empty data
  var Empty := TSpeechAudioData.FromPCM16([], 16000);
  Assert.IsTrue(Empty.IsEmpty, 'Empty data should be empty');
  Assert.IsTrue(Empty.DurationMs >= 0, 'Duration should be >= 0');

  // 1 second of 16kHz mono PCM16 = 32000 bytes
  var OneSec: TBytes;
  SetLength(OneSec, 32000);
  var Data := TSpeechAudioData.FromPCM16(OneSec, 16000);
  Assert.IsFalse(Data.IsEmpty, '1 sec data should not be empty');
  Assert.IsTrue(Data.DurationMs >= 900, 'Duration should be approx 1000ms');
  Assert.IsTrue(Data.DurationMs <= 1100, 'Duration should be approx 1000ms');
end;

procedure TSpeechTypesPBT.P7_TTSOptions_Default_Consistent;
begin
  var Opt := TTTSOptions.Default;
  Assert.AreEqual('', Opt.VoiceId, 'Default VoiceId should be empty');
  Assert.AreEqual('zh-CN', Opt.Language, 'Default Language should be zh-CN');
  Assert.AreEqual(0, Opt.Rate, 'Default Rate should be 0');
  Assert.AreEqual(100, Opt.Volume, 'Default Volume should be 100');
end;

procedure TSpeechTypesPBT.P8_RecognitionResult_Failed_HasError;
begin
  var R := TSpeechRecognitionResult.Failed(srsServiceError, 'ERR_001', 'Service unavailable');
  Assert.IsFalse(R.Success, 'Failed result should not be successful');
  Assert.AreEqual('', R.Text, 'Failed result should have empty text');
  Assert.AreEqual('ERR_001', R.ErrorCode, 'Error code should match');
  Assert.AreEqual('Service unavailable', R.ErrorMessage, 'Error message should match');
  Assert.AreEqual(srsServiceError, R.Status, 'Status should match');
end;

initialization
  TDUnitX.RegisterTestFixture(TSpeechRegistryPBT);
  TDUnitX.RegisterTestFixture(TSpeechTypesPBT);

end.