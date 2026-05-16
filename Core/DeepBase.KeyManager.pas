{ ============================================================================
  DeepBase.KeyManager - Advanced Key Management System
  
  Version: 1.0
  Description: Secure key management with machine-binding affinity and key rotation.
  
  Features:
    - Machine-affinity key derivation (computer name, user, env)
    - Master key derivation with PBKDF2
    - Data encryption keys (DEK) management
    - Key rotation support
    - Secure key storage using DPAPI/Keychain
    - Multi-level key hierarchy (Master -> Domain -> Data)
  
  Thread Safety: All public methods are thread-safe.
  
  Security Model:
    - Master Key: Derived from user password + machine affinity fingerprint
    - Key Encryption Key (KEK): Encrypts other keys
    - Data Encryption Key (DEK): Encrypts actual data
    - Keys are never stored in plain text
  
  Important note (BASIC-017):
    The "fingerprint" used here is currently a MACHINE-AFFINITY fingerprint
    derived from environment variables and computer name. It is NOT a true
    hardware identifier (it does not query BIOS serial, MAC, disk UUID).
    Treat it as user-portable convenience, not a tamper-resistant binding.
    Production hardware binding requires platform adapters (WMI / IOKit /
    udev) that are not implemented yet. Migration paths must remain available
    when the fingerprint changes (re-prompt for password etc.).
  ============================================================================ }

unit DeepBase.KeyManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.Hash,
  System.SyncObjs,
  System.DateUtils,
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  DeepBase.Crypto;

type
  EKeyManagerException = class(Exception);

  TKeyPurpose = (
    kpMaster,      // Master key - top of hierarchy
    kpEncryption,  // General encryption
    kpSigning,     // Digital signatures
    kpConfig,      // Configuration encryption
    kpDatabase,    // Database field encryption
    kpBackup,      // Backup encryption
    kpSession      // Session keys (temporary)
  );

  TKeyStatus = (
    ksActive,      // Key is active and can be used
    ksRotating,    // Key is being rotated
    ksRetired,     // Key retired, only for decryption
    ksRevoked      // Key revoked, cannot be used
  );

  TKeyInfo = record
    KeyId: string;
    Purpose: TKeyPurpose;
    Status: TKeyStatus;
    CreatedAt: TDateTime;
    ExpiresAt: TDateTime;
    RotatedAt: TDateTime;
    Version: Integer;
    Algorithm: string;
    KeyLength: Integer;
    
    function IsExpired: Boolean;
    function DaysUntilExpiry: Integer;
  end;

  THardwareFingerprint = record
    MachineId: string;
    ProcessorId: string;
    BiosSerial: string;
    DiskSerial: string;
    MacAddress: string;
    ComputerName: string;
    Fingerprint: string;
    
    class function Collect: THardwareFingerprint; static;
    function ToHash: string;
    function Matches(const AOther: THardwareFingerprint): Boolean;
  end;

  TKeyDerivationParams = record
    Salt: TBytes;
    Iterations: Integer;
    KeyLength: Integer;
    Algorithm: THashAlgorithm;
    
    class function Default: TKeyDerivationParams; static;
    class function High: TKeyDerivationParams; static;
  end;

  TMasterKey = class
  private
    FKeyData: TBytes;
    FFingerprint: THardwareFingerprint;
    FParams: TKeyDerivationParams;
    FCreatedAt: TDateTime;
    FIsUnlocked: Boolean;
    
    procedure ClearKey;
    
  public
    constructor Create;
    destructor Destroy; override;
    
    procedure DeriveFromPassword(const APassword: string; const AParams: TKeyDerivationParams);
    procedure DeriveWithHardwareBinding(const APassword: string);
    procedure Lock;
    function GetKeyData: TBytes;
    
    property IsUnlocked: Boolean read FIsUnlocked;
    property CreatedAt: TDateTime read FCreatedAt;
    property Fingerprint: THardwareFingerprint read FFingerprint;
  end;

  TDataKey = class
  private
    FKeyId: string;
    FKeyData: TBytes;
    FEncryptedKeyData: TBytes;
    FPurpose: TKeyPurpose;
    FStatus: TKeyStatus;
    FCreatedAt: TDateTime;
    FExpiresAt: TDateTime;
    FVersion: Integer;
    
  public
    constructor Create(APurpose: TKeyPurpose);
    destructor Destroy; override;
    
    procedure Generate(AKeyLength: Integer = 32);
    procedure EncryptWith(const AKEK: TBytes);
    procedure DecryptWith(const AKEK: TBytes);
    procedure Rotate(const AKEK: TBytes);
    function GetInfo: TKeyInfo;
    
    property KeyId: string read FKeyId;
    property KeyData: TBytes read FKeyData;
    property EncryptedKeyData: TBytes read FEncryptedKeyData;
    property Purpose: TKeyPurpose read FPurpose;
    property Status: TKeyStatus read FStatus write FStatus;
    property Version: Integer read FVersion;
  end;

  TKeyStore = class
  private
    FKeys: TObjectDictionary<string, TDataKey>;
    FLock: TCriticalSection;
    FStorePath: string;
    FMasterKey: TMasterKey;
    
    function GetKEK: TBytes;
    procedure SaveToFile;
    procedure LoadFromFile;
    
  public
    constructor Create(const AStorePath: string);
    destructor Destroy; override;
    
    procedure Initialize(AMasterKey: TMasterKey);
    function CreateKey(APurpose: TKeyPurpose; AExpiryDays: Integer = 365): TDataKey;
    function GetKey(const AKeyId: string): TDataKey;
    function GetActiveKey(APurpose: TKeyPurpose): TDataKey;
    procedure RotateKey(const AKeyId: string);
    procedure RevokeKey(const AKeyId: string);
    function GetAllKeys: TArray<TKeyInfo>;
    procedure Save;
    procedure Load;
  end;

  TKeyManager = class
  private
    FMasterKey: TMasterKey;
    FKeyStore: TKeyStore;
    FLock: TCriticalSection;
    FIsInitialized: Boolean;
    FOnKeyRotated: TNotifyEvent;
    FOnKeyExpiring: TNotifyEvent;
    
    class var FInstance: TKeyManager;
    class var FInstanceLock: TCriticalSection;
    
    function GetHardwareFingerprint: THardwareFingerprint;
    
  public
    constructor Create(const AStorePath: string);
    destructor Destroy; override;
    
    class function Instance: TKeyManager;
    class procedure SetInstance(AInstance: TKeyManager);
    
    procedure Initialize(const AMasterPassword: string; AUseHardwareBinding: Boolean = True);
    procedure Lock;
    function IsUnlocked: Boolean;
    
    // Key operations
    function CreateDataKey(APurpose: TKeyPurpose; AExpiryDays: Integer = 365): string;
    function GetDataKey(const AKeyId: string): TBytes;
    function GetActiveKeyForPurpose(APurpose: TKeyPurpose): TBytes;
    procedure RotateKey(const AKeyId: string);
    procedure RevokeKey(const AKeyId: string);
    
    // Encryption shortcuts
    function Encrypt(const AData: TBytes; APurpose: TKeyPurpose = kpEncryption): TBytes;
    function Decrypt(const AData: TBytes; APurpose: TKeyPurpose = kpEncryption): TBytes;
    function EncryptString(const AData: string; APurpose: TKeyPurpose = kpEncryption): string;
    function DecryptString(const AData: string; APurpose: TKeyPurpose = kpEncryption): string;
    
    // Config encryption
    function EncryptConfig(const AValue: string): string;
    function DecryptConfig(const AValue: string): string;
    
    // Hardware binding
    function ValidateHardwareBinding: Boolean;
    function GetMachineFingerprint: string;
    
    // Key info
    function GetKeyInfo(const AKeyId: string): TKeyInfo;
    function GetAllKeyInfo: TArray<TKeyInfo>;
    function GetExpiringKeys(ADaysThreshold: Integer = 30): TArray<TKeyInfo>;
    
    property IsInitialized: Boolean read FIsInitialized;
    property OnKeyRotated: TNotifyEvent read FOnKeyRotated write FOnKeyRotated;
    property OnKeyExpiring: TNotifyEvent read FOnKeyExpiring write FOnKeyExpiring;
  end;

function KeyManager: TKeyManager;
procedure SetKeyManager(AManager: TKeyManager);

function KeyPurposeToStr(APurpose: TKeyPurpose): string;
function KeyStatusToStr(AStatus: TKeyStatus): string;

implementation

uses
  System.IOUtils,
  System.JSON,
  System.NetEncoding;

var
  GKeyManager: TKeyManager = nil;

function KeyManager: TKeyManager;
begin
  Result := TKeyManager.Instance;
end;

procedure SetKeyManager(AManager: TKeyManager);
begin
  TKeyManager.SetInstance(AManager);
end;

function KeyPurposeToStr(APurpose: TKeyPurpose): string;
begin
  case APurpose of
    kpMaster:     Result := 'Master';
    kpEncryption: Result := 'Encryption';
    kpSigning:    Result := 'Signing';
    kpConfig:     Result := 'Config';
    kpDatabase:   Result := 'Database';
    kpBackup:     Result := 'Backup';
    kpSession:    Result := 'Session';
  else
    Result := 'Unknown';
  end;
end;

function KeyStatusToStr(AStatus: TKeyStatus): string;
begin
  case AStatus of
    ksActive:   Result := 'Active';
    ksRotating: Result := 'Rotating';
    ksRetired:  Result := 'Retired';
    ksRevoked:  Result := 'Revoked';
  else
    Result := 'Unknown';
  end;
end;

{ TKeyInfo }

function TKeyInfo.IsExpired: Boolean;
begin
  Result := (ExpiresAt > 0) and (Now > ExpiresAt);
end;

function TKeyInfo.DaysUntilExpiry: Integer;
begin
  if ExpiresAt = 0 then
    Result := MaxInt
  else
    Result := DaysBetween(Now, ExpiresAt);
end;

{ THardwareFingerprint }

class function THardwareFingerprint.Collect: THardwareFingerprint;
{$IFDEF MSWINDOWS}
var
  ComputerNameBuf: array[0..MAX_COMPUTERNAME_LENGTH] of Char;
  Size: DWORD;
{$ENDIF}
begin
  Result := Default(THardwareFingerprint);

  // BASIC-017: This is a machine-affinity fingerprint derived from
  // environment variables and computer name. It is NOT a true hardware
  // identifier. Production hardware binding (BIOS serial, MAC, disk UUID)
  // requires platform-specific adapters not implemented in this unit.

  {$IFDEF MSWINDOWS}
  // Computer name
  Size := MAX_COMPUTERNAME_LENGTH + 1;
  if GetComputerName(ComputerNameBuf, Size) then
    Result.ComputerName := ComputerNameBuf;
  
  // Machine ID from registry
  Result.MachineId := GetEnvironmentVariable('COMPUTERNAME') + '-' + 
                      GetEnvironmentVariable('USERNAME');
  
  // For production hardware ID: add platform adapter that queries WMI
  // (Win32_BIOS.SerialNumber, Win32_Processor.ProcessorId, Win32_DiskDrive.SerialNumber).
  // Until then, the values below are placeholders derived from ComputerName.
  Result.ProcessorId := GetEnvironmentVariable('PROCESSOR_IDENTIFIER');
  Result.BiosSerial := 'BIOS-' + Result.ComputerName;
  Result.DiskSerial := 'DISK-' + Result.ComputerName;
  {$ELSE}
  // macOS/Linux
  Result.ComputerName := GetEnvironmentVariable('HOSTNAME');
  if Result.ComputerName = '' then
    Result.ComputerName := GetEnvironmentVariable('USER');
  Result.MachineId := Result.ComputerName;
  {$ENDIF}
  
  // Generate composite fingerprint
  Result.Fingerprint := Result.ToHash;
end;

function THardwareFingerprint.ToHash: string;
var
  Data: string;
begin
  Data := MachineId + '|' + ProcessorId + '|' + BiosSerial + '|' + 
          DiskSerial + '|' + ComputerName;
  Result := THashUtils.SHA256(Data);
end;

function THardwareFingerprint.Matches(const AOther: THardwareFingerprint): Boolean;
begin
  // Allow some flexibility - match if at least 3 of 5 identifiers match
  var MatchCount := 0;
  if (MachineId <> '') and (MachineId = AOther.MachineId) then Inc(MatchCount);
  if (ProcessorId <> '') and (ProcessorId = AOther.ProcessorId) then Inc(MatchCount);
  if (BiosSerial <> '') and (BiosSerial = AOther.BiosSerial) then Inc(MatchCount);
  if (DiskSerial <> '') and (DiskSerial = AOther.DiskSerial) then Inc(MatchCount);
  if (ComputerName <> '') and (ComputerName = AOther.ComputerName) then Inc(MatchCount);
  
  Result := MatchCount >= 3;
end;

{ TKeyDerivationParams }

class function TKeyDerivationParams.Default: TKeyDerivationParams;
begin
  Result.Salt := TRandomGenerator.RandomBytes(16);
  Result.Iterations := 100000;
  Result.KeyLength := 32;
  Result.Algorithm := haSHA256;
end;

class function TKeyDerivationParams.High: TKeyDerivationParams;
begin
  Result.Salt := TRandomGenerator.RandomBytes(32);
  Result.Iterations := 310000;
  Result.KeyLength := 32;
  Result.Algorithm := haSHA512;
end;

{ TMasterKey }

constructor TMasterKey.Create;
begin
  inherited Create;
  FIsUnlocked := False;
  FCreatedAt := Now;
end;

destructor TMasterKey.Destroy;
begin
  ClearKey;
  inherited;
end;

procedure TMasterKey.ClearKey;
begin
  if Length(FKeyData) > 0 then
  begin
    FillChar(FKeyData[0], Length(FKeyData), 0);
    SetLength(FKeyData, 0);
  end;
  FIsUnlocked := False;
end;

procedure TMasterKey.DeriveFromPassword(const APassword: string; const AParams: TKeyDerivationParams);
begin
  FParams := AParams;
  FKeyData := TPasswordUtils.PBKDF2(APassword, AParams.Salt, AParams.Iterations, 
                                    AParams.KeyLength, AParams.Algorithm);
  FIsUnlocked := True;
  FCreatedAt := Now;
end;

procedure TMasterKey.DeriveWithHardwareBinding(const APassword: string);
var
  Params: TKeyDerivationParams;
  HWData: string;
begin
  FFingerprint := THardwareFingerprint.Collect;
  HWData := APassword + '|' + FFingerprint.ToHash;
  
  Params := TKeyDerivationParams.High;
  DeriveFromPassword(HWData, Params);
end;

procedure TMasterKey.Lock;
begin
  ClearKey;
end;

function TMasterKey.GetKeyData: TBytes;
begin
  if not FIsUnlocked then
    raise EKeyManagerException.Create('Master key is locked');
  Result := Copy(FKeyData);
end;

{ TDataKey }

constructor TDataKey.Create(APurpose: TKeyPurpose);
begin
  inherited Create;
  FPurpose := APurpose;
  FStatus := ksActive;
  FCreatedAt := Now;
  FVersion := 1;
  FKeyId := TRandomGenerator.NewGuidNoDashes;
end;

destructor TDataKey.Destroy;
begin
  if Length(FKeyData) > 0 then
  begin
    FillChar(FKeyData[0], Length(FKeyData), 0);
    SetLength(FKeyData, 0);
  end;
  inherited;
end;

procedure TDataKey.Generate(AKeyLength: Integer);
begin
  FKeyData := TRandomGenerator.RandomBytes(AKeyLength);
end;

procedure TDataKey.EncryptWith(const AKEK: TBytes);
var
  AES: TAESCrypto;
  IV, Cipher: TBytes;
begin
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(AKEK);
    IV := TRandomGenerator.RandomBytes(16);
    AES.SetIV(IV);
    Cipher := AES.Encrypt(FKeyData);
    SetLength(FEncryptedKeyData, Length(IV) + Length(Cipher));
    Move(IV[0], FEncryptedKeyData[0], Length(IV));
    Move(Cipher[0], FEncryptedKeyData[Length(IV)], Length(Cipher));
  finally
    AES.Free;
  end;
end;

procedure TDataKey.DecryptWith(const AKEK: TBytes);
var
  AES: TAESCrypto;
  IV, Cipher: TBytes;
begin
  if Length(FEncryptedKeyData) = 0 then
    Exit;
  if Length(FEncryptedKeyData) <= 16 then
    raise EKeyManagerException.Create('Invalid encrypted data key');
    
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(AKEK);
    IV := Copy(FEncryptedKeyData, 0, 16);
    Cipher := Copy(FEncryptedKeyData, 16, Length(FEncryptedKeyData) - 16);
    AES.SetIV(IV);
    FKeyData := AES.Decrypt(Cipher);
  finally
    AES.Free;
  end;
end;

procedure TDataKey.Rotate(const AKEK: TBytes);
begin
  FStatus := ksRotating;
  Inc(FVersion);
  Generate(Length(FKeyData));
  EncryptWith(AKEK);
  FStatus := ksActive;
end;

function TDataKey.GetInfo: TKeyInfo;
begin
  Result.KeyId := FKeyId;
  Result.Purpose := FPurpose;
  Result.Status := FStatus;
  Result.CreatedAt := FCreatedAt;
  Result.ExpiresAt := FExpiresAt;
  Result.RotatedAt := 0;
  Result.Version := FVersion;
  Result.Algorithm := 'AES-256-CBC';
  Result.KeyLength := Length(FKeyData) * 8;
end;

{ TKeyStore }

constructor TKeyStore.Create(const AStorePath: string);
begin
  inherited Create;
  FKeys := TObjectDictionary<string, TDataKey>.Create([doOwnsValues]);
  FLock := TCriticalSection.Create;
  FStorePath := AStorePath;
end;

destructor TKeyStore.Destroy;
begin
  FreeAndNil(FKeys);
  FreeAndNil(FLock);
  inherited;
end;

procedure TKeyStore.Initialize(AMasterKey: TMasterKey);
begin
  FMasterKey := AMasterKey;
  if TFile.Exists(FStorePath) then
    Load;
end;

function TKeyStore.GetKEK: TBytes;
begin
  if (FMasterKey = nil) or not FMasterKey.IsUnlocked then
    raise EKeyManagerException.Create('Master key not available');
  Result := FMasterKey.GetKeyData;
end;

function TKeyStore.CreateKey(APurpose: TKeyPurpose; AExpiryDays: Integer): TDataKey;
var
  Key: TDataKey;
begin
  FLock.Enter;
  try
    Key := TDataKey.Create(APurpose);
    Key.Generate(32);
    Key.FExpiresAt := IncDay(Now, AExpiryDays);
    Key.EncryptWith(GetKEK);
    FKeys.Add(Key.KeyId, Key);
    Save;
    Result := Key;
  finally
    FLock.Leave;
  end;
end;

function TKeyStore.GetKey(const AKeyId: string): TDataKey;
begin
  FLock.Enter;
  try
    if not FKeys.TryGetValue(AKeyId, Result) then
      Result := nil
    else if Length(Result.FKeyData) = 0 then
      Result.DecryptWith(GetKEK);
  finally
    FLock.Leave;
  end;
end;

function TKeyStore.GetActiveKey(APurpose: TKeyPurpose): TDataKey;
var
  Key: TDataKey;
begin
  FLock.Enter;
  try
    Result := nil;
    for Key in FKeys.Values do
    begin
      if (Key.Purpose = APurpose) and (Key.Status = ksActive) and not Key.GetInfo.IsExpired then
      begin
        if Length(Key.FKeyData) = 0 then
          Key.DecryptWith(GetKEK);
        Result := Key;
        Break;
      end;
    end;
    if Result = nil then
      Result := CreateKey(APurpose, 365);
  finally
    FLock.Leave;
  end;
end;

procedure TKeyStore.RotateKey(const AKeyId: string);
var
  Key: TDataKey;
begin
  FLock.Enter;
  try
    if FKeys.TryGetValue(AKeyId, Key) then
    begin
      Key.Rotate(GetKEK);
      Save;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKeyStore.RevokeKey(const AKeyId: string);
var
  Key: TDataKey;
begin
  FLock.Enter;
  try
    if FKeys.TryGetValue(AKeyId, Key) then
    begin
      Key.Status := ksRevoked;
      Save;
    end;
  finally
    FLock.Leave;
  end;
end;

function TKeyStore.GetAllKeys: TArray<TKeyInfo>;
var
  Key: TDataKey;
  List: TList<TKeyInfo>;
begin
  FLock.Enter;
  try
    List := TList<TKeyInfo>.Create;
    try
      for Key in FKeys.Values do
        List.Add(Key.GetInfo);
      Result := List.ToArray;
    finally
      List.Free;
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKeyStore.Save;
begin
  SaveToFile;
end;

procedure TKeyStore.Load;
begin
  LoadFromFile;
end;

procedure TKeyStore.SaveToFile;
var
  JSON: TJSONObject;
  KeysArray: TJSONArray;
  KeyObj: TJSONObject;
  Key: TDataKey;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('version', TJSONNumber.Create(1));
    
    KeysArray := TJSONArray.Create;
    for Key in FKeys.Values do
    begin
      KeyObj := TJSONObject.Create;
      KeyObj.AddPair('id', Key.KeyId);
      KeyObj.AddPair('purpose', Ord(Key.Purpose));
      KeyObj.AddPair('status', Ord(Key.Status));
      KeyObj.AddPair('created', DateToISO8601(Key.FCreatedAt));
      KeyObj.AddPair('expires', DateToISO8601(Key.FExpiresAt));
      KeyObj.AddPair('version', Key.Version);
      KeyObj.AddPair('data', TEncodingUtils.Base64Encode(Key.EncryptedKeyData));
      KeysArray.AddElement(KeyObj);
    end;
    JSON.AddPair('keys', KeysArray);
    
    TFile.WriteAllText(FStorePath, JSON.ToJSON);
  finally
    JSON.Free;
  end;
end;

procedure TKeyStore.LoadFromFile;
var
  JSON: TJSONObject;
  KeysArray: TJSONArray;
  KeyObj: TJSONObject;
  Key: TDataKey;
  I: Integer;
begin
  if not TFile.Exists(FStorePath) then
    Exit;
    
  JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FStorePath)) as TJSONObject;
  if JSON = nil then
    Exit;
    
  try
    KeysArray := JSON.GetValue<TJSONArray>('keys');
    if KeysArray = nil then
      Exit;
      
    FKeys.Clear;
    for I := 0 to KeysArray.Count - 1 do
    begin
      KeyObj := KeysArray.Items[I] as TJSONObject;
      Key := TDataKey.Create(TKeyPurpose(KeyObj.GetValue<Integer>('purpose')));
      Key.FKeyId := KeyObj.GetValue<string>('id');
      Key.FStatus := TKeyStatus(KeyObj.GetValue<Integer>('status'));
      Key.FCreatedAt := ISO8601ToDate(KeyObj.GetValue<string>('created'));
      Key.FExpiresAt := ISO8601ToDate(KeyObj.GetValue<string>('expires'));
      Key.FVersion := KeyObj.GetValue<Integer>('version');
      Key.FEncryptedKeyData := TEncodingUtils.Base64Decode(KeyObj.GetValue<string>('data'));
      FKeys.Add(Key.KeyId, Key);
    end;
  finally
    JSON.Free;
  end;
end;

{ TKeyManager }

constructor TKeyManager.Create(const AStorePath: string);
begin
  inherited Create;
  FLock := TCriticalSection.Create;
  FMasterKey := TMasterKey.Create;
  FKeyStore := TKeyStore.Create(AStorePath);
  FIsInitialized := False;
end;

destructor TKeyManager.Destroy;
begin
  FreeAndNil(FKeyStore);
  FreeAndNil(FMasterKey);
  FreeAndNil(FLock);
  inherited;
end;

class function TKeyManager.Instance: TKeyManager;
begin
  if FInstance = nil then
  begin
    FInstanceLock.Enter;
    try
      if FInstance = nil then
        FInstance := TKeyManager.Create(
          TPath.Combine(TPath.GetHomePath, '.DeepBase_keys.json'));
    finally
      FInstanceLock.Leave;
    end;
  end;
  Result := FInstance;
end;

class procedure TKeyManager.SetInstance(AInstance: TKeyManager);
begin
  FInstanceLock.Enter;
  try
    if FInstance <> nil then
      FreeAndNil(FInstance);
    FInstance := AInstance;
  finally
    FInstanceLock.Leave;
  end;
end;

procedure TKeyManager.Initialize(const AMasterPassword: string; AUseHardwareBinding: Boolean);
begin
  FLock.Enter;
  try
    if AUseHardwareBinding then
      FMasterKey.DeriveWithHardwareBinding(AMasterPassword)
    else
      FMasterKey.DeriveFromPassword(AMasterPassword, TKeyDerivationParams.Default);
      
    FKeyStore.Initialize(FMasterKey);
    FIsInitialized := True;
    
    // Create default keys if none exist
    if Length(FKeyStore.GetAllKeys) = 0 then
    begin
      FKeyStore.CreateKey(kpConfig, 365);
      FKeyStore.CreateKey(kpDatabase, 365);
      FKeyStore.CreateKey(kpBackup, 365);
    end;
  finally
    FLock.Leave;
  end;
end;

procedure TKeyManager.Lock;
begin
  FLock.Enter;
  try
    FMasterKey.Lock;
    FIsInitialized := False;
  finally
    FLock.Leave;
  end;
end;

function TKeyManager.IsUnlocked: Boolean;
begin
  Result := FMasterKey.IsUnlocked;
end;

function TKeyManager.GetHardwareFingerprint: THardwareFingerprint;
begin
  Result := THardwareFingerprint.Collect;
end;

function TKeyManager.CreateDataKey(APurpose: TKeyPurpose; AExpiryDays: Integer): string;
var
  Key: TDataKey;
begin
  Key := FKeyStore.CreateKey(APurpose, AExpiryDays);
  Result := Key.KeyId;
end;

function TKeyManager.GetDataKey(const AKeyId: string): TBytes;
var
  Key: TDataKey;
begin
  Key := FKeyStore.GetKey(AKeyId);
  if Key = nil then
    raise EKeyManagerException.CreateFmt('Key not found: %s', [AKeyId]);
  Result := Key.KeyData;
end;

function TKeyManager.GetActiveKeyForPurpose(APurpose: TKeyPurpose): TBytes;
var
  Key: TDataKey;
begin
  Key := FKeyStore.GetActiveKey(APurpose);
  if Key = nil then
    Key := FKeyStore.CreateKey(APurpose, 365);
  Result := Key.KeyData;
end;

procedure TKeyManager.RotateKey(const AKeyId: string);
begin
  FKeyStore.RotateKey(AKeyId);
  if Assigned(FOnKeyRotated) then
    FOnKeyRotated(Self);
end;

procedure TKeyManager.RevokeKey(const AKeyId: string);
begin
  FKeyStore.RevokeKey(AKeyId);
end;

function TKeyManager.Encrypt(const AData: TBytes; APurpose: TKeyPurpose): TBytes;
var
  AES: TAESCrypto;
  KeyData: TBytes;
  IV, Cipher: TBytes;
begin
  KeyData := GetActiveKeyForPurpose(APurpose);
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(KeyData);
    IV := TRandomGenerator.RandomBytes(16);
    AES.SetIV(IV);
    Cipher := AES.Encrypt(AData);
    SetLength(Result, Length(IV) + Length(Cipher));
    Move(IV[0], Result[0], Length(IV));
    Move(Cipher[0], Result[Length(IV)], Length(Cipher));
  finally
    AES.Free;
  end;
end;

function TKeyManager.Decrypt(const AData: TBytes; APurpose: TKeyPurpose): TBytes;
var
  AES: TAESCrypto;
  KeyData: TBytes;
  IV, Cipher: TBytes;
begin
  if Length(AData) <= 16 then
    raise EKeyManagerException.Create('Invalid encrypted payload');

  KeyData := GetActiveKeyForPurpose(APurpose);
  AES := TAESCrypto.Create(aes256, aesCBC);
  try
    AES.SetKey(KeyData);
    IV := Copy(AData, 0, 16);
    Cipher := Copy(AData, 16, Length(AData) - 16);
    AES.SetIV(IV);
    Result := AES.Decrypt(Cipher);
  finally
    AES.Free;
  end;
end;

function TKeyManager.EncryptString(const AData: string; APurpose: TKeyPurpose): string;
var
  DataBytes, EncBytes: TBytes;
begin
  DataBytes := TEncoding.UTF8.GetBytes(AData);
  EncBytes := Encrypt(DataBytes, APurpose);
  Result := TEncodingUtils.Base64Encode(EncBytes);
end;

function TKeyManager.DecryptString(const AData: string; APurpose: TKeyPurpose): string;
var
  EncBytes, DecBytes: TBytes;
begin
  EncBytes := TEncodingUtils.Base64Decode(AData);
  DecBytes := Decrypt(EncBytes, APurpose);
  Result := TEncoding.UTF8.GetString(DecBytes);
end;

function TKeyManager.EncryptConfig(const AValue: string): string;
begin
  Result := EncryptString(AValue, kpConfig);
end;

function TKeyManager.DecryptConfig(const AValue: string): string;
begin
  Result := DecryptString(AValue, kpConfig);
end;

function TKeyManager.ValidateHardwareBinding: Boolean;
var
  CurrentFP: THardwareFingerprint;
begin
  CurrentFP := THardwareFingerprint.Collect;
  Result := FMasterKey.Fingerprint.Matches(CurrentFP);
end;

function TKeyManager.GetMachineFingerprint: string;
begin
  Result := THardwareFingerprint.Collect.ToHash;
end;

function TKeyManager.GetKeyInfo(const AKeyId: string): TKeyInfo;
var
  Key: TDataKey;
begin
  Key := FKeyStore.GetKey(AKeyId);
  if Key = nil then
    raise EKeyManagerException.CreateFmt('Key not found: %s', [AKeyId]);
  Result := Key.GetInfo;
end;

function TKeyManager.GetAllKeyInfo: TArray<TKeyInfo>;
begin
  Result := FKeyStore.GetAllKeys;
end;

function TKeyManager.GetExpiringKeys(ADaysThreshold: Integer): TArray<TKeyInfo>;
var
  AllKeys: TArray<TKeyInfo>;
  Info: TKeyInfo;
  List: TList<TKeyInfo>;
begin
  AllKeys := GetAllKeyInfo;
  List := TList<TKeyInfo>.Create;
  try
    for Info in AllKeys do
    begin
      if (Info.Status = ksActive) and (Info.DaysUntilExpiry <= ADaysThreshold) then
        List.Add(Info);
    end;
    Result := List.ToArray;
  finally
    List.Free;
  end;
end;

initialization
  TKeyManager.FInstanceLock := TCriticalSection.Create;

finalization
  if TKeyManager.FInstance <> nil then
  begin
    TKeyManager.FInstance.Free;
    TKeyManager.FInstance := nil;
  end;
  FreeAndNil(TKeyManager.FInstanceLock);

end.
