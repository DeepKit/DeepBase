{ ============================================================================
  Test.DeepBase.Security - Cross-Platform Security Module Tests
  
  Tests:
  - Windows: DPAPI encryption
  - macOS/Linux: OpenSSL AES-256-GCM (UBS2 format)
  - Secret management (all platforms)
  - Tamper detection
  ============================================================================ }

unit Test.DeepBase.Security;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.NetEncoding,
  DeepBase.Manager,
  DeepBase.Security
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  , DeepBase.Crypto.OpenSSL
  {$ENDIF}
  ;

type
  [TestFixture]
  TTestDeepBaseSecurity = class
  private
    FInitialized: Boolean;
  public
    [Setup]
    procedure Setup;
    
    [TearDown]
    procedure TearDown;
    
    // DPAPI Tests
    [Test]
    procedure Test_ProtectUnprotect_SimpleString;
    
    [Test]
    procedure Test_ProtectUnprotect_EmptyString;
    
    [Test]
    procedure Test_ProtectUnprotect_UnicodeString;
    
    [Test]
    procedure Test_ProtectUnprotect_SpecialChars;
    
    [Test]
    procedure Test_ProtectUnprotect_LongString;
    
    // Secret Management Tests
    [Test]
    procedure Test_SaveAndLoadSecret;
    
    [Test]
    procedure Test_SecretExists_True;
    
    [Test]
    procedure Test_SecretExists_False;
    
    [Test]
    procedure Test_DeleteSecret;
    
    [Test]
    procedure Test_LoadSecret_NotFound;
    
    [Test]
    procedure Test_GetSecretNames;
    
    [Test]
    procedure Test_SaveSecret_UpdateExisting;
    
    // Global Function Tests
    [Test]
    procedure Test_GlobalLoadSaveSecret;

    [Test]
    procedure Test_SecureZeroMemory_Bytes;

    [Test]
    procedure Test_SecureZeroMemory_String;
    
    // Tamper Detection Tests
    [Test]
    procedure Test_TamperDetection_ModifiedByte;
    [Test]
    procedure Test_TamperDetection_TruncatedData;
    [Test]
    procedure Test_TamperDetection_InvalidHeader;
    
    // Encryption Diversity Test
    [Test]
    procedure Test_DifferentEncryptions_DifferentOutput;
  end;

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  /// <summary>
  /// Tests specific to OpenSSL backend (macOS/Linux only)
  /// </summary>
  [TestFixture]
  TTestOpenSSLBackend = class
  public
    [Test]
    procedure Test_OpenSSL_LoadAndVersion;
    [Test]
    procedure Test_RandomBytes_LengthAndEntropy;
    [Test]
    procedure Test_PBKDF2_Deterministic;
    [Test]
    procedure Test_AES256GCM_Roundtrip;
    [Test]
    procedure Test_AES256GCM_TagMismatch;
    [Test]
    procedure Test_UBS2_HeaderVersion_IsCurrent;
    [Test]
    procedure Test_UBS2_UnsupportedVersion_RaisesClearError;
    [Test]
    procedure Test_UBS2_UnsupportedKDF_RaisesClearError;
    [Test]
    procedure Test_UBS2_LegacyMagic_RaisesMigrationError;
  end;
{$ENDIF}

implementation

uses
  DeepBase.Exceptions;

{ TTestDeepBaseSecurity }

procedure TTestDeepBaseSecurity.Setup;
begin
  // Initialize DeepBase with in-memory database for testing
  if not DeepBase.Manager.DeepBase.IsInitialized then
    FInitialized := DeepBase.Manager.DeepBase.InitializeWithDB(':memory:')
  else
    FInitialized := True;
end;

procedure TTestDeepBaseSecurity.TearDown;
begin
  // Cleanup test secrets if initialized
  if FInitialized and Assigned(DeepBase.Manager.DeepBase.Security) then
  begin
    // Clean up test data
    DeepBase.Manager.DeepBase.Security.DeleteSecret('test_secret');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('test_unicode');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('test_special');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('test_delete');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('test_update');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('test_global');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('secret1');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('secret2');
    DeepBase.Manager.DeepBase.Security.DeleteSecret('secret3');
  end;
end;

// ============================================================================
// DPAPI Tests
// ============================================================================

procedure TTestDeepBaseSecurity.Test_ProtectUnprotect_SimpleString;
var
  Original: string;
  Encrypted: TBytes;
  Decrypted: string;
begin
  Original := 'Hello, World!';
  
  Encrypted := ProtectStringDpapi(Original);
  Assert.IsTrue(Length(Encrypted) > 0, 'Encrypted data should not be empty');
  
  Decrypted := UnprotectStringDpapi(Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

procedure TTestDeepBaseSecurity.Test_ProtectUnprotect_EmptyString;
var
  Original: string;
  Encrypted: TBytes;
  Decrypted: string;
begin
  Original := '';
  
  Encrypted := ProtectStringDpapi(Original);
  Assert.AreEqual(Integer(0), Integer(Length(Encrypted)), 'Empty string should produce empty bytes');
  
  Decrypted := UnprotectStringDpapi(Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

procedure TTestDeepBaseSecurity.Test_ProtectUnprotect_UnicodeString;
var
  Original: string;
  Encrypted: TBytes;
  Decrypted: string;
begin
  Original := 'Hello world unicode test';
  
  Encrypted := ProtectStringDpapi(Original);
  Assert.IsTrue(Length(Encrypted) > 0, 'Encrypted data should not be empty');
  
  Decrypted := UnprotectStringDpapi(Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

procedure TTestDeepBaseSecurity.Test_ProtectUnprotect_SpecialChars;
var
  Original: string;
  Encrypted: TBytes;
  Decrypted: string;
begin
  Original := 'P@ssw0rd!#$%^&*()_+-=[]{}|;'':",./<>?`~';
  
  Encrypted := ProtectStringDpapi(Original);
  Assert.IsTrue(Length(Encrypted) > 0, 'Encrypted data should not be empty');
  
  Decrypted := UnprotectStringDpapi(Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

procedure TTestDeepBaseSecurity.Test_ProtectUnprotect_LongString;
var
  Original: string;
  Encrypted: TBytes;
  Decrypted: string;
  i: Integer;
begin
  // Create a 10KB string
  Original := '';
  for i := 1 to 10000 do
    Original := Original + Chr(65 + (i mod 26));
  
  Encrypted := ProtectStringDpapi(Original);
  Assert.IsTrue(Length(Encrypted) > 0, 'Encrypted data should not be empty');
  
  Decrypted := UnprotectStringDpapi(Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

// ============================================================================
// Secret Management Tests
// ============================================================================

procedure TTestDeepBaseSecurity.Test_SaveAndLoadSecret;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  DeepBase.Manager.DeepBase.Security.SaveSecret('test_secret', 'MySecretPassword123');
  Loaded := DeepBase.Manager.DeepBase.Security.LoadSecret('test_secret');
  
  Assert.AreEqual('MySecretPassword123', Loaded);
end;

procedure TTestDeepBaseSecurity.Test_SecretExists_True;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  DeepBase.Manager.DeepBase.Security.SaveSecret('test_secret', 'value');
  Assert.IsTrue(DeepBase.Manager.DeepBase.Security.SecretExists('test_secret'));
end;

procedure TTestDeepBaseSecurity.Test_SecretExists_False;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  Assert.IsFalse(DeepBase.Manager.DeepBase.Security.SecretExists('nonexistent_secret'));
end;

procedure TTestDeepBaseSecurity.Test_DeleteSecret;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  DeepBase.Manager.DeepBase.Security.SaveSecret('test_delete', 'value');
  Assert.IsTrue(DeepBase.Manager.DeepBase.Security.SecretExists('test_delete'));
  
  DeepBase.Manager.DeepBase.Security.DeleteSecret('test_delete');
  Assert.IsFalse(DeepBase.Manager.DeepBase.Security.SecretExists('test_delete'));
end;

procedure TTestDeepBaseSecurity.Test_LoadSecret_NotFound;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  Loaded := DeepBase.Manager.DeepBase.Security.LoadSecret('definitely_not_exists');
  Assert.AreEqual('', Loaded);
end;

procedure TTestDeepBaseSecurity.Test_GetSecretNames;
var
  Names: TArray<string>;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  // Save some secrets
  DeepBase.Manager.DeepBase.Security.SaveSecret('secret1', 'value1');
  DeepBase.Manager.DeepBase.Security.SaveSecret('secret2', 'value2');
  DeepBase.Manager.DeepBase.Security.SaveSecret('secret3', 'value3');
  
  Names := DeepBase.Manager.DeepBase.Security.GetSecretNames;
  Assert.IsTrue(Length(Names) >= 3, 'Should have at least 3 secrets');
end;

procedure TTestDeepBaseSecurity.Test_SaveSecret_UpdateExisting;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  // Save initial value
  DeepBase.Manager.DeepBase.Security.SaveSecret('test_update', 'initial_value');
  Loaded := DeepBase.Manager.DeepBase.Security.LoadSecret('test_update');
  Assert.AreEqual('initial_value', Loaded);
  
  // Update value
  DeepBase.Manager.DeepBase.Security.SaveSecret('test_update', 'updated_value');
  Loaded := DeepBase.Manager.DeepBase.Security.LoadSecret('test_update');
  Assert.AreEqual('updated_value', Loaded);
end;

// ============================================================================
// Global Function Tests
// ============================================================================

procedure TTestDeepBaseSecurity.Test_GlobalLoadSaveSecret;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'DeepBase should be initialized');
  
  // Use global functions
  DeepBase.Security.SaveSecret('test_global', 'global_value');
  Loaded := DeepBase.Security.LoadSecret('test_global');
  
  Assert.AreEqual('global_value', Loaded);
end;

procedure TTestDeepBaseSecurity.Test_SecureZeroMemory_Bytes;
var
  Data: TBytes;
  B: Byte;
begin
  Data := TEncoding.UTF8.GetBytes('sensitive-bytes');
  Assert.IsTrue(Length(Data) > 0);

  SecureZeroMemory(Data);

  for B in Data do
    Assert.AreEqual(Byte(0), B);
end;

procedure TTestDeepBaseSecurity.Test_SecureZeroMemory_String;
var
  Data: string;
  I: Integer;
begin
  Data := 'sensitive-string';
  Assert.IsTrue(Length(Data) > 0);

  SecureZeroMemory(Data);

  for I := 1 to Length(Data) do
    Assert.AreEqual(#0, Data[I]);
end;

// ============================================================================
// Tamper Detection Tests
// ============================================================================

procedure TTestDeepBaseSecurity.Test_TamperDetection_ModifiedByte;
var
  Original: string;
  Encrypted: TBytes;
  TamperPos: Integer;
begin
  Original := 'Secret data for tamper test';
  Encrypted := ProtectStringDpapi(Original);
  
  // Tamper with a byte in the middle
  TamperPos := Length(Encrypted) div 2;
  Encrypted[TamperPos] := Encrypted[TamperPos] xor $FF;
  
  Assert.WillRaise(
    procedure
    begin
      UnprotectStringDpapi(Encrypted);
    end,
    EDecryptionException
  );
end;

procedure TTestDeepBaseSecurity.Test_TamperDetection_TruncatedData;
var
  Original: string;
  Encrypted, Truncated: TBytes;
begin
  Original := 'Secret data';
  Encrypted := ProtectStringDpapi(Original);

  // Truncate to half length
  SetLength(Truncated, Length(Encrypted) div 2);
  Move(Encrypted[0], Truncated[0], Length(Truncated));

  Assert.WillRaise(
    procedure
    begin
      UnprotectStringDpapi(Truncated);
    end,
    EDecryptionException
  );
end;

procedure TTestDeepBaseSecurity.Test_TamperDetection_InvalidHeader;
var
  BadData: TBytes;
begin
  // Create data with invalid header
  SetLength(BadData, 100);
  FillChar(BadData[0], Length(BadData), 0);
  BadData[0] := Ord('X');
  BadData[1] := Ord('Y');
  BadData[2] := Ord('Z');
  BadData[3] := Ord('!');

  Assert.WillRaise(
    procedure
    begin
      UnprotectStringDpapi(BadData);
    end,
    EDecryptionException
  );
end;

procedure TTestDeepBaseSecurity.Test_DifferentEncryptions_DifferentOutput;
var
  Original: string;
  Encrypted1, Encrypted2: TBytes;
  Base64_1, Base64_2: string;
begin
  Original := 'Same input text';
  
  Encrypted1 := ProtectStringDpapi(Original);
  Encrypted2 := ProtectStringDpapi(Original);
  
  Base64_1 := TNetEncoding.Base64.EncodeBytesToString(Encrypted1);
  Base64_2 := TNetEncoding.Base64.EncodeBytesToString(Encrypted2);
  
  // Both should decrypt to same value regardless of ciphertext difference
  Assert.AreEqual(Original, UnprotectStringDpapi(Encrypted1));
  Assert.AreEqual(Original, UnprotectStringDpapi(Encrypted2));
  
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  // On macOS/Linux with random salt/IV, output should differ
  Assert.AreNotEqual(Base64_1, Base64_2, 
    'Different encryptions should produce different ciphertext (random IV/salt)');
  {$ENDIF}
end;

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
// ============================================================================
// OpenSSL Backend Tests (macOS/Linux only)
// ============================================================================

procedure TTestOpenSSLBackend.Test_OpenSSL_LoadAndVersion;
var
  Ver: string;
begin
  OpenSSL_Init;
  Assert.IsTrue(OpenSSL_IsLoaded, 'OpenSSL should be loaded after Init');
  
  Ver := OpenSSL_Version;
  Assert.IsNotEmpty(Ver, 'OpenSSL version should not be empty');
end;

procedure TTestOpenSSLBackend.Test_RandomBytes_LengthAndEntropy;
var
  Bytes: TBytes;
  AllZeros: Boolean;
  I: Integer;
begin
  OpenSSL_Init;
  
  // Test various lengths
  Bytes := OpenSSL_RandomBytes(32);
  Assert.AreEqual(32, Length(Bytes), 'Should return requested length');
  
  Bytes := OpenSSL_RandomBytes(1024);
  Assert.AreEqual(1024, Integer(Length(Bytes)));
  
  // Check entropy (not all zeros)
  Bytes := OpenSSL_RandomBytes(32);
  AllZeros := True;
  for I := 0 to Length(Bytes) - 1 do
    if Bytes[I] <> 0 then
    begin
      AllZeros := False;
      Break;
    end;
  Assert.IsFalse(AllZeros, 'Random bytes should not all be zeros');
end;

procedure TTestOpenSSLBackend.Test_PBKDF2_Deterministic;
var
  Password, Salt, Key1, Key2: TBytes;
begin
  OpenSSL_Init;
  
  Password := TEncoding.UTF8.GetBytes('password123');
  Salt := TEncoding.UTF8.GetBytes('fixed_salt_value');
  
  Key1 := OpenSSL_PBKDF2_SHA256(Password, Salt, 1000, 32);
  Key2 := OpenSSL_PBKDF2_SHA256(Password, Salt, 1000, 32);
  
  Assert.AreEqual(32, Integer(Length(Key1)));
  Assert.AreEqual(32, Integer(Length(Key2)));
  
  // Same inputs should produce same key
  Assert.IsTrue(CompareMem(@Key1[0], @Key2[0], 32), 
    'PBKDF2 should be deterministic with same inputs');
end;

procedure TTestOpenSSLBackend.Test_AES256GCM_Roundtrip;
var
  Key, IV, Plaintext, Ciphertext, Tag, Decrypted: TBytes;
begin
  OpenSSL_Init;
  
  Key := OpenSSL_RandomBytes(32);
  IV := OpenSSL_RandomBytes(12);
  Plaintext := TEncoding.UTF8.GetBytes('Hello AES-256-GCM encryption test!');
  
  Ciphertext := OpenSSL_AES256GCM_Encrypt(Key, IV, Plaintext, nil, Tag);
  Assert.IsTrue(Length(Ciphertext) > 0, 'Ciphertext should not be empty');
  Assert.AreEqual(16, Length(Tag), 'Tag should be 16 bytes');
  
  Decrypted := OpenSSL_AES256GCM_Decrypt(Key, IV, Ciphertext, nil, Tag);
  Assert.AreEqual(
    TEncoding.UTF8.GetString(Plaintext),
    TEncoding.UTF8.GetString(Decrypted),
    'Decrypted should match plaintext'
  );
end;

procedure TTestOpenSSLBackend.Test_AES256GCM_TagMismatch;
var
  Key, IV, Plaintext, Ciphertext, Tag, BadTag: TBytes;
begin
  OpenSSL_Init;
  
  Key := OpenSSL_RandomBytes(32);
  IV := OpenSSL_RandomBytes(12);
  Plaintext := TEncoding.UTF8.GetBytes('Secret message');
  
  Ciphertext := OpenSSL_AES256GCM_Encrypt(Key, IV, Plaintext, nil, Tag);
  
  // Create bad tag
  BadTag := Copy(Tag);
  BadTag[0] := BadTag[0] xor $FF;
  
  Assert.WillRaise(
    procedure
    begin
      OpenSSL_AES256GCM_Decrypt(Key, IV, Ciphertext, nil, BadTag);
    end,
    EOpenSSLError,
    'Bad tag should raise authentication error'
  );
end;

procedure TTestOpenSSLBackend.Test_UBS2_HeaderVersion_IsCurrent;
var
  Encrypted: TBytes;
begin
  Encrypted := ProtectStringDpapi('versioned secret');

  Assert.IsTrue(Length(Encrypted) > 5, 'UBS2 payload should include magic and version');
  Assert.AreEqual(Ord('U'), Integer(Encrypted[0]));
  Assert.AreEqual(Ord('B'), Integer(Encrypted[1]));
  Assert.AreEqual(Ord('S'), Integer(Encrypted[2]));
  Assert.AreEqual(Ord('2'), Integer(Encrypted[3]));
  Assert.AreEqual(1, Integer(Encrypted[4]), 'UBS2 v1 should be the current writer version');
  Assert.AreEqual('versioned secret', UnprotectStringDpapi(Encrypted));
end;

procedure TTestOpenSSLBackend.Test_UBS2_UnsupportedVersion_RaisesClearError;
var
  Encrypted: TBytes;
begin
  Encrypted := ProtectStringDpapi('unsupported version');
  Encrypted[4] := $7F;

  try
    UnprotectStringDpapi(Encrypted);
    Assert.Fail('Unsupported UBS2 version should raise EDecryptionException');
  except
    on E: EDecryptionException do
    begin
      Assert.Contains(E.Message, 'Unsupported UBS2 version');
      Assert.Contains(E.Message, 'supported');
      Assert.Contains(E.Message, 'migrate');
    end;
  end;
end;

procedure TTestOpenSSLBackend.Test_UBS2_UnsupportedKDF_RaisesClearError;
var
  Encrypted: TBytes;
begin
  Encrypted := ProtectStringDpapi('unsupported kdf');
  Encrypted[5] := $7F;

  try
    UnprotectStringDpapi(Encrypted);
    Assert.Fail('Unsupported UBS2 KDF should raise EDecryptionException');
  except
    on E: EDecryptionException do
    begin
      Assert.Contains(E.Message, 'Unsupported UBS2 v1 KDF type');
      Assert.Contains(E.Message, 'PBKDF2-SHA256');
    end;
  end;
end;

procedure TTestOpenSSLBackend.Test_UBS2_LegacyMagic_RaisesMigrationError;
var
  LegacyData: TBytes;
begin
  SetLength(LegacyData, 64);
  FillChar(LegacyData[0], Length(LegacyData), 0);
  LegacyData[0] := Ord('U');
  LegacyData[1] := Ord('B');
  LegacyData[2] := Ord('S');
  LegacyData[3] := Ord('1');

  try
    UnprotectStringDpapi(LegacyData);
    Assert.Fail('Legacy UBS1 payload should raise EDecryptionException');
  except
    on E: EDecryptionException do
    begin
      Assert.Contains(E.Message, 'legacy');
      Assert.Contains(E.Message, 'UBS1');
      Assert.Contains(E.Message, 'Migrate');
    end;
  end;
end;
{$ENDIF}

initialization
  TDUnitX.RegisterTestFixture(TTestDeepBaseSecurity);
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  TDUnitX.RegisterTestFixture(TTestOpenSSLBackend);
  {$ENDIF}

end.
