{ ============================================================================
  Test.Regression.BUG033_WeakEncryption - Weak Encryption Algorithm Regression Test

  BUG-033: Weak Encryption Algorithm Usage
  
  Original Issue: Using XOR obfuscation instead of real encryption;
                  Using XOR as AES fallback on non-Windows platforms.
  
  Fix: Remove XOR encryption option, enforce AES-256 encryption;
       Add key configuration validation.
  
  Fix Date: 2025-12-16
  File: Features/UniBase.AntiTamper.pas
  Priority: P0 (Critical)
  Category: Security
  ============================================================================ }

unit Test.Regression.BUG033_WeakEncryption;

interface

uses
  System.SysUtils,
  DUnitX.TestFramework,
  Test.Regression.Base;

type
  [TestFixture]
  [Category('Regression')]
  [Category('P0')]
  [Category('Security')]
  TBug033_WeakEncryptionTest = class(TRegressionTestBase)
  protected
    function GetBugNumber: string; override;
    function GetBugDescription: string; override;
    function GetFixDate: string; override;
    function GetPriority: string; override;
    function GetAffectedFile: string; override;
  public
    [Test]
    [Description('Verify AES-256 encryption works correctly')]
    procedure Test_AES256_Encryption_Works;
    
    [Test]
    [Description('Verify encrypted data differs from original')]
    procedure Test_EncryptedData_DiffersFromOriginal;
    
    [Test]
    [Description('Verify encryption and decryption are reversible')]
    procedure Test_EncryptDecrypt_IsReversible;
    
    [Test]
    [Description('Verify different keys produce different results')]
    procedure Test_DifferentKeys_ProduceDifferentResults;
    
    [Test]
    [Description('Verify empty key is rejected')]
    procedure Test_EmptyKey_IsRejected;
    
    [Test]
    [Description('Verify encrypted data has correct block size')]
    procedure Test_EncryptedData_HasCorrectBlockSize;
  end;

implementation

uses
  UniBase.Crypto;

{ TBug033_WeakEncryptionTest }

function TBug033_WeakEncryptionTest.GetBugNumber: string;
begin
  Result := 'BUG-033';
end;

function TBug033_WeakEncryptionTest.GetBugDescription: string;
begin
  Result := 'Weak encryption algorithm usage';
end;

function TBug033_WeakEncryptionTest.GetFixDate: string;
begin
  Result := '2025-12-16';
end;

function TBug033_WeakEncryptionTest.GetPriority: string;
begin
  Result := 'P0';
end;

function TBug033_WeakEncryptionTest.GetAffectedFile: string;
begin
  Result := 'Features/UniBase.AntiTamper.pas';
end;

procedure TBug033_WeakEncryptionTest.Test_AES256_Encryption_Works;
var
  AES: TAESCrypto;
  PlainText: string;
  Encrypted: string;
begin
  LogTestStart('Test_AES256_Encryption_Works');
  
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKeyFromPassword('TestPassword123!', TEncoding.UTF8.GetBytes('bug033_salt'));
    AES.GenerateIV;
    
    PlainText := 'This is a test message for AES-256 encryption.';
    Encrypted := AES.EncryptString(PlainText);
    
    Assert.IsNotEmpty(Encrypted, 'AES-256 encryption should produce non-empty result');
    Assert.AreNotEqual(PlainText, Encrypted, 'Encrypted data should differ from original');
  finally
    AES.Free;
  end;
  
  LogTestEnd('Test_AES256_Encryption_Works', True);
end;

procedure TBug033_WeakEncryptionTest.Test_EncryptedData_DiffersFromOriginal;
var
  AES: TAESCrypto;
  PlainText: string;
  Encrypted: string;
begin
  LogTestStart('Test_EncryptedData_DiffersFromOriginal');
  
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKeyFromPassword('SecurePassword!@#', TEncoding.UTF8.GetBytes('bug033_salt'));
    AES.GenerateIV;
    
    PlainText := 'Sensitive data that must be protected';
    Encrypted := AES.EncryptString(PlainText);
    
    Assert.IsFalse(Encrypted.Contains(PlainText),
      'Encrypted data should not contain original plaintext');
    
    Assert.IsTrue(Length(Encrypted) > Length(PlainText),
      'Encrypted data length should be greater than original (includes IV and padding)');
  finally
    AES.Free;
  end;
  
  LogTestEnd('Test_EncryptedData_DiffersFromOriginal', True);
end;

procedure TBug033_WeakEncryptionTest.Test_EncryptDecrypt_IsReversible;
var
  AES: TAESCrypto;
  PlainText: string;
  Encrypted: string;
  Decrypted: string;
begin
  LogTestStart('Test_EncryptDecrypt_IsReversible');
  
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKeyFromPassword('MySecretKey123', TEncoding.UTF8.GetBytes('bug033_salt'));
    AES.GenerateIV;
    
    PlainText := 'Test message with special chars: test @#$%';
    Encrypted := AES.EncryptString(PlainText);
    Decrypted := AES.DecryptString(Encrypted);
    
    Assert.AreEqual(PlainText, Decrypted,
      'Decrypted data should match original exactly');
  finally
    AES.Free;
  end;
  
  LogTestEnd('Test_EncryptDecrypt_IsReversible', True);
end;

procedure TBug033_WeakEncryptionTest.Test_DifferentKeys_ProduceDifferentResults;
var
  AES1, AES2: TAESCrypto;
  PlainText: string;
  Encrypted1, Encrypted2: string;
  IV: TBytes;
begin
  LogTestStart('Test_DifferentKeys_ProduceDifferentResults');
  
  PlainText := 'Same message encrypted with different keys';
  
  IV := TRandomGenerator.RandomBytes(16);
  
  AES1 := TAESCrypto.Create(aes256, aesCBC);
  AES2 := TAESCrypto.Create(aes256, aesCBC);
  try
    AES1.SetKeyFromPassword('FirstPassword', TEncoding.UTF8.GetBytes('bug033_salt'));
    AES1.SetIV(IV);
    
    AES2.SetKeyFromPassword('SecondPassword', TEncoding.UTF8.GetBytes('bug033_salt'));
    AES2.SetIV(IV);
    
    Encrypted1 := AES1.EncryptString(PlainText);
    Encrypted2 := AES2.EncryptString(PlainText);
    
    Assert.AreNotEqual(Encrypted1, Encrypted2,
      'Different keys should produce different encryption results');
  finally
    AES1.Free;
    AES2.Free;
  end;
  
  LogTestEnd('Test_DifferentKeys_ProduceDifferentResults', True);
end;

procedure TBug033_WeakEncryptionTest.Test_EmptyKey_IsRejected;
var
  AES: TAESCrypto;
  ExceptionRaised: Boolean;
begin
  LogTestStart('Test_EmptyKey_IsRejected');
  
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    ExceptionRaised := False;
    
    try
      AES.SetKey(nil);
      AES.GenerateIV;
      AES.EncryptString('Test');
    except
      on E: Exception do
        ExceptionRaised := True;
    end;
    
    Assert.IsTrue(ExceptionRaised, 'Empty key should be rejected');
  finally
    AES.Free;
  end;
  
  LogTestEnd('Test_EmptyKey_IsRejected', True);
end;

procedure TBug033_WeakEncryptionTest.Test_EncryptedData_HasCorrectBlockSize;
var
  AES: TAESCrypto;
  PlainData: TBytes;
  EncryptedData: TBytes;
begin
  LogTestStart('Test_EncryptedData_HasCorrectBlockSize');
  
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKeyFromPassword('TestKey', TEncoding.UTF8.GetBytes('bug033_salt'));
    AES.GenerateIV;
    
    SetLength(PlainData, 10);
    FillChar(PlainData[0], 10, $41);
    
    EncryptedData := AES.Encrypt(PlainData);
    
    Assert.AreEqual(Integer(0), Integer(Length(EncryptedData) mod 16),
      'Encrypted data length should be multiple of 16 bytes (AES block size)');
    
    SetLength(PlainData, 16);
    FillChar(PlainData[0], 16, $42);
    
    EncryptedData := AES.Encrypt(PlainData);
    Assert.AreEqual(Integer(0), Integer(Length(EncryptedData) mod 16),
      'Encrypted data length should be multiple of 16 bytes');
  finally
    AES.Free;
  end;
  
  LogTestEnd('Test_EncryptedData_HasCorrectBlockSize', True);
end;

initialization
  TDUnitX.RegisterTestFixture(TBug033_WeakEncryptionTest);

end.
