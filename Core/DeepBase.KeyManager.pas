{ ============================================================================
  DeepBase.KeyManager - Advanced Key Management System
  
  Version: 2.0
  Description: Key hierarchy (master -> KEK -> DEK) with rotation and a
    machine-bound, fail-closed keystore.

  Security model (Top20 #5):
    - KEK = PBKDF2(user password, persisted salt). Machine identity is NOT
      password entropy; the password is the only secret the user must remember.
    - Machine identity is the AAD of every wrapped DEK and the gate persisted in
      the keystore header, so a stolen keystore plus password still cannot be
      opened on another machine.
    - DEK: random 256-bit keys wrapped by the KEK, persisted as JSON.
    - Keys are never stored in plain text.

  Related SSOT units (do not restate their rules here):
    - DeepBase.Security.MachineIdentity: which sources form the binding and its
      scheme version.
    - DeepBase.Security.MasterKey: the per-user secret entropy for UBS2.
    - DeepBase.Security.UBS2: the authenticated secret envelope format.

  Thread Safety: All public methods are thread-safe.
  ============================================================================ }

unit DeepBase.KeyManager;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  System.SyncObjs,
  System.DateUtils,
  DeepBase.Crypto, DeepBase.Crypto.AES, DeepBase.Crypto.Encoding, DeepBase.Crypto.Hash, DeepBase.Crypto.Random,
  DeepBase.Security.MachineIdentity,
  // 与 DeepBase.License 共用同一个时钟源：密钥有效期若读裸墙钟，回拨系统时间就能
  // 让到期密钥重新可用，也会把新建密钥的有效期窗口整体往前挪。
  DeepBase.TimeSource;

type
  EKeyManagerException = class(Exception);

const
  /// <summary>On-disk keystore format. v1 sealed the KEK with machine-fingerprint
  /// password entropy and wrapped DEKs without a machine binding, so this build
  /// refuses to read it: run the keystore re-key migration.</summary>
  KEYSTORE_FORMAT_VERSION = 2;
  /// <summary>Version byte prefixing a wrapped DEK: AES-256-GCM.</summary>
  DEK_WRAP_VERSION_GCM = $01;
  /// <summary>Explicit cipher-suite marker for the TKeyManager payload envelope
  /// (distinct from the DEK-wrap layer above). Decrypt only accepts this value and
  /// rejects any other leading byte instead of silently downgrading (A2-04).</summary>
  KEYMGR_FMT_AES256_GCM = $02;

type
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

  TKeyDerivationParams = record
    Salt: TBytes;
    Iterations: Integer;
    KeyLength: Integer;
    Algorithm: THashAlgorithm;
    
    class function Default: TKeyDerivationParams; static;
    class function High: TKeyDerivationParams; static;
  end;

  /// <summary>Key encryption key (KEK). Derived from the user password alone;
  /// machine affinity is enforced by the keystore, not by the derived key
  /// material (Top20 #5).</summary>
  TMasterKey = class
  private
    FKeyData: TBytes;
    FParams: TKeyDerivationParams;
    FCreatedAt: TDateTime;
    FIsUnlocked: Boolean;

    procedure ClearKey;

  public
    constructor Create;
    destructor Destroy; override;

    procedure DeriveFromPassword(const APassword: string; const AParams: TKeyDerivationParams);
    procedure Lock;
    function GetKeyData: TBytes;

    property IsUnlocked: Boolean read FIsUnlocked;
    /// <summary>CR-001: 当前派生参数，供 keystore 持久化（盐不是机密）</summary>
    property Params: TKeyDerivationParams read FParams;
    property CreatedAt: TDateTime read FCreatedAt;
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
    /// <summary>Wrap with the KEK; AAAD carries the machine binding so the
    /// wrapped key cannot be unwrapped on another machine.</summary>
    procedure EncryptWith(const AKEK: TBytes; const AAAD: TBytes);
    procedure DecryptWith(const AKEK: TBytes; const AAAD: TBytes);
    procedure Rotate(const AKEK: TBytes; const AAAD: TBytes);
    function GetInfo: TKeyInfo;
    /// <summary>Returns a copy: callers must not alias key material the store owns,
    /// otherwise freeing the store wipes memory the caller still holds.</summary>
    function GetKeyData: TBytes;

    property KeyId: string read FKeyId;
    property KeyData: TBytes read GetKeyData;
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
    FKdfParams: TKeyDerivationParams;
    FSealedBindingScheme: Integer;
    FSealedBindingHash: string;
    FCurrentBinding: TMachineIdentity;
    FBindingResolved: Boolean;
    FHasSealedState: Boolean;

    function GetKEK: TBytes;
    /// <summary>Current machine binding, collected once per store instance.
    /// Raises when a mandatory identity source is unavailable.</summary>
    function Binding: TMachineIdentity;
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

    /// <summary>CR-001: 读取 keystore 的非机密封存头（KDF 参数 + 机器绑定）。
    /// 盐与绑定都不是机密，但必须在派生 KEK 之前拿到，否则跨会话无法复现 KEK。
    /// 文件存在而封存头缺字段时一律 fail-closed 抛错，不回落到默认值。</summary>
    procedure LoadSealedState;
    /// <summary>机器绑定门禁：指纹方案版本与全量取值必须与封存时一致。</summary>
    procedure VerifyMachineBinding;
    /// <summary>CR-001: 抽验一把存量密钥可用当前 KEK 解密，
    /// 密码错误时尽早失败，而不是推迟到业务首次加解密。</summary>
    procedure VerifyKeysDecryptable;

    property KdfParams: TKeyDerivationParams read FKdfParams;
    function HasSealedState: Boolean;
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
    
    
  public
    constructor Create(const AStorePath: string);
    destructor Destroy; override;
    
    class function Instance: TKeyManager;
    class procedure SetInstance(AInstance: TKeyManager);
    
    /// <summary>Unlock the keystore. The password is the only secret entropy;
    /// the machine binding is verified as a gate, never mixed into the key.</summary>
    procedure Initialize(const AMasterPassword: string);
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
    
    /// <summary>Hex fingerprint of the current machine identity. Opening the
    /// keystore itself enforces the binding gate and raises with the reason.</summary>
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
  System.NetEncoding,
  DeepBase.SecureMemory;

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
  // 与许可同一条判据：裸 Now 会被系统回拨绕过，到期密钥因此重新可用
  Result := (ExpiresAt > 0) and (TDeepBaseTimeSource.Shared.Now > ExpiresAt);
end;

function TKeyInfo.DaysUntilExpiry: Integer;
begin
  if ExpiresAt = 0 then
    Result := MaxInt
  else
    Result := DaysBetween(TDeepBaseTimeSource.Shared.Now, ExpiresAt);
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
  FCreatedAt := TDeepBaseTimeSource.Shared.Now;
end;

destructor TMasterKey.Destroy;
begin
  ClearKey;
  inherited;
end;

procedure TMasterKey.ClearKey;
begin
  SecureClearBytes(FKeyData);
  FIsUnlocked := False;
end;

procedure TMasterKey.DeriveFromPassword(const APassword: string; const AParams: TKeyDerivationParams);
begin
  FParams := AParams;
  FKeyData := TPasswordUtils.PBKDF2(APassword, AParams.Salt, AParams.Iterations,
                                    AParams.KeyLength, AParams.Algorithm);
  FIsUnlocked := True;
  FCreatedAt := TDeepBaseTimeSource.Shared.Now;
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
  FCreatedAt := TDeepBaseTimeSource.Shared.Now;
  FVersion := 1;
  FKeyId := TRandomGenerator.NewGuidNoDashes;
end;

destructor TDataKey.Destroy;
begin
  SecureClearBytes(FKeyData);
  inherited;
end;

procedure TDataKey.Generate(AKeyLength: Integer);
begin
  FKeyData := TRandomGenerator.RandomBytes(AKeyLength);
end;

procedure TDataKey.EncryptWith(const AKEK: TBytes; const AAAD: TBytes);
var
  AES: TAESCrypto;
  GCMData: TBytes;
begin
  // REVIEW5-CORE-005: AES-256-GCM (AEAD).
  // Format: Version(1) + Nonce(12) + Cipher + Tag(16)
  // The machine binding travels as AAD, so a wrapped DEK is bound to its machine
  // cryptographically rather than by a flag an attacker can rewrite (Top20 #5).
  AES := TAESCrypto.Create(aes256, aesGCM);
  try
    AES.SetKey(AKEK);
    GCMData := AES.Encrypt(FKeyData, AAAD);
    SetLength(FEncryptedKeyData, 1 + Length(GCMData));
    FEncryptedKeyData[0] := DEK_WRAP_VERSION_GCM;
    Move(GCMData[0], FEncryptedKeyData[1], Length(GCMData));
  finally
    AES.Free;
  end;
end;

procedure TDataKey.DecryptWith(const AKEK: TBytes; const AAAD: TBytes);
var
  AES: TAESCrypto;
  IV, Cipher, GCMData: TBytes;
begin
  if Length(FEncryptedKeyData) = 0 then
    Exit;

  if (Length(FEncryptedKeyData) > 1) and (FEncryptedKeyData[0] = DEK_WRAP_VERSION_GCM) then
  begin
    // Version(1) already consumed; rest is Nonce(12) + Cipher + Tag(16).
    GCMData := Copy(FEncryptedKeyData, 1, Length(FEncryptedKeyData) - 1);
    AES := TAESCrypto.Create(aes256, aesGCM);
    try
      AES.SetKey(AKEK);
      FKeyData := AES.Decrypt(GCMData, AAAD);
    finally
      AES.Free;
    end;
  end
  else
  begin
    // Legacy format — AES-256-CBC (unauthenticated). Format: IV(16) + Cipher.
    // CBC has no authenticated data and TAESCrypto rejects AAD outside GCM, so the
    // machine binding cannot cover these records; their removal is Top20 #10 (A17).
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
end;

procedure TDataKey.Rotate(const AKEK: TBytes; const AAAD: TBytes);
begin
  FStatus := ksRotating;
  Inc(FVersion);
  Generate(Length(FKeyData));
  EncryptWith(AKEK, AAAD);
  FStatus := ksActive;
end;

function TDataKey.GetKeyData: TBytes;
begin
  Result := Copy(FKeyData);
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
  // CORE-R2-007: Report actual encryption mode based on version byte.
  // EncryptWith writes version byte $01 for AES-256-GCM; legacy data
  // lacks this prefix and was encrypted with AES-256-CBC.
  if (Length(FEncryptedKeyData) > 0) and (FEncryptedKeyData[0] = DEK_WRAP_VERSION_GCM) then
    Result.Algorithm := 'AES-256-GCM'
  else
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

function TKeyStore.Binding: TMachineIdentity;
begin
  if not FBindingResolved then
  begin
    // Collected once per store: the sources are stable for the process lifetime and
    // the collector is fail-closed, so an unreadable source raises on first use.
    FCurrentBinding := TMachineIdentityProvider.Collect;
    FBindingResolved := True;
  end;
  Result := FCurrentBinding;
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
    Key.FExpiresAt := IncDay(TDeepBaseTimeSource.Shared.Now, AExpiryDays);
    Key.EncryptWith(GetKEK, Binding.ToBinding);
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
      Result.DecryptWith(GetKEK, Binding.ToBinding);
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
          Key.DecryptWith(GetKEK, Binding.ToBinding);
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
      Key.Rotate(GetKEK, Binding.ToBinding);
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
  KeyObj, KdfObj, BindingObj: TJSONObject;
  Key: TDataKey;
  LSerialized: string;
  LTmpPath, LBakPath: string;
  LStream: TFileStream;
  LBytes: TBytes;
  LBinding: TMachineIdentity;
begin
  JSON := TJSONObject.Create;
  try
    JSON.AddPair('version', TJSONNumber.Create(KEYSTORE_FORMAT_VERSION));

    // 封存头 = KDF 参数（盐不是机密）+ 机器绑定指纹。缺任何一项，keystore 都无法
    // 在下次会话中被正确打开，因此写侧同样拒绝产出不完整的封存头。
    if FMasterKey = nil then
      raise EKeyManagerException.Create('Keystore cannot be sealed without a master key');
    FKdfParams := FMasterKey.Params;
    if Length(FKdfParams.Salt) = 0 then
      raise EKeyManagerException.Create('Keystore cannot be sealed without KDF parameters');
    KdfObj := TJSONObject.Create;
    KdfObj.AddPair('salt', TEncodingUtils.Base64Encode(FKdfParams.Salt));
    KdfObj.AddPair('iterations', TJSONNumber.Create(FKdfParams.Iterations));
    KdfObj.AddPair('keylength', TJSONNumber.Create(FKdfParams.KeyLength));
    KdfObj.AddPair('algorithm', TJSONNumber.Create(Ord(FKdfParams.Algorithm)));
    JSON.AddPair('kdf', KdfObj);

    LBinding := Binding;
    BindingObj := TJSONObject.Create;
    BindingObj.AddPair('scheme', TJSONNumber.Create(LBinding.SchemeVersion));
    BindingObj.AddPair('hash', LBinding.ToHash);
    JSON.AddPair('binding', BindingObj);

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
    LSerialized := JSON.ToJSON;
  finally
    JSON.Free;
  end;

  // A13/Top20#3: atomic write with backup. Write .tmp → flush → rename.
  // If crash occurs between write and rename, original file remains intact.
  LTmpPath := FStorePath + '.tmp';
  LBakPath := FStorePath + '.bak';
  LStream := TFileStream.Create(LTmpPath, fmCreate or fmShareDenyWrite);
  try
    LBytes := TEncoding.UTF8.GetBytes(LSerialized);
    if Length(LBytes) > 0 then
      LStream.WriteBuffer(LBytes[0], Length(LBytes));
  finally
    LStream.Free; // CloseHandle flushes OS buffers
  end;
  if TFile.Exists(FStorePath) then
  begin
    TFile.Copy(FStorePath, LBakPath, True);
    // TFile.Move refuses to replace an existing destination (ERROR_ALREADY_EXISTS),
    // which is why the live file is retired to .bak first: a crash inside this
    // window still leaves a readable .bak plus a complete .tmp, never a half file.
    TFile.Delete(FStorePath);
  end;
  TFile.Move(LTmpPath, FStorePath);
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
    // 封存头（KDF 参数 + 机器绑定）只有一个解析入口，避免两套读法互相分叉
    LoadSealedState;

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

procedure TKeyStore.LoadSealedState;
var
  JSON, KdfObj, BindingObj: TJSONObject;
  LVersion: Integer;
begin
  FHasSealedState := False;
  FKdfParams := Default(TKeyDerivationParams);
  FSealedBindingScheme := 0;
  FSealedBindingHash := '';

  // 文件不存在 = 全新 keystore，没有门禁可校验；存在则字段必须齐全。
  if not TFile.Exists(FStorePath) then
    Exit;

  JSON := TJSONObject.ParseJSONValue(TFile.ReadAllText(FStorePath)) as TJSONObject;
  if JSON = nil then
    raise EKeyManagerException.Create('Keystore is not valid JSON: ' + FStorePath);

  try
    LVersion := JSON.GetValue<Integer>('version', 0);
    if LVersion <> KEYSTORE_FORMAT_VERSION then
      raise EKeyManagerException.CreateFmt(
        'Keystore format v%d is not readable by this build, which writes v%d; ' +
        'run the keystore re-key migration.', [LVersion, KEYSTORE_FORMAT_VERSION]);

    if not JSON.TryGetValue<TJSONObject>('kdf', KdfObj) then
      raise EKeyManagerException.Create('Keystore has no sealed KDF parameters.');
    FKdfParams.Salt := TEncodingUtils.Base64Decode(KdfObj.GetValue<string>('salt'));
    FKdfParams.Iterations := KdfObj.GetValue<Integer>('iterations');
    FKdfParams.KeyLength := KdfObj.GetValue<Integer>('keylength');
    FKdfParams.Algorithm := THashAlgorithm(KdfObj.GetValue<Integer>('algorithm'));
    if Length(FKdfParams.Salt) = 0 then
      raise EKeyManagerException.Create('Keystore sealed KDF salt is empty.');

    if not JSON.TryGetValue<TJSONObject>('binding', BindingObj) then
      raise EKeyManagerException.Create(
        'Keystore has no sealed machine binding; run the keystore re-key migration.');
    FSealedBindingScheme := BindingObj.GetValue<Integer>('scheme');
    FSealedBindingHash := BindingObj.GetValue<string>('hash');
    if FSealedBindingHash = '' then
      raise EKeyManagerException.Create('Keystore sealed machine binding hash is empty.');

    FHasSealedState := True;
  finally
    JSON.Free;
  end;
end;

procedure TKeyStore.VerifyMachineBinding;
var
  LCurrent: TMachineIdentity;
begin
  if not FHasSealedState then
    Exit;

  // 全量匹配 + 指纹版本化（替代旧的"5 中 3"）：任一绑定来源取值变化、或采集方案
  // 版本变化，都不再是同一台机器，一律拒绝开启。
  LCurrent := Binding;
  if LCurrent.SchemeVersion <> FSealedBindingScheme then
    raise EKeyManagerException.CreateFmt(
      'Machine identity scheme changed: keystore sealed with v%d, this machine reports ' +
      'v%d. Run the keystore re-key migration.',
      [FSealedBindingScheme, LCurrent.SchemeVersion]);
  if not SameText(LCurrent.ToHash, FSealedBindingHash) then
    raise EKeyManagerException.Create(
      'Machine identity does not match the binding this keystore was sealed with. ' +
      'The store is machine-bound and cannot be opened elsewhere.');
end;

function TKeyStore.HasSealedState: Boolean;
begin
  Result := FHasSealedState;
end;

procedure TKeyStore.VerifyKeysDecryptable;
var
  Key: TDataKey;
begin
  for Key in FKeys.Values do
    if Length(Key.EncryptedKeyData) > 0 then
    begin
      // 抽验第一把：失败即抛（GCM tag 校验），不修改 FKeyData
      Key.DecryptWith(GetKEK, Binding.ToBinding);
      Exit;
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

procedure TKeyManager.Initialize(const AMasterPassword: string);
var
  Params: TKeyDerivationParams;
begin
  FLock.Enter;
  try
    // CR-001: 先读封存头再派生 KEK。盐不是机密；
    // 同一密码必须跨会话复现同一 KEK，否则存量数据密钥永久无法解密。
    FKeyStore.LoadSealedState;
    // 门禁排在派生之前：机器不对时直接说出原因，
    // 而不是让 GCM 校验失败伪装成"主密码错误"。
    FKeyStore.VerifyMachineBinding;

    Params := FKeyStore.KdfParams;
    if Length(Params.Salt) = 0 then
      Params := TKeyDerivationParams.High;

    // Top20 #5: 用户口令是唯一机密熵源，机器绑定只做 AAD/门禁，不再参与派生。
    FMasterKey.DeriveFromPassword(AMasterPassword, Params);

    FKeyStore.Initialize(FMasterKey);
    FIsInitialized := True;

    // 已有封存头时，密码错误应在此处立即失败，
    // 而不是等到业务首次加解密才发现（此时可能已写入新数据）。
    if FKeyStore.HasSealedState then
    begin
      try
        FKeyStore.VerifyKeysDecryptable;
      except
        on E: Exception do
          raise EKeyManagerException.Create(
            '主密码错误或密钥材料损坏：无法用当前 KEK 解密存量密钥。' +
            E.Message);
      end;
    end;

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

{ TKeyManager.Encrypt — AES-256-GCM authenticated encryption.

  Output format (v2):
    Version(1 byte = $02) + Nonce(12) + CipherText + Tag(16)

  Older CBC payloads (no version byte, or unrecognized first byte) are
  handled transparently by Decrypt for backward compatibility.
  New data is always encrypted with GCM (AEAD) to prevent padding-oracle
  and silent tampering attacks that plain CBC is vulnerable to. }
function TKeyManager.Encrypt(const AData: TBytes; APurpose: TKeyPurpose): TBytes;
var
  AES: TAESCrypto;
  KeyData: TBytes;
  GCMData: TBytes;
begin
  KeyData := GetActiveKeyForPurpose(APurpose);
  AES := TAESCrypto.Create(aes256, aesGCM);
  try
    AES.SetKey(KeyData);
    GCMData := AES.Encrypt(AData);  // Nonce(12) + Cipher + Tag(16)
    // Prepend the explicit format marker so Decrypt can validate it (A2-04).
    SetLength(Result, 1 + Length(GCMData));
    Result[0] := KEYMGR_FMT_AES256_GCM;
    Move(GCMData[0], Result[1], Length(GCMData));
  finally
    AES.Free;
  end;
end;

{ TKeyManager.Decrypt — explicit version-header decryption (A2-04 fail-closed).

  The cipher suite MUST NOT be selected by an unprotected data byte that an
  attacker can flip: the previous "first byte = $02 => GCM, anything else =>
  legacy CBC" rule let a one-byte flip silently downgrade authenticated GCM
  ciphertext into tamperable CBC decryption.

  Recognized formats (explicit enum in KEYMGR_FMT_*):
    $02 : AES-256-GCM authenticated decryption (Nonce(12)+Cipher+Tag(16)).
  Anything else — including the old unmarked legacy CBC blobs — is rejected
  rather than downgraded. Legacy plaintext must be re-provisioned (Encrypt
  always emits $02), which is the accepted, boss-authorized breaking change
  for this security defect (WO-20260925-A2 §0.8). }
function TKeyManager.Decrypt(const AData: TBytes; APurpose: TKeyPurpose): TBytes;
var
  AES: TAESCrypto;
  KeyData: TBytes;
  GCMData: TBytes;
begin
  if Length(AData) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  if AData[0] <> KEYMGR_FMT_AES256_GCM then
    raise EKeyManagerException.CreateFmt(
      'Unsupported or tampered ciphertext: unknown format marker $%.2x. ' +
      'Refusing to downgrade authenticated decryption.', [AData[0]]);

  if Length(AData) < 1 + AES_GCM_NONCE_SIZE + AES_GCM_TAG_SIZE then
    raise EKeyManagerException.Create('Invalid GCM payload: truncated');

  KeyData := GetActiveKeyForPurpose(APurpose);
  // v2 — AES-256-GCM authenticated decryption
  GCMData := Copy(AData, 1, Length(AData) - 1); // Nonce(12) + Cipher + Tag(16)
  AES := TAESCrypto.Create(aes256, aesGCM);
  try
    AES.SetKey(KeyData);
    Result := AES.Decrypt(GCMData);
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

function TKeyManager.GetMachineFingerprint: string;
begin
  Result := TMachineIdentityProvider.Fingerprint;
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
