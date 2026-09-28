{ ============================================================================
  Test.DeepBase.TimeSource - A5-R09 判据用例（Core 单一时钟源 + last-seen 水位）

  覆盖：
    1. 时钟源契约：可注入、nil 回到墙钟、EffectiveNow = Max(读数, 水位)、
       回拨可观测、SeedWatermark 只升不降。
    2. 许可面：回拨 30 天不得让到期许可续命；剩余天数按水位计；载荷里的
       last-seen（字段 l）只能推进水位；伪造更早 l 被拒且不动水位；
       无 l 字段的历史载荷走进程水位。
    3. 密钥面：TKeyInfo.IsExpired / DaysUntilExpiry 与建钥时间戳、有效期
       窗口全部走同一个时钟源。

  时钟状态纪律：每个用例 [Setup] Reset 共享时钟、[TearDown] 再 Reset。水位是
  进程级单调量，不 Reset 会把注入的未来时间泄漏给后续 fixture，也会让本 fixture
  的起点依赖别人先跑过什么。
  ============================================================================ }

unit Test.DeepBase.TimeSource;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils,
  System.NetEncoding,
  System.IOUtils,
  Winapi.Windows,
  DeepBase.TimeSource,
  DeepBase.License,
  DeepBase.KeyManager;

type
  [TestFixture]
  TTimeSourceContractTests = class
  private
    FClock: TDeepBaseTimeSource;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Default_Reading_TracksWallClock;
    [Test]
    procedure Injected_Reading_ReplacesWallClock;
    [Test]
    procedure NilFunc_RestoresWallClock;
    [Test]
    procedure Rollback_ReturnsWatermark_AndIsCounted;
    [Test]
    procedure Watermark_NeverRetreatsAcrossMixedReads;
    [Test]
    procedure SeedWatermark_RaisesOnly;
    [Test]
    procedure SeedWatermark_IgnoresUnassignedValue;
  end;

  [TestFixture]
  TLicenseClockRollbackTests = class
  private
    FClock: TDeepBaseTimeSource;
    FLicense: TDeepBaseLicense;
    FPreviousSecret: string;
    function DecodedPayload(const LicenseKey: string): string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ExpiredLicense_StaysExpired_AfterThirtyDayRollback;
    [Test]
    procedure DaysRemaining_CountsFromWatermark_NotFromRolledBackClock;
    [Test]
    procedure OlderGenuineLicense_WithLowerLastSeen_DoesNotLowerWatermark;
    [Test]
    procedure LegacyLicense_WithoutLastSeenField_StillJudgedByWatermark;
    [Test]
    procedure GenerateLicenseKey_PersistsLastSeenField;
    [Test]
    procedure ForgedLowerLastSeen_IsRejected_AndWatermarkUnchanged;
  end;

  [TestFixture]
  TKeyClockRollbackTests = class
  private
    FClock: TDeepBaseTimeSource;
    FStorePath: string;
    FMaster: TMasterKey;
    FStore: TKeyStore;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure ExpiredKeyInfo_StaysExpired_AfterRollback;
    [Test]
    procedure DaysUntilExpiry_CountsFromWatermark;
    [Test]
    procedure MasterKeyCreatedAt_ComesFromSharedClock;
    [Test]
    procedure DataKeyCreatedAt_ComesFromSharedClock;
    [Test]
    procedure CreatedKeyExpiryWindow_ComesFromSharedClock;
  end;

implementation

const
  // 与 Tests/Test.DeepBase.License.pas 同一个 CI-only 测试签名密钥（非生产凭据）
  TEST_LICENSE_SECRET_ENV = 'DEEPBASE_LEGACY_LICENSE_SIGNING_KEY';
  TEST_LICENSE_SECRET = 'DeepBase-License-CI-Only';

  // 修前（载荷里没有 last-seen 字段）签发的真实历史许可：ExpiresAt=2027-08-15、
  // ltEnterprise（跳过设备绑定，可跨机复现）。故意冻结成字面量——它代表升级前
  // 就存在的许可文件的载荷，修后的生成器已经造不出不带 l 的 key。
  LEGACY_KEY_WITHOUT_LAST_SEEN =
    'eyJ2IjoiMS4wIiwidCI6NCwiZSI6MTgxODI4ODAwMCwiaSI6MTc5MDY0NzY1MCwidG8iOiJBNS1SMDkgTGVnYWN5IEZpeHR1cmUiLCJkIjoiIiwidSI6MSwiZiI6W119' +
    '.870f18927ea6f5d216a99bf054cbf153';

{ 基准时刻一律取正午：TDateTime 的 0 兼作"未赋值"，午夜整点又正好压在 DaysBetween
  的日期边界上，两个都容易让断言读不出真实语义。 }
function Noon(AY: Integer; AMonth, ADay: Word): TDateTime;
begin
  Result := EncodeDate(AY, AMonth, ADay) + 12 / 24;
end;

{ TDateTime 是二进制小数，而许可载荷只带整秒（DateTimeToUnix）：同一时刻往返一次
  会掉亚秒位，所以跨序列化边界的时刻比较一律留 1e-8 日（约 0.86ms）容差。 }
procedure AssertSameMoment(const AExpected, AActual: TDateTime; const AMessage: string = '');
begin
  Assert.IsTrue(Abs(AActual - AExpected) < 1e-8,
    Format('%s (expected %.10f, got %.10f)', [AMessage, AExpected, AActual]));
end;

{ 把共享时钟钉在某个读数上。闭包必须捕获局部变量：捕获 const 形参会随调用帧销毁。 }
procedure PinClock(const AValue: TDateTime);
var
  Captured: TDateTime;
begin
  Captured := AValue;
  TDeepBaseTimeSource.Shared.SetNowFunc(
    function: TDateTime
    begin
      Result := Captured;
    end);
end;

{ TTimeSourceContractTests }

procedure TTimeSourceContractTests.Setup;
begin
  FClock := TDeepBaseTimeSource.Shared;
  FClock.Reset;
end;

procedure TTimeSourceContractTests.TearDown;
begin
  FClock.Reset;
end;

procedure TTimeSourceContractTests.Default_Reading_TracksWallClock;
begin
  Assert.IsTrue(SecondsBetween(FClock.Now, System.SysUtils.Now) < 5,
    'without injection the shared clock must hand out the wall clock');
  Assert.AreEqual(0, FClock.RollbackCount, 'a wall clock reading is not a rollback');
end;

procedure TTimeSourceContractTests.Injected_Reading_ReplacesWallClock;
var
  Fixed: TDateTime;
begin
  Fixed := Noon(2030, 3, 4);
  PinClock(Fixed);

  AssertSameMoment(Fixed, FClock.Now, 'injected reading must be the only reading');
  AssertSameMoment(Fixed, FClock.LastSeen, 'the reading advances the watermark');
end;

procedure TTimeSourceContractTests.NilFunc_RestoresWallClock;
begin
  PinClock(Noon(2000, 1, 1));
  AssertSameMoment(Noon(2000, 1, 1), FClock.Now);

  FClock.SetNowFunc(nil);
  Assert.IsTrue(FClock.Now > Noon(2000, 1, 2),
    'nil nowfunc falls back to the wall clock instead of raising');
end;

procedure TTimeSourceContractTests.Rollback_ReturnsWatermark_AndIsCounted;
begin
  PinClock(Noon(2026, 9, 1));
  FClock.Now;

  // 回拨 30 天：读数必须仍等于水位，且回拨必须可观测
  PinClock(Noon(2026, 8, 2));

  AssertSameMoment(Noon(2026, 9, 1), FClock.Now,
    'a rolled-back clock must not hand out an earlier time');
  Assert.AreEqual(1, FClock.RollbackCount, 'the rollback must be counted');
  Assert.AreEqual(Int64(30) * 86400, FClock.MaxRollbackSeconds,
    'the rollback magnitude must be observable');
end;

procedure TTimeSourceContractTests.Watermark_NeverRetreatsAcrossMixedReads;
begin
  PinClock(Noon(2026, 1, 1));
  FClock.Now;
  PinClock(Noon(2025, 6, 1));
  FClock.Now;
  PinClock(Noon(2027, 2, 2));
  FClock.Now;
  PinClock(Noon(2024, 1, 1));
  FClock.Now;

  AssertSameMoment(Noon(2027, 2, 2), FClock.LastSeen,
    'the watermark is the high-water mark of every reading');
  Assert.AreEqual(2, FClock.RollbackCount, 'two of the four reads were backwards');
end;

procedure TTimeSourceContractTests.SeedWatermark_RaisesOnly;
begin
  FClock.SeedWatermark(Noon(2030, 1, 1));
  AssertSameMoment(Noon(2030, 1, 1), FClock.LastSeen);

  FClock.SeedWatermark(Noon(2020, 1, 1));
  AssertSameMoment(Noon(2030, 1, 1), FClock.LastSeen,
    'seeding an older last-seen must not lower the watermark');
end;

procedure TTimeSourceContractTests.SeedWatermark_IgnoresUnassignedValue;
begin
  FClock.SeedWatermark(0);
  Assert.IsTrue(FClock.LastSeen = 0,
    'an absent last-seen field (unassigned) must leave the clock untouched');
end;

{ TLicenseClockRollbackTests }

function TLicenseClockRollbackTests.DecodedPayload(const LicenseKey: string): string;
var
  Parts: TArray<string>;
begin
  Parts := LicenseKey.Split(['.']);
  Assert.IsTrue(Length(Parts) = 2, 'license key must be payload.signature');
  Result := TEncoding.UTF8.GetString(TNetEncoding.Base64URL.DecodeStringToBytes(Parts[0]));
end;

procedure TLicenseClockRollbackTests.Setup;
begin
  FPreviousSecret := GetEnvironmentVariable(TEST_LICENSE_SECRET_ENV);
  Winapi.Windows.SetEnvironmentVariable(PChar(TEST_LICENSE_SECRET_ENV), PChar(TEST_LICENSE_SECRET));

  FClock := TDeepBaseTimeSource.Shared;
  FClock.Reset;
  FLicense := TDeepBaseLicense.Create(nil);
end;

procedure TLicenseClockRollbackTests.TearDown;
begin
  FreeAndNil(FLicense);
  FClock.Reset;
  if FPreviousSecret = '' then
    Winapi.Windows.SetEnvironmentVariable(PChar(TEST_LICENSE_SECRET_ENV), nil)
  else
    Winapi.Windows.SetEnvironmentVariable(PChar(TEST_LICENSE_SECRET_ENV), PChar(FPreviousSecret));
end;

procedure TLicenseClockRollbackTests.ExpiredLicense_StaysExpired_AfterThirtyDayRollback;
var
  Key: string;
  Info: TLicenseInfo;
begin
  PinClock(Noon(2027, 9, 1));
  Key := TDeepBaseLicense.GenerateLicenseKey(ltStandard, Noon(2027, 8, 15),
    'Rollback User', FLicense.GetDeviceId, []);

  Info := FLicense.ValidateLicense(Key);
  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status),
    'a licence past its expiry is expired at the injected time');

  // 系统时钟回拨到过期日之前：墙钟口径会判"还没过期"，许可因此续命
  PinClock(Noon(2027, 8, 1));
  Info := FLicense.ValidateLicense(Key);

  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status),
    'a clock rollback must not bring an expired licence back to life');
  Assert.AreEqual(0, Info.DaysRemaining,
    'remaining days stay clamped at the watermark');
  Assert.IsTrue(FClock.RollbackCount > 0, 'the rollback has to be observable');
end;

procedure TLicenseClockRollbackTests.DaysRemaining_CountsFromWatermark_NotFromRolledBackClock;
var
  Key: string;
  Info: TLicenseInfo;
begin
  PinClock(Noon(2027, 9, 1));
  Key := TDeepBaseLicense.GenerateLicenseKey(ltStandard, Noon(2027, 12, 1),
    'Watermark User', FLicense.GetDeviceId, []);

  Info := FLicense.ValidateLicense(Key);
  Assert.AreEqual(Ord(lsValid), Ord(Info.Status), 'the licence is valid at the injected time');
  Assert.AreEqual(91, Info.DaysRemaining, '2027-09-01 -> 2027-12-01 is 91 days');

  // 回拨 31 天：墙钟口径会把剩余天数从 91 涨到 122，等于给许可多续一个月
  PinClock(Noon(2027, 8, 1));
  Info := FLicense.ValidateLicense(Key);

  Assert.AreEqual(91, Info.DaysRemaining,
    'remaining days must not grow when the system clock is rolled back');
  Assert.AreEqual(Ord(lsValid), Ord(Info.Status),
    'a still-in-date licence stays valid, only the counter is clamped');
end;

procedure TLicenseClockRollbackTests.OlderGenuineLicense_WithLowerLastSeen_DoesNotLowerWatermark;
var
  Key: string;
  Watermark: TDateTime;
  Info: TLicenseInfo;
begin
  // 真签名的旧副本：其 last-seen 早于当前水位，回载不得把水位拉回去
  PinClock(Noon(2025, 6, 1));
  Key := TDeepBaseLicense.GenerateLicenseKey(ltStandard, Noon(2027, 8, 15),
    'Old Copy', FLicense.GetDeviceId, []);

  PinClock(Noon(2027, 9, 1));
  Info := FLicense.ValidateLicense(Key);
  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status),
    'the licence is expired once the clock has passed 2027-08-15');

  Watermark := FClock.LastSeen;
  PinClock(Noon(2025, 7, 1));
  Info := FLicense.ValidateLicense(Key);

  AssertSameMoment(Watermark, FClock.LastSeen,
    'loading a genuinely older licence file must not lower the watermark');
  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status),
    'and must not hand the expired licence back to life');
end;

procedure TLicenseClockRollbackTests.LegacyLicense_WithoutLastSeenField_StillJudgedByWatermark;
var
  Info: TLicenseInfo;
begin
  Assert.IsTrue(Pos('"l"', DecodedPayload(LEGACY_KEY_WITHOUT_LAST_SEEN)) = 0,
    'the frozen fixture must really carry no last-seen field');

  PinClock(Noon(2027, 9, 1));
  Info := FLicense.ValidateLicense(LEGACY_KEY_WITHOUT_LAST_SEEN);
  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status),
    'a pre-fix licence without last-seen still validates and is expired');

  // 载荷里没有水位可播种 ⇒ 保护只能来自进程水位本身
  PinClock(Noon(2027, 8, 1));
  Info := FLicense.ValidateLicense(LEGACY_KEY_WITHOUT_LAST_SEEN);

  Assert.AreEqual(Ord(lsExpired), Ord(Info.Status),
    'a missing last-seen field must not disable rollback protection');
  AssertSameMoment(Noon(2027, 9, 1), FClock.LastSeen,
    'a payload without last-seen leaves the watermark where the readings put it');
end;

procedure TLicenseClockRollbackTests.GenerateLicenseKey_PersistsLastSeenField;
var
  Key: string;
  Payload: string;
begin
  PinClock(Noon(2027, 9, 1));
  Key := TDeepBaseLicense.GenerateLicenseKey(ltStandard, Noon(2027, 12, 1),
    'Watermark Writer', FLicense.GetDeviceId, []);

  Payload := DecodedPayload(Key);
  Assert.IsTrue(Pos('"l":' + IntToStr(DateTimeToUnix(Noon(2027, 9, 1))) + ',', Payload) > 0,
    'an issued licence must persist the current watermark as payload field l, got: ' + Payload);
end;

procedure TLicenseClockRollbackTests.ForgedLowerLastSeen_IsRejected_AndWatermarkUnchanged;
var
  Key, Payload, OldPair, NewPair, ForgedPayload, Signature: string;
  Info: TLicenseInfo;
  Watermark: TDateTime;
begin
  PinClock(Noon(2027, 9, 1));
  Key := TDeepBaseLicense.GenerateLicenseKey(ltStandard, Noon(2027, 12, 1),
    'Forged Watermark', FLicense.GetDeviceId, []);

  Payload := DecodedPayload(Key);
  OldPair := '"l":' + IntToStr(DateTimeToUnix(Noon(2027, 9, 1)));
  // 等宽替换（同为 10 位秒数），让差异只剩 l 的数值本身
  NewPair := '"l":' + IntToStr(DateTimeToUnix(Noon(2027, 8, 2)));
  Assert.AreEqual(Length(OldPair), Length(NewPair), 'the forged value must keep the same width');
  Assert.IsTrue(Pos(OldPair, Payload) > 0, 'fixture payload must contain ' + OldPair);

  ForgedPayload := StringReplace(Payload, OldPair, NewPair, []);
  Signature := Key.Split(['.'])[1];
  // 只换载荷、留原签名：载荷字节必然与原 HMAC 不匹配
  Key := TNetEncoding.Base64URL.EncodeBytesToString(TEncoding.UTF8.GetBytes(ForgedPayload)) + '.' + Signature;

  Watermark := FClock.LastSeen;
  Info := FLicense.ValidateLicense(Key);

  Assert.AreEqual(Ord(lsTampered), Ord(Info.Status),
    'a forged lower last-seen must be rejected by the signature');
  AssertSameMoment(Watermark, FClock.LastSeen,
    'and it must never reach the watermark: seeding happens after verification');
end;

{ TKeyClockRollbackTests }

procedure TKeyClockRollbackTests.Setup;
var
  Params: TKeyDerivationParams;
begin
  FClock := TDeepBaseTimeSource.Shared;
  FClock.Reset;

  FStorePath := TPath.Combine(TPath.GetTempPath, 'DeepBase_a5r09_keystore.json');
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);

  PinClock(Noon(2027, 9, 1));
  FMaster := TMasterKey.Create;
  Params := TKeyDerivationParams.Default;
  FMaster.DeriveFromPassword('a5r09-master', Params);

  FStore := TKeyStore.Create(FStorePath);
  FStore.Initialize(FMaster);
end;

procedure TKeyClockRollbackTests.TearDown;
begin
  FreeAndNil(FStore);
  FreeAndNil(FMaster);
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
  FClock.Reset;
end;

procedure TKeyClockRollbackTests.ExpiredKeyInfo_StaysExpired_AfterRollback;
var
  Info: TKeyInfo;
begin
  Info := Default(TKeyInfo);
  Info.ExpiresAt := Noon(2027, 8, 15);

  PinClock(Noon(2027, 9, 1));
  Assert.IsTrue(Info.IsExpired, 'a key past its expiry is expired at the injected time');

  PinClock(Noon(2027, 8, 1));
  Assert.IsTrue(Info.IsExpired,
    'a clock rollback must not make an expired data key usable again');
  // DaysUntilExpiry 取的是 DaysBetween 的绝对值（过期后仍为正数，属既存口径，
  // 本单只登记不改）：判据因此是天数按水位算还是按回拨后的墙钟算。
  Assert.AreEqual(17, Info.DaysUntilExpiry,
    'the counter must stay measured from the watermark (17 days), not the rolled-back clock (14)');
end;

procedure TKeyClockRollbackTests.DaysUntilExpiry_CountsFromWatermark;
var
  Info: TKeyInfo;
begin
  Info := Default(TKeyInfo);
  Info.ExpiresAt := Noon(2027, 12, 1);

  PinClock(Noon(2027, 9, 1));
  Assert.AreEqual(91, Info.DaysUntilExpiry, '2027-09-01 -> 2027-12-01 is 91 days');

  PinClock(Noon(2027, 8, 1));
  Assert.AreEqual(91, Info.DaysUntilExpiry,
    'remaining days must not grow when the system clock is rolled back');
end;

procedure TKeyClockRollbackTests.MasterKeyCreatedAt_ComesFromSharedClock;
var
  Master: TMasterKey;
begin
  // 取在水位之后（Setup 已把水位推到 2027-09-01）：更早的注入读数会被当成回拨钳制掉
  PinClock(Noon(2028, 5, 5));
  Master := TMasterKey.Create;
  try
    AssertSameMoment(Noon(2028, 5, 5), Master.CreatedAt,
      'key stamps must come from the shared clock, not the raw wall clock');
  finally
    Master.Free;
  end;
end;

procedure TKeyClockRollbackTests.DataKeyCreatedAt_ComesFromSharedClock;
var
  Key: TDataKey;
begin
  PinClock(Noon(2028, 5, 5));
  Key := TDataKey.Create(kpEncryption);
  try
    AssertSameMoment(Noon(2028, 5, 5), Key.GetInfo.CreatedAt,
      'the data key creation stamp must follow the shared clock');
  finally
    Key.Free;
  end;
end;

procedure TKeyClockRollbackTests.CreatedKeyExpiryWindow_ComesFromSharedClock;
var
  Key: TDataKey;
begin
  // 建钥时把系统时钟回拨 31 天：墙钟口径会把 30 天窗口整体往前挪，新钥凭空多活一个月
  PinClock(Noon(2027, 8, 1));
  Key := FStore.CreateKey(kpConfig, 30);
  AssertSameMoment(Noon(2027, 10, 1), Key.GetInfo.ExpiresAt,
    'the expiry window must be measured from the watermark, not the rolled-back clock');
end;

initialization
  TDUnitX.RegisterTestFixture(TTimeSourceContractTests);
  TDUnitX.RegisterTestFixture(TLicenseClockRollbackTests);
  TDUnitX.RegisterTestFixture(TKeyClockRollbackTests);

end.
