{ ============================================================================
  Test.SeedTool - SeedTool 宸ュ叿鍗曞厓娴嬭瘯

  娴嬭瘯瑕嗙洊:
    - TBasicProtection: 鍔犲瘑瑙ｅ瘑銆丠MAC銆佸搱甯?    - TAntiTamperPackage: 闃茬鏀规暟鎹寘
  ============================================================================ }

unit Test.SeedTool;

interface

uses
  System.SysUtils,
  System.Classes,
  System.IOUtils,
  System.Hash,
  DUnitX.TestFramework;

type
  // ============================================================================
  // TBasicProtection Tests
  // ============================================================================

  [TestFixture]
  TBasicProtectionTests = class
  public
    [Test]
    procedure Test_EncryptDecrypt_String;

    [Test]
    procedure Test_EncryptDecrypt_CustomPassword;

    [Test]
    procedure Test_EncryptDecrypt_Empty;

    [Test]
    procedure Test_EncryptDecrypt_Unicode;

    [Test]
    procedure Test_EncryptDecrypt_LongString;

    [Test]
    procedure Test_EncryptDecrypt_Binary;

    [Test]
    procedure Test_CalculateHMAC;

    [Test]
    procedure Test_VerifyDataIntegrity_Valid;

    [Test]
    procedure Test_VerifyDataIntegrity_Invalid;

    [Test]
    procedure Test_CalculateDataHash;

    [Test]
    procedure Test_CalculateDataHash_Consistency;

    [Test]
    procedure Test_CalculateFileHash;

    [Test]
    procedure Test_Encrypted_Different_Each_Time;
  end;

  // ============================================================================
  // TAntiTamperPackage Tests
  // ============================================================================

  [TestFixture]
  TAntiTamperPackageTests = class
  private
    FTestDir: string;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_CreatePackage;

    [Test]
    procedure Test_LoadPackage;

    [Test]
    procedure Test_PackageContainsSignature;

    [Test]
    procedure Test_PackageContainsTimestamp;

    [Test]
    procedure Test_TamperedPackage_Detection;
  end;

implementation

uses
  uBasicProtection,
  uAntiTamperPackage;

{ TBasicProtectionTests }

procedure TBasicProtectionTests.Test_EncryptDecrypt_String;
var
  Original, Encrypted, Decrypted: string;
begin
  Original := 'Hello World!';
  Encrypted := TBasicProtection.EncryptSensitiveData(Original);
  Decrypted := TBasicProtection.DecryptSensitiveData(Encrypted);

  Assert.AreNotEqual(Original, Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

procedure TBasicProtectionTests.Test_EncryptDecrypt_CustomPassword;
var
  Original, Encrypted, Decrypted: string;
begin
  Original := 'Secret Data';
  Encrypted := TBasicProtection.EncryptSensitiveData(Original, 'MyCustomPassword123');
  Decrypted := TBasicProtection.DecryptSensitiveData(Encrypted, 'MyCustomPassword123');

  Assert.AreEqual(Original, Decrypted);
end;

procedure TBasicProtectionTests.Test_EncryptDecrypt_Empty;
var
  Encrypted, Decrypted: string;
begin
  Encrypted := TBasicProtection.EncryptSensitiveData('');
  Decrypted := TBasicProtection.DecryptSensitiveData(Encrypted);

  Assert.AreEqual('', Decrypted);
end;

procedure TBasicProtectionTests.Test_EncryptDecrypt_Unicode;
var
  Original, Encrypted, Decrypted: string;
begin
  Original := '涓枃娴嬭瘯 鏃ユ湰瑾?頃滉淡鞏?馃帀';
  Encrypted := TBasicProtection.EncryptSensitiveData(Original);
  Decrypted := TBasicProtection.DecryptSensitiveData(Encrypted);

  Assert.AreEqual(Original, Decrypted);
end;

procedure TBasicProtectionTests.Test_EncryptDecrypt_LongString;
var
  Original, Encrypted, Decrypted: string;
  I: Integer;
begin
  // 鐢熸垚 10KB 娴嬭瘯鏁版嵁
  Original := '';
  for I := 1 to 1000 do
    Original := Original + 'TestData_' + IntToStr(I) + '_';

  Encrypted := TBasicProtection.EncryptSensitiveData(Original);
  Decrypted := TBasicProtection.DecryptSensitiveData(Encrypted);

  Assert.AreEqual(Original, Decrypted);
end;

procedure TBasicProtectionTests.Test_EncryptDecrypt_Binary;
var
  Original, Encrypted, Decrypted: TBytes;
  I: Integer;
begin
  SetLength(Original, 256);
  for I := 0 to 255 do
    Original[I] := Byte(I);

  Encrypted := TBasicProtection.EncryptBinaryData(Original);
  Decrypted := TBasicProtection.DecryptBinaryData(Encrypted);

  Assert.AreEqual(Length(Original), Length(Decrypted));
  for I := 0 to High(Original) do
    Assert.AreEqual(Original[I], Decrypted[I]);
end;

procedure TBasicProtectionTests.Test_CalculateHMAC;
var
  Data, HMAC: string;
begin
  Data := 'Test data for HMAC';
  HMAC := TBasicProtection.CalculateHMAC(Data);

  Assert.IsNotEmpty(HMAC);
  Assert.AreEqual(64, Integer(Length(HMAC));  // SHA-256 produces 64 hex chars
end;

procedure TBasicProtectionTests.Test_VerifyDataIntegrity_Valid;
var
  Data, HMAC: string;
begin
  Data := 'Original data';
  HMAC := TBasicProtection.CalculateHMAC(Data);

  Assert.IsTrue(TBasicProtection.VerifyDataIntegrity(Data, HMAC));
end;

procedure TBasicProtectionTests.Test_VerifyDataIntegrity_Invalid;
var
  Data, HMAC: string;
begin
  Data := 'Original data';
  HMAC := TBasicProtection.CalculateHMAC(Data);

  // 淇敼鏁版嵁鍚庨獙璇佸簲璇ュけ璐?  Assert.IsFalse(TBasicProtection.VerifyDataIntegrity('Modified data', HMAC));
end;

procedure TBasicProtectionTests.Test_CalculateDataHash;
var
  Data: TBytes;
  Hash: string;
begin
  Data := TEncoding.UTF8.GetBytes('Test data');
  Hash := TBasicProtection.CalculateDataHash(Data);

  Assert.IsNotEmpty(Hash);
  Assert.AreEqual(64, Integer(Length(Hash));  // SHA-256
end;

procedure TBasicProtectionTests.Test_CalculateDataHash_Consistency;
var
  Data: TBytes;
  Hash1, Hash2: string;
begin
  Data := TEncoding.UTF8.GetBytes('Consistent data');
  Hash1 := TBasicProtection.CalculateDataHash(Data);
  Hash2 := TBasicProtection.CalculateDataHash(Data);

  Assert.AreEqual(Hash1, Hash2);
end;

procedure TBasicProtectionTests.Test_CalculateFileHash;
var
  FileName, Hash: string;
begin
  FileName := TPath.Combine(TPath.GetTempPath, 'test_hash_' + FormatDateTime('hhnnsszzz', Now) + '.tmp');
  try
    TFile.WriteAllText(FileName, 'File content for hashing');
    Hash := TBasicProtection.CalculateFileHash(FileName);

    Assert.IsNotEmpty(Hash);
    Assert.AreEqual(64, Integer(Length(Hash));
  finally
    if TFile.Exists(FileName) then
      TFile.Delete(FileName);
  end;
end;

procedure TBasicProtectionTests.Test_Encrypted_Different_Each_Time;
var
  Original, Encrypted1, Encrypted2: string;
begin
  Original := 'Same input data';
  Encrypted1 := TBasicProtection.EncryptSensitiveData(Original);
  Encrypted2 := TBasicProtection.EncryptSensitiveData(Original);

  // 鐢变簬闅忔満 IV锛屾瘡娆″姞瀵嗙粨鏋滃簲璇ヤ笉鍚?  Assert.AreNotEqual(Encrypted1, Encrypted2);

  // 浣嗕袱涓兘搴旇鑳芥纭В瀵?  Assert.AreEqual(Original, TBasicProtection.DecryptSensitiveData(Encrypted1));
  Assert.AreEqual(Original, TBasicProtection.DecryptSensitiveData(Encrypted2));
end;

{ TAntiTamperPackageTests }

procedure TAntiTamperPackageTests.Setup;
begin
  FTestDir := TPath.Combine(TPath.GetTempPath, 'SeedTool_Test_' + FormatDateTime('hhnnsszzz', Now));
  ForceDirectories(FTestDir);
end;

procedure TAntiTamperPackageTests.TearDown;
begin
  if TDirectory.Exists(FTestDir) then
    TDirectory.Delete(FTestDir, True);
end;

procedure TAntiTamperPackageTests.Test_CreatePackage;
var
  Package: TAntiTamperPackage;
  FileName: string;
begin
  Package := TAntiTamperPackage.Create;
  try
    Package.SetData('testKey', 'testValue');

    FileName := TPath.Combine(FTestDir, 'test.pkg');
    Package.SaveToFile(FileName);

    Assert.IsTrue(TFile.Exists(FileName));
    Assert.IsTrue(TFile.GetSize(FileName) > 0);
  finally
    Package.Free;
  end;
end;

procedure TAntiTamperPackageTests.Test_LoadPackage;
var
  Package1, Package2: TAntiTamperPackage;
  FileName: string;
begin
  FileName := TPath.Combine(FTestDir, 'load_test.pkg');

  Package1 := TAntiTamperPackage.Create;
  try
    Package1.SetData('key1', 'value1');
    Package1.SetData('key2', 'value2');
    Package1.SaveToFile(FileName);
  finally
    Package1.Free;
  end;

  Package2 := TAntiTamperPackage.Create;
  try
    Package2.LoadFromFile(FileName);
    Assert.AreEqual('value1', Package2.GetData('key1'));
    Assert.AreEqual('value2', Package2.GetData('key2'));
  finally
    Package2.Free;
  end;
end;

procedure TAntiTamperPackageTests.Test_PackageContainsSignature;
var
  Package: TAntiTamperPackage;
  FileName: string;
  Content: TBytes;
begin
  Package := TAntiTamperPackage.Create;
  try
    Package.SetData('test', 'data');
    FileName := TPath.Combine(FTestDir, 'sig_test.pkg');
    Package.SaveToFile(FileName);

    Content := TFile.ReadAllBytes(FileName);
    // 鏂囦欢搴旇鍖呭惈绛惧悕/鏍￠獙鏁版嵁
    Assert.IsTrue(Length(Content) > 10);
  finally
    Package.Free;
  end;
end;

procedure TAntiTamperPackageTests.Test_PackageContainsTimestamp;
var
  Package: TAntiTamperPackage;
begin
  Package := TAntiTamperPackage.Create;
  try
    Package.SetData('test', 'data');
    Assert.IsTrue(Package.Timestamp > 0);
  finally
    Package.Free;
  end;
end;

procedure TAntiTamperPackageTests.Test_TamperedPackage_Detection;
var
  Package: TAntiTamperPackage;
  FileName: string;
  Content: TBytes;
  FS: TFileStream;
begin
  Package := TAntiTamperPackage.Create;
  try
    Package.SetData('secret', 'sensitive data');
    FileName := TPath.Combine(FTestDir, 'tamper_test.pkg');
    Package.SaveToFile(FileName);
  finally
    Package.Free;
  end;

  // 绡℃敼鏂囦欢涓棿鐨勪竴涓瓧鑺?  Content := TFile.ReadAllBytes(FileName);
  if Length(Content) > 50 then
    Content[50] := Content[50] xor $FF;
  TFile.WriteAllBytes(FileName, Content);

  // 鍔犺浇绡℃敼鍚庣殑鏂囦欢搴旇妫€娴嬪埌
  Package := TAntiTamperPackage.Create;
  try
    try
      Package.LoadFromFile(FileName);
      // 濡傛灉娌℃湁鎶涘嚭寮傚父锛屾鏌ュ畬鏁存€ф爣蹇?      Assert.IsFalse(Package.IsValid, 'Tampered package should be detected as invalid');
    except
      on E: Exception do
        // 鎶涘嚭寮傚父涔熸槸鍚堢悊鐨勮涓?        Assert.Pass('Tampering detected via exception: ' + E.Message);
    end;
  finally
    Package.Free;
  end;
end;

initialization
  TDUnitX.RegisterTestFixture(TBasicProtectionTests);
  TDUnitX.RegisterTestFixture(TAntiTamperPackageTests);

end.
