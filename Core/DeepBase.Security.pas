{ ============================================================================
  DeepBase.Security - Cross-Platform Security Module
  
  Version: 1.0
  Description: Provides secure storage for sensitive data.
               - Windows: Uses DPAPI (user scope)
               - macOS/Linux: Uses the UBS2 authenticated envelope
               Use this module for passwords, API keys, tokens, and other secrets.

  The envelope format, the KDF cost policy and the legacy-v1 reader live in
  DeepBase.Security.UBS2 (format SSOT). The user secret lives in
  DeepBase.Security.MasterKey, the machine binding in
  DeepBase.Security.MachineIdentity. This unit only composes them.

  Thread Safety: All public methods are thread-safe.

  SECURITY NOTES:
  - Windows DPAPI uses user-scope encryption (current Windows user only)
  - macOS/Linux derives the AES-256-GCM key from the per-user secret only; machine
    identity is authenticated through the AAD, never mixed into the key password
  - Encrypted data cannot be decrypted on a different machine or by a different user
  - Cross-machine migration is an explicit export/import of the user secret, not an
    environment variable carrying key material
  ============================================================================ }

unit DeepBase.Security;

interface

uses
  System.SysUtils,
  System.Classes,
  System.Generics.Collections,
  DeepBase.Types,
  DeepBase.Exceptions,
  DeepBase.Storage.Interfaces,
  DeepBase.StorageFactory;

type
  /// <summary>
  /// Security manager for sensitive data using Windows DPAPI
  /// </summary>
  TDeepBaseSecurity = class
  private
    FStorage: ISecuritySecretStorage;
    FLock: TObject;
    FOwnsLock: Boolean;

    procedure EnsureSecretsTable;

  public
    constructor Create(AConnection: TObject; ALock: TObject = nil); overload;
    constructor Create(const AStorage: ISecuritySecretStorage;
      ALock: TObject = nil); overload;
    destructor Destroy; override;

    class procedure SetStorageFactory(
      const AFactory: TFunc<TObject, ISecuritySecretStorage>); static;
    
    // ========================================
    // DPAPI Encryption Functions
    // ========================================
    
    /// <summary>
    /// Encrypt string using Windows DPAPI (user scope).
    /// Returns encrypted binary data.
    /// </summary>
    function ProtectString(const AText: string): TBytes;
    
    /// <summary>
    /// Decrypt binary data using Windows DPAPI.
    /// Returns decrypted string.
    /// </summary>
    function UnprotectString(const AData: TBytes): string;
    
    // ========================================
    // Secret Management
    // ========================================
    
    /// <summary>
    /// Load a secret value by name. Returns empty string if not found.
    /// The value is automatically decrypted using DPAPI.
    /// </summary>
    function LoadSecret(const AName: string): string;
    
    /// <summary>
    /// Save a secret value. The value is automatically encrypted using DPAPI.
    /// </summary>
    procedure SaveSecret(const AName, APlainValue: string; 
      const ADescription: string = '');
    
    /// <summary>
    /// Delete a secret by name.
    /// </summary>
    procedure DeleteSecret(const AName: string);
    
    /// <summary>
    /// Check if a secret exists.
    /// </summary>
    function SecretExists(const AName: string): Boolean;
    
    /// <summary>
    /// Get all secret names (without values for security).
    /// </summary>
    function GetSecretNames: TArray<string>;

    {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
    /// <summary>迁移窗口：把库中仍为 UBS2 v1 的凭据逐条用旧口令熵解出、以当前用户
    /// 密钥重新封存为 v2 后写回（名称与描述不变），返回迁移条数。旧熵公式只存在于
    /// 迁移器中，正常读取路径仍然拒绝 v1。取钥前默认拒绝建钥：密钥文件不存在时
    /// LoadOrCreate 会静默新建一把，那会让用户手上的既有备份全部对不上，因此只有
    /// 调用方显式放行（AAllowProvisioning=True）才允许本次新建。</summary>
    function MigrateLegacyUBS2Secrets(const ALegacyPassphrase: string;
      const AAllowProvisioning: Boolean = False): Integer;
    {$ENDIF}
    
    /// <summary>
    /// Validate secret name format for security
    /// </summary>
    class function IsValidSecretName(const AName: string): Boolean; static;
  end;

// ============================================================================
// Global Shortcut Functions
// ============================================================================

/// <summary>
/// Load secret from DeepBase security store.
/// Shortcut for DeepBase.Security.LoadSecret().
/// </summary>
function LoadSecret(const AName: string): string;

/// <summary>
/// Save secret to DeepBase security store.
/// Shortcut for DeepBase.Security.SaveSecret().
/// </summary>
procedure SaveSecret(const AName, APlainValue: string; 
  const ADescription: string = '');

/// <summary>
/// Check if secret exists in DeepBase security store.
/// </summary>
function SecretExists(const AName: string): Boolean;

// ============================================================================
// Low-level Secret Protection Functions (for advanced usage)
// ============================================================================

/// <summary>
/// Encrypt a secret string. Windows: DPAPI user scope. macOS/Linux: UBS2 envelope.
/// </summary>
function ProtectStringDpapi(const AText: string): TBytes;

/// <summary>
/// Decrypt output of ProtectStringDpapi. Windows: DPAPI user scope.
/// macOS/Linux: UBS2 v2 only; v1 must go through the UBS2 migrator first.
/// </summary>
function UnprotectStringDpapi(const AData: TBytes): string;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  DeepBase.SecureMemory,
  DeepBase.Security.UBS2,
  DeepBase.Security.UBS2.Migration,
  DeepBase.Security.MasterKey,
  DeepBase.Security.MachineIdentity,
  DeepBase.Logging,
  {$ENDIF}
  System.NetEncoding,
  DeepBase.Manager;

{$IFDEF MSWINDOWS}
// ============================================================================
// Windows DPAPI Declarations
// ============================================================================

type
  PDataBlob = ^TDataBlob;
  TDataBlob = record
    cbData: DWORD;
    pbData: PByte;
  end;

function CryptProtectData(pDataIn: PDataBlob; szDataDescr: PWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptProtectData';

function CryptUnprotectData(pDataIn: PDataBlob; ppszDataDescr: PPWideChar;
  pOptionalEntropy: PDataBlob; pvReserved: Pointer;
  pPromptStruct: Pointer; dwFlags: DWORD; pDataOut: PDataBlob): BOOL; stdcall;
  external 'crypt32.dll' name 'CryptUnprotectData';

{$ENDIF}

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
// ============================================================================
// UBS2 Key Material
// ============================================================================

// The user secret is the only password entropy; machine identity only travels
// through the AAD, so the binding authenticates a record without being a secret
// an attacker could enumerate to rebuild the key.
//
// The notice sink exists because this is the call that can mint that secret: a key
// that appears without a word is exactly how a user ends up holding backups that
// match nothing. It reaches the application log; before the manager exists there is
// no log to write to, which is why the same facts are readable from
// "DeepBase security status" and are refused by RequireExistingKey on the migration
// path instead of being announced only here.
function BuildUBS2Key: TUBS2KeyMaterial;
begin
  Result.MasterSecret := TUserMasterKey.LoadOrCreate(
    procedure(const AMessage: string)
    var
      AppLogger: TDeepBaseLogger;
    begin
      AppLogger := DeepBase.Manager.DeepBase.Logger;
      if Assigned(AppLogger) then
        AppLogger.Warn(AMessage, 'DeepBase.Security');
    end);
  Result.Binding := TMachineIdentityProvider.Binding;
end;
{$ENDIF}

// ============================================================================
// Global Encryption Functions
// ============================================================================

function ProtectStringDpapi(const AText: string): TBytes;
{$IFDEF MSWINDOWS}
var
  InBlob, OutBlob: TDataBlob;
  WideText: UnicodeString;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  WideText := AText; // UTF-16
  InBlob.cbData := Length(WideText) * SizeOf(WideChar);
  InBlob.pbData := PByte(PWideChar(WideText));
  
  // User-scope encryption (not using CRYPTPROTECT_LOCAL_MACHINE)
  if not CryptProtectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    raise EEncryptionException.CreateFmt('DPAPI encryption failed: %s', [SysErrorMessage(GetLastError)]);
  
  SetLength(Result, OutBlob.cbData);
  Move(OutBlob.pbData^, Result[0], OutBlob.cbData);
  LocalFree(HLOCAL(OutBlob.pbData));
end;
{$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
var
  Key: TUBS2KeyMaterial;
  Plaintext: TBytes;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  Key := BuildUBS2Key;
  Plaintext := TEncoding.UTF8.GetBytes(AText);
  try
    Result := TUBS2.Protect(Plaintext, Key);
  finally
    SecureClearBytes(Plaintext);
    SecureClearBytes(Key.MasterSecret);
    SecureClearBytes(Key.Binding);
  end;
end;
{$ELSE}
begin
  // Unsupported platform - raise error instead of silent failure
  raise EEncryptionException.Create('Encryption not supported on this platform');
end;
{$ENDIF}

function UnprotectStringDpapi(const AData: TBytes): string;
{$IFDEF MSWINDOWS}
var
  InBlob, OutBlob: TDataBlob;
  WideText: UnicodeString;
begin
  if Length(AData) = 0 then
    Exit('');
  
  InBlob.cbData := Length(AData);
  InBlob.pbData := @AData[0];
  
  if not CryptUnprotectData(@InBlob, nil, nil, nil, nil, 0, @OutBlob) then
    raise EDecryptionException.CreateFmt('DPAPI decryption failed: %s', [SysErrorMessage(GetLastError)]);
  
  SetString(WideText, PWideChar(OutBlob.pbData), OutBlob.cbData div SizeOf(WideChar));
  Result := WideText;
  LocalFree(HLOCAL(OutBlob.pbData));
end;
{$ELSEIF DEFINED(MACOS) OR DEFINED(LINUX)}
var
  Key: TUBS2KeyMaterial;
  PlainBytes: TBytes;
begin
  Key := BuildUBS2Key;
  try
    PlainBytes := TUBS2.Unprotect(AData, Key);
  finally
    SecureClearBytes(Key.MasterSecret);
    SecureClearBytes(Key.Binding);
  end;
  try
    Result := TEncoding.UTF8.GetString(PlainBytes);
  finally
    SecureClearBytes(PlainBytes);
  end;
end;
{$ELSE}
begin
  raise EDecryptionException.Create('Decryption not supported on this platform');
end;
{$ENDIF}

// ============================================================================
// Global Shortcut Functions
// ============================================================================

function LoadSecret(const AName: string): string;
begin
  if DeepBase.Manager.DeepBase.IsInitialized and 
     Assigned(DeepBase.Manager.DeepBase.Security) then
    Result := DeepBase.Manager.DeepBase.Security.LoadSecret(AName)
  else
    Result := '';
end;

procedure SaveSecret(const AName, APlainValue: string; 
  const ADescription: string);
begin
  if DeepBase.Manager.DeepBase.IsInitialized and 
     Assigned(DeepBase.Manager.DeepBase.Security) then
    DeepBase.Manager.DeepBase.Security.SaveSecret(AName, APlainValue, ADescription);
end;

function SecretExists(const AName: string): Boolean;
begin
  if DeepBase.Manager.DeepBase.IsInitialized and 
     Assigned(DeepBase.Manager.DeepBase.Security) then
    Result := DeepBase.Manager.DeepBase.Security.SecretExists(AName)
  else
    Result := False;
end;

// ============================================================================
// TDeepBaseSecurity
// ============================================================================

constructor TDeepBaseSecurity.Create(AConnection: TObject; ALock: TObject);
var
  LStorage: ISecuritySecretStorage;
begin
  LStorage := TConnectionStorageFactory<ISecuritySecretStorage>.Create(AConnection);
  if (LStorage = nil) and Assigned(AConnection) then
    raise EInvalidOp.Create(
      'No security storage factory registered for connection-backed constructor. ' +
      'Include DeepBase.Persistence.Security.FireDAC or DeepBase.Persistence.Manager.FireDAC.');
  Create(LStorage, ALock);
end;

constructor TDeepBaseSecurity.Create(const AStorage: ISecuritySecretStorage;
  ALock: TObject);
begin
  inherited Create;
  FStorage := AStorage;
  if Assigned(ALock) then
  begin
    FLock := ALock;
    FOwnsLock := False;
  end
  else
  begin
    FLock := TObject.Create;
    FOwnsLock := True;
  end;
end;

destructor TDeepBaseSecurity.Destroy;
begin
  if FOwnsLock then
    FreeAndNil(FLock);
  inherited;
end;

procedure TDeepBaseSecurity.EnsureSecretsTable;
begin
  if Assigned(FStorage) then
    FStorage.EnsureSecretsTable;
end;

class procedure TDeepBaseSecurity.SetStorageFactory(
  const AFactory: TFunc<TObject, ISecuritySecretStorage>);
begin
  TConnectionStorageFactory<ISecuritySecretStorage>.SetFactory(AFactory);
end;

function TDeepBaseSecurity.ProtectString(const AText: string): TBytes;
begin
  Result := ProtectStringDpapi(AText);
end;

function TDeepBaseSecurity.UnprotectString(const AData: TBytes): string;
begin
  Result := UnprotectStringDpapi(AData);
end;

function TDeepBaseSecurity.LoadSecret(const AName: string): string;
var
  Rec: TSecretRecord;
  CipherBytes: TBytes;
begin
  Result := '';

  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;

    if not FStorage.TryReadSecret(AName, Rec) then
      Exit;
    if Rec.CipherBlobBase64 = '' then
      Exit;

    CipherBytes := TNetEncoding.Base64.DecodeStringToBytes(Rec.CipherBlobBase64);
    Result := UnprotectString(CipherBytes);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseSecurity.SaveSecret(const AName, APlainValue: string;
  const ADescription: string);
var
  CipherBytes: TBytes;
  CipherBase64: string;
  NowStr: string;
begin
    // Secret names go into SQL parameters and file paths, so the format is validated first.
  if not IsValidSecretName(AName) then
    raise EArgumentException.Create('Invalid secret name format');
    
  // Limit plaintext size to avoid storing oversized secret blobs.
  if Length(TEncoding.UTF8.GetBytes(APlainValue)) > 64 * 1024 then
    raise EArgumentException.Create('Secret value too large (max 64KB)');

  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;

    CipherBytes := ProtectString(APlainValue);
    CipherBase64 := TNetEncoding.Base64.EncodeBytesToString(CipherBytes);

    // Use ISO8601 format for SQLite datetime compatibility
    NowStr := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);

    FStorage.UpsertSecret(AName, CipherBase64, ADescription, NowStr);
  finally
    TMonitor.Exit(FLock);
  end;
end;

procedure TDeepBaseSecurity.DeleteSecret(const AName: string);
begin
  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    FStorage.DeleteSecret(AName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

{$IF DEFINED(MACOS) OR DEFINED(LINUX)}
function TDeepBaseSecurity.MigrateLegacyUBS2Secrets(
  const ALegacyPassphrase: string;
  const AAllowProvisioning: Boolean): Integer;
var
  Names: TArray<string>;
  Name: string;
  Rec: TSecretRecord;
  LegacyBlob, Migrated: TBytes;
  Key: TUBS2KeyMaterial;
begin
  Result := 0;

  // Ahead of the storage check and ahead of taking key material: BuildUBS2Key
  // provisions when the key file is absent, and a migration that minted a key
  // would invalidate every backup the user holds while still reporting success.
  TUserMasterKey.RequireExistingKey('the UBS2 v1 to v2 secret migration',
    AAllowProvisioning);

  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    Names := FStorage.ReadSecretNames;
    Key := BuildUBS2Key;
    try
      for Name in Names do
      begin
        if not FStorage.TryReadSecret(Name, Rec) then
          Continue;

        LegacyBlob := TNetEncoding.Base64.DecodeStringToBytes(Rec.CipherBlobBase64);
        try
          if not TUBS2Migrator.NeedsMigration(LegacyBlob) then
            Continue;

          // Reencrypt throws before anything is written, so a record that cannot be
          // opened under the legacy passphrase keeps its original v1 blob.
          Migrated := TUBS2Migrator.Reencrypt(LegacyBlob, ALegacyPassphrase, Key);
          try
            FStorage.UpsertSecret(Name,
              TNetEncoding.Base64.EncodeBytesToString(Migrated),
              Rec.Description,
              FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now));
          finally
            SecureClearBytes(Migrated);
          end;
          Inc(Result);
        finally
          SecureClearBytes(LegacyBlob);
        end;
      end;
    finally
      SecureClearBytes(Key.MasterSecret);
      SecureClearBytes(Key.Binding);
    end;
  finally
    TMonitor.Exit(FLock);
  end;
end;
{$ENDIF}

function TDeepBaseSecurity.SecretExists(const AName: string): Boolean;
begin
  Result := False;

  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    Result := FStorage.SecretExists(AName);
  finally
    TMonitor.Exit(FLock);
  end;
end;

function TDeepBaseSecurity.GetSecretNames: TArray<string>;
begin
  SetLength(Result, 0);

  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;
    Result := FStorage.ReadSecretNames;
  finally
    TMonitor.Exit(FLock);
  end;
end;

class function TDeepBaseSecurity.IsValidSecretName(const AName: string): Boolean;
var
  I: Integer;
  C: Char;
begin
  Result := False;
  
  // æ£æ¥åºæ¬è¦æ±?
  if AName.IsEmpty or (Length(AName) > 255) then
    Exit;
    
  // ä¸è½ä»¥ç¹å¼å¤´ï¼é²æ­¢éèæä»¶ï¼?
  if AName.StartsWith('.') then
    Exit;
    
  // æ£æ¥æ¯ä¸ªå­ç¬?
  for I := 1 to Length(AName) do
  begin
    C := AName[I];
    
    // åªåè®¸å­æ¯ãæ°å­ãä¸åçº¿ãè¿å­ç¬¦åç¹
    if not (CharInSet(C, ['a'..'z', 'A'..'Z', '0'..'9', '_', '-', '.'])) then
      Exit;
      
    // ä¸åè®¸è¿ç»­çç¹ï¼é²æ­¢è·¯å¾éåï¼?
    if (C = '.') and (I > 1) and (AName[I-1] = '.') then
      Exit;
  end;
  
  // ä¸è½ä»¥ç¹ç»å°¾
  if AName.EndsWith('.') then
    Exit;
    
  // æ£æ¥ä¿çåç§?
  var LowerName := AName.ToLower;
  if (LowerName = 'con') or (LowerName = 'prn') or (LowerName = 'aux') or
     (LowerName = 'nul') then
    Exit;
  // CR-254: Windows 保留设备名是 COM1..9/LPT1..9（含扩展名变体）的精确形态，
  // 前缀匹配会误杀 common_config、lpt_settings 等合法名称
  var LStem := LowerName;
  var LDot := Pos('.', LStem);
  if LDot > 1 then
    LStem := Copy(LStem, 1, LDot - 1); // 首个扩展名前的主干（COM1.ini 形态）
  if (Length(LStem) = 4) and
     (LStem.StartsWith('com') or LStem.StartsWith('lpt')) and
     CharInSet(LStem[4], ['1'..'9']) then
    Exit;

  Result := True;
end;

end.
