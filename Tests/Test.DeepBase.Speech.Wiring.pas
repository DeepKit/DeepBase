{ ============================================================================
  Test.DeepBase.Speech.Wiring
  ---------------------------------------------------------------------------
  Stage-0 regression coverage for the speech backend wiring gap (BUG-438 era
  follow-on): the registry now carries instance Factory closures so
  TSpeechService.WireFromRegistry can auto-inject backends without a hard
  cross-package uses dependency, and SAPI ASR is bridged via an adapter so it
  satisfies ISpeechRecognizerEx.

  Scope: these tests exercise the wiring layer only (registry Factory closures
  are present and callable; SAPI adapter implements the interface contract).
  They deliberately do NOT call TSpeechService.WireFromRegistry, because that
  mutates global class-var backends with no clean teardown (the registry has
  no Unregister) and would leak test-only mock backends into the shared
  backend list. WireFromRegistry's end-to-end behavior is exercised by the
  Speech fixture run in the verification stage instead.
  ============================================================================ }

unit Test.DeepBase.Speech.Wiring;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  DeepBase.Speech.Types,
  DeepBase.Speech.Registry,
  DeepBase.Speech.ASR.SAPI,
  DeepBase.Speech.ASR.SAPIAdapter;

type
  [TestFixture]
  TSpeechWiringTests = class
  public
    /// <summary>
    /// Each backend that is meant to be auto-wired must have a non-nil
    /// Factory closure of the right kind. Config-gated backends (StepFun)
    /// intentionally leave it nil. Verifies the registration blocks in the
    /// Edge/SenseVoice/SAPI units actually populated the new fields.
    /// </summary>
    [Test]
    procedure Registry_AutoWireBackends_HaveFactoryClosures;

    /// <summary>
    /// Discover returns backends sorted by priority ascending. For ASR the
    /// expected order is SenseVoice (5) before SAPI (20). Sanity-checks that
    /// the resolver still prefers the lower-numbered, better backend.
    /// </summary>
    [Test]
    procedure Registry_Discover_ASROrderedByPriority;

    /// <summary>
    /// The SAPI adapter implements ISpeechRecognizerEx and reports the
    /// SAPI backend kind. Kind is the discriminator WireFromRegistry's
    /// consumers use to pick streaming vs batch behavior.
    /// </summary>
    [Test]
    procedure SAPIAdapter_ImplementsInterface_ReportsSAPIKind;

    /// <summary>
    /// SAPI has no synchronous batch Recognize; the adapter surfaces this
    /// explicitly instead of returning a bogus success. SupportsBatch must be
    /// False so the resolver does not pick SAPI for a batch-only call, and
    /// Recognize returns srsProviderNotReady with a SAPI_BATCH_UNSUPPORTED
    /// code that callers can branch on.
    /// </summary>
    [Test]
    procedure SAPIAdapter_BatchRecognize_UnsupportedAndHonest;
  end;

implementation

{ TSpeechWiringTests }

procedure TSpeechWiringTests.Registry_AutoWireBackends_HaveFactoryClosures;
var
  LInfo: TSpeechBackendInfo;
  LEdgeFactory, LStepFunFactory: Boolean;
  LSenseFactory, LSAPIFactory: Boolean;
begin
  // Do NOT filter by availability (AOnlyAvailable=False) so the closure
  // presence is checked regardless of whether SenseVoice has a model loaded
  // or SAPI is present on this machine — those are environment concerns.
  LEdgeFactory := False;
  LStepFunFactory := False;
  LSenseFactory := False;
  LSAPIFactory := False;

  for LInfo in TSpeechRegistry.Discover(sbkTTS, False) do
  begin
    if SameText(LInfo.Name, 'Edge') then
      LEdgeFactory := Assigned(LInfo.TTSFactory)
    else if SameText(LInfo.Name, 'StepFun') then
      LStepFunFactory := Assigned(LInfo.TTSFactory);
  end;

  for LInfo in TSpeechRegistry.Discover(sbkASR, False) do
  begin
    if SameText(LInfo.Name, 'SenseVoice') then
      LSenseFactory := Assigned(LInfo.ASRFactory)
    else if SameText(LInfo.Name, 'SAPI') then
      LSAPIFactory := Assigned(LInfo.ASRFactory);
  end;

  // Auto-wireable backends MUST carry a factory.
  Assert.IsTrue(LEdgeFactory, 'Edge TTS backend must expose a TTSFactory for auto-wiring');
  Assert.IsTrue(LSenseFactory, 'SenseVoice ASR backend must expose an ASRFactory for auto-wiring');
  Assert.IsTrue(LSAPIFactory, 'SAPI ASR backend must expose an ASRFactory (via the adapter) for auto-wiring');

  // Config-gated backends intentionally leave the factory nil so WireFromRegistry
  // skips them and the consumer injects a configured instance explicitly.
  Assert.IsFalse(LStepFunFactory,
    'StepFun TTS backend must NOT expose a TTSFactory (it needs an API key; consumer registers explicitly)');
end;

procedure TSpeechWiringTests.Registry_Discover_ASROrderedByPriority;
var
  LList: TArray<TSpeechBackendInfo>;
  LSenseIdx, LSAPIIdx: Integer;
  I: Integer;
begin
  LList := TSpeechRegistry.Discover(sbkASR, False);
  Assert.IsTrue(Length(LList) >= 2, 'Expected at least two ASR backends registered (SenseVoice + SAPI)');

  LSenseIdx := -1;
  LSAPIIdx := -1;
  for I := 0 to High(LList) do
  begin
    if SameText(LList[I].Name, 'SenseVoice') then LSenseIdx := I;
    if SameText(LList[I].Name, 'SAPI') then LSAPIIdx := I;
  end;

  Assert.IsTrue(LSenseIdx >= 0, 'SenseVoice ASR backend not found in registry');
  Assert.IsTrue(LSAPIIdx >= 0, 'SAPI ASR backend not found in registry');
  // Lower priority number sorts first (better). SenseVoice (5) < SAPI (20).
  Assert.IsTrue(LSenseIdx < LSAPIIdx,
    'ASR discover order wrong: SenseVoice (priority 5) must come before SAPI (priority 20)');
end;

procedure TSpeechWiringTests.SAPIAdapter_ImplementsInterface_ReportsSAPIKind;
var
  LAdapter: ISpeechRecognizerEx;
begin
  // Create with nil inner so the adapter owns a fresh TDeepBaseSAPIASR; this
  // exercises the ownership branch independently of the GlobalSAPIASR singleton.
  LAdapter := TDeepBaseSAPIASRAdapter.Create(nil);
  try
    Assert.IsNotNull(LAdapter, 'SAPI adapter must be instantiable');
    Assert.IsTrue(LAdapter.Kind = abkSAPI, 'SAPI adapter Kind must be abkSAPI');
    Assert.IsTrue(LAdapter.SupportsStreaming, 'SAPI adapter must advertise streaming support');
  finally
    LAdapter := nil; // release ref-counted adapter (frees the owned inner)
  end;
end;

procedure TSpeechWiringTests.SAPIAdapter_BatchRecognize_UnsupportedAndHonest;
var
  LAdapter: ISpeechRecognizerEx;
  LResult: TSpeechRecognitionResult;
begin
  LAdapter := TDeepBaseSAPIASRAdapter.Create(nil);
  try
    // Batch must be advertised as unsupported so the resolver does not route
    // a batch-only request to SAPI.
    Assert.IsFalse(LAdapter.SupportsBatch,
      'SAPI adapter must NOT advertise batch support (Recognize is a stub)');

    // Recognize must fail honestly rather than return a fabricated success.
    // Note: we deliberately do NOT assert on CheckStatus here — that method
    // bridges the inner TDeepBaseSAPIASR, which talks to the SAPI COM stack,
    // an integration concern (COM init, engine availability) outside the
    // wiring-layer scope of this stage. Verify against a live SAPI engine in
    // the Speech fixture run instead.
    LResult := LAdapter.Recognize(Default(TSpeechAudioData), Default(TSpeechRecognitionOptions));
    Assert.IsTrue(LResult.Status = srsProviderNotReady,
      'SAPI batch Recognize must return srsProviderNotReady, got ' + IntToStr(Ord(LResult.Status)));
    Assert.IsTrue(SameText(LResult.ErrorCode, 'SAPI_BATCH_UNSUPPORTED'),
      'SAPI batch Recognize ErrorCode must be SAPI_BATCH_UNSUPPORTED, got ' + LResult.ErrorCode);
  finally
    LAdapter := nil;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TSpeechWiringTests);

end.
