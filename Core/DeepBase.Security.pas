{ ============================================================================
  DeepBase.Security - Cross-Platform Security Module
  
  Version: 1.0
  Description: Provides secure storage for sensitive data.
               - Windows: Uses DPAPI (user scope)
               - macOS/Linux: Uses OpenSSL AES-256-GCM + PBKDF2 (requires bundled libcrypto)
               Use this module for passwords, API keys, tokens, and other secrets.
  
  Thread Safety: All public methods are thread-safe.
  
  SECURITY NOTES:
  - Windows DPAPI uses user-scope encryption (current Windows user only)
  - macOS/Linux uses AES-256-GCM with PBKDF2 key derivation from machine entropy
  - Encrypted data cannot be decrypted on different machines or users
  - For cross-machine scenarios, set DeepBase_MASTER_KEY environment variable
  
  DATA FORMAT (UBS2 for macOS/Linux):
  - Magic: "UBS2" (4 bytes)
  - Version: 0x01 (1 byte)
  - KDF: 0x01=PBKDF2-SHA256 (1 byte)
  - Iterations: UInt32 LE (4 bytes)
  - Salt: 16 bytes
  - IV/Nonce: 12 bytes (GCM)
  - Ciphertext: variable
  - Tag: 16 bytes (GCM auth tag)
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
    
    /// <summary>
    /// Validate secret name format for security
    /// </summary>
    class function IsValidSecretName(const AName: string): Boolean; static;
  end;

// ============================================================================
// BUG-038 FIX: Secure Memory Functions
// ============================================================================

/// <summary>
/// Securely zero memory to prevent sensitive data from remaining in memory.
/// Uses volatile write to prevent compiler optimization.
/// </summary>
procedure SecureZeroMemory(var Data: TBytes); overload;
procedure SecureZeroMemory(var Data: string); overload;

/// <summary>
/// Securely clear a byte array and set length to 0.
/// </summary>
procedure SecureClearBytes(var Data: TBytes);

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
// Low-level DPAPI Functions (for advanced usage)
// ============================================================================

/// <summary>
/// Encrypt string using Windows DPAPI (user scope).
/// </summary>
function ProtectStringDpapi(const AText: string): TBytes;

/// <summary>
/// Decrypt binary data using Windows DPAPI.
/// </summary>
function UnprotectStringDpapi(const AData: TBytes): string;

implementation

uses
  {$IFDEF MSWINDOWS}
  Winapi.Windows,
  {$ENDIF}
  {$IF DEFINED(MACOS) OR DEFINED(LINUX)}
  DeepBase.Crypto.OpenSSL,
  {$ENDIF}
  System.NetEncoding,
  DeepBase.Manager,
  DeepBase.Consts;

// ============================================================================
// BUG-038 FIX: Secure Memory Functions Implementation
// ============================================================================

{$IFDEF MSWINDOWS}
type
  TSecureZeroProc = function(ptr: Pointer; cnt: NativeUInt): Pointer; stdcall;

function ResolveSecureZeroProc: Pointer;
var
  LModule: HMODULE;
begin
  Result := nil;

  // Some Windows builds do not export RtlSecureZeroMemory from kernel32.
  // Resolve at runtime to avoid load-time STATUS_ENTRYPOINT_NOT_FOUND.
  LModule := GetModuleHandle('kernel32.dll');
  if LModule <> 0 then
    Result := GetProcAddress(LModule, 'RtlSecureZeroMemory');

  if Result = nil then
  begin
    LModule := GetModuleHandle('ntdll.dll');
    if LModule <> 0 then
      Result := GetProcAddress(LModule, 'RtlZeroMemory');
  end;
end;

procedure ZeroMemorySecure(Ptr: Pointer; Count: NativeUInt);
var
  LProc: Pointer;
begin
  if (Ptr = nil) or (Count = 0) then
    Exit;

  LProc := ResolveSecureZeroProc;
  if LProc <> nil then
    TSecureZeroProc(LProc)(Ptr, Count)
  else
    FillChar(Ptr^, Count, 0);
end;
{$ENDIF}

procedure SecureZeroMemory(var Data: TBytes);
begin
  if Length(Data) = 0 then
    Exit;

  {$IFDEF MSWINDOWS}
  ZeroMemorySecure(@Data[0], Length(Data));
  {$ELSE}
  FillChar(Data[0], Length(Data), 0);
  {$ENDIF}
end;

procedure SecureZeroMemory(var Data: string);
begin
  if Length(Data) > 0 then
  begin
    UniqueString(Data);
    {$IFDEF MSWINDOWS}
    ZeroMemorySecure(PChar(Data), Length(Data) * SizeOf(Char));
    {$ELSE}
    FillChar(PChar(Data)^, Length(Data) * SizeOf(Char), 0);
    {$ENDIF}
  end;
end;

procedure SecureClearBytes(var Data: TBytes);
begin
  SecureZeroMemory(Data);
  SetLength(Data, 0);
end;

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
// Cross-Platform AES-256-GCM Encryption (macOS/Linux) using OpenSSL
// ============================================================================
// UBS2 Format: [Magic:4][Ver:1][KDF:1][Iter:4][Salt:16][IV:12][Cipher:N][Tag:16]

const
  UBS2_MAGIC: array[0..3] of Byte = ($55, $42, $53, $32); // 'UBS2'
  UBS2_VERSION_V1 = $01;
  UBS2_VERSION_CURRENT = UBS2_VERSION_V1;
  UBS2_SUPPORTED_VERSIONS = '1';
  UBS2_KDF_PBKDF2_SHA256 = $01;
  UBS2_SALT_SIZE = 16;
  UBS2_IV_SIZE = 12;   // GCM recommended nonce size
  UBS2_KEY_SIZE = 32;  // AES-256
  UBS2_TAG_SIZE = 16;  // GCM tag
  UBS2_PBKDF2_ITERATIONS = 100000;
  UBS2_HEADER_SIZE = 4 + 1 + 1 + 4 + 16 + 12; // 38 bytes before ciphertext
  UBS2_MIN_PAYLOAD_SIZE = UBS2_HEADER_SIZE + UBS2_TAG_SIZE;

function GetMachineEntropy: TBytes;
var
  Entropy, EnvKey: string;
  {$IFDEF LINUX}
  F: TextFile;
  MachineId: string;
  {$ENDIF}
begin
  // Check for explicit master key override (for CI/containers)
  EnvKey := GetEnvironmentVariable('DeepBase_MASTER_KEY');
  if EnvKey <> '' then
  begin
    Result := TEncoding.UTF8.GetBytes(EnvKey);
    Exit;
  end;
  
  // Collect machine-specific entropy
  {$IFDEF MACOS}
  Entropy := GetEnvironmentVariable('HOME') + ':' + 
             GetEnvironmentVariable('USER') + ':macOS:DeepBase';
  {$ENDIF}
  
  {$IFDEF LINUX}
  MachineId := '';
  if FileExists('/etc/machine-id') then
  begin
    try
      AssignFile(F, '/etc/machine-id');
      Reset(F);
      ReadLn(F, MachineId);
      CloseFile(F);
    except
      MachineId := '';
    end;
  end;
  if MachineId = '' then
    MachineId := GetEnvironmentVariable('HOSTNAME');
  Entropy := MachineId + ':' + GetEnvironmentVariable('USER') + ':Linux:DeepBase';
  {$ENDIF}
  
  Result := TEncoding.UTF8.GetBytes(Entropy);
end;

function UBS2MagicMatches(const AData: TBytes; const AMagic: string): Boolean;
var
  I: Integer;
begin
  if Length(AData) < Length(AMagic) then
    Exit(False);

  for I := 1 to Length(AMagic) do
    if AData[I - 1] <> Ord(AMagic[I]) then
      Exit(False);

  Result := True;
end;

procedure RaiseInvalidUBS2Magic(const AData: TBytes);
begin
  if UBS2MagicMatches(AData, 'UBS1') then
    raise EDecryptionException.Create(
      'Unsupported legacy encrypted data format UBS1. ' +
      'Migrate or re-save this secret to UBS2 before decrypting.');

  raise EDecryptionException.Create(
    'Unsupported encrypted data format: expected UBS2 magic. ' +
    'Legacy formats must be migrated to UBS2 before decrypting.');
end;

function ReadUBS2Version(const AData: TBytes): Byte;
begin
  if Length(AData) < 5 then
    raise EDecryptionException.CreateFmt(
      'Invalid UBS2 encrypted data: too short to read version (got %d bytes)',
      [Length(AData)]);

  if not UBS2MagicMatches(AData, 'UBS2') then
    RaiseInvalidUBS2Magic(AData);

  Result := AData[4];
end;

procedure RaiseUnsupportedUBS2Version(AVersion: Byte);
begin
  raise EDecryptionException.CreateFmt(
    'Unsupported UBS2 version: %d (supported: %s; current writer: %d). ' +
    'Upgrade DeepBase or migrate/re-save this secret before decrypting. DeepBase=%s',
    [AVersion, UBS2_SUPPORTED_VERSIONS, UBS2_VERSION_CURRENT,
     DeepBase_VERSION_STRING]);
end;

function ReadUInt32LE(const AData: TBytes; AOffset: Integer): Cardinal;
begin
  Result := Cardinal(AData[AOffset]) or
            (Cardinal(AData[AOffset + 1]) shl 8) or
            (Cardinal(AData[AOffset + 2]) shl 16) or
            (Cardinal(AData[AOffset + 3]) shl 24);
end;

function DecryptUBS2V1(const AData: TBytes): string;
var
  MachineKey, Salt, IV, Key, Ciphertext, Tag, Plaintext: TBytes;
  Iterations: Cardinal;
  Offset, CiphertextLen: Integer;
begin
  Result := '';

  if Length(AData) < UBS2_MIN_PAYLOAD_SIZE then
    raise EDecryptionException.CreateFmt(
      'Invalid UBS2 v1 encrypted data: too short (got %d bytes, minimum %d)',
      [Length(AData), UBS2_MIN_PAYLOAD_SIZE]);

  Offset := 5; // Magic and version have already been validated.

  if AData[Offset] <> UBS2_KDF_PBKDF2_SHA256 then
    raise EDecryptionException.CreateFmt(
      'Unsupported UBS2 v1 KDF type: %d (supported: %d/PBKDF2-SHA256)',
      [AData[Offset], UBS2_KDF_PBKDF2_SHA256]);
  Inc(Offset);

  Iterations := ReadUInt32LE(AData, Offset);
  Inc(Offset, 4);
  if Iterations = 0 then
    raise EDecryptionException.Create(
      'Invalid UBS2 v1 encrypted data: PBKDF2 iterations must be greater than zero');

  SetLength(Salt, UBS2_SALT_SIZE);
  Move(AData[Offset], Salt[0], UBS2_SALT_SIZE);
  Inc(Offset, UBS2_SALT_SIZE);

  SetLength(IV, UBS2_IV_SIZE);
  Move(AData[Offset], IV[0], UBS2_IV_SIZE);
  Inc(Offset, UBS2_IV_SIZE);

  CiphertextLen := Length(AData) - Offset - UBS2_TAG_SIZE;
  if CiphertextLen < 0 then
    raise EDecryptionException.Create('Invalid UBS2 v1 encrypted data: corrupted');
  SetLength(Ciphertext, CiphertextLen);
  if CiphertextLen > 0 then
    Move(AData[Offset], Ciphertext[0], CiphertextLen);
  Inc(Offset, CiphertextLen);

  SetLength(Tag, UBS2_TAG_SIZE);
  Move(AData[Offset], Tag[0], UBS2_TAG_SIZE);

  OpenSSL_Init;

  MachineKey := GetMachineEntropy;
  try
    Key := OpenSSL_PBKDF2_SHA256(MachineKey, Salt, Iterations, UBS2_KEY_SIZE);
    try
      Plaintext := OpenSSL_AES256GCM_Decrypt(Key, IV, Ciphertext, nil, Tag);
      try
        Result := TEncoding.UTF8.GetString(Plaintext);
      finally
        // Zeroize decrypted plaintext so a memory dump cannot recover the
        // cleartext secret (CORE-R3-004 fix).
        SecureClearBytes(Plaintext);
      end;
    finally
      // Zeroize the derived key and machine entropy material.
      SecureClearBytes(Key);
    end;
  finally
    SecureClearBytes(MachineKey);
  end;
end;

function DecryptUBS2(const AData: TBytes): string;
var
  Version: Byte;
begin
  Version := ReadUBS2Version(AData);

  case Version of
    UBS2_VERSION_V1:
      Result := DecryptUBS2V1(AData);
  else
    RaiseUnsupportedUBS2Version(Version);
  end;
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
  MachineKey, Salt, IV, Key, Plaintext, Ciphertext, Tag: TBytes;
  Iterations: Cardinal;
  Offset: Integer;
begin
  if AText = '' then
  begin
    SetLength(Result, 0);
    Exit;
  end;
  
  // Initialize OpenSSL if not already done
  OpenSSL_Init;
  
  // Generate random salt and IV
  Salt := OpenSSL_RandomBytes(UBS2_SALT_SIZE);
  IV := OpenSSL_RandomBytes(UBS2_IV_SIZE);
  
  // Derive key from machine entropy using OpenSSL PBKDF2
  MachineKey := GetMachineEntropy;
  try
    Iterations := UBS2_PBKDF2_ITERATIONS;
    Key := OpenSSL_PBKDF2_SHA256(MachineKey, Salt, Iterations, UBS2_KEY_SIZE);
    try
      // Encrypt using AES-256-GCM
      Plaintext := TEncoding.UTF8.GetBytes(AText);
      try
        Ciphertext := OpenSSL_AES256GCM_Encrypt(Key, IV, Plaintext, nil, Tag);

        // Build UBS2 format output
        SetLength(Result, UBS2_HEADER_SIZE + Length(Ciphertext) + UBS2_TAG_SIZE);
        Offset := 0;

        // Magic
        Move(UBS2_MAGIC[0], Result[Offset], 4);
        Inc(Offset, 4);

        // Version
        Result[Offset] := UBS2_VERSION_CURRENT;
        Inc(Offset);

        // KDF type
        Result[Offset] := UBS2_KDF_PBKDF2_SHA256;
        Inc(Offset);

        // Iterations (little-endian)
        Result[Offset] := Byte(Iterations);
        Result[Offset + 1] := Byte(Iterations shr 8);
        Result[Offset + 2] := Byte(Iterations shr 16);
        Result[Offset + 3] := Byte(Iterations shr 24);
        Inc(Offset, 4);

        // Salt
        Move(Salt[0], Result[Offset], UBS2_SALT_SIZE);
        Inc(Offset, UBS2_SALT_SIZE);

        // IV
        Move(IV[0], Result[Offset], UBS2_IV_SIZE);
        Inc(Offset, UBS2_IV_SIZE);

        // Ciphertext
        if Length(Ciphertext) > 0 then
          Move(Ciphertext[0], Result[Offset], Length(Ciphertext));
        Inc(Offset, Length(Ciphertext));

        // Tag
        Move(Tag[0], Result[Offset], UBS2_TAG_SIZE);
      finally
        // Zeroize the UTF-8 plaintext bytes (CORE-R3-004 fix).
        SecureClearBytes(Plaintext);
      end;
    finally
      SecureClearBytes(Key);
    end;
  finally
    SecureClearBytes(MachineKey);
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
begin
  Result := DecryptUBS2(AData);
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
  CipherBase64: string;
  CipherBytes: TBytes;
begin
  Result := '';

  if not Assigned(FStorage) then
    Exit;

  TMonitor.Enter(FLock);
  try
    EnsureSecretsTable;

    if not FStorage.TryReadCipherBlob(AName, CipherBase64) then
      Exit;
    if CipherBase64 = '' then
      Exit;

    CipherBytes := TNetEncoding.Base64.DecodeStringToBytes(CipherBase64);
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
  // éªè¯å¯é¥åç§°ï¼é²æ­¢SQLæ³¨å¥åè·¯å¾éå?
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
