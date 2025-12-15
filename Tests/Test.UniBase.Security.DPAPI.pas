unit Test.UniBase.Security.DPAPI;

interface

uses
  System.SysUtils,
  System.Classes,
  DUnitX.TestFramework,
  {$IFDEF MSWINDOWS}
  UniBase.Security.DPAPI
  {$ENDIF};

{$IFDEF MSWINDOWS}

type
  /// <summary>
  /// Tests for TDPAPIHelper class.
  /// </summary>
  [TestFixture]
  TDPAPIHelperTests = class
  public
    [Test]
    procedure Test_IsAvailable_Returns_True_On_Windows;

    [Test]
    procedure Test_ProtectString_UnprotectString_Roundtrip;

    [Test]
    procedure Test_ProtectString_Returns_Base64_Encoded;

    [Test]
    procedure Test_Protect_Unprotect_Bytes_Roundtrip;

    [Test]
    procedure Test_ProtectString_With_Entropy;

    [Test]
    procedure Test_UnprotectString_With_Wrong_Entropy_Fails;

    [Test]
    procedure Test_ProtectString_Empty_String;

    [Test]
    procedure Test_ProtectString_Unicode_Content;

    [Test]
    procedure Test_ProtectString_Large_Content;
  end;

  /// <summary>
  /// Tests for TCredentialManager class.
  /// </summary>
  [TestFixture]
  TCredentialManagerTests = class
  private const
    TEST_TARGET = 'UniBase_Test_Credential_12345';
  public
    [Setup]
    procedure Setup;

    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_SaveCredential_And_GetCredential_Roundtrip;

    [Test]
    procedure Test_CredentialExists_Returns_True_After_Save;

    [Test]
    procedure Test_CredentialExists_Returns_False_For_NonExistent;

    [Test]
    procedure Test_DeleteCredential_Removes_Credential;

    [Test]
    procedure Test_GetCredential_Returns_False_For_NonExistent;

    [Test]
    procedure Test_SaveCredential_Updates_Existing;
  end;

  /// <summary>
  /// Tests for TSecureString class.
  /// </summary>
  [TestFixture]
  TSecureStringTests = class
  public
    [Test]
    procedure Test_Create_From_String;

    [Test]
    procedure Test_Create_From_Bytes;

    [Test]
    procedure Test_ToString_Returns_Original;

    [Test]
    procedure Test_ToBytes_Returns_UTF8_Bytes;

    [Test]
    procedure Test_Clear_Zeros_Memory;

    [Test]
    procedure Test_DataLength_Returns_Correct_Length;

    [Test]
    procedure Test_Empty_String;

    [Test]
    procedure Test_Unicode_Content;
  end;

{$ENDIF}

implementation

{$IFDEF MSWINDOWS}

{ TDPAPIHelperTests }

procedure TDPAPIHelperTests.Test_IsAvailable_Returns_True_On_Windows;
begin
  Assert.IsTrue(TDPAPIHelper.IsAvailable, 'DPAPI should be available on Windows');
end;

procedure TDPAPIHelperTests.Test_ProtectString_UnprotectString_Roundtrip;
var
  Original, Encrypted, Decrypted: string;
begin
  Original := 'Hello, this is a secret message!';

  Encrypted := TDPAPIHelper.ProtectString(Original);
  Assert.AreNotEqual(Original, Encrypted, 'Encrypted should differ from original');

  Decrypted := TDPAPIHelper.UnprotectString(Encrypted);
  Assert.AreEqual(Original, Decrypted, 'Decrypted should match original');
end;

procedure TDPAPIHelperTests.Test_ProtectString_Returns_Base64_Encoded;
var
  Encrypted: string;
begin
  Encrypted := TDPAPIHelper.ProtectString('Test');

  // Base64 only contains alphanumeric, +, /, and = characters
  Assert.IsTrue(Encrypted.Length > 0, 'Encrypted should not be empty');
  // Basic check: Base64 doesn't contain special characters like spaces
  Assert.IsFalse(Encrypted.Contains(' '), 'Base64 should not contain spaces');
end;

procedure TDPAPIHelperTests.Test_Protect_Unprotect_Bytes_Roundtrip;
var
  Original, Encrypted, Decrypted: TBytes;
begin
  Original := TBytes.Create(1, 2, 3, 4, 5, 255, 0, 128);

  Encrypted := TDPAPIHelper.Protect(Original);
  Assert.IsTrue(Length(Encrypted) > 0, 'Encrypted should not be empty');

  Decrypted := TDPAPIHelper.Unprotect(Encrypted);
  Assert.AreEqual(Length(Original), Length(Decrypted), 'Decrypted length should match');

  for var I := 0 to High(Original) do
    Assert.AreEqual(Original[I], Decrypted[I], Format('Byte %d should match', [I]));
end;

procedure TDPAPIHelperTests.Test_ProtectString_With_Entropy;
var
  Original, Encrypted, Decrypted: string;
  Entropy: TBytes;
begin
  Original := 'Secret with entropy';
  Entropy := TEncoding.UTF8.GetBytes('my-entropy-password');

  Encrypted := TDPAPIHelper.ProtectString(Original, psCurrentUser, Entropy);
  Decrypted := TDPAPIHelper.UnprotectString(Encrypted, Entropy);

  Assert.AreEqual(Original, Decrypted, 'Should decrypt with correct entropy');
end;

procedure TDPAPIHelperTests.Test_UnprotectString_With_Wrong_Entropy_Fails;
var
  Original, Encrypted: string;
  CorrectEntropy, WrongEntropy: TBytes;
begin
  Original := 'Secret with entropy';
  CorrectEntropy := TEncoding.UTF8.GetBytes('correct-entropy');
  WrongEntropy := TEncoding.UTF8.GetBytes('wrong-entropy');

  Encrypted := TDPAPIHelper.ProtectString(Original, psCurrentUser, CorrectEntropy);

  Assert.WillRaise(
    procedure
    begin
      TDPAPIHelper.UnprotectString(Encrypted, WrongEntropy);
    end,
    EDPAPIError,
    'Should fail with wrong entropy'
  );
end;

procedure TDPAPIHelperTests.Test_ProtectString_Empty_String;
var
  Encrypted, Decrypted: string;
begin
  Encrypted := TDPAPIHelper.ProtectString('');
  Decrypted := TDPAPIHelper.UnprotectString(Encrypted);

  Assert.AreEqual('', Decrypted, 'Empty string should roundtrip');
end;

procedure TDPAPIHelperTests.Test_ProtectString_Unicode_Content;
var
  Original, Encrypted, Decrypted: string;
begin
  Original := '你好世界 🌍 Привет мир مرحبا';

  Encrypted := TDPAPIHelper.ProtectString(Original);
  Decrypted := TDPAPIHelper.UnprotectString(Encrypted);

  Assert.AreEqual(Original, Decrypted, 'Unicode content should roundtrip');
end;

procedure TDPAPIHelperTests.Test_ProtectString_Large_Content;
var
  Original, Encrypted, Decrypted: string;
  I: Integer;
begin
  // Create a 10KB string
  Original := '';
  for I := 1 to 10000 do
    Original := Original + Chr(65 + (I mod 26));

  Encrypted := TDPAPIHelper.ProtectString(Original);
  Decrypted := TDPAPIHelper.UnprotectString(Encrypted);

  Assert.AreEqual(Original.Length, Decrypted.Length, 'Large content length should match');
  Assert.AreEqual(Original, Decrypted, 'Large content should roundtrip');
end;

{ TCredentialManagerTests }

procedure TCredentialManagerTests.Setup;
begin
  // Ensure test credential doesn't exist before each test
  TCredentialManager.DeleteCredential(TEST_TARGET);
end;

procedure TCredentialManagerTests.TearDown;
begin
  // Clean up test credential after each test
  TCredentialManager.DeleteCredential(TEST_TARGET);
end;

procedure TCredentialManagerTests.Test_SaveCredential_And_GetCredential_Roundtrip;
var
  Username, Password: string;
begin
  TCredentialManager.SaveCredential(TEST_TARGET, 'testuser', 'testpass123');

  Assert.IsTrue(
    TCredentialManager.GetCredential(TEST_TARGET, Username, Password),
    'GetCredential should return True'
  );
  Assert.AreEqual('testuser', Username, 'Username should match');
  Assert.AreEqual('testpass123', Password, 'Password should match');
end;

procedure TCredentialManagerTests.Test_CredentialExists_Returns_True_After_Save;
begin
  Assert.IsFalse(
    TCredentialManager.CredentialExists(TEST_TARGET),
    'Should not exist before save'
  );

  TCredentialManager.SaveCredential(TEST_TARGET, 'user', 'pass');

  Assert.IsTrue(
    TCredentialManager.CredentialExists(TEST_TARGET),
    'Should exist after save'
  );
end;

procedure TCredentialManagerTests.Test_CredentialExists_Returns_False_For_NonExistent;
begin
  Assert.IsFalse(
    TCredentialManager.CredentialExists('NonExistent_Credential_XYZ_123'),
    'Should return False for non-existent credential'
  );
end;

procedure TCredentialManagerTests.Test_DeleteCredential_Removes_Credential;
begin
  TCredentialManager.SaveCredential(TEST_TARGET, 'user', 'pass');
  Assert.IsTrue(TCredentialManager.CredentialExists(TEST_TARGET), 'Should exist');

  Assert.IsTrue(
    TCredentialManager.DeleteCredential(TEST_TARGET),
    'Delete should return True'
  );

  Assert.IsFalse(
    TCredentialManager.CredentialExists(TEST_TARGET),
    'Should not exist after delete'
  );
end;

procedure TCredentialManagerTests.Test_GetCredential_Returns_False_For_NonExistent;
var
  Username, Password: string;
begin
  Assert.IsFalse(
    TCredentialManager.GetCredential('NonExistent_Credential_XYZ_456', Username, Password),
    'Should return False for non-existent'
  );
end;

procedure TCredentialManagerTests.Test_SaveCredential_Updates_Existing;
var
  Username, Password: string;
begin
  TCredentialManager.SaveCredential(TEST_TARGET, 'user1', 'pass1');
  TCredentialManager.SaveCredential(TEST_TARGET, 'user2', 'pass2');

  TCredentialManager.GetCredential(TEST_TARGET, Username, Password);

  Assert.AreEqual('user2', Username, 'Username should be updated');
  Assert.AreEqual('pass2', Password, 'Password should be updated');
end;

{ TSecureStringTests }

procedure TSecureStringTests.Test_Create_From_String;
var
  Secure: TSecureString;
begin
  Secure := TSecureString.Create('Hello World');
  try
    Assert.AreEqual('Hello World', Secure.ToString);
  finally
    Secure.Free;
  end;
end;

procedure TSecureStringTests.Test_Create_From_Bytes;
var
  Secure: TSecureString;
  Bytes: TBytes;
begin
  Bytes := TEncoding.UTF8.GetBytes('Test Data');
  Secure := TSecureString.Create(Bytes);
  try
    Assert.AreEqual('Test Data', Secure.ToString);
  finally
    Secure.Free;
  end;
end;

procedure TSecureStringTests.Test_ToString_Returns_Original;
var
  Secure: TSecureString;
begin
  Secure := TSecureString.Create('Original String');
  try
    Assert.AreEqual('Original String', Secure.ToString);
    // Call again to ensure it's still valid
    Assert.AreEqual('Original String', Secure.ToString);
  finally
    Secure.Free;
  end;
end;

procedure TSecureStringTests.Test_ToBytes_Returns_UTF8_Bytes;
var
  Secure: TSecureString;
  Bytes: TBytes;
  Expected: TBytes;
begin
  Secure := TSecureString.Create('ABC');
  try
    Bytes := Secure.ToBytes;
    Expected := TEncoding.UTF8.GetBytes('ABC');

    Assert.AreEqual(Length(Expected), Length(Bytes), 'Byte length should match');
    for var I := 0 to High(Expected) do
      Assert.AreEqual(Expected[I], Bytes[I], Format('Byte %d should match', [I]));
  finally
    Secure.Free;
  end;
end;

procedure TSecureStringTests.Test_Clear_Zeros_Memory;
var
  Secure: TSecureString;
begin
  Secure := TSecureString.Create('Secret Data');
  try
    Assert.IsTrue(Secure.DataLength > 0, 'Should have data before clear');

    Secure.Clear;

    Assert.AreEqual(0, Secure.DataLength, 'DataLength should be 0 after clear');
    Assert.AreEqual('', Secure.ToString, 'ToString should be empty after clear');
  finally
    Secure.Free;
  end;
end;

procedure TSecureStringTests.Test_DataLength_Returns_Correct_Length;
var
  Secure: TSecureString;
begin
  Secure := TSecureString.Create('Hello');
  try
    // UTF-8 bytes for 'Hello' is 5 bytes
    Assert.AreEqual(5, Secure.DataLength);
  finally
    Secure.Free;
  end;
end;

procedure TSecureStringTests.Test_Empty_String;
var
  Secure: TSecureString;
begin
  Secure := TSecureString.Create('');
  try
    Assert.AreEqual(0, Secure.DataLength);
    Assert.AreEqual('', Secure.ToString);
  finally
    Secure.Free;
  end;
end;

procedure TSecureStringTests.Test_Unicode_Content;
var
  Secure: TSecureString;
begin
  Secure := TSecureString.Create('中文测试');
  try
    Assert.AreEqual('中文测试', Secure.ToString);
    Assert.IsTrue(Secure.DataLength > 4, 'UTF-8 bytes should be more than char count');
  finally
    Secure.Free;
  end;
end;

{$ENDIF}

initialization
{$IFDEF MSWINDOWS}
  TDUnitX.RegisterTestFixture(TDPAPIHelperTests);
  TDUnitX.RegisterTestFixture(TCredentialManagerTests);
  TDUnitX.RegisterTestFixture(TSecureStringTests);
{$ENDIF}

end.
