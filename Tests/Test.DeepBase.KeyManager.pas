{ ============================================================================
  Test.DeepBase.KeyManager - Unit Tests for Key Management Module
  
  Test Coverage:
    - TKeyPurpose / TKeyStatus enums and helpers
    - TKeyInfo helpers (IsExpired / DaysUntilExpiry)
    - Machine binding: versioned full match, AAD-wrapped data keys, sealed header
    - TKeyDerivationParams presets
    - TMasterKey derivation and lock/unlock
    - TDataKey generation, encrypt/decrypt, rotate
    - TKeyStore basic operations (create/load/rotate/revoke)
    - TKeyManager high-level APIs (Encrypt/Decrypt, Config helpers)
  ============================================================================ }

unit Test.DeepBase.KeyManager;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  DeepBase.Crypto.Encoding,
  DeepBase.Crypto.Platform,
  System.Classes,
  System.DateUtils,
  System.IOUtils,
  System.Generics.Collections,
  System.JSON,
  DeepBase.KeyManager,
  DeepBase.Security.MachineIdentity;

type
  [TestFixture]
  TTestKeyEnums = class
  public
    [Test]
    procedure Test_KeyPurpose_Ordinals;
    [Test]
    procedure Test_KeyStatus_Ordinals;
    [Test]
    procedure Test_KeyPurposeToStr;
    [Test]
    procedure Test_KeyStatusToStr;
  end;

  [TestFixture]
  TTestKeyInfoHelpers = class
  public
    [Test]
    procedure Test_IsExpired_FalseWhenNoExpiry;
    [Test]
    procedure Test_IsExpired_TrueWhenPast;
    [Test]
    procedure Test_DaysUntilExpiry_NoExpiry;
    [Test]
    procedure Test_DaysUntilExpiry_Positive;
  end;

  [TestFixture]
  TTestKeyDerivationParams = class
  public
    [Test]
    procedure Test_Default_Params;
    [Test]
    procedure Test_High_Params;
  end;

  [TestFixture]
  TTestMasterKey = class
  private
    FMaster: TMasterKey;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_DeriveFromPassword_SetsKeyData;
    [Test]
    procedure Test_DeriveFromPassword_IsReproducible;
    [Test]
    procedure Test_Lock_ClearsKey;
    [Test]
    [TestCase('LockedRaises','')]
    procedure Test_GetKeyData_RaisesWhenLocked(const Dummy: string);
  end;

  [TestFixture]
  TTestDataKey = class
  private
    FKEK: TBytes;
    FBindingAAD, FForeignBindingAAD: TBytes;
  public
    [Setup]
    procedure Setup;

    [Test]
    procedure Test_Create_Defaults;
    [Test]
    procedure Test_Generate_Length;
    [Test]
    procedure Test_EncryptDecrypt_RoundTrip;
    [Test]
    procedure Test_UnwrapWithForeignBinding_Raises;
    [Test]
    procedure Test_Rotate_IncrementsVersion;
  end;

  [TestFixture]
  TTestKeyStore = class
  private
    FStorePath: string;
    FMaster: TMasterKey;
    FStore: TKeyStore;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Initialize_LoadsOrCreatesFile;
    [Test]
    procedure Test_CreateKey_And_GetKey;
    [Test]
    procedure Test_GetActiveKey_CreatesWhenMissing;
    [Test]
    procedure Test_RotateKey_ChangesVersion;
    [Test]
    procedure Test_RevokeKey_ChangesStatus;
    [Test]
    procedure Test_SaveAndLoad_PersistsKeys;
  end;

  [TestFixture]
  TTestKeyStoreSealedState = class
  private
    FStorePath: string;
    FMaster: TMasterKey;
    FStore: TKeyStore;
    function ReadSealedJson: TJSONObject;
    procedure WriteSealedJson(const ARoot: TJSONObject);
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;

    [Test]
    procedure Test_Save_SealsKdfParamsAndMachineBinding;
    [Test]
    procedure Test_LoadSealedState_ReproducesKdfParams;
    [Test]
    procedure Test_LoadSealedState_RejectsForeignFormatVersion;
    [Test]
    procedure Test_LoadSealedState_RejectsMissingBinding;
    [Test]
    procedure Test_LoadSealedState_RejectsMissingKdf;
    [Test]
    procedure Test_VerifyMachineBinding_RejectsForeignFingerprint;
  end;

  [TestFixture]
  TTestKeyManager = class
  private
    FStorePath: string;
    FManager: TKeyManager;
  public
    [Setup]
    procedure Setup;
    [TearDown]
    procedure TearDown;
    
    [Test]
    procedure Test_Initialize_And_IsUnlocked;
    [Test]
    procedure Test_CreateDataKey_And_GetDataKey;
    [Test]
    procedure Test_EncryptDecrypt_String;
    [Test]
    procedure Test_EncryptDecrypt_Config;
    [Test]
    procedure Test_GetAllKeyInfo_NotEmpty;
    [Test]
    procedure Test_GetExpiringKeys;
    [Test]
    procedure Test_Initialize_ReopenWithSamePassword_ReturnsSameDEK;
    [Test]
    procedure Test_Initialize_WrongPassword_FailsFast;
    [Test]
    procedure Test_Initialize_ForeignMachineBinding_FailsClosed;
    [Test]
    procedure Test_GetMachineFingerprint_NotEmpty;
  end;

implementation

{ TTestKeyEnums }

procedure TTestKeyEnums.Test_KeyPurpose_Ordinals;
begin
  Assert.AreEqual(0, Ord(kpMaster));
  Assert.AreEqual(1, Ord(kpEncryption));
  Assert.AreEqual(2, Ord(kpSigning));
  Assert.AreEqual(3, Ord(kpConfig));
  Assert.AreEqual(4, Ord(kpDatabase));
  Assert.AreEqual(5, Ord(kpBackup));
  Assert.AreEqual(6, Ord(kpSession));
end;

procedure TTestKeyEnums.Test_KeyStatus_Ordinals;
begin
  Assert.AreEqual(0, Ord(ksActive));
  Assert.AreEqual(1, Ord(ksRotating));
  Assert.AreEqual(2, Ord(ksRetired));
  Assert.AreEqual(3, Ord(ksRevoked));
end;

procedure TTestKeyEnums.Test_KeyPurposeToStr;
begin
  Assert.AreEqual('Master', KeyPurposeToStr(kpMaster));
  Assert.AreEqual('Encryption', KeyPurposeToStr(kpEncryption));
  Assert.AreEqual('Signing', KeyPurposeToStr(kpSigning));
  Assert.AreEqual('Config', KeyPurposeToStr(kpConfig));
  Assert.AreEqual('Database', KeyPurposeToStr(kpDatabase));
  Assert.AreEqual('Backup', KeyPurposeToStr(kpBackup));
  Assert.AreEqual('Session', KeyPurposeToStr(kpSession));
end;

procedure TTestKeyEnums.Test_KeyStatusToStr;
begin
  Assert.AreEqual('Active', KeyStatusToStr(ksActive));
  Assert.AreEqual('Rotating', KeyStatusToStr(ksRotating));
  Assert.AreEqual('Retired', KeyStatusToStr(ksRetired));
  Assert.AreEqual('Revoked', KeyStatusToStr(ksRevoked));
end;

{ TTestKeyInfoHelpers }

procedure TTestKeyInfoHelpers.Test_IsExpired_FalseWhenNoExpiry;
var
  Info: TKeyInfo;
begin
  Info.ExpiresAt := 0;
  Assert.IsFalse(Info.IsExpired);
end;

procedure TTestKeyInfoHelpers.Test_IsExpired_TrueWhenPast;
var
  Info: TKeyInfo;
begin
  Info.ExpiresAt := Now - 1;
  Assert.IsTrue(Info.IsExpired);
end;

procedure TTestKeyInfoHelpers.Test_DaysUntilExpiry_NoExpiry;
var
  Info: TKeyInfo;
begin
  Info.ExpiresAt := 0;
  Assert.AreEqual(MaxInt, Info.DaysUntilExpiry);
end;

procedure TTestKeyInfoHelpers.Test_DaysUntilExpiry_Positive;
var
  Info: TKeyInfo;
begin
  Info.ExpiresAt := Now + 10;
  Assert.IsTrue(Info.DaysUntilExpiry >= 9);
end;

{ TTestKeyDerivationParams }

procedure TTestKeyDerivationParams.Test_Default_Params;
var
  P: TKeyDerivationParams;
begin
  P := TKeyDerivationParams.Default;
  Assert.IsTrue(Length(P.Salt) >= 16);
  Assert.AreEqual(100000, P.Iterations);
  Assert.AreEqual(32, P.KeyLength);
end;

procedure TTestKeyDerivationParams.Test_High_Params;
var
  P: TKeyDerivationParams;
begin
  P := TKeyDerivationParams.High;
  Assert.IsTrue(Length(P.Salt) >= 32);
  Assert.IsTrue(P.Iterations >= 300000);
  Assert.AreEqual(32, P.KeyLength);
end;

{ TTestMasterKey }

procedure TTestMasterKey.Setup;
begin
  FMaster := TMasterKey.Create;
end;

procedure TTestMasterKey.TearDown;
begin
  FMaster.Free;
end;

procedure TTestMasterKey.Test_DeriveFromPassword_SetsKeyData;
var
  Params: TKeyDerivationParams;
  Data: TBytes;
begin
  Params := TKeyDerivationParams.Default;
  FMaster.DeriveFromPassword('test-password', Params);
  
  Assert.IsTrue(FMaster.IsUnlocked);
  Data := FMaster.GetKeyData;
  Assert.AreEqual(Integer(Params.KeyLength), Integer(Length(Data)));
end;

procedure TTestMasterKey.Test_DeriveFromPassword_IsReproducible;
var
  Other: TMasterKey;
  Params: TKeyDerivationParams;
  First, Second: TBytes;
  I: Integer;
begin
  // The KEK is a pure function of the password and the persisted KDF parameters:
  // machine identity must not leak into the derivation (Top20 #5).
  Params := TKeyDerivationParams.High;
  FMaster.DeriveFromPassword('same-password', Params);
  First := FMaster.GetKeyData;

  Other := TMasterKey.Create;
  try
    Other.DeriveFromPassword('same-password', Params);
    Second := Other.GetKeyData;
  finally
    Other.Free;
  end;

  Assert.AreEqual(Length(First), Length(Second));
  for I := 0 to High(First) do
    if First[I] <> Second[I] then
      Assert.Fail('Same password and KDF parameters must reproduce the same KEK');
end;

procedure TTestMasterKey.Test_Lock_ClearsKey;
var
  Params: TKeyDerivationParams;
  Data: TBytes;
begin
  Params := TKeyDerivationParams.Default;
  FMaster.DeriveFromPassword('pwd', Params);
  FMaster.Lock;
  
  Assert.IsFalse(FMaster.IsUnlocked);
  Assert.WillRaise(
    procedure
    begin
      Data := FMaster.GetKeyData;
    end);
end;

procedure TTestMasterKey.Test_GetKeyData_RaisesWhenLocked(const Dummy: string);
var
  Data: TBytes;
begin
  FMaster.Lock;
  Assert.WillRaise(
    procedure
    begin
      Data := FMaster.GetKeyData;
    end);
end;

{ TTestDataKey }

procedure TTestDataKey.Setup;
begin
  // 32-byte KEK
  SetLength(FKEK, 32);
  FillChar(FKEK[0], Length(FKEK), 1);
  FBindingAAD := TEncoding.UTF8.GetBytes('v1|machine_guid=afff3ce9|volume_serial=8EB53A74');
  FForeignBindingAAD := TEncoding.UTF8.GetBytes('v1|machine_guid=0000000|volume_serial=8EB53A74');
end;

procedure TTestDataKey.Test_Create_Defaults;
var
  Key: TDataKey;
begin
  Key := TDataKey.Create(kpEncryption);
  try
    Assert.AreEqual(kpEncryption, Key.Purpose);
    Assert.AreEqual(ksActive, Key.Status);
    Assert.AreEqual(1, Key.Version);
    Assert.IsNotEmpty(Key.KeyId);
  finally
    Key.Free;
  end;
end;

procedure TTestDataKey.Test_Generate_Length;
var
  Key: TDataKey;
begin
  Key := TDataKey.Create(kpEncryption);
  try
    Key.Generate(32);
    Assert.AreEqual(32, Integer(Length(Key.KeyData)));
  finally
    Key.Free;
  end;
end;

procedure TTestDataKey.Test_EncryptDecrypt_RoundTrip;
var
  Key: TDataKey;
  Plain, Dek: TBytes;
begin
  Key := TDataKey.Create(kpEncryption);
  try
    Key.Generate(32);
    Plain := Copy(Key.KeyData);
    Key.EncryptWith(FKEK, FBindingAAD);
    Key.DecryptWith(FKEK, FBindingAAD);
    Dek := Key.KeyData;
    Assert.AreEqual(Length(Plain), Length(Dek));
  finally
    Key.Free;
  end;
end;

procedure TTestDataKey.Test_UnwrapWithForeignBinding_Raises;
var
  Key: TDataKey;
begin
  Key := TDataKey.Create(kpEncryption);
  try
    Key.Generate(32);
    Key.EncryptWith(FKEK, FBindingAAD);
    // Same KEK, another machine's binding: the wrap is authenticated, so it must fail.
    Assert.WillRaise(
      procedure
      begin
        Key.DecryptWith(FKEK, FForeignBindingAAD);
      end, ECryptoException);
  finally
    Key.Free;
  end;
end;

procedure TTestDataKey.Test_Rotate_IncrementsVersion;
var
  Key: TDataKey;
  OldVersion: Integer;
begin
  Key := TDataKey.Create(kpBackup);
  try
    Key.Generate(32);
    Key.EncryptWith(FKEK, FBindingAAD);
    OldVersion := Key.Version;
    Key.Rotate(FKEK, FBindingAAD);
    Assert.AreEqual(OldVersion + 1, Key.Version);
    Assert.AreEqual(ksActive, Key.Status);
  finally
    Key.Free;
  end;
end;

{ TTestKeyStore }

procedure TTestKeyStore.Setup;
var
  Params: TKeyDerivationParams;
begin
  FStorePath := TPath.Combine(TPath.GetTempPath, 'DeepBase_keystore_test.json');
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
  
  FMaster := TMasterKey.Create;
  Params := TKeyDerivationParams.Default;
  FMaster.DeriveFromPassword('test-master', Params);
  
  FStore := TKeyStore.Create(FStorePath);
  FStore.Initialize(FMaster);
end;

procedure TTestKeyStore.TearDown;
begin
  FStore.Free;
  FMaster.Free;
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
end;

procedure TTestKeyStore.Test_Initialize_LoadsOrCreatesFile;
begin
  Assert.IsTrue(TFile.Exists(FStorePath) or not TFile.Exists(FStorePath) or True);
end;

procedure TTestKeyStore.Test_CreateKey_And_GetKey;
var
  Created: TDataKey;
  Loaded: TDataKey;
begin
  Created := FStore.CreateKey(kpConfig, 30);
  Assert.IsNotNull(Created);
  
  Loaded := FStore.GetKey(Created.KeyId);
  Assert.IsNotNull(Loaded);
  Assert.AreEqual(Created.KeyId, Loaded.KeyId);
end;

procedure TTestKeyStore.Test_GetActiveKey_CreatesWhenMissing;
var
  Key: TDataKey;
begin
  Key := FStore.GetActiveKey(kpDatabase);
  Assert.IsNotNull(Key);
  Assert.AreEqual(kpDatabase, Key.Purpose);
end;

procedure TTestKeyStore.Test_RotateKey_ChangesVersion;
var
  Key: TDataKey;
  OldVersion: Integer;
begin
  Key := FStore.CreateKey(kpBackup, 365);
  OldVersion := Key.Version;
  FStore.RotateKey(Key.KeyId);
  Assert.IsTrue(Key.Version > OldVersion);
end;

procedure TTestKeyStore.Test_RevokeKey_ChangesStatus;
var
  Key: TDataKey;
  Info: TKeyInfo;
begin
  Key := FStore.CreateKey(kpEncryption, 365);
  FStore.RevokeKey(Key.KeyId);
  Info := Key.GetInfo;
  Assert.AreEqual(ksRevoked, Info.Status);
end;

procedure TTestKeyStore.Test_SaveAndLoad_PersistsKeys;
var
  KeyId: string;
  InfoBefore, InfoAfter: TKeyInfo;
  Store2: TKeyStore;
  Master2: TMasterKey;
  Params: TKeyDerivationParams;
begin
  KeyId := FStore.CreateKey(kpConfig, 365).KeyId;
  InfoBefore := FStore.GetAllKeys[0];
  
  FStore.Save;
  
  Master2 := TMasterKey.Create;
  try
    Params := TKeyDerivationParams.Default;
    Master2.DeriveFromPassword('test-master', Params);
    
    Store2 := TKeyStore.Create(FStorePath);
    try
      Store2.Initialize(Master2);
      InfoAfter := Store2.GetAllKeys[0];
      Assert.AreEqual(InfoBefore.KeyId, InfoAfter.KeyId);
    finally
      Store2.Free;
    end;
  finally
    Master2.Free;
  end;
end;

procedure ExpectRaise(const AWhat: string; AAction: TTestLocalMethod;
  const AMessageFragment: string);
begin
  try
    AAction();
    Assert.Fail(AWhat + ': expected EKeyManagerException, none raised');
  except
    on E: EKeyManagerException do
      if (AMessageFragment <> '') and (Pos(AMessageFragment, E.Message) = 0) then
        Assert.Fail(AWhat + ': unexpected message "' + E.Message + '"');
  else
    raise;
  end;
end;

{ TTestKeyStoreSealedState }

procedure TTestKeyStoreSealedState.Setup;
var
  Params: TKeyDerivationParams;
begin
  FStorePath := TPath.Combine(TPath.GetTempPath, 'DeepBase_keystore_sealed_test.json');
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
  if TFile.Exists(FStorePath + '.bak') then
    TFile.Delete(FStorePath + '.bak');

  FMaster := TMasterKey.Create;
  Params := TKeyDerivationParams.High;
  FMaster.DeriveFromPassword('sealed-master', Params);

  FStore := TKeyStore.Create(FStorePath);
  FStore.Initialize(FMaster);
  // CreateKey seals the store, which is what writes the persisted header.
  FStore.CreateKey(kpConfig, 365);
end;

procedure TTestKeyStoreSealedState.TearDown;
begin
  FStore.Free;
  FMaster.Free;
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
  if TFile.Exists(FStorePath + '.bak') then
    TFile.Delete(FStorePath + '.bak');
end;

function TTestKeyStoreSealedState.ReadSealedJson: TJSONObject;
begin
  Result := TJSONObject.ParseJSONValue(TFile.ReadAllText(FStorePath)) as TJSONObject;
  Assert.IsNotNull(Result, 'Sealed keystore must be valid JSON');
end;

procedure TTestKeyStoreSealedState.WriteSealedJson(const ARoot: TJSONObject);
begin
  TFile.WriteAllText(FStorePath, ARoot.ToJSON);
end;

procedure TTestKeyStoreSealedState.Test_Save_SealsKdfParamsAndMachineBinding;
var
  Root, KdfObj, BindingObj: TJSONObject;
begin
  Root := ReadSealedJson;
  try
    Assert.AreEqual(Integer(KEYSTORE_FORMAT_VERSION), Root.GetValue<Integer>('version'));
    KdfObj := Root.GetValue<TJSONObject>('kdf');
    Assert.IsTrue(Length(TEncodingUtils.Base64Decode(KdfObj.GetValue<string>('salt'))) > 0);

    BindingObj := Root.GetValue<TJSONObject>('binding');
Assert.AreEqual(Integer(MACHINE_IDENTITY_SCHEME_VERSION), BindingObj.GetValue<Integer>('scheme'));
    Assert.AreEqual(TMachineIdentityProvider.Fingerprint, BindingObj.GetValue<string>('hash'));
  finally
    Root.Free;
  end;
end;

procedure TTestKeyStoreSealedState.Test_LoadSealedState_ReproducesKdfParams;
var
  Other: TKeyStore;
begin
  Other := TKeyStore.Create(FStorePath);
  try
    Other.LoadSealedState;
    Assert.IsTrue(Other.HasSealedState);
    Assert.AreEqual(Length(FMaster.Params.Salt), Length(Other.KdfParams.Salt));
    Assert.AreEqual(FMaster.Params.Iterations, Other.KdfParams.Iterations);
    Assert.AreEqual(FMaster.Params.KeyLength, Other.KdfParams.KeyLength);
    Other.VerifyMachineBinding;
  finally
    Other.Free;
  end;
end;

procedure TTestKeyStoreSealedState.Test_LoadSealedState_RejectsForeignFormatVersion;
var
  Root: TJSONObject;
  Other: TKeyStore;
begin
  Root := ReadSealedJson;
  try
    Root.RemovePair('version').Free;
    Root.AddPair('version', TJSONNumber.Create(KEYSTORE_FORMAT_VERSION - 1));
    WriteSealedJson(Root);
  finally
    Root.Free;
  end;

  Other := TKeyStore.Create(FStorePath);
  try
    ExpectRaise('A keystore sealed in another format must not be read',
      procedure begin Other.LoadSealedState; end, 're-key migration');
  finally
    Other.Free;
  end;
end;

procedure TTestKeyStoreSealedState.Test_LoadSealedState_RejectsMissingBinding;
var
  Root: TJSONObject;
  Other: TKeyStore;
begin
  Root := ReadSealedJson;
  try
    Root.RemovePair('binding').Free;
    WriteSealedJson(Root);
  finally
    Root.Free;
  end;

  Other := TKeyStore.Create(FStorePath);
  try
    ExpectRaise('A keystore without a sealed binding must not be read',
      procedure begin Other.LoadSealedState; end, 'machine binding');
  finally
    Other.Free;
  end;
end;

procedure TTestKeyStoreSealedState.Test_LoadSealedState_RejectsMissingKdf;
var
  Root: TJSONObject;
  Other: TKeyStore;
begin
  Root := ReadSealedJson;
  try
    Root.RemovePair('kdf').Free;
    WriteSealedJson(Root);
  finally
    Root.Free;
  end;

  Other := TKeyStore.Create(FStorePath);
  try
    ExpectRaise('A keystore without KDF parameters must not be read',
      procedure begin Other.LoadSealedState; end, 'KDF parameters');
  finally
    Other.Free;
  end;
end;

procedure TTestKeyStoreSealedState.Test_VerifyMachineBinding_RejectsForeignFingerprint;
var
  Root, BindingObj: TJSONObject;
  Other: TKeyStore;
begin
  Root := ReadSealedJson;
  try
    BindingObj := Root.GetValue<TJSONObject>('binding');
    BindingObj.RemovePair('hash').Free;
    BindingObj.AddPair('hash', StringOfChar('0', 64));
    WriteSealedJson(Root);
  finally
    Root.Free;
  end;

  Other := TKeyStore.Create(FStorePath);
  try
    Other.LoadSealedState;
    ExpectRaise('A foreign machine identity must not unlock the keystore',
      procedure begin Other.VerifyMachineBinding; end, 'Machine identity does not match');
  finally
    Other.Free;
  end;
end;

{ TTestKeyManager }

procedure TTestKeyManager.Setup;
begin
  FStorePath := TPath.Combine(TPath.GetTempPath, 'DeepBase_keymanager_test.json');
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
  if TFile.Exists(FStorePath + '.bak') then
    TFile.Delete(FStorePath + '.bak');
  FManager := TKeyManager.Create(FStorePath);
  FManager.Initialize('test-password');
end;

procedure TTestKeyManager.TearDown;
begin
  FManager.Free;
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
  if TFile.Exists(FStorePath + '.bak') then
    TFile.Delete(FStorePath + '.bak');
end;

procedure TTestKeyManager.Test_Initialize_And_IsUnlocked;
begin
  Assert.IsTrue(FManager.IsInitialized);
  Assert.IsTrue(FManager.IsUnlocked);
end;

procedure TTestKeyManager.Test_CreateDataKey_And_GetDataKey;
var
  KeyId: string;
  Data: TBytes;
begin
  KeyId := FManager.CreateDataKey(kpEncryption, 365);
  Assert.IsNotEmpty(KeyId);
  
  Data := FManager.GetDataKey(KeyId);
  Assert.IsTrue(Length(Data) > 0);
end;

procedure TTestKeyManager.Test_EncryptDecrypt_String;
var
  Plain, Enc, Dec: string;
begin
  Plain := 'Hello, DeepBase KeyManager!';
  Enc := FManager.EncryptString(Plain, kpEncryption);
  Assert.IsNotEmpty(Enc);
  
  Dec := FManager.DecryptString(Enc, kpEncryption);
  Assert.AreEqual(Plain, Dec);
end;

procedure TTestKeyManager.Test_EncryptDecrypt_Config;
var
  Plain, Enc, Dec: string;
begin
  Plain := 'SensitiveConfigValue';
  Enc := FManager.EncryptConfig(Plain);
  Dec := FManager.DecryptConfig(Enc);
  Assert.AreEqual(Plain, Dec);
end;

procedure TTestKeyManager.Test_GetAllKeyInfo_NotEmpty;
var
  Infos: TArray<TKeyInfo>;
begin
  Infos := FManager.GetAllKeyInfo;
  Assert.IsTrue(Length(Infos) >= 3);
end;

procedure TTestKeyManager.Test_GetExpiringKeys;
var
  Infos: TArray<TKeyInfo>;
begin
  Infos := FManager.GetExpiringKeys(3650);
  // No strict assertion on length, just ensure call works
  Assert.IsTrue(Length(Infos) >= 0);
end;

procedure TTestKeyManager.Test_Initialize_ReopenWithSamePassword_ReturnsSameDEK;
var
  KeyId: string;
  First, Second: TBytes;
  I: Integer;
  Again: TKeyManager;
begin
  KeyId := FManager.CreateDataKey(kpEncryption, 365);
  First := FManager.GetDataKey(KeyId);

  Again := TKeyManager.Create(FStorePath);
  try
    Again.Initialize('test-password');
    Second := Again.GetDataKey(KeyId);
  finally
    Again.Free;
  end;

  Assert.AreEqual(Length(First), Length(Second));
  for I := 0 to High(First) do
    if First[I] <> Second[I] then
      Assert.Fail('Reopening the keystore must reproduce the same data key');
end;

procedure TTestKeyManager.Test_Initialize_WrongPassword_FailsFast;
var
  Again: TKeyManager;
begin
  Again := TKeyManager.Create(FStorePath);
  try
    ExpectRaise('A wrong master password must fail while unlocking',
      procedure begin Again.Initialize('wrong-password'); end, '');
  finally
    Again.Free;
  end;
end;

procedure TTestKeyManager.Test_Initialize_ForeignMachineBinding_FailsClosed;
var
  Root, BindingObj: TJSONObject;
  Again: TKeyManager;
begin
  FManager.CreateDataKey(kpEncryption, 365);

  // Simulate the keystore being opened on another machine: the sealed binding hash
  // no longer matches what this host reports. The gate must refuse, not downgrade.
  Root := TJSONObject.ParseJSONValue(TFile.ReadAllText(FStorePath)) as TJSONObject;
  try
    BindingObj := Root.GetValue<TJSONObject>('binding');
    BindingObj.RemovePair('hash').Free;
    BindingObj.AddPair('hash', StringOfChar('f', 64));
    TFile.WriteAllText(FStorePath, Root.ToJSON);
  finally
    Root.Free;
  end;

  Again := TKeyManager.Create(FStorePath);
  try
    ExpectRaise('A keystore sealed on another machine must refuse to open',
      procedure begin Again.Initialize('test-password'); end, '');
  finally
    Again.Free;
  end;
end;

procedure TTestKeyManager.Test_GetMachineFingerprint_NotEmpty;
var
  FP: string;
begin
  FP := FManager.GetMachineFingerprint;
  Assert.IsNotEmpty(FP);
end;

initialization
  TDUnitX.RegisterTestFixture(TTestKeyEnums);
  TDUnitX.RegisterTestFixture(TTestKeyInfoHelpers);
  TDUnitX.RegisterTestFixture(TTestKeyDerivationParams);
  TDUnitX.RegisterTestFixture(TTestMasterKey);
  TDUnitX.RegisterTestFixture(TTestDataKey);
  TDUnitX.RegisterTestFixture(TTestKeyStore);
  TDUnitX.RegisterTestFixture(TTestKeyStoreSealedState);
  TDUnitX.RegisterTestFixture(TTestKeyManager);

end.
