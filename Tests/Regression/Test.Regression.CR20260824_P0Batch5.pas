{ ============================================================================
  Test.Regression.CR20260824_P0Batch5 - audit 2026-08-24, quick-win batch

  Covers:
  - CR-256: password strength scale mismatch (0..5 score vs 0..100 thresholds)
    made every password report psVeryWeak.
  - CR-261: TCache.GetTTL returned a POSITIVE value for already-expired
    entries (SecondsBetween absolute value).
  - CR-264: TCountingSet.Remove accepted negative counts and inflated totals.
  - CR-120: RoundToMinute/RoundToHour manual carry overflowed at minute 59 /
    hour 23 boundaries (EncodeDateTime range error).
  - CR-254: secret-name validation prefix-matched com/lpt, rejecting legal
    names like common_config / lpt_settings.
  ============================================================================ }

unit Test.Regression.CR20260824_P0Batch5;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DUnitX.TestFramework,
  Test.Regression.Base,
  DeepBase.Cache,
  DeepBase.Collections,
  DeepBase.Crypto.Hash,
  DeepBase.DateTime,
  DeepBase.Security,
  DeepBase.Services.Interfaces,
  DeepBase.Services.Crypto;

type
  [TestFixture]
  [Category('regression')]
  TCR20260824P0Batch5Test = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    procedure Test_CR256_StrengthScale_HasGradient;

    [Test]
    procedure Test_CR261_GetTTL_ExpiredEntry_ReturnsZero;

    [Test]
    procedure Test_CR264_Remove_NegativeCount_Raises;

    [Test]
    procedure Test_CR120_RoundToMinute_CarryOverBoundaries;

    [Test]
    procedure Test_CR120_RoundToHour_DayBoundary;

    [Test]
    procedure Test_CR254_SecretNames_PreciseReservedMatch;
  end;

implementation

function MakeCache: TCache<string, string>;
begin
  Result := TCache<string, string>.Create;
end;

{ TCR20260824P0Batch5Test }

function TCR20260824P0Batch5Test.GetBugNumber: string;
begin
  Result := 'CR-256/CR-261/CR-264/CR-120/CR-254';
end;

function TCR20260824P0Batch5Test.GetBugDescription: string;
begin
  Result := 'Quick-win batch: strength scale / expired TTL sign / negative count / time rounding carry / reserved-name prefixes';
end;

function TCR20260824P0Batch5Test.GetFixDate: string;
begin
  Result := '2026-08-24';
end;

function TCR20260824P0Batch5Test.GetPriority: string;
begin
  Result := 'P2';
end;

function TCR20260824P0Batch5Test.GetAffectedFile: string;
begin
  Result := 'Core\DeepBase.Services.Crypto.pas; Core\DeepBase.Cache.pas; Core\DeepBase.Collections.pas; Core\DeepBase.DateTime.pas; Core\DeepBase.Security.pas';
end;

procedure TCR20260824P0Batch5Test.Test_CR256_StrengthScale_HasGradient;
var
  Svc: IPasswordService;
begin
  Svc := TPasswordServiceImpl.Create;
  Assert.IsTrue(Svc.CheckStrength('short') = psVeryWeak, 'short -> very weak');
  Assert.IsTrue(Svc.CheckStrength('abcdefgh') = psVeryWeak, '8 lowercase -> very weak');
  Assert.IsTrue(Svc.CheckStrength('Abcdefgh1!') = psStrong, 'mixed 10 chars -> strong');
  Assert.IsTrue(Svc.CheckStrength('Abcdefghij123!@#') = psVeryStrong,
    '16+ all classes -> very strong (was unreachable pre-fix)');
end;

procedure TCR20260824P0Batch5Test.Test_CR261_GetTTL_ExpiredEntry_ReturnsZero;
var
  C: TCache<string, string>;
begin
  C := MakeCache;
  try
    C.Put('k', 'v', 1); // 1 second TTL
    Assert.IsTrue(C.GetTTL('k') > 0, 'live entry has positive TTL');
    Sleep(1300);
    Assert.AreEqual(0, C.GetTTL('k'),
      'expired entry must report 0 remaining seconds (pre-fix grew with age)');
  finally
    C.Free;
  end;
end;

procedure TCR20260824P0Batch5Test.Test_CR264_Remove_NegativeCount_Raises;
var
  CS: TCountingSet<string>;
begin
  CS := TCountingSet<string>.Create;
  try
    CS.Add('x', 5);
    Assert.WillRaise(
      procedure
      begin
        CS.Remove('x', -3);
      end,
      ECollectionException);
    Assert.AreEqual(5, CS.CountOf('x'), 'count must be untouched by rejected call');
  finally
    CS.Free;
  end;
end;

procedure TCR20260824P0Batch5Test.Test_CR120_RoundToMinute_CarryOverBoundaries;
begin
  Assert.AreEqual(EncodeDateTime(2026, 1, 1, 11, 0, 0, 0),
    TDateTimeCalc.RoundToMinute(EncodeDateTime(2026, 1, 1, 10, 59, 45, 0)),
    '10:59:45 rounds up to 11:00 (pre-fix EConvertError)');
  Assert.AreEqual(EncodeDateTime(2026, 1, 2, 0, 0, 0, 0),
    TDateTimeCalc.RoundToMinute(EncodeDateTime(2026, 1, 1, 23, 59, 59, 0)),
    '23:59:59 rounds into next day midnight (pre-fix EConvertError)');
  Assert.AreEqual(EncodeDateTime(2026, 1, 1, 10, 59, 0, 0),
    TDateTimeCalc.RoundToMinute(EncodeDateTime(2026, 1, 1, 10, 59, 29, 0)),
    'below threshold truncates in place');
end;

procedure TCR20260824P0Batch5Test.Test_CR120_RoundToHour_DayBoundary;
begin
  Assert.AreEqual(EncodeDateTime(2026, 1, 2, 0, 0, 0, 0),
    TDateTimeCalc.RoundToHour(EncodeDateTime(2026, 1, 1, 23, 45, 0, 0)),
    '23:45 rounds into next day (pre-fix hour=24 EConvertError)');
  Assert.AreEqual(EncodeDateTime(2026, 1, 1, 23, 0, 0, 0),
    TDateTimeCalc.RoundToHour(EncodeDateTime(2026, 1, 1, 23, 15, 0, 0)),
    'below half-hour truncates');
end;

procedure TCR20260824P0Batch5Test.Test_CR254_SecretNames_PreciseReservedMatch;
begin
  // legal names that the old prefix match wrongly rejected
  Assert.IsTrue(TDeepBaseSecurity.IsValidSecretName('common_config'), 'common_config');
  Assert.IsTrue(TDeepBaseSecurity.IsValidSecretName('lpt_settings'), 'lpt_settings');
  Assert.IsTrue(TDeepBaseSecurity.IsValidSecretName('company_key'), 'company_key');
  // reserved forms must stay rejected
  Assert.IsFalse(TDeepBaseSecurity.IsValidSecretName('con'), 'con');
  Assert.IsFalse(TDeepBaseSecurity.IsValidSecretName('com1'), 'com1');
  Assert.IsFalse(TDeepBaseSecurity.IsValidSecretName('COM9.dll'), 'COM9.dll');
  Assert.IsFalse(TDeepBaseSecurity.IsValidSecretName('lpt4'), 'lpt4');
  Assert.IsFalse(TDeepBaseSecurity.IsValidSecretName('nul'), 'nul');
end;

initialization
  TDUnitX.RegisterTestFixture(TCR20260824P0Batch5Test);

end.
