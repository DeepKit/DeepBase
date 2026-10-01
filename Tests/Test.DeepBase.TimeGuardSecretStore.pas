{ ============================================================================
  Test.DeepBase.TimeGuardSecretStore - acceptance net for the TimeGuard
  watermark wiring (WO-20260929-AUDIT-甲-A11).

  The defect this pins: TTimeGuard could only detect a rewound clock through a
  persisted last-known-good watermark, but nothing in production ever gave it a
  secret store, so the watermark never survived a process restart and both
  rewind branches of Verify were unreachable. These tests hold the properties
  the fix introduces:

    - the adapter round-trips the watermark through a real ISecretStore backend
      under the same key, and reports a missing key as empty instead of raising;
    - a clock that goes backwards against the persisted watermark is refused
      (tgClockRewound, clock not trusted) through the default wiring, i.e. with
      no test-only injection of a store;
    - a machine without a credential backend keeps an honest reading
      (tgOk/tgOffline) — an environment gap must not turn into a refusal.

  Where a test touches the platform backend it allocates a unique key per case
  and deletes every key it created in the teardown, so the suite leaves no
  credential behind. }

unit Test.DeepBase.TimeGuardSecretStore;

interface

uses
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.Generics.Collections,
  DUnitX.TestFramework,
  DeepBase.Security.SecretStore,
  DeepBase.TimeGuard,
  DeepBase.TimeGuard.SecretStore;

type
  /// <summary>
  /// In-memory ISecretStore so the adapter's own contract is testable without
  /// machine state; the two raise switches stand in for a backend that fails.
  /// </summary>
  TFakeSecretBackend = class(TInterfacedObject, ISecretStore)
  private
    FValues: TDictionary<string, string>;
  public
    RaiseOnGet: Boolean;
    RaiseOnPut: Boolean;
    constructor Create;
    destructor Destroy; override;
    function TryGet(const AKey: string; out AValue: string): Boolean;
    procedure Put(const AKey: string; const AValue: string);
    procedure Delete(const AKey: string);
    function IsAvailable: Boolean;
    function Stored(const AKey: string): string;
  end;

  /// <summary>Server reading handed to Verify; 0 stands for an unreachable server.</summary>
  TFakeTimeServer = class(TInterfacedObject, ITimeGuardHttpTransport)
  private
    FServerTime: TDateTime;
  public
    constructor Create(const AServerTime: TDateTime);
    function FetchServerTime(const AUrl: string): TDateTime;
  end;

  [TestFixture]
  TTimeGuardSecretStoreTests = class
  private
    FProbeKeys: TStringList;
    function NewProbeKey(const ARole: string): string;
    function HasCredentialBackend: Boolean;
    function BackendContains(const AKey: string): Boolean;
    procedure SafeDelete(const AKey: string);
  public
    [Setup] procedure Setup;
    [Teardown] procedure TearDown;

    [Test] procedure Adapter_RoundTrips_ValueUnderTheSameKey;
    [Test] procedure Adapter_UnknownKey_LoadsEmptyWithoutRaising;
    [Test] procedure BackendFailures_DoNotEscapeThroughVerify;
    [Test] procedure CreateTimeGuardStore_NeverRaises_AndMatchesBackend;
    [Test] procedure DefaultWiring_RewoundClock_IsRefused;
    [Test] procedure WithoutWatermark_Offline_KeepsHonestReading;
  end;

implementation

const
  // A watermark value in the form TimeGuard's persistence layer actually writes.
  SENTINEL = '2031-03-01T12:00:00Z';

{ TFakeSecretBackend }

constructor TFakeSecretBackend.Create;
begin
  inherited Create;
  FValues := TDictionary<string, string>.Create;
  RaiseOnGet := False;
  RaiseOnPut := False;
end;

destructor TFakeSecretBackend.Destroy;
begin
  FValues.Free;
  inherited;
end;

function TFakeSecretBackend.TryGet(const AKey: string; out AValue: string): Boolean;
begin
  if RaiseOnGet then
    raise ESecretStoreUnavailable.Create('simulated backend read failure');
  Result := FValues.TryGetValue(AKey, AValue);
end;

procedure TFakeSecretBackend.Put(const AKey: string; const AValue: string);
begin
  if RaiseOnPut then
    raise ESecretStoreUnavailable.Create('simulated backend write failure');
  FValues.AddOrSetValue(AKey, AValue);
end;

procedure TFakeSecretBackend.Delete(const AKey: string);
begin
  FValues.Remove(AKey);
end;

function TFakeSecretBackend.IsAvailable: Boolean;
begin
  Result := True;
end;

function TFakeSecretBackend.Stored(const AKey: string): string;
begin
  FValues.TryGetValue(AKey, Result);
end;

{ TFakeTimeServer }

constructor TFakeTimeServer.Create(const AServerTime: TDateTime);
begin
  inherited Create;
  FServerTime := AServerTime;
end;

function TFakeTimeServer.FetchServerTime(const AUrl: string): TDateTime;
begin
  Result := FServerTime;
end;

{ TTimeGuardSecretStoreTests }

procedure TTimeGuardSecretStoreTests.Setup;
begin
  FProbeKeys := TStringList.Create;
end;

function TTimeGuardSecretStoreTests.NewProbeKey(const ARole: string): string;
var
  LGuid: TGUID;
begin
  CreateGUID(LGuid);
  Result := 'deepbase.a11.' + ARole + '.' +
    GUIDToString(LGuid).Trim(['{', '}']).ToLower;
  FProbeKeys.Add(Result);
end;

function TTimeGuardSecretStoreTests.HasCredentialBackend: Boolean;
begin
  Result := CreateTimeGuardSecretStore <> nil;
end;

function TTimeGuardSecretStoreTests.BackendContains(const AKey: string): Boolean;
var
  LDummy: string;
begin
  Result := TSecretStoreFactory.CreatePlatformStore.TryGet(AKey, LDummy);
end;

procedure TTimeGuardSecretStoreTests.Adapter_RoundTrips_ValueUnderTheSameKey;
var
  LBackend: ISecretStore;
  LFake: TFakeSecretBackend;
  LAdapter: ITimeGuardSecretStore;
begin
  LFake := TFakeSecretBackend.Create;
  LBackend := LFake;
  LAdapter := TTimeGuardSecretStore.Create(LBackend);

  LAdapter.SaveSecret('a11.watermark', SENTINEL);

  Assert.AreEqual(SENTINEL, LAdapter.LoadSecret('a11.watermark'),
    'The watermark must come back byte for byte');
  Assert.AreEqual(SENTINEL, LFake.Stored('a11.watermark'),
    'The adapter must hand the backend the same key TimeGuard asked for');
end;

procedure TTimeGuardSecretStoreTests.Adapter_UnknownKey_LoadsEmptyWithoutRaising;
var
  LBackend: ISecretStore;
  LAdapter: ITimeGuardSecretStore;
begin
  LBackend := TFakeSecretBackend.Create;
  LAdapter := TTimeGuardSecretStore.Create(LBackend);

  // An escaping exception is reported as a test error by the runner, so this
  // assertion also pins "the adapter does not raise on a missing key".
  Assert.AreEqual('', LAdapter.LoadSecret('a11.absent'),
    'A key the backend never held loads as empty, not as an error');
end;

procedure TTimeGuardSecretStoreTests.BackendFailures_DoNotEscapeThroughVerify;
var
  LBackend: TFakeSecretBackend;
  LAdapter: ITimeGuardSecretStore;
  LGuard: TTimeGuard;
  LResult: TTimeGuardResult;
begin
  LBackend := TFakeSecretBackend.Create;
  LBackend.RaiseOnGet := True;
  LBackend.RaiseOnPut := True;
  LAdapter := TTimeGuardSecretStore.Create(LBackend);

  // A backend that fails in both directions is the worst case for the wiring:
  // the clock verdict must stay honest instead of turning into an exception, or
  // into a refusal the caller cannot distinguish from real tampering.
  LGuard := TTimeGuard.Create(NewProbeKey('fail'), 5);
  try
    LGuard.SetServerUrl('http://127.0.0.1:1');
    LGuard.SetHttpTransport(TFakeTimeServer.Create(
      TTimeZone.Local.ToUniversalTime(System.SysUtils.Now)));
    LGuard.SetSecretStore(LAdapter);

    // No try/except of its own here: an exception escaping Verify would surface
    // as a runner error, which is what pins "the call chain does not leak".
    LResult := LGuard.Verify;
    Assert.IsTrue(LResult in [tgOk, tgSkewMinor, tgOffline],
      'Without a watermark there is nothing to compare against, got '
      + TimeGuardResultToStr(LResult));
    Assert.IsTrue(LGuard.IsTimeTrusted,
      'A backend failure must not be reported as an untrusted clock');
  finally
    LGuard.Free;
  end;
end;

procedure TTimeGuardSecretStoreTests.CreateTimeGuardStore_NeverRaises_AndMatchesBackend;
var
  LAdapter: ITimeGuardSecretStore;
  LKey: string;
begin
  // Reaching the next assertion at all is the proof that a missing backend
  // answers nil instead of raising into the caller.
  LAdapter := CreateTimeGuardSecretStore;

{$IF DEFINED(MSWINDOWS)}
  // Credential Manager is always there on Windows, so a nil adapter here would
  // mean the adapter itself is broken rather than the environment being bare.
  // Without this the branch below could go green by taking the easy path.
  Assert.IsTrue(HasCredentialBackend,
    'Windows offers a credential backend, so the adapter must be usable');
{$ENDIF}

  if HasCredentialBackend then
  begin
    // The production path on a machine that does have a backend: write through
    // the adapter, read the same bytes back, and let TearDown remove the key.
    LKey := NewProbeKey('live');
    LAdapter.SaveSecret(LKey, SENTINEL);
    Assert.AreEqual(SENTINEL, LAdapter.LoadSecret(LKey),
      'The platform backend must persist the watermark as written');
    Assert.IsTrue(BackendContains(LKey),
      'The watermark must land in the platform store, not only in the adapter');
  end
  else
    Assert.IsNull(LAdapter,
      'With no credential backend the adapter must be absent, not a failing stub');
end;

procedure TTimeGuardSecretStoreTests.DefaultWiring_RewoundClock_IsRefused;
var
  LKey: string;
  LAhead: TDateTime;
  LFirst: TTimeGuard;
  LSecond: TTimeGuard;
begin
  LKey := NewProbeKey('rewind');
  // The server reading sits a day ahead, so the watermark both instances
  // compare against is a day in front of the wall clock that follows.
  LAhead := IncDay(System.SysUtils.Now, 1);

  // No SetSecretStore call anywhere in this case: the watermark has to reach
  // storage through the default wiring, which is what production does.
{$IF DEFINED(MSWINDOWS)}
  Assert.IsTrue(HasCredentialBackend,
    'The rewinding verdict below is only meaningful against a live backend');
{$ENDIF}
  LFirst := TTimeGuard.Create(LKey, 5);
  try
    LFirst.SetServerUrl('http://127.0.0.1:1');
    LFirst.SetHttpTransport(TFakeTimeServer.Create(LAhead));
    Assert.AreEqual(Ord(tgSkewMajor), Ord(LFirst.Verify),
      'A day of server drift classifies as MajorSkew and still records the watermark');

    if not HasCredentialBackend then
    begin
      // No backend on this machine: the watermark cannot persist, so the next
      // instance has nothing to compare against. Assert that honest degradation
      // instead of pretending the rewind was detected.
      Assert.IsFalse(BackendContains(LKey),
        'Without a backend the watermark must not be reported as persisted');
      Exit;
    end;

    Assert.IsTrue(BackendContains(LKey),
      'The default wiring must have persisted the watermark itself');
  finally
    LFirst.Free;
  end;

  // A fresh instance is the next process launch: it reloads the watermark from
  // storage while the local clock is still a day behind it.
  LSecond := TTimeGuard.Create(LKey, 5);
  try
    LSecond.SetServerUrl('http://127.0.0.1:1');
    LSecond.SetHttpTransport(TFakeTimeServer.Create(0));
    Assert.AreEqual(Ord(tgClockRewound), Ord(LSecond.Verify),
      'A clock below the persisted watermark must be refused as rewound');
    Assert.IsFalse(LSecond.IsTimeTrusted,
      'A rewound clock must not be reported as trusted');
    Assert.IsTrue(Abs(LSecond.LastKnownGoodTime - LAhead) < 1 / 1440,
      'The refusal must come from the reloaded watermark, not from the local clock');
  finally
    LSecond.Free;
  end;
end;

procedure TTimeGuardSecretStoreTests.WithoutWatermark_Offline_KeepsHonestReading;
var
  LGuard: TTimeGuard;
begin
  // A key nothing has ever written to: the first launch of an installation.
  LGuard := TTimeGuard.Create(NewProbeKey('first'), 5);
  try
    LGuard.SetServerUrl('http://127.0.0.1:1');
    LGuard.SetHttpTransport(TFakeTimeServer.Create(0));
    Assert.AreEqual(Ord(tgOffline), Ord(LGuard.Verify),
      'An unreachable server with no watermark is offline, not a rewind');
    Assert.IsTrue(LGuard.IsTimeTrusted,
      'The first launch must not be refused for lacking a watermark');
  finally
    LGuard.Free;
  end;
end;

procedure TTimeGuardSecretStoreTests.TearDown;
var
  I: Integer;
begin
  for I := 0 to FProbeKeys.Count - 1 do
    SafeDelete(FProbeKeys[I]);
  FreeAndNil(FProbeKeys);
end;

procedure TTimeGuardSecretStoreTests.SafeDelete(const AKey: string);
var
  LStore: ISecretStore;
begin
  try
    LStore := TSecretStoreFactory.CreatePlatformStore;
    LStore.Delete(AKey);
  except
    // Cleanup only: a missing or unusable backend has nothing to delete, and a
    // teardown error must not decide the verdict of a test that already passed.
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TTimeGuardSecretStoreTests);

end.
