{ ============================================================================
  Test.UniBase.Protection - Unit tests for UniBase.Protection (TBasicProtection)

  Coverage:
    - AES-256-CBC string encryption/decryption (Encrypt/DecryptSensitiveData)
    - AES-256-CBC binary encryption/decryption (Encrypt/DecryptBinaryData)
    - HMAC calculation and integrity verification
    - File hash and data hash helpers
  ============================================================================ }

unit Test.UniBase.Protection;

interface

{$IFDEF MSWINDOWS} // UniBase.Protection 基于 Windows CryptoAPI，仅在 Windows 上测试

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  UniBase.Protection;

type
  [TestFixture]
  TTestBasicProtection = class
  public
    [Test]
    procedure EncryptDecryptSensitive_Roundtrip_SimpleText;

    [Test]
    procedure EncryptDecryptSensitive_Roundtrip_Unicode;

    [Test]
    procedure EncryptSensitive_SameInput_ProducesDifferentCiphertext;

    [Test]
    procedure EncryptDecryptBinary_Roundtrip;

    [Test]
    procedure CalculateHMAC_And_VerifyDataIntegrity_ReturnsTrue;

    [Test]
    procedure VerifyDataIntegrity_ReturnsFalse_WhenDataTampered;

    [Test]
    procedure CalculateFileHash_FileNotFound_RaisesException;

    [Test]
    procedure CalculateFileHash_FileHashChanges_WhenContentChanges;

    [Test]
    procedure CalculateDataHash_IsStableAndDistinct;
  end;

{$ENDIF} // MSWINDOWS

implementation

{$IFDEF MSWINDOWS}

{ TTestBasicProtection }

procedure TTestBasicProtection.EncryptDecryptSensitive_Roundtrip_SimpleText;
var
  Plain, Encrypted, Decrypted: string;
begin
  Plain := 'Hello, UniBase!';

  Encrypted := TBasicProtection.EncryptSensitiveData(Plain, 'P@ssw0rd');
  Assert.IsNotEmpty(Encrypted, 'Encrypted text should not be empty');

  Decrypted := TBasicProtection.DecryptSensitiveData(Encrypted, 'P@ssw0rd');
  Assert.AreEqual(Plain, Decrypted, 'Decrypted text should equal original');
end;

procedure TTestBasicProtection.EncryptDecryptSensitive_Roundtrip_Unicode;
var
  Plain, Encrypted, Decrypted: string;
begin
  Plain := '多语言测试 🌍 你好, 世界!';

  Encrypted := TBasicProtection.EncryptSensitiveData(Plain, 'Unicode-Key');
  Assert.IsNotEmpty(Encrypted, 'Encrypted text should not be empty');

  Decrypted := TBasicProtection.DecryptSensitiveData(Encrypted, 'Unicode-Key');
  Assert.AreEqual(Plain, Decrypted, 'Unicode text should roundtrip correctly');
end;

procedure TTestBasicProtection.EncryptSensitive_SameInput_ProducesDifferentCiphertext;
var
  C1, C2: string;
begin
  C1 := TBasicProtection.EncryptSensitiveData('SamePlainText', 'Key-123');
  C2 := TBasicProtection.EncryptSensitiveData('SamePlainText', 'Key-123');

  Assert.IsNotEmpty(C1);
  Assert.IsNotEmpty(C2);
  // 使用随机 IV，正常情况下两次密文应不同（碰撞概率极低）
  Assert.AreNotEqual(C1, C2, 'Two encryptions with random IV should produce different ciphertext');
end;

procedure TTestBasicProtection.EncryptDecryptBinary_Roundtrip;
var
  Data, Encrypted, Decrypted: TBytes;
  I: Integer;
begin
  SetLength(Data, 256);
  for I := 0 to High(Data) do
    Data[I] := Byte(I);

  Encrypted := TBasicProtection.EncryptBinaryData(Data, 'Bin-Key');
  Assert.IsTrue(Length(Encrypted) > Length(Data), 'Encrypted binary should include IV and padding');

  Decrypted := TBasicProtection.DecryptBinaryData(Encrypted, 'Bin-Key');
  Assert.AreEqual(Length(Data), Length(Decrypted), 'Decrypted length should match original');
  for I := 0 to High(Data) do
    Assert.AreEqual<Integer>(Data[I], Decrypted[I], Format('Byte %d mismatch', [I]));
end;

procedure TTestBasicProtection.CalculateHMAC_And_VerifyDataIntegrity_ReturnsTrue;
var
  Data, HMAC: string;
begin
  Data := 'Important configuration payload';
  HMAC := TBasicProtection.CalculateHMAC(Data, 'HMAC-Key');
  Assert.IsNotEmpty(HMAC, 'HMAC should not be empty');

  Assert.IsTrue(TBasicProtection.VerifyDataIntegrity(Data, HMAC, 'HMAC-Key'),
    'VerifyDataIntegrity should return True for unchanged data and same key');
end;

procedure TTestBasicProtection.VerifyDataIntegrity_ReturnsFalse_WhenDataTampered;
var
  Data, HMAC: string;
begin
  Data := 'Original data';
  HMAC := TBasicProtection.CalculateHMAC(Data, 'Key-1');

  // 修改数据或密钥后，校验应失败
  Assert.IsFalse(TBasicProtection.VerifyDataIntegrity('Original data (tampered)', HMAC, 'Key-1'));
  Assert.IsFalse(TBasicProtection.VerifyDataIntegrity(Data, HMAC, 'Key-2'));
end;

procedure TTestBasicProtection.CalculateFileHash_FileNotFound_RaisesException;
begin
  Assert.WillRaise(
    procedure
    begin
      TBasicProtection.CalculateFileHash('Z:\this_file_should_not_exist_123456789.txt');
    end,
    Exception
  );
end;

procedure TTestBasicProtection.CalculateFileHash_FileHashChanges_WhenContentChanges;
var
  TempFile: string;
  Hash1, Hash2: string;
begin
  TempFile := TPath.Combine(TPath.GetTempPath, 'unibase_protection_hash_test.tmp');

  if TFile.Exists(TempFile) then
    TFile.Delete(TempFile);

  TFile.WriteAllText(TempFile, 'Content A', TEncoding.UTF8);
  Hash1 := TBasicProtection.CalculateFileHash(TempFile);

  TFile.WriteAllText(TempFile, 'Content B', TEncoding.UTF8);
  Hash2 := TBasicProtection.CalculateFileHash(TempFile);

  Assert.IsNotEmpty(Hash1);
  Assert.IsNotEmpty(Hash2);
  Assert.AreNotEqual(Hash1, Hash2, 'Hash should change when file content changes');

  TFile.Delete(TempFile);
end;

procedure TTestBasicProtection.CalculateDataHash_IsStableAndDistinct;
var
  Data1, Data2: TBytes;
  H11, H12, H2: string;
begin
  Data1 := TEncoding.UTF8.GetBytes('ABC123');
  Data2 := TEncoding.UTF8.GetBytes('ABC1234');

  H11 := TBasicProtection.CalculateDataHash(Data1);
  H12 := TBasicProtection.CalculateDataHash(Data1);
  H2 := TBasicProtection.CalculateDataHash(Data2);

  Assert.AreEqual(H11, H12, 'Same data should always produce same hash');
  Assert.AreNotEqual(H11, H2, 'Different data should produce different hashes');
end;

initialization
  TDUnitX.RegisterTestFixture(TTestBasicProtection);

{$ENDIF} // MSWINDOWS

end.
