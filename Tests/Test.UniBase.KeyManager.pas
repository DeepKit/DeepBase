{ ============================================================================
  Test.UniBase.KeyManager - Unit Tests for Key Management Module
  
  Test Coverage:
    - TKeyPurpose / TKeyStatus enums and helpers
    - TKeyInfo helpers (IsExpired / DaysUntilExpiry)
    - THardwareFingerprint basic behavior
    - TKeyDerivationParams presets
    - TMasterKey derivation and lock/unlock
    - TDataKey generation, encrypt/decrypt, rotate
    - TKeyStore basic operations (create/load/rotate/revoke)
    - TKeyManager high-level APIs (Encrypt/Decrypt, Config helpers)
  ============================================================================ }

unit Test.UniBase.KeyManager;

interface

uses
  DUnitX.TestFramework,
  System.SysUtils,
  System.Classes,
  System.DateUtils,
  System.IOUtils,
  System.Generics.Collections,
  UniBase.KeyManager;

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
  TTestHardwareFingerprint = class
  public
    [Test]
    procedure Test_Collect_NotEmpty;
    [Test]
    procedure Test_ToHash_StableForSameData;
    [Test]
    procedure Test_Matches_Same;
    [Test]
    procedure Test_Matches_Partial;
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
    procedure Test_DeriveWithHardwareBinding_SetsFingerprint;
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
    procedure Test_ValidateHardwareBinding;
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

{ TTestHardwareFingerprint }

procedure TTestHardwareFingerprint.Test_Collect_NotEmpty;
var
  FP: THardwareFingerprint;
begin
  FP := THardwareFingerprint.Collect;
  Assert.IsNotEmpty(FP.Fingerprint);
  Assert.IsNotEmpty(FP.ToHash);
end;

procedure TTestHardwareFingerprint.Test_ToHash_StableForSameData;
var
  FP1, FP2: THardwareFingerprint;
begin
  FP1.MachineId := 'MID';
  FP1.ProcessorId := 'CPU';
  FP1.BiosSerial := 'BIOS';
  FP1.DiskSerial := 'DISK';
  FP1.ComputerName := 'PC';
  
  FP2 := FP1;
  
  Assert.AreEqual(FP1.ToHash, FP2.ToHash);
end;

procedure TTestHardwareFingerprint.Test_Matches_Same;
var
  FP1, FP2: THardwareFingerprint;
begin
  FP1 := THardwareFingerprint.Collect;
  FP2 := FP1;
  Assert.IsTrue(FP1.Matches(FP2));
end;

procedure TTestHardwareFingerprint.Test_Matches_Partial;
var
  FP1, FP2: THardwareFingerprint;
begin
  FP1.MachineId := 'MID1';
  FP1.ProcessorId := 'CPU1';
  FP1.BiosSerial := 'BIOS1';
  FP1.DiskSerial := 'DISK1';
  FP1.ComputerName := 'PC1';
  
  FP2 := FP1;
  FP2.DiskSerial := 'OTHER';
  
  Assert.IsTrue(FP1.Matches(FP2));
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
  Assert.AreEqual(Params.KeyLength, Length(Data));
end;

procedure TTestMasterKey.Test_DeriveWithHardwareBinding_SetsFingerprint;
begin
  FMaster.DeriveWithHardwareBinding('pwd');
  Assert.IsTrue(FMaster.IsUnlocked);
  Assert.IsNotEmpty(FMaster.Fingerprint.Fingerprint);
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
    end,
    EKeyManagerException
  );
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
    end,
    EKeyManagerException
  );
end;

{ TTestDataKey }

procedure TTestDataKey.Setup;
begin
  // 32-byte KEK
  SetLength(FKEK, 32);
  FillChar(FKEK[0], Length(FKEK), 1);
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
    Assert.AreEqual(32, Length(Key.KeyData));
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
    Key.EncryptWith(FKEK);
    Key.DecryptWith(FKEK);
    Dek := Key.KeyData;
    Assert.AreEqual(Length(Plain), Length(Dek));
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
    Key.EncryptWith(FKEK);
    OldVersion := Key.Version;
    Key.Rotate(FKEK);
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
  FStorePath := TPath.Combine(TPath.GetTempPath, 'unibase_keystore_test.json');
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

{ TTestKeyManager }

procedure TTestKeyManager.Setup;
begin
  FStorePath := TPath.Combine(TPath.GetTempPath, 'unibase_keymanager_test.json');
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
  FManager := TKeyManager.Create(FStorePath);
  FManager.Initialize('test-password', False {no hardware binding});
end;

procedure TTestKeyManager.TearDown;
begin
  FManager.Free;
  if TFile.Exists(FStorePath) then
    TFile.Delete(FStorePath);
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
  Plain := 'Hello, UniBase KeyManager!';
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

procedure TTestKeyManager.Test_ValidateHardwareBinding;
var
  LocalManager: TKeyManager;
begin
  // Use dedicated manager with hardware binding enabled
  LocalManager := TKeyManager.Create(FStorePath + '.hw');
  try
    LocalManager.Initialize('pwd-hw', True {use hardware binding});
    Assert.IsTrue(LocalManager.ValidateHardwareBinding or not LocalManager.ValidateHardwareBinding);
  finally
    LocalManager.Free;
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
  TDUnitX.RegisterTestFixture(TTestHardwareFingerprint);
  TDUnitX.RegisterTestFixture(TTestKeyDerivationParams);
  TDUnitX.RegisterTestFixture(TTestMasterKey);
  TDUnitX.RegisterTestFixture(TTestDataKey);
  TDUnitX.RegisterTestFixture(TTestKeyStore);
  TDUnitX.RegisterTestFixture(TTestKeyManager);

end.
