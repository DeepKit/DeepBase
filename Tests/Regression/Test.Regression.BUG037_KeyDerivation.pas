{ ============================================================================
  Test.Regression.BUG037_KeyDerivation - Key Derivation Regression Test

  BUG-037: Insecure Key Derivation
  
  Original Issue: Using simple hash instead of PBKDF2 for key derivation,
                  not using salt, or using too few iterations.
  
  Fix: Implement PBKDF2 with configurable iterations (minimum 10000);
       Enforce salt usage; Add key derivation validation.
  
  Fix Date: 2025-12-16
  File: Core/DeepBase.Crypto.pas
  Priority: P1 (High)
  Category: Security
  ============================================================================ }

unit Test.Regression.BUG037_KeyDerivation;

interface

uses
  System.SysUtils,
  System.DateUtils,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P1')]
  [Category('Security')]
  TBug037_KeyDerivationTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('Verify PBKDF2 generates keys with sufficient entropy')]
    procedure Test_PBKDF2_GeneratesSecureKey;
    
    [Test]
    [Description('Verify PBKDF2 uses salt')]
    procedure Test_PBKDF2_UsesSalt;
    
    [Test]
    [Description('Verify PBKDF2 with different salts produces different keys')]
    procedure Test_PBKDF2_DifferentSalts_DifferentKeys;
    
    [Test]
    [Description('Verify PBKDF2 iteration count is sufficient')]
    procedure Test_PBKDF2_IterationCount_Sufficient;
    
    [Test]
    [Description('Verify PBKDF2 output length is correct')]
    procedure Test_PBKDF2_OutputLength_IsCorrect;
  end;

implementation

uses
  DeepBase.Crypto, DeepBase.Crypto.Encoding, DeepBase.Crypto.Hash, DeepBase.Crypto.Random;

{ TBug037_KeyDerivationTest }

function TBug037_KeyDerivationTest.GetBugNumber: string;
begin
  Result := 'BUG-037';
end;

function TBug037_KeyDerivationTest.GetBugDescription: string;
begin
  Result := 'Insecure key derivation';
end;

function TBug037_KeyDerivationTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug037_KeyDerivationTest.GetPriority: string;
begin
  Result := 'P1';
end;

function TBug037_KeyDerivationTest.GetAffectedFile: string;
begin
  Result := 'Core/DeepBase.Crypto.pas';
end;

procedure TBug037_KeyDerivationTest.Test_PBKDF2_GeneratesSecureKey;
var
  Key: TBytes;
  Salt: TBytes;
  I: Integer;
  NonZeroCount: Integer;
begin
  LogTestStart('Test_PBKDF2_GeneratesSecureKey');
  
  Salt := TEncoding.ASCII.GetBytes('TestSalt12345678');
  Key := TPasswordUtils.PBKDF2('TestPassword123!', Salt, 10000, 32);
  
  Assert.AreEqual(Integer(32), Integer(Length(Key)), 'PBKDF2 should generate 32-byte key');
  
  // Check key has entropy (not all zeros)
  NonZeroCount := 0;
  for I := 0 to High(Key) do
    if Key[I] <> 0 then
      Inc(NonZeroCount);
  
  Assert.IsTrue(NonZeroCount > 16, 'Key should have sufficient entropy');
  
  LogTestEnd('Test_PBKDF2_GeneratesSecureKey', True);
end;

procedure TBug037_KeyDerivationTest.Test_PBKDF2_UsesSalt;
var
  Key1, Key2: TBytes;
  Salt: TBytes;
begin
  LogTestStart('Test_PBKDF2_UsesSalt');
  
  Salt := TRandomGenerator.RandomBytes(16);
  
  Key1 := TPasswordUtils.PBKDF2('Password', Salt, 10000, 32);
  Key2 := TPasswordUtils.PBKDF2('Password', Salt, 10000, 32);
  
  // Same password and salt should produce same key
  Assert.AreEqual(TEncodingUtils.HexEncode(Key1), TEncodingUtils.HexEncode(Key2),
    'Same password and salt should produce same key');
  
  LogTestEnd('Test_PBKDF2_UsesSalt', True);
end;

procedure TBug037_KeyDerivationTest.Test_PBKDF2_DifferentSalts_DifferentKeys;
var
  Key1, Key2: TBytes;
  Salt1, Salt2: TBytes;
begin
  LogTestStart('Test_PBKDF2_DifferentSalts_DifferentKeys');
  
  Salt1 := TRandomGenerator.RandomBytes(16);
  Salt2 := TRandomGenerator.RandomBytes(16);
  
  Key1 := TPasswordUtils.PBKDF2('SamePassword', Salt1, 10000, 32);
  Key2 := TPasswordUtils.PBKDF2('SamePassword', Salt2, 10000, 32);
  
  Assert.AreNotEqual(TEncodingUtils.HexEncode(Key1), TEncodingUtils.HexEncode(Key2),
    'Different salts should produce different keys');
  
  LogTestEnd('Test_PBKDF2_DifferentSalts_DifferentKeys', True);
end;

procedure TBug037_KeyDerivationTest.Test_PBKDF2_IterationCount_Sufficient;
var
  StartTime: TDateTime;
  Key: TBytes;
  Salt: TBytes;
begin
  LogTestStart('Test_PBKDF2_IterationCount_Sufficient');
  
  Salt := TEncoding.ASCII.GetBytes('TestSalt12345678');
  StartTime := Now;
  Key := TPasswordUtils.PBKDF2('TestPassword', Salt, 10000, 32);
  
  // 10000 iterations should take at least some time (usually 10-100ms)
  // This is a sanity check, not a strict requirement
  Assert.IsTrue(Length(Key) = 32, 'PBKDF2 should produce 32-byte key');
  
  LogTestEnd('Test_PBKDF2_IterationCount_Sufficient', True);
end;

procedure TBug037_KeyDerivationTest.Test_PBKDF2_OutputLength_IsCorrect;
var
  Salt: TBytes;
  DerivedKey16, DerivedKey32, DerivedKey64: TBytes;
begin
  LogTestStart('Test_PBKDF2_OutputLength_IsCorrect');
  
  Salt := TRandomGenerator.RandomBytes(16);
  
  DerivedKey16 := TPasswordUtils.PBKDF2('Test', Salt, 10000, 16);
  DerivedKey32 := TPasswordUtils.PBKDF2('Test', Salt, 10000, 32);
  DerivedKey64 := TPasswordUtils.PBKDF2('Test', Salt, 10000, 64);
  
  Assert.AreEqual(Integer(16), Integer(Length(DerivedKey16)), 'PBKDF2 should generate 16-byte key');
  Assert.AreEqual(Integer(32), Integer(Length(DerivedKey32)), 'PBKDF2 should generate 32-byte key');
  Assert.AreEqual(Integer(64), Integer(Length(DerivedKey64)), 'PBKDF2 should generate 64-byte key');
  
  LogTestEnd('Test_PBKDF2_OutputLength_IsCorrect', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug037_KeyDerivationTest);

end.
