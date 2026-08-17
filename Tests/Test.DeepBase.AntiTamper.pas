{ ============================================================================
  Test.DeepBase.AntiTamper - Unit Tests for Anti-Tamper Module
  
  Test Coverage:
    - TEncryptionType / TAntiTamperConfig defaults
    - TAntiTamperPackage.GetDefaultConfig
    - TAntiTamperPackage.Initialize
    - CalculateMD5 / CalculateSHA256
    - EncryptImageData / DecryptImageData
    - VerifyImageIntegrity
  
  Note: Database-related and UI-interactive methods (SetupDatabase/LoadSecureImage/
        HandleSecurityViolation) are not invoked in tests to avoid side effects.
  ============================================================================ }

unit Test.DeepBase.AntiTamper;

{$WARN SYMBOL_DEPRECATED OFF}

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.Hash,
  DeepBase.AntiTamper, DeepBase.Exceptions;

type
  [TestFixture]
  TTestAntiTamperConfig = class
  public
    [Test]
    procedure Test_DefaultConfig_Values;
    [Test]
    procedure Test_DefaultConfig_EncryptionType_AES256;
  end;

  [TestFixture]
  TTestAntiTamperCrypto = class
  public
    [Test]
    procedure Test_Initialize_WithDefaultConfig;
    [Test]
    procedure Test_CalculateMD5_Length;
    [Test]
    procedure Test_CalculateSHA256_Length;
    [Test]
    procedure Test_EncryptDecrypt_AES_RoundTrip;
    [Test]
    procedure Test_VerifyImageIntegrity_Pass;
    [Test]
    procedure Test_VerifyImageIntegrity_Fail;
  end;

implementation

{ TTestAntiTamperConfig }

procedure TTestAntiTamperConfig.Test_DefaultConfig_Values;
var
  C: TAntiTamperConfig;
begin
  C := TAntiTamperPackage.GetDefaultConfig;
  Assert.IsEmpty(C.EncryptionKey, 'EncryptionKey must be configured explicitly by each application');
  Assert.IsNotEmpty(C.DownloadURL);
  Assert.IsNotEmpty(C.TableName);
  Assert.IsEmpty(C.Salt, 'Salt must be configured explicitly by each application (BUG-426/E-007): a hardcoded default Salt enables rainbow-table attacks');
  Assert.IsTrue(C.KdfIterations > 0);
  Assert.IsTrue(C.EnableHMAC);
end;

procedure TTestAntiTamperConfig.Test_DefaultConfig_EncryptionType_AES256;
var
  C: TAntiTamperConfig;
begin
  C := TAntiTamperPackage.GetDefaultConfig;
  Assert.AreEqual(etAES256, C.EncryptionType);
end;

{ TTestAntiTamperCrypto }

procedure TTestAntiTamperCrypto.Test_Initialize_WithDefaultConfig;
var
  C: TAntiTamperConfig;
begin
  // BUG-426 (E-007): default config has empty Salt; Initialize must reject it.
  C := TAntiTamperPackage.GetDefaultConfig;
  Assert.WillRaise(
    procedure begin TAntiTamperPackage.Initialize(C); end,
    EAntiTamperException,
    'Initialize must reject empty Salt with EAntiTamperException');

  // With an explicit Salt, Initialize succeeds.
  C.Salt := 'UnitTest_AntiTamper_Salt_2026';
  TAntiTamperPackage.Initialize(C);
  Assert.Pass; // no exception means success
end;

procedure TTestAntiTamperCrypto.Test_CalculateMD5_Length;
var
  Data: TBytes;
  MD5Hex: string;
begin
  Data := TEncoding.UTF8.GetBytes('Hello AntiTamper');
  MD5Hex := TAntiTamperPackage.CalculateMD5(Data);
  Assert.AreEqual(32, Integer(Length(MD5Hex)));
end;

procedure TTestAntiTamperCrypto.Test_CalculateSHA256_Length;
var
  Data: TBytes;
  SHAHex: string;
begin
  Data := TEncoding.UTF8.GetBytes('Hello AntiTamper');
  SHAHex := TAntiTamperPackage.CalculateSHA256(Data);
  Assert.AreEqual(64, Integer(Length(SHAHex)));
end;

procedure TTestAntiTamperCrypto.Test_EncryptDecrypt_AES_RoundTrip;
var
  C: TAntiTamperConfig;
  Plain, Encrypted, Decrypted: TBytes;
begin
  C := TAntiTamperPackage.GetDefaultConfig;
  C.EncryptionKey := 'UnitTest_AntiTamper_Key_2026';
  C.Salt := 'UnitTest_AntiTamper_Salt_2026'; // BUG-426 (E-007): Salt required, default is empty
  C.EncryptionType := etAES256;
  TAntiTamperPackage.Initialize(C);
  
  Plain := TEncoding.UTF8.GetBytes('AES Test Data 12345');
  Encrypted := TAntiTamperPackage.EncryptImageData(Plain);
  Decrypted := TAntiTamperPackage.DecryptImageData(Encrypted);
  
  Assert.AreEqual(Length(Plain), Length(Decrypted));
end;

procedure TTestAntiTamperCrypto.Test_VerifyImageIntegrity_Pass;
var
  Data: TBytes;
  Hash: string;
begin
  Data := TEncoding.UTF8.GetBytes('Integrity Test');
  Hash := TAntiTamperPackage.CalculateSHA256(Data);
  Assert.IsTrue(TAntiTamperPackage.VerifyImageIntegrity(Data, Hash));
end;

procedure TTestAntiTamperCrypto.Test_VerifyImageIntegrity_Fail;
var
  Data: TBytes;
  Hash: string;
begin
  Data := TEncoding.UTF8.GetBytes('Integrity Test');
  Hash := TAntiTamperPackage.CalculateSHA256(TEncoding.UTF8.GetBytes('Other Data'));
  Assert.IsFalse(TAntiTamperPackage.VerifyImageIntegrity(Data, Hash));
end;

initialization
  TDUnitX.RegisterTestFixture(TTestAntiTamperConfig);
  TDUnitX.RegisterTestFixture(TTestAntiTamperCrypto);

end.
