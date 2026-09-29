unit Test.DeepBase.LicensingTimeSource;

{ Time-source wiring regressions for the licensing facade (WO-20260925-AUDIT-乙-B7).

  Before B7 the trial verdict read the raw wall clock while Core read its own
  clock, and an unverified clock was trusted by default. These tests pin the
  three properties the fix introduces: the judgement follows the single
  injectable Core clock, a rewound clock never revives an expired trial, and an
  unverified or rewound clock is refused instead of silently falling back.

  Framework note the tests depend on: the facade parses the stored expiry with
  AReturnUTC=False, which yields the *local naked* value of that UTC instant,
  and compares it with the Core clock, which is also local naked. The stored
  value is written here in the Zulu form the server actually sends. }

interface

uses
  System.SysUtils,
  System.DateUtils,
  DUnitX.TestFramework,
  DeepBase.Licensing,
  DeepBase.TimeGuard,
  DeepBase.TimeSource;

type
  /// <summary>Server time handed to TTimeGuard.Verify; 0 simulates an unreachable server.</summary>
  TFakeTimeGuardTransport = class(TInterfacedObject, ITimeGuardHttpTransport)
  private
    FServerTime: TDateTime;
  public
    constructor Create(const AServerTime: TDateTime);
    function FetchServerTime(const AUrl: string): TDateTime;
  end;

  /// <summary>Holds the single last-known-good value the guard persists.</summary>
  TFakeTimeGuardStore = class(TInterfacedObject, ITimeGuardSecretStore)
  public
    Value: string;
    procedure SaveSecret(const AKey, AValue: string);
    function LoadSecret(const AKey: string): string;
  end;

  [TestFixture]
  TLicensingTimeSourceTests = class
  private
    FLicensing: TDeepLicensing;
    FStore: TFakeTimeGuardStore;
    function AnchorNoon: TDateTime;
    function LocalOf(const AUtcInstant: TDateTime): TDateTime;
    procedure InstallGuardWith(const AServerTime: TDateTime;
      const ALastKnownGood: TDateTime);
    procedure UseFakeClock(const ANow: TDateTime);
    procedure WriteTrialExpiring(const AUtcExpiry: TDateTime);
  public
    [Setup] procedure Setup;
    [Teardown] procedure TearDown;

    [Test] procedure Test_TrialDays_FollowInjectedCoreClockNotWallClock;
    [Test] procedure Test_RewoundClockAfterWatermark_ExpiredTrialStaysExpired;
    [Test] procedure Test_ClockRewoundByGuard_TrialRejectedAndCorrectedNowRefused;
    [Test] procedure Test_NeverVerifiedFacade_ReportsUntrustedAndRefusesCorrectedNow;
    [Test] procedure Test_MinorSkewClock_StillTrusted_TrialDaysUnchanged;
    [Test] procedure Test_MajorSkewClock_RefusedAndNotSeededIntoCoreClock;
    [Test] procedure Test_ServerCorrectedTime_SeededIntoCoreClockShortensTrial;
  end;

implementation

uses
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef,
  DeepBase.Config,
  DeepBase.Manager,
  // The trial window lives in config storage, so this fixture declares its own
  // DB adapter and SQLite driver link: with them linked the unit runs outside the
  // product dpr, and without them InitializeWithDB fails loud instead of silently
  // reporting "no expiry stored".
  DeepBase.Persistence.Manager.FireDAC;

const
  TRIAL_KEY_STARTED = 'Licensing.TrialStarted';
  TRIAL_KEY_EXPIRES = 'Licensing.TrialExpiresAt';
  LICENSING_CATEGORY = 'Licensing';

{ TFakeTimeGuardTransport }

constructor TFakeTimeGuardTransport.Create(const AServerTime: TDateTime);
begin
  inherited Create;
  FServerTime := AServerTime;
end;

function TFakeTimeGuardTransport.FetchServerTime(const AUrl: string): TDateTime;
begin
  Result := FServerTime;
end;

{ TFakeTimeGuardStore }

procedure TFakeTimeGuardStore.SaveSecret(const AKey, AValue: string);
begin
  Value := AValue;
end;

function TFakeTimeGuardStore.LoadSecret(const AKey: string): string;
begin
  Result := Value;
end;

{ TLicensingTimeSourceTests }

function TLicensingTimeSourceTests.AnchorNoon: TDateTime;
begin
  // Far-future anchor keeps every assertion independent of the real date. It is
  // used as a UTC instant, and the clock the facade reads is derived from it, so
  // the local time zone cancels out as well.
  Result := EncodeDateTime(2031, 3, 1, 12, 0, 0, 0);
end;

function TLicensingTimeSourceTests.LocalOf(const AUtcInstant: TDateTime): TDateTime;
begin
  // Same conversion the facade's parse performs, so the injected clock and the
  // stored expiry are in one framework on any machine.
  Result := TTimeZone.Local.ToLocalTime(AUtcInstant);
end;

procedure TLicensingTimeSourceTests.Setup;
var
  Config: TDeepLicensingProductConfig;
begin
  // Reset the shared clock first so a leak from another fixture cannot decide
  // these verdicts, and so these tests cannot leak into the next ones.
  TDeepBaseTimeSource.Shared.Reset;
  Assert.IsTrue(DeepBase.Manager.DeepBase.InitializeWithDB(':memory:'),
    'Config storage must initialize for the trial chain to be testable: '
    + DeepBase.Manager.DeepBase.LastError);
  DeleteConfig(TRIAL_KEY_STARTED);
  DeleteConfig(TRIAL_KEY_EXPIRES);

  FStore := TFakeTimeGuardStore.Create;

  // Port 1 on loopback is closed, so the device login fails fast and the
  // fixture stays on the offline path; SafeClient requires a non-empty base URL.
  Config := TDeepLicensingProductConfig.Create('deepbase_test', 'DTEST',
    'http://127.0.0.1:1');
  FLicensing := TDeepLicensing.Create(Config);
  FLicensing.Initialize;
end;

procedure TLicensingTimeSourceTests.TearDown;
begin
  FreeAndNil(FLicensing);
  FStore := nil;
  DeleteConfig(TRIAL_KEY_STARTED);
  DeleteConfig(TRIAL_KEY_EXPIRES);
  TDeepBaseTimeSource.Shared.Reset;
end;

procedure TLicensingTimeSourceTests.InstallGuardWith(const AServerTime: TDateTime;
  const ALastKnownGood: TDateTime);
var
  Transport: TFakeTimeGuardTransport;
begin
  Transport := TFakeTimeGuardTransport.Create(AServerTime);
  if ALastKnownGood > 0 then
    FStore.Value := DateToISO8601(ALastKnownGood, False);

  // The guard belongs to the facade and is created by Initialize; its own test
  // seams are used here, so no production seam exists for tests alone.
  FLicensing.TimeGuard.SetHttpTransport(Transport);
  FLicensing.TimeGuard.SetSecretStore(FStore);
end;

procedure TLicensingTimeSourceTests.UseFakeClock(const ANow: TDateTime);
var
  FixedNow: TDateTime;
begin
  FixedNow := ANow;
  TDeepBaseTimeSource.Shared.SetNowFunc(
    function: TDateTime
    begin
      Result := FixedNow;
    end);
end;

procedure TLicensingTimeSourceTests.WriteTrialExpiring(const AUtcExpiry: TDateTime);
begin
  SetConfig(TRIAL_KEY_STARTED, 'true', LICENSING_CATEGORY);
  SetConfig(TRIAL_KEY_EXPIRES, DateToISO8601(AUtcExpiry, True),
    LICENSING_CATEGORY);
end;

procedure TLicensingTimeSourceTests.Test_TrialDays_FollowInjectedCoreClockNotWallClock;
var
  UtcExpiry, LocalExpiry, Parsed: TDateTime;
begin
  UtcExpiry := IncDay(AnchorNoon, 10);
  LocalExpiry := LocalOf(UtcExpiry);
  WriteTrialExpiring(UtcExpiry);

  // Pins the framework the judgement relies on: parsing the stored Zulu instant
  // with AReturnUTC=False yields the local naked value, which is what the Core
  // clock is also expressed in.
  Assert.IsTrue(TryISO8601ToDate(GetConfig(TRIAL_KEY_EXPIRES), Parsed, False),
    'Stored trial expiry must parse');
  Assert.AreEqual(FormatDateTime('yyyymmddhhnnss', LocalExpiry),
    FormatDateTime('yyyymmddhhnnss', Parsed),
    'Stored expiry and the clock must land in the same time framework');

  // A server clock that agrees with the wall clock makes the clock trusted; the
  // trial verdict then has to come from the injectable Core clock, not the wall
  // clock, which is what makes the verdict testable and single-tracked.
  InstallGuardWith(System.SysUtils.Now, 0);
  Assert.AreEqual(Ord(tgOk), Ord(FLicensing.VerifyTime),
    'Server time within tolerance must classify the clock as trusted');

  UseFakeClock(IncDay(LocalExpiry, -7));
  Assert.AreEqual(7, FLicensing.GetTrialDaysRemaining,
    'Trial days must be computed from the injected Core clock');
  Assert.IsTrue(FLicensing.IsTrialActive,
    'A trial inside its window on the Core clock must stay active');
end;

procedure TLicensingTimeSourceTests.Test_RewoundClockAfterWatermark_ExpiredTrialStaysExpired;
var
  LocalExpiry: TDateTime;
begin
  LocalExpiry := LocalOf(IncDay(AnchorNoon, 10));
  WriteTrialExpiring(IncDay(AnchorNoon, 10));
  InstallGuardWith(System.SysUtils.Now, 0);
  Assert.AreEqual(Ord(tgOk), Ord(FLicensing.VerifyTime));

  // Drive the clock past expiry so the shared clock records that instant as its
  // monotonic watermark.
  UseFakeClock(IncDay(LocalExpiry, 30));
  Assert.AreEqual(0, FLicensing.GetTrialDaysRemaining,
    'Trial must read as expired once the clock passed its expiry');

  // Then rewind the fake clock by 30 days: the watermark only moves forward, so
  // the expired trial cannot be revived — the end-to-end revival failure this
  // work order requires.
  UseFakeClock(LocalExpiry);
  Assert.AreEqual(0, FLicensing.GetTrialDaysRemaining,
    'Rewinding the clock by 30 days after expiry must not grant trial days again');
  Assert.IsFalse(FLicensing.IsTrialActive,
    'A rewound clock must not reactivate an expired trial');
  Assert.IsTrue(TDeepBaseTimeSource.Shared.RollbackCount > 0,
    'The rewind itself must stay observable');
  Assert.AreEqual(Int64(30 * 86400), TDeepBaseTimeSource.Shared.MaxRollbackSeconds,
    'The recorded rewind magnitude must be the full 30 days');
end;

procedure TLicensingTimeSourceTests.Test_ClockRewoundByGuard_TrialRejectedAndCorrectedNowRefused;
begin
  // The trial window is wide open on the fake clock; only the guard can reject it.
  WriteTrialExpiring(IncDay(AnchorNoon, 400));

  // An unreachable server plus a last-known-good value ahead of the local clock
  // is the clock-rewound signal.
  InstallGuardWith(0, IncDay(System.SysUtils.Now, 40));
  Assert.AreEqual(Ord(tgClockRewound), Ord(FLicensing.VerifyTime),
    'Local time below last known good must classify as ClockRewound');

  UseFakeClock(IncDay(LocalOf(AnchorNoon), 3));
  Assert.IsFalse(FLicensing.IsTimeTrusted,
    'A rewound clock must not be reported as trusted');
  Assert.AreEqual(0, FLicensing.GetTrialDaysRemaining,
    'A rewound clock must not grant trial days');
  Assert.WillRaise(
    procedure begin FLicensing.GetCorrectedNow; end,
    EDeepBaseLicensingTimeUntrusted,
    'GetCorrectedNow must refuse instead of falling back to the wall clock');
end;

procedure TLicensingTimeSourceTests.Test_NeverVerifiedFacade_ReportsUntrustedAndRefusesCorrectedNow;
var
  Licensing: TDeepLicensing;
  Config: TDeepLicensingProductConfig;
begin
  // Fail-closed replaces the previous "trust by default": a facade whose guard
  // never completed a verification reports untrusted.
  Config := TDeepLicensingProductConfig.Create('deepbase_test', 'DTEST',
    'http://127.0.0.1:1');
  Licensing := TDeepLicensing.Create(Config);
  try
    Assert.IsFalse(Licensing.IsInitialized,
      'A fresh facade is the never-verified state under test');
    Assert.IsFalse(Licensing.IsTimeTrusted,
      'An unverified clock must not be reported as trusted');
    Assert.WillRaise(
      procedure begin Licensing.GetCorrectedNow; end,
      EDeepBaseLicensingTimeUntrusted,
      'GetCorrectedNow must fail closed before any clock was verified');
  finally
    Licensing.Free;
  end;
end;

procedure TLicensingTimeSourceTests.Test_MinorSkewClock_StillTrusted_TrialDaysUnchanged;
var
  LocalExpiry: TDateTime;
begin
  // Drift inside twice the tolerated window stays trusted, so the verdict on the
  // honest path must not have been tightened by the fail-closed change: the same
  // 7 days as the fully trusted case.
  LocalExpiry := LocalOf(IncDay(AnchorNoon, 10));
  WriteTrialExpiring(IncDay(AnchorNoon, 10));
  InstallGuardWith(IncMinute(System.SysUtils.Now, 7), 0);
  Assert.AreEqual(Ord(tgSkewMinor), Ord(FLicensing.VerifyTime),
    'Seven minutes of server drift stays inside the tolerated skew');
  Assert.IsTrue(FLicensing.IsTimeTrusted,
    'A minor skew clock must stay trusted');

  UseFakeClock(IncDay(LocalExpiry, -7));
  Assert.AreEqual(7, FLicensing.GetTrialDaysRemaining,
    'A tolerated skew must not shorten the trial verdict');
  Assert.IsTrue(FLicensing.IsTrialActive,
    'A tolerated skew must not deactivate the trial');
end;

procedure TLicensingTimeSourceTests.Test_MajorSkewClock_RefusedAndNotSeededIntoCoreClock;
begin
  // A clock days away from the server is suspicious: it must be refused, and its
  // reading must never be pushed into the monotonic watermark, otherwise a
  // fake-ahead server could extend a licence window.
  WriteTrialExpiring(IncDay(AnchorNoon, 400));
  InstallGuardWith(IncDay(System.SysUtils.Now, 3), 0);
  Assert.AreEqual(Ord(tgSkewMajor), Ord(FLicensing.VerifyTime),
    'Three days of server drift must classify as MajorSkew');
  Assert.IsFalse(FLicensing.IsTimeTrusted,
    'A major skew clock must not be reported as trusted');

  UseFakeClock(IncDay(LocalOf(AnchorNoon), 3));
  Assert.AreEqual(0, FLicensing.GetTrialDaysRemaining,
    'A major skew clock must not grant trial days');
  Assert.WillRaise(
    procedure begin FLicensing.GetCorrectedNow; end,
    EDeepBaseLicensingTimeUntrusted,
    'GetCorrectedNow must refuse a major skew clock');
  Assert.IsTrue(TDeepBaseTimeSource.Shared.LastSeen <= 0,
    'A refused reading must not seed the monotonic watermark');
end;

procedure TLicensingTimeSourceTests.Test_ServerCorrectedTime_SeededIntoCoreClockShortensTrial;
var
  WallNow: TDateTime;
begin
  // This window is anchored to the real wall clock instead of the far-future
  // anchor, because the property under test is that the reading the server
  // confirmed actually flows into the verdict: five days behind that reading is
  // the injected clock, so the seed is what keeps the verdict short. The
  // half-day slack keeps the whole-day truncation stable against the
  // millisecond jitter between these wall-clock snapshots.
  WallNow := System.SysUtils.Now;
  WriteTrialExpiring(TTimeZone.Local.ToUniversalTime(IncHour(IncDay(WallNow, 3), 6)));

  // A server that agrees with the wall clock is trusted, and its corrected
  // reading is the wall clock itself.
  InstallGuardWith(WallNow, 0);
  Assert.AreEqual(Ord(tgOk), Ord(FLicensing.VerifyTime));

  // Without the watermark seed the verdict would be eight days: the trial would
  // silently follow whatever the process clock claims instead of what the server
  // confirmed.
  UseFakeClock(IncDay(WallNow, -5));
  Assert.AreEqual(3, FLicensing.GetTrialDaysRemaining,
    'The server-confirmed reading must shorten the verdict, not the fake clock behind it');
end;

initialization
  TDUnitX.RegisterTestFixture(TLicensingTimeSourceTests);

end.
