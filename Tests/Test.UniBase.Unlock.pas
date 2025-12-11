unit Test.UniBase.Unlock;

{*******************************************************************************
  UniBase Unlock Module Unit Tests

  Coverage:
    - TUniBaseUnlock.GenerateCode / ValidateCode
    - Date window validation (current + previous 2 months)
    - Product code prefix validation
    - Checksum validation and level inference
    - Config-backed persistence via ApplyCode / StoredLevel
*******************************************************************************}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.DateUtils,
  UniBase.Manager,
  UniBase.Unlock;

type
  [TestFixture]
  TTestUniBaseUnlock = class
  private
    FUnlock: TUniBaseUnlock;
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_GenerateAndValidate_AllLevels;

    [Test]
    procedure Test_ExpiredCode_Detected;

    [Test]
    procedure Test_ProductMismatch_Detected;

    [Test]
    procedure Test_InvalidChecksum_Detected;

    [Test]
    procedure Test_ApplyCode_PersistsLevelAndCode;
  end;

implementation

{ TTestUniBaseUnlock }

procedure TTestUniBaseUnlock.Setup;
begin
  // Always initialize UniBase with in-memory database for deterministic tests
  UniBase.Manager.UniBase.InitializeWithDB(':memory:');

  FUnlock := TUniBaseUnlock.Create('TK'); // TwoKeyRun product code example
end;

procedure TTestUniBaseUnlock.TearDown;
begin
  FreeAndNil(FUnlock);
end;

procedure TTestUniBaseUnlock.Test_GenerateAndValidate_AllLevels;
var
  Level: TUnlockLevel;
  Code: string;
  Info: TUnlockInfo;
  Status: TUnlockValidationStatus;
begin
  for Level := Low(TUnlockLevel) to High(TUnlockLevel) do
  begin
    Code := TUniBaseUnlock.GenerateCode('TK', Date, Level);
    Status := FUnlock.ValidateCode(Code, Info);

    Assert.AreEqual(Ord(uvsOk), Ord(Status), 'Status should be uvsOk');
    Assert.IsTrue(Info.IsValid, 'Info.IsValid should be True');
    Assert.AreEqual(Ord(Level), Ord(Info.Level), 'Level should round-trip correctly');
    Assert.AreEqual('TK', Info.ProductCode, 'ProductCode should be TK');
  end;
end;

procedure TTestUniBaseUnlock.Test_ExpiredCode_Detected;
var
  OldDate: TDateTime;
  Code: string;
  Info: TUnlockInfo;
  Status: TUnlockValidationStatus;
begin
  // 3 full months before current month => should be outside 3-month window
  OldDate := IncMonth(StartOfTheMonth(Date), -3);
  Code := TUniBaseUnlock.GenerateCode('TK', OldDate, ulFollow);

  Status := FUnlock.ValidateCode(Code, Info);

  Assert.AreEqual(Ord(uvsExpired), Ord(Status), 'Status should be uvsExpired for old code');
  Assert.IsTrue(Info.IsExpired, 'Info.IsExpired should be True');
end;

procedure TTestUniBaseUnlock.Test_ProductMismatch_Detected;
var
  Code: string;
  Info: TUnlockInfo;
  Status: TUnlockValidationStatus;
  OtherProduct: TUniBaseUnlock;
begin
  Code := TUniBaseUnlock.GenerateCode('TK', Date, ulFollow);

  // Use different product code manager to validate
  OtherProduct := TUniBaseUnlock.Create('MC');
  try
    Status := OtherProduct.ValidateCode(Code, Info);
    Assert.AreEqual(Ord(uvsProductMismatch), Ord(Status), 'Status should be uvsProductMismatch');
  finally
    OtherProduct.Free;
  end;
end;

procedure TTestUniBaseUnlock.Test_InvalidChecksum_Detected;
var
  Code: string;
  BadCode: string;
  Info: TUnlockInfo;
  Status: TUnlockValidationStatus;
begin
  Code := TUniBaseUnlock.GenerateCode('TK', Date, ulShare);
  BadCode := Code;

  // Flip last character to something else to break checksum
  if BadCode[Length(BadCode)] <> 'X' then
    BadCode[Length(BadCode)] := 'X'
  else
    BadCode[Length(BadCode)] := 'Z';

  Status := FUnlock.ValidateCode(BadCode, Info);

  Assert.AreEqual(Ord(uvsInvalidChecksum), Ord(Status), 'Status should be uvsInvalidChecksum');
end;

procedure TTestUniBaseUnlock.Test_ApplyCode_PersistsLevelAndCode;
var
  CodeFollow, CodeShare: string;
  Info: TUnlockInfo;
begin
  // Start from default (Free)
  Assert.AreEqual(Ord(ulFree), Ord(FUnlock.StoredLevel), 'Initial StoredLevel should be ulFree');

  CodeFollow := TUniBaseUnlock.GenerateCode('TK', Date, ulFollow);
  Assert.IsTrue(FUnlock.ApplyCode(CodeFollow, Info), 'Follow code should apply successfully');
  Assert.AreEqual(Ord(ulFollow), Ord(FUnlock.StoredLevel), 'StoredLevel should be ulFollow');
  Assert.AreEqual(CodeFollow, FUnlock.StoredCode, 'StoredCode should equal last code');

  // Share code should upgrade level
  CodeShare := TUniBaseUnlock.GenerateCode('TK', Date, ulShare);
  Assert.IsTrue(FUnlock.ApplyCode(CodeShare, Info), 'Share code should apply successfully');
  Assert.AreEqual(Ord(ulShare), Ord(FUnlock.StoredLevel), 'StoredLevel should be ulShare');
  Assert.AreEqual(CodeShare, FUnlock.StoredCode, 'StoredCode should be updated to share code');

  // Applying a lower-level code should not downgrade StoredLevel
  Assert.IsTrue(FUnlock.ApplyCode(CodeFollow, Info), 'Reapplying follow code should still succeed logically');
  Assert.AreEqual(Ord(ulShare), Ord(FUnlock.StoredLevel), 'StoredLevel should remain ulShare (no downgrade)');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseUnlock);

end.
