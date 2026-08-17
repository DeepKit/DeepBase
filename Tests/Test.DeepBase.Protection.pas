{ ============================================================================
  Test.DeepBase.Protection - Unit tests for DeepBase.Protection (TBasicProtection)

  Coverage:
    - AES-256-GCM string encryption/decryption (Encrypt/DecryptSensitiveData)
    - AES-256-GCM binary encryption/decryption (Encrypt/DecryptBinaryData)
    - Legacy AES-256-CBC decryption compatibility
    - HMAC calculation and integrity verification
    - File hash and data hash helpers
  ============================================================================ }

unit Test.DeepBase.Protection;

interface

{$IFDEF MSWINDOWS} // DeepBase.Protection 基于 Windows CryptoAPI，仅�?Windows 上测�?

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.IOUtils,
  DeepBase.Protection,
  DeepBase.Exceptions;

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
    procedure EncryptSensitive_UsesGcmTextFormat;

    [Test]
    procedure EncryptDecryptBinary_Roundtrip;

    [Test]
    procedure EncryptBinary_UsesGcmEnvelope;

    [Test]
    procedure DecryptSensitive_WithWrongPassword_RaisesException;

    [Test]
    procedure DecryptSensitive_TamperedGcmPayload_RaisesException;

    [Test]
    procedure DecryptBinary_TamperedGcmPayload_RaisesException;

    [Test]
    procedure DecryptSensitive_LegacyCbcPayload_Roundtrip;

    [Test]
    procedure DecryptBinary_LegacyCbcPayload_Roundtrip;

    [Test]
    procedure CalculateHMAC_And_VerifyDataIntegrity_ReturnsTrue;

    [Test]
    procedure CalculateHMAC_UsesStandardHmacSha256Vector;

    [Test]
    procedure CalculateHMAC_EmptyPassword_RaisesMissingConfiguration;

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

function TestBytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to High(ABytes) do
    Result := Result + IntToHex(ABytes[I], 2);
end;

function TestHexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to High(Result) do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;

{ TTestBasicProtection }

procedure TTestBasicProtection.EncryptDecryptSensitive_Roundtrip_SimpleText;
var
  Plain, Encrypted, Decrypted: string;
begin
  Plain := 'Hello, DeepBase!';

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
  // 使用随机 IV，正常情况下两次密文应不同（碰撞概率极低�?
  Assert.AreNotEqual(C1, C2, 'Two encryptions with random IV should produce different ciphertext');
end;

procedure TTestBasicProtection.EncryptSensitive_UsesGcmTextFormat;
var
  Encrypted: string;
begin
  Encrypted := TBasicProtection.EncryptSensitiveData('Secret', 'Key-123');

  // CORE-R2-005: 字符串加密走 PBKDF2-HMAC-SHA256 派生密钥 + AES-GCM 信封,
  // 文本前缀 'UBP1|' 区分于裸 GCM 路径的 'UBG1|' (见 DecryptSensitiveData 分流).
  Assert.IsTrue(Encrypted.StartsWith('UBP1|'), 'New string encryption should use UBP1 PBKDF2-GCM format');
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

procedure TTestBasicProtection.EncryptBinary_UsesGcmEnvelope;
var
  Data, Encrypted: TBytes;
begin
  Data := TEncoding.UTF8.GetBytes('Binary payload');
  Encrypted := TBasicProtection.EncryptBinaryData(Data, 'Bin-Key');

  Assert.IsTrue(Length(Encrypted) > Length(Data), 'GCM envelope should include magic, nonce and tag');
  // CORE-R2-005: 二进制加密走 PBKDF2-GCM, magic = 'UBG2' ($32='2') 区分裸 GCM 的 'UBG1'.
  Assert.AreEqual<Integer>(Ord('U'), Encrypted[0]);
  Assert.AreEqual<Integer>(Ord('B'), Encrypted[1]);
  Assert.AreEqual<Integer>(Ord('G'), Encrypted[2]);
  Assert.AreEqual<Integer>(Ord('2'), Encrypted[3]);
end;

procedure TTestBasicProtection.DecryptSensitive_WithWrongPassword_RaisesException;
var
  Encrypted: string;
begin
  Encrypted := TBasicProtection.EncryptSensitiveData('Secret payload', 'Correct-Key');

  Assert.WillRaise(
    procedure
    begin
      TBasicProtection.DecryptSensitiveData(Encrypted, 'Wrong-Key');
    end,
    EDecryptionException
  );
end;

procedure TTestBasicProtection.DecryptSensitive_TamperedGcmPayload_RaisesException;
var
  Payload: TBytes;
  Tampered: string;
begin
  Payload := TBasicProtection.EncryptBinaryData(TEncoding.UTF8.GetBytes('Secret payload'), 'Correct-Key');
  Payload[High(Payload)] := Payload[High(Payload)] xor $01;
  Tampered := 'UBG1|' + TestBytesToHex(Payload);

  Assert.WillRaise(
    procedure
    begin
      TBasicProtection.DecryptSensitiveData(Tampered, 'Correct-Key');
    end,
    EDecryptionException
  );
end;

procedure TTestBasicProtection.DecryptBinary_TamperedGcmPayload_RaisesException;
var
  Encrypted: TBytes;
begin
  Encrypted := TBasicProtection.EncryptBinaryData(TEncoding.UTF8.GetBytes('Secret payload'), 'Correct-Key');
  Encrypted[High(Encrypted)] := Encrypted[High(Encrypted)] xor $01;

  Assert.WillRaise(
    procedure
    begin
      TBasicProtection.DecryptBinaryData(Encrypted, 'Correct-Key');
    end,
    EDecryptionException
  );
end;

procedure TTestBasicProtection.DecryptSensitive_LegacyCbcPayload_Roundtrip;
const
  LegacyEncrypted =
    '000102030405060708090A0B0C0D0E0F|' +
    'DC6F517AA8AF2D0EC67AAFDCFA2017C2EB2C504CA17BC02B1422157E833536FCFD9B0E759A3BE80F3409EEB404B94134';
begin
  Assert.AreEqual('Legacy CBC payload',
    TBasicProtection.DecryptSensitiveData(LegacyEncrypted, 'Legacy-Key'));
end;

procedure TTestBasicProtection.DecryptBinary_LegacyCbcPayload_Roundtrip;
const
  LegacyEncrypted =
    '000102030405060708090A0B0C0D0E0F' +
    'DC6F517AA8AF2D0EC67AAFDCFA2017C2EB2C504CA17BC02B1422157E833536FCFD9B0E759A3BE80F3409EEB404B94134';
var
  Decrypted: TBytes;
begin
  Decrypted := TBasicProtection.DecryptBinaryData(TestHexToBytes(LegacyEncrypted), 'Legacy-Key');

  Assert.AreEqual('Legacy CBC payload', TEncoding.UTF8.GetString(Decrypted));
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

procedure TTestBasicProtection.CalculateHMAC_UsesStandardHmacSha256Vector;
const
  CData = 'The quick brown fox jumps over the lazy dog';
  CKey = 'key';
  CExpected = 'f7bc83f430538424b13298e6aa6fb143ef4d59a14946175997479dbc2d1a3cd8';
var
  Actual: string;
begin
  Actual := LowerCase(TBasicProtection.CalculateHMAC(CData, CKey));
  Assert.AreEqual(CExpected, Actual, 'HMAC-SHA256 vector mismatch');
end;

procedure TTestBasicProtection.CalculateHMAC_EmptyPassword_RaisesMissingConfiguration;
begin
  Assert.WillRaise(
    procedure
    begin
      TBasicProtection.CalculateHMAC('payload', '');
    end,
    EMissingConfigurationException
  );
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
    EFileNotFoundExceptionEx
  );
end;

procedure TTestBasicProtection.CalculateFileHash_FileHashChanges_WhenContentChanges;
var
  TempFile: string;
  Hash1, Hash2: string;
begin
  TempFile := TPath.Combine(TPath.GetTempPath, 'DeepBase_protection_hash_test.tmp');

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
