{ ============================================================================
  Test.UniBase.Security - Security Module Tests
  
  Tests DPAPI encryption and secret management functionality.
  ============================================================================ }

unit Test.UniBase.Security;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  UniBase.Manager,
  UniBase.Security;

type
  [TestFixture]
  TTestUniBaseSecurity = class
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
  end;

implementation

{ TTestUniBaseSecurity }

procedure TTestUniBaseSecurity.Setup;
begin
  // Initialize UniBase with in-memory database for testing
  if not UniBase.Manager.UniBase.IsInitialized then
    FInitialized := UniBase.Manager.UniBase.InitializeWithDB(':memory:')
  else
    FInitialized := True;
end;

procedure TTestUniBaseSecurity.TearDown;
begin
  // Cleanup test secrets if initialized
  if FInitialized and Assigned(UniBase.Manager.UniBase.Security) then
  begin
    // Clean up test data
    UniBase.Manager.UniBase.Security.DeleteSecret('test_secret');
    UniBase.Manager.UniBase.Security.DeleteSecret('test_unicode');
    UniBase.Manager.UniBase.Security.DeleteSecret('test_special');
    UniBase.Manager.UniBase.Security.DeleteSecret('test_delete');
    UniBase.Manager.UniBase.Security.DeleteSecret('test_update');
    UniBase.Manager.UniBase.Security.DeleteSecret('test_global');
    UniBase.Manager.UniBase.Security.DeleteSecret('secret1');
    UniBase.Manager.UniBase.Security.DeleteSecret('secret2');
    UniBase.Manager.UniBase.Security.DeleteSecret('secret3');
  end;
end;

// ============================================================================
// DPAPI Tests
// ============================================================================

procedure TTestUniBaseSecurity.Test_ProtectUnprotect_SimpleString;
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

procedure TTestUniBaseSecurity.Test_ProtectUnprotect_EmptyString;
var
  Original: string;
  Encrypted: TBytes;
  Decrypted: string;
begin
  Original := '';
  
  Encrypted := ProtectStringDpapi(Original);
  Assert.AreEqual(0, Length(Encrypted), 'Empty string should produce empty bytes');
  
  Decrypted := UnprotectStringDpapi(Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

procedure TTestUniBaseSecurity.Test_ProtectUnprotect_UnicodeString;
var
  Original: string;
  Encrypted: TBytes;
  Decrypted: string;
begin
  Original := '你好世界！日本語テスト한국어테스트';
  
  Encrypted := ProtectStringDpapi(Original);
  Assert.IsTrue(Length(Encrypted) > 0, 'Encrypted data should not be empty');
  
  Decrypted := UnprotectStringDpapi(Encrypted);
  Assert.AreEqual(Original, Decrypted);
end;

procedure TTestUniBaseSecurity.Test_ProtectUnprotect_SpecialChars;
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

procedure TTestUniBaseSecurity.Test_ProtectUnprotect_LongString;
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

procedure TTestUniBaseSecurity.Test_SaveAndLoadSecret;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  UniBase.Manager.UniBase.Security.SaveSecret('test_secret', 'MySecretPassword123');
  Loaded := UniBase.Manager.UniBase.Security.LoadSecret('test_secret');
  
  Assert.AreEqual('MySecretPassword123', Loaded);
end;

procedure TTestUniBaseSecurity.Test_SecretExists_True;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  UniBase.Manager.UniBase.Security.SaveSecret('test_secret', 'value');
  Assert.IsTrue(UniBase.Manager.UniBase.Security.SecretExists('test_secret'));
end;

procedure TTestUniBaseSecurity.Test_SecretExists_False;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  Assert.IsFalse(UniBase.Manager.UniBase.Security.SecretExists('nonexistent_secret'));
end;

procedure TTestUniBaseSecurity.Test_DeleteSecret;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  UniBase.Manager.UniBase.Security.SaveSecret('test_delete', 'value');
  Assert.IsTrue(UniBase.Manager.UniBase.Security.SecretExists('test_delete'));
  
  UniBase.Manager.UniBase.Security.DeleteSecret('test_delete');
  Assert.IsFalse(UniBase.Manager.UniBase.Security.SecretExists('test_delete'));
end;

procedure TTestUniBaseSecurity.Test_LoadSecret_NotFound;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  Loaded := UniBase.Manager.UniBase.Security.LoadSecret('definitely_not_exists');
  Assert.AreEqual('', Loaded);
end;

procedure TTestUniBaseSecurity.Test_GetSecretNames;
var
  Names: TArray<string>;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  // Save some secrets
  UniBase.Manager.UniBase.Security.SaveSecret('secret1', 'value1');
  UniBase.Manager.UniBase.Security.SaveSecret('secret2', 'value2');
  UniBase.Manager.UniBase.Security.SaveSecret('secret3', 'value3');
  
  Names := UniBase.Manager.UniBase.Security.GetSecretNames;
  Assert.IsTrue(Length(Names) >= 3, 'Should have at least 3 secrets');
end;

procedure TTestUniBaseSecurity.Test_SaveSecret_UpdateExisting;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  // Save initial value
  UniBase.Manager.UniBase.Security.SaveSecret('test_update', 'initial_value');
  Loaded := UniBase.Manager.UniBase.Security.LoadSecret('test_update');
  Assert.AreEqual('initial_value', Loaded);
  
  // Update value
  UniBase.Manager.UniBase.Security.SaveSecret('test_update', 'updated_value');
  Loaded := UniBase.Manager.UniBase.Security.LoadSecret('test_update');
  Assert.AreEqual('updated_value', Loaded);
end;

// ============================================================================
// Global Function Tests
// ============================================================================

procedure TTestUniBaseSecurity.Test_GlobalLoadSaveSecret;
var
  Loaded: string;
begin
  Assert.IsTrue(FInitialized, 'UniBase should be initialized');
  
  // Use global functions
  UniBase.Security.SaveSecret('test_global', 'global_value');
  Loaded := UniBase.Security.LoadSecret('test_global');
  
  Assert.AreEqual('global_value', Loaded);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestUniBaseSecurity);

end.
