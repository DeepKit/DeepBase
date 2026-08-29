unit DeepBase.Protection;

{$WARN SYMBOL_DEPRECATED OFF}
{$WARN IMPLICIT_STRING_CAST OFF}

interface

uses
  Winapi.Windows, System.SysUtils, System.Classes, System.Hash, System.NetEncoding,
  System.IOUtils, System.AnsiStrings, System.DateUtils, System.Math,
  DeepBase.Logging, DeepBase.Exceptions;

const
  // Windows Crypto API 常量
  PROV_RSA_FULL = 1;
  PROV_RSA_AES = 24;
  CRYPT_VERIFYCONTEXT = $F0000000;
  CRYPT_EXPORTABLE = $00000001;
  CALG_SHA_256 = $0000800c;
  CALG_AES_256 = $00006610;
  KP_MODE = 4;
  KP_IV = 1;
  CRYPT_MODE_CBC = 1;
  HP_HASHVAL = 2;
  MS_ENH_RSA_AES_PROV = 'Microsoft Enhanced RSA and AES Cryptographic Provider';

  // Windows CNG / BCrypt constants for AES-256-GCM
  BCRYPT_DLL = 'bcrypt.dll';
  BCRYPT_AES_ALGORITHM = 'AES';
  BCRYPT_CHAIN_MODE_GCM = 'ChainingModeGCM';
  BCRYPT_CHAINING_MODE = 'ChainingMode';
  BCRYPT_OBJECT_LENGTH = 'ObjectLength';
  BCRYPT_USE_SYSTEM_PREFERRED_RNG = $00000002;
  STATUS_SUCCESS = 0;

  BASIC_PROTECTION_GCM_TEXT_PREFIX = 'UBG1|';
  BASIC_PROTECTION_GCM_MAGIC: array[0..3] of Byte = ($55, $42, $47, $31); // UBG1
  BASIC_PROTECTION_GCM_NONCE_SIZE = 12;
  BASIC_PROTECTION_GCM_TAG_SIZE = 16;
  BASIC_PROTECTION_GCM_HEADER_SIZE = 4 + BASIC_PROTECTION_GCM_NONCE_SIZE + BASIC_PROTECTION_GCM_TAG_SIZE;

  // PBKDF2-derived GCM payload (CORE-R2-005).
  // Layout: Magic(4) + Salt(16) + Nonce(12) + Tag(16) + CipherText
  BASIC_PROTECTION_PBKDF2_MAGIC: array[0..3] of Byte = ($55, $42, $47, $32); // UBG2
  BASIC_PROTECTION_PBKDF2_SALT_SIZE = 16;
  BASIC_PROTECTION_PBKDF2_ITERATIONS = 100000;  // NIST SP 800-132 minimum (2023)
  BASIC_PROTECTION_PBKDF2_NONCE_SIZE = BASIC_PROTECTION_GCM_NONCE_SIZE;
  BASIC_PROTECTION_PBKDF2_TAG_SIZE = BASIC_PROTECTION_GCM_TAG_SIZE;
  BASIC_PROTECTION_PBKDF2_HEADER_SIZE = 4 + BASIC_PROTECTION_PBKDF2_SALT_SIZE +
    BASIC_PROTECTION_PBKDF2_NONCE_SIZE + BASIC_PROTECTION_PBKDF2_TAG_SIZE;
  // Text prefix for password-based PBKDF2 encryption (EncryptSensitiveData)
  BASIC_PROTECTION_PBKDF2_TEXT_PREFIX = 'UBP1|';

type
  HCRYPTPROV = THandle;
  HCRYPTKEY = THandle;
  HCRYPTHASH = THandle;
  BCRYPT_ALG_HANDLE = THandle;
  BCRYPT_KEY_HANDLE = THandle;
  NTSTATUS = LongInt;

  BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO = record
    cbSize: ULONG;
    dwInfoVersion: ULONG;
    pbNonce: PByte;
    cbNonce: ULONG;
    pbAuthData: PByte;
    cbAuthData: ULONG;
    pbTag: PByte;
    cbTag: ULONG;
    pbMacContext: PByte;
    cbMacContext: ULONG;
    cbAAD: ULONG;
    cbData: UInt64;
    dwFlags: ULONG;
  end;
  PBCRYPT_AUTHENTICATED_CIPHER_MODE_INFO = ^BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;

// Windows Crypto API 函数声明
function CryptAcquireContext(var phProv: HCRYPTPROV; pszContainer: PAnsiChar;
  pszProvider: PAnsiChar; dwProvType: DWORD; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll' name 'CryptAcquireContextA';

function CryptReleaseContext(hProv: HCRYPTPROV; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptGenRandom(hProv: HCRYPTPROV; dwLen: DWORD; pbBuffer: PByte): BOOL; stdcall; external 'advapi32.dll';

function CryptCreateHash(hProv: HCRYPTPROV; Algid: DWORD; hKey: HCRYPTKEY;
  dwFlags: DWORD; var phHash: HCRYPTHASH): BOOL; stdcall; external 'advapi32.dll';

function CryptHashData(hHash: HCRYPTHASH; pbData: PByte; dwDataLen: DWORD;
  dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptDeriveKey(hProv: HCRYPTPROV; Algid: DWORD; hBaseData: HCRYPTHASH;
  dwFlags: DWORD; var phKey: HCRYPTKEY): BOOL; stdcall; external 'advapi32.dll';

function CryptSetKeyParam(hKey: HCRYPTKEY; dwParam: DWORD; pbData: PByte;
  dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptEncrypt(hKey: HCRYPTKEY; hHash: HCRYPTHASH; Final: BOOL;
  dwFlags: DWORD; pbData: PByte; var pdwDataLen: DWORD; dwBufLen: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptDecrypt(hKey: HCRYPTKEY; hHash: HCRYPTHASH; Final: BOOL;
  dwFlags: DWORD; pbData: PByte; var pdwDataLen: DWORD): BOOL; stdcall; external 'advapi32.dll';

function CryptDestroyKey(hKey: HCRYPTKEY): BOOL; stdcall; external 'advapi32.dll';

function CryptDestroyHash(hHash: HCRYPTHASH): BOOL; stdcall; external 'advapi32.dll';

function CryptGetHashParam(hHash: HCRYPTHASH; dwParam: DWORD; pbData: PByte;
  var pdwDataLen: DWORD; dwFlags: DWORD): BOOL; stdcall; external 'advapi32.dll';

// Windows CNG / BCrypt 函数声明
function BCryptOpenAlgorithmProvider(out phAlgorithm: BCRYPT_ALG_HANDLE;
  pszAlgId: PWideChar; pszImplementation: PWideChar; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptCloseAlgorithmProvider(hAlgorithm: BCRYPT_ALG_HANDLE;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptGetProperty(hObject: THandle; pszProperty: PWideChar;
  pbOutput: PByte; cbOutput: ULONG; out pcbResult: ULONG;
  dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptSetProperty(hObject: THandle; pszProperty: PWideChar;
  pbInput: PByte; cbInput: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptGenerateSymmetricKey(hAlgorithm: BCRYPT_ALG_HANDLE;
  out phKey: BCRYPT_KEY_HANDLE; pbKeyObject: PByte; cbKeyObject: ULONG;
  pbSecret: PByte; cbSecret: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptDestroyKey(hKey: BCRYPT_KEY_HANDLE): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptEncrypt(hKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  pPaddingInfo: Pointer; pbIV: PByte; cbIV: ULONG; pbOutput: PByte;
  cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptDecrypt(hKey: BCRYPT_KEY_HANDLE; pbInput: PByte; cbInput: ULONG;
  pPaddingInfo: Pointer; pbIV: PByte; cbIV: ULONG; pbOutput: PByte;
  cbOutput: ULONG; out pcbResult: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

function BCryptGenRandom(hAlgorithm: BCRYPT_ALG_HANDLE; pbBuffer: PByte;
  cbBuffer: ULONG; dwFlags: ULONG): NTSTATUS; stdcall; external BCRYPT_DLL;

type
  TBasicProtection = class
  private
    class function GenerateRandomBytes(ALength: Integer): TBytes; static;
    class function DeriveAes256Key(const APassword: string): TBytes; static; deprecated 'Use DeriveAes256KeyPBKDF2 for new code (CORE-R2-005)';
    class function IsGcmPayload(const AData: TBytes): Boolean; static;
    class function DecryptGcmBytes(const AEncryptedData: TBytes; const APassword: string): TBytes; static;
    class function DecryptCbcBytes(const AEncryptedData: TBytes; const APassword: string): TBytes; static;
    class function BytesToHex(const ABytes: TBytes): string; static;
    class function HexToBytes(const AHex: string): TBytes; static;
    class function UnpadData(const AData: TBytes): TBytes; static;
    class function CalculateHMACBinary(const AData: TBytes; const AKey: TBytes): TBytes; static;
    /// <summary>
    ///   PBKDF2-HMAC-SHA256 key derivation (RFC 2898).
    ///   Use for new encryption code paths. Replaces the deprecated single-SHA-256
    ///   DeriveAes256Key with an iteration-hardened derivation that resists
    ///   brute-force and dictionary attacks.
    /// </summary>
    /// <param name="APassword">Password string (UTF-8 encoded internally).</param>
    /// <param name="ASalt">Random salt; 16 bytes recommended. Must be unique per derivation.</param>
    /// <param name="AIterations">Iteration count. Minimum 100000 (NIST 2023).</param>
    /// <returns>32-byte (256-bit) derived key suitable for AES-256.</returns>
    class function DeriveAes256KeyPBKDF2(const APassword: string;
      const ASalt: TBytes; AIterations: Integer): TBytes; static;
    class function IsPbkdf2Payload(const AData: TBytes): Boolean; static;
    class function EncryptGcmPbkdf2Bytes(const AData: TBytes; const APassword: string): TBytes; static;
    class function DecryptGcmPbkdf2Bytes(const AEncryptedData: TBytes; const APassword: string): TBytes; static;
  public
    // 密钥生成（为兼容保留，当前返回空字符串）
    class function GetDynamicKey: string; static; deprecated 'Use DeepBase.Security for key management';
    // 加密解密
    // BUG-034 FIX: Remove hardcoded default password - require explicit password
    class function EncryptSensitiveData(const AData: string; const APassword: string): string; static;
    class function DecryptSensitiveData(const AEncryptedData: string; const APassword: string): string; static;
    class function EncryptBinaryData(const AData: TBytes; const APassword: string): TBytes; static;
    class function DecryptBinaryData(const AEncryptedData: TBytes; const APassword: string): TBytes; static;
    // 完整性校�?
    class function CalculateHMAC(const AData: string; const APassword: string): string; static;
    class function VerifyDataIntegrity(const AData, AHMAC: string; const APassword: string): Boolean; static;
    class function CalculateFileHash(const AFileName: string): string; static;
    class function CalculateDataHash(const AData: TBytes): string; static;
  end;

implementation

// 以下实现直接来自�?uBasicProtection.pas，保持语义不�?

class function TBasicProtection.GetDynamicKey: string;
begin
  // 移除动态密钥生成，返回空字符串
  // 这个方法已被弃用，建议使用更安全的密钥管理方�?
  Result := '';
  
  // 记录警告日志
  try
    if DeepBase.Logging.Logger <> nil then
      DeepBase.Logging.Logger.Warn('GetDynamicKey is deprecated and returns empty string for security reasons');
  except
    // Ignore logging errors
  end;
end;

class function TBasicProtection.GenerateRandomBytes(ALength: Integer): TBytes;
var
  Status: NTSTATUS;
begin
  if ALength < 0 then
    raise ERandomException.Create('Invalid random byte count');

  SetLength(Result, ALength);
  if ALength = 0 then
    Exit;

  Status := BCryptGenRandom(0, @Result[0], ALength, BCRYPT_USE_SYSTEM_PREFERRED_RNG);
  if Status <> STATUS_SUCCESS then
    raise ERandomException.CreateFmt('BCryptGenRandom failed with status: %d', [Status]);
end;

class function TBasicProtection.DeriveAes256Key(const APassword: string): TBytes;
begin
  if Trim(APassword) = '' then
    raise EMissingConfigurationException.Create('Password is required');

  // DEPRECATED (CORE-R2-005): single SHA-256 is too fast for password-derived keys;
  // it offers no resistance to brute-force or dictionary attacks.
  // Retained ONLY for decrypting data produced by EncryptGcmBytes prior to the
  // PBKDF2 upgrade (UBG1 payloads). New code paths must use DeriveAes256KeyPBKDF2
  // together with EncryptGcmPbkdf2Bytes / DecryptGcmPbkdf2Bytes (UBG2 payloads).
  Result := THashSHA2.GetHashBytes(APassword);
  if Length(Result) <> 32 then
    raise EHashException.Create('Failed to derive AES-256 key');
end;

class function TBasicProtection.IsGcmPayload(const AData: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(AData) >= BASIC_PROTECTION_GCM_HEADER_SIZE;
  if not Result then
    Exit;

  for I := 0 to High(BASIC_PROTECTION_GCM_MAGIC) do
  begin
    if AData[I] <> BASIC_PROTECTION_GCM_MAGIC[I] then
      Exit(False);
  end;
end;

class function TBasicProtection.DecryptGcmBytes(const AEncryptedData: TBytes; const APassword: string): TBytes;
var
  AlgHandle: BCRYPT_ALG_HANDLE;
  KeyHandle: BCRYPT_KEY_HANDLE;
  KeyObjectSize, PropSize, ResultSize: ULONG;
  Status: NTSTATUS;
  ChainMode: WideString;
  KeyObject, KeyBytes, Nonce, Tag, Ciphertext: TBytes;
  AuthInfo: BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;
  Offset, CipherLen: Integer;
begin
  if not IsGcmPayload(AEncryptedData) then
    raise EDecryptionException.Create('Invalid AES-GCM encrypted data format');

  Offset := Length(BASIC_PROTECTION_GCM_MAGIC);

  SetLength(Nonce, BASIC_PROTECTION_GCM_NONCE_SIZE);
  Move(AEncryptedData[Offset], Nonce[0], Length(Nonce));
  Inc(Offset, Length(Nonce));

  SetLength(Tag, BASIC_PROTECTION_GCM_TAG_SIZE);
  Move(AEncryptedData[Offset], Tag[0], Length(Tag));
  Inc(Offset, Length(Tag));

  CipherLen := Length(AEncryptedData) - Offset;
  SetLength(Ciphertext, CipherLen);
  if CipherLen > 0 then
    Move(AEncryptedData[Offset], Ciphertext[0], CipherLen);

  AlgHandle := 0;
  KeyHandle := 0;
  KeyBytes := DeriveAes256Key(APassword);

  try
    Status := BCryptOpenAlgorithmProvider(AlgHandle, BCRYPT_AES_ALGORITHM, nil, 0);
    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('BCryptOpenAlgorithmProvider failed: %d', [Status]);

    ChainMode := BCRYPT_CHAIN_MODE_GCM;
    Status := BCryptSetProperty(AlgHandle, BCRYPT_CHAINING_MODE,
      PByte(PWideChar(ChainMode)), (Length(ChainMode) + 1) * SizeOf(WideChar), 0);
    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('BCryptSetProperty (GCM) failed: %d', [Status]);

    Status := BCryptGetProperty(AlgHandle, BCRYPT_OBJECT_LENGTH,
      @KeyObjectSize, SizeOf(KeyObjectSize), PropSize, 0);
    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('BCryptGetProperty failed: %d', [Status]);

    SetLength(KeyObject, KeyObjectSize);
    Status := BCryptGenerateSymmetricKey(AlgHandle, KeyHandle,
      @KeyObject[0], KeyObjectSize, @KeyBytes[0], Length(KeyBytes), 0);
    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [Status]);

    SetLength(Result, Length(Ciphertext));
    FillChar(AuthInfo, SizeOf(AuthInfo), 0);
    AuthInfo.cbSize := SizeOf(AuthInfo);
    AuthInfo.dwInfoVersion := 1;
    AuthInfo.pbNonce := @Nonce[0];
    AuthInfo.cbNonce := Length(Nonce);
    AuthInfo.pbTag := @Tag[0];
    AuthInfo.cbTag := Length(Tag);

    if Length(Ciphertext) > 0 then
      Status := BCryptDecrypt(KeyHandle, @Ciphertext[0], Length(Ciphertext), @AuthInfo,
        nil, 0, @Result[0], Length(Result), ResultSize, 0)
    else
      Status := BCryptDecrypt(KeyHandle, nil, 0, @AuthInfo,
        nil, 0, nil, 0, ResultSize, 0);

    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('AES-GCM authentication failed: %d', [Status]);

    SetLength(Result, ResultSize);
  finally
    if KeyHandle <> 0 then
      BCryptDestroyKey(KeyHandle);
    if AlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(AlgHandle, 0);
  end;
end;

class function TBasicProtection.UnpadData(const AData: TBytes): TBytes;
var
  PadLength: Integer;
  I: Integer;
begin
  if Length(AData) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  PadLength := AData[High(AData)];

  if (PadLength <= 0) or (PadLength > Length(AData)) then
    raise EDecryptionException.Create('Invalid data padding');

  for I := Length(AData) - PadLength to High(AData) do
  begin
    if AData[I] <> PadLength then
      raise EDecryptionException.Create('Invalid data padding');
  end;

  SetLength(Result, Length(AData) - PadLength);
  if Length(Result) > 0 then
    Move(AData[0], Result[0], Length(Result));
end;

class function TBasicProtection.IsPbkdf2Payload(const AData: TBytes): Boolean;
var
  I: Integer;
begin
  Result := Length(AData) >= BASIC_PROTECTION_PBKDF2_HEADER_SIZE;
  if not Result then
    Exit;
  for I := 0 to High(BASIC_PROTECTION_PBKDF2_MAGIC) do
    if AData[I] <> BASIC_PROTECTION_PBKDF2_MAGIC[I] then
      Exit(False);
end;

class function TBasicProtection.EncryptGcmPbkdf2Bytes(
  const AData: TBytes; const APassword: string): TBytes;
var
  AlgHandle: BCRYPT_ALG_HANDLE;
  KeyHandle: BCRYPT_KEY_HANDLE;
  KeyObjectSize, PropSize, ResultSize: ULONG;
  Status: NTSTATUS;
  ChainMode: WideString;
  KeyObject, KeyBytes, Salt, Nonce, Tag, Ciphertext: TBytes;
  AuthInfo: BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;
  Offset: Integer;
begin
  AlgHandle := 0;
  KeyHandle := 0;
  Salt := GenerateRandomBytes(BASIC_PROTECTION_PBKDF2_SALT_SIZE);
  Nonce := GenerateRandomBytes(BASIC_PROTECTION_PBKDF2_NONCE_SIZE);
  KeyBytes := DeriveAes256KeyPBKDF2(APassword, Salt, BASIC_PROTECTION_PBKDF2_ITERATIONS);

  try
    Status := BCryptOpenAlgorithmProvider(AlgHandle, BCRYPT_AES_ALGORITHM, nil, 0);
    if Status <> STATUS_SUCCESS then
      raise EEncryptionException.CreateFmt('BCryptOpenAlgorithmProvider failed: %d', [Status]);

    ChainMode := BCRYPT_CHAIN_MODE_GCM;
    Status := BCryptSetProperty(AlgHandle, BCRYPT_CHAINING_MODE,
      PByte(PWideChar(ChainMode)), (Length(ChainMode) + 1) * SizeOf(WideChar), 0);
    if Status <> STATUS_SUCCESS then
      raise EEncryptionException.CreateFmt('BCryptSetProperty (GCM) failed: %d', [Status]);

    Status := BCryptGetProperty(AlgHandle, BCRYPT_OBJECT_LENGTH,
      @KeyObjectSize, SizeOf(KeyObjectSize), PropSize, 0);
    if Status <> STATUS_SUCCESS then
      raise EEncryptionException.CreateFmt('BCryptGetProperty failed: %d', [Status]);

    SetLength(KeyObject, KeyObjectSize);
    Status := BCryptGenerateSymmetricKey(AlgHandle, KeyHandle,
      @KeyObject[0], KeyObjectSize, @KeyBytes[0], Length(KeyBytes), 0);
    if Status <> STATUS_SUCCESS then
      raise EEncryptionException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [Status]);

    SetLength(Tag, BASIC_PROTECTION_PBKDF2_TAG_SIZE);
    SetLength(Ciphertext, Length(AData));

    FillChar(AuthInfo, SizeOf(AuthInfo), 0);
    AuthInfo.cbSize := SizeOf(AuthInfo);
    AuthInfo.dwInfoVersion := 1;
    AuthInfo.pbNonce := @Nonce[0];
    AuthInfo.cbNonce := Length(Nonce);
    AuthInfo.pbTag := @Tag[0];
    AuthInfo.cbTag := Length(Tag);

    if Length(AData) > 0 then
      Status := BCryptEncrypt(KeyHandle, @AData[0], Length(AData), @AuthInfo,
        nil, 0, @Ciphertext[0], Length(Ciphertext), ResultSize, 0)
    else
      Status := BCryptEncrypt(KeyHandle, nil, 0, @AuthInfo,
        nil, 0, nil, 0, ResultSize, 0);

    if Status <> STATUS_SUCCESS then
      raise EEncryptionException.CreateFmt('AES-GCM encryption failed: %d', [Status]);

    SetLength(Ciphertext, ResultSize);

    // Output: Magic(4) + Salt(16) + Nonce(12) + Tag(16) + CipherText
    SetLength(Result, BASIC_PROTECTION_PBKDF2_HEADER_SIZE + Length(Ciphertext));
    Offset := 0;
    Move(BASIC_PROTECTION_PBKDF2_MAGIC[0], Result[Offset], Length(BASIC_PROTECTION_PBKDF2_MAGIC));
    Inc(Offset, Length(BASIC_PROTECTION_PBKDF2_MAGIC));
    Move(Salt[0], Result[Offset], Length(Salt));
    Inc(Offset, Length(Salt));
    Move(Nonce[0], Result[Offset], Length(Nonce));
    Inc(Offset, Length(Nonce));
    Move(Tag[0], Result[Offset], Length(Tag));
    Inc(Offset, Length(Tag));
    if Length(Ciphertext) > 0 then
      Move(Ciphertext[0], Result[Offset], Length(Ciphertext));
  finally
    if KeyHandle <> 0 then
      BCryptDestroyKey(KeyHandle);
    if AlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(AlgHandle, 0);
  end;
end;

class function TBasicProtection.DecryptGcmPbkdf2Bytes(
  const AEncryptedData: TBytes; const APassword: string): TBytes;
var
  AlgHandle: BCRYPT_ALG_HANDLE;
  KeyHandle: BCRYPT_KEY_HANDLE;
  KeyObjectSize, PropSize, ResultSize: ULONG;
  Status: NTSTATUS;
  ChainMode: WideString;
  KeyObject, KeyBytes, Salt, Nonce, Tag, Ciphertext: TBytes;
  AuthInfo: BCRYPT_AUTHENTICATED_CIPHER_MODE_INFO;
  Offset, CipherLen: Integer;
begin
  if not IsPbkdf2Payload(AEncryptedData) then
    raise EDecryptionException.Create('Invalid PBKDF2-GCM encrypted data format');

  Offset := Length(BASIC_PROTECTION_PBKDF2_MAGIC);

  SetLength(Salt, BASIC_PROTECTION_PBKDF2_SALT_SIZE);
  Move(AEncryptedData[Offset], Salt[0], Length(Salt));
  Inc(Offset, Length(Salt));

  SetLength(Nonce, BASIC_PROTECTION_PBKDF2_NONCE_SIZE);
  Move(AEncryptedData[Offset], Nonce[0], Length(Nonce));
  Inc(Offset, Length(Nonce));

  SetLength(Tag, BASIC_PROTECTION_PBKDF2_TAG_SIZE);
  Move(AEncryptedData[Offset], Tag[0], Length(Tag));
  Inc(Offset, Length(Tag));

  CipherLen := Length(AEncryptedData) - Offset;
  SetLength(Ciphertext, CipherLen);
  if CipherLen > 0 then
    Move(AEncryptedData[Offset], Ciphertext[0], CipherLen);

  // Derive key using PBKDF2 with the salt embedded in the payload
  KeyBytes := DeriveAes256KeyPBKDF2(APassword, Salt, BASIC_PROTECTION_PBKDF2_ITERATIONS);

  AlgHandle := 0;
  KeyHandle := 0;

  try
    Status := BCryptOpenAlgorithmProvider(AlgHandle, BCRYPT_AES_ALGORITHM, nil, 0);
    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('BCryptOpenAlgorithmProvider failed: %d', [Status]);

    ChainMode := BCRYPT_CHAIN_MODE_GCM;
    Status := BCryptSetProperty(AlgHandle, BCRYPT_CHAINING_MODE,
      PByte(PWideChar(ChainMode)), (Length(ChainMode) + 1) * SizeOf(WideChar), 0);
    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('BCryptSetProperty (GCM) failed: %d', [Status]);

    Status := BCryptGetProperty(AlgHandle, BCRYPT_OBJECT_LENGTH,
      @KeyObjectSize, SizeOf(KeyObjectSize), PropSize, 0);
    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('BCryptGetProperty failed: %d', [Status]);

    SetLength(KeyObject, KeyObjectSize);
    Status := BCryptGenerateSymmetricKey(AlgHandle, KeyHandle,
      @KeyObject[0], KeyObjectSize, @KeyBytes[0], Length(KeyBytes), 0);
    if Status <> STATUS_SUCCESS then
      raise EEncryptionException.CreateFmt('BCryptGenerateSymmetricKey failed: %d', [Status]);

    SetLength(Result, Length(Ciphertext));
    FillChar(AuthInfo, SizeOf(AuthInfo), 0);
    AuthInfo.cbSize := SizeOf(AuthInfo);
    AuthInfo.dwInfoVersion := 1;
    AuthInfo.pbNonce := @Nonce[0];
    AuthInfo.cbNonce := Length(Nonce);
    AuthInfo.pbTag := @Tag[0];
    AuthInfo.cbTag := Length(Tag);

    if Length(Ciphertext) > 0 then
      Status := BCryptDecrypt(KeyHandle, @Ciphertext[0], Length(Ciphertext), @AuthInfo,
        nil, 0, @Result[0], Length(Result), ResultSize, 0)
    else
      Status := BCryptDecrypt(KeyHandle, nil, 0, @AuthInfo,
        nil, 0, nil, 0, ResultSize, 0);

    if Status <> STATUS_SUCCESS then
      raise EDecryptionException.CreateFmt('AES-GCM authentication failed: %d', [Status]);

    SetLength(Result, ResultSize);
  finally
    if KeyHandle <> 0 then
      BCryptDestroyKey(KeyHandle);
    if AlgHandle <> 0 then
      BCryptCloseAlgorithmProvider(AlgHandle, 0);
  end;
end;

class function TBasicProtection.EncryptSensitiveData(const AData: string; const APassword: string): string;
var
  Payload: TBytes;
begin
  if AData = '' then
  begin
    Result := '';
    Exit;
  end;

  // CORE-R2-005: New encryption uses PBKDF2-HMAC-SHA256 key derivation + AES-GCM.
  Payload := EncryptGcmPbkdf2Bytes(TEncoding.UTF8.GetBytes(AData), APassword);
  Result := BASIC_PROTECTION_PBKDF2_TEXT_PREFIX + BytesToHex(Payload);
end;

class function TBasicProtection.DecryptSensitiveData(const AEncryptedData: string; const APassword: string): string;
var
  Parts: TArray<string>;
  IV, EncryptedBytes, Payload: TBytes;
begin
  Result := '';
  if AEncryptedData = '' then
    Exit;

  // CORE-R2-005: PBKDF2-GCM path (new format)
  if Copy(AEncryptedData, 1, Length(BASIC_PROTECTION_PBKDF2_TEXT_PREFIX)) = BASIC_PROTECTION_PBKDF2_TEXT_PREFIX then
  begin
    Payload := HexToBytes(Copy(AEncryptedData, Length(BASIC_PROTECTION_PBKDF2_TEXT_PREFIX) + 1, MaxInt));
    Result := TEncoding.UTF8.GetString(DecryptGcmPbkdf2Bytes(Payload, APassword));
    Exit;
  end;

  // Legacy UBG1 path: SHA-256 key derivation + AES-GCM
  if Copy(AEncryptedData, 1, Length(BASIC_PROTECTION_GCM_TEXT_PREFIX)) = BASIC_PROTECTION_GCM_TEXT_PREFIX then
  begin
    Payload := HexToBytes(Copy(AEncryptedData, Length(BASIC_PROTECTION_GCM_TEXT_PREFIX) + 1, MaxInt));
    Result := TEncoding.UTF8.GetString(DecryptGcmBytes(Payload, APassword));
    Exit;
  end;

  // Legacy CBC path: no authentication. Reject if the data looks like a
  // truncated GCM payload (starts with GCM magic bytes in hex) to prevent
  // downgrade attacks where an attacker strips the UBG1| prefix.
  if Length(AEncryptedData) >= Length(BASIC_PROTECTION_GCM_MAGIC) * 2 then
  begin
    var HexPrefix := LowerCase(Copy(AEncryptedData, 1, Length(BASIC_PROTECTION_GCM_MAGIC) * 2));
    var MagicHex: string;
    for var I := 0 to High(BASIC_PROTECTION_GCM_MAGIC) do
      MagicHex := MagicHex + IntToHex(BASIC_PROTECTION_GCM_MAGIC[I], 2);
    MagicHex := LowerCase(MagicHex);
    if HexPrefix = MagicHex then
      raise EDecryptionException.Create('Refusing legacy CBC decrypt of GCM-formatted data (possible downgrade)');
  end;

  Parts := AEncryptedData.Split(['|']);
  if Length(Parts) <> 2 then
    raise EDecryptionException.Create('Invalid encrypted data format');

  IV := HexToBytes(Parts[0]);
  EncryptedBytes := HexToBytes(Parts[1]);

  SetLength(Payload, Length(IV) + Length(EncryptedBytes));
  if Length(IV) > 0 then
    Move(IV[0], Payload[0], Length(IV));
  if Length(EncryptedBytes) > 0 then
    Move(EncryptedBytes[0], Payload[Length(IV)], Length(EncryptedBytes));

  Result := TEncoding.UTF8.GetString(DecryptCbcBytes(Payload, APassword));
end;

class function TBasicProtection.EncryptBinaryData(const AData: TBytes; const APassword: string): TBytes;
begin
  if Length(AData) = 0 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  // CORE-R2-005: Use PBKDF2-HMAC-SHA256 key derivation + AES-GCM.
  // The output uses the UBG2 magic so DecryptBinaryData can distinguish it
  // from the legacy UBG1 (single SHA-256 key derivation) format.
  Result := EncryptGcmPbkdf2Bytes(AData, APassword);
end;


class function TBasicProtection.DecryptBinaryData(const AEncryptedData: TBytes; const APassword: string): TBytes;
begin
  SetLength(Result, 0);
  if Length(AEncryptedData) = 0 then
    Exit;

  // CORE-R2-005: Detect PBKDF2-GCM payload first (UBG2), then legacy SHA-256
  // GCM payload (UBG1), and finally fall back to legacy CBC (no magic).
  if IsPbkdf2Payload(AEncryptedData) then
    Result := DecryptGcmPbkdf2Bytes(AEncryptedData, APassword)
  else if IsGcmPayload(AEncryptedData) then
    Result := DecryptGcmBytes(AEncryptedData, APassword)
  else
    Result := DecryptCbcBytes(AEncryptedData, APassword);
end;

class function TBasicProtection.DecryptCbcBytes(const AEncryptedData: TBytes; const APassword: string): TBytes;
var
  hProv: HCRYPTPROV;
  hKey: HCRYPTKEY;
  hHash: HCRYPTHASH;
  IV, EncryptedBytes, DecryptedData: TBytes;
  DataLen: DWORD;
  KeyBytes: TBytes;
  Mode: DWORD;
begin
  SetLength(Result, 0);
  if Length(AEncryptedData) < 16 then Exit;

  SetLength(IV, 16);
  Move(AEncryptedData[0], IV[0], 16);
  SetLength(EncryptedBytes, Length(AEncryptedData) - 16);
  Move(AEncryptedData[16], EncryptedBytes[0], Length(EncryptedBytes));

  KeyBytes := TEncoding.UTF8.GetBytes(APassword);

  if not CryptAcquireContext(hProv, nil, MS_ENH_RSA_AES_PROV, PROV_RSA_AES, CRYPT_VERIFYCONTEXT) then
    raise EDecryptionException.Create('Failed to acquire AES decryption context');

  try
    if not CryptCreateHash(hProv, CALG_SHA_256, 0, 0, hHash) then
      raise EHashException.Create('Failed to create hash object');
    try
      if not CryptHashData(hHash, @KeyBytes[0], Length(KeyBytes), 0) then
        raise EHashException.Create('Failed to hash key data');
      if not CryptDeriveKey(hProv, CALG_AES_256, hHash, CRYPT_EXPORTABLE, hKey) then
        raise EEncryptionException.Create('Failed to derive AES key');
      try
        Mode := CRYPT_MODE_CBC;
        if not CryptSetKeyParam(hKey, KP_MODE, @Mode, 0) then
          raise EEncryptionException.Create('Failed to set CBC mode');
        if not CryptSetKeyParam(hKey, KP_IV, @IV[0], 0) then
          raise EEncryptionException.Create('Failed to set IV');

        DecryptedData := Copy(EncryptedBytes);
        DataLen := Length(DecryptedData);
        if not CryptDecrypt(hKey, 0, True, 0, @DecryptedData[0], DataLen) then
          raise EDecryptionException.Create('AES decryption failed');

        SetLength(DecryptedData, DataLen);
        Result := UnpadData(DecryptedData);
      finally
        CryptDestroyKey(hKey);
      end;
    finally
      CryptDestroyHash(hHash);
    end;
  finally
    CryptReleaseContext(hProv, 0);
  end;
end;

class function TBasicProtection.DeriveAes256KeyPBKDF2(
  const APassword: string; const ASalt: TBytes; AIterations: Integer): TBytes;
var
  LPasswordBytes: TBytes;
  LSaltPlusBlock: TBytes;
  LBlock, LUTemp: TBytes;
  I, J: Integer;
begin
  if Trim(APassword) = '' then
    raise EMissingConfigurationException.Create('Password is required');
  if Length(ASalt) = 0 then
    raise EMissingConfigurationException.Create('Salt is required for PBKDF2');
  if AIterations < 1000 then
    raise EMissingConfigurationException.CreateFmt(
      'PBKDF2 iteration count too low: %d (minimum 1000)', [AIterations]);

  LPasswordBytes := TEncoding.UTF8.GetBytes(APassword);
  try
    SetLength(Result, 32);
    SetLength(LSaltPlusBlock, Length(ASalt) + 4);
    Move(ASalt[0], LSaltPlusBlock[0], Length(ASalt));

    // PBKDF2-HMAC-SHA256 (RFC 2898 §5.2).
    // 32 bytes fits in a single HMAC block (dkLen <= hLen), so the outer
    // loop runs exactly once (block index = 1).
    //
    // U_1  = HMAC-SHA256(password, salt || INT_32_BE(1))
    // U_j  = HMAC-SHA256(password, U_{j-1})     for j = 2..iterations
    // DK   = U_1 xor U_2 xor ... xor U_c
    LSaltPlusBlock[Length(ASalt)]     := 0;
    LSaltPlusBlock[Length(ASalt) + 1] := 0;
    LSaltPlusBlock[Length(ASalt) + 2] := 0;
    LSaltPlusBlock[Length(ASalt) + 3] := 1; // INT_32_BE block index = 1

    // U_1
    LBlock := THashSHA2.GetHMACAsBytes(LSaltPlusBlock, LPasswordBytes);
    Result := Copy(LBlock);

    // U_2 .. U_c; accumulate XOR directly into Result
    for J := 2 to AIterations do
    begin
      LUTemp := THashSHA2.GetHMACAsBytes(LBlock, LPasswordBytes);
      for I := 0 to 31 do
        Result[I] := Result[I] xor LUTemp[I];
      LBlock := LUTemp;
    end;
  finally
    // Zeroize ALL intermediate key material on the heap, including the
    // UTF-8 password bytes and the salt||block buffer, so a memory dump
    // cannot recover the password or derive inputs (CORE-R3-003 fix).
    if Length(LPasswordBytes) > 0 then
      FillChar(LPasswordBytes[0], Length(LPasswordBytes), 0);
    if Length(LSaltPlusBlock) > 0 then
      FillChar(LSaltPlusBlock[0], Length(LSaltPlusBlock), 0);
    if Length(LBlock) > 0 then
      FillChar(LBlock[0], Length(LBlock), 0);
    if Length(LUTemp) > 0 then
      FillChar(LUTemp[0], Length(LUTemp), 0);
  end;
end;

class function TBasicProtection.CalculateHMACBinary(const AData: TBytes; const AKey: TBytes): TBytes;
begin
  if Length(AKey) = 0 then
    raise EMissingConfigurationException.Create('HMAC key is required');

  Result := THashSHA2.GetHMACAsBytes(
    AData,
    AKey,
    THashSHA2.TSHA2Version.SHA256
  );
end;

class function TBasicProtection.VerifyDataIntegrity(const AData, AHMAC: string; const APassword: string): Boolean;
var
  ExpectedHMAC: string;
  I, Diff: Integer;
begin
  // BUG-036 FIX: Use constant-time comparison to prevent timing attacks
  ExpectedHMAC := CalculateHMAC(AData, APassword);
  
  // Constant-time string comparison
  if Length(ExpectedHMAC) <> Length(AHMAC) then
    Exit(False);
  
  Diff := 0;
  for I := 1 to Length(ExpectedHMAC) do
    Diff := Diff or (Ord(ExpectedHMAC[I]) xor Ord(AHMAC[I]));
  
  Result := Diff = 0;
end;

class function TBasicProtection.CalculateFileHash(const AFileName: string): string;
var
  FileStream: TFileStream;
begin
  if not TFile.Exists(AFileName) then
    raise EFileNotFoundExceptionEx.Create('File not found: ' + AFileName);

  FileStream := TFileStream.Create(AFileName, fmOpenRead or fmShareDenyWrite);
  try
    Result := THashSHA2.GetHashString(FileStream);
  finally
    FileStream.Free;
  end;
end;

class function TBasicProtection.CalculateDataHash(const AData: TBytes): string;
var
  LHash: THashSHA2;
begin
  LHash := THashSHA2.Create;
  LHash.Update(AData, Length(AData));
  Result := LHash.HashAsString;
end;

class function TBasicProtection.BytesToHex(const ABytes: TBytes): string;
var
  I: Integer;
begin
  Result := '';
  for I := 0 to Length(ABytes) - 1 do
    Result := Result + IntToHex(ABytes[I], 2);
end;

class function TBasicProtection.HexToBytes(const AHex: string): TBytes;
var
  I: Integer;
begin
  SetLength(Result, Length(AHex) div 2);
  for I := 0 to Length(Result) - 1 do
    Result[I] := StrToInt('$' + Copy(AHex, I * 2 + 1, 2));
end;


class function TBasicProtection.CalculateHMAC(const AData: string; const APassword: string): string;
var
  DataBytes, KeyBytes, HMACBytes: TBytes;
begin
  if Trim(APassword) = '' then
    raise EMissingConfigurationException.Create('Password is required');

  DataBytes := TEncoding.UTF8.GetBytes(AData);
  KeyBytes := TEncoding.UTF8.GetBytes(APassword);
  HMACBytes := CalculateHMACBinary(DataBytes, KeyBytes);
  Result := BytesToHex(HMACBytes);
end;

end.
